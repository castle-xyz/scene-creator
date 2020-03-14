local FrictionBehavior = {
    name = 'Friction',
    displayName = 'friction',
    propertyNames = {
    },
    dependencies = {
        'Solid',
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(FrictionBehavior)


-- Component management

function FrictionBehavior.handlers:addComponent(component, bp, opts)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixture = body:getFixtures()[1]
    if fixture then
        fixture:setSensor(false)
        wakeBodyAndColliders(body)
    end
end

function FrictionBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixture = body:getFixtures()[1]
        if fixture then
            fixture:setRestitution(0)
        end
    end
end


-- UI

function FrictionBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId
    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
    if fixture then
        self:uiValue('numberInput', 'sliding friction', fixture:getFriction(), {
            props = { step = 0.05 },
            onChange = function(params)
                local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
                physics:setFriction(fixtureId, params.value)
            end,
        })
    end
end


