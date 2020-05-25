local TextBehavior = defineCoreBehavior {
    name = 'Text',
    displayName = 'text',
    propertyNames = {
       'content',
       'visible',
       'order',
    },
    dependencies = {},
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
   bp.order = 0 -- don't copy order
end

-- UI

function TextBehavior.handlers:uiComponent(component, opts)
   local actorId = component.actorId
   self:uiProperty('textArea', 'content', actorId, 'content')
   self:uiProperty('checkbox', 'visible', actorId, 'visible')
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
