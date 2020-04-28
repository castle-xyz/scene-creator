local SlowdownBehavior =
    defineCoreBehavior {
    name = "Slowdown",
    displayName = "slowdown",
    propertyNames = {
        "motionSlowdown",
        "rotationSlowdown"
    },
    dependencies = {
        "Moving",
        "Body"
    },
    setters = {}
}

-- Methods

function SlowdownBehavior:updateJoint(component)
    if not component._joint then
        local groundBodyId, groundBody = self.dependencies.Body:getGroundBody()
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local x, y = body:getPosition()
        component._joint = love.physics.newFrictionJoint(groundBody, body, x, y)
    end
    component._joint:setMaxForce(math.max(0.01, 10 * component.properties.motionSlowdown))
    component._joint:setMaxTorque(math.max(0.01, 8 * component.properties.rotationSlowdown))
end

-- Setters

function SlowdownBehavior.setters:motionSlowdown(component, newMotionSlowdown)
    if component.properties.motionSlowdown ~= newMotionSlowdown then
        component.properties.motionSlowdown = newMotionSlowdown
        self:updateJoint(component)
    end
end

function SlowdownBehavior.setters:rotationSlowdown(component, newRotationSlowdown)
    if component.properties.rotationSlowdown ~= newRotationSlowdown then
        component.properties.rotationSlowdown = newRotationSlowdown
        self:updateJoint(component)
    end
end

-- Component management

function SlowdownBehavior.handlers:addComponent(component, bp, opts)
    component.properties.motionSlowdown = bp.motionSlowdown or 5
    component.properties.rotationSlowdown = bp.rotationSlowdown or 5
    self:updateJoint(component)
end

function SlowdownBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        if component._joint then
            component._joint:destroy()
        end
    end
end

function SlowdownBehavior.handlers:blueprintComponent(component, bp)
    bp.motionSlowdown = component.properties.motionSlowdown
    bp.rotationSlowdown = component.properties.rotationSlowdown
end

-- Setting performing

function SlowdownBehavior.handlers:setPerforming(newPerforming)
    -- Bodies may have moved -- update joints
    if newPerforming then
        for actorId, component in pairs(self.components) do
            self:updateJoint(component)
        end
    end
end

-- UI

function SlowdownBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiProperty(
        "numberInput",
        "motion slowdown",
        actorId,
        "motionSlowdown",
        {
            props = {min = 0}
        }
    )

    self:uiProperty(
        "numberInput",
        "rotation slowdown",
        actorId,
        "rotationSlowdown",
        {
            props = {min = 0}
        }
    )
end
