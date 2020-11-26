DEFAULT_SCENE_PROPERTIES = {
   backgroundColor = { r = 227 / 255, g = 230 / 255, b = 252 / 255 },
}

NEW_CARD_SCENE_PROPERTIES = {
   coordinateSystemVersion = 2,
}

function Common:getDefaultYOffset()
   local yPosition = 0.5 * DEFAULT_VIEW_WIDTH
   if self.sceneProperties.coordinateSystemVersion == 2 then
      yPosition = 0.5 * DEFAULT_VIEW_WIDTH * VIEW_HEIGHT_TO_WIDTH_RATIO
   end

   return yPosition
end

function Common:getYOffset()
   local yPosition = 0.5 * self.viewWidth
   if self.sceneProperties.coordinateSystemVersion == 2 then
      yPosition = 0.5 * self.viewWidth * VIEW_HEIGHT_TO_WIDTH_RATIO
   end

   return yPosition
end

function Common:startSceneProperties()
   self.sceneProperties = util.deepCopyTable(DEFAULT_SCENE_PROPERTIES)

   if self.isNewScene then
      for k, v in pairs(NEW_CARD_SCENE_PROPERTIES) do
         self.sceneProperties[k] = v
      end
   end
end

function Common:sendSetSceneProperties(properties, opts)
   self:send("setSceneProperties", self.clientId, properties, opts)
end

function Common:sendSetSceneProperty(name, val)
   self:send("setSceneProperty", self.clientId, name, val)
end

function Common.receivers:setSceneProperties(time, clientId, properties, opts)
   if opts.snapshotLoaded then
      if properties.backgroundColor == nil then
         -- snapshot did not contain a background color, use legacy tan color
         properties.backgroundColor = { r = 0.82, g = 0.749, b = 0.639 }
      end
   end

   for k, v in pairs(properties) do
      self.sceneProperties[k] = util.deepCopyTable(v)
   end
end

function Common.receivers:setSceneProperty(time, clientId, name, val)
   self.sceneProperties[name] = util.deepCopyTable(val)
end
