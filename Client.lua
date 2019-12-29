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

    -- Client-local initialization below


    self.photoImages = {}
end


-- Connect / reconnect / disconnect

function Client:connect()
    -- Send `me`
    local me = castle.user.getMe()
    self:send('me', self.clientId, me)
end

function Client:reconnect()
    Common.start(self) -- This should just re-initialize our shared stuff
end


-- Mes

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
    -- Not connected?
    if not self.connected then
        return
    end

    -- Common update
    Common.update(self, dt)
end


-- Draw

function Client:draw()
    do -- Physics bodies
        local worldId, world = self.physics:getWorld()
        if world then
            love.graphics.setLineWidth(2)
            for _, body in ipairs(world:getBodies()) do
                local bodyId = self.physics:idForObject(body)
                local ownerId = self.physics:getOwner(bodyId)
                if ownerId then
                    local c = ownerId + 1
                    love.graphics.setColor(c % 2, math.floor(c / 2) % 2, math.floor(c / 4) % 2)
                else
                    love.graphics.setColor(1, 1, 1)
                end

                -- Draw shapes
                for _, fixture in ipairs(body:getFixtures()) do
                    local shape = fixture:getShape()
                    local ty = shape:getType()
                    if ty == 'circle' then
                        love.graphics.circle('line', body:getX(), body:getY(), shape:getRadius())
                    elseif ty == 'polygon' then
                        love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                    elseif ty == 'edge' then
                        love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                    elseif ty == 'chain' then
                        love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                    end
                end
            end
        end
    end

    do -- Debug overlay
        local networkText = ''
        if self.connected then
            networkText = networkText .. '    ping: ' .. self.client.getPing() .. 'ms'
            networkText = networkText .. '    mem: ' .. math.floor(collectgarbage('count')) .. 'kb'
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.print('fps: ' .. love.timer.getFPS() .. networkText, 22, 2)
    end
end


-- UI

local ui = castle.ui

function Client:uiupdate()
    if false then -- UI for disconnection testing
        if self.connected then
            ui.markdown("You are connected! Click 'kick' to disconnect yourself.")
            if ui.button('kick') then
                self:kick()
            end
        elseif not self.connected and self.clientId then
            ui.markdown("You are disconnected. Click 'retry' to try reconnecting.")
            if ui.button('retry') then
                self:retry()
            end
        end
        ui.markdown("Auto-retry automatically retries connecting if a disconnection is noticed.")
        self.autoRetry = ui.toggle('auto-retry disabled', 'auto-retry enabled', self.autoRetry)
    end
end
