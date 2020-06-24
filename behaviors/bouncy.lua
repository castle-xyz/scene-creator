local BouncyBehavior =
    defineCoreBehavior {
    name = "Bouncy",
    displayName = "Bounce",
    propertyNames = { "bounciness" },
    dependencies = {
        "Solid",
        "Body"
    },
    propertySpecs = {
       bounciness = {
          method = 'numberInput',
          label = 'Rebound',
          props = { step = 0.05, min = 0, max = 2 },
       },
    },
}

-- Component management

function BouncyBehavior.handlers:addComponent(component, bp, opts)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixtures = body:getFixtures()
    for _, fixture in pairs(fixtures) do
        if fixture:getRestitution() == 0 then
            fixture:setRestitution(0.8)
        end
    end
end

function BouncyBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setRestitution(0)
        end
    end
end

function BouncyBehavior.getters:bounciness(component)
    local actorId = component.actorId
    local members = self.dependencies.Body:getMembers(actorId)
    if members.fixture then
       return members.fixture:getRestitution()
    end
    return 0
end

function BouncyBehavior.setters:bounciness(component, value)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)

   for _, fixtureId in pairs(members.fixtureIds) do
    members.physics:setRestitution(fixtureId, value)
   end
end
