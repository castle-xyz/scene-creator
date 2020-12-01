-- Constants

local BELT_HEIGHT = 200

local ELEM_SIZE = 170
local ELEM_GAP = 20

local DECEL_X = 2000

local SNAP_THRESHOLD_VX = 200

local SHOW_HIDE_VY = 1200

-- Start / stop

function Common:startBelt()
    self.beltDirty = true

    self.beltElems = {}

    self.beltCursorX = 0
    self.beltCursorVX = 0

    self.beltVisible = false

    self.beltTop = nil -- Initialized on first update
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

-- Update

function Common:markBeltDirty()
    -- Mark belt as needing synchronization
    self.beltDirty = true
end

function Common:syncBelt()
    -- Synchronize belt data with library entries

    -- Collect set of ids the current belt data covers
    local currElemIds = {}
    for _, beltElem in ipairs(self.beltElems) do
        currElemIds[beltElem.entryId] = true
    end

    -- Prepare list of new elements
    local newElems = {}
    for entryId, entry in pairs(self.library) do
        if not currElemIds[entryId] then
            local newElem = {}
            newElem.entryId = entry.entryId
            newElem.title = entry.title
            newElem.order = entry.beltOrder
            if newElem.order == nil then
                newElem.order = 0
            end
            if entry.base64Png then
                local decoded = love.data.decode("data", "base64", entry.base64Png)
                local imgData = love.image.newImageData(decoded)
                newElem.image = love.graphics.newImage(imgData)
            end
            table.insert(newElems, newElem)
        end
    end

    -- Save new elements
    for _, newElem in ipairs(newElems) do
        table.insert(self.beltElems, newElem)
    end

    -- Sort belt
    table.sort(self.beltElems, function(a, b)
        return a.order < b.order
    end)

    -- Calculate positions
    for i, elem in ipairs(self.beltElems) do
        elem.x = (ELEM_SIZE + ELEM_GAP) * (i - 1)
    end

    self.beltDirty = false
end

function Common:updateBelt(dt)
    if self.beltDirty then
        self:syncBelt()
    end

    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Animate belt in / out
    if not self.beltTop then
        self.beltTop = windowHeight -- Initialization
    end
    if self.beltVisible == false and self.beltTop < windowHeight then
        self.beltTop = self.beltTop + SHOW_HIDE_VY * dt
        if self.beltTop > windowHeight then
            self.beltTop = windowHeight
        end
    end
    if self.beltVisible == true and self.beltTop > windowHeight - BELT_HEIGHT then
        self.beltTop = self.beltTop - SHOW_HIDE_VY * dt
        if self.beltTop < windowHeight - BELT_HEIGHT then
            self.beltTop = windowHeight - BELT_HEIGHT
        end
    end

    -- Skip all this logic when hidden and animations are done
    if self.beltTop >= windowHeight and self.beltCursorVX == 0 then
        return
    end

    local skipApplyVel = false

    local dragScrolling = false
    if self.numTouches == 1 and self.maxNumTouches == 1 then -- Single touch
        local touchId, touch = next(self.touches)

        if touch.screenY > self.beltTop then -- Touch on belt
            -- Track which element was first pressed on
            if touch.pressed then
                local touchBeltX = touch.screenX - 0.5 * windowWidth + self.beltCursorX

                local beltIndex = math.floor(touchBeltX / (ELEM_SIZE + ELEM_GAP) + 0.5) + 1
                local placeElem = self.beltElems[beltIndex]
                if placeElem then
                    touch.beltIndex = beltIndex
                    placeElem.placeRelX = placeElem.x - touchBeltX
                    placeElem.placeRelY = self.beltTop + 0.5 * BELT_HEIGHT - touch.screenY
                end
            end

            -- See if we should enter placing mode
            if touch.beltIndex and not touch.beltPlacing then
                local totalDX = touch.screenX - touch.initialScreenX
                local totalDY = touch.screenY - touch.initialScreenY
                local totalDLen = totalDX * totalDX + totalDY * totalDY
                local long = totalDLen > (0.25 * ELEM_SIZE) * (0.25 * ELEM_SIZE)
                local vertical = totalDY < 0 and math.abs(totalDY) > 1.2 * math.abs(totalDX)
                if long and vertical then
                    touch.beltPlacing = true
                    touch.beltUsed = true
                    touch.used = true
                end
            end

            -- This is a drag scroll if not placing
            if not touch.beltPlacing then
                touch.beltUsed = true
                touch.used = true
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
            local projX = self.beltCursorX + 0.3 * self.beltCursorVX
            local i = math.floor(projX / (ELEM_SIZE + ELEM_GAP) + 0.5)

            local beforeX = (i - 0.5) * (ELEM_SIZE + ELEM_GAP)
            local afterX = (i + 0.5) * (ELEM_SIZE + ELEM_GAP)
            local beforeDX = projX - beforeX
            local afterDX = afterX - projX

            -- Model snap using springs on both ends of the current elem. That
            -- might reduce to a spring at the current elem, so maybe we could
            -- simplify to that...
            local accel = 0
            accel = accel - 0.7 * SNAP_THRESHOLD_VX * beforeDX
            accel = accel + 0.7 * SNAP_THRESHOLD_VX * afterDX
            self.beltCursorVX = self.beltCursorVX + accel * dt

            -- Below applies explonential damping -- seems fine without it though
            --self.beltCursorVX = 0.92 * self.beltCursorVX
            --skipDecelerate = true
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
    for i, elem in ipairs(self.beltElems) do
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

    -- Highlight box
    love.graphics.setColor(0, 1, 0)
    love.graphics.setLineWidth(3 * love.graphics.getDPIScale())
    local boxSize = 1.05 * ELEM_SIZE
    love.graphics.rectangle("line",
        0.5 * windowWidth - 0.5 * boxSize, elemsY - 0.5 * boxSize,
        boxSize, boxSize)

    love.graphics.pop()
end
