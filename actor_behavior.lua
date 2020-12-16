-- Actor / behavior system

-- Base behavior

local BaseBehavior = {}

function BaseBehavior:getUiName()
    return self.displayName or self.name
end

function BaseBehavior:isActive()
    if self.tool then
        if self.game.activeToolBehaviorId ~= self.behaviorId then
            return false
        end
    end
    return true
end

function BaseBehavior:callHandler(handlerName, ...)
    local handler = self.handlers[handlerName]
    if handler then
        local behaviorSelf = self
        local varArgs = {...}

        return profileFunction(handlerName .. ' ' .. self.name, function()
            return handler(behaviorSelf, unpack(varArgs))
        end)
    end
end

function BaseBehavior:fireTrigger(...)
    -- this calls "RulesBehavior.handlers:trigger" in rules.lua
    return self.game.behaviorsByName.Rules:callHandler("trigger", ...)
end

function BaseBehavior:sendSetProperties(opts, ...)
    local actorId, sendOpts
    if type(opts) == "table" then
        actorId = opts.actorId
        sendOpts = setmetatable({kind = "setProperties"}, {__index = opts})
    else
        actorId = opts
        sendOpts = "setProperties"
    end

    local function checkPropertyNames(name, value, ...)
       if name ~= nil then
          local spec = self.propertySpecs[name]
          if not spec then
             error("behavior '" .. self.name .. "' has no property named '" .. name .. "'")
          end
          return name, value, checkPropertyNames(...)
       end
    end
    
    self.game:send(sendOpts, self.game.clientId, actorId, self.behaviorId, checkPropertyNames(...))
end

function BaseBehavior:has(actorId)
    return not (not self.components[actorId])
end

function BaseBehavior:get(actorId)
    return self.components[actorId]
end

function BaseBehavior:getTouchData()
    local empty = {
        touches = {},
        numTouches = 0,
        maxNumTouches = 0,
        allTouchesReleased = false,
        gestureId = nil
    }

    if self.game.gestureStolen then
        return empty
    end
    return {
        touches = self.game.touches,
        numTouches = self.game.numTouches,
        maxNumTouches = self.game.maxNumTouches,
        allTouchesReleased = self.game.allTouchesReleased,
        gestureId = self.game.gestureId
    }
end

function BaseBehavior:getOtherBehavior(otherBehaviorId)
    return self.game.behaviors[otherBehaviorId]
end

function BaseBehavior:getActor(actorId)
    return self.game.actors[actorId]
end

function BaseBehavior:hasAnyEnabledComponent()
   for _, component in pairs(self.components) do
      if not component.disabled then
         return true
      end
   end
   return false
end

function BaseBehavior:isInteractive(component)
   if self.getters.isInteractive ~= nil then
      return self.getters.isInteractive(self, component)
   end
   return false
end

function BaseBehavior:command(description, opts, doFunc, undoFunc)
    self.game:command(description, setmetatable({behaviorId = self.behaviorId}, {__index = opts}), doFunc, undoFunc)
end

function BaseBehavior:onEndOfFrame(func)
    table.insert(self.game.onEndOfFrames, func)
end

-- Core behavior definition

local CORE_BEHAVIORS = {}

function defineCoreBehavior(behaviorSpec)
    behaviorSpec.isCore = true
    behaviorSpec.propertySpecs = behaviorSpec.propertySpecs or {}
    behaviorSpec.handlers = behaviorSpec.handlers or {}
    behaviorSpec.getters = behaviorSpec.getters or {}
    behaviorSpec.setters = behaviorSpec.setters or {}
    behaviorSpec.dependencies = behaviorSpec.dependencies or {}
    behaviorSpec.triggers = behaviorSpec.triggers or {}
    behaviorSpec.responses = behaviorSpec.responses or {}
    table.insert(CORE_BEHAVIORS, behaviorSpec)
    return behaviorSpec
end

-- Start / stop

function Common:startActorBehavior()
    self.nextActorIdSuffix = 1

    self.actors = {} -- `actorId` -> actor
    self.actorsByDrawOrder = {} -- { `actor1`, `actor2`, ... }
    self.behaviors = {} -- `behaviorId` -> behavior
    self.behaviorsByName = {} -- `behaviorName` -> behavior
    self.behaviorsByHandler = {} -- `handlerName` -> `behaviorId` -> behavior
    self.tools = {} -- `behaviorId` -> behavior, for tool behaviors

    for behaviorId, behaviorSpec in ipairs(CORE_BEHAVIORS) do
        self.receivers.addBehavior(self, 0, self.clientId, behaviorId, behaviorSpec)
    end
end

function Common:stopActorBehavior()
    -- Need to visit dependents before dependencies -- collect pre-order traversal along dependency
    -- links, then use its reverse
    local order = {}
    local visited = {}
    local function visit(behaviorId, behavior)
        if visited[behaviorId] then
            return
        end
        visited[behaviorId] = true
        behavior = behavior or self.behaviors[behaviorId]
        for _, dependency in pairs(behavior.dependencies) do
            visit(dependency.behaviorId, dependency)
        end
        table.insert(order, behaviorId)
    end
    for behaviorId, behavior in pairs(self.behaviors) do
        visit(behaviorId, behavior)
    end
    for i = #order, 1, -1 do
        self.receivers.removeBehavior(self, 0, self.clientId, order[i])
    end
end

-- Message receivers

function Common.receivers:addActor(time, clientId, actorId, parentEntryId, isGhost)
    assert(not self.actors[actorId], "addActor: this `actorId` is already used")

    local actor = {}
    actor.actorId = actorId
    actor.parentEntryId = parentEntryId
    if isGhost ~= nil then
        actor.isGhost = isGhost
    else
        actor.isGhost = false
    end
    actor.components = {}

    self.actors[actorId] = actor

    -- Insert at end of draw order
    actor.drawOrder = #self.actorsByDrawOrder + 1
    self.actorsByDrawOrder[actor.drawOrder] = actor
end

function Common.receivers:postAddActor(time, actorId)
   self:variablesUpdatePostAddActor(actorId)
   self:callHandlers("postAddActor", actorId)
end

function Common.receivers:postAddComponents(time, actorId)
    self:callHandlers("postAddComponents", actorId)
end

function Common.receivers:removeActor(time, clientId, actorId, opts)
    opts = opts or {}

    local actor = self.actors[actorId]
    if not actor then
        if not opts.soft then
            error("removeActor: no such actor")
        end
        return
    end

    -- Need to visit dependents before dependencies -- collect pre-order traversal along dependency
    -- links, then use its reverse
    local order = {}
    local visited = {}
    local function visit(behaviorId, behavior)
        if visited[behaviorId] then
            return
        end
        visited[behaviorId] = true
        behavior = behavior or self.behaviors[behaviorId]
        for _, dependency in pairs(behavior.dependencies) do
            visit(dependency.behaviorId, dependency)
        end
        table.insert(order, behavior)
    end
    for behaviorId in pairs(actor.components) do
        visit(behaviorId)
    end
    for i = #order, 1, -1 do
        local behavior = order[i]
        behavior:callHandler(
            "preRemoveActor",
            behavior.components[actorId],
            {
                isOrigin = self.clientId == clientId,
            }
        )
    end
    for i = #order, 1, -1 do
        local behavior = order[i]
        behavior:callHandler(
            "disableComponent",
            behavior.components[actorId],
            {
                isOrigin = self.clientId == clientId,
                removeActor = true
            }
        )
        behavior.components[actorId] = nil
    end

    self.actors[actorId] = nil

    self.actorsByDrawOrder[actor.drawOrder] = nil -- Holes will be cleaned up in the next `:forEachActorByDrawOrder`
end

function Common.receivers:setActorDrawOrder(time, actorId, newDrawOrder)
    local actor = assert(self.actors[actorId], "setActorDrawOrder: no such actor")

    if actor.drawOrder == newDrawOrder then
        return
    end
    local step = newDrawOrder > actor.drawOrder and 1 or -1

    local actorsByDrawOrder = self.actorsByDrawOrder
    for i = actor.drawOrder, newDrawOrder - step, step do
        local nextActor = actorsByDrawOrder[i + step]
        actorsByDrawOrder[i] = nextActor
        if nextActor then
            nextActor.drawOrder = i
        end
    end
    actorsByDrawOrder[newDrawOrder] = actor
    actor.drawOrder = newDrawOrder
end

function Common.receivers:setActorParentEntryId(time, actorId, newParentEntryId)
    local actor = assert(self.actors[actorId], "setActorParentEntryId: no such actor")
    actor.parentEntryId = newParentEntryId
end

function Common.receivers:addBehavior(time, clientId, behaviorId, behaviorSpec)
    assert(not self.behaviors[behaviorId], "addBehavior: this `behaviorId` is already used")
    assert(behaviorSpec, "addBehavior: need a `behaviorSpec`")

    -- Basics
    local behavior = setmetatable({}, {__index = BaseBehavior})
    behavior.behaviorId = behaviorId
    behavior.behaviorSpec = behaviorSpec
    behavior.isCore = behaviorSpec.isCore
    behavior.name = behaviorSpec.name
    behavior.displayName = behaviorSpec.displayName
    behavior.allowsDisableWithoutRemoval = behaviorSpec.allowsDisableWithoutRemoval
    behavior.description = helps.behaviors[behavior.name] and helps.behaviors[behavior.name].description
    behavior.game = self
    behavior.clientId = 0
    behavior.globals = {}
    behavior.components = {}

    -- Copy methods
    for methodName, method in pairs(behaviorSpec) do
        if type(method) == "function" then
            behavior[methodName] = method
        end
    end

    -- Copy handlers and properties
    behavior.handlers = {}
    for handlerName, handler in pairs(behaviorSpec.handlers) do
        behavior.handlers[handlerName] = handler
    end
    behavior.getters = {}
    for getterName, getter in pairs(behaviorSpec.getters) do
       behavior.getters[getterName] = getter
    end
    behavior.setters = {}
    for setterName, setter in pairs(behaviorSpec.setters) do
        behavior.setters[setterName] = setter
    end
    behavior.propertySpecs = util.deepCopyTable(behaviorSpec.propertySpecs)

    -- Copy triggers and responses
    behavior.triggers = {}
    for triggerName, trigger in pairs(behaviorSpec.triggers) do
        behavior.triggers[triggerName] = trigger
    end
    behavior.responses = {}
    for responseName, response in pairs(behaviorSpec.responses) do
        behavior.responses[responseName] = response
    end

    -- Reference dependencies
    behavior.dependents = {}
    behavior.dependencies = {}
    for _, dependencyName in pairs(behaviorSpec.dependencies) do
        local dependency =
            assert(self.behaviorsByName[dependencyName], "dependency '" .. dependencyName .. "' not resolved")
        behavior.dependencies[dependencyName] = dependency
        dependency.dependents[behavior.name] = behavior
    end

    -- Copy tool spec
    if behaviorSpec.tool then
        behavior.tool = util.deepCopyTable(behaviorSpec.tool)
    end

    -- Set in maps
    self.behaviors[behaviorId] = behavior
    self.behaviorsByName[behavior.name] = behavior
    for handlerName in pairs(behavior.handlers) do
        if not self.behaviorsByHandler[handlerName] then
            self.behaviorsByHandler[handlerName] = {}
        end
        self.behaviorsByHandler[handlerName][behaviorId] = behavior
    end
    if behavior.tool then
        self.tools[behaviorId] = behavior
    end

    -- Notify `addBehavior`
    behavior:callHandler(
        "addBehavior",
        {
            isOrigin = self.clientId == clientId
        }
    )
end

function Common.receivers:removeBehavior(time, clientId, behaviorId)
    local behavior = assert(self.behaviors[behaviorId], "removeBehavior: no such behavior")

    -- Notify `removeBehavior`
    behavior:callHandler(
        "removeBehavior",
        {
            isOrigin = self.clientId == clientId
        }
    )

    -- Unset in maps
    self.tools[behaviorId] = nil
    for actorId in pairs(behavior.components) do
        local actor = self.actors[actorId]
        local component = actor.components[behaviorId]
        for _, dependency in pairs(behavior.dependencies) do
            dependency:callHandler(
                "removeDependentComponent",
                component,
                {
                    isOrigin = self.clientId == clientId
                }
            )
            actor.components[dependency.behaviorId].dependents[behaviorId] = nil
        end
        actor.components[behaviorId] = nil
    end
    for handlerName in pairs(behavior.handlers) do
        self.behaviorsByHandler[handlerName][behaviorId] = nil
        if not next(self.behaviorsByHandler[handlerName]) then
            self.behaviorsByHandler[handlerName] = nil
        end
    end
    self.behaviorsByName[behavior.name] = nil
    self.behaviors[behaviorId] = nil
end

function Common.receivers:addComponent(time, clientId, actorId, behaviorId, bp, opts)
    opts = opts or {}
    bp = bp or {}

    local actor = assert(self.actors[actorId], "addComponent: no such actor")
    local behavior = assert(self.behaviors[behaviorId], "addComponent: no such behavior")

    if actor.components[behaviorId] then
        error("addComponent: actor already has a component for this behavior")
    end

    for _, dependency in pairs(behavior.dependencies) do
        if not dependency.components[actorId] then
            error("addComponent: '" .. behavior.name .. "' depends on '" .. dependency.name .. "'")
        end
    end

    local component = {}
    component.actorId = actorId
    component.behaviorId = behaviorId
    component.disabled = bp.disabled or false
    component.properties = {}
    component.dependents = {}
    if behavior.tool then
        component.clientId = clientId
    end

    actor.components[behaviorId] = component
    behavior.components[actorId] = component

    for _, dependency in pairs(behavior.dependencies) do
        actor.components[dependency.behaviorId].dependents[behaviorId] = component
        dependency:callHandler(
            "addDependentComponent",
            component,
            {
                isOrigin = self.clientId == clientId,
                interactive = opts.interactive
            }
        )
    end

    behavior:callHandler(
        "addComponent",
        component,
        bp,
        {
            isOrigin = self.clientId == clientId,
            interactive = opts.interactive
        }
    )

    if not component.disabled then
       self.receivers.enableComponent(self, time, clientId, actorId, behaviorId)
    end
end

function Common.receivers:removeComponent(time, clientId, actorId, behaviorId)
    local actor = assert(self.actors[actorId], "removeComponent: no such actor")
    local behavior = assert(self.behaviors[behaviorId], "removeComponent: no such behavior")

    local component = actor.components[behaviorId]

    if next(component.dependents) ~= nil then
        error("removeComponent: cannot remove '" .. behavior.name .. "' because it has dependents in this actor")
    end

    self.receivers.disableComponent(self, time, clientId, actorId, behaviorId)

    for _, dependency in pairs(behavior.dependencies) do
        dependency:callHandler(
            "removeDependentComponent",
            component,
            {
                isOrigin = self.clientId == clientId
            }
        )
        actor.components[dependency.behaviorId].dependents[behaviorId] = nil
    end
    actor.components[behaviorId] = nil
    behavior.components[actorId] = nil
end

function Common.receivers:enableComponent(time, clientId, actorId, behaviorId)
    local actor = assert(self.actors[actorId], "enableComponent: no such actor")
    local behavior = assert(self.behaviors[behaviorId], "enableComponent: no such behavior")

    local component = actor.components[behaviorId]
    if not component then
       -- can be called by a rule even after the behavior was removed
       return
    end

    behavior:callHandler(
        "enableComponent",
        component,
        {
            isOrigin = self.clientId == clientId,
        }
    )

    for _, dependency in pairs(behavior.dependencies) do
        dependency:callHandler(
            "enableDependentComponent",
            component,
            {
                isOrigin = self.clientId == clientId
            }
        )
    end

    component.disabled = false
end

function Common.receivers:disableComponent(time, clientId, actorId, behaviorId)
    local actor = assert(self.actors[actorId], "disableComponent: no such actor")
    local behavior = assert(self.behaviors[behaviorId], "disableComponent: no such behavior")

    local component = actor.components[behaviorId]
    if not component then
       -- can be called by a rule even after the behavior was removed
       return
    end

    behavior:callHandler(
        "disableComponent",
        component,
        {
            isOrigin = self.clientId == clientId,
        }
    )

    for _, dependency in pairs(behavior.dependencies) do
        dependency:callHandler(
            "disableDependentComponent",
            component,
            {
                isOrigin = self.clientId == clientId
            }
        )
    end

    component.disabled = true
end

function Common.receivers:setProperties(time, clientId, actorId, behaviorId, ...)
    local behavior = assert(self.behaviors[behaviorId], "setProperties: no such behavior")

    local component
    if actorId then
        local actor = assert(self.actors[actorId], "setProperties: no such actor")
        component = actor.components[behaviorId]
    end

    for i = 1, select("#", ...), 2 do
        local name, value = select(i, ...)
        if not name then
            error("setProperties: bad property id")
        end
        local setter = behavior.setters[name]
        if actorId then
            if setter then
                setter(
                    behavior,
                    component,
                    value,
                    {
                        isOrigin = self.clientId == clientId
                    }
                )
            else
                component.properties[name] = value
            end
        else
            if setter then
                setter(
                    behavior,
                    nil,
                    value,
                    {
                        isOrigin = self.clientId == clientId
                    }
                )
            else
                behavior.globals[name] = value
            end
        end
    end
end

-- Methods

function Common:generateActorId()
    local prefix = "0"

    local newId
    while true do
        newId = prefix .. ":" .. tostring(self.nextActorIdSuffix)
        self.nextActorIdSuffix = self.nextActorIdSuffix + 1
        if not self.actors[newId] then
            break
        end
    end

    return newId
end

function Common:sendAddActor(bp, opts)
    local actorId = opts.actorId or self:generateActorId()

    self:send("addActor", self.clientId, actorId, opts.parentEntryId, opts.isGhost)

    -- Set draw order if given
    if opts.drawOrder then
        self:send("setActorDrawOrder", actorId, opts.drawOrder)
    end

    -- Add components in depth-first order through dependency graph
    local visited = {}
    local function visit(behaviorName, componentBp)
        if visited[behaviorName] then
            return
        end
        visited[behaviorName] = true

        componentBp = componentBp or bp.components[behaviorName]

        local behavior = self.behaviorsByName[behaviorName]
        if not behavior then
            print("addActor: no behavior '" .. behaviorName .. "'")
            return
        end

        for dependencyName in pairs(behavior.dependencies) do
            visit(dependencyName)
        end

        self:send("addComponent", self.clientId, actorId, behavior.behaviorId, componentBp)
    end
    local hasTags = false
    for behaviorName, componentBp in pairs(bp.components) do
        if behaviorName == 'Tags' then
            hasTags = true
        end
        visit(behaviorName, componentBp)
    end

    -- legacy: if the actor doesn't have tags behavior, add it
    if not hasTags then
        self:send("addComponent", self.clientId, actorId, self.behaviorsByName.Tags.behaviorId, {})
    end

    self:send("postAddComponents", actorId)
    
    if self.performing then
        self:send("postAddActor", actorId)
    end

    return actorId
end

function Common:isActorInteractive(actorId)
   local actor = assert(self.actors[actorId], "isActorInteractive: no such actor")
   for behaviorId, component in pairs(actor.components) do
      local behavior = self.behaviors[component.behaviorId]
      if behavior:isInteractive(component) then
         return true
      end
   end
   return false
end

function Common:blueprintActor(actorId)
    local bp = {}

    local actor = assert(self.actors[actorId], "blueprintActor: no such actor")

    -- Blueprint each component that isn't a tool
    bp.components = {}
    for behaviorId, component in pairs(actor.components) do
        if not self.tools[behaviorId] then
            local behavior = self.behaviors[component.behaviorId]
            local componentBp = {}
            behavior:callHandler("blueprintComponent", component, componentBp)
            componentBp.disabled = component.disabled or false
            bp.components[behavior.name] = componentBp
        end
    end

    return bp
end

function Common:actorBlueprintPng(actorId)
    local actor = assert(self.actors[actorId], "blueprintActor: no such actor")

    for behaviorId, component in pairs(actor.components) do
        if not self.tools[behaviorId] then
            local behavior = self.behaviors[component.behaviorId]
            if behavior.name == 'Drawing2' then
                return behavior:callHandler("blueprintPng", component)
            end
        end
    end

    return nil
end

function Common:callHandlers(handlerName, ...)
    local behaviors = self.behaviorsByHandler[handlerName]
    if behaviors then
        for behaviorId, behavior in pairs(behaviors) do
            behavior:callHandler(handlerName, ...)
        end
    end
end

function Common:forEachActorByDrawOrder(func)
    -- Visit all, sifting down if we found holes
    local nextNewDrawOrder = 1 -- The next 'dense' draw order
    for i = 1, table.maxn(self.actorsByDrawOrder) do
        local actor = self.actorsByDrawOrder[i]
        if actor and not actor.isGhost then
            if i ~= nextNewDrawOrder then -- Sift down if needed
                self.actorsByDrawOrder[i] = nil
                self.actorsByDrawOrder[nextNewDrawOrder] = actor
                actor.drawOrder = nextNewDrawOrder
            end
            nextNewDrawOrder = nextNewDrawOrder + 1

            if func then
                func(actor)
            end
        end
    end
end
