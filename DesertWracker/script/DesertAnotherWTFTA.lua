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
---ПОЧИНИТЬ ДЫРКИ В КУБАХ, ПОЧИНИТЬ ОДНООБРАЗНОСТЬ, ПОЧИНИТЬ КОРРИДОРНОСТЬ, ПОЧИНИТЬ ВЫХОД С ПЕРВОГО КУБА И 2 КУБА ВНИЗ ВСЕГДА

-- Configuration
local MATERIAL = "concrete"           -- Cube material
local DEBUG_MODE = true           -- Enable debug visualization
local NUM_CUBES = 20              -- Total cubes to spawn (adjustable)
local FIXED_SIZE = "96 96 96"     -- Fixed cube size in world units

-- Brush sizes for different carving operations
local LARGE_BRUSH_MIN = 20        -- Minimum size for large brushes
local LARGE_BRUSH_MAX = 25        -- Maximum size for large brushes
local MEDIUM_BRUSH_MIN = 12       -- Minimum size for medium brushes
local MEDIUM_BRUSH_MAX = 19       -- Maximum size for medium brushes
local SMALL_BRUSH_MIN = 5         -- Minimum size for small brushes
local SMALL_BRUSH_MAX = 11        -- Maximum size for small brushes

-- Direction weights for cube placement (for spawning)
local DIRECTION_WEIGHTS = {
    [Vec(1, 0, 0)] = 19,    -- Right
    [Vec(-1, 0, 0)] = 19,   -- Left
    [Vec(0, 1, 0)] = 0,    -- Up
    [Vec(0, -1, 0)] = 22,   -- Down
    [Vec(0, 0, 1)] = 19,    -- Forward
    [Vec(0, 0, -1)] = 19    -- Back
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
    local entryPos = Vec(20, 30, -50)
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
local function easeInOutQuad(t)
    if t < 0.5 then
        return 2*t*t
    else
        return -1 + (4 - 2*t)*t
    end
end

function CarveTunnelBetweenTwoCubes(cubeA, cubeB)
    -- Вычисляем разницу позиций двух кубов.
    local diff = VecSub(cubeB.position, cubeA.position)
    -- Нормализуем направление по преобладающей оси.
    local absDiff = { math.abs(diff[1]), math.abs(diff[2]), math.abs(diff[3]) }
    local direction = {}
    if absDiff[1] >= absDiff[2] and absDiff[1] >= absDiff[3] then
        direction = { diff[1] > 0 and 1 or -1, 0, 0 }
    elseif absDiff[2] >= absDiff[1] and absDiff[2] >= absDiff[3] then
        direction = { 0, diff[2] > 0 and 1 or -1, 0 }
    else
        direction = { 0, 0, diff[3] > 0 and 1 or -1 }
    end

    -- Вычисляем центры нужных граней в кубах.
    local faceCenterA = GetFaceCenter(cubeA, direction)
    local faceCenterB = GetFaceCenter(cubeB, { -direction[1], -direction[2], -direction[3] })

    -- Добавляем небольшое расширение, чтобы гарантировать вырезание до конца.
    local extraMargin = 2 -- количество вокселей, на которое расширяем вырезание
    local extVector = VecScale(direction, extraMargin)
    local extendedFaceA = VecSub(faceCenterA, extVector)
    local extendedFaceB = VecAdd(faceCenterB, extVector)

    -- Выбираем размер кисти для туннеля.
    local tunnelBrush = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)

    -- Вычисляем промежуточную точку для соединения туннеля.
    local midPoint = VecScale(VecAdd(extendedFaceA, extendedFaceB), 0.5)

    -- В кубе A вырезаем туннель от исходной грани до midPoint без отступа (margin = 0)
    CarvePathInCube(cubeA, VecSub(faceCenterA, cubeA.position), VecSub(midPoint, cubeA.position), tunnelBrush, 0)
    -- В кубе B вырезаем туннель от его грани до midPoint без отступа
    CarvePathInCube(cubeB, VecSub(faceCenterB, cubeB.position), VecSub(midPoint, cubeB.position), tunnelBrush, 0)

    -- Добавляем детальную обработку на стыке (также с margin = 0)
    local detailBrush = math.random(SMALL_BRUSH_MIN, SMALL_BRUSH_MAX)
    AddTunnelRoughness(cubeA, VecSub(faceCenterA, cubeA.position), VecSub(midPoint, cubeA.position), detailBrush)
    AddTunnelRoughness(cubeB, VecSub(faceCenterB, cubeB.position), VecSub(midPoint, cubeB.position), detailBrush)

    DebugLog("Tunnel fully carved between '" .. cubeA.name .. "' and '" .. cubeB.name .. "'.")
end

-- Carve a path in a cube from start to end point with given brush size
function CarvePathInCube(cube, startPoint, endPoint, brushSize, margin)
    margin = margin or 2  -- по умолчанию отступ 2
    local halfBrush = math.floor(brushSize / 2)
    local sx, sy, sz = ParseSize(cube.size)
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
    local steps = math.ceil(length / (brushSize * 0.5))
    for i = 0, steps do
        local t = i / steps
        local pos = {
            startPoint[1] + direction[1] * length * t,
            startPoint[2] + direction[2] * length * t,
            startPoint[3] + direction[3] * length * t
        }
        -- Применяем случайное смещение только если точка не близко к границе (безопасная зона)
        if i > 0 and i < steps then
            for axis = 1, 3 do
                local posVal = pos[axis]
                local minBound, maxBound
                if axis == 1 then
                    minBound, maxBound = halfBrush + margin, sx - halfBrush - margin
                elseif axis == 2 then
                    minBound, maxBound = halfBrush + margin, sy - halfBrush - margin
                else
                    minBound, maxBound = halfBrush + margin, sz - halfBrush - margin
                end
                if posVal > minBound and posVal < maxBound then
                    pos[axis] = pos[axis] + math.random(-1, 1)
                end
            end
        end
        pos[1] = math.max(halfBrush + margin, math.min(sx - halfBrush - margin, pos[1]))
        pos[2] = math.max(halfBrush + margin, math.min(sy - halfBrush - margin, pos[2]))
        pos[3] = math.max(halfBrush + margin, math.min(sz - halfBrush - margin, pos[3]))
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

function CarveInteriorFeatures(cube)
    local sx, sy, sz = ParseSize(cube.size)
    local center = { sx / 2, sy / 2, sz / 2 }
    if cube.name == "entrance" then
        CarveWindingPassage(cube, center, true)
        DebugLog("Entrance cube carved with deep through passage on top face.")
        return
    end
    -- Новая логика: с вероятностью 10% вместо стандартной топологии создаем огромную комнату
    if math.random() < 0.1 then
        CarveHugeRoom(cube, center)
        return
    end
    local featureType = ChooseCaveFeature()
    if featureType == "winding_passage" then
        featureType = "corridor"
    end
    table.insert(cube.features, featureType)
    if featureType == "chamber" then
        CarveChamber(cube, center)
    elseif featureType == "corridor" then
        CarveCorridorSystem(cube, center)
    elseif featureType == "vertical_shaft" then
        CarveVerticalShaft(cube, center)
    end
    DebugLog("Carved '" .. featureType .. "' in cube '" .. cube.name .. "'.")
end

function CarveHugeRoom(cube, center)
    local sx, sy, sz = ParseSize(cube.size)
    local roomSize = math.min(sx, sy, sz) - 4  -- оставляем небольшой отступ от границ
    SetBrush("sphere", roomSize, 0)
    DrawShapeBox(cube.shape, 
        center[1] - roomSize/2, 
        center[2] - roomSize/2, 
        center[3] - roomSize/2, 
        center[1] + roomSize/2, 
        center[2] + roomSize/2, 
        center[3] + roomSize/2)
    DebugLog("Huge room carved in cube '" .. cube.name .. "'.")
end
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

function CarveWindingPassage(cube, center, isEntrance)
    local sx, sy, sz = ParseSize(cube.size)
    if isEntrance then
        local passageBrush = 30
        local depth = 30
        local entranceStyle = math.random() < 0.8 and "crevice" or "standard"
        if entranceStyle == "crevice" then
            CarveEntranceCrevice(cube, center, passageBrush, depth)
            DebugLog("Entrance carved using crevice style (smaller crevice).")
            for i = 1, math.random(1, 2) do
                local offsetX = (math.random() - 0.5) * passageBrush * 0.5
                local offsetZ = (math.random() - 0.5) * passageBrush * 0.5
                local cutBrush = math.floor(passageBrush * (0.6 + math.random() * 0.2))
                local cutStart = { center[1] + offsetX, sy - math.floor(cutBrush / 2), center[3] + offsetZ }
                local cutEndY = math.max(0, cutStart[2] - depth * (0.6 + math.random() * 0.3))
                local cutEnd = { cutStart[1], cutEndY, cutStart[3] }
                CarvePathInCube(cube, cutStart, cutEnd, cutBrush)
            end
            DebugLog("Entrance carved using crevice style.")
            return
        end
    end
    -- Для не-входного куба уменьшаем размеры прохода, чтобы в полах не было больших дыр
    local passageSize = math.random(MEDIUM_BRUSH_MIN, 15)
    local startPoint = { center[1], sy, center[3] }
    local endPoint = { center[1], sy - passageSize, center[3] }
    local numSegments = 20
    for i = 0, numSegments do
        local t = i / numSegments
        local pos = {
            startPoint[1]*(1-t) + endPoint[1]*t,
            startPoint[2]*(1-t) + endPoint[2]*t,
            startPoint[3]*(1-t) + endPoint[3]*t
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
    if math.random() < 0.7 then
        local chamberSize = math.random(passageSize * 1.2, passageSize * 2)
        local chamberPos = { center[1], sy - passageSize, center[3] }
        local halfChamber = math.floor(chamberSize / 2)
        chamberPos[1] = math.max(halfChamber, math.min(sx - halfChamber, chamberPos[1]))
        chamberPos[2] = math.max(halfChamber, math.min(sy - halfChamber, chamberPos[2]))
        chamberPos[3] = math.max(halfChamber, math.min(sz - halfChamber, chamberPos[3]))
        SetBrush("sphere", chamberSize, 0)
        DrawShapeBox(cube.shape,
            chamberPos[1] - halfChamber, chamberPos[2] - halfChamber, chamberPos[3] - halfChamber,
            chamberPos[1] + halfChamber, chamberPos[2] + halfChamber, chamberPos[3] + halfChamber)
    end
    DebugLog("Top-only winding passage carved in cube '" .. cube.name .. "'.")
end

function CarveStalactitesAndStalagmites(cube)
    -- Получаем размеры куба
    local sx, sy, sz = ParseSize(cube.size)
    
    -- Добавляем сталактиты (с потолка)
    local numStalactites = math.random(2, 5)
    for i = 1, numStalactites do
        -- Выбираем случайную позицию по X и Z с некоторым отступом от краёв
        local x = math.random(10, sx - 10)
        local z = math.random(10, sz - 10)
        local brushSize = math.random(5, 10)
        local halfBrush = math.floor(brushSize / 2)
        local startY = sy - halfBrush  -- начало у потолка
        local depth = math.random(brushSize * 2, brushSize * 4)
        local endY = math.max(halfBrush, startY - depth)
        local steps = math.ceil((startY - endY) / (brushSize * 0.5))
        
        for j = 0, steps do
            local t = j / steps
            local currentY = startY - (startY - endY) * t
            -- Добавляем небольшое случайное смещение по X и Z для естественности
            local offsetX = math.random(-1, 1)
            local offsetZ = math.random(-1, 1)
            local currentX = x + offsetX
            local currentZ = z + offsetZ
            SetBrush("sphere", brushSize, 1)
            DrawShapeBox(cube.shape, 
                currentX - halfBrush, currentY - halfBrush, currentZ - halfBrush,
                currentX + halfBrush, currentY + halfBrush, currentZ + halfBrush)
        end
    end

    -- Добавляем сталгмиты (с пола)
    local numStalagmites = math.random(2, 5)
    for i = 1, numStalagmites do
        local x = math.random(10, sx - 10)
        local z = math.random(10, sz - 10)
        local brushSize = math.random(5, 10)
        local halfBrush = math.floor(brushSize / 2)
        local startY = halfBrush  -- начало у пола
        local height = math.random(brushSize * 2, brushSize * 4)
        local endY = math.min(sy - halfBrush, startY + height)
        local steps = math.ceil((endY - startY) / (brushSize * 0.5))
        
        for j = 0, steps do
            local t = j / steps
            local currentY = startY + (endY - startY) * t
            local offsetX = math.random(-1, 1)
            local offsetZ = math.random(-1, 1)
            local currentX = x + offsetX
            local currentZ = z + offsetZ
            SetBrush("sphere", brushSize, 1)
            DrawShapeBox(cube.shape, 
                currentX - halfBrush, currentY - halfBrush, currentZ - halfBrush,
                currentX + halfBrush, currentY + halfBrush, currentZ + halfBrush)
        end
    end

    DebugLog("Stalactites and stalagmites added in cube '" .. cube.name .. "'.")
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
    local numCorridors = math.random(1, 3)  -- сохраняем уменьшенное число коридоров
    local corridorPoints = {}
    table.insert(corridorPoints, center)
    for i = 1, numCorridors do
        local angle1 = math.random() * math.pi * 2
        local angle2 = math.random() * math.pi
        local distance = math.random(sx * 0.3, sx * 0.55)  -- расширенный диапазон для вариативности
        local corridorEnd = {
            center[1] + math.cos(angle1) * math.sin(angle2) * distance,
            center[2] + math.sin(angle1) * math.sin(angle2) * distance,
            center[3] + math.cos(angle2) * distance
        }
        local corridorSize = math.random(MEDIUM_BRUSH_MIN - 2, MEDIUM_BRUSH_MAX + 4)  -- разнообразие размеров
        local halfCorridor = math.floor(corridorSize / 2)
        corridorEnd[1] = math.max(halfCorridor, math.min(sx - halfCorridor, corridorEnd[1]))
        corridorEnd[2] = math.max(halfCorridor, math.min(sy - halfCorridor, corridorEnd[2]))
        corridorEnd[3] = math.max(halfCorridor, math.min(sz - halfCorridor, corridorEnd[3]))
        table.insert(corridorPoints, corridorEnd)
    end
    for i = 2, #corridorPoints do
        local startPoint = corridorPoints[1]
        local endPoint = corridorPoints[i]
        local corridorType = math.random(1, 4)
        local corridorSize = math.random(MEDIUM_BRUSH_MIN - 2, MEDIUM_BRUSH_MAX + 4)
        if corridorType == 1 then
            CarvePathInCube(cube, startPoint, endPoint, corridorSize)
        elseif corridorType == 2 then
            CarveWindingPath(cube, startPoint, endPoint, corridorSize)
        elseif corridorType == 3 then
            CarvePathInCube(cube, startPoint, endPoint, corridorSize)
            CarveSidePockets(cube, startPoint, endPoint, math.floor(corridorSize * 0.7))
        else
            CarveHeightVariations(cube, startPoint, endPoint, corridorSize)
        end
    end
    for i = 2, #corridorPoints do
        if math.random() < 0.7 then
            local chamberSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX + 4)
            local halfChamber = math.floor(chamberSize / 2)
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
end

-- Carve a vertical shaft in the cube
function CarveVerticalShaft(cube, center)
    local sx, sy, sz = ParseSize(cube.size)
    local shaftRadius = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
    local shaftHeight = math.random(sy * 0.7, sy * 0.9)
    local shaftBottom = {
        center[1],
        center[2] - shaftHeight/2,
        center[3]
    }
    shaftBottom[2] = math.max(shaftRadius, shaftBottom[2])
    local steps = math.ceil(shaftHeight / (shaftRadius * 0.5))
    for i = 0, steps do
        local t = i / steps
        -- Применяем плавное нелинейное смещение (easeInOutQuad)
        local smoothT = easeInOutQuad(t)
        local offsetX = math.sin(smoothT * math.pi * 2) * (shaftRadius / 3) + math.random(-1,1)
        local offsetZ = math.cos(smoothT * math.pi * 2) * (shaftRadius / 3) + math.random(-1,1)
        local pos = {
            shaftBottom[1] + offsetX,
            shaftBottom[2] + shaftHeight * smoothT,
            shaftBottom[3] + offsetZ
        }
        local variedRadius = shaftRadius * (0.8 + math.random() * 0.4)
        SetBrush("sphere", variedRadius, 0)
        DrawShapeBox(cube.shape, 
            pos[1] - variedRadius/2, 
            pos[2] - variedRadius/2, 
            pos[3] - variedRadius/2, 
            pos[1] + variedRadius/2, 
            pos[2] + variedRadius/2, 
            pos[3] + variedRadius/2)
    end
    -- Дополнительные формирования (например, выступы) оставляем без изменений
    local numLedges = math.random(2, 4)
    for i = 1, numLedges do
        local ledgeHeight = shaftBottom[2] + shaftHeight * (i / (numLedges + 1))
        local angle = math.random() * math.pi * 2
        local ledgeDir = {
            math.cos(angle),
            0,
            math.sin(angle)
        }
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
            local halfLedge = math.floor(ledgeWidth / 2)
            ledgePos[1] = math.max(halfLedge, math.min(sx - halfLedge, ledgePos[1]))
            ledgePos[3] = math.max(halfLedge, math.min(sz - halfLedge, ledgePos[3]))
            SetBrush("sphere", ledgeWidth, 0)
            DrawShapeBox(cube.shape, 
                ledgePos[1] - halfLedge, 
                ledgePos[2] - halfLedge, 
                ledgePos[3] - halfLedge, 
                ledgePos[1] + halfLedge, 
                ledgePos[2] + halfLedge, 
                ledgePos[3] + halfLedge)
        end
        if math.random() < 0.6 then
            local chamberSize = math.random(MEDIUM_BRUSH_MIN, MEDIUM_BRUSH_MAX)
            local chamberPos = {
                center[1] + ledgeDir[1] * ledgeLength,
                ledgeHeight,
                center[3] + ledgeDir[3] * ledgeLength
            }
            local halfChamber = math.floor(chamberSize / 2)
            chamberPos[1] = math.max(halfChamber, math.min(sx - halfChamber, chamberPos[1]))
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
    end
    local numFormations = math.random(3, 7)
    for i = 1, numFormations do
        local formationHeight = shaftBottom[2] + math.random() * shaftHeight
        local angle = math.random() * math.pi * 2
        local distance = math.random(shaftRadius * 0.3, shaftRadius * 0.8)
        local formationBase = {
            center[1] + math.cos(angle) * distance,
            formationHeight,
            center[3] + math.sin(angle) * distance
        }
        local isFromCeiling = formationHeight > center[2]
        local formationDir = isFromCeiling and -1 or 1
        local formationLength = math.random(SMALL_BRUSH_MIN, SMALL_BRUSH_MAX)
        local formationSteps = math.ceil(formationLength / 2)
        for j = 0, formationSteps do
            local ft = j / formationSteps
            local formationSize = SMALL_BRUSH_MIN * (1.0 - ft * 0.8)
            local formationPos = {
                formationBase[1] + math.random(-1, 1) * ft,
                formationBase[2] + formationDir * formationLength * ft,
                formationBase[3] + math.random(-1, 1) * ft
            }
            local halfFormation = math.floor(formationSize / 2)
            formationPos[1] = math.max(halfFormation, math.min(sx - halfFormation, formationPos[1]))
            formationPos[2] = math.max(halfFormation, math.min(sy - halfFormation, formationPos[2]))
            formationPos[3] = math.max(halfFormation, math.min(sz - halfFormation, formationPos[3]))
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
function GetFaceCenter(cube, direction)
    local sx, sy, sz = ParseSize(cube.size)
    local faceX = cube.position[1] + (direction[1] > 0 and sx or (direction[1] < 0 and 0 or sx/2))
    local faceY = cube.position[2] + (direction[2] > 0 and sy or (direction[2] < 0 and 0 or sy/2))
    local faceZ = cube.position[3] + (direction[3] > 0 and sz or (direction[3] < 0 and 0 or sz/2))
    return Vec(faceX, faceY, faceZ)
end
-----------------------------------------------------
-- Main Functions
-----------------------------------------------------
function init()
    DebugLog("Initializing enhanced cave generator...")
    math.randomseed(34567)
    
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
    for _, cube in ipairs(cubes) do
        CarveStalactitesAndStalagmites(cube)
    end
    DebugLog("Cave generation complete!")
end
