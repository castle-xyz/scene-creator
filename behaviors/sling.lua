local SlingBehavior = {
    name = 'Sling',
    displayName = 'sling',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(SlingBehavior)


local MAX_SPEED = 3 * UNIT

local SPEED_MULTIPLIER = 3.2
local DRAW_MULTIPLIER = 0.8

local CIRCLE_RADIUS = 18 * UNIT
local TRIANGLE_LENGTH = 25 * UNIT
local TRIANGLE_WIDTH = 10 * UNIT


-- Body type

function SlingBehavior.handlers:bodyTypeComponent(component)
    return 'dynamic'
end


-- Perform

function SlingBehavior.handlers:perform(dt)
    if not self.game.clientId then
        return
    end

    local physics = self.dependencies.Body:getPhysics()

    -- Make our bodies owned by us
    for actorId, component in pairs(self.components) do
        local bodyId, body = self.dependencies.Body:getBody(actorId)
        if physics:getOwner(bodyId) ~= self.game.clientId then
            physics:setOwner(bodyId, self.game.clientId, true, 0)
        end
    end

    local touchData = self:getTouchData()
    if touchData.maxNumTouches == 1 and touchData.allTouchesReleased then
        local touchId, touch = next(touchData.touches)

        local vX, vY = touch.initialX - touch.x, touch.initialY - touch.y
        local vLen = math.sqrt(vX * vX + vY * vY)
        if vLen > MAX_SPEED then
            vX, vY = vX * MAX_SPEED / vLen, vY * MAX_SPEED / vLen
            vLen = MAX_SPEED
        end

        for actorId, component in pairs(self.components) do
            -- We own the body, so just set velocity locally and the physics system will sync it
            local bodyId, body = self.dependencies.Body:getBody(actorId)
            body:setLinearVelocity(SPEED_MULTIPLIER * vX, SPEED_MULTIPLIER * vY)
        end
    end
end


-- Draw

function SlingBehavior.handlers:drawOverlay()
    if not self.game.performing then
        return
    end

    -- Look for a single-finger drag
    local touchData = self:getTouchData()
    if touchData.maxNumTouches == 1 then
        local touchId, touch = next(touchData.touches)

        local vX, vY = touch.initialX - touch.x, touch.initialY - touch.y
        local vLen = math.sqrt(vX * vX + vY * vY)
        if vLen > 0 then
            if vLen > MAX_SPEED then
                vX, vY = vX * MAX_SPEED / vLen, vY * MAX_SPEED / vLen
                vLen = MAX_SPEED
            end

            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.setLineWidth(1.25 * self.game:getPixelScale())

            local circleRadius = CIRCLE_RADIUS * self.game:getPixelScale()
            local triangleLength = TRIANGLE_LENGTH * self.game:getPixelScale()
            local triangleWidth = TRIANGLE_WIDTH * self.game:getPixelScale()

            -- Circle with solid outline and transparent fill
            love.graphics.circle('line', touch.initialX, touch.initialY, circleRadius)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.circle('fill', touch.initialX, touch.initialY, circleRadius)
            love.graphics.setColor(1, 1, 1, 0.8)

            -- Line and triangle
            local endX, endY = touch.initialX + DRAW_MULTIPLIER * vX, touch.initialY + DRAW_MULTIPLIER * vY
            love.graphics.line(
                touch.initialX, touch.initialY,
                endX - triangleLength * vX / vLen, endY - triangleLength * vY / vLen)
            love.graphics.polygon('fill',
                endX, endY,
                endX - triangleLength * vX / vLen - triangleWidth * vY / vLen,
                endY - triangleLength * vY / vLen + triangleWidth * vX / vLen,
                endX - triangleLength * vX / vLen + triangleWidth * vY / vLen,
                endY - triangleLength * vY / vLen - triangleWidth * vX / vLen)
        end
    end
end


-- UI

function SlingBehavior.handlers:uiComponent(component, opts)
end

