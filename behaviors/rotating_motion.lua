local RotatingMotionBehavior = {
    name = 'RotatingMotion',
    displayName = 'rotating motion',
    propertyNames = {
        'rotationsPerSecond',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
    description = [[
Rotates the actor's body continuously.
]],
}

registerCoreBehavior(4, RotatingMotionBehavior)


-- Body type

function RotatingMotionBehavior.handlers:bodyTypeComponent(component)
    return 'kinematic'
end


-- Component management

function RotatingMotionBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rotationsPerSecond = bp.rotationsPerSecond or 1
end

function RotatingMotionBehavior.handlers:blueprintComponent(component, bp)
    bp.rotationsPerSecond = component.properties.rotationsPerSecond
end


-- Perform

function RotatingMotionBehavior.handlers:perform(dt)
    for actorId, component in pairs(self.components) do
        local bodyId, body = self.dependencies.Body:getBody(actorId)

        -- Physics bodies are automatically synced by the server, so just set locally
        body:setAngularVelocity(2 * math.pi * component.properties.rotationsPerSecond)
    end
end


-- UI

function RotatingMotionBehavior.handlers:uiComponent(component, opts)
    ui.numberInput('rotations per second', component.properties.rotationsPerSecond, {
        onChange = function(newRotationsPerSecond)
            self:sendSetProperties(component.actorId, 'rotationsPerSecond', newRotationsPerSecond)
        end,
    })
end



