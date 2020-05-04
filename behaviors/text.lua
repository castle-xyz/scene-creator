local TextBehavior = defineCoreBehavior {
    name = 'Text',
    displayName = 'text',
    propertyNames = {
       'content',
       'visible',
    },
    dependencies = {},
}


-- Component management

function TextBehavior.handlers:addComponent(component, bp, opts)
   component.properties.content = bp.content or ''
   component.properties.visible = bp.visible or true
end

function TextBehavior.handlers:blueprintComponent(component, bp)
   bp.content = component.properties.content
   bp.visible = component.properties.visible
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
