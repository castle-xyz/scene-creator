local Physics = require 'multi.physics'


love.physics.setMeter(64)


local BodyBehavior = {
    name = 'Body',
    propertyNames = {
        'worldId',
        'bodyId',
        'fixtureId',
    },
    handlers = {},
    description = table.concat {
        'Gives the actor a position in the scene along with an angle and a shape. All actors have ',
        'this behavior.',
        '\n',
        'The actor gets a rectangular shape by default, but other behaviors can be used to change ',
        'the shape.',
    }
}

registerCoreBehavior(1, BodyBehavior)


-- Behavior management

function BodyBehavior.handlers:addBehavior(opts)
    -- Create a local `Physics` at every host
    self._physics = Physics.new({
        game = self.game,
        updateRate = 120,
        reliableChannel = MAIN_RELIABLE_CHANNEL,
    })

    if self.game.server then
        -- If server, create a new world
        self:sendSetProperties(nil, 'worldId', self._physics:newWorld(0, 64 * 9.8, true))
    end
end

function BodyBehavior.handlers:removeBehavior(opts)
    -- Destroy the local copy of the world
    local worldId, world = self:getWorld()
    if world then
        world:destroy()
    end
end

function BodyBehavior.handlers:preSyncClient(clientId)
    -- Sync the world to the new client
    self._physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })
end


-- Component management

function BodyBehavior.handlers:addComponent(component, bp, opts)
    if opts.isOrigin then
        -- At the origin, create the physics body and fixtures and shapes. Other hosts will receive
        -- them through sync

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

        -- Associate the component with the underlying body
        self._physics:setUserData(bodyId, component.actorId)
        self:sendSetProperties(component.actorId, 'bodyId', bodyId)
    end
end

function BodyBehavior.handlers:removeComponent(component, opts)
    if opts.isOrigin then
        -- At the origin, destroy the body. Associated fixtures and shapes will automatically be
        -- destroyed. Other hosts will receive the destructions through sync.

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

function BodyBehavior.handlers:addDependentComponent(addedComponent)
    -- Promote body type based on what dependents request. The order is: static, kinematic, dynamic.
    -- Bodies are static by default. A request for a higher type always wins.

    local addedBehavior = self:getOtherBehavior(addedComponent.behaviorId)
    local addedBodyType = addedBehavior:callHandler('bodyTypeComponent', addedComponent)
    if addedBodyType then
        local actor = self:getActor(addedComponent.actorId)

        local finalBodyType = addedBodyType
        if finalBodyType ~= 'dynamic' then -- Dynamic always wins
            for otherBehaviorId, otherComponent in pairs(actor.components) do
                if otherBehaviorId ~= addedComponent.behaviorId then
                    local otherBehavior = self:getOtherBehavior(otherBehaviorId)
                    local otherBodyType = otherBehavior:callHandler('bodyTypeComponent', otherComponent)
                    if otherBodyType then
                        if otherBodyType == 'dynamic' then -- Dynamic always wins
                            finalBodyType = 'dynamic'
                            return
                        elseif otherBodyType == 'kinematic' then -- Promote to kinematic from static
                            finalBodyType = 'kinematic'
                        end
                    end
                end
            end
        end

        local bodyId, body = self:getBody(addedComponent.actorId)
        if body:getType() ~= finalBodyType then
            self._physics:setType(bodyId, finalBodyType)
        end
    end
end

function BodyBehavior.handlers:removeDependentComponent(removedComponent)
    -- Demote body type based on removal of dependents.

    local removedBehavior = self:getOtherBehavior(removedComponent.behaviorId)
    local removedBodyType = removedBehavior:callHandler('bodyTypeComponent', removedComponent)
    if removedBodyType then
        local actor = self:getActor(removedComponent.actorId)

        local finalBodyType = 'static'
        for otherBehaviorId, otherComponent in pairs(actor.components) do
            if otherBehaviorId ~= removedComponent.behaviorId then
                local otherBehavior = self:getOtherBehavior(otherBehaviorId)
                local otherBodyType = otherBehavior:callHandler('bodyTypeComponent', otherComponent)
                if otherBodyType then
                    if otherBodyType == 'dynamic' then -- Dynamic always wins
                        finalBodyType = 'dynamic'
                        return
                    elseif otherBodyType == 'kinematic' then -- Promote to kinematic from static
                        finalBodyType = 'kinematic'
                    end
                end
            end
        end

        local bodyId, body = self:getBody(removedComponent.actorId)
        if body:getType() ~= finalBodyType then
            self._physics:setType(bodyId, finalBodyType)
        end
    end
end


-- Perform / update

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


-- UI

function BodyBehavior.handlers:uiComponent(component, opts)
    local bodyId, body = self:getBody(component)

    ui.tabs('body properties', function()
        ui.tab('basic', function()
            -- Position and angle inputs
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

            local fixture = body:getFixtures()[1]
            if fixture then
                local shape = fixture:getShape()
                local shapeType = shape:getType()

                -- Width and height inputs if rectangle shaped
                local rectangleWidth, rectangleHeight
                if shapeType == 'polygon' then
                    local p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, p5x = shape:getPoints()
                    if p4y ~= nil and p5x == nil then
                        if (p1y == p2y and p1x == -p2x and p1x == p4x and p1y == -p4y and p2x == p3x and p2y == -p3y) or
                            (p1x == p2x and p1y == -p2y and p1y == p4y and p1x == -p4x and p2y == p3y and p2x == -p3x) then
                            rectangleWidth, rectangleHeight = 2 * math.abs(p1x), 2 * math.abs(p1y)
                        end
                    end
                end
                if rectangleWidth and rectangleHeight then
                    util.uiRow('rectangle-size', function()
                        ui.numberInput('width', rectangleWidth, {
                            min = 0,
                            onChange = function(newRectangleWidth)
                                self:replaceShape(component, self._physics:newRectangleShape(newRectangleWidth, rectangleHeight))
                            end,
                        })
                    end, function()
                        ui.numberInput('height', rectangleHeight, {
                            min = 0,
                            onChange = function(newRectangleHeight)
                                self:replaceShape(component, self._physics:newRectangleShape(rectangleWidth, newRectangleHeight))
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


-- Methods

function BodyBehavior:replaceShape(componentOrActorId, newShapeId)
    local bodyId, body = self:getBody(componentOrActorId)
    local fixture = body:getFixtures()[1]
    if fixture then
        local fixtureId = self._physics:idForObject(fixture)

        local newFixtureId = self._physics:newFixture(bodyId, newShapeId, fixture:getDensity())
        self._physics:destroyObject(newShapeId)

        self._physics:setFriction(newFixtureId, fixture:getFriction())
        self._physics:setRestitution(newFixtureId, fixture:getRestitution())
        self._physics:setSensor(newFixtureId, fixture:isSensor())

        self._physics:destroyObject(fixtureId)

        return newFixtureId
    end
end


-- Getters

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

function BodyBehavior:getSize(actorId)
    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    local bodyId, body = self:getBody(component)
    local fixture = body:getFixtures()[1]
    if fixture then
        -- Cache the size so we don't recompute it every time. This is made easier by the fact that
        -- fixtures are immutable -- we can use them as a cache key.
        local sizeCache = component._sizeCache
        if not sizeCache then
            sizeCache = setmetatable({}, { __mode = 'k' })
            component._sizeCache = sizeCache
        end
        local cached = sizeCache[fixture]
        if not cached then
            cached = {}
            sizeCache[fixture] = cached

            local shape = fixture:getShape()
            local shapeType = shape:getType()

            if shapeType == 'circle' then
                local radius = shape:getRadius()
                cached.width, cached.height = 2 * radius, 2 * radius
            elseif shapeType == 'polygon' or shapeType == 'edge' or shapeType == 'chain' then
                local points = { shape:getPoints() }
                local minX, minY, maxX, maxY = points[1], points[2], points[1], points[2]
                for i = 3, #points - 1, 2 do
                    minX, minY = math.min(minX, points[i]), math.min(minY, points[i + 1])
                    maxX, maxY = math.max(maxX, points[i]), math.max(maxY, points[i + 1])
                end
                cached.width, cached.height = maxX - minX, maxY - minY
            end
        end
        return cached.width, cached.height
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


-- Draw

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

