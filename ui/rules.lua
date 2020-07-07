local Rules = {}

-- cjson will try to serialize 1-indexed consecutive tables to arrays, but will later
-- encounter issues with diffs if we try to grow the array, so instead just pick
-- not-1-indexed keys to convince the bridge that this should never be an array.
function Rules.noArray(array)
   local result = {}
   for k, v in ipairs(array) do
      result[k + 42] = v
   end
   return result
end

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
            initialParams = entry.entry.initialParams,
            returnType = entry.entry.returnType,
            triggerFilter = entry.entry.triggerFilter,
         }
         table.insert(category, cleanEntry)
      end
      result[categoryName] = category
   end
   return result
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
         rules = component.properties.rules
      else
         actions['add'] = function(blueprint)
            self:_addBehavior(actor, rulesBehavior.behaviorId, blueprint)
            component = actor.components[rulesBehavior.behaviorId]
            self:_addRule(actorId, component)
         end
      end

      local triggers = rulesBehavior:getRuleEntries('trigger', self.behaviors)
      local responses = rulesBehavior:getRuleEntries('response', self.behaviors)
      local conditions = rulesBehavior:getRuleEntries('response', self.behaviors, { returnType = 'boolean' })
      
      ui.data(
         {
            name = 'Rules',
            rules = Rules.noArray(rules),
            triggers = Rules.sanitizeEntries(triggers),
            responses = Rules.sanitizeEntries(responses),
            conditions = Rules.sanitizeEntries(conditions),
         },
         {
            actions = actions,
         }
      )
   end
end

function Client:uiLegacyRules()
   local actorId = next(self.selectedActorIds)
   if actorId then
      local actor = self.actors[actorId]
      local rulesBehavior = self.behaviorsByName.Rules
      local component = actor.components[rulesBehavior.behaviorId]
      if component then
         rulesBehavior:callHandler('uiComponent', component)
      end
   end
end
