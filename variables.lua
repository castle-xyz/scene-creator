-- Start / stop

function Common:startVariables()
    self.variables = {}
    self._updateQueued = false
    self._framesSinceUpdate = 0
end

-- Message kind definitions

function Common:defineVariablesMessageKinds()
    -- From anyone to all
    self:defineMessageKind("updateVariables", self.sendOpts.reliableToAll)
end

-- Utils

function Common:variablesReset()
    if self._initialVariables then
        self:send("updateVariables", self._initialVariables)
    end
end

function Common:variablesNamesToValues()
   local variableNameToValue = {}
   if self.variables ~= nil then
      for _, variable in ipairs(self.variables) do
         variableNameToValue[variable.name] = variable.value
      end
   end
   return variableNameToValue
end

function Common:variablesNames()
    local names = {}
    for i = 1, #self.variables do
        names[i] = self.variables[i].name
    end
    return names
end

function Common:variableNameToId(name)
    for i = 1, #self.variables do
        if self.variables[i].name == name then
            return self.variables[i].id
        end
    end

    return nil
end

function Common:variableIdToName(id)
    for i = 1, #self.variables do
        if self.variables[i].id == id then
            return self.variables[i].name
        end
    end

    return "(none)"
end

function Common:variableIdToValue(id)
    for i = 1, #self.variables do
        if self.variables[i].id == id then
            return self.variables[i].value
        end
    end

    return 0
end


local function variableReachesValueTrigger(self, actorId, variableId, newValue)
    self.behaviorsByName.Rules:fireTrigger(
        "variable reaches value",
        actorId,
        {},
        {
            filter = function(params)
                local applies, lhs, rhs
                if params.variableId == variableId then
                    -- $variable reaches value
                    applies = true
                    lhs = newValue
                    rhs = self:evalExpression(actorId, params.value)
                elseif type(params.value) == "table"
                    and params.value.expressionType == "variable"
                    and params.value.params.variableId == variableId then
                     -- $other_variable reaches $variable
                     applies = true
                     lhs = self:variableIdToValue(params.variableId)
                     rhs = newValue
                end

                if not applies then
                   return false
                end

                if params.comparison == "equal" and lhs == rhs then
                    return true
                end
                if params.comparison == "less or equal" and lhs <= rhs then
                    return true
                end
                if params.comparison == "greater or equal" and lhs >= rhs then
                    return true
                end
                return false
            end
        }
    )

    -- maybe fire 'counter reaches $variable'
    self.behaviorsByName.Counter:fireTrigger(
       "counter reaches value",
       actorId,
       {},
       {
          filter = function(params)
             local component = self.behaviorsByName.Counter.components[actorId]
             if component == nil then
                return false
             end
             if type(params.value) ~= "table" or params.value.expressionType ~= "variable" then
                return false
             end
             if params.value.params.variableId == variableId then
                 local lhs = component.properties.value
                 local rhs = newValue

                 if params.comparison == "equal" and lhs == rhs then
                    return true
                 end
                 if params.comparison == "less or equal" and lhs <= rhs then
                    return true
                 end
                 if params.comparison == "greater or equal" and lhs >= rhs then
                    return true
                 end
                 return false
             end
          end
       }
    )
end

local function fireVariableTriggers(self, variableId, newValue)
    self._updateQueued = true

    for actorId, actor in pairs(self.actors) do
        self.behaviorsByName.Rules:fireTrigger(
            "variable changes",
            actorId,
            {},
            {
                filter = function(params)
                    return params.variableId == variableId
                end
            }
        )

        variableReachesValueTrigger(self, actorId, variableId, newValue)
    end
end

function Common:variableReset(id)
   for i = 1, #self.variables do
      if self.variables[i].id == id then
        if self._initialVariables[i].value ~= self.variables[i].value then
            self.variables[i].value = self._initialVariables[i].value
            fireVariableTriggers(self, id, self.variables[i].value)
        end
      end
   end
end

function Common:variableResetAll()
    for i = 1, #self.variables do
        if self._initialVariables[i].value ~= self.variables[i].value then
            self.variables[i].value = self._initialVariables[i].value
            fireVariableTriggers(self, id, self.variables[i].value)
        end
    end
 end

function Common:variableSetToValue(variableId, value)
    for i = 1, #self.variables do
        if self.variables[i].id == variableId then
            if self.variables[i].value ~= value then
                self.variables[i].value = value

                fireVariableTriggers(self, variableId, self.variables[i].value)
            end
        end
    end
end

function Common:variableChangeByValue(variableId, changeBy)
    if changeBy == 0 then
        return
    end

    for i = 1, #self.variables do
        if self.variables[i].id == variableId then
            self.variables[i].value = self.variables[i].value + changeBy

            fireVariableTriggers(self, variableId, self.variables[i].value)
        end
    end
end

function Common:sendVariableUpdate()
    if self._updateQueued and self._framesSinceUpdate > 10 then
        self._updateQueued = false
        self._framesSinceUpdate = 0

        jsEvents.send(
            "GHOST_MESSAGE",
            {
                messageType = "CHANGE_DECK_STATE",
                data = {
                    variables = self.variables
                }
            }
        )
    else
        self._framesSinceUpdate = self._framesSinceUpdate + 1
    end
end

-- Message receivers

function Common.receivers:updateVariables(time, variables)
    for i = 1, #variables do
        if not variables[i].value then
            variables[i].value = variables[i].initialValue
        end
    end

    self.variables = variables
    self._initialVariables = util.deepCopyTable(variables or {})
end

function Common:variablesUpdatePostAddActor(actorId)
    for i = 1, #self.variables do
        variableReachesValueTrigger(self, actorId, self.variables[i].id, self.variables[i].value)
    end
end
