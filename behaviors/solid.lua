local SolidBehavior = {
    name = 'Solid',
    displayName = 'solid',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(SolidBehavior)


-- Utilities

local function wakeBodyAndColliders(body)
    body:setAwake(true)
    for _, contact in ipairs(body:getContacts()) do
        local f1, f2 = contact:getFixtures()
        local b1, b2 = f1:getBody(), f2:getBody()
        local otherBody = body == b1 and b2 or b1
        otherBody:setAwake(true)
    end
end


-- Component management

function SolidBehavior.handlers:addComponent(component, bp, opts)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixture = body:getFixtures()[1]
    if fixture then
        fixture:setSensor(false)
        wakeBodyAndColliders(body)
    end
end

function SolidBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixture = body:getFixtures()[1]
        if fixture then
            fixture:setSensor(true)
            wakeBodyAndColliders(body)
        end
    end
end


-- UI

function SolidBehavior.handlers:uiComponent(component, opts)
    local physics = self.dependencies.Body:getPhysics()
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixture = body:getFixtures()[1]
    if fixture then
        local fixtureId = physics:idForObject(fixture)

        ui.numberInput('bounciness', fixture:getRestitution(), {
            step = 0.05,
            onChange = function(newBounciness)
                physics:setRestitution(fixtureId, newBounciness)
            end,
        })

        ui.numberInput('friction', fixture:getFriction(), {
            step = 0.05,
            onChange = function(newFriction)
                physics:setFriction(fixtureId, newFriction)
            end,
        })
    end
end


