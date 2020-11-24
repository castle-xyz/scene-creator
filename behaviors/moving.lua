local MovingBehavior =
    defineCoreBehavior {
    name = "Moving",
    displayName = "Dynamic Motion",
    dependencies = {
        "Body"
    },
    propertySpecs = {
       vx = {
          method = 'numberInput',
          label = 'Velocity X',
          rules = {
             set = true,
             get = true,
          },
       },
       vy = {
          method = 'numberInput',
          label = 'Velocity Y',
          rules = {
             set = true,
             get = true,
          },
       },
       angularVelocity = {
          method = 'numberInput',
          label = 'Rotation speed (degrees)',
          rules = {
             set = true,
             get = true,
          },
       },
       density = {
          method = 'numberInput',
          label = 'Density',
          props = { min = 0.1, step = 0.1 },
          rules = {
             set = true,
             get = true,
          },
       },
    },
}

-- Body type

function MovingBehavior.handlers:bodyTypeComponent(component)
    return "dynamic"
end

-- Component management

function MovingBehavior.handlers:addComponent(component, bp, opts)
   local bodyComponent = self.dependencies.Body.components[component.actorId]
   if bp.vx ~= nil and bp.vy ~= nil then
      component.properties.vx = bp.vx
      component.properties.vy = bp.vy
   else
      -- old scenes stored this prop in the body blueprint
      if bodyComponent and bodyComponent.properties.linearVelocity ~= nil then
         component.properties.vx, component.properties.vy = unpack(bodyComponent.properties.linearVelocity)
      else
         component.properties.vx = 0
         component.properties.vy = 0
      end
   end
   if bp.angularVelocity ~= nil then
      component.properties.angularVelocity = bp.angularVelocity
   else
      -- old scenes stored this prop in the body blueprint
      if bodyComponent and bodyComponent.properties.angularVelocity ~= nil then
         component.properties.angularVelocity = bodyComponent.properties.angularVelocity * 180 / math.pi
      else
         component.properties.angularVelocity = 0
      end
   end
   if bp.density ~= nil then
      component.properties.density = bp.density
   else
      component.properties.density = 1
   end
end

function MovingBehavior.handlers:blueprintComponent(component, bp)
   bp.vx = component.properties.vx
   bp.vy = component.properties.vy
   bp.angularVelocity = component.properties.angularVelocity
   bp.density = component.properties.density
end

function MovingBehavior.handlers:blueprintFixture(component, fixture, fixtureBp)
   fixtureBp.density = fixture:getDensity()
end

function MovingBehavior.handlers:enableComponent(component, opts)
   local bodyId, body = self.dependencies.Body:getBody(component.actorId)
   body:setLinearVelocity(component.properties.vx, component.properties.vy)
   body:setAngularVelocity(component.properties.angularVelocity * math.pi / 180)
   local fixtures = body:getFixtures()
   for _, fixture in pairs(fixtures) do
      fixture:setDensity(component.properties.density)
   end
   body:resetMassData()
   body:setAwake(true)
end

function MovingBehavior.handlers:enableDependentComponent(component)
   -- if we enable anything that depends on Moving, awaken the body
   local bodyId, body = self.dependencies.Body:getBody(component.actorId)
   body:setAwake(true)
end

function MovingBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
        self:fireTrigger("velocity changes", actorId) -- fire this once, stop polling afterward
        component._prevVelocity = nil
        component._prevPosition = nil
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
           fixture:setDensity(1)
        end
        body:resetMassData()
    end
end

function MovingBehavior.handlers:updateComponentFixture(component, fixtureId)
   local members = self.dependencies.Body:getMembers(component.actorId)
   if component.disabled then
      members.physics:setDensity(fixtureId, 1)
   else
      members.physics:setDensity(fixtureId, component.properties.density)
   end
end

local STOPS_TRANSLATING_THRESHOLD = 0.0005
local STOPS_ROTATING_THRESHOLD = 0.001

function MovingBehavior.handlers:postPerform(dt)
   for actorId, component in pairs(self.components) do
      if not component.disabled then
         local members = self.dependencies.Body:getMembers(actorId)
         local vx, vy = members.body:getLinearVelocity()
         local va = members.body:getAngularVelocity()
         if component._prevVelocity == nil or component._prevVelocity.x ~= vx or component._prevVelocity.y ~= vy or component._prevVelocity.a ~= va then
            self:fireTrigger("velocity changes", actorId)
         end
         component._prevVelocity = component._prevVelocity or {}
         component._prevVelocity.x = vx
         component._prevVelocity.y = vy
         component._prevVelocity.a = va

         local x, y = members.body:getX(), members.body:getY()
         local a = members.body:getAngle()
         if component._prevPosition ~= nil then
            if component._startsMovingTriggerFired and
               (math.abs(component._prevPosition.x - x) < STOPS_TRANSLATING_THRESHOLD and
                math.abs(component._prevPosition.y - y) < STOPS_TRANSLATING_THRESHOLD and
                math.abs(component._prevPosition.a - a) < STOPS_ROTATING_THRESHOLD) then
                  component._startsMovingTriggerFired = false
                  self:fireTrigger("stops moving", actorId)
            elseif not component._startsMovingTriggerFired and
               (math.abs(component._prevPosition.x - x) >= STOPS_TRANSLATING_THRESHOLD or
                math.abs(component._prevPosition.y - y) >= STOPS_TRANSLATING_THRESHOLD or
                math.abs(component._prevPosition.a - a) >= STOPS_ROTATING_THRESHOLD) then
                  component._startsMovingTriggerFired = true
            end
         end
         component._prevPosition = component._prevPosition or {}
         component._prevPosition.x = x
         component._prevPosition.y = y
         component._prevPosition.a = a
      end
   end
end

-- Triggers

MovingBehavior.triggers["velocity changes"] = {
   description = "When velocity changes",
   category = "motion",
}

MovingBehavior.triggers["stops moving"] = {
   description = "When this stops moving",
   category = "motion",
}

-- Responses

MovingBehavior.responses["add velocity"] = {
    description = "Adjust velocity (legacy)",
    migrate = function(self, actorId, response)
       local rules = self.game.behaviorsByName.Rules
       response.behaviorId = rules.behaviorId
       response.name = 'set behavior property'
       response.params = {
          behaviorId = self.behaviorId,
          propertyName = 'vx',
          value = response.params.x,
          relative = true,
          nextResponse = {
             behaviorId = rules.behaviorId,
             name = 'set behavior property',
             params = {
                behaviorId = self.behaviorId,
                propertyName = 'vy',
                value = response.params.y,
                relative = true,
                nextResponse = response.params.nextResponse,
             },
          },
       }
    end,
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            local m = body:getMass()
            body:applyLinearImpulse(m * params.x, m * params.y)
        end
    end
}

MovingBehavior.responses["add rotation speed"] = {
    description = "Adjust rotation speed (legacy)",
    migrate = function(self, actorId, response)
       local rules = self.game.behaviorsByName.Rules
       response.behaviorId = rules.behaviorId
       response.name = 'set behavior property'
       response.params = {
          behaviorId = self.behaviorId,
          propertyName = 'angularVelocity',
          value = response.params.speed,
          relative = true,
          nextResponse = response.params.nextResponse,
       }
    end,
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            local I = body:getInertia()
            body:applyAngularImpulse(I * params.speed * math.pi / 180)
        end
    end
}

MovingBehavior.responses["set velocity"] = {
    description = "Set velocity (legacy)",
    migrate = function(self, actorId, response)
       local rules = self.game.behaviorsByName.Rules
       response.behaviorId = rules.behaviorId
       response.name = 'set behavior property'
       response.params = {
          behaviorId = self.behaviorId,
          propertyName = 'vx',
          value = response.params.x,
          nextResponse = {
             behaviorId = rules.behaviorId,
             name = 'set behavior property',
             params = {
                behaviorId = self.behaviorId,
                propertyName = 'vy',
                value = response.params.y,
                nextResponse = response.params.nextResponse,
             },
          },
       }
    end,
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            body:setLinearVelocity(params.x, params.y)
        end
    end
}

MovingBehavior.responses["set rotation speed"] = {
    description = "Set rotation speed (legacy)",
    migrate = function(self, actorId, response)
       local rules = self.game.behaviorsByName.Rules
       response.behaviorId = rules.behaviorId
       response.name = 'set behavior property'
       response.params = {
          behaviorId = self.behaviorId,
          propertyName = 'angularVelocity',
          value = response.params.speed,
          nextResponse = response.params.nextResponse,
       }
    end,
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            -- degrees per second
            body:setAngularVelocity(params.speed * math.pi / 180)
        end
    end
}

MovingBehavior.responses["move toward own angle"] = {
   description = "Move toward my own angle",
   category = "motion",
   paramSpecs = {
      speed = {
         method = "numberInput",
         label = "Speed",
         initialValue = 0,
      },
   },
   run = function(self, actorId, params, context)
      local members = self.game.behaviorsByName.Body:getMembers(actorId)
      if members.body then
         local angle = members.body:getAngle()
         local m = members.body:getMass()
         local speed = self.game:evalExpression(params.speed, actorId, context)
         members.body:applyLinearImpulse(m * speed * math.cos(angle), m * speed * math.sin(angle))
      end
   end,
}

MovingBehavior.responses["move toward actor"] = {
   description = "Move toward another actor (dynamic motion)",
   category = "motion",
   paramSpecs = {
      tag = {
         method = "tagPicker",
         label = "Tag",
         props = { singleSelect = true },
      },
      speed = {
         method = "numberInput",
         label = "Speed",
         initialValue = 0,
      },
   },
   run = function(self, actorId, params, context)
      local members = self.game.behaviorsByName.Body:getMembers(actorId)
      local x, y = 0, 0
      if members.body then
         x, y = members.body:getPosition()
      end
      
      local closestActorId, actorX, actorY = self.game:closestActorWithTag(actorId, params.tag)
      if members.body and closestActorId ~= nil then
         local m = members.body:getMass()
         local angle = math.atan2(actorY - y, actorX - x)
         local speed = self.game:evalExpression(params.speed, actorId, context)
         members.body:applyLinearImpulse(m * speed * math.cos(angle), m * speed * math.sin(angle))
      end
   end
}

function MovingBehavior.setters:vx(component, value)
   component.properties.vx = value
   if not component.disabled then
      local members = self.dependencies.Body:getMembers(component.actorId)
      local vx, vy = members.body:getLinearVelocity()
      members.physics:setLinearVelocity(members.bodyId, value, vy)
   end
end

function MovingBehavior.setters:vy(component, value)
   component.properties.vy = value
   if not component.disabled then
      local members = self.dependencies.Body:getMembers(component.actorId)
      local vx, vy = members.body:getLinearVelocity()
      members.physics:setLinearVelocity(members.bodyId, vx, value)
   end
end

function MovingBehavior.setters:angularVelocity(component, value)
   component.properties.angularVelocity = value
   if not component.disabled then
      local members = self.dependencies.Body:getMembers(component.actorId)
      members.physics:setAngularVelocity(members.bodyId, value * math.pi / 180)
   end
end

function MovingBehavior.setters:density(component, value)
   component.properties.density = value
   local members = self.dependencies.Body:getMembers(component.actorId)
   for _, fixture in pairs(members.fixtures) do
      fixture:setDensity(component.properties.density)
   end
end

function MovingBehavior.getters:vx(component)
   local members = self.dependencies.Body:getMembers(component.actorId)
   local vx, vy = members.body:getLinearVelocity()
   return vx
end

function MovingBehavior.getters:vy(component)
   local members = self.dependencies.Body:getMembers(component.actorId)
   local vx, vy = members.body:getLinearVelocity()
   return vy
end

function MovingBehavior.getters:angularVelocity(component)
   local members = self.dependencies.Body:getMembers(component.actorId)
   local va = members.body:getAngularVelocity()
   return va * 180 / math.pi
end
