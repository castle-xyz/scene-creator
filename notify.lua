local FONT_SIZE = 16
local DEFAULT_NOTIFY_TIME = 3.5
local RECTANGLE_BORDER_RADIUS = 10
local PADDING = 4

function Client:startNotify()
    self.notifyMessage = ''
    self.notifyTime = 0
    self.notifyError = false
end

function Client:updateNotify(dt)
    if self.notifyTime > 0 then
        self.notifyTime = self.notifyTime - dt
        if self.notifyTime <= 0 then
            self:clearNotify()
        end
    end
end

local font
local lastDpiScale

function Client:drawNotify()
    if self.notifyTime <= 0 then
        return
    end

    local dpiScale = love.graphics.getDPIScale()
    if dpiScale ~= lastDpiScale then
        print('dpiScale', dpiScale)
        font = love.graphics.newFont(dpiScale * FONT_SIZE)
        lastDpiScale = dpiScale
    end

    love.graphics.push('all')

    love.graphics.setFont(font)

    local textWidth = font:getWidth(self.notifyMessage)
    local textHeight = font:getHeight()

    local windowWidth, windowHeight = love.graphics.getDimensions()

    love.graphics.origin()

    local rectangleBorderRadius = dpiScale * RECTANGLE_BORDER_RADIUS
    local padding = dpiScale * PADDING

    if notifyError then
        love.graphics.setColor(0.5, 0, 0, 0.7)
    else
        love.graphics.setColor(0, 0, 0, 0.7)
    end
    love.graphics.rectangle(
        'fill',
        0.5 * (windowWidth - textWidth - 2 * rectangleBorderRadius - 2 * padding),
        -rectangleBorderRadius - padding,
        textWidth + 2 * rectangleBorderRadius + 2 * padding,
        textHeight + 2 * rectangleBorderRadius + 2 * padding,
        rectangleBorderRadius)

    --love.graphics.setColor(1, 0, 0)
    --love.graphics.rectangle('fill', 0.5 * (windowWidth - textWidth), padding, textWidth, textHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.notifyMessage, 0.5 * (windowWidth - textWidth), padding)

    love.graphics.pop()
end

function Client:notify(message, time, isError)
    self.notifyMessage = message
    self.notifyTime = time or DEFAULT_NOTIFY_TIME
    if isError ~= nil then
        self.notifyError = isError
    else
        self.notifyError = false
    end
end

function Client:clearNotify()
    self.notifyMessage = ''
    self.notifyTime = 0
    self.notifyError = false
end
