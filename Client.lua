-- 'multi' boilerplate
function GET_SERVER_MODULE_NAME()
    return 'Server'
end
Game = require('multi.client', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Start / stop

function Client:start()
    Common.start(self)

    self.photoImages = {}
end


-- Connect / reconnect / disconnect

function Client:connect()
    -- Send `me`
    local me = castle.user.getMe()
    self:send('me', self.clientId, me)
end

function Client:reconnect()
    Common.stop(self)
    Common.start(self)
end


-- Users

function Client.receivers:me(time, clientId, me)
    Common.receivers.me(self, time, clientId, me)

    -- Also load the photo image
    local photoUrl = self.mes[clientId].photoUrl
    if photoUrl then
        network.async(function()
            self.photoImages[clientId] = love.graphics.newImage(photoUrl)
        end)
    end
end


-- Update

function Client:update(dt)
    if not self.connected then
        return
    end

    -- Common update
    Common.update(self, dt)
end


-- Draw

local debugFont = love.graphics.newFont(14)

function Client:draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    do -- Background color
        love.graphics.clear(1, 0.98, 0.98)
    end

    if not self.connected then -- Not connected?
        local peer = self.client.getENetPeer()
        if peer then
            love.graphics.print('connection state: ' .. peer:state(), 22, 2)
        else
            love.graphics.print('initializing...', 22, 2)
        end
        return
    end

    do -- Behaviors
        local order = {}
        self:callHandlers('draw', order)
        table.sort(order, function(o1, o2)
            return o1.depth < o2.depth
        end)
        for _, o in ipairs(order) do
            o.draw()
        end
    end

    do -- Debug overlay
        local networkText = ''
        if self.connected then
            networkText = networkText .. '    ping: ' .. self.client.getPing() .. 'ms'
            networkText = networkText .. '    mem: ' .. math.floor(collectgarbage('count')) .. 'kb'
        end

        love.graphics.setFont(debugFont)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print('fps: ' .. love.timer.getFPS() .. networkText, 16, windowHeight - debugFont:getHeight() - 16)
    end
end


-- Mouse

function Client:mousepressed(x, y, button)
    if not self.connected then
        return
    end

    if button == 1 or button == 2 then
        local worldId, world = self.behaviorsByName.Body:getWorld()

        if world then
            local removedSomething = false

            world:queryBoundingBox(
                x - 1, y - 1, x + 1, y + 1,
                function(fixture)
                    if fixture:testPoint(x, y) then
                        local actorId = self.behaviorsByName.Body:getActorForBody(fixture:getBody())
                        if actorId then
                            self:send('removeActor', self.clientId, actorId)
                            removedSomething = true
                            return false
                        end
                    end
                    return true
                end)

            if not removedSomething then
                self:sendAddActor({
                    Body = {
                        x = x,
                        y = y,
                        fixture = {
                            shapeType = 'polygon',
                            points = {
                                -math.random(20, 60), -math.random(20, 60),
                                -math.random(20, 60), math.random(20, 60),
                                math.random(20, 60), math.random(20, 60),
                                math.random(20, 60), -math.random(20, 60),
                            },
                        },
                        bodyType = button == 2 and 'kinematic' or 'dynamic',
                        gravityScale = 200,
                    },
                    Image = {
                        url = 'https://art.pixilart.com/5d29768f5c3f448.png',
                    },
                    Mover = button == 2 and {} or nil,
                })
            end
        end
    end
end


-- UI

local ui = castle.ui

function Client:uiupdate()
    if not castle.system.isMobile() then
        return
    end

    ui.pane('toolbar', {
        customLayout = true,
        flexDirection = 'row',
    }, function()
        ui.button('hello')

        ui.box('spacer', {
            flex = 1,
        }, function()
        end)

        ui.button('world')
    end)

    ui.pane('default', { customLayout = true }, function()
        ui.tabs('tabs', {
            containerStyle = { flex = 1, margin = 0, backgroundColor = 'white' },
            contentStyle = { flex = 1 },
        }, function()
            ui.tab('library', function()
                ui.scrollBox('scrollBox1', {
                    padding = 2,
                    margin = 4,
                    flex = 1,
                }, function()
                    for i = 1, 10 do
                        ui.markdown('row ' .. i)
                        if ui.button('alpha ' .. i) then
                            print('alpha ' .. i .. ' pressed!')
                        end
                    end
                end)
            end)
            ui.tab('properties', function()
            end)
        end)
    end)
end
