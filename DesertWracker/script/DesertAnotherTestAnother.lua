----------------------------------------------------------------
-- Генерация инопланетных каркасных растений с проверкой поверхности
-- Оптимизированный код для создания экзотических структур только при наличии земли под ними
----------------------------------------------------------------

-- Кэширование глобальных функций для оптимизации
local m_floor = math.floor
local m_random = math.random
local m_sin = math.sin
local m_cos = math.cos
local m_rad = math.rad
local m_pi = math.pi

------------------------- 
-- Настройки конфигурации
-------------------------
local Config = {
  -- Основные параметры
  numPlants = 200,        -- Количество растений
  worldSize = 256,       -- Размер мира (1024x1024)
  
  -- Параметры растений
  minHeight = 10,         -- Минимальная высота растения
  maxHeight = 100,         -- Максимальная высота растения
  baseHeight = 50,         -- Базовая высота, на которой начинают генерироваться растения (на земле)
  
  -- Параметры ветвей
  minBranches = 5,        -- Минимальное количество основных ветвей
  maxBranches = 12,       -- Максимальное количество основных ветвей
  branchLength = 8,       -- Базовая длина ветви
  branchVariation = 6,    -- Вариация длины ветви
  
  -- Параметры подветвей
  subBranchChance = 0.5,  -- Вероятность появления подветвей (0-1)
  minSubBranches = 1,     -- Минимальное количество подветвей
  maxSubBranches = 4,     -- Максимальное количество подветвей
  
  -- Параметры каркасных структур
  minSegments = 4,        -- Минимальное количество сегментов в каркасе
  maxSegments = 10,       -- Максимальное количество сегментов в каркасе
  
  -- Включение/отключение типов растений
  enableTypes = {
    [2] = true,   -- Спиральная башня
    [3] = true,   -- Решетчатая структура
  }
}

----------------------------------------------------
-- Функция для рисования линии (ветви)
----------------------------------------------------
local function drawLine(shape, x1, y1, z1, x2, y2, z2)
  DrawShapeLine(shape, x1, y1, z1, x2, y2, z2)
end

----------------------------------------------------
-- Функция для создания спиральной башни
----------------------------------------------------
local function drawSpiralTower(shape, baseX, baseY, baseZ, height, radius)
  local turns = m_random(3, 6)
  local segments = m_random(Config.minSegments, Config.maxSegments)
  local verticalSegments = m_random(3, 6)
  
  -- Создаем спираль
  local prevX, prevY, prevZ = baseX, baseY, baseZ
  for i = 1, segments do
    local ratio = i / segments
    local angle = ratio * turns * 2 * m_pi
    local currRadius = radius * (1 - ratio * 0.3) -- Сужающаяся спираль
    local currHeight = baseY + height * ratio
    
    local x = baseX + currRadius * m_cos(angle)
    local z = baseZ + currRadius * m_sin(angle)
    
    drawLine(shape, prevX, prevY, prevZ, x, currHeight, z)
    prevX, prevY, prevZ = x, currHeight, z
  end
  
  -- Создаем вертикальные опоры
  for i = 1, verticalSegments do
    local angle = (i / verticalSegments) * 2 * m_pi
    local x = baseX + radius * 0.8 * m_cos(angle)
    local z = baseZ + radius * 0.8 * m_sin(angle)
    
    drawLine(shape, x, baseY, z, x, baseY + height, z)
    
    -- Добавляем горизонтальные соединения между опорами
    if i > 1 then
      local prevAngle = ((i-1) / verticalSegments) * 2 * m_pi
      local prevX = baseX + radius * 0.8 * m_cos(prevAngle)
      local prevZ = baseZ + radius * 0.8 * m_sin(prevAngle)
      
      -- Соединяем на нескольких уровнях
      local levels = m_random(1, 3)
      for level = 0, levels do
        local levelY = baseY + (height * level / levels)
        drawLine(shape, x, levelY, z, prevX, levelY, prevZ)
      end
    end
  end
  
  return true -- Всегда соединена с землей
end

----------------------------------------------------
-- Функция для создания решетчатой структуры
----------------------------------------------------
local function drawLatticeStructure(shape, x, y, z, width, height, depth)
  local halfWidth = width / 2
  local halfDepth = depth / 2
  
  -- Создаем вертикальные опоры по углам
  drawLine(shape, x - halfWidth, y, z - halfDepth, x - halfWidth, y + height, z - halfDepth)
  drawLine(shape, x + halfWidth, y, z - halfDepth, x + halfWidth, y + height, z - halfDepth)
  drawLine(shape, x + halfWidth, y, z + halfDepth, x + halfWidth, y + height, z + halfDepth)
  drawLine(shape, x - halfWidth, y, z + halfDepth, x - halfWidth, y + height, z + halfDepth)
  
  -- Добавляем горизонтальные перекладины на разных высотах
  local levels = m_random(2, 4)
  for i = 0, levels do
    local levelY = y + (height * i / levels)
    
    -- Рисуем горизонтальные перекладины
    drawLine(shape, x - halfWidth, levelY, z - halfDepth, x + halfWidth, levelY, z - halfDepth)
    drawLine(shape, x + halfWidth, levelY, z - halfDepth, x + halfWidth, levelY, z + halfDepth)
    drawLine(shape, x + halfWidth, levelY, z + halfDepth, x - halfWidth, levelY, z + halfDepth)
    drawLine(shape, x - halfWidth, levelY, z + halfDepth, x - halfWidth, levelY, z - halfDepth)
    
    -- Добавляем диагональные перекладины (не крестообразные)
    if m_random() < 0.5 then
      if m_random() < 0.5 then
        drawLine(shape, x - halfWidth, levelY, z - halfDepth, x + halfWidth, levelY, z + halfDepth)
      else
        drawLine(shape, x + halfWidth, levelY, z - halfDepth, x - halfWidth, levelY, z + halfDepth)
      end
    end
  end
  
  -- Добавляем вертикальные диагонали (не все сразу, чтобы избежать крестов)
  local diagonalCount = m_random(1, 2)
  local diagonals = {1, 2, 3, 4}
  
  -- Перемешиваем массив диагоналей
  for i = #diagonals, 2, -1 do
    local j = m_random(1, i)
    diagonals[i], diagonals[j] = diagonals[j], diagonals[i]
  end
  
  -- Рисуем только несколько случайных диагоналей
  for i = 1, diagonalCount do
    if diagonals[i] == 1 then
      drawLine(shape, x - halfWidth, y, z - halfDepth, x + halfWidth, y + height, z - halfDepth)
    elseif diagonals[i] == 2 then
      drawLine(shape, x + halfWidth, y, z - halfDepth, x + halfWidth, y + height, z + halfDepth)
    elseif diagonals[i] == 3 then
      drawLine(shape, x + halfWidth, y, z + halfDepth, x - halfWidth, y + height, z + halfDepth)
    else
      drawLine(shape, x - halfWidth, y, z + halfDepth, x - halfWidth, y + height, z - halfDepth)
    end
  end
  
  return true -- Всегда соединена с землей
end

----------------------------------------------------
-- Функция для генерации каркасных подветвей
----------------------------------------------------
local function generateWireframeSubBranches(shape, x, y, z, direction, length)
  local subBranchCount = m_random(Config.minSubBranches, Config.maxSubBranches)
  local connectedBranches = 0
  
  for i = 1, subBranchCount do
    -- Создаем случайное отклонение от основного направления
    local angleOffset = m_random(-45, 45)
    local newAngle = direction + angleOffset
    
    -- Вычисляем длину подветви
    local subLength = length * m_random(0.4, 0.8)
    
    -- Вычисляем конечную точку подветви
    local endX = x + subLength * m_cos(m_rad(newAngle))
    local endY = y + m_random(-2, 2) -- Небольшое отклонение по Y
    local endZ = z + subLength * m_sin(m_rad(newAngle))
    
    -- Проверяем, не слишком ли высоко поднимается ветвь
    if endY <= y + 3 then
      -- Рисуем подветвь
      drawLine(shape, x, y, z, endX, endY, endZ)
      connectedBranches = connectedBranches + 1
    end
  end
  
  return connectedBranches > 0
end

----------------------------------------------------
-- Функция для генерации одного инопланетного растения
----------------------------------------------------
local function generateAlienPlant(shape, x, y, z)
  -- Выбираем случайную высоту растения
  local plantHeight = m_random(Config.minHeight, Config.maxHeight)
  local topY = y
  local topX, topZ = x, z
  
  -- Определяем тип основной структуры
  local structureType
  repeat
    structureType = m_random(1, 5)
  until Config.enableTypes[structureType]
  
  local structureCreated = false
  
  if structureType == 2 then
    -- Спиральная башня
    structureCreated = drawSpiralTower(shape, x, y, z, plantHeight, plantHeight * 0.3)
  elseif structureType == 3 then
    -- Решетчатая структура
    local width = plantHeight * m_random(0.4, 0.8)
    local depth = width * m_random(0.8, 1.2)
    structureCreated = drawLatticeStructure(shape, x, y, z, width, plantHeight, depth)
  end
  
  -- Если структура не была создана, пропускаем дальнейшую генерацию
  if not structureCreated then
    return
  end
  
  -- Обновляем координаты вершины растения
  topY = y + plantHeight
  
  -- Генерация основных ветвей
  local branchCount = m_random(Config.minBranches, Config.maxBranches)
  
  for i = 1, branchCount do
    -- Выбираем точку на стволе для ветви
    local branchY = y + m_random(plantHeight * 0.3, plantHeight * 0.9)
    
    -- Выбираем случайный угол для ветви
    local angle = m_random(0, 360)
    
    -- Вычисляем длину ветви
    local branchLength = Config.branchLength + m_random(-Config.branchVariation, Config.branchVariation)
    
    -- Вычисляем координаты конца ветви
    local branchEndX = topX + branchLength * m_cos(m_rad(angle))
    local branchEndZ = topZ + branchLength * m_sin(m_rad(angle))
    local branchEndY = branchY + m_random(-3, 3)
    
    -- Проверяем, не слишком ли высоко поднимается ветвь
    if branchEndY <= branchY + 3 then
      -- Рисуем ветвь
      drawLine(shape, topX, branchY, topZ, branchEndX, branchEndY, branchEndZ)
      
      -- Генерируем подветви с определенной вероятностью
      if m_random() < Config.subBranchChance then
        generateWireframeSubBranches(shape, branchEndX, branchEndY, branchEndZ, angle, branchLength * 0.6)
      end
    end
  end
end

---------------------
-- Основная функция SpawnPlants с проверкой поверхности
---------------------
function SpawnPlants()
  -- Находим базовую форму
  local shape = FindShape("desert_base", true)
  if not shape then
    DebugPrint("Warning: Форма 'desert_base' не найдена.")
    return
  end
  
  -- Устанавливаем материал по умолчанию
  SetBrush("sphere", 1, 1)
  
  local halfWorld = Config.worldSize / 2
  
  for i = 1, Config.numPlants do
    -- Генерируем случайные координаты в пределах мира
    local x = m_random(-halfWorld, halfWorld)
    local z = m_random(-halfWorld, halfWorld)
    
    -- Проверяем наличие поверхности под точкой спавна:
    -- Кастуем луч сверху вниз от точки (x, baseHeight+50, z) до (x, baseHeight-50, z)
    local origin = Vec(x, Config.baseHeight + 50, z)
    local direction = Vec(0, -1, 0)
    local maxDist = 100
    local hit, dist = QueryRaycast(origin, direction, maxDist)
    
    if hit then
      local groundY = origin[2] - dist
      generateAlienPlant(shape, x, groundY, z)
    else
      DebugPrint("Пропуск растения в (" .. x .. ", " .. z .. ") - sosi.")
    end
  end
end

return {
  SpawnPlants = SpawnPlants
}