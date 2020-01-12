local util = {}


function util.unpackPairs(t)
    local rets, nArgs = {}, 0
    for k, v in pairs(t) do
        rets[nArgs + 1], rets[nArgs + 2] = k, v
        nArgs = nArgs + 2
    end
    return unpack(rets, 1, nArgs)
end

function util.deepCopyTable(t)
    local typ = type(t)
    if typ == 'nil' or typ == 'boolean' or typ == 'number' or typ == 'string' then
        return t
    elseif typ == 'table' then
        local u = {}
        for k, v in pairs(t) do
            u[util.deepCopyTable(k)] = util.deepCopyTable(v)
        end
        return u
    else
        error('deepCopyTable: bad type')
    end
end


local ui = castle.ui

function util.uiRow(id, ...)
    local nArgs = select('#', ...)
    local args = { ... }
    ui.box(id, { flexDirection = 'row', alignItems = 'flex-start' }, function()
        for i = 1, nArgs do
            ui.box(tostring(i), { flex = 1 }, args[i])
            if i < nArgs then
                ui.box('space', { width = 16 }, function() end)
            end
        end
    end)
end


return util
