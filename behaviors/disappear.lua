local DisappearBehavior = {
    name = 'Disappear',
    displayName = 'disappear',
    propertyNames = {
        'disappearOnCollision',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(DisappearBehavior)


-- Component management

function DisappearBehavior.handlers:addComponent(component, bp, opts)
    if bp.disappearOnCollision ~= nil then
        component.properties.disappearOnCollision = bp.disappearOnCollision
    else
        component.properties.disappearOnCollision = true
    end
end

function DisappearBehavior.handlers:blueprintComponent(component, bp)
    bp.disappearOnCollision = component.properties.disappearOnCollision
end


-- Collision

function DisappearBehavior.handlers:bodyContactComponent(component, opts)
    if component.properties.disappearOnCollision then
        if opts.isOwner then
            local actorId = component.actorId
            self:onEndOfFrame(function()
                if self.game.actors[actorId] then
                    self.game:send('removeActor', self.clientId, actorId, { soft = true })
                end
            end)
        end
    end
end


-- UI

function DisappearBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiProperty('toggle', 'disappear on collision', actorId, 'disappearOnCollision')
end



