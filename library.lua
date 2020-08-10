-- Core library

local CORE_LIBRARY = {
    {
        entryType = "actorBlueprint",
        title = "Wall",
        description = "Solid square that doesn't move",
        actorBlueprint = {
            components = {
                Drawing2 = {
                    drawData = {
                      color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                      fillCanvasSize = 256,
                      fillPng = "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAABlBMVEUAAAAkn94NkT71AAAAAXRSTlMAQObYZgAAADZJREFUeJztyjEBAAAEADDNNUcDLt92L+KSvSpBEARBEARBEARBEARBEARBEARBEARBEITfcBnZ1yIUOBjhWAAAAABJRU5ErkJggg==",
                      gridSize = 15,
                      lineColor = { 0.66037992589614, 0.4, 0.93333333333333, 1 },
                      nextPathId = 4,
                      pathDataList = { {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 1,
                          points = { {
                              x = 0,
                              y = 0
                            }, {
                              x = 0,
                              y = 10
                            } },
                          style = 1
                        }, {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 2,
                          points = { {
                              x = 0,
                              y = 10
                            }, {
                              x = 10,
                              y = 10
                            } },
                          style = 1
                        }, {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 3,
                          points = { {
                              x = 10,
                              y = 10
                            }, {
                              x = 10,
                              y = 0
                            } },
                          style = 1
                        }, {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 4,
                          points = { {
                              x = 10,
                              y = 0
                            }, {
                              x = 0,
                              y = 0
                            } },
                          style = 1
                        } },
                      scale = 10
                    },
                    physicsBodyData = {
                      scale = 10,
                      shapes = { {
                          p1 = {
                            x = 10,
                            y = 10
                          },
                          p2 = {
                            x = 0,
                            y = 0
                          },
                          type = "rectangle"
                        } }
                    }
                },
                Body = {},
                Solid = {}
            }
        },
        base64Png = "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAgMAAAAhHED1AAAADFBMVEUAAAAJKDcST28kn96BE2+VAAAAA3RSTlMAQIDntwj7AAAAc0lEQVR4nO3bMRWAQBBDwaXAFxKuQS/ObjkNhAbe/D7jIFU/aD+DxgKuDppVW7LvjoEDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADPgcqAF27r+XH+890k6T1qMQWTwgAAAABJRU5ErkJggg==",
    },
    {
        entryType = "actorBlueprint",
        title = "Ball",
        description = "Solid circle that obeys gravity",
        actorBlueprint = {
            components = {
                Drawing2 = {
                    drawData = {
                      color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                      fillCanvasSize = 256,
                      fillPng = "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAABlBMVEUAAAAkn94NkT71AAAAAXRSTlMAQObYZgAAAopJREFUeJztmkGOwjAMRUEsWHKEHCVHS4/GUXoEll1UzUwpIYlj+2fkqmIksvUD7G8LGn9Op78dF+OkxW/x9zzk+Dk+zyACfgNmKX6Jr3OXM9yOlGd8Hz5+zcCopSinGaP+GdcS4D7DlQBXRyiBpY2fY3UGPQUuCVcDbRKhBtokIjk0iQsF7gS4UYDOlaMAzTJQgGZJ47RfTY40y2sLjHqONEvfAvVUNUXQMtp4XcaZAwa9iLqMphPrKbvBVFnXyVRZ18lUWdfJxcs62SrLOplerueuy1AKwcpQCuF4IAvheSALEXggC8HHsxCCDFkIQYYOICkl6JSVEnTKSjkEeAmYEJCkDBKQpJTiGIhA6SSlKGSSEgKi0klrUekO4KG3ImntDcCst6IDWEArXs1AgNKrrVsQUHq1dQsCSjO3bkFAaebWTgg4EzDp3e4A5h4gaMCyC6DFnxNjBtSBWkfKDqgTt86cHVBHsgMYdwDUoe4AHjsAzghMHwF4IzD/DyB8PrB8gS+wK7DH0PovED/luxoCB/zqWYE9fv2twB5PQRA44GHvgEfWIx68vQZ03Q6cBkw9gP0aBQH7Xc9+37Tfee33bny19wZg7ttgQAAuSSAAFzX2XRBcN8GFFV55BQR4CUhrNycBUy8Al4dw/QgXmHBHKgKndCAQ+Hhe5HoeyKtgxwN5mQzX0XChDVficKkO1/J4se85oLQGHAeU5gK0J1gh7gUALRJosmCbhqmzdoKYMmrHC5pNTD+rIrDhhS0zpxfBlDESABp/TZY0TrNsbViSZetIEy2bFLCFCk1YbONWSbQpnLCVXE4Vb3hDOxsa4thSf2s1CEB6C/m/A/CPAVshoxx/Dpbyevb8ADwrn93OGkmmAAAAAElFTkSuQmCC",
                      gridSize = 15,
                      lineColor = { 0.66037992589614, 0.4, 0.93333333333333, 1 },
                      nextPathId = 4,
                      pathDataList = { {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 1,
                          points = { {
                              x = 5,
                              y = 0
                            }, {
                              x = 10,
                              y = 5
                            } },
                          style = 2
                        }, {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 2,
                          points = { {
                              x = 10,
                              y = 5
                            }, {
                              x = 5,
                              y = 10
                            } },
                          style = 3
                        }, {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 3,
                          points = { {
                              x = 5,
                              y = 10
                            }, {
                              x = 0,
                              y = 5
                            } },
                          style = 3
                        }, {
                          color = { 0.14360261804917, 0.62352941176471, 0.87058823529412, 1 },
                          id = 4,
                          points = { {
                              x = 0,
                              y = 5
                            }, {
                              x = 5,
                              y = 0
                            } },
                          style = 2
                        } },
                      scale = 10
                    },
                    physicsBodyData = {
                      scale = 10,
                      shapes = { {
                          radius = 5,
                          type = "circle",
                          x = 5,
                          y = 5
                        } }
                    }
                },
                Body = {gravityScale = 1},
                CircleShape = {},
                Solid = {},
                Falling = {}
            }
        },
        base64Png = "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEABAMAAACuXLVVAAAAFVBMVEUAAAAJKDcST28bd6Ykn94knt0kndxydfh2AAAAB3RSTlMAQIC////+2XIY7gAABJtJREFUeJztnQt6nDAMhDctB8imPQDZ+ACb0AOwhfb+R2oISzBgwA9pxv2CLjB/pJHsJWCfTkf8z3Hu45Gi/VK1VlQXKMX55Ve7iAbGcK6W6neGZ4D8k+OPt9OgLH/elFfPwsOufBe/1bzww0e+C506PLz46r8nQUPfK/1DNKW0/lOIfBfCBN7lVyKI0BcliNIXJIjUFyOI1hcaCAn6Ijn4lqIvQJCon0wQNv9ckTiVTap+IkFnwD+pBK/x+skG6KOM1U83QB/RRTAy+tEE36X0I4sgVYAumhiAn3L6UUUQ6oAhymAAIwsQnAJBB/YRmAJJB/YR6ENRB/ZxC0qAvH7bhvxiU0hAUApUEhCSApUEBKRAKQH+KVBKgHcK1BLgmwK1BHimQDEBfilQTEDb1h4Amvo+K4L4MjiN6y6A0QXY3RcIb4SWUXITsNuJqj34ETs2LNQBdmxo9AE2bahuwS62pqHqFBxiqwbie2FXbNgQUoGtUWAwAOujAKO/XgNQBdZrAOmBLtZqAOmBLlZqAKvA2iwqQOp/12aRAQG0a+sBTr9tyRZwN6JBArgaEQrgaERoBVyNCAZYNqLBAixNgNVfmgBcgaUJlH8SLmNuAoMGqNkA8+UArT9fDuAenLuwwANMXWjwANNRBNsOjjEZRfqPBRxB9uDUhQUDwHahYQDc2AC2Cxn6NgDFg7YL6QAFB2BsA8MBqNkAYx8SVoIuxjbg6I8ApCYY24AOULAArrkAGBbALRcA0hgY+5Clzwe470spW+I+HrlzKAOA8gMA/mxijCt3EGYA0O+JYP8oWcaNO4mzAaAtBcOTKp7+fTE4AL4yQJsFAHE7kAHA4wFwABwAB8AB8OUBsliOvzQAfUuWCQD9lxEdwLAB6M8HiAD0JyQ1+xnRNY/HdESAMo8npfSH1USATP5fwFsMhvfJDBuANgqH/5oVLID6DkCbRGUuALRB8PkWCwtg0GcNgvG1UlIf0gHqTwBSG5T5AJD68DQGpQ0aNoD9cjelDWoLoGAA2C+1UtqgtADoLzYzXDj9wIDgwilAgQeoJwCEn2flBID+iQfehfOPXOAurGcA8FE0swB+FJ3mATbB8rNXsAnmFoCbYG4BuAkW+mATuL58hppgaQGwCZYWAJvAoZ/Bx+8FDsD9+T+wBi4LnICNuHYcDawR6xUA+jEgqBqsHwgEqsFaBTI4DAdTg60jmegHItGPhKIfioVYkzcs2IW6/t75fOo23DukkX44Hv14QG0b7iZAeRr6nJusmoL9EyKVd2Ye+vyDUvlHxdIPy+UfF0w/MJl/ZDT90Gz+seEaKfAZglawj46X3xeUgQD06wOkUxBx1ZioD6MuUzFy+nH3iAgWoYwCkEtB9G02QgTx9/kIFSHhsr3g+9xcETiDp2HS9ROuMxIhSL3oL9UGTfJti+xrxRIJkgwoQJBowCEuZP1oAjH9SALRC0/DfZDef2kE0vrvBIarfwqayoL2s8N3bWzOOvrv4XXb7Kvmxcv7Tqi0733euXBZL/sWwmoWKoR8Fw8Xx7XX1TP2+vGnS/VZjKZ6Q/3ts+gvXudoHyEV/wDH2DHZdglO0QAAAABJRU5ErkJggg==",
    },
    {
        entryType = "actorBlueprint",
        title = "Text box",
        description = "Block of text, pinned to the bottom of the card",
        actorBlueprint = {
            components = {
                Text = {
                    content = "To be?"
                }
            }
        },
        base64Png = "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",
    },
    {
       entryType = "actorBlueprint",
       title = "Navigation button",
       description = "Text box that sends the player to another card when tapped",
       actorBlueprint = {
          components = {
             Text = {
                content = "Tap here to go to the card specified in my Rules.",
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
       base64Png = "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",
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
