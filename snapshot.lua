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


-- Backups

local backupSessionId = util.uuid()

local sqlite = require 'lsqlite3'

local db = sqlite3.open(love.filesystem.getSaveDirectory() .. '/scene_creator_backup.db')

db:exec[[
    create table if not exists scene_backup (
        id integer primary key,
        timestamp datetime default current_timestamp,
        sessionId,
        data
    );
]]

local backupIndex = {}

local updateBackupIndex
do
    -- Select backups in descending order of timestamp
    local selectStmt = db:prepare[[
        select id, datetime(timestamp, 'localtime'), sessionId
            from scene_backup
            order by timestamp desc;
    ]]

    function updateBackupIndex()
        backupIndex = {}
        for id, timestamp, sessionId in selectStmt:urows() do
            table.insert(backupIndex, {
                id = id,
                timestamp = timestamp,
                sessionId = sessionId,
            })
        end
    end
end

updateBackupIndex()

local readBackupData
do
    -- Select backup by id
    local selectStmt = db:prepare[[
        select data from scene_backup where id = $id;
    ]]

    function readBackupData(id)
        local result
        selectStmt:bind_names({ id = id })
        for data in selectStmt:urows() do
            result = data
        end
        selectStmt:reset()
        return result
    end
end

local writeBackup
do
    -- Insert a new backup
    local insertStmt = db:prepare[[
        insert into scene_backup (sessionId, data) values ($sessionId, $data);
    ]]

    -- Remove backups other than the newly inserted one in the past 5 minutes (so we don't
    -- keep a ton of backups around because we do a backup every 2 seconds)
    local simplifyStmt = db:prepare[[
        delete from scene_backup where
            id <> $otherThanId and
            sessionId = $sessionId and
            timestamp > datetime('now', '-5 minute') and
            length(data) <= $minDataLength;
    ]]

    -- Remove old backups
    local deleteOldStmt = db:prepare[[
        delete from scene_backup where timestamp < datetime('now', '-3 hour');
    ]]

    function writeBackup(data)
        local sessionId = backupSessionId
        insertStmt:bind_names({ sessionId = sessionId, data = data })
        while insertStmt:step() == sqlite.ROW do end
        insertStmt:reset()
        if db:errcode() == 0 then
            local id = db:last_insert_rowid()

            simplifyStmt:bind_names({ otherThanId = id, sessionId = sessionId, minDataLength = #data })
            while simplifyStmt:step() == sqlite.ROW do
            end
            simplifyStmt:reset()

            while deleteOldStmt:step() == sqlite.ROW do
            end
            deleteOldStmt:reset()
        end
        updateBackupIndex()
    end
end

local clearBackups
do
    -- Delete all backups
    local deleteStmt = db:prepare[[
        delete from scene_backup;
    ]]

    function clearBackups()
        while deleteStmt:step() == sqlite.ROW do
        end
        deleteStmt:reset()
        updateBackupIndex()
    end
end


-- Methods

function Common:createSnapshot(opts)
    snapshot = {}

    -- Snapshot non-core library entries
    snapshot.library = {}
    for entryId, entry in pairs(self.library) do
        if not entry.isCore then
            snapshot.library[entryId] = entry
        end
    end

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
    if not self.performing then
        self.lastSaveAttemptTime = love.timer.getTime()

        local data = cjson.encode({
            snapshot = snapshot or self:createSnapshot(),
        })
        if data ~= self.lastSuccessfulSaveData then
            if next(self.actors) then
                pcall(function()
                    writeBackup(data)
                end)
            end

            jsEvents.send('GHOST_MESSAGE', {
                messageType = 'SAVE_SCENE',
                data = data,
            })
            self.lastSuccessfulSaveData = data
        end
    end
end

function Common:updateAutoSaveScene()
    if not self.performing then
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

    self:transact(self.sendOpts.reliableToAll, function()
        -- Stop performance
        if opts.stopPerforming ~= false and self.performing then
            self:send('setPerforming', false)
        end

        if opts.clear ~= false then
            self:send('clearScene')

            -- Clear existing library entries
            for entryId, entry in pairs(self.library) do
                if not entry.isCore then
                    self:send('removeLibraryEntry', entryId)
                end
            end

            -- Clear existing actors
            for actorId in pairs(self.actors) do
                self:send('removeActor', self.clientId, actorId)
            end
        end

        -- Add new library entries
        for entryId, entry in pairs(snapshot.library or {}) do
            self:send('addLibraryEntry', entryId, entry)
        end

        -- Add new actors
        for _, actorSp in pairs(snapshot.actors or {}) do
            self:sendAddActor(actorSp.bp, {
                actorId = actorSp.actorId,
                parentEntryId = actorSp.parentEntryId,
            })
        end
    end)
end


-- UI

function Common:uiBackups(onLoad)
    if next(backupIndex) then
        if ui.button('clear backups') then
            clearBackups()
        end
    end

    local prevSessionId
    for _, backup in ipairs(backupIndex) do
        ui.box(tostring(backup.id), {
            padding = 4,
            margin = 4,
            marginTop = (prevSessionId and prevSessionId ~= backup.sessionId and 8) or nil,
            marginBottom = 8,
            flexDirection = 'row',
        }, function()
            ui.box('timestamp', { flex = 1 }, function()
                ui.markdown(backup.timestamp)
            end)
            ui.button('load', {
                onClick = function()
                    onLoad()
                    local dataJson = readBackupData(backup.id)
                    if dataJson then
                        local data = cjson.decode(dataJson)
                        if data and data.snapshot then
                            backupSessionId = util.uuid()
                            self:send('addSnapshot', util.uuid(), data.snapshot, { isRewind = true })
                            self:send('restoreSnapshot', self.rewindSnapshotId, {
                                stopPerforming = true,
                            })
                        end
                    end
                end,
            })
        end)
        prevSessionId = backup.sessionId
    end
end

