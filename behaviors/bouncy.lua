local BouncyBehavior = {
    name = 'Bouncy',
    displayName = 'bouncy',
    propertyNames = {
    },
    dependencies = {
        'Solid',
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(BouncyBehavior)


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


-- UI

function BouncyBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId
    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
    if fixture then
        self:uiValue('numberInput', 'bounciness', fixture:getRestitution(), {
            props = { step = 0.05 },
            onChange = function(params)
                local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
                physics:setRestitution(fixtureId, params.value)
            end,
        })
    end
end


