local TagsBehavior =
    defineCoreBehavior {
    name = "Tags",
    displayName = "tags",
    propertyNames = {
        "tagsString" -- Space-separate tags string
    },
    dependencies = {}
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

-- UI

function TagsBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiProperty("textInput", "tags (separated by spaces)", actorId, "tagsString")
end
