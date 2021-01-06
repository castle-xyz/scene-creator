require('tools.draw_data_frame')

DrawData = {}
local FILL_CANVAS_SIZE = 256
DRAW_LINE_WIDTH = 0.2
local DEBUG_FILL_IMAGE_SIZE = false

function DrawData:gridCellSize()
    return self.gridSize
end

function DrawData:globalToGridCoordinates(x, y)
    local gridX = x / self:gridCellSize()
    local gridY = y / self:gridCellSize()
    return gridX, gridY
end

function DrawData:gridToGlobalCoordinates(x, y)
    local globalX = x * self:gridCellSize()
    local globalY = y * self:gridCellSize()
    return globalX, globalY
end

function DrawData:roundGlobalDiffCoordinatesToGrid(x, y)
    local gridX, gridY = self:globalToGridCoordinates(x, y)

    gridX = math.floor(gridX + 0.5)
    gridY = math.floor(gridY + 0.5)

    return self:gridToGlobalCoordinates(gridX, gridY)
end

function DrawData:roundGlobalCoordinatesToGrid(x, y)
    local gridX, gridY = self:globalToGridCoordinates(x, y)

    gridX = math.floor(gridX + 0.5)
    gridY = math.floor(gridY + 0.5)

    return self:clampGlobalCoordinates(self:gridToGlobalCoordinates(gridX, gridY))
end

function DrawData:clampGlobalCoordinates(x, y)
    if x < -DRAW_MAX_SIZE then
        x = -DRAW_MAX_SIZE
    elseif x > DRAW_MAX_SIZE then
        x = DRAW_MAX_SIZE
    end

    if y < -DRAW_MAX_SIZE then
        y = -DRAW_MAX_SIZE
    elseif y > DRAW_MAX_SIZE then
        y = DRAW_MAX_SIZE
    end

    return x, y
end

function DrawData:roundGlobalDistanceToGrid(d)
    local x, y = self:roundGlobalCoordinatesToGrid(d, 0)
    return x
end

local function makeSubpathsFromSubpathData(pathData)
    for i = 1, #pathData.subpathDataList do
        local subpathData = pathData.subpathDataList[i]
        local subpath = tove.newSubpath()
        pathData.tovePath:addSubpath(subpath)

        if subpathData.type == 'line' then
            subpath:moveTo(subpathData.p1.x, subpathData.p1.y)
            subpath:lineTo(subpathData.p2.x, subpathData.p2.y)
        elseif subpathData.type == 'arc' then
            subpath:arc(subpathData.center.x, subpathData.center.y, subpathData.radius, subpathData.startAngle * 180 / math.pi, subpathData.endAngle * 180 / math.pi)
        end
    end
end

local function addLineSubpathData(pathData, p1x, p1y, p2x, p2y)
    table.insert(pathData.subpathDataList, {
        type = 'line',
        p1 = {
            x = p1x,
            y = p1y
        },
        p2 = {
            x = p2x,
            y = p2y
        }
    })
end

local function addCircleSubpathData(pathData, centerX, centerY, radius, startAngle, endAngle)
    table.insert(pathData.subpathDataList, {
        type = 'arc',
        center = {
            x = centerX,
            y = centerY
        },
        radius = radius,
        startAngle = startAngle,
        endAngle = endAngle
    })
end

function DrawData:drawEndOfArc(pathData, p1x, p1y, p2x, p2y)
    if p1x == p2x and p1y == p2y then
        return
    end

    -- TODO: fix
    --p1x, p1y = self:roundGlobalCoordinatesToGrid(p1x, p1y)
    --p2x, p2y = self:roundGlobalCoordinatesToGrid(p2x, p2y)

    addLineSubpathData(pathData, p1x, p1y, p2x, p2y)
end

function DrawData:addSubpathDataForPoints(pathData, p1, p2)
    local style = pathData.style
    local bendPoint = pathData.bendPoint

    if bendPoint then
        local midpointP1P2 = {
            x = (p1.x + p2.x) / 2.0,
            y = (p1.y + p2.y) / 2.0,
        }
        local radiusP1P2 = math.sqrt(math.pow(p1.x - p2.x, 2.0) + math.pow(p1.y - p2.y, 2.0)) / 2.0
        local distFromMidpointToBendPoint = math.sqrt(math.pow(midpointP1P2.x - bendPoint.x, 2.0) + math.pow(midpointP1P2.y - bendPoint.y, 2.0))
    
        if distFromMidpointToBendPoint > radiusP1P2 then
            local scaleAmt = radiusP1P2 / distFromMidpointToBendPoint

            bendPoint = {
                x = (bendPoint.x - midpointP1P2.x) * scaleAmt + midpointP1P2.x,
                y = (bendPoint.y - midpointP1P2.y) * scaleAmt + midpointP1P2.y,
            }
        end

        local p1NormalVector = {
            dx = -(bendPoint.y - p1.y),
            dy = bendPoint.x - p1.x
        }
        local p2NormalVector = {
            dx = -(bendPoint.y - p2.y),
            dy = bendPoint.x - p2.x
        }
        local p1Midpoint = {
            x = (bendPoint.x + p1.x) / 2.0,
            y = (bendPoint.y + p1.y) / 2.0,
        }
        local p2Midpoint = {
            x = (bendPoint.x + p2.x) / 2.0,
            y = (bendPoint.y + p2.y) / 2.0,
        }
    
        local circleCenterX, circleCenterY = rayRayIntersection(
            p1Midpoint.x, p1Midpoint.y,
            p1Midpoint.x + p1NormalVector.dx, p1Midpoint.y + p1NormalVector.dy,
            p2Midpoint.x, p2Midpoint.y,
            p2Midpoint.x + p2NormalVector.dx, p2Midpoint.y + p2NormalVector.dy
        )
    
        if circleCenterX == nil then
            addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
            return
        end
    
        local radius = math.sqrt(math.pow(p1.y - circleCenterY, 2.0) + math.pow(p1.x - circleCenterX, 2.0))
    
        if radius > 50 then
            addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
            return
        end
    
        local angle1 = math.atan2(p1.y - circleCenterY, p1.x - circleCenterX)
        local angleBendPoint = math.atan2(bendPoint.y - circleCenterY, bendPoint.x - circleCenterX)
        local angle2 = math.atan2(p2.y - circleCenterY, p2.x - circleCenterX)
        local startAngle, endAngle
    
        if isAngleBetween(angleBendPoint, angle1, angle2) then
            startAngle = angle1
            endAngle = angle2
        else
            startAngle = angle2
            endAngle = angle1
        end

        addCircleSubpathData(pathData, circleCenterX, circleCenterY, radius, startAngle, endAngle)

        --[[
        for i = 1, pathData.tovePath.subpaths.count do
            local subpath = pathData.tovePath.subpaths[i]
            local numPoints, pointsPtr = subpath:getPoints()

            for j = 0, numPoints - 1, 3 do
                local testPoint = {
                    x = pointsPtr[2 * j + 0],
                    y = pointsPtr[2 * j + 1]
                }

                if not self:isPointInBounds(testPoint) then
                    pathData.style = 1
                    local tempBendPoint = pathData.bendPoint
                    pathData.bendPoint = nil
                    pathData.tovePath = nil
                    self:updatePathDataRendering(pathData)
                    pathData.bendPoint = tempBendPoint
                    return
                end
            end
        end]]--
    else
        if style == 1 then
            addLineSubpathData(pathData, p1.x, p1.y, p2.x, p2.y)
            return
        end

        local isOver = style == 2

        if p1.x > p2.x or (p1.x == p2.x and p1.y > p2.y) then
            local t = p1
            p1 = p2
            p2 = t
        end

        local radius = math.min(math.abs(p2.x - p1.x), math.abs(p2.y - p1.y))
        local xIsLonger = math.abs(p2.x - p1.x) > math.abs(p2.y - p1.y)

        if radius == 0 then
            radius = math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0)) / 2.0
            local circleCenter = {
                x = (p2.x + p1.x) / 2.0,
                y = (p2.y + p1.y) / 2.0,
            }

            local startAngle

            if p1.x == p2.x then
                if isOver then
                    startAngle = math.pi * 3.0 / 2.0
                else
                    startAngle = math.pi / 2.0
                end
            else
                if isOver then
                    startAngle = math.pi
                else
                    startAngle = 0.0
                end
            end

            local testPoint = {
                x = circleCenter.x + math.cos(startAngle + math.pi / 2.0) * radius,
                y = circleCenter.y + math.sin(startAngle + math.pi / 2.0) * radius,
            }

            if not self:isPointInBounds(testPoint) then
                pathData.style = pathData.style + 1
                if pathData.style > 3 then
                    pathData.style = 1
                end

                pathData.tovePath = nil
                self:updatePathDataRendering(pathData)
                return 
            end

            addCircleSubpathData(pathData, circleCenter.x, circleCenter.y, radius, startAngle, startAngle + math.pi / 2.0)
            addCircleSubpathData(pathData, circleCenter.x, circleCenter.y, radius, startAngle + math.pi / 2.0, startAngle + math.pi)
        else
            local circleCenter = {}
            local startAngle

            if p1.y > p2.y then
                startAngle = 0.0
                if isOver then
                    startAngle = startAngle + math.pi
                end

                if xIsLonger then
                    --
                    --             .
                    -- .
                    --
                    if isOver then
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y + radius

                        self:drawEndOfArc(pathData, p1.x + radius, p2.y, p2.x, p2.y)
                    else
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y - radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p2.x - radius, p1.y)
                    end
                else
                    --
                    --   .
                    --
                    --
                    --
                    -- .
                    --
                    if isOver then
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y + radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p1.x, p2.y + radius)
                    else
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y - radius

                        self:drawEndOfArc(pathData, p2.x, p1.y - radius, p2.x, p2.y)
                    end
                end
            else
                startAngle = math.pi / 2.0
                if isOver then
                    startAngle = startAngle + math.pi
                end

                if xIsLonger then
                    --
                    -- .
                    --             .
                    --
                    if isOver then
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y + radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p2.x - radius, p1.y)
                    else
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y - radius

                        self:drawEndOfArc(pathData, p1.x + radius, p2.y, p2.x, p2.y)
                    end
                else
                    --
                    -- .
                    --
                    --
                    --
                    --   .
                    --
                    if isOver then
                        circleCenter.x = p2.x - radius
                        circleCenter.y = p1.y + radius

                        self:drawEndOfArc(pathData, p2.x, p1.y + radius, p2.x, p2.y)
                    else
                        circleCenter.x = p1.x + radius
                        circleCenter.y = p2.y - radius

                        self:drawEndOfArc(pathData, p1.x, p1.y, p1.x, p2.y - radius)
                    end
                end
            end

            addCircleSubpathData(pathData, circleCenter.x, circleCenter.y, radius, startAngle, startAngle + math.pi / 2.0)
        end
    end
end

function DrawData:updatePathDataRendering(pathData)
    if pathData.tovePath and pathData.tovePath ~= nil then
        return
    end

    local path = tove.newPath()
    if pathData.color then
        path:setLineColor(pathData.color[1], pathData.color[2], pathData.color[3], 1.0)
    else
        path:setLineColor(self.lineColor[1], self.lineColor[2], self.lineColor[3], 1.0)
    end
    path:setLineWidth(DRAW_LINE_WIDTH)
    path:setMiterLimit(1)
    path:setLineJoin("round")
    pathData.tovePath = path

    pathData.subpathDataList = {}

    if pathData.isTransparent then
        return
    end

    for i = 1, #pathData.points - 1 do
        local p1 = pathData.points[i]
        local p2 = pathData.points[i + 1]

        self:addSubpathDataForPoints(pathData, p1, p2)
    end

    makeSubpathsFromSubpathData(pathData)
end

function DrawData:selectedLayer()
    return self:layerForId(self.selectedLayerId)
end

function DrawData:getRealFrameIndexForLayerId(layerId, frame)
    local layer = self:layerForId(layerId)

    while frame > 0 do
        if not layer.frames[frame].isLinked then
            return frame
        end

        frame = frame - 1
    end

    return frame
end

function DrawData:layerForId(id)
    for i = 1, #self.layers do
        if self.layers[i].id == id then
            return self.layers[i]
        end
    end

    return nil
end

function DrawData:currentLayerFrame()
    local realFrame = self:getRealFrameIndexForLayerId(self:selectedLayer().id, self.selectedFrame)
    return self:selectedLayer().frames[realFrame]
end

function DrawData:currentPathDataList()
    return self:currentLayerFrame().pathDataList
end

function DrawData:new(obj)
    if not obj or obj == nil then
        obj = {
            version = 2
        }
    end

    local newObj = {
        _graphics = nil,
        _graphicsNeedsReset = true,
        pathDataList = obj.pathDataList or {},
        color = obj.color or obj.fillColor or {hexStringToRgb("f9a31b")},
        lineColor = obj.lineColor or {hexStringToRgb("f9a31b")},
        gridSize = obj.gridSize or 0.71428571428571,
        scale = obj.scale or DRAW_DATA_SCALE,
        pathsCanvas = nil,
        fillImageData = nil,
        fillImage = nil,
        fillImageBounds = obj.fillImageBounds or {
            maxX = 0,
            maxY = 0,
            minX = 0,
            minY = 0
        },
        fillCanvasSize = obj.fillCanvasSize or FILL_CANVAS_SIZE,
        fillPng = obj.fillPng or nil,
        version = obj.version or nil,
        fillPixelsPerUnit = obj.fillPixelsPerUnit or 25.6,
        bounds = obj.bounds or nil,
        framesBounds = obj.framesBounds or {},
        layers = obj.layers or {},
        numTotalLayers = obj.numTotalLayers or 1,
        selectedLayerId = obj.selectedLayerId or nil,
        selectedFrame = obj.selectedFrame or 1,
        _layerDataChanged = true,
        _layerData = nil,
    }

    for l = 1, #newObj.layers do
        for f = 1, #newObj.layers[l].frames do
            local frame = newObj.layers[l].frames[f]
            frame.pathsCanvas = nil
            frame.fillImageData = nil
            frame.fillImage = nil
        end
    end

    newObj = util.deepCopyTable(newObj)

    setmetatable(newObj, self)
    self.__index = self

    newObj:migrateV1ToV2()
    newObj:migrateV2ToV3()

    newObj:clearGraphics()

    setmetatable(newObj, self)
    self.__index = self

    for l = 1, #newObj.layers do
        local layer = newObj.layers[l]
        if layer.isVisible == nil then
            layer.isVisible = true
        end
        if not layer.id then
            layer.id = 'layer' .. l
        end

        for f = 1, #newObj.layers[l].frames do
            local frame = newObj.layers[l].frames[f]

            setmetatable(frame, {__index = DrawDataFrame})
            frame.parent = function()
                return newObj
            end

            frame:deserializePathDataList()
        end
    end

    if newObj.selectedLayerId == nil then
        newObj.selectedLayerId = newObj.layers[1].id
    end
    
    newObj:graphics()

    for l = 1, #newObj.layers do
        for f = 1, #newObj.layers[l].frames do
            local frame = newObj.layers[l].frames[f]
            frame:deserializeFillAndPreview()
        end
    end

    return newObj
end

function DrawData:migrateV1ToV2()
    if self.version ~= nil and self.version >= 2 then
        return
    end

    self.version = 2
    self.gridSize = self.scale / (self.gridSize - 1)
    self.bounds = {
        minX = -self.scale / 2.0,
        minY = -self.scale / 2.0,
        maxX = self.scale / 2.0,
        maxY = self.scale / 2.0,
    }

    self.fillImageBounds = {
        minX = self.fillPixelsPerUnit * -self.scale / 2.0,
        minY = self.fillPixelsPerUnit * -self.scale / 2.0,
        maxX = self.fillPixelsPerUnit * self.scale / 2.0,
        maxY = self.fillPixelsPerUnit * self.scale / 2.0,
    }

    for i = 1, #self.pathDataList do
        local pathData = self.pathDataList[i]

        for j = 1, #pathData.points do
            pathData.points[j].x = pathData.points[j].x - self.scale / 2.0
            pathData.points[j].y = pathData.points[j].y - self.scale / 2.0
        end

        if pathData.bendPoint then
            pathData.bendPoint.x = pathData.bendPoint.x - self.scale / 2.0
            pathData.bendPoint.y = pathData.bendPoint.y - self.scale / 2.0
        end
    end

    local boundsPathData1 = {}
    boundsPathData1.points = {{
        x = -self.scale / 2.0,
        y = -self.scale / 2.0,
    }, {
        x = -self.scale / 2.0,
        y = -self.scale / 2.0,
    }}
    boundsPathData1.style = -1
    boundsPathData1.isFreehand = true
    boundsPathData1.isTransparent = true

    local boundsPathData2 = {}
    boundsPathData2.points = {{
        x = self.scale / 2.0,
        y = self.scale / 2.0,
    }, {
        x = self.scale / 2.0,
        y = self.scale / 2.0,
    }}
    boundsPathData2.style = -1
    boundsPathData2.isFreehand = true
    boundsPathData2.isTransparent = true

    table.insert(self.pathDataList, boundsPathData1)
    table.insert(self.pathDataList, boundsPathData2)
end

function DrawData:migrateV2ToV3()
    if self.version >= 3 and #self.layers > 0 then
        return
    end

    self.version = 3

    self.frames = 1
    self.layers = {{
        title = "Layer 1",
        frames = {util.deepCopyTable({
            pathDataList = self.pathDataList,
            pathsCanvas = self.pathsCanvas,
            fillImageData = self.fillImageData,
            fillImage = self.fillImage,
            fillImageBounds = self.fillImageBounds,
            fillCanvasSize = self.fillCanvasSize,
            fillPng = self.fillPng,
        })}
    }}

    self.pathDataList = nil
    self.pathsCanvas = nil
    self.fillImageData = nil
    self.fillImage = nil
    self.fillImageBounds = nil
    self.fillCanvasSize = nil
    self.fillPng = nil
    self.framesBounds = {self.bounds}
    self.bounds = nil
end

function DrawData:getLayerData()
    if self._layerDataChanged then
        self._layerDataChanged = false

        local data = {
            selectedLayerId = self.selectedLayerId,
            selectedFrame = self.selectedFrame,
            layers = {}
        }

        for l = 1, #self.layers do
            local layer = self.layers[l]
            local layerData = {
                title = layer.title,
                id = layer.id,
                order = l,
                isVisible = layer.isVisible,
                frames = {}
            }

            for f = 1, #layer.frames do
                local frame = layer.frames[f]
                local frameData = {
                    order = f,
                    isLinked = frame.isLinked,
                    base64Png = frame.base64Png,
                }
                layerData.frames['frame' .. f] = frameData
            end

            data.layers[layer.id] = layerData
        end

        self._layerData = data
    end

    return self._layerData
end

function DrawData:updateBounds()
    self.framesBounds[self.selectedFrame] = nil
end

function DrawData:getBounds(frame)
    if self.framesBounds[frame] then
        return self.framesBounds[frame]
    end

    local bounds = nil
    for l = 1, #self.layers do
        local layer = self.layers[l]
        local realFrame = self:getRealFrameIndexForLayerId(layer.id, frame)
        local frame = layer.frames[realFrame]
        bounds = frame:getPathDataBounds(bounds)
    end

    self.framesBounds[frame] = bounds
    return bounds
end

function floatArrayEquals(a1, a2)
    if a1 == nil and a2 == nil then
        return true
    end

    if a1 == nil or a2 == nil then
        return false
    end

    if #a1 ~= #a2 then
        return false
    end

    for i = 1, #a1 do
        if not floatEquals(a1[i], a2[i]) then
            return false
        end
    end

    return true
end

local function coordinatesEqual(c1, c2)
    if not floatEquals(c1.x, c2.x) then
        return false
    end

    if not floatEquals(c1.y, c2.y) then
        return false
    end

    return true
end

function DrawData:arePathDatasFloodFillable(pd1, pd2)
    if not coordinatesEqual(pd1.points[#pd1.points], pd2.points[1]) then
        return false
    end

    if not floatArrayEquals(pd1.color, pd2.color) then
        return false
    end

    return true
end

function DrawData:saveEditorSettings()
    local result = {
        selectedLayerId = self.selectedLayerId,
        selectedFrame = self.selectedFrame,
    }

    return result
end

function DrawData:applyEditorSettings(editorSettings)
    if not editorSettings then
        return
    end

    self.selectedLayerId = editorSettings.selectedLayerId
    self.selectedFrame = editorSettings.selectedFrame

    local foundSelectedLayer = false

    for l = 1, #self.layers do
        if self.layers[l].id == self.selectedLayerId then
            foundSelectedLayer = true
        end
    end

    if not foundSelectedLayer then
        self.selectedLayerId = self.layers[1].id
    end

    if self.selectedFrame > #self.layers[1].frames then
        self.selectedFrame = #self.layers[1].frames
    end
end

function DrawData:serialize()
    for i = 1, self:getNumFrames() do
        self:getBounds(i)
    end

    local data = {
        pathDataList = {},
        color = self.color,
        lineColor = self.lineColor,
        gridSize = self.gridSize,
        scale = self.scale,
        version = self.version,
        fillPixelsPerUnit = self.fillPixelsPerUnit,
        numTotalLayers = self.numTotalLayers,
        layers = {},
        framesBounds = self.framesBounds,
    }

    for l = 1, #self.layers do
        local layerData = {
            title = self.layers[l].title,
            id = self.layers[l].id,
            isVisible = self.layers[l].isVisible,
            frames = {},
        }

        for f = 1, #self.layers[l].frames do
            local frame = self.layers[l].frames[f]
            table.insert(layerData.frames, frame:serialize())
        end

        table.insert(data.layers, layerData)
    end

    return data
end

function DrawData:touchLayerData()
    self._layerDataChanged = true
end

function DrawData:updateFramePreview()
    self:touchLayerData()
    self:currentLayerFrame().base64Png = self:currentLayerFrame():renderPreviewPng()
end

function DrawData:selectLayer(layerId)
    self.selectedLayerId = layerId
    self:touchLayerData()
end

function DrawData:selectFrame(frame)
    self.selectedFrame = frame
    self:touchLayerData()
end

function DrawData:deleteLayer(layerId)
    local layerIndex = 1
    for i = 1, #self.layers do
        if self.layers[i].id == layerId then
            layerIndex = i
        end
    end

    table.remove(self.layers, layerIndex)

    if #self.layers == 0 then
        self:addLayer()
        return
    end

    if self.selectedLayerId == layerId then
        self.selectedLayerId = self.layers[1].id

        if layerIndex <= #self.layers then
            self.selectedLayerId = self.layers[layerIndex].id
        elseif layerIndex > 1 then
            self.selectedLayerId = self.layers[layerIndex - 1].id
        end
    end

    self:touchLayerData()
end

function DrawData:deleteFrame(frame)
    self.framesBounds = {}

    for i = 1, #self.layers do
        table.remove(self.layers[i].frames, frame)
    end

    if #self.layers[1].frames == 0 then
        self:addFrame()
        return
    end

    if self.selectedFrame > #self.layers[1].frames then
        self.selectedFrame = #self.layers[1].frames
    end

    self:touchLayerData()
end

function DrawData:reorderLayers(layerIds)
    local layerIdToLayer = {}

    for i = 1, #self.layers do
        layerIdToLayer[self.layers[i].id] = self.layers[i]
    end

    self.layers = {}

    for i = #layerIds, 1, -1  do
        table.insert(self.layers, layerIdToLayer[layerIds[i]])
    end

    self:touchLayerData()
end

function DrawData:setLayerIsVisible(layerId, isVisible)
    self:layerForId(layerId).isVisible = isVisible
    self:touchLayerData()
end

function DrawData:_newFrame(isLinked)
    local newFrame = {
        isLinked = isLinked,
        pathDataList = {},
        fillImageBounds = {
            maxX = 0,
            maxY = 0,
            minX = 0,
            minY = 0
        },
    }

    setmetatable(newFrame, {__index = DrawDataFrame})
    newFrame.parent = function()
        return self
    end

    return newFrame
end

function DrawData:setCellLinked(layerId, frame, isLinked)
    if frame < 2 then
        return
    end

    if isLinked then
        self:layerForId(layerId).frames[frame] = self:_newFrame(isLinked)
    else
        local realFrame = self:getRealFrameIndexForLayerId(layerId, frame)
        local oldFrame = self:layerForId(layerId).frames[realFrame]
        local newFrame = util.deepCopyTable(oldFrame:serialize())

        setmetatable(newFrame, {__index = DrawDataFrame})
        newFrame.parent = function()
            return self
        end

        newFrame:deserializePathDataList()
        newFrame:deserializeFillAndPreview()

        self:layerForId(layerId).frames[frame] = newFrame
    end

    self:touchLayerData()
end

function DrawData:addLayer()
    self.numTotalLayers = self.numTotalLayers + 1

    local newLayer = {
        title = 'Layer ' .. self.numTotalLayers,
        id = 'layer' .. self.numTotalLayers,
        isVisible = true,
        frames = {},
    }

    local frameCount = 1
    if #self.layers > 0 then
        frameCount = #self.layers[1].frames
    end

    for i = 1, frameCount do
        table.insert(newLayer.frames, self:_newFrame(i > 1))
    end

    table.insert(self.layers, newLayer)
    self.selectedLayerId = newLayer.id
    self:touchLayerData()
end

function DrawData:addFrame()
    local isLinked = #self.layers[1].frames > 0

    for l = 1, #self.layers do
        table.insert(self.layers[l].frames, self:_newFrame(isLinked))
    end

    self.selectedFrame = #self.layers[1].frames
    self:touchLayerData()
end

function DrawData:newAnimationState()
    return {
        animationFrameTime = 0.0,
    }
end

function DrawData:getNumFrames()
    return #self.layers[1].frames
end

function DrawData:modFrameIndex(value)
    value = math.floor(value + 0.5)
    local numFrames = self:getNumFrames()

    while value > numFrames do
        value = value - numFrames
    end

    while value < 1 do
        value = value + numFrames
    end

    return value
end

function DrawData:runAnimation(animationState, componentProperties, dt, fireTrigger)
    if not animationState or not componentProperties then
        return
    end

    if not componentProperties.playing then
        return
    end

    animationState.animationFrameTime = animationState.animationFrameTime + dt
    local secondsPerFrame = 1.0 / componentProperties.framesPerSecond

    if animationState.animationFrameTime > math.abs(secondsPerFrame) then
        animationState.animationFrameTime = animationState.animationFrameTime - math.abs(secondsPerFrame)

        local firstFrame = componentProperties.loopStartFrame
        if not firstFrame or firstFrame < 1 or firstFrame > self:getNumFrames() then
            firstFrame = 1
        end

        local lastFrame = componentProperties.loopEndFrame
        if not lastFrame or lastFrame < 1 or lastFrame > self:getNumFrames() then
            lastFrame = self:getNumFrames()
        end

        local currentFrame = self:modFrameIndex(componentProperties.currentFrame)

        if secondsPerFrame > 0.0 then
            if floatEquals(currentFrame, lastFrame) then
                if componentProperties.loop then
                    componentProperties.currentFrame = firstFrame

                    if fireTrigger then
                        fireTrigger("animation loop")
                    end
                else
                    componentProperties.playing = false
                    animationState.animationFrameTime = 0.0

                    if fireTrigger then
                        fireTrigger("animation end")
                    end
                end
            else
                componentProperties.currentFrame = currentFrame + 1
            end
        else
            if floatEquals(currentFrame, firstFrame) then
                if componentProperties.loop then
                    componentProperties.currentFrame = lastFrame

                    if fireTrigger then
                        fireTrigger("animation loop")
                    end
                else
                    componentProperties.playing = false
                    animationState.animationFrameTime = 0.0

                    if fireTrigger then
                        fireTrigger("animation end")
                    end
                end
            else
                componentProperties.currentFrame = currentFrame - 1
            end
        end
    end
end

function DrawData:stepBackward()
    self.selectedFrame = self.selectedFrame - 1

    if self.selectedFrame < 1 then
        self.selectedFrame = #self.layers[1].frames
    end

    self:touchLayerData()
end

function DrawData:stepForward()
    self.selectedFrame = self.selectedFrame + 1

    if self.selectedFrame > #self.layers[1].frames then
        self.selectedFrame = 1
    end

    self:touchLayerData()
end

function DrawData:addFrameAtPosition(position)
    self.framesBounds = {}

    local isLinked = #self.layers[1].frames > 0

    for l = 1, #self.layers do
        table.insert(self.layers[l].frames, position + 1, self:_newFrame(isLinked))
    end

    self.selectedFrame = #self.layers[1].frames
    self:touchLayerData()
end

function DrawData:clearFrame()
    local realFrame = self:getRealFrameIndexForLayerId(self:selectedLayer().id, self.selectedFrame)
    self:selectedLayer().frames[realFrame] = self:_newFrame(false)
end

function DrawData:graphics()
    return self:currentLayerFrame():graphics()
end

function DrawData:preload()
    self:graphics()
end

function DrawData:render(componentProperties)
    local frameIdx = self.selectedFrame

    if componentProperties and componentProperties.currentFrame then
        frameIdx = self:modFrameIndex(componentProperties.currentFrame)
    end

    for l = 1, #self.layers do
        if self.layers[l].isVisible then
            local realFrame = self:getRealFrameIndexForLayerId(self.layers[l].id, frameIdx)
            local frame = self.layers[l].frames[realFrame]
            frame:renderFill()
            frame:graphics():draw()
        end
    end
end

function DrawData:renderOnionSkinning()
    local frame = self.selectedFrame - 1
    if frame < 1 then
        frame = #self.layers[1].frames
    end

    for l = 1, #self.layers do
        local layer = self.layers[l]
        if layer.isVisible then
            local realFrame = self:getRealFrameIndexForLayerId(layer.id, frame)
            local frame = layer.frames[realFrame]
            frame:renderFill()
            frame:graphics():draw()
        end
    end
end

function DrawData:renderForTool(animationState, tempTranslateX, tempTranslateY, tempGraphics)
    local frameIdx = self.selectedFrame

    if animationState then
        frameIdx = animationState.currentFrame
    end

    for l = 1, #self.layers do
        local layer = self.layers[l]
        local realFrame = self:getRealFrameIndexForLayerId(layer.id, frameIdx)
        local frame = self.layers[l].frames[realFrame]

        if layer.isVisible then
            if layer.id == self.selectedLayerId then
                love.graphics.push()
                love.graphics.translate(tempTranslateX, tempTranslateY)
                frame:renderFill()
                frame:graphics():draw()
                love.graphics.pop()

                if tempGraphics ~= nil then
                    tempGraphics:draw()
                end
            else
                frame:renderFill()
                frame:graphics():draw()
            end
        end
    end
end

function DrawData:renderPreviewPngForFrames(size)
    local results = {
        numFrames = #self.layers[1].frames,
    }

    for i = 1, #self.layers[1].frames do
        results['frame' .. (i - 1)] = self:renderPreviewPng(i, size)
    end

    return results
end

function DrawData:renderPreviewPng(frame, size)
    if not size then
        size = 256
    end

    local previewCanvas = love.graphics.newCanvas(
        size,
        size,
        {
            dpiscale = 1,
            msaa = 4
        }
    )

    previewCanvas:renderTo(
        function()
            local pathBounds = self:getBounds(frame)

            local width = pathBounds.maxX - pathBounds.minX
            local height = pathBounds.maxY - pathBounds.minY

            local maxDimension = width
            if height > maxDimension then
                maxDimension = height
            end

            local widthPadding = (maxDimension - width) / 2.0
            local heightPadding = (maxDimension - height) / 2.0

            local padding = maxDimension * 0.025

            love.graphics.push("all")

            love.graphics.origin()
            love.graphics.scale(size / (maxDimension * 1.05))
            love.graphics.translate(padding - pathBounds.minX + widthPadding, padding - pathBounds.minY + heightPadding)

            love.graphics.clear(0.0, 0.0, 0.0, 0.0)
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
            self:render({
                currentFrame = frame,
            })

            love.graphics.pop()
        end
    )

    local fileData = previewCanvas:newImageData():encode("png")
    return love.data.encode("string", "base64", fileData:getString())
end

function DrawData:clearGraphics()
    for l = 1, #self.layers do
        for f = 1, #self.layers[l].frames do
            local frame = self.layers[l].frames[f]

            frame._graphics = nil
            frame._graphicsNeedsReset = true

            for i = 1, #frame.pathDataList do
                frame.pathDataList[i].tovePath = nil
                frame.pathDataList[i].subpathDataList = nil
            end
        end
    end
end

function DrawData:updateColor(r, g, b)
    if r == self.color[1] and g == self.color[2] and b == self.color[3] then
        return false
    end

    self.color[1] = r
    self.color[2] = g
    self.color[3] = b

    return true
end

function DrawData:isPointInBounds(point)
    return point.x >= -DRAW_MAX_SIZE and point.x <= DRAW_MAX_SIZE and point.y >= -DRAW_MAX_SIZE and point.y <= DRAW_MAX_SIZE
end

function DrawData:_pointsToPaths(points)
    local paths = {}

    for i = 1, #points, 2 do
        local nextI = i + 2
        if nextI > #points then
            nextI = nextI - #points
        end

        table.insert(paths, {
            points = {
                {
                    x = points[i],
                    y = points[i + 1],
                },
                {
                    x = points[nextI],
                    y = points[nextI + 1],
                },
            },
            style = 1,
        })
    end

    return paths
end

function DrawData:getRectangleShape(p1, p2)
    if self:isPointInBounds(p1) and self:isPointInBounds(p2) and not floatEquals(p1.x, p2.x) and not floatEquals(p1.y, p2.y) then
        return self:_pointsToPaths({
            p1.x, p1.y,
            p1.x, p2.y,
            p2.x, p2.y,
            p2.x, p1.y,
        })
    else
        return nil
    end
end

function DrawData:getTriangleShape(p1, p2, p3)
    if not p3 then
        p3 = {
            x = p1.x,
            y = p2.y,
        }
    end

    local isColinear = math.abs((p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y)) < 0.01

    if self:isPointInBounds(p1) and self:isPointInBounds(p2) and self:isPointInBounds(p3) and isColinear == false then
        return self:_pointsToPaths({
            p1.x, p1.y,
            p2.x, p2.y,
            p3.x, p3.y,
        })
    else
        return nil
    end
end

function DrawData:getCircleShape(p1, p2, roundFn, roundDistFn, roundDx, roundDy)
    local shape = {
        x = (p1.x + p2.x) / 2.0,
        y = (p1.y + p2.y) / 2.0,
        radius = math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0)) / 2.0
    }

    if not roundDx then
        roundDx = -1
    end
    if not roundDy then
        roundDy = 0
    end

    local leftX = shape.x + roundDx * shape.radius
    local leftY = shape.y + roundDy * shape.radius

    leftX, leftY = roundFn(leftX, leftY)

    shape.radius = roundDistFn(shape.radius)
    shape.x = leftX - roundDx * shape.radius
    shape.y = leftY - roundDy * shape.radius

    local topPoint = {
        x = shape.x,
        y = shape.y - shape.radius,
    }
    local bottomPoint = {
        x = shape.x,
        y = shape.y + shape.radius,
    }
    local rightPoint = {
        x = shape.x + shape.radius,
        y = shape.y,
    }
    local leftPoint = {
        x = shape.x - shape.radius,
        y = shape.y,
    }

    if self:isPointInBounds(topPoint) and self:isPointInBounds(bottomPoint) and self:isPointInBounds(leftPoint) and self:isPointInBounds(rightPoint) and shape.radius > 0 then
        return {
            {
                points = {topPoint, rightPoint},
                style = 2,
            },
            {
                points = {rightPoint, bottomPoint},
                style = 3,
            },
            {
                points = {bottomPoint, leftPoint},
                style = 3,
            },
            {
                points = {leftPoint, topPoint},
                style = 2,
            },
        }
    else
        return nil
    end
end
