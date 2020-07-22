local SolidBehavior =
    defineCoreBehavior {
    name = "Solid",
    displayName = "Solid",
    allowsDisableWithoutRemoval = true,
    dependencies = {
        "Body"
    }
}

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

function SolidBehavior.handlers:enableComponent(component, opts)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixtures = body:getFixtures()
    for _, fixture in pairs(fixtures) do
        fixture:setSensor(false)
        wakeBodyAndColliders(body)
    end
end

function SolidBehavior.handlers:disableComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setSensor(true)
            wakeBodyAndColliders(body)
        end
    end
end

function SolidBehavior.handlers:updateComponentFixture(component, fixtureId)
   local members = self.dependencies.Body:getMembers(actorId)
   members.physics:setSensor(fixtureId, not (not component.disabled))
end

function SolidBehavior.handlers:blueprintFixture(component, fixture, fixtureBp)
   fixtureBp.sensor = fixture:isSensor()
end
