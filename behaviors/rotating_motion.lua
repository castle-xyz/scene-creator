local RotatingMotionBehavior = {
    name = 'RotatingMotion',
    displayName = 'rotating motion',
    propertyNames = {
        'rotationSpeed',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(4, RotatingMotionBehavior)


-- Body type

function RotatingMotionBehavior.handlers:bodyTypeComponent(component)
    return 'kinematic'
end


-- Component management

function RotatingMotionBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rotationSpeed = bp.rotationSpeed or 80
end

function RotatingMotionBehavior.handlers:blueprintComponent(component, bp)
    bp.rotationSpeed = component.properties.rotationSpeed
end


-- Perform

function RotatingMotionBehavior.handlers:perform(dt)
    for actorId, component in pairs(self.components) do
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        body:setAngularVelocity(component.properties.rotationSpeed) -- Only set locally -- server syncs everyone
        component.properties.rotationSpeed = body:getAngularVelocity() -- Account for floating point precision differences
    end
end


-- UI

function RotatingMotionBehavior.handlers:uiComponent(component, opts)
    ui.numberInput('rotation speed (degrees per second)', component.properties.rotationSpeed * 180 / math.pi, {
        onChange = function(newRotationSpeed)
            self:sendSetProperties(component.actorId, 'rotationSpeed', newRotationSpeed * math.pi / 180)
        end,
    })
end



