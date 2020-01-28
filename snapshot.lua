-- Start / stop

function Common:startSnapshot()
    self.snapshots = {}
    self.rewindSnapshotId = nil
end


-- Message kind definitions

function Common:defineSnapshotMessageKinds()
    self:defineMessageKind('addSnapshot', self.sendOpts.reliableToAll)
    self:defineMessageKind('removeSnapshot', self.sendOpts.reliableToAll)
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

    -- Blueprint actors, preserving the parent entry id
    snapshot.actors = {}
    for actorId, actor in pairs(self.actors) do
        local actorBp = self:blueprintActor(actorId)
        snapshot.actors[actorId] = {
            parentEntryId = actor.parentEntryId,
            bp = actorBp,
        }
    end

    return snapshot
end

function Common:restoreSnapshot(snapshot, opts)
    opts = opts or {}

    -- Clear existing
    if opts.clear ~= false then
        for actorId in pairs(self.actors) do
            self:send('removeActor', self.clientId, actorId)
        end
    end

    -- Add new
    for actorId, actorSp in pairs(snapshot.actors) do
        self:sendAddActor(actorSp.bp, {
            actorId = actorId,
            parentEntryId = actorSp.parentEntryId,
        })
    end

    -- Refresh tools
    self:applySelections() 
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

