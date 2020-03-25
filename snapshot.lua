-- Start / stop

function Common:startSnapshot()
    self.snapshots = {}
    self.rewindSnapshotId = nil
    self.lastSaveAttemptTime = nil
    self.lastSuccessfulSaveData = nil
end


-- Message kind definitions

function Common:defineSnapshotMessageKinds()
    -- From anyone to all
    self:defineMessageKind('addSnapshot', self.sendOpts.reliableToAll)
    self:defineMessageKind('removeSnapshot', self.sendOpts.reliableToAll)

    -- From client to server
    self:defineMessageKind('restoreSnapshot', {
        reliable = true,
        channel = self.channels.mainReliable,
        selfSend = false,
        forward = false,
    })
end


-- Sync new client

function Common:syncClientSnapshot(clientId, send)
    for snapshotId, snapshot in pairs(self.snapshots) do
        send('addSnapshot', snapshotId, snapshot, {
            isRewind = self.rewindSnapshotId == snapshotId,
        })
    end
end


-- Methods

function Common:createSnapshot(opts)
    snapshot = {}

    -- Snapshot actors in draw order
    snapshot.actors = {}
    self:forEachActorByDrawOrder(function(actor)
        local actorBp = self:blueprintActor(actor.actorId)
        table.insert(snapshot.actors, {
            actorId = actor.actorId,
            parentEntryId = actor.parentEntryId,
            bp = actorBp,
        })
    end)

    return snapshot
end

function Common:saveScene(snapshot)
    if not self.sceneId then
        return
    end

    if not self.performing then
        self.lastSaveAttemptTime = love.timer.getTime()

        local data = cjson.encode({
            snapshot = snapshot or self:createSnapshot(),
        })
        if data ~= self.lastSuccessfulSaveData then
            jsEvents.send('GHOST_MESSAGE', {
                messageType = 'SAVE_SCENE',
                data = data,
            })
            self.lastSuccessfulSaveData = data
        end
    end
end

function Common:updateAutoSaveScene()
    if self.sceneId and not self.performing then
        if not self.lastSaveAttemptTime or love.timer.getTime() - self.lastSaveAttemptTime > 2 then
            self:saveScene()
        end
    end
end


-- Message receivers

function Common.receivers:addSnapshot(time, snapshotId, snapshot, opts)
    opts = opts or {}

    self.snapshots[snapshotId] = snapshot

    if opts.isRewind then
        self.rewindSnapshotId = snapshotId
    end
end

function Common.receivers:removeSnapshot(time, snapshotId)
    if self.rewindSnapshotId == snapshotId then
        self.rewindSnapshotId = nil
    end
    self.snapshots[snapshotId] = nil
end

function Server.receivers:restoreSnapshot(time, snapshotId, opts)
    opts = opts or {}

    local snapshot = assert(self.snapshots[snapshotId], 'restoreSnapshot: no such snapshot')

    self:transact({
        to = 'all',
        reliable = true,
        selfSend = true,
        channel = self.channels.mainReliable,
    }, function()
        -- Stop performance
        if opts.stopPerforming ~= false and self.performing then
            self:send('setPerforming', false)
        end

        -- Clear existing
        if opts.clear ~= false then
            self:send('clearScene')
            for actorId in pairs(self.actors) do
                self:send('removeActor', self.clientId, actorId)
            end
        end

        -- Add new
        for _, actorSp in pairs(snapshot.actors) do
            self:sendAddActor(actorSp.bp, {
                actorId = actorSp.actorId,
                parentEntryId = actorSp.parentEntryId,
            })
        end
    end)
end

