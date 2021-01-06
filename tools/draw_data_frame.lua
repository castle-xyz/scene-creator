DrawDataFrame = {}

function DrawDataFrame:deserializePathDataList()
    local newPathDataList = {}
    for i = 1, #self.pathDataList do
        local pathData = self.pathDataList[i]
        if #pathData.points > 2 then
            local pathData = util.deepCopyTable(pathData)
            pathData.subpathDataList = nil
            pathData.tovePath = nil

            for j = 1, #pathData.points - 1 do
                local newPathData = util.deepCopyTable(pathData)
                newPathData.points = util.deepCopyTable({pathData.points[j], pathData.points[j + 1]})

                table.insert(newPathDataList, newPathData)
            end
        else
            table.insert(newPathDataList, pathData)
        end
    end

    self.pathDataList = newPathDataList
end

function DrawDataFrame:deserializeFillAndPreview()
    if self.fillPng then
        local fileDataString = love.data.decode("string", "base64", self.fillPng)
        local fileData = love.filesystem.newFileData(fileDataString, "fill.png")
        self.fillImageData = love.image.newImageData(fileData)
    end

    self.base64Png = self:renderPreviewPng()
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

function DrawDataFrame:arePathDatasMergable(pd1, pd2)
    if not coordinatesEqual(pd1.points[#pd1.points], pd2.points[1]) then
        return false
    end

    if pd1.style ~= pd2.style then
        return false
    end

    if not floatArrayEquals(pd1.bendPoint, pd2.bendPoint) then
        return false
    end

    if pd1.isFreehand ~= pd2.isFreehand then
        return false
    end

    if not floatArrayEquals(pd1.color, pd2.color) then
        return false
    end

    return true
end

local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function roundFloatArray(a)
    if a == nil then
        return a
    end

    for i = 1, #a do
        a[i] = round(a[i], 4)
    end

    return a
end

function DrawDataFrame:serialize()
    local frameData = {
        isLinked = self.isLinked,
        pathDataList = {},
        fillImageBounds = self.fillImageBounds,
        fillCanvasSize = self.fillCanvasSize,
    }

    local lastSerializedPathData = nil
    for i = 1, #self.pathDataList do
        local pathData = self.pathDataList[i]

        local serializedPathData = {
            points = util.deepCopyTable(pathData.points),
            style = pathData.style,
            bendPoint = roundFloatArray(pathData.bendPoint),
            isFreehand = pathData.isFreehand,
            color = roundFloatArray(pathData.color),
            isTransparent = pathData.isTransparent,
        }

        for j = 1, #serializedPathData.points do
            serializedPathData.points[j].x = round(serializedPathData.points[j].x, 4)
            serializedPathData.points[j].y = round(serializedPathData.points[j].y, 4)
        end

        if lastSerializedPathData ~= nil and self:arePathDatasMergable(lastSerializedPathData, serializedPathData) then
            table.insert(lastSerializedPathData.points, serializedPathData.points[2])
        else
            table.insert(frameData.pathDataList, serializedPathData)
            lastSerializedPathData = serializedPathData
        end
    end

    if self.fillImageData then
        local fileData = self.fillImageData:encode("png")
        frameData.fillPng = love.data.encode("string", "base64", fileData:getString())
    end

    return frameData
end

function DrawDataFrame:cleanUpPaths()
    for i = 1, #self.pathDataList do
        self:parent():updatePathDataRendering(self.pathDataList[i])
    end
end

function DrawDataFrame:getPathDataBounds(bounds)
    if not bounds or bounds == nil then
        bounds = {
            minX = DRAW_MAX_SIZE,
            minY = DRAW_MAX_SIZE,
            maxX = -DRAW_MAX_SIZE,
            maxY = -DRAW_MAX_SIZE,
        }
    end

    -- https://poke1024.github.io/tove2d-api/classes/Graphics.html#Graphics:computeAABB
    local minX, minY, maxX, maxY = self:graphics():computeAABB()
    minX = minX + DRAW_LINE_WIDTH / 2.0
    minY = minY + DRAW_LINE_WIDTH / 2.0
    maxX = maxX - DRAW_LINE_WIDTH / 2.0
    maxY = maxY - DRAW_LINE_WIDTH / 2.0

    -- we still need this because of isTransparent
    for i = 1, #self.pathDataList do
        local pathData = self.pathDataList[i]

        for j = 1, #pathData.points do
            local x = pathData.points[j].x
            local y = pathData.points[j].y

            if x < minX then
                minX = x
            end

            if y < minY then
                minY = y
            end

            if x > maxX then
                maxX = x
            end

            if y > maxY then
                maxY = y
            end
        end
    end

    if minX < bounds.minX then
        bounds.minX = minX
    end
    if minY < bounds.minY then
        bounds.minY = minY
    end
    if maxX > bounds.maxX then
        bounds.maxX = maxX
    end
    if maxY > bounds.maxY then
        bounds.maxY = maxY
    end

    return bounds
end

function DrawDataFrame:getPathDataBoundsInPixelCoordinates()
    local bounds = self:getPathDataBounds()

    return {
        minX = math.floor(bounds.minX * self:parent().fillPixelsPerUnit),
        minY = math.floor(bounds.minY * self:parent().fillPixelsPerUnit),
        maxX = math.ceil(bounds.maxX * self:parent().fillPixelsPerUnit),
        maxY = math.ceil(bounds.maxY * self:parent().fillPixelsPerUnit),
    }
end

function DrawDataFrame:resetGraphics()
    self._graphicsNeedsReset = true
end

function DrawDataFrame:getFillImageDataSizedToPathBounds()
    local pathBounds = self:getPathDataBoundsInPixelCoordinates()
    local width = pathBounds.maxX - pathBounds.minX
    local height = pathBounds.maxY - pathBounds.minY

    -- imagedata can't have 0 width/height
    if width < 1 then
        width = 1
    end
    if height < 1 then
        height = 1
    end

    if self.fillImageData == nil then
        self.fillImageData = love.image.newImageData(width, height)
    elseif self.fillImageData:getWidth() ~= width or self.fillImageData:getHeight() ~= height then
        local newFillImageData = love.image.newImageData(width, height)

        -- sourceX, sourceY, sourceWidth, sourceHeight, destX, destY
        newFillImageData:copyImageData(
            self.fillImageData,
            0,
            0,
            self.fillImageBounds.maxX - self.fillImageBounds.minX,
            self.fillImageBounds.maxY - self.fillImageBounds.minY,
            self.fillImageBounds.minX - pathBounds.minX,
            self.fillImageBounds.minY - pathBounds.minY)
        self.fillImageData:release()
        self.fillImageData = newFillImageData
    end

    self.fillImageBounds = util.deepCopyTable(pathBounds)

    return self.fillImageData
end

function DrawDataFrame:getFillImage()
    if self.fillImage ~= nil then
        return self.fillImage
    end

    if self.fillImageData == nil then
        return nil
    end

    self.fillImage = love.graphics.newImage(self.fillImageData)
    self.fillImage:setFilter('nearest', 'nearest')
    return self.fillImage
end

function DrawDataFrame:updateFillImageWithFillImageData()
    if self.fillImageData == nil then
        return
    end

    if self.fillImage ~= nil then
        if self.fillImage:getWidth() == self.fillImageData:getWidth() and self.fillImage:getHeight() == self.fillImageData:getHeight() then
            self.fillImage:replacePixels(self.fillImageData)
            return
        end

        self.fillImage:release()
    end

    self.fillImage = love.graphics.newImage(self.fillImageData)
    self.fillImage:setFilter('nearest', 'nearest')
end

function DrawDataFrame:compressFillCanvas()
    if self.fillImageData == nil then
        return
    end

    if self.fillImageData:isEmpty() then
        self.fillImageData:release()
        if self.fillImage ~= nil then
            self.fillImage:release()
        end

        self.fillImageData = nil
        self.fillImage = nil
    else
        local minX, minY, maxX, maxY = self.fillImageData:getBounds()
        local width = maxX - minX + 1
        local height = maxY - minY + 1

        local newFillImageData = love.image.newImageData(width, height)

        -- sourceX, sourceY, sourceWidth, sourceHeight, destX, destY
        newFillImageData:copyImageData(
            self.fillImageData,
            minX,
            minY,
            width,
            height,
            0,
            0)

        if DEBUG_FILL_IMAGE_SIZE then
            for x = 0, width - 1 do
                newFillImageData:setPixel(x, 0, 1.0, 0.0, 0.0, 1.0)
            end

            for y = 0, height - 1 do
                newFillImageData:setPixel(0, y, 1.0, 0.0, 0.0, 1.0)
            end
        end

        self.fillImageData:release()
        self.fillImageData = newFillImageData
        self.fillImageBounds.minX = self.fillImageBounds.minX + minX
        self.fillImageBounds.minY = self.fillImageBounds.minY + minY
        self.fillImageBounds.maxX = self.fillImageBounds.maxX + minX
        self.fillImageBounds.maxY = self.fillImageBounds.maxY + minY
    end
end

function DrawDataFrame:floodFill(x, y)
    self:updatePathsCanvas()
    local pathsImageData = self.pathsCanvas:newImageData()

    local pixelCount = self:getFillImageDataSizedToPathBounds():floodFill(
        math.floor(x * self:parent().fillPixelsPerUnit - self.fillImageBounds.minX),
        math.floor(y * self:parent().fillPixelsPerUnit - self.fillImageBounds.minY),
        pathsImageData,
        self:parent().color[1],
        self:parent().color[2],
        self:parent().color[3],
        1.0
    )
    self:compressFillCanvas()
    self:updateFillImageWithFillImageData()

    return pixelCount > 0
end

function DrawDataFrame:floodClear(x, y, radius)
    self:updatePathsCanvas()
    local pathsImageData = self.pathsCanvas:newImageData()

    local pixelCount = self:getFillImageDataSizedToPathBounds():floodFillErase(
        math.floor(x * self:parent().fillPixelsPerUnit - self.fillImageBounds.minX),
        math.floor(y * self:parent().fillPixelsPerUnit - self.fillImageBounds.minY),
        math.floor(radius * self:parent().fillPixelsPerUnit),
        pathsImageData
    )
    self:compressFillCanvas()
    self:updateFillImageWithFillImageData()

    return pixelCount > 0
end

function DrawDataFrame:resetFill()
    self:cleanUpPaths()
    self:updatePathsCanvas()
    local pathsImageData = self.pathsCanvas:newImageData()

    self:getFillImageDataSizedToPathBounds():updateFloodFillForNewPaths(pathsImageData)
    self:compressFillCanvas()
    self:updateFillImageWithFillImageData()
end

function DrawDataFrame:updatePathsCanvas()
    local bounds = self:getPathDataBoundsInPixelCoordinates()
    local width = bounds.maxX - bounds.minX
    local height = bounds.maxY - bounds.minY

    -- canvas can't have 0 width/height
    if width < 1 then
        width = 1
    end
    if height < 1 then
        height = 1
    end

    if self.pathsCanvas == nil or self.pathsCanvas:getWidth() ~= width or self.pathsCanvas:getHeight() ~= height then
        if self.pathsCanvas ~= nil then
            self.pathsCanvas:release()
        end

        self.pathsCanvas = love.graphics.newCanvas(
            width,
            height,
            {
                dpiscale = 1,
                msaa = 4
            }
        )
    end

    self.pathsCanvas:renderTo(
        function()
            love.graphics.push("all")

            love.graphics.origin()
            love.graphics.translate(-bounds.minX, -bounds.minY)
            love.graphics.scale(self:parent().fillPixelsPerUnit)

            love.graphics.clear(0.0, 0.0, 0.0, 0.0)
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
            self:graphics():draw()

            love.graphics.pop()
        end
    )
end

function DrawDataFrame:graphics()
    if self._graphicsNeedsReset or not self._graphics then
        self._graphicsNeedsReset = false
        self:cleanUpPaths()

        self._graphics = tove.newGraphics()
        self._graphics:setDisplay("mesh", 2048)
        self._graphics:setResolution(2)

        for i = 1, #self.pathDataList do
            self._graphics:addPath(self.pathDataList[i].tovePath)
        end
    end
    
    return self._graphics
end

function DrawDataFrame:renderFill()
    local fillImage = self:getFillImage()
    if fillImage ~= nil then
        love.graphics.draw(fillImage, self.fillImageBounds.minX / self:parent().fillPixelsPerUnit, self.fillImageBounds.minY / self:parent().fillPixelsPerUnit, 0.0, 1.0 / self:parent().fillPixelsPerUnit, 1.0 / self:parent().fillPixelsPerUnit)
    end
end

function DrawDataFrame:renderPreviewPng(size)
    if self.isLinked then
        return nil
    end

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
            local pathBounds = self:getPathDataBounds()

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
            self:renderFill()
            self:graphics():draw()

            love.graphics.pop()
        end
    )

    local fileData = previewCanvas:newImageData():encode("png")
    return love.data.encode("string", "base64", fileData:getString())
end
