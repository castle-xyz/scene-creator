local FillTool = defineDrawSubtool {
    category = "draw",
    name = "fill",
}

function FillTool.handlers:addSubtool()
    self._didChange = false
end

function FillTool.handlers:onTouch(component, touchData)
    if self:drawData():floodFill(touchData.touchX, touchData.touchY) then
        self._didChange = true
    end

    if touchData.touch.released then
        if self._didChange then
            self:saveDrawing("fill", component)
        end
        self._didChange = false
    end
end