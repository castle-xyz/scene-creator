-- Constants

local OS = love.system.getOS()

BELT_HEIGHT = 160
local beltHeightFraction = castle.game.getInitialParams().beltHeightFraction
if beltHeightFraction then
    BELT_HEIGHT = beltHeightFraction * love.graphics.getHeight()
end

local ELEM_GAP = 20
local ELEM_SIZE = BELT_HEIGHT - 30

local DECEL_X = 2200

local SNAP_THRESHOLD_VX = 200

local SHOW_HIDE_VY = 1200

local ENABLE_HAPTICS = true

local DEBUG_TOUCHES = false

-- Start / stop

function Common:startBelt()
    self.beltDirty = true

    -- Each elem holds `entryId` + non-persistent info like renderable image, x position etc. 
    self.beltElems = {} 

    self.beltGhostActorIds = {} -- `entryId` -> `actorId` for ghost actors
    self.beltLastGhostSelectTime = nil

    self.beltCursorX = -(ELEM_SIZE + ELEM_GAP) -- Start with focus on add button
    self.beltCursorVX = 0

    self.beltVisible = true

    self.beltTop = 0 -- Initialized on first update
    self.beltBottom = BELT_HEIGHT

    self.beltTargetIndex = nil -- Target element to scroll to if not `nil`
    
    self.beltEntryId = nil -- Entry id of currently highlighted belt element

    self.beltLastVibrated = love.timer.getTime()

    self.beltHighlightEnabled = false

    self.beltHighlightCanvas = nil -- Set up lazily
    self.beltHighlightCanvas2 = nil

    self.beltHapticsGesture = false -- Whether current gesture should fire haptics

    -- Renders grey if the pixel is fully transparent, and white otherwise.
    -- Used with a multiply blend mode to darken the screen.
    self.beltHighlightShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
            color = Texel(texture, texCoords);
            if (color.a == 0.0) {
                //#define DIAGS
                #ifdef DIAGS
                    float xPix = texCoords.x * love_ScreenSize.x;
                    float yPix = texCoords.y * love_ScreenSize.y;
                    float diag = (xPix + yPix) / 20.0;
                    float f = abs(diag - floor(diag) - 0.5);
                    float c = 0.3 + f * 0.4;
                    color = vec4(c, c, c, 1.0);
                #else
                    color = vec4(0.35, 0.35, 0.35, 1.0);
                #endif
            } else {
                color = vec4(1.0, 1.0, 1.0, 1.0);
            }
            return color;
        }
    ]])

    -- Renders grey around edges, black otherwise
    self.beltOutlineShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
            vec4 c = Texel(texture, texCoords);
            if (c.a == 0.0) {
                float l = Texel(texture, vec2(texCoords.x - 1.0 / love_ScreenSize.x, texCoords.y)).a - c.a;
                float r = Texel(texture, vec2(texCoords.x + 1.0 / love_ScreenSize.x, texCoords.y)).a - c.a;
                float u = Texel(texture, vec2(texCoords.x, texCoords.y - 1.0 / love_ScreenSize.y)).a - c.a;
                float d = Texel(texture, vec2(texCoords.x, texCoords.y + 1.0 / love_ScreenSize.y)).a - c.a;
                float m = max(max(abs(l), abs(r)), max(abs(u), abs(d)));
                return vec4(m, m, m, 1.0);
            } else {
                return vec4(0.0, 0.0, 0.0, 1.0);
            }
        }
    ]])
    self.beltOutlineThickeningShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
            float c = Texel(texture, texCoords).r;
            float l = Texel(texture, vec2(texCoords.x - 1.0 / love_ScreenSize.x, texCoords.y)).r;
            float r = Texel(texture, vec2(texCoords.x + 1.0 / love_ScreenSize.x, texCoords.y)).r;
            float u = Texel(texture, vec2(texCoords.x, texCoords.y - 1.0 / love_ScreenSize.y)).r;
            float d = Texel(texture, vec2(texCoords.x, texCoords.y + 1.0 / love_ScreenSize.y)).r;
            float m = max(c, max(max(l, r), max(u, d)));
            return vec4(m, m, m, 1.0);
        }
    ]])

    -- Same as above but for icon previews (smaller size, transparent background)
    self.beltPreviewOutlineShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
            vec4 c = Texel(texture, texCoords);
                vec4 ll = Texel(texture, vec2(texCoords.x - 1.0 / 100.0, texCoords.y));
                float l = ll.a > 0.37 ? 1.0 : 0.0;
                vec4 rr = Texel(texture, vec2(texCoords.x + 1.0 / 100.0, texCoords.y));
                float r = rr.a > 0.37 ? 1.0 : 0.0;
                vec4 uu = Texel(texture, vec2(texCoords.x, texCoords.y - 1.0 / 100.0));
                float u = uu.a > 0.37 ? 1.0 : 0.0;
                vec4 dd = Texel(texture, vec2(texCoords.x, texCoords.y + 1.0 / 100.0));
                float d = dd.a > 0.37 ? 1.0 : 0.0;

                vec4 lulu = Texel(texture, vec2(texCoords.x - 1.0 / 100.0, texCoords.y - 1.0 / 100.0));
                float lu = lulu.a > 0.37 ? 1.0 : 0.0;
                vec4 ruru = Texel(texture, vec2(texCoords.x + 1.0 / 100.0, texCoords.y - 1.0 / 100.0));
                float ru = ruru.a > 0.37 ? 1.0 : 0.0;
                vec4 ldld = Texel(texture, vec2(texCoords.x - 1.0 / 100.0, texCoords.y + 1.0 / 100.0));
                float ld = ldld.a > 0.37 ? 1.0 : 0.0;
                vec4 rdrd = Texel(texture, vec2(texCoords.x + 1.0 / 100.0, texCoords.y + 1.0 / 100.0));
                float rd = rdrd.a > 0.37 ? 1.0 : 0.0;

                float m = max(max(abs(l), abs(r)), max(abs(u), abs(d)));
                m = max(m, max(max(abs(lu), abs(ru)), max(abs(ld), abs(rd))));

                return vec4(m, m, m, 1.0);
        }
    ]])
    self.beltPreviewOutlineThickeningShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
            //float xx = floor(10.0 * texCoords.x);
            //float yy = floor(10.0 * texCoords.y);
            //if (mod(xx + yy, 2.0) == 0.0) {
                //return vec4(0.0);
            //}
            float c = Texel(texture, texCoords).r;
            float l = Texel(texture, vec2(texCoords.x - 1.0 / love_ScreenSize.x, texCoords.y)).r;
            float r = Texel(texture, vec2(texCoords.x + 1.0 / love_ScreenSize.x, texCoords.y)).r;
            float u = Texel(texture, vec2(texCoords.x, texCoords.y - 1.0 / love_ScreenSize.y)).r;
            float d = Texel(texture, vec2(texCoords.x, texCoords.y + 1.0 / love_ScreenSize.y)).r;
           //float lu = Texel(texture, vec2(texCoords.x - 1.0 / love_ScreenSize.x, texCoords.y - 1.0 / love_ScreenSize.y)).r;
           //float ru = Texel(texture, vec2(texCoords.x + 1.0 / love_ScreenSize.x, texCoords.y - 1.0 / love_ScreenSize.y)).r;
           //float ld = Texel(texture, vec2(texCoords.x - 1.0 / love_ScreenSize.x, texCoords.y + 1.0 / love_ScreenSize.y)).r;
           //float rd = Texel(texture, vec2(texCoords.x + 1.0 / love_ScreenSize.x, texCoords.y + 1.0 / love_ScreenSize.y)).r;
            float m = max(c, max(max(l, r), max(u, d)));
           //m = max(m, max(max(lu, ru), max(ld, rd)));
            return vec4(m, m, m, m == 0.0 ? 0.0 : 1.0);
        }
    ]])

    -- Below from https://github.com/vrld/moonshine/blob/d39271e0c000e2fedbc2e3ad286b78b5a5146065/boxblur.lua#L20
    self.beltOutlineBlurShader = love.graphics.newShader([[
        #define RADIUS 1.0
        extern vec2 direction;
        vec4 effect(vec4 color, Image texture, vec2 tc, vec2 _) {
            vec4 c = vec4(0.0);
            for (float i = -RADIUS; i <= RADIUS; i += 1.0)
            {
                c += Texel(texture, tc + i * direction);
            }
            return c / (2.0 * RADIUS + 1.0) * color;
        }
    ]])
    self.beltPreviewOutlineBlurShader = love.graphics.newShader([[
        #define RADIUS 3.0
        extern vec2 direction;
        vec4 effect(vec4 color, Image texture, vec2 tc, vec2 _) {
            vec4 c = vec4(0.0);
            for (float i = -RADIUS; i <= RADIUS; i += 1.0)
            {
                c += Texel(texture, tc + i * direction);
            }
            return c / (2.0 * RADIUS + 1.0) * color;
        }
    ]])

    self.beltTextCanvas = nil
    self.beltPreviewCanvas = nil
    self.beltPreviewCanvas2 = nil
end

-- Layout

function Common:getBeltYOffset()
    if self.isEditable and not self:isActiveToolFullscreen() then
        return BELT_HEIGHT
    end
    return 0
end

-- Haptics

function Common:fireBeltHaptic()
    local currTime = love.timer.getTime()
    if currTime - self.beltLastVibrated > 0.03 then
        if OS == 'iOS' then
            if false then
                love.system.vibrate(0.71) -- Tuned for our iOS vibration patch
            end
        else
            love.system.vibrate(0.04)
        end
        self.beltLastVibrated = currTime
    end
end

-- Update

local EMPTY_BASE64_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQAAAAB0CZXLAAAAAnRSTlMAAHaTzTgAAAAfSURBVHic7cEBDQAAAMKg909tDjegAAAAAAAAAAC+DSEAAAHxZyHuAAAAAElFTkSuQmCC'
local emptyDrawingIcon = love.graphics.newImage('assets/artless-blueprint.png')

function Common:updateBeltElemImage(elem, entry)
    --local padding = 0.05 * ELEM_SIZE
    --local size = ELEM_SIZE
    local padding = 16
    local size = 256

    elem.base64Png = entry.base64Png

    if entry.base64Png == EMPTY_BASE64_PNG then
        elem.image = emptyDrawingIcon
        return
    end

    if not self.beltPreviewCanvas then
        self.beltPreviewCanvas = love.graphics.newCanvas(size, size)
    end
    if not self.beltPreviewCanvas2 then
        self.beltPreviewCanvas2 = love.graphics.newCanvas(size, size)
    end

    -- Create renderable texture from saved preview data in blueprint
    local decoded = love.data.decode("data", "base64", entry.base64Png)
    local imgData = love.image.newImageData(decoded)
    local img = love.graphics.newImage(imgData)

    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.push('all')
    self.beltPreviewCanvas:renderTo(function()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(self.beltPreviewOutlineShader)
        love.graphics.draw(img, padding, padding, 0, (size - 2 * padding) / img:getWidth())
    end)
    for i = 1, 4 do
        self.beltPreviewCanvas2:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setShader(self.beltPreviewOutlineThickeningShader)
            love.graphics.draw(self.beltPreviewCanvas)
        end)
        self.beltPreviewCanvas:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setShader(self.beltPreviewOutlineThickeningShader)
            love.graphics.draw(self.beltPreviewCanvas2)
        end)
    end
    for i = 1, 0 do
        self.beltPreviewCanvas2:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)
            self.beltPreviewOutlineBlurShader:send("direction", { 1 / 128, 0 })
            love.graphics.setShader(self.beltPreviewOutlineBlurShader)
            love.graphics.draw(self.beltPreviewCanvas)
        end)
        self.beltPreviewCanvas:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)
            self.beltPreviewOutlineBlurShader:send("direction", { 0, 1 / 128 })
            love.graphics.setShader(self.beltPreviewOutlineBlurShader)
            love.graphics.draw(self.beltPreviewCanvas2)
        end)
    end
    love.graphics.pop()
    self.beltPreviewCanvas2:renderTo(function()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.beltPreviewCanvas)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, padding, padding, 0, (size - 2 * padding) / img:getWidth())
    end)
    love.graphics.pop()

    elem.image = love.graphics.newImage(self.beltPreviewCanvas2:newImageData())
end

local textPreviewFont = love.graphics.newFont('assets/Roboto-Regular.ttf', 32)
local textPreviewFontHeight = textPreviewFont:getHeight()

local textPreviewOffset = textPreviewFontHeight * 0.3
local textPreviewSize = textPreviewFontHeight * 4 
local textPreviewCanvasSize = textPreviewSize + 2 * textPreviewOffset

function Common:updateBeltElemImageFromText(elem, text, tappable)
    elem.lastPreviewedText = text
    elem.lastPreviewedTextTappable = tappable
    if not self.beltTextCanvas then
        self.beltTextCanvas = love.graphics.newCanvas(textPreviewCanvasSize, textPreviewCanvasSize, {
            dpiscale = 1,
            msaa = 4,
        })
    end
    self.beltTextCanvas:renderTo(function()
        love.graphics.push('all')
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)

        if tappable then
            love.graphics.setColor(0, 0, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle('fill', 0, 0, textPreviewCanvasSize, textPreviewCanvasSize, 0.8 * textPreviewOffset)

        love.graphics.setFont(textPreviewFont)
        if #text > 0 then
            if tappable then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0, 0, 0)
            end
            local width, wrapped = textPreviewFont:getWrap(text, textPreviewSize)
            for i = 1, 4 do
                if wrapped[i] then
                    love.graphics.print(wrapped[i], textPreviewOffset, textPreviewOffset + textPreviewFontHeight * (i - 1))
                end
            end
        end

        if tappable then
            love.graphics.setLineWidth(3)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle('line', 2, 2, textPreviewCanvasSize - 4, textPreviewCanvasSize - 4, 0.8 * textPreviewOffset)
        end

        love.graphics.pop()
    end)
    elem.image = love.graphics.newImage(self.beltTextCanvas:newImageData())
end

function Common:markBeltDirty()
    -- Mark belt as needing synchronization
    self.beltDirty = true
end

local function isTextTappable(entry)
    local rulesComp = entry.actorBlueprint and entry.actorBlueprint.components and entry.actorBlueprint.components.Rules
    if rulesComp then
        for _, rule in ipairs(rulesComp.rules) do
            if rule.trigger.name == 'tap' then
                return true
            end
        end
    end
    return false
end

function Common:syncBelt()
    -- Synchronize belt data with library entries

    if self.performing then
        return
    end
    if not self.beltDirty then
        return
    end

    -- Update images that changed
    for _, elem in ipairs(self.beltElems) do
        local entry = self.library[elem.entryId]
        -- Lua interns strings so hopefully the comparison is quick when equal
        if entry then
            local textComp = entry.actorBlueprint and entry.actorBlueprint.components and entry.actorBlueprint.components.Text
            if textComp then
                local newContent = textComp.content or ''
                local newTappable = isTextTappable(entry)
                if newContent ~= entry.lastPreviewedText or newTappable ~= entry.lastPreviewdTextTappable then
                    self:updateBeltElemImageFromText(elem, textComp.content or '', newTappable)
                end
            elseif entry and entry.base64Png ~= elem.base64Png then 
                self:updateBeltElemImage(elem, entry)
            end
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
            local textComp = entry.actorBlueprint and entry.actorBlueprint.components and entry.actorBlueprint.components.Text
            if textComp then
                self:updateBeltElemImageFromText(newElem, textComp.content or '', isTextTappable(entry))
            elseif entry.base64Png then
                self:updateBeltElemImage(newElem, entry)
            end
            table.insert(self.beltElems, newElem)
        end
    end

    -- Remove old elements from belt
    do
        local numElems = #self.beltElems
        local filledI = 1
        for i = numElems, 1, -1 do
            if not self.library[self.beltElems[i].entryId] then
                table.remove(self.beltElems, i)
            end
        end
    end

    -- Sort belt
    table.sort(self.beltElems, function(a, b)
        local entryA = self.library[a.entryId]
        local entryB = self.library[b.entryId]
        if entryA.beltOrder ~= entryB.beltOrder then
            return (entryA.beltOrder or 0) < (entryB.beltOrder or 0)
        end
        return entryA.title:lower() < entryB.title:lower()
    end)

    -- Calculate positions
    for i, elem in ipairs(self.beltElems) do
        elem.x = (ELEM_SIZE + ELEM_GAP) * (i - 1)
    end

    -- Update ghost actors
    for entryId, entry in pairs(self.library) do
        if not entry.isCore and (not self.beltGhostActorIds[entryId] or not self.actors[self.beltGhostActorIds[entryId]]) then
            -- Use a stable mapping from entry id -> ghost actor id so that
            -- it's preserved across undo / redo
            local ghostActorId = 'ghost:' .. entryId

            -- Remove existing actor with this id just in case
            if self.actors[ghostActorId] then
                self:send('removeActor', self.clientId, ghostActorId)
            end

            -- Add new ghost actor
            local bp = util.deepCopyTable(entry.actorBlueprint)
            if bp.components.Body then
                bp.components.Body.x = 0
                bp.components.Body.y = 0
            end
            self:sendAddActor(bp, {
                actorId = ghostActorId,
                parentEntryId = entryId,
                isGhost = true,
            })

            self.beltGhostActorIds[entryId] = ghostActorId
        end
    end
    for entryId, ghostActorId in pairs(self.beltGhostActorIds) do
        if not self.library[entryId] then
            -- Remove associations for removed entries
            if self.actors[ghostActorId] then
                self:send('removeActor', self.clientId, ghostActorId)
            end
            self.beltGhostActorIds[entryId] = nil
        end
    end

    self.beltDirty = false

    -- Focus the currently selected entry again (mostly helps if its order changed)
    if self.beltEntryId then
        for i, elem in ipairs(self.beltElems) do
            if elem.entryId == self.beltEntryId then
                self.beltTargetIndex = i
                return
            end
        end
    end
end

function Common:syncSelectionsWithBelt()
    if next(self.selectedActorIds) then
        -- Don't do anything if we're already focused on a selected actor's blueprint
        for actorId in pairs(self.selectedActorIds) do
            local actor = self.actors[actorId]
            if actor and actor.parentEntryId == self.beltEntryId then
                return
            end
        end

        -- Try to pick some selected non-ghost actor and focus its blueprint
        for actorId in pairs(self.selectedActorIds) do
            local actor = self.actors[actorId]
            if not actor.isGhost then
                local entry = actor and actor.parentEntryId and self.library[actor.parentEntryId]
                if entry and not entry.isCore then
                    -- Find element and target it
                    for i, elem in ipairs(self.beltElems) do
                        if elem.entryId == entry.entryId then
                            self.beltTargetIndex = i
                            self.beltEntryId = entry.entryId
                            return
                        end
                    end
                end
            end
        end
    end
end

function Common:syncBeltGhostSelection()
    -- Don't select too rapidly
    local currTime = love.timer.getTime()
    if math.abs(self.beltCursorVX) > 10 and self.beltLastGhostSelectTime and currTime - self.beltLastGhostSelectTime < 0.2 then
        return
    end

    -- If any non-ghost actor is selected, we don't need a ghost
    for actorId in pairs(self.selectedActorIds) do
        local actor = self.actors[actorId]
        if not actor.isGhost then
            return
        end
    end

    -- If ghost isn't selected, deselect all and select it
    if self.beltGhostActorIds[self.beltEntryId] then
        local ghostActorId = self.beltGhostActorIds[self.beltEntryId]
        if not self.selectedActorIds[ghostActorId] then
            local theBeltEntryId = self.beltEntryId -- Save and restore this across deselection
            self:deselectAllActors()
            self.beltEntryId = theBeltEntryId
            self:selectActor(ghostActorId)
            self:applySelections()
            self.beltLastGhostSelectTime = currTime
        end
    end
end

function Common:updateBelt(dt)
    if self.performing then
        return
    end

    -- Make belt snap quicker. Resorted to making time faster after tuning the
    -- other constants for spring damping + deceleration...
    local origDt = dt
    dt = 1.6 * dt 

    -- Stay in sync
    self:syncBelt()
    self:syncSelectionsWithBelt()

    local currTime = love.timer.getTime()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    local prevBeltCursorX = self.beltCursorX
    local prevBeltCursorVX = self.beltCursorVX

    local skipApplyVel = false

    local dragScrolling = false
    if not self:isActiveToolFullscreen() and self.numTouches == 1 and self.maxNumTouches == 1 then -- Single touch
        local touchId, touch = next(self.touches)

        if touch.beltUsed or (not touch.used and touch.screenY < self.beltBottom) then -- Touch on belt
            ui.setUpdatesPaused(false) -- Update inspector eagerly to reflect focused blueprint

            if not touch.beltPlaced and next(self.selectedActorIds) then
                self:deselectAllActors({ noDeselectBelt = true })
            end

            touch.beltUsed = true -- Grab / scale-rotate steal even if `touch.used`
            touch.used = true

            local touchBeltX = touch.screenX - 0.5 * windowWidth + self.beltCursorX
            local touchBeltIndex = math.floor(touchBeltX / (ELEM_SIZE + ELEM_GAP) + 0.5) + 1

            -- Cancel existing target on press, track new target on tap. Also enable highlight
            if touch.pressed then
                self.beltTargetIndex = nil
                touch.beltStartVX = self.beltCursorVX
            end
            if touch.released and not touch.movedNear and currTime - touch.pressTime < 0.2 then
                if math.abs(touch.beltStartVX) > ELEM_SIZE / 1.2 then
                    -- Scrolling pretty fast, likely the user just wanted to 'stop' and not actually target at tap.
                    -- So just target the element under the cursor
                    if self.beltEntryId then
                        local cursorIndex = math.floor(self.beltCursorX / (ELEM_SIZE + ELEM_GAP) + 0.5) + 1
                        cursorIndex = math.max(1, math.min(cursorIndex, #self.beltElems))
                        local cursorElemX = self.beltElems[cursorIndex].x
                        if cursorElemX < self.beltCursorX and touch.beltStartVX > 0 then
                            cursorIndex = cursorIndex + 1
                        elseif cursorElemX > self.beltCursorX and touch.beltStartVX < 0 then
                            cursorIndex = cursorIndex - 1
                        end
                        cursorIndex = math.max(1, math.min(cursorIndex, #self.beltElems))
                        self.beltTargetIndex = cursorIndex
                    end
                else
                    -- Scrolling slow, target the tapped element
                    self.beltTargetIndex = touchBeltIndex
                    if touchBeltIndex == 0 then
                        self:beltOnTouchNewBlueprint()
                    end
                end
                if self.beltTargetIndex then
                    self.beltHighlightEnabled = true -- Enable highlight on belt touch
                    self:fireBeltHaptic()
                    self.beltLastGhostSelectTime = nil -- Inspect it immediately
                end
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
            if not touch.beltNeverPlace and touch.beltIndex and not touch.beltPlacing then
                self.beltHapticsGesture = false -- Don't distract user with haptics in placing mode

                local totalDX = touch.screenX - touch.initialScreenX
                local totalDY = touch.screenY - touch.initialScreenY
                local totalDLen2 = totalDX * totalDX + totalDY * totalDY
                local long = totalDLen2 > (0.25 * ELEM_SIZE) * (0.25 * ELEM_SIZE)
                local vertical = touch.screenY > self.beltBottom + 0.6 * BELT_HEIGHT or math.abs(totalDY) > 1.5 * math.abs(totalDX)
                if long and vertical then
                    touch.beltPlacing = true
                end
            end

            -- This is a drag scroll if not placing
            if not (touch.beltPlacing or touch.beltPlaced) then
                self.beltHapticsGesture = true -- Enable haptics on a scroll

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

                -- If the touch moves far enough along X without exiting belt
                -- bottom, keep as drag scroll forever
                if touch.screenY < self.beltBottom and math.abs(touch.screenX - touch.initialScreenX) > 1.2 * ELEM_SIZE then
                    touch.beltNeverPlace = true
                end
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
            if not self.isInspectorSheetMaximized and touch.screenY > self.beltBottom + 0.6 * BELT_HEIGHT then
                touch.beltUsed = false
                touch.beltPlacing = nil
                touch.beltIndex = nil
                placeElem.placeX, placeElem.placeY = nil, nil
                placeElem.placeRelX, placeElem.placeRelY = nil, nil
                self:_addBlueprintToScene(placeElem.entryId, touch.x, touch.y, {
                    noSaveUndo = true, -- We'll add a coalesced undo on touch release (see below)
                })
                touch.beltPlaced = true
                touch.beltPlacedEntryId = placeElem.entryId

                -- Sync immediately with placed actor
                self:syncSelectionsWithBelt()
                self.beltLastGhostSelectTime = nil
            end
        end
        if touch.beltPlaced and touch.screenY < self.beltBottom then
            -- Dragged back into belt -- cancel placing
            for actorId in pairs(self.selectedActorIds) do
                local actor = self.actors[actorId]
                if actor and not actor.isGhost then
                    self:deselectActor(actorId)
                    self:applySelections()
                    self:send('removeActor', self.clientId, actorId)
                    break
                end
            end
        end
        if touch.beltPlaced and touch.released then
            local entryId = touch.beltPlacedEntryId
            for actorId in pairs(self.selectedActorIds) do
                local actor = self.actors[actorId]
                if actor and not actor.isGhost and actor.parentEntryId == entryId then
                    -- Do at end of frame to allow grab tool to apply any last motions
                    table.insert(self.onEndOfFrames, function()
                        local x, y = 0, 0
                        local bodyId, body = self.behaviorsByName.Body:getBody(actorId)
                        if body then
                            x, y = body:getPosition()
                        end
                        self:send('removeActor', self.clientId, actorId)
                        self:_addBlueprintToScene(entryId, x, y, {
                            actorId = actorId,
                        })
                    end)
                end
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
    local targetMode = false
    local targetElem = self.beltElems[self.beltTargetIndex]
    if targetElem then
        self.beltEntryId = targetElem.entryId
        if math.abs(targetElem.x - self.beltCursorX) <= 3 then
            -- Reached target
            self.beltTargetIndex = nil
            self.beltCursorX = targetElem.x
            self.beltCursorVX = 0
        else
            -- Rubber band toward target
            self.beltCursorX = 0.4 * targetElem.x + 0.6 * self.beltCursorX
        end
        targetMode = true
    else
        self.beltTargetIndex = nil -- Invalid target index

        -- If have current entry, update based on cursor position
        if self.beltEntryId then
            local cursorIndex = math.floor(self.beltCursorX / (ELEM_SIZE + ELEM_GAP) + 0.5) + 1
            cursorIndex = math.max(1, math.min(cursorIndex, #self.beltElems))
            local cursorElem = self.beltElems[cursorIndex]
            if cursorElem and cursorElem.entryId ~= self.beltEntryId then
                self.beltHighlightEnabled = true
                self.beltEntryId = cursorElem.entryId
            end
        end
    end

    if not targetMode then
        local rubberBandMode = false
        -- Strong rubber band on ends
        if not dragScrolling then
            if #self.beltElems == 0 then
                self.beltCursorVX = 0.5 * self.beltCursorVX
                self.beltCursorX = 0.85 * self.beltCursorX + 0.15 * -(ELEM_SIZE + ELEM_GAP)
                rubberBandMode = true
            else
                if self.beltCursorX < 0 then
                    self.beltCursorVX = 0.5 * self.beltCursorVX
                    self.beltCursorX = 0.85 * self.beltCursorX
                    rubberBandMode = true
                end
                local maxX = self.beltElems[#self.beltElems].x
                if self.beltCursorX > maxX then
                    self.beltCursorVX = 0.5 * self.beltCursorVX
                    self.beltCursorX = 0.85 * self.beltCursorX + 0.15 * maxX
                    rubberBandMode = true
                end
            end
        end

        -- Snap cursor to nearest elem
        local skipDecelerate = false
        if self.beltEntryId and not rubberBandMode and not dragScrolling then
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
                local newVX = self.beltCursorVX + accel * math.min(dt, 0.038)
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

    -- Vibrate when we go across elements
    if ENABLE_HAPTICS and self.beltHapticsGesture and self.beltEntryId then
        local offset
        if self.beltCursorX < prevBeltCursorX then
            offset = 0.5 + 0.32
        end
        if self.beltCursorX > prevBeltCursorX then
            offset = 0.5 - 0.32
        end
        if offset then
            local currIndex = math.floor(self.beltCursorX / (ELEM_SIZE + ELEM_GAP) + offset)
            currIndex = math.max(-1, math.min(currIndex, #self.beltElems))
            local prevIndex = math.floor(prevBeltCursorX / (ELEM_SIZE + ELEM_GAP) + offset)
            prevIndex = math.max(-1, math.min(prevIndex, #self.beltElems))
            if currIndex ~= prevIndex then
                self:fireBeltHaptic()
            end
        end
    end
    if math.abs(self.beltCursorVX) <= 1 then
        self.beltHapticsGesture = false -- Scroll ended
    end

    -- Disable highlight when no entry selected, or if some non-ghost actor is selected
    if not self.beltEntryId then
        self.beltHighlightEnabled = false
    else
        for actorId in pairs(self.selectedActorIds) do
            local actor = self.actors[actorId]
            if not actor.isGhost then
                self.beltHighlightEnabled = false
                break
            end
        end
    end

    self:syncBeltGhostSelection()
end

local DrawingData = require 'library_drawing_data'

jsEvents.listen(
    "NEW_BLUEPRINT",
    function(params)
        local self = currentInstance()
        if not self then
            return
        end
        local entry = CORE_TEMPLATES[params.templateIndex + 1]
        entry = util.deepCopyTable(entry)
        if entry.title == 'Object' or entry.actorBlueprint and entry.actorBlueprint.components and entry.actorBlueprint.components.Text then
            -- Blank or text actor should have blank preview
            entry.base64Png = nil
        end
        local newEntryId = util.uuid()

        -- Templates have some unfilled data, so we 'canonicalize' it by creating a temporary actor and loading back
        if entry.actorBlueprint then
            local newActorId = self:sendAddActor(entry.actorBlueprint, {
                parentEntryId = newEntryId,
                isGhost = true,
            })
            local actorBp = self:blueprintActor(newActorId)
            if actorBp.components.Body then
                actorBp.components.Body.x, actorBp.components.Body.y = nil, nil
            end
            entry.actorBlueprint = actorBp
            self:send('removeActor', self.clientId, newActorId)
        end

        self:command('add blueprint', {
            params = { 'entry', 'newEntryId' },
        }, function(params, live)
            self:duplicateBlueprint(entry, { keepTitle = true, newEntryId = newEntryId })
            if live then
                -- Immediately select entry
                self:syncBelt()
                self:deselectAllActors()
                for i, elem in ipairs(self.beltElems) do
                    if elem.entryId == newEntryId then
                        self.beltTargetIndex = i
                        self.beltEntryId = newEntryId
                        self.beltHighlightEnabled = true
                        break
                    end
                end
                self:syncBeltGhostSelection()
            end
        end, function()
            self:send('removeLibraryEntry', newEntryId)
        end)
    end
)

jsEvents.listen(
    "PASTE_BLUEPRINT",
    function(params)
        local entry = params.entry
        if not entry then
            return
        end

        local self = currentInstance()
        if not self then
            return
        end

        local oldEntry = self.library[entry.entryId]
        entry = util.deepCopyTable(entry)
        local newEntryId = entry.entryId
        if not oldEntry then
            -- New entry by pasting
            self:command('add blueprint from clipboard', {
                params = { 'entry', 'newEntryId' },
            }, function(params, live)
                self:duplicateBlueprint(entry, { keepTitle = true, newEntryId = newEntryId })
                if live then
                    -- Immediately select entry
                    self:syncBelt()
                    self:deselectAllActors()
                    for i, elem in ipairs(self.beltElems) do
                        if elem.entryId == newEntryId then
                            self.beltTargetIndex = i
                            self.beltEntryId = newEntryId
                            self.beltHighlightEnabled = true
                            break
                        end
                    end
                    self:syncBeltGhostSelection()
                end
            end, function()
                self:send('removeLibraryEntry', newEntryId)
            end)
        else
            -- Update existing entry by pasting
            self:command('update blueprint from clipboard', {
                params = { 'entry', 'oldEntry', 'newEntryId' },
            }, function(params, live)
                self:send('updateLibraryEntry', self.clientId, newEntryId, entry, {
                    updateActors = true,
                })
                if live then
                    -- Immediately select entry
                    self:syncBelt()
                    self:deselectAllActors()
                    for i, elem in ipairs(self.beltElems) do
                        if elem.entryId == newEntryId then
                            self.beltTargetIndex = i
                            self.beltEntryId = newEntryId
                            self.beltHighlightEnabled = true
                            break
                        end
                    end
                    self:syncBeltGhostSelection()
                end
            end, function()
                self:send('updateLibraryEntry', self.clientId, newEntryId, oldEntry, {
                    updateActors = true,
                })
            end)
        end
    end
)

function Common:beltOnTouchNewBlueprint()
    jsEvents.send('SHOW_NEW_BLUEPRINT_SHEET', {})
end

-- Draw

local titleFont = love.graphics.newFont(32)

function Common:drawBeltHighlight()
    if self:isActiveToolFullscreen() then
        return
    end
    if not self.beltVisible then
        return
    end

    local windowWidth, windowHeight = love.graphics.getDimensions()

    if not self.performing and self.beltHighlightEnabled then
        -- Set up and render to highlight canvas
        if not self.beltHighlightCanvas then
            self.beltHighlightCanvas = love.graphics.newCanvas(windowWidth, windowHeight - BELT_HEIGHT)
        end
        if not self.beltHighlightCanvas2 then
            self.beltHighlightCanvas2 = love.graphics.newCanvas(windowWidth, windowHeight - BELT_HEIGHT)
        end
        self.beltHighlightCanvas:renderTo(function()
            love.graphics.push("all")
            love.graphics.clear(0, 0, 0, 0)

            love.graphics.origin()
            love.graphics.applyTransform(self.viewTransform)

            local drawBehaviors = self.behaviorsByHandler["drawComponent"] or {}
            local entry = self.library[self.beltEntryId]
            if entry and not entry.isCore then
                self:forEachActorByDrawOrder(function(actor)
                    -- Render actor if it uses the currently highlighted blueprint
                    if actor and actor.parentEntryId and actor.parentEntryId == self.beltEntryId then
                        for behaviorId, behavior in pairs(drawBehaviors) do
                            local component = actor.components[behaviorId]
                            if component then
                                behavior:callHandler("drawComponent", component)
                            end
                        end
                    end
                end)
            end

            love.graphics.pop()
        end)

        -- Render highlight canvas to screen
        love.graphics.push("all") -- Transparent overlay (to make obscured actors visible)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.draw(self.beltHighlightCanvas)
        love.graphics.pop()
        love.graphics.push("all") -- Darken other actors
        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.setShader(self.beltHighlightShader)
        love.graphics.draw(self.beltHighlightCanvas)
        love.graphics.pop()

        -- Glow
        self.beltHighlightCanvas2:renderTo(function()
            -- Gray outside edges
            love.graphics.push("all")
            love.graphics.setShader(self.beltOutlineShader)
            love.graphics.draw(self.beltHighlightCanvas)
            love.graphics.pop()
        end)
        self.beltHighlightCanvas:renderTo(function()
            -- Spread the gray further
            love.graphics.push("all")
            love.graphics.setShader(self.beltOutlineThickeningShader)
            love.graphics.draw(self.beltHighlightCanvas2)
            love.graphics.pop()
        end)
        --self.beltHighlightCanvas2:renderTo(function()
        --    -- Blur horizontally
        --    love.graphics.push("all")
        --    self.beltOutlineBlurShader:send("direction", { 1 / love.graphics.getWidth(), 0 })
        --    love.graphics.setShader(self.beltOutlineBlurShader)
        --    love.graphics.draw(self.beltHighlightCanvas)
        --    love.graphics.pop()
        --end)
        --self.beltHighlightCanvas:renderTo(function()
        --    -- Blur vertically
        --    love.graphics.push("all")
        --    self.beltOutlineBlurShader:send("direction", { 0, 1 / love.graphics.getHeight() })
        --    love.graphics.setShader(self.beltOutlineBlurShader)
        --    love.graphics.draw(self.beltHighlightCanvas2)
        --    love.graphics.pop()
        --end)
        love.graphics.push("all")
        love.graphics.setBlendMode("add") -- Glow
        love.graphics.draw(self.beltHighlightCanvas)
        love.graphics.pop()
    end
end

function Common:drawBelt()
    if self:isActiveToolFullscreen() then
        return
    end
    if not self.beltVisible then
        return
    end

    local windowWidth, windowHeight = love.graphics.getDimensions()

    love.graphics.push("all")

    -- Background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill",
        0, self.beltTop,
        windowWidth, BELT_HEIGHT)

    local elemsY = self.beltTop + 0.5 * BELT_HEIGHT
    if not self.performing then -- Empty when playtesting

        -- Elements
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(3 * love.graphics.getDPIScale())
        local function drawElem(elem)
            local x = 0.5 * windowWidth + elem.x - self.beltCursorX
            local y = elemsY

            if elem.placeX and elem.placeY then
                -- Use placing coordinates if we're placing
                x, y = elem.placeX, elem.placeY
            end

            local img = elem.image or emptyDrawingIcon
            local imgW, imgH = img:getDimensions()
            local scale = math.min(ELEM_SIZE / imgW, ELEM_SIZE / imgH)

            love.graphics.draw(img,
                x, y,
                0, scale, scale, 0.5 * imgW, 0.5 * imgH)
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
        if self.beltEntryId then
            local actorSelected = false
            for actorId in pairs(self.selectedActorIds) do
                local actor = self.actors[actorId]
                if actor and not actor.isGhost then
                    actorSelected = true
                    break
                end
            end
            if actorSelected then
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.setLineWidth(2 * love.graphics.getDPIScale())
            else
                love.graphics.setColor(0, 1, 0)
                love.graphics.setLineWidth(3 * love.graphics.getDPIScale())
            end
            local boxSize = 1.08 * ELEM_SIZE
            love.graphics.rectangle("line",
                0.5 * windowWidth - 0.5 * boxSize, elemsY - 0.5 * boxSize,
                boxSize, boxSize, boxSize * 0.04)
        end

        -- New blueprint button
        do
            local buttonX = 0.5 * windowWidth - (ELEM_SIZE + ELEM_GAP) - self.beltCursorX

            local BUTTON_RADIUS = 0.7 * 0.5 * ELEM_SIZE
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', buttonX, elemsY, BUTTON_RADIUS)

            local PLUS_FACTOR = 0.5
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(0.04 * ELEM_SIZE)
            love.graphics.line(buttonX - PLUS_FACTOR * BUTTON_RADIUS, elemsY, buttonX + PLUS_FACTOR * BUTTON_RADIUS, elemsY)
            love.graphics.line(buttonX, elemsY - PLUS_FACTOR * BUTTON_RADIUS, buttonX, elemsY + PLUS_FACTOR * BUTTON_RADIUS)
        end

        -- Title for current element
        --love.graphics.setColor(1, 1, 1)
        --local currEntry = self.library[self.beltEntryId]
        --if currEntry and currEntry.title then
        --    local w = titleFont:getWidth(currEntry.title)
        --    local h = titleFont:getHeight()
        --    love.graphics.print(currEntry.title, titleFont,
        --        0.5 * windowWidth - 0.5 * w,
        --        self.beltBottom + 0.2 * h)
        --end

        -- Debug touch overlay
        if DEBUG_TOUCHES and not self:isActiveToolFullscreen() then
            love.graphics.setColor(1, 0, 1, 0.5)
            for _, touch in pairs(self.touches) do
                love.graphics.circle('fill', touch.screenX, touch.screenY, ELEM_SIZE * 0.2)
            end
        end
    end

    love.graphics.pop()
end
