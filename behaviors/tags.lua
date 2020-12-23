local TagsBehavior =
    defineCoreBehavior {
    name = "Tags",
    displayName = "tags",
    dependencies = {},
    propertySpecs = {
       tagsString = {
          method = 'tagPicker',
          label = 'tags',
       },
       tagToActorIds = {
          method = 'data',
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
end

function TagsBehavior.handlers:enableComponent(component, opts)
   self.setters.tagsString(self, component, component.properties.tagsString)
end

function TagsBehavior.handlers:disableComponent(component, opts)
    for tag in pairs(component._tags) do
        tag = tag:lower()
        self._tagToActorIds[tag][component.actorId] = nil
        if not next(self._tagToActorIds[tag]) then
            self._tagToActorIds[tag] = nil
        end
    end
end

function TagsBehavior.handlers:blueprintComponent(component, bp)
    bp.tagsString = component.properties.tagsString
end

-- Getters

function TagsBehavior.getters:tagToActorIds()
   if self._tagToActorIds then
      return self._tagToActorIds
   end
   return {}
end

-- Setters

function TagsBehavior.setters:tagsString(component, newTagsString)
    component.properties.tagsString = newTagsString

    -- Update indices
    for tag in pairs(component._tags) do
       tag = tag:lower()
       self._tagToActorIds[tag][component.actorId] = nil
        if not next(self._tagToActorIds[tag]) then
            self._tagToActorIds[tag] = nil
        end
    end
    component._tags = {}
    for tag in component.properties.tagsString:gmatch("%S+") do
       tag = tag:lower()
       component._tags[tag] = true
    end
    for tag in pairs(component._tags) do
       tag = tag:lower()
       if not self._tagToActorIds[tag] then
            self._tagToActorIds[tag] = {}
        end
        self._tagToActorIds[tag][component.actorId] = true
    end
end

function TagsBehavior.setters:tagToActorIds()
   -- noop, use other setter
end

-- Methods

function TagsBehavior:actorHasTag(actorId, tag)
    local component = self.components[actorId]
    if not component then
        return false
    end
    tag = tag:lower()
    return component._tags[tag] ~= nil
end

function TagsBehavior:getActorsWithTag(tag)
    local result = {}
    tag = tag:lower()
    if self._tagToActorIds[tag] then
        for actorId in pairs(self._tagToActorIds[tag]) do
            result[actorId] = true
        end
    end
    return result
end

function TagsBehavior:forEachActorWithTag(tag, func)
    tag = tag:lower()
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
         method = "tagPicker",
         label = "Tags",
         initialValue = "",
      },
   },
   run = function(self, actorId, params, context)
      local component = self.components[actorId]
      if params.tag ~= nil and params.tag ~= '' then
         for tag in params.tag:gmatch("%S+") do
            tag = tag:lower()
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
         method = "tagPicker",
         label = "Tags",
         initialValue = "",
      },
   },
   run = function(self, actorId, params, context)
      local component = self.components[actorId]
      if params.tag ~= nil and params.tag ~= '' then
         for tag in params.tag:gmatch("%S+") do
            tag = tag:lower()
            component._tags[tag] = nil
            if self._tagToActorIds[tag] then
               self._tagToActorIds[tag][actorId] = nil
            end
         end
      end
   end,
}

TagsBehavior.responses["has tag"] = {
    description = "If this has a tag",
    category = "state",
    returnType = "boolean",
    paramSpecs = {
       tag = {
         method = "tagPicker",
         label = "Tag",
         initialValue = "",
         props = { singleSelect = true },
      },
    },
    run = function(self, actorId, params, context)
       local component = self.components[actorId]
       if not component then return false end
       
       if params.tag ~= nil and params.tag ~= '' then
           local tag = params.tag:lower()
           if component._tags[tag] == nil or not component._tags[tag] then
               return false
           end
       end
       return true
    end,
}
