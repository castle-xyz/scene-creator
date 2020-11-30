local HANDLE_TOUCH_RADIUS = 30

local ScaleRotateTool = defineDrawSubtool {
    category = "collision_move",
    name = "scale-rotate",
}

function ScaleRotateTool.handlers:addSubtool()
    self._initialCoord = nil
end

function ScaleRotateTool.handlers:onSelected()
    if self:physicsBodyData():getNumShapes() > 0 then
        self:scaleRotateData().index = self:physicsBodyData():getNumShapes()
    else
        self:scaleRotateData().index = nil
    end
end

function ScaleRotateTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
        self._initialCoord = {
            x = touchData.touchX,
            y = touchData.touchY
        }

        if self:scaleRotateData().index then
            local handleTouchRadius = HANDLE_TOUCH_RADIUS * self:getPixelScale()
            local scaleRotateShape = self:physicsBodyData():getShapeAtIndex(self:scaleRotateData().index)
        
            local handles = self:physicsBodyData():getHandlesForShape(scaleRotateShape)
            for i = 1, #handles do
                local handle = handles[i]
                local distance = math.sqrt(math.pow(touchData.touchX - handle.x, 2.0) + math.pow(touchData.touchY - handle.y, 2.0))
                if distance < handleTouchRadius then
                    self:scaleRotateData().handle = handle

                    if scaleRotateShape.type == 'triangle' then
                        self:scaleRotateData().otherPoints = {}
                        for j = 1, #handles do
                            if j ~= i then
                                table.insert(self:scaleRotateData().otherPoints, {
                                    x = handles[j].x,
                                    y = handles[j].y,
                                })
                            end
                        end
                    end
                    break
                end
            end
        end

        -- only allow choosing a new shape if we didn't find a handle
        if self:scaleRotateData().handle == nil then
            local index = self:physicsBodyData():getShapeIdxAtPoint(self._initialCoord)

            if index then
                self:scaleRotateData().index = index
            end
        end
    end

    if self:scaleRotateData().index and self:scaleRotateData().handle then
        local otherCoord = {
            x = self:scaleRotateData().handle.oppositeX,
            y = self:scaleRotateData().handle.oppositeY,
        }

        local scaleRotateShape = self:physicsBodyData():getShapeAtIndex(self:scaleRotateData().index)
        local type = scaleRotateShape.type
        local shape

        if type == 'rectangle' then
            shape = self:physicsBodyData():getRectangleShape(otherCoord, touchData.roundedCoord)
        elseif type == 'circle' then
            local roundDx = floatUnit(self:scaleRotateData().handle.oppositeX - touchData.touchX)
            local roundDy = floatUnit(self:scaleRotateData().handle.oppositeY - touchData.touchY)

            shape = self:physicsBodyData():getCircleShape(otherCoord, touchData.roundedCoord, self:bind(self:drawData(), 'roundGlobalCoordinatesToGrid'), self:bind(self:drawData(), 'roundGlobalDistanceToGrid'), roundDx, roundDy)
        elseif type == 'triangle' then
            shape = self:physicsBodyData():getTriangleShape(touchData.roundedCoord, self:scaleRotateData().otherPoints[1], self:scaleRotateData().otherPoints[2])
        end

        if shape then
            self:physicsBodyData():updateShapeAtIdx(self:scaleRotateData().index, shape)
        end
    end

    if touchData.touch.released then
        if self:scaleRotateData().handle then
            self:saveDrawing("scale", component)
        end

        self._initialCoord = nil
        self:scaleRotateData().handle = nil
    end
end
