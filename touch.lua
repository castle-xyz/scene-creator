-- Start / stop

function Client:startTouch()
    self.touches = {} -- `touchId` -> touch
    self.numTouches = 0 -- Number of currently active touches
    self.maxNumTouches = 0 -- Max number of touches in the current gesture
    self.allTouchesReleased = false -- Whether we are at the end of a gesture
end


-- Update

function Client:postUpdateTouch()
    -- Clear touch state
    for touchId, touch in pairs(self.touches) do
        if touch.released then
            self.touches[touchId] = nil
            self.numTouches = self.numTouches - 1
            if self.numTouches == 0 then
                self.maxNumTouches = 0
            end
        else
            touch.pressed = false
            touch.dx, touch.dy = 0, 0
        end
    end
    self.allTouchesReleased = false
end


-- Main touch events

function Client:touchpressed(touchId, x, y, dx, dy)
    if not self.connected then
        return
    end

    if self.addFromLibraryEntryId then -- Adding?
        local entry = self.library[self.addFromLibraryEntryId]
        self.addFromLibraryEntryId = nil
        if entry then
            if entry.entryType == 'actorBlueprint' then
                local actorBp = util.deepCopyTable(entry.actorBlueprint)

                -- If it has a `Body`, initialize position to touch location
                if actorBp.Body then 
                    actorBp.Body.x, actorBp.Body.y = x, y
                end

                local actorId = self:sendAddActor(actorBp)

                -- Select the actor. If we're not performing and it has a `Body`, switch to the `Grab` tool.
                if not self.performing and actorBp.Body then
                    self:setActiveTool(nil)
                end
                self:deselectAllActors()
                self:selectActor(actorId)
                self:refreshTools()
                if not self.performing and actorBp.Body then
                    self:setActiveTool(self.behaviorsByName.Grab.behaviorId)
                end
            end
        end
    end

    local touch = {}

    touch.initialX, touch.initialY = x, y
    touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
    touch.pressed = true
    touch.released = false

    self.touches[touchId] = touch

    self.numTouches = self.numTouches + 1
    self.maxNumTouches = math.max(self.maxNumTouches, self.numTouches)
end

function Client:touchreleased(touchId, x, y, dx, dy)
    local touch = self.touches[touchId]
    if touch then
        touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
        touch.released = true

        -- Check if end of gesture
        self.allTouchesReleased = true
        for touchId, touch in pairs(self.touches) do
            if not touch.released then
                self.allTouchesReleased = false
            end
        end
    end
end

function Client:touchmoved(touchId, x, y, dx, dy)
    local touch = self.touches[touchId]
    if touch then
        touch.x, touch.y, touch.dx, touch.dy = x, y, dx, dy
    end
end
