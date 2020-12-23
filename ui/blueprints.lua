function Client:_makeBlueprintData(actor)
   local saveBlueprintData = nil
   if not saveBlueprintData then
      local oldEntry = self.library[actor.parentEntryId]
      if oldEntry ~= nil and oldEntry.isCore then
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
    local base64Png = self:actorBlueprintPng(actor.actorId)
    local newEntry = {
        entryType = 'actorBlueprint',
        title = saveBlueprintData.title,
        description = saveBlueprintData.description,
        actorBlueprint = newActorBp,
        base64Png = base64Png,
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
    local base64Png = self:actorBlueprintPng(actor.actorId)
    self:send('addLibraryEntry', newEntryId, {
        entryType = 'actorBlueprint',
        title = saveBlueprintData.title,
        description = saveBlueprintData.description,
        actorBlueprint = newActorBp,
        base64Png = base64Png,
    })
    self:send('setActorParentEntryId', actor.actorId, newEntryId)
end

function Client:uiBlueprints()
   local data = { library = self.library }
   local actions = {}

    --runOnProfilerFrame("uiBlueprints data", function ()
    --    printObject(data)
   --end)
   
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

   actions['addBlueprintToScene'] = function(entryId)
      self:_addBlueprintToScene(entryId)
   end
   
   ui.data(data, { actions = actions })
end

function Client:_addBlueprintToScene(entryId, x, y)
   local entry = self.library[entryId]

   -- If core entry, duplicate the entry and use that instead
   if entry.isCore then
       entry = self:duplicateBlueprint(entry)
       entryId = entry.entryId
   end
   
   -- Set up actor blueprint and id
    local bp = util.deepCopyTable(entry.actorBlueprint)
    if bp.components.Body then -- Has a `Body`? Position at given position or window center
        if not (x and y) then
            x, y = self.viewX, self.viewY
        end
        local gridSize = self.behaviorsByName.Grab:getGridSize()
        bp.components.Body.x = util.quantize(x, gridSize)
        bp.components.Body.y = util.quantize(y, gridSize)
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
