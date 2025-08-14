local colors = {
    {1.0, 1.0, 0.0}, -- Жёлтый
    {1.0, 0.0, 0.0}, -- Красный
    {0.0, 0.5, 1.0}  -- Голубой
}

local painted = false
local cubePos = Vec(0, 5, 0)

function init()
    local cubeData = [[<voxbox size='10 10 10' prop='true' material='hardmetal'/>]]
    Spawn(cubeData, Transform(cubePos))
end

function tick()
    if not painted then
        local mainColor = colors[math.random(1, 3)]
        local radius = 5.5
        local density = 0.35
        local iterations = 12  -- Увеличено количество слоев
        
        PaintRGBA(cubePos, radius, mainColor[1], mainColor[2], mainColor[3], 1.0, 0.65)

        for i = 1, iterations do
            local noiseColor = colors[math.random(1, 3)]
            -- Увеличиваем разброс смещений и радиус эффекта
            local offset = Vec(
                math.random(-7, 7) * 0.8,  -- Более плавное распределение
                math.random(-7, 7) * 0.8,
                math.random(-7, 7) * 0.8
            )
            local noisePos = VecAdd(cubePos, offset)
            
            -- Увеличиваем радиус и плотность шумового эффекта
            PaintRGBA(noisePos, 3.2,  -- Увеличенный радиус
                noiseColor[1], noiseColor[2], noiseColor[3], 
                0.85,  -- Небольшая прозрачность
                density + 0.15)  -- Повышенная плотность
        end
        
        painted = true
    end
end
