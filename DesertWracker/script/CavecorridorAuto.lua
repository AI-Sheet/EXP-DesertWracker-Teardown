------------------------------------------------------------------
-- Cave Generator with Fixed Cube Size (64x64x64),
-- Drunkard's Walk Tunnel Carving between cubes and internal
-- drunkard's walk cave carving inside each cube.
--
-- This script spawns cubes (64x64x64) filled with voxels.
-- It first connects cubes via randomly carved corridors at their
-- interfaces, then, for each cube, it carves an irregular cave interior
-- using the drunkard's walk algorithm.
--
-- IMPORTANT: Only one entrance is allowed – the entrance cube has
-- an opening carved exclusively on its top face. Other cubes' walls
-- are preserved to prevent unintended openings.
--
-- In each carving operation the brush size is chosen randomly 
-- from 10 to 17.
--
-- TeardownAPI + Lua 5.1
------------------------------------------------------------------

-- Configuration
local MATERIAL = "wood"           -- Cube material
local DEBUG_MODE = true           -- Enable debug visualization
local NUM_CUBES = 5               -- Total cubes to spawn (adjustable)
local FIXED_SIZE = "64 64 64"       -- Fixed cube size in world units

-- Direction weights for cube placement (for spawning)
local DIRECTION_WEIGHTS = {
    [Vec(1, 0, 0)] = 15,    -- Right
    [Vec(-1, 0, 0)] = 15,   -- Left
    [Vec(0, 1, 0)] = 10,     -- Up
    [Vec(0, -1, 0)] = 25,   -- Down
    [Vec(0, 0, 1)] = 15,    -- Forward
    [Vec(0, 0, -1)] = 10     -- Back
}

-- Tables to store cube data
local cubeData = {}   -- Data for spawning cubes (position, size, name)
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
    local baseOffset = (halfSize + halfSize) / 10 - 1.8 -- approx. 4.6
    local extraOffset = 1  -- Additional extra offset to space cubes out
    local finalOffset = math.max(baseOffset, 0) + extraOffset
    return math.floor(finalOffset + 0.5)
end

-----------------------------------------------------
-- Spawning Cubes
-----------------------------------------------------
function SpawnCubes()
    DebugLog("Spawning cubes with fixed size " .. FIXED_SIZE .. "...")
    cubeData = {}
    cubes = {}
    
    -- Spawn the entrance cube at a fixed position.
    local entryPos = Vec(20, 10, -50)
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
-- Tunnel Carving between Two Adjacent Cubes
-----------------------------------------------------
-- Carves a tunnel between two cubes along the primary axis from their centers.
function CarveTunnelBetweenTwoCubes(cubeA, cubeB)
    local centerA = CubeCenter(cubeA.position, cubeA.size)
    local centerB = CubeCenter(cubeB.position, cubeB.size)
    local delta = VecSub(centerB, centerA)
    
    -- Determine primary movement axis.
    local absDelta = { math.abs(delta[1]), math.abs(delta[2]), math.abs(delta[3]) }
    local primaryAxis, signDir
    if absDelta[1] >= absDelta[2] and absDelta[1] >= absDelta[3] then
        primaryAxis = 1
        signDir = (delta[1] > 0) and 1 or -1
    elseif absDelta[2] >= absDelta[1] and absDelta[2] >= absDelta[3] then
        primaryAxis = 2
        signDir = (delta[2] > 0) and 1 or -1
    else
        primaryAxis = 3
        signDir = (delta[3] > 0) and 1 or -1
    end
    
    -- Determine face points for each cube.
    local function getFaceCoords(cube, center, axis, sign)
        local sx, sy, sz = ParseSize(cube.size)
        local localCenter = VecSub(center, cube.position)
        local face = { localCenter[1], localCenter[2], localCenter[3] }
        if axis == 1 then
            face[1] = (sign > 0) and sx or 0
        elseif axis == 2 then
            face[2] = (sign > 0) and sy or 0
        elseif axis == 3 then
            face[3] = (sign > 0) and sz or 0
        end
        return face
    end
    
    local faceA = getFaceCoords(cubeA, centerA, primaryAxis, signDir)
    local faceB = getFaceCoords(cubeB, centerB, primaryAxis, -signDir)
    
    -- Carve corridor in a cube given a start and an end point.
    local function carveInCube(cube, startPoint, endPoint)
        local brush = math.random(10, 17)
        local halfBrush = math.floor(brush / 2)
        local minBound = {
            math.min(startPoint[1], endPoint[1]) - halfBrush,
            math.min(startPoint[2], endPoint[2]) - halfBrush,
            math.min(startPoint[3], endPoint[3]) - halfBrush
        }
        local maxBound = {
            math.max(startPoint[1], endPoint[1]) + halfBrush,
            math.max(startPoint[2], endPoint[2]) + halfBrush,
            math.max(startPoint[3], endPoint[3]) + halfBrush
        }
        local sx, sy, sz = ParseSize(cube.size)
        minBound[1] = math.max(minBound[1], 0)
        minBound[2] = math.max(minBound[2], 0)
        minBound[3] = math.max(minBound[3], 0)
        maxBound[1] = math.min(maxBound[1], sx)
        maxBound[2] = math.min(maxBound[2], sy)
        maxBound[3] = math.min(maxBound[3], sz)
        SetBrush("sphere", brush, 0)
        DrawShapeBox(cube.shape, minBound[1], minBound[2], minBound[3],
                              maxBound[1], maxBound[2], maxBound[3])
    end
    
    -- Carve in cubeA from its center to faceA.
    local localCenterA = VecSub(centerA, cubeA.position)
    carveInCube(cubeA, localCenterA, faceA)
    
    -- Carve in cubeB from its center to faceB.
    local localCenterB = VecSub(centerB, cubeB.position)
    carveInCube(cubeB, localCenterB, faceB)
    
    DebugLog("Tunnel carved between '" .. cubeA.name .. "' and '" .. cubeB.name .. "'.")
end

-----------------------------------------------------
-- Internal Drunkard's Walk Cave Carving Within a Cube
-----------------------------------------------------
-- Carves an irregular cave interior within a cube using a drunkard's walk.
-- The carving is restricted to an inner region, preserving the outer walls
-- (except for the entrance cube).
function DrunkardsWalkCaveInCube(cube)
    local sx, sy, sz = ParseSize(cube.size)
    local margin =  math.random(10, 17)  -- Use a random margin from the same range.
    -- Start at a random location within the inner region.
    local x = math.random(margin + 1, sx - margin - 1)
    local y = math.random(margin + 1, sy - margin - 1)
    local z = math.random(margin + 1, sz - margin - 1)
    local steps = math.random(100, 300)
    for i = 1, steps do
        local dx = math.random(-1,1)
        local dy = math.random(-1,1)
        local dz = math.random(-1,1)
        x = math.min(math.max(x + dx, margin + 1), sx - margin - 1)
        y = math.min(math.max(y + dy, margin + 1), sy - margin - 1)
        z = math.min(math.max(z + dz, margin + 1), sz - margin - 1)
        local brush = math.random(10, 17)
        local halfBrush = math.floor(brush/2)
        local minX = x - halfBrush
        local minY = y - halfBrush
        local minZ = z - halfBrush
        local maxX = x + halfBrush
        local maxY = y + halfBrush
        local maxZ = z + halfBrush
        SetBrush("sphere", brush, 0)
        DrawShapeBox(cube.shape, minX, minY, minZ, maxX, maxY, maxZ)
    end
    DebugLog("Cave interior carved in cube '" .. cube.name .. "'.")
end

-----------------------------------------------------
-- Carve a Single Entrance on the Top of the Entrance Cube
-----------------------------------------------------
function CarveEntranceOnTop(cube)
    local sx, sy, sz = ParseSize(cube.size)
    local brush = math.random(10, 17)
    local halfBrush = math.floor(brush/2)
    -- Carve an opening on the top face.
    local centerX = math.floor(sx / 2)
    local centerZ = math.floor(sz / 2)
    local openWidth = brush  -- Use random brush size for opening width.
    local minX = centerX - math.floor(openWidth/2)
    local maxX = centerX + math.floor(openWidth/2)
    local minZ = centerZ - math.floor(openWidth/2)
    local maxZ = centerZ + math.floor(openWidth/2)
    -- The top face is at y = sy.
    local minY = sy - openWidth * 3
    local maxY = sy
    SetBrush("sphere", brush, 0)
    DrawShapeBox(cube.shape, minX, minY, minZ, maxX, maxY, maxZ)
    DebugLog("Entrance carved on top of cube '" .. cube.name .. "'.")
end

-----------------------------------------------------
-- Helper to Check if Two Cubes are Adjacent
-----------------------------------------------------
function IsAdjacent(cubeA, cubeB)
    local posA = cubeA.position
    local posB = cubeB.position
    local diff = VecSub(posB, posA)
    local tol = 0.2
    if math.abs(diff[1]) > tol and math.abs(diff[2]) < tol and math.abs(diff[3]) < tol then
        local dir = Vec((diff[1] > 0) and 1 or -1, 0, 0)
        local reqOffset = ComputeRequiredOffset(cubeA, cubeB, dir)
        if math.abs(math.abs(diff[1]) - reqOffset) < tol then return true end
    elseif math.abs(diff[2]) > tol and math.abs(diff[1]) < tol and math.abs(diff[3]) < tol then
        local dir = Vec(0, (diff[2] > 0) and 1 or -1, 0)
        local reqOffset = ComputeRequiredOffset(cubeA, cubeB, dir)
        if math.abs(math.abs(diff[2]) - reqOffset) < tol then return true end
    elseif math.abs(diff[3]) > tol and math.abs(diff[1]) < tol and math.abs(diff[2]) < tol then
        local dir = Vec(0, 0, (diff[3] > 0) and 1 or -1)
        local reqOffset = ComputeRequiredOffset(cubeA, cubeB, dir)
        if math.abs(math.abs(diff[3]) - reqOffset) < tol then return true end
    end
    return false
end

-----------------------------------------------------
-- Drunkard's Walk Tunnel Carving Algorithm Between Cubes
-----------------------------------------------------
function DrunkardsWalkTunnels()
    if #cubes == 0 then
        DebugLog("No cubes available for drilling tunnels.")
        return
    end

    DebugLog("Starting enhanced Drunkard's Walk tunnel carving...")
    local visited = {}
    local path = {}
    local totalCubes = #cubes

    -- Pick a random starting cube.
    local startIndex = math.random(1, totalCubes)
    local currentCube = cubes[startIndex]
    table.insert(path, currentCube)
    visited[currentCube.name] = true

    while (next(visited) and (table.getn(visited) or #path) < totalCubes) do
        local neighbors = {}
        for _, cube in ipairs(cubes) do
            if cube.name ~= currentCube.name and (not visited[cube.name]) then
                if IsAdjacent(currentCube, cube) then
                    table.insert(neighbors, cube)
                end
            end
        end

        if #neighbors > 0 then
            local nextCube = neighbors[math.random(1, #neighbors)]
            CarveTunnelBetweenTwoCubes(currentCube, nextCube)
            table.insert(path, nextCube)
            visited[nextCube.name] = true
            currentCube = nextCube
        else
            local backtracked = false
            for i = #path, 1, -1 do
                local candidate = path[i]
                local candidateNeighbors = {}
                for _, cube in ipairs(cubes) do
                    if cube.name ~= candidate.name and (not visited[cube.name]) then
                        if IsAdjacent(candidate, cube) then
                            table.insert(candidateNeighbors, cube)
                        end
                    end
                end
                if #candidateNeighbors > 0 then
                    currentCube = candidate
                    local nextCube = candidateNeighbors[math.random(1, #candidateNeighbors)]
                    CarveTunnelBetweenTwoCubes(currentCube, nextCube)
                    table.insert(path, nextCube)
                    visited[nextCube.name] = true
                    currentCube = nextCube
                    backtracked = true
                    break
                end
            end
            if not backtracked then break end
        end
    end

    DebugLog("Enhanced Drunkard's Walk tunnel carving complete. Visited " ..
        tostring(table.getn(visited) or #path) .. " cubes.")
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
-- Main Flow: Spawn, Carve Tunnels & Internal Cave, Merge
-----------------------------------------------------
function SpawnCaveStructure()
    DebugLog("Spawning cave structure with tunnels and irregular cave interiors...")
    SpawnCubes()
    -- Carve tunnels (corridors) between adjacent cubes.
    DrunkardsWalkTunnels()
    -- For each cube, carve its interior.
    for _, cube in ipairs(cubes) do
        if cube.name == "entrance" then
            -- Only create one entrance (top) for the entrance cube.
            CarveEntranceOnTop(cube)
        else
            -- Restrict internal carving to preserve exterior walls.
            DrunkardsWalkCaveInCube(cube)
        end
    end
    local mergedShape = MergeAllCubes()
    DebugLog("Merged shape handle: " .. tostring(mergedShape))
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
    DebugLog("Cave Generator with Advanced Drunkard's Walk and single top entrance initialized. Press 'G' to spawn structure.")
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