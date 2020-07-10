local CounterBehavior =
    defineCoreBehavior {
    name = "Counter",
    displayName = "counter",
    propertyNames = {
        "value",
        "minValue",
        "maxValue"
    },
    dependencies = {},
    propertySpecs = {
       value = {
          method = 'numberInput',
          label = 'value',
          props = { step = 1 }, -- TODO: dynamic min and max
       },
       minValue = {
          method = 'numberInput',
          label = 'minimum value',
          props = { step = 1 },
       },
       maxValue = {
          method = 'numberInput',
          label = 'maximum value',
          props = { step = 1 },
       },
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
    local newValue = math.max(component.properties.minValue, math.min(newValue, component.properties.maxValue))
    if component.properties.value ~= newValue then
        component.properties.value = newValue
        if self.game.performing and opts.isOrigin then
            self:fireTrigger(
                "counter reaches value",
                component.actorId,
                {
                    counterValue = newValue
                },
                {
                    filter = function(params)
                        if params.comparison == "equal" and newValue == params.value then
                            return true
                        end
                        if params.comparison == "less or equal" and newValue <= params.value then
                            return true
                        end
                        if params.comparison == "greater or equal" and newValue >= params.value then
                            return true
                        end
                        return false
                    end
                }
            )

            self:fireTrigger("counter changes", component.actorId)
        end
    end
end

-- Triggers

CounterBehavior.triggers["counter reaches value"] = {
    description = "When this actor's counter reaches a value",
    category = "state",
    paramSpecs = {
       comparison = {
          method = "dropdown",
          initialValue = "equal",
          props = {
             items = {
                "equal",
                "less or equal",
                "greater or equal",
             },
          },
       },
       value = {
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        comparison = "equal",
        value = 0
    },
    uiBody = function(self, params, onChangeParam)
        util.uiRow(
            "the row",
            function()
                ui.dropdown(
                    "comparison",
                    params.comparison,
                    {
                        "equal",
                        "less or equal",
                        "greater or equal"
                    },
                    {
                        onChange = function(newComparison)
                            onChangeParam("change comparison type", "comparison", newComparison)
                        end
                    }
                )
            end,
            function()
                ui.numberInput(
                    "value",
                    params.value,
                    {
                        step = 1,
                        onChange = function(newValue)
                            onChangeParam("change comparison value", "value", newValue)
                        end
                    }
                )
            end
        )
    end
}

CounterBehavior.triggers["counter changes"] = {
    description = "When the actor's counter changes",
    category = "state"
}

-- Responses

CounterBehavior.responses["change counter"] = {
    description = "Adjust the actor's counter",
    category = "state",
    paramSpecs = {
       changeBy = {
          label = "adjust by",
          method = "numberInput",
          initialValue = 1,
       },
    },
    initialParams = {
        changeBy = 1
    },
    uiBody = function(self, params, onChangeParam)
        ui.numberInput(
            "change by",
            params.changeBy,
            {
                step = 1,
                onChange = function(newChangeBy)
                    onChangeParam("set counter change by", "changeBy", newChangeBy)
                end
            }
        )
    end,
    run = function(self, actorId, params, context)
        if context.isOwner then -- Only owning host should fire counter updates
            local component = self.components[actorId]
            if component then
                self:sendSetProperties(actorId, "value", component.properties.value + params.changeBy)
            end
        end
    end
}

CounterBehavior.responses["set counter"] = {
    description = "Set the actor's counter",
    category = "state",
    paramSpecs = {
       setToValue = {
          label = "set to value",
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        setToValue = 0
    },
    uiBody = function(self, params, onChangeParam)
        ui.numberInput(
            "set to value",
            params.setToValue,
            {
                step = 1,
                onChange = function(newSetToValue)
                    onChangeParam("change set counter value", "setToValue", newSetToValue)
                end
            }
        )
    end,
    run = function(self, actorId, params, context)
        if context.isOwner then -- Only owning host should fire counter updates
            local component = self.components[actorId]
            if component then
                self:sendSetProperties(actorId, "value", params.setToValue)
            end
        end
    end
}

CounterBehavior.responses["counter meets condition"] = {
    description = "If the actor's counter meets a condition",
    category = "state",
    returnType = "boolean",
    paramSpecs = {
       comparison = {
          method = "dropdown",
          initialValue = "equal",
          props = {
             items = {
                "equal",
                "less or equal",
                "greater or equal",
             },
          },
       },
       value = {
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        comparison = "equal",
        value = 0
    },
    uiBody = function(self, params, onChangeParam)
        util.uiRow(
            "the row",
            function()
                ui.dropdown(
                    "comparison",
                    params.comparison,
                    {
                        "equal",
                        "less or equal",
                        "greater or equal"
                    },
                    {
                        onChange = function(newComparison)
                            onChangeParam("change comparison type", "comparison", newComparison)
                        end
                    }
                )
            end,
            function()
                ui.numberInput(
                    "value",
                    params.value,
                    {
                        step = 1,
                        onChange = function(newValue)
                            onChangeParam("change comparison value", "value", newValue)
                        end
                    }
                )
            end
        )
    end,
    run = function(self, actorId, params, context)
        local component = self.components[actorId]
        if not component then
            return false
        end
        local value = component.properties.value

        if params.comparison == "equal" and value == params.value then
            return true
        end
        if params.comparison == "less or equal" and value <= params.value then
            return true
        end
        if params.comparison == "greater or equal" and value >= params.value then
            return true
        end
        return false
    end
}

-- UI

function CounterBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    local initialPrefix = not self.performing and "initial " or ""

    self:uiProperty(
        "numberInput",
        initialPrefix .. "value",
        actorId,
        "value",
        {
            props = {
                min = component.properties.minValue,
                max = component.properties.maxValue,
                step = 1
            }
        }
    )

    util.uiRow(
        "min max",
        function()
            self:uiProperty(
                "numberInput",
                "minimum value",
                actorId,
                "minValue",
                {
                    props = {
                        max = component.properties.maxValue,
                        step = 1
                    }
                }
            )
        end,
        function()
            self:uiProperty(
                "numberInput",
                "maximum value",
                actorId,
                "maxValue",
                {
                    props = {
                        min = component.properties.minValue,
                        step = 1
                    }
                }
            )
        end
    )
end
