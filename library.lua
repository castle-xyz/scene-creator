-- Core library

local DrawingData = require 'library_drawing_data'
local ExtraTemplates = require 'library_extra_templates'

local CORE_LIBRARY = {}

CORE_TEMPLATES = {
    {
        isBlank = true,
        entryType = "actorBlueprint",
        title = "Object",
        description = "Blank actor",
        actorBlueprint = {
            components = {
                Drawing2 = {
                    -- Based on serialized form of 'Wall' after clearing drawing
                    disabled = false,
                    drawData = {
                        fillPixelsPerUnit = 25.600000000000001,
                        framesBounds = {
                            {
                                maxX = 5,
                                maxY = 5,
                                minX = -5,
                                minY = -5
                            }
                        },
                        gridSize = 0.71428571428570997,
                        layers = {
                            {
                                frames = {
                                    {
                                        fillImageBounds = {
                                            maxX = 0,
                                            maxY = 0,
                                            minX = 0,
                                            minY = 0
                                        },
                                        isLinked = false,
                                        pathDataList = {}
                                    }
                                },
                                id = "layer1",
                                isVisible = true,
                                title = "Layer 1"
                            }
                        },
                        lineColor = {
                            0.66037992589614003,
                            0.40000000000000002,
                            0.93333333333333002,
                            1
                        },
                        numTotalLayers = 1,
                        pathDataList = {},
                        scale = 10,
                        selectedFrame = 1,
                        selectedLayerId = "layer1",
                        version = 3
                    },
                    framesPerSecond = 4,
                    initialFrame = 1,
                    loop = false,
                    physicsBodyData = {
                       scale = 10,
                       shapes = { {
                           p1 = {
                             x = 5,
                             y = 5
                           },
                           p2 = {
                             x = -5,
                             y = -5
                           },
                           type = "rectangle"
                         } },
                       version = 2,
                       zeroShapesInV1 = false
                    },
                    playing = false
                },
                Body = {
                    widthScale = 0.1,
                    heightScale = 0.1,
                },
                Tags = {},
            }
        },
        base64Png = DrawingData.Object.base64Png,
    },
    {
        isBlank = true,
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
    {title = "Ball",actorBlueprint = {components = {Drawing2 = DrawingData.Ball.Drawing2,Falling = {disabled = false,gravity = 1},Friction = {disabled = false,friction = 0.2},Bouncy = {disabled = false,bounciness = 1},Tags = {disabled = false,tagsString = ""},Solid = {disabled = false},Body = {width = 0.98995000123978,disabled = false,angle = 0,widthScale = 0.1,layerName = "main",heightScale = 0.1,bodyType = "dynamic",fixtures = {{y = 0,x = 0,radius = 5,shapeType = "circle"}},massData = {0,0,4,0.66666668653488},editorBounds = {maxX = 5,minY = -5,minX = -5,maxY = 5},bullet = false,height = 0.98995000123978,visible = true},Moving = {vy = 0,disabled = false,vx = 0,density = 1,angularVelocity = 0}}},entryType = "actorBlueprint",entryId = "8024c161-1922-4f75-cf26-cf009514816c",description = "Solid circle that obeys gravity", base64Png = DrawingData.Ball.base64Png},
    {title = "Wall",actorBlueprint = {components = {Drawing2 = DrawingData.Wall.Drawing2,Tags = {disabled = false,tagsString = ""},Solid = {disabled = false},Body = {width = 0.98995000123978,disabled = false,angle = 0,widthScale = 0.1,layerName = "main",heightScale = 0.1,bodyType = "static",fixtures = {{points = {-5,-5,-5,5,5,5,5,-5},shapeType = "polygon"}},massData = {0,0,0,0},editorBounds = {maxX = 5,minY = -5,minX = -5,maxY = 5},bullet = false,height = 0.98995000123978,visible = true},Friction = {disabled = false,friction = 0.2}}},entryType = "actorBlueprint",entryId = "a260c3d2-1d0f-4df1-cda7-8124ac58ca85",description = "Solid square that doesn't move",base64Png = DrawingData.Wall.base64Png},
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

for _, template in ipairs(ExtraTemplates) do
   print('adding template: ' .. tostring(template.title))
   table.insert(CORE_TEMPLATES, #CORE_TEMPLATES - 3, template)
end

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

    if self.currentCommand and self.currentCommandMode == 'undo' and self.currentCommand.autoForkedFromEntryId then
        -- When undoing an auto-fork, remove the forked blueprint and restore actor to parent blueprint
        self:send('removeLibraryEntry', oldEntry.entryId)
        self:send('setActorParentEntryId', actorId, self.currentCommand.autoForkedFromEntryId)
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

    local shouldFork = false
    if not (self.currentCommand and self.currentCommandMode == 'undo') and not (opts.explicit or actor.isGhost) then
        -- If edited an actor, and there's other instances of this blueprint, we should "fork"
        for otherActorId, otherActor in pairs(self.actors) do
            if not otherActor.isGhost and otherActorId ~= actorId and otherActor.parentEntryId == actor.parentEntryId then
                shouldFork = true
                break
            end
        end
    end

    if not shouldFork then
        -- Not forking, update the same entry
        self:send('updateLibraryEntry', self.clientId, oldEntry.entryId, newEntry, {
            updateActors = true,
            applyLayoutChanges = opts.applyLayoutChanges,
            skipActorId = actorId,
        })
    else
        -- Forking. Create a new entry with parent as current, update actor to use this entry
        local result = self:duplicateBlueprint(newEntry)
        self:send('setActorParentEntryId', actorId, result.entryId)
        if self.currentCommand then
            self.currentCommand.autoForkedFromEntryId = oldEntry.entryId
        end
    end
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
                                local equal = false
                                if behaviorName == 'Drawing2' and (key == 'drawData' or key == 'physicsBodyData') then
                                    equal = oldBp.components[behaviorName].hash == bp.components[behaviorName].hash
                                elseif not opts.applyLayoutChanges and behaviorName == 'Body' and (key == 'widthScale' or key == 'heightScale' or key == 'x' or key == 'y' or key == 'angle') then
                                    -- Skip propagating layout changes unless explicitly asked for
                                else
                                    equal = valueEqual(
                                        oldBp.components[behaviorName][key],
                                        bp.components[behaviorName][key]
                                    )
                                end
                                if equal then
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

    if not opts.keepTitle or self:haveLibraryEntryWithTitle(newEntry.title) then
        local titlePrefix = entry.title:gsub(' %d*$', '')
        local titleSuffix = 2
        while self:haveLibraryEntryWithTitle(titlePrefix .. ' ' .. titleSuffix) do
            titleSuffix = titleSuffix + 1
        end
        newEntry.title = titlePrefix .. ' ' .. titleSuffix
    end

    self:send('addLibraryEntry', newEntry.entryId, newEntry)

    return newEntry
end
