-- Start / stop

function Client:startUi()
    self.updateCounts = setmetatable({}, { __mode = 'k' }) -- `actor` -> count to force UI updates

    self.openComponentBehaviorId = nil -- `behaviorId` of open component section

    self.saveBlueprintDatas = setmetatable({}, { __mode = 'k' }) -- `actor` -> data for "save blueprint" popover
end


-- UI

function Client:uiToolbar()
    ui.box('left', { flexDirection = 'row' }, function()
        if not self.performing then
            -- Paused mode

            -- Play
            ui.button('play', {
                icon = 'play',
                iconFamily = 'FontAwesome',
                hideLabel = true,
                onClick = function()
                    self:send('addSnapshot', util.uuid(), self:createSnapshot(), { isRewind = true })
                    self:send('setPerforming', true)
                end,
            })
        else
            -- Play mode

            -- Rewind
            ui.button('rewind', {
                icon = 'stop',
                iconFamily = 'FontAwesome',
                hideLabel = true,
                onClick = function()
                    if self.rewindSnapshotId then
                        self:send('restoreSnapshot', self.rewindSnapshotId)
                        self:send('removeSnapshot', self.rewindSnapshotId)
                    end
                end,
            })
        end
    end)

    ui.box('spacer', { flex = 1 }, function() end)

    ui.box('middle', { flexDirection = 'row' }, function()
        -- Tools
        if next(self.selectedActorIds) then
            local order = {}
            for _, tool in pairs(self.applicableTools) do
                table.insert(order, tool)
            end
            table.sort(order, function(tool1, tool2)
                return tool1.behaviorId < tool2.behaviorId
            end)
            for _, tool in ipairs(order) do
                local selected = self.activeToolBehaviorId == tool.behaviorId

                local popoverAllowed, popoverStyle, popover

                if tool.handlers.uiSettings then
                    popoverAllowed = selected
                    popoverStyle = { width = 300 }
                    popover = function(closePopover)
                        tool:callHandler('uiSettings', closePopover)
                    end
                end

                ui.button(tool.name, {
                    icon = tool.tool.icon,
                    iconFamily = tool.tool.iconFamily,
                    hideLabel = true,
                    selected = selected,
                    onClick = function()
                        self:setActiveTool(tool.behaviorId)
                    end,
                    popoverAllowed = popoverAllowed,
                    popoverStyle = popoverStyle,
                    popover = popover,
                })
            end
        end
    end)

    if self.performing then
        return -- Everything to the right of this is for pause mode only
    end

    ui.box('spacer', { flex = 1 }, function() end)

    ui.box('right', { flexDirection = 'row' }, function()
        -- Move up / down
        if next(self.selectedActorIds) then
            -- TODO(nikki): Support multiple selections

            ui.button('ordering', {
                icon = 'layers',
                iconFamily = 'Entypo',
                hideLabel = true,
                popoverAllowed = true,
                popoverStyle = { width = 200 },
                popover = function()
                    ui.button('move forward', {
                        icon = 'arrow-bold-up',
                        iconFamily = 'Entypo',
                        onClick = function()
                            local actor = self.actors[next(self.selectedActorIds)]
                            if actor.drawOrder < table.maxn(self.actorsByDrawOrder) then
                                local bodyId, body = self.behaviorsByName.Body:getBody(actor.actorId)
                                local fixture = body:getFixtures()[1]
                                if fixture then
                                    local newDrawOrder
                                    local hits = self.behaviorsByName.Body:getActorsAtBoundingBox(
                                        fixture:getBoundingBox())
                                    for hit in pairs(hits) do -- Find greatest draw order below us
                                        local otherActor = self.actors[hit]
                                        if (otherActor.drawOrder > actor.drawOrder and
                                                (not newDrawOrder or otherActor.drawOrder < newDrawOrder)) then
                                            newDrawOrder = otherActor.drawOrder
                                        end
                                    end
                                    if newDrawOrder then
                                        self:send('setActorDrawOrder', actor.actorId, newDrawOrder)
                                    end
                                end
                            end
                        end,
                    })
                    ui.button('move backward', {
                        icon = 'arrow-bold-down',
                        iconFamily = 'Entypo',
                        onClick = function()
                            local actor = self.actors[next(self.selectedActorIds)]
                            if actor.drawOrder > 1 then
                                local bodyId, body = self.behaviorsByName.Body:getBody(actor.actorId)
                                local fixture = body:getFixtures()[1]
                                if fixture then
                                    local newDrawOrder
                                    local hits = self.behaviorsByName.Body:getActorsAtBoundingBox(
                                        fixture:getBoundingBox())
                                    for hit in pairs(hits) do -- Find greatest draw order below us
                                        local otherActor = self.actors[hit]
                                        if (otherActor.drawOrder < actor.drawOrder and
                                                (not newDrawOrder or otherActor.drawOrder > newDrawOrder)) then
                                            newDrawOrder = otherActor.drawOrder
                                        end
                                    end
                                    if newDrawOrder then
                                        self:send('setActorDrawOrder', actor.actorId, newDrawOrder)
                                    end
                                end
                            end
                        end,
                    })
                end,
            })
        end


        -- Duplicate
        if next(self.selectedActorIds) then
            ui.button('duplicate actor', {
                icon = 'copy',
                iconFamily = 'FontAwesome5',
                hideLabel = true,
                onClick = function()
                    local duplicateActorIds = {}

                    -- Use blueprints to duplicate. Nudge position a little bit.
                    for actorId in pairs(self.selectedActorIds) do
                        local actor = self.actors[actorId]

                        local bp = self:blueprintActor(actorId)
                        if bp.components.Body then
                            bp.components.Body.x = bp.components.Body.x + UNIT
                            bp.components.Body.y = bp.components.Body.y + UNIT
                        end

                        local newActorId = self:sendAddActor(bp, {
                            parentEntryId = actor.parentEntryId
                        })
                        duplicateActorIds[newActorId] = true
                    end

                    -- Select new actors
                    self:deselectAllActors()
                    for actorId in pairs(duplicateActorIds) do
                        self:selectActor(actorId)
                    end
                end,
            })
        end

        -- Delete
        if next(self.selectedActorIds) then
            ui.button('remove actor', {
                icon = 'trash-alt',
                iconFamily = 'FontAwesome5',
                hideLabel = true,
                onClick = function()
                    for actorId in pairs(self.selectedActorIds) do
                        self:deselectActor(actorId)
                        self:send('removeActor', self.clientId, actorId)
                    end
                end,
            })
        end
    end)
end

function Client:uiProperties()
    ui.scrollBox('scrollBox1', {
        padding = 2,
        margin = 2,
        flex = 1,
    }, function()
        local actorId = next(self.selectedActorIds)
        if actorId then
            local actor = self.actors[actorId]

            local updateCount = self.updateCounts[actor] or 1

            ui.box('properties-' .. actor.actorId .. '-' .. updateCount, function()
                -- Sort by `behaviorId`
                local order = {}
                for behaviorId, component in pairs(actor.components) do
                    local behavior = self.behaviors[behaviorId]
                    if not behavior.tool and behavior.handlers.uiComponent then
                        table.insert(order, component)
                    end
                end
                table.sort(order, function (component1, component2)
                    return component1.behaviorId < component2.behaviorId
                end)

                -- Sections for each component
                for _, component in ipairs(order) do
                    local behavior = self.behaviors[component.behaviorId]

                    local uiName = behavior:getUiName()

                    local newOpen = ui.section(uiName, {
                        id = actorId .. '-' .. component.behaviorId,
                        open = self.openComponentBehaviorId == component.behaviorId,
                        header = function()
                            ui.button('description', {
                                margin = 0,
                                marginLeft = 6,
                                icon = 'question',
                                iconFamily = 'FontAwesome5',
                                hideLabel = true,
                                popoverAllowed = true,
                                popoverStyle = { width = 300 },
                                popover = function()
                                    ui.markdown('## ' .. uiName .. '\n' .. (behavior.description or ''))
                                end,
                            })
                            if behavior.name ~= 'Body' then
                                ui.button('remove', {
                                    margin = 0,
                                    marginLeft = 6,
                                    icon = 'close',
                                    iconFamily = 'FontAwesome',
                                    hideLabel = true,
                                    onClick = function()
                                        castle.system.alert({
                                            title = 'Remove behavior?',
                                            message = "Remove '" .. uiName .. "' from this actor?",
                                            okLabel = 'Yes',
                                            onOk = function()
                                                self:send('removeComponent', self.clientId, actorId, component.behaviorId)
                                                self.updateCounts[actorId] = updateCount + 1
                                            end,
                                            cancelLabel = 'No',
                                        })
                                    end,
                                })
                            end
                        end,
                    }, function()
                        behavior:callHandler('uiComponent', component, {})
                    end)

                    -- Track open section
                    if newOpen then
                        self.openComponentBehaviorId = component.behaviorId
                    elseif self.openComponentBehaviorId == component.behaviorId then
                        self.openComponentBehaviorId = nil
                    end
                end

                -- Add component
                ui.box('spacer', { height = 16 }, function() end)
                ui.button('add behavior', {
                    flex = 1,
                    icon = 'plus',
                    iconFamily = 'FontAwesome5',
                    popoverAllowed = true,
                    popoverStyle = { width = 300, height = 300 },
                    popover = function(closePopover)
                        self:uiLibrary({
                            filterType = 'behavior',
                            filterBehavior = function(behavior)
                                -- Skip behaviors we already have, skip tools
                                return not (actor.components[behavior.behaviorId] or behavior.tool)
                            end,
                            emptyText = 'No other behaviors to add!',
                            buttons = function(entry)
                                ui.button('add to actor', {
                                    flex = 1,
                                    icon = 'plus',
                                    iconFamily = 'FontAwesome5',
                                    onClick = function()
                                        self.updateCounts[actorId] = updateCount + 1

                                        closePopover()

                                        -- Add the component and open its section
                                        self:send('addComponent', self.clientId, actorId, entry.behaviorId, {})
                                        self.openComponentBehaviorId = entry.behaviorId
                                    end,
                                })
                            end,
                        })
                    end
                })

                -- Save blueprint
                ui.button('save blueprint', {
                    flex = 1,
                    icon = 'save',
                    iconFamily = 'FontAwesome5',
                    popoverAllowed = true,
                    popoverStyle = { width = 300, height = 300 },
                    popover = function(closePopover)
                        ui.scrollBox('save blueprint', { flex = 1 }, function()
                            local saveBlueprintData = self.saveBlueprintDatas[actor]
                            if not saveBlueprintData then
                                local oldEntry = self.library[actor.parentEntryId]
                                saveBlueprintData = {
                                    title = oldEntry and oldEntry.title or '',
                                    description = oldEntry and oldEntry.description or '',
                                }
                                self.saveBlueprintDatas[actor] = saveBlueprintData
                            end

                            saveBlueprintData.title = ui.textInput('title', saveBlueprintData.title)

                            saveBlueprintData.description = ui.textArea('description', saveBlueprintData.description)

                            ui.button('save', {
                                icon = 'save',
                                iconFamily = 'FontAwesome5',
                                onClick = function()
                                    if saveBlueprintData.title == '' then
                                        castle.system.alert('Title required', 'Please enter a title for the new blueprint.')
                                        return
                                    end

                                    if saveBlueprintData.description == '' then
                                        castle.system.alert('Title description', 'Please enter a description for the new blueprint.')
                                        return
                                    end

                                    closePopover()

                                    local newEntryId = util.uuid()
                                    self:send('addLibraryEntry', newEntryId, {
                                        entryType = 'actorBlueprint',
                                        title = saveBlueprintData.title,
                                        description = saveBlueprintData.description,
                                        actorBlueprint = self:blueprintActor(actor.actorId),
                                    })
                                    self:send('setActorParentEntryId', actor.actorId, newEntryId)
                                end,
                            })
                        end)
                    end
                })
            end)
        end
    end)
end

function Client:uiupdate()
    if not castle.system.isMobile() then
        ui.markdown('# Hello!\nThis prototype is meant for mobile. :O')
        return
    end

    if not self.connected then
        ui.markdown('connecting...')
        return
    end

    -- Refresh tools first to make sure selections and applicable tool set are valid
    self:applySelections() 

    -- Toolbar
    ui.pane('toolbar', {
        customLayout = true,
        flexDirection = 'row',
        padding = 2,
    }, function()
        self:uiToolbar()
    end)

    -- Panel
    ui.pane('default', { customLayout = true }, function()
        ui.tabs('tabs', {
            containerStyle = { flex = 1, margin = 0 },
            contentStyle = { flex = 1 },
        }, function()
            if self.performing then
                -- Play tab
                ui.tab('play', function()
                end)
            else
                -- Blueprints tab
                ui.tab('blueprints', function()
                    self:uiLibrary({
                        filterType = 'actorBlueprint',
                        buttons = function(entry)
                            ui.button('add to scene', {
                                flex = 1,
                                icon = 'plus',
                                iconFamily = 'FontAwesome5',
                                onClick = function()
                                    -- Add the actor, initializing some values in the blueprint
                                    local actorBp = util.deepCopyTable(entry.actorBlueprint)
                                    if actorBp.components.Body then -- Has a `Body`? Position at center of window.
                                        local windowWidth, windowHeight = love.graphics.getDimensions()
                                        actorBp.components.Body.x = 0
                                        actorBp.components.Body.y = 0
                                    end
                                    local actorId = self:sendAddActor(actorBp, {
                                        parentEntryId = entry.entryId,
                                    })

                                    -- Select the actor. If it has a `Body`, switch to the `Grab` tool.
                                    if actorBp.components.Body then
                                        self:setActiveTool(nil)
                                    end
                                    self:deselectAllActors()
                                    self:selectActor(actorId)
                                    self:applySelections()
                                    if actorBp.components.Body then
                                        self:setActiveTool(self.behaviorsByName.Grab.behaviorId)
                                    end
                                end
                            })
                        end,
                    })
                end)

                -- Properties tab
                ui.tab('properties', function()
                    self:uiProperties()
                end)
            end
        end)
    end)
end
