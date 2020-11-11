local Rules = {}

-- TODO: we only do this because the raw entries contain functions,
-- which cannot be serialized.
-- this method won't be necessary after entries stop containing ui logic.
function Rules.sanitizeEntries(categories)
   local result = {}
   for categoryName, entries in pairs(categories) do
      local category = {}
      for _, entry in pairs(entries) do
         local cleanEntry = {
            name = entry.name,
            description = entry.entry.description,
            behaviorId = entry.behaviorId,
            behaviorName = entry.behaviorName,
            category = entry.category,
            paramSpecs = entry.entry.paramSpecs,
            returnType = entry.entry.returnType,
            triggerFilter = entry.entry.triggerFilter,
         }
         table.insert(category, cleanEntry)
      end
      result[categoryName] = category
   end
   return result
end

function Client:_addSoundActions(actions)
   -- TODO: we could generalize to an onChange callback on responses
   -- and diff old -> new rules to see what changed.
   -- right now sound is the only thing that needs this.
   actions['changeSound'] = function(params)
      self:addSound(params)
      self:playSound(params)
      self:buildSoundPool() -- release any unreferenced previous sound
   end
end

function Client:uiRules()
   local actorId = next(self.selectedActorIds)
   if actorId then
      local actor = self.actors[actorId]
      local rulesBehavior = self.behaviorsByName.Rules
      local actions = {}
      local rules = {}

      -- top-level rules actions
      local component = actor.components[rulesBehavior.behaviorId]
      if component then
         actions['add'] = function()
            self.behaviorsByName.Rules:addRule(actorId, component)
         end
         actions['change'] = function(newRules)
            self.behaviorsByName.Rules:changeRules(
               actorId, component,
               function()
                  component.properties.rules = newRules
               end
            )
         end
         actions['copy'] = function(rulesToCopy)
            self.behaviorsByName.Rules:copyRules(component, rulesToCopy)
         end
         actions['paste'] = function()
            self.behaviorsByName.Rules:pasteRules(component)
         end
         self:_addSoundActions(actions)
         rules = component.properties.rules
      else
         actions['add'] = function(blueprint)
            self:_addBehavior(actor, rulesBehavior.behaviorId, blueprint)
            component = actor.components[rulesBehavior.behaviorId]
         end
         actions['paste'] = function()
            self:_addBehavior(actor, rulesBehavior.behaviorId)
            component = actor.components[rulesBehavior.behaviorId]
            self.behaviorsByName.Rules:pasteRules(component)
         end
      end

      local triggers = rulesBehavior:getRuleEntries('trigger', self.behaviors, { triggerFilter = "all" })
      local responses = rulesBehavior:getRuleEntries('response', self.behaviors, { triggerFilter = "all" })
      local conditions = rulesBehavior:getRuleEntries('response', self.behaviors, { returnType = 'boolean' }, { triggerFilter = "all" })
      
      ui.data(
         {
            name = 'Rules',
            rules = util.noArray(rules),
            triggers = Rules.sanitizeEntries(triggers),
            responses = Rules.sanitizeEntries(responses),
            conditions = Rules.sanitizeEntries(conditions),
            isClipboardEmpty = rulesBehavior:isClipboardEmpty(),
         },
         {
            actions = actions,
         }
      )
   end
end
