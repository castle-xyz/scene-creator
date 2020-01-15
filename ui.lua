-- Start / stop

function Client:startUi()
    self.componentSectionOpens = setmetatable({}, { __mode = 'k' }) -- `actor` -> `behaviorId` of open component section
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
                    duplicateActorIds[self:sendAddActor(bp)] = true
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

                local title = (behavior.displayName or behavior.name):lower()
                local newOpen = ui.section(title, {
                    id = actorId .. '-' .. component.behaviorId,
                    open = self.componentSectionOpens[actor] == component.behaviorId,
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
        end
    end)
end

function Client:uiupdate()
    if not castle.system.isMobile() then
        ui.markdown('# Hello!\nThis prototype is meant for mobile. :O')
        return
    end

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
            -- Library tab
            ui.tab('library', function()
                self:uiLibrary()
            end)

            -- Properties tab
            ui.tab('properties', function()
                self:uiProperties()
            end)
        end)
    end)
end
