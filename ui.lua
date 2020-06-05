require "ui.inspector"
require "ui.inspector_actions"
require "ui.blueprints"

-- Start / stop

function Client:startUi()
    self.updateCounts = setmetatable({}, { __mode = 'k' }) -- `actor` -> count to force UI updates

    self.openComponentBehaviorId = nil -- `behaviorId` of open component section

    self.selectedInspectorTab = 'general'
    self.inspectorTabs = {
       {
          name = 'general',
          behaviors = { 'Drawing', 'Text', 'Tags', 'Body' },
       },
       {
          name = 'behaviors',
       },
    }

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
      }
   end
   ui.data({ textActors = textActors })
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
   
   ui.data(
      {
         performing = self.performing,
         hasSelection = next(self.selectedActorIds) ~= nil,
         actionsAvailable = actionsAvailable,
      },
      {
         actions = actions,
      }
   )
end

function Client:uiSettings()
   for behaviorId, tool in pairs(self.tools) do
      if tool.handlers.uiSettings then
         tool:callHandler('uiSettings')
      end
   end
end

function Client:uiupdate()
    -- Refresh tools first to make sure selections and applicable tool set are valid
    self:applySelections() 

    -- Global actions
    ui.pane('sceneCreatorGlobalActions', function()
        self:uiGlobalActions()
    end)

    -- Blueprints
    ui.pane('sceneCreatorBlueprints', function()
        self:uiBlueprints()
    end)

    -- Inspector
    ui.pane('sceneCreatorInspectorActions', function()
        self:uiInspectorActions()
    end)

    local sceneCreatorInspectorProps = {}
    local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]

    if activeTool and activeTool.handlers.contentHeight then
        sceneCreatorInspectorProps.contentHeight = activeTool.handlers.contentHeight()
    end

    ui.pane('sceneCreatorInspector', sceneCreatorInspectorProps, function()
        self:uiInspector()
    end)

    -- Settings
    ui.pane('sceneCreatorSettings', function()
        self:uiSettings()
    end)

    -- Text actors
    ui.pane('sceneCreatorTextActors', function()
        self:uiTextActorsData()
    end)
end
