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

    self.activeToolBehaviorId = nil -- `behaviorId` of active tool
    self.lastActiveToolBehaviorId = nil -- the last non-`nil` value of `self.activeToolBehaviorId`
    self.applicableTools = {} -- `behaviorId` -> behavior, for tools applicable to selection

    self.touches = {} -- `touchId` -> touch
    self.numTouches = 0 -- Number of currently active touches
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
    self.allTouchesReleased = false -- Whether we are at the end of a gesture
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


-- Selections / tools

function Client:clearRemovedSelections()
    for actorId in pairs(self.selectedActorIds) do
        if not self.actors[actorId] then
            self:deselectActor(actorId)
        end
    end
    if not self.tools[self.activeToolBehaviorId] then
        self.activeToolBehaviorId = nil
    end
end

function Client:refreshTools()
    self.applicableTools = {}

    -- Find common behaviors across all actors -- used by dependency check below
    local commonBehaviorIds
    for actorId in pairs(self.selectedActorIds) do
        local actor = self.actors[actorId]
        if commonBehaviorIds then
            for behaviorId in pairs(commonBehaviorIds) do
                if not actor.components[behaviorId] then
                    commonBehaviorIds[behaviorId] = nil
                end
            end
        else
            commonBehaviorIds = {}
            for behaviorId in pairs(actor.components) do
                commonBehaviorIds[behaviorId] = true
            end
        end
    end
    commonBehaviorIds = commonBehaviorIds or {}

    for behaviorId, tool in pairs(self.tools) do
        local applicable = true

        -- Check if it needs performance to be off or on
        if applicable then
            if self.performing and tool.tool.needsPerformingOff then
                applicable = false
            end
            if not self.performing and tool.tool.needsPerformingOn then
                applicable = false
            end
        end

        -- Check that dependencies are satisfied
        if applicable then
            for dependencyName, dependency in pairs(tool.dependencies) do
                if not commonBehaviorIds[dependency.behaviorId] then
                    applicable = false
                    break
                end
            end
        end

        if applicable then
            self.applicableTools[behaviorId] = tool
        end
    end

    if self.activeToolBehaviorId then
        -- Deactivate active tool if it doesn't apply any more
        if not self.applicableTools[self.activeToolBehaviorId] then
            self:setActiveTool(nil)
        end
    else -- No tool currently active, but see if the last active tool can be re-activated
        if self.applicableTools[self.lastActiveToolBehaviorId] then
            self:setActiveTool(self.lastActiveToolBehaviorId)
        end
    end

    -- Add or remove components for active tool based on selections
    if self.activeToolBehaviorId then
        -- Remove components whose actors aren't selected any more
        local activeTool = self.tools[self.activeToolBehaviorId]
        for actorId, component in pairs(activeTool.components) do
            if self.clientId == component.clientId and not self.selectedActorIds[actorId] then
                self:send('removeComponent', self.clientId, actorId, activeTool.behaviorId)
            end
        end

        -- Add components for new selections
        for actorId in pairs(self.selectedActorIds) do
            if not activeTool:has(actorId) then
                self:send('addComponent', self.clientId, actorId, self.activeToolBehaviorId)
            end
        end
    end
end

function Client:selectActor(actorId)
    self.selectedActorIds[actorId] = true
end

function Client:deselectActor(actorId)
    self.selectedActorIds[actorId] = nil
end

function Client:deselectAllActors()
    for actorId in pairs(self.selectedActorIds) do
        self:deselectActor(actorId)
    end
end

function Client:setActiveTool(toolBehaviorId)
    if self.activeToolBehaviorId then
        -- Clear our components from old tool -- we could use `self.selectedActorIds` but
        -- we actually go through the tool's components to make sure
        local activeTool = self.tools[self.activeToolBehaviorId]
        for actorId, component in pairs(activeTool.components) do
            if self.clientId == component.clientId then
                self:send('removeComponent', self.clientId, actorId, activeTool.behaviorId)
            end
        end
    end

    self.activeToolBehaviorId = toolBehaviorId
    if self.activeToolBehaviorId then
        self.lastActiveToolBehaviorId = self.activeToolBehaviorId
    end

    -- Activate new tool and add components to it if it applies
    if self.activeToolBehaviorId and self.applicableTools[self.activeToolBehaviorId] then
        local activeTool = self.tools[self.activeToolBehaviorId]
        for actorId in pairs(self.selectedActorIds) do
            if not activeTool:has(actorId) then
                self:send('addComponent', self.clientId, actorId, self.activeToolBehaviorId)
            end
        end
    end
end

function Client:selectActorAtPoint(x, y, hits)
    local hits = hits or self.behaviorsByName.Body:getActorsAtPoint(x, y)
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
    self:deselectAllActors()
    if pick then
        self:selectActor(pick)
    end
end


-- Update

function Client:update(dt)
    if not self.connected then
        return
    end

    self:clearRemovedSelections()

    -- Touch-to-select (do this before refreshing tools since it affects selections)
    if self.numTouches == 1 and self.maxNumTouches == 1 then
        local touchId, touch = next(self.touches)

        -- Press? Check at point and select if nothing already selected there.
        if touch.pressed then
            local someSelectedHit = false
            local hits = self.behaviorsByName.Body:getActorsAtPoint(touch.x, touch.y)
            for actorId in pairs(hits) do
                if self.selectedActorIds[actorId] then
                    someSelectedHit = true
                    break
                end
            end
            if not someSelectedHit then
                self:selectActorAtPoint(touch.x, touch.y, hits)
            end
        end

        -- Press and release without moving? Select!
        if touch.released and touch.x - touch.initialX == 0 and touch.y - touch.initialY == 0 then
            self:selectActorAtPoint(touch.x, touch.y)
        end
    end

    self:refreshTools()

    -- Common update
    Common.update(self, dt)

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
    self.allTouchesReleased = false
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
            if o1.depth < o2.depth then
                return true
            end
            if o1.depth > o2.depth then
                return false
            end
            return o1.id < o2.id
        end)
        for _, o in ipairs(order) do
            o.draw()
        end
    end

    do -- Selections
        love.graphics.setColor(0, 1, 0)
        local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]
        for actorId in pairs(self.selectedActorIds) do
            if self.behaviorsByName.Body:has(actorId) then
                if activeTool then
                    local component = activeTool.components[actorId]
                    if component and self.clientId ~= component.clientId then
                        love.graphics.setColor(1, 0, 0)
                    else
                        love.graphics.setColor(0, 1, 0)
                    end
                end
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

                -- If it has a `Body`, initialize position to touch location
                if actorBp.Body then 
                    actorBp.Body.x, actorBp.Body.y = x, y
                end

                local actorId = self:sendAddActor(actorBp)

                -- Select the actor. If we're not performing and it has a `Body`, switch to the `Grab` tool.
                if not self.performing and actorBp.Body then
                    self:setActiveTool(nil)
                end
                self:deselectAllActors()
                self:selectActor(actorId)
                self:refreshTools()
                if not self.performing and actorBp.Body then
                    self:setActiveTool(self.behaviorsByName.Grab.behaviorId)
                end
            end
        end
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

        -- Check if end of gesture
        self.allTouchesReleased = true
        for touchId, touch in pairs(self.touches) do
            if not touch.released then
                self.allTouchesReleased = false
            end
        end
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

        -- Tools
        if next(self.selectedActorIds) then
            local order = {}
            for _, tool in pairs(self.applicableTools) do
                table.insert(order, tool)
            end
            table.sort(order, function(tool1, tool2)
                return tool1.behaviorId < tool2.behaviorId
            end)
            for _, tool in ipairs(order) do
                ui.button(tool.name, {
                    icon = tool.tool.icon,
                    iconFamily = tool.tool.iconFamily,
                    hideLabel = true,
                    selected = self.activeToolBehaviorId == tool.behaviorId,
                    onClick = function()
                        self:setActiveTool(tool.behaviorId)
                    end,
                })
            end
        end

        -- Delete
        if next(self.selectedActorIds) then
            ui.button('remove actor', {
                icon = 'trash-alt',
                iconFamily = 'FontAwesome5',
                hideLabel = true,
                onClick = function()
                    for actorId in pairs(self.selectedActorIds) do
                        self:deselectActor(actorId)
                        self:send('removeActor', self.clientId, actorId)
                    end
                end,
            })
        end
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
