local SolidBehavior =
    defineCoreBehavior {
    name = "Solid",
    displayName = "Solid",
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

function SolidBehavior.handlers:addComponent(component, bp, opts)
    local bodyId, body = self.dependencies.Body:getBody(component.actorId)
    local fixtures = body:getFixtures()
    for _, fixture in pairs(fixtures) do
        fixture:setSensor(false)
        wakeBodyAndColliders(body)
    end

   self.dependencies.Body:sendSetProperties(component.actorId, "sensor", false)
end

function SolidBehavior.handlers:removeComponent(component, opts)
    if not opts.removeActor then
        local bodyId, body = self.dependencies.Body:getBody(component.actorId)
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            fixture:setSensor(true)
            wakeBodyAndColliders(body)
        end

        self.dependencies.Body:sendSetProperties(component.actorId, "sensor", true)
    end
end
