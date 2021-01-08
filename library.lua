-- Core library

local DrawingData = require 'library_drawing_data'

local CORE_LIBRARY = {
    {
        entryType = "actorBlueprint",
        title = "Brick",
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
        --entry.isCore = true -- NOTE(nikki): We're dropping core blueprints for now till new belt UX
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

function Common:updateBlueprintFromActor(actorId, opts)
    opts = opts or {}

    local actor = self.actors[actorId]
    if not actor then
        print('tried to update blueprint from non-existent actor')
        return
    end

    local oldEntry = actor.parentEntryId and self.library[actor.parentEntryId]
    if not oldEntry then
        print('tried to update blueprint from actor without parent entry id')
        return
    end

    -- Blueprint the actor and zero-out layout x, y
    local newActorBp = self:blueprintActor(actorId)
    if newActorBp.components.Body then
        newActorBp.components.Body.x, newActorBp.components.Body.y = nil, nil
    end

    -- Compute base64Png if needed
    local base64Png = oldEntry.base64Png
    if opts.updateBase64Png then
        base64Png = self:actorBlueprintPng(actorId)
    end

    local newEntry = {
        entryType = 'actorBlueprint',
        title = opts.title or oldEntry.title or '',
        description = opts.description or oldEntry.description or '',
        actorBlueprint = newActorBp,
        base64Png = base64Png,
    }

    self:send('updateLibraryEntry', self.clientId, oldEntry.entryId, newEntry, {
        updateActors = true,
        skipActorId = actorId,
    })
end

function Common.receivers:updateLibraryEntry(time, clientId, entryId, newEntry, opts)
    local oldEntry = self.library[entryId]
    assert(oldEntry.entryType == newEntry.entryType, "updateLibraryEntry: cannot change entry type")

    if self.clientId == clientId then
        if newEntry.entryType == "actorBlueprint" and opts.updateActors then
            local newBp = newEntry.actorBlueprint
            for actorId, actor in pairs(self.actors) do
                if actorId ~= opts.skipActorId and actor.parentEntryId == entryId then
                    local oldBp = self:blueprintActor(actorId)
                    local updateBp = util.deepCopyTable(newBp)
                    if updateBp.components.Body then
                        -- Keep local overrides of layout properties
                        -- TODO(nikki): Allow pushing updates to these some times
                        if oldBp.components.Body.x then
                            updateBp.components.Body.x = oldBp.components.Body.x
                        end
                        if oldBp.components.Body.y then
                            updateBp.components.Body.y = oldBp.components.Body.y
                        end
                        if oldBp.components.Body.angle then
                            updateBp.components.Body.angle = oldBp.components.Body.angle
                        end
                        if oldBp.components.Body.widthScale then
                            updateBp.components.Body.widthScale = oldBp.components.Body.widthScale
                        end
                        if oldBp.components.Body.heightScale then
                            updateBp.components.Body.heightScale = oldBp.components.Body.heightScale
                        end
                    end
                    self:send("removeActor", self.clientId, actorId)
                    self:sendAddActor(
                        updateBp,
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

-- Utils

function Client:haveLibraryEntryWithTitle(title)
    for _, entry in pairs(self.library) do
        if entry.title == title then
            return true
        end
    end
    return false
end

function Client:duplicateBlueprint(entry, opts)
    opts = opts or {}

    local newEntry = util.deepCopyTable(entry)
    newEntry.entryId = opts.newEntryId or util.uuid()
    newEntry.isCore = nil
    newEntry.beltOrder = nil

    local titlePrefix = entry.title:gsub(' %d*$', '')
    local titleSuffix = 2
    while self:haveLibraryEntryWithTitle(titlePrefix .. ' ' .. titleSuffix) do
        titleSuffix = titleSuffix + 1
    end
    newEntry.title = titlePrefix .. ' ' .. titleSuffix

    self:send('addLibraryEntry', newEntry.entryId, newEntry)

    return newEntry
end
