local DrawTool =
    defineCoreBehavior {
    name = "Draw",
    propertyNames = {},
    dependencies = {
        "Body",
        "Drawing"
    },
    tool = {
        icon = "pencil-alt",
        iconFamily = "FontAwesome5",
        needsPerformingOff = true,
        isFullScreen = true,
    }
}


-- Behavior management

function DrawTool.handlers:addBehavior(opts)
end

-- Methods

function DrawTool:getSingleComponent()
    local singleComponent
    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            if singleComponent then
                return nil
            end
            singleComponent = component
        end
    end
    return singleComponent
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
    local c = self:getSingleComponent()
    if not c then
        return
    end
end

local GRID_HORIZONTAL_PADDING = 0.1
local GRID_ROWS = 10
local GRID_COLS = 10

local function globalToGridCoordinates(x, y)
    local gridX = 
end

-- Draw

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end

    love.graphics.clear(0.9, 0.9, 0.9)

    love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
    love.graphics.setPointSize(10.0)
    love.graphics.points(0.5, 0.5)
end

-- UI

function DrawTool.handlers:uiPanel()
    if not self:isActive() then
        return
    end

    local c = self:getSingleComponent()
    if not c then
        return
    end
end
