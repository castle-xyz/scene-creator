local FallingBehavior = defineCoreBehavior {
    name = "Falling",
    displayName = "Gravity",
    dependencies = {
        "Moving",
        "Body"
    },
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

function FallingBehavior.handlers:enableComponent(component, opts)
    if opts.interactive then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setGravityScale(1)
    end
end

function FallingBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setGravityScale(0)
    end
end

function FallingBehavior.setters:gravity(component, value)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   members.physics:setGravityScale(members.bodyId, value)
end

function FallingBehavior.getters:gravity(component)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   return members.body:getGravityScale()
end
