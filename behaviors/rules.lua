local RulesBehavior = defineCoreBehavior {
    name = 'Rules',
    displayName = 'rules',
    propertyNames = {
        'rules',
    },
    dependencies = {
    },
}


local MAX_COROUTINES_PER_ACTOR = 20

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


-- Behavior management

function RulesBehavior.handlers:addBehavior(opts)
    self._coroutines = {}
end


-- Component management

function RulesBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rules = util.deepCopyTable(bp.rules or { EMPTY_RULE })
    self.setters.rules(self, component, component.properties.rules)
end

function RulesBehavior.handlers:preRemoveComponent(component, opts)
    -- TODO(nikki): Fire 'destroy' trigger
end

function RulesBehavior.handlers:removeComponent(component, opts)
    self._coroutines[component.actorId] = nil
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
            if not self._coroutines[actorId] then
                self._coroutines[actorId] = {}
            end
            if #self._coroutines[actorId] < MAX_COROUTINES_PER_ACTOR then
                table.insert(self._coroutines[actorId], coroutine.create(function()
                    self:runResponse(ruleToRun.response, actorId, context)
                end))
            end
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
                    local result = responseEntry.run(behavior, component, response.params, context)
                    if responseEntry.returnType ~= nil then
                        return result
                    else
                        self:runResponse(response.params.nextResponse, actorId, context)
                    end
                end
            end
        end
    end
end


-- Actor triggers

RulesBehavior.triggers.create = {
    description = [[
Triggered when the actor is created. If the actor is already present when the scene starts, this is triggered when the scene starts.
    ]],
}

--RulesBehavior.triggers.destroy = {
--    description = [[
--Triggered when the actor is removed from the scene.
--    ]],
--}


-- Timing responses

RulesBehavior.responses.wait = {
    description = [[
**Wait some time** before performing the next response.
    ]],

    autoNext = false,

    category = 'timing',

    initialParams = {
        duration = 1,
    },

    uiBody = function(self, params, onChangeParam)
        ui.numberInput('duration (seconds)', params.duration, {
            min = 0,
            max = 30,
            step = 0.2,
            onChange = function(newDuration)
                onChangeParam('duration', newDuration)
            end,
        })
    end,

    run = function(self, component, params, context)
        local timeLeft = params.duration
        while timeLeft > 0 do
            timeLeft = timeLeft - coroutine.yield()
        end
    end,
}


-- Logic responses

RulesBehavior.responses['if'] = {
    description = [[
Perform a response **only if** a given condition is true. Optionally can have an 'else' branch for when the condition is false.
    ]],

    category = 'logic',

    uiMenu = function(self, params, onChangeParam, uiChild)
        ui.toggle("use 'else' branch", "use 'else' branch", params['else'] ~= nil, {
            onToggle = function(newElseEnabled)
                if newElseEnabled then
                    onChangeParam('else', util.deepCopyTable(EMPTY_RULE.response))
                else
                    onChangeParam('else', nil)
                end
            end,
        })
    end,

    uiHeader = function(self, params, onChangeParam, uiChild)
        uiChild('condition', {
            label = 'condition',
            noMarginTop = true,
            returnType = 'boolean',
        })
    end,

    uiBody = function(self, params, onChangeParam, uiChild)
        uiChild('then')
        if params['else'] then
            ui.box('else container', {
                flexDirection = 'row',
            }, function()
                ui.box('else backgrond', {
                    marginTop = 12,
                    marginBottom = 6,
                    marginLeft = -9,
                    borderWidth = 2,
                    borderColor = '#eee',
                    backgroundColor = '#eee',
                    borderTopRightRadius = 6,
                    borderBottomRightRadius = 6,
                }, function()
                    ui.markdown('### else')
                end)
            end)
            uiChild('else')
        end
    end,

    run = function(self, component, params, context)
        if self:runResponse(params['condition'], component.actorId, context) then
            self:runResponse(params['then'], component.actorId, context)
        else
            self:runResponse(params['else'], component.actorId, context)
        end
    end,
}


-- Random responses

RulesBehavior.responses['coin flip'] = {
    description = [[
Is true if a coin flip comes up heads. The coin can be biased with a given probability.
    ]],

    category = 'random',

    returnType = 'boolean',

    initialParams = {
        probability = 0.5,
    },

    uiBody = function(self, params, onChangeParam, uiChild)
        ui.numberInput('probability of heads', params.probability, {
            min = 0,
            max = 1,
            step = 0.2,
            onChange = function(newProbability)
                onChangeParam('probability', newProbability)
            end,
        })
    end,

    run = function(self, component, params, context)
        return math.random() < params.probability
    end,
}


-- Perform

function RulesBehavior.handlers:postPerform(dt)
    -- Lazily fire 'create' triggers
    for actorId, component in pairs(self.components) do
        if not component._triggeredCreate then
            component._triggeredCreate = true
            self:fireTrigger('create', component.actorId)
        end
    end

    -- Resume coroutines
    for actorId, coroutines in pairs(self._coroutines) do
        local newCoroutines = {}
        for _, coro in ipairs(coroutines) do
            local succeeded, err = coroutine.resume(coro, dt)
            if not succeeded then
                print('rule error: ', err)
            end
            if coroutine.status(coro) ~= 'dead' then
                table.insert(newCoroutines, coro)
            end
        end
        if next(newCoroutines) then
            self._coroutines[actorId] = newCoroutines
        else
            self._coroutines[actorId] = nil
        end
    end
end


-- UI

function RulesBehavior:uiPart(actorId, part, props)
    part = part or EMPTY_RULE.response

    local actor = self.game.actors[actorId]

    local behavior, entry
    if part.name ~= 'none' then
        behavior = self.game.behaviors[part.behaviorId]
        entry = behavior[props.kind .. 's'][part.name]
    end

    local function callEntryUi(funcName)
        if entry[funcName] then
            entry[funcName](behavior, part.params,
                function(paramName, newValue)
                    local newParams = util.deepCopyTable(part.params)
                    newParams[paramName] = newValue
                    props.onChange({
                        behaviorId = part.behaviorId,
                        name = part.name,
                        params = newParams,
                    })
                end, function(childName, childProps)
                    local newProps = util.deepCopyTable(childProps) or {}
                    newProps.kind = 'response'
                    newProps.onChange = function(newChild)
                        local newParams = util.deepCopyTable(part.params)
                        newParams[childName] = newChild
                        props.onChange({
                            behaviorId = part.behaviorId,
                            name = part.name,
                            params = newParams,
                        })
                    end
                    self:uiPart(actorId, part.params[childName], newProps)
                end)
        end
    end

    ui.box(part.name .. ' container', {
        flex = 1, 
        marginTop = not props.noMarginTop and 6 or nil
    }, function()
        ui.box('header', {
            flex = 1,
            flexDirection = 'row',
            marginLeft = 12,
            zIndex = 1,
        }, function()
            if part.name ~= 'none' and entry.uiBody then
                ui.box('border', {
                    position = 'absolute',
                    top = 8,
                    left = 0,
                    right = 0,
                    bottom = 0,
                    borderLeftWidth = part.name == 'none' and 0 or 3,
                    borderColor = '#eee',
                }, function() end)
            end
            ui.box('selector', {
                flex = part.name == 'none' and 1 or nil,
            }, function()
                local label
                if part.name == 'none' then
                    label = (props.kind == 'response' and props.returnType == nil and 'add ' or 'select ') .. (props.label or props.kind)
                else
                    label = part.name
                end
                ui.button(label, {
                    margin = 0,
                    textStyle = part.name ~= 'none' and { fontSize = 18 } or nil,
                    icon = part.name == 'none' and 'plus' or 'ellipsis-v',
                    iconFamily = 'FontAwesome5',
                    onClick = function()
                        self._picking = nil
                    end,
                    popoverAllowed = true,
                    popoverStyle = { width = 300, maxHeight = 300 },
                    popover = function(closePopover)
                        ui.scrollBox('scroll box', {
                            padding = 2,
                            margin = 2,
                            flexGrow = 0,
                            alwaysBounceVertical = false,
                        }, function()
                            if part.name ~= 'none' and not self._picking then
                                ui.markdown('## ' .. part.name .. '\n' .. (entry.description or ''))
                                if entry.uiMenu then
                                    callEntryUi('uiMenu')
                                    ui.box('spacer', { height = 18 }, function() end)
                                end
                                if props.kind == 'response' and entry.returnType == nil then
                                    util.uiRow('insert move', function()
                                        ui.button('insert before', {
                                            icon = 'plus',
                                            iconFamily = 'FontAwesome5',
                                            onClick = function()
                                                self._picking = 'insertBefore'
                                            end,
                                        })
                                    end, function()
                                        if part.params.nextResponse and part.params.nextResponse.name ~= 'none' then
                                            ui.button('move down', {
                                                icon = 'arrow-bold-down',
                                                iconFamily = 'Entypo',
                                                onClick = function()
                                                    closePopover()
                                                    local clone = util.deepCopyTable(part)
                                                    local newHead = clone.params.nextResponse
                                                    clone.params.nextResponse = newHead.params.nextResponse
                                                    newHead.params.nextResponse = clone
                                                    props.onChange(newHead)
                                                end,
                                            })
                                        end
                                    end)
                                end
                                util.uiRow('replace remove', function()
                                    ui.button('replace', {
                                        icon = 'exchange-alt',
                                        iconFamily = 'FontAwesome5',
                                        onClick = function()
                                            self._picking = 'replace'
                                        end,
                                    })
                                end, function()
                                    ui.button('remove', {
                                        icon = 'trash-alt',
                                        iconFamily = 'FontAwesome5',
                                        onClick = function()
                                            closePopover()
                                            props.onChange(part.params.nextResponse)
                                        end,
                                    })
                                end)
                            else
                                local categories = {}
                                for behaviorId in pairs(actor.components) do
                                    local behavior = self.game.behaviors[behaviorId]
                                    local behaviorUiName = behavior:getUiName()
                                    for name, entry in pairs(behavior[props.kind .. 's']) do
                                        if entry.returnType == props.returnType then
                                            local categoryName = entry.category or behaviorUiName
                                            if not categories[categoryName] then
                                                categories[categoryName] = {}
                                            end
                                            table.insert(categories[categoryName], {
                                                name = name,
                                                behaviorId = behaviorId,
                                                entry = entry,
                                            })
                                        end
                                    end
                                end
                                for categoryName, rows in pairs(categories) do
                                    ui.section(categoryName, { defaultOpen = true }, function()
                                        for _, row in ipairs(rows) do
                                            ui.box(row.name, {
                                                borderWidth = 1,
                                                borderColor = '#292929',
                                                borderRadius = 4,
                                                padding = 4,
                                                margin = 4,
                                                marginBottom = 8,
                                            }, function()
                                                ui.markdown('## ' .. row.name .. '\n' .. (row.entry.description or ''))

                                                ui.box('buttons', { flexDirection = 'row' }, function()
                                                    ui.button('use', {
                                                        flex = 1,
                                                        icon = 'plus',
                                                        iconFamily = 'FontAwesome5',
                                                        onClick = function()
                                                            closePopover()
                                                            if props.onChange then
                                                                local newParams = util.deepCopyTable(row.entry.initialParams) or {}
                                                                if self._picking == 'replace' then
                                                                    if part.params and part.params.nextResponse then
                                                                        newParams.nextResponse = part.params.nextResponse
                                                                    end
                                                                elseif self._picking == 'insertBefore' then
                                                                    newParams.nextResponse = part
                                                                end
                                                                props.onChange({
                                                                    behaviorId = row.behaviorId,
                                                                    name = row.name,
                                                                    params = newParams,
                                                                })
                                                            end
                                                            self._picking = nil
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
            if part.name ~= 'none' then
                callEntryUi('uiHeader')
            end
        end)

        if part.name ~= 'none' and entry.uiBody then
            ui.box(part.name .. ' box', {
                flex = 1,
                borderBottomLeftRadius = 6,
                borderLeftWidth = part.name == 'none' and 0 or 3,
                borderColor = '#eee',
                marginTop = -8,
                marginBottom = 4,
                paddingTop = 12,
                paddingLeft = 6,
                marginLeft = 12,
            }, function()
                callEntryUi('uiBody')
            end)
        end

        if props.kind == 'response' and part.name ~= 'none' and entry.returnType == nil then
            self:uiPart(actorId, part.params.nextResponse or EMPTY_RULE.response, {
                kind = 'response',
                onChange = function(newNextResponse)
                    local newParams = util.deepCopyTable(part.params)
                    newParams.nextResponse = newNextResponse
                    props.onChange({
                        behaviorId = part.behaviorId,
                        name = part.name,
                        params = newParams,
                    })
                end
            })
        end
    end)
end

function RulesBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    for ruleIndex, rule in ipairs(component.properties.rules) do
        ui.box('rule-' .. ruleIndex, {
            borderRadius = 6,
            borderLeftWidth = 3,
            borderColor = '#eee',
            margin = 4,
            marginVertical = 8,
            paddingLeft = 6,
        }, function()
            ui.box('when row', { flexDirection = 'row' }, function()
                ui.box('when box', { marginRight = 6, marginBottom = 8, marginTop = 2 }, function()
                    ui.markdown('### when')
                end)
                self:uiPart(actorId, rule.trigger, {
                    kind = 'trigger',
                    noMarginTop = true,
                    onChange = function(newTrigger)
                        rule.trigger = newTrigger or util.deepCopyTable(EMPTY_RULE.trigger)
                        self:sendSetProperties(component.actorId, 'rules', component.properties.rules)
                    end,
                })
            end)
            self:uiPart(actorId, rule.response, {
                kind = 'response',
                onChange = function(newResponse)
                    rule.response = newResponse or util.deepCopyTable(EMPTY_RULE.response)
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
