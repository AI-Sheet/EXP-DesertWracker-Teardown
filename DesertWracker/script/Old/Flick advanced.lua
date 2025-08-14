local red = {1.0, 0.0, 0.0}
local blue = {0.0, 0.5, 1.0}
local yellow = {1.0, 1.0, 0.0}

local painted = false
local cubePos = Vec(0, 5, 0)
local cubeBody = nil

-- Система весов (общая сумма = 100)
local colorWeights = {
    {color = red,   weight = 0},  -- Основной цвет
    {color = blue,  weight = 0},  -- Вторичный цвет
    {color = yellow,weight = 100}   -- Акцентный
}

-- Параметры для каждого цвета
local paintParams = {
    {
        radius = 4.2,
        density = 0.55,
        offsetRange = 7.5,
        layerCount = 3
    },
    {
        radius = 3.8,
        density = 0.65,
        offsetRange = 8.5,
        layerCount = 2
    },
    {
        radius = 2.5,
        density = 0.75,
        offsetRange = 9.0,
        layerCount = 1
    }
}

function init()
    local cubeData = [[<voxbox size='10 10 10' prop='true' material='hardmetal'/>]]
    cubeBody = Spawn(cubeData, Transform(cubePos))
end

function WeightedPaint(basePos)
    -- Нормализация весов
    local totalWeight = 0
    for _, cw in ipairs(colorWeights) do
        totalWeight = totalWeight + cw.weight
    end

    -- Главный цикл покраски
    for i = 1, 200 do  -- Общее количество точек
        -- Выбор цвета по весу
        local rnd = math.random(totalWeight)
        local selectedColor = colorWeights[1]
        
        for _, cw in ipairs(colorWeights) do
            rnd = rnd - cw.weight
            if rnd <= 0 then
                selectedColor = cw
                break
            end
        end

        -- Параметры для выбранного цвета
        local params = paintParams[selectedColor == red and 1 or (selectedColor == blue and 2 or 3)]
        
        -- Генерация позиции
        local offset = Vec(
            math.random(-params.offsetRange, params.offsetRange) * 0.65,
            math.random(-params.offsetRange, params.offsetRange) * 0.65,
            math.random(-params.offsetRange, params.offsetRange) * 0.65
        )
        
        -- Многослойное нанесение
        for l = 1, params.layerCount do
            local pos = VecAdd(basePos, offset)
            local layerRadius = params.radius * (1.1 - 0.15*l)
            PaintRGBA(pos, layerRadius, 
                selectedColor.color[1], selectedColor.color[2], selectedColor.color[3], 
                0.9 - 0.1*l, 
                params.density * (0.8 + 0.2*l))
        end
    end
end

function tick()
    if not painted then
        WeightedPaint(cubePos)
        
        -- Добавляем акценты поверх
        for i = 1, 40 do
            -- Синие акценты
            local offset = Vec(
                math.random(-8, 8),
                math.random(-8, 8),
                math.random(-8, 8)
            )
            PaintRGBA(VecAdd(cubePos, offset), 2.5, 
                blue[1], blue[2], blue[3], 0.9, 0.4)
            
            -- Жёлтые точки (1/4 случаев)
            if i % 4 == 0 then
                PaintRGBA(VecAdd(cubePos, offset), 1.2, 
                    yellow[1], yellow[2], yellow[3], 1.0, 0.3)
            end
        end
        painted = true
    end
end
