-- Core library

local CORE_LIBRARY = {
    {
        entryType = "actorBlueprint",
        title = "Wall",
        description = "A rectangular solid that doesn't move.",
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
        description = "A circular solid that falls.",
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
        title = "Text",
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
       title = "Button",
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
