local CircleShapeBehavior = {
    name = 'CircleShape',
    displayName = 'circle shape',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(CircleShapeBehavior)


-- Component management

function CircleShapeBehavior.handlers:addComponent(component, bp, opts)
    if opts.isOrigin then
        if self.dependencies.Body:getShapeType(component.actorId) ~= 'circle' then
            local physics = self.dependencies.Body:getPhysics()
            self.dependencies.Body:setShape(component.actorId, physics:newCircleShape(0.5 * UNIT))
        end
    end
end

function CircleShapeBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        self.dependencies.Body:resetShape(component.actorId)
    end
end


-- UI

function CircleShapeBehavior.handlers:uiComponent(component, opts)
    local physics = self.dependencies.Body:getPhysics()
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixture = body:getFixtures()[1]
    if fixture then
        local shape = fixture:getShape()
        if shape:getType() == 'circle' then
            ui.numberInput('radius', shape:getRadius(), {
                min = 0.5 * MIN_BODY_SIZE,
                max = 0.5 * MAX_BODY_SIZE,
                onChange = function(newRadius)
                    newRadius = math.max(0.5 * MIN_BODY_SIZE, math.min(newRadius, 0.5 * MAX_BODY_SIZE))
                    self.dependencies.Body:setShape(component.actorId, physics:newCircleShape(newRadius))
                end,
            })
        end
    end
end



