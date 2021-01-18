function Common:startCommand()
    -- Don't lose state if already exists (eg. when reconnecting)
    self.undos = self.undos or {}
    self.redos = self.redos or {}
end

local STANDARD_IMPLICITS = {
    actorId = true
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

function Common:command(description, opts, doFunc, undoFunc)
    local command = {}
    command.time = self.time
    command.localTime = love.timer.getTime()
    command.commandId = util.uuid()
    command.description = description
    undoFunc = undoFunc or doFunc
    command.funcs = {["do"] = doFunc, ["undo"] = undoFunc}
    command.behaviorId = opts.behaviorId
    command.paramOverrides = opts.paramOverrides
    command.selections = {["do"] = {}, ["undo"] = {}}

    local params = opts.params or {}

    -- Collect allowed implicit params
    local implicits = {}
    for _, name in ipairs(params) do
        implicits[name] = true
    end

    -- Create params table
    command.params = {}
    for name, value in pairs(params) do
        if type(name) == "string" then
            command.params[name] = value
        end
    end
    for _, func in pairs(command.funcs) do
        forEachUpvalue(
            func,
            function(name, value, i)
                if name ~= "self" then -- `self` has special handling
                    if not STANDARD_IMPLICITS[name] and not implicits[name] and not params[name] then
                        error("command: upvalue '" .. name .. "' not allowed")
                    end
                    if not command.params[name] then
                        command.params[name] = value -- Save implicit param
                    end
                end
            end
        )
    end

    -- Now that upvalues are read, clone the functions (unjoins upvalues)
    for mode, func in pairs(command.funcs) do
        command.funcs[mode] = load(string.dump(func), nil, nil, _G)
    end

    -- Use given coalesce id or generate one with the given suffix
    if opts.coalesceId then
        command.coalesceId = opts.coalesceId
    elseif opts.coalesceSuffix then
        command.coalesceId =
            love.data.hash(
            "md5",
            (opts.behaviorId or "*") .. "-" .. (command.params.actorId or "*") .. "-" .. opts.coalesceSuffix
        )
    end

    -- Insert into undos, coalescing with an applicable previous command. Limit undo list size.
    if not opts.noSaveUndo then
        local coalesced = false
        if command.coalesceId then
            for i = #self.undos, 1, -1 do
                local prevCommand = self.undos[i]
                if
                    (command.coalesceId == prevCommand.coalesceId and
                        command.localTime - prevCommand.localTime < (opts.coalesceInterval or DEFAULT_COALESCE_INTERVAL))
                 then
                    -- Use undo part of `prevCommand`
                    command.funcs.undo = prevCommand.funcs.undo
                    command.paramOverrides = command.paramOverrides or {}
                    command.paramOverrides.undo = prevCommand.params
                    if prevCommand.paramOverrides and prevCommand.paramOverrides.undo then
                        for name, value in pairs(prevCommand.paramOverrides.undo) do
                            command.paramOverrides.undo[name] = value
                        end
                    end

                    -- Replace in undo list
                    self.undos[i] = command
                    coalesced = true
                    break
                end
                if opts.coalesceLast ~= false then
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
    end

    -- Reset redos
    self.redos = {}

    -- Clear notifications
    self:clearNotify()

    -- Do command, saving selections before and after
    for actorId in pairs(self.selectedActorIds) do
        table.insert(command.selections["undo"], actorId)
    end
    self:runCommand("do", command, true)
    for actorId in pairs(self.selectedActorIds) do
        table.insert(command.selections["do"], actorId)
    end
end

function Common:undoOrRedo(mode, fromList, toList, presentTense, pastTense)
    if #fromList > 0 then
        local command = table.remove(fromList)
        local err = self:runCommand(mode, command)
        if err then
            self:notify("skipped " .. presentTense .. ": " .. command.description .. " (" .. err .. ")", nil, true)
        else
            self:notify(pastTense .. ": " .. command.description)
            table.insert(toList, command)
        end
    end
end

function Common:undo()
    self:undoOrRedo("undo", self.undos, self.redos, "undo", "undid")
end

function Common:redo()
    self:undoOrRedo("do", self.redos, self.undos, "redo", "redid")
end

function Common:runCommand(mode, command, live)
    local func = command.funcs[mode]

    -- Construct params
    local params = util.deepCopyTable(command.params)
    if command.paramOverrides and command.paramOverrides[mode] then
        for name, value in pairs(command.paramOverrides[mode]) do
            params[name] = value
        end
    end

    -- Check actor and component existence
    if params.actorId then
        if not self.actors[params.actorId] then
            return "actor was deleted"
        end
        if command.behaviorId then
            local behavior = self.behaviors[command.behaviorId]
            if not behavior.tool and not behavior.components[params.actorId] then
                return "behavior was removed"
            end
        end
    end

    -- Set upvalues, call function, then unset upvalues
    forEachUpvalue(
        func,
        function(name, value, i)
            assert(value == nil, "command function upvalue aleady set")
            if name == "self" then -- `self` has special handling
                debug.setupvalue(func, i, command.behaviorId and self.behaviors[command.behaviorId] or self)
            else
                debug.setupvalue(func, i, params[name])
            end
        end
    )
    local succeeded, err = pcall(func, params, not (not live))
    forEachUpvalue(
        func,
        function(name, value, i)
            debug.setupvalue(func, i, nil)
        end
    )
    if not succeeded then
        print("command error: " .. err)
        return "error"
    end
    if err then
        return err
    end

    -- Restore selections if not a live run
    if not live and command.selections[mode] then
        self:syncBelt() -- Ensure ghost actors exist before selecting

       local needsReset = false
       -- if the command includes a selection that's not already selected, reset
       for _, actorId in ipairs(command.selections[mode]) do
          if not self.selectedActorIds[actorId] then
             needsReset = true
             break
          end
       end
       -- if something is selected that's not in the command, reset
       local numSelectedActors = 0
       for actorId, _ in pairs(self.selectedActorIds) do numSelectedActors = numSelectedActors + 1 end
       if numSelectedActors ~= #command.selections[mode] then
          needsReset = true
       end

       if needsReset then
          self:deselectAllActors()
       end
       
        for _, actorId in ipairs(command.selections[mode]) do
            if self.actors[actorId] then
                self:selectActor(actorId)
            end
        end

        -- If the resulting selection consists solely of ghost actors, select some corresponding belt entry
        local allGhosts = true
        for actorId in pairs(self.selectedActorIds) do
            local actor = self.actors[actorId]
            if actor and not actor.isGhost then
                allGhosts = false
            end
        end
        local someSelectedActorId = next(self.selectedActorIds)
        if allGhosts and someSelectedActorId then
            local actor = self.actors[someSelectedActorId]
            local entry = actor and actor.parentEntryId and self.library[actor.parentEntryId]
            if entry and not entry.isCore then
                -- Find element and target it
                for i, elem in ipairs(self.beltElems) do
                    if elem.entryId == entry.entryId then
                        self.beltTargetIndex = i
                        self.beltEntryId = entry.entryId
                        self.beltHighlightEnabled = true
                        return
                    end
                end
            end
        end
    end
end
