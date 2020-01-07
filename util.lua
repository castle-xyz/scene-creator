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


return util
