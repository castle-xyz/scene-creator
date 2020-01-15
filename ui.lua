-- Start / stop

function Client:startUi()
    self.openBehaviorId = nil -- `behaviorId` of behavior whose components' properties section is open
end


-- Main UI events

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

                    for actorId in pairs(self.selectedActorIds) do
                        local bp = self:blueprintActor(actorId)
                        if bp.Body then
                            bp.Body.x, bp.Body.y = bp.Body.x + 64, bp.Body.y + 64
                        end
                        duplicateActorIds[self:sendAddActor(bp)] = true
                    end

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
                ui.scrollBox('scrollBox1', {
                    padding = 2,
                    margin = 2,
                    flex = 1,
                }, function()
                    local actorId = next(self.selectedActorIds)
                    if actorId then
                        local actor = self.actors[actorId]

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
                        for _, component in ipairs(order) do
                            local behavior = self.behaviors[component.behaviorId]
                            local newOpen = ui.section(behavior.name:lower(), {
                                id = actorId .. '-' .. component.behaviorId,
                                open = self.openBehaviorId == component.behaviorId,
                            }, function()
                                behavior:callHandler('uiComponent', component, {})
                            end)
                            if newOpen then
                                self.openBehaviorId = component.behaviorId
                            elseif self.openBehaviorId == component.behaviorId then
                                self.openBehaviorId = nil
                            end
                        end
                    end
                end)
            end)
        end)
    end)
end
