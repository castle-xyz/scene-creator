local DEFAULT_SCENE_PROPERTIES = {
   backgroundColor = { r = 0.82, g = 0.749, b = 0.639 }, -- "nikki tan" 🤔
}

function Common:startSceneProperties()
   self.sceneProperties = util.deepCopyTable(DEFAULT_SCENE_PROPERTIES)
end

function Common:sendSetSceneProperties(properties)
   self:send("setSceneProperties", self.clientId, properties)
end

function Common:sendSetSceneProperty(name, val)
   self:send("setSceneProperty", self.clientId, name, val)
end

function Common.receivers:setSceneProperties(time, clientId, properties)
   for k, v in pairs(properties) do
      self.sceneProperties[k] = util.deepCopyTable(v)
   end
end

function Common.receivers:setSceneProperty(time, clientId, name, val)
   self.sceneProperties[name] = util.deepCopyTable(val)
end
