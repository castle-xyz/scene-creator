local FallingBehavior =
    defineCoreBehavior {
    name = "Falling",
    displayName = "falling",
    propertyNames = {},
    dependencies = {
        "Moving",
        "Body"
    }
}

-- Body type

function FallingBehavior.handlers:bodyTypeComponent(component)
    return "dynamic"
end

-- Component management

function FallingBehavior.handlers:addComponent(component, bp, opts)
    if opts.interactive then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setGravityScale(1)
    end
end

function FallingBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setGravityScale(0)
    end
end

-- UI

function FallingBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId
    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)

    self:uiValue(
        "numberInput",
        "gravity",
        body:getGravityScale(),
        {
            props = {step = 0.5, min = 0},
            onChange = function(params)
                local physics, bodyId, body = self.dependencies.Body:getMembers(actorId)
                physics:setGravityScale(bodyId, params.value)
            end
        }
    )
end
