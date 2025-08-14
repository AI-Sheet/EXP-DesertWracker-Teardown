local colors = {
    {1.0, 1.0, 0.0}, -- Желтый
    {1.0, 0.0, 0.0}, -- Красный
    {0.0, 0.5, 1.0}  -- Голубой (для лучшего контраста)
}

local painted = false
local cubePos = Vec(0, 5, 0)

function init()
    -- Спавн куба
    local cubeData = [[<voxbox size='10 10 10' prop='true' material='hardmetal'/>]]
    Spawn(cubeData, Transform(cubePos))
end

function tick()
    if not painted then
        -- Выбираем случайный основной цвет
        local mainColor = colors[math.random(1, 3)]
        
        -- Параметры рисования
        local radius = 5.5     -- Радиус покрытия
        local density = 0.35   -- Плотность зернистости (0-1)
        local iterations = 8   -- Количество слоев шума
        
        -- Основной слой цвета
        PaintRGBA(cubePos, radius, mainColor[1], mainColor[2], mainColor[3], 1.0, 0.7)
        
        -- Добавляем шум из других цветов
        for i = 1, iterations do
            local noiseColor = colors[math.random(1, 3)]
            local noisePos = cubePos + Vec(
                math.random(-5, 5),
                math.random(-5, 5),
                math.random(-5, 5)
            )
            PaintRGBA(noisePos, 2.5, noiseColor[1], noiseColor[2], noiseColor[3], 0.8, density)
        end
        
        painted = true -- Помечаем как окрашенный
    end
end
