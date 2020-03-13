-- Start / stop

function Client:startUi()
    self.updateCounts = setmetatable({}, { __mode = 'k' }) -- `actor` -> count to force UI updates

    self.openComponentBehaviorId = nil -- `behaviorId` of open component section

    self.saveBlueprintDatas = setmetatable({}, { __mode = 'k' }) -- `actor` -> data for "save blueprint" popover

    self.blueprintsSnap = { count = 1, point = 3 }
    self.inspectorSnap = { count = 1, point = 2 }
end


-- Methods

function Client:moveActorForward(actorId, command)
    local actor = self.actors[actorId]
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
end

function Client:moveActorBackward(actorId, command)
    local actor = self.actors[actorId]
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
end

function Client:snapBlueprintsPane(point)
    self.blueprintsSnap.point = point
    self.blueprintsSnap.count = self.blueprintsSnap.count + 1
end

function Client:snapInspectorPane(point)
    self.inspectorSnap.point = point
    self.inspectorSnap.count = self.inspectorSnap.count + 1
end


-- UI

function Client:uiGlobalActions()
    ui.button('back', {
        icon = 'arrow-left',
        iconFamily = 'FontAwesome5',
        onClick = function()
            jsEvents.send('GHOST_BACK', {})
        end,
    })

    ui.box('spacer', { flex = 1 }, function() end)

    ui.box('global-actions-performing-' .. tostring(self.performing), {
        flexDirection = 'row',
    }, function()
        ui.box('left', { flexDirection = 'row' }, function()
            if not self.performing then
                -- Paused mode

                -- Play
                ui.button('play', {
                    icon = 'play',
                    iconFamily = 'FontAwesome',
                    hideLabel = true,
                    onClick = function()
                        self:endEditing()
                    end,
                })

                -- Undo / redo
                local hasUndo, hasRedo = #self.undos > 0, #self.redos > 0
                if hasUndo then
                    ui.button('undo', {
                        icon = 'ios-undo',
                        iconFamily = 'Ionicons',
                        hideLabel = true,
                        onClick = function()
                            self:undo()
                        end,
                    })
                end
                if hasRedo then
                    ui.button('redo', {
                        icon = 'ios-redo',
                        iconFamily = 'Ionicons',
                        hideLabel = true,
                        onClick = function()
                            self:redo()
                        end,
                    })
                end
            else
                -- Play mode

                -- Rewind
                ui.button('rewind', {
                    icon = 'stop',
                    iconFamily = 'FontAwesome',
                    hideLabel = true,
                    onClick = function()
                        self:beginEditing()
                    end,
                })
            end
        end)
    end)

    ui.box('spacer', { flex = 1 }, function() end)
end

function Client:uiBlueprints()
    self:uiLibrary({
        id = 'add actor',
        filterType = 'actorBlueprint',
        bottomSpace = 300,
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

function Client:uiInspectorActions()
    if not next(self.selectedActorIds) then
        return
    end

    -- Tools
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

    ui.box('spacer', { flex = 1 }, function() end)

    -- Ordering
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
                    self:moveActorForward(next(self.selectedActorIds), true)
                end,
            })
            ui.button('move backward', {
                icon = 'arrow-bold-down',
                iconFamily = 'Entypo',
                onClick = function()
                    self:moveActorBackward(next(self.selectedActorIds), true)
                end,
            })
            ui.button('move to front', {
                icon = 'align-top',
                iconFamily = 'Entypo',
                onClick = function()
                    local actorId = next(self.selectedActorIds)
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
                end,
            })
            ui.button('move to back', {
                icon = 'align-bottom',
                iconFamily = 'Entypo',
                onClick = function()
                    local actorId = next(self.selectedActorIds)
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
                end,
            })
        end,
    })

    -- Duplicate
    ui.button('duplicate actor', {
        icon = 'copy',
        iconFamily = 'FontAwesome5',
        hideLabel = true,
        onClick = function()
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
        end,
    })

    -- Delete
    ui.button('delete', {
        icon = 'trash-alt',
        iconFamily = 'FontAwesome5',
        hideLabel = true,
        onClick = function()
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
                for _, save in ipairs(saves) do
                    self:deselectActor(save.actorId)
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
        end,
    })
end

function Client:uiInspector()
    local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]
    if activeTool and activeTool.handlers.uiPanel then
        local uiName = activeTool:getUiName()
        ui.scrollBox('inspector-tool-' .. uiName, {
            padding = 2,
            margin = 2,
            flex = 1,
        }, function()
            activeTool:callHandler('uiPanel')
            ui.box('bottom space', { height = 300 }, function() end)
        end)
        return
    end

    ui.scrollBox('inspector-properties', {
        padding = 2,
        marginTop = -18,
        flex = 1,
    }, function()
        local actorId = next(self.selectedActorIds)
        if actorId then
            local actor = self.actors[actorId]

            ui.box('properties-' .. actor.actorId .. '-' .. (self.updateCounts[actorId] or 1), function()
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

                -- Component header buttons
                ui.box('tabs', {
                    flexDirection = 'row',
                    flexWrap = 'wrap',
                }, function()
                    -- Each existing component
                    for i = 1, #order do
                        local component = order[i]
                        local behavior = self.behaviors[component.behaviorId]
                        local uiName = behavior:getUiName()
                        ui.box(uiName .. ' box', { 
                            flexDirection = 'row',
                        }, function()
                            ui.button(uiName, {
                                selected = self.openComponentBehaviorId == behavior.behaviorId,
                                onClick = function()
                                    self.openComponentBehaviorId = behavior.behaviorId
                                end
                            })

                            -- Last box? Add '+'.
                            if i == #order then
                                ui.button('add behavior', {
                                    icon = 'plus',
                                    hideLabel = true,
                                    iconFamily = 'FontAwesome5',
                                    popoverAllowed = true,
                                    popoverStyle = { width = 300, height = 300 },
                                    popover = function(closePopover)
                                        self:uiLibrary({
                                            id = 'add behavior',
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
                                                        closePopover()

                                                        local behaviorId = entry.behaviorId
                                                        local behavior = self.behaviors[behaviorId]
                                                        self:command('add ' .. behavior:getUiName(), {
                                                            params = { 'behaviorId' },
                                                        }, function()
                                                            local behavior = self.behaviors[behaviorId]
                                                            if behavior.components[actorId] then
                                                                return 'behavior was added'
                                                            end
                                                            self:send('addComponent', self.clientId, actorId, behaviorId, {})
                                                            self.openComponentBehaviorId = behaviorId
                                                            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                                                        end, function()
                                                            local behavior = self.behaviors[behaviorId]
                                                            if not behavior.components[actorId] then
                                                                return 'behavior was removed'
                                                            end
                                                            self:send('removeComponent', self.clientId, actorId, behaviorId)
                                                            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                                                        end)
                                                    end,
                                                })
                                            end,
                                        })
                                    end,
                                })
                            end
                        end)
                    end
                end)

                -- Open component
                local component = actor.components[self.openComponentBehaviorId]
                if component then
                    local behavior = self.behaviors[component.behaviorId]
                    local uiName = behavior:getUiName()

                    -- Spacer
                    ui.box('spacer', { height = 24 }, function() end)

                    -- Header
                    ui.box('header', {
                        flexDirection = 'row',
                    }, function()
                        ui.box('title', {
                            flex = 1,
                        }, function()
                            ui.markdown('## ' .. uiName)
                        end)
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
                                            local behaviorId = component.behaviorId
                                            local componentBp = {}
                                            behavior:callHandler('blueprintComponent', component, componentBp)
                                            self:command('remove ' .. uiName, {
                                                params = { 'behaviorId', 'componentBp' },
                                            }, function()
                                                local behavior = self.behaviors[behaviorId]
                                                if not behavior.components[actorId] then
                                                    return 'behavior was removed'
                                                end
                                                self:send('removeComponent', self.clientId, actorId, behaviorId)
                                                self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                                            end, function()
                                                local behavior = self.behaviors[behaviorId]
                                                if behavior.components[actorId] then
                                                    return 'behavior was added'
                                                end
                                                self:send('addComponent', self.clientId, actorId, behaviorId, componentBp)
                                                self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                                            end)
                                        end,
                                        cancelLabel = 'No',
                                    })
                                end,
                            })
                        end
                    end)

                    -- Component's UI
                    behavior:callHandler('uiComponent', component, {})
                end

                -- Spacer
                ui.box('spacer-2', { height = 24 }, function() end)

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

        ui.box('bottom space', { height = 300 }, function() end)
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

    -- Global actions
    ui.pane('sceneCreatorGlobalActions', function()
        self:uiGlobalActions()
    end)

    -- Blueprints
    ui.pane('sceneCreatorBlueprints', {
        snapCount = self.blueprintsSnap.count,
        snapPoint = self.blueprintsSnap.point,
    }, function()
        self:uiBlueprints()
    end)

    -- Inspector
    ui.pane('sceneCreatorInspectorActions', function()
        self:uiInspectorActions()
    end)
    ui.pane('sceneCreatorInspector', {
        snapCount = self.inspectorSnap.count,
        snapPoint = self.inspectorSnap.point,
    }, function()
        self:uiInspector()
    end)

    -- Panel
    do return end
    ui.pane('default', {
        visible = not self.performing,
        customLayout = true,
    }, function()
        ui.box('default-panel', {
            flex = 1,
        }, function()
            ui.tabs('tabs', {
                containerStyle = { flex = 1, margin = 0 },
                contentStyle = { flex = 1 },
            }, function()
                -- Blueprints tab
                ui.tab('blueprints', function()
                end)

                -- Properties tab
                ui.tab('properties', function()
                    self:uiProperties()
                end)
            end)
        end)
    end)
end
