local BouncyBehavior =
    defineCoreBehavior {
    name = "Bouncy",
    displayName = "Bounce",
    dependencies = {
        "Solid",
        "Body"
    },
    propertySpecs = {
       bounciness = {
          method = 'numberInput',
          label = 'Rebound',
          props = { step = 0.05, min = 0, max = 2 },
          rules = {
             set = true,
          },
       },
    },
}

-- Component management

function BouncyBehavior.handlers:addComponent(component, bp, opts)
   if bp.bounciness ~= nil then
      component.properties.bounciness = bp.bounciness
   else
      -- old scenes stored this prop in the body blueprint
      local bodyComponent = self.dependencies.Body.components[component.actorId]
      if bodyComponent and bodyComponent.properties.restitution ~= nil then
         component.properties.bounciness = bodyComponent.properties.restitution
      else
         component.properties.bounciness = 0.8
      end
   end
end

function BouncyBehavior.handlers:blueprintComponent(component, bp)
   bp.bounciness = component.properties.bounciness
end

function BouncyBehavior.handlers:enableComponent(component, opts)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixtures = body:getFixtures()

    for _, fixture in pairs(fixtures) do
       fixture:setRestitution(component.properties.bounciness)
    end
end

function BouncyBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setRestitution(0)
        end
    end
end

function BouncyBehavior.handlers:updateComponentFixture(component, fixtureId)
   local members = self.dependencies.Body:getMembers(actorId)
   if component.disabled then
      members.physics:setRestitution(fixtureId, 0)
   else
      members.physics:setRestitution(fixtureId, component.properties.bounciness)
   end
end

function BouncyBehavior.handlers:blueprintFixture(component, fixture, fixtureBp)
   fixtureBp.restitution = fixture:getRestitution()
end

function BouncyBehavior.setters:bounciness(component, value)
   component.properties.bounciness = value
   if not component.disabled then
      self.handlers.enableComponent(self, component)
   end
end
