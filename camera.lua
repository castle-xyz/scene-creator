-- Start / stop

function Common:startCamera()
    self.camera = {
        x = 0.0,
        y = 0.0,
        lastFrameX = 0.0,
        lastFrameY = 0.0,
        actorId = nil,
        newActorId = nil,
    }
end

-- Utils

function lerp(a, b, t)
    return a + t * (b - a)
end

function Common:cameraGetActorBody()
    local actorId = self.camera.actorId

    if actorId then
        local bodyId, body = self.behaviorsByName.Body:getBody(actorId)
        if body then
            return body
        end
    end

    return nil
end

-- Getters

function Common:getCameraPosition()
    return self.camera.x, self.camera.y
end

-- Message receivers

function Common:cameraAttachToActorId(actorId)
    self.camera.newActorId = actorId
end

function Common:updateCamera(dt)
    if self.camera.newActorId then
        self.camera.actorId = self.camera.newActorId
        self.camera.newActorId = nil

        local body = self:cameraGetActorBody()
        if body then
            local bodyX = body:getX()
            local bodyY = body:getY()

            self.camera.x = bodyX
            self.camera.y = bodyY
        end
    else
        local body = self:cameraGetActorBody()
        if body then
            local bodyX = body:getX()
            local bodyY = body:getY()

            self.camera.x = bodyX--lerp(self.camera.x, bodyX, dt * 10)
            self.camera.y = bodyY--lerp(self.camera.y, bodyY, dt * 10)
        end
    end
end