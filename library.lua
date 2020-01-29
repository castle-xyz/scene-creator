-- Core library

local CORE_LIBRARY = {
    {
        entryType = 'actorBlueprint',
        title = 'dog',
        description = 'A canine friend that falls and rolls around!',
        actorBlueprint = {
            components = {
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
                            -0.5, -0.5,
                            -0.5, 0.5,
                            0.5, 0.5,
                            0.5, -0.5,
                        },
                    },
                },
                Solid = {},
                FreeMotion = {},
            },
        },
    },
    {
        entryType = 'actorBlueprint',
        title = 'ice platform',
        description = 'Something to stand on...',
        actorBlueprint = {
            components = {
                Image = {
                    url = 'http://www.photonstorm.com/wp-content/uploads/2015/01/ice-platform.png',
                },
                Body = {
                    fixture = {
                        shapeType = 'polygon',
                        points = {
                            -2, -0.5,
                            -2, 0.5,
                            2, 0.5,
                            2, -0.5,
                        },
                    },
                    bodyType = 'static',
                },
                Solid = {},
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

    -- On server, populate the library with core entries
    for _, entrySpec in pairs(CORE_LIBRARY) do
        local entryId = self:generateId()
        local entry = util.deepCopyTable(entrySpec)
        entry.entryId = entryId
        self.library[entryId] = entry
    end
end


-- Message kind definitions

function Common:defineLibraryMessageKinds()
    self:defineMessageKind('addLibraryEntry', self.sendOpts.reliableToAll)
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
    -- Reusable library UI component

    opts = opts or {}

    ui.scrollBox('scrollBox1', {
        padding = 2,
        margin = 2,
        flex = 1,
    }, function()
        local order = {}

        -- Add regular library entries
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

        -- Add behaviors unless filtered out
        if not opts.filterType or opts.filterType == 'behavior' then
            for behaviorId, behavior in pairs(self.behaviors) do
                if not opts.filterBehavior or opts.filterBehavior(behavior) then
                    table.insert(order, {
                        entryId = tostring(behaviorId),
                        entryType = 'behavior',
                        title = behavior:getUiName(),
                        description = behavior.description,
                        behaviorId = behaviorId,
                    })
                end
            end
        end

        -- Sort
        table.sort(order, function(entry1, entry2)
            return entry1.title:upper() < entry2.title:upper()
        end)

        -- Empty?
        if #order == 0 then
            ui.box('empty text', {
                paddingLeft = 4,
                margin = 4,
            }, function()
                ui.markdown(opts.emptyText or 'No entries!')
            end)
        end

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
                    if actorBp.components.Image and actorBp.components.Image.url then
                        imageUrl = actorBp.components.Image.url
                    end
                end

                -- Show image if applies
                if imageUrl then
                    ui.box('image container', {
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

                ui.box('text buttons', { flex = 1 }, function()
                    -- Title, short description
                    local shortDescription = (entry.description and entry.description:match('^[\n ]*[^\n]*')) or ''
                    ui.markdown('## ' .. entry.title .. '\n' .. shortDescription)

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
