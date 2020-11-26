-- for dragging points with a fill, we can render to a bmp and then test each affected slab against the bmp

function floatEquals(f1, f2)
    return f1 > f2 - 0.001 and f1 < f2 + 0.001
end

function floatUnit(f)
    if floatEquals(f, 0) then
        return 0
    elseif f > 0 then
        return 1
    else
        return -1
    end
end

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

function directionForPathData(pathData)
    local direction = {
        x = pathData.points[2].x - pathData.points[1].x,
        y = pathData.points[2].y - pathData.points[1].y,
    }

    local distance = math.sqrt(direction.x * direction.x + direction.y * direction.y)
    direction.x = direction.x / distance
    direction.y = direction.y / distance

    return direction
end

function arePathDataDirectionsEqual(dir1, dir2)
    return dir1.x > dir2.x - 0.001 and dir1.x < dir2.x + 0.001 and dir1.y > dir2.y - 0.001 and dir1.y < dir2.y + 0.001
end

function simplifyPathDataList(pathDataList)
    local results = {}

    local _tempPathData
    local _currentDirection

    for i = 1, #pathDataList do
        local pathData = pathDataList[i]

        local newDirection = directionForPathData(pathData)

        if _tempPathData == nil then
            _tempPathData = pathData
            _currentDirection = directionForPathData(pathData)
        elseif arePathDataDirectionsEqual(_currentDirection, newDirection) then
            _tempPathData.points[2] = pathData.points[2]
        else
            table.insert(results, _tempPathData)

            _tempPathData = pathData
            _currentDirection = directionForPathData(pathData)
        end
    end

    if _tempPathData ~= nil then
        table.insert(results, _tempPathData)
    end

    return results
end

function arePointsEqual(p1, p2)
    return (p1.x == p2.x and p1.y == p2.y)
end

function distance(p1, p2)
    return math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0))
end

function areAnglesEqual(a1, a2)
    local delta = 0.001
    for i = -1, 1, 1 do
        local ta1 = a1 + (i * math.pi * 2.0)
        if a2 > ta1 - delta and a2 < ta1 + delta then
            return true
        end
    end

    return false
end

function rayRayIntersection(x1, y1, x2, y2, x3, y3, x4, y4)
    local denom = ((x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4))
    if denom < 0.01 and denom > -0.01 then
        return nil
    end

    local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom

    return (x1 + t * (x2 - x1)), (y1 + t * (y2 - y1))
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

function normalizeRadianAngle(angle)
    local pi2 = 2.0 * math.pi
    if angle < 0 then
        angle = angle + pi2
    elseif angle > pi2 then
        angle = angle - pi2
    end

    return angle
end

function isAngleBetween(N, a, b)
    N = normalizeRadianAngle(N)
    a = normalizeRadianAngle(a)
    b = normalizeRadianAngle(b)
   
    if a < b then
        return a <= N and N <= b
    else
        return a <= N or N <= b
    end
end

function radianAngleQuadrant(angle)
    return math.floor(normalizeRadianAngle(angle) / (math.pi / 2.0)) + 1
end

