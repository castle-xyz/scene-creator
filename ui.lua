require "ui.inspector"
require "ui.inspector_actions"
require "ui.blueprints"
require "ui.rules"
require "ui.expressions"

-- Start / stop

function Client:startUi()
    self.updateCounts = setmetatable({}, { __mode = 'k' }) -- `actor` -> count to force UI updates
    self.saveBlueprintDatas = setmetatable({}, { __mode = 'k' }) -- `actor` -> data for "save blueprint" popover
end

-- UI

function Client:_textActorHasTapTrigger(actor)
   for behaviorId, component in pairs(actor.components) do
      local behavior = self.behaviors[behaviorId]
      if behavior.name == 'Rules' then
         return behavior.handlers.componentHasTrigger(component, 'tap')
      end
   end
end

function Client:uiTextActorsData()
   local textActors = {}
   local textActorsContent = self.behaviorsByName.Text:parseComponentsContent(self.performing)
   for actorId, component in pairs(self.behaviorsByName.Text.components) do
      local actor = self.actors[actorId]
      if not (actor.isGhost and not self.selectedActorIds[actorId]) then -- Skip if unselected ghost
          local visible = true
          if self.performing then
             visible = component.properties.visible or false
          end
          textActors[actorId] = {
             content = textActorsContent[actorId],
             order = component.properties.order,
             visible = visible,
             actor = actor,
             isSelected = self.selectedActorIds[actorId] ~= nil,
             hasTapTrigger = self:_textActorHasTapTrigger(actor),
             isGhost = actor.isGhost,
          }
      end
   end
   ui.data({ textActors = textActors })
end

function Client:uiActiveTool()
   local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]
   if activeTool and activeTool.handlers.uiData then
      activeTool:callHandler('uiData')
   else
      ui.data({})
   end
end

function Client:uiGlobalActions()
   local actionsAvailable = {}
   local actions = {}

   actionsAvailable['onPlay'] = not self.performing
   actions['onPlay'] = function()
      endEditing()
   end

   actionsAvailable['onRewind'] = self.performing
   actions['onRewind'] = function()
      beginEditing()
   end

   local hasUndo, hasRedo = #self.undos > 0, #self.redos > 0
   actionsAvailable['onUndo'] = hasUndo
   actions['onUndo'] = function()
      self:undo()
   end
   actionsAvailable['onRedo'] = hasRedo
   actions['onRedo'] = function()
      self:redo()
   end

   actionsAvailable['startCapture'] = self.performing and not self:isCapturing()
   actions['startCapture'] = function()
      self:startCapture()
   end

   actions['clearCapture'] = function()
      self:clearCapture()
   end

   -- TODO: dup of some logic in inspector_actions
   local tools = {}
    for _, tool in pairs(self.tools) do
       table.insert(
          tools,
          {
             name = tool.name,
             behaviorId = tool.behaviorId,
          }
       )
    end
    actions['setActiveTool'] = function(id) self:setActiveTool(id) end
    actions['resetActiveTool'] = function(id) self:setActiveTool(self.behaviorsByName.Grab.behaviorId) end
   
   ui.data(
      {
         performing = self.performing,
         selectedActorId = next(self.selectedActorIds),
         actionsAvailable = actionsAvailable,
         tools = tools,
         activeToolBehaviorId = self.activeToolBehaviorId,
         beltVisible = self.beltVisible,
      },
      {
         actions = actions,
      }
   )
end

function Client:uiSettings()
   local actions, data = {}, {}

   -- tools (e.g. grab and scale)
   for behaviorId, tool in pairs(self.tools) do
      if tool.handlers.uiSettings then
         tool:callHandler('uiSettings', data, actions)
      end
   end

   -- scene properties
   data.sceneProperties = {}
   for k, v in pairs(self.sceneProperties) do
      data.sceneProperties[k] = v
      actions['set:' .. k] = function(newValue)
         self:sendSetSceneProperty(k, newValue)
      end
   end
   
   ui.data(data, { actions = actions })
end

function Client:uiupdate()
   local uiSelf = self

   profileFunction('uiupdate.uiTextActorsData', function()
      -- Text actors
      ui.pane('sceneCreatorTextActors', function()
         uiSelf:uiTextActorsData()
      end)
   end)

   if not self.isEditable then
      return
   end

   profileFunction('uiupdate.uiGlobalActions', function()
      -- Global actions
      ui.pane('sceneCreatorGlobalActions', function()
         uiSelf:uiGlobalActions()
      end)
   end)

   if self.performing then
      return
   end

   profileFunction('uiupdate.applySelections', function()
      -- Refresh tools first to make sure selections and applicable tool set are valid
      uiSelf:applySelections()
   end)

   if self.activeToolBehaviorId == self.behaviorsByName.Draw2.behaviorId then
      profileFunction('uiupdate.uiActiveTool', function()
         -- Active "tool" ui (only drawing at time of writing)
         ui.pane('sceneCreatorTool', function() uiSelf:uiActiveTool() end)
      end)

      return
   end

   profileFunction('uiupdate.uiBlueprints', function()
      -- Blueprints
      ui.pane('sceneCreatorBlueprints', function()
         uiSelf:uiBlueprints()
      end)
   end)

   profileFunction('uiupdate.uiInspectorActions', function()
      -- Inspector
      ui.pane('sceneCreatorInspectorActions', function()
         uiSelf:uiInspectorActions()
      end)
   end)

   local sceneCreatorInspectorProps = {}
   local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]

   if activeTool and activeTool.handlers.contentHeight then
      sceneCreatorInspectorProps.contentHeight = activeTool.handlers.contentHeight()
   end

   profileFunction('uiupdate.uiInspector', function()
      ui.pane('sceneCreatorInspector', sceneCreatorInspectorProps, function()
         uiSelf:uiInspector()
      end)
   end)

   profileFunction('uiupdate.uiRules', function()
      ui.pane('sceneCreatorRules', function()
         uiSelf:uiRules()
      end)
   end)

   profileFunction('uiupdate.uiExpressions', function()
       ui.pane('sceneCreatorExpressions', function()
           uiSelf:uiExpressions()
       end)
   end)

   profileFunction('uiupdate.uiSettings', function()
      -- Settings
      ui.pane('sceneCreatorSettings', function()
         uiSelf:uiSettings()
      end)
   end)
end
