local FrictionBehavior =
    defineCoreBehavior {
    name = "Friction",
    displayName = "Friction",
    dependencies = {
        "Body"
    },
    propertySpecs = {
       friction = {
          method = 'numberInput',
          label = 'Amount',
          props = { step = 0.05, min = 0 },
          rules = {
             set = true,
          },
       },
    },
}

-- Component management

function FrictionBehavior.handlers:enableComponent(component, opts)
    if opts.interactive then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setFriction(0.2)
        end

        self.dependencies.Body:sendSetProperties(component.actorId, "friction", 0.2)
    end
end

function FrictionBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setFriction(0)
        end

        self.dependencies.Body:sendSetProperties(component.actorId, "friction", 0)
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

   self.dependencies.Body:sendSetProperties(component.actorId, "friction", value)
end
