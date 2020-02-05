function Common:startCommand()
    self.undos = {}
    self.redos = {}
end

local STANDARD_IMPLICITS = {
    actorId = true,
}

local DEFAULT_COALESCE_INTERVAL = 2.2

local MAX_UNDOS = 100

local function forEachUpvalue(func, body)
    local i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if name == nil then
            break
        end
        body(name, value, i)
        i = i + 1
    end
end

function Common:command(description, opts, params, doFunc, undoFunc)
    local command = {}
    command.time = self.time
    command.localTime = love.timer.getTime()
    command.commandId = util.uuid()
    command.description = description
    undoFunc = undoFunc or doFunc
    command.funcs = { ['do'] = doFunc, ['undo'] = undoFunc }
    command.behaviorId = opts.behaviorId
    command.extraParams = opts.extraParams

    -- Collect allowed implicit params
    local implicits = {}
    for _, name in ipairs(params) do
        implicits[name] = true
    end

    -- Create params table
    command.params = {}
    for name, value in pairs(params) do
        if type(name) == 'string' then
            command.params[name] = value
        end
    end
    for _, func in pairs(command.funcs) do
        forEachUpvalue(func, function(name, value, i)
            if name ~= 'self' then -- `self` has special handling
                if not STANDARD_IMPLICITS[name] and not implicits[name] and not params[name] then
                    error("command: upvalue '" .. name .. "' not allowed")
                end
                if not command.params[name] then
                    command.params[name] = value -- Save implicit param
                end
            end
        end)
    end

    -- Now that upvalues are read, clone the functions (unjoins upvalues)
    for funcKey, func in pairs(command.funcs) do
        command.funcs[funcKey] = load(string.dump(func), nil, nil, _G)
    end

    -- Generate a coalesce id or use given one
    if opts.coalesceId then
        command.coalesceId = opts.coalesceId
    else
        command.coalesceId = love.data.hash('md5',
            (opts.behaviorId or '*') .. '-' ..
            (command.params.actorId or '*') .. '-' .. 
            (opts.coalesceSuffix or command.description))
    end

    -- Insert into undos, coalescing with an applicable previous command. Limit undo list size.
    local coalesced = false
    if not opts.noCoalesce then
        for i = #self.undos, 1, -1 do
            local prevCommand = self.undos[i]
            if (command.coalesceId == prevCommand.coalesceId and
                    command.localTime - prevCommand.localTime < (opts.coalesceInterval or DEFAULT_COALESCE_INTERVAL)) then
                command.funcs.undo = prevCommand.funcs.undo
                command.extraParams = command.extraParams or {}
                command.extraParams.undo = prevCommand.params
                if prevCommand.extraParams and prevCommand.extraParams.undo then
                    for name, value in pairs(prevCommand.extraParams.undo) do
                        command.extraParams.undo[name] = value
                    end
                end
                self.undos[i] = command
                coalesced = true
                break
            end
        end
    end
    if not coalesced then
        table.insert(self.undos, command)
    end
    while #self.undos > MAX_UNDOS do
        table.remove(self.undos, 1)
    end

    -- Reset redos
    self.redos = {}

    -- Do command
    self:runCommand('do', command)
end

function Common:undo()
    if #self.undos > 0 then
        local command = table.remove(self.undos)
        self:runCommand('undo', command)
        print("undid '" .. command.description .. "'")
        table.insert(self.redos, command)
    end
end

function Common:redo()
    if #self.redos > 0 then
        local command = table.remove(self.redos)
        self:runCommand('do', command)
        print("redid '" .. command.description .. "'")
        table.insert(self.undos, command)
    end
end

function Common:runCommand(funcKey, command)
    local func = command.funcs[funcKey]

    -- Construct params
    local params = util.deepCopyTable(command.params)
    if command.extraParams and command.extraParams[funcKey] then
        for name, value in pairs(command.extraParams[funcKey]) do
            params[name] = value
        end
    end

    -- Set upvalues, call function, then unset upvalues
    forEachUpvalue(func, function(name, value, i)
        assert(value == nil, 'command function upvalue aleady set')
        if name == 'self' then -- `self` has special handling
            debug.setupvalue(func, i,
                command.behaviorId and self.behaviors[command.behaviorId] or self)
        else
            debug.setupvalue(func, i, params[name])
        end
    end)
    local succeeded, err = pcall(func, params)
    forEachUpvalue(func, function(name, value, i)
        debug.setupvalue(func, i, nil)
    end)
    if not succeeded then
        error(err, 0)
    end
end
