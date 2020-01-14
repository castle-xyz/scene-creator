-- Core library

local CORE_LIBRARY = {
    {
        entryType = 'actorBlueprint',
        title = 'dog',
        description = 'A canine friend that falls and rolls around!',
        actorBlueprint = {
            Image = {
                url = 'https://art.pixilart.com/5d29768f5c3f448.png',
                width = 110,
                height = 128,
                cropEnabled = true,
                cropX = 256,
                cropY = 150,
                cropWidth = 600,
                cropHeight = 700,
            },
            Body = {
                fixture = {
                    shapeType = 'polygon',
                    points = {
                        -55, -64,
                        -55, 64,
                        55, 64,
                        55, -64,
                    },
                },
                bodyType = 'dynamic',
                gravityScale = 1,
            },
        },
    },
    {
        entryType = 'actorBlueprint',
        title = 'ice platform',
        description = 'Something to stand on...',
        actorBlueprint = {
            Image = {
                url = 'http://www.photonstorm.com/wp-content/uploads/2015/01/ice-platform.png',
                width = 384,
                height = 96,
            },
            Body = {
                fixture = {
                    shapeType = 'polygon',
                    points = {
                        -192, -48,
                        -192, 48,
                        192, 48,
                        192, -48,
                    },
                },
                bodyType = 'static',
            },
        },
    },
}


-- Start / stop

function Common:startLibrary()
    self.library = {} -- `entryId` -> entry
end

function Server:startLibrary()
    Common.startLibrary(self)
    
    -- On server, populate core library entries
    for _, entrySpec in pairs(CORE_LIBRARY) do
        local entryId = self:generateId()
        local entry = util.deepCopyTable(entrySpec)
        entry.entryId = entryId
        self.library[entryId] = entry
    end
end

function Common:stopLibrary()
end


-- Message kind definitions

function Common:defineLibraryMessageKinds(config)
    self:defineMessageKind('addLibraryEntry', config.reliableToAllSendOpts)
end


-- Sync new client

function Server:syncClientLibrary(clientId, send)
    for entryId, entry in pairs(self.library) do
        send('addLibraryEntry', entryId, entry)
    end
end


-- Message receivers

function Common.receivers:addLibraryEntry(time, entryId, entry)
    local entryCopy = util.deepCopyTable(entry)
    entryCopy.entryId = entryId
    self.library[entryId] = entryCopy
end

