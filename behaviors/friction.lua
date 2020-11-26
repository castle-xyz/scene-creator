FrictionBehavior =
    defineCoreBehavior {
    name = "Friction",
    displayName = "Friction",
    dependencies = {
        "Body"
    },
    allowsDisableWithoutRemoval = true,
    propertySpecs = {
       friction = {
          method = 'numberInput',
          label = 'Amount',
          props = { step = 0.05, min = 0 },
          rules = {
             set = true,
             get = true,
          },
       },
    },
}

-- Component management

function FrictionBehavior.handlers:addComponent(component, bp, opts)
   if bp.friction ~= nil then
      component.properties.friction = bp.friction
   else
      -- old scenes stored this prop in the body blueprint
      local bodyComponent = self.dependencies.Body.components[component.actorId]
      if bodyComponent and bodyComponent.properties.friction ~= nil then
         component.properties.friction = bodyComponent.properties.friction
      else
         component.properties.friction = 0.2
      end
   end
end

function FrictionBehavior.handlers:blueprintComponent(component, bp)
   bp.friction = component.properties.friction
end

function FrictionBehavior.handlers:enableComponent(component, opts)
   local bodyId, body = self.dependencies.Body:getBody(component.actorId)
   local fixtures = body:getFixtures()
   for _, fixture in pairs(fixtures) do
      fixture:setFriction(component.properties.friction)
   end
end

function FrictionBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setFriction(0)
        end
    end
end

function FrictionBehavior.handlers:updateComponentFixture(component, fixtureId)
   local members = self.dependencies.Body:getMembers(component.actorId)
   if component.disabled then
      members.physics:setFriction(fixtureId, 0)
   else
      members.physics:setFriction(fixtureId, component.properties.friction)
   end
end

function FrictionBehavior.handlers:blueprintFixture(component, fixture, fixtureBp)
   fixtureBp.friction = fixture:getFriction()
end

function FrictionBehavior.setters:friction(component, value)
   component.properties.friction = value
   if not component.disabled then
      self.handlers.enableComponent(self, component)
   end
end
