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
    trigger = {
        name = 'none',
        behaviorId = nil,
    },
    response = {
        name = 'none',
        behaviorId = nil,
    }
}


-- Component management

function RulesBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rules = util.deepCopyTable(bp.rules or { EMPTY_RULE })
    component._rulesByTriggerName = {}
end

function RulesBehavior.handlers:blueprintComponent(component, bp)
    bp.rules = util.deepCopyTable(component.properties.rules)
end


-- Setters

function RulesBehavior.setters:rules(component, newRules)
    component.properties.rules = newRules

    component._rulesByTriggerName = {}
    for _, rule in ipairs(component.properties.rules) do
        if rule.trigger.name ~= 'none' then
            if not component._rulesByTriggerName[rule.trigger.name] then
                component._rulesByTriggerName[rule.trigger.name] = {}
            end
            table.insert(component._rulesByTriggerName[rule.trigger.name], rule)
        end
    end
end


-- Trigger handler

function RulesBehavior.handlers:trigger(triggerName, actorId, context)
    local component = self.components[actorId]
    if not component then -- No rules on this actor?
        return
    end

    context = context or {}

    local rulesToRun = component._rulesByTriggerName[triggerName]
    if rulesToRun then
        for _, ruleToRun in ipairs(rulesToRun) do
            self:runResponse(ruleToRun.response, actorId, context)
        end
    end
end


-- Methods

function RulesBehavior:runResponse(response, actorId, context)
    if response and response.behaviorId and response.name ~= 'none' then
        local behavior = self.game.behaviors[response.behaviorId]
        if behavior then
            local component = behavior.components[actorId]
            if component then
                local responseEntry = behavior.responses[response.name]
                if responseEntry then
                    responseEntry.runComponent(behavior, component, response.params, context, function(childName)
                        self:runResponse(response.params[childName], actorId, context)
                    end)
                end
            end
        end
    end
end


-- Responses

RulesBehavior.responses.wait = {
    description = [[
**Wait some time** then perform another response.
    ]],

    initialParams = {
        time = 15,
        nextResponse = {
            name = 'none',
            behaviorId = nil,
        },
    },
}

function RulesBehavior.responses.wait:ui(params, onChangeParam, uiChild)
    ui.numberInput('time (seconds)', params.time, {
        min = 0,
        onChange = function(newTime)
            onChangeParam('time', newTime)
        end,
    })

    uiChild('nextResponse')
end

function RulesBehavior.responses.wait:runComponent(component, params, context, runChild)
    network.async(function()
        copas.sleep(params.time)
        runChild('nextResponse')
    end)
end


-- UI

function RulesBehavior:uiPart(actorId, part, props)
    local actor = self.game.actors[actorId]

    local behavior, entry
    if part.name ~= 'none' then
        behavior = self.game.behaviors[part.behaviorId]
        entry = behavior[props.kind .. 's'][part.name]
    end

    ui.box(part.name .. ' box', {
        flex = 1,
        borderRadius = 6,
        borderLeftWidth = part.name == 'none' and 0 or 2,
        borderColor = '#eee',
        margin = 3,
    }, function()
        ui.box('header', { flexDirection = 'row' }, function()
            if part.name ~= 'none' then
                ui.box('name', {
                    flex = 1,
                    paddingLeft = 4,
                }, function()
                    ui.markdown('## ' .. part.name)
                end)
            end
            if part.name ~= 'none' then
                ui.button('description', {
                    margin = 0,
                    marginRight = 6,
                    icon = 'question',
                    iconFamily = 'FontAwesome5',
                    hideLabel = true,
                    popoverAllowed = true,
                    popoverStyle = { width = 300 },
                    popover = function()
                        ui.markdown('## ' .. part.name .. '\n' .. (entry.description or ''))
                    end,
                })
            end
            ui.box('selector', {
                flex = part.name == 'none' and 1 or nil,
            }, function()
                ui.button('select ' .. props.kind, {
                    flex = part.name == 'none' and 1 or nil,
                    margin = 0,
                    icon = 'ellipsis-v',
                    iconFamily = 'FontAwesome5',
                    hideLabel = part.name ~= 'none',
                    popoverAllowed = true,
                    popoverStyle = { width = 300, height = 300 },
                    popover = function(closePopover)
                        ui.scrollBox('scroll box', {
                            padding = 2,
                            margin = 2,
                            flex = 1,
                        }, function()
                            for behaviorId in pairs(actor.components) do
                                local behavior = self.game.behaviors[behaviorId]
                                local behaviorParts = behavior[props.kind .. 's']
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
                                                            if props.onChange then
                                                                props.onChange({
                                                                    behaviorId = behaviorId,
                                                                    name = entryName,
                                                                    params = util.deepCopyTable(entry.initialParams),
                                                                })
                                                            end
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
        if part.name ~= 'none' and entry.ui then
            entry.ui(behavior, part.params,
                function(paramName, newValue)
                    local newParams = util.deepCopyTable(part.params)
                    newParams[paramName] = newValue
                    props.onChange({
                        behaviorId = part.behaviorId,
                        name = part.name,
                        params = newParams,
                    })
                end, function(childName)
                    self:uiPart(actorId, part.params[childName], {
                        kind = 'response',
                        onChange = function(newChild)
                            local newParams = util.deepCopyTable(part.params)
                            newParams[childName] = newChild
                            props.onChange({
                                behaviorId = part.behaviorId,
                                name = part.name,
                                params = newParams,
                            })
                        end,
                    })
                end)
        end
    end)
end

function RulesBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    for ruleIndex, rule in ipairs(component.properties.rules) do
        ui.box('rule-' .. ruleIndex, {
            borderRadius = 6,
            borderLeftWidth = 2,
            borderColor = '#eee',
            marginBottom = 8,
        }, function()
            ui.box('trigger box', { flexDirection = 'row' }, function()
                ui.box('when box', { margin = 3 }, function()
                    ui.markdown('## when')
                end)
                self:uiPart(actorId, rule.trigger, {
                    kind = 'trigger',
                    onChange = function(newTrigger)
                        rule.trigger = newTrigger
                        self:sendSetProperties(component.actorId, 'rules', component.properties.rules)
                    end,
                })
            end)
            self:uiPart(actorId, rule.response, {
                kind = 'response',
                onChange = function(newResponse)
                    rule.response = newResponse
                    self:sendSetProperties(component.actorId, 'rules', component.properties.rules)
                end,
            })
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
