require "ui.inspector"
require "ui.inspector_actions"
require "ui.blueprints"
require "ui.rules"

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

function Client:uiActiveTool()
   -- Does the active tool have a panel?
   local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]

   if activeTool and activeTool.handlers.uiData then
      activeTool:callHandler('uiData')
   elseif activeTool and activeTool.handlers.uiPanel then
      local uiName = activeTool:getUiName()
      ui.scrollBox('inspector-tool-' .. uiName, {
            padding = 2,
            margin = 2,
            flex = 1,
      }, function()
            activeTool:callHandler('uiPanel')
      end)
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

   -- TODO: dup of some logic in inspector_actions
   local tools = {}
    for _, tool in pairs(self.tools) do
       table.insert(
          tools,
          {
             name = tool.name,
             behaviorId = tool.behaviorId,
             hasUi = not (not tool.handlers.uiPanel),
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

    ui.pane('sceneCreatorRules', function()
        self:uiRules()
    end)

    -- Settings
    ui.pane('sceneCreatorSettings', function()
        self:uiSettings()
    end)

    -- Text actors
    ui.pane('sceneCreatorTextActors', function()
        self:uiTextActorsData()
    end)

    -- Active "tool" ui (only drawing at time of writing)
    ui.pane('sceneCreatorTool', function() self:uiActiveTool() end)
end
