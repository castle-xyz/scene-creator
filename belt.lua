-- Start / stop

function Common:startBelt()
    self.beltDirty = true

    self.beltElems = {}
end

-- Update

function Common:markBeltDirty()
    -- Mark belt as needing synchronization
    self.beltDirty = true
end

function Common:syncBelt()
    -- Synchronize belt data with library entries

    -- Collect set of ids the current belt data covers
    local currElemIds = {}
    for _, beltElem in ipairs(self.beltElems) do
        currElemIds[beltElem.entryId] = true
    end

    -- Prepare list of new elements
    local newElems = {}
    for entryId, entry in pairs(self.library) do
        if not currElemIds[entryId] then
            local newElem = {}
            newElem.entryId = entry.entryId
            newElem.title = entry.title
            newElem.order = entry.beltOrder
            if newElem.order == nil then
                newElem.order = 0
            end
            if entry.base64Png then
                local decoded = love.data.decode("data", "base64", entry.base64Png)
                local imgData = love.image.newImageData(decoded)
                newElem.image = love.graphics.newImage(imgData)
            end
            table.insert(newElems, newElem)
        end
    end

    -- Save new elements
    for _, newElem in ipairs(newElems) do
        table.insert(self.beltElems, newElem)
    end

    -- Sort belt
    table.sort(self.beltElems, function(a, b)
        return a.order < b.order
    end)
end

function Common:updateBelt(dt)
    if self.beltDirty then
        self:syncBelt()
    end
end

-- Draw

local BELT_HEIGHT = 200

local ELEM_SIZE = 170
local ELEM_GAP = 20

function Common:drawBelt()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    love.graphics.push("all")

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill",
        0, windowHeight - BELT_HEIGHT,
        windowWidth, BELT_HEIGHT)

    local y = windowHeight - 0.5 * BELT_HEIGHT

    love.graphics.setColor(1, 1, 1)
    for i, elem in ipairs(self.beltElems) do
        local x = 0.5 * windowWidth + (ELEM_SIZE + ELEM_GAP) * (i - 1)

        if elem.image then
            local imgW, imgH = elem.image:getDimensions()
            local scale = math.min(ELEM_SIZE / imgW, ELEM_SIZE / imgH)
            love.graphics.draw(elem.image, x, y, 0, scale, scale, 0.5 * imgW, 0.5 * imgH)
        end

        --love.graphics.rectangle("fill",
        --    x - 0.5 * ELEM_SIZE, y - 0.5 * ELEM_SIZE,
        --    ELEM_SIZE, ELEM_SIZE)
    end

    love.graphics.pop()
end
