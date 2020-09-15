local PROFILER_ENABLED = true
local DISPLAY_INTERVAL = 5.0

local timeSinceLastDisplay = 0.0
local categoryStats = {}

function profileFunction(category, fn)
    if not PROFILER_ENABLED then
        fn()
        return
    end

    local startTime = love.timer.getTime()
    local result = {fn()}
    local timeDiff = love.timer.getTime() - startTime

    if categoryStats[category] then
        categoryStats[category] = {
            count = 1 + categoryStats[category].count,
            time = timeDiff + categoryStats[category].time,
        }
    else
        categoryStats[category] = {
            count = 1,
            time = timeDiff,
        }
    end

    return unpack(result)
end

local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function profilerUpdate(dt)
    if not PROFILER_ENABLED then
        return
    end

    timeSinceLastDisplay = timeSinceLastDisplay + dt
    if timeSinceLastDisplay < DISPLAY_INTERVAL then
        return
    end

    timeSinceLastDisplay = 0.0

    local sortedCategoryStats = {}

    for categoryName, categoryStat in pairs(categoryStats) do
        local avgTime = categoryStat.time / categoryStat.count
        table.insert(sortedCategoryStats, {
            avgTime = avgTime * 60 * 100, -- % of one frame
            totalTime = categoryStat.time * 1000,
            timesCalled = categoryStat.count,
            categoryName = categoryName,
        })
    end

    table.sort(
        sortedCategoryStats,
        function(entry1, entry2)
            return entry1.totalTime > entry2.totalTime
        end
    )

    print('')
    print('Profiler:')
    for i = 1, #sortedCategoryStats do
        print(sortedCategoryStats[i].categoryName)
        print('      avg: ' .. round(sortedCategoryStats[i].avgTime, 2) .. ' % of a frame')
        print('    total: ' .. round(sortedCategoryStats[i].totalTime, 2) .. 'ms')
        print('    count: ' .. sortedCategoryStats[i].timesCalled .. ' times')
    end

    print('')

    categoryStats = {}
end
