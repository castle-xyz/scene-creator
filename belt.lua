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
        if currElemIds[entryId] == nil then
            local newElem = {}
            newElem.title = entry.title
            table.insert(newElems, newElem)
        end
    end
end

function Common:updateBelt(dt)
    if self.beltDirty then
        self:syncBelt()
    end
end

-- Draw

local BELT_HEIGHT = 200

function Common:drawBelt()
    if not DIDITM8 then
        print(serpent.block(self.library))
        DIDITM8 = true
    end

    local windowWidth, windowHeight = love.graphics.getDimensions()

    love.graphics.push("all")

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill",
        0, windowHeight - BELT_HEIGHT,
        windowWidth, BELT_HEIGHT)

    love.graphics.pop()
end
