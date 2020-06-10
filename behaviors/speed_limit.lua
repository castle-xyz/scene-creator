local SpeedLimitBehavior =
    defineCoreBehavior {
    name = "SpeedLimit",
    displayName = "speed limit",
    propertyNames = {
        "maximumSpeed"
    },
    dependencies = {
        "Body"
    },
    propertySpecs = {
       maximumSpeed = {
          method = 'numberInput',
          label = 'maximum speed (units per second)',
          props = { min = 0.1 },
       },
    },
}

-- Component management

function SpeedLimitBehavior.handlers:addComponent(component, bp, opts)
    component.properties.maximumSpeed = bp.maximumSpeed or 1
end

function SpeedLimitBehavior.handlers:blueprintComponent(component, bp)
    bp.maximumSpeed = component.properties.maximumSpeed
end

-- Perform

function SpeedLimitBehavior.handlers:perform(dt)
    for actorId, component in pairs(self.components) do
        local bodyId, body = self.dependencies.Body:getBody(actorId)

        local maximumSpeed = component.properties.maximumSpeed
        local maximumSpeedSquared = maximumSpeed * maximumSpeed

        -- Physics bodies are automatically synced by the server, so just set locally
        local vx, vy = body:getLinearVelocity()
        local speedSquared = vx * vx + vy * vy
        if speedSquared > maximumSpeedSquared then
            -- Box2D uses the equation (from b2Island.cpp, `h` is `dt`):
            --   v *= 1.0f / (1.0f + h * b->m_linearDamping);
            -- We solve for the damping that reduces us to the maximum speed in one update:
            --   d = (v / newV - 1) / h
            local speed = math.sqrt(speedSquared)
            body:setLinearDamping((speed / maximumSpeed - 1) / dt)
        else
            body:setLinearDamping(0)
        end
    end
end

-- UI

function SpeedLimitBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiProperty(
        "numberInput",
        "maximum speed (units per second)",
        actorId,
        "maximumSpeed",
        {
            props = {min = 0.1}
        }
    )
end
