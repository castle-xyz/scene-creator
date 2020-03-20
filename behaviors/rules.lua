local RulesBehavior = defineCoreBehavior {
    name = 'Rules',
    displayName = 'rules',
    propertyNames = {
        'rules',
    },
    dependencies = {
    },
}


local EMPTY_RULE = {
    triggerBehaviorId = nil,
    triggerName = 'none',
    responseBehaviorId = nil,
    responseName = 'none',
}


-- Component management

function RulesBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rules = util.deepCopyTable(bp.rules or { EMPTY_RULE })
end

function RulesBehavior.handlers:blueprintComponent(component, bp)
    bp.rules = util.deepCopyTable(component.properties.rules)
end


-- Setters

function RulesBehavior.setters:rules(component, newRules)
    component.properties.rules = newRules

    component._rulesByTriggerName = {}
    for _, rule in ipairs(component.properties.rules) do
        if rule.triggerName ~= 'none' then
            if not component._rulesByTriggerName[rule.triggerName] then
                component._rulesByTriggerName[rule.triggerName] = {}
            end
            table.insert(component._rulesByTriggerName[rule.triggerName], rule)
        end
    end
end


-- Trigger / response

function RulesBehavior.handlers:trigger(triggerName, opts)
    local actorId = opts.actorId
    local component = self.components[actorId]
    if not component then -- No rules on this actor?
        return
    end

    local params = opts.params or {}

    local rulesToRun = component._rulesByTriggerName[triggerName]
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

function RulesBehavior:uiRulePart(component, rule, part, label)
    local actor = self.game.actors[component.actorId]

    local buttonLabel
    if rule[part .. 'BehaviorId'] then
        local behavior = self.game.behaviors[rule[part .. 'BehaviorId']]
        buttonLabel = behavior:getUiName() .. ': ' .. rule[part .. 'Name']
    else
        buttonLabel = 'no ' .. part
    end

    ui.box(part .. ' part', {
        flexDirection = 'row',
    }, function()
        ui.box(part .. ' label', {
            flex = 1,
        }, function()
            ui.markdown('## ' .. label)
        end)
        ui.box(part .. ' chooser', {
            flex = 3,
        }, function()
            ui.button(buttonLabel, {
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
                                                        self:sendSetProperties(component.actorId, 'rules', component.properties.rules)
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
        end)
    end)
end

function RulesBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    for ruleIndex, rule in ipairs(component.properties.rules) do
        ui.box('rule-' .. ruleIndex, {
            borderWidth = 1,
            borderColor = '#292929',
            borderRadius = 4,
            padding = 4,
            margin = 4,
            marginBottom = 8,
        }, function()
            self:uiRulePart(component, rule, 'trigger', 'when')
            self:uiRulePart(component, rule, 'response', 'do')
        end)
    end

    ui.button('add rule', {
        icon = 'plus',
        iconFamily = 'FontAwesome5',
        onClick = function()
            table.insert(component.properties.rules, util.deepCopyTable(EMPTY_RULE))
            self:sendSetProperties(actorId, 'rules', component.properties.rules)
        end,
    })
end
