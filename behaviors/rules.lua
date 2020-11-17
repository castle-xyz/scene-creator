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
    self._stopRepeatingIds = {}
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
end

function RulesBehavior.handlers:enableComponent(component, opts)
   self.setters.rules(self, component, component.properties.rules)
end

function RulesBehavior.handlers:preRemoveActor(component, opts)
   self:fireTrigger("destroy", component.actorId)
end

function RulesBehavior.handlers:blueprintComponent(component, bp)
    bp.rules = util.deepCopyTable(component.properties.rules)
end

function RulesBehavior.handlers.componentHasTrigger(component, triggerName)
   return component._rulesByTriggerName[triggerName] ~= nil
end

-- TODO: might want to specify this in the trigger config instead
local interactiveTriggers = {
   'tap',
   'press',
}
function RulesBehavior.getters:isInteractive(component)
   for _, triggerName in ipairs(interactiveTriggers) do
      if self.handlers.componentHasTrigger(component, triggerName) then
         return true
      end
   end
   return false
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
   elseif response.name == 'set behavior property' and response.params and response.params.behaviorId == behavior.behaviorId then
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
                end
                self:runResponse(response.params.nextResponse, actorId, context)
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
}

-- Variables responses

RulesBehavior.responses["reset variable"] = {
    description = "Reset a variable to its initial value",
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
    run = function(self, actorId, params)
       self.game:variableReset(params.variableId)
    end
}

RulesBehavior.responses["reset all variables"] = {
   description = "Reset all variables to their initial values",
   category = "state",
   run = function(self, actorId, params)
      self.game:variableResetAll()
   end
}

RulesBehavior.responses["change variable"] = {
    description = "Adjust the value of a variable (legacy)",
    isDeprecated = true,
    migrate = function(self, actorId, response)
       response.name = "set variable"

       response.params.relative = true
       response.params.setToValue = response.params.changeBy
       response.params.changeBy = nil
    end,
    run = function(self, actorId, params, context)
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
    description = "Modify the value of a variable",
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
       relative = {
          method = "toggle",
          label = "relative",
          initialValue = false,
       },
    },
    run = function(self, actorId, params, context)
        local component = self.components[actorId]
        if component and self.game.performing then
            if params.relative then
                self.game:variableChangeByValue(params.variableId, params.setToValue)
            else
                self.game:variableSetToValue(params.variableId, params.setToValue)
            end
        end
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
    description = "Create a new actor from blueprint",
    migrate = function(self, actorId, response)
      if response.params.coordinateSystem == "position" then
         response.params.coordinateSystem = "relative position"
      elseif response.params.coordinateSystem == "angle and distance" then
         response.params.coordinateSystem = "relative angle and distance"
      end
    end,
    category = "general",
    paramSpecs = {
       entryId = {
          label = "blueprint to create",
          method = "blueprint",
          initialValue = nil,
       },
       coordinateSystem = {
          label = "coordinate system",
          method = "dropdown",
          initialValue = "relative position",
          props = {
             items = {
                "relative position",
                "relative angle and distance",
                "absolute position",
             },
          },
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
       xAbsolute = {
         label = "absolute x position",
         method = "numberInput",
         initialValue = 0,
      },
      yAbsolute = {
         label = "absolute y position",
         method = "numberInput",
         initialValue = 0,
      },
       angle = {
          label = "angle (degrees)",
          method = "numberInput",
          initialValue = 0,
       },
       distance = {
          label = "distance",
          method = "numberInput",
          initialValue = 0,
       },
       depth = {
          label = "depth",
          method = "dropdown",
          initialValue = "in front of all actors",
          props = {
             items = {
                "behind all actors",
                "behind this actor",
                "in front of this actor",
                "in front of all actors",
             },
          },
       },
    },
    validate = function(self, actorId, params)
       local entry = self.game.library[params.entryId]
       if not entry then
          -- nonexistent blueprint?
          params.entryId = nil
       end
    end,
    run = function(self, actorId, params, context)
        local entry = self.game.library[params.entryId]
        if entry then
            local x, y, a = 0, 0, 0
            local members = self.game.behaviorsByName.Body:getMembers(actorId)
            if members.bodyId and members.body and context.isOwner then
                x, y = members.body:getPosition()
                a = members.body:getAngle()
            elseif context.x and context.y and context.isOwner then
                x, y, a = context.x, context.y, context.a -- Actor was destroyed but left a position in `context`
            end

            if x and y then
                local bp = util.deepCopyTable(entry.actorBlueprint)
                if bp.components.Body then
                   local coordinateSystem = params.coordinateSystem or "relative position"
                   if coordinateSystem == "relative position" then
                      bp.components.Body.x = x + params.xOffset
                      bp.components.Body.y = y + params.yOffset
                   elseif coordinateSystem == "relative angle and distance" then
                      local angle, distance = math.rad(params.angle or 0) + a, params.distance or 0
                      bp.components.Body.x = x + distance * math.cos(angle)
                      bp.components.Body.y = y + distance * math.sin(angle)
                  else
                     bp.components.Body.x = params.xAbsolute
                     bp.components.Body.y = params.yAbsolute
                  end
                end
                local newActorId = self.game:generateActorId()

                local drawOrder = nil
                if params.depth == "behind all actors" then
                   drawOrder = 1
                elseif params.depth == "behind this actor" then
                   drawOrder = self.game.actors[actorId].drawOrder
                elseif params.depth == "in front of this actor" then
                   drawOrder = self.game.actors[actorId].drawOrder + 1
                end

                self.game:sendAddActor(
                    bp,
                    {
                        actorId = self.game:generateActorId(),
                        parentEntryId = entry.entryId,
                        drawOrder = drawOrder,
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
                context.a = members.body:getAngle()
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
             min = 0.0625,
             max = 30,
             step = 0.1,
             decimalDigits = 4,
          },
       },
    },
    run = function(self, actorId, params, context)
        local timeLeft = self.game:evalExpression(
           params.duration,
           self.responses["wait"].paramSpecs.duration
        )
        while timeLeft > 0 do
            timeLeft = timeLeft - coroutine.yield()
        end
    end
}

-- Logic responses

RulesBehavior.responses["set behavior property"] = {
   description = "Modify a behavior property",
   category = "behavior",
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
      relative = {
         method = "toggle",
         label = "relative",
         initialValue = false,
      },
   },
   validate = function(self, actorId, params)
      if params.behaviorId == nil or params.propertyName == nil then
         return response
      end
      local behavior = self.game.behaviors[params.behaviorId]
      local component = behavior.components[actorId]
      if component == nil then
         params.behaviorId = nil
         params.propertyName = nil
         params.value = 0
      end
   end,
   run = function(self, actorId, params, context)
      if params.behaviorId == nil or params.propertyName == nil then
         -- incomplete rule
         return
      end
      local behavior = self.game.behaviors[params.behaviorId]
      local component = behavior.components[actorId]
      if component == nil then
         -- actor doesn't have this behavior (possibly removed)
         return
      end

      local newValue
      if params.relative then
         local oldValue
         if behavior.getters[params.propertyName] then
            oldValue = behavior.getters[params.propertyName](behavior, component)
         else
            oldValue = component.properties[params.propertyName]
         end
         newValue = oldValue + self.game:evalExpression(params.value)
      else
         -- absolute
         newValue = self.game:evalExpression(params.value)
      end

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

RulesBehavior.responses["change behavior property"] = {
   description = "Adjust a behavior property (legacy)",
   isDeprecated = true,
   migrate = function(self, actorId, response)
       response.name = "set behavior property"

       -- keep all params the same, except enable relative flag
       response.params.relative = true
   end,
   run = function(self, actorId, params, context)
      if params.behaviorId == nil or params.propertyName == nil then
         -- incomplete rule
         return
      end
      local behavior = self.game.behaviors[params.behaviorId]
      local component = behavior.components[actorId]
      if component == nil then
         -- actor doesn't have this behavior (possibly removed)
         return
      end
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

RulesBehavior.responses["disable behavior"] = {
   description = "Disable a behavior",
   category = "behavior",
   paramSpecs = {
      behaviorId = {
         label = "behavior",
         method = "dropdown",
         initialValue = nil,
      },
   },
   validate = function(self, actorId, params)
      if params.behaviorId ~= nil then
         local behavior = self.game.behaviors[params.behaviorId]
         local component = behavior.components[actorId]
         if component == nil then
            params.behaviorId = nil
         end
      end
   end,
   run = function(self, actorId, params, context)
      if params.behaviorId ~= nil then
         self.game:send("disableComponent", self.clientId, actorId, params.behaviorId)
      end
   end
}

RulesBehavior.responses["enable behavior"] = {
   description = "Enable a behavior",
   category = "behavior",
   paramSpecs = {
      behaviorId = {
         label = "behavior",
         method = "dropdown",
         initialValue = nil,
      },
   },
   validate = function(self, actorId, params)
      if params.behaviorId ~= nil then
         local behavior = self.game.behaviors[params.behaviorId]
         local component = behavior.components[actorId]
         if component == nil then
            params.behaviorId = nil
         end
      end
   end,
   run = function(self, actorId, params, context)
      if params.behaviorId ~= nil then
         self.game:send("enableComponent", self.clientId, actorId, params.behaviorId)
      end
   end
}

RulesBehavior.responses["if"] = {
    description = "If a condition is met, run a response",
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
    description = "Repeat N times",
    category = "logic",
    paramSpecs = {
       count = {
          label = "repetitions",
          method = "numberInput",
          initialValue = 3,
          props = {
             min = 0,
             step = 1,
             discrete = true,
          },
       },
    },
    run = function(self, actorId, params, context)
       local count = self.game:evalExpression(
          params.count,
          self.responses["repeat"].paramSpecs.count
       )
       for i = 1, count do
          self:runResponse(params["body"], actorId, context)

          if self._stopRepeatingIds[actorId] and self._stopRepeatingIds[actorId][self._currentThreadKey] then
            self._stopRepeatingIds[actorId][self._currentThreadKey] = false
            return
          end

          -- yield every 5 repeats
          if math.fmod(i, 5) < 1 then
            coroutine.yield()
          end

          local members = self.game.behaviorsByName.Body:getMembers(actorId)
          if not (members.bodyId and members.body) then
             -- actor was destroyed, abandon remaining iterations
             break
          end
        end
    end
}

RulesBehavior.responses["infinite repeat"] = {
   description = "Repeat every N seconds",
   category = "logic",
   paramSpecs = {
      interval = {
         label = "interval (seconds)",
         method = "numberInput",
         initialValue = 1,
         expression = false, -- temporally ambiguous what this would mean
         props = {
            min = 0.0625,
            max = 30,
            step = 0.1,
            decimalDigits = 4,
         },
      },
   },
   run = function(self, actorId, params, context)
      while true do
         self:runResponse(params["body"], actorId, context)

         if self._stopRepeatingIds[actorId] and self._stopRepeatingIds[actorId][self._currentThreadKey] then
            self._stopRepeatingIds[actorId][self._currentThreadKey] = false
            return
         end

         local timeLeft = params.interval
         while timeLeft > 0 do
               timeLeft = timeLeft - coroutine.yield()
         end

         local members = self.game.behaviorsByName.Body:getMembers(actorId)
         if not (members.bodyId and members.body) then
            -- actor was destroyed, abandon remaining iterations
            break
         end
       end
   end
}

RulesBehavior.responses["stop repeating"] = {
   description = "Stop repeating",
   category = "logic",
   parentTypeFilter = {["repeat"] = true},
   run = function(self, actorId, params, context)
      if not self._stopRepeatingIds[actorId] then
         self._stopRepeatingIds[actorId] = {}
      end

      self._stopRepeatingIds[actorId][self._currentThreadKey] = true
   end
}

RulesBehavior.responses["act on"] = {
    description = "Tell actors with tag to perform a response",
    category = "tell other actors",
    paramSpecs = {
       tag = {
          method = "tagPicker",
          props = { singleSelect = true },
       },
    },
    run = function(self, actorId, params, context)
        if params.tag and params.tag ~= '' then
            self.game:cameraBeginActOn()
            self.game.behaviorsByName.Tags:forEachActorWithTag(
                params.tag,
                function(otherActorId)
                    self:runResponse(params["body"], otherActorId, context)
                end
            )
            self.game:cameraEndActOn()
        end
    end
}

RulesBehavior.responses["act on other"] = {
    description = "Tell the colliding actor to perform a response",
    category = "tell other actors",
    triggerFilter = {collide = true},
    run = function(self, actorId, params, context)
        if context.otherActorId then
            self:runResponse(params["body"], context.otherActorId, context)
        end
    end
}

-- Sound

RulesBehavior.responses["play sound"] = {
   description = "Play a sound",
   category = "sound",
   paramSpecs = {
      -- sfxr randomization category last used to generate the sound
      category = {
         label = "category",
         method = "dropdown",
         initialValue = "random",
         props = {
            items = {
               "pickup",
               "laser",
               "explosion",
               "powerup",
               "hit",
               "jump",
               "blip",
               "random",
            },
         },
      },
      -- seed passed to sfxr randomizer
      seed = {
         method = "numberInput",
         label = "random seed",
         initialValue = 1337,
         props = {
            min = 0,
         },
      },
      -- if nonzero, mutate the sound once by [seed + mutationSeed]
      mutationSeed = {
         method = "numberInput",
         label = "mutation seed",
         initialValue = 0,
      },
      -- magnitude passed to sfxr mutation call (if applicable)
      mutationAmount = {
         method = "numberInput",
         label = "mutation amount",
         initialValue = 5,
         props = {
            min = 0,
            max = 20,
         },
      },
   },
   run = function(self, actorId, params, context)
      self.game:playSound(params)
   end,
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
    run = function(self, actorId, params, context)
        return math.random() < params.probability
    end
}

-- Camera responses

RulesBehavior.responses["follow with camera"] = {
   description = "Follow this with the camera",
   category = "camera",
   run = function(self, actorId, params, context)
       self.game:cameraAttachToActorId(actorId)
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
            self._currentThreadKey = threadKey
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

function RulesBehavior.handlers:clearScene(paused)
    -- Clear coroutines when scene is cleared
    self._coroutines = {}
    if not paused then
        self.game:variablesReset()
    end
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
                    not entry.isDeprecated and
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

-- Rules clipboard

function RulesBehavior:isClipboardEmpty()
   return self.clipboard == nil
      or self.clipboard.rules == nil
      or #self.clipboard.rules == 0
end

function RulesBehavior:copyRules(component, rules)
   -- make a deep copy snapshot in case the original is modified or deleted before we paste
   -- TODO: does this work? do any rules reference actors etc.?
   self.clipboard = self.clipboard or {}
   self.clipboard.rules = util.deepCopyTable(rules)
end

function RulesBehavior:pasteRules(component, rules)
   rules = rules or self.clipboard.rules
   self:changeRules(
      component.actorId, component,
      function()
         for _, rule in ipairs(rules) do
            local ruleToInsert = {}
            ruleToInsert.trigger = self:validateTriggerForActor(component.actorId, util.deepCopyTable(rule.trigger))
            ruleToInsert.response = self:validateResponseForActor(component.actorId, util.deepCopyTable(rule.response))
            table.insert(component.properties.rules, ruleToInsert)
         end
      end,
      #rules == 1 and 'paste rule' or 'paste rules',
      false
   )
end

function RulesBehavior:validateTriggerForActor(actorId, trigger)
   local triggerBehavior = self.game.behaviors[trigger.behaviorId]
   if triggerBehavior.components[actorId] ~= nil then
      -- target actor has the needed behavior for this trigger,
      -- now validate the trigger's params
      if triggerBehavior.triggers[trigger.name].validate then
         triggerBehavior.triggers[trigger.name].validate(
            triggerBehavior,
            actorId,
            trigger.params
         )
      end
      return trigger
   end
   -- target actor doesn't have the needed behavior for this trigger
   return util.deepCopyTable(EMPTY_RULE.trigger)
end

function RulesBehavior:validateResponseForActor(actorId, response)
   if not response then return nil end

   local responseBehavior = self.game.behaviors[response.behaviorId]
   if responseBehavior.components[actorId] ~= nil then
      -- target actor has the needed behavior for this response,
      -- now validate the response's params
      if responseBehavior.responses[response.name].validate then
         responseBehavior.responses[response.name].validate(
            responseBehavior,
            actorId,
            response.params
         )
      end
      response.params.nextResponse = self:validateResponseForActor(actorId, response.params.nextResponse)
      response.params.body = self:validateResponseForActor(actorId, response.params.body)
      response.params["then"] = self:validateResponseForActor(actorId, response.params["then"])
      response.params["else"] = self:validateResponseForActor(actorid, response.params["else"])
      return response
   else
      -- target actor doesn't have the behavior for this response, delete it and move to next
      return self:validateResponseForActor(actorId, response.params.nextResponse)
   end
end
