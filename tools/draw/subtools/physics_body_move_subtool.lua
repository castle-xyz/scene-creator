local MoveTool = defineDrawSubtool {
    category = "collision_move",
    name = "move",
}

function MoveTool.handlers:addSubtool()
    self._initialCoord = nil
    self._grabbedShape = nil
end

function MoveTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
        self._initialCoord = {
            x = touchData.touchX,
            y = touchData.touchY
        }
        local idx = self:physicsBodyData():getShapeIdxAtPoint(self._initialCoord)
        if idx then
            self._grabbedShape = self:physicsBodyData():removeShapeAtIndex(idx)
        end
    end

    if self._grabbedShape then
        local diffX, diffY = self:drawData():roundGlobalDiffCoordinatesToGrid(touchData.touchX - self._initialCoord.x, touchData.touchY - self._initialCoord.y)

        self:physicsBodyData().tempShape = self:physicsBodyData():moveShapeBy(self._grabbedShape, diffX, diffY, self:drawData():gridCellSize())
    end

    if touchData.touch.released then
        if self:physicsBodyData():commitTempShape() then
            self:saveDrawing("move", component)
        end

        self._initialCoord = nil
        self._grabbedShape = nil
    end
end
