local FrictionBehavior = defineCoreBehavior {
    name = 'Friction',
    displayName = 'friction',
    propertyNames = {
        'movingFriction',
        'rotatingFriction',
    },
    dependencies = {
        'Body',
    },
    setters = {},
}


-- Methods

function FrictionBehavior:updateJoint(component)
    if not component._joint then
        local groundBodyId, groundBody = self.dependencies.Body:getGroundBody()
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local x, y = body:getPosition()
        component._joint = love.physics.newFrictionJoint(groundBody, body, x, y)
    end
    component._joint:setMaxForce(math.max(0.01, component.properties.movingFriction))
    component._joint:setMaxTorque(math.max(0.01, component.properties.rotatingFriction))
end


-- Setters

function FrictionBehavior.setters:movingFriction(component, newMovingFriction)
    if component.properties.movingFriction ~= newMovingFriction then
        component.properties.movingFriction = newMovingFriction
        self:updateJoint(component)
    end
end

function FrictionBehavior.setters:rotatingFriction(component, newRotatingFriction)
    if component.properties.rotatingFriction ~= newRotatingFriction then
        component.properties.rotatingFriction = newRotatingFriction
        self:updateJoint(component)
    end
end


-- Component management

function FrictionBehavior.handlers:addComponent(component, bp, opts)
    component.properties.movingFriction = bp.movingFriction or 10
    component.properties.rotatingFriction = bp.rotatingFriction or 10
    self:updateJoint(component)
end

function FrictionBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        if component._joint then
            component._joint:destroy()
        end
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixture = body:getFixtures()[1]
        if fixture then
            fixture:setFriction(0)
        end
    end
end

function FrictionBehavior.handlers:blueprintComponent(component, bp)
    bp.movingFriction = component.properties.movingFriction
    bp.rotatingFriction = component.properties.rotatingFriction
end


-- Setting performing

function FrictionBehavior.handlers:setPerforming(newPerforming)
    -- Bodies may have moved -- recreate joints
    if newPerforming then
        for actorId, component in pairs(self.components) do
            self:updateJoint(component)
        end
    end
end


-- UI

function FrictionBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiProperty('numberInput', 'moving friction', actorId, 'movingFriction', {
        props = { min = 0 },
    })

    self:uiProperty('numberInput', 'rotating friction', actorId, 'rotatingFriction', {
        props = { min = 0 },
    })

    local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
    if fixture then
        self:uiValue('numberInput', 'rubbing friction', fixture:getFriction(), {
            props = { step = 0.05, min = 0 },
            onChange = function(params)
                local physics, bodyId, body, fixtureId, fixture = self.dependencies.Body:getMembers(actorId)
                physics:setFriction(fixtureId, params.value)
            end,
        })
    end
end
