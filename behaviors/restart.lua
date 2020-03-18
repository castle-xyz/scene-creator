local RestartBehavior = {
    name = 'Restart',
    displayName = 'restart',
    propertyNames = {
        'restartOnCollision',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

registerCoreBehavior(RestartBehavior)


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
        if self.game.server then
            self:onEndOfFrame(function()
                if self.game.rewindSnapshotId then
                    self.game:send({
                        selfSendOnly = true,
                        kind = 'restoreSnapshot',
                    }, self.game.rewindSnapshotId, { stopPerforming = false })
                end
            end)
        end
    end
end


-- UI

function RestartBehavior.handlers:uiComponent(component, opts)
    local actorId = component.actorId

    self:uiProperty('toggle', 'restart on collision', actorId, 'restartOnCollision')
end



