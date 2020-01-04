local Physics = require 'multi.physics'


local resource_loader = require 'resource_loader'


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0
SECONDARY_RELIABLE_CHANNEL = 99


-- Behavior base

local Behavior = {}

function Behavior:callHandler(handlerName, ...)
    local handler = self.handlers[handlerName]
    if handler then
        return handler(self, ...)
    end
end

function Behavior:forEachComponent(func)
    for actorId, component in pairs(self.game.behaviorActorComponent[self.behaviorId]) do
        func(component)
    end
end

function Behavior:getComponent(...)
    local behaviorId, actorId
    local nArgs = select('#', ...)
    if nArgs == 2 then
        local behaviorName
        behaviorName, actorId = ...
        behaviorId = self.game.nameBehaviors[behaviorName]
    else
        actorId = ...
        behaviorId = self.behaviorId
    end
    return self.game.behaviorActorComponent[behaviorId][actorId]
end

function Behavior:setProperties(opts, ...)
    local actorId, newOpts
    if type(opts) == 'table' then
        actorId = opts.actorId
        newOpts = setmetatable({ kind = 'setProperties' }, { __index = opts })
    else
        actorId = opts
        newOpts = 'setProperties'
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

    self.game:send(newOpts, actorId, self.behaviorId, propertyNamesToIds(...))
end


-- Body behavior

local BodyBehavior = {
    name = 'Body',
    propertyNames = {
        'worldId',
        'bodyId',
        'fixtureId',
    },
    handlers = {},
}

function BodyBehavior.handlers:addBehavior()
    self._physics = Physics.new({
        game = self.game,
        updateRate = 120,
        reliableChannel = MAIN_RELIABLE_CHANNEL,
    })

    if self.game.server then
        self:setProperties(nil, 'worldId', self._physics:newWorld(0, 32 * 9.8, true))
    end
end

function BodyBehavior.handlers:removeBehavior()
    self._physics:objectForId(self.globals.worldId):destroy()
end

function BodyBehavior.handlers:preSyncClient(clientId)
    self._physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })
end

function BodyBehavior.handlers:addComponent(component)
    -- TODO(nikki): If server, create body and set `bodyId`
    if self.game.server then
        local shapeId = self._physics:newRectangleShape(32, 32)
        local bodyId = self._physics:newBody(self.globals.worldId, 400, 200, 'dynamic')
        local fixtureId = self._physics:newFixture(bodyId, shapeId, 1)
        self._physics:destroyObject(shapeId)

        self:setProperties(component.actorId, 'bodyId', bodyId, 'fixtureId', fixtureId)
    end
end

function BodyBehavior.handlers:removeComponent(component)
    -- TODO(nikki): If server, destroy body
end

function BodyBehavior.handlers:perform(dt)
    self._physics:updateWorld(self.globals.worldId, dt)
    self._physics:sendSyncs(self.globals.worldId)
end

function BodyBehavior:getBody(actorId)
    local component = self.game.behaviorActorComponent[self.behaviorId][actorId]
    return self._physics:objectForId(component.properties.bodyId)
end


-- Image behavior

local ImageBehavior = {
    name = 'Image',
    propertyNames = {
        'url',
        'depth',
        'filter',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

function ImageBehavior.handlers:addComponent(component)
    component.properties.url = 'https://github.com/nikki93/edit-world/raw/master/assets/checkerboard.png'
    component.properties.depth = 0
    component.properties.filter = 'nearest'
end

function ImageBehavior.handlers:removeComponent(component)
end

function ImageBehavior.handlers:draw(order)
    self:forEachComponent(function(component)
        table.insert(order, {
            depth = component.properties.depth,
            draw = function()
                component._imageHolder = resource_loader.loadImage(component.properties.url, component.properties.filter)
                local image = component._imageHolder.image

                local body = self.dependencies.Body:getBody(component.actorId)

                love.graphics.draw(
                    image,
                    body:getX(), body:getY(),
                    body:getAngle(),
                    32 / image:getWidth(), 32 / image:getHeight(),
                    16, 16)
            end,
        })
    end)
end


-- Core behavior list

CORE_BEHAVIORS = {
    BodyBehavior,
    ImageBehavior,
}


-- Define

function Common:define()
    -- Users
    self:defineMessageKind('me', {
        reliable = true,
        channel = SECONDARY_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    })

    -- Actors / behaviors
    local reliableToAll = {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
        rate = 20,
    }
    self:defineMessageKind('addActor', reliableToAll)
    self:defineMessageKind('removeActor', reliableToAll)
    self:defineMessageKind('addBehavior', reliableToAll)
    self:defineMessageKind('removeBehavior', reliableToAll)
    self:defineMessageKind('addComponent', reliableToAll)
    self:defineMessageKind('removeComponent', reliableToAll)
    self:defineMessageKind('setProperties', reliableToAll)
end


-- Start / stop

function Common:start()
    -- Users

    self.mes = {}


    -- Actors / behaviors

    self.actors = {} -- `actorId` -> actor
    self.behaviors = {} -- `behaviorId` -> behavior
    self.nameBehavior = {} -- `behaviorName` -> behavior
    self.actorBehaviorComponent = {} -- `actorId` -> `behaviorId` -> component
    self.behaviorActorComponent = {} -- `behaviorId` -> `actorId` -> component
    self.handlerBehaviors = {} -- `handlerName` -> `behaviorId` -> `true`

    for behaviorId, behaviorSpec in pairs(CORE_BEHAVIORS) do
        self.receivers.addBehavior(self, 0, behaviorId, behaviorSpec)
    end
end

function Common:stop()
    for behaviorId, behavior in pairs(self.behaviors) do
        self.receivers.removeBehavior(self, 0, behaviorId)
    end
end


-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Actors / behaviors

function Common.receivers:addActor(time, actorId)
    assert(not self.actors[actorId], 'addActor: this `actorId` is already used')

    self.actors[actorId] = {}

    self.actorBehaviorComponent[actorId] = {}
end

function Common.receivers:removeActor(time, actorId)
    assert(self.actors[actorId], 'removeActor: no such actor')

    for behaviorId in pairs(self.actorBehaviorComponent[actorId]) do
        self.behaviorActorComponent[behaviorId][actorId] = nil
    end
    self.actorBehaviorComponent[actorId] = nil

    self.actors[actorId] = nil
end

function Common.receivers:addBehavior(time, behaviorId, behaviorSpec)
    assert(not self.behaviors[behaviorId], 'addBehavior: this `behaviorId` is already used')
    assert(behaviorSpec, 'addBehavior: need a `behaviorSpec`')

    -- Basics
    local behavior = setmetatable({}, { __index = Behavior })
    behavior.behaviorId = behaviorId
    behavior.behaviorSpec = behaviorSpec
    behavior.name = behaviorSpec.name
    behavior.game = self
    behavior.globals = {}

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
        behavior.dependencies[dependencyName] = assert(self.nameBehavior[dependencyName],
            "dependency '" .. dependencyName .. "' not resolved")
    end

    -- Set in maps
    self.behaviors[behaviorId] = behavior
    self.nameBehavior[behavior.name] = behavior
    self.behaviorActorComponent[behaviorId] = {}
    for handlerName in pairs(behavior.handlers) do
        if not self.handlerBehaviors[handlerName] then
            self.handlerBehaviors[handlerName] = {}
        end
        self.handlerBehaviors[handlerName][behaviorId] = true
    end

    -- Notify `addBehavior`
    behavior:callHandler('addBehavior')
end

function Common.receivers:removeBehavior(time, behaviorId)
    assert(self.behaviors[behaviorId], 'removeBehavior: this `behaviorId` is already used')

    -- Notify `removeBehavior`
    behavior:callHandler('removeBehavior')

    -- Unset in maps
    for handlerName in pairs(behavior.handlers) do
        self.handlerBehaviors[handlerName][behaviorId] = nil
        if not next(self.handlerBehaviors[handlerName]) then
            self.handlerBehaviors[handlerName] = nil
        end
    end
    for actorId in pairs(self.behaviorActorComponent[behaviorId]) do
        self.actorBehaviorComponent[actorId][behaviorId] = nil
    end
    self.behaviorActorComponent[behaviorId] = nil
    self.nameBehavior[behavior.name] = nil
    self.behaviors[behaviorId] = nil
end

function Common.receivers:addComponent(time, actorId, behaviorId)
    assert(self.actors[actorId], 'addComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'addComponent: no such behavior')

    -- Basics
    local component = {}
    component.actorId = actorId
    component.properties = {}

    -- Set in maps
    self.actorBehaviorComponent[actorId][behaviorId] = component
    self.behaviorActorComponent[behaviorId][actorId] = component

    -- Notify `addComponent`
    behavior:callHandler('addComponent', component)
end

function Common.receivers:removeComponent(time, actorId, behaviorId)
    assert(self.actors[actorId], 'removeComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'removeComponent: no such behavior')

    -- Notify `removeComponent`
    behavior:callHandler('removeComponent', self.actorBehaviorComponent[actorId][behaviorId])

    -- Unset in maps
    self.actorBehaviorComponent[actorId][behaviorId] = nil
    self.behaviorActorComponent[behaviorId][actorId] = nil
end

function Common.receivers:setProperties(time, actorId, behaviorId, ...)
    local behavior = assert(self.behaviors[behaviorId], 'setProperties: no such behavior')

    local component
    if actorId then
        assert(self.actors[actorId], 'setProperties: no such actor')
        component = self.actorBehaviorComponent[actorId][behaviorId]
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
                setter(behavior, component, value)
            else
                component.properties[name] = value
            end
        else
            if setter then
                setter(behavior, value)
            else
                behavior.globals[name] = value
            end
        end
    end
end

function Common:forEachBehaviorWithHandler(handlerName, func)
    local behaviors = self.handlerBehaviors[handlerName]
    if behaviors then
        for behaviorId in pairs(behaviors) do
            func(self.behaviors[behaviorId])
        end
    end
end


-- Update

function Common:update(dt)
    self:forEachBehaviorWithHandler('perform', function(behavior)
        behavior:callHandler('perform', dt)
    end)
end
