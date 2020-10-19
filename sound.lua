local Sound = {
   -- key -> { params, source }
   sources = {},
}

local SOUND_MAX_DUR = 1

function Sound.makeKey(params)
   return 'sound-' .. tostring(params.category)
      .. tostring(params.seed) .. '-'
      .. tostring(params.mutationSeed) .. '-'
      .. tostring(params.mutationAmount)
end

function Sound.clampLength(sound)
   local dur = sound.envelope.attack
      + sound.envelope.sustain
      + sound.envelope.decay
   if dur > SOUND_MAX_DUR then
      local ratio = SOUND_MAX_DUR / dur
      sound.envelope.attack = sound.envelope.attack * ratio
      sound.envelope.sustain = sound.envelope.sustain * ratio
      sound.envelope.decay = sound.envelope.decay * ratio
      print('clamped sound with original dur: ' .. dur)
   end
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

   local mutationSeed = params.mutationSeed or 0
   local mutationAmount = params.mutationAmount or 5
   if mutationSeed ~= 0 then
      sound:mutate(mutationAmount, params.seed + mutationSeed)
   end

   Sound.clampLength(sound)
   
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

   for entryId, entry in pairs(self.library) do
      if entry.actorBlueprint and entry.actorBlueprint.components
      and entry.actorBlueprint.components.Rules then
         local blueprintRules = entry.actorBlueprint.components.Rules
         for _, rule in ipairs(blueprintRules.rules) do
            self:_addResponseToSoundPool(rule.response, keyUsed)
         end
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

function Client:addSound(params)
   local key = Sound.makeKey(params)
   if not Sound.sources[key] then
      Sound.sources[key] = {
         params = params,
         source = Sound.makeSource(params),
      }
   end
end

function Client:_addResponseToSoundPool(response, keyUsed)
   if not response then return end

   if response.name == "play sound" then
      local key = Sound.makeKey(response.params)
      keyUsed[key] = true
      self:addSound(response.params)
   end
   
   if response.params then
      self:_addResponseToSoundPool(response.params.nextResponse, keyUsed)
      self:_addResponseToSoundPool(response.params.body, keyUsed)
      self:_addResponseToSoundPool(response.params["then"], keyUsed)
      self:_addResponseToSoundPool(response.params["else"], keyUsed)
   end
end

function Client:playSound(params)
   local key = Sound.makeKey(params)
   if Sound.sources[key] then
      local source = Sound.sources[key].source
      if source:isPlaying() then
         source:stop()
      end
      source:play()
   else
      print('Tried to play a sound that is not in the sound pool')
   end
end
