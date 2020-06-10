local TextBehavior = defineCoreBehavior {
    name = 'Text',
    displayName = 'text',
    propertyNames = {
       'content',
       'visible',
       'order',
    },
    dependencies = {},
    propertySpecs = {
       content = {
          method = 'textArea',
          label = 'content',
       },
       visible = {
          method = 'checkbox',
          label = 'visible',
       },
    },
}


-- Component management

function TextBehavior.handlers:addComponent(component, bp, opts)
   component.properties.content = bp.content or ''
   if bp.visible == nil then
      component.properties.visible = true
   else
      component.properties.visible = bp.visible
   end
   if bp.order ~= nil then
      component.properties.order = bp.order
   else
      local maxExistingOrder = 0
      for _, component in pairs(self.components) do
         if component.properties.order ~= nil and component.properties.order >= maxExistingOrder then
            maxExistingOrder = component.properties.order
         end
      end
      component.properties.order = maxExistingOrder + 1
   end
end

function TextBehavior.handlers:blueprintComponent(component, bp)
   bp.content = component.properties.content
   bp.visible = component.properties.visible
   bp.order = component.properties.order
end

-- rendering text content

function TextBehavior:parseContent(component, performing, variableNameToValue)
   if component.properties.content == nil then
      return nil
   end
      
   if not performing then
      -- editing, so return content literal
      return component.properties.content
   end

   -- parse variables
   local output = component.properties.content:gsub(
      "(%$%w+)",
      function(maybeVariable)
            local variableName = string.sub(maybeVariable, 2)
            if variableNameToValue[variableName] ~= nil then
               return variableNameToValue[variableName]
            end
         return maybeVariable
      end
   )
   return output
end

function TextBehavior:parseComponentsContent(performing)
   local contents = {}
   local variableNameToValue = self.game:variablesNamesToValues()
   for actorId, component in pairs(self.components) do
      contents[actorId] = self:parseContent(component, performing, variableNameToValue)
   end
   return contents
end

-- order

function TextBehavior:getOrdering()
   local ordering = {}
   for actorId, component in pairs(self.components) do
      ordering[actorId] = component.properties.order
   end
   return ordering
end

function TextBehavior.handlers:setOrdering(ordering)
   for actorId, component in pairs(self.components) do
      component.properties.order = ordering[actorId]
   end
end

function TextBehavior.handlers:moveForward(component)
   self:_maybeAssignDefaultOrder()
   
   local lowerOrder = component.properties.order
   local upperOrder = 0
   local tieExists = false
   local orderedComponents = self:_orderedComponents()

   if #orderedComponents == 1 then
      -- singleton
      return
   end
   
   for _, other in ipairs(orderedComponents) do
      if other.actorId ~= component.actorId then
         if other.properties.order == lowerOrder then
            tieExists = true
         end
         if other.properties.order > lowerOrder then
            upperOrder = other.properties.order
            break
         end
      end
   end
   if upperOrder > lowerOrder then
      for _, other in pairs(self.components) do
         if other.properties.order == upperOrder then
            other.properties.order = lowerOrder
         end
      end
      component.properties.order = upperOrder
   elseif tieExists then
      component.properties.order = component.properties.order + 1
   end
end

function TextBehavior.handlers:moveToFront(component)
   self:_maybeAssignDefaultOrder()
   
   local lowerOrder = component.properties.order
   local orderedComponents = self:_orderedComponents()

   if #orderedComponents == 1 then
      -- singleton
      return
   end

   local upperOrder = orderedComponents[#orderedComponents].properties.order
   
   if upperOrder > lowerOrder then
      for _, other in pairs(self.components) do
         if other.properties.order <= upperOrder then
            other.properties.order = other.properties.order - 1
         end
      end
      component.properties.order = upperOrder
   elseif upperOrder == lowerOrder then
      component.properties.order = component.properties.order + 1
   end
end

function TextBehavior.handlers:moveBackward(component)
   self:_maybeAssignDefaultOrder()
   
   local upperOrder = component.properties.order
   local lowerOrder = 1
   local tieExists = false
   local orderedComponents = self:_orderedComponents()

   if #orderedComponents == 1 then
      -- singleton
      return
   end

   for i = #orderedComponents, 1, -1 do
      local other = orderedComponents[i]
      if other.actorId ~= component.actorId then
         if other.properties.order == upperOrder then
            tieExists = true
         end
         if other.properties.order < upperOrder then
            lowerOrder = other.properties.order
            break
         end
      end
   end
   if lowerOrder < upperOrder then
      for _, other in pairs(self.components) do
         if other.properties.order == lowerOrder then
            other.properties.order = upperOrder
         end
      end
      component.properties.order = lowerOrder
   elseif tieExists then
      component.properties.order = component.properties.order - 1
   end
end

function TextBehavior.handlers:moveToBack(component)
   self:_maybeAssignDefaultOrder()
   
   local upperOrder = component.properties.order
   local orderedComponents = self:_orderedComponents()

   if #orderedComponents == 1 then
      -- singleton
      return
   end

   local lowerOrder = orderedComponents[1].properties.order
   
   if lowerOrder < upperOrder then
      for _, other in pairs(self.components) do
         if other.properties.order >= lowerOrder then
            other.properties.order = other.properties.order + 1
         end
      end
      component.properties.order = lowerOrder
   elseif lowerOrder == upperOrder then
      component.properties.order = component.properties.order - 1
   end
end

-- Rules and triggers

TextBehavior.triggers.tap = {
    description = [[
Triggered when the user taps (a quick **touch and release**) on the actor.
]],
    category = "input"
}

-- Responses

TextBehavior.responses["show"] = {
   description = [[
Shows the text.
   ]],
   category = 'visible',
   run = function(self, actorId, params, context)
      local component = self.components[actorId]
      component.properties.visible = true
   end
}

TextBehavior.responses["hide"] = {
   description = [[
Hides the text.
   ]],
   category = 'visible',
   run = function(self, actorId, params, context)
      local component = self.components[actorId]
      component.properties.visible = false
   end
}

TextBehavior.responses["send player to card"] = {
   description = [[
Sends the player to another card in this deck.
   ]],
   category = 'navigation',
   triggerFilter = { tap = true },
   initialParams = {
      card = nil,
   },
   uiBody = function(self, params, onChangeParam)
      ui.cardPicker(
            "destination card",
            params.card,
            {
               onChange = function(newCard)
                  onChangeParam("change card", "card", newCard)
                end
            }
        )
   end,
   run = function(self, actorId, params, context)
      jsEvents.send("NAVIGATE_TO_CARD", { card = params.card })
   end
}

-- ordering utilities

function TextBehavior:_orderedComponents()
   local orderedComponents = {}
   for _, component in pairs(self.components) do
      table.insert(orderedComponents, component)
   end
   table.sort(orderedComponents, function (a, b) return a.properties.order < b.properties.order end)
   return orderedComponents
end

function TextBehavior:_maybeAssignDefaultOrder()
   -- older versions of the app didn't assign order
   -- establish an ordering with no zero-ties
   local numZeroes = 0
   for _, component in pairs(self.components) do
      if component.properties.order == nil or component.properties.order == 0 then
         component.properties.order = 0
         numZeroes = numZeroes + 1
      end
      component.properties.order = component.properties.order + numZeroes
   end
end
