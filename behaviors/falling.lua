local FallingBehavior = defineCoreBehavior {
    name = "Falling",
    displayName = "Gravity",
    dependencies = {
        "Moving",
        "Body"
    },
    allowsDisableWithoutRemoval = true,
    propertySpecs = {
      gravity = {
         method = 'numberInput',
         label = 'Strength',
         props = {
            step = 0.5
         },
         rules = {
             set = true,
          },
      },
   },
}

-- Body type

function FallingBehavior.handlers:bodyTypeComponent(component)
    return "dynamic"
end

-- Component management

function FallingBehavior.handlers:addComponent(component, bp, opts)
   if bp.gravity ~= nil then
      component.properties.gravity = bp.gravity
   else
      -- old scenes stored this prop in the body blueprint
      local bodyComponent = self.dependencies.Body.components[component.actorId]
      if bodyComponent and bodyComponent.properties.gravityScale ~= nil then
         component.properties.gravity = bodyComponent.properties.gravityScale
      else
         component.properties.gravity = 1
      end
   end
end

function FallingBehavior.handlers:enableComponent(component, opts)
   local bodyId, body = self.dependencies.Body:getBody(component.actorId)
   body:setGravityScale(component.properties.gravity)
end

function FallingBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setGravityScale(0)
    end
end

function FallingBehavior.handlers:blueprintComponent(component, bp)
   bp.gravity = component.properties.gravity
end

function FallingBehavior.setters:gravity(component, value)
   local actorId = component.actorId
   component.properties.gravity = value
   if not component.disabled then
      local members = self.dependencies.Body:getMembers(actorId)
      members.physics:setGravityScale(members.bodyId, value)
   end
end
