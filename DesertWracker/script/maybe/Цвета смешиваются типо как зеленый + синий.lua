--------------------------------------------------------------------------------
-- Teardown Lua script (Enhanced Deformation with Platform-Based Timer)
-- Simplified version without roller-based deformation
--------------------------------------------------------------------------------
---@diagnostic disable: lowercase-global, param-type-mismatch
local TRIGGER_NAME = "trg"
local triggerHandle = 0

-- Platform shape: "inprogress"
local inprogressShape = 0

--------------------------------------------------------------------------------
-- CONFIGURATION CONSTANTS
--------------------------------------------------------------------------------

local SPEED_THRESHOLD   = 1            -- Shredder speed threshold to start deformation
local CLEANUP_DELAY     = 5            -- 5-second timer per object after deformation starts
local CUBE_MASS         = 20
local FIXED_SPAWN_POS   = Vec(0, 0, 0) -- This will be updated based on the trigger's position

-- Spawning cubes
local cubeSpawnQueue = {}
local spawnTimer = 0
local SPAWN_INTERVAL = 1.0  -- Interval between cube spawns (in seconds)

-- Brush size logic
local MIN_BRUSH_SIZE  = 1
local MAX_BRUSH_SIZE  = 6

-- Downward speed factors for sinking when platform is removed
local DOWNWARD_SPEED_AT_MAX_FACTOR = -0.03
local DOWNWARD_SPEED_AT_MIN_FACTOR = -0.001

--------------------------------------------------------------------------------
-- SCRIPT STATE
--------------------------------------------------------------------------------

local spawnQueue      = 0
local spawnIndex      = 0

local processingItems = {}
local leftoverMass    = 0

local originalInprogressTransform = nil
local inprogressShifted           = false

--------------------------------------------------------------------------------
-- SPAWNING CUBES FUNCTIONALITY (OPTIMIZED)
--------------------------------------------------------------------------------
-- Color system configuration
local sortedColors = {}
-- Color system configuration
local colorNames = {"red", "green", "yellow", "blue"}
local colors = {
    red    = {value = {1.0, 0.0, 0.0}, weight = 0},
    green  = {value = {0.05, 0.61, 0.07}, weight = 0},
    yellow = {value = {1.0, 1.0, 0.0}, weight = 0},
    blue   = {value = {0, 0.58, 1}, weight = 0}
}
local cubePrototype = "<voxbox size='3 3 1' prop='true' material='hardmetal'/>"

--------------------------------------------------------------------------------
-- PAINTING SYSTEM
--------------------------------------------------------------------------------
function paintCube(shape)
    local availableColors = {}
    local tags = ListTags(shape)
    if tags then
        for _, tag in ipairs(tags) do
            if colors[tag] then
                table.insert(availableColors, colors[tag].value)
            end
        end
    end
    if #availableColors == 0 then return end

    -- Улучшенный расчет размера вокселя
    local min, max = GetShapeBounds(shape)
    local voxelSizeX = (max[1] - min[1])/3
    local voxelSizeY = (max[2] - min[2])/3
    local voxelSizeZ = (max[3] - min[3])/3
    local voxelSize = math.max(voxelSizeX, voxelSizeY, voxelSizeZ)

    -- Основной проход покраски
    for x = 0, 2 do
        for y = 0, 2 do
            for z = 0, 2 do
                -- Случайное смещение внутри вокселя
                local offsetX = (math.random() - 0.5) * voxelSize * 0.4
                local offsetY = (math.random() - 0.5) * voxelSize * 0.4
                local offsetZ = (math.random() - 0.5) * voxelSize * 0.4

                local pos = Vec(
                    min[1] + x*voxelSizeX + voxelSizeX/2 + offsetX,
                    min[2] + y*voxelSizeY + voxelSizeY/2 + offsetY,
                    min[3] + z*voxelSizeZ + voxelSizeZ/2 + offsetZ
                )

                -- Смешивание цветов с весами
                local mixedColor = {0, 0, 0}
                local totalWeight = 0
                for _, color in ipairs(availableColors) do
                    local weight = math.random() * 0.8 + 0.2
                    mixedColor[1] = mixedColor[1] + color[1] * weight
                    mixedColor[2] = mixedColor[2] + color[2] * weight
                    mixedColor[3] = mixedColor[3] + color[3] * weight
                    totalWeight = totalWeight + weight
                end
                mixedColor[1] = mixedColor[1]/totalWeight
                mixedColor[2] = mixedColor[2]/totalWeight
                mixedColor[3] = mixedColor[3]/totalWeight

                -- Основная покраска с большим радиусом
                PaintRGBA(pos, voxelSize * 1.5, 
                    mixedColor[1], mixedColor[2], mixedColor[3], 
                    1.0, 1.0)

                -- Дополнительная покраска краев
                if x == 0 or x == 2 or y == 0 or y == 2 then
                    PaintRGBA(pos, voxelSize * 0.8, 
                        mixedColor[1], mixedColor[2], mixedColor[3], 
                        1.0, 0.7)
                end
            end
        end
    end
end
function determinePlateColor()
    local totalWeight = 0
    for _, colorName in ipairs(colorNames) do
        totalWeight = totalWeight + colors[colorName].weight
    end

    if totalWeight == 0 then
        -- Если веса нет, возвращаем нейтральный цвет (например, серый)
        return {0.5, 0.5, 0.5}
    end

    local randomValue = math.random() * totalWeight
    local accumulatedWeight = 0

    for _, colorName in ipairs(colorNames) do
        accumulatedWeight = accumulatedWeight + colors[colorName].weight
        if randomValue <= accumulatedWeight then
            return colors[colorName].value
        end
    end

    -- В крайнем случае, возвращаем первый цвет
    return colors[colorNames[1]].value
end



--------------------------------------------------------------------------------
-- MODIFIED SPAWNING LOGIC (with color integration)
--------------------------------------------------------------------------------

function queueCubes(num)
    for i = 1, num do
        table.insert(cubeSpawnQueue, {})
    end
    DebugPrint(string.format("queueCubes() -> Queued %d, total in queue=%d", num, #cubeSpawnQueue))
end

function spawnCubes(num)
    queueCubes(num)
end

function spawnOneCubeFromQueue()
    if #cubeSpawnQueue > 0 then
        table.remove(cubeSpawnQueue, 1)
        spawnIndex = spawnIndex + 1

        local spawnPos = Vec(FIXED_SPAWN_POS[1], FIXED_SPAWN_POS[2], FIXED_SPAWN_POS[3])
        local angleDeg = math.random(0, 359)
        local hiddenPos = Vec(spawnPos[1], spawnPos[2] - 20, spawnPos[3])
        local spawnTransform = Transform(hiddenPos, QuatEuler(0, angleDeg, 0))

        local entities = Spawn(cubePrototype, spawnTransform)
        if #entities < 2 then return end

        local shape = entities[2]
        
        -- Добавляем теги цветов на основе весов
        for colorName, colorData in pairs(colors) do
            if colorData.weight > 0 then
                SetTag(shape, colorName)
            end
        end

        -- Генерируем базовый цвет и добавляем его как тег
        local baseColor = determinePlateColor()
        local baseColorName = getColorName(baseColor)
        SetTag(shape, baseColorName)

        -- Создаем детализацию краев
        SetBrush("noise", 1, 0)
        for z = 0, 0 do
            for x = 0, 2 do
                for y = 0, 2 do
                    if (x == 0 or x == 2 or y == 0 or y == 2) and math.random() < 0.4 then
                        DrawShapeBox(shape, x, y, z, x, y, z)
                    end
                end
            end
        end

        -- Активируем мультицветную покраску
        paintCube(shape)

        -- Перемещение куба на позицию
        local body = GetShapeBody(shape)
        if body ~= 0 then
            local bodyTr = GetBodyTransform(body)
            local finalWorldTr = Transform(spawnPos, QuatEuler(0, angleDeg, 0))
            local finalLocalTr = TransformToLocalTransform(bodyTr, finalWorldTr)
            SetShapeLocalTransform(shape, finalLocalTr)
            SetBodyVelocity(body, Vec(1, 0, 0))
        end
    end
end

function getColorName(color)
    local closest = ""
    local minDist = math.huge
    for name, data in pairs(colors) do
        local dist = math.sqrt(
            (color[1]-data.value[1])^2 +
            (color[2]-data.value[2])^2 +
            (color[3]-data.value[3])^2)
        if dist < minDist then
            minDist = dist
            closest = name
        end
    end
    return closest
end


--------------------------------------------------------------------------------
-- PLATFORM LOGIC (INPROGRESS)
--------------------------------------------------------------------------------

local function moveInprogressDown()
    if inprogressShape == 0 or inprogressShifted then return end
    if not originalInprogressTransform then
        originalInprogressTransform = GetShapeLocalTransform(inprogressShape)
    end
    local tr = TransformCopy(originalInprogressTransform)
    tr.pos[2] = tr.pos[2] - 10
    SetShapeLocalTransform(inprogressShape, tr)
    inprogressShifted = true
    DebugPrint("moveInprogressDown() -> 'inprogress' platform lowered by 10.")
end

local function moveInprogressUp()
    if inprogressShape == 0 or not inprogressShifted then return end
    if originalInprogressTransform then
        SetShapeLocalTransform(inprogressShape, originalInprogressTransform)
        inprogressShifted = false
        DebugPrint("moveInprogressUp() -> 'inprogress' platform returned to original position.")
    end
end

--------------------------------------------------------------------------------
-- DEFORMATION HANDLING FOR OBJECTS IN TRIGGER
--------------------------------------------------------------------------------

function initDeformation(shape)
    if processingItems[shape] then return end
    local bdy = GetShapeBody(shape)
    local mass = 0
    if bdy then mass = GetBodyMass(bdy) or 0 end
    
    local colorWeights = {}
    for _, colorName in ipairs(colorNames) do
        if HasTag(shape, colorName) then
            colorWeights[colorName] = mass  -- Записываем вес для этого цвета
        else
            colorWeights[colorName] = 0  -- Если тега нет, вес 0
        end
    end

    processingItems[shape] = {
        mass         = mass,
        isProcessing = false,
        chunkRemoved = false,
        deformTimer  = 0.0,
        descentTimer = nil,
        initialY     = 0,
        colorWeights = colorWeights -- Сохраняем веса цветов в processingItems
    }

    if bdy then
        local bodyTransform = GetBodyTransform(bdy)
        if bodyTransform and bodyTransform.pos then
            processingItems[shape].initialY = bodyTransform.pos[2]
        else
            DebugPrint("initDeformation() -> bodyTransform or bodyTransform.pos is nil")
        end
    else
        local tr = GetShapeLocalTransform(shape)
        if tr and tr.pos then
            processingItems[shape].initialY = tr.pos[2]
        else
            DebugPrint("initDeformation() -> tr or tr.pos is nil")
        end
    end

    DebugPrint(string.format("initDeformation() -> Shape %s added with mass %.2f, Colors: red=%.2f, green=%.2f, yellow=%.2f, blue=%.2f",
                             tostring(shape), mass, colorWeights["red"], colorWeights["green"], colorWeights["yellow"], colorWeights["blue"]))
end


function startDeformation(data)
    if data.isProcessing then return end
    data.isProcessing = true
    data.descentTimer = CLEANUP_DELAY
    DebugPrint("startDeformation() -> Deformation started; 5-sec timer initiated.")
end

-- Simplified deformation function
local function deformShape(shape, data, speed, dt)
    if not data.isProcessing then return end

    local bdy = GetShapeBody(shape)
    if not bdy then
        DebugPrint("deformShape() -> Shape " .. tostring(shape) .. " has no body!")
        return
    end

    local factor = speed / 25
    factor = math.max(0, math.min(factor, 1))

    if (not data.chunkRemoved) and factor > 0 then
        data.chunkRemoved = true
        moveInprogressDown()
        DebugPrint("deformShape() -> First deformation; platform removed.")
    end

    local sinkSpeed = DOWNWARD_SPEED_AT_MIN_FACTOR * (1 - factor) +
                      DOWNWARD_SPEED_AT_MAX_FACTOR * factor

    local velocity = GetBodyVelocity(bdy)
    velocity[2] = sinkSpeed

    SetBodyVelocity(bdy, velocity)
    data.deformTimer = data.deformTimer + dt

    local tries = math.random(20, 40)
    SetBrush("sphere", math.floor(MIN_BRUSH_SIZE + (MAX_BRUSH_SIZE - MIN_BRUSH_SIZE) * (1 - factor)), 0)

    for j = 1, tries do
        local x = math.random(0, 20)
        local y = math.random(0, 20)
        local z = math.random(0, 10)
        DrawShapeBox(shape, x, y, z, x, y, z)
    end
end

--------------------------------------------------------------------------------
-- PER-OBJECT CLEANUP
--------------------------------------------------------------------------------

local function cleanupObject(shape)
    if not IsHandleValid(shape) then return end
    DebugPrint("cleanupObject() -> Removing shape " .. tostring(shape))
    local data = processingItems[shape] or {}
    local shapeMass = data.mass or 0
    local bdy = GetShapeBody(shape)
    local canProduce = HasTag(shape, "resy") or (bdy and HasTag(bdy, "resy"))

    -- Обновляем веса цветов, используя сохраненные данные
    colors.red.weight    = colors.red.weight    + (data.colorWeights["red"] or 0)
    colors.green.weight  = colors.green.weight  + (data.colorWeights["green"] or 0)
    colors.yellow.weight = colors.yellow.weight + (data.colorWeights["yellow"] or 0)
    colors.blue.weight   = colors.blue.weight   + (data.colorWeights["blue"] or 0)

    if canProduce then
        leftoverMass = leftoverMass + shapeMass
        DebugPrint(string.format(
            "cleanupObject() -> Shape %s (resy): accumulated mass=%.2f",
            tostring(shape), leftoverMass
        ))
    else
        DebugPrint("cleanupObject() -> Shape "..tostring(shape).." (not resy); no cubes spawned.")
    end

    -- Spawn cubes after adding mass
    local toSpawn = math.floor(leftoverMass / CUBE_MASS)
    if toSpawn > 0 then
        spawnCubes(toSpawn)
        leftoverMass = leftoverMass % CUBE_MASS
    end

    if bdy then
        Delete(bdy)
    else
        Delete(shape)
    end
    processingItems[shape] = nil
end


--------------------------------------------------------------------------------
-- PROCESS PER-OBJECT TIMERS
--------------------------------------------------------------------------------
local function processObjectTimers(dt)
    local count = 0
    for shape, data in pairs(processingItems) do
        count = count + 1
        if data.isProcessing and data.descentTimer then
            data.descentTimer = data.descentTimer - dt
            if data.descentTimer <= 0 then
                cleanupObject(shape)
            end
        end
    end

    -- If nothing is being processed and the platform is still down, raise it
    if count == 0 and inprogressShifted then
        moveInprogressUp()
    end
end

--------------------------------------------------------------------------------
-- MAIN TICK FUNCTION
--------------------------------------------------------------------------------
function tick()
    if not triggerHandle then return end
    local dt = GetTimeStep()
    local speed = GetFloat("shredderSpeed") or 0

    -- Remove invalid items from processing
    for shape in pairs(processingItems) do
        if not IsHandleValid(shape) then
            processingItems[shape] = nil
        end
    end

    -- Process all shapes in the trigger
    local shapes = FindShapes("", true)
    for i = 1, #shapes do
        local shp = shapes[i]
        local bdy = GetShapeBody(shp)
        if bdy and IsBodyInTrigger(triggerHandle, bdy) then
            local data = processingItems[shp]
            if not data then
                initDeformation(shp)
                data = processingItems[shp]
            end

            if data then
                if not data.isProcessing and speed > SPEED_THRESHOLD then
                    startDeformation(data)
                end
                if data.isProcessing then
                    deformShape(shp, data, speed, dt)
                end
            end
        end
    end

    -- Periodic cube spawn
    spawnTimer = spawnTimer + dt
    if spawnTimer >= SPAWN_INTERVAL then
        spawnOneCubeFromQueue()
        spawnTimer = 0
    end

    -- Process timers for individual objects
    processObjectTimers(dt)

    -- Cleanup if an object is in the middle of processing but removed from trigger
    for shape, data in pairs(processingItems) do
        if data.isProcessing then
            local bdy = GetShapeBody(shape)
            if bdy == 0 or (bdy ~= 0 and not IsBodyInTrigger(triggerHandle, bdy)) then
                cleanupObject(shape)
            end
        end
    end

    -- Сброс весов цветов, когда все обработано и очередь спавна пуста
    local processingCount = 0
    for _ in pairs(processingItems) do
        processingCount = processingCount + 1
    end

    if #cubeSpawnQueue == 0 and processingCount == 0 and not inprogressShifted then
        resetColorWeights()
    end
end

function resetColorWeights()
    for _, colorName in ipairs(colorNames) do
        colors[colorName].weight = 0
    end
    DebugPrint("Color weights reset to 0.")
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------
function init()
    triggerHandle = FindTrigger(TRIGGER_NAME, true)
    inprogressShape = FindShape("inprogress", true)
    
    if triggerHandle ~= 0 then
        local triggerTransform = GetTriggerTransform(triggerHandle)
        FIXED_SPAWN_POS = Vec(
            triggerTransform.pos[1] + 3,
            triggerTransform.pos[2] - 0.3,
            triggerTransform.pos[3] - 0.5
        )
    end
    
    if inprogressShape ~= 0 then
        originalInprogressTransform = GetShapeLocalTransform(inprogressShape)
    end

    -- Initialize color arrays
    for i = 1, 4 do
        sortedColors[i] = {value = {}, weight = 0}
    end
    
    DebugPrint("Integrated system initialized")
end