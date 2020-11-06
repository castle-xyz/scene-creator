-- Start / stop

function Common:startCamera()
    self.camera = {
        x = 0.0,
        y = 0.0,
        isStartOfActOn = true,
        isInActOn = false,
        actorIds = nil,
        newActorIds = nil,
    }
end

-- Getters

function Common:getCameraPosition()
    return self.camera.x, self.camera.y
end

function Common:getCameraCornerPosition()
    return self.camera.x - 0.5 * self.viewWidth, self.camera.y - self:getYOffset()
end

function Common:getCameraSize()
    return self.viewWidth, self.viewWidth * VIEW_HEIGHT_TO_WIDTH_RATIO
end

-- Message receivers

function Common:cameraAttachToActorId(actorId)
    if self.camera.isInActOn then
        if self.camera.isStartOfActOn then
            self.camera.isStartOfActOn = false
            self.camera.newActorIds = {}
        end

        table.insert(self.camera.newActorIds, actorId)
    else
        self.camera.newActorIds = {actorId}
    end
end

function Common:cameraBeginActOn()
    self.camera.isInActOn = true
    self.camera.isStartOfActOn = true
end

function Common:cameraEndActOn()
    self.camera.isInActOn = false
end

function Common:updateCamera(dt)
    if self.camera.newActorIds then
        self.camera.actorIds = self.camera.newActorIds
    end

    if self.camera.actorIds then
        local numActors = 0
        local totalX = 0
        local totalY = 0

        for i = 1, #self.camera.actorIds do
            local actorId = self.camera.actorIds[i]
            local bodyId, body = self.behaviorsByName.Body:getBody(actorId)
            if body then
                local bodyX = body:getX()
                local bodyY = body:getY()

                numActors = numActors + 1
                totalX = totalX + bodyX
                totalY = totalY + bodyY
            end
        end

        if numActors > 0 then
            self.camera.x = totalX / numActors
            self.camera.y = totalY / numActors
        end
    end

    self.camera.isInActOn = false
end
