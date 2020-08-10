local DEFAULT_SCENE_PROPERTIES = {
   backgroundColor = { r = 227 / 255, g = 230 / 255, b = 252 / 255 },
}

function Common:startSceneProperties()
   self.sceneProperties = util.deepCopyTable(DEFAULT_SCENE_PROPERTIES)
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
