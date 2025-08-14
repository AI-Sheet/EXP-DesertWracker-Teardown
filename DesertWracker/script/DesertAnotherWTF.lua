--[[
    Оптимизированная система генерации пещер для Teardown
    
    Этот скрипт создает сложную систему пещер в объекте "desert_base" с различными
    особенностями: спуски разных типов (лестницы, спирали, резкие), развилки,
    тупики, ловушки и просторные "комнаты" для отдыха.
    
    Особенности:
    - Разнообразные типы входных спусков (лестница, спираль, резкий)
    - Сложная система туннелей с развилками и тупиками
    - Просторные "комнаты" для отдыха
    - Узкие проходы и ловушки
    - Множественные проходы для удаления обломков
    - Настраиваемые параметры генерации
--]]

-- Настройки генерации пещер
local settings = {
    startHeight = 10,        -- Начальная высота (Y-координата) входа в пещеру
    descentType = 0,        -- Тип спуска (0=случайный, 1=лестница, 2=спираль, 3=резкий)
    descentDepth = 0,       -- Глубина спуска (определяется случайно от 5 до 15)
    minRadius = 0.5,        -- Минимальный радиус туннелей
    maxRadius = 1.3,        -- Максимальный радиус туннелей
    roomChance = 0.05,      -- Вероятность создания "комнаты" (0-1)
    roomMinRadius = 1,      -- Минимальный радиус "комнаты"
    roomMaxRadius = 2,      -- Максимальный радиус "комнаты"
    mainPathLength = 120,   -- Длина основного пути (количество сегментов)
    branchChance = 0.5,     -- Вероятность создания ответвления (0-1)
    branchLength = 50,      -- Длина ответвлений (количество сегментов)
    maxBranches = 30,       -- Максимальное количество ответвлений
    deadEndChance = 0.6,    -- Вероятность того, что ответвление будет тупиком (0-1)
    trapChance = 0.3,       -- Вероятность создания ловушки (0-1)
    stepSize = 1.9,         -- Размер шага между сегментами
    verticalChance = 0.5,   -- Вероятность вертикального движения (0-1)
    downwardBias = 0.8,     -- Вероятность движения вниз при вертикальном движении (0-1)
    cleanupPasses = 4,      -- Количество дополнительных проходов для удаления обломков
    silentRemoval = true,   -- Отключение звуков разрушения
    borderMargin = 1,       -- Отступ от границ объекта
    supportPillars = true,  -- Создавать поддерживающие колонны для предотвращения обрушения
    pillarSpacing = 7,      -- Расстояние между поддерживающими колоннами
    subBranchChance = 0.3,  -- Вероятность создания ответвлений от ответвлений
    subBranchLength = 10,   -- Длина ответвлений от ответвлений
    maxSubBranches = 20,    -- Максимальное количество ответвлений от ответвлений
    directionChangeChance = 0.4, -- Вероятность изменения направления
    narrowPassageChance = 0.3 -- Вероятность создания очень узкого прохода
}

-- Глобальные переменные
local desertShape = 0       -- Хендл основного объекта
local caveCreated = false   -- Флаг создания пещеры
local allPositions = {}     -- Массив всех позиций сегментов пещеры
local totalVoxelsRemoved = 0 -- Общее количество удаленных вокселей
local branchesCreated = 0   -- Счетчик созданных ответвлений
local subBranchesCreated = 0 -- Счетчик созданных ответвлений от ответвлений
local roomsCreated = 0      -- Счетчик созданных комнат
local trapsCreated = 0      -- Счетчик созданных ловушек
local deadEndsCreated = 0   -- Счетчик созданных тупиков
local pillarsCreated = 0    -- Счетчик созданных поддерживающих колонн
local objectBounds = {min = Vec(0,0,0), max = Vec(0,0,0)} -- Границы объекта
local pillarPositions = {}  -- Кэш позиций колонн
local debugMode = true      -- Режим отладки

-- Предварительно вычисленные направления (оптимизация)
local DIRECTIONS = {
    Vec(1, 0, 0),   -- +X
    Vec(-1, 0, 0),  -- -X
    Vec(0, 0, 1),   -- +Z
    Vec(0, 0, -1),  -- -Z
}

-- Улучшенная функция отладочного вывода
function DebugLog(message)
    if debugMode then
        DebugPrint("[CaveGen] " .. message)
    end
end



-- Создает дыру с заданным радиусом в указанной позиции
function CreateHole(position, radius)
    -- Проверяем корректность параметров
    if not position or type(radius) ~= "number" then
        DebugLog("ERROR in CreateHole: Invalid parameters")
        return 0
    end
    
    -- Проверяем, что радиус положительный
    radius = math.max(0.1, radius)
    
    -- Проверяем, что позиция находится в пределах объекта
    if not IsWithinSafeBounds(position) then
        position = ClampToBounds(position)
    end
    
    -- Создаем дыру
    local voxelsRemoved = MakeHole(position, radius, radius, radius, settings.silentRemoval)
    totalVoxelsRemoved = totalVoxelsRemoved + voxelsRemoved
    
    return voxelsRemoved
end

-- Генерирует случайное направление движения (оптимизировано)
function GetRandomDirection()
    return DIRECTIONS[math.random(1, #DIRECTIONS)]
end

-- Проверяет, находится ли позиция в пределах безопасной зоны объекта
function IsWithinSafeBounds(position)
    local margin = settings.borderMargin
    local min = objectBounds.min
    local max = objectBounds.max
    
    return position[1] >= min[1] + margin and
           position[1] <= max[1] - margin and
           position[2] >= min[2] + margin and
           position[2] <= max[2] - margin and
           position[3] >= min[3] + margin and
           position[3] <= max[3] - margin
end

-- Ограничивает позицию в пределах безопасной зоны объекта
function ClampToBounds(position)
    local margin = settings.borderMargin
    local min = objectBounds.min
    local max = objectBounds.max
    
    -- Оптимизировано: создаем вектор только один раз
    return Vec(
        math.max(min[1] + margin, math.min(max[1] - margin, position[1])),
        math.max(min[2] + margin, math.min(max[2] - margin, position[2])),
        math.max(min[3] + margin, math.min(max[3] - margin, position[3]))
    )
end

-- Создает поддерживающую колонну от пола до потолка
function CreateSupportPillar(position, radius)
    pillarsCreated = pillarsCreated + 1
    
    -- Находим пол и потолок
    local floorY = objectBounds.min[2] + 1
    local ceilingY = objectBounds.max[2] - 1
    
    -- Создаем колонну (не удаляем вокселы в этой области)
    local pillarRadius = radius * 0.7
    local pillarPos = Vec(position[1], (floorY + ceilingY) / 2, position[3])
    
    DebugLog("Creating support pillar #" .. pillarsCreated .. " at position " .. VecStr(pillarPos))
    
    -- Добавляем позицию колонны в кэш
    table.insert(pillarPositions, pillarPos)
    
    return pillarPos
end

-- Создает спуск типа "лестница"
function CreateStaircaseDescent(startPos, depth)
    local segments = {}
    local currentPos = Vec(startPos[1], startPos[2], startPos[3])
    local direction = GetRandomDirection()
    local stepsCount = math.floor(depth / 1.5)
    local verticalStep = depth / stepsCount
    
    DebugLog("Creating staircase descent with " .. stepsCount .. " steps")
    
    for i = 1, stepsCount do
        -- Сначала шаг вперед
        currentPos = Vec(
            currentPos[1] + direction[1] * settings.stepSize,
            currentPos[2],
            currentPos[3] + direction[3] * settings.stepSize
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        table.insert(segments, Vec(currentPos[1], currentPos[2], currentPos[3]))
        
        -- Затем шаг вниз
        currentPos = Vec(
            currentPos[1],
            currentPos[2] - verticalStep,
            currentPos[3]
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        table.insert(segments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    end
    
    DebugLog("Created staircase descent to depth: " .. depth)
    return segments, currentPos
end

-- Создает спуск типа "спираль"
function CreateSpiralDescent(startPos, depth)
    local segments = {}
    local currentPos = Vec(startPos[1], startPos[2], startPos[3])
    local radius = math.min(3.0, settings.borderMargin * 0.5)
    local turns = 2.0
    local stepsCount = 20
    local verticalStep = depth / stepsCount
    local angleStep = turns * 2 * math.pi / stepsCount
    
    DebugLog("Creating spiral descent with radius " .. radius)
    
    for i = 1, stepsCount do
        local angle = i * angleStep
        currentPos = Vec(
            startPos[1] + radius * math.cos(angle),
            startPos[2] - i * verticalStep,
            startPos[3] + radius * math.sin(angle)
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        table.insert(segments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    end
    
    DebugLog("Created spiral descent to depth: " .. depth)
    return segments, currentPos
end

-- Создает резкий спуск (почти вертикальный)
function CreateSteepDescent(startPos, depth)
    local segments = {}
    local currentPos = Vec(startPos[1], startPos[2], startPos[3])
    local direction = GetRandomDirection()
    local horizontalSteps = 3
    local horizontalStep = settings.stepSize
    local verticalStep = depth / horizontalSteps
    
    DebugLog("Creating steep descent with depth " .. depth)
    
    -- Сначала небольшой горизонтальный проход
    for i = 1, 2 do
        currentPos = Vec(
            currentPos[1] + direction[1] * horizontalStep,
            currentPos[2],
            currentPos[3] + direction[3] * horizontalStep
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        table.insert(segments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    end
    
    -- Затем резкий спуск вниз
    for i = 1, horizontalSteps do
        currentPos = Vec(
            currentPos[1] + direction[1] * horizontalStep * 0.5,
            currentPos[2] - verticalStep,
            currentPos[3] + direction[3] * horizontalStep * 0.5
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        table.insert(segments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    end
    
    DebugLog("Created steep descent to depth: " .. depth)
    return segments, currentPos
end

-- Создает случайный спуск (выбирает один из трех типов)
function CreateRandomDescent(startPos, depth)
    local descentType = math.random(1, 3)
    
    if descentType == 1 then
        return CreateStaircaseDescent(startPos, depth)
    elseif descentType == 2 then
        return CreateSpiralDescent(startPos, depth)
    else
        return CreateSteepDescent(startPos, depth)
    end
end

-- Создает вход в пещеру и начальный спуск
function CreateCaveEntrance()
    -- Определяем случайную начальную позицию на поверхности
    local startX = objectBounds.min[1] + settings.borderMargin + math.random() * (objectBounds.max[1] - objectBounds.min[1] - 2 * settings.borderMargin)
    local startZ = objectBounds.min[3] + settings.borderMargin + math.random() * (objectBounds.max[3] - objectBounds.min[3] - 2 * settings.borderMargin)
    local startY = objectBounds.max[2] - settings.startHeight
    
    local startPos = Vec(startX, startY, startZ)
    
    -- Определяем глубину спуска (если не задана)
    if settings.descentDepth <= 0 then
        settings.descentDepth = math.random(5, 15)
    end
    
    -- Создаем вход (большая дыра на поверхности)
    local entranceRadius = settings.maxRadius * 1.5
    CreateHole(startPos, entranceRadius)
    
    -- Создаем спуск выбранного типа
    local descentSegments, endPos
    
    if settings.descentType == 0 then
        descentSegments, endPos = CreateRandomDescent(startPos, settings.descentDepth)
    elseif settings.descentType == 1 then
        descentSegments, endPos = CreateStaircaseDescent(startPos, settings.descentDepth)
    elseif settings.descentType == 2 then
        descentSegments, endPos = CreateSpiralDescent(startPos, settings.descentDepth)
    else
        descentSegments, endPos = CreateSteepDescent(startPos, settings.descentDepth)
    end
    
    -- Создаем дыры для всех сегментов спуска
    for _, pos in ipairs(descentSegments) do
        local radius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius)
        CreateHole(pos, radius)
        table.insert(allPositions, pos)
    end
    
    DebugLog("Created cave entrance at " .. VecStr(startPos) .. " with descent to " .. VecStr(endPos))
    return endPos
end

-- Проверяет, находится ли позиция достаточно далеко от всех существующих позиций
function IsPositionFarEnough(position, minDistance)
    -- Оптимизация: ранний выход, если список пуст
    if #allPositions == 0 then
        return true
    end
    
    minDistance = minDistance or settings.stepSize * 0.5
    local minDistSq = minDistance * minDistance
    
    -- Оптимизация: используем квадрат расстояния вместо вычисления корня
    for _, pos in ipairs(allPositions) do
        local dx = position[1] - pos[1]
        local dy = position[2] - pos[2]
        local dz = position[3] - pos[3]
        local distSq = dx*dx + dy*dy + dz*dz
        
        if distSq < minDistSq then
            return false
        end
    end
    
    return true
end

-- Проверяет, находится ли позиция достаточно далеко от всех колонн
function IsPositionFarFromPillars(position, minDistance)
    -- Оптимизация: ранний выход, если список пуст
    if #pillarPositions == 0 then
        return true
    end
    
    minDistance = minDistance or settings.stepSize
    local minDistSq = minDistance * minDistance
    
    -- Оптимизация: используем квадрат расстояния вместо вычисления корня
    for _, pos in ipairs(pillarPositions) do
        local dx = position[1] - pos[1]
        local dy = position[2] - pos[2]
        local dz = position[3] - pos[3]
        local distSq = dx*dx + dy*dy + dz*dz
        
        if distSq < minDistSq then
            return false
        end
    end
    
    return true
end

-- Создает "комнату" (большую полость) в указанной позиции
function CreateRoom(position)
    roomsCreated = roomsCreated + 1
    
    -- Определяем случайный радиус комнаты
    local radius = settings.roomMinRadius + math.random() * (settings.roomMaxRadius - settings.roomMinRadius)
    
    -- Создаем основную полость комнаты
    CreateHole(position, radius)
    
    -- Создаем несколько дополнительных полостей вокруг для создания неровностей
    local irregularities = math.random(3, 6)
    for i = 1, irregularities do
        local angle = math.random() * 2 * math.pi
        local distance = radius * 0.6 * math.random()
        local irregularityPos = Vec(
            position[1] + math.cos(angle) * distance,
            position[2] + (math.random() - 0.5) * radius * 0.5,
            position[3] + math.sin(angle) * distance
        )
        
        -- Проверяем и ограничиваем позицию
        irregularityPos = ClampToBounds(irregularityPos)
        
        -- Создаем дополнительную полость
        local irregularityRadius = radius * 0.3 + math.random() * radius * 0.3
        CreateHole(irregularityPos, irregularityRadius)
    end
    
    -- Если нужно, создаем поддерживающую колонну
    if settings.supportPillars and math.random() < 0.7 then
        CreateSupportPillar(position, radius)
    end
    
    DebugLog("Created room #" .. roomsCreated .. " at " .. VecStr(position) .. " with radius " .. radius)
    return radius
end

-- Создает ловушку (узкий проход с резким спуском)
function CreateTrap(position, direction)
    trapsCreated = trapsCreated + 1
    
    local trapSegments = {}
    local currentPos = Vec(position[1], position[2], position[3])
    
    -- Создаем узкий горизонтальный проход
    local passageLength = math.random(3, 5)
    for i = 1, passageLength do
        currentPos = Vec(
            currentPos[1] + direction[1] * settings.stepSize,
            currentPos[2],
            currentPos[3] + direction[3] * settings.stepSize
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        table.insert(trapSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    end
    
    -- Затем резкий спуск вниз
    local dropDepth = math.random(3, 7)
    currentPos = Vec(
        currentPos[1],
        currentPos[2] - dropDepth,
        currentPos[3]
    )
    
    -- Проверяем и ограничиваем позицию
    currentPos = ClampToBounds(currentPos)
    table.insert(trapSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    
    -- Создаем дыры для всех сегментов ловушки (с уменьшенным радиусом)
    for _, pos in ipairs(trapSegments) do
        local radius = settings.minRadius * 0.8
        CreateHole(pos, radius)
        table.insert(allPositions, pos)
    end
    
    DebugLog("Created trap #" .. trapsCreated .. " at " .. VecStr(position))
    return currentPos
end

-- Создает тупик (короткий проход, заканчивающийся небольшой полостью)
function CreateDeadEnd(position, direction)
    deadEndsCreated = deadEndsCreated + 1
    
    local deadEndSegments = {}
    local currentPos = Vec(position[1], position[2], position[3])
    
    -- Создаем короткий проход
    local passageLength = math.random(2, 4)
    for i = 1, passageLength do
        currentPos = Vec(
            currentPos[1] + direction[1] * settings.stepSize,
            currentPos[2],
            currentPos[3] + direction[3] * settings.stepSize
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        table.insert(deadEndSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    end
    
    -- Создаем дыры для всех сегментов тупика
    for _, pos in ipairs(deadEndSegments) do
        local radius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius) * 0.5
        CreateHole(pos, radius)
        table.insert(allPositions, pos)
    end
    
    -- Создаем небольшую полость в конце тупика
    local endRadius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius)
    CreateHole(currentPos, endRadius)
    
    DebugLog("Created dead end #" .. deadEndsCreated .. " at " .. VecStr(position))
    return currentPos
end

-- Создает ответвление от основного пути
function CreateBranch(startPos, length, isSubBranch)
    if isSubBranch then
        subBranchesCreated = subBranchesCreated + 1
    else
        branchesCreated = branchesCreated + 1
    end
    
    local branchSegments = {}
    local currentPos = Vec(startPos[1], startPos[2], startPos[3])
    local direction = GetRandomDirection()
    
    -- Определяем, будет ли это тупик
    local isDeadEnd = math.random() < settings.deadEndChance
    
    if isDeadEnd then
        return CreateDeadEnd(currentPos, direction)
    end
    
    -- Создаем ответвление
    for i = 1, length do
        -- Возможное изменение направления
        if math.random() < settings.directionChangeChance then
            direction = GetRandomDirection()
        end
        
        -- Возможное вертикальное движение
        local verticalOffset = 0
        if math.random() < settings.verticalChance then
            if math.random() < settings.downwardBias then
                verticalOffset = -settings.stepSize * math.random() * 0.5
            else
                verticalOffset = settings.stepSize * math.random() * 0.3
            end
        end
        
        -- Вычисляем новую позицию
        currentPos = Vec(
            currentPos[1] + direction[1] * settings.stepSize,
            currentPos[2] + verticalOffset,
            currentPos[3] + direction[3] * settings.stepSize
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        
        -- Проверяем, не слишком ли близко к существующим туннелям
        if not IsPositionFarEnough(currentPos) then
            break
        end
        
        -- Определяем радиус туннеля (возможно узкий проход)
        local radius
        if math.random() < settings.narrowPassageChance then
            radius = settings.minRadius * 0.7
        else
            radius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius)
        end
        
        -- Создаем дыру
        CreateHole(currentPos, radius)
        table.insert(branchSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
        table.insert(allPositions, currentPos)
        
        -- Возможное создание комнаты
        if math.random() < settings.roomChance then
            CreateRoom(currentPos)
        end
        
        -- Возможное создание ловушки
        if math.random() < settings.trapChance then
            CreateTrap(currentPos, direction)
        end
        
        -- Возможное создание поддерживающей колонны
        if settings.supportPillars and i % settings.pillarSpacing == 0 and IsPositionFarFromPillars(currentPos) then
            CreateSupportPillar(currentPos, radius)
        end
        
        -- Возможное создание ответвления от ответвления (только если это не под-ответвление)
        if not isSubBranch and math.random() < settings.subBranchChance and subBranchesCreated < settings.maxSubBranches then
            CreateBranch(currentPos, math.random(5, settings.subBranchLength), true)
        end
    end
    
    local branchType = isSubBranch and "sub-branch" or "branch"
    DebugLog("Created " .. branchType .. " #" .. (isSubBranch and subBranchesCreated or branchesCreated) .. " with " .. #branchSegments .. " segments")
    return currentPos
end

-- Создает основной путь пещеры
function CreateMainPath(startPos)
    local mainPathSegments = {}
    local currentPos = Vec(startPos[1], startPos[2], startPos[3])
    local direction = GetRandomDirection()
    
    DebugLog("Creating main path with " .. settings.mainPathLength .. " segments...")
    
    for i = 1, settings.mainPathLength do
        -- Возможное изменение направления
        if math.random() < settings.directionChangeChance then
            direction = GetRandomDirection()
        end
        
        -- Возможное вертикальное движение
        local verticalOffset = 0
        if math.random() < settings.verticalChance then
            if math.random() < settings.downwardBias then
                verticalOffset = -settings.stepSize * math.random() * 0.5
            else
                verticalOffset = settings.stepSize * math.random() * 0.3
            end
        end
        
        -- Вычисляем новую позицию
        currentPos = Vec(
            currentPos[1] + direction[1] * settings.stepSize,
            currentPos[2] + verticalOffset,
            currentPos[3] + direction[3] * settings.stepSize
        )
        
        -- Проверяем и ограничиваем позицию
        currentPos = ClampToBounds(currentPos)
        
        -- Проверяем, не слишком ли близко к существующим туннелям
        if not IsPositionFarEnough(currentPos) then
            -- Пытаемся найти новое направление
            local foundNewDirection = false
            for _ = 1, 4 do
                direction = GetRandomDirection()
                local testPos = Vec(
                    currentPos[1] + direction[1] * settings.stepSize,
                    currentPos[2],
                    currentPos[3] + direction[3] * settings.stepSize
                )
                
                if IsPositionFarEnough(testPos) then
                    foundNewDirection = true
                    break
                end
            end
            
            if not foundNewDirection then
                DebugLog("Main path terminated early due to collision at segment " .. i)
                break
            end
        end
        
        -- Определяем радиус туннеля (возможно узкий проход)
        local radius
        if math.random() < settings.narrowPassageChance then
            radius = settings.minRadius * 0.7
        else
            radius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius)
        end
        
        -- Создаем дыру
        CreateHole(currentPos, radius)
        table.insert(mainPathSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
        table.insert(allPositions, currentPos)
        
        -- Возможное создание комнаты
        if math.random() < settings.roomChance then
            CreateRoom(currentPos)
        end
        
        -- Возможное создание ловушки
        if math.random() < settings.trapChance then
            CreateTrap(currentPos, direction)
        end
        
        -- Возможное создание поддерживающей колонны
        if settings.supportPillars and i % settings.pillarSpacing == 0 and IsPositionFarFromPillars(currentPos) then
            CreateSupportPillar(currentPos, radius)
        end
        
        -- Возможное создание ответвления
        if math.random() < settings.branchChance and branchesCreated < settings.maxBranches then
            CreateBranch(currentPos, math.random(10, settings.branchLength), false)
        end
    end
    
    DebugLog("Main path created with " .. #mainPathSegments .. " segments")
    return mainPathSegments
end

-- Выполняет дополнительные проходы для удаления обломков и сглаживания пещеры
function CleanupCave()
    DebugLog("Performing " .. settings.cleanupPasses .. " cleanup passes...")
    
    -- Кэшируем позиции для оптимизации
    local cleanupPositions = {}
    for _, pos in ipairs(allPositions) do
        table.insert(cleanupPositions, Vec(pos[1], pos[2], pos[3]))
    end
    
    -- Добавляем случайные позиции между существующими для лучшего сглаживания
    local positionsCount = #cleanupPositions
    for i = 1, positionsCount - 1 do
        local pos1 = cleanupPositions[i]
        local pos2 = cleanupPositions[i + 1]
        
        -- Вычисляем среднюю позицию
        local midPos = Vec(
            (pos1[1] + pos2[1]) * 0.5,
            (pos1[2] + pos2[2]) * 0.5,
            (pos1[3] + pos2[3]) * 0.5
        )
        
        table.insert(cleanupPositions, midPos)
    end
    
    -- Выполняем проходы очистки
    for pass = 1, settings.cleanupPasses do
        local voxelsRemovedInPass = 0
        
        for _, pos in ipairs(cleanupPositions) do
            -- Используем уменьшающийся радиус с каждым проходом для более тонкой очистки
            local radius = settings.minRadius * (1.0 - (pass - 1) / settings.cleanupPasses * 0.3)
            local voxelsRemoved = CreateHole(pos, radius)
            voxelsRemovedInPass = voxelsRemovedInPass + voxelsRemoved
        end
        
        DebugLog("Cleanup pass " .. pass .. " removed " .. voxelsRemovedInPass .. " voxels")
        
        -- Если в этом проходе не было удалено много вокселей, можно прервать очистку
        if voxelsRemovedInPass < 100 then
            DebugLog("Early termination of cleanup at pass " .. pass .. " due to minimal changes")
            break
        end
    end
end

-- Создает пещеру
function CreateCave()
    if caveCreated then
        DebugPrint("Cave already created!")
        return
    end
    
    -- Находим и объединяем объект "desert_base"
    local shape = FindShape("desert_base", true)
    if shape == 0 then
        DebugPrint("ERROR: Object 'desert_base' not found!")
        return
    else
        -- Объединяем форму с другими подходящими формами
        desertShape = shape
        
        -- Получаем и сохраняем границы объекта
        local boundsMin, boundsMax = GetShapeBounds(desertShape)
        if boundsMin and boundsMax then
            objectBounds.min = boundsMin
            objectBounds.max = boundsMax
            DebugPrint("Object bounds: min=" .. VecStr(boundsMin) .. ", max=" .. VecStr(boundsMax))
        else
            DebugPrint("WARNING: Failed to get shape bounds!")
            -- Устанавливаем примерные границы, чтобы скрипт не сломался
            objectBounds.min = Vec(-50, -50, -50)
            objectBounds.max = Vec(50, 50, 50)
        end
    end
    
    -- Сбрасываем счетчики и массивы
    allPositions = {}
    pillarPositions = {}
    totalVoxelsRemoved = 0
    branchesCreated = 0
    subBranchesCreated = 0
    roomsCreated = 0
    trapsCreated = 0
    deadEndsCreated = 0
    pillarsCreated = 0
    
    -- Создаем вход в пещеру и начальный спуск
    local startX = objectBounds.min[1] + settings.borderMargin + math.random() * (objectBounds.max[1] - objectBounds.min[1] - 2 * settings.borderMargin)
    local startZ = objectBounds.min[3] + settings.borderMargin + math.random() * (objectBounds.max[3] - objectBounds.min[3] - 2 * settings.borderMargin)
    local startY = objectBounds.max[2] - settings.startHeight
    
    local startPos = Vec(startX, startY, startZ)
    
    -- Определяем глубину спуска (если не задана)
    if settings.descentDepth <= 0 then
        settings.descentDepth = math.random(5, 15)
    end
    
    -- Создаем вход (большая дыра на поверхности)
    local entranceRadius = settings.maxRadius * 1.5
    MakeHole(startPos, entranceRadius, entranceRadius, entranceRadius, settings.silentRemoval)
    
    -- Создаем спуск выбранного типа
    local descentSegments = {}
    local currentPos = Vec(startPos[1], startPos[2], startPos[3])
    local direction = DIRECTIONS[math.random(1, #DIRECTIONS)]
    
    -- Создаем спуск (простая лестница для надежности)
    local stepsCount = math.floor(settings.descentDepth / 1.5)
    local verticalStep = settings.descentDepth / stepsCount
    
    for i = 1, stepsCount do
        -- Сначала шаг вперед
        currentPos = Vec(
            currentPos[1] + direction[1] * settings.stepSize,
            currentPos[2],
            currentPos[3] + direction[3] * settings.stepSize
        )
        
        -- Проверяем и ограничиваем позицию
        if currentPos[1] < objectBounds.min[1] + settings.borderMargin then currentPos[1] = objectBounds.min[1] + settings.borderMargin end
        if currentPos[1] > objectBounds.max[1] - settings.borderMargin then currentPos[1] = objectBounds.max[1] - settings.borderMargin end
        if currentPos[2] < objectBounds.min[2] + settings.borderMargin then currentPos[2] = objectBounds.min[2] + settings.borderMargin end
        if currentPos[2] > objectBounds.max[2] - settings.borderMargin then currentPos[2] = objectBounds.max[2] - settings.borderMargin end
        if currentPos[3] < objectBounds.min[3] + settings.borderMargin then currentPos[3] = objectBounds.min[3] + settings.borderMargin end
        if currentPos[3] > objectBounds.max[3] - settings.borderMargin then currentPos[3] = objectBounds.max[3] - settings.borderMargin end
        
        table.insert(descentSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
        
        -- Затем шаг вниз
        currentPos = Vec(
            currentPos[1],
            currentPos[2] - verticalStep,
            currentPos[3]
        )
        
        -- Проверяем и ограничиваем позицию
        if currentPos[1] < objectBounds.min[1] + settings.borderMargin then currentPos[1] = objectBounds.min[1] + settings.borderMargin end
        if currentPos[1] > objectBounds.max[1] - settings.borderMargin then currentPos[1] = objectBounds.max[1] - settings.borderMargin end
        if currentPos[2] < objectBounds.min[2] + settings.borderMargin then currentPos[2] = objectBounds.min[2] + settings.borderMargin end
        if currentPos[2] > objectBounds.max[2] - settings.borderMargin then currentPos[2] = objectBounds.max[2] - settings.borderMargin end
        if currentPos[3] < objectBounds.min[3] + settings.borderMargin then currentPos[3] = objectBounds.min[3] + settings.borderMargin end
        if currentPos[3] > objectBounds.max[3] - settings.borderMargin then currentPos[3] = objectBounds.max[3] - settings.borderMargin end
        
        table.insert(descentSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
    end
    
    -- Создаем дыры для всех сегментов спуска
    for _, pos in ipairs(descentSegments) do
        local radius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius)
        MakeHole(pos, radius, radius, radius, settings.silentRemoval)
        table.insert(allPositions, pos)
    end
    
    -- Создаем основной путь пещеры
    local mainPathSegments = {}
    direction = DIRECTIONS[math.random(1, #DIRECTIONS)]
    
    for i = 1, settings.mainPathLength do
        -- Возможное изменение направления
        if math.random() < settings.directionChangeChance then
            direction = DIRECTIONS[math.random(1, #DIRECTIONS)]
        end
        
        -- Возможное вертикальное движение
        local verticalOffset = 0
        if math.random() < settings.verticalChance then
            if math.random() < settings.downwardBias then
                verticalOffset = -settings.stepSize * math.random() * 0.5
            else
                verticalOffset = settings.stepSize * math.random() * 0.3
            end
        end
        
        -- Вычисляем новую позицию
        currentPos = Vec(
            currentPos[1] + direction[1] * settings.stepSize,
            currentPos[2] + verticalOffset,
            currentPos[3] + direction[3] * settings.stepSize
        )
        
        -- Проверяем и ограничиваем позицию
        if currentPos[1] < objectBounds.min[1] + settings.borderMargin then currentPos[1] = objectBounds.min[1] + settings.borderMargin end
        if currentPos[1] > objectBounds.max[1] - settings.borderMargin then currentPos[1] = objectBounds.max[1] - settings.borderMargin end
        if currentPos[2] < objectBounds.min[2] + settings.borderMargin then currentPos[2] = objectBounds.min[2] + settings.borderMargin end
        if currentPos[2] > objectBounds.max[2] - settings.borderMargin then currentPos[2] = objectBounds.max[2] - settings.borderMargin end
        if currentPos[3] < objectBounds.min[3] + settings.borderMargin then currentPos[3] = objectBounds.min[3] + settings.borderMargin end
        if currentPos[3] > objectBounds.max[3] - settings.borderMargin then currentPos[3] = objectBounds.max[3] - settings.borderMargin end
        
        -- Определяем радиус туннеля
        local radius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius)
        
        -- Создаем дыру
        MakeHole(currentPos, radius, radius, radius, settings.silentRemoval)
        table.insert(mainPathSegments, Vec(currentPos[1], currentPos[2], currentPos[3]))
        table.insert(allPositions, currentPos)
        
        -- Возможное создание комнаты
        if math.random() < settings.roomChance then
            -- Создаем комнату
            local roomRadius = settings.roomMinRadius + math.random() * (settings.roomMaxRadius - settings.roomMinRadius)
            MakeHole(currentPos, roomRadius, roomRadius, roomRadius, settings.silentRemoval)
            roomsCreated = roomsCreated + 1
        end
        
        -- Возможное создание ответвления
        if math.random() < settings.branchChance and branchesCreated < settings.maxBranches then
            -- Создаем ответвление
            local branchDir = DIRECTIONS[math.random(1, #DIRECTIONS)]
            local branchPos = Vec(currentPos[1], currentPos[2], currentPos[3])
            local branchLength = math.random(10, settings.branchLength)
            
            for j = 1, branchLength do
                branchPos = Vec(
                    branchPos[1] + branchDir[1] * settings.stepSize,
                    branchPos[2] + (math.random() - 0.5) * settings.stepSize * 0.5,
                    branchPos[3] + branchDir[3] * settings.stepSize
                )
                
                -- Проверяем и ограничиваем позицию
                if branchPos[1] < objectBounds.min[1] + settings.borderMargin then branchPos[1] = objectBounds.min[1] + settings.borderMargin end
                if branchPos[1] > objectBounds.max[1] - settings.borderMargin then branchPos[1] = objectBounds.max[1] - settings.borderMargin end
                if branchPos[2] < objectBounds.min[2] + settings.borderMargin then branchPos[2] = objectBounds.min[2] + settings.borderMargin end
                if branchPos[2] > objectBounds.max[2] - settings.borderMargin then branchPos[2] = objectBounds.max[2] - settings.borderMargin end
                if branchPos[3] < objectBounds.min[3] + settings.borderMargin then branchPos[3] = objectBounds.min[3] + settings.borderMargin end
                if branchPos[3] > objectBounds.max[3] - settings.borderMargin then branchPos[3] = objectBounds.max[3] - settings.borderMargin end
                
                local branchRadius = settings.minRadius + math.random() * (settings.maxRadius - settings.minRadius)
                MakeHole(branchPos, branchRadius, branchRadius, branchRadius, settings.silentRemoval)
                table.insert(allPositions, branchPos)
            end
            
            branchesCreated = branchesCreated + 1
        end
    end
    
    -- Выполняем дополнительные проходы для удаления обломков и сглаживания пещеры
    for pass = 1, settings.cleanupPasses do
        for _, pos in ipairs(allPositions) do
            local radius = settings.minRadius * 0.8
            MakeHole(pos, radius, radius, radius, settings.silentRemoval)
        end
    end
    
    -- Выводим статистику
    DebugPrint("Cave generation complete!")
    DebugPrint("Total positions: " .. #allPositions)
    DebugPrint("Branches created: " .. branchesCreated)
    DebugPrint("Rooms created: " .. roomsCreated)
    
    caveCreated = true
end

-- Инициализация
function init()
    -- Инициализируем генератор случайных чисел
    math.randomseed(63253)
    
    -- Выводим информацию о скрипте
    DebugLog("Cave Generator initialized. Press C to generate cave.")
end

-- Основной цикл
function tick()
    -- Создаем пещеру при нажатии клавиши C
    if InputPressed("c") then
        DebugLog("Starting cave generation...")
        CreateCave()
    end
    
    -- Отображаем подсказку
    if not caveCreated then
        DebugWatch("Press C to generate cave", "")
    else
        DebugWatch("Cave generated", "")
        DebugWatch("Total voxels removed", totalVoxelsRemoved)
        DebugWatch("Branches", branchesCreated)
        DebugWatch("Sub-branches", subBranchesCreated)
        DebugWatch("Rooms", roomsCreated)
        DebugWatch("Traps", trapsCreated)
        DebugWatch("Dead ends", deadEndsCreated)
        DebugWatch("Support pillars", pillarsCreated)
    end
end