-- for dragging points with a fill, we can render to a bmp and then test each affected slab against the bmp

function idToSubpath(pathDataList, id)
    return pathDataList[id.pathIdx].subpathDataList[id.subpathIdx]
end

function makeSubpathId(pathIdx, subpathIdx, subpathData)
    return {
        stringId = subpathData.id,
        pathIdx = pathIdx,
        subpathIdx = subpathIdx,
    }
end

function makeSubpathStringId(subpathData)
    return subpathData.id
end

function subpathIdToSubpathStringId(subpathId)
    return subpathId.stringId
end

function findAllIntersections(pathDataList)
    local result = {}

    for i = 1, #pathDataList do
        for j = 1, #pathDataList[i].subpathDataList do
            local subpathData = pathDataList[i].subpathDataList[j]

            if j > 1 then
                -- create an intersection between two subpaths on the same path
                local otherSubpathData = pathDataList[i].subpathDataList[j - 1]
                local intersections = subpathDataIntersection(subpathData, otherSubpathData)
                for m = 1, #intersections do
                    table.insert(result, {
                        x = intersections[m].x,
                        y = intersections[m].y,
                        subpathIds = {
                            makeSubpathId(i, j, subpathData),
                            makeSubpathId(i, j - 1, otherSubpathData)
                        }
                    })
                end
            end

            for k = 1, i - 1 do
                for l = 1, #pathDataList[k].subpathDataList do
                    local otherSubpathData = pathDataList[k].subpathDataList[l]

                    local intersections = subpathDataIntersection(subpathData, otherSubpathData)
                    for m = 1, #intersections do
                        table.insert(result, {
                            x = intersections[m].x,
                            y = intersections[m].y,
                            subpathIds = {
                                makeSubpathId(i, j, subpathData),
                                makeSubpathId(k, l, otherSubpathData)
                            }
                        })
                    end
                end
            end
        end
    end

    --print(inspect(result))

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

            local intersections = subpathDataIntersection(subpathData, fakeSubpath)
            if #intersections > 0 then
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

            return slabNum
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

            local intersections = subpathDataIntersection(subpathData, slab1FakeSubpath)
            if #intersections > 0 then
                slab1SubpathIds[makeSubpathStringId(subpathData)] = true
            end
        end
    end

    --print(inspect(slab1SubpathIds))

    local slabIntersections = {}
    for i = 1, #pathDataList do
        for j = 1, #pathDataList[i].subpathDataList do
            local subpathData = pathDataList[i].subpathDataList[j]

            local intersections = subpathDataIntersection(subpathData, slab2FakeSubpath)
            if #intersections > 0 then
                local subpathStringId = makeSubpathStringId(subpathData)
                if slab1SubpathIds[subpathStringId] then
                    -- TODO: i don't think it's possible to have more than one intersection here
                    -- but should think about it more
                    for k = 1, #intersections do
                        table.insert(slabIntersections, {
                            y = intersections[k].y,
                            subpathId = makeSubpathId(i, j, subpathData),
                        })
                    end
                end
            end
        end
    end

    return slabIntersections
end

function colorAllSlabs(slabsList, pathDataList, minY, maxY, facesToColor, newFaces, color)
    -- print(inspect(facesToColor))

    for i = 1, #slabsList - 1 do
        local slab1 = slabsList[i]
        local slab2 = slabsList[i + 1]
        
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

        local midPointX = (slab1.x + slab2.x) / 2.0
        local slabMidpointFakeSubpath = {
            type = "line",
            p1 = {
                x = midPointX,
                y = minY,
            },
            p2 = {
                x = midPointX,
                y = maxY,
            },
        }

        for i = 1, #slabIntersections do
            local subpath = idToSubpath(pathDataList, slabIntersections[i].subpathId)
            local intersections = subpathDataIntersection(subpath, slabMidpointFakeSubpath)
    
            slabIntersections[i].midpointIntersectionY = intersections[1].y
        end
    
        table.sort(slabIntersections, function (a, b) return a.midpointIntersectionY < b.midpointIntersectionY end)



        for j = 1, #slabIntersections - 1 do
            local topSubpathId = slabIntersections[j].subpathId
            local bottomSubpathId = slabIntersections[j + 1].subpathId

            local faceId = 'subpath1:' .. subpathIdToSubpathStringId(topSubpathId) .. ' subpath2:' .. subpathIdToSubpathStringId(bottomSubpathId) .. ' slab1:' .. slab1.id .. ' slab2:' .. slab2.id
            -- print(faceId)
            if facesToColor[faceId] then
                local topSubpath = idToSubpath(pathDataList, topSubpathId)
                local bottomSubpath = idToSubpath(pathDataList, bottomSubpathId)

                local fillSubpath = tove.newSubpath()
                local fillPath = tove.newPath()
                fillPath:addSubpath(fillSubpath)
                fillPath:setFillColor(color[1], color[2], color[3], 1.0)

                
                local topLeftIntersections = subpathDataIntersection(topSubpath, slab1FakeSubpath)
                fillSubpath:moveTo(topLeftIntersections[1].x, topLeftIntersections[1].y)


                local topRightIntersections = subpathDataIntersection(topSubpath, slab2FakeSubpath)
                fillSubpath:lineTo(topRightIntersections[1].x, topRightIntersections[1].y)


                local bottomRightIntersections = subpathDataIntersection(bottomSubpath, slab2FakeSubpath)
                fillSubpath:lineTo(bottomRightIntersections[1].x, bottomRightIntersections[1].y)


                local bottomLeftIntersections = subpathDataIntersection(bottomSubpath, slab1FakeSubpath)
                fillSubpath:lineTo(bottomLeftIntersections[1].x, bottomLeftIntersections[1].y)

                fillSubpath.isClosed = true

                table.insert(newFaces, {
                    id = faceId,
                    face = fillPath
                })
            end
        end
    end
end

-- find the top left point of the face. this is not necessarily a subpath/subpath intersection. can also be a subpath/slab line intersection
function findFaceForPoint(slabsList, pathDataList, minY, maxY, point, newFaces, currentFaces, cellSize, color)
    --table.insert(_FACE_POINTS, point.x)
    --table.insert(_FACE_POINTS, point.y)

    local firstSlabIdx = findSlabsForPoint(slabsList, point)
    if firstSlabIdx == nil then
        return false
    end
    local slab1 = slabsList[firstSlabIdx]
    local slab2 = slabsList[firstSlabIdx + 1]

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
        local userIntersections = subpathDataIntersection(subpath, slabPointFakeSubpath)

        slabIntersections[i].userIntersectionY = userIntersections[1].y
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

    local faceId = 'subpath1:' .. subpathIdToSubpathStringId(topSubpathId) .. ' subpath2:' .. subpathIdToSubpathStringId(bottomSubpathId) .. ' slab1:' .. slab1.id .. ' slab2:' .. slab2.id
    if currentFaces[faceId] then
        return true
    end

    currentFaces[faceId] = true

    local topSubpath = idToSubpath(pathDataList, topSubpathId)
    local bottomSubpath = idToSubpath(pathDataList, bottomSubpathId)

    local fillSubpath = tove.newSubpath()
    local fillPath = tove.newPath()
    fillPath:addSubpath(fillSubpath)
    fillPath:setFillColor(color[1], color[2], color[3], 1.0)

    if DEBUG_FLOOD_FILL then
        fillPath:setLineColor(1.0, 0.0, 0.0, 1.0)
        fillPath:setLineWidth(0.02)
        fillPath:setMiterLimit(1)
        fillPath:setLineJoin("round")
    end

    
    local topLeftIntersections = subpathDataIntersection(topSubpath, slab1FakeSubpath)
    if #topLeftIntersections == 0 then
        return true
    end
    local topLeftX = topLeftIntersections[1].x
    local topLeftY = topLeftIntersections[1].y
    fillSubpath:moveTo(topLeftIntersections[1].x, topLeftIntersections[1].y)

    cutSubpathData(topSubpath, fillSubpath, slab1.x, slab2.x, minY, maxY, true)

    local topRightIntersections = subpathDataIntersection(topSubpath, slab2FakeSubpath)
    if #topRightIntersections == 0 then
        return true
    end
    local topRightX = topRightIntersections[1].x
    local topRightY = topRightIntersections[1].y
    fillSubpath:lineTo(topRightIntersections[1].x, topRightIntersections[1].y)





    local bottomRightIntersections = subpathDataIntersection(bottomSubpath, slab2FakeSubpath)
    if #bottomRightIntersections == 0 then
        return true
    end
    local bottomRightX = bottomRightIntersections[1].x
    local bottomRightY = bottomRightIntersections[1].y
    fillSubpath:lineTo(bottomRightIntersections[1].x, bottomRightIntersections[1].y)


    cutSubpathData(bottomSubpath, fillSubpath, slab1.x, slab2.x, minY, maxY, false)

    local bottomLeftIntersections = subpathDataIntersection(bottomSubpath, slab1FakeSubpath)
    if #bottomLeftIntersections == 0 then
        return true
    end
    local bottomLeftX = bottomLeftIntersections[1].x
    local bottomLeftY = bottomLeftIntersections[1].y
    fillSubpath:lineTo(bottomLeftIntersections[1].x, bottomLeftIntersections[1].y)



    fillSubpath.isClosed = true

    table.insert(newFaces, {
        id = faceId,
        face = fillPath
    })


    -- print(cellSize .. ' ' .. topLeftY .. ' ' .. bottomLeftY .. ' ' .. topRightY .. ' ' .. bottomRightY)


    local myOffsetX = cellSize * 0.1
    local mySlabWidth = slab2.x - slab1.x
    if mySlabWidth * 0.5 < myOffsetX then
        myOffsetX = mySlabWidth * 0.5
    end

    local offsetX = cellSize * 0.1

    if firstSlabIdx > 1 then
        local prevSlabWidth = slab1.x - slabsList[firstSlabIdx - 1].x
        if prevSlabWidth * 0.5 < offsetX then
            offsetX = prevSlabWidth * 0.5
        end
    end

    local y = topLeftIntersections[1].y + cellSize * 0.5
    while y < bottomLeftY do
        if not doesLineIntersectWithAnyPath(pathDataList, {
            x = topLeftX - offsetX,
            y = y,
        }, {
            x = topLeftX + myOffsetX,
            y = y,
        }) then
            if not findFaceForPoint(slabsList, pathDataList, minY, maxY, {
                x = topLeftX - cellSize * offsetX,
                y = y,
            }, newFaces, currentFaces, cellSize, color) then
                for k in pairs(newFaces) do
                    newFaces[k] = nil
                end
                return false
            end
        end

        y = y + cellSize * 0.5
    end
    

    offsetX = cellSize * 0.1

    if firstSlabIdx + 2 <= #slabsList then
        local nextSlabWidth = slabsList[firstSlabIdx + 2].x - slab2.x
        if nextSlabWidth * 0.5 < offsetX then
            offsetX = nextSlabWidth * 0.5
        end
    end

    y = topRightY + cellSize * 0.5
    while y < bottomRightY do
        if not doesLineIntersectWithAnyPath(pathDataList, {
            x = topRightX - myOffsetX,
            y = y,
        }, {
            x = topRightX + offsetX,
            y = y,
        }) then
            if not findFaceForPoint(slabsList, pathDataList, minY, maxY, {
                x = topRightX + cellSize * offsetX,
                y = y,
            }, newFaces, currentFaces, cellSize, color) then
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
        local subpathId1 = intersectionPoints[i].subpathIds[1]
        local subpathId2 = intersectionPoints[i].subpathIds[2]

        if subpathId1.stringId > subpathId2.stringId then
            local tempSubpathId = subpathId1
            subpathId1 = subpathId2
            subpathId2 = tempSubpathId
        end

        table.insert(tempSlabs, {
            x = intersectionPoints[i].x,
            id = 'slab+' .. subpathIdToSubpathStringId(subpathId1) .. '+' .. subpathIdToSubpathStringId(subpathId2),
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

    -- dedup
    -- TODO: not sure exactly how we should handle ids here. just using the first might be stable enough?
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

local function distance(p1, p2)
    return math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0))
end

local function areAnglesEqual(a1, a2)
    local delta = 0.001
    for i = -1, 1, 1 do
        local ta1 = a1 + (i * math.pi * 2.0)
        if a2 > ta1 - delta and a2 < ta1 + delta then
            return true
        end
    end

    return false
end

function subpathDataIntersection(s1, s2)
    local results = {}

    if s1.type == 'line' and s2.type == 'line' then
        if arePointsEqual(s1.p1, s2.p1) or arePointsEqual(s1.p1, s2.p2) then
            table.insert(results, {
                x = s1.p1.x,
                y = s1.p1.y,
            })
            return results
        elseif arePointsEqual(s1.p2, s2.p1) or arePointsEqual(s1.p2, s2.p2) then
            table.insert(results, {
                x = s1.p2.x,
                y = s1.p2.y,
            })
            return results
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
            return results
        end

        local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        if t < 0.0 or t > 1.0 then
            return results
        end

        local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        if u  < 0.0 or u > 1.0 then
            return results
        end

        table.insert(results, {
            x = (x1 + t * (x2 - x1)),
            y = (y1 + t * (y2 - y1))
        })
    elseif s1.type == 'arc' and s2.type == 'arc' then
        -- https://stackoverflow.com/questions/3349125/circle-circle-intersection-points
        local d = distance(s1.center, s2.center)

        if d > s1.radius + s2.radius then
            return results
        end

        -- one circle is completely inside the other
        if d < math.abs(s1.radius - s2.radius) then
            return results
        end

        local tempResults = {}

        if d > -0.0001 and d < 0.0001 then
            -- the circles are coincident. add all the end points of the arcs
            -- TODO: should we handle if the lines completely overlap?
            if areAnglesEqual(s1.startAngle, s2.endAngle) or areAnglesEqual(s1.startAngle, s2.startAngle) then
                table.insert(tempResults, {
                    x = s1.center.x + math.cos(s1.startAngle) * s1.radius,
                    y = s1.center.y + math.sin(s1.startAngle) * s1.radius,
                })
            elseif areAnglesEqual(s1.endAngle, s2.endAngle) or areAnglesEqual(s1.endAngle, s2.startAngle) then
                table.insert(tempResults, {
                    x = s1.center.x + math.cos(s1.endAngle) * s1.radius,
                    y = s1.center.y + math.sin(s1.endAngle) * s1.radius,
                })
            else
                return results
            end
        else
            local a = (math.pow(s1.radius, 2.0) - math.pow(s2.radius, 2.0) + math.pow(d, 2.0)) / (2.0 * d)
            -- h will be 0 if they intersect at only one point
            local h = math.sqrt(math.pow(s1.radius, 2.0) - math.pow(a, 2.0))
            local p2 = {
                x = s1.center.x + ((a * (s2.center.x - s1.center.x)) / d),
                y = s1.center.y + ((a * (s2.center.y - s1.center.y)) / d),
            }

            table.insert(tempResults, p2)

            if h > -0.0001 and h < 0.0001 then
                table.insert(tempResults, p2)
            else
                table.insert(tempResults, {
                    x = p2.x + ((h * (s2.center.y - s1.center.y)) / d),
                    y = p2.y - ((h * (s2.center.x - s1.center.x)) / d),
                })

                table.insert(tempResults, {
                    x = p2.x - ((h * (s2.center.y - s1.center.y)) / d),
                    y = p2.y + ((h * (s2.center.x - s1.center.x)) / d),
                })
            end
        end

        for i = 1, #tempResults do
            local tempResult = tempResults[i]
            local angle1 = math.atan2(tempResult.y - s1.center.y, tempResult.x - s1.center.x)
            local angle2 = math.atan2(tempResult.y - s2.center.y, tempResult.x - s2.center.x)
            local angle1Passed = false
            local angle2Passed = false

            for j = -1, 1, 1 do
                local add = 2.0 * math.pi * j
                if angle1 + add >= s1.startAngle - 0.001 and angle1 + add <= s1.endAngle + 0.001 then
                    angle1Passed = true
                end
                if angle2 + add >= s2.startAngle - 0.001 and angle2 + add <= s2.endAngle + 0.001 then
                    angle2Passed = true
                end
            end

            if angle1Passed and angle2Passed then
                table.insert(results, {
                    x = tempResult.x,
                    y = tempResult.y,
                })
            end
        end
    else
        if s1.type == 'arc' then
            local t = s1
            s1 = s2
            s2 = t
        end

        -- imagine the circle is centered at (0, 0)
        local x1 = s1.p1.x - s2.center.x
        local y1 = s1.p1.y - s2.center.y
        local x2 = s1.p2.x - s2.center.x
        local y2 = s1.p2.y - s2.center.y

        local dx = x2 - x1
        local dy = y2 - y1
        local dr = math.sqrt(dx * dx + dy * dy)
        local D = x1 * y2 - x2 * y1
        local r = s2.radius

        local discriminant = r * r * dr * dr - D * D
        local tempResults = {}

        local angleDelta = 0.0001
        if discriminant <= -angleDelta then
            return results
        elseif discriminant < angleDelta and discriminant > -angleDelta then
            local resultX = (D * dy) / (dr * dr)
            local resultY = (-D * dx) / (dr * dr)
            table.insert(tempResults, {
                x = resultX,
                y = resultY,
            })
        else
            local sgnDy = 1
            if dy < 0 then
                sgnDy = -1
            end

            local resultX1 = (D * dy + sgnDy * dx * math.sqrt(discriminant)) / (dr * dr)
            local resultY1 = (-D * dx + math.abs(dy) * math.sqrt(discriminant)) / (dr * dr)
            local resultX2 = (D * dy - sgnDy * dx * math.sqrt(discriminant)) / (dr * dr)
            local resultY2 = (-D * dx - math.abs(dy) * math.sqrt(discriminant)) / (dr * dr)

            table.insert(tempResults, {
                x = resultX1,
                y = resultY1,
            })

            table.insert(tempResults, {
                x = resultX2,
                y = resultY2,
            })
        end

        -- make sure the points are inside the line segment
        local tempResults2 = {}
        local delta = 0.00001
        for i = 1, #tempResults do
            local tempResult = tempResults[i]
            local minx = math.min(x1, x2) - delta
            local maxx = math.max(x1, x2) + delta
            local miny = math.min(y1, y2) - delta
            local maxy = math.max(y1, y2) + delta

            --print('minx:' .. minx .. ' maxx:' .. maxx .. ' miny:' .. miny .. ' maxy:' .. maxy .. ' tempx:' .. tempResult.x .. ' tempy:' .. tempResult.y)

            if tempResult.x >= minx and tempResult.x <= maxx and tempResult.y >= miny and tempResult.y <= maxy then 
                table.insert(tempResults2, tempResult)
            end
        end

        -- check to make sure the points are actually in this part of the arc
        for i = 1, #tempResults2 do
            local tempResult = tempResults2[i]
            local angle = math.atan2(tempResult.y, tempResult.x)
            --print('intersection angle: ' .. angle)
            --print('start angle: ' .. s2.startAngle .. '   end Angle' .. s2.endAngle)
            for j = -1, 1, 1 do
                local add = 2.0 * math.pi * j
                if angle + add >= s2.startAngle and angle + add <= s2.endAngle then
                    table.insert(results, {
                        x = tempResult.x + s2.center.x,
                        y = tempResult.y + s2.center.y,
                        angle = angle,
                    })
                    break
                end
            end
        end
    end

    return results
end

--[[

    |
  3 |  4
    |
----------
    |
  2 |  1
    |

]]--

local function normalizeRadianAngle(angle)
    local pi2 = 2.0 * math.pi
    if angle < 0 then
        angle = angle + pi2
    elseif angle > pi2 then
        angle = angle - pi2
    end

    return angle
end

local function radianAngleQuadrant(angle)
    return math.floor(normalizeRadianAngle(angle) / (math.pi / 2.0)) + 1
end

function cutSubpathData(subpathData, newSubpath, x1, x2, minY, maxY, leftToRight)
    local x1FakeSubpath = {
        type = "line",
        p1 = {
            x = x1,
            y = minY,
        },
        p2 = {
            x = x1,
            y = maxY,
        },
    }

    local x2FakeSubpath = {
        type = "line",
        p1 = {
            x = x2,
            y = minY,
        },
        p2 = {
            x = x2,
            y = maxY,
        },
    }

    local x1Intersections = subpathDataIntersection(subpathData, x1FakeSubpath)
    local x2Intersections = subpathDataIntersection(subpathData, x2FakeSubpath)

    if #x1Intersections ~= 1 or #x2Intersections ~= 1 then
        -- this should be impossible
       return nil 
    end

    local x1Int = x1Intersections[1]
    local x2Int = x2Intersections[1]

    if subpathData.type == 'line' then
        
    else

        local numSegments = 10.0
        local xStep
        local currentX

        if leftToRight then
            xStep = (x2 - x1) / numSegments
            currentX = x1 + xStep
        else
            xStep = -(x2 - x1) / numSegments
            currentX = x2 + xStep
        end

        for i = 1, numSegments - 1 do
            local fakeSubpath = {
                type = "line",
                p1 = {
                    x = currentX,
                    y = minY,
                },
                p2 = {
                    x = currentX,
                    y = maxY,
                },
            }

            local xIntersections = subpathDataIntersection(subpathData, fakeSubpath)
            newSubpath:lineTo(xIntersections[1].x, xIntersections[1].y)

            currentX = currentX + xStep
        end

        --[[
        local angle1 = normalizeRadianAngle(x1Int.angle)
        local angle2 = normalizeRadianAngle(x2Int.angle)
        local quadrant1 = radianAngleQuadrant(angle1)
        local quadrant2 = radianAngleQuadrant(angle2)

        if quadrant1 > quadrant2 and quadrant1 ~= 4 then
            local t = angle1
            angle1 = angle2
            angle2 = t

            t = quadrant1
            quadrant1 = quadrant2
            quadrant2 = t
        end

        local startAngle, endAngle

        local angle1X = math.cos(angle1) * subpathData.radius + subpathData.center.x
        local angle1Y = math.sin(angle1) * subpathData.radius + subpathData.center.y
        local distFromAngle1ToStartPoint = math.sqrt(math.pow(angle1X - startPoint.x, 2.0) + math.pow(angle1Y - startPoint.y, 2.0))
        print(distFromAngle1ToStartPoint)
        if distFromAngle1ToStartPoint < 0.001 then
            startAngle = angle1
            endAngle = angle2
        else
            startAngle = angle2
            endAngle = angle1
        end

        local numPoints = 3
        local angleDiff = endAngle - startAngle
        if math.abs(angleDiff) > math.pi / 2.0 then
            local tryAngleDiff = angleDiff - 2.0 * math.pi

            if math.abs(tryAngleDiff) > math.pi / 2.0 then
                tryAngleDiff = angleDiff + 2.0 * math.pi
            end

            angleDiff = tryAngleDiff
        end
        print('angleDiff ' .. angleDiff)
        local angleDelta = angleDiff / numPoints
        local currentAngle = endAngle - angleDiff

        for i = 1, numPoints do
            currentAngle = currentAngle + angleDelta
            local x = math.cos(currentAngle) * subpathData.radius + subpathData.center.x
            local y = math.sin(currentAngle) * subpathData.radius + subpathData.center.y

            print(x .. ' ' .. y)

            newSubpath:lineTo(x, y)
        end
]]--

        --newSubpath:arc(subpathData.center.x, subpathData.center.y, subpathData.radius, startAngle * 180 / math.pi, endAngle * 180 / math.pi)
    end
end