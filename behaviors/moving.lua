local MovingBehavior =
    defineCoreBehavior {
    name = "Moving",
    displayName = "Dynamic Motion",
    propertyNames = { "vx", "vy", "angularVelocity" },
    dependencies = {
        "Body"
    },
    propertySpecs = {
       vx = {
          method = 'numberInput',
          label = 'velocity x',
          rules = {
             set = true,
          },
       },
       vy = {
          method = 'numberInput',
          label = 'velocity y',
          rules = {
             set = true,
          },
       },
       angularVelocity = {
          method = 'numberInput',
          label = 'rotation speed (degrees)',
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

function MovingBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

-- Responses

MovingBehavior.responses["add velocity"] = {
    description = "Adjust velocity",
    paramSpecs = {
       x = {
          method = "numberInput",
          initialValue = 0,
       },
       y = {
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        x = 0,
        y = 0
    },
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            local m = body:getMass()
            body:applyLinearImpulse(m * params.x, m * params.y)
        end
    end
}

MovingBehavior.responses["add rotation speed"] = {
    description = "Adjust rotation speed",
    paramSpecs = {
       speed = {
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        speed = 0
    },
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            local I = body:getInertia()
            body:applyAngularImpulse(I * params.speed * math.pi / 180)
        end
    end
}

MovingBehavior.responses["set velocity"] = {
    description = "Set velocity",
    paramSpecs = {
       x = {
          method = "numberInput",
          initialValue = 0,
       },
       y = {
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        x = 0,
        y = 0
    },
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            body:setLinearVelocity(params.x, params.y)
        end
    end
}

MovingBehavior.responses["set rotation speed"] = {
    description = "Set rotation speed",
    paramSpecs = {
       speed = {
          label = "rotation speed",
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        speed = 0
    },
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            -- degrees per second
            body:setAngularVelocity(params.speed * math.pi / 180)
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
