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


-- Behavior management

function RulesBehavior.handlers:addBehavior(opts)
    self._pendingWaits = {}
end


-- Component management

function RulesBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rules = util.deepCopyTable(bp.rules or { EMPTY_RULE })
    self.setters.rules(self, component, component.properties.rules)
end

function RulesBehavior.handlers:removeComponent(component, opts)
    self._pendingWaits[component.actorId] = nil
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

    local function doIt()
        local rulesToRun = component._rulesByTriggerName[triggerName]
        if rulesToRun then
            for _, ruleToRun in ipairs(rulesToRun) do
                self:runResponse(ruleToRun.response, actorId, context)
            end
        end
    end

    if triggerName == 'collide' then
        self:onEndOfFrame(doIt) -- Wait till end of frame for collide trigger
    else
        doIt()
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
                    local result = responseEntry.run(behavior, component, response.params, context, function(childName)
                        self:runResponse(response.params[childName], actorId, context)
                    end)
                    if responseEntry.returnType ~= nil then
                        return result
                    end
                    if responseEntry.autoNext ~= false then
                        self:runResponse(response.params.nextResponse, actorId, context)
                    end
                end
            end
        end
    end
end


-- Responses

RulesBehavior.responses.wait = {
    description = [[
**Wait some time** before performing the next response.
    ]],

    autoNext = false,

    category = 'timing',

    initialParams = {
        duration = 1,
    },

    ui = function(self, params, onChangeParam)
        ui.numberInput('duration (seconds)', params.duration, {
            min = 0,
            onChange = function(newDuration)
                onChangeParam('duration', newDuration)
            end,
        })
    end,

    run = function(self, component, params, context, runChild)
        if not self._pendingWaits[component.actorId] then
            self._pendingWaits[component.actorId] = {}
        end
        table.insert(self._pendingWaits[component.actorId], {
            actorId = component.actorId,
            timeLeft = params.duration,
            run = function()
                runChild('nextResponse')
            end,
        })
    end,
}


-- Perform

function RulesBehavior.handlers:perform(dt)
    for actorId, pendingWaits in pairs(self._pendingWaits) do
        local newPendingWaits = {}
        for _, wait in ipairs(pendingWaits) do
            wait.timeLeft = wait.timeLeft - dt
            if wait.timeLeft <= 0 then
                wait.run()
            else
                table.insert(newPendingWaits, wait)
            end
        end
        if next(newPendingWaits) then
            self._pendingWaits[actorId] = newPendingWaits
        else
            self._pendingWaits[actorId] = nil
        end
    end
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
        borderLeftWidth = part.name == 'none' and 0 or 3,
        borderColor = '#eee',
        margin = 3,
        paddingLeft = 6,
        marginLeft = 10,
    }, function()
        ui.box('header', { flexDirection = 'row' }, function()
            if part.name ~= 'none' then
                ui.box('name', {
                    flex = 1,
                }, function()
                    ui.markdown('## ' .. part.name)
                end)
            end
            ui.box('selector', {
                flex = part.name == 'none' and 1 or nil,
            }, function()
                ui.button('add ' .. props.kind, {
                    flex = part.name == 'none' and 1 or nil,
                    margin = 0,
                    icon = part.name == 'none' and 'plus' or 'ellipsis-v',
                    iconFamily = 'FontAwesome5',
                    hideLabel = part.name ~= 'none',
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
                end, function(childName, childReturnType)
                    self:uiPart(actorId, part.params[childName], {
                        kind = 'response',
                        returnType = childReturnType,
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
        }, function()
            ui.box('trigger box', { flexDirection = 'row' }, function()
                ui.box('when box', { margin = 3 }, function()
                    ui.markdown('## when')
                end)
                self:uiPart(actorId, rule.trigger, {
                    kind = 'trigger',
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
