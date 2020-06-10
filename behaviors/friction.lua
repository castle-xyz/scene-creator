local FrictionBehavior =
    defineCoreBehavior {
    name = "Friction",
    displayName = "friction",
    propertyNames = { "friction" },
    dependencies = {
        "Body"
    },
    propertySpecs = {
       friction = {
          method = 'numberInput',
          label = 'friction',
          props = { step = 0.05, min = 0 },
       },
    },
}

-- Component management

function FrictionBehavior.handlers:addComponent(component, bp, opts)
    if opts.interactive then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixture = body:getFixtures()[1]
        if fixture then
            fixture:setFriction(0.2)
        end
    end
end

function FrictionBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixture = body:getFixtures()[1]
        if fixture then
            fixture:setFriction(0)
        end
    end
end

function FrictionBehavior.getters:friction(component)
   local actorId = component.actorId
   local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
   if fixture then
      return fixture:getFriction()
   end
   return 0
end

function FrictionBehavior.setters:friction(component, value)
   local actorId = component.actorId
   local physics, bodyId, body, fixtureId = self.dependencies.Body:getMembers(actorId)
   physics:setFriction(fixtureId, params.value)
end
