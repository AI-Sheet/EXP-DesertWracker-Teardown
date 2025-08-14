-- Конфигурация
local TRIGGER_NAME = "trg"
local BASE_SPAWN_POS = Vec(0, 15, 0)
local SPAWN_OFFSET_RANGE = 2.0
local CUBE_MASS = 100
local TRIGGER_RADIUS = 30
local triggerHandle = 0
local cachedTotalMass = 0
local leftoverMass = 0
local showUI = false
local done = false

-- Система цветов
local colors = {
    red = {
        name = "red",
        value = {1.0, 0.0, 0.0},
        weight = 0
    },
    green = {
        name = "green",
        value = {0.05, 0.61, 0.07},
        weight = 0
    },
    yellow = {
        name = "yellow",
        value = {1.0, 1.0, 0.0},
        weight = 0
    },
    blue = {
        name = "blue",
        value = {0.07, 0.32, 0.56},
        weight = 0
    }
}

-- Инициализация
function init()
    triggerHandle = FindTrigger(TRIGGER_NAME, true)
end

-- Обновление массы
function updateTotalMass()
    cachedTotalMass = 0
    local masses = {}
    for colorName, _ in pairs(colors) do
        masses[colorName] = 0
    end
    
    local shapes = FindShapes("resy", true)
    for _, shape in ipairs(shapes) do
        local body = GetShapeBody(shape)
        if IsBodyInTrigger(triggerHandle, body) then
            local mass = GetBodyMass(body)
            cachedTotalMass = cachedTotalMass + mass
            
            -- Учет всех цветовых тегов объекта
            for colorName, _ in pairs(colors) do
                if HasTag(shape, colorName) then
                    masses[colorName] = masses[colorName] + mass
                end
            end
        end
    end
    
    -- Обновление весов
    local sumMasses = 0
    for _, mass in pairs(masses) do
        sumMasses = sumMasses + mass
    end
    
    for colorName, colorData in pairs(colors) do
        if sumMasses > 0 then
            colorData.weight = (masses[colorName] / sumMasses) * 100
        else
            colorData.weight = 0
        end
    end
end

-- Спавн куба
function spawnCube()
    local offset = Vec(
        math.random(-SPAWN_OFFSET_RANGE, SPAWN_OFFSET_RANGE),
        0,
        math.random(-SPAWN_OFFSET_RANGE, SPAWN_OFFSET_RANGE)
    )
    local spawnTransform = Transform(
        VecAdd(BASE_SPAWN_POS, offset),
        QuatEuler(math.random(0, 360), math.random(0, 360), math.random(0, 360)))
    
    local entities = Spawn([[<voxbox size='10 10 10' prop='true' material='hardmetal'/>]], spawnTransform)
    if #entities < 2 then return end
    
    local shape = entities[2]
    deformCube(shape)
    paintCube(shape)
    SetTag(shape, "sell")
end

-- Покраска куба
function paintCube(shape)
    local min, max = GetShapeBounds(shape)
    local center = VecLerp(min, max, 0.5)
    
    local sorted = {}
    for _, color in pairs(colors) do
        table.insert(sorted, color)
    end
    table.sort(sorted, function(a,b) return a.weight > b.weight end)
    
    -- Сумма всех весов
    local total = 0
    for _, color in ipairs(sorted) do
        total = total + color.weight
    end
    if total <= 0 then
        total = 100
        sorted[1].weight = 100
    end
    
    -- Покраска вокселей
    for x = 1, 10 do
        for y = 1, 10 do
            for z = 1, 10 do
                local rnd = math.random() * total
                local accum = 0
                local selected = sorted[1]
                
                for i = 1, #sorted do
                    accum = accum + sorted[i].weight
                    if rnd <= accum then
                        selected = sorted[i]
                        break
                    end
                end
                
                local pos = Vec(
                    min[1] + x - 0.5,
                    min[2] + y - 0.5,
                    min[3] + z - 0.5
                )
                
                PaintRGBA(
                    pos,
                    1.1,
                    selected.value[1],
                    selected.value[2],
                    selected.value[3],
                    1.0, 1.0
                )
            end
        end
    end
end

-- Деформация куба (остается без изменений)
function deformCube(shape)
    SetBrush("noise", 2, 0)
    for x = 0, 10 do
        for y = 0, 10 do
            for z = 0, 10 do
                if (x == 0 or x == 9 or y == 0 or y == 9 or z == 0 or z == 9) 
                   and math.random() < 0.4 then
                    DrawShapeBox(shape, x, y, z, x, y, z)
                end
            end
        end
    end
end

-- Переработка (остается без изменений)
function processRecycling()
    local toDelete = {}
    local shapes = FindShapes("resy", true)
    for _, shape in ipairs(shapes) do
        local body = GetShapeBody(shape)
        if IsBodyInTrigger(triggerHandle, body) then
            table.insert(toDelete, body)
        end
    end
    for _, body in ipairs(toDelete) do
        Delete(body)
    end
    
    local totalMass = cachedTotalMass + leftoverMass
    local cubesToSpawn = math.floor(totalMass / CUBE_MASS)
    leftoverMass = totalMass % CUBE_MASS
    cachedTotalMass = 0
    
    if cubesToSpawn > 0 then
        for i = 1, cubesToSpawn do
            spawnCube()
        end
    end
end

-- Интерфейс
function draw()
    if done or not showUI then return end
    UiMakeInteractive()
    
    -- Блок общей информации
    UiPush()
        UiTranslate(50, 50)
        UiAlign("left")
        UiFont("regular.ttf", 34)
        UiText("Total: " .. math.floor(cachedTotalMass + leftoverMass) .. " kg")
        
        -- Соотношение цветов
        UiTranslate(0, 40)
        UiFont("regular.ttf", 24)
        for _, colorName in ipairs({"red", "green", "yellow", "blue"}) do
            local color = colors[colorName]
            UiText(color.name .. ": " .. string.format("%.1f%%", color.weight))
            UiTranslate(0, 25)
        end
    UiPop()
    
    -- Блок кнопок
    UiPush()
        UiTranslate(UiCenter() - 150, UiMiddle() - 50)
        UiAlign("center")
        UiFont("regular.ttf", 34)
        local cubes = math.floor((cachedTotalMass + leftoverMass) / CUBE_MASS)
        if UiTextButton("Recycle (" .. cubes .. ")") then
            processRecycling()
            done = true
            showUI = false
        end
        UiTranslate(0, 40)
        if UiTextButton("Exit") then
            done = true
            showUI = false
        end
    UiPop()
end

-- Основной цикл (остается без изменений)
function tick()
    local playerPos = GetPlayerTransform().pos
    local triggerPos = GetTriggerTransform(triggerHandle).pos
    local dist = VecLength(VecSub(playerPos, triggerPos))
    
    if dist < TRIGGER_RADIUS then
        if InputPressed("interact") then
            updateTotalMass()
            showUI = true
            done = false
        end
    else
        showUI = false
        done = true
    end
end