-- Start / stop

function Client:startUi()
    self.updateCounts = setmetatable({}, { __mode = 'k' }) -- `actor` -> count to force UI updates

    self.componentSectionOpens = setmetatable({}, { __mode = 'k' }) -- `actor` -> `behaviorId` of open component section

    self.saveBlueprintDatas = setmetatable({}, { __mode = 'k' }) -- `actor` -> data for "save blueprint" popover
end


-- UI

function Client:uiToolbar()
    ui.button('toggle performing', {
        icon = 'play',
        iconFamily = 'FontAwesome',
        hideLabel = true,
        selected = self.performing,
        onClick = function()
            self:send('setPerforming', not self.performing)
        end,
    })

    ui.box('spacer', { flex = 1 }, function() end)

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
            ui.button(tool.name, {
                icon = tool.tool.icon,
                iconFamily = tool.tool.iconFamily,
                hideLabel = true,
                selected = self.activeToolBehaviorId == tool.behaviorId,
                onClick = function()
                    self:setActiveTool(tool.behaviorId)
                end,
            })
        end
    end

    ui.box('spacer', { flex = 1 }, function() end)

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
                    local bp = self:blueprintActor(actorId)
                    if bp.Body then
                        bp.Body.x, bp.Body.y = bp.Body.x + 64, bp.Body.y + 64
                    end
                    local actor = self.actors[actorId]
                    duplicateActorIds[self:sendAddActor(bp, actor.parentEntryId)] = true
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
                        open = self.componentSectionOpens[actor] == component.behaviorId,
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
                        self.componentSectionOpens[actor] = component.behaviorId
                    elseif self.componentSectionOpens[actor] == component.behaviorId then
                        self.componentSectionOpens[actor] = 'none' -- Sentinel to mark none as open
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
                                        self.componentSectionOpens[actor] = entry.behaviorId
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
                                -- Stop performing
                                self:send('setPerforming', false)

                                -- Add the actor, initializing some values in the blueprint
                                local actorBp = util.deepCopyTable(entry.actorBlueprint)
                                if actorBp.Body then -- Has a `Body`? Position at center of window.
                                    local windowWidth, windowHeight = love.graphics.getDimensions()
                                    actorBp.Body.x, actorBp.Body.y = 0.5 * windowWidth, 0.5 * windowHeight
                                end
                                local actorId = self:sendAddActor(actorBp, entry.entryId)

                                -- Select the actor. If it has a `Body`, switch to the `Grab` tool.
                                if actorBp.Body then
                                    self:setActiveTool(nil)
                                end
                                self:deselectAllActors()
                                self:selectActor(actorId)
                                self:applySelections()
                                if actorBp.Body then
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
        end)
    end)
end
