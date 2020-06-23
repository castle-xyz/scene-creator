local Inspector = {
}

function Client:_uiActorAllowsBehavior(actor, behavior)
   -- if actor has body and this is text, return false
   if (actor.components[self.behaviorsByName.Body.behaviorId] and behavior == self.behaviorsByName.Text) then
      return false
   end

   -- if actor has text and this is not rules or text, return false
   if (actor.components[self.behaviorsByName.Text.behaviorId] and behavior ~= self.behaviorsByName.Rules) and behavior ~= self.behaviorsByName.Text then
      return false
   end
   return true
end

function Client:_removeBehavior(actorId, component, behavior)
    local uiName = behavior:getUiName()
    if next(component.dependents) ~= nil then -- Has dependents?
        local names = {}
        for dependentId in pairs(component.dependents) do
            local dependent = self.behaviors[dependentId]
            table.insert(names, dependent:getUiName())
        end
        local list = ''
        for i = 1, #names do
            if i > 1 then
                if i < #names then
                    list = list .. ', '
                else
                    list = list .. ' and '
                end
            end
            list = list .. "'" .. names[i] .. "'"
        end
        local message = (list .. ' need' .. (#names > 1 and '' or 's') .. " '" ..
            uiName .. "'.")
        castle.system.alert("Cannot remove '" .. uiName .. "'", message)
    else
        local behaviorId = component.behaviorId
        local componentBp = {}
        behavior:callHandler('blueprintComponent', component, componentBp)
        self:command('remove ' .. uiName, {
            params = { 'behaviorId', 'componentBp' },
        }, function()
            local behavior = self.behaviors[behaviorId]
            if not behavior.components[actorId] then
                return 'behavior was removed'
            end
            self:send('removeComponent', self.clientId, actorId, behaviorId)
            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
        end, function()
            local behavior = self.behaviors[behaviorId]
            if behavior.components[actorId] then
                return 'behavior was added'
            end
            self:send('addComponent', self.clientId, actorId, behaviorId, componentBp)
            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
        end)
    end
end

function Client:_addBehavior(actor, behaviorId, blueprint)
    local behavior = self.behaviors[behaviorId]
    local actorId = actor.actorId

    -- Get full order of adding behaviors in case of non-present dependencies
    local order = {}
    local visited = {}
    local function visit(behavior)
        if visited[behavior.behaviorId] then
            return
        end
        visited[behavior.behaviorId] = true
        if not actor.components[behavior.behaviorId] then
            for _, dependency in pairs(behavior.dependencies) do
                visit(dependency)
            end
            table.insert(order, behavior.behaviorId)
        end
    end
    visit(behavior)

    self:command('add ' .. behavior:getUiName(), {
        params = { 'behaviorId', 'order', 'blueprint' },
    }, function()
        local behavior = self.behaviors[behaviorId]
        if behavior.components[actorId] then
            return 'behavior was added'
        end
        for i = 1, #order do
            local bp = (i == #order) and blueprint or {} -- use provided blueprint only for root component being added
            self:send('addComponent', self.clientId, actorId, order[i], bp, {
                interactive = true,
            })
        end
        self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
    end, function()
        local behavior = self.behaviors[behaviorId]
        if not behavior.components[actorId] then
            return 'behavior was removed'
        end
        for i = #order, 1, -1 do
            self:send('removeComponent', self.clientId, actorId, order[i])
        end
        self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
    end)
end

function Client:uiInspector()
   local actorId = next(self.selectedActorIds)
   if actorId then
      local actor = self.actors[actorId]

      -- behaviors data
      for behaviorName, behavior in pairs(self.behaviorsByName) do
         local actions = {}
         local properties = {}
         local isActive = false
         local component = actor.components[behavior.behaviorId]
         if component then
            isActive = true
            for propertyName, _ in pairs(behavior.propertySpecs) do
               -- actions to set value for each property of the behavior
               actions['set:' .. propertyName] = function(value)
                  behavior:sendSetProperties(actorId, propertyName, value)
               end
               -- current value of each property of the behavior
               if behavior.getters[propertyName] then
                  properties[propertyName] = behavior.getters[propertyName](behavior, component)
               else
                  properties[propertyName] = component.properties[propertyName]
               end
            end
            -- action to remove behavior from this actor
            actions['remove'] = function()
               self:_removeBehavior(actorId, component, behavior)
            end
         elseif self.tools[behavior.behaviorId] then
            -- action to use tool
            actions['setActiveTool'] = function()
               self:setActiveTool(behavior.behaviorId)
            end
         else
            -- actor does not have this behavior, action to add it
            actions['add'] = function(blueprint)
               self:_addBehavior(actor, behavior.behaviorId, blueprint)
            end
         end

         local dependencies = {}
         for _, dep in ipairs(behavior.dependencies) do
            table.insert(dependencies, dep)
         end
         
         ui.data(
            {
               name = behaviorName,
               isActive = isActive,
               dependencies = dependencies,
               propertySpecs = behavior.propertySpecs,
               properties = properties,
            },
            {
               actions = actions,
            }
         )
      end
   end
end
