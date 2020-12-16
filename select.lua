-- Start / stop

function Client:startSelect()
    self.selectedActorIds = {} -- `actorId` -> `true` for all selected actors

    self.activeToolBehaviorId = nil -- `behaviorId` of active tool
    self.activeToolHistory = {} -- `{ behaviorId1, behaviorId2, ... }` of last active tools, oldest first, deduped, max 10
    self.applicableTools = {} -- `behaviorId` -> behavior, for tools applicable to selection
end

-- Methods

function Client:removeToolComponents(filter)
    if self.activeToolBehaviorId then
        local activeTool = self.tools[self.activeToolBehaviorId]
        for actorId, component in pairs(activeTool.components) do
            if self.clientId == component.clientId and filter(component) then
                self:send("removeComponent", self.clientId, actorId, activeTool.behaviorId)
            end
        end
    end
end

function Client:addToolComponents()
    if self.activeToolBehaviorId and self.applicableTools[self.activeToolBehaviorId] then
        local activeTool = self.tools[self.activeToolBehaviorId]
        if not activeTool.tool.noSelect then
            for actorId in pairs(self.selectedActorIds) do
                -- Check if there's already a component for this tool
                local component = activeTool.components[actorId]
                if component then
                    -- If the component is our own we can just keep it, else check if we can take it from the other client
                    if component.clientId ~= self.clientId then
                        local lastPingTime = self.lastPingTimes[component.clientId]
                        if not (lastPingTime and self.time - lastPingTime < 5) then
                            -- No ping from them recently, let's take it from them
                            self:send("removeComponent", self.clientId, actorId, self.activeToolBehaviorId)
                            self:send("addComponent", self.clientId, actorId, self.activeToolBehaviorId)
                        end
                    end
                else -- No component, just add
                    self:send("addComponent", self.clientId, actorId, self.activeToolBehaviorId)
                end
            end
        end
    end
end

function Client:applySelections()
    -- Clear stale selections and tools
    for actorId in pairs(self.selectedActorIds) do
        if not self.actors[actorId] then
            self:deselectActor(actorId)
        end
    end
    if not self.tools[self.activeToolBehaviorId] then
        self.activeToolBehaviorId = nil
    end

    -- Recompute applicable tool set
    do
        self.applicableTools = {}

        -- Find common behaviors across all actors -- used by dependency check below
        local commonBehaviorIds
        for actorId in pairs(self.selectedActorIds) do
            local actor = self.actors[actorId]
            if commonBehaviorIds then
                for behaviorId in pairs(commonBehaviorIds) do
                    if not actor.components[behaviorId] then
                        commonBehaviorIds[behaviorId] = nil
                    end
                end
            else
                commonBehaviorIds = {}
                for behaviorId in pairs(actor.components) do
                    commonBehaviorIds[behaviorId] = true
                end
            end
        end
        commonBehaviorIds = commonBehaviorIds or {}

        for behaviorId, tool in pairs(self.tools) do
            local applicable = true

            -- Check if it needs performance to be off or on
            if applicable then
                if self.performing and tool.tool.needsPerformingOff then
                    applicable = false
                end
                if not self.performing and tool.tool.needsPerformingOn then
                    applicable = false
                end
            end

            -- Check that dependencies are satisfied
            if
                (not tool.tool.noSelect and not (tool.tool.emptySelect and not (next(self.selectedActorIds))) and
                    applicable)
             then
                for dependencyName, dependency in pairs(tool.dependencies) do
                    if not commonBehaviorIds[dependency.behaviorId] then
                        applicable = false
                        break
                    end
                end
            end

            if applicable then
                self.applicableTools[behaviorId] = tool
            end
        end
    end

    -- Deactivate active tool if it doesn't apply any more
    if self.activeToolBehaviorId then
        if not self.applicableTools[self.activeToolBehaviorId] then
            self:setActiveTool(nil)
        end
    end

    -- Activate Grab by default when selection changes and Grab is applicable
    if self.selectionChanged and self.applicableTools[self.behaviorsByName.Grab.behaviorId] then
        self:setActiveTool(self.behaviorsByName.Grab.behaviorId)
    end

    -- Reset inspector tab when selection changes
    if self.selectionChanged then
       self.selectedInspectorTab = 'general'
    end
    
    -- If this deactivated the tool, pick another one
    if not self.activeToolBehaviorId then
        for i = #self.activeToolHistory, 1, -1 do -- Try history
            if self.applicableTools[self.activeToolHistory[i]] then
                self:setActiveTool(self.activeToolHistory[i])
                break
            end
        end
        if not self.activeToolBehaviorId then -- Still nothing? Pick tool with lowest id
            local someApplicableTool
            for behaviorId in pairs(self.applicableTools) do
                if not someApplicableTool or behaviorId < someApplicableTool then
                    someApplicableTool = behaviorId
                end
            end
            if someApplicableTool then
                self:setActiveTool(someApplicableTool)
            end
        end
    end

    -- Remove components whose actors aren't selected any more, add components for new selections
    self:removeToolComponents(
        function(component)
            return not self.selectedActorIds[component.actorId]
        end
    )
    self:addToolComponents()
    
    self.selectionChanged = false

    self:syncSelectionsWithBelt()
end

function Client:selectActor(actorId)
   if not self.selectedActorIds[actorId] then
      self.selectionChanged = true
   end
   
   self.selectedActorIds[actorId] = true

   -- auto open either Body or Text component
   local actor = self.actors[actorId]
   if self.behaviorsByName.Text.components[actorId] then
      self.openComponentBehaviorId = self.behaviorsByName.Text.behaviorId
   elseif self.behaviorsByName.Body.components[actorId] then
      self.openComponentBehaviorId = self.behaviorsByName.Body.behaviorId
   end
end

function Client:deselectActor(actorId)
    if self.selectedActorIds[actorId] then
        self.selectionChanged = true
    end
    self.selectedActorIds[actorId] = nil
end

function Client:deselectAllActors(opts)
    opts = opts or {}
    if not opts.noDeselectBelt then
        self.beltEntryId = nil
    end
    for actorId in pairs(self.selectedActorIds) do
        local skip = false
        if opts.noDeselectBelt then
            local actor = self.actors[actorId]
            if actor and actor.isGhost then
                skip = true
            end
        end
        if not skip then
            self:deselectActor(actorId)
        end
    end
end

function Client:setActiveTool(toolBehaviorId, toolOptions)
    if self.activeToolBehaviorId == toolBehaviorId then
        return -- Already active, skip
    end

    -- Remove all components from old tool, set new tool as active, add components to new tool
    self:removeToolComponents(
        function(component)
            return true
        end
    )
    self.activeToolBehaviorId = toolBehaviorId
    self:addToolComponents()

    -- Save to history
    if self.activeToolBehaviorId then
        local activeTool = self.tools[self.activeToolBehaviorId]
        if not activeTool.tool.noHistory then
            for i = #self.activeToolHistory, 1, -1 do -- Dedup
                if self.activeToolHistory[i] == self.activeToolBehaviorId then
                    table.remove(self.activeToolHistory, i) -- This shouldn't happen more than once...
                end
            end
            table.insert(self.activeToolHistory, self.activeToolBehaviorId)
            while #self.activeToolHistory > 10 do -- Limit to 10
                table.remove(self.activeToolHistory, 1)
            end
        end

        if activeTool.handlers['onSetActive'] then
            activeTool.handlers['onSetActive'](activeTool, toolOptions)
        end
    end
end

function Client:getActiveTool()
    if self.activeToolBehaviorId == nil then
        return nil
    end

    return self.tools[self.activeToolBehaviorId].tool
end

function Client:isActiveToolFullscreen()
    if self.activeToolBehaviorId then
        local activeTool = self.tools[self.activeToolBehaviorId]
        if activeTool and activeTool.handlers['isFullScreen'] and activeTool.handlers['isFullScreen'](activeTool) then
            return true
        end
    end

    return false
end

function Client:selectActorAtPoint(x, y, hits)
    local hits = hits or self.behaviorsByName.Body:getActorsAtPoint(x, y)
    local pick
    if next(hits) then -- Pick the next unselected hit in draw order. Belt-highlighted actors get priority.
        local order = {}
        for actorId in pairs(hits) do
            table.insert(order, actorId)
        end
        local highlightEntry = self.beltHighlightEnabled and self.library[self.beltEntryId]
        if hightlightEntry and highlightEntry.isCore then
            highlightEntry = nil
        end
        table.sort(
            order,
            function(actorId1, actorId2)
                local actor1, actor2 = self.actors[actorId1], self.actors[actorId2]
                if highlightEntry then
                    local highlight1 = actor1.parentEntryId == highlightEntry.entryId
                    local highlight2 = actor2.parentEntryId == highlightEntry.entryId
                    if highlight1 and not highlight2 then
                        return false
                    end
                    if highlight2 and not highlight1 then
                        return true
                    end
                end
                return actor1.drawOrder < actor2.drawOrder
            end
        )
        for i = #order, 1, -1 do
            local nextI = i == 1 and #order or i - 1 -- Wrap around end of order
            if self.selectedActorIds[order[i]] then
                pick = order[nextI]
            end
        end
        pick = pick or order[#order]
    end
    self:deselectAllActors()
    if pick then
        self:selectActor(pick)
    end
end

function Client:selectActorAtTouch(touch, hits)
    self:selectActorAtPoint(touch.x, touch.y, hits)
    touch.used = true
    self:applySelections()
end

function Client:touchToSelect()
    -- Touch-to-select. We skip if `touch.used` since the touch is already being used for some gesture.
    if self.numTouches == 1 and self.maxNumTouches == 1 then
        local touchId, touch = next(self.touches)

        -- Press and move? Check at point and select if nothing already selected there.
        if (not touch.used and touch.movedNear and love.timer.getTime() - touch.pressTime < 0.2) then
            local someSelectedHit = false
            local hits = self.behaviorsByName.Body:getActorsAtPoint(touch.initialX, touch.initialY)
            for actorId in pairs(hits) do
                if self.selectedActorIds[actorId] then
                    someSelectedHit = true
                    break
                end
            end
            if not someSelectedHit then
                self:selectActorAtPoint(touch.initialX, touch.initialY, hits)
                touch.used = true
                self:applySelections()
            end
        end

        -- Quick press and release without moving? Select!
        if (not touch.used and touch.released and not touch.movedNear and love.timer.getTime() - touch.pressTime < 0.2) then
            self:selectActorAtTouch(touch)
        end
    end
end
