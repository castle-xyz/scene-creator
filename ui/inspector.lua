function Client:uiInspector()
    -- Does the active tool have a panel?
    local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]

    if activeTool and activeTool.handlers.uiPanel then
        local uiName = activeTool:getUiName()
        ui.scrollBox('inspector-tool-' .. uiName, {
            padding = 2,
            margin = 2,
            flex = 1,
        }, function()
            activeTool:callHandler('uiPanel')
        end)
        return
    end

    -- Make sure `self.openComponentBehaviorId` is valid
    if not self.behaviors[self.openComponentBehaviorId] then
        self.openComponentBehaviorId = nil
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
                                    iconFamily = 'FontAwesome5',
                                    hideLabel = true,
                                    popoverAllowed = true,
                                    popoverStyle = { width = 300, height = 300 },
                                    popover = function(closePopover)
                                        self:uiLibrary({
                                            id = 'add behavior',
                                            filterType = 'behavior',
                                            filterBehavior = function(behavior)
                                               -- if actor has body and this is text, return false
                                               if (actor.components[self.behaviorsByName.Body.behaviorId] and behavior == self.behaviorsByName.Text) then
                                                  return false
                                               end

                                               -- if actor has text and this is not rules, return false
                                               if (actor.components[self.behaviorsByName.Text.behaviorId] and behavior ~= self.behaviorsByName.Rules) then
                                                  return false
                                               end

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
                                                        local behaviorId = entry.behaviorId
                                                        local behavior = self.behaviors[behaviorId]

                                                        -- Get full order of adding behaviors in case of non-present dependencies
                                                        local order = {}
                                                        local visited = {}
                                                        local function visit(behavior)
                                                            if visited[behavior.behaviorId] then
                                                                return
                                                            end
                                                            visited[behavior.behaviorId] = true
                                                            if not actor.components[behavior.behaviorId] then
                                                                for _, dependency in pairs(behavior.dependencies) do
                                                                    visit(dependency)
                                                                end
                                                                table.insert(order, behavior.behaviorId)
                                                            end
                                                        end
                                                        visit(behavior)

                                                        -- Prompt if adding more than one behavior, else add immediately
                                                        local function doIt()
                                                            closePopover()

                                                            self:command('add ' .. behavior:getUiName(), {
                                                                params = { 'behaviorId', 'order' },
                                                            }, function()
                                                                local behavior = self.behaviors[behaviorId]
                                                                if behavior.components[actorId] then
                                                                    return 'behavior was added'
                                                                end
                                                                for i = 1, #order do
                                                                    self:send('addComponent', self.clientId, actorId, order[i], {}, {
                                                                        interactive = true,
                                                                    })
                                                                end
                                                                self.openComponentBehaviorId = behaviorId
                                                                self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                                                            end, function()
                                                                local behavior = self.behaviors[behaviorId]
                                                                if not behavior.components[actorId] then
                                                                    return 'behavior was removed'
                                                                end
                                                                for i = #order, 1, -1 do
                                                                    self:send('removeComponent', self.clientId, actorId, order[i])
                                                                end
                                                                self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                                                            end)
                                                        end
                                                        if #order > 1 then
                                                            local list = ''
                                                            for i = 1, #order - 1 do
                                                                if i > 1 then
                                                                    if i < #order - 1 then
                                                                        list = list .. ', '
                                                                    else
                                                                        list = list .. ' and '
                                                                    end
                                                                end
                                                                list = list .. "'" .. self.behaviors[order[i]]:getUiName() .. "'"
                                                            end
                                                            local message = ("'" .. behavior:getUiName() .. "' needs " .. list ..
                                                                '. Add ' .. (#order == 2 and 'it' or 'them') .. ' also?')
                                                            castle.system.alert({
                                                                title = 'Add needed behaviors?',
                                                                message = message,
                                                                okLabel = 'Yes',
                                                                cancelLabel = 'No',
                                                                onOk = function()
                                                                    doIt()
                                                                end,
                                                                onCancel = function()
                                                                    closePopover()
                                                                end
                                                            })
                                                        else
                                                            doIt()
                                                        end
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
                    ui.box('spacer', { height = 8 }, function() end)

                    -- Header
                    if behavior.name ~= 'Text' then
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
                                        if next(component.dependents) ~= nil then -- Has dependents?
                                            local names = {}
                                            for dependentId in pairs(component.dependents) do
                                                local dependent = self.behaviors[dependentId]
                                                table.insert(names, dependent:getUiName())
                                            end
                                            local list = ''
                                            for i = 1, #names do
                                                if i > 1 then
                                                    if i < #names then
                                                        list = list .. ', '
                                                    else
                                                        list = list .. ' and '
                                                    end
                                                end
                                                list = list .. "'" .. names[i] .. "'"
                                            end
                                            local message = (list .. ' need' .. (#names > 1 and '' or 's') .. " '" ..
                                                uiName .. "'.")
                                            castle.system.alert("Cannot remove '" .. uiName .. "'", message)
                                        else
                                            castle.system.alert({
                                                title = 'Remove behavior?',
                                                message = "Remove '" .. uiName .. "' from this actor?",
                                                okLabel = 'Yes',
                                                cancelLabel = 'No',
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
                                                end
                                            })
                                        end
                                    end,
                                })
                            end
                        end)
                    end -- header

                    -- Component's UI
                    behavior:callHandler('uiComponent', component, {})
                end

                -- Spacer
                ui.box('spacer-2', { height = 8 }, function() end)

                -- Save blueprint
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

                            saveBlueprintData.title = ui.textInput('title', saveBlueprintData.title)

                            saveBlueprintData.description = ui.textArea('description', saveBlueprintData.description)

                            local existingEntry = self.library[saveBlueprintData.entryId]
                            if existingEntry then
                                local numOtherActors = 0
                                for otherActorId, otherActor in pairs(self.actors) do
                                    if otherActorId ~= actorId and otherActor.parentEntryId == existingEntry.entryId then
                                        numOtherActors = numOtherActors + 1
                                    end
                                end
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

                                        closePopover()

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

                                    closePopover()

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
                                end,
                            })
                        end)
                    end
                })
            end)
        end
    end)
end
