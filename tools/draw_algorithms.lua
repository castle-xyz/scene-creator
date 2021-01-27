-- DrawAlgorithms
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

function arePointsEqual(p1, p2)
    return (p1.x == p2.x and p1.y == p2.y)
end

function pointsDistance(p1, p2)
    return math.sqrt(math.pow(p2.x - p1.x, 2.0) + math.pow(p2.y - p1.y, 2.0))
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

local function radianAngleQuadrant(angle)
    return math.floor(normalizeRadianAngle(angle) / (math.pi / 2.0)) + 1
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
