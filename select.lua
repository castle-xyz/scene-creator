-- Start / stop

function Client:startSelect()
    self.selectedActorIds = {} -- `actorId` -> `true` for all selected actors

    self.activeToolBehaviorId = nil -- `behaviorId` of active tool
    self.lastActiveToolBehaviorId = nil -- the last non-`nil` value of `self.activeToolBehaviorId`
    self.applicableTools = {} -- `behaviorId` -> behavior, for tools applicable to selection
end


-- Methods

function Client:refreshTools()
    -- Clear removed actors
    for actorId in pairs(self.selectedActorIds) do
        if not self.actors[actorId] then
            self:deselectActor(actorId)
        end
    end

    -- Clear active tool if removed
    if not self.tools[self.activeToolBehaviorId] then
        self.activeToolBehaviorId = nil
    end

    -- Refresh applicable tool set
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
        if applicable then
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

    if self.activeToolBehaviorId then
        -- Deactivate active tool if it doesn't apply any more
        if not self.applicableTools[self.activeToolBehaviorId] then
            self:setActiveTool(nil)
        end
    else -- No tool currently active, but see if the last active tool can be re-activated
        if self.applicableTools[self.lastActiveToolBehaviorId] then
            self:setActiveTool(self.lastActiveToolBehaviorId)
        end
    end

    -- Add or remove components for active tool based on selections
    if self.activeToolBehaviorId then
        -- Remove components whose actors aren't selected any more
        local activeTool = self.tools[self.activeToolBehaviorId]
        for actorId, component in pairs(activeTool.components) do
            if self.clientId == component.clientId and not self.selectedActorIds[actorId] then
                self:send('removeComponent', self.clientId, actorId, activeTool.behaviorId)
            end
        end

        -- Add components for new selections
        for actorId in pairs(self.selectedActorIds) do
            if not activeTool:has(actorId) then
                self:send('addComponent', self.clientId, actorId, self.activeToolBehaviorId)
            end
        end
    end
end

function Client:selectActor(actorId)
    self.selectedActorIds[actorId] = true
end

function Client:deselectActor(actorId)
    self.selectedActorIds[actorId] = nil
end

function Client:deselectAllActors()
    for actorId in pairs(self.selectedActorIds) do
        self:deselectActor(actorId)
    end
end

function Client:setActiveTool(toolBehaviorId)
    if self.activeToolBehaviorId == toolBehaviorId then
        return -- Already active, skip
    end

    if self.activeToolBehaviorId then
        -- Clear our components from old tool -- we could use `self.selectedActorIds` but
        -- we actually go through the tool's components to make sure
        local activeTool = self.tools[self.activeToolBehaviorId]
        for actorId, component in pairs(activeTool.components) do
            if self.clientId == component.clientId then
                self:send('removeComponent', self.clientId, actorId, activeTool.behaviorId)
            end
        end
    end

    self.activeToolBehaviorId = toolBehaviorId
    if self.activeToolBehaviorId then
        self.lastActiveToolBehaviorId = self.activeToolBehaviorId
    end

    -- Activate new tool and add components to it if it applies
    if self.activeToolBehaviorId and self.applicableTools[self.activeToolBehaviorId] then
        local activeTool = self.tools[self.activeToolBehaviorId]
        for actorId in pairs(self.selectedActorIds) do
            if not activeTool:has(actorId) then
                self:send('addComponent', self.clientId, actorId, self.activeToolBehaviorId)
            end
        end
    end
end

function Client:selectActorAtPoint(x, y, hits)
    local hits = hits or self.behaviorsByName.Body:getActorsAtPoint(x, y)
    local pick
    if next(hits) then -- Pick the next unselected hit in some sorted order
        local order = {}
        for actorId in pairs(hits) do
            table.insert(order, actorId)
        end
        table.sort(order)
        for i = #order, 1, -1 do
            local nextI = i == 1 and #order or i - 1
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


-- Update

function Client:preUpdateSelect()
    -- Touch-to-select (do this before refreshing tools since it affects selections)
    if self.numTouches == 1 and self.maxNumTouches == 1 then
        local touchId, touch = next(self.touches)

        -- Press? Check at point and select if nothing already selected there.
        if touch.pressed then
            local someSelectedHit = false
            local hits = self.behaviorsByName.Body:getActorsAtPoint(touch.x, touch.y)
            for actorId in pairs(hits) do
                if self.selectedActorIds[actorId] then
                    someSelectedHit = true
                    break
                end
            end
            if not someSelectedHit then
                self:selectActorAtPoint(touch.x, touch.y, hits)
                touch.usedForSelection = true -- Mark as having been used for a selection
            end
        end

        -- Quick press and release without moving? And touch wasn't already used for a selection? Select!
        if (not touch.usedForSelection and touch.released and
                touch.x - touch.initialX == 0 and touch.y - touch.initialY == 0 and
                love.timer.getTime() - touch.pressTime < 0.2) then
            self:selectActorAtPoint(touch.x, touch.y)
        end
    end

    self:refreshTools()
end
