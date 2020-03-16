local SlidingBehavior = {
    name = 'Sliding',
    displayName = 'sliding',
    propertyNames = {
        'direction',
        'distance',
    },
    dependencies = {
        'Moving',
        'Body',
    },
    handlers = {},
    setters = {},
}

registerCoreBehavior(SlidingBehavior)


-- Methods

function SlidingBehavior:updateJoint(component)
    if component._joint then
        component._joint:destroy()
    end

    local ax, ay
    local direction = component.properties.direction
    if direction == 'horizontal' then
        ax, ay = 1, 0
    elseif direction == 'vertical' then
        ax, ay = 0, 1
    end

    if ax and ay then
        local groundBodyId, groundBody = self.dependencies.Body:getGroundBody()
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local x, y = body:getPosition()
        component._joint = love.physics.newPrismaticJoint(groundBody, body, x, y, ax, ay)
        component._joint:setLimits(-component.properties.distance, component.properties.distance)
    end
end


-- Setters

function SlidingBehavior.setters:direction(component, newLimitType)
    if component.properties.direction ~= newLimitType then
        component.properties.direction = newLimitType
        self:updateJoint(component)
    end
end

function SlidingBehavior.setters:distance(component, newDistance)
    if component.properties.distance ~= newDistance then
        component.properties.distance = newDistance
        self:updateJoint(component)
    end
end


-- Component management

function SlidingBehavior.handlers:addComponent(component, bp, opts)
    component.properties.direction = bp.direction or 'horizontal'
    component.properties.distance = bp.distance or 2
    self:updateJoint(component)
end

function SlidingBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        if component._joint then
            component._joint:destroy()
        end
    end
end

function SlidingBehavior.handlers:blueprintComponent(component, bp)
    bp.direction = component.properties.direction
    bp.distance = component.properties.distance
end


-- Setting performing

function SlidingBehavior.handlers:setPerforming(newPerforming)
    -- Bodies may have moved -- recreate joints
    if newPerforming then
        for actorId, component in pairs(self.components) do
            self:updateJoint(component)
        end
    end
end


-- UI

function SlidingBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiValue('dropdown', 'direction', component.properties.direction, {
        props = { items = { 'horizontal', 'vertical' } },
        onChange = function(params)
            if params.value then
                self:sendSetProperties(actorId, 'direction', params.value)
            end
        end,
    })

    self:uiValue('numberInput', 'maximum distance', component.properties.distance, {
        props = { min = 0, max = 20 },
        onChange = function(params)
            self:sendSetProperties(actorId, 'distance', params.value)
        end,
    })
end
