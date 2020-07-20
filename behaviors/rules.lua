local RulesBehavior =
    defineCoreBehavior {
    name = "Rules",
    displayName = "rules",
    dependencies = {},
    propertySpecs = {
       rules = {
          method = 'data'
       },
    },
}

local EMPTY_RULE = {
    trigger = {
        name = "none",
        behaviorId = nil
    },
    response = {
        name = "none",
        behaviorId = nil
    }
}

-- Behavior management

function RulesBehavior.handlers:addBehavior(opts)
    -- By default, there is at most one thread running per actor per rule.
    -- `threadKey`s can be used customize that per trigger.
    self._coroutines = {} -- `actorId` -> `threadKey` -> current coroutine for that thread key
end

-- Component management

function RulesBehavior:migrateLegacy(component, rules)
   local result = util.deepCopyTable(rules)

   local function migrateResponses(response)
      if response == nil then return end

      if response.params then
         migrateResponses(response.params.nextResponse)
         migrateResponses(response.params.body)
         migrateResponses(response.params["then"])
         migrateResponses(response.params["else"])
      end

      if response.behaviorId then
         local behavior = self.game.behaviors[response.behaviorId]
         local responseBp = behavior.responses[response.name]
         if responseBp.migrate then
            responseBp.migrate(behavior, component.actorId, response)
         end
      end
   end
   
   for _, rule in ipairs(result) do
      migrateResponses(rule.response)
   end
   return result
end

function RulesBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rules = self:migrateLegacy(component, bp.rules or {EMPTY_RULE})
    self.setters.rules(self, component, component.properties.rules)
end

function RulesBehavior.handlers:preRemoveComponent(component, opts)
    if opts.removeActor then
        self:fireTrigger("destroy", component.actorId)
    end
end

function RulesBehavior.handlers:blueprintComponent(component, bp)
    bp.rules = util.deepCopyTable(component.properties.rules)
end

function RulesBehavior.handlers.componentHasTrigger(component, triggerName)
   return component._rulesByTriggerName[triggerName] ~= nil
end

function RulesBehavior:_checkResponseReferencesBehavior(response, behavior)
   if not response then return false end
   
   if response.params then
      if self:_checkResponseReferencesBehavior(response.params.nextResponse, behavior) then
         return true
      end
      if self:_checkResponseReferencesBehavior(response.params.body, behavior) then
         return true
      end
      if self:_checkResponseReferencesBehavior(response.params["then"], behavior) then
         return true
      end
      if self:_checkResponseReferencesBehavior(response.params["else"], behavior) then
         return true
      end
   end

   if response.behaviorId == behavior.behaviorId then
      return true
   elseif response.name == 'set behavior property' and response.params and respone.params.behaviorId == behavior.behaviorId then
      return true
   elseif response.name == 'change behavior property' and response.params and response.params.behaviorId == behavior.behaviorId then
      return true
   end
   return false
end

function RulesBehavior:componentReferencesBehavior(component, behavior)
   for _, rule in ipairs(component.properties.rules) do
      if rule.trigger and rule.trigger.behaviorId == behavior.behaviorId then
         return true, 'trigger'
      end
      if self:_checkResponseReferencesBehavior(
         rule.response,
         behavior
      ) then
         return true, 'response'
      end
   end
   return false
end

-- Setters

function RulesBehavior.setters:rules(component, newRules)
    component.properties.rules = newRules

    -- Rules changed, so clear coroutines
    self._coroutines[component.actorId] = nil

    -- Update rules index
    component._rulesByTriggerName = {}
    for _, rule in ipairs(component.properties.rules) do
        if rule.trigger.name ~= "none" then
            if not component._rulesByTriggerName[rule.trigger.name] then
                component._rulesByTriggerName[rule.trigger.name] = {}
            end
            table.insert(component._rulesByTriggerName[rule.trigger.name], rule)
        end
    end
end

-- Trigger handler

function RulesBehavior.handlers:trigger(triggerName, actorId, context, opts)
    opts = opts or {}

    local filter = opts.filter
    local threadKey = opts.threadKey

    local applies = false

    local component = self.components[actorId]
    if component then
        context = context or {}

        if context.isOwner == nil then
            -- By default, based on actor's ownership
            context.isOwner = self.game.behaviorsByName.Body:isOwner(actorId)
        end

        local rulesToRun = component._rulesByTriggerName[triggerName]
        if rulesToRun then
            for _, ruleToRun in ipairs(rulesToRun) do
                if not filter or filter(ruleToRun.trigger.params) then
                    applies = true
                    if not self._coroutines[actorId] then
                        self._coroutines[actorId] = {}
                    end
                    self._coroutines[actorId][threadKey or ruleToRun] =
                        coroutine.create(
                        function()
                            self:runResponse(ruleToRun.response, actorId, context)
                        end
                    )
                end
            end
        end
    end

    return applies
end

-- Methods

function RulesBehavior:runResponse(response, actorId, context)
    if response and response.behaviorId and response.name ~= "none" then
        local behavior = self.game.behaviors[response.behaviorId]
        if behavior then
            local responseEntry = behavior.responses[response.name]
            if responseEntry then
                local result = responseEntry.run(behavior, actorId, response.params, context)
                if responseEntry.returnType ~= nil then
                    return result
                else
                    self:runResponse(response.params.nextResponse, actorId, context)
                end
            end
        end
    end
end

-- Variables triggers

RulesBehavior.triggers["variable reaches value"] = {
    description = "When a variable reaches a value",
    category = "state",
    paramSpecs = {
       variableId = {
          label = "variable",
          method = "dropdown",
          initialValue = "(none)",
          props = {
             showVariablesItems = true,
          },
       },
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
        variableId = "(none)",
        comparison = "equal",
        value = 0
    },
}

RulesBehavior.triggers["variable changes"] = {
    description = "When a variable changes",
    category = "state",
    paramSpecs = {
       variableId = {
          label = "variable",
          method = "dropdown",
          initialValue = "(none)",
          props = {
             showVariablesItems = true,
          },
       },
    },
    initialParams = {
        variableId = "(none)"
    },
}

-- Variables responses

RulesBehavior.responses["change variable"] = {
    description = "Adjust the value of a variable",
    category = "state",
    paramSpecs = {
       changeBy = {
          label = "adjust by",
          method = "numberInput",
          initialValue = 1,
       },
       variableId = {
          label = "variable",
          method = "dropdown",
          initialValue = "(none)",
          props = {
             showVariablesItems = true,
          },
       },
    },
    initialParams = {
        changeBy = 1,
        variableId = nil
    },
    run = function(self, actorId, params, context)
        -- self.game:send('updateVariables

        -- MULTIPLAYER TODO: figure out who should own variables
        --if context.isOwner then -- Only owning host should fire variable updates
        local component = self.components[actorId]
        if component and self.game.performing then
            self.game:variableChangeByValue(params.variableId, params.changeBy)
        end
        --end
    end
}

RulesBehavior.responses["set variable"] = {
    description = 'Set a variable to a value',
    category = "state",
    paramSpecs = {
       variableId = {
          label = "variable",
          method = "dropdown",
          initialValue = "(none)",
          props = {
             showVariablesItems = true,
          },
       },
       setToValue = {
          label = "set to value",
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        setToValue = 0,
        variableId = nil
    },
    run = function(self, actorId, params, context)
        -- MULTIPLAYER TODO: figure out who should own variables
        --if context.isOwner then
        local component = self.components[actorId]
        if component and self.game.performing then
            self.game:variableSetToValue(params.variableId, params.setToValue)
        end
        --end
    end
}

RulesBehavior.responses["variable meets condition"] = {
    description = 'If a variable meets a condition',
    category = "state",
    returnType = "boolean",
    paramSpecs = {
       variableId = {
          label = "variable",
          method = "dropdown",
          initialValue = "(none)",
          props = {
             showVariablesItems = true,
          },
       },
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
        variableId = "(none)",
        comparison = "equal",
        value = 0
    },
    run = function(self, actorId, params, context)
        local value = self.game:variableIdToValue(params.variableId)
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

-- Lifetime triggers

RulesBehavior.triggers.create = {
    description = "When this is created",
    category = "general"
}

RulesBehavior.triggers.destroy = {
    description = "When this is destroyed",
    category = "general"
}

-- Lifetime responses

RulesBehavior.responses.create = {
    description = "Create a new actor",
    category = "general",
    paramSpecs = {
       entryId = {
          label = "blueprint to create",
          method = "blueprint",
          initialValue = nil,
       },
       xOffset = {
          label = "relative x position",
          method = "numberInput",
          initialValue = 0,
       },
       yOffset = {
          label = "relative y position",
          method = "numberInput",
          initialValue = 0,
       },
    },
    initialParams = {
        xOffset = 0,
        yOffset = 0,
        entryId = nil
    },
    run = function(self, actorId, params, context)
        local entry = self.game.library[params.entryId]
        if entry then
            local x = 0
            local y = 0
            local members = self.game.behaviorsByName.Body:getMembers(actorId)
            if members.bodyId and members.body and context.isOwner then
                x, y = members.body:getPosition()
            elseif context.x and context.y and context.isOwner then
                x, y = context.x, context.y -- Actor was destroyed but left a position in `context`
            end

            if x and y then
                local bp = util.deepCopyTable(entry.actorBlueprint)
                if bp.components.Body then
                    bp.components.Body.x = x + params.xOffset
                    bp.components.Body.y = y + params.yOffset
                end
                local newActorId = self.game:generateActorId()
                self.game:sendAddActor(
                    bp,
                    {
                        actorId = self.game:generateActorId(),
                        parentEntryId = entry.entryId
                    }
                )
            end
        end
    end
}

RulesBehavior.responses.destroy = {
    description = "Destroy this actor",
    category = "general",
    run = function(self, actorId, params, context)
        if self.game.actors[actorId] then
            local members = self.game.behaviorsByName.Body:getMembers(actorId)
            if members.bodyId and members.body then
                -- Save a few things in `context` for use in responses after 'wait's
                context.x, context.y = members.body:getPosition()
            end
            self:onEndOfFrame(
                function()
                    self.game:send("removeActor", self.clientId, actorId, {soft = true})
                end
            )
        end
    end
}

-- Scene responses

RulesBehavior.responses["restart scene"] = {
    description = "Restart this card",
    category = "general",
    run = function(self, actorId, params, context)
        self.game:restartScene()
    end
}

-- Timing responses

RulesBehavior.responses.wait = {
    description = "Wait before a response",
    autoNext = false,
    category = "logic",
    paramSpecs = {
       duration = {
          label = "duration (seconds)",
          method = "numberInput",
          initialValue = 1,
          props = {
             min = 0,
             max = 30,
             step = 0.2,
          },
       },
    },
    initialParams = {
        duration = 1
    },
    run = function(self, actorId, params, context)
        local timeLeft = params.duration
        while timeLeft > 0 do
            timeLeft = timeLeft - coroutine.yield()
        end
    end
}

-- Logic responses

RulesBehavior.responses["set behavior property"] = {
   description = "Set a behavior",
   category = "general",
   paramSpecs = {
      behaviorId = {
         label = "behavior",
         method = "dropdown",
         initialValue = nil,
      },
      propertyName = {
         label = "parameter",
         method = "dropdown",
         initialValue = nil,
      },
      value = {
         method = "numberInput",
         label = "set to",
         initialValue = 0,
      },
   },
   initialParams = {
      behaviorId = nil,
      propertyName = nil,
      value= 0,
   },
   run = function(self, actorId, params, context)
      local behavior = self.game.behaviors[params.behaviorId]
      behavior:sendSetProperties(actorId, params.propertyName, params.value)
   end
}

RulesBehavior.responses["change behavior property"] = {
   description = "Adjust a behavior",
   category = "general",
   paramSpecs = {
      behaviorId = {
         label = "behavior",
         method = "dropdown",
         initialValue = nil,
      },
      propertyName = {
         label = "parameter",
         method = "dropdown",
         initialValue = nil,
      },
      value = {
         method = "numberInput",
         label = "adjust by",
         initialValue = 0,
      },
   },
   initialParams = {
      behaviorId = nil,
      propertyName = nil,
      value = 0,
   },
   run = function(self, actorId, params, context)
      local behavior = self.game.behaviors[params.behaviorId]
      local component = behavior.components[actorId]
      local oldValue
      if behavior.getters[params.propertyName] then
         oldValue = behavior.getters[params.propertyName](behavior, component)
      else
         oldValue = component.properties[params.propertyName]
      end
      local newValue = oldValue + params.value
      local propertySpec = behavior.propertySpecs[params.propertyName]
      if propertySpec.props then
         if propertySpec.props.min and newValue < propertySpec.props.min then
            newValue = propertySpec.props.min
         end
         if propertySpec.props.max and newValue > propertySpec.props.max then
            newValue = propertySpec.props.max
         end
      end
      behavior:sendSetProperties(actorId, params.propertyName, newValue)
   end
}

RulesBehavior.responses["if"] = {
    description = "Condition a response",
    category = "logic",
    run = function(self, actorId, params, context)
        if self:runResponse(params["condition"], actorId, context) then
            self:runResponse(params["then"], actorId, context)
        else
            self:runResponse(params["else"], actorId, context)
        end
    end
}

RulesBehavior.responses["repeat"] = {
    description = "Repeat a response",
    category = "logic",
    paramSpecs = {
       count = {
          label = "repetitions",
          method = "numberInput",
          initialValue = 3,
          props = {
             min = 0,
             step = 1,
          },
       },
    },
    initialParams = {
        count = 3
    },
    run = function(self, actorId, params, context)
        for i = 1, params.count do
            self:runResponse(params["body"], actorId, context)
        end
    end
}

RulesBehavior.responses["act on"] = {
    description = "Act on any actor with a specific tag",
    category = "interaction",
    paramSpecs = {
       tag = {
          method = "textInput",
       },
    },
    run = function(self, actorId, params, context)
        if params.tag and params.tag ~= '' then
            self.game.behaviorsByName.Tags:forEachActorWithTag(
                params.tag,
                function(otherActorId)
                    self:runResponse(params["body"], otherActorId, context)
                end
            )
        end
    end
}

RulesBehavior.responses["act on other"] = {
    description = "Act on the other actor this collided with",
    category = "interaction",
    triggerFilter = {collide = true},
    run = function(self, actorId, params, context)
        if context.otherActorId then
            self:runResponse(params["body"], context.otherActorId, context)
        end
    end
}

-- Random responses

RulesBehavior.responses["coin flip"] = {
    description = "If a coin flip shows heads",
    category = "random",
    returnType = "boolean",
    paramSpecs = {
       probability = {
          label = "probability of heads",
          method = "numberInput",
          initialValue = 0.5,
          props = {
             min = 0,
             max = 1,
             step = 0.1,
          },
       },
    },
    initialParams = {
        probability = 0.5
    },
    run = function(self, actorId, params, context)
        return math.random() < params.probability
    end
}

-- Performance

function RulesBehavior.handlers:postPerform(dt)
    -- Lazily fire 'create' triggers
    for actorId, component in pairs(self.components) do
        if not component._triggeredCreate then
            component._triggeredCreate = true
            self:fireTrigger("create", component.actorId)
        end
    end

    -- Resume coroutines
    for actorId, coros in pairs(self._coroutines) do
        for threadKey, coro in pairs(coros) do
            local succeeded, err = coroutine.resume(coro, dt)
            if not succeeded then
                print("rule error: ", err)
            end
            if coroutine.status(coro) == "dead" then
                coros[threadKey] = nil
            end
        end
        if not next(coros) then
            self._coroutines[actorId] = nil
        end
    end
end

function RulesBehavior.handlers:setPerforming(newPerforming)
    -- Clear coroutines when performance mode changes
    self._coroutines = {}
    self.game:variablesReset()
end

function RulesBehavior.handlers:clearScene()
    -- Clear coroutines when scene is cleared
    self._coroutines = {}
    self.game:variablesReset()
end

-- Rule management

-- get all the triggers or responses for the given behaviorIds,
-- possibly filtered by props
function RulesBehavior:getRuleEntries(kind, behaviorIds, props)
    props = props or {}
    local categories = {}
    for behaviorId in pairs(behaviorIds) do
        local behavior = self.game.behaviors[behaviorId]
        local behaviorUiName = behavior:getUiName()
        for name, entry in pairs(behavior[kind .. "s"]) do
            if
                (entry.returnType == props.returnType and
                    not entry.migrate and
                    (not entry.triggerFilter or
                        props.triggerFilter == "all" or
                        entry.triggerFilter[props.triggerName]))
             then
                local categoryName = entry.category or behaviorUiName
                if not categories[categoryName] then
                    categories[categoryName] = {}
                end
                table.insert(
                    categories[categoryName],
                    {
                        name = name,
                        behaviorId = behaviorId,
                        behaviorName = behavior.name,
                        category = categoryName,
                        entry = entry
                    }
                )
            end
        end
    end
    return categories
end

function RulesBehavior:addRule(actorId, component)
   self:changeRules(
      actorId, component,
      function()
         table.insert(component.properties.rules, util.deepCopyTable(EMPTY_RULE))
      end,
      'add new rule',
      false
   )
end

function RulesBehavior:changeRules(actorId, component, changeRulesFunc, description, shouldCoalesce)
   description = description or ''
   local oldRules = util.deepCopyTable(component.properties.rules)
   changeRulesFunc(actorId, component)
   local newRules = util.deepCopyTable(component.properties.rules)
   self:command(
      description,
      {
         coalesceLast = false,
         params = {"oldRules", "newRules"},
         coalesceSuffix = shouldCoalesce and description or nil,
      },
      function()
         self:sendSetProperties(actorId, "rules", newRules)
      end,
      function()
         self:sendSetProperties(actorId, "rules", oldRules)
      end
   )
end
