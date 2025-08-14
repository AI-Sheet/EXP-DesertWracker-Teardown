---@diagnostic disable: lowercase-global
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

local colorNames = {"red", "green", "yellow", "blue"}
local sortedColors = {}
local colorWeights = {}

local colors = {			 
    red = {value = {1.0, 0.0, 0.0}, weight = 0},			   
    green = {value = {0.05, 0.61, 0.07}, weight = 0},				
    yellow = {value = {1.0, 1.0, 0.0}, weight = 0},				  
    blue = {value = {0.07, 0.32, 0.56}, weight = 0}
}

-- Инициализация
function init()
    triggerHandle = FindTrigger(TRIGGER_NAME, true)
    for i = 1, 4 do
        sortedColors[i] = {value = {}, weight = 0}
    end
end

-- Обновление массы
function updateTotalMass()
    cachedTotalMass = 0
    local masses = {red = 0, green = 0, yellow = 0, blue = 0}
    local shapes = FindShapes("resy", true)
    local numShapes = #shapes
    local triggerHandleCache = triggerHandle
    
    for i = 1, numShapes do
        local shape = shapes[i]
        local body = GetShapeBody(shape)
        if IsBodyInTrigger(triggerHandleCache, body) then
            local mass = GetBodyMass(body)
            cachedTotalMass = cachedTotalMass + mass
            
            -- Быстрая проверка тегов
            for j = 1, 4 do
                local color = colorNames[j]
                if HasTag(shape, color) then
                    masses[color] = masses[color] + mass
                end
            end
        end
    end
    
    -- Обновление весов
    local sumMasses = masses.red + masses.green + masses.yellow + masses.blue
								   
    local sumInv = sumMasses > 0 and (100 / sumMasses) or 0
	   
    
    colors.red.weight = masses.red * sumInv
    colors.green.weight = masses.green * sumInv
    colors.yellow.weight = masses.yellow * sumInv
    colors.blue.weight = masses.blue * sumInv
								
		   
	   
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

function paintCube(shape)
    local min, max = GetShapeBounds(shape) -- Исправлено получение границ
    local rx, ry, rz = min[1], min[2], min[3] -- Разложение компонентов вектора							 
    local total = 0
    for i = 1, 4 do
        local color = colors[colorNames[i]]
        sortedColors[i].value = color.value
        sortedColors[i].weight = color.weight
        total = total + color.weight
    end
    
    if total <= 0 then
        total = 100
        sortedColors[1].weight = 100
    end
    
    -- Покраска с корректным вызовом PaintRGBA
    for x = 1, 10 do
        for y = 1, 10 do
            for z = 1, 10 do
                local rnd = math.random() * total
                local accum = 0
                local selected = sortedColors[1]
                
                for i = 1, 4 do
                    accum = accum + sortedColors[i].weight
                    if rnd <= accum then
                        selected = sortedColors[i]
                        break
                    end
                end
                
                -- Формируем позицию как VEC
                local pos = Vec(
                    rx + x - 0.5,
                    ry + y - 0.5,
                    rz + z - 0.5
                )
                
---@diagnostic disable-next-line: undefined-global
                PaintRGBA(
                    pos,
                    1.1,
                    selected.value[1],
                    selected.value[2],
                    selected.value[3],
                    1.0,
                    1.0
                )
            end
        end
    end
end

function deformCube(shape)
---@diagnostic disable-next-line: param-type-mismatch
    SetBrush("noise", 2, 0)
    for x = 0, 9 do
        for y = 0, 9 do
            for z = 0, 9 do
                if (x == 0 or x == 9 or y == 0 or y == 9 or z == 0 or z == 9) 
                   and math.random() < 0.4 then
                    DrawShapeBox(shape, x, y, z, x, y, z)
                end
            end
        end
    end
end

-- Переработка
function processRecycling()
    local toDelete = {}
    local shapes = FindShapes("resy", true)
    local numShapes = #shapes
    
    for i = 1, numShapes do
        local shape = shapes[i]
        local body = GetShapeBody(shape)
        if IsBodyInTrigger(triggerHandle, body) then
            toDelete[#toDelete + 1] = body
        end
    end
    
    for i = 1, #toDelete do
        Delete(toDelete[i])
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
    
    -- Блок информации
    UiPush()
        UiTranslate(50, 50)
        UiAlign("left")
        UiFont("regular.ttf", 34)
        UiText("Total: " .. math.floor(cachedTotalMass + leftoverMass) .. " kg")								  
        UiTranslate(0, 40)
        UiFont("regular.ttf", 24)
        for i = 1, 4 do
            local color = colors[colorNames[i]]
            UiText(colorNames[i] .. ": " .. string.format("%.1f%%", color.weight))
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

-- Основной цикл
function tick()
    local playerPos = GetPlayerTransform().pos
    local triggerPos = GetTriggerTransform(triggerHandle).pos
    local dx = playerPos[1] - triggerPos[1]
    local dz = playerPos[3] - triggerPos[3]
    local distSq = dx*dx + dz*dz
    
    if distSq < TRIGGER_RADIUS*TRIGGER_RADIUS then
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