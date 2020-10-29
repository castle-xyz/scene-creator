-- Start / stop

function Common:startCamera()
    self.camera = {
        x = 0.0,
        y = 0.0,
        actorId = nil,
    }
end

-- Getters

function Common:getCameraPosition()
    return self.camera.x, self.camera.y
end

-- Message receivers

function Common:cameraAttachToActorId(actorId)
    self.camera.actorId = actorId
end

function Common.receivers:updateCamera(time)
    local actorId = self.camera.actorId

    if actorId then
        local bodyId, body = self.behaviorsByName.Body:getBody(actorId)
        if body then
            local bodyX = body:getX()
            local bodyY = body:getY()

            self.camera.x = bodyX
            self.camera.y = bodyY
        end
    end
end