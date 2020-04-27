local TextBehavior = defineCoreBehavior {
    name = 'Text',
    displayName = 'text',
    propertyNames = {
        'content',
    },
    dependencies = {},
}


-- Component management

function TextBehavior.handlers:addComponent(component, bp, opts)
    component.properties.content = bp.content or ''
end

function TextBehavior.handlers:blueprintComponent(component, bp)
    bp.content = component.properties.content
end

-- UI

function TextBehavior.handlers:uiComponent(component, opts)
   local actorId = component.actorId
   self:uiProperty('textArea', 'content', actorId, 'content')
end



