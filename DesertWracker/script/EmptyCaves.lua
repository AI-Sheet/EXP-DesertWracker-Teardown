-- Cave Generator using Drunkard's Walk algorithm with Size-Based Connectivity
-- New cubes are spawned such that they intrude slightly into an existing cube.
-- The offset is computed by dividing the sum of the half-sizes by 10 
-- (e.g., 64 world units yield 6.4 local units) and subtracting OVERLAP_MARGIN.
-- To remove any small fractional gaps (<1 unit), the final offset is rounded to the nearest integer.
--
-- TeardownAPI + Lua 5.1

-- Configuration
local MATERIAL = "rock"         -- Cube material
local DEBUG_MODE = true         -- Enable debug visualization
local NUM_CUBES = 30            -- Number of cubes to generate
local STANDARD_SIZE = 64        -- Standard cube size (64x64x64) in world units
local MIN_SIZE = 64             -- Minimum cube size
local MAX_SIZE = 100            -- Maximum cube size
local TOLERANCE = 0.1           -- Tolerance for connectivity check

-- Use a small OVERLAP_MARGIN to keep cubes close.
local OVERLAP_MARGIN = 1.8        -- Adjusted to 1 to prevent overly negative offsets

-- Direction weights for Drunkard's Walk (using primary axis directions)
local DIRECTION_WEIGHTS = {
    [Vec(1, 0, 0)] = 15,    -- Right
    [Vec(-1, 0, 0)] = 15,   -- Left
    [Vec(0, 1, 0)] = 5,    -- Up
    [Vec(0, -1, 0)] = 35,   -- Down (higher weight)
    [Vec(0, 0, 1)] = 15,    -- Forward
    [Vec(0, 0, -1)] = 5    -- Back
}

-- Tables to store cave data
local cubes = {}
local connections = {}

-- Helper function for logging
function DebugLog(message)
    DebugPrint("[CaveGenerator] " .. message)
end

-- Helper function: Parses a size string "w h d" into three numbers.
function ParseSize(sizeStr)
    local w, h, d = sizeStr:match("(%d+)%s+(%d+)%s+(%d+)")
    return tonumber(w), tonumber(h), tonumber(d)
end

-- Function to generate a random size with variation.
function RandomSize()
    if math.random() < 0.3 then
        return math.random(STANDARD_SIZE, MAX_SIZE)
    end
    return math.random(MIN_SIZE, STANDARD_SIZE)
end

-- Function to choose a direction based on weighted probabilities.
function ChooseDirection()
    local totalWeight = 0
    for _, weight in pairs(DIRECTION_WEIGHTS) do
        totalWeight = totalWeight + weight
    end

    local choice = math.random() * totalWeight
    local currentWeight = 0
    for direction, weight in pairs(DIRECTION_WEIGHTS) do
        currentWeight = currentWeight + weight
        if choice <= currentWeight then
            return direction
        end
    end

    local axes = { Vec(1, 0, 0), Vec(-1, 0, 0), Vec(0, 1, 0), Vec(0, -1, 0), Vec(0, 0, 1), Vec(0, 0, -1) }
    return axes[math.random(#axes)]
end

-- Compute the required offset for connectivity on the specified axis.
-- Using the formula:
--    rawOffset = ((half-size of currentCube + half-size of candidateCube) / 10) - OVERLAP_MARGIN
-- The final offset is clamped to non-negative values and then rounded to the nearest integer.
function ComputeRequiredOffset(currentCube, candidateCube, direction)
    local w1, h1, d1 = ParseSize(currentCube.size)
    local w2, h2, d2 = ParseSize(candidateCube.size)
    
    local rawOffset = 0
    if math.abs(direction[1]) > 0 then
        rawOffset = ((w1/2 + w2/2) / 10) - OVERLAP_MARGIN
    elseif math.abs(direction[2]) > 0 then
        rawOffset = ((h1/2 + h2/2) / 10) - OVERLAP_MARGIN
    elseif math.abs(direction[3]) > 0 then
        rawOffset = ((d1/2 + d2/2) / 10) - OVERLAP_MARGIN
    end
    
    local finalOffset = math.max(rawOffset, 0)
    -- Round to nearest integer to remove any small gaps less than 1
    return math.floor(finalOffset + 0.5)
end

-- Function to spawn the connected cave structure.
-- The first cube is placed at Y=4 as the top entrance.
-- Each subsequent cube is spawned based on the computed offset.
function SpawnCaveStructure()
    DebugLog("Spawning cave structure with offset formula (rounded to eliminate gaps)...")

    -- Clear existing cube and connection data.
    cubes = {}
    connections = {}
    
    -- Spawn the entrance cube at an elevated position (Y = 4).
    local w = RandomSize()
    local h = RandomSize()
    local d = RandomSize()
    local entryPos = Vec(0, 4, 0)
    local topCube = { pos = entryPos, size = w .. " " .. h .. " " .. d, name = "entrance" }
    
    local cubeData = { topCube }
    local currentPos = entryPos
    local currentIndex = 1
    local cubesCreated = 1
    
    while cubesCreated < NUM_CUBES do
        local cw = RandomSize()
        local ch = RandomSize()
        local cd = RandomSize()
        local candidateSize = cw .. " " .. ch .. " " .. cd
        local candidateCube = { pos = nil, size = candidateSize, name = "cube_" .. (cubesCreated + 1) }
        
        local direction = ChooseDirection()
        local currentCube = cubeData[currentIndex]
        local requiredOffset = ComputeRequiredOffset(currentCube, candidateCube, direction)
        candidateCube.pos = VecAdd(currentPos, VecScale(direction, requiredOffset))
        
        local isConnected = false
        for j = 1, #cubeData do
            local otherCube = cubeData[j]
            local reqOffset = ComputeRequiredOffset(otherCube, candidateCube, direction)
            local diff = VecSub(candidateCube.pos, otherCube.pos)
            
            if math.abs(direction[1]) > 0 then
                if math.abs(math.abs(diff[1]) - reqOffset) < TOLERANCE and 
                   math.abs(diff[2]) < TOLERANCE and 
                   math.abs(diff[3]) < TOLERANCE then
                    isConnected = true
                    table.insert(connections, { from = #cubeData + 1, to = j, offset = reqOffset })
                    break
                end
            elseif math.abs(direction[2]) > 0 then
                if math.abs(math.abs(diff[2]) - reqOffset) < TOLERANCE and 
                   math.abs(diff[1]) < TOLERANCE and 
                   math.abs(diff[3]) < TOLERANCE then
                    isConnected = true
                    table.insert(connections, { from = #cubeData + 1, to = j, offset = reqOffset })
                    break
                end
            elseif math.abs(direction[3]) > 0 then
                if math.abs(math.abs(diff[3]) - reqOffset) < TOLERANCE and 
                   math.abs(diff[1]) < TOLERANCE and 
                   math.abs(diff[2]) < TOLERANCE then
                    isConnected = true
                    table.insert(connections, { from = #cubeData + 1, to = j, offset = reqOffset })
                    break
                end
            end
        end
        
        if isConnected then
            table.insert(cubeData, candidateCube)
            currentPos = candidateCube.pos
            currentIndex = #cubeData
            cubesCreated = cubesCreated + 1
        else
            local backIndex = math.random(1, #cubeData)
            currentPos = cubeData[backIndex].pos
            currentIndex = backIndex
        end
    end
    
    for i, cube in ipairs(cubeData) do
        local voxboxXml = "<voxbox size='" .. cube.size .. "' prop='false' material='" .. MATERIAL .. "'/>"
        local transform = Transform(cube.pos)
        local entities = Spawn(voxboxXml, transform, true, true)
        if entities and #entities > 0 then
            DebugLog("Cube " .. i .. " (" .. cube.name .. ") spawned at " ..
                     cube.pos[1] .. ", " .. cube.pos[2] .. ", " .. cube.pos[3] ..
                     " with size " .. cube.size)
            table.insert(cubes, { position = cube.pos, shape = entities[1], name = cube.name, size = cube.size })
        else
            DebugLog("Failed to spawn cube " .. i)
        end
    end
    DebugLog("Spawned " .. #cubes .. " connected cubes with " .. #connections .. " connections")
end

-- Function to visualize cubes and connections in debug mode.
function DrawDebugVisualization()
    if not DEBUG_MODE or #cubes == 0 then return end
    for i = 1, #connections do
        local conn = connections[i]
        if cubes[conn.from] and cubes[conn.to] then
            DebugLine(cubes[conn.from].position, cubes[conn.to].position, 0, 1, 0, 0.5)
            if conn.offset then
                local midpoint = VecLerp(cubes[conn.from].position, cubes[conn.to].position, 0.5)
                DebugPrint(string.format("%.1f", conn.offset), midpoint[1], midpoint[2], midpoint[3])
            end
        end
    end
    for i = 1, #cubes do
        local col = (i == 1) and {0, 0, 1} or {1, 0, 0}
        DebugCross(cubes[i].position, col[1], col[2], col[3], 1)
        local labelPos = VecAdd(cubes[i].position, Vec(0, 0.5, 0))
        DebugPrint(cubes[i].name .. " - " .. cubes[i].size, labelPos[1], labelPos[2], labelPos[3])
    end
end

-- Script lifecycle functions.
function init()
    DebugLog("Cave Generator initialized using rounded connectivity offset. Press 'G' to spawn cave structure.")
    math.randomseed(GetTime())
end

function tick()
    if InputPressed("g") and #cubes == 0 then
        SpawnCaveStructure()
    end
    if InputPressed("r") and #cubes > 0 then
        for i = 1, #cubes do
            Delete(cubes[i].shape)
        end
        cubes = {}
        connections = {}
        DebugLog("Reset complete. Press 'G' to spawn cave structure again.")
    end
    DrawDebugVisualization()
    if #cubes > 0 then
        DebugPrint("Cave structure: " .. #cubes .. " cubes, " .. #connections .. " connections. Press R to reset.")
    else
        DebugPrint("Press 'G' to spawn cave structure.")
    end
end