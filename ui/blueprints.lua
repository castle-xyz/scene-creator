function Client:_makeBlueprintData(actor)
   local saveBlueprintData = self.saveBlueprintDatas[actor]
   if not saveBlueprintData then
      local oldEntry = self.library[actor.parentEntryId]
      if oldEntry.isCore then
         -- Don't overwrite core entries
         oldEntry = nil
      end
      saveBlueprintData = {
         entryId = oldEntry and oldEntry.entryId or nil,
         title = oldEntry and oldEntry.title or '',
         description = oldEntry and oldEntry.description or '',
      }
      self.saveBlueprintDatas[actor] = saveBlueprintData
   end
   return saveBlueprintData
end

function Client:_getExistingLibraryEntry(actorId, entryId)
    local existingEntry = self.library[entryId]
    local numOtherActors = 0
    if existingEntry then
        for otherActorId, otherActor in pairs(self.actors) do
            if otherActorId ~= actorId and otherActor.parentEntryId == existingEntry.entryId then
                numOtherActors = numOtherActors + 1
            end
        end
    end
    return existingEntry, numOtherActors
end

function Client:_updateBlueprint(actor, saveBlueprintData, existingEntry)
    local entryId = existingEntry.entryId
    local oldEntry = existingEntry
    local newActorBp = self:blueprintActor(actor.actorId)
    if newActorBp.components.Body then
        newActorBp.components.Body.x, newActorBp.components.Body.y = nil, nil
    end
    local newEntry = {
        entryType = 'actorBlueprint',
        title = saveBlueprintData.title,
        description = saveBlueprintData.description,
        actorBlueprint = newActorBp,
    }

    self:command('update blueprint', {
        params = { 'entryId', 'oldEntry', 'newEntry' },
    }, function(params, live)
        self:send('updateLibraryEntry', self.clientId, entryId, newEntry, {
            updateActors = true,
            skipActorId = actorId,
        })
    end, function()
        self:send('updateLibraryEntry', self.clientId, entryId, oldEntry, {
            updateActors = true,
            skipActorId = actorId,
        })
    end)
end

function Client:_addBlueprint(actor, saveBlueprintData)
    local newEntryId = util.uuid()
    local newActorBp = self:blueprintActor(actor.actorId)
    if newActorBp.components.Body then
        newActorBp.components.Body.x, newActorBp.components.Body.y = nil, nil
    end
    self:send('addLibraryEntry', newEntryId, {
        entryType = 'actorBlueprint',
        title = saveBlueprintData.title,
        description = saveBlueprintData.description,
        actorBlueprint = newActorBp,
    })
    self:send('setActorParentEntryId', actor.actorId, newEntryId)
end

function Client:_saveBlueprintButton(actor)
    ui.button('save blueprint', {
        flex = 1,
        icon = 'save',
        iconFamily = 'FontAwesome5',
        onClick = function()
            self.saveBlueprintDatas[actor] = nil
        end,
        popoverAllowed = true,
        popoverStyle = { width = 300 },
        popover = function(closePopover)
            ui.scrollBox('save blueprint', { flex = 1 }, function()
                local saveBlueprintData = self:_makeBlueprintData(actor)
                saveBlueprintData.title = ui.textInput('title', saveBlueprintData.title)
                saveBlueprintData.description = ui.textArea('description', saveBlueprintData.description)

                local existingEntry, numOtherActors = self:_getExistingLibraryEntry(actor.actorId, saveBlueprintData.entryId)
                if existingEntry then
                    if numOtherActors > 0 then
                        ui.markdown('This blueprint is used by ' .. numOtherActors ..
                            ' other actor' .. (numOtherActors > 1 and 's' or ''))
                    else
                        ui.markdown('No other actors use this blueprint')
                    end

                    ui.button('update used blueprint', {
                        icon = 'file-upload',
                        iconFamily = 'FontAwesome5',
                        onClick = function()
                            if saveBlueprintData.title == '' then
                                castle.system.alert('Title required', 'Please enter a title for the blueprint.')
                                return
                            end
                            for entryId, entry in pairs(self.library) do
                                if (entry.entryType == 'actorBlueprint' and
                                        entry.entryId ~= existingEntry.entryId and
                                        entry.title == saveBlueprintData.title) then
                                    castle.system.alert('Title in use',
                                        'This title is already used by another blueprint. Please enter a different title.')
                                    return
                                end
                            end

                            self:_updateBlueprint(actor, saveBlueprintData, existingEntry)
                            closePopover()
                        end,
                    })
                end

                ui.button('save as new blueprint', {
                    icon = 'addfile',
                    iconFamily = 'AntDesign',
                    onClick = function()
                        if saveBlueprintData.title == '' then
                            castle.system.alert('Title required', 'Please enter a title for the new blueprint.')
                            return
                        end
                        for entryId, entry in pairs(self.library) do
                            if entry.entryType == 'actorBlueprint' and entry.title == saveBlueprintData.title then
                                castle.system.alert('Title in use',
                                    'This title is already used by another blueprint. Please enter a different title.')
                                return
                            end
                        end

                        self:_addBlueprint(actor, saveBlueprintData)
                        closePopover()
                    end,
                })
            end)
        end
    })
end

function Client:uiBlueprints()
   local data = { library = self.library }
   local actions = {}
   
   local actorId = next(self.selectedActorIds)
   if actorId then
      local actor = self.actors[actorId]

      local saveBlueprintData = self:_makeBlueprintData(actor)
      local existingEntry, numOtherActors = self:_getExistingLibraryEntry(actorId, saveBlueprintData.entryId)

      data['saveBlueprintData'] = saveBlueprintData
      data['isExisting'] = (existingEntry ~= nil)
      data['numOtherActors'] = numOtherActors

      actions['updateBlueprint'] = function(saveBlueprintData)
         self:_updateBlueprint(actor, saveBlueprintData, existingEntry)
      end

      actions['addBlueprint'] = function(saveBlueprintData)
         self:_addBlueprint(actor, saveBlueprintData)
      end
   end
   
   ui.data(data, { actions = actions })
end

function Client:uiLegacyBlueprints()
    self:uiLibrary({
        id = 'add actor',
        filterType = 'actorBlueprint',
        buttons = function(entry)
            ui.button('add to scene', {
                flex = 1,
                icon = 'plus',
                iconFamily = 'FontAwesome5',
                onClick = function()
                    -- Set up actor blueprint and id
                    local bp = util.deepCopyTable(entry.actorBlueprint)
                    if bp.components.Body then -- Has a `Body`? Position at center of window.
                        local windowWidth, windowHeight = love.graphics.getDimensions()
                        bp.components.Body.x = util.quantize(self.viewX, 0.5 * UNIT)
                        bp.components.Body.y = util.quantize(self.viewY, 0.5 * UNIT)
                    end
                    local newActorId = self:generateActorId()

                    local entryId = entry.entryId
                    self:command('add', {
                        params = { 'bp', 'newActorId', 'entryId' },
                    }, function()
                        -- Add the actor
                        self:sendAddActor(bp, {
                            actorId = newActorId,
                            parentEntryId = entryId,
                        })

                        -- Select the actor. If it has a `Body`, switch to the `Grab` tool.
                        if bp.components.Body then
                            self:setActiveTool(nil)
                        end
                        self:deselectAllActors()
                        self:selectActor(newActorId)
                        self:applySelections()
                        if bp.components.Body then
                            self:setActiveTool(self.behaviorsByName.Grab.behaviorId)
                        end
                    end, function()
                        -- Make sure actor still exists
                        if not self.actors[newActorId] then
                            return 'actor was deleted'
                        end

                        -- Deselect and remove the actor
                        self:deselectActor(newActorId)
                        self:send('removeActor', self.clientId, newActorId)
                    end)
                end
            })
        end,
    })
end
