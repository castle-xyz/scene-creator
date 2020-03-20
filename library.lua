-- Core library

local CORE_LIBRARY = {
    {
        entryType = 'actorBlueprint',
        title = 'wall',
        description = "A rectangular solid that doesn't move.",
        actorBlueprint = {
            components = {
                Drawing = {
                    url = 'assets/rectangle.svg',
                },
                Body = {},
                Solid = {},
            },
        },
    },
    {
        entryType = 'actorBlueprint',
        title = 'ball',
        description = "A circular solid that falls and bounces.",
        actorBlueprint = {
            components = {
                Drawing = {
                    url = 'assets/circle.svg',
                },
                Body = { gravityScale = 1 },
                CircleShape = {},
                Solid = {},
                Bouncy = {},
                Falling = {},
            },
        },
    },
}

local assetNames = require 'asset_names'
for _, assetName in ipairs(assetNames) do
    -- SVG?
    if assetName:match('%.svg$') then
        table.insert(CORE_LIBRARY, {
            entryType = 'drawing',
            title = assetName:gsub('%.svg', ''),
            description = 'A drawing from the default asset library.',
            drawing = {
                url = 'assets/' .. assetName,
            },
        })
    end
end


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

local PAGE_SIZE = 10

local currPage = {}

function Client:uiLibrary(opts)
    -- Reusable library UI component

    opts = opts or {}

    opts.id = opts.id or 'library'

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
                local dependencyNames = {}
                for name, dependency in pairs(behavior.dependencies) do
                    if name ~= 'Body' then
                        table.insert(dependencyNames, '**' .. dependency:getUiName() .. '**')
                    end
                end
                local requiresLine = ''
                if next(dependencyNames) then
                    requiresLine = 'Needs ' .. table.concat(dependencyNames, ', ') .. '.\n\n'
                end
                local shortDescription = (behavior.description and behavior.description:match('^[\n ]*[^\n]*')) or ''
                table.insert(order, {
                    entryId = tostring(behaviorId),
                    entryType = 'behavior',
                    title = behavior:getUiName(),
                    description = requiresLine .. shortDescription,
                    behaviorId = behaviorId,
                })
            end
        end
    end

    -- Sort
    table.sort(order, function(entry1, entry2)
        if entry1.behaviorId and entry2.behaviorId then
            return compareBehaviorId(entry1.behaviorId, entry2.behaviorId)
        end
        return entry1.title:upper() < entry2.title:upper()
    end)

    -- Paginate
    if #order > PAGE_SIZE then
        currPage[opts.id] = currPage[opts.id] or 1

        local numPages = math.ceil(#order / PAGE_SIZE)

        local newOrder = {}
        for i = 1, PAGE_SIZE do
            local j = PAGE_SIZE * (currPage[opts.id] - 1) + i
            if j > #order then
                break
            end
            table.insert(newOrder, order[j])
        end
        order = newOrder

        ui.box('top page buttons', {
            flexDirection = 'row',
        }, function()
            ui.button('previous page', {
                icon = 'arrow-bold-left',
                iconFamily = 'Entypo',
                hideLabel = true,
                onClick = function()
                    currPage[opts.id] = math.max(1, currPage[opts.id] - 1)
                end,
            })
            ui.box('spacer', { flex = 1 }, function() end)
            ui.markdown('page ' .. currPage[opts.id] .. ' of ' .. numPages)
            ui.box('spacer', { flex = 1 }, function() end)
            ui.button('previous page', {
                icon = 'arrow-bold-right',
                iconFamily = 'Entypo',
                hideLabel = true,
                onClick = function()
                    currPage[opts.id] = math.min(currPage[opts.id] + 1, numPages)
                end,
            })
        end)
    end

    -- Scrolling view of current page
    ui.scrollBox('scrollBox' .. opts.id .. (currPage[opts.id] or 1), {
        padding = 2,
        margin = 2,
        flex = 1,
    }, function()
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
                    if actorBp.components.Drawing and actorBp.components.Drawing.url then
                        imageUrl = actorBp.components.Drawing.url
                    end
                end
                if entry.entryType == 'image' then
                    imageUrl = entry.image.url
                end
                if entry.entryType == 'drawing' then
                    imageUrl = entry.drawing.url
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
                    ui.markdown('## ' .. entry.title .. '\n' .. (entry.description or ''))

                    -- Buttons
                    if opts.buttons then
                        ui.box('buttons', { flexDirection = 'row' }, function()
                            opts.buttons(entry)
                        end)
                    end
                end)
            end)
        end

        if opts.bottomSpace then
            ui.box('bottom space', { height = opts.bottomSpace }, function() end)
        end
    end)
end
