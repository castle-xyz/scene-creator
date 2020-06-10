local RulesBehavior =
    defineCoreBehavior {
    name = "Rules",
    displayName = "rules",
    propertyNames = {
        "rules"
    },
    dependencies = {},
    propertySpecs = {
       rules = {
          method = 'data' -- TODO: basically never try to render this without custom ui
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

function RulesBehavior.handlers:addComponent(component, bp, opts)
    component.properties.rules = util.deepCopyTable(bp.rules or {EMPTY_RULE})
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
    description = [[
Triggered when a variable reaches a given value.
    ]],
    category = "variable",
    initialParams = {
        variableId = "(none)",
        comparison = "equal",
        value = 0
    },
    uiBody = function(self, params, onChangeParam)
        ui.dropdown(
            "variable",
            self.game:variableIdToName(params.variableId),
            self.game:variablesNames(),
            {
                onChange = function(newVariableName)
                    onChangeParam("change variable id", "variableId", self.game:variableNameToId(newVariableName))
                end
            }
        )

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

RulesBehavior.triggers["variable changes"] = {
    description = [[
Triggered when a variable changes.
    ]],
    category = "variable",
    initialParams = {
        variableId = "(none)"
    },
    uiBody = function(self, params, onChangeParam)
        util.uiRow(
            "the row",
            function()
                ui.dropdown(
                    "variable",
                    self.game:variableIdToName(params.variableId),
                    self.game:variablesNames(),
                    {
                        onChange = function(newVariableName)
                            onChangeParam(
                                "change variable id",
                                "variableId",
                                self.game:variableNameToId(newVariableName)
                            )
                        end
                    }
                )
            end
        )
    end
}

-- Variables responses

RulesBehavior.responses["change variable"] = {
    description = [[
Changes a variable by the given value. A **positive value increments** the variable, while a **negative value decrements** it.
    ]],
    category = "variable",
    initialParams = {
        changeBy = 1,
        variableId = nil
    },
    uiBody = function(self, params, onChangeParam)
        ui.dropdown(
            "variable",
            self.game:variableIdToName(params.variableId),
            self.game:variablesNames(),
            {
                onChange = function(newVariableName)
                    onChangeParam("change variable id", "variableId", self.game:variableNameToId(newVariableName))
                end
            }
        )
        ui.numberInput(
            "change by",
            params.changeBy,
            {
                step = 1,
                onChange = function(newChangeBy)
                    onChangeParam("set variable change by", "changeBy", newChangeBy)
                end
            }
        )
    end,
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
    description = [[
**Directly sets** a variable to the given value.
    ]],
    category = "variable",
    initialParams = {
        setToValue = 0,
        variableId = nil
    },
    uiBody = function(self, params, onChangeParam)
        ui.dropdown(
            "variable",
            self.game:variableIdToName(params.variableId),
            self.game:variablesNames(),
            {
                onChange = function(newVariableName)
                    onChangeParam("change variable id", "variableId", self.game:variableNameToId(newVariableName))
                end
            }
        )
        ui.numberInput(
            "set to value",
            params.setToValue,
            {
                step = 1,
                onChange = function(newSetToValue)
                    onChangeParam("change set variable value", "setToValue", newSetToValue)
                end
            }
        )
    end,
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
    description = [[
Returns true if the variable meets the condition.
    ]],
    category = "variable",
    returnType = "boolean",
    initialParams = {
        variableId = "(none)",
        comparison = "equal",
        value = 0
    },
    uiBody = function(self, params, onChangeParam)
        ui.dropdown(
            "variable",
            self.game:variableIdToName(params.variableId),
            self.game:variablesNames(),
            {
                onChange = function(newVariableName)
                    onChangeParam("change variable id", "variableId", self.game:variableNameToId(newVariableName))
                end
            }
        )

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
    description = [[
Triggered when the **actor is created**. If the actor is already present when the scene starts, this is triggered when the scene starts.
    ]],
    category = "lifetime"
}

RulesBehavior.triggers.destroy = {
    description = [[
Triggered when the actor is **removed from the scene**.
    ]],
    category = "lifetime"
}

-- Lifetime responses

RulesBehavior.responses.create = {
    description = [[
**Adds a new actor** to the scene, based on a selected **blueprint**. The new actor can be placed at an offset position from the actor creating it.
    ]],
    category = "lifetime",
    initialParams = {
        xOffset = 0,
        yOffset = 0,
        entryId = nil
    },
    uiBody = function(self, params, onChangeParam)
        -- Entry box
        local entry = self.game.library[params.entryId]
        if entry then
            ui.box(
                "blueprint preview",
                {
                    borderWidth = 1,
                    borderColor = "#292929",
                    borderRadius = 4,
                    padding = 4,
                    margin = 4,
                    marginBottom = 8,
                    flexDirection = "row",
                    alignItems = "center"
                },
                function()
                    -- Figure out image based on type
                    local imageUrl
                    if entry.entryType == "actorBlueprint" then
                        local actorBp = entry.actorBlueprint
                        if actorBp.components.Image and actorBp.components.Image.url then
                            imageUrl = actorBp.components.Image.url
                        end
                        if actorBp.components.Drawing and actorBp.components.Drawing.url then
                            imageUrl = actorBp.components.Drawing.url
                        end
                    end
                    if imageUrl then
                        ui.box(
                            "image container",
                            {
                                width = "28%",
                                aspectRatio = 1,
                                margin = 4,
                                marginLeft = 8,
                                backgroundColor = "white"
                            },
                            function()
                                ui.image(CHECKERBOARD_IMAGE_URL, {flex = 1, margin = 0})

                                ui.image(
                                    imageUrl,
                                    {
                                        position = "absolute",
                                        left = 0,
                                        top = 0,
                                        bottom = 0,
                                        right = 0,
                                        margin = 0
                                    }
                                )
                            end
                        )

                        ui.box(
                            "spacer",
                            {width = 8},
                            function()
                            end
                        )
                    end

                    ui.box(
                        "text buttons",
                        {flex = 1},
                        function()
                            -- Title, short description
                            ui.markdown("## " .. entry.title .. "\n" .. (entry.description or ""))
                        end
                    )
                end
            )
        end

        ui.button(
            (entry and "change" or "choose") .. " blueprint",
            {
                icon = "book",
                iconFamily = "FontAwesome",
                popoverAllowed = true,
                popoverStyle = {width = 300, height = 300},
                popover = function(closePopover)
                    self.game:uiLibrary(
                        {
                            id = "create actor response",
                            filterType = "actorBlueprint",
                            buttons = function(entry)
                                ui.button(
                                    "use",
                                    {
                                        flex = 1,
                                        icon = "plus",
                                        iconFamily = "FontAwesome5",
                                        onClick = function()
                                            closePopover()

                                            onChangeParam("change create blueprint", "entryId", entry.entryId)
                                        end
                                    }
                                )
                            end
                        }
                    )
                end
            }
        )

        util.uiRow(
            "offset",
            function()
                ui.numberInput(
                    "offset x",
                    params.xOffset,
                    {
                        onChange = function(newX)
                            onChangeParam("change create x offset", "xOffset", newX)
                        end
                    }
                )
            end,
            function()
                ui.numberInput(
                    "offset y",
                    params.yOffset,
                    {
                        onChange = function(newY)
                            onChangeParam("change create y offset", "yOffset", newY)
                        end
                    }
                )
            end
        )
    end,
    run = function(self, actorId, params, context)
        local entry = self.game.library[params.entryId]
        if entry then
            local x = 0
            local y = 0
            local physics, bodyId, body = self.game.behaviorsByName.Body:getMembers(actorId)
            if bodyId and body and context.isOwner then
                x, y = body:getPosition()
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
    description = [[
**Removes the actor** from the scene.
    ]],
    category = "lifetime",
    run = function(self, actorId, params, context)
        if self.game.actors[actorId] then
            local physics, bodyId, body = self.game.behaviorsByName.Body:getMembers(actorId)
            if bodyId and body then
                -- Save a few things in `context` for use in responses after 'wait's
                context.x, context.y = body:getPosition()
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
    description = [[
Restores the scene back to the start state.
    ]],
    category = "scene",
    run = function(self, actorId, params, context)
        self.game:restartScene()
    end
}

-- Timing responses

RulesBehavior.responses.wait = {
    description = [[
**Wait some time** before performing the next response.
    ]],
    autoNext = false,
    category = "timing",
    initialParams = {
        duration = 1
    },
    uiBody = function(self, params, onChangeParam)
        ui.numberInput(
            "duration (seconds)",
            params.duration,
            {
                min = 0,
                max = 30,
                step = 0.2,
                onChange = function(newDuration)
                    onChangeParam("change wait duration", "duration", newDuration)
                end
            }
        )
    end,
    run = function(self, actorId, params, context)
        local timeLeft = params.duration
        while timeLeft > 0 do
            timeLeft = timeLeft - coroutine.yield()
        end
    end
}

-- Logic responses

RulesBehavior.responses["if"] = {
    description = [[
Perform responses **only if** a given condition is true. Optionally can have an 'else' branch for when the condition is false.
    ]],
    category = "logic",
    uiMenu = function(self, params, onChangeParam, uiChild)
        ui.toggle(
            "use 'else' branch",
            "use 'else' branch",
            params["else"] ~= nil,
            {
                onToggle = function(newElseEnabled)
                    if newElseEnabled then
                        onChangeParam("add else branch", "else", util.deepCopyTable(EMPTY_RULE.response))
                    else
                        onChangeParam("remove else branch", "else", nil)
                    end
                end
            }
        )
    end,
    uiHeader = function(self, params, onChangeParam, uiChild)
        uiChild(
            "condition",
            {
                label = "condition",
                noMarginTop = true,
                returnType = "boolean"
            }
        )
    end,
    uiBody = function(self, params, onChangeParam, uiChild)
        uiChild("then")
        if params["else"] then
            ui.box(
                "else container",
                {
                    flexDirection = "row"
                },
                function()
                    ui.box(
                        "else backgrond",
                        {
                            marginTop = 12,
                            marginBottom = 6,
                            marginLeft = -9,
                            borderWidth = 2,
                            borderColor = "#eee",
                            backgroundColor = "#eee",
                            borderTopRightRadius = 6,
                            borderBottomRightRadius = 6
                        },
                        function()
                            ui.markdown("### else")
                        end
                    )
                end
            )
            uiChild("else")
        end
    end,
    run = function(self, actorId, params, context)
        if self:runResponse(params["condition"], actorId, context) then
            self:runResponse(params["then"], actorId, context)
        else
            self:runResponse(params["else"], actorId, context)
        end
    end
}

RulesBehavior.responses["repeat"] = {
    description = [[
Repeat responses a certain number of times.
    ]],
    category = "logic",
    initialParams = {
        count = 3
    },
    uiBody = function(self, params, onChangeParam, uiChild)
        ui.numberInput(
            "repetitions",
            params.count,
            {
                min = 0,
                step = 1,
                onChange = function(newCount)
                    onChangeParam("change repeat count", "count", math.floor(newCount))
                end
            }
        )
        uiChild("body")
    end,
    run = function(self, actorId, params, context)
        for i = 1, params.count do
            self:runResponse(params["body"], actorId, context)
        end
    end
}

RulesBehavior.responses["act on"] = {
    description = [[
Run responses **on each actor** that has the given **tag**.
    ]],
    category = "act",
    uiBody = function(self, params, onChangeParam, uiChild)
        ui.textInput(
            "tag",
            params.tag or "",
            {
                onChange = function(newTag)
                    newTag = newTag:gsub(" ", "")
                    if newTag == "" then
                        newTag = nil
                    end
                    onChangeParam("change with tag", "tag", newTag)
                end
            }
        )
        uiChild("body", {allBehaviors = true})
    end,
    run = function(self, actorId, params, context)
        if params.tag then
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
    description = [[
Run responses on the **other actor** that an actor **collided** with.
    ]],
    category = "act",
    triggerFilter = {collide = true},
    uiBody = function(self, params, onChangeParam, uiChild)
        uiChild("body", {allBehaviors = true})
    end,
    run = function(self, actorId, params, context)
        if context.otherActorId then
            self:runResponse(params["body"], context.otherActorId, context)
        end
    end
}

-- Random responses

RulesBehavior.responses["coin flip"] = {
    description = [[
Is true if a coin flip comes up heads. The coin can be biased with a given probability.
    ]],
    category = "random",
    returnType = "boolean",
    initialParams = {
        probability = 0.5
    },
    uiBody = function(self, params, onChangeParam, uiChild)
        ui.numberInput(
            "probability of heads",
            params.probability,
            {
                min = 0,
                max = 1,
                step = 0.2,
                onChange = function(newProbability)
                    onChangeParam("change coin flip probability", "probability", newProbability)
                end
            }
        )
    end,
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

-- UI

function RulesBehavior:uiPart(actorId, part, props)
    part = part or EMPTY_RULE.response

    local actor = self.game.actors[actorId]

    local behavior, entry
    if part.name ~= "none" then
        behavior = self.game.behaviors[part.behaviorId]
        entry = behavior[props.kind .. "s"][part.name]
    end

    local function callEntryUi(funcName)
        if entry[funcName] then
            entry[funcName](
                behavior,
                part.params,
                function(description, paramName, newValue)
                    local newParams = util.deepCopyTable(part.params)
                    newParams[paramName] = newValue
                    props.onChange(
                        {
                            behaviorId = part.behaviorId,
                            name = part.name,
                            params = newParams
                        },
                        description,
                        true
                    )
                end,
                function(childName, childProps)
                    local newProps = util.deepCopyTable(childProps) or {}
                    newProps.triggerName = props.triggerName
                    newProps.allBehaviors = newProps.allBehaviors or props.allBehaviors
                    newProps.kind = "response"
                    newProps.onChange = function(newChild, description)
                        local newParams = util.deepCopyTable(part.params)
                        newParams[childName] = newChild
                        props.onChange(
                            {
                                behaviorId = part.behaviorId,
                                name = part.name,
                                params = newParams
                            },
                            description
                        )
                    end
                    self:uiPart(actorId, part.params[childName], newProps)
                end
            )
        end
    end

    ui.box(
        part.name .. " container",
        {
            flex = 1,
            marginTop = not props.noMarginTop and 8 or nil
        },
        function()
            ui.box(
                "header",
                {
                    flex = 1,
                    flexDirection = "row",
                    marginLeft = 12,
                    zIndex = 1
                },
                function()
                    if part.name ~= "none" and entry.uiBody then
                        ui.box(
                            "border",
                            {
                                position = "absolute",
                                top = 8,
                                left = 0,
                                right = 0,
                                bottom = 0,
                                borderLeftWidth = part.name == "none" and 0 or 3,
                                borderColor = "#eee"
                            },
                            function()
                            end
                        )
                    end
                    ui.box(
                        "selector",
                        {
                            flex = part.name == "none" and 1 or nil
                        },
                        function()
                            local label
                            if part.name == "none" then
                                label =
                                    (props.kind == "response" and props.returnType == nil and "add " or "select ") ..
                                    (props.label or props.kind)
                            else
                                label = part.name
                            end
                            ui.button(
                                label,
                                {
                                    margin = 0,
                                    textStyle = part.name ~= "none" and {fontSize = 18} or nil,
                                    icon = part.name == "none" and "plus" or "ellipsis-v",
                                    iconFamily = "FontAwesome5",
                                    onClick = function()
                                        self._picking = nil
                                    end,
                                    popoverAllowed = true,
                                    popoverStyle = {width = 300, maxHeight = 300},
                                    popover = function(closePopover)
                                        ui.scrollBox(
                                            "scroll box",
                                            {
                                                padding = 2,
                                                margin = 2,
                                                flexGrow = 0,
                                                alwaysBounceVertical = false
                                            },
                                            function()
                                                if part.name ~= "none" and not self._picking then
                                                    ui.markdown("## " .. part.name .. "\n" .. (entry.description or ""))
                                                    if entry.uiMenu then
                                                        callEntryUi("uiMenu")
                                                        ui.box(
                                                            "spacer",
                                                            {height = 18},
                                                            function()
                                                            end
                                                        )
                                                    end
                                                    if props.kind == "response" and entry.returnType == nil then
                                                        util.uiRow(
                                                            "insert move",
                                                            function()
                                                                ui.button(
                                                                    "insert before",
                                                                    {
                                                                        icon = "plus",
                                                                        iconFamily = "FontAwesome5",
                                                                        onClick = function()
                                                                            self._picking = "insertBefore"
                                                                        end
                                                                    }
                                                                )
                                                            end,
                                                            function()
                                                                if
                                                                    part.params.nextResponse and
                                                                        part.params.nextResponse.name ~= "none"
                                                                 then
                                                                    ui.button(
                                                                        "move down",
                                                                        {
                                                                            icon = "arrow-bold-down",
                                                                            iconFamily = "Entypo",
                                                                            onClick = function()
                                                                                closePopover()
                                                                                local clone = util.deepCopyTable(part)
                                                                                local newHead =
                                                                                    clone.params.nextResponse
                                                                                clone.params.nextResponse =
                                                                                    newHead.params.nextResponse
                                                                                newHead.params.nextResponse = clone
                                                                                props.onChange(
                                                                                    newHead,
                                                                                    "move response down"
                                                                                )
                                                                            end
                                                                        }
                                                                    )
                                                                end
                                                            end
                                                        )
                                                    end
                                                    util.uiRow(
                                                        "replace remove",
                                                        function()
                                                            ui.button(
                                                                "replace",
                                                                {
                                                                    icon = "exchange-alt",
                                                                    iconFamily = "FontAwesome5",
                                                                    onClick = function()
                                                                        self._picking = "replace"
                                                                    end
                                                                }
                                                            )
                                                        end,
                                                        function()
                                                            ui.button(
                                                                "remove",
                                                                {
                                                                    icon = "trash-alt",
                                                                    iconFamily = "FontAwesome5",
                                                                    onClick = function()
                                                                        closePopover()
                                                                        props.onChange(
                                                                            part.params.nextResponse,
                                                                            "remove response"
                                                                        )
                                                                    end
                                                                }
                                                            )
                                                        end
                                                    )
                                                else
                                                    local categories = {}
                                                    local behaviorIds =
                                                        props.allBehaviors and self.game.behaviors or actor.components
                                                    for behaviorId in pairs(behaviorIds) do
                                                        local behavior = self.game.behaviors[behaviorId]
                                                        local behaviorUiName = behavior:getUiName()
                                                        for name, entry in pairs(behavior[props.kind .. "s"]) do
                                                            if
                                                                (entry.returnType == props.returnType and
                                                                    (not entry.triggerFilter or
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
                                                                        entry = entry
                                                                    }
                                                                )
                                                            end
                                                        end
                                                    end
                                                    for categoryName, rows in pairs(categories) do
                                                        ui.section(
                                                            categoryName,
                                                            {defaultOpen = true},
                                                            function()
                                                                for _, row in ipairs(rows) do
                                                                    ui.box(
                                                                        row.name,
                                                                        {
                                                                            borderWidth = 1,
                                                                            borderColor = "#292929",
                                                                            borderRadius = 4,
                                                                            padding = 4,
                                                                            margin = 4,
                                                                            marginBottom = 8
                                                                        },
                                                                        function()
                                                                            ui.markdown(
                                                                                "## " ..
                                                                                    row.name ..
                                                                                        "\n" ..
                                                                                            (row.entry.description or "")
                                                                            )

                                                                            ui.box(
                                                                                "buttons",
                                                                                {flexDirection = "row"},
                                                                                function()
                                                                                    ui.button(
                                                                                        "use",
                                                                                        {
                                                                                            flex = 1,
                                                                                            icon = "plus",
                                                                                            iconFamily = "FontAwesome5",
                                                                                            onClick = function()
                                                                                                closePopover()
                                                                                                if props.onChange then
                                                                                                    local newParams =
                                                                                                        util.deepCopyTable(
                                                                                                        row.entry.initialParams
                                                                                                    ) or {}
                                                                                                    if
                                                                                                        self._picking ==
                                                                                                            "replace"
                                                                                                     then
                                                                                                        if
                                                                                                            part.params and
                                                                                                                part.params.nextResponse
                                                                                                         then
                                                                                                            newParams.nextResponse =
                                                                                                                part.params.nextResponse
                                                                                                        end
                                                                                                    elseif
                                                                                                        self._picking ==
                                                                                                            "insertBefore"
                                                                                                     then
                                                                                                        newParams.nextResponse =
                                                                                                            part
                                                                                                    end
                                                                                                    props.onChange(
                                                                                                        {
                                                                                                            behaviorId = row.behaviorId,
                                                                                                            name = row.name,
                                                                                                            params = newParams
                                                                                                        },
                                                                                                        "add " ..
                                                                                                            row.name ..
                                                                                                                " " ..
                                                                                                                    (props.label or
                                                                                                                        props.kind)
                                                                                                    )
                                                                                                end
                                                                                                self._picking = nil
                                                                                            end
                                                                                        }
                                                                                    )
                                                                                end
                                                                            )
                                                                        end
                                                                    )
                                                                end
                                                            end
                                                        )
                                                    end
                                                end
                                            end
                                        )
                                    end
                                }
                            )
                        end
                    )
                    if part.name ~= "none" then
                        callEntryUi("uiHeader")
                    end
                end
            )

            if part.name ~= "none" and entry.uiBody then
                ui.box(
                    part.name .. " box",
                    {
                        flex = 1,
                        borderBottomLeftRadius = 6,
                        borderLeftWidth = part.name == "none" and 0 or 3,
                        borderColor = "#eee",
                        marginTop = -8,
                        marginBottom = 2,
                        paddingTop = 12,
                        paddingLeft = 6,
                        marginLeft = 12
                    },
                    function()
                        callEntryUi("uiBody")
                    end
                )
            end

            if props.kind == "response" and part.name ~= "none" and entry.returnType == nil then
                self:uiPart(
                    actorId,
                    part.params.nextResponse or EMPTY_RULE.response,
                    {
                        triggerName = props.triggerName,
                        allBehaviors = props.allBehaviors,
                        kind = "response",
                        onChange = function(newNextResponse)
                            local newParams = util.deepCopyTable(part.params)
                            newParams.nextResponse = newNextResponse
                            props.onChange(
                                {
                                    behaviorId = part.behaviorId,
                                    name = part.name,
                                    params = newParams
                                },
                                "add response"
                            )
                        end
                    }
                )
            end
        end
    )
end

function RulesBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    for ruleIndex, rule in ipairs(component.properties.rules) do
        ui.box(
            "rule-" .. ruleIndex,
            {
                borderRadius = 6,
                borderLeftWidth = 3,
                borderColor = "#eee",
                margin = 4,
                marginVertical = 8,
                paddingLeft = 6
            },
            function()
                ui.box(
                    "when row",
                    {flexDirection = "row"},
                    function()
                        ui.box(
                            "when box",
                            {marginRight = 6, marginBottom = 6, marginTop = 2},
                            function()
                                ui.markdown("### when")
                            end
                        )
                        self:uiPart(
                            actorId,
                            rule.trigger,
                            {
                                kind = "trigger",
                                noMarginTop = true,
                                onChange = function(newTrigger, description, shouldCoalesce)
                                    local oldRules = util.deepCopyTable(component.properties.rules)
                                    rule.trigger = newTrigger or util.deepCopyTable(EMPTY_RULE.trigger)
                                    local newRules = util.deepCopyTable(component.properties.rules)
                                    self:command(
                                        description,
                                        {
                                            coalesceLast = false,
                                            params = {"oldRules", "newRules"},
                                            coalesceSuffix = shouldCoalesce and description or nil
                                        },
                                        function()
                                            self:sendSetProperties(actorId, "rules", newRules)
                                        end,
                                        function()
                                            self:sendSetProperties(actorId, "rules", oldRules)
                                        end
                                    )
                                end
                            }
                        )
                    end
                )
                self:uiPart(
                    actorId,
                    rule.response,
                    {
                        triggerName = rule.trigger and rule.trigger.name or "none",
                        kind = "response",
                        onChange = function(newResponse, description, shouldCoalesce)
                            local oldRules = util.deepCopyTable(component.properties.rules)
                            rule.response = newResponse or util.deepCopyTable(EMPTY_RULE.response)
                            local newRules = util.deepCopyTable(component.properties.rules)
                            self:command(
                                description,
                                {
                                    coalesceLast = false,
                                    params = {"oldRules", "newRules"},
                                    coalesceSuffix = shouldCoalesce and description or nil
                                },
                                function()
                                    self:sendSetProperties(actorId, "rules", newRules)
                                end,
                                function()
                                    self:sendSetProperties(actorId, "rules", oldRules)
                                end
                            )
                        end
                    }
                )
            end
        )
    end

    ui.button(
        "add rule",
        {
            icon = "plus",
            iconFamily = "FontAwesome5",
            onClick = function()
                local oldRules = util.deepCopyTable(component.properties.rules)
                table.insert(component.properties.rules, util.deepCopyTable(EMPTY_RULE))
                local newRules = util.deepCopyTable(component.properties.rules)
                self:command(
                    description,
                    {
                        params = {"oldRules", "newRules"}
                    },
                    function()
                        self:sendSetProperties(actorId, "rules", newRules)
                    end,
                    function()
                        self:sendSetProperties(actorId, "rules", oldRules)
                    end
                )
            end
        }
    )
end
