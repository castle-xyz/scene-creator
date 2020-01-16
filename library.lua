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


-- UI

function Client:uiLibrary(opts)
    opts = opts or {}

    ui.scrollBox('scrollBox1', {
        padding = 2,
        margin = 2,
        flex = 1,
    }, function()
        local order = {}
        for entryId, entry in pairs(self.library) do
            local skip = false
            if opts.filter then
                if not opts.filter(entry) then
                    skip = true
                end
            elseif opts.filterType then
                if entry.entryType ~= opts.filterType then
                    skip = true
                end
            end
            if not skip then
                table.insert(order, entry)
            end
        end
        table.sort(order, function(entry1, entry2)
            return entry1.title:upper() < entry2.title:upper()
        end)

        for _, entry in ipairs(order) do
            -- Entry box
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

                -- Figure out image based on type
                if entry.entryType == 'actorBlueprint' then
                    local actorBp = entry.actorBlueprint
                    if actorBp.Image and actorBp.Image.url then
                        imageUrl = actorBp.Image.url
                    end
                end

                -- Show image if applies
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
                    -- Title, description
                    ui.markdown('## ' .. entry.title .. '\n' .. entry.description)

                    -- Buttons
                    if opts.buttons then
                        ui.box('buttons', { flexDirection = 'row' }, function()
                            opts.buttons(entry)
                        end)
                    end
                end)
            end)
        end
    end)
end
