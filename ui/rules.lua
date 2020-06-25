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
            behaviorId = entry.behaviorId,
            behaviorName = entry.behaviorName,
            category = entry.category,
            entry = {
               returnType = entry.entry.returnType,
               triggerFilter = entry.entry.triggerFilter,
               initialParams = entry.entry.initialParams,
            },
         }
         table.insert(category, cleanEntry)
      end
      result[categoryName] = category
   end
   return result
end

function Client:_addRule(actorId, component)
   self.behaviorsByName.Rules:addRule(actorId, component)
end

function Client:uiRules()
   local actorId = next(self.selectedActorIds)
   if actorId then
      local actor = self.actors[actorId]
      local rulesBehavior = self.behaviorsByName.Rules
      local actions = {}
      local rules = {} -- TODO: replace with individual data panes

      -- top-level rules actions
      local component = actor.components[rulesBehavior.behaviorId]
      if component then
         actions['add'] = function()
            self:_addRule(actorId, component)
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
      
      ui.data(
         {
            name = 'Rules',
            rules = rules,
            triggers = Rules.sanitizeEntries(triggers),
            responses = Rules.sanitizeEntries(responses),
         },
         {
            actions = actions,
         }
      )
      
      --[[
         TODO: ui.pane (from ui.lua) containing many ui.datas
         - ui.data for each rule
         ----- actions: specific to rule
         ]]--
   end
end
