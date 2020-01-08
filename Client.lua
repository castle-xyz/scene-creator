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


    -- Tools

    self.addingEntryId = nil
    self.selectedActorIds = {} -- `actorId` -> `true` for all selected actors
    self.touches = {} -- `touchId` -> `{ x, y, dx, dy }`
    self.numTouches = 0 -- Number of currently active touches
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
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

    -- Selection
    if self.numTouches == 1 and self.maxNumTouches == 1 then
        local touchId, touch = next(self.touches)
        if touch.released and touch.x - touch.initialX == 0 and touch.y - touch.initialY == 0 then
            local hits = self.behaviorsByName.Body:getActorsAtPoint(touch.x, touch.y)
            local pick
            if next(hits) then -- Pick the next unselected hit in some sorted order
                local ordered = {}
                for actorId in pairs(hits) do
                    table.insert(ordered, actorId)
                end
                table.sort(ordered)
                for i = #ordered, 1, -1 do
                    local nextI = i == 1 and #ordered or i - 1
                    if self.selectedActorIds[ordered[i]] then
                        pick = ordered[nextI]
                    end
                end
                pick = pick or ordered[#ordered]
            end
            self.selectedActorIds = {}
            if pick then
                self.selectedActorIds[pick] = true
            end
        end
    end

    -- Clear touch state
    for touchId, touch in pairs(self.touches) do
        if touch.released then
            self.touches[touchId] = nil
            self.numTouches = self.numTouches - 1
            if self.numTouches == 0 then
                self.maxNumTouches = 0
            end
        else
            touch.pressed = false
            touch.dx, touch.dy = 0, 0
        end
    end
end


-- Draw

local debugFont = love.graphics.newFont(14)

function Client:draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    do -- Background color
        love.graphics.clear(1, 0.98, 0.98)
    end

    if not self.connected then -- Not connected?
        love.graphics.setFont(debugFont)
        love.graphics.setColor(0, 0, 0)
        local peer = self.client.getENetPeer()
        local text = peer and ('connection state: ' .. peer:state()) or 'trying to connect...'
        love.graphics.print(text, 16, windowHeight - debugFont:getHeight() - 16)
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

    do -- Selections
        love.graphics.setColor(0, 1, 0)
        for actorId in pairs(self.selectedActorIds) do
            if self.behaviorsByName.Body:has(actorId) then
                self.behaviorsByName.Body:drawBodyOutline(actorId)
            end
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


-- Touch

function Client:touchpressed(touchId, x, y, dx, dy)
    if not self.connected then
        return
    end

    if self.addingEntryId then -- Adding? Just add and skip the touch.
        local entry = self.library[self.addingEntryId]
        self.addingEntryId = nil
        if entry then
            if entry.entryType == 'actorBlueprint' then
                local actorBp = util.deepCopyTable(entry.actorBlueprint)

                if actorBp.Body then
                    actorBp.Body.x, actorBp.Body.y = x, y
                end

                self:sendAddActor(actorBp)
            end
        end
        return
    end

    local touch = {}

    touch.initialX, touch.initialY = x, y
    touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
    touch.pressed = true
    touch.released = false

    self.touches[touchId] = touch

    self.numTouches = self.numTouches + 1
    self.maxNumTouches = math.max(self.maxNumTouches, self.numTouches)
end

function Client:touchreleased(touchId, x, y, dx, dy)
    local touch = self.touches[touchId]
    if touch then
        touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
        touch.released = true
    end
end

function Client:touchmoved(touchId, x, y, dx, dy)
    local touch = self.touches[touchId]
    if touch then
        touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
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
        padding = 2,
    }, function()
        ui.button('toggle performing', {
            icon = 'play',
            iconFamily = 'FontAwesome',
            hideLabel = true,
            selected = self.performing,
            onClick = function()
                self:send('setPerforming', not self.performing)
            end,
        })

        ui.box('spacer', { flex = 1 }, function() end)

        ui.button('world')
    end)

    ui.pane('default', { customLayout = true }, function()
        ui.tabs('tabs', {
            containerStyle = { flex = 1, margin = 0 },
            contentStyle = { flex = 1 },
        }, function()
            ui.tab('library', function()
                ui.scrollBox('scrollBox1', {
                    padding = 2,
                    margin = 4,
                    flex = 1,
                }, function()
                    local order = {}
                    for entryId, entry in pairs(self.library) do
                        table.insert(order, entry)
                    end
                    table.sort(order, function(entry1, entry2)
                        return entry1.title:upper() < entry2.title:upper()
                    end)

                    for _, entry in ipairs(order) do
                        ui.box(entry.entryId, {
                            borderWidth = 1,
                            borderColor = '#292929',
                            borderRadius = 4,
                            padding = 4,
                            margin = 4,
                            marginBottom = 8,
                            flexDirection = 'row',
                            alignItems = 'center',
                        }, function()
                            local imageUrl

                            if entry.entryType == 'actorBlueprint' then
                                local actorBp = entry.actorBlueprint
                                if actorBp.Image and actorBp.Image.url then
                                    imageUrl = actorBp.Image.url
                                end
                            end

                            if imageUrl then
                                ui.box('image-container', {
                                    width = '28%',
                                    aspectRatio = 1,
                                    margin = 4,
                                    marginLeft = 8,
                                    backgroundColor = 'white',
                                }, function()
                                    ui.image(CHECKERBOARD_IMAGE_URL, { flex = 1, margin = 0 })

                                    ui.image(imageUrl, {
                                        position = 'absolute',
                                        left = 0, top = 0, bottom = 0, right = 0,
                                        margin = 0,
                                    })
                                end)

                                ui.box('spacer', { width = 8 }, function() end)
                            end

                            ui.box('text-buttons', { flex = 1 }, function()
                                ui.markdown('## ' .. entry.title .. '\n' .. entry.description)

                                if self.addingEntryId ~= entry.entryId then
                                    if ui.button('add') then
                                        self.addingEntryId = entry.entryId
                                    end
                                else
                                    if ui.button('adding...', { selected = true }) then
                                        self.addingEntryId = nil
                                    end
                                end
                            end)
                        end)
                    end
                end)
            end)

            ui.tab('properties', function()
            end)
        end)
    end)
end
