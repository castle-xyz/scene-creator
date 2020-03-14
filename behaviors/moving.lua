local MovingBehavior = {
    name = 'Moving',
    displayName = 'moving',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(MovingBehavior)


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

    -- Linear velocity
    local vx, vy = body:getLinearVelocity()
    util.uiRow('linear velocity', function()
        self:uiValue('numberInput', 'velocity x', vx, {
            onChange = function(params)
                local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                local vx, vy = body:getLinearVelocity()
                physics:setLinearVelocity(bodyId, params.value, vy)
            end,
        })
    end, function()
        self:uiValue('numberInput', 'velocity y', vy, {
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
        self:uiValue('toggle', 'fixed rotation', isFixedRotation, {
            onChange = function(params)
                local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                physics:setFixedRotation(bodyId, params.value)
            end,
        })
    end
    if isFixedRotation then
        fixedRotationToggle()
    else
        util.uiRow('rotation speed and fixed rotation', function()
            self:uiValue('numberInput', 'rotation speed (degrees)', body:getAngularVelocity() * 180 / math.pi, {
                onChange = function(params)
                    local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                    physics:setAngularVelocity(bodyId, params.value * math.pi / 180)
                end,
            })
        end, fixedRotationToggle)
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



