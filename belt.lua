-- Constants

local BELT_HEIGHT = 200

local ELEM_SIZE = 170
local ELEM_GAP = 20

local DECEL_X = 2200

local SNAP_THRESHOLD_VX = 200

local SHOW_HIDE_VY = 1200

BELT_DARKEN = 0.4

-- Start / stop

function Common:startBelt()
    self.beltDirty = true

    -- Each elem holds `entryId` + non-persistent info like renderable image, x position etc. 
    self.beltElems = {} 

    self.beltCursorX = 0
    self.beltCursorVX = 0

    self.beltVisible = false

    self.beltTop = nil -- Initialized on first update

    self.beltTargetIndex = nil -- Target element to scroll to if not `nil`
    
    self.beltEntryId = nil -- Entry id of currently highlighted belt element
end

-- Show / hide

jsEvents.listen(
    "SHOW_BELT",
    function()
        local self = currentInstance()
        if self then
            self.beltVisible = true
        end
    end
)

jsEvents.listen(
    "HIDE_BELT",
    function()
        local self = currentInstance()
        if self then
            self.beltVisible = false
        end
    end
)

jsEvents.listen(
    "TOGGLE_BELT",
    function()
        local self = currentInstance()
        if self then
            self.beltVisible = not self.beltVisible
        end
    end
)

-- Focus

function Common:focusEntryInBelt(entryId, opts)
    opts = opts or {}
    self:syncBelt() -- Often called right after a change, so let's sync
    for i, elem in ipairs(self.beltElems) do
        if elem.entryId == entryId then
            self.beltTargetIndex = i
            self.beltEntryId = entryId
            if not opts.noShow then
                self.beltVisible = true
            end
            break
        end
    end
end

-- Update

function Common:updateBeltElemImage(elem, entry)
    -- Create renderable texture from saved preview data in blueprint
    local decoded = love.data.decode("data", "base64", entry.base64Png)
    local imgData = love.image.newImageData(decoded)
    elem.image = love.graphics.newImage(imgData)
    elem.base64Png = entry.base64Png
end

function Common:markBeltDirty()
    -- Mark belt as needing synchronization
    self.beltDirty = true
end

function Common:syncBelt()
    -- Synchronize belt data with library entries

    if not self.beltDirty then
        return
    end

    -- Update images that changed
    for _, elem in ipairs(self.beltElems) do
        local entry = self.library[elem.entryId]
        -- Lua interns strings so hopefully the comparison is quick when equal
        if entry and entry.base64Png ~= elem.base64Png then 
            self:updateBeltElemImage(elem, entry)
        end
    end

    -- Add new elements to belt
    local currElemIds = {}
    for _, elem in ipairs(self.beltElems) do
        currElemIds[elem.entryId] = true
    end
    for entryId, entry in pairs(self.library) do
        if not currElemIds[entryId] then
            local newElem = {}
            newElem.entryId = entry.entryId
            if entry.base64Png then
                self:updateBeltElemImage(newElem, entry)
            end
            table.insert(self.beltElems, newElem)
        end
    end

    -- Sort belt
    table.sort(self.beltElems, function(a, b)
        local entryA = self.library[a.entryId]
        local entryB = self.library[b.entryId]
        if entryA.beltOrder ~= entryB.beltOrder then
            return (entryA.beltOrder or 0) > (entryB.beltOrder or 0)
        end
        return entryA.title < entryB.title
    end)

    -- Calculate positions
    for i, elem in ipairs(self.beltElems) do
        elem.x = (ELEM_SIZE + ELEM_GAP) * (i - 1)
    end

    self.beltDirty = false
end

function Common:updateBelt(dt)
    -- Make belt snap quicker. Resorted to making time faster after tuning the
    -- other constants for spring damping + deceleration...
    local origDt = dt
    dt = 1.6 * dt 

    -- Stay in sync
    self:syncBelt()

    if next(self.selectedActorIds) then
        -- For now we'll dismiss belt when something is selected. Should make it so
        -- the inspector and the belt never try to be visible at the same time.
        self.beltVisible = false

        -- Focus the blueprint of some selected actor so that we'll be on it
        -- if the user opens the belt again
        local needToFocus = true
        for actorId in pairs(self.selectedActorIds) do
            local actor = self.actors[actorId]
            if actor and actor.parentEntryId == self.beltEntryId then
                -- `next(...)` below may not consistently give us the same
                -- item, so prevent trashing
                needToFocus = false
            end
        end
        if needToFocus then
            local actorId = next(self.selectedActorIds)
            local actor = self.actors[actorId]
            local entry = actor and actor.parentEntryId and self.library[actor.parentEntryId]
            if entry and not entry.isCore then
                self:focusEntryInBelt(entry.entryId, { noShow = true })
            end
        end
    end

    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Save previous velocity, we'll use this for smoothing at the end
    local prevBeltCursorVX = self.beltCursorVX

    -- Animate belt show / hide
    if not self.beltTop then
        self.beltTop = windowHeight -- Initialization
    end
    if self.beltVisible == false and self.beltTop < windowHeight then
        self.beltTop = self.beltTop + SHOW_HIDE_VY * origDt
        if self.beltTop > windowHeight then
            self.beltTop = windowHeight
        end
    end
    if self.beltVisible == true and self.beltTop > windowHeight - BELT_HEIGHT then
        self.beltTop = self.beltTop - SHOW_HIDE_VY * origDt
        if self.beltTop < windowHeight - BELT_HEIGHT then
            self.beltTop = windowHeight - BELT_HEIGHT
        end
    end

    -- Skip all this logic when hidden and animations are done
    if self.beltTop >= windowHeight and self.beltCursorVX == 0 then
        -- Scroll to target immediately so we're there and don't do an
        -- animation when opening belt again
        -- TODO(nikki): Shares logic with "Scroll to target" below, refactor out?
        local targetElem = self.beltElems[self.beltTargetIndex]
        if targetElem ~= nil then
            self.beltEntryId = targetElem.entryId
            self.targetElem = nil
            self.beltCursorX = targetElem.x
            self.beltCursorVX = 0
        else
            self.beltTargetIndex = nil
        end

        return
    end

    local skipApplyVel = false

    local dragScrolling = false
    if self.numTouches == 1 and self.maxNumTouches == 1 then -- Single touch
        local touchId, touch = next(self.touches)

        if touch.screenY > self.beltTop then -- Touch on belt
            touch.beltUsed = true -- Grab / scale-rotate steal even if `touch.used`
            touch.used = true

            local touchBeltX = touch.screenX - 0.5 * windowWidth + self.beltCursorX
            local touchBeltIndex = math.floor(touchBeltX / (ELEM_SIZE + ELEM_GAP) + 0.5) + 1

            -- Cancel existing target on press, track new target on tap
            if touch.pressed then
                self.beltTargetIndex = nil
            end
            if touch.released and not touch.movedNear and love.timer.getTime() - touch.pressTime < 0.2 then
                self.beltTargetIndex = touchBeltIndex
            end

            -- Track which element the touch begins on
            if touch.pressed then
                local placeElem = self.beltElems[touchBeltIndex]
                if placeElem then
                    touch.beltIndex = touchBeltIndex
                    placeElem.placeRelX = placeElem.x - touchBeltX
                    placeElem.placeRelY = self.beltTop + 0.5 * BELT_HEIGHT - touch.screenY
                end
            end

            -- Start placing if the touch began on an element and it's a long-ish vertical drag
            if touch.beltIndex and not touch.beltPlacing then
                local totalDX = touch.screenX - touch.initialScreenX
                local totalDY = touch.screenY - touch.initialScreenY
                local totalDLen2 = totalDX * totalDX + totalDY * totalDY
                local long = totalDLen2 > (0.25 * ELEM_SIZE) * (0.25 * ELEM_SIZE)
                local vertical = totalDY < 0 and math.abs(totalDY) > 1.2 * math.abs(totalDX)
                if long and vertical then
                    touch.beltPlacing = true
                end
            end

            -- This is a drag scroll if not placing
            if not touch.beltPlacing then
                self.beltCursorX = self.beltCursorX - touch.screenDX
                skipApplyVel = true
                dragScrolling = true

                -- Keep track of last 3 touch velocities and use max, to smooth things out
                if not touch.beltVelocities then
                    touch.beltVelocities = {}
                end
                table.insert(touch.beltVelocities, -touch.screenDX / dt)
                while #touch.beltVelocities > 3 do
                    table.remove(touch.beltVelocities, 1)
                end
                local maxVel = 0
                for _, vel in ipairs(touch.beltVelocities) do
                    if math.abs(vel) > math.abs(maxVel) then
                        maxVel = vel
                    end
                end
                self.beltCursorVX = maxVel
            end
        end

        -- Placing
        if touch.beltPlacing and touch.beltIndex then
            -- Slow down scroll real quick if we're placing
            self.beltCursorVX = 0.2 * self.beltCursorVX

            -- Update place position
            local placeElem = self.beltElems[touch.beltIndex]
            placeElem.placeX = touch.screenX + placeElem.placeRelX
            placeElem.placeY = touch.screenY + placeElem.placeRelY

            -- Touch dragged far enough into scene? Place actor!
            if touch.screenY < self.beltTop - 0.1 * BELT_HEIGHT then
                touch.beltUsed = false
                touch.beltPlacing = nil
                touch.beltIndex = nil
                placeElem.placeX, placeElem.placeY = nil, nil
                placeElem.placeRelX, placeElem.placeRelY = nil, nil
                self:_addBlueprintToScene(placeElem.entryId, touch.x, touch.y)
                self.beltVisible = false
            end
        end
    else
        -- Clear placings
        for _, elem in ipairs(self.beltElems) do
            elem.placeX, elem.placeY = nil, nil
            elem.placeRelX, elem.placeRelY = nil, nil
        end
    end

    -- Scroll to target, also manage current entry id
    -- TODO(nikki): Shares logic with "Scroll to target immedately" above, refactor out?
    local targetElem = self.beltElems[self.beltTargetIndex]
    if targetElem ~= nil then
        self.beltEntryId = targetElem.entryId
        if math.abs(targetElem.x - self.beltCursorX) <= 3 then
            -- Reached target
            self.targetElem = nil
            self.beltCursorX = targetElem.x
            self.beltCursorVX = 0
        else
            -- Rubber band toward target
            self.beltCursorX = 0.4 * targetElem.x + 0.6 * self.beltCursorX
        end
        return -- Skip velocity-based logic when in target mode
    else
        self.beltTargetIndex = nil -- Invalid target index

        -- Set entry id based on cursor position
        local cursorIndex = math.floor(self.beltCursorX / (ELEM_SIZE + ELEM_GAP) + 0.5) + 1
        if cursorIndex < 1 then
            cursorIndex = 1
        end
        if cursorIndex > #self.beltElems then
            cursorIndex = self.beltElems
        end
        local cursorElem = self.beltElems[cursorIndex]
        if cursorElem then
            self.beltEntryId = cursorElem.entryId
        end
    end

    -- Strong rubber band on ends
    local rubberBanded = false
    if not dragScrolling then
        if self.beltCursorX < 0 then
            self.beltCursorVX = 0.5 * self.beltCursorVX
            self.beltCursorX = 0.85 * self.beltCursorX
            rubberBanded = true
        end
        local maxX = self.beltElems[#self.beltElems].x
        if self.beltCursorX > maxX then
            self.beltCursorVX = 0.5 * self.beltCursorVX
            self.beltCursorX = 0.85 * self.beltCursorX + 0.15 * maxX
            rubberBanded = true
        end
    end

    -- Snap cursor to nearest elem
    local skipDecelerate = false
    if not rubberBanded and not dragScrolling then
        if math.abs(self.beltCursorVX) <= SNAP_THRESHOLD_VX then
            local projX = self.beltCursorX

            -- Apply spring force toward nearest elem
            local i = math.floor(projX / (ELEM_SIZE + ELEM_GAP) + 0.5)
            local iX = i * (ELEM_SIZE + ELEM_GAP)
            if math.abs(self.beltCursorVX) > 0.7 * SNAP_THRESHOLD_VX then
                -- Don't "pull back" if we really want to go forward
                if iX < projX and self.beltCursorVX > 0 then
                    iX = math.max(projX, iX + 0.8 * (ELEM_SIZE + ELEM_GAP))
                end
                if iX > projX and self.beltCursorVX < 0 then
                    iX = math.min(projX, iX - 0.8 * (ELEM_SIZE + ELEM_GAP))
                end
            end
            local accel = 0.7 * SNAP_THRESHOLD_VX * (iX - projX)
            local newVX = self.beltCursorVX + accel * dt
            self.beltCursorVX = 0.85 * newVX + 0.15 * self.beltCursorVX

            -- Explonential damping
            --self.beltCursorVX = 0.92 * self.beltCursorVX
        end
    end

    -- Velocity application
    if not skipApplyVel then
        self.beltCursorX = self.beltCursorX + self.beltCursorVX * dt
    end

    -- Deceleration -- stopping at proper zero if we get there
    if not skipDecelerate and self.beltCursorVX ~= 0 then
        if self.beltCursorVX > 0 then
            self.beltCursorVX = self.beltCursorVX - DECEL_X * dt
            if self.beltCursorVX < 0 then
                self.beltCursorVX = 0
            end
        elseif self.beltCursorVX < 0 then
            self.beltCursorVX = self.beltCursorVX + DECEL_X * dt
            if self.beltCursorVX > 0 then
                self.beltCursorVX = 0
            end
        end
    end

    -- Smoothing out various velocity artifacts
    if self.beltCursorVX ~= 0 then
        self.beltCursorVX = 0.8 * self.beltCursorVX + 0.2 * prevBeltCursorVX
    end
end

-- Draw

function Common:drawBelt()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Skip drawing when hidden
    if self.beltTop >= windowHeight then
        return
    end

    love.graphics.push("all")

    -- Background
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill",
        0, self.beltTop,
        windowWidth, BELT_HEIGHT)

    local elemsY = self.beltTop + 0.5 * BELT_HEIGHT

    -- Elements
    love.graphics.setColor(1, 1, 1)
    local function drawElem(elem)
        if elem.image then
            local imgW, imgH = elem.image:getDimensions()
            local scale = math.min(ELEM_SIZE / imgW, ELEM_SIZE / imgH)

            local x = 0.5 * windowWidth + elem.x - self.beltCursorX
            local y = elemsY

            if elem.placeX and elem.placeY then
                -- Use placing coordinates if we're placing
                x, y = elem.placeX, elem.placeY
            end

            love.graphics.draw(elem.image,
                x, y,
                0, scale, scale, 0.5 * imgW, 0.5 * imgH)
        end
    end
    local placeElem -- If we have a placing elem, draw it on top of others
    for i, elem in ipairs(self.beltElems) do
        if elem.placeX and elem.placeY then
            placeElem = elem
        else
            drawElem(elem)
        end
    end
    if placeElem then
        drawElem(placeElem)
    end

    -- Highlight box
    love.graphics.setColor(0, 1, 0)
    love.graphics.setLineWidth(3 * love.graphics.getDPIScale())
    local boxSize = 1.05 * ELEM_SIZE
    love.graphics.rectangle("line",
        0.5 * windowWidth - 0.5 * boxSize, elemsY - 0.5 * boxSize,
        boxSize, boxSize)

    -- Touch overlay
    love.graphics.setColor(1, 0, 1, 0.5)
    for _, touch in pairs(self.touches) do
        love.graphics.circle('fill', touch.screenX, touch.screenY, ELEM_SIZE * 0.2)
    end

    love.graphics.pop()
end
