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
       },
       vy = {
          method = 'numberInput',
          label = 'velocity y',
       },
       angularVelocity = {
          method = 'numberInput',
          label = 'rotation speed (degrees)',
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
    description = [[
Changes the actor's velocity by the given amount.
    ]],
    initialParams = {
        x = 0,
        y = -3
    },
    uiBody = function(self, params, onChangeParam)
        util.uiRow(
            "velocity",
            function()
                ui.numberInput(
                    "added velocity x",
                    params.x,
                    {
                        onChange = function(newX)
                            onChangeParam("change add velocity x", "x", newX)
                        end
                    }
                )
            end,
            function()
                ui.numberInput(
                    "added velocity y",
                    params.y,
                    {
                        onChange = function(newY)
                            onChangeParam("change add velocity y", "y", newY)
                        end
                    }
                )
            end
        )
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
    description = [[
Changes the actor's rotation speed by the given amount.
    ]],
    initialParams = {
        speed = 20
    },
    uiBody = function(self, params, onChangeParam)
        ui.numberInput(
            "added rotation speed (degrees per second)",
            params.speed,
            {
                step = 20,
                onChange = function(newSpeed)
                    onChangeParam("change add rotation speed", "speed", newSpeed)
                end
            }
        )
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
    description = [[
Sets the actor's velocity to the given value.
    ]],
    initialParams = {
        x = 0,
        y = -3
    },
    uiBody = function(self, params, onChangeParam)
        util.uiRow(
            "velocity",
            function()
                ui.numberInput(
                    "velocity x",
                    params.x,
                    {
                        onChange = function(newX)
                            onChangeParam("change set velocity x", "x", newX)
                        end
                    }
                )
            end,
            function()
                ui.numberInput(
                    "velocity y",
                    params.y,
                    {
                        onChange = function(newY)
                            onChangeParam("change set velocity y", "y", newY)
                        end
                    }
                )
            end
        )
    end,
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            body:setLinearVelocity(params.x, params.y)
        end
    end
}

MovingBehavior.responses["set rotation speed"] = {
    description = [[
Sets the actor's rotation speed to the given value.
    ]],
    initialParams = {
        speed = 20
    },
    uiBody = function(self, params, onChangeParam)
        ui.numberInput(
            "rotation speed (degrees per second)",
            params.speed,
            {
                step = 20,
                onChange = function(newSpeed)
                    onChangeParam("change set rotation speed", "speed", newSpeed)
                end
            }
        )
    end,
    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
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
