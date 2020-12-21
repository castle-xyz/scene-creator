local EraseTool = defineDrawSubtool {
    category = "collision",
    name = "collision_erase",
}

function EraseTool.handlers:addSubtool()
    self._initialCoord = nil
end

function EraseTool.handlers:onTouch(component, touchData)
    if self._initialCoord == nil then
        self._initialCoord = touchData.roundedCoord

        local idx = self:physicsBodyData():getShapeIdxAtPoint(self._initialCoord)
        if idx then
            self:physicsBodyData():removeShapeAtIndex(idx)
            self:saveDrawing("erase", component)
        end
    end

    if touchData.touch.released then
        self._initialCoord = nil
    end
end
