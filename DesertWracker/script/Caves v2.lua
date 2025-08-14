------------------------------------------------------------------
-- Enhanced Cave Generator with Improved Interior
--
-- Я понял твою идею: сначала планировать структуру пещеры, затем размещать кубы
-- под эту структуру. Это создаст более естественные, плавные пещерные системы,
-- которые охватывают несколько кубов без швов. Расчет смещения сохранен
-- для обеспечения идеального выравнивания кубов.
--
-- Основные улучшения:
-- 1. Более разнообразный и интересный интерьер пещер
-- 2. Лучшие переходы между кубами
-- 3. Вертикальные элементы (шахты, спуски, подъемы)
-- 4. Пространства типа камер и узкие проходы
-- 5. Оптимизированный подход к вырезанию (сначала большие кисти, затем детали)
------------------------------------------------------------------

-- Configuration
local MATERIAL = "rock"           -- Cube material
local DEBUG_MODE = true           -- Enable debug visualization
local NUM_CUBES = 4              -- Total cubes to spawn (adjustable)
local FIXED_SIZE = "96 96 96"     -- Fixed cube size in world units

-- Brush sizes for different carving operations
local LARGE_BRUSH_MIN = 20        -- Minimum size for large brushes
local LARGE_BRUSH_MAX = 30        -- Maximum size for large brushes
local MEDIUM_BRUSH_MIN = 12       -- Minimum size for medium brushes
local MEDIUM_BRUSH_MAX = 19       -- Maximum size for medium brushes
local SMALL_BRUSH_MIN = 5         -- Minimum size for small brushes
local SMALL_BRUSH_MAX = 11        -- Maximum size for small brushes

-- Direction weights for cube placement (for spawning)
local DIRECTION_WEIGHTS = {
    [Vec(1, 0, 0)] = 15,    -- Right
    [Vec(-1, 0, 0)] = 15,   -- Left
    [Vec(0, 1, 0)] = 0,    -- Up
    [Vec(0, -1, 0)] = 35,   -- Down
    [Vec(0, 0, 1)] = 15,    -- Forward
    [Vec(0, 0, -1)] = 10    -- Back
}

-- Cave feature types with their probabilities
local CAVE_FEATURES = {
    { name = "chamber", probability = 0.3 },
    { name = "corridor", probability = 0.3 },
    { name = "vertical_shaft", probability = 0.2 },
    { name = "winding_passage", probability = 0.2 }
}

-- Tables to store cube data
local cubeData = {}   -- Data for spawning cubes (position, size, name)
local cubes = {}      -- Spawned cube info: { position, shape, name, size }
local caveNodes = {}  -- Nodes representing the cave structure

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
    local halfSize = 48 -- half of 96
    -- Объединяем baseOffset и extraOffset как ты просил
    local finalOffset = (halfSize + halfSize) / 10 - 0.8
    return math.floor(finalOffset + 0.5)
end

-- Choose a random cave feature based on probabilities
function ChooseCaveFeature()
    local rand = math.random()
    local cumulativeProbability = 0
    
    for _, feature in ipairs(CAVE_FEATURES) do
        cumulativeProbability = cumulativeProbability + feature.probability
        if rand <= cumulativeProbability then
            return feature.name
        end
    end
    
    return "corridor" -- Default fallback
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
            table.insert(cubes, { 
                position = cube.pos, 
                shape = entities[1], 
                name = cube.name, 
                size = cube.size,
                features = {}  -- Will store cave features carved in this cube
            })
        else
            DebugLog("Failed to spawn cube " .. i)
        end
    end
    
    -- Debug: Draw crosses at cube centers.
    if DEBUG_MODE then
        for i, cube in ipairs(cubes) do
            local center = CubeCenter(cube.position, cube.size)
            DebugCross(center, 1, 0, 0, 3)
        end
    end
end

-----------------------------------------------------
-- Enhanced Tunnel Carving between Two Adjacent Cubes
-----------------------------------------------------
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
    
    -- Determine tunnel type and properties
    local tunnelType = math.random(1, 4)
    local mainBrushSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
    local detailBrushSize = math.random(SMALL_BRUSH_MIN, SMALL_BRUSH_MAX)
    
    -- Carve main tunnel path with larger brush
    CarvePathInCube(cubeA, VecSub(centerA, cubeA.position), faceA, mainBrushSize)
    CarvePathInCube(cubeB, VecSub(centerB, cubeB.position), faceB, mainBrushSize)
    
    -- Add tunnel details based on tunnel type
    if tunnelType == 1 then
        -- Straight tunnel with some roughness
        AddTunnelRoughness(cubeA, VecSub(centerA, cubeA.position), faceA, detailBrushSize)
        AddTunnelRoughness(cubeB, VecSub(centerB, cubeB.position), faceB, detailBrushSize)
    elseif tunnelType == 2 then
        -- Winding tunnel
        CarveWindingPath(cubeA, VecSub(centerA, cubeA.position), faceA, detailBrushSize)
        CarveWindingPath(cubeB, VecSub(centerB, cubeB.position), faceB, detailBrushSize)
    elseif tunnelType == 3 then
        -- Tunnel with side pockets
        CarveSidePockets(cubeA, VecSub(centerA, cubeA.position), faceA, detailBrushSize)
        CarveSidePockets(cubeB, VecSub(centerB, cubeB.position), faceB, detailBrushSize)
    else
        -- Tunnel with height variations
        CarveHeightVariations(cubeA, VecSub(centerA, cubeA.position), faceA, detailBrushSize)
        CarveHeightVariations(cubeB, VecSub(centerB, cubeB.position), faceB, detailBrushSize)
    end
    
    DebugLog("Enhanced tunnel carved between '" .. cubeA.name .. "' and '" .. cubeB.name .. "'.")
end

-- Carve a path in a cube from start to end point with given brush size
function CarvePathInCube(cube, startPoint, endPoint, brushSize)
    local halfBrush = math.floor(brushSize / 2)
    local sx, sy, sz = ParseSize(cube.size)
    
    -- Calculate direction vector
    local direction = {
        endPoint[1] - startPoint[1],
        endPoint[2] - startPoint[2],
        endPoint[3] - startPoint[3]
    }
    
    -- Calculate length of path
    local length = math.sqrt(direction[1]^2 + direction[2]^2 + direction[3]^2)
    
    -- Normalize direction
    if length > 0 then
        direction[1] = direction[1] / length
        direction[2] = direction[2] / length
        direction[3] = direction[3] / length
    end
    
    -- Carve path with multiple spheres along the way
    local steps = math.ceil(length / (brushSize * 0.5))  -- Overlap spheres for smoother path
    for i = 0, steps do
        local t = i / steps
        local pos = {
            startPoint[1] + direction[1] * length * t,
            startPoint[2] + direction[2] * length * t,
            startPoint[3] + direction[3] * length * t
        }
        
        -- Add slight variation to path for more natural look
        if i > 0 and i < steps then
            pos[1] = pos[1] + math.random(-2, 2)
            pos[2] = pos[2] + math.random(-2, 2)
            pos[3] = pos[3] + math.random(-2, 2)
        end
        
        -- Ensure we stay within cube bounds
        pos[1] = math.max(halfBrush, math.min(sx - halfBrush, pos[1]))
        pos[2] = math.max(halfBrush, math.min(sy - halfBrush, pos[2]))
        pos[3] = math.max(halfBrush, math.min(sz - halfBrush, pos[3]))
        
        -- Carve sphere at this position
        SetBrush("sphere", brushSize, 0)
        DrawShapeBox(cube.shape, 
            pos[1] - halfBrush, 
            pos[2] - halfBrush, 
            pos[3] - halfBrush, 
            pos[1] + halfBrush, 
            pos[2] + halfBrush, 
            pos[3] + halfBrush)
    end
end

-- Add roughness to tunnel walls for more natural look
function AddTunnelRoughness(cube, startPoint, endPoint, brushSize)
    local direction = {
        endPoint[1] - startPoint[1],
        endPoint[2] - startPoint[2],
        endPoint[3] - startPoint[3]
    }
    
    local length = math.sqrt(direction[1]^2 + direction[2]^2 + direction[3]^2)
    
    if length > 0 then
        direction[1] = direction[1] / length
        direction[2] = direction[2] / length
        direction[3] = direction[3] / length
    end
    
    -- Find perpendicular vectors to create roughness in all directions
    local perpA, perpB
    if math.abs(direction[1]) < 0.9 then
        perpA = { 1, 0, 0 }
    else
        perpA = { 0, 1, 0 }
    end
    
    -- Cross product to get perpendicular vectors
    perpB = {
        direction[2] * perpA[3] - direction[3] * perpA[2],
        direction[3] * perpA[1] - direction[1] * perpA[3],
        direction[1] * perpA[2] - direction[2] * perpA[1]
    }
    
    perpA = {
        direction[2] * perpB[3] - direction[3] * perpB[2],
        direction[3] * perpB[1] - direction[1] * perpB[3],
        direction[1] * perpB[2] - direction[2] * perpB[1]
    }
    
    -- Normalize perpendicular vectors
    local lenA = math.sqrt(perpA[1]^2 + perpA[2]^2 + perpA[3]^2)
    local lenB = math.sqrt(perpB[1]^2 + perpB[2]^2 + perpB[3]^2)
    
    if lenA > 0 then
        perpA[1] = perpA[1] / lenA
        perpA[2] = perpA[2] / lenA
        perpA[3] = perpA[3] / lenA
    end
    
    if lenB > 0 then
        perpB[1] = perpB[1] / lenB
        perpB[2] = perpB[2] / lenB
        perpB[3] = perpB[3] / lenB
    end
    
    -- Add roughness along the path
    local steps = math.ceil(length / (brushSize * 0.8))
    for i = 0, steps do
        local t = i / steps
        local basePos = {
            startPoint[1] + direction[1] * length * t,
            startPoint[2] + direction[2] * length * t,
            startPoint[3] + direction[3] * length * t
        }
        
        -- Add 2-4 roughness points around the main path
        local numPoints = math.random(2, 4)
        for j = 1, numPoints do
            local angle = math.random() * math.pi * 2
            local distance = math.random(brushSize * 0.8, brushSize * 1.5)
            
            local offset = {
                perpA[1] * math.cos(angle) * distance + perpB[1] * math.sin(angle) * distance,
                perpA[2] * math.cos(angle) * distance + perpB[2] * math.sin(angle) * distance,
                perpA[3] * math.cos(angle) * distance + perpB[3] * math.sin(angle) * distance
            }
            
            local roughPos = {
                basePos[1] + offset[1],
                basePos[2] + offset[2],
                basePos[3] + offset[3]
            }
            
            -- Ensure we stay within cube bounds
            local sx, sy, sz = ParseSize(cube.size)
            local halfBrush = math.floor(brushSize / 2)
            roughPos[1] = math.max(halfBrush, math.min(sx - halfBrush, roughPos[1]))
            roughPos[2] = math.max(halfBrush, math.min(sy - halfBrush, roughPos[2]))
            roughPos[3] = math.max(halfBrush, math.min(sz - halfBrush, roughPos[3]))
            
            -- Carve small sphere for roughness
            local smallBrush = math.random(math.floor(brushSize * 0.3), math.floor(brushSize * 0.7))
            SetBrush("sphere", smallBrush, 0)
            DrawShapeBox(cube.shape, 
                roughPos[1] - smallBrush/2, 
                roughPos[2] - smallBrush/2, 
                roughPos[3] - smallBrush/2, 
                roughPos[1] + smallBrush/2, 
                roughPos[2] + smallBrush/2, 
                roughPos[3] + smallBrush/2)
        end
    end
end

-- Create a winding path for more natural tunnel
function CarveWindingPath(cube, startPoint, endPoint, brushSize)
    local direction = {
        endPoint[1] - startPoint[1],
        endPoint[2] - startPoint[2],
        endPoint[3] - startPoint[3]
    }
    
    local length = math.sqrt(direction[1]^2 + direction[2]^2 + direction[3]^2)
    
    if length > 0 then
        direction[1] = direction[1] / length
        direction[2] = direction[2] / length
        direction[3] = direction[3] / length
    end
    
    -- Find perpendicular vectors for winding
    local perpA, perpB
    if math.abs(direction[1]) < 0.9 then
        perpA = { 1, 0, 0 }
    else
        perpA = { 0, 1, 0 }
    end
    
    -- Cross product to get perpendicular vectors
    perpB = {
        direction[2] * perpA[3] - direction[3] * perpA[2],
        direction[3] * perpA[1] - direction[1] * perpA[3],
        direction[1] * perpA[2] - direction[2] * perpA[1]
    }
    
    -- Normalize perpendicular vectors
    local lenB = math.sqrt(perpB[1]^2 + perpB[2]^2 + perpB[3]^2)
    if lenB > 0 then
        perpB[1] = perpB[1] / lenB
        perpB[2] = perpB[2] / lenB
        perpB[3] = perpB[3] / lenB
    end
    
    -- Create a winding path with sine wave
    local steps = math.ceil(length / (brushSize * 0.4))
    local amplitude = math.random(brushSize * 0.8, brushSize * 2)
    local frequency = math.random(1, 3)
    
    for i = 0, steps do
        local t = i / steps
        -- Base position along the direct path
        local basePos = {
            startPoint[1] + direction[1] * length * t,
            startPoint[2] + direction[2] * length * t,
            startPoint[3] + direction[3] * length * t
        }
        
        -- Add sine wave offset for winding
        local offset = math.sin(t * math.pi * frequency) * amplitude
        local windPos = {
            basePos[1] + perpB[1] * offset,
            basePos[2] + perpB[2] * offset,
            basePos[3] + perpB[3] * offset
        }
        
        -- Ensure we stay within cube bounds
        local sx, sy, sz = ParseSize(cube.size)
        local halfBrush = math.floor(brushSize / 2)
        windPos[1] = math.max(halfBrush, math.min(sx - halfBrush, windPos[1]))
        windPos[2] = math.max(halfBrush, math.min(sy - halfBrush, windPos[2]))
        windPos[3] = math.max(halfBrush, math.min(sz - halfBrush, windPos[3]))
        
        -- Carve sphere at this position
        SetBrush("sphere", brushSize, 0)
        DrawShapeBox(cube.shape, 
            windPos[1] - halfBrush, 
            windPos[2] - halfBrush, 
            windPos[3] - halfBrush, 
            windPos[1] + halfBrush, 
            windPos[2] + halfBrush, 
            windPos[3] + halfBrush)
    end
end

-- Create side pockets along the tunnel
function CarveSidePockets(cube, startPoint, endPoint, brushSize)
    local direction = {
        endPoint[1] - startPoint[1],
        endPoint[2] - startPoint[2],
        endPoint[3] - startPoint[3]
    }
    
    local length = math.sqrt(direction[1]^2 + direction[2]^2 + direction[3]^2)
    
    if length > 0 then
        direction[1] = direction[1] / length
        direction[2] = direction[2] / length
        direction[3] = direction[3] / length
    end
    
    -- Find perpendicular vectors for side pockets
    local perpA, perpB
    if math.abs(direction[1]) < 0.9 then
        perpA = { 1, 0, 0 }
    else
        perpA = { 0, 1, 0 }
    end
    
    -- Cross product to get perpendicular vectors
    perpB = {
        direction[2] * perpA[3] - direction[3] * perpA[2],
        direction[3] * perpA[1] - direction[1] * perpA[3],
        direction[1] * perpA[2] - direction[2] * perpA[1]
    }
    
    perpA = {
        direction[2] * perpB[3] - direction[3] * perpB[2],
        direction[3] * perpB[1] - direction[1] * perpB[3],
        direction[1] * perpB[2] - direction[2] * perpB[1]
    }
    
    -- Normalize perpendicular vectors
    local lenA = math.sqrt(perpA[1]^2 + perpA[2]^2 + perpA[3]^2)
    local lenB = math.sqrt(perpB[1]^2 + perpB[2]^2 + perpB[3]^2)
    
    if lenA > 0 then
        perpA[1] = perpA[1] / lenA
        perpA[2] = perpA[2] / lenA
        perpA[3] = perpA[3] / lenA
    end
    
    if lenB > 0 then
        perpB[1] = perpB[1] / lenB
        perpB[2] = perpB[2] / lenB
        perpB[3] = perpB[3] / lenB
    end
    
    -- Create 2-4 side pockets
    local numPockets = math.random(2, 4)
    for i = 1, numPockets do
        -- Position along the main path
        local t = math.random() * 0.8 + 0.1  -- Avoid ends of the path
        local basePos = {
            startPoint[1] + direction[1] * length * t,
            startPoint[2] + direction[2] * length * t,
            startPoint[3] + direction[3] * length * t
        }
        
        -- Choose a random direction for the pocket
        local angle = math.random() * math.pi * 2
        local pocketDir = {
            perpA[1] * math.cos(angle) + perpB[1] * math.sin(angle),
            perpA[2] * math.cos(angle) + perpB[2] * math.sin(angle),
            perpA[3] * math.cos(angle) + perpB[3] * math.sin(angle)
        }
        
        -- Create a small pocket chamber
        local pocketLength = math.random(brushSize * 2, brushSize * 4)
        local pocketSteps = math.ceil(pocketLength / (brushSize * 0.5))
        local pocketSize = math.random(brushSize, brushSize * 1.5)
        
        for j = 0, pocketSteps do
            local pt = j / pocketSteps
            local pocketPos = {
                basePos[1] + pocketDir[1] * pocketLength * pt,
                basePos[2] + pocketDir[2] * pocketLength * pt,
                basePos[3] + pocketDir[3] * pocketLength * pt
            }
            
            -- Add some variation
            if j > 0 and j < pocketSteps then
                pocketPos[1] = pocketPos[1] + math.random(-2, 2)
                pocketPos[2] = pocketPos[2] + math.random(-2, 2)
                pocketPos[3] = pocketPos[3] + math.random(-2, 2)
            end
            
            -- Ensure we stay within cube bounds
            local sx, sy, sz = ParseSize(cube.size)
            local halfPocket = math.floor(pocketSize / 2)
            pocketPos[1] = math.max(halfPocket, math.min(sx - halfPocket, pocketPos[1]))
            pocketPos[2] = math.max(halfPocket, math.min(sy - halfPocket, pocketPos[2]))
            pocketPos[3] = math.max(halfPocket, math.min(sz - halfPocket, pocketPos[3]))
            
            -- Carve sphere for pocket
            SetBrush("sphere", pocketSize, 0)
            DrawShapeBox(cube.shape, 
                pocketPos[1] - halfPocket, 
                pocketPos[2] - halfPocket, 
                pocketPos[3] - halfPocket, 
                pocketPos[1] + halfPocket, 
                pocketPos[2] + halfPocket, 
                pocketPos[3] + halfPocket)
        end
        
        -- Add a small chamber at the end of the pocket
        if math.random() < 0.7 then
            local chamberSize = math.random(pocketSize * 1.2, pocketSize * 2)
            local chamberPos = {
                basePos[1] + pocketDir[1] * pocketLength,
                basePos[2] + pocketDir[2] * pocketLength,
                basePos[3] + pocketDir[3] * pocketLength
            }
            
            -- Ensure chamber is within bounds
            local sx, sy, sz = ParseSize(cube.size)
            local halfChamber = math.floor(chamberSize / 2)
            chamberPos[1] = math.max(halfChamber, math.min(sx - halfChamber, chamberPos[1]))
            chamberPos[2] = math.max(halfChamber, math.min(sy - halfChamber, chamberPos[2]))
            chamberPos[3] = math.max(halfChamber, math.min(sz - halfChamber, chamberPos[3]))
            
            -- Carve chamber
            SetBrush("sphere", chamberSize, 0)
            DrawShapeBox(cube.shape, 
                chamberPos[1] - halfChamber, 
                chamberPos[2] - halfChamber, 
                chamberPos[3] - halfChamber, 
                chamberPos[1] + halfChamber, 
                chamberPos[2] + halfChamber, 
                chamberPos[3] + halfChamber)
        end
    end
end

-- Create height variations in the tunnel
function CarveHeightVariations(cube, startPoint, endPoint, brushSize)
    local direction = {
        endPoint[1] - startPoint[1],
        endPoint[2] - startPoint[2],
        endPoint[3] - startPoint[3]
    }
    
    local length = math.sqrt(direction[1]^2 + direction[2]^2 + direction[3]^2)
    
    if length > 0 then
        direction[1] = direction[1] / length
        direction[2] = direction[2] / length
        direction[3] = direction[3] / length
    end
    
    -- Create a path with vertical variations
    local steps = math.ceil(length / (brushSize * 0.4))
    local verticalAmplitude = math.random(brushSize * 0.8, brushSize * 2)
    
    -- Create a series of points with varying heights
    local points = {}
    for i = 0, steps do
        local t = i / steps
        local basePos = {
            startPoint[1] + direction[1] * length * t,
            startPoint[2] + direction[2] * length * t,
            startPoint[3] + direction[3] * length * t
        }
        
        -- Add vertical variation
        -- Use perlin-like noise for smoother transitions
        local vertOffset = math.sin(t * math.pi * 2) * verticalAmplitude
        basePos[2] = basePos[2] + vertOffset
        
        -- Ensure we stay within cube bounds
        local sx, sy, sz = ParseSize(cube.size)
        local halfBrush = math.floor(brushSize / 2)
        basePos[1] = math.max(halfBrush, math.min(sx - halfBrush, basePos[1]))
        basePos[2] = math.max(halfBrush, math.min(sy - halfBrush, basePos[2]))
        basePos[3] = math.max(halfBrush, math.min(sz - halfBrush, basePos[3]))
        
        table.insert(points, basePos)
    end
    
    -- Carve along the path
    for i = 1, #points do
        local pos = points[i]
        local halfBrush = math.floor(brushSize / 2)
        
        -- Vary brush size slightly for more natural look
        local variedBrush = brushSize * (0.8 + math.random() * 0.4)
        halfBrush = math.floor(variedBrush / 2)
        
        SetBrush("sphere", variedBrush, 0)
        DrawShapeBox(cube.shape, 
            pos[1] - halfBrush, 
            pos[2] - halfBrush, 
            pos[3] - halfBrush, 
            pos[1] + halfBrush, 
            pos[2] + halfBrush, 
            pos[3] + halfBrush)
    end
    
    -- Add some stalactites/stalagmites
    if math.random() < 0.7 then
        local numFormations = math.random(2, 5)
        for i = 1, numFormations do
            -- Choose a random point along the path
            local pointIndex = math.random(1, #points)
            local basePos = points[pointIndex]
            
            -- Create either stalactite (from ceiling) or stalagmite (from floor)
            local isFromCeiling = math.random() < 0.5
            local formationDir = isFromCeiling and -1 or 1
            local formationLength = math.random(brushSize * 1.5, brushSize * 3)
            local formationSteps = math.ceil(formationLength / (brushSize * 0.3))
            
            -- Base position is offset vertically
            local formationBase = {
                basePos[1],
                basePos[2] + (isFromCeiling and brushSize or -brushSize),
                basePos[3]
            }
            
            -- Create the formation
            for j = 0, formationSteps do
                local ft = j / formationSteps
                local formationSize = brushSize * (1.0 - ft * 0.8)  -- Taper the formation
                local formationPos = {
                    formationBase[1] + math.random(-2, 2) * ft,  -- Add slight wobble
                    formationBase[2] + formationDir * formationLength * ft,
                    formationBase[3] + math.random(-2, 2) * ft   -- Add slight wobble
                }
                
                -- Ensure we stay within cube bounds
                local sx, sy, sz = ParseSize(cube.size)
                local halfFormation = math.floor(formationSize / 2)
                formationPos[1] = math.max(halfFormation, math.min(sx - halfFormation, formationPos[1]))
                formationPos[2] = math.max(halfFormation, math.min(sy - halfFormation, formationPos[2]))
                formationPos[3] = math.max(halfFormation, math.min(sz - halfFormation, formationPos[3]))
                
                -- Carve sphere for formation
                SetBrush("sphere", formationSize, 0)
                DrawShapeBox(cube.shape, 
                    formationPos[1] - halfFormation, 
                    formationPos[2] - halfFormation, 
                    formationPos[3] - halfFormation, 
                    formationPos[1] + halfFormation, 
                    formationPos[2] + halfFormation, 
                    formationPos[3] + halfFormation)
            end
        end
    end
end

-----------------------------------------------------
-- Carve Interior Features in a Cube
-----------------------------------------------------

------------------------------------------------------------------
-- Обновлённые функции для глубокого вырезания входа в кубе
--
-- Для куба с именем "entrance" теперь проход вырезается не только на 
-- верхней грани, но и проникает глубже во внутреннее пространство куба.
------------------------------------------------------------------

-- Функция обновлённой выемки внутренних особенностей куба.
function CarveInteriorFeatures(cube)
    local sx, sy, sz = ParseSize(cube.size)
    local center = { sx / 2, sy / 2, sz / 2 }
    
    -- Если куб является входным, вызываем CarveWindingPassage с флагом isEntrance = true.
    if cube.name == "entrance" then
        -- Вызываем выемку с глубоким проходом.
        CarveWindingPassage(cube, center, true)
        DebugLog("Entrance cube carved with deep through passage on top face.")
        return
    end
    
    -- Для остальных кубов выбираем тип внутренней структуры случайным образом.
    local featureType = ChooseCaveFeature()
    table.insert(cube.features, featureType)
    
    if featureType == "chamber" then
        CarveChamber(cube, center)
    elseif featureType == "corridor" then
        CarveCorridorSystem(cube, center)
    elseif featureType == "vertical_shaft" then
        CarveVerticalShaft(cube, center)
    else  -- winding_passage
        CarveWindingPassage(cube, center, false)
    end
    
    DebugLog("Carved '" .. featureType .. "' in cube '" .. cube.name .. "'.")
end

------------------------------------------------------------------
-- Обновлённое вырезание входа в пещеру
--
-- Изменения:
-- 1. Уменьшен размер расщелины: вместо brushSize 40 используется 30, глубина уменьшается до 30.
-- 2. Стили входа выбираются с большей вероятностью для "расщелины".
-- 3. Если вход всё-таки не вырезан (вызов функции происходит с isEntrance = true),
--    выбирается стиль "crevice" с гарантированной отрисовкой.
------------------------------------------------------------------

-- Обновлённая helper-функция для вырезания расщелины (crevice) меньшего размера.
function CarveEntranceCrevice(cube, center, brushSize, depth)
    local sx, sy, sz = ParseSize(cube.size)
    local halfBrush = math.floor(brushSize / 2)
    -- Начальная точка: немного ниже верхней границы для аккуратного входа.
    local startPoint = { center[1], sy - halfBrush, center[3] }
    local endPoint = { center[1], math.max(0, startPoint[2] - depth), center[3] }
    local length = depth
    -- Уменьшенное количество шагов для более компактной расщелины.
    local steps = math.ceil(length / (brushSize * 0.4))
    
    for i = 0, steps do
        local t = i / steps
        local baseY = startPoint[2] - length * t
        local baseX = startPoint[1]
        local baseZ = startPoint[3]
        -- Добавляем менее выраженные горизонтальные отклонения.
        local offsetX = (math.random() - 0.5) * brushSize * 0.4
        local offsetZ = (math.random() - 0.5) * brushSize * 0.4
        local pos = { baseX + offsetX, baseY, baseZ + offsetZ }
        
        -- Гарантируем, что сферы не выходят за границы куба по X и Z.
        pos[1] = math.max(halfBrush, math.min(sx - halfBrush, pos[1]))
        pos[3] = math.max(halfBrush, math.min(sz - halfBrush, pos[3]))
        -- По оси Y только минимальная проверка.
        pos[2] = math.max(halfBrush, pos[2])
        
        local variedSize = brushSize * (0.9 + math.random() * 0.2)  -- Проявляем небольшое варьирование.
        local halfSize = math.floor(variedSize / 2)
        SetBrush("sphere", variedSize, 0)
        DrawShapeBox(cube.shape,
            pos[1] - halfSize, pos[2] - halfSize, pos[3] - halfSize,
            pos[1] + halfSize, pos[2] + halfSize, pos[3] + halfSize)
    end
    DebugLog("Entrance crevice carved from top with brush size " .. brushSize .. " and depth " .. depth)
end

-- Обновлённая функция CarveWindingPassage.
-- Если cube является входным (isEntrance == true), метод выбора стиля производится так,
-- чтобы с высокой вероятностью выбрался стиль "crevice" (с меньшим размером расщелины).
function CarveWindingPassage(cube, center, isEntrance)
    local sx, sy, sz = ParseSize(cube.size)

    if isEntrance then
        -- Используем меньшие параметры для входа.
        local passageBrush = 30         -- Уменьшенный размер кисти для входа.
        local depth = 30                -- Уменьшенная глубина.
        -- Вероятность выбора стиля "crevice" повышена.
        local entranceStyle = math.random() < 0.8 and "crevice" or "standard"

        if entranceStyle == "crevice" then
            CarveEntranceCrevice(cube, center, passageBrush, depth)
            -- Дополнительно: можно добавить небольшие боковые вырезы для естественности.
            local numSideCuts = math.random(1, 2)
            for i = 1, numSideCuts do
                local offsetX = (math.random() - 0.5) * passageBrush * 0.5
                local offsetZ = (math.random() - 0.5) * passageBrush * 0.5
                local cutBrush = math.floor(passageBrush * (0.6 + math.random() * 0.2))
                local cutStart = { center[1] + offsetX, sy - math.floor(cutBrush / 2), center[3] + offsetZ }
                local cutEndY = math.max(0, cutStart[2] - depth * (0.6 + math.random() * 0.3))
                local cutEnd = { cutStart[1], cutEndY, cutStart[3] }
                CarvePathInCube(cube, cutStart, cutEnd, cutBrush)
            end
            DebugLog("Entrance carved using crevice style (smaller crevice).")
        else
            -- Стандартный стиль.
            local startPoint = { center[1], sy, center[3] }
            local endY = math.max(0, startPoint[2] - depth)
            local endPoint = { center[1], endY, center[3] }
            CarveEntrancePathInCube(cube, startPoint, endPoint, passageBrush)
            DebugLog("Entrance carved using standard style.")
        end

        -- Добавляем небольшие камеры вдоль входа.
        local numChambers = math.random(1, 2)
        for i = 1, numChambers do
            local t = math.random()
            local chamberPos = { center[1], sy - depth * t, center[3] }
            local chamberSize = math.max(15, math.random(15, 25))
            local halfChamber = math.floor(chamberSize / 2)
            chamberPos[1] = math.max(halfChamber, math.min(sx - halfChamber, chamberPos[1]))
            chamberPos[2] = math.max(halfChamber, math.min(sy - halfChamber, chamberPos[2]))
            chamberPos[3] = math.max(halfChamber, math.min(sz - halfChamber, chamberPos[3]))
            
            SetBrush("sphere", chamberSize, 0)
            DrawShapeBox(cube.shape,
                chamberPos[1] - halfChamber,
                chamberPos[2] - halfChamber,
                chamberPos[3] - halfChamber,
                chamberPos[1] + halfChamber,
                chamberPos[2] + halfChamber,
                chamberPos[3] + halfChamber)
        end
        
        return
    end

    -- Для не входных кубов используется оригинальная логика случайных вырезок.
    local basePassageSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
    local passageSize = basePassageSize
    local startPoint, endPoint
    local axis = math.random(1, 3)
    local startFace = math.random(0, 1)
    local endFace = 1 - startFace
    startPoint = { center[1], center[2], center[3] }
    endPoint = { center[1], center[2], center[3] }
    
    if axis == 1 then
        startPoint[1] = startFace * sx
        endPoint[1] = endFace * sx
        startPoint[2] = math.random(passageSize, sy - passageSize)
        startPoint[3] = math.random(passageSize, sz - passageSize)
        endPoint[2] = math.random(passageSize, sy - passageSize)
        endPoint[3] = math.random(passageSize, sz - passageSize)
    elseif axis == 2 then
        startPoint[2] = startFace * sy
        endPoint[2] = endFace * sy
        startPoint[1] = math.random(passageSize, sx - passageSize)
        startPoint[3] = math.random(passageSize, sz - passageSize)
        endPoint[1] = math.random(passageSize, sx - passageSize)
        endPoint[3] = math.random(passageSize, sz - passageSize)
    else
        startPoint[3] = startFace * sz
        endPoint[3] = endFace * sz
        startPoint[1] = math.random(passageSize, sx - passageSize)
        startPoint[2] = math.random(passageSize, sy - passageSize)
        endPoint[1] = math.random(passageSize, sx - passageSize)
        endPoint[2] = math.random(passageSize, sy - passageSize)
    end

    local controlPoints = {}
    local numControlPoints = math.random(3, 5)
    table.insert(controlPoints, startPoint)
    for i = 1, numControlPoints do
        local t = i / (numControlPoints + 1)
        local basePos = {
            startPoint[1] * (1 - t) + endPoint[1] * t,
            startPoint[2] * (1 - t) + endPoint[2] * t,
            startPoint[3] * (1 - t) + endPoint[3] * t
        }
        local maxOffset = math.min(sx, sy, sz) * 0.2
        local offset = {
            math.random(-maxOffset, maxOffset),
            math.random(-maxOffset, maxOffset),
            math.random(-maxOffset, maxOffset)
        }
        basePos[1] = basePos[1] + offset[1]
        basePos[2] = basePos[2] + offset[2]
        basePos[3] = basePos[3] + offset[3]
        basePos[1] = math.max(passageSize, math.min(sx - passageSize, basePos[1]))
        basePos[2] = math.max(passageSize, math.min(sy - passageSize, basePos[2]))
        basePos[3] = math.max(passageSize, math.min(sz - passageSize, basePos[3]))
        table.insert(controlPoints, basePos)
    end
    table.insert(controlPoints, endPoint)

    local numSegments = 20 * (#controlPoints - 1)
    local function catmullRom(p0, p1, p2, p3, t)
        local t2 = t * t
        local t3 = t2 * t
        local a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
        local b = p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3
        local c = -0.5 * p0 + 0.5 * p2
        local d = p1
        return a * t3 + b * t2 + c * t + d
    end

    for i = 1, #controlPoints - 3 do
        for j = 0, math.floor(numSegments / (#controlPoints - 3)) do
            local t = j / (numSegments / (#controlPoints - 3))
            local p0 = controlPoints[i]
            local p1 = controlPoints[i + 1]
            local p2 = controlPoints[i + 2]
            local p3 = controlPoints[i + 3]
            local pos = {
                catmullRom(p0[1], p1[1], p2[1], p3[1], t),
                catmullRom(p0[2], p1[2], p2[2], p3[2], t),
                catmullRom(p0[3], p1[3], p2[3], p3[3], t)
            }
            local halfPassage = math.floor(passageSize / 2)
            pos[1] = math.max(halfPassage, math.min(sx - halfPassage, pos[1]))
            pos[2] = math.max(halfPassage, math.min(sy - halfPassage, pos[2]))
            pos[3] = math.max(halfPassage, math.min(sz - halfPassage, pos[3]))
            local variedSize = passageSize * (0.8 + math.random() * 0.4)
            local halfSize = math.floor(variedSize / 2)
            SetBrush("sphere", variedSize, 0)
            DrawShapeBox(cube.shape,
                pos[1] - halfSize, pos[2] - halfSize, pos[3] - halfSize,
                pos[1] + halfSize, pos[2] + halfSize, pos[3] + halfSize)
        end
    end

    local numChambers = math.random(1, 3)
    for i = 1, numChambers do
        local pointIndex = math.random(2, #controlPoints - 1)
        local chamberPos = controlPoints[pointIndex]
        local chamberSize = math.random(passageSize * 1.2, passageSize * 2)
        local halfChamber = math.floor(chamberSize / 2)
        chamberPos[1] = math.max(halfChamber, math.min(sx - halfChamber, chamberPos[1]))
        chamberPos[2] = math.max(halfChamber, math.min(sy - halfChamber, chamberPos[2]))
        chamberPos[3] = math.max(halfChamber, math.min(sz - halfChamber, chamberPos[3]))
        SetBrush("sphere", chamberSize, 0)
        DrawShapeBox(cube.shape,
            chamberPos[1] - halfChamber, chamberPos[2] - halfChamber, chamberPos[3] - halfChamber,
            chamberPos[1] + halfChamber, chamberPos[2] + halfChamber, chamberPos[3] + halfChamber)
    end
end
function CarveChamber(cube, center)
    -- Create a large central chamber
    local chamberSize = math.random(LARGE_BRUSH_MIN, LARGE_BRUSH_MAX)
    SetBrush("sphere", chamberSize, 0)
    DrawShapeBox(cube.shape, 
        center[1] - chamberSize/2, 
        center[2] - chamberSize/2, 
        center[3] - chamberSize/2, 
        center[1] + chamberSize/2, 
        center[2] + chamberSize/2, 
        center[3] + chamberSize/2)
    
    -- Add some smaller chambers around the main one
    local numSmallChambers = math.random(3, 6)
    for i = 1, numSmallChambers do
        -- Random direction from center
        local angle1 = math.random() * math.pi * 2
        local angle2 = math.random() * math.pi
        local distance = math.random(chamberSize * 0.6, chamberSize * 1.2)
        
        local smallChamberPos = {
            center[1] + math.cos(angle1) * math.sin(angle2) * distance,
            center[2] + math.sin(angle1) * math.sin(angle2) * distance,
            center[3] + math.cos(angle2) * distance
        }
        
        -- Ensure we stay within cube bounds
        local sx, sy, sz = ParseSize(cube.size)
        local smallChamberSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
        local halfSmall = math.floor(smallChamberSize / 2)
        smallChamberPos[1] = math.max(halfSmall, math.min(sx - halfSmall, smallChamberPos[1]))
        smallChamberPos[2] = math.max(halfSmall, math.min(sy - halfSmall, smallChamberPos[2]))
        smallChamberPos[3] = math.max(halfSmall, math.min(sz - halfSmall, smallChamberPos[3]))
        
        -- Carve small chamber
        SetBrush("sphere", smallChamberSize, 0)
        DrawShapeBox(cube.shape, 
            smallChamberPos[1] - halfSmall, 
            smallChamberPos[2] - halfSmall, 
            smallChamberPos[3] - halfSmall, 
            smallChamberPos[1] + halfSmall, 
            smallChamberPos[2] + halfSmall, 
            smallChamberPos[3] + halfSmall)
        
        -- Connect small chamber to main chamber
        CarvePathInCube(cube, center, smallChamberPos, SMALL_BRUSH_MIN)
    end
    
    -- Add some stalactites/stalagmites for detail
    local numFormations = math.random(5, 10)
    for i = 1, numFormations do
        -- Random position within the chamber
        local angle1 = math.random() * math.pi * 2
        local angle2 = math.random() * math.pi
        local distance = math.random(chamberSize * 0.3, chamberSize * 0.7)
        
        local formationBase = {
            center[1] + math.cos(angle1) * math.sin(angle2) * distance,
            center[2] + math.sin(angle1) * math.sin(angle2) * distance,
            center[3] + math.cos(angle2) * distance
        }
        
        -- Determine if it's a stalactite or stalagmite
        local isFromCeiling = math.random() < 0.5
        local formationDir = isFromCeiling and -1 or 1
        local formationLength = math.random(SMALL_BRUSH_MIN, SMALL_BRUSH_MAX)
        local formationSteps = math.ceil(formationLength / 2)
        
        -- Create the formation
        for j = 0, formationSteps do
            local ft = j / formationSteps
            local formationSize = SMALL_BRUSH_MIN * (1.0 - ft * 0.8)  -- Taper the formation
            local formationPos = {
                formationBase[1] + math.random(-1, 1) * ft,
                formationBase[2] + formationDir * formationLength * ft,
                formationBase[3] + math.random(-1, 1) * ft
            }
            
            -- Ensure we stay within cube bounds
            local sx, sy, sz = ParseSize(cube.size)
            local halfFormation = math.floor(formationSize / 2)
            formationPos[1] = math.max(halfFormation, math.min(sx - halfFormation, formationPos[1]))
            formationPos[2] = math.max(halfFormation, math.min(sy - halfFormation, formationPos[2]))
            formationPos[3] = math.max(halfFormation, math.min(sz - halfFormation, formationPos[3]))
            
            -- Carve sphere for formation
            SetBrush("sphere", formationSize, 0)
            DrawShapeBox(cube.shape, 
                formationPos[1] - halfFormation, 
                formationPos[2] - halfFormation, 
                formationPos[3] - halfFormation, 
                formationPos[1] + halfFormation, 
                formationPos[2] + halfFormation, 
                formationPos[3] + halfFormation)
        end
    end
end

-- Carve a corridor system in the cube
function CarveCorridorSystem(cube, center)
    local sx, sy, sz = ParseSize(cube.size)
    
    -- Create a network of corridors
    local numCorridors = math.random(3, 6)
    local corridorPoints = {}
    
    -- Start with the center point
    table.insert(corridorPoints, center)
    
    -- Create random corridor endpoints
    for i = 1, numCorridors do
        local angle1 = math.random() * math.pi * 2
        local angle2 = math.random() * math.pi
        local distance = math.random(sx * 0.3, sx * 0.45)  -- Use cube size to scale
        
        local corridorEnd = {
            center[1] + math.cos(angle1) * math.sin(angle2) * distance,
            center[2] + math.sin(angle1) * math.sin(angle2) * distance,
            center[3] + math.cos(angle2) * distance
        }
        
        -- Ensure we stay within cube bounds
        local corridorSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
        local halfCorridor = math.floor(corridorSize / 2)
        corridorEnd[1] = math.max(halfCorridor, math.min(sx - halfCorridor, corridorEnd[1]))
        corridorEnd[2] = math.max(halfCorridor, math.min(sy - halfCorridor, corridorEnd[2]))
        corridorEnd[3] = math.max(halfCorridor, math.min(sz - halfCorridor, corridorEnd[3]))
        
        table.insert(corridorPoints, corridorEnd)
    end
    
    -- Connect all points to form a corridor network
    for i = 2, #corridorPoints do
        local startPoint = corridorPoints[1]  -- Connect from center
        local endPoint = corridorPoints[i]
        
        -- Determine corridor type
        local corridorType = math.random(1, 4)
        local corridorSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
        
        if corridorType == 1 then
            -- Straight corridor
            CarvePathInCube(cube, startPoint, endPoint, corridorSize)
        elseif corridorType == 2 then
            -- Winding corridor
            CarveWindingPath(cube, startPoint, endPoint, corridorSize)
        elseif corridorType == 3 then
            -- Corridor with side pockets
            CarvePathInCube(cube, startPoint, endPoint, corridorSize)
            CarveSidePockets(cube, startPoint, endPoint, math.floor(corridorSize * 0.7))
        else
            -- Corridor with height variations
            CarveHeightVariations(cube, startPoint, endPoint, corridorSize)
        end
    end
    
    -- Add some small chambers at corridor endpoints
    for i = 2, #corridorPoints do
        if math.random() < 0.7 then
            local chamberSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
            local halfChamber = math.floor(chamberSize / 2)
            
            -- Carve chamber at endpoint
            SetBrush("sphere", chamberSize, 0)
            DrawShapeBox(cube.shape, 
                corridorPoints[i][1] - halfChamber, 
                corridorPoints[i][2] - halfChamber, 
                corridorPoints[i][3] - halfChamber, 
                corridorPoints[i][1] + halfChamber, 
                corridorPoints[i][2] + halfChamber, 
                corridorPoints[i][3] + halfChamber)
        end
    end
    
    -- Add some intersections between corridors for more interesting network
    if numCorridors > 3 then
        local numIntersections = math.random(1, math.floor(numCorridors / 2))
        for i = 1, numIntersections do
            -- Choose two random corridors to connect
            local idx1 = math.random(2, #corridorPoints)
            local idx2 = idx1
            while idx2 == idx1 do
                idx2 = math.random(2, #corridorPoints)
            end
            
            -- Connect these two endpoints
            local corridorSize = math.random(SMALL_BRUSH_MIN, MEDIUM_BRUSH_MIN)
            CarvePathInCube(cube, corridorPoints[idx1], corridorPoints[idx2], corridorSize)
        end
    end
end

-- Carve a vertical shaft in the cube
function CarveVerticalShaft(cube, center)
    local sx, sy, sz = ParseSize(cube.size)
    
    -- Create a vertical shaft
    local shaftRadius = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
    local shaftHeight = math.random(sy * 0.7, sy * 0.9)  -- Most of the cube height
    
    -- Determine shaft bottom position
    local shaftBottom = {
        center[1],
        center[2] - shaftHeight/2,  -- Center the shaft vertically
        center[3]
    }
    
    -- Ensure shaft bottom is within cube bounds
    shaftBottom[2] = math.max(shaftRadius, shaftBottom[2])
    
    -- Carve the main shaft
    local steps = math.ceil(shaftHeight / (shaftRadius * 0.5))
    for i = 0, steps do
        local t = i / steps
        local pos = {
            shaftBottom[1] + math.random(-3, 3) * t,  -- Add slight wobble
            shaftBottom[2] + shaftHeight * t,
            shaftBottom[3] + math.random(-3, 3) * t   -- Add slight wobble
        }
        
        -- Vary shaft radius slightly for more natural look
        local variedRadius = shaftRadius * (0.8 + math.random() * 0.4)
        
        -- Carve sphere at this position
        SetBrush("sphere", variedRadius, 0)
        DrawShapeBox(cube.shape, 
            pos[1] - variedRadius/2, 
            pos[2] - variedRadius/2, 
            pos[3] - variedRadius/2, 
            pos[1] + variedRadius/2, 
            pos[2] + variedRadius/2, 
            pos[3] + variedRadius/2)
    end
    
    -- Add ledges along the shaft
    local numLedges = math.random(2, 4)
    for i = 1, numLedges do
        -- Position along the shaft
        local ledgeHeight = shaftBottom[2] + shaftHeight * (i / (numLedges + 1))
        
        -- Random direction for the ledge
        local angle = math.random() * math.pi * 2
        local ledgeDir = {
            math.cos(angle),
            0,  -- Horizontal ledge
            math.sin(angle)
        }
        
        -- Create the ledge
        local ledgeLength = math.random(shaftRadius * 1.2, shaftRadius * 2.5)
        local ledgeWidth = math.random(SMALL_BRUSH_MIN, MEDIUM_BRUSH_MIN)
        local ledgeSteps = math.ceil(ledgeLength / (ledgeWidth * 0.5))
        
        for j = 0, ledgeSteps do
            local lt = j / ledgeSteps
            local ledgePos = {
                center[1] + ledgeDir[1] * ledgeLength * lt,
                ledgeHeight,
                center[3] + ledgeDir[3] * ledgeLength * lt
            }
            
            -- Ensure ledge is within cube bounds
            local halfLedge = math.floor(ledgeWidth / 2)
            ledgePos[1] = math.max(halfLedge, math.min(sx - halfLedge, ledgePos[1]))
            ledgePos[3] = math.max(halfLedge, math.min(sz - halfLedge, ledgePos[3]))
            
            -- Carve sphere for ledge
            SetBrush("sphere", ledgeWidth, 0)
            DrawShapeBox(cube.shape, 
                ledgePos[1] - halfLedge, 
                ledgePos[2] - halfLedge, 
                ledgePos[3] - halfLedge, 
                ledgePos[1] + halfLedge, 
                ledgePos[2] + halfLedge, 
                ledgePos[3] + halfLedge)
        end
        
        -- Add a small chamber at the end of some ledges
        if math.random() < 0.6 then
            local chamberSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
            local chamberPos = {
                center[1] + ledgeDir[1] * ledgeLength,
                ledgeHeight,
                center[3] + ledgeDir[3] * ledgeLength
            }
            
            -- Ensure chamber is within bounds
            local halfChamber = math.floor(chamberSize / 2)
            chamberPos[1] = math.max(halfChamber, math.min(sx - halfChamber, chamberPos[1]))
            chamberPos[3] = math.max(halfChamber, math.min(sz - halfChamber, chamberPos[3]))
            
            -- Carve chamber
            SetBrush("sphere", chamberSize, 0)
            DrawShapeBox(cube.shape, 
                chamberPos[1] - halfChamber, 
                chamberPos[2] - halfChamber, 
                chamberPos[3] - halfChamber, 
                chamberPos[1] + halfChamber, 
                chamberPos[2] + halfChamber, 
                chamberPos[3] + halfChamber)
        end
    end
    
    -- Add some stalactites/stalagmites along the shaft
    local numFormations = math.random(3, 7)
    for i = 1, numFormations do
        -- Random position along the shaft
        local formationHeight = shaftBottom[2] + math.random() * shaftHeight
        
        -- Random direction from shaft center
        local angle = math.random() * math.pi * 2
        local distance = math.random(shaftRadius * 0.3, shaftRadius * 0.8)
        
        local formationBase = {
            center[1] + math.cos(angle) * distance,
            formationHeight,
            center[3] + math.sin(angle) * distance
        }
        
        -- Determine if it's a stalactite or stalagmite
        local isFromCeiling = formationHeight > center[2]
        local formationDir = isFromCeiling and -1 or 1
        local formationLength = math.random(SMALL_BRUSH_MIN, SMALL_BRUSH_MAX)
        local formationSteps = math.ceil(formationLength / 2)
        
        -- Create the formation
        for j = 0, formationSteps do
            local ft = j / formationSteps
            local formationSize = SMALL_BRUSH_MIN * (1.0 - ft * 0.8)  -- Taper the formation
            local formationPos = {
                formationBase[1] + math.random(-1, 1) * ft,
                formationBase[2] + formationDir * formationLength * ft,
                formationBase[3] + math.random(-1, 1) * ft
            }
            
            -- Ensure we stay within cube bounds
            local halfFormation = math.floor(formationSize / 2)
            formationPos[1] = math.max(halfFormation, math.min(sx - halfFormation, formationPos[1]))
            formationPos[2] = math.max(halfFormation, math.min(sy - halfFormation, formationPos[2]))
            formationPos[3] = math.max(halfFormation, math.min(sz - halfFormation, formationPos[3]))
            
            -- Carve sphere for formation
            SetBrush("sphere", formationSize, 0)
            DrawShapeBox(cube.shape, 
                formationPos[1] - halfFormation, 
                formationPos[2] - halfFormation, 
                formationPos[3] - halfFormation, 
                formationPos[1] + halfFormation, 
                formationPos[2] + halfFormation, 
                formationPos[3] + halfFormation)
        end
    end
end

-----------------------------------------------------
-- Find Adjacent Cubes
-----------------------------------------------------
function FindAdjacentCubes()
    local adjacentPairs = {}
    
    for i = 1, #cubes do
        for j = i+1, #cubes do
            local cubeA = cubes[i]
            local cubeB = cubes[j]
            
            -- Calculate centers
            local centerA = CubeCenter(cubeA.position, cubeA.size)
            local centerB = CubeCenter(cubeB.position, cubeB.size)
            
            -- Calculate vector between centers
            local delta = VecSub(centerB, centerA)
            local distance = VecLength(delta)
            
            -- Determine if cubes are adjacent
            local sx, sy, sz = ParseSize(cubeA.size)
            local requiredOffset = ComputeRequiredOffset(cubeA, cubeB, VecNormalize(delta))
            
            -- Check if distance is approximately equal to the required offset
            if math.abs(distance - requiredOffset) < 1.0 then
                table.insert(adjacentPairs, { cubeA, cubeB })
            end
        end
    end
    
    return adjacentPairs
end

-----------------------------------------------------
-- Main Functions
-----------------------------------------------------
function init()
    DebugLog("Initializing enhanced cave generator...")
    math.randomseed(53242)
    
    -- Generate the cave system
    SpawnCubes()
    
    -- Carve interior features in each cube
    for _, cube in ipairs(cubes) do
        CarveInteriorFeatures(cube)
    end
    
    -- Find adjacent cubes and create tunnels between them
    local adjacentPairs = FindAdjacentCubes()
    for _, pair in ipairs(adjacentPairs) do
        CarveTunnelBetweenTwoCubes(pair[1], pair[2])
    end
    
    DebugLog("Cave generation complete!")
end

function tick(dt)
    -- Optional: Add dynamic elements or effects here
    -- For example, particle effects, water flow, etc.
end

function draw()
    -- Optional: Add debug visualization here
    if DEBUG_MODE then
        for i, cube in ipairs(cubes) do
            local center = CubeCenter(cube.position, cube.size)
            DebugCross(center, 1, 0, 0, 1)
            
            -- Draw lines to adjacent cubes
            local adjacentPairs = FindAdjacentCubes()
            for _, pair in ipairs(adjacentPairs) do
                if pair[1] == cube then
                    local otherCenter = CubeCenter(pair[2].position, pair[2].size)
                    DebugLine(center, otherCenter, 0, 1, 0, 1)
                elseif pair[2] == cube then
                    local otherCenter = CubeCenter(pair[1].position, pair[1].size)
                    DebugLine(center, otherCenter, 0, 1, 0, 1)
                end
            end
        end
    end
end