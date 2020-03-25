local MovingBehavior = defineCoreBehavior {
    name = 'Moving',
    displayName = 'moving',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
}


-- Body type

function MovingBehavior.handlers:bodyTypeComponent(component)
    return 'dynamic'
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

MovingBehavior.responses['add velocity'] = {
    description = [[
Changes the actor's velocity by the given amount.
    ]],

    initialParams = {
        x = 0,
        y = -3,
    },

    uiBody = function(self, params, onChangeParam)
        util.uiRow('velocity', function()
            ui.numberInput('added velocity x', params.x, {
                onChange = function(newX)
                    onChangeParam('x', newX)
                end,
            })
        end, function()
            ui.numberInput('added velocity y', params.y, {
                onChange = function(newY)
                    onChangeParam('y', newY)
                end,
            })
        end)
    end,

    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            local m = body:getMass()
            body:applyLinearImpulse(m * params.x, m * params.y)
        end
    end,
}

MovingBehavior.responses['add rotation speed'] = {
    description = [[
Changes the actor's rotation speed by the given amount.
    ]],

    initialParams = {
        speed = 20,
    },

    uiBody = function(self, params, onChangeParam)
        ui.numberInput('added rotation speed (degrees per second)', params.speed, {
            step = 20,
            onChange = function(newSpeed)
                onChangeParam('speed', newSpeed)
            end,
        })
    end,

    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            local I = body:getInertia()
            body:applyAngularImpulse(I * params.speed * math.pi / 180)
        end
    end,
}

MovingBehavior.responses['set velocity'] = {
    description = [[
Sets the actor's velocity to the given value.
    ]],

    initialParams = {
        x = 0,
        y = -3,
    },

    uiBody = function(self, params, onChangeParam)
        util.uiRow('velocity', function()
            ui.numberInput('velocity x', params.x, {
                onChange = function(newX)
                    onChangeParam('x', newX)
                end,
            })
        end, function()
            ui.numberInput('velocity y', params.y, {
                onChange = function(newY)
                    onChangeParam('y', newY)
                end,
            })
        end)
    end,

    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            body:setLinearVelocity(params.x, params.y)
        end
    end,
}

MovingBehavior.responses['set rotation speed'] = {
    description = [[
Sets the actor's rotation speed to the given value.
    ]],

    initialParams = {
        speed = 20,
    },

    uiBody = function(self, params, onChangeParam)
        ui.numberInput('rotation speed (degrees per second)', params.speed, {
            step = 20,
            onChange = function(newSpeed)
                onChangeParam('speed', newSpeed)
            end,
        })
    end,

    run = function(self, actorId, params, context)
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if body then
            body:setAngularVelocity(params.speed * math.pi / 180)
        end
    end,
}


-- UI

function MovingBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId
    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)

    -- Density and gravity
    --util.uiRow('density and gravity', function()
    --    if fixture then
    --        self:uiValue('numberInput', 'density', fixture:getDensity(), {
    --            onChange = function(params)
    --                local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
    --                if fixtureId then
    --                    physics:setDensity(fixtureId, params.value)
    --                    physics:resetMassData(bodyId)
    --                end
    --            end,
    --        })
    --    end
    --end, function()
    --    self:uiValue('numberInput', 'gravity', body:getGravityScale(), {
    --        onChange = function(params)
    --            local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
    --            physics:setGravityScale(bodyId, params.value)
    --        end,
    --    })
    --end)

    local initialPrefix = not self.performing and 'initial ' or ''

    -- Linear velocity
    local vx, vy = body:getLinearVelocity()
    util.uiRow('linear velocity', function()
        self:uiValue('numberInput', initialPrefix .. 'velocity x', vx, {
            onChange = function(params)
                local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                local vx, vy = body:getLinearVelocity()
                physics:setLinearVelocity(bodyId, params.value, vy)
            end,
        })
    end, function()
        self:uiValue('numberInput', initialPrefix .. 'velocity y', vy, {
            onChange = function(params)
                local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                local vx, vy = body:getLinearVelocity()
                physics:setLinearVelocity(bodyId, vx, params.value)
            end,
        })
    end)

    -- Fixed rotation / angular velocity
    local isFixedRotation = body:isFixedRotation()
    local function fixedRotationToggle()
        self:uiValue('toggle', 'allow rotation', not isFixedRotation, {
            onChange = function(params)
                local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                physics:setFixedRotation(bodyId, not params.value)
            end,
        })
    end
    if isFixedRotation then
        fixedRotationToggle()
    else
        util.uiRow('rotation speed and fixed rotation',
            fixedRotationToggle, function()
            self:uiValue('numberInput',
                initialPrefix .. 'rotation speed (degrees)',
                body:getAngularVelocity() * 180 / math.pi, {
                onChange = function(params)
                    local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                    physics:setAngularVelocity(bodyId, params.value * math.pi / 180)
                end,
            })
        end)
    end

    -- Damping
    --util.uiRow('damping', function()
    --    self:uiValue('numberInput', 'linear damping', body:getLinearDamping(), {
    --        props = { step = 0.05 },
    --        onChange = function(params)
    --            local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
    --            physics:setLinearDamping(bodyId, params.value)
    --        end,
    --    })
    --end, function()
    --    self:uiValue('numberInput', 'angular damping', body:getAngularDamping(), {
    --        props = { step = 0.05 },
    --        onChange = function(params)
    --            local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
    --            physics:setAngularDamping(bodyId, params.value)
    --        end,
    --    })
    --end)
end



