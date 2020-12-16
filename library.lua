-- Core library

local DrawingData = require 'library_drawing_data'

local CORE_BELT_ORDER_OFFSET = 1000000
local CORE_LIBRARY = {
    {
        entryType = "actorBlueprint",
        title = "Wall",
        description = "Solid square that doesn't move",
        actorBlueprint = {
            components = {
                Drawing2 = DrawingData.Wall.Drawing2,
                Body = {
                    widthScale = 0.1,
                    heightScale = 0.1,
                },
                Solid = {},
                Tags = {},
            }
        },
        base64Png = DrawingData.Wall.base64Png,
        beltOrder = CORE_BELT_ORDER_OFFSET + 2,
    },
    {
        entryType = "actorBlueprint",
        title = "Ball",
        description = "Solid circle that obeys gravity",
        actorBlueprint = {
            components = {
                Drawing2 = DrawingData.Ball.Drawing2,
                Body = {
                    gravityScale = 1,
                    widthScale = 0.1,
                    heightScale = 0.1,
                },
                Solid = {},
                Falling = {},
                Tags = {},
            }
        },
        base64Png = DrawingData.Ball.base64Png,
        beltOrder = CORE_BELT_ORDER_OFFSET + 1,
    },
    {
        entryType = "actorBlueprint",
        title = "Text box",
        description = "Block of text, pinned to the bottom of the card",
        actorBlueprint = {
            components = {
                Text = {
                    content = "Your text goes here"
                },
                Tags = {},
            }
        },
        base64Png = DrawingData.TextBox.base64Png,
        beltOrder = CORE_BELT_ORDER_OFFSET + 3,
    },
    {
       entryType = "actorBlueprint",
       title = "Navigation button",
       description = "Text box that sends the player to another card when tapped",
       actorBlueprint = {
          components = {
             Text = {
                content = "Tap me to go to the card specified in my rules",
             },
             Tags = {},
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
       base64Png = DrawingData.NavigationButton.base64Png,
        beltOrder = CORE_BELT_ORDER_OFFSET + 4,
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

function Common:generateLibraryId()
    local suffix = tostring(self._nextLibraryIdSuffix)
    self._nextLibraryIdSuffix = self._nextLibraryIdSuffix + 1

    local prefix = "0"

    return prefix .. "-" .. suffix
end

function Common:startLibrary()
    -- need this to be backwards compatible. we used to use the same
    -- ids for this and for physics bodies. this broke when we added multiple layers
    self._nextLibraryIdSuffix = 2
    self.library = {} -- `entryId` -> entry

    for _, entrySpec in pairs(CORE_LIBRARY) do
        local entryId = self:generateLibraryId()
        local entry = util.deepCopyTable(entrySpec)
        entry.entryId = entryId
        entry.isCore = true
        self.library[entryId] = entry
    end

    self:markBeltDirty()
end

-- Message receivers

function Common.receivers:addLibraryEntry(time, entryId, entry)
    local entryCopy = util.deepCopyTable(entry)
    entryCopy.entryId = entryId
    self.library[entryId] = entryCopy

    if entryCopy and entryCopy.actorBlueprint and entryCopy.actorBlueprint.components and entryCopy.actorBlueprint.components.Drawing2 then
        self.behaviorsByName.Drawing2:preloadDrawing(entryCopy.actorBlueprint.components.Drawing2)
    end

    self:markBeltDirty()
end

function Common.receivers:removeLibraryEntry(time, entryId)
    self.library[entryId] = nil

    self:markBeltDirty()
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
                            parentEntryId = entryId,
                            drawOrder = actor.drawOrder,
                            isGhost = actor.isGhost,
                        }
                    )
                end
            end
        end
    end

    local newEntryCopy = util.deepCopyTable(newEntry)
    newEntryCopy.entryId = entryId
    self.library[entryId] = newEntryCopy

    self:markBeltDirty()
end
