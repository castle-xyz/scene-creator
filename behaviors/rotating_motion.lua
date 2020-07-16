local RotatingMotionBehavior = defineCoreBehavior {
    name = "RotatingMotion",
    displayName = "Fixed Motion",
    propertyNames = {
       "vx", "vy",
        "rotationsPerSecond"
    },
    dependencies = {
        "Body"
    },
    propertySpecs = {
       vx = {
          method = 'numberInput',
          label = 'Velocity X',
          rules = {
             set = true,
          },
       },
       vy = {
          method = 'numberInput',
          label = 'Velocity Y',
          rules = {
             set = true,
          },
       },
       rotationsPerSecond = {
          method = 'numberInput',
          label = 'Rotations per second',
          rules = {
             set = true,
          },
       },
    },
}

-- Body type

function RotatingMotionBehavior.handlers:bodyTypeComponent(component)
    return "kinematic"
end

-- Component management

function RotatingMotionBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rotationsPerSecond = bp.rotationsPerSecond or 0
    component.properties.vx = bp.vx or 0
    component.properties.vy = bp.vy or 0
end

function RotatingMotionBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

function RotatingMotionBehavior.handlers:blueprintComponent(component, bp)
    bp.rotationsPerSecond = component.properties.rotationsPerSecond
    bp.vx = component.properties.vx
    bp.vy = component.properties.vy
end

-- Perform

function RotatingMotionBehavior.handlers:perform(dt)
    for actorId, component in pairs(self.components) do
        local bodyId, body = self.dependencies.Body:getBody(actorId)

        -- Physics bodies are automatically synced by the server, so just set locally
        body:setLinearVelocity(component.properties.vx, component.properties.vy)
        body:setAngularVelocity(2 * math.pi * component.properties.rotationsPerSecond)
    end
end
