-- for dragging points with a fill, we can render to a bmp and then test each affected slab against the bmp

function idToSubpath(pathDataList, id)
    return pathDataList[id.pathIdx].subpathDataList[id.subpathIdx]
end

function makeSubpathId(pathIdx, subpathIdx)
    return {
        pathIdx = pathIdx,
        subpathIdx = subpathIdx,
    }
end

function makeSubpathStringId(pathIdx, subpathIdx)
    return pathIdx .. '-' .. subpathIdx
end

function subpathIdToSubpathStringId(subpathId)
    return subpathId.pathIdx .. '-' .. subpathId.subpathIdx
end

function findAllIntersections(pathDataList)
    local result = {}

    for i = 1, #pathDataList do
        for j = 1, #pathDataList[i].subpathDataList do
            local subpathData = pathDataList[i].subpathDataList[j]

            for k = 1, i - 1 do
                for l = 1, #pathDataList[k].subpathDataList do
                    local otherSubpathData = pathDataList[k].subpathDataList[l]

                    local p1, p2 = subpathDataIntersection(subpathData, otherSubpathData)
                    if p1 then
                        table.insert(result, {
                            x = p1,
                            y = p2,
                            subpathIds = {
                                makeSubpathId(i, j),
                                makeSubpathId(k, l)
                            }
                        })
                    end
                end
            end
        end
    end

    return result
end

function doesLineIntersectWithAnyPath(pathDataList, p1, p2)
    local fakeSubpath = {
        type = "line",
        p1 = p1,
        p2 = p2,
    }

    for i = 1, #pathDataList do
        for j = 1, #pathDataList[i].subpathDataList do
            local subpathData = pathDataList[i].subpathDataList[j]

            local p1, p2 = subpathDataIntersection(subpathData, fakeSubpath)
            if p1 then
                return true
            end
        end
    end

    return false
end

function findSlabsForPoint(slabsList, point)
    for i = 1, #slabsList do
        local slab = slabsList[i]
        if point.x < slab.x then
            local slabNum = i - 1
            if slabNum < 1 then
                return nil
            end

            return slabsList[slabNum], slabsList[i]
        end
    end

    return nil
end

_FACE_POINTS = {}

local function getSharedSubpathsForSlabs(pathDataList, slab1FakeSubpath, slab2FakeSubpath)
    local slab1SubpathIds = {}

    for i = 1, #pathDataList do
        for j = 1, #pathDataList[i].subpathDataList do
            local subpathData = pathDataList[i].subpathDataList[j]

            local p1, p2 = subpathDataIntersection(subpathData, slab1FakeSubpath)
            if p1 then
                slab1SubpathIds[makeSubpathStringId(i, j)] = true
            end
        end
    end

    --print(inspect(slab1SubpathIds))

    local slabIntersections = {}
    for i = 1, #pathDataList do
        for j = 1, #pathDataList[i].subpathDataList do
            local subpathData = pathDataList[i].subpathDataList[j]

            local p1, p2 = subpathDataIntersection(subpathData, slab2FakeSubpath)
            if p1 then
                local subpathStringId = makeSubpathStringId(i, j)
                if slab1SubpathIds[subpathStringId] then
                    table.insert(slabIntersections, {
                        y = p2,
                        subpathId = makeSubpathId(i, j),
                    })
                end
            end
        end
    end

    return slabIntersections
end

-- find the top left point of the face. this is not necessarily a subpath/subpath intersection. can also be a subpath/slab line intersection
function findFaceForPoint(slabsList, pathDataList, minY, maxY, point, newFaces, currentFacesHolder, cellSize)
    --table.insert(_FACE_POINTS, point.x)
    --table.insert(_FACE_POINTS, point.y)

    local slab1, slab2 = findSlabsForPoint(slabsList, point)
    if not slab1 then
        return false
    end

    local slab1FakeSubpath = {
        type = "line",
        p1 = {
            x = slab1.x,
            y = minY,
        },
        p2 = {
            x = slab1.x,
            y = maxY,
        },
    }

    local slab2FakeSubpath = {
        type = "line",
        p1 = {
            x = slab2.x,
            y = minY,
        },
        p2 = {
            x = slab2.x,
            y = maxY,
        },
    }

    local slabIntersections = getSharedSubpathsForSlabs(pathDataList, slab1FakeSubpath, slab2FakeSubpath)
    --print(inspect(slabIntersections))


    local slabPointFakeSubpath = {
        type = "line",
        p1 = {
            x = point.x,
            y = minY,
        },
        p2 = {
            x = point.x,
            y = maxY,
        },
    }

    for i = 1, #slabIntersections do
        local subpath = idToSubpath(pathDataList, slabIntersections[i].subpathId)
        local userIntersectionX, userIntersectionY = subpathDataIntersection(subpath, slabPointFakeSubpath)

        slabIntersections[i].userIntersectionY = userIntersectionY
    end

    table.sort(slabIntersections, function (a, b) return a.userIntersectionY < b.userIntersectionY end)

    local slabIntersectionIndex = 0
    for i = 1, #slabIntersections do
        if point.y < slabIntersections[i].userIntersectionY then
            slabIntersectionIndex = i - 1
            break
        end
    end

    if slabIntersectionIndex < 1 or slabIntersectionIndex >= #slabIntersections then
        return false
    end

    local topSubpathId = slabIntersections[slabIntersectionIndex].subpathId
    local bottomSubpathId = slabIntersections[slabIntersectionIndex + 1].subpathId

    local faceId = subpathIdToSubpathStringId(topSubpathId) .. '+' .. subpathIdToSubpathStringId(bottomSubpathId) .. '+' .. slab1.x .. '+' .. slab2.x
    if currentFacesHolder.currentFaces[faceId] then
        return true
    end

    currentFacesHolder.currentFaces[faceId] = true

    local topSubpath = idToSubpath(pathDataList, topSubpathId)
    local bottomSubpath = idToSubpath(pathDataList, bottomSubpathId)

    local fillSubpath = tove.newSubpath()
    local fillPath = tove.newPath()
    fillPath:addSubpath(fillSubpath)
    fillPath:setFillColor(0.6, 0.6, 0.0, 1.0)

    
    local topLeftX, topLeftY = subpathDataIntersection(topSubpath, slab1FakeSubpath)
    if not topLeftX then
        return true
    end
    fillSubpath:moveTo(topLeftX, topLeftY)


    local topRightX, topRightY = subpathDataIntersection(topSubpath, slab2FakeSubpath)
    if not topRightX then
        return true
    end
    fillSubpath:lineTo(topRightX, topRightY)


    local bottomRightX, bottomRightY = subpathDataIntersection(bottomSubpath, slab2FakeSubpath)
    if not bottomRightX then
        return true
    end
    fillSubpath:lineTo(bottomRightX, bottomRightY)


    local bottomLeftX, bottomLeftY = subpathDataIntersection(bottomSubpath, slab1FakeSubpath)
    if not bottomLeftX then
        return true
    end
    fillSubpath:lineTo(bottomLeftX, bottomLeftY)

    fillSubpath.isClosed = true

    table.insert(newFaces, fillPath)


    -- print(cellSize .. ' ' .. topLeftY .. ' ' .. bottomLeftY .. ' ' .. topRightY .. ' ' .. bottomRightY)

    local y = topLeftY + cellSize * 0.5
    local offsetX = 0.5
    while y < bottomLeftY do
        if not doesLineIntersectWithAnyPath(pathDataList, {
            x = topLeftX - cellSize * offsetX,
            y = y,
        }, {
            x = topLeftX + cellSize * offsetX,
            y = y,
        }) then
            if not findFaceForPoint(slabsList, pathDataList, minY, maxY, {
                x = topLeftX - cellSize * offsetX,
                y = y,
            }, newFaces, currentFacesHolder, cellSize) then
                for k in pairs(newFaces) do
                    newFaces[k] = nil
                end
                return false
            end
        end

        y = y + cellSize * 0.5
    end

    y = topRightY + cellSize * 0.5
    while y < bottomRightY do
        if not doesLineIntersectWithAnyPath(pathDataList, {
            x = topRightX - cellSize * offsetX,
            y = y,
        }, {
            x = topRightX + cellSize * offsetX,
            y = y,
        }) then
            if not findFaceForPoint(slabsList, pathDataList, minY, maxY, {
                x = topRightX + cellSize * offsetX,
                y = y,
            }, newFaces, currentFacesHolder, cellSize) then
                for k in pairs(newFaces) do
                    newFaces[k] = nil
                end
                return false
            end
        end

        y = y + cellSize * 0.5
    end

    return true
end

function findAllSlabs(pathDataList)
    local intersectionPoints = findAllIntersections(pathDataList)
    local tempSlabs = {}

    for i = 1, #intersectionPoints do
        table.insert(tempSlabs, {
            x = intersectionPoints[i].x,
            points = {
                {
                    y = intersectionPoints[i].y,
                    subpathIds = intersectionPoints[i].subpathIds
                }
            }
        })
    end

    table.sort(tempSlabs, function (a, b) return a.x < b.x end)

    local slabs = {}
    local hash = {}

    for i = 1, #tempSlabs do
        if hash[tempSlabs[i].x] then
            table.insert(slabs[hash[tempSlabs[i].x]].points, tempSlabs[i].points[1])
        else
            table.insert(slabs, tempSlabs[i])
            hash[tempSlabs[i].x] = #slabs
        end
    end

    return slabs
end

function arePointsEqual(p1, p2)
    return (p1.x == p2.x and p1.y == p2.y)
end

function subpathGetYatX(s, x)
    if s.type == 'line' then
        -- vertical lines are a special case. just send back top point
        if s.p1.x == s.p2.x then
            return math.min(s.p1.y, s.p2.y)
        end

        local riseOverRun = (s.p2.y - s.p1.y) / (s.p2.x - s.p1.x)
        local percent = (x - s.p1.x) / (s.p2.x - s.p1.x)
        return s.p1.y + percent * riseOverRun
    end
end

function subpathDataIntersection(s1, s2)
    if s1.type == 'line' and s2.type == 'line' then
        if arePointsEqual(s1.p1, s2.p1) then
            return s1.p1.x, s1.p1.y
        elseif arePointsEqual(s1.p1, s2.p2) then
            return s1.p1.x, s1.p1.y
        elseif arePointsEqual(s1.p2, s2.p1) then
            return s1.p2.x, s1.p2.y
        elseif arePointsEqual(s1.p2, s2.p2) then
            return s1.p2.x, s1.p2.y
        end

        local x1 = s1.p1.x
        local y1 = s1.p1.y
        local x2 = s1.p2.x
        local y2 = s1.p2.y

        local x3 = s2.p1.x
        local y3 = s2.p1.y
        local x4 = s2.p2.x
        local y4 = s2.p2.y

        local denom = ((x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4))
        if denom < 0.01 and denom > -0.01 then
            return nil
        end

        local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        if t < 0.0 or t > 1.0 then
            return nil
        end

        local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        if u  < 0.0 or u > 1.0 then
            return nil
        end

        return (x1 + t * (x2 - x1)), (y1 + t * (y2 - y1))
    else
        return nil
    end
end


-- http://will.thimbleby.net/scanline-flood-fill/
function floodFillScanline(x, y, width, height, diagonal, test, paint)
    -- xMin, xMax, y, down[true] / up[false], extendLeft, extendRight
    local ranges = {}
    table.insert(ranges, {
        xMin = x,
        xMax = x,
        y = y,
        direction = nil,
        extendLeft = true,
        extendRight = true,
    })

    paint(x, y)

    while #ranges > 0 do
        local r = table.remove(ranges)
        -- print(inspect(r))
        local down = r.direction == 'down'
        local up =   r.direction == 'up'

        -- extendLeft
        local minX = r.xMin
        local y = r.y
        if r.extendLeft then
            while minX > 0 and test(minX-1, y) do
                minX = minX - 1
                paint(minX, y)
            end
        end

        local maxX = r.xMax
        -- extendRight
        if r.extendRight then
            while maxX < width - 1 and test(maxX+1, y) do
                maxX = maxX + 1
                paint(maxX, y)
            end
        end

        if diagonal then
            -- extend range looked at for next lines
            if minX>0 then minX = minX - 1 end
            if maxX<width-1 then maxX = maxX + 1 end
        else
            -- extend range ignored from previous line
            r.xMin = r.xMin - 1
            r.xMax = r.xMax + 1
        end

        local function addNextLine(newY, isNext, direction)
            local rMinX = minX
            local inRange = false
            for x=minX, maxX do
                -- skip testing, if testing previous line within previous range
                local empty = (isNext or (x<r.xMin or x>r.xMax)) and test(x, newY)
                if (not inRange) and empty then
                    rMinX = x
                    inRange = true
                elseif inRange and (not empty) then
                    table.insert(ranges, {
                        xMin = rMinX,
                        xMax = x - 1,
                        y = newY,
                        direction = direction,
                        extendLeft = rMinX==minX,
                        extendRight = false,
                    })

                    inRange = false
                end

                if inRange then
                    paint(x, newY)
                end
                -- skip
                if (not isNext) and x==r.xMin then
                    x = r.xMax
                end
            end
            if inRange then
                table.insert(ranges, {
                    xMin = rMinX,
                    xMax = x - 1,
                    y = newY,
                    direction = direction,
                    extendLeft = rMinX==minX,
                    extendRight = true,
                })
            end
        end

        if(y<height-1) then
            addNextLine(y+1, not up, 'down')
        end
        if(y>0) then
            addNextLine(y-1, not down, 'up')
        end
    end
end

function floodFill8Way(startX, startY, width, height, test, paint)
    local queue = {}

    if startX < 0 or startX < 0 or startX >= width or startX >= height then
        return
    end

    table.insert(queue, {
        x = startX,
        y = startY,
    })

    while #queue > 0 do
        local item = table.remove(queue)
        local x = item.x
        local y = item.y

        if test(x, y) then
            paint(x, y)

            for dx = -1, 1 do
                for dy = -1, 1 do
                    local skip = false
                    if dx == 0 and dy == 0 then
                        skip = true
                    end

                    local newX = x + dx
                    local newY = y + dy

                    if newX < 0 or newY < 0 or newX >= width or newY >= height then
                        skip = true
                    end

                    if not skip then
                        if test(newX, newY) then
                            table.insert(queue, {
                                x = newX,
                                y = newY,
                            })
                        end
                    end
                end
            end
        end
    end
end

