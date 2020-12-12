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
    if not next(self.selectedActorIds) then
        return
    end

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

    ui.data(
       {
          applicableTools = util.noArray(tools),
          activeToolBehaviorId = self.activeToolBehaviorId,
       },
       {
          actions = actions,
       }
    )
end
