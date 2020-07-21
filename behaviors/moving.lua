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
          },
       },
       vy = {
          method = 'numberInput',
          label = 'Velocity Y',
          rules = {
             set = true,
          },
       },
       angularVelocity = {
          method = 'numberInput',
          label = 'Rotation speed (degrees)',
          rules = {
             set = true,
          },
       },
    },
}

-- Body type

function MovingBehavior.handlers:bodyTypeComponent(component)
    return "dynamic"
end

-- Component management

function MovingBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

-- Responses

MovingBehavior.responses["add velocity"] = {
    description = "Adjust velocity (legacy)",
    migrate = function(self, actorId, response)
       local rules = self.game.behaviorsByName.Rules
       response.behaviorId = rules.behaviorId
       response.name = 'change behavior property'
       response.params = {
          behaviorId = self.behaviorId,
          propertyName = 'vx',
          value = response.params.x,
          nextResponse = {
             behaviorId = rules.behaviorId,
             name = 'change behavior property',
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
       response.name = 'change behavior property'
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

MovingBehavior.responses["move toward actor"] = {
   description = "Move toward another actor (dynamic motion)",
   category = "motion",
   paramSpecs = {
      tag = {
         method = "textInput",
         label = "Tag",
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
      
      local closestActorId, minDistance, targetX, targetY = nil, math.huge, 0, 0
      for otherActorId, actor in pairs(self.game.actors) do
         if otherActorId ~= actorId
         and ((not params.tag or params.tag == '') or self.game.behaviorsByName.Tags:actorHasTag(otherActorId, params.tag)) then
            local members = self.game.behaviorsByName.Body:getMembers(otherActorId)
            if members.body then
               local otherX, otherY = members.body:getPosition()
               local dx, dy = otherX - x, otherY - y
               local dist = math.sqrt(dx * dx + dy * dy)
               if dist < minDistance then
                  minDistance = dist
                  closestActorId = otherActorId
                  targetX = otherX
                  targetY = otherY
               end
            end
         end
      end

      if members.body and closestActorId ~= nil then
         local m = members.body:getMass()
         local angle = math.atan2(targetY - y, targetX - x)
         members.body:applyLinearImpulse(m * params.speed * math.cos(angle), m * params.speed * math.sin(angle))
      end
   end
}

function MovingBehavior.getters:vx(component)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   local vx, vy = members.body:getLinearVelocity()
   return vx
end

function MovingBehavior.getters:vy(component)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   local vx, vy = members.body:getLinearVelocity()
   return vy
end

function MovingBehavior.getters:angularVelocity(component)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   return members.body:getAngularVelocity() * 180 / math.pi
end

function MovingBehavior.setters:vx(component, value)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   local vx, vy = members.body:getLinearVelocity()
   members.physics:setLinearVelocity(members.bodyId, value, vy)
end

function MovingBehavior.setters:vy(component, value)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   local vx, vy = members.body:getLinearVelocity()
   members.physics:setLinearVelocity(members.bodyId, vx, value)
end

function MovingBehavior.setters:angularVelocity(component, value)
   local actorId = component.actorId
   local members = self.dependencies.Body:getMembers(actorId)
   members.physics:setAngularVelocity(members.bodyId, value * math.pi / 180)
end
