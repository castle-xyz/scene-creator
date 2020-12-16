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
local DEFAULT_LAYER = "main"
local CAMERA_LAYER = "camera"
local EDITOR_BOUNDS_MIN_SIZE = 0.5

local BodyBehavior =
    defineCoreBehavior {
    name = "Body",
    displayName = "Layout",
    propertySpecs = {
       x = {
          method = 'numberInput',
          label = 'X Position',
          rules = {
             get = true,
             set = true,
          },
       },
       y = {
          method = 'numberInput',
          label = 'Y Position',
          rules = {
             get = true,
             set = true,
          },
       },
       angle = {
          method = 'numberInput',
          label = 'Rotation',
          rules = {
             set = true,
             get = true,
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
       widthScale = {
          method = 'numberInput',
          label = 'Width Scale',
          props = { min = MIN_BODY_SCALE, max = MAX_BODY_SCALE, decimalDigits = 2, step = 0.25 },
          rules = {
            get = true,
            set = true,
         },
       },
       heightScale = {
          method = 'numberInput',
          label = 'Height Scale',
          props = { min = MIN_BODY_SCALE, max = MAX_BODY_SCALE, decimalDigits = 2, step = 0.25 },
          rules = {
            get = true,
            set = true,
         },
       },
       visible = {
          method = 'toggle',
          label = 'Visible',
          rules = {
             set = true,
          },
       },
       relativeToCamera = {
          method = 'toggle',
          label = 'Relative to camera',
       },
       layerName = {},
       layers = {},
       bodyId = {},
       fixtureId = {},
       fixtures = {},
       isNewDrawingTool = {},
       isInViewport = {},
       sensor = {},
       editorBounds = {},
    },
}

-- Behavior management

function BodyBehavior:_createLayer(relativeToCamera)
    local layer = {}

    layer.worldId = self._physics:newWorld(0, UNIT * 9.8, true)
    layer.groundBodyId = self._physics:newBody(layer.worldId, 0, 0, "static")
    layer.relativeToCamera = relativeToCamera

    return layer
end

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

    local layers = {}
    layers[DEFAULT_LAYER] = self:_createLayer(false)
    layers[CAMERA_LAYER] = self:_createLayer(true)

    self:sendSetProperties(nil, "layers", layers)
end

function BodyBehavior.handlers:removeBehavior(opts)
    for _, layerName in pairs(self:getLayerNames()) do
        -- Destroy the local copy of the world
        local worldId, world = self:getWorld(layerName)
        if world then
            world:destroy()
        end
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

        component.properties.layerName = bp.layerName or DEFAULT_LAYER

        local bodyId = self._physics:newBody(self.globals.layers[component.properties.layerName].worldId, bp.x or 0, bp.y or 0, bp.bodyType or "static")
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

        local width, height
        if bp.width then
            width = bp.width
            height = bp.height
        else
            width, height = self:getFixtureBoundingBoxSize(component.actorId)
        end

        component.properties.width = width
        component.properties.height = height
        component.properties.widthScale = bp.widthScale or nil
        component.properties.heightScale = bp.heightScale or nil
        component.properties.editorBounds = bp.editorBounds or nil
        component.properties.isNewDrawingTool = false
        if bp.visible == nil then
           component.properties.visible = true
        else
           component.properties.visible = bp.visible
        end

        component.properties.relativeToCamera = false
        if component.properties.layerName == CAMERA_LAYER then
            component.properties.relativeToCamera = true
        end
        component.properties.isInViewport = false
    end
end

function BodyBehavior.handlers:postAddComponents(actorId)
    local component = self.components[actorId]
    if not component then
        return
    end

    if component.properties.widthScale == nil or component.properties.heightScale == nil then
        if (not component.properties.isNewDrawingTool) or self.game.actors[actorId].components[self.game.behaviorsByName.CircleShape.behaviorId] then
            local fixtures = component.properties.fixtures
            local fixture = fixtures[1]

            if fixture.shapeType == 'circle' then
                local width, height = self:getFixtureBoundingBoxSize(actorId)
                component.properties.width = width
                component.properties.height = height
            end
        end

        if component.properties.editorBounds == nil then
            local halfWidth = component.properties.width * 0.5
            local halfHeight = component.properties.height * 0.5
            component.properties.editorBounds = {
                minX = -halfWidth,
                minY = -halfHeight,
                maxX = halfWidth,
                maxY = halfHeight,
            }

            component.properties.widthScale = 1.0
            component.properties.heightScale = 1.0
        else
            local bounds = component.properties.editorBounds
            local boundsWidth = bounds.maxX - bounds.minX
            local boundsHeight = bounds.maxY - bounds.minY

            component.properties.widthScale = component.properties.width / boundsWidth
            component.properties.heightScale = component.properties.height / boundsHeight

            -- need to scale our own fixtures, because there are some cases
            -- where body has fixtures, draw2 has no fixtures, and so body's
            -- fixtures never get overridden. see the purple background in remy's pinball game
            for _, fixture in ipairs(component.properties.fixtures) do
                if fixture.shapeType == 'circle' then
                    fixture.radius = fixture.radius / component.properties.widthScale
                else
                    for i = 1, #fixture.points, 2 do
                        fixture.points[i] = fixture.points[i] / component.properties.widthScale
                        fixture.points[i + 1] = fixture.points[i + 1] / component.properties.heightScale
                    end
                end
            end

            -- most of the time we want to grab the fixtures from draw2 again
            -- otherwise the previous step would have incorrectly scaled the draw2
            -- fixtures
            self.game.behaviorsByName.Drawing2:updateBodyShape(component.actorId)
        end
    end

    self:updatePhysicsFixturesFromProperties(component.actorId)
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
    bp.widthScale = component.properties.widthScale
    bp.heightScale = component.properties.heightScale
    bp.editorBounds = component.properties.editorBounds
    bp.visible = component.properties.visible
    bp.layerName = component.properties.layerName
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

    for _, layerName in pairs(self:getLayerNames()) do
        self._physics:updateWorld(self.globals.layers[layerName].worldId, dt)
    end

    -- If client, check for touches
    if self.game.clientId then
        local touchData = self:getTouchData()
        for touchId, touch in pairs(touchData.touches) do
            local hits = self:getActorsAtPoint(touch.x, touch.y)
            if (touch.released and not touch.movedFar and love.timer.getTime() - touch.pressTime < 0.3) then
                for actorId in pairs(hits) do
                    if self:fireTrigger("tap", actorId) then
                        touch.used = true
                    end
                end
            end
            if touch.released then
               for actorId in pairs(hits) do
                  self:fireTrigger("touch up", actorId)
               end
            else
                for actorId in pairs(hits) do
                    -- press all actors under this touch
                    if self:fireTrigger("press", actorId) then
                        touch.used = true
                    end

                    -- if we dragged onto a new actor, touch down
                    if touch.pressed or not touch.previousActorsTouched[actorId] then
                       if self:fireTrigger("touch down", actorId) then
                          touch.used = true
                       end
                    end
                end

                -- if we dragged off of an actor, touch up
                for actorId in pairs(touch.previousActorsTouched) do
                   if not hits[actorId] then
                      self:fireTrigger("touch up", actorId)
                   end
                end
            end
            touch.previousActorsTouched = hits
        end

        local cameraX, cameraY = self.game:getCameraCornerPosition()
        local cameraWidth, cameraHeight = self.game:getCameraSize()
        local viewportHits = self:getActorsAtBoundingBox(cameraX, cameraY, cameraX + cameraWidth, cameraY + cameraHeight)
        for actorId in pairs(viewportHits) do
            local component = self:getComponent(actorId)
            if component and not component.properties.isInViewport then
                component.properties.isInViewport = true
                self:fireTrigger("enter camera viewport", actorId)
            end
        end

        self.game:forEachActorByDrawOrder(
            function(actor)
                if not viewportHits[actor.actorId] then
                    local component = self:getComponent(actor.actorId)
                    if component and component.properties.isInViewport then
                        component.properties.isInViewport = false
                        self:fireTrigger("exit camera viewport", actor.actorId)
                    end
                end
            end
        )
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
          method = "tagPicker",
          props = { singleSelect = true },
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

BodyBehavior.triggers["touch down"] = {
   description = "When a touch begins on this",
   category = "controls",
}

BodyBehavior.triggers["touch up"] = {
   description = "When a touch ends on this",
   category = "controls",
}

BodyBehavior.triggers["enter camera viewport"] = {
   description = "When this enters the camera viewport",
   category = "camera",
}

BodyBehavior.triggers["exit camera viewport"] = {
   description = "When this exits the camera viewport",
   category = "camera",
}

-- Responses

BodyBehavior.responses["is colliding"] = {
    description = "If this is colliding",
    category = "collision",
    returnType = "boolean",
    paramSpecs = {
       tag = {
          label = "colliding with tag",
          method = "tagPicker",
          props = { singleSelect = true },
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

BodyBehavior.responses["is in camera viewport"] = {
    description = "If this is in the camera viewport",
    category = "camera",
    returnType = "boolean",
    run = function(self, actorId, params, context)
        local component = self:getComponent(actorId)
        if component then
            return component.properties.isInViewport
        end
        return false
    end
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

function BodyBehavior.setters:relativeToCamera(component, value)
    if value then
        component.properties.layerName = CAMERA_LAYER
    else
        component.properties.layerName = DEFAULT_LAYER
    end

    component.properties.relativeToCamera = value
end

function BodyBehavior.setters:widthScale(component, value)
    component.properties.widthScale = value / 10.0
    self:updatePhysicsFixturesFromProperties(component.actorId)
end

function BodyBehavior.setters:heightScale(component, value)
    component.properties.heightScale = value / 10.0
    self:updatePhysicsFixturesFromProperties(component.actorId)
end

function BodyBehavior.setters:editorBounds(component, value)
    component.properties.editorBounds = value
    self:updatePhysicsFixturesFromProperties(component.actorId)
end

local function floatEquals(f1, f2)
    return f1 > f2 - 0.001 and f1 < f2 + 0.001
end

function BodyBehavior:updatePhysicsFixturesFromProperties(componentOrActorId)
    local component = self:getComponent(componentOrActorId)

    if component.properties.widthScale == nil or component.properties.heightScale == nil then
        -- this can happen when Drawing2 calls setShapes before this component has been
        -- migrated. this function will get called again at the end of the migration so
        -- we can exit here
        return
    end

    local bodyId, body = self:getBody(componentOrActorId)
    local bodyFixtures = body:getFixtures()

    for _, fixture in pairs(bodyFixtures) do
        local fixtureId = self._physics:idForObject(fixture)
        self._physics:destroyObject(fixtureId)
    end

    if self.game.performing then
        local widthScale = component.properties.widthScale
        local heightScale = component.properties.heightScale

        for _, fixtureBp in ipairs(component.properties.fixtures) do
            local shapeId
            local shapeType = fixtureBp.shapeType

            if shapeType == "circle" then
                if floatEquals(math.abs(widthScale), math.abs(heightScale)) then
                    shapeId =
                        self._physics:newCircleShape((fixtureBp.x or 0) * widthScale, (fixtureBp.y or 0) * heightScale, math.abs((fixtureBp.radius or 0.5) * widthScale))
                else
                    -- approximate a stretched circle with a polygon
                    local centerX = fixtureBp.x
                    local centerY = fixtureBp.y
                    local radius = fixtureBp.radius

                    local angle = 0
                    local points = {}
                    for i = 1, 8 do
                        local diffX = radius * math.cos(angle)
                        local diffY = radius * math.sin(angle)
                        table.insert(points, (centerX + diffX) * widthScale)
                        table.insert(points, (centerY + diffY) * heightScale)

                        angle = angle - math.pi * 2.0 / 8.0
                    end

                    shapeId = self._physics:newPolygonShape(points)
                end
            elseif shapeType == "polygon" then
                local points = fixtureBp.points
                local newPoints = {}

                for i = 1, #points, 2 do
                    table.insert(newPoints, points[i] * widthScale)
                    table.insert(newPoints, points[i + 1] * heightScale)
                end

                shapeId = self._physics:newPolygonShape(newPoints)
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
        local bounds = self:getScaledEditorBounds(component)
        local shapeId = self._physics:newRectangleShape(bounds.centerX, bounds.centerY, bounds.width, bounds.height, 0)

        self._physics:newFixture(bodyId, shapeId, 1)
        self._physics:destroyObject(shapeId)
    end
end

function BodyBehavior:getScaledEditorBounds(componentOrActorId)
    local component = self:getComponent(componentOrActorId)

    local bounds = util.deepCopyTable(component.properties.editorBounds)
    bounds.minX = bounds.minX * component.properties.widthScale
    bounds.maxX = bounds.maxX * component.properties.widthScale
    bounds.minY = bounds.minY * component.properties.heightScale
    bounds.maxY = bounds.maxY * component.properties.heightScale

    bounds.centerX = (bounds.maxX + bounds.minX) / 2.0
    bounds.centerY = (bounds.maxY + bounds.minY) / 2.0

    bounds.width = math.abs(bounds.maxX - bounds.minX)
    bounds.height = math.abs(bounds.maxY - bounds.minY)

    if bounds.width < EDITOR_BOUNDS_MIN_SIZE then
        bounds.width = EDITOR_BOUNDS_MIN_SIZE
    end
    if bounds.height < EDITOR_BOUNDS_MIN_SIZE then
        bounds.height = EDITOR_BOUNDS_MIN_SIZE
    end

    return bounds
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

function BodyBehavior:setShapes(componentOrActorId, fixtures)
    if fixtures == nil then
        return
    end

    local component = self:getComponent(componentOrActorId)
    component.properties.fixtures = fixtures
    self:updatePhysicsFixturesFromProperties(componentOrActorId)
end

function BodyBehavior:isCircleShape(componentOrActorId)
    local component = self:getComponent(componentOrActorId)

    if component.properties.fixtures == nil then
        return false
    end

    if #component.properties.fixtures ~= 1 then
        return false
    end

    return component.properties.fixtures[1].shapeType == 'circle'
end

function BodyBehavior:resize(componentOrActorId, newScaledBoundsWidth, newScaledBoundsHeight)
    local component = self:getComponent(componentOrActorId)
    local oldBounds = self:getScaledEditorBounds(component)

    local oldWidth = oldBounds.width
    local oldHeight = oldBounds.height

    component.properties.widthScale = component.properties.widthScale * newScaledBoundsWidth / oldWidth
    component.properties.heightScale = component.properties.heightScale * newScaledBoundsHeight / oldHeight
    self:updatePhysicsFixturesFromProperties(component.actorId)
end

function BodyBehavior:resetShapes(actorId)
    local component = self:getComponent(actorId)

    local width = (component.properties.width or UNIT) * 0.5
    local height = (component.properties.height or UNIT) * 0.5

    self:setShapes(
        componentOrActorId,
        {{
            shapeType = "polygon",
            points = {
                width, height,
                -width, height,
                -width, -height,
                width, -height,
            }
        }}
    )
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

function BodyBehavior.getters:widthScale(component)
    return component.properties.widthScale * 10.0
end

function BodyBehavior.getters:heightScale(component)
    return component.properties.heightScale * 10.0
end

function BodyBehavior:getPhysics()
    return self._physics
end

function BodyBehavior:getLayerNames()
    local result = {}

    for k, v in pairs(self.globals.layers) do
      table.insert(result, k)
    end

    return result
end

function BodyBehavior:getWorld(layerName)
    return self.globals.layers[layerName].worldId, self._physics:objectForId(self.globals.layers[layerName].worldId)
end

function BodyBehavior:getGroundBody(layerName)
    return self.globals.layers[layerName].groundBodyId, self._physics:objectForId(self.globals.layers[layerName].groundBodyId)
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

    local component = self:getComponent(componentOrActorId)
    local layerName = DEFAULT_LAYER
    if component then
        layerName = component.properties.layerName
    end

    local layer = self.globals.layers[layerName]

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
        layerName = layerName,
        layer = layer,
    }
end

function BodyBehavior:getSize(actorId)
    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    return component.properties.width, component.properties.height
end

function BodyBehavior:getScale(actorId)
    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    return component.properties.widthScale, component.properties.heightScale
end

-- only used for legacy drawings
function BodyBehavior:getFixtureBoundingBoxSize(actorId)
    -- Get bounding box size, whatever the shape of the body

    local component = assert(self.components[actorId], "this actor doesn't have a `Body` component")
    local fixtures = component.properties.fixtures
    local firstFixture = fixtures[1]
    if not firstFixture then
        return 0, 0
    end

    local firstFixtureType = firstFixture.shapeType

    if firstFixtureType == "circle" then
        local radius = firstFixture.radius
        return 2 * radius, 2 * radius
    end

    local points = firstFixture.points
    local minX, minY, maxX, maxY = points[1], points[2], points[1], points[2]

    for _, fixture in pairs(fixtures) do
        points = fixture.points

        for i = 3, #points - 1, 2 do
            minX, minY = math.min(minX, points[i]), math.min(minY, points[i + 1])
            maxX, maxY = math.max(maxX, points[i]), math.max(maxY, points[i + 1])
        end
    end

    return maxX - minX, maxY - minY
end

function BodyBehavior:getActorForBody(body)
    return body:getUserData()
end

function BodyBehavior:getActorsAtBoundingBox(minX, minY, maxX, maxY)
    local cameraX, cameraY = self.game:getCameraPosition()
    local hits = {}

    for layerName, layer in pairs(self.globals.layers) do
        local tempMinX = minX
        local tempMinY = minY
        local tempMaxX = maxX
        local tempMaxY = maxY

        if layer.relativeToCamera then
            tempMinX = tempMinX - cameraX
            tempMinY = tempMinY - cameraY
            tempMaxX = tempMaxX - cameraX
            tempMaxY = tempMaxY - cameraY
        end

        local worldId, world = self:getWorld(layerName)
        if world then
            world:queryBoundingBox(
                tempMinX,
                tempMinY,
                tempMaxX,
                tempMaxY,
                function(fixture)
                    local actorId = self:getActorForBody(fixture:getBody())
                    local actor = self.game.actors[actorId]
                    if actor and not actor.isGhost then
                        hits[actorId] = true
                    end
                    return true
                end
            )
        end
    end

    return hits
end

function BodyBehavior:getActorsAtPoint(x, y)
    local cameraX, cameraY = self.game:getCameraPosition()
    local hits = {}

    for layerName, layer in pairs(self.globals.layers) do
        local tempX = x
        local tempY = y

        if layer.relativeToCamera then
            tempX = tempX - cameraX
            tempY = tempY - cameraY
        end

        local worldId, world = self:getWorld(layerName)
        if world then
            world:queryBoundingBox(
                tempX - 1,
                tempY - 1,
                tempX + 1,
                tempY + 1,
                function(fixture)
                    if fixture:testPoint(tempX, tempY) then
                        local actorId = self:getActorForBody(fixture:getBody())
                        local actor = self.game.actors[actorId]
                        if actor and not actor.isGhost then
                            hits[actorId] = true
                        end
                    end
                    return true
                end
            )
        end
    end

    return hits
end

function BodyBehavior:isOwner(actorId)
    return true
end

-- Draw

function BodyBehavior:drawBodyOutline(componentOrActorId)
    local component = self:getComponent(componentOrActorId)
    local bodyId, body = self:getBody(componentOrActorId)

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
