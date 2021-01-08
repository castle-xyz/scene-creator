function Client:moveActorForward(actorId, command)
   if self.behaviorsByName.Text.components[actorId] then
      -- text actors maintain their own order
      if command then
         self:command(
            'move text forward',
            { params = { 'actorId' } },
            function(params, live)          
               self.behaviorsByName.Text:callHandler('moveForward', self.behaviorsByName.Text.components[actorId])
            end, function()
               self.behaviorsByName.Text:callHandler('moveBackward', self.behaviorsByName.Text.components[actorId])
         end)
      else
         self.behaviorsByName.Text:callHandler('moveForward', self.behaviorsByName.Text.components[actorId])
      end
      return
   end
    local actor = self.actors[actorId]
    if actor.drawOrder < table.maxn(self.actorsByDrawOrder) then
        local bodyId, body = self.behaviorsByName.Body:getBody(actor.actorId)
        local fixtures = body:getFixtures()

        local newDrawOrder

        for _, fixture in pairs(fixtures) do
            local hits = self.behaviorsByName.Body:getActorsAtBoundingBox(
                fixture:getBoundingBox())
            for hit in pairs(hits) do -- Find greatest draw order below us
                local otherActor = self.actors[hit]
                if (otherActor.drawOrder > actor.drawOrder and
                        (not newDrawOrder or otherActor.drawOrder < newDrawOrder)) then
                    newDrawOrder = otherActor.drawOrder
                end
            end
        end

        if newDrawOrder then
            if command then
                self:command('move forward', {
                    params = { 'newDrawOrder' },
                }, function(params, live)
                    if live then
                        self:send('setActorDrawOrder', actorId, newDrawOrder)
                    else
                        self:moveActorForward(actorId, false)
                    end
                end, function()
                    self:moveActorBackward(actorId, false)
                end)
            else
                self:send('setActorDrawOrder', actor.actorId, newDrawOrder)
            end
        end
    end
end

function Client:moveActorBackward(actorId, command)
   if self.behaviorsByName.Text.components[actorId] then
      -- text actors maintain their own order
      if command then
         self:command(
            'move text backward',
            { params = { 'actorId' } },
            function(params, live)          
               self.behaviorsByName.Text:callHandler('moveBackward', self.behaviorsByName.Text.components[actorId])
            end, function()
               self.behaviorsByName.Text:callHandler('moveForward', self.behaviorsByName.Text.components[actorId])
         end)
      else
         self.behaviorsByName.Text:callHandler('moveBackward', self.behaviorsByName.Text.components[actorId])
      end
      return
   end
    local actor = self.actors[actorId]
    if actor.drawOrder > 1 then
        local bodyId, body = self.behaviorsByName.Body:getBody(actor.actorId)
        local fixtures = body:getFixtures()

        local newDrawOrder

        for _, fixture in pairs(fixtures) do
            local hits = self.behaviorsByName.Body:getActorsAtBoundingBox(
                fixture:getBoundingBox())
            for hit in pairs(hits) do -- Find greatest draw order below us
                local otherActor = self.actors[hit]
                if (otherActor.drawOrder < actor.drawOrder and
                        (not newDrawOrder or otherActor.drawOrder > newDrawOrder)) then
                    newDrawOrder = otherActor.drawOrder
                end
            end
        end

        if newDrawOrder then
            if command then
                self:command('move backward', {
                    params = { 'newDrawOrder' },
                }, function(params, live)
                    if live then
                        self:send('setActorDrawOrder', actorId, newDrawOrder)
                    else
                        self:moveActorBackward(actorId, false)
                    end
                end, function()
                    self:moveActorForward(actorId, false)
                end)
            else
                self:send('setActorDrawOrder', actor.actorId, newDrawOrder)
            end
        end
    end
end

function Client:moveActorToFront(actorId)
   if self.behaviorsByName.Text.components[actorId] then
      -- text actors maintain their own order
      local oldOrdering = self.behaviorsByName.Text:getOrdering()
      self:command(
         'move text to front',
         { params = { 'oldOrdering' } },
         function(params, live)
            self.behaviorsByName.Text:callHandler('moveToFront', self.behaviorsByName.Text.components[actorId])
         end, function()
            self.behaviorsByName.Text:callHandler('setOrdering', oldOrdering)
      end)
      return
    end
    local oldDrawOrder = self.actors[actorId].drawOrder
    self:command('move to front', {
        params = { 'oldDrawOrder' },
    }, function()
        local highestDrawOrder = table.maxn(self.actorsByDrawOrder)
        if self.actors[actorId].drawOrder ~= highestDrawOrder then
            self:send('setActorDrawOrder', actorId, highestDrawOrder)
        end
    end, function()
        self:send('setActorDrawOrder', actorId, oldDrawOrder)
    end)
end

function Client:moveActorToBack(actorId)
   if self.behaviorsByName.Text.components[actorId] then
      -- text actors maintain their own order
      local oldOrdering = self.behaviorsByName.Text:getOrdering()
      self:command(
         'move text to back',
         { params = { 'oldOrdering' } },
         function(params, live)
            self.behaviorsByName.Text:callHandler('moveToBack', self.behaviorsByName.Text.components[actorId])
         end, function()
            self.behaviorsByName.Text:callHandler('setOrdering', oldOrdering)
      end)
      return
   end
    local oldDrawOrder = self.actors[actorId].drawOrder
    self:command('move to back', {
        params = { 'oldDrawOrder' },
    }, function()
        if self.actors[actorId].drawOrder ~= 1 then
            self:send('setActorDrawOrder', actorId, 1)
        end
    end, function()
        self:send('setActorDrawOrder', actorId, oldDrawOrder)
    end)
end

function Client:duplicateSelection()
    -- Got a ghost? Duplicate the blueprint
    for actorId in pairs(self.selectedActorIds) do
        local actor = self.actors[actorId]
        if actor and actor.isGhost then
            local oldEntry = self.library[actor.parentEntryId]
            local newEntryId = util.uuid()
            self:command('duplicate blueprint', {
                params = { 'oldEntry', 'newEntryId' },
            }, function(params, live)
                self:duplicateBlueprint(oldEntry, { newEntryId = newEntryId })
                if live then
                    -- Immediately select entry
                    self:syncBelt()
                    self:deselectAllActors()
                    for i, elem in ipairs(self.beltElems) do
                        if elem.entryId == newEntryId then
                            self.beltTargetIndex = i
                            self.beltEntryId = newEntryId
                            self.beltHighlightEnabled = true
                            break
                        end
                    end
                    self:syncBeltGhostSelection()
                end
            end, function()
                self:send('removeLibraryEntry', newEntryId)
            end)
            return
        end
    end

    -- Generate map of actor ids to new ids for their duplicates
    local newActorIds = {}
    for actorId in pairs(self.selectedActorIds) do
        newActorIds[actorId] = self:generateActorId()
    end

    self:command('duplicate', {
        params = { 'newActorIds' },
    }, function()
        -- Make sure actors still exist
        for actorId in pairs(newActorIds) do
            if not self.actors[actorId] then
                return 'actor was deleted'
            end
        end

        -- Use blueprints to duplicate. Nudge position a little bit.
        for actorId in pairs(newActorIds) do
            local bp = self:blueprintActor(actorId)
            if bp.components.Body then
                bp.components.Body.x = bp.components.Body.x + 0.5 * UNIT
                bp.components.Body.y = bp.components.Body.y + 0.5 * UNIT
            end

            local actor = self.actors[actorId]
            self:sendAddActor(bp, {
                actorId = newActorIds[actorId],
                parentEntryId = actor.parentEntryId,
                drawOrder = actor.drawOrder + 1,
            })
        end

        -- Select new actors
        self:deselectAllActors()
        for actorId, newActorId in pairs(newActorIds) do
            self:selectActor(newActorId)
        end
    end, function()
        -- Make sure new actors still exist
        for actorId, newActorId in pairs(newActorIds) do
            if not self.actors[newActorId] then
                return 'actor was deleted'
            end
        end

        -- Remove new actors
        for actorId, newActorId in pairs(newActorIds) do
            self:send('removeActor', self.clientId, newActorId)
        end
    end)
end

function Client:deleteSelection()
    -- Got a ghost? Delete the blueprint
    for actorId in pairs(self.selectedActorIds) do
        local actor = self.actors[actorId]
        if actor and actor.isGhost then
            local entry = self.library[actor.parentEntryId]
            if not entry then
                return
            end

            -- Make sure no other actors have this
            for otherActorId, otherActor in pairs(self.actors) do
                if otherActorId ~= actorId and otherActor.parentEntryId == actor.parentEntryId then
                    castle.system.alert(
                        "Cannot delete '" .. entry.title .. "'",
                        "There are actors in the scene with this blueprint, so it cannot be deleted.")
                    return
                end
            end

            -- If this is the last body blueprint or last text blueprint, don't delete it
            local isLast = true
            for otherEntryId, otherEntry in pairs(self.library) do
                if otherEntryId ~= entry.entryId and otherEntry.entryType == 'actorBlueprint' then
                    if entry.actorBlueprint.components.Text and otherEntry.actorBlueprint.components.Text then
                        isLast = false
                        break
                    end
                    if entry.actorBlueprint.components.Body and otherEntry.actorBlueprint.components.Body then
                        isLast = false
                        break
                    end
                end
            end
            if isLast then
                castle.system.alert(
                    "Cannot delete '" .. entry.title .. "'",
                    entry.actorBlueprint.components.Text and
                    "This is the last blueprint with text." or
                    "This is the last blueprint with movement.")
                return
            end

            local weakActorId = actorId
            self:command('delete blueprint', {
                params = { 'entry', 'weakActorId' },
            }, function(params, live)
                self:deselectAllActors()
                if live then
                    self:send('removeActor', self.clientId, weakActorId)
                end
                self:send('removeLibraryEntry', entry.entryId)
            end, function()
                self:send('addLibraryEntry', entry.entryId, entry)
            end)
            return
        end
    end

    -- Save actor data
    local saves = {}
    for actorId in pairs(self.selectedActorIds) do
        local actor = self.actors[actorId]
        table.insert(saves, {
            actorId = actorId,
            bp = self:blueprintActor(actorId),
            parentEntryId = actor.parentEntryId,
            drawOrder = actor.drawOrder,
        })
    end
    table.sort(saves, function(save1, save2)
        return save1.drawOrder < save2.drawOrder
    end)

    self:command('delete', {
        params = { 'saves' },
    }, function()
        -- Make sure actors still exist
        for _, save in ipairs(saves) do
            if not self.actors[save.actorId] then
                return 'actor was deleted'
            end
        end

        -- Deselect and remove actors
        self:deselectAllActors()
        for _, save in ipairs(saves) do
            self:send('removeActor', self.clientId, save.actorId)
        end
    end, function()
        -- Resurrect actors
        for _, save in ipairs(saves) do
            self:sendAddActor(save.bp, {
                actorId = save.actorId,
                parentEntryId = save.parentEntryId,
                drawOrder = save.drawOrder,
            })
        end
    end)
end

function Client:uiInspectorActions()
    local actorId = next(self.selectedActorIds)
    if not actorId then
        return
    end
    local actor = self.actors[actorId]

    local actions = {}

    actions['moveSelectionForward'] = function()
        self:moveActorForward(next(self.selectedActorIds), true)
    end
    actions['moveSelectionBackward'] = function()
        self:moveActorBackward(next(self.selectedActorIds), true)
    end
    actions['moveSelectionToFront'] = function()
        self:moveActorToFront(next(self.selectedActorIds))
    end
    actions['moveSelectionToBack'] = function()
        self:moveActorToBack(next(self.selectedActorIds))
    end
    actions['duplicateSelection'] = function()
       self:duplicateSelection()
    end
    actions['deleteSelection'] = function()
       self:deleteSelection()
    end

    actions['setActiveTool'] = function(id) self:setActiveTool(id) end
    actions['setActiveToolWithOptions'] = function(opts) self:setActiveTool(opts.id, opts) end
    actions['closeInspector'] = function() self:deselectAllActors() end

    local tools = {}

    for _, tool in pairs(self.applicableTools) do
       table.insert(
          tools,
          {
             name = tool.name,
             behaviorId = tool.behaviorId,
          }
       )
    end

    local entry = self.library[actor.parentEntryId]
    local title = entry and entry.title or ''
    actions['setTitle'] = function(newTitle)
        if newTitle ~= title then
            local newEntry = util.deepCopyTable(entry)
            newEntry.title = newTitle
            self:command('change title', {
                params = { 'entry', 'newEntry' },
            }, function()
                self:send('updateLibraryEntry', self.clientId, entry.entryId, newEntry, {
                    updateActors = false,
                })
            end, function()
                self:send('updateLibraryEntry', self.clientId, entry.entryId, entry, {
                    updateActors = false,
                })
            end)
        end
    end

    ui.data(
       {
          isBlueprint = actor.isGhost or false,
          title = title,
          applicableTools = util.noArray(tools),
          activeToolBehaviorId = self.activeToolBehaviorId,
       },
       {
          actions = actions,
       }
    )
end
