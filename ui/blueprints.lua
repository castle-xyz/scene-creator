function Client:uiBlueprints()
    self:uiLibrary({
        id = 'add actor',
        filterType = 'actorBlueprint',
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
