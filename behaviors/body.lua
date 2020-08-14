local Physics = require "physics"

-- To account for `b2_polygonRadius` (see 'b2Settings.h')
local succeeded =
    pcall(
    function()
        love.physics.setMeter(0.5 * UNIT)
    end
)
if not succeeded then
    love.physics.setMeter(UNIT)
end
BODY_POLYGON_SKIN = love.physics.newRectangleShape(UNIT, UNIT):getRadius()
BODY_RECTANGLE_SLOP = 2.01 * BODY_POLYGON_SKIN

local BodyBehavior =
    defineCoreBehavior {
    name = "Body",
    displayName = "Layout",
    propertySpecs = {
       x = {
          method = 'numberInput',
          label = 'X Position',
          rules = {
             set = true,
          },
       },
       y = {
          method = 'numberInput',
          label = 'Y Position',
          rules = {
             set = true,
          },
       },
       angle = {
          method = 'numberInput',
          label = 'Rotation',
          rules = {
             set = true,
          },
       },
       width = {
          method = 'numberInput',
          label = 'Width',
          props = { min = MIN_BODY_SIZE, max = MAX_BODY_SIZE, decimalDigits = 1 },
       },
       height = {
          method = 'numberInput',
          label = 'Height',
          props = { min = MIN_BODY_SIZE, max = MAX_BODY_SIZE, decimalDigits = 1 },
       },
       worldId = {},
       groundBodyId = {},
       bodyId = {},
       fixtureId = {},
       fixtures = {},
       isNewDrawingTool = {},
       sensor = {},
    },
}

-- Behavior management

function BodyBehavior.handlers:addBehavior(opts)
    -- Create a local `Physics` at every host
    self._physics =
        Physics.new(
        {
            game = self.game,
            updateRate = 120
        }
    )

    -- Collision callbacks
    self._physics.onContact = function(...)
        self:onContact(...)
    end

    -- Create a new world
    self:sendSetProperties(nil, "worldId", self._physics:newWorld(0, UNIT * 9.8, true))

    -- Create the ground body
    self:sendSetProperties(nil, "groundBodyId", self._physics:newBody(self.globals.worldId, 0, 0, "static"))
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
    self._physics:syncNewClient(
        {
            clientId = clientId,
            channel = self.game.channels.mainReliable
        }
    )
end

-- Component management

function BodyBehavior.handlers:postAddActor(actorId)
   -- this is needed in case we picked up any dependent behaviors during the actor's
   -- construction which could modify our fixtures
   if self.components[actorId] ~= nil then
      local component = self.components[actorId]
      local bodyId, body = self:getBody(component)
      local bodyFixtures = body:getFixtures()

      for _, fixture in pairs(bodyFixtures) do
         local fixtureId = self._physics:idForObject(fixture)
         self:updatePhysicsFixtureFromDependentBehaviors(component, fixtureId)
      end
   end
end

function BodyBehavior.handlers:addComponent(component, bp, opts)
    if opts.isOrigin then
        -- At the origin, create the physics body and fixtures and shapes. Other hosts will receive
        -- them through sync

        local bodyId = self._physics:newBody(self.globals.worldId, bp.x or 0, bp.y or 0, bp.bodyType or "static")
        if bp.massData then
            local massData = bp.massData

            -- box2d throws an error if this is negative
            local m_I = massData[4] - massData[3] * (massData[1]*massData[1] + massData[2]*massData[2])
            if m_I <= 0.00001 then
                -- TODO: actually calculate this in a better way
                massData = {0, 0, 5.0, 0.0}
            end

            self._physics:setMassData(bodyId, unpack(massData))
        end

        if bp.angle ~= nil then
            self._physics:setAngle(bodyId, bp.angle)
        end
        if bp.bullet ~= nil then
            self._physics:setBullet(bodyId, bp.bullet)
        end

        -- defaults which could be overridden by behaviors later
        self._physics:setAngularDamping(bodyId, 0)
        self._physics:setLinearDamping(bodyId, 0)
        self._physics:setFixedRotation(bodyId, false)
        self._physics:setGravityScale(bodyId, 0)
        
        local fixtureBps = bp.fixture and {bp.fixture} or bp.fixtures
        if fixtureBps then
            component.properties.fixtures = fixtureBps
        else -- Default shape
            local shapeId = self._physics:newRectangleShape(UNIT - BODY_RECTANGLE_SLOP, UNIT - BODY_RECTANGLE_SLOP)
            component.properties.fixtures = {{
                shapeType = "polygon",
                points = {
                    self._physics:objectForId(shapeId):getPoints()
                },
            }}
        end

        local firstFixtureBp = nil
        if fixtureBps and fixtureBps[1] then
            firstFixtureBp = fixtureBps[1]
        end
        
        self:_assignLegacyComponentProps(component, bp, firstFixtureBp)

        -- Associate the component with the underlying body
        self._physics:setUserData(bodyId, component.actorId)
        self:sendSetProperties(component.actorId, "bodyId", bodyId)

        self:updatePhysicsFixturesFromProperties(component.actorId)

        local width, height
        if bp.width then
            width = bp.width
            height = bp.height
        else
            width, height = self:getFixtureBoundingBoxSize(component.actorId)
        end

        component.properties.width = width
        component.properties.height = height
        component.properties.isNewDrawingTool = false
    end
end

function BodyBehavior:_assignLegacyComponentProps(component, bp, firstFixtureBp)
   -- legacy props from older scenes - will be saved in a different component next time
   component.properties.gravityScale = bp.gravityScale
   component.properties.fixedRotation = bp.fixedRotation
   component.properties.linearVelocity = bp.linearVelocity
   component.properties.angularVelocity = bp.angularVelocity
   if bp.friction ~= nil then
      component.properties.friction = bp.friction
   elseif firstFixtureBp ~= nil and firstFixtureBp.friction ~= nil then
      component.properties.friction = firstFixtureBp.friction
   end
   if bp.restitution ~= nil then
      component.properties.restitution = bp.restitution
   elseif firstFixtureBp ~= nil and firstFixtureBp.restitution ~= nil then
      component.properties.restitution = firstFixtureBp.restitution
   end
   if bp.sensor ~= nil then
      component.properties.sensor = bp.sensor
   elseif firstFixtureBp ~= nil and firstFixtureBp.sensor ~= nil then
      component.properties.sensor = firstFixtureBp.sensor
   end
end

function BodyBehavior.handlers:disableComponent(component, opts)
    if opts.isOrigin then
        -- At the origin, destroy the body. Associated fixtures and shapes will automatically be
        -- destroyed. Other hosts will receive the destructions through sync.

        self._physics:destroyObject(component.properties.bodyId)
    end
end

function BodyBehavior:serializeFixture(component, fixture)
    local fixtureBp = {}

    local shape = fixture:getShape()
    local shapeType = shape:getType()
    fixtureBp.shapeType = shapeType
    if shapeType == "circle" then
        fixtureBp.x, fixtureBp.y = shape:getPoint()
        fixtureBp.radius = shape:getRadius()
    elseif shapeType == "polygon" then
        fixtureBp.points = {shape:getPoints()}
    elseif shapeType == "edge" then
        fixtureBp.points = {shape:getPoints()}
        fixtureBp.previousVertex = {shape:getPreviousVertex()}
        fixtureBp.nextVertex = {shape:getNextVertex()}
    elseif shapeType == "chain" then
        fixtureBp.points = {shape:getPoints()}
        fixtureBp.previousVertex = {shape:getPreviousVertex()}
        fixtureBp.nextVertex = {shape:getNextVertex()}
    end

    for behaviorId, dependentComponent in pairs(component.dependents) do
       self.game.behaviors[behaviorId]:callHandler("blueprintFixture", dependentComponent, fixture, fixtureBp)
    end

    return fixtureBp
end

function BodyBehavior.handlers:blueprintComponent(component, bp)
    local bodyId, body = self:getBody(component)
    bp.x = body:getX()
    bp.y = body:getY()
    bp.bodyType = body:getType()
    bp.massData = {body:getMassData()}
    bp.angle = body:getAngle()
    bp.bullet = body:isBullet()

    bp.fixtures = component.properties.fixtures
    bp.width = component.properties.width
    bp.height = component.properties.height
end

function BodyBehavior.handlers:addDependentComponent(addedComponent, opts)
    local addedBehavior = self:getOtherBehavior(addedComponent.behaviorId)

    -- Promote body type. Order is: static, kinematic, dynamic. Bodies are
    -- static by default. A request for a higher type always wins.
    local addedBodyType = addedBehavior:callHandler("bodyTypeComponent", addedComponent)
    if addedBodyType then
        local actor = self:getActor(addedComponent.actorId)

        local finalBodyType = addedBodyType
        if finalBodyType ~= "dynamic" then -- Dynamic always wins
            for otherBehaviorId, otherComponent in pairs(actor.components) do
                if otherBehaviorId ~= addedComponent.behaviorId then
                    local otherBehavior = self:getOtherBehavior(otherBehaviorId)
                    local otherBodyType = otherBehavior:callHandler("bodyTypeComponent", otherComponent)
                    if otherBodyType then
                        if otherBodyType == "dynamic" then -- Dynamic always wins
                            finalBodyType = "dynamic"
                            return
                        elseif otherBodyType == "kinematic" then -- Promote to kinematic from static
                            finalBodyType = "kinematic"
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

    -- Track callbacks
    if addedBehavior.handlers.bodyContactComponent then
        local component = self.components[addedComponent.actorId]
        if not component._contactListeners then
            component._contactListeners = {}
        end
        component._contactListeners[addedComponent.behaviorId] = addedComponent
    end
end

function BodyBehavior.handlers:removeDependentComponent(removedComponent, opts)
    local removedBehavior = self:getOtherBehavior(removedComponent.behaviorId)

    -- Demote body type
    local removedBodyType = removedBehavior:callHandler("bodyTypeComponent", removedComponent)
    if removedBodyType then
        local actor = self:getActor(removedComponent.actorId)

        local finalBodyType = "static"
        for otherBehaviorId, otherComponent in pairs(actor.components) do
            if otherBehaviorId ~= removedComponent.behaviorId then
                local otherBehavior = self:getOtherBehavior(otherBehaviorId)
                local otherBodyType = otherBehavior:callHandler("bodyTypeComponent", otherComponent)
                if otherBodyType then
                    if otherBodyType == "dynamic" then -- Dynamic always wins
                        finalBodyType = "dynamic"
                        return
                    elseif otherBodyType == "kinematic" then -- Promote to kinematic from static
                        finalBodyType = "kinematic"
                    end
                end
            end
        end

        local bodyId, body = self:getBody(removedComponent.actorId)
        if body:getType() ~= finalBodyType then
            self._physics:setType(bodyId, finalBodyType)
        end
    end

    -- Untrack callbacks
    if removedBehavior.handlers.bodyContactComponent then
        local component = self.components[removedComponent.actorId]
        if component._contactListeners then
            component._contactListeners[removedComponent.behaviorId] = nil
            if not next(component._contactListeners) then
                component._contactListeners = nil
            end
        end
    end
end

-- Perform / update

function BodyBehavior.handlers:prePerform(dt)
    -- Update the world at the very start of the performance to allow other behaviors to make
    -- changes after
    self._physics:updateWorld(self.globals.worldId, dt)

    -- If client, check for touches
    if self.game.clientId then
        local touchData = self:getTouchData()
        for touchId, touch in pairs(touchData.touches) do
            if (touch.released and not touch.movedFar and love.timer.getTime() - touch.pressTime < 0.3) then
                local hits = self:getActorsAtPoint(touch.x, touch.y)
                for actorId in pairs(hits) do
                    if self:fireTrigger("tap", actorId) then
                        touch.used = true
                    end
                end
            end
            if not touch.released then
                local hits = self:getActorsAtPoint(touch.x, touch.y)
                for actorId in pairs(hits) do
                    if self:fireTrigger("press", actorId) then
                        touch.used = true
                    end
                end
            end
        end
    end
end

function BodyBehavior.handlers:postUpdate(dt)
    -- Send syncs at the end of the frame, after tool updates
    --if self.game.performing then
    --    self._physics:sendSyncs(self.globals.worldId)
    --end
end

-- Collision

function BodyBehavior:onContact(event, fixture1, fixture2, contact)
    local body1 = fixture1:getBody()
    local body2 = fixture2:getBody()

    local actorId1 = self:getActorForBody(body1)
    local actorId2 = self:getActorForBody(body2)

    local component1 = actorId1 and self.components[actorId1]
    local component2 = actorId2 and self.components[actorId2]

    local isBegin = event == "begin"
    local isEnd = not isBegin

    local ownerId1, strongOwned1 = self._physics:getOwner(body1)
    local ownerId2, strongOwned2 = self._physics:getOwner(body2)
    local ownerId
    if strongOwned1 then
        ownerId = ownerId1
    elseif strongOwned2 then
        ownerId = ownerId2
    else
        ownerId = ownerId1 or ownerId2
    end
    local isOwner = true

    local visited = {}
    if component1 then
        local context = {
            contact = contact,
            isBegin = isBegin,
            isEnd = isEnd,
            otherActorId = actorId2,
            fixture = fixture1,
            otherFixture = fixture2,
            isOwner = isOwner
        }
        if isBegin then
            self:fireTrigger(
                "collide",
                actorId1,
                context,
                {
                    threadKey = {},
                    filter = function(params)
                        if params.tag == nil or params.tag == '' then
                            return true
                        else
                            return self.game.behaviorsByName.Tags:actorHasTag(actorId2, params.tag)
                        end
                    end
                }
            )
        end
        if component1._contactListeners then
            for listenerBehaviorId, listenerComponent in pairs(component1._contactListeners) do
                local listenerBehavior = self.game.behaviors[listenerBehaviorId]
                if listenerBehavior then
                    context.isRepeat = false
                    listenerBehavior:callHandler("bodyContactComponent", listenerComponent, context)
                    visited[listenerBehavior] = true
                end
            end
        end
    end
    if component2 then
        local context = {
            contact = contact,
            isBegin = isBegin,
            isEnd = isEnd,
            otherActorId = actorId1,
            fixture = fixture2,
            otherFixture = fixture1,
            isOwner = isOwner
        }
        if isBegin then
            self:fireTrigger(
                "collide",
                actorId2,
                context,
                {
                    threadKey = {},
                    filter = function(params)
                        if params.tag == nil or params.tag == '' then
                            return true
                        else
                            return self.game.behaviorsByName.Tags:actorHasTag(actorId1, params.tag)
                        end
                    end
                }
            )
        end
        if component2._contactListeners then
            for listenerBehaviorId, listenerComponent in pairs(component2._contactListeners) do
                local listenerBehavior = self.game.behaviors[listenerBehaviorId]
                if listenerBehavior then
                    context.isRepeat =
                        visited[listenerBehavior] ~= nil,
                        listenerBehavior:callHandler("bodyContactComponent", listenerComponent, context)
                end
            end
        end
    end
end

-- Triggers

BodyBehavior.triggers.collide = {
    description = "When this collides with another actor",
    category = "general",
    paramSpecs = {
       tag = {
          label = "colliding with tag",
          method = "textInput",
          props = { autoCapitalize = 'none' },
       },
    },
}

BodyBehavior.triggers.tap = {
    description = "When this is tapped",
    category = "controls",
}

BodyBehavior.triggers.press = {
    description = "While this is pressed",
    category = "controls"
}

-- Responses

BodyBehavior.responses["is colliding"] = {
    description = "If this is colliding",
    category = "collision",
    returnType = "boolean",
    paramSpecs = {
       tag = {
          label = "colliding with tag",
          method = "textInput",
          props = { autoCapitalize = 'none' },
       },
    },
    run = function(self, actorId, params, context)
        local bodyId, body = self:getBody(actorId)
        if body then
            for _, contact in ipairs(body:getContacts()) do
                if params.tag == nil or params.tag == '' then
                    return true
                end
                local f1, f2 = contact:getFixtures()
                local b1, b2 = f1:getBody(), f2:getBody()
                local otherBody = body == b1 and b2 or b1
                local otherActorId = self:getActorForBody(otherBody)
                if otherActorId and self.game.behaviorsByName.Tags:actorHasTag(otherActorId, params.tag) then
                    return true
                end
            end
        end
        return false
    end
}

BodyBehavior.responses["face direction of motion"] = {
   description = "Face direction of motion",
   category = "motion",
   run = function(self, actorId, params, context)
      local members = self.game.behaviorsByName.Body:getMembers(actorId)
      local x, y = 0, 0
      if members.body and members.physics then
         local vx, vy = members.body:getLinearVelocity()
         local angle = math.atan2(vy, vx)
         members.physics:setAngle(members.bodyId, angle)
      end
   end,
}


-- Setters

function BodyBehavior.setters:x(component, value)
   local actorId = component.actorId
   local members = self:getMembers(actorId)
   members.physics:setX(members.bodyId, value)
end

function BodyBehavior.setters:y(component, value)
   local actorId = component.actorId
   local members = self:getMembers(actorId)
   members.physics:setY(members.bodyId, value)
end

function BodyBehavior.setters:angle(component, value)
   local actorId = component.actorId
   local members = self:getMembers(actorId)
   members.physics:setAngle(members.bodyId, value * math.pi / 180)
end

function BodyBehavior.setters:width(component, value)
   component.properties.width = value
   local actorId = component.actorId
   local rectangleWidth, rectangleHeight = self:getRectangleSize(actorId)
   self:setRectangleShape(actorId, value, rectangleHeight)
end

function BodyBehavior.setters:height(component, value)
    component.properties.height = value
   local actorId = component.actorId
   local rectangleWidth, rectangleHeight = self:getRectangleSize(actorId)
   self:setRectangleShape(actorId, rectangleWidth, value)
end

function BodyBehavior:updatePhysicsFixturesFromProperties(componentOrActorId)
    local bodyId, body = self:getBody(componentOrActorId)
    local bodyFixtures = body:getFixtures()

    for _, fixture in pairs(bodyFixtures) do
        local fixtureId = self._physics:idForObject(fixture)
        self._physics:destroyObject(fixtureId)
    end

    local component = self:getComponent(componentOrActorId)

    if self.game.performing or not component.properties.isNewDrawingTool then
        for _, fixtureBp in ipairs(component.properties.fixtures) do
            local shapeId
            local shapeType = fixtureBp.shapeType

            if shapeType == "circle" then
                shapeId =
                    self._physics:newCircleShape(fixtureBp.x or 0, fixtureBp.y or 0, fixtureBp.radius or 0.5 * UNIT)
            elseif shapeType == "polygon" then
                shapeId = self._physics:newPolygonShape(unpack(assert(fixtureBp.points)))
            elseif shapeType == "edge" then
                shapeId = self._physics:newEdgeShape(unpack(assert(fixtureBp.points)))
                self._physics:setPreviousVertex(unpack(assert(fixtureBp.previousVertex)))
                self._physics:setNextVertex(unpack(assert(fixtureBp.nextVertex)))
            elseif shapeType == "chain" then
                shapeId = self._physics:newChainShape(unpack(assert(fixtureBp.points)))
                self._physics:setPreviousVertex(unpack(assert(fixtureBp.previousVertex)))
                self._physics:setNextVertex(unpack(assert(fixtureBp.nextVertex)))
            end

            local fixtureId = self._physics:newFixture(bodyId, shapeId, 1)
            self:updatePhysicsFixtureFromDependentBehaviors(component, fixtureId)

            self._physics:destroyObject(shapeId)
        end
    else
        local halfWidth = component.properties.width
        local halfHeight = component.properties.height

        local shapeId = self._physics:newRectangleShape(component.properties.width, component.properties.height)
        local fixtureId = self._physics:newFixture(bodyId, shapeId, 1)
        self:updatePhysicsFixtureFromDependentBehaviors(component, fixtureId)

        self._physics:destroyObject(shapeId)
    end
end

function BodyBehavior:updatePhysicsFixtureFromDependentBehaviors(component, fixtureId)
   -- defaults which could be overridden by behaviors later
   self._physics:setSensor(fixtureId, true)
   self._physics:setFriction(fixtureId, 0)
   self._physics:setRestitution(fixtureId, 0)
   self._physics:setDensity(fixtureId, 1)
   
   for behaviorId, dependentComponent in pairs(component.dependents) do
      self.game.behaviors[behaviorId]:callHandler("updateComponentFixture", dependentComponent, fixtureId)
   end
   local bodyId, body = self:getBody(component)
   body:resetMassData()
end

-- TODO: this is inefficient. it should take serialized fixtures instead of
-- actual physics objects
function BodyBehavior:setShapes(componentOrActorId, newShapeIds)
    local bodyId, body = self:getBody(componentOrActorId)
    local fixtures = body:getFixtures()

    local component = self:getComponent(componentOrActorId)

    local density = 1 -- default density may get overridden by motion component

    for _, fixture in pairs(fixtures) do
        local fixtureId = self._physics:idForObject(fixture)
        self._physics:destroyObject(fixtureId)
    end

    for _, newShapeId in pairs(newShapeIds) do
        local newFixtureId = self._physics:newFixture(bodyId, newShapeId, density)
        self._physics:destroyObject(newShapeId)
        self:updatePhysicsFixtureFromDependentBehaviors(component, newFixtureId)
    end

    component.properties.fixtures = {}
    for _, fixture in ipairs(body:getFixtures()) do
        table.insert(component.properties.fixtures, self:serializeFixture(component, fixture))
    end

    self:updatePhysicsFixturesFromProperties(componentOrActorId)
end

function BodyBehavior:setRectangleShape(componentOrActorId, newWidth, newHeight)
    newWidth = math.max(MIN_BODY_SIZE, math.min(newWidth, MAX_BODY_SIZE))
    newHeight = math.max(MIN_BODY_SIZE, math.min(newHeight, MAX_BODY_SIZE))
    self:setShapes(
        componentOrActorId,
        {self._physics:newRectangleShape(newWidth - BODY_RECTANGLE_SLOP, newHeight - BODY_RECTANGLE_SLOP)}
    )
end

function BodyBehavior:resize(componentOrActorId, newWidth, newHeight)
    local members = self:getMembers(componentOrActorId)
    local component = self:getComponent(componentOrActorId)
    local newShapes = {}

    for _, fixture in pairs(members.fixtures) do
        local points = {fixture:getShape():getPoints()}

        for i = 1, #points, 2 do
            points[i] = points[i] * newWidth / component.properties.width
            points[i + 1] = points[i + 1] * newHeight / component.properties.height
        end

        table.insert(newShapes, self._physics:newPolygonShape(points))
    end

    self:setShapes(componentOrActorId, newShapes)
    self:sendSetProperties(component.actorId, "width", newWidth)
    self:sendSetProperties(component.actorId, "height", newHeight)
end

function BodyBehavior:resetShapes(actorId)
    local component = self:getComponent(actorId)
    self:setRectangleShape(actorId, component.properties.width or UNIT, component.properties.height or UNIT)
end

-- Getters

function BodyBehavior.getters:x(component)
   local actorId = component.actorId
   local members = self:getMembers(actorId)
   return members.body:getX()
end

function BodyBehavior.getters:y(component)
   local actorId = component.actorId
   local members = self:getMembers(actorId)
   return members.body:getY()
end

function BodyBehavior.getters:angle(component)
   local actorId = component.actorId
   local members = self:getMembers(actorId)
   return members.body:getAngle() * 180 / math.pi
end

function BodyBehavior.getters:width(component)
   local rectangleWidth, rectangleHeight = self:getRectangleSize(component.actorId)
   return rectangleWidth or 0
end

function BodyBehavior.getters:height(component)
   local rectangleWidth, rectangleHeight = self:getRectangleSize(component.actorId)
   return rectangleHeight or 0
end

function BodyBehavior:getPhysics()
    return self._physics
end

function BodyBehavior:getWorld()
    return self.globals.worldId, self._physics:objectForId(self.globals.worldId)
end

function BodyBehavior:getGroundBody()
    return self.globals.groundBodyId, self._physics:objectForId(self.globals.groundBodyId)
end

function BodyBehavior:getComponent(componentOrActorId)
    return type(componentOrActorId) == "table" and componentOrActorId or self.components[componentOrActorId]
end

function BodyBehavior:getBody(componentOrActorId)
    local component = self:getComponent(componentOrActorId)
    if component then
        local bodyId = component.properties.bodyId
        return bodyId, self._physics:objectForId(bodyId)
    end
end

function BodyBehavior:getMembers(componentOrActorId)
    local physics = self._physics
    local bodyId, body = self:getBody(componentOrActorId)
    local fixtures = body and body:getFixtures()
    local firstFixture = fixtures and fixtures[1]
    local fixtureIds = {}

    if fixtures then
        for _, fixture in pairs(fixtures) do
            table.insert(fixtureIds, physics:idForObject(fixture))
        end
    end

    return {
        physics = physics,
        bodyId = bodyId,
        body = body,
        fixtures = fixtures,
        firstFixture = firstFixture,
        fixtureIds = fixtureIds,
    }
end

local function getRectangleSizeFromFixture(fixture)
    local shape = fixture:getShape()
    if shape:getType() == "polygon" then
        local p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, p5x = shape:getPoints()
        if p4y ~= nil and p5x == nil then
            if
                (p1y == p2y and p1x == -p2x and p1x == p4x and p1y == -p4y and p2x == p3x and p2y == -p3y) or
                    (p1x == p2x and p1y == -p2y and p1y == p4y and p1x == -p4x and p2y == p3y and p2x == -p3x)
             then
                return 2 * math.abs(p1x) + BODY_RECTANGLE_SLOP, 2 * math.abs(p1y) + BODY_RECTANGLE_SLOP
            end
        end
    end
end

function BodyBehavior:getSize(actorId)
    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    local bodyId, body = self:getBody(component)
    local fixtures = body:getFixtures()

    if not component.properties.isNewDrawingTool then
        local fixture = fixtures[1]
        local shape = fixture:getShape()
        local shapeType = shape:getType()

        if shapeType == 'circle' then
            return self:getFixtureBoundingBoxSize(actorId)
        end
    end
    
    return component.properties.width, component.properties.height
end

function BodyBehavior:getComponentSize(actorId)
    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    return component.properties.width, component.properties.height
end

function BodyBehavior:getFixtureBoundingBoxSize(actorId)
    -- Get bounding box size, whatever the shape of the body

    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    local bodyId, body = self:getBody(component)
    local fixtures = body:getFixtures()
    local firstFixture = fixtures[1]
    if not firstFixture then
        return 0, 0
    end

    local firstShape = firstFixture:getShape()
    local firstShapeType = firstShape:getType()

    if not component.properties.isNewDrawingTool then
        local rectangleWidth, rectangleHeight = getRectangleSizeFromFixture(firstFixture, component)
        if rectangleHeight and rectangleHeight then
            return rectangleWidth, rectangleHeight
        end

        if firstShapeType == "circle" then
            local radius = firstShape:getRadius()
            return 2 * radius, 2 * radius
        end
    end

    local points = {firstShape:getPoints()}
    local minX, minY, maxX, maxY = points[1], points[2], points[1], points[2]

    for _, fixture in pairs(fixtures) do
        local shape = fixture:getShape()
        points = {shape:getPoints()}

        for i = 3, #points - 1, 2 do
            minX, minY = math.min(minX, points[i]), math.min(minY, points[i + 1])
            maxX, maxY = math.max(maxX, points[i]), math.max(maxY, points[i + 1])
        end
    end

    return maxX - minX, maxY - minY
end

function BodyBehavior:getRectangleSize(componentOrActorId)
    -- Return width and height of rectangle shape if rectangle-shaped, else `nil`
    local component = self:getComponent(componentOrActorId)
    if self:getShapeType(component.actorId) == 'circle' then
        return nil
    end

    return component.properties.width, component.properties.height
end

function BodyBehavior:getShapeType(actorId)
    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    local bodyId, body = self:getBody(actorId)
    local fixtures = body:getFixtures()

    if component.properties.isNewDrawingTool then
        return "polygon"
    end

    local fixture = fixtures[1]
    if fixture then
        local shape = fixture:getShape()
        if shape then
            return shape:getType()
        end
    end
end

function BodyBehavior:getActorForBody(body)
    return body:getUserData()
end

function BodyBehavior:getActorsAtBoundingBox(minX, minY, maxX, maxY)
    local hits = {}
    local worldId, world = self:getWorld()
    if world then
        world:queryBoundingBox(
            minX,
            minY,
            maxX,
            maxY,
            function(fixture)
                local actorId = self:getActorForBody(fixture:getBody())
                if actorId then
                    hits[actorId] = true
                end
                return true
            end
        )
    end
    return hits
end

function BodyBehavior:getActorsAtPoint(x, y)
    local hits = {}
    local worldId, world = self:getWorld()
    if world then
        world:queryBoundingBox(
            x - 1,
            y - 1,
            x + 1,
            y + 1,
            function(fixture)
                if fixture:testPoint(x, y) then
                    local actorId = self:getActorForBody(fixture:getBody())
                    if actorId then
                        hits[actorId] = true
                    end
                end
                return true
            end
        )
    end
    return hits
end

function BodyBehavior:isOwner(actorId)
    return true
end

-- Draw

function BodyBehavior:drawBodyOutline(componentOrActorId)
    local bodyId, body = self:getBody(componentOrActorId)
    local rectangleWidth, rectangleHeight = self:getRectangleSize(componentOrActorId)
    if rectangleHeight and rectangleHeight then
        -- Draw rectangles directly to account for slop
        local hh = 0.5 * rectangleHeight
        local hw = 0.5 * rectangleWidth
        love.graphics.polygon("line", body:getWorldPoints(-hw, -hh, -hw, hh, hw, hh, hw, -hh))
    else
        local fixtures = body:getFixtures()
        for _, fixture in pairs(fixtures) do
            local shape = fixture:getShape()
            local ty = shape:getType()
            if ty == "circle" then
                love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
            elseif ty == "polygon" then
                love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
            elseif ty == "edge" then
                love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
            elseif ty == "chain" then
                love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
            end
        end
    end
end
