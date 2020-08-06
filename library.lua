-- Core library

local CORE_LIBRARY = {
    {
        entryType = "actorBlueprint",
        title = "wall",
        description = "A rectangular solid that doesn't move.",
        actorBlueprint = {
            components = {
                Drawing = {
                    url = "assets/rectangle.svg"
                },
                Drawing2 = {
                    data = {}
                },
                Body = {},
                Solid = {}
            }
        }
    },
    {
        entryType = "actorBlueprint",
        title = "ball",
        description = "A circular solid that falls.",
        actorBlueprint = {
            components = {
                Drawing = {
                    url = "assets/circle.svg"
                },
                Drawing2 = {
                    data = {}
                },
                Body = {gravityScale = 1},
                CircleShape = {},
                Solid = {},
                Falling = {}
            }
        }
    },
    {
        entryType = "actorBlueprint",
        title = "text",
        description = "A humble block of text, pinned to the bottom of the card.",
        actorBlueprint = {
            components = {
                Text = {
                    content = "To be?"
                }
            }
        }
    },
    {
       entryType = "actorBlueprint",
       title = "button",
       description = "A button that can send the player to another card.",
       actorBlueprint = {
          components = {
             Text = {
                content = "Press here to go to the card given in my Rules.",
             },
             Rules = {
                rules = {
                   {
                      trigger = {
                         name = "tap",
                         behaviorId = 19, -- TODO: fix when we fix behaviorId
                         params = {},
                      },
                      response = {
                         name = "send player to card",
                         behaviorId = 19, -- TODO: fix when we fix behaviorId
                         params = {
                            card = nil,
                         },
                      },
                   },
                },
             },
          },
       },
    },
}

local assetNames = require "asset_names"
for _, assetName in ipairs(assetNames) do
    -- SVG?
    if assetName:match("%.svg$") then
        table.insert(
            CORE_LIBRARY,
            {
                entryType = "drawing",
                title = assetName:gsub("%.svg", ""),
                description = "A drawing from the default asset library.",
                drawing = {
                    url = "assets/" .. assetName
                }
            }
        )
    end
end

-- Start / stop

function Common:startLibrary()
    self.library = {} -- `entryId` -> entry

    for _, entrySpec in pairs(CORE_LIBRARY) do
        local entryId = self:generateId()
        local entry = util.deepCopyTable(entrySpec)
        entry.entryId = entryId
        entry.isCore = true
        self.library[entryId] = entry
    end
end

-- Message receivers

function Common.receivers:addLibraryEntry(time, entryId, entry)
    local entryCopy = util.deepCopyTable(entry)
    entryCopy.entryId = entryId
    self.library[entryId] = entryCopy
end

function Common.receivers:removeLibraryEntry(time, entryId)
    self.library[entryId] = nil
end

function Common.receivers:updateLibraryEntry(time, clientId, entryId, newEntry, opts)
    local oldEntry = self.library[entryId]
    assert(oldEntry.entryType == newEntry.entryType, "updateLibraryEntry: cannot change entry type")

    if self.clientId == clientId then
        if newEntry.entryType == "actorBlueprint" and opts.updateActors then
            local oldBp = oldEntry.actorBlueprint
            local newBp = newEntry.actorBlueprint

            local function valueEqual(value1, value2)
                if type(value1) == "table" and type(value2) == "table" then
                    -- Quick hack for checking table equality...
                    return serpent.dump(value1, {sortkeys = true}) == serpent.dump(value2, {sortkeys = true})
                else
                    return value1 == value2
                end
            end

            -- Collect list of changes
            local changes = {}
            for behaviorName, newComponentBp in pairs(newBp.components) do
                local oldComponentBp = oldBp.components[behaviorName]
                if oldComponentBp then -- Component already existed, check value changes
                    for key, newValue in pairs(newComponentBp) do
                        if not valueEqual(oldComponentBp[key], newValue) then
                            table.insert(
                                changes,
                                {
                                    changeType = "value",
                                    behaviorName = behaviorName,
                                    key = key,
                                    newValue = newValue
                                }
                            )
                        end
                    end
                    for key, oldValue in pairs(oldComponentBp) do
                        if newComponentBp[key] == nil then -- Check for `nil`'d values skipped above
                            table.insert(
                                changes,
                                {
                                    changeType = "value",
                                    behaviorName = behaviorName,
                                    key = key,
                                    newValue = nil
                                }
                            )
                        end
                    end
                else -- Component newly added
                    table.insert(
                        changes,
                        {
                            changeType = "add component",
                            behaviorName = behaviorName,
                            newComponentBp = newComponentBp
                        }
                    )
                end
            end
            for behaviorName, oldComponentBp in pairs(oldBp.components) do
                if newBp.components[behaviorName] == nil then -- Check for removed components skipped above
                    table.insert(
                        changes,
                        {
                            changeType = "remove component",
                            behaviorName = behaviorName
                        }
                    )
                end
            end

            -- Update actors
                for actorId, actor in pairs(self.actors) do
                if actorId ~= opts.skipActorId and actor.parentEntryId == entryId then
                    local bp = self:blueprintActor(actorId) -- Start with old blueprint and merge changes
                    for _, change in ipairs(changes) do
                        local changeType, behaviorName, key = change.changeType, change.behaviorName, change.key
                        if changeType == "value" then
                            if bp.components[behaviorName] then
                                if
                                    valueEqual(
                                        oldBp.components[behaviorName][key],
                                        bp.components[behaviorName][key]
                                    )
                                 then
                                    -- Only change value if not overridden
                                    bp.components[behaviorName][key] = change.newValue
                                end
                            end
                        elseif changeType == "add component" then
                            bp.components[behaviorName] = change.newComponentBp
                        elseif changeType == "remove component" then
                            bp.components[behaviorName] = nil
                        end
                    end
                    self:send("removeActor", self.clientId, actorId)
                    self:sendAddActor(
                        bp,
                        {
                            actorId = actorId,
                            parentEntryId = entryId
                        }
                    )
                end
            end
        end
    end

    local newEntryCopy = util.deepCopyTable(newEntry)
    newEntryCopy.entryId = entryId
    self.library[entryId] = newEntryCopy
end

-- UI

local PAGE_SIZE = 10

local currPage = {}

function Client:uiLibrary(opts)
    -- Reusable library UI component

    opts = opts or {}

    opts.id = opts.id or "library"

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
    if not opts.filterType or opts.filterType == "behavior" then
        for behaviorId, behavior in pairs(self.behaviors) do
            if not opts.filterBehavior or opts.filterBehavior(behavior) then
                local dependencyNames = {}
                for name, dependency in pairs(behavior.dependencies) do
                    if name ~= "Body" then
                        table.insert(dependencyNames, "**" .. dependency:getUiName() .. "**")
                    end
                end
                local requiresLine = ""
                if next(dependencyNames) then
                    requiresLine = "Needs " .. table.concat(dependencyNames, ", ") .. ".\n\n"
                end
                local shortDescription = (behavior.description and behavior.description:match("^[\n ]*[^\n]*")) or ""
                table.insert(
                    order,
                    {
                        entryId = tostring(behaviorId),
                        entryType = "behavior",
                        title = behavior:getUiName(),
                        description = requiresLine .. shortDescription,
                        behaviorId = behaviorId
                    }
                )
            end
        end
    end

    -- Sort
    table.sort(
        order,
        function(entry1, entry2)
            if entry1.behaviorId and entry2.behaviorId then
                return entry1.behaviorId < entry2.behaviorId
            end
            return entry1.title:upper() < entry2.title:upper()
        end
    )

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

        ui.box(
            "top page buttons",
            {
                flexDirection = "row"
            },
            function()
                ui.button(
                    "previous page",
                    {
                        icon = "arrow-bold-left",
                        iconFamily = "Entypo",
                        hideLabel = true,
                        onClick = function()
                            currPage[opts.id] = math.max(1, currPage[opts.id] - 1)
                        end
                    }
                )
                ui.box(
                    "spacer",
                    {flex = 1},
                    function()
                    end
                )
                ui.markdown("page " .. currPage[opts.id] .. " of " .. numPages)
                ui.box(
                    "spacer",
                    {flex = 1},
                    function()
                    end
                )
                ui.button(
                    "previous page",
                    {
                        icon = "arrow-bold-right",
                        iconFamily = "Entypo",
                        hideLabel = true,
                        onClick = function()
                            currPage[opts.id] = math.min(currPage[opts.id] + 1, numPages)
                        end
                    }
                )
            end
        )
    end

    -- Scrolling view of current page
    ui.scrollBox(
        "scrollBox" .. opts.id .. (currPage[opts.id] or 1),
        {
            padding = 2,
            margin = 2,
            flex = 1
        },
        function()
            -- Empty?
            if #order == 0 then
                ui.box(
                    "empty text",
                    {
                        paddingLeft = 4,
                        margin = 4
                    },
                    function()
                        ui.markdown(opts.emptyText or "No entries!")
                    end
                )
            end

            for _, entry in ipairs(order) do
                -- Entry box
                ui.box(
                    entry.entryId,
                    {
                        borderWidth = 1,
                        borderColor = "#292929",
                        borderRadius = 4,
                        padding = 4,
                        margin = 4,
                        marginBottom = 8,
                        flexDirection = "row",
                        alignItems = "center"
                    },
                    function()
                        local imageUrl

                        -- Figure out image based on type
                        if entry.entryType == "actorBlueprint" then
                            local actorBp = entry.actorBlueprint
                            if actorBp.components.Image and actorBp.components.Image.url then
                                imageUrl = actorBp.components.Image.url
                            end
                            if actorBp.components.Drawing and actorBp.components.Drawing.url then
                                imageUrl = actorBp.components.Drawing.url
                            end
                        end
                        if entry.entryType == "image" then
                            imageUrl = entry.image.url
                        end
                        if entry.entryType == "drawing" then
                            imageUrl = entry.drawing.url
                        end

                        -- Show image if applies
                        if imageUrl then
                            ui.box(
                                "image container",
                                {
                                    width = "28%",
                                    aspectRatio = 1,
                                    margin = 4,
                                    marginLeft = 8,
                                    backgroundColor = "white"
                                },
                                function()
                                    ui.image(CHECKERBOARD_IMAGE_URL, {flex = 1, margin = 0})

                                    ui.image(
                                        imageUrl,
                                        {
                                            position = "absolute",
                                            left = 0,
                                            top = 0,
                                            bottom = 0,
                                            right = 0,
                                            margin = 0
                                        }
                                    )
                                end
                            )

                            ui.box(
                                "spacer",
                                {width = 8},
                                function()
                                end
                            )
                        end

                        ui.box(
                            "text buttons",
                            {flex = 1},
                            function()
                                -- Title, short description
                                ui.markdown("## " .. entry.title .. "\n" .. (entry.description or ""))

                                -- Buttons
                                if opts.buttons then
                                    ui.box(
                                        "buttons",
                                        {flexDirection = "row"},
                                        function()
                                            opts.buttons(entry)
                                        end
                                    )
                                end
                            end
                        )
                    end
                )
            end

            if opts.bottomSpace then
                ui.box(
                    "bottom space",
                    {height = opts.bottomSpace},
                    function()
                    end
                )
            end
        end
    )
end
