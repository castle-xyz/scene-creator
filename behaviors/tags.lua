local TagsBehavior =
    defineCoreBehavior {
    name = "Tags",
    displayName = "tags",
    propertyNames = {
        "tagsString" -- Space-separate tags string
    },
    dependencies = {},
    propertySpecs = {
       tagsString = {
          method = 'textInput',
          label = 'tags (separated by spaces)',
       },
    },
}

-- Behavior management

function TagsBehavior.handlers:addBehavior(opts)
    self._tagToActorIds = {} -- `tag` -> `actorId` -> `true`
end

-- Component management

function TagsBehavior.handlers:addComponent(component, bp, opts)
    component.properties.tagsString = bp.tagsString or ""
    component._tags = {}
    self.setters.tagsString(self, component, component.properties.tagsString)
end

function TagsBehavior.handlers:removeComponent(component, opts)
    for tag in pairs(component._tags) do
        self._tagToActorIds[tag][component.actorId] = nil
        if not next(self._tagToActorIds[tag]) then
            self._tagToActorIds[tag] = nil
        end
    end
end

function TagsBehavior.handlers:blueprintComponent(component, bp)
    bp.tagsString = component.properties.tagsString
end

-- Setters

function TagsBehavior.setters:tagsString(component, newTagsString)
    component.properties.tagsString = newTagsString

    -- Update indices
    for tag in pairs(component._tags) do
        self._tagToActorIds[tag][component.actorId] = nil
        if not next(self._tagToActorIds[tag]) then
            self._tagToActorIds[tag] = nil
        end
    end
    component._tags = {}
    for tag in component.properties.tagsString:gmatch("%S+") do
        component._tags[tag] = true
    end
    for tag in pairs(component._tags) do
        if not self._tagToActorIds[tag] then
            self._tagToActorIds[tag] = {}
        end
        self._tagToActorIds[tag][component.actorId] = true
    end
end

-- Methods

function TagsBehavior:actorHasTag(actorId, tag)
    local component = self.components[actorId]
    if not component then
        return false
    end
    return component._tags[tag] ~= nil
end

function TagsBehavior:getActorsWithTag(tag)
    local result = {}
    if self._tagToActorIds[tag] then
        for actorId in pairs(self._tagToActorIds[tag]) do
            result[actorId] = true
        end
    end
    return result
end

function TagsBehavior:forEachActorWithTag(tag, func)
    if self._tagToActorIds[tag] then
        for actorId in pairs(self._tagToActorIds[tag]) do
            func(actorId)
        end
    end
end

-- Rules

TagsBehavior.responses["add tag"] = {
   description = "Add tags to this actor",
   category = "general",
   paramSpecs = {
      tag = {
         method = "textInput",
         label = "Tags",
         initialValue = "",
      },
   },
   run = function(self, actorId, params, context)
      local component = self.components[actorId]
      if params.tag ~= nil and params.tag ~= '' then
         for tag in params.tag:gmatch("%S+") do
            component._tags[tag] = true
            if not self._tagToActorIds[tag] then
               self._tagToActorIds[tag] = {}
            end
            self._tagToActorIds[tag][actorId] = true
         end
      end
   end,
}

TagsBehavior.responses["remove tag"] = {
   description = "Remove tags from this actor",
   category = "general",
   paramSpecs = {
      tag = {
         method = "textInput",
         label = "Tags",
         initialValue = "",
      },
   },
   run = function(self, actorId, params, context)
      local component = self.components[actorId]
      if params.tag ~= nil and params.tag ~= '' then
         for tag in params.tag:gmatch("%S+") do
            component._tags[tag] = nil
            if self._tagToActorIds[tag] then
               self._tagToActorIds[tag][actorId] = nil
            end
         end
      end
   end,
}
