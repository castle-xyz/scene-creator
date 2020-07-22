local SlidingBehavior =
    defineCoreBehavior {
    name = "Sliding",
    displayName = "Axis Lock",
    dependencies = {
        "Moving",
        "Body"
    },
    allowsDisableWithoutRemoval = true,
    propertySpecs = {
       direction = {
          method = 'dropdown',
          label = 'Direction',
          props = { items = {"horizontal", "vertical", "both", "none"} },
       },
       isRotationAllowed = {
          method = 'toggle',
          label = 'Rotates',
          rules = {
             set = true,
          },
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
    if direction == "none" then
       -- we still want to allow rotation, so fix the body to a revolute joint at its own position
       local members = self.dependencies.Body:getMembers(component.actorId)
       local x, y = members.body:getPosition()
       local groundBodyId, groundBody = self.dependencies.Body:getGroundBody()
       component._joint = love.physics.newRevoluteJoint(groundBody, members.body, x, y)
    elseif direction ~= "both" then
        -- allow motion in one dimension
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

-- Setters

function SlidingBehavior.setters:isRotationAllowed(component, value)
   component.properties.isRotationAllowed = value
   if not component.disabled then
      local members = self.dependencies.Body:getMembers(component.actorId)
      members.physics:setFixedRotation(members.bodyId, not value)
   end
end

function SlidingBehavior.setters:direction(component, newLimitType)
    if component.properties.direction ~= newLimitType then
        component.properties.direction = newLimitType
        if not component.disabled then
            self:updateJoint(component)
        end
    end
end

-- Component management

function SlidingBehavior.handlers:addComponent(component, bp, opts)
   component.properties.direction = bp.direction or "both"

   if bp.isRotationAllowed ~= nil then
      component.properties.isRotationAllowed = bp.isRotationAllowed
   else
      -- old scenes stored this prop in the body blueprint
      local bodyComponent = self.dependencies.Body.components[component.actorId]
      if bodyComponent and bodyComponent.properties.fixedRotation ~= nil then
         component.properties.isRotationAllowed = not bodyComponent.properties.fixedRotation
      else
         component.properties.isRotationAllowed = true
      end
   end
end

function SlidingBehavior.handlers:enableComponent(component, opts)
   self:updateJoint(component)
   local members = self.dependencies.Body:getMembers(component.actorId)
   members.physics:setFixedRotation(members.bodyId, not component.properties.isRotationAllowed)
end

function SlidingBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        if component._joint then
            component._joint:destroy()
        end
        local members = self.dependencies.Body:getMembers(component.actorId)
        members.physics:setFixedRotation(members.bodyId, false)
    end
end

function SlidingBehavior.handlers:blueprintComponent(component, bp)
    bp.direction = component.properties.direction
    bp.isRotationAllowed = component.properties.isRotationAllowed
end

-- Setting performing

function SlidingBehavior.handlers:setPerforming(newPerforming)
    -- Bodies may have moved -- recreate joints
    if newPerforming then
        for actorId, component in pairs(self.components) do
            if not component.disabled then
                self:updateJoint(component)
            end
        end
    end
end
