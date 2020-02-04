function Common:startCommand()
    self.undos = {}
    self.redos = {}
end

local STANDARD_IMPLICITS = {
    actorId = true,
}

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

function Common:command(description, params, doFunc, undoFunc, opts)
    local command = {}
    command.time = self.time
    command.commandId = util.uuid()
    command.description = description
    command.funcs = { ['do'] = doFunc, ['undo'] = undoFunc }
    command.behaviorId = opts.behaviorId

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
            debug.setupvalue(func, i, nil)
        end)
    end

    -- Track command
    table.insert(self.undos, command)
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

    -- Set upvalues, call function, then unset upvalues
    forEachUpvalue(func, function(name, value, i)
        assert(value == nil, 'command function upvalue aleady set')
        if name == 'self' then -- `self` has special handling
            debug.setupvalue(func, i,
                command.behaviorId and self.behaviors[command.behaviorId] or self)
        else
            debug.setupvalue(func, i, command.params[name])
        end
    end)
    local succeeded, err = pcall(func)
    forEachUpvalue(func, function(name, value, i)
        debug.setupvalue(func, i, nil)
    end)
    if not succeeded then
        error(err, 0)
    end
end
