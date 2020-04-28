local CircleShapeBehavior =
    defineCoreBehavior {
    name = "CircleShape",
    displayName = "circle",
    propertyNames = {},
    dependencies = {
        "Body"
    }
}

-- Component management

function CircleShapeBehavior.handlers:addComponent(component, bp, opts)
    if opts.isOrigin then
        if self.dependencies.Body:getShapeType(component.actorId) ~= "circle" then
            local physics = self.dependencies.Body:getPhysics()
            local width, height = self.dependencies.Body:getSize(component.actorId)
            local newRadius = 0.5 * (width and height and math.max(width, height) or UNIT)
            self.dependencies.Body:setShape(component.actorId, physics:newCircleShape(newRadius))
        end
    end
end

function CircleShapeBehavior.handlers:removeComponent(component, opts)
    if opts.isOrigin and not opts.removeActor then
        self.dependencies.Body:resetShape(component.actorId)
    end
end

-- UI

function CircleShapeBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId
    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
    if fixture then
        local shape = fixture:getShape()
        if shape:getType() == "circle" then
            self:uiValue(
                "numberInput",
                "radius",
                shape:getRadius(),
                {
                    props = {min = 0.5 * MIN_BODY_SIZE, max = 0.5 * MAX_BODY_SIZE, decimalDigits = 1},
                    onChange = function(params)
                        local value = math.max(0.5 * MIN_BODY_SIZE, math.min(params.value, 0.5 * MAX_BODY_SIZE))
                        local physics = self.dependencies.Body:getPhysics()
                        self.dependencies.Body:setShape(actorId, physics:newCircleShape(value))
                    end
                }
            )
        end
    end
end
