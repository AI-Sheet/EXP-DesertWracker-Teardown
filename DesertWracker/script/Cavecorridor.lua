------------------------------------------------------------------
-- Cave Generator with Fixed Cube Size (64x64x64), Through-Holes
-- and Interior Tunnels Carving Toward Neighboring Cubes
--
-- This script spawns cubes (64x64x64), carves a through-hole in
-- each cube for interconnection, and then carves interior tunnels 
-- from each cube's center only in the direction of an adjacent cube.
-- The tunnel is carved using a fixed corridor width.
--
-- TeardownAPI + Lua 5.1
------------------------------------------------------------------

-- Configuration
local MATERIAL = "wood"           -- Cube material
local DEBUG_MODE = true           -- Enable debug visualization
local NUM_CUBES = 2              -- Number of cubes to spawn (adjust as needed)
local FIXED_SIZE = "64 64 64"       -- Fixed cube size in world units
local HOLE_SIZE = 0             -- Size of the central through-hole (in voxels)
local CORRIDOR_WIDTH = 20         -- Width of the interior tunnel (in voxels)

-- Direction weights for cube placement (for spawning)
local DIRECTION_WEIGHTS = {
    [Vec(1, 0, 0)] = 15,    -- Right
    [Vec(-1, 0, 0)] = 15,   -- Left
    [Vec(0, 1, 0)] = 5,     -- Up
    [Vec(0, -1, 0)] = 35,   -- Down
    [Vec(0, 0, 1)] = 15,    -- Forward
    [Vec(0, 0, -1)] = 5     -- Back
}

-- Tables to store cube data
local cubeData = {}   -- Data for spawning cubes (contains position, size, name)
local cubes = {}      -- Spawned cube info: { position, shape, name, size }

-----------------------------------------------------
-- Helper Functions
-----------------------------------------------------

function DebugLog(message)
    DebugPrint("[CaveGenerator] " .. message)
end

-- Parse a size string "w h d" into three numbers.
function ParseSize(sizeStr)
    local w, h, d = sizeStr:match("(%d+)%s+(%d+)%s+(%d+)")
    return tonumber(w), tonumber(h), tonumber(d)
end

-- Computes the center of a cube from its lower corner (position) and size.
function CubeCenter(pos, sizeStr)
    local sx, sy, sz = ParseSize(sizeStr)
    return Vec(pos[1] + sx/2, pos[2] + sy/2, pos[3] + sz/2)
end

-- Choose a random direction for cube placement based on weighted probabilities.
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
    local axes = { Vec(1,0,0), Vec(-1,0,0), Vec(0,1,0), Vec(0,-1,0), Vec(0,0,1), Vec(0,0,-1) }
    return axes[math.random(#axes)]
end

-- Computes offset for positioning a candidate cube so that cubes can connect.
function ComputeRequiredOffset(currentCube, candidateCube, direction)
    local halfSize = 32 -- half of 64
    local rawOffset = (halfSize + halfSize) / 10 - 1.8 -- approx. 4.6
    local finalOffset = math.max(rawOffset, 0)
    return math.floor(finalOffset + 0.5)
end

-----------------------------------------------------
-- Spawning Cubes
-----------------------------------------------------

function SpawnCubes()
    DebugLog("Spawning cubes with fixed size " .. FIXED_SIZE .. "...")
    cubeData = {}
    cubes = {}

    -- Spawn entrance cube at a fixed position.
    local entryPos = Vec(0, 4, 0)
    local entranceCube = { pos = entryPos, size = FIXED_SIZE, name = "entrance" }
    table.insert(cubeData, entranceCube)

    local currentPos = entryPos
    local currentIndex = 1
    local cubesCreated = 1

    while cubesCreated < NUM_CUBES do
        local candidateCube = { pos = nil, size = FIXED_SIZE, name = "cube_" .. (cubesCreated + 1) }
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
                if math.abs(math.abs(diff[1]) - reqOffset) < 0.1 and 
                   math.abs(diff[2]) < 0.1 and 
                   math.abs(diff[3]) < 0.1 then
                    isConnected = true
                    break
                end
            elseif math.abs(direction[2]) > 0 then
                if math.abs(math.abs(diff[2]) - reqOffset) < 0.1 and 
                   math.abs(diff[1]) < 0.1 and 
                   math.abs(diff[3]) < 0.1 then
                    isConnected = true
                    break
                end
            elseif math.abs(direction[3]) > 0 then
                if math.abs(math.abs(diff[3]) - reqOffset) < 0.1 and 
                   math.abs(diff[1]) < 0.1 and 
                   math.abs(diff[2]) < 0.1 then
                    isConnected = true
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

    -- Spawn cubes in the world.
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

    -- Debug: Draw crosses at cube centers.
    for i, cube in ipairs(cubes) do
        local center = CubeCenter(cube.position, cube.size)
        DebugCross(center, 1, 0, 0, 3)
        DebugPrint("Cube center (" .. cube.name .. "): (" .. center[1] .. ", " ..
                   center[2] .. ", " .. center[3] .. ")")
    end
end

-----------------------------------------------------
-- Carving Through-Holes between Cubes
-----------------------------------------------------

function CarveTunnelBetweenCubes()
    DebugLog("Carving through-hole in each cube...")
    local halfHole = HOLE_SIZE / 2
    for i, cube in ipairs(cubes) do
        local center = CubeCenter(cube.position, cube.size)
        SetBrush("sphere", 3, 0)
        -- Convert center from global to local coordinates.
        local lx1 = center[1] - halfHole - cube.position[1]
        local ly1 = center[2] - halfHole - cube.position[2]
        local lz1 = center[3] - halfHole - cube.position[3]
        local lx2 = center[1] + halfHole - cube.position[1]
        local ly2 = center[2] + halfHole - cube.position[2]
        local lz2 = center[3] + halfHole - cube.position[3]
        DrawShapeBox(cube.shape, lx1, ly1, lz1, lx2, ly2, lz2)
        DebugLog("Carved through-hole in cube '" .. cube.name .. "' at center (" ..
                 center[1] .. ", " .. center[2] .. ", " .. center[3] .. ")")
    end
end

-----------------------------------------------------
-- Carving Interior Tunnels Toward Neighboring Cubes
-----------------------------------------------------

-- For each cube, determine neighbors based on center positions.
-- Carve an interior tunnel from the cube's center only in the direction
-- of each adjacent cube (one tunnel per cardinal direction).
function CarveInteriorTunnels()
    DebugLog("Carving interior tunnels toward neighboring cubes...")
    local sx, sy, sz = ParseSize(FIXED_SIZE)  -- Cube dimensions (64x64x64)
    for i, cube in ipairs(cubes) do
        local center = CubeCenter(cube.position, cube.size)
        local localCenter = VecSub(center, cube.position)
        local carvedDirs = {}  -- Keep track of directions already carved for this cube

        for j, other in ipairs(cubes) do
            if other ~= cube then
                local otherCenter = CubeCenter(other.position, other.size)
                local delta = VecSub(otherCenter, center)
                local absDelta = { math.abs(delta[1]), math.abs(delta[2]), math.abs(delta[3]) }
                local directionKey = nil
                if absDelta[1] >= absDelta[2] and absDelta[1] >= absDelta[3] then
                    directionKey = (delta[1] > 0) and "posX" or "negX"
                elseif absDelta[2] >= absDelta[1] and absDelta[2] >= absDelta[3] then
                    directionKey = (delta[2] > 0) and "posY" or "negY"
                else
                    directionKey = (delta[3] > 0) and "posZ" or "negZ"
                end

                if not carvedDirs[directionKey] then
                    local face = nil
                    if directionKey == "posX" then
                        face = { sx, localCenter[2], localCenter[3] }
                    elseif directionKey == "negX" then
                        face = { 0, localCenter[2], localCenter[3] }
                    elseif directionKey == "posY" then
                        face = { localCenter[1], sy, localCenter[3] }
                    elseif directionKey == "negY" then
                        face = { localCenter[1], 0, localCenter[3] }
                    elseif directionKey == "posZ" then
                        face = { localCenter[1], localCenter[2], sz }
                    elseif directionKey == "negZ" then
                        face = { localCenter[1], localCenter[2], 0 }
                    end

                    local startPoint = localCenter
                    local endPoint = face
                    local lx = math.min(startPoint[1], endPoint[1]) - CORRIDOR_WIDTH/2
                    local ly = math.min(startPoint[2], endPoint[2]) - CORRIDOR_WIDTH/2
                    local lz = math.min(startPoint[3], endPoint[3]) - CORRIDOR_WIDTH/2
                    local ux = math.max(startPoint[1], endPoint[1]) + CORRIDOR_WIDTH/2
                    local uy = math.max(startPoint[2], endPoint[2]) + CORRIDOR_WIDTH/2
                    local uz = math.max(startPoint[3], endPoint[3]) + CORRIDOR_WIDTH/2
                    -- Clamp bounds to cube dimensions.
                    lx = math.max(lx, 0)
                    ly = math.max(ly, 0)
                    lz = math.max(lz, 0)
                    ux = math.min(ux, sx)
                    uy = math.min(uy, sy)
                    uz = math.min(uz, sz)
                    SetBrush("sphere", 3, 0)
                    DrawShapeBox(cube.shape, lx, ly, lz, ux, uy, uz)
                    DebugLog("Carved interior tunnel in cube '" .. cube.name .. "' toward " .. directionKey)
                    carvedDirs[directionKey] = true
                end
            end
        end
    end
end

-----------------------------------------------------
-- Merging Cube Shapes
-----------------------------------------------------

function MergeAllCubes()
    DebugLog("Merging cube shapes...")
    local shapes = {}
    for i, cube in ipairs(cubes) do
        table.insert(shapes, cube.shape)
    end
    if #shapes == 0 then return 0 end
    local mergedShape = shapes[1]
    for i = 2, #shapes do
        mergedShape = MergeShape(shapes[i])
    end
    return mergedShape
end

-----------------------------------------------------
-- Main Flow: Spawn, Carve Through-Holes and Interior Tunnels, Merge
-----------------------------------------------------

function SpawnCaveStructure()
    DebugLog("Spawning cave structure with interior tunnels toward neighbors...")
    SpawnCubes()
    CarveTunnelBetweenCubes()
    CarveInteriorTunnels()
    local mergedShape = MergeAllCubes()
    DebugLog("Merged shape handle: " .. mergedShape)
end

-----------------------------------------------------
-- Debug Visualization
-----------------------------------------------------

function DrawDebugVisualization()
    if not DEBUG_MODE or #cubes == 0 then return end
    for i, cube in ipairs(cubes) do
        local col = (i == 1) and {0, 0, 1} or {1, 0, 0}
        DebugCross(cube.position, col[1], col[2], col[3], 1)
        local labelPos = VecAdd(cube.position, Vec(0, 0.5, 0))
        DebugPrint(cube.name .. " - " .. cube.size, labelPos[1], labelPos[2], labelPos[3])
        local center = CubeCenter(cube.position, cube.size)
        DebugCross(center, 1, 0, 0, 3)
    end
end

-----------------------------------------------------
-- Script Lifecycle Functions
-----------------------------------------------------

function init()
    DebugLog("Cave Generator with Interior Tunnels (Neighbor Directed) initialized. Press 'G' to spawn structure.")
    math.randomseed(GetTime())
end

function tick()
    if InputPressed("g") then
        SpawnCaveStructure()
    end
    if InputPressed("r") then
        for i = 1, #cubes do
            Delete(cubes[i].shape)
        end
        cubes = {}
        cubeData = {}
        DebugLog("Reset complete. Press 'G' to spawn structure again.")
    end
    DrawDebugVisualization()
    if #cubes > 0 then
        DebugPrint("Structure present. Press 'R' to reset.")
    else
        DebugPrint("Press 'G' to spawn cave structure.")
    end
end