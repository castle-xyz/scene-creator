local RestartBehavior = defineCoreBehavior {
    name = 'Restart',
    displayName = 'restart',
    propertyNames = {
        'restartOnCollision',
    },
    dependencies = {
        'Body',
    },
}


-- Component management

function RestartBehavior.handlers:addComponent(component, bp, opts)
    if bp.restartOnCollision ~= nil then
        component.properties.restartOnCollision = bp.restartOnCollision
    else
        component.properties.restartOnCollision = true
    end
end

function RestartBehavior.handlers:blueprintComponent(component, bp)
    bp.restartOnCollision = component.properties.restartOnCollision
end


-- Collision

function RestartBehavior.handlers:bodyContactComponent(component, opts)
    if component.properties.restartOnCollision then
        if opts.isOwner then
            self:onEndOfFrame(function()
                self.game:restartScene()
            end)
        end
    end
end


-- UI

function RestartBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiProperty('toggle', 'restart on collision', actorId, 'restartOnCollision')
end



