local FallingBehavior = defineCoreBehavior {
    name = "Falling",
    displayName = "falling",
    propertyNames = { "gravity" },
    dependencies = {
        "Moving",
        "Body"
    },
    propertySpecs = {
      gravity = {
         method = 'numberInput',
         label = 'gravity',
         props = {
            step = 0.5
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
    if opts.interactive then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setGravityScale(1)
    end
end

function FallingBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setGravityScale(0)
    end
end

function FallingBehavior.setters:gravity(component, value)
   local actorId = component.actorId
   local physics, bodyId = self.dependencies.Body:getMembers(actorId)
   physics:setGravityScale(bodyId, value)   
end

function FallingBehavior.getters:gravity(component)
   local actorId = component.actorId
   local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
   return body:getGravityScale()
end

-- UI

function FallingBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId
    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)

    self:uiValue(
        "numberInput",
        "gravity",
        body:getGravityScale(),
        {
            props = {step = 0.5},
            onChange = function(params)
                local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                physics:setGravityScale(bodyId, params.value)
            end
        }
    )
end
