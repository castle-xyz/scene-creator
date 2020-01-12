local Physics = require 'multi.physics'
local ui = castle.ui


CHECKERBOARD_IMAGE_URL = 'https://raw.githubusercontent.com/nikki93/edit-world/4c9d0d6f92b3a67879c7a5714e6608530093b45a/assets/checkerboard.png'


serpent = require 'https://raw.githubusercontent.com/pkulchenko/serpent/879580fb21933f63eb23ece7d60ba2349a8d2848/src/serpent.lua'


resource_loader = require 'resource_loader'
util = require 'util'


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0
SECONDARY_RELIABLE_CHANNEL = 99


-- Behavior base

local Behavior = {}

function Behavior:callHandler(handlerName, ...)
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

function Behavior:sendSetProperties(opts, ...)
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

function Behavior:has(actorId)
    return not not self.components[actorId]
end

function Behavior:getTouchData()
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
        self:sendSetProperties(nil, 'worldId', self._physics:newWorld(0, 64 * 9.8, true))
    end
end

function BodyBehavior.handlers:removeBehavior(opts)
    local worldId, world = self:getWorld()
    if world then
        world:destroy()
    end
end

function BodyBehavior.handlers:preSyncClient(clientId)
    self._physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })
end

function BodyBehavior.handlers:addComponent(component, bp, opts)
    if opts.isOrigin then
        local bodyId = self._physics:newBody(self.globals.worldId,
            bp.x or 0, bp.y or 0,
            bp.bodyType or 'static')
        if bp.massData then
            self._physics:setMassData(bodyId, unpack(bp.massData))
        end
        if bp.fixedRotation ~= nil then
            self._physics:setFixedRotation(bodyId, bp.fixedRotation)
        end
        if bp.angle ~= nil then
            self._physics:setAngle(bodyId, bp.angle)
        end
        if bp.linearVelocity ~= nil then
            self._physics:setLinearVelocity(bodyId, unpack(bp.linearVelocity))
        end
        if bp.angularVelocity ~= nil then
            self._physics:setAngularVelocity(bodyId, bp.angularVelocity)
        end
        if bp.linearDamping ~= nil then
            self._physics:setLinearDamping(bodyId, bp.linearDamping)
        end
        if bp.angularDamping ~= nil then
            self._physics:setAngularDamping(bodyId, bp.angularDamping)
        end
        if bp.bullet ~= nil then
            self._physics:setBullet(bodyId, bp.bullet)
        end
        if bp.gravityScale ~= nil then
            self._physics:setGravityScale(bodyId, bp.gravityScale)
        end

        local fixtureBps = bp.fixture and { bp.fixture } or bp.fixtures
        if fixtureBps then
            for _, fixtureBp in ipairs(fixtureBps) do
                local shapeId
                local shapeType = fixtureBp.shapeType

                if shapeType == 'circle' then
                    shapeId = self._physics:newCircleShape(fixtureBp.x or 0, fixtureBp.y or 0, fixtureBp.radius or 64)
                elseif shapeType == 'polygon' then
                    shapeId = self._physics:newPolygonShape(unpack(assert(fixtureBp.points)))
                elseif shapeType == 'edge' then
                    shapeId = self._physics:newEdgeShape(unpack(assert(fixtureBp.points)))
                    self._physics:setPreviousVertex(unpack(assert(fixtureBp.previousVertex)))
                    self._physics:setNextVertex(unpack(assert(fixtureBp.nextVertex)))
                elseif shapeType == 'chain' then
                    shapeId = self._physics:newChainShape(unpack(assert(fixtureBp.points)))
                    self._physics:setPreviousVertex(unpack(assert(fixtureBp.previousVertex)))
                    self._physics:setNextVertex(unpack(assert(fixtureBp.nextVertex)))
                end

                local fixtureId = self._physics:newFixture(bodyId, shapeId, fixtureBp.density or 1)
                if fixtureBp.friction ~= nil then
                    self._physics:setFriction(fixtureId, fixtureBp.friction)
                end
                if fixtureBp.restitution ~= nil then
                    self._physics:setRestitution(fixtureId, fixtureBp.restitution)
                end
                if fixtureBp.sensor ~= nil then
                    self._physics:setSensor(fixtureId, fixtureBp.sensor)
                end

                self._physics:destroyObject(shapeId)
            end
        else -- Default shape
            local shapeId = self._physics:newRectangleShape(128, 128)
            local fixtureId = self._physics:newFixture(bodyId, shapeId, 1)
            self._physics:destroyObject(shapeId)
        end

        self._physics:setUserData(bodyId, component.actorId)
        self:sendSetProperties(component.actorId, 'bodyId', bodyId)
    end
end

function BodyBehavior.handlers:removeComponent(component, opts)
    if opts.isOrigin then
        self._physics:destroyObject(component.properties.bodyId)
    end
end

function BodyBehavior.handlers:blueprintComponent(component, bp)
    local bodyId, body = self:getBody(component)
    bp.x = body:getX()
    bp.y = body:getY()
    bp.bodyType = body:getType()
    bp.massData = { body:getMassData() }
    bp.fixedRotation = body:isFixedRotation()
    bp.angle = body:getAngle()
    bp.linearVelocity = { body:getLinearVelocity() }
    bp.angularVelocity = body:getAngularVelocity()
    bp.linearDamping = body:getLinearDamping()
    bp.angularDamping = body:getAngularDamping()
    bp.bullet = body:isBullet()
    bp.gravityScale = body:getGravityScale()

    bp.fixtures = {}
    for _, fixture in ipairs(body:getFixtures()) do
        local fixtureBp = {}

        local shape = fixture:getShape()
        local shapeType = shape:getType()
        fixtureBp.shapeType = shapeType
        if shapeType == 'circle' then
            fixtureBp.x, fixtureBp.y = shape:getPoint()
            fixtureBp.radius = shape:getRadius()
        elseif shapeType == 'polygon' then
            fixtureBp.points = { shape:getPoints() }
        elseif shapeType == 'edge' then
            fixtureBp.points = { shape:getPoints() }
            fixtureBp.previousVertex = { shape:getPreviousVertex() }
            fixtureBp.nextVertex = { shape:getNextVertex() }
        elseif shapeType == 'chain' then
            fixtureBp.points = { shape:getPoints() }
            fixtureBp.previousVertex = { shape:getPreviousVertex() }
            fixtureBp.nextVertex = { shape:getNextVertex() }
        end

        fixtureBp.density = fixture:getDensity()
        fixtureBp.friction = fixture:getFriction()
        fixtureBp.restitution = fixture:getRestitution()
        fixtureBp.sensor = fixture:isSensor()

        table.insert(bp.fixtures, fixtureBp)
    end
end

function BodyBehavior.handlers:prePerform(dt)
    self._physics:updateWorld(self.globals.worldId, dt)

    if self.game.server then -- Remove out-of-bound bodies
        for actorId, component in pairs(self.components) do
            local bodyId, body = self:getBody(component)
            local x, y = body:getPosition()
            if y > 1600 or y < -800 or x < -400 or x > 800 + 400 then
                self.game:send('removeActor', self.clientId, actorId)
            end
        end
    end
end

function BodyBehavior.handlers:postUpdate(dt)
    -- Do this in `postUpdate` so it's after tool updates
    if self.game.performing then
        self._physics:sendSyncs(self.globals.worldId)
    end
end

function BodyBehavior.handlers:setPerforming(performing)
    if performing then 
        -- Wake up all non-static bodies when performance starts, because things may have moved
        for actorId, component in pairs(self.components) do
            local bodyId, body = self:getBody(component)
            if body:getType() ~= 'static' then
                body:setAwake(true)
            end
        end
    else
        -- Send a final reliable sync when performance stops, because we'll stop sending
        -- continuous syncs
        self._physics:sendSyncs({
            reliable = true,
            channel = MAIN_RELIABLE_CHANNEL,
        }, self.globals.worldId)
    end
end

function BodyBehavior.handlers:uiComponent(component, opts)
    local bodyId, body = self:getBody(component)

    ui.tabs('body properties', function()
        ui.tab('basic', function()
            util.uiRow('position', function()
                ui.numberInput('x', body:getX(), {
                    onChange = function(newX)
                        self._physics:setX(bodyId, newX)
                    end,
                })
            end, function()
                ui.numberInput('y', body:getY(), {
                    onChange = function(newY)
                        self._physics:setY(bodyId, newY)
                    end,
                })
            end)
            ui.numberInput('angle (degrees)', body:getAngle() * 180 / math.pi, {
                onChange = function(newAngle)
                    self._physics:setAngle(bodyId, newAngle * math.pi / 180)
                end,
            })
        end)

        ui.tab('shape', function()
            local fixtures = body:getFixtures()
            local fixture = fixtures[1]
            if fixture then
                local fixtureId = self._physics:idForObject(fixture)

                local function recreateFixture(newShapeId)
                    local oldFixtureId = fixtureId
                    fixtureId = self._physics:newFixture(bodyId, newShapeId, fixture:getDensity())
                    self._physics:setFriction(fixtureId, fixture:getFriction())
                    self._physics:setRestitution(fixtureId, fixture:getRestitution())
                    self._physics:setSensor(fixtureId, fixture:isSensor())
                    self._physics:destroyObject(newShapeId)
                    self._physics:destroyObject(oldFixtureId)
                end

                local shape = fixture:getShape()
                local shapeType = shape:getType()

                local displayShapeType = shapeType
                local rectangleWidth, rectangleHeight
                if shapeType == 'polygon' then
                    local p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, p5x = shape:getPoints()
                    if p4y ~= nil and p5x == nil then
                        if p1y == p2y and p1x == -p2x and p1x == p4x and p1y == -p4y and p2x == p3x and p2y == -p3y then
                            displayShapeType = 'rectangle'
                            rectangleWidth = 2 * math.abs(p1x)
                            rectangleHeight = 2 * math.abs(p1y)
                        end
                        if p1x == p2x and p1y == -p2y and p1y == p4y and p1x == -p4x and p2y == p3y and p2x == -p3x then
                            displayShapeType = 'rectangle'
                            rectangleWidth = 2 * math.abs(p1x)
                            rectangleHeight = 2 * math.abs(p1y)
                        end
                    end
                end

                ui.dropdown('type', displayShapeType, { 'circle', 'rectangle', 'polygon', 'chain' }, {
                    onChange = function(newDisplayShapeType)
                        if newDisplayShapeType == displayShapeType then
                            return
                        end

                        if newDisplayShapeType == 'circle' then
                            recreateFixture(self._physics:newCircleShape(0, 0, 64))
                        elseif newDisplayShapeType == 'rectangle' then
                            recreateFixture(self._physics:newRectangleShape(128, 128))
                        end
                    end
                })

                if displayShapeType == 'circle' then
                    local x, y = shape:getPoint()
                    local radius = shape:getRadius()

                    ui.numberInput('radius', radius, {
                        min = 0,
                        onChange = function(newRadius)
                            recreateFixture(self._physics:newCircleShape(x, y, newRadius))
                        end,
                    })
                elseif displayShapeType == 'rectangle' then
                    util.uiRow('rectangle-size', function()
                        ui.numberInput('width', rectangleWidth, {
                            min = 0,
                            onChange = function(newRectangleWidth)
                                recreateFixture(self._physics:newRectangleShape(newRectangleWidth, rectangleHeight))
                            end,
                        })
                    end, function()
                        ui.numberInput('height', rectangleHeight, {
                            min = 0,
                            onChange = function(newRectangleHeight)
                                recreateFixture(self._physics:newRectangleShape(rectangleWidth, newRectangleHeight))
                            end,
                        })
                    end)
                end
            end
        end)

        ui.tab('motion', function()
            local bodyType = body:getType()

            local function typeDropdown()
                ui.dropdown('type', bodyType, { 'static', 'dynamic', 'kinematic' }, {
                    onChange = function(newType)
                        if newType and newType ~= body:getType() then
                            bodyType = newType
                            self._physics:setType(bodyId, newType)
                        end
                    end,
                })
            end

            if bodyType == 'dynamic' then
                util.uiRow('type-and-mass', typeDropdown, function()
                    ui.numberInput('mass', body:getMass(), {
                        min = 0,
                        onChange = function(newMass)
                            self._physics:setMass(bodyId, newMass)
                        end,
                    })
                end)
            else
                typeDropdown()
            end

            if bodyType == 'dynamic' or bodyType == 'kinematic' then
                local vx, vy = body:getLinearVelocity()
                util.uiRow('linear velocity', function()
                    ui.numberInput('velocity x', vx, {
                        onChange = function(newVX)
                            self._physics:setLinearVelocity(bodyId, newVX, vy)
                        end,
                    })
                end, function()
                    ui.numberInput('velocity y', vy, {
                        onChange = function(newVY)
                            self._physics:setLinearVelocity(bodyId, vx, newVY)
                        end,
                    })
                end)

                local function rotationSpeedInput()
                    ui.numberInput('rotation speed (degrees)', body:getAngularVelocity() * 180 / math.pi, {
                        onChange = function(newAV)
                            self._physics:setAngularVelocity(bodyId, newAV * math.pi / 180)
                        end,
                    })
                end

                if bodyType == 'dynamic' then
                    local isFixedRotation = body:isFixedRotation()

                    local function fixedRotationToggle()
                        ui.toggle('fixed rotation off', 'fixed rotation on', isFixedRotation, {
                            onToggle = function(newFixedRotation)
                                self._physics:setFixedRotation(bodyId, newFixedRotation)
                            end,
                        })
                    end

                    if isFixedRotation then
                        fixedRotationToggle()
                    else
                        util.uiRow('rotation-speed-and-fixed-rotation', rotationSpeedInput, fixedRotationToggle)
                    end
                else
                    rotationSpeedInput()
                end
            end

            if bodyType == 'dynamic' then
                ui.numberInput('gravity scale', body:getGravityScale(), {
                    onChange = function(newGravityScale)
                        self._physics:setGravityScale(bodyId, newGravityScale)
                    end,
                })

                util.uiRow('damping', function()
                    ui.numberInput('linear damping', body:getLinearDamping(), {
                        step = 0.05,
                        onChange = function(newLinearDamping)
                            self._physics:setLinearDamping(bodyId, newLinearDamping)
                        end,
                    })
                end, function()
                    ui.numberInput('angular damping', body:getAngularDamping(), {
                        step = 0.05,
                        onChange = function(newAngularDamping)
                            self._physics:setAngularDamping(bodyId, newAngularDamping)
                        end,
                    })
                end)
            end
        end)
    end)
end

function BodyBehavior:getPhysics()
    return self._physics
end

function BodyBehavior:getWorld()
    return self.globals.worldId, self._physics:objectForId(self.globals.worldId)
end

function BodyBehavior:getBody(componentOrActorId)
    local component = type(componentOrActorId) == 'table' and componentOrActorId or self.components[componentOrActorId]
    if component then
        local bodyId = component.properties.bodyId
        return bodyId, self._physics:objectForId(bodyId)
    end
end

function BodyBehavior:getActorForBody(body)
    return body:getUserData()
end

function BodyBehavior:getActorsAtPoint(x, y)
    local hits = {}
    local worldId, world = self:getWorld()
    if world then
        world:queryBoundingBox(
            x - 1, y - 1, x + 1, y + 1,
            function(fixture)
                if fixture:testPoint(x, y) then
                    local actorId = self:getActorForBody(fixture:getBody())
                    if actorId then
                        hits[actorId] = true
                    end
                end
                return true
            end)
    end
    return hits
end

function BodyBehavior:drawBodyOutline(componentOrActorId)
    local bodyId, body = self:getBody(componentOrActorId)
    if body then
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
end


-- Image behavior

local ImageBehavior = {
    name = 'Image',
    propertyNames = {
        'url',
        'width',
        'height',
        'depth',
        'filter',
        'fitMode',
        'cropEnabled',
        'cropX',
        'cropY',
        'cropWidth',
        'cropHeight',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

function ImageBehavior.handlers:addComponent(component, bp, opts)
    component.properties.url = bp.url or CHECKERBOARD_IMAGE_URL
    component.properties.width = bp.width or 128
    component.properties.height = bp.height or 128
    component.properties.depth = bp.depth or 0
    component.properties.filter = bp.filter or 'nearest'
    component.properties.fitMode = bp.fitMode or 'contain'
    if bp.cropEnabled ~= nil then
        component.properties.cropEnabled = bp.cropEnabled
    else
        component.properties.cropEnabled = false
    end
    component.properties.cropX = bp.cropX or 0
    component.properties.cropY = bp.cropY or 0
    component.properties.cropWidth = bp.cropWidth or 32
    component.properties.cropHeight = bp.cropHeight or 32
end

function ImageBehavior.handlers:removeComponent(component, opts)
end

function ImageBehavior.handlers:blueprintComponent(component, bp)
    bp.url = component.properties.url
    bp.width = component.properties.width
    bp.height = component.properties.height
    bp.depth = component.properties.depth
    bp.filter = component.properties.filter
    bp.fitMode = component.properties.fitMode
    bp.cropEnabled = component.properties.cropEnabled
    bp.cropX = component.properties.cropX
    bp.cropY = component.properties.cropY
    bp.cropWidth = component.properties.cropWidth
    bp.cropHeight = component.properties.cropHeight
end

local theTransform = love.math.newTransform()
local theQuad = love.graphics and love.graphics.newQuad(0, 0, 32, 32, 32, 32)

function ImageBehavior.handlers:draw(order)
    for actorId, component in pairs(self.components) do
        table.insert(order, {
            id = actorId,
            depth = component.properties.depth,
            draw = function()
                component._imageHolder = resource_loader.loadImage(
                    component.properties.localUrl or component.properties.url,
                    component.properties.filter)
                local image = component._imageHolder.image
                local imageWidth, imageHeight = image:getDimensions()

                local quad
                if component._imageHolder.loaded and component.properties.cropEnabled then
                    theQuad:setViewport(component.properties.cropX, component.properties.cropY,
                        component.properties.cropWidth, component.properties.cropHeight,
                        imageWidth, imageHeight)
                    imageWidth, imageHeight = component.properties.cropWidth, component.properties.cropHeight
                else
                    theQuad:setViewport(0, 0, imageWidth, imageHeight, imageWidth, imageHeight)
                end

                local scaleX, scaleY = component.properties.width / imageWidth, component.properties.height / imageHeight
                if component._imageHolder.loaded and component.properties.fitMode == 'contain' then
                    scaleX = math.min(scaleX, scaleY)
                    scaleY = scaleX
                end

                local bodyId, body = self.dependencies.Body:getBody(actorId)

                love.graphics.draw(
                    image,
                    theQuad,
                    body:getX(), body:getY(),
                    body:getAngle(),
                    scaleX, scaleY,
                    0.5 * imageWidth, 0.5 * imageHeight)
            end,
        })
    end
end

function ImageBehavior.handlers:uiComponent(component, opts)
    ui.filePicker(component.properties.localUrl and 'image (uploading...)' or 'image',
        component.properties.localUrl or component.properties.url, {
        id = 'image',
        type = 'image',
        onChange = function(newUrl)
            if not newUrl then
                self:sendSetProperties(component.actorId, 'url', CHECKERBOARD_IMAGE_URL)
            elseif newUrl:match('^file://') then
                component.properties.localUrl = newUrl
            else
                component.properties.localUrl = nil
                self:sendSetProperties(component.actorId, 'url', newUrl)
            end
        end,
    })

    util.uiRow('size', function()
        ui.numberInput('width', component.properties.width, {
            min = 0,
            onChange = function(newWidth)
                self:sendSetProperties(component.actorId, 'width', newWidth)
            end,
        })
    end, function()
        ui.numberInput('height', component.properties.height, {
            min = 0,
            onChange = function(newHeight)
                self:sendSetProperties(component.actorId, 'height', newHeight)
            end,
        })
    end)

    util.uiRow('fit-mode-and-scaling-style', function()
        ui.dropdown('fit mode', component.properties.fitMode, { 'contain', 'stretch' }, {
            onChange = function(newFitMode)
                self:sendSetProperties(component.actorId, 'fitMode', newFitMode)
            end,
        })
    end, function()
        ui.dropdown('scaling style',
            component.properties.filter == 'nearest' and 'pixelated' or 'smooth', { 'pixelated', 'smooth' }, {
            onChange = function(newScalingStyle)
                if newScalingStyle == 'pixelated' then
                    self:sendSetProperties(component.actorId, 'filter', 'nearest')
                elseif newScalingStyle == 'smooth' then
                    self:sendSetProperties(component.actorId, 'filter', 'linear')
                end
            end,
        })
    end)

    ui.numberInput('depth', component.properties.depth, {
        onChange = function(newDepth)
            self:sendSetProperties(component.actorId, 'depth', newDepth)
        end,
    })

    util.uiRow('crop', function()
        ui.toggle('crop off', 'crop on', component.properties.cropEnabled, {
            onToggle = function(newCropEnabled)
                component.properties.cropEnabled = newCropEnabled
            end,
        })
    end, function()
        if component.properties.cropEnabled and component._imageHolder then
            local image = component._imageHolder.image
            local imageWidth, imageHeight = image:getDimensions()
            ui.markdown('base image is ' .. imageWidth .. ' by ' .. imageHeight)
        end
    end)
    if component.properties.cropEnabled then
        util.uiRow('crop-position', function()
            ui.numberInput('crop x', component.properties.cropX, {
                onChange = function(newCropX)
                    self:sendSetProperties(component.actorId, 'cropX', newCropX)
                end,
            })
        end, function()
            ui.numberInput('crop y', component.properties.cropY, {
                onChange = function(newCropY)
                    self:sendSetProperties(component.actorId, 'cropY', newCropY)
                end,
            })
        end)
        util.uiRow('crop-size', function()
            ui.numberInput('crop width', component.properties.cropWidth, {
                onChange = function(newCropWidth)
                    self:sendSetProperties(component.actorId, 'cropWidth', newCropWidth)
                end,
            })
        end, function()
            ui.numberInput('crop height', component.properties.cropHeight, {
                onChange = function(newCropHeight)
                    self:sendSetProperties(component.actorId, 'cropHeight', newCropHeight)
                end,
            })
        end)
    end
end


-- Grab behavior

local GrabBehavior = {
    name = 'Grab',
    propertyNames = {
    },
    dependencies = {
        'Body',
    },
    handlers = {},
    tool = {
        icon = 'move',
        iconFamily = 'Feather',
    },
}

function GrabBehavior.handlers:update(dt)
    local physics = self.dependencies.Body:getPhysics()
    local touchData = self:getTouchData()

    if touchData.numTouches == 1 or touchData.numTouches == 2 then
        local moveX, moveY = 0, 0
        local centerX, centerY
        local rotation
        local cosRotation, sinRotation

        if touchData.numTouches == 1 then -- Pure-move
            local touchId, touch = next(touchData.touches)
            moveX, moveY = touch.dx, touch.dy
        elseif touchData.numTouches == 2 then -- Move and rotate
            local touchId1, touch1 = next(touchData.touches)
            local touchId2, touch2 = next(touchData.touches, touchId1)

            local touch1PrevX, touch1PrevY = touch1.x - touch1.dx, touch1.y - touch1.dy
            local touch2PrevX, touch2PrevY = touch2.x - touch2.dx, touch2.y - touch2.dy

            centerX, centerY = 0.5 * (touch1.x + touch2.x), 0.5 * (touch1.y + touch2.y)
            local centerPrevX, centerPrevY = 0.5 * (touch1PrevX + touch2PrevX), 0.5 * (touch1PrevY + touch2PrevY)

            moveX, moveY = centerX - centerPrevX, centerY - centerPrevY

            local angle = math.atan2(touch2.y - touch1.y, touch2.x - touch1.x)
            local prevAngle = math.atan2(touch2PrevY - touch1PrevY, touch2PrevX - touch1PrevX)
            rotation = angle - prevAngle
            cosRotation, sinRotation = math.cos(rotation), math.sin(rotation)
        end

        if not (moveX == 0 and moveY == 0 and (rotation == nil or rotation == 0)) then
            -- If an actual motion is happening and performance is on, turn it off
            if self.game.performing then
                self.game:send('setPerforming', false)
            end
        end

        for actorId, component in pairs(self.components) do
            if self.game.clientId == component.clientId then
                local bodyId, body = self.dependencies.Body:getBody(actorId)

                local x, y
                local angle

                -- We use these `.save` values to override stale incoming updates to the body
                -- from other hosts that had not yet received the `setPerforming` message
                if component.save then
                    x, y = component.save.x, component.save.y
                    angle = component.save.angle
                else
                    x, y = body:getPosition()
                    angle = body:getAngle()
                end

                local newX, newY, newAngle
                if rotation then
                    local lX, lY = x - centerX, y - centerY
                    lX = cosRotation * lX - sinRotation * lY
                    lY = sinRotation * lX + cosRotation * lY
                    newX, newY = centerX + moveX + lX, centerY + moveY + lY
                    newAngle = angle + rotation
                else
                    newX, newY = x + moveX, y + moveY
                    newAngle = angle
                end

                -- When not performing we need to actually send the sync messages. We also
                -- send a reliable message on touch release to make sure the final state is
                -- reflected.
                local sendOpts = {
                    reliable = touchData.allTouchesReleased,
                    channel = touchData.allTouchesReleased and physics.reliableChannel or nil,
                }
                physics:setPosition(sendOpts, bodyId, newX, newY)
                if body:getType() == 'dynamic' then
                    physics:setLinearVelocity(sendOpts, bodyId, 0, 0)
                    physics:setAngularVelocity(sendOpts, bodyId, 0)
                end
                physics:setAngle(sendOpts, bodyId, newAngle)

                -- Write back to `.save`, or clear it out if the gesture ended
                if touchData.allTouchesReleased then
                    component.save = nil
                else
                    component.save = {}
                    component.save.x, component.save.y = newX, newY
                    component.save.angle = newAngle
                end
            end
        end
    end
end


-- Core behavior list

CORE_BEHAVIORS = {
    BodyBehavior,
    ImageBehavior,
    GrabBehavior,
}


-- Define

function Common:define()
    local reliableToAll = {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
        rate = 20, -- In case a `reliable = false` override is used
    }

    -- Users
    self:defineMessageKind('me', {
        reliable = true,
        channel = SECONDARY_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    })

    -- Actors / behaviors
    self:defineMessageKind('addActor', reliableToAll)
    self:defineMessageKind('removeActor', reliableToAll)
    self:defineMessageKind('addBehavior', reliableToAll)
    self:defineMessageKind('removeBehavior', reliableToAll)
    self:defineMessageKind('addComponent', reliableToAll)
    self:defineMessageKind('removeComponent', reliableToAll)
    self:defineMessageKind('setProperties', reliableToAll)

    -- Library
    self:defineMessageKind('addLibraryEntry', reliableToAll)

    -- Performance
    self:defineMessageKind('setPerforming', reliableToAll)
end


-- Start / stop

function Common:start()
    -- Users

    self.mes = {}


    -- Actors / behaviors

    self.actors = {} -- `actorId` -> actor
    self.behaviors = {} -- `behaviorId` -> behavior
    self.behaviorsByName = {} -- `behaviorName` -> behavior
    self.behaviorsByHandler = {} -- `handlerName` -> `behaviorId` -> behavior
    self.tools = {} -- `behaviorId` -> behavior, for tool behaviors

    for behaviorId, behaviorSpec in pairs(CORE_BEHAVIORS) do
        self.receivers.addBehavior(self, 0, self.clientId, behaviorId, behaviorSpec)
    end


    -- Library

    self.library = {} -- `entryId` -> entry


    -- Performance

    self.performing = false
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

function Common:sendAddActor(bp)
    local actorId = self:generateId()

    self:send('addActor', self.clientId, actorId)

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

function Common:callHandlers(handlerName, ...)
    local behaviors = self.behaviorsByHandler[handlerName]
    if behaviors then
        for behaviorId, behavior in pairs(behaviors) do
            behavior:callHandler(handlerName, ...)
        end
    end
end

function Common:blueprintActor(actorId)
    local bp = {}

    local actor = assert(self.actors[actorId], 'blueprintActor: no such actor')

    for behaviorId, component in pairs(actor.components) do
        local behavior = self.behaviors[component.behaviorId]
        local behaviorBp = {}
        behavior:callHandler('blueprintComponent', component, behaviorBp)
        bp[behavior.name] = behaviorBp
    end

    return bp
end


-- Library

function Common.receivers:addLibraryEntry(time, entryId, entry)
    local entryCopy = util.deepCopyTable(entry)
    entryCopy.entryId = entryId
    self.library[entryId] = entryCopy
end


-- Performance

function Common:updatePerformance(dt)
    if self.performing then
        self:callHandlers('prePerform', dt)
        self:callHandlers('perform', dt)
        self:callHandlers('postPerform', dt)
    end
end

function Common.receivers:setPerforming(time, performing)
    if self.performing ~= performing then
        self.performing = performing
        self:callHandlers('setPerforming', performing)
    end
end


-- Update

function Common:update(dt)
    self:updatePerformance(dt)

    self:callHandlers('preUpdate', dt)
    self:callHandlers('update', dt)
    self:callHandlers('postUpdate', dt)
end
