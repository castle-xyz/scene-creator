local CounterBehavior = defineCoreBehavior {
    name = 'Counter',
    displayName = 'counter',
    propertyNames = {
        'value',
        'minValue',
        'maxValue',
    },
    dependencies = {
    },
}


-- Component management

function CounterBehavior.handlers:addComponent(component, bp, opts)
    component.properties.value = bp.value or bp.minValue or bp.maxValue or 0
    component.properties.minValue = bp.minValue or 0
    component.properties.maxValue = bp.maxValue or 100
end

function CounterBehavior.handlers:blueprintComponent(component, bp)
    bp.minValue = component.properties.minValue
    bp.maxValue = component.properties.maxValue
    bp.value = component.properties.value
end


-- Setters

function CounterBehavior.setters:value(component, newValue, opts)
    local newValue = math.max(component.properties.minValue,
        math.min(newValue, component.properties.maxValue))
    if component.properties.value ~= newValue then
        component.properties.value = newValue
        if self.game.performing and opts.isOrigin then
            self:fireTrigger('counter reaches value', component.actorId, {
                counterValue = newValue,
            }, {
                filter = function(params)
                    if params.comparison == 'equal' and newValue == params.value then
                        return true
                    end
                    if params.comparison == 'less or equal' and newValue <= params.value then
                        return true
                    end
                    if params.comparison == 'greater or equal' and newValue >= params.value then
                        return true
                    end
                    return false
                end,
            })

            self:fireTrigger('counter changes', component.actorId)
        end
    end
end


-- Triggers

CounterBehavior.triggers['counter reaches value'] = {
    description = [[
Triggered when the actor's counter reaches a given value.
    ]],

    category = 'counter',

    initialParams = {
        comparison = 'equal',
        value = 0,
    },

    uiBody = function(self, params, onChangeParam)
        util.uiRow('the row', function()
            ui.dropdown('comparison', params.comparison, {
                'equal', 'less or equal', 'greater or equal',
            }, {
                onChange = function(newComparison)
                    onChangeParam('change comparison type', 'comparison', newComparison)
                end,
            })
        end, function()
            ui.numberInput('value', params.value, {
                step = 1,
                onChange = function(newValue)
                    onChangeParam('change comparison value', 'value', newValue)
                end,
            })
        end)
    end,
}

CounterBehavior.triggers['counter changes'] = {
    description = [[
Triggered when the actor's counter changes.
    ]],

    category = 'counter',
}



-- Responses

CounterBehavior.responses['change counter'] = {
    description = [[
Changes the actor's counter by the given value. A **positive value increments** the counter, while a **negative value decrements** it.
    ]],

    category = 'counter',

    initialParams = {
        changeBy = 1,
    },

    uiBody = function(self, params, onChangeParam)
        ui.numberInput('change by', params.changeBy, {
            step = 1,
            onChange = function(newChangeBy)
                onChangeParam('set counter change by', 'changeBy', newChangeBy)
            end,
        })
    end,

    run = function(self, actorId, params, context)
        if context.isOwner then -- Only owning host should fire counter updates
            local component = self.components[actorId]
            if component then
                self:sendSetProperties(actorId, 'value', component.properties.value + params.changeBy)
            end
        end
    end,
}

CounterBehavior.responses['set counter'] = {
    description = [[
**Directly sets** the counter to the given value.
    ]],

    category = 'counter',

    initialParams = {
        setToValue = 0,
    },

    uiBody = function(self, params, onChangeParam)
        ui.numberInput('set to value', params.setToValue, {
            step = 1,
            onChange = function(newSetToValue)
                onChangeParam('change set counter value', 'setToValue', newSetToValue)
            end,
        })
    end,

    run = function(self, actorId, params, context)
        if context.isOwner then -- Only owning host should fire counter updates
            local component = self.components[actorId]
            if component then
                self:sendSetProperties(actorId, 'value', params.setToValue)
            end
        end
    end,
}


-- UI

function CounterBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    local initialPrefix = not self.performing and 'initial ' or ''

    self:uiProperty('numberInput', initialPrefix .. 'value', actorId, 'value', {
        props = {
            min = component.properties.minValue,
            max = component.properties.maxValue,
            step = 1,
        },
    })

    util.uiRow('min max', function()
        self:uiProperty('numberInput', 'minimum value', actorId, 'minValue', {
            props = {
                max = component.properties.maxValue,
                step = 1,
            },
        })
    end, function()
        self:uiProperty('numberInput', 'maximum value', actorId, 'maxValue', {
            props = {
                min = component.properties.minValue,
                step = 1,
            },
        })
    end)
end


