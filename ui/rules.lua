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
      ui.data(
         {
            name = 'Rules',
            rules = rules,
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
