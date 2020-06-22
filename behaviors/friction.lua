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
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setFriction(0.2)
        end
    end
end

function FrictionBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setFriction(0)
        end
    end
end

function FrictionBehavior.getters:friction(component)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   if members.firstFixture then
      return members.firstFixture:getFriction()
   end
   return 0
end

function FrictionBehavior.setters:friction(component, value)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   for _, fixtureId in pairs(members.fixtureIds) do
      members.physics:setFriction(fixtureId, value)
   end
end
