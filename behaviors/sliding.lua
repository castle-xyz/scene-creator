local SlidingBehavior =
    defineCoreBehavior {
    name = "Sliding",
    displayName = "Axis Lock",
    propertyNames = {
       "direction",
       "isRotationAllowed",
    },
    dependencies = {
        "Moving",
        "Body"
    },
    propertySpecs = {
       direction = {
          method = 'dropdown',
          label = 'Direction',
          props = { items = {"horizontal", "vertical", "both"} },
       },
       isRotationAllowed = {
          method = 'toggle',
          label = 'Rotates',
       },
    },
}

-- Methods

function SlidingBehavior:updateJoint(component)
    if component._joint then
        component._joint:destroy()
        component._joint = nil
    end

    local direction = component.properties.direction
    if direction ~= "both" then
        local ax, ay
        if direction == "horizontal" then
            ax, ay = 1, 0
        elseif direction == "vertical" then
            ax, ay = 0, 1
        end

        if ax and ay then
            local groundBodyId, groundBody = self.dependencies.Body:getGroundBody()
            local bodyId, body = self.dependencies.Body:getBody(component.actorId)
            local x, y = body:getPosition()
            component._joint = love.physics.newWheelJoint(groundBody, body, x, y, ax, ay)
            component._joint:setSpringFrequency(0)
        end
    end
end

-- Getters

function SlidingBehavior.getters:isRotationAllowed(component)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   local isFixedRotation = members.body:isFixedRotation()
   return not isFixedRotation
end

-- Setters

function SlidingBehavior.setters:isRotationAllowed(component, value)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   members.physics:setFixedRotation(members.bodyId, not value)
end

function SlidingBehavior.setters:direction(component, newLimitType)
    if component.properties.direction ~= newLimitType then
        component.properties.direction = newLimitType
        self:updateJoint(component)
    end
end

-- Component management

function SlidingBehavior.handlers:addComponent(component, bp, opts)
    component.properties.direction = bp.direction or "both"
    self:updateJoint(component)
end

function SlidingBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        if component._joint then
            component._joint:destroy()
        end
    end
end

function SlidingBehavior.handlers:blueprintComponent(component, bp)
    bp.direction = component.properties.direction
end

-- Setting performing

function SlidingBehavior.handlers:setPerforming(newPerforming)
    -- Bodies may have moved -- recreate joints
    if newPerforming then
        for actorId, component in pairs(self.components) do
            self:updateJoint(component)
        end
    end
end
