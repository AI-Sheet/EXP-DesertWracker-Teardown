--------------------------------------------------------------------------------
-- Оптимизированный скрипт Teardown (Deformation + Sinking) с поддержкой до 10 цветов
-- и переходных оттенков. Скрипт выполняет деформацию объектов с эффектом sinking и 
-- создает кубы (пластинки) на основе накопленной массы и весов цветов.
-- Для визуализации используется логика покраски, которая определяет два основных цвета:
-- главный (dominant) и вторичный (inclusion), а затем генерирует до 3 переходных оттенков.
--
-- Функция TrimShape, которая обрезает пустые области фигуры, не используется после спавна
-- пластинок, так как нам важна визуализация исходных цветов.
--
-- Debug messages are printed in English.
--------------------------------------------------------------------------------
---@diagnostic disable: lowercase-global, param-type-mismatch

------------------------
-- НАСТРОЙКИ КОНСТАНТ --
------------------------
local TRIGGER_NAME              = "trg"
local SPEED_THRESHOLD           = 1              -- Минимальная скорость для начала деформации
local CLEANUP_DELAY             = 5              -- Задержка (сек) до очистки объекта
local CUBE_MASS                 = 20             -- Масса, необходимая для создания одного куба
local FIXED_SPAWN_POS           = Vec(0, 0, 0)   -- Позиция спавна устанавливается при init

-- Очередь спавна кубов
local cubeSpawnQueue            = {}
local spawnTimer                = 0
local SPAWN_INTERVAL            = 1.0            -- Интервал спавна кубов (сек)

-- Размер кисти для деформации
local MIN_BRUSH_SIZE            = 1
local MAX_BRUSH_SIZE            = 6

-- Коэффициенты sinking по оси Y
local DOWNWARD_SPEED_AT_MAX     = -0.08
local DOWNWARD_SPEED_AT_MIN     = -0.02

------------------------
-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ --
------------------------
local triggerHandle             = 0
local processingItems           = {}   -- Объекты, находящиеся в обработке
local leftoverMass              = 0    -- Накопленная масса для спавна кубов

local colors = {
    red    = {value = {1.0, 0.0, 0.0},       weight = 0},
    green  = {value = {0.05, 0.61, 0.07},      weight = 0},
    yellow = {value = {1.0, 1.0, 0.0},         weight = 0},
    blue   = {value = {0, 0.58, 1},            weight = 0},
    purple = {value = {0.5, 0.0, 0.5},         weight = 0},
    orange = {value = {1.0, 0.5, 0.0},         weight = 0},
    cyan   = {value = {0.0, 1.0, 1.0},         weight = 0},
    magenta= {value = {1.0, 0.0, 1.0},         weight = 0},
    lime   = {value = {0.75, 1.0, 0.0},        weight = 0},
    brown  = {value = {0.6, 0.4, 0.2},         weight = 0}
}

-- Прототип куба (пластинки)
local cubePrototype = "<voxbox size='3 3 1' prop='true' material='hardmetal'/>"

--------------------------
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ --
--------------------------
-- Функция возвращает случайную позицию внутри заданных границ minB, maxB.
local function randomPosInBounds(minB, maxB)
    return Vec(
        minB[1] + math.random() * (maxB[1] - minB[1]),
        minB[2] + math.random() * (maxB[2] - minB[2]),
        minB[3] + math.random() * (maxB[3] - minB[3])
    )
end

-- Возвращает имя цвета, ближайшего к заданному (по евклидову расстоянию).
function getColorName(color)
    local closest = ""
    local minDist = math.huge
    for name, data in pairs(colors) do
        local dist = math.sqrt(
            (color[1] - data.value[1])^2 +
            (color[2] - data.value[2])^2 +
            (color[3] - data.value[3])^2
        )
        if dist < minDist then
            minDist = dist
            closest = name
        end
    end
    return closest
end

-------------------------
-- ЛОГИКА СМЕША ЦВЕТОВ --
-------------------------
-- Функция определяет два основных цвета для пластинки.
-- Перебирает все цвета с ненулевым весом, сортирует их по весу и 
-- возвращает:
--    mainColor: цвет с наибольшим весом,
--    secondaryColor: цвет со вторым по величине весом (если отсутствует, то такой же).
local function determinePlateColors()
    local sorted = {}
    for name, data in pairs(colors) do
        if data.weight > 0 then
            table.insert(sorted, {name = name, weight = data.weight, value = data.value})
        end
    end
    table.sort(sorted, function(a, b) return a.weight > b.weight end)
    local mainColor, secondaryColor
    if #sorted == 0 then
        mainColor = {0.5, 0.5, 0.5}
        secondaryColor = mainColor
    elseif #sorted == 1 then
        mainColor = sorted[1].value
        secondaryColor = mainColor
    else
        mainColor = sorted[1].value
        secondaryColor = sorted[2].value
    end
    return mainColor, secondaryColor
end

-- Функция генерации переходных (трансляционных) оттенков.
-- Принимает два цвета (main и secondary) и количество переходных оттенков.
-- Возвращает таблицу с промежуточными цветами.
local function generateTransitionColors(mainColor, secondaryColor, count)
    local transitions = {}
    for i = 1, count do
        local t = i / (count + 1)  -- доля перехода
        local r = mainColor[1] * (1 - t) + secondaryColor[1] * t
        local g = mainColor[2] * (1 - t) + secondaryColor[2] * t
        local b = mainColor[3] * (1 - t) + secondaryColor[3] * t
        table.insert(transitions, {r, g, b})
    end
    return transitions
end

-------------------------
-- РИСОВАНИЕ КУБА --
-------------------------
-- Функция покраски куба (пластинки) с использованием нескольких слоев.
-- Основная заливка создаётся крупными пятнами основного цвета.
-- Затем добавляется переходной слой (до 3 оттенков от основного к вторичному),
-- после чего наносятся вкрапления вторичного цвета.
function paintCube(shape)
    local tags = ListTags(shape)
    if not (tags and #tags > 0) then return end

    local mainColor, secondaryColor = determinePlateColors()
    local transitions = generateTransitionColors(mainColor, secondaryColor, 3)  -- максимум 3 переходных оттенка

    local minB, maxB = GetShapeBounds(shape)
    local dX, dY, dZ = maxB[1] - minB[1], maxB[2] - minB[2], maxB[3] - minB[3]
    local voxelSize = math.max(dX, dY, dZ) / 3

    local MAIN_SPOTS        = 150  -- пятна основного цвета
    local TRANSITION_SPOTS  = 50   -- пятна переходных оттенков
    local INLAY_SPOTS       = 30   -- пятна вторичного цвета

    -- Рисуем основную заливку основным цветом.
    for i = 1, MAIN_SPOTS do
        local spotSize = voxelSize * (0.6 + math.random() * 0.4)
        local pos = randomPosInBounds(minB, maxB)
        PaintRGBA(pos, spotSize, mainColor[1]^0.45, mainColor[2]^0.45, mainColor[3]^0.45, 1.0, 1.0)
    end

    -- Рисуем переходной слой.
    for i = 1, TRANSITION_SPOTS do
        local colorIdx = math.random(1, #transitions)
        local transitionColor = transitions[colorIdx]
        local spotSize = voxelSize * (0.4 + math.random() * 0.2)  -- чуть меньше пятен
        local pos = randomPosInBounds(minB, maxB)
        PaintRGBA(pos, spotSize, transitionColor[1]^0.45, transitionColor[2]^0.45, transitionColor[3]^0.45, 1.0, 1.0)
    end

    -- Рисуем вкрапления вторичным цветом.
    for i = 1, INLAY_SPOTS do
        local spotSize = voxelSize * (0.2 + math.random() * 0.3)
        local pos = randomPosInBounds(minB, maxB)
        PaintRGBA(pos, spotSize, secondaryColor[1]^0.45, secondaryColor[2]^0.45, secondaryColor[3]^0.45, 1.0, 1.0)
    end

    -- Добавляем шум для эффекта зернистости по краям.
    SetBrush("noise", 1.5, 0)
    for x = 0, 2 do
        for y = 0, 2 do
            if (x == 0 or x == 2 or y == 0 or y == 2) and math.random() < 0.4 then
                DrawShapeBox(shape, x, y, 0, x, y, 0)
            end
        end
    end
end

----------------------------
-- СПАВН КУБОВ (ОЧЕРЕДЬ) --
----------------------------
function queueCubes(num)
    if num > 0 then
        for i = 1, num do
            cubeSpawnQueue[#cubeSpawnQueue + 1] = {}  -- маркер в очереди
        end
        DebugPrint(string.format("Queued %d cubes, total in queue = %d", num, #cubeSpawnQueue))
    end
end

function spawnOneCubeFromQueue()
    if #cubeSpawnQueue > 0 then
        table.remove(cubeSpawnQueue, 1)
        local spawnPos = FIXED_SPAWN_POS
        local angleDeg = math.random(0, 359)
        local hiddenPos = Vec(spawnPos[1], spawnPos[2] - 20, spawnPos[3])
        local spawnTransform = Transform(hiddenPos, QuatEuler(0, angleDeg, 0))
        local entities = Spawn(cubePrototype, spawnTransform)
        if #entities >= 2 then
            local shape = entities[2]
            -- Применяем теги для каждого цвета, если вес ненулевой.
            for colorName, colorData in pairs(colors) do
                if colorData.weight > 0 then 
                    SetTag(shape, colorName)
                end
            end
            local mainColor, _ = determinePlateColors()
            SetTag(shape, getColorName(mainColor))
            paintCube(shape)
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
end

----------------------------
-- ОБРАБОТКА ОБЪЕКТОВ --
----------------------------
function initDeformation(shape)
    if not processingItems[shape] then
        local bdy = GetShapeBody(shape)
        local mass = (bdy and GetBodyMass(bdy)) or 0
        local colorWeights = {}
        for name, data in pairs(colors) do
            colorWeights[name] = HasTag(shape, name) and mass or 0
        end
        local initialY = 0
        if bdy then 
            local bodyTransform = GetBodyTransform(bdy)
            initialY = (bodyTransform and bodyTransform.pos and bodyTransform.pos[2]) or 0
        else
            local tr = GetShapeLocalTransform(shape)
            initialY = (tr and tr.pos and tr.pos[2]) or 0
        end
        processingItems[shape] = {
            mass = mass,
            isProcessing = false,
            deformTimer = 0,
            descentTimer = 0,
            initialY = initialY,
            colorWeights = colorWeights,
            collisionDisabled = false
        }
        DebugPrint(string.format("Added shape %s with mass %.2f; colors: red=%.2f, green=%.2f, yellow=%.2f, blue=%.2f",
                   tostring(shape), mass, colorWeights["red"] or 0, colorWeights["green"] or 0, colorWeights["yellow"] or 0, colorWeights["blue"] or 0))
    end
end

function deformShape(shape, data, speed, dt)
    local bdy = GetShapeBody(shape)
    if not (data.isProcessing and bdy) then 
        DebugPrint("deformShape() -> Shape " .. tostring(shape) .. " has no body!")
        return 
    end
    local factor = math.max(0, math.min(speed / 25, 1))
    data.deformTimer = data.deformTimer + dt
    local sinkSpeed = DOWNWARD_SPEED_AT_MIN * (1 - factor) + DOWNWARD_SPEED_AT_MAX * factor
    local velocity = GetBodyVelocity(bdy)
    velocity[2] = sinkSpeed
    SetBodyVelocity(bdy, velocity)
    if not data.collisionDisabled then
        SetShapeCollisionFilter(shape, 99, 0)
        data.collisionDisabled = true
        DebugPrint("Disabled collisions for shape " .. tostring(shape))
    end
    SetBrush("sphere", math.floor(MIN_BRUSH_SIZE + (MAX_BRUSH_SIZE - MIN_BRUSH_SIZE) * (1 - factor)), 0)
    for j = 1, math.random(20, 40) do
        local x = math.random(0, 20)
        local y = math.random(0, 20)
        local z = math.random(0, 10)
        DrawShapeBox(shape, x, y, z, x, y, z)
    end
end

function cleanupObject(shape)
    if not IsHandleValid(shape) then return end
    DebugPrint("Removing shape " .. tostring(shape))
    local data = processingItems[shape] or {}
    local shapeMass = data.mass or 0
    local bdy = GetShapeBody(shape)
    local canProduce = false
    for name, _ in pairs(colors) do
        if HasTag(shape, name) then 
            canProduce = true 
            break 
        end
    end
    for name, _ in pairs(colors) do
        colors[name].weight = colors[name].weight + (data.colorWeights[name] or 0)
    end
    if canProduce then
        leftoverMass = leftoverMass + shapeMass
        DebugPrint(string.format("Accumulated mass = %.2f from shape %s", leftoverMass, tostring(shape)))
    else
        DebugPrint("Shape " .. tostring(shape) .. " does not produce cubes.")
    end
    local toSpawn = math.floor(leftoverMass / CUBE_MASS)
    if toSpawn > 0 then
        queueCubes(toSpawn)
        leftoverMass = leftoverMass % CUBE_MASS
    end
    if bdy then 
        Delete(bdy) 
    else 
        Delete(shape) 
    end
    processingItems[shape] = nil
end

----------------------------
-- ПРОВЕРКА ИГРОКА --
----------------------------
function checkPlayerKill()
    local playerTr = GetPlayerTransform()
    local triggerTr = GetTriggerTransform(triggerHandle)
    if playerTr and triggerTr then
        local diff = VecSub(playerTr.pos, triggerTr.pos)
        if VecLength(diff) < 1.5 and (GetFloat("shredderSpeed") or 0) > SPEED_THRESHOLD and GetPlayerHealth() > 0 then
            DebugPrint("Player within active range. Killing player!")
            SetPlayerHealth(0)
        end
    end
end

----------------------------
-- ГЛАВНАЯ ТИК-ФУНКЦИЯ --
----------------------------
function tick()
    if triggerHandle and triggerHandle ~= 0 then
        local dt = GetTimeStep()
        local speed = GetFloat("shredderSpeed") or 0
        checkPlayerKill()
        local shapes = FindShapes("", true)
        for i = 1, #shapes do
            local shp = shapes[i]
            local bdy = GetShapeBody(shp)
            if bdy and IsBodyInTrigger(triggerHandle, bdy) and not HasTag(shp, "val") then
                if not processingItems[shp] then 
                    initDeformation(shp)
                end
                local data = processingItems[shp]
                if data then
                    if not data.isProcessing and speed > SPEED_THRESHOLD then
                        data.isProcessing = true
                        data.descentTimer = CLEANUP_DELAY
                    end
                    if data.isProcessing then 
                        deformShape(shp, data, speed, dt) 
                    end
                end
            end
        end
        spawnTimer = spawnTimer + dt
        if spawnTimer >= SPAWN_INTERVAL then
            spawnOneCubeFromQueue()
            spawnTimer = 0
        end
        for shape, data in pairs(processingItems) do
            if IsHandleValid(shape) then
                local body = GetShapeBody(shape)
                if data.isProcessing and (not body or not IsBodyInTrigger(triggerHandle, body)) then
                    cleanupObject(shape)
                elseif data.isProcessing then
                    data.descentTimer = data.descentTimer - dt
                    if data.descentTimer <= 0 then 
                        cleanupObject(shape) 
                    end
                end
            else
                processingItems[shape] = nil
            end
        end
    end
end

----------------------------
-- ИНИЦИАЛИЗАЦИЯ --
----------------------------
function init()
    triggerHandle = FindTrigger(TRIGGER_NAME, true)
    if triggerHandle and triggerHandle ~= 0 then
        local tr = GetTriggerTransform(triggerHandle)
        FIXED_SPAWN_POS = Vec(tr.pos[1] + 3, tr.pos[2] - 0.3, tr.pos[3] - 0.5)
    end
end