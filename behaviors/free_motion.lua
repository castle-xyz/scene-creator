local FreeMotionBehavior = {
    name = 'FreeMotion',
    displayName = 'free motion',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(FreeMotionBehavior)


-- Body type

function FreeMotionBehavior.handlers:bodyTypeComponent(component)
    return 'dynamic'
end


-- Component management

function FreeMotionBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end


-- UI

function FreeMotionBehavior.handlers:uiComponent(component, opts)
    local physics = self.dependencies.Body:getPhysics()
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixture = body:getFixtures()[1]
    local fixtureId = fixture and physics:idForObject(fixture)

    -- Density and gravity
    util.uiRow('density and gravity', function()
        if fixture then
            ui.numberInput('density', fixture:getDensity(), {
                onChange = function(newDensity)
                    physics:setDensity(fixtureId, newDensity)
                    physics:resetMassData(bodyId)
                end,
            })
        end
    end, function()
        ui.numberInput('gravity', body:getGravityScale(), {
            onChange = function(newGravityScale)
                physics:setGravityScale(bodyId, newGravityScale)
            end,
        })
    end)

    -- Linear velocity
    local vx, vy = body:getLinearVelocity()
    util.uiRow('linear velocity', function()
        ui.numberInput('velocity x', vx, {
            onChange = function(newVX)
                physics:setLinearVelocity(bodyId, newVX, vy)
            end,
        })
    end, function()
        ui.numberInput('velocity y', vy, {
            onChange = function(newVY)
                physics:setLinearVelocity(bodyId, vx, newVY)
            end,
        })
    end)

    -- Fixed rotation / angular velocity
    local isFixedRotation = body:isFixedRotation()
    local function fixedRotationToggle()
        ui.toggle('fixed rotation off', 'fixed rotation on', isFixedRotation, {
            onToggle = function(newFixedRotation)
                physics:setFixedRotation(bodyId, newFixedRotation)
            end,
        })
    end
    if isFixedRotation then
        fixedRotationToggle()
    else
        util.uiRow('rotation speed and fixed rotation', function()
            ui.numberInput('rotation speed (degrees)', body:getAngularVelocity() * 180 / math.pi, {
                onChange = function(newAV)
                    physics:setAngularVelocity(bodyId, newAV * math.pi / 180)
                end,
            })
        end, fixedRotationToggle)
    end

    -- Damping
    util.uiRow('damping', function()
        ui.numberInput('linear damping', body:getLinearDamping(), {
            step = 0.05,
            onChange = function(newLinearDamping)
                physics:setLinearDamping(bodyId, newLinearDamping)
            end,
        })
    end, function()
        ui.numberInput('angular damping', body:getAngularDamping(), {
            step = 0.05,
            onChange = function(newAngularDamping)
                physics:setAngularDamping(bodyId, newAngularDamping)
            end,
        })
    end)
end



