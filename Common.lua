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

function Behavior:setProperties(opts, ...)
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

    self.game:send(sendOpts, actorId, self.behaviorId, propertyNamesToIds(...))
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

function BodyBehavior.handlers:addBehavior(opts)
    self._physics = Physics.new({
        game = self.game,
        updateRate = 120,
        reliableChannel = MAIN_RELIABLE_CHANNEL,
    })

    if self.game.server then
        self:setProperties(nil, 'worldId', self._physics:newWorld(0, 1, true))
    end
end

function BodyBehavior.handlers:removeBehavior(opts)
    self:getWorld():destroy()
end

function BodyBehavior.handlers:preSyncClient(clientId)
    self._physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })
end

function BodyBehavior.handlers:addComponent(component, opts)
    if opts.isOrigin then
        local bodyId = self._physics:newBody(self.globals.worldId, math.random(800), math.random(450), 'dynamic')
        self._physics:setGravityScale(bodyId, 0)

        local shapeId = self._physics:newRectangleShape(32, 32)
        local fixtureId = self._physics:newFixture(bodyId, shapeId, 1)
        self._physics:destroyObject(shapeId)

        self._physics:setUserData(bodyId, component.actorId)
        self:setProperties(component.actorId, 'bodyId', bodyId)
    end
end

function BodyBehavior.handlers:removeComponent(component, opts)
    if opts.isOrigin then
        self._physics:destroyObject(component.properties.bodyId)
    end
end

function BodyBehavior.handlers:perform(dt)
    self._physics:updateWorld(self.globals.worldId, dt)
    self._physics:sendSyncs(self.globals.worldId)
end

function BodyBehavior.handlers:draw(order)
    local world = self:getWorld()
    if world then
        table.insert(order, {
            depth = 100,
            draw = function()
                love.graphics.push('all')
                love.graphics.setColor(0, 1, 0)
                for _, body in ipairs(world:getBodies()) do
                    for _, fixture in ipairs(body:getFixtures()) do
                        local shape = fixture:getShape()
                        local ty = shape:getType()
                        if ty == 'circle' then
                            love.graphics.circle('line', body:getX(), body:getY(), shape:getRadius())
                        elseif ty == 'polygon' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        elseif ty == 'edge' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        elseif ty == 'chain' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        end
                    end
                end
                love.graphics.pop()
            end,
        })
    end
end

function BodyBehavior:getWorld()
    return self._physics:objectForId(self.globals.worldId)
end

function BodyBehavior:getBody(actorId)
    return self._physics:objectForId(self.components[actorId].properties.bodyId)
end

function BodyBehavior:getActorForBody(body)
    return body:getUserData()
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

function ImageBehavior.handlers:addComponent(component, opts)
    component.properties.url = 'https://raw.githubusercontent.com/nikki93/edit-world/4c9d0d6f92b3a67879c7a5714e6608530093b45a/assets/checkerboard.png'
    component.properties.depth = 0
    component.properties.filter = 'nearest'
end

function ImageBehavior.handlers:removeComponent(component, opts)
end

function ImageBehavior.handlers:draw(order)
    for actorId, component in pairs(self.components) do
        table.insert(order, {
            depth = component.properties.depth,
            draw = function()
                component._imageHolder = resource_loader.loadImage(component.properties.url, component.properties.filter)
                local image = component._imageHolder.image
                local width, height = image:getDimensions()

                local body = self.dependencies.Body:getBody(actorId)

                love.graphics.draw(
                    image,
                    body:getX(), body:getY(),
                    body:getAngle(),
                    32 / width, 32 / height,
                    0.5 * width, 0.5 * height)
            end,
        })
    end
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
    self.behaviorsByName = {} -- `behaviorName` -> behavior
    self.behaviorsByHandler = {} -- `handlerName` -> `behaviorId` -> `true`

    for behaviorId, behaviorSpec in pairs(CORE_BEHAVIORS) do
        self.receivers.addBehavior(self, 0, self.clientId, behaviorId, behaviorSpec)
    end
end

function Common:stop()
    for behaviorId, behavior in pairs(self.behaviors) do
        self.receivers.removeBehavior(self, 0, self.clientId, behaviorId)
    end
end


-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Actors / behaviors

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
    local behavior = setmetatable({}, { __index = Behavior })
    behavior.behaviorId = behaviorId
    behavior.behaviorSpec = behaviorSpec
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

    -- Set in maps
    self.behaviors[behaviorId] = behavior
    self.behaviorsByName[behavior.name] = behavior
    for handlerName in pairs(behavior.handlers) do
        if not self.behaviorsByHandler[handlerName] then
            self.behaviorsByHandler[handlerName] = {}
        end
        self.behaviorsByHandler[handlerName][behaviorId] = true
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

function Common.receivers:addComponent(time, clientId, actorId, behaviorId)
    local actor = assert(self.actors[actorId], 'addComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'addComponent: no such behavior')

    local component = {}
    component.actorId = actorId
    component.behaviorId = behaviorId
    component.properties = {}

    actor.components[behaviorId] = component
    behavior.components[actorId] = component

    behavior:callHandler('addComponent', component, {
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

function Common.receivers:setProperties(time, actorId, behaviorId, ...)
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
    local behaviors = self.behaviorsByHandler[handlerName]
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
