local ScaleRotateTool =
    defineCoreBehavior {
    name = "ScaleRotate",
    propertyNames = {},
    dependencies = {
        "Body"
    },
    tool = {
        needsPerformingOff = true,
        emptySelect = true
    }
}

-- Behavior management

function ScaleRotateTool.handlers:addBehavior(opts)
end

-- Methods

-- Update

function ScaleRotateTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end
end

function ScaleRotateTool.handlers:update(dt)
    if not self:isActive() then
        return
    end
end

-- Draw

function ScaleRotateTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end
end

-- UI

function ScaleRotateTool.handlers:uiPanel()
    if not self:isActive() then
        return
    end
end
