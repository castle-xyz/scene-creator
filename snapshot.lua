function Common:startSnapshot()
    self.lastSaveAttemptTime = nil
    self.lastSuccessfulSaveData = nil
end

function Common:setLastSuccessfulSaveSnapshot(snapshot)
    self.lastSuccessfulSaveData = cjson.encode(
        {
            snapshot = snapshot
        }
    )
end

function Common:restoreSnapshot(snapshot)
    -- We had a bug where something in the body behavior was modifying the snapshot
    -- directly which caused issues when restarting a card. Easiest for now
    -- to just create a duplicate object since it only takes ~10ms
    snapshot = util.deepCopyTable(snapshot)

    self:send("clearScene")

    -- Clear existing library entries
    for entryId, entry in pairs(self.library) do
        if not entry.isCore then
            self:send("removeLibraryEntry", entryId)
        end
    end

    -- Clear existing actors
    for actorId in pairs(self.actors) do
        self:send("removeActor", self.clientId, actorId)
    end

    if snapshot then
        -- Add new library entries
        for entryId, entry in pairs(snapshot.library or {}) do
            self:send("addLibraryEntry", entryId, entry)
        end

        -- Add new actors
        for _, actorSp in pairs(snapshot.actors or {}) do
            local actorBp = actorSp.bp -- Already a duplicate so we can edit in-place
            local entry = snapshot.library[actorSp.parentEntryId]

            if snapshot.actorBlueprintInherit then
                local actorComps = actorBp.components
                if entry and entry.actorBlueprint then
                    local entryComps = entry.actorBlueprint.components
                    for compName, entryComp in pairs(entryComps) do
                        local actorComp = actorComps[compName]
                        if actorComp ~= '_NIL' then
                            if not actorComp then
                                -- Actor doesn't have this component at all, just use entry data
                                actorComps[compName] = entryComp
                            else
                                -- Use entry property wherever there's no actor property
                                for propName, entryProp in pairs(entryComp) do
                                    if actorComp[propName] == nil then
                                        actorComp[propName] = entryProp
                                    end
                                end
                            end
                        end
                    end
                end

                -- Clear `nil` overrides
                for compName, actorComp in pairs(actorComps) do
                    if actorComp == '_NIL' then
                        actorComps[compName] = nil
                    else
                        for propName, value in pairs(actorComp) do
                            if value == '_NIL' then
                                actorComp[propName] = nil
                            end
                        end
                    end
                end
            end

            self:sendAddActor(
                actorBp,
                {
                    actorId = actorSp.actorId,
                    parentEntryId = actorSp.parentEntryId
                }
            )
        end

        -- Load scene properties
        self:sendSetSceneProperties(snapshot.sceneProperties or {}, { snapshotLoaded = true })
    end
end

local function valueEqual(value1, value2)
    if type(value1) == "table" and type(value2) == "table" then
        -- Quick hack for checking table equality...
        return serpent.dump(value1, {sortkeys = true}) == serpent.dump(value2, {sortkeys = true})
    else
        return value1 == value2
    end
end
            
function Common:createSnapshot()
    snapshot = {}

    -- Snapshot non-core library entries
    snapshot.library = {}
    for entryId, entry in pairs(self.library) do
        if not entry.isCore then
            snapshot.library[entryId] = entry
        end
    end

    -- Snapshot actors in draw order
    snapshot.actors = {}
    self:forEachActorByDrawOrder(
        function(actor)
            local actorBp = self:blueprintActor(actor.actorId)
            local entry = self.library[actor.parentEntryId]

            -- Remove properties that are equal to corresponding property from
            -- blueprint. Also mark explicit `nil` overrides as `'_NIL'`.
            if entry and entry.actorBlueprint then
                local entryComps = entry.actorBlueprint.components
                for compName in pairs(entryComps) do
                    if actorBp.components[compName] == nil then
                        actorBp.components[compName] = '_NIL'
                    end
                end
                for compName, actorComp in pairs(actorBp.components) do
                    if actorComp ~= '_NIL' then
                        local entryComp = entryComps[compName]
                        if entryComp then
                            for propName in pairs(entryComp) do
                                if actorComp[propName] == nil then
                                    actorComp[propName] = '_NIL'
                                end
                            end
                            for propName, actorProp in pairs(actorComp) do
                                if actorProp ~= '_NIL' then
                                    local entryProp = entryComp[propName]
                                    local propValueEqual = false
                                    if compName == 'Drawing2' and (propName == 'drawData' or propName == 'physicsBodyData') then
                                        -- Compare drawing data by hash
                                        propValueEqual = actorComp.hash == entryComp.hash
                                    else
                                        propValueEqual = valueEqual(actorProp, entryProp)
                                    end
                                    if propValueEqual then
                                        actorComp[propName] = nil
                                    end
                                end
                            end
                            if not next(actorComp) then
                                -- No actor overrides in this component, just remove
                                actorBp.components[compName] = nil
                            end
                        end
                    end
                end
            end
            
            table.insert(
                snapshot.actors,
                {
                    actorId = actor.actorId,
                    parentEntryId = actor.parentEntryId,
                    bp = actorBp
                }
            )
        end
    )

    -- Save scene properties
    snapshot.sceneProperties = self.sceneProperties

    snapshot.actorBlueprintInherit = true

    return snapshot
end

function Common:saveScene(snapshot)
    if not self.performing then
        self.lastSaveAttemptTime = love.timer.getTime()

        local snapshot = snapshot or self:createSnapshot()
        local data =
            cjson.encode(
            {
                snapshot = snapshot,
            }
        )
        if data ~= self.lastSuccessfulSaveData then
            --print('---------------')
            --print(serpent.block(snapshot))
            --print('size', #data)
            if next(self.actors) then
                pcall(
                    function()
                        --writeBackup(data)
                    end
                )
            end

            jsEvents.send(
                "GHOST_MESSAGE",
                {
                    messageType = "UPDATE_SCENE",
                    data = data
                }
            )
            self.lastSuccessfulSaveData = data
        end
    end
end

function Common:updateAutoSaveScene()
    if not self.performing then
        if not self.lastSaveAttemptTime or love.timer.getTime() - self.lastSaveAttemptTime > 1 then
            self:saveScene()
        end
    end
end
