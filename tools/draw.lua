local DrawTool = {
    name = 'Draw',
    propertyNames = {
    },
    dependencies = {
        'Body',
        'Drawing',
    },
    handlers = {},
    tool = {
        icon = 'pencil-alt',
        iconFamily = 'FontAwesome5',
        needsPerformingOff = true,
    },
}

registerCoreBehavior(DrawTool)


-- Behavior management

function DrawTool.handlers:addBehavior(opts)
    self._lineWidth = 10
    self._lineColor = { 0, 0, 0, 1 }

    self._fillEnabled = true
    self._fillColor = { 1, 1, 1, 1 }
end


-- Component management

function DrawTool.handlers:addComponent(component, bp, opts)
end

function DrawTool.handlers:removeComponent(component, opts)
    if opts.isOrigin and not opts.removeActor and component._graphics then
        local actorId = component.actorId

        local newUrl = 'ser:' .. self.dependencies.Drawing:serialize(
            component._graphics,
            component._graphicsWidth,
            component._graphicsHeight)
        print('newUrl', newUrl)
        local oldUrl = self.dependencies.Drawing:get(actorId).properties.url

        self.dependencies.Drawing:command('draw', {
            params = { 'oldUrl', 'newUrl' },
        }, function()
            self:sendSetProperties(actorId, 'url', newUrl)
        end, function()
            self:sendSetProperties(actorId, 'url', oldUrl)
        end)
    end
end


-- Update

function DrawTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end

    -- Steal all touches
    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        touch.used = true
    end
end

function DrawTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    -- Make sure we have exactly one actor active
    local singleActorId, singleComponent
    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            if singleActorId then
                return
            end
            singleActorId, singleComponent = actorId, component
        end
    end
    if not singleComponent then
        return
    end
    local c = singleComponent

    -- Make sure the graphics is initialized
    local drawingComponent = self.dependencies.Drawing:get(c.actorId)
    if not (drawingComponent._cacheEntry and drawingComponent._cacheEntry.graphics) then
        return
    end
    if not c._graphics then
        c._graphics = drawingComponent._cacheEntry.graphics:clone()
        c._graphicsWidth = drawingComponent._cacheEntry.graphicsWidth
        c._graphicsHeight = drawingComponent._cacheEntry.graphicsHeight
        c._graphics:setDisplay('mesh', 1024)
        c._currPath = nil
        c._currSubpath = nil
        c._lastCornerX, c._lastCornerY = nil
    end

    -- Look for a single-finger drag and release
    local touchData = self:getTouchData()
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)

        -- Get body attributes
        local bodyWidth, bodyHeight = self.dependencies.Body:getSize(c.actorId)
        local bodyId, body = self.dependencies.Body:getBody(c.actorId)
        local bodyX, bodyY = body:getPosition()
        local bodyAngle = body:getAngle()
        local scaleX, scaleY = bodyWidth / c._graphicsWidth, bodyHeight / c._graphicsHeight

        -- Transform touch coordinates to graphics coordinates
        local x, y = body:getLocalPoint(touch.x, touch.y)
        x, y = x / scaleX, y / scaleY
        local prevX, prevY = body:getLocalPoint(touch.x - touch.dx, touch.y - touch.dy)
        prevX, prevY = prevX / scaleX, prevY / scaleY
        local dx, dy = x - prevX, y - prevY

        -- Non-released motion
        if not touch.released and (touch.dx ~= 0 or touch.dy ~= 0) then
            -- Create new subpath for this element if doesn't already exist
            if not c._currSubpath then
                c._currSubpath = tove.newSubpath()

                c._currPath = tove.newPath()
                c._currPath:addSubpath(c._currSubpath)
                c._graphics:addPath(c._currPath)

                c._currPath:setLineColor(unpack(self._lineColor))
                c._currPath:setLineWidth(math.max(2, self._lineWidth))
                c._currPath:setMiterLimit(1)

                c._currSubpath:moveTo(x - dx, y - dy)
            end

            local numPoints = c._currSubpath.points.count

            -- Always place if fewer than two points
            local place = numPoints < 12

            -- Place if at least 30 units from last point
            local lastPoint = c._currSubpath.points[numPoints]
            local dispX, dispY = x - lastPoint.x, y - lastPoint.y
            local dispSqLen = dispX * dispX + dispY * dispY 
            if dispSqLen >= 30 * 30 then
                place = true
            end

            -- Previous segment
            local lastCurve = c._currSubpath.points.count > 2 and c._currSubpath.curves[c._currSubpath.curves.count]
            local lastCurveDX, lastCurveDY
            if lastCurve then
                lastCurveDX, lastCurveDY = lastCurve.x - lastCurve.x0, lastCurve.y - lastCurve.y0
            end

            -- Not already placing and it's a corner? Place at corner
            local cornerX, cornerY
            if not place and lastCurve then
                local lastCurveLen = math.sqrt(lastCurveDX * lastCurveDX + lastCurveDY * lastCurveDY)
                local dot = (dx * lastCurveDX + dy * lastCurveDY) / (math.sqrt(dx * dx + dy * dy) * lastCurveLen)
                if dot < 0.55 then
                    cornerX, cornerY = x - dx, y - dy
                    if numPoints >= 32 and c._lastCornerX and c._lastCornerY then
                        local cornerDX, cornerDY = cornerX - c._lastCornerX, cornerY - c._lastCornerY
                        if cornerDX * cornerDX + cornerDY * cornerDY < 3 * 3 then
                            cornerX, cornerY = nil, nil
                        end
                    end
                    if cornerX and cornerY then
                        c._lastCornerX, c._lastCornerY = cornerX, cornerY
                    end
                end
            end

            if cornerX and cornerY then
                c._currSubpath:lineTo(cornerX, cornerY)
            elseif place then
                c._currSubpath:lineTo(x, y)
            end
        end

        -- Released
        if touch.released then
            if c._currPath and c._currSubpath then
                -- Final curve
                c._currSubpath:lineTo(x, y)

                -- Fill
                if self._fillEnabled then
                    c._currPath:setFillColor(unpack(self._fillColor))
                    c._currSubpath.isClosed = true
                else
                    c._currSubpath.isClosed = false
                end

                -- Curve smoothing
                local numCurves = c._currSubpath.curves.count
                if numCurves >= 3 then
                    for i = 1, numCurves do
                        local p0 = c._currSubpath.curves[i]
                        local p1 = c._currSubpath.curves[i == numCurves and 1 or (i + 1)]

                        local v1x, v1y = p0.x - p0.cp2x, p0.y - p0.cp2y
                        local v1l = math.sqrt(v1x * v1x + v1y * v1y)
                        v1x, v1y = v1x / v1l, v1y / v1l
                        local v2x, v2y = p1.cp1x - p1.x0, p1.cp1y - p1.y0
                        local v2l = math.sqrt(v2x * v2x + v2y * v2y)
                        v2x, v2y = v2x / v2l, v2y / v2l

                        if v1x * v2x + v1y * v2y > 0.3 then
                            local hx, hy = 0.5 * (v1x + v2x), 0.5 * (v1y + v2y)
                            local hl = math.sqrt(hx * hx + hy * hy)
                            hx, hy = hx / hl, hy / hl
                            p0.cp2x, p0.cp2y = p0.x - v1l * hx, p0.y - v1l * hy
                            p1.cp1x, p1.cp1y = p1.x0 + v2l * hx, p1.y0 + v2l * hy
                        end
                    end
                end
                
                -- Set to actual line width
                c._currPath:setLineWidth(self._lineWidth)

                -- Clean up
                c._graphics:clean(0.2)

                -- Reset state
                c._currSubpath = nil
                c._currPath = nil
                c._lastCornerX, c._lastCornerY = nil, nil
            end
        end
    end
end


-- Draw

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end
end


-- UI

--function DrawTool.handlers:uiSettings(closeSettings)
--end

