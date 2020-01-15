-- Core library

local CORE_LIBRARY = {
    {
        entryType = 'actorBlueprint',
        title = 'dog',
        description = 'A canine friend that falls and rolls around!',
        actorBlueprint = {
            Image = {
                url = 'https://art.pixilart.com/5d29768f5c3f448.png',
                cropEnabled = true,
                cropX = 256,
                cropY = 150,
                cropWidth = 600,
                cropHeight = 700,
            },
            Body = {
                fixture = {
                    shapeType = 'polygon',
                    points = {
                        -55, -64,
                        -55, 64,
                        55, 64,
                        55, -64,
                    },
                },
                bodyType = 'dynamic',
                gravityScale = 1,
            },
        },
    },
    {
        entryType = 'actorBlueprint',
        title = 'ice platform',
        description = 'Something to stand on...',
        actorBlueprint = {
            Image = {
                url = 'http://www.photonstorm.com/wp-content/uploads/2015/01/ice-platform.png',
            },
            Body = {
                fixture = {
                    shapeType = 'polygon',
                    points = {
                        -192, -48,
                        -192, 48,
                        192, 48,
                        192, -48,
                    },
                },
                bodyType = 'static',
            },
        },
    },
    {
        entryType = 'actorBlueprint',
        title = 'rotating ice platform',
        description = "Like 'ice platform', but rotating!",
        actorBlueprint = {
            Image = {
                url = 'http://www.photonstorm.com/wp-content/uploads/2015/01/ice-platform.png',
            },
            Body = {
                fixture = {
                    shapeType = 'polygon',
                    points = {
                        -192, -48,
                        -192, 48,
                        192, 48,
                        192, -48,
                    },
                },
            },
            RotatingMotion = {
                rotationsPerSecond = 0.5,
            },
        },
    },
}


-- Start / stop

function Common:startLibrary()
    self.library = {} -- `entryId` -> entry
end

function Server:startLibrary()
    Common.startLibrary(self)
    
    for _, entrySpec in pairs(CORE_LIBRARY) do
        local entryId = self:generateId()
        local entry = util.deepCopyTable(entrySpec)
        entry.entryId = entryId
        self.library[entryId] = entry
    end
end

function Client:startLibrary()
    Common.startLibrary(self)

    self.addFromLibraryEntryId = nil -- `entryId` of entry we are adding from, if adding, `nil` otherwise
    self.addToLibraryTitle = ''
    self.addToLibraryDescription = ''
end

function Common:stopLibrary()
end


-- Message kind definitions

function Common:defineLibraryMessageKinds(config)
    self:defineMessageKind('addLibraryEntry', config.reliableToAllSendOpts)
end


-- Sync new client

function Server:syncClientLibrary(clientId, send)
    for entryId, entry in pairs(self.library) do
        send('addLibraryEntry', entryId, entry)
    end
end


-- Message receivers

function Common.receivers:addLibraryEntry(time, entryId, entry)
    local entryCopy = util.deepCopyTable(entry)
    entryCopy.entryId = entryId
    self.library[entryId] = entryCopy
end


-- Update

function Client:preUpdateLibrary()
    if self.addFromLibraryEntryId then -- Adding something?
        -- Check for a single touch
        if self.numTouches == 1 and self.maxNumTouches == 1 then
            local touchId, touch = next(self.touches)

            local entry = self.library[self.addFromLibraryEntryId]
            self.addFromLibraryEntryId = nil
            if entry then
                if entry.entryType == 'actorBlueprint' then
                    local actorBp = util.deepCopyTable(entry.actorBlueprint)

                    -- If it has a `Body`, initialize position to touch location
                    if actorBp.Body then 
                        actorBp.Body.x, actorBp.Body.y = touch.x, touch.y
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

                    -- Mark the touch as used for selection so we don't change selections again
                    touch.usedForSelection = true
                end
            end
        end
    end
end


-- UI

function Client:uiLibrary()
    ui.scrollBox('scrollBox1', {
        padding = 2,
        margin = 2,
        flex = 1,
    }, function()
        local actorId = next(self.selectedActorIds)
        if actorId then
            ui.button('add to library', {
                popoverAllowed = true,
                popover = function()
                    self.addToLibraryTitle = ui.textInput('title', self.addToLibraryTitle)

                    self.addToLibraryDescription = ui.textInput('description', self.addToLibraryDescription)

                    if ui.button('save') then
                        local entryId = util.uuid()

                        local actorBlueprint = self:blueprintActor(actorId)

                        print(serpent.block(actorBlueprint))

                        self:send('addLibraryEntry', entryId, {
                            entryType = 'actorBlueprint',
                            title = self.addToLibraryTitle,
                            description = self.addToLibraryDescription,
                            actorBlueprint = actorBlueprint,
                        })
                        self.addToLibraryTitle = ''
                        self.addToLibraryDescription = ''
                    end
                end,
            })
        end

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

                    if self.addFromLibraryEntryId ~= entry.entryId then
                        if ui.button('add') then
                            self.addFromLibraryEntryId = entry.entryId
                        end
                    else
                        if ui.button('adding...', { selected = true }) then
                            self.addFromLibraryEntryId = nil
                        end
                    end
                end)
            end)
        end
    end)
end
