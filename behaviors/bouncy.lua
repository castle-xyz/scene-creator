local BouncyBehavior =
    defineCoreBehavior {
    name = "Bouncy",
    displayName = "bouncy",
    propertyNames = { "bounciness" },
    dependencies = {
        "Solid",
        "Body"
    },
    propertySpecs = {
       bounciness = {
          method = 'numberInput',
          label = 'bounciness',
          props = { step = 0.05, min = 0, max = 2 },
       },
    },
}

-- Component management

function BouncyBehavior.handlers:addComponent(component, bp, opts)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixture = body:getFixtures()[1]
    if fixture then
        if fixture:getRestitution() == 0 then
            fixture:setRestitution(0.8)
        end
    end
end

function BouncyBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixture = body:getFixtures()[1]
        if fixture then
            fixture:setRestitution(0)
        end
    end
end

function BouncyBehavior.getters:bounciness(component)
    local actorId = component.actorId
    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
    if fixture then
       return fixture:getRestitution()
    end
    return 0
end

function BouncyBehavior.setters:bounciness(component, value)
   local actorId = component.actorId
   local physics, bodyId, body, fixtureId = self.dependencies.Body:getMembers(actorId)
   physics:setRestitution(fixtureId, value)
end
