local Sound = {
   -- key -> { params, source }
   sources = {},
}

function Sound.makeKey(params)
   return 'sound-' .. tostring(params.category) .. tostring(params.seed)
end

function Sound.makeSource(params)
   local sound = sfxr:newSound()
   if params.category == "pickup" then
      sound:randomPickup(params.seed)
   elseif params.category == "laser" then
      sound:randomLaser(params.seed)
   elseif params.category == "explosion" then
      sound:randomExplosion(params.seed)
   elseif params.category == "powerup" then
      sound:randomPowerup(params.seed)
   elseif params.category == "hit" then
      sound:randomHit(params.seed)
   elseif params.category == "jump" then
      sound:randomJump(params.seed)
   elseif params.category == "blip" then
      sound:randomBlip(params.seed)
   else
      sound:randomize(params.seed)
   end
   local sounddata = sound:generateSoundData()
   local source = love.audio.newSource(sounddata)
   source:setVolume(1)
   return source
end

-- when performing is about to start,
-- scan all responses in the scene, and save sources for all audio objects
-- and delete ones that are changed or unused
function Client:buildSoundPool()
   local rules = self.behaviorsByName.Rules
   local keyUsed = {}
   for actorId, component in pairs(rules.components) do
      for _, rule in ipairs(component.properties.rules) do
         self:_addResponseToSoundPool(rule.response, keyUsed)
      end
   end

   -- clear unreferenced sounds by keyUsed
   for key, sound in pairs(Sound.sources) do
      if not keyUsed[key] then
         sound.source:release()
         Sound.sources[key] = nil
      end
   end
end

function Client:_addResponseToSoundPool(response, keyUsed)
   if not response then return end

   if response.name == "play sound" then
      local key = Sound.makeKey(response.params)
      keyUsed[key] = true
      if not Sound.sources[key] then
         Sound.sources[key] = {
               params = response.params,
               source = Sound.makeSource(response.params),
         }
      end
   end
   
   if response.params then
      self:_addResponseToSoundPool(response.params.nextResponse)
      self:_addResponseToSoundPool(response.params.body)
      self:_addResponseToSoundPool(response.params["then"])
      self:_addResponseToSoundPool(response.params["else"])
   end
end

function Client:playSound(params)
   local key = Sound.makeKey(params)
   if Sound.sources[key] then
      Sound.sources[key].source:play()
   else
      print('Tried to play a sound that is not in the sound pool')
   end
end
