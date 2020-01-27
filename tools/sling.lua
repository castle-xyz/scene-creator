local SlingTool = {
    name = 'Sling',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
    tool = {
        icon = 'racquetball',
        iconFamily = 'MaterialCommunityIcons',
        needsPerformingOn = true,
    },
}

registerCoreBehavior(SlingTool)


local MAX_SPEED = 8 * UNIT

local SPEED_MULTIPLIER = 2
local DRAW_MULTIPLIER = 0.6

local CIRCLE_RADIUS = 0.25 * UNIT
local TRIANGLE_LENGTH = 0.25 * UNIT
local TRIANGLE_WIDTH = 0.1 * UNIT


-- Body ownership

function SlingTool.handlers:bodyOwnershipComponent(component)
    return true, 0
end


-- Update

function SlingTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end

    -- Steal all touches
    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        touch.used = true
    end
end

function SlingTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    -- Look for a single-finger drag and release
    local touchData = self:getTouchData()
    if touchData.maxNumTouches == 1 and touchData.allTouchesReleased then
        local touchId, touch = next(touchData.touches)

        local vX, vY = touch.initialX - touch.x, touch.initialY - touch.y
        if vX == 0 and vY == 0 then -- Release without moving touch? Just select.
            self.game:selectActorAtTouch(touch)
        else -- Moved and released -- apply velocity
            local vLen = math.sqrt(vX * vX + vY * vY)
            if vLen > MAX_SPEED then
                vX, vY = vX * MAX_SPEED / vLen, vY * MAX_SPEED / vLen
            end

            local physics = self.dependencies.Body:getPhysics()

            for actorId, component in pairs(self.components) do
                if self.game.clientId == component.clientId then
                    -- We own the body, so just set velocity locally and the physics system will sync it
                    local bodyId, body = self.dependencies.Body:getBody(actorId)
                    body:setLinearVelocity(SPEED_MULTIPLIER * vX, SPEED_MULTIPLIER * vY)
                end
            end
        end
    end
end


-- Draw

function SlingTool.handlers:drawOverlay(dt)
    if not self:isActive() then
        return
    end

    -- Look for a single-finger drag
    local touchData = self:getTouchData()
    if touchData.numTouches == 1 then
        local touchId, touch = next(touchData.touches)

        local vX, vY = touch.initialX - touch.x, touch.initialY - touch.y
        local vLen = math.sqrt(vX * vX + vY * vY)
        if vLen > 0 then
            if vLen > MAX_SPEED then
                vX, vY = vX * MAX_SPEED / vLen, vY * MAX_SPEED / vLen
            end

            -- Circle with solid outline and transparent fill
            love.graphics.circle('line', touch.initialX, touch.initialY, CIRCLE_RADIUS)
            local r, g, b, a = love.graphics.getColor()
            love.graphics.setColor(r, g, b, 0.5 * a)
            love.graphics.circle('fill', touch.initialX, touch.initialY, CIRCLE_RADIUS)
            love.graphics.setColor(r, g, b, a)

            -- Line and triangle
            local endX, endY = touch.initialX + DRAW_MULTIPLIER * vX, touch.initialY + DRAW_MULTIPLIER * vY
            love.graphics.line(
                touch.initialX, touch.initialY,
                endX - TRIANGLE_LENGTH * vX / vLen, endY - TRIANGLE_LENGTH * vY / vLen)
            love.graphics.polygon('fill',
                endX, endY,
                endX - TRIANGLE_LENGTH * vX / vLen - TRIANGLE_WIDTH * vY / vLen,
                endY - TRIANGLE_LENGTH * vY / vLen + TRIANGLE_WIDTH * vX / vLen,
                endX - TRIANGLE_LENGTH * vX / vLen + TRIANGLE_WIDTH * vY / vLen,
                endY - TRIANGLE_LENGTH * vY / vLen - TRIANGLE_WIDTH * vX / vLen)
        end
    end
end


-- UI

--function SlingTool.handlers:uiSettings(closeSettings)
--end

