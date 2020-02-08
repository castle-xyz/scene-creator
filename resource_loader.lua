local resource_loader = {}


-- Load functions retain a 'holder' to which a strong reference must be held while the resource is in use


local defaultImage

if love.graphics then
    defaultImage = love.graphics.newImage(CHECKERBOARD_IMAGE_URL)
    defaultImage:setFilter('nearest', 'nearest')
end

local imageHolders = {
    linear = setmetatable({}, { __mode = 'v' }),
    nearest = setmetatable({}, { __mode = 'v' }),
}

function resource_loader.loadImage(url, filter)
    filter = filter or 'linear'
    local holder = imageHolders[filter][url]
    if not holder then
        holder = {}
        imageHolders[filter][url] = holder
        holder.image = defaultImage
        if url ~= '' then
            network.async(function()
                holder.image = love.graphics.newImage(url)
                holder.image:setFilter(filter, filter)
                holder.loaded = true
            end)
        end
    end
    return holder
end


local fontHolders = setmetatable({}, { __mode = 'v' })

function resource_loader.loadFont(url, size)
    local key = size .. '|' .. url
    local holder = fontHolders[key]
    if not holder then
        holder = {}
        fontHolders[key] = holder
        holder.font = love.graphics.newFont(size)
        if url ~= '' then
            network.async(function()
                holder.font = love.graphics.newFont(url, size)
            end)
        end
    end
    return holder
end


local fileDataHolders = setmetatable({}, { __mode = 'v' })

function resource_loader.loadFileData(url)
    local holder = fileDataHolders[url]
    if not holder then
        holder = {}
        fileDataHolders[url] = holder
        network.async(function()
            holder.fileData = love.filesystem.newFileData(url)
        end)
    end
    return holder
end


return resource_loader
