local Inspector = {
}

jsEvents.listen(
    "SCENE_CREATOR_INSPECTOR_SHEET_MAXIMIZED",
    function(params)
        local self = currentInstance()
        if self then
            self.isInspectorSheetMaximized = params.isMaximized
        end
    end
)

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

function Client:_getDependenciesOrder(actor, behavior)
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
    return order
end

function Client:_checkDependentsForRemoval(component)
    local uiName = self.behaviors[component.behaviorId]:getUiName()
    local message

    -- check dependent behaviors
    if next(component.dependents) ~= nil then
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
        message = (list .. ' need' .. (#names > 1 and '' or 's') .. " '" ..
            uiName .. "'.")
    end

    -- check whether any rules reference this behavior
    local rules = self.behaviorsByName.Rules
    local rulesComponent = rules.components[component.actorId]
    if not message and rulesComponent then
       local referenced, reason = rules:componentReferencesBehavior(rulesComponent, self.behaviors[component.behaviorId])
       if referenced then
          if reason == "trigger" then
             message = "This actor has rule triggers which reference this behavior"
          elseif reason == "response" then
             message = "This actor has rule responses which reference this behavior"
          else
             message = "This actor has rules which reference this behavior"
          end
       end
    end

    if message then
       castle.system.alert("Cannot remove '" .. uiName .. "'", message)
       return false
    end
    return true
end

function Client:_removeBehavior(actorId, component, behavior)
    local uiName = behavior:getUiName()
    if self:_checkDependentsForRemoval(component) then
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
            self:updateBlueprintFromActor(actorId)
        end, function()
            local behavior = self.behaviors[behaviorId]
            if behavior.components[actorId] then
                return 'behavior was added'
            end
            self:send('addComponent', self.clientId, actorId, behaviorId, componentBp)
            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
            self:updateBlueprintFromActor(actorId)
        end)
    end
end

function Client:_addBehavior(actor, behaviorId, blueprint)
    local behavior = self.behaviors[behaviorId]
    local actorId = actor.actorId
    local order = self:_getDependenciesOrder(actor, behavior)

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
        self:updateBlueprintFromActor(actorId)
    end, function()
        local behavior = self.behaviors[behaviorId]
        if not behavior.components[actorId] then
            return 'behavior was removed'
        end
        for i = #order, 1, -1 do
            self:send('removeComponent', self.clientId, actorId, order[i])
        end
        self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
        self:updateBlueprintFromActor(actorId)
    end)
end

function Client:_swapBehavior(actor, component, newBehaviorId, blueprint)
    local actorId = actor.actorId
    local newBehavior = self.behaviors[newBehaviorId]
    local oldBehaviorId = component.behaviorId
    local oldBehavior = self.behaviors[oldBehaviorId]

    if not self:_checkDependentsForRemoval(component) then return end

    local oldComponentBp = {}
    oldBehavior:callHandler('blueprintComponent', component, oldComponentBp)

    local order = self:_getDependenciesOrder(actor, newBehavior)
    
    self:command('swap ' .. oldBehavior:getUiName() .. ' with ' .. newBehavior:getUiName(), {
        params = { 'oldBehaviorId', 'oldComponentBp', 'newBehaviorId', 'order', 'blueprint' },
    }, function()
        if not self.behaviors[oldBehaviorId].components[actorId] then
            return 'old behavior was removed'
        end
        if self.behaviors[newBehaviorId].components[actorId] then
            return 'new behavior was added'
        end

        self:send('removeComponent', self.clientId, actorId, oldBehaviorId)
        for i = 1, #order do
            local bp = (i == #order) and blueprint or {} -- use provided blueprint only for root component being added
            self:send('addComponent', self.clientId, actorId, order[i], bp, {
                interactive = true,
            })
        end
        self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
        self:updateBlueprintFromActor(actorId)
    end, function()
        if not self.behaviors[newBehaviorId].components[actorId] then
            return 'new behavior was removed'
        end
        if self.behaviors[oldBehaviorId].components[actorId] then
            return 'old behavior was added'
        end
        for i = #order, 1, -1 do
            self:send('removeComponent', self.clientId, actorId, order[i])
        end
        self:send('addComponent', self.clientId, actorId, oldBehaviorId, oldComponentBp)
        self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
        self:updateBlueprintFromActor(actorId)
    end)
end

function Client:_setProperty(actorId, behaviorId, propertyName, oldValue, newValue)
   self:command(
      'change ' .. propertyName,
      {
         coalesceLast = false,
         coalesceSuffix = propertyName,
         params = { "behaviorId", "actorId", "propertyName", "oldValue", "newValue" },
      },
      function()
         local behavior = self.behaviors[behaviorId]
         behavior:sendSetProperties(actorId, propertyName, newValue)
         self:updateBlueprintFromActor(actorId)
      end,
      function()
         local behavior = self.behaviors[behaviorId]
         behavior:sendSetProperties(actorId, propertyName, oldValue)
         self:updateBlueprintFromActor(actorId)
      end
   )
end

function Client:_enableComponent(actorId, behavior)
   local behaviorId = behavior.behaviorId
   self:command(
      'enable ' .. behavior:getUiName(),
      {
         params = { "behaviorId", "actorId" },
      },
      function()
         self:send('enableComponent', self.clientId, actorId, behaviorId)
         self:updateBlueprintFromActor(actorId)
      end,
      function()
         self:send('disableComponent', self.clientId, actorId, behaviorId)
         self:updateBlueprintFromActor(actorId)
      end
   )
end

function Client:_disableComponent(actorId, behavior)
   local behaviorId = behavior.behaviorId
   self:command(
      'disable ' .. behavior:getUiName(),
      {
         params = { "behaviorId", "actorId" },
      },
      function()
         self:send('disableComponent', self.clientId, actorId, behaviorId)
         self:updateBlueprintFromActor(actorId)
      end,
      function()
         self:send('enableComponent', self.clientId, actorId, behaviorId)
         self:updateBlueprintFromActor(actorId)
      end
   )
end

function Client:uiInspector()
   local actorId = next(self.selectedActorIds)
   if actorId then
      local actor = self.actors[actorId]

      -- behaviors data
      for behaviorName, behavior in pairs(self.behaviorsByName) do
         local actions = {}
         local properties = {}
         local isActive, isDisabled = false, false
         local component = actor.components[behavior.behaviorId]
         if component then
            isActive = true
            isDisabled = not (not component.disabled)
            for propertyName, propertySpec in pairs(behavior.propertySpecs) do
               if propertySpec.method ~= nil then
                  -- current value of each property of the behavior
                  if behavior.getters[propertyName] then
                     properties[propertyName] = behavior.getters[propertyName](behavior, component)
                  else
                     properties[propertyName] = component.properties[propertyName]
                  end
                  -- actions to set value for each property of the behavior
                  actions['set:' .. propertyName] = function(value)
                     self:_setProperty(actorId, behavior.behaviorId, propertyName, properties[propertyName], value)
                  end
               end
            end
            -- action to remove behavior from this actor
            actions['remove'] = function()
               self:_removeBehavior(actorId, component, behavior)
            end
            -- action to swap this behavior for another
            actions['swap'] = function(newBlueprint)
               local newBehaviorName = newBlueprint.name
               local newBehaviorId = self.behaviorsByName[newBehaviorName].behaviorId
               self:_swapBehavior(actor, component, newBehaviorId, newBlueprint)
            end
            -- actions to enable/disable this behavior for this actor
            if behavior.allowsDisableWithoutRemoval then
               actions['enable'] = function()
                  self:_enableComponent(actorId, behavior)
               end
               actions['disable'] = function()
                  self:_disableComponent(actorId, behavior)
               end
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

         if behavior.behaviorId == self.behaviorsByName.Body.behaviorId then
             actions['applyLayoutChangesToBlueprint'] = function()
                 local actor = self.actors[actorId]
                 if not actor or not actor.parentEntryId then
                     return
                 end
                 local saves = {}
                 for otherActorId, otherActor in pairs(self.actors) do
                     if otherActor.parentEntryId == actor.parentEntryId then
                         table.insert(saves, {
                             actorId = otherActorId,
                             bp = self:blueprintActor(otherActorId),
                             drawOrder = otherActor.drawOrder,
                             isGhost = otherActor.isGhost,
                         })
                     end
                 end
                 table.sort(saves, function(save1, save2)
                     return save1.drawOrder < save2.drawOrder
                 end)
                 local entryId = actor.parentEntryId
                 self:command('apply layout',  {
                     params = { 'saves', 'entryId' },
                 }, function()
                     self:updateBlueprintFromActor(actorId, { applyLayoutChanges = true })
                 end, function()
                     for _, save in ipairs(saves) do
                         self:send("removeActor", self.clientId, save.actorId)
                         self:sendAddActor(save.bp, {
                             actorId = save.actorId,
                             parentEntryId = entryId,
                             drawOrder = save.drawOrder,
                             isGhost = save.isGhost,
                         })
                     end
                 end)
             end
         end
         
         ui.data(
            {
               behaviorId = behavior.behaviorId,
               name = behaviorName,
               displayName = behavior.displayName,
               allowsDisableWithoutRemoval = behavior.allowsDisableWithoutRemoval,
               isActive = isActive,
               isDisabled = isDisabled,
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
