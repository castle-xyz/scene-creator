local SlowdownBehavior = defineCoreBehavior {
    name = "Slowdown",
    displayName = "Slow down",
    dependencies = {
        "Moving",
        "Body"
    },
    allowsDisableWithoutRemoval = true,
    propertySpecs = {
       motionSlowdown = {
          method = 'numberInput',
          label = 'Translation',
          props = { min = 0 },
          rules = {
             set = true,
          },
       },
       rotationSlowdown = {
          method = 'numberInput',
          label = 'Rotation',
          props = { min = 0, step = 0.1 },
          rules = {
             set = true,
          },
       },
    },
}

-- Methods

function SlowdownBehavior:updateJoint(component)
    if not component._joint then
        local members = self.dependencies.Body:getMembers(component.actorId)
        local groundBodyId, groundBody = self.dependencies.Body:getGroundBody(members.layerName)
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local x, y = body:getPosition()
        component._joint = love.physics.newFrictionJoint(groundBody, body, x, y)
    end
    component._joint:setMaxForce(math.max(0.01, 10 * component.properties.motionSlowdown))
    component._joint:setMaxTorque(math.max(0.01, 8 * component.properties.rotationSlowdown))
end

function SlowdownBehavior.setters:motionSlowdown(component, newMotionSlowdown)
    if component.properties.motionSlowdown ~= newMotionSlowdown then
        component.properties.motionSlowdown = newMotionSlowdown
        if not component.disabled then
            self:updateJoint(component)
        end
    end
end

function SlowdownBehavior.setters:rotationSlowdown(component, newRotationSlowdown)
    if component.properties.rotationSlowdown ~= newRotationSlowdown then
        component.properties.rotationSlowdown = newRotationSlowdown
        if not component.disabled then
            self:updateJoint(component)
        end
    end
end

-- Component management

function SlowdownBehavior.handlers:addComponent(component, bp, opts)
    component.properties.motionSlowdown = bp.motionSlowdown or 5
    component.properties.rotationSlowdown = bp.rotationSlowdown or 0.5
end

function SlowdownBehavior.handlers:enableComponent(component, opts)
   self:updateJoint(component)
end

function SlowdownBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        if component._joint then
            component._joint:destroy()
            component._joint = nil
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
           if not component.disabled then
              self:updateJoint(component)
           end
        end
    end
end
