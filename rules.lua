BaseRulesBehavior = {
    propertyNames = {
        'rules',
    },
    handlers = {},
}

initBehaviorSpec(BaseRulesBehavior)


local EMPTY_RULE = {
    triggerBehaviorId = nil,
    triggerName = 'none',
    responseBehaviorId = nil,
    responseName = 'none',
}


-- Behavior management

function BaseRulesBehavior.handlers:addBehavior(opts)
    self:sendSetProperties(nil, 'rules', { util.deepCopyTable(EMPTY_RULE) })
end


-- Setters

function BaseRulesBehavior.setters:rules(component, newRules)
    if component == nil then
        self.globals.rules = newRules

        self._rulesByTriggerName = {}
        for _, rule in ipairs(self.globals.rules) do
            if rule.triggerName ~= 'none' then
                if not self._rulesByTriggerName[rule.triggerName] then
                    self._rulesByTriggerName[rule.triggerName] = {}
                end
                table.insert(self._rulesByTriggerName[rule.triggerName], rule)
            end
        end
    end
end


-- Trigger / response

function BaseRulesBehavior.handlers:trigger(triggerName, opts)
    local actorId = opts.actorId
    if actorId and not self.components[actorId] then
        return -- TODO(nikki): Make this more efficient than having to go through every trigger behavior
    end

    local params = opts.params or {}

    local rulesToRun = self._rulesByTriggerName[triggerName]
    if rulesToRun then
        for _, ruleToRun in ipairs(rulesToRun) do
            local responseBehavior = self.game.behaviors[ruleToRun.responseBehaviorId]
            if responseBehavior then
                local responseComponent = responseBehavior.components[actorId]
                if responseComponent then
                    local response = responseBehavior.responses[ruleToRun.responseName]
                    if response then
                        response.call(responseBehavior, responseComponent, params)
                    end
                end
            end
        end
    end
end


-- UI

function BaseRulesBehavior:uiRulePart(part, rule, actorId)
    local actor = self.game.actors[actorId]

    local label
    if rule[part .. 'BehaviorId'] then
        local behavior = self.game.behaviors[rule[part .. 'BehaviorId']]
        label = behavior:getUiName() .. ': ' .. rule[part .. 'Name']
    else
        label = 'no ' .. part
    end
    ui.button(label, {
        flex = 1,
        popoverAllowed = true,
        popoverStyle = { width = 300, height = 300 },
        popover = function(closePopover)
            ui.scrollBox('scrollBox-' .. part, {
                padding = 2,
                margin = 2,
                flex = 1,
            }, function()
                for behaviorId in pairs(actor.components) do
                    local behavior = self.game.behaviors[behaviorId]
                    local behaviorParts = behavior[part .. 's']
                    if next(behaviorParts) then
                        ui.section(behavior:getUiName(), { defaultOpen = true }, function()
                            for entryName, entry in pairs(behaviorParts) do
                                ui.box(entryName, {
                                    borderWidth = 1,
                                    borderColor = '#292929',
                                    borderRadius = 4,
                                    padding = 4,
                                    margin = 4,
                                    marginBottom = 8,
                                }, function()
                                    ui.markdown('## ' .. entryName .. '\n' .. (entry.description or ''))

                                    ui.box('buttons', { flexDirection = 'row' }, function()
                                        ui.button('use', {
                                            flex = 1,
                                            icon = 'plus',
                                            iconFamily = 'FontAwesome5',
                                            onClick = function()
                                                closePopover()
                                                rule[part .. 'BehaviorId'] = behaviorId
                                                rule[part .. 'Name'] = entryName
                                                self:sendSetProperties(nil, 'rules', self.globals.rules)
                                            end,
                                        })
                                    end)
                                end)
                            end
                        end)
                    end
                end
            end)
        end
    })
end

function BaseRulesBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    if next(component.properties) then
        ui.section('properties', { defaultOpen = true }, function()
        end)
    end
    ui.section('rules', { defaultOpen = true }, function()
        for ruleIndex, rule in ipairs(self.globals.rules) do
            ui.box('rule-' .. ruleIndex, {
                borderWidth = 1,
                borderColor = '#292929',
                borderRadius = 4,
                padding = 4,
                margin = 4,
                marginBottom = 8,
            }, function()
                ui.box('trigger part', {
                    flexDirection = 'row',
                }, function()
                    ui.box('trigger label', {
                        flex = 1,
                    }, function()
                        ui.markdown('## when')
                    end)
                    ui.box('trigger chooser', {
                        flex = 3,
                    }, function()
                        self:uiRulePart('trigger', rule, actorId)
                    end)
                end)
                ui.box('response part', {
                    flexDirection = 'row',
                }, function()
                    ui.box('response label', {
                        flex = 1,
                    }, function()
                        ui.markdown('## do')
                    end)
                    ui.box('response chooser', {
                        flex = 3,
                    }, function()
                        self:uiRulePart('response', rule, actorId)
                    end)
                end)
            end)
        end

        ui.button('add rule', {
            icon = 'plus',
            iconFamily = 'FontAwesome5',
            onClick = function()
                table.insert(self.globals.rules, util.deepCopyTable(EMPTY_RULE))
                self:sendSetProperties(nil, 'rules', self.globals.rules)
            end,
        })
    end)
end
