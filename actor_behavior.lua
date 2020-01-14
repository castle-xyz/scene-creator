-- Actor / behavior system


-- Base behavior

local BaseBehavior = {}

function BaseBehavior:callHandler(handlerName, ...)
    if self.tool then -- Tool? Skip if server or if not currently active on client.
        if self.game.server or (self.game.client and self.game.activeToolBehaviorId ~= self.behaviorId) then
            return
        end
    end
    local handler = self.handlers[handlerName]
    if handler then
        return handler(self, ...)
    end
end

function BaseBehavior:sendSetProperties(opts, ...)
    local actorId, sendOpts
    if type(opts) == 'table' then
        actorId = opts.actorId
        sendOpts = setmetatable({ kind = 'setProperties' }, { __index = opts })
    else
        actorId = opts
        sendOpts = 'setProperties'
    end

    local function propertyNamesToIds(name, value, ...)
        if name ~= nil then
            local id = self.propertyIds[name]
            if not id then
                error("behavior '" .. self.name .. "' has no property named '" .. name .. "'")
            end
            return id, value, propertyNamesToIds(...)
        end
    end

    self.game:send(sendOpts, self.game.clientId, actorId, self.behaviorId, propertyNamesToIds(...))
end

function BaseBehavior:has(actorId)
    return not not self.components[actorId]
end

function BaseBehavior:getTouchData()
    if self.game.server then
        return {
            touches = {},
            numTouches = 0,
            maxNumTouches = 0,
            allTouchesReleased = false,
        }
    end
    if self.game.client then
        return {
            touches = self.game.touches,
            numTouches = self.game.numTouches,
            maxNumTouches = self.game.maxNumTouches,
            allTouchesReleased = self.game.allTouchesReleased,
        }
    end
end


-- Core behavior registration

local CORE_BEHAVIORS = {}

function registerCoreBehavior(behaviorId, behaviorSpec)
    assert(not CORE_BEHAVIORS[behaviorId], "core `behaviorId` '" .. behaviorId .. "' is already used")
    behaviorSpec.isCore = true
    CORE_BEHAVIORS[behaviorId] = behaviorSpec
end


-- Start / stop

function Common:startActorBehavior()
    self.actors = {} -- `actorId` -> actor
    self.behaviors = {} -- `behaviorId` -> behavior
    self.behaviorsByName = {} -- `behaviorName` -> behavior
    self.behaviorsByHandler = {} -- `handlerName` -> `behaviorId` -> behavior
    self.tools = {} -- `behaviorId` -> behavior, for tool behaviors

    for behaviorId, behaviorSpec in pairs(CORE_BEHAVIORS) do
        self.receivers.addBehavior(self, 0, self.clientId, behaviorId, behaviorSpec)
    end
end

function Common:stopActorBehavior()
    for behaviorId, behavior in pairs(self.behaviors) do
        self.receivers.removeBehavior(self, 0, self.clientId, behaviorId)
    end
end


-- Message kind definitions

function Common:defineActorBehaviorMessageKinds(config)
    self:defineMessageKind('addActor', config.reliableToAllSendOpts)
    self:defineMessageKind('removeActor', config.reliableToAllSendOpts)
    self:defineMessageKind('addBehavior', config.reliableToAllSendOpts)
    self:defineMessageKind('removeBehavior', config.reliableToAllSendOpts)
    self:defineMessageKind('addComponent', config.reliableToAllSendOpts)
    self:defineMessageKind('removeComponent', config.reliableToAllSendOpts)
    self:defineMessageKind('setProperties', config.reliableToAllSendOpts)
end


-- Connect / disconnect

function Server:syncClientActorBehavior(clientId, send)
    -- Send behaviors and their global properties
    for behaviorId, behavior in pairs(self.behaviors) do
        if not behavior.isCore then
            send('addBehavior', self.clientId, behaviorId, behavior.behaviorSpec)
        end

        behavior:sendSetProperties({
            to = clientId,
            selfSend = false,
            channel = MAIN_RELIABLE_CHANNEL,
        }, util.unpackPairs(behavior.globals))
    end

    -- Notify `preSyncClient`
    for behaviorId, behavior in pairs(self.behaviors) do
        behavior:callHandler('preSyncClient', clientId)
    end

    -- Send actors and components
    for actorId, actor in pairs(self.actors) do
        send('addActor', self.clientId, actorId)

        for behaviorId, component in pairs(actor.components) do
            send('addComponent', self.clientId, actorId, behaviorId)

            local behavior = self.behaviors[behaviorId]
            behavior:sendSetProperties({
                to = clientId,
                selfSend = false,
                channel = MAIN_RELIABLE_CHANNEL,
                actorId = actorId,
            }, util.unpackPairs(component.properties))
        end
    end

    -- Notify `postSyncClient`
    for behaviorId, behavior in pairs(self.behaviors) do
        behavior:callHandler('postSyncClient', clientId)
    end
end

function Server:disconnectActorBehavior(clientId)
    -- Clear tool components for this client
    for behaviorId, tool in pairs(self.tools) do
        for actorId, component in pairs(tool.components) do
            if component.clientId == clientId then
                self:send('removeComponent', self.clientId, actorId, behaviorId)
            end
        end
    end
end


-- Message receivers

function Common.receivers:addActor(time, clientId, actorId)
    assert(not self.actors[actorId], 'addActor: this `actorId` is already used')

    local actor = {}
    actor.actorId = {}
    actor.components = {}

    self.actors[actorId] = actor
end

function Common.receivers:removeActor(time, clientId, actorId)
    local actor = assert(self.actors[actorId], 'removeActor: no such actor')

    for behaviorId, component in pairs(actor.components) do
        local behavior = self.behaviors[behaviorId]
        behavior:callHandler('removeComponent', component, {
            isOrigin = self.clientId == clientId,
        })
        behavior.components[actorId] = nil
    end

    self.actors[actorId] = nil
end

function Common.receivers:addBehavior(time, clientId, behaviorId, behaviorSpec)
    assert(not self.behaviors[behaviorId], 'addBehavior: this `behaviorId` is already used')
    assert(behaviorSpec, 'addBehavior: need a `behaviorSpec`')

    -- Basics
    local behavior = setmetatable({}, { __index = BaseBehavior })
    behavior.behaviorId = behaviorId
    behavior.behaviorSpec = behaviorSpec
    behavior.isCore = behaviorSpec.isCore
    behavior.name = behaviorSpec.name
    behavior.game = self
    behavior.globals = {}
    behavior.components = {}

    -- Copy property names
    behavior.propertyIds = {}
    behavior.propertyNames = {}
    for propertyId, propertyName in ipairs(behaviorSpec.propertyNames) do
        behavior.propertyIds[propertyName] = propertyId
        behavior.propertyNames[propertyId] = propertyName
    end

    -- Copy methods
    for methodName, method in pairs(behaviorSpec) do
        if type(method) == 'function' then
            behavior[methodName] = method
        end
    end

    -- Copy handlers and setters
    behavior.handlers = {}
    for handlerName, handler in pairs(behaviorSpec.handlers or {}) do
        behavior.handlers[handlerName] = handler
    end
    behavior.setters = {}
    for setterName, setter in pairs(behaviorSpec.setters or {}) do
        behavior.setters[setterName] = setter
    end

    -- Reference dependencies
    behavior.dependencies = {}
    for _, dependencyName in pairs(behaviorSpec.dependencies or {}) do
        behavior.dependencies[dependencyName] = assert(self.behaviorsByName[dependencyName],
            "dependency '" .. dependencyName .. "' not resolved")
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
    behavior:callHandler('addBehavior', {
        isOrigin = self.clientId == clientId,
    })
end

function Common.receivers:removeBehavior(time, clientId, behaviorId)
    local behavior = assert(self.behaviors[behaviorId], 'removeBehavior: no such behavior')

    -- Notify `removeBehavior`
    behavior:callHandler('removeBehavior', {
        isOrigin = self.clientId == clientId,
    })

    -- Unset in maps
    self.tools[behaviorId] = nil
    for actorId in pairs(behavior.components) do
        self.actors[actorId].components[behaviorId] = nil
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

function Common.receivers:addComponent(time, clientId, actorId, behaviorId, bp)
    local actor = assert(self.actors[actorId], 'addComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'addComponent: no such behavior')

    if actor.components[behaviorId] then
        error('addComponent: actor already has a component for this behavior')
    end

    for _, dependency in pairs(behavior.dependencies) do
        if not dependency.components[actorId] then
            error("addComponent: '" .. behavior.name .. "' depends on '" .. dependency.name .. "'")
        end
    end

    local component = {}
    component.actorId = actorId
    component.behaviorId = behaviorId
    component.properties = {}
    if behavior.tool then
        component.clientId = clientId
    end

    actor.components[behaviorId] = component
    behavior.components[actorId] = component

    behavior:callHandler('addComponent', component, bp or {}, {
        isOrigin = self.clientId == clientId,
    })
end

function Common.receivers:removeComponent(time, clientId, actorId, behaviorId)
    local actor = assert(self.actors[actorId], 'removeComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'removeComponent: no such behavior')

    behavior:callHandler('removeComponent', actor.components[behaviorId], {
        isOrigin = self.clientId == clientId,
    })

    actor.components[behaviorId] = nil
    behavior.components[actorId] = nil
end

function Common.receivers:setProperties(time, clientId, actorId, behaviorId, ...)
    local behavior = assert(self.behaviors[behaviorId], 'setProperties: no such behavior')

    local component
    if actorId then
        local actor = assert(self.actors[actorId], 'setProperties: no such actor')
        component = actor.components[behaviorId]
    end

    for i = 1, select('#', ...), 2 do
        local id, value = select(i, ...)
        local name = behavior.propertyNames[id]
        if not name then
            error('setProperties: bad property id')
        end
        local setter = behavior.setters[name]
        if actorId then
            if setter then
                setter(behavior, component, value, {
                    isOrigin = self.clientId == clientId,
                })
            else
                component.properties[name] = value
            end
        else
            if setter then
                setter(behavior, value, {
                    isOrigin = self.clientId == clientId,
                })
            else
                behavior.globals[name] = value
            end
        end
    end
end


-- Methods

function Common:sendAddActor(bp)
    local actorId = self:generateId()

    self:send('addActor', self.clientId, actorId)

    -- Add components in depth-first order through dependency graph

    local visited = {}
    local function visit(behaviorName, componentBp)
        if visited[behaviorName] then
            return
        end
        visited[behaviorName] = true

        componentBp = componentBp or bp[behaviorName]

        local behavior = self.behaviorsByName[behaviorName]
        if not behavior then
            error("addActor: no behavior '" .. behaviorName .. "'")
        end

        for dependencyName in pairs(behavior.dependencies) do
            visit(dependencyName)
        end

        self:send('addComponent', self.clientId, actorId, behavior.behaviorId, componentBp)
    end
    for behaviorName, componentBp in pairs(bp) do
        visit(behaviorName, componentBp)
    end

    return actorId
end

function Common:blueprintActor(actorId)
    local bp = {}

    local actor = assert(self.actors[actorId], 'blueprintActor: no such actor')

    -- Blueprint each component that isn't a tool
    for behaviorId, component in pairs(actor.components) do
        if not component.tool then
            local behavior = self.behaviors[component.behaviorId]
            local behaviorBp = {}
            behavior:callHandler('blueprintComponent', component, behaviorBp)
            bp[behavior.name] = behaviorBp
        end
    end

    return bp
end

function Common:callHandlers(handlerName, ...)
    local behaviors = self.behaviorsByHandler[handlerName]
    if behaviors then
        for behaviorId, behavior in pairs(behaviors) do
            behavior:callHandler(handlerName, ...)
        end
    end
end

