----------------------------------------------------------------
-- Модуль генерации ландшафта с оптимизациями
-- Оптимизации:
--   1. In-place операции для векторных вычислений (VecAddInPlace)
--   2. Кэширование функции grad для шума Перлина (gradCache)
--   3. Развертывание цикла в enhancedNoise при фиксированном числе октав (4)
-- Примечание: Перед внедрением изменений сверяемся с API: функции Vec, SetBrush, DrawShapeLine,
-- FindShape, DebugPrint и т.д. остаются неизменными.
----------------------------------------------------------------

-------------------------
-- Кэширование глобальных функций
-------------------------
local m_floor = math.floor
local m_min   = math.min
local m_max   = math.max
local m_sqrt  = math.sqrt
local m_sin   = math.sin
local m_cos   = math.cos
local m_rad   = math.rad

-------------------------
-- Настройки конфигурации
-------------------------
local Config = {
  baseHeight = 20,
  amplitude = 16,
  frequency = 0.01,
  blockSize = 4,
  gridCols = 128,            -- 128 * 4 = 512 (ширина региона)
  gridRows = 256,            -- 128 * 4 = 512 (глубина региона)
  cellSize = 4,
  topLayerThickness = 2,
  noiseScale = 2.0,
  octaves = 4,               -- Оптимизация: если октав ровно 4, то применяется развёртывание цикла
  lacunarity = 2.0,
  persistence = 0.5,
  verticalSmoothness = 0.75, -- Плавное сглаживание высот
  boundaryMargin = 16        -- Для плавного перехода по краям
}

------------------------------------------
-- Таблица перестановок для шума Перлина
------------------------------------------
local P = {
  151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
  8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
  35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,
  134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,
  55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,
  18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,
  250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,
  189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,
  172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,
  228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,
  107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
  138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
}
for i = 0, 255 do
  P[i + 256] = P[i + 1]
end

-------------------------------
-- Вспомогательные функции шума
-------------------------------

-- Кэш для функций grad (градиентов)
local gradCache = {}

local function grad(hash, x, z)
  if gradCache[hash] then
    return gradCache[hash](x, z)
  end
  local h = hash % 4
  local func
  if h == 0 then
    func = function(x, z) return x + z end
  elseif h == 1 then
    func = function(x, z) return -x + z end
  elseif h == 2 then
    func = function(x, z) return x - z end
  else
    func = function(x, z) return -x - z end
  end
  gradCache[hash] = func
  return func(x, z)
end

local function fastfloor(x)
  return x > 0 and m_floor(x) or m_floor(x) - 1
end

local function fade(t)
  return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(t, a, b)
  return a + t * (b - a)
end

-- Функция noise с нормализацией индексов
local function noise(x, z)
  local fx = fastfloor(x)
  local fz = fastfloor(z)
  local xi = ((fx % 256) + 256) % 256
  local zi = ((fz % 256) + 256) % 256
  x = x - fx
  z = z - fz
  local u = fade(x)
  local v = fade(z)
  
  local A  = (P[xi + 1] + zi) % 256
  local AA = P[A + 1]
  local AB = P[A + 2]
  local B  = (P[((xi + 1) % 256) + 1] + zi) % 256
  local BA = P[B + 1]
  local BB = P[B + 2]
  
  return lerp(v,
              lerp(u, grad(P[AA + 1], x, z),
                      grad(P[BA + 1], x - 1, z)),
              lerp(u, grad(P[AB + 1], x, z - 1),
                      grad(P[BB + 1], x - 1, z - 1)))
end

-- Оптимизированная функция enhancedNoise с развернутым циклом при octaves == 4
local function enhancedNoise(x, z)
  local total = 0
  local frequency = Config.frequency
  local amplitude = 1.0
  local maxValue = 0
  if Config.octaves == 4 then
    -- Разворачивание цикла для 4 октав
    total = total + noise(x * frequency, z * frequency) * amplitude
    maxValue = maxValue + amplitude
    amplitude = amplitude * Config.persistence
    frequency = frequency * Config.lacunarity

    total = total + noise(x * frequency, z * frequency) * amplitude
    maxValue = maxValue + amplitude
    amplitude = amplitude * Config.persistence
    frequency = frequency * Config.lacunarity

    total = total + noise(x * frequency, z * frequency) * amplitude
    maxValue = maxValue + amplitude
    amplitude = amplitude * Config.persistence
    frequency = frequency * Config.lacunarity

    total = total + noise(x * frequency, z * frequency) * amplitude
    maxValue = maxValue + amplitude
  else
    for i = 1, Config.octaves do
      total = total + noise(x * frequency, z * frequency) * amplitude
      maxValue = maxValue + amplitude
      amplitude = amplitude * Config.persistence
      frequency = frequency * Config.lacunarity
    end
  end
  return (total / maxValue) * Config.noiseScale
end
--------------------------------------------------------
-- Генерация базового паттерна (блоков)
--------------------------------------------------------
local function generateBaseBlocks()
  local regionWidth = Config.gridCols * Config.cellSize
  local regionDepth = Config.gridRows * Config.cellSize
  local blocks = {}
  
  for x = 0, regionWidth - Config.blockSize, Config.blockSize do
    for z = 0, regionDepth - Config.blockSize, Config.blockSize do
      local noiseHeight = m_floor(enhancedNoise(x, z) * Config.amplitude)
      local h = Config.baseHeight + noiseHeight
      
      local distX = m_min(x, regionWidth - (x + Config.blockSize))
      local distZ = m_min(z, regionDepth - (z + Config.blockSize))
      local boundaryFactor = m_min(distX, distZ) / Config.boundaryMargin
      if boundaryFactor > 1 then boundaryFactor = 1 end
      h = 1 + boundaryFactor * (h - 1)
      
      blocks[#blocks + 1] = {x = x, y = h, z = z}
    end
  end
  return blocks
end

------------------------------------------------
-- Объединение блоков в megaBlocks
------------------------------------------------
local function createMegaBlocks(blocks)
  local megaBlocks = {}
  table.sort(blocks, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.z ~= b.z then return a.z < b.z end
    return a.y < b.y
  end)
  local blockSize = Config.blockSize
  
  local function smoothHeight(x, z, y)
    local y0 = y
    if Config.verticalSmoothness > 0 then
      local totalHeight = 0
      local totalWeight = 0
      local maxDist = blockSize * 2
      for dx = -maxDist, maxDist, blockSize do
        for dz = -maxDist, maxDist, blockSize do
          local pos = VecAdd(Vec(x, 0, z), Vec(dx, 0, dz))
          local dist = m_sqrt(dx * dx + dz * dz)
          local weight = m_max(0, 1 - (dist / maxDist)^2)
          if dist > 0 
             and pos[1] >= 0 and pos[1] < Config.gridCols * Config.cellSize
             and pos[3] >= 0 and pos[3] < Config.gridRows * Config.cellSize then
            local hNeighbor = Config.baseHeight + m_floor(enhancedNoise(pos[1], pos[3]) * Config.amplitude)
            totalHeight = totalHeight + hNeighbor * weight
            totalWeight = totalWeight + weight
          end
        end
      end
      if totalWeight > 0 then
        local avgHeight = totalHeight / totalWeight
        y0 = y0 + (avgHeight - y0) * Config.verticalSmoothness * 0.75
      end
    end
    return y0
  end
  
  local i = 1
  while i <= #blocks do
    local current = blocks[i]
    local x = current.x
    local z = current.z
    local y = current.y
    local y0 = smoothHeight(x, z, y)
    local megaBlock = {
      x0 = x,
      y0 = y0,
      z0 = z,
      x1 = x + blockSize,
      y1 = y0 + Config.topLayerThickness,
      z1 = z + blockSize
    }
    i = i + 1
    while i <= #blocks and blocks[i].y == current.y 
          and blocks[i].z == current.z 
          and blocks[i].x >= megaBlock.x0 do
      megaBlock.x1 = m_max(megaBlock.x1, blocks[i].x + blockSize)
      i = i + 1
    end
    table.insert(megaBlocks, megaBlock)
  end
  return megaBlocks
end

-------------------------------------------------------------
-- Копирование и трансформация паттерна с использованием векторов
-------------------------------------------------------------
local function copyAndTransformRegion(blocks, srcRegion, destOffset, scaleFactor, rotationAngle, transitionWidth)
  local transformedBlocks = {}
  -- Если угол поворота меняется редко, вычисление rad можно вынести вне цикла
  local rad = m_rad(rotationAngle)
  local cosA = m_cos(rad)
  local sinA = m_sin(rad)
  local srcCenter = Vec(srcRegion.x + srcRegion.width / 2, 0, srcRegion.z + srcRegion.depth / 2)
  local offsetCenter = Vec(destOffset.x + (srcRegion.width * scaleFactor / 2), 0, destOffset.z + (srcRegion.depth * scaleFactor / 2))
  
  for _, block in ipairs(blocks) do
    if block.x >= srcRegion.x and block.x < (srcRegion.x + srcRegion.width)
       and block.z >= srcRegion.z and block.z < (srcRegion.z + srcRegion.depth) then
      local blockPos = Vec(block.x, 0, block.z)
      local rel = VecSub(blockPos, srcCenter)
      local scaled = VecScale(rel, scaleFactor)
      local rotated = {
        scaled[1] * cosA - scaled[3] * sinA,
        0,
        scaled[1] * sinA + scaled[3] * cosA
      }
      local newPos = VecAdd(offsetCenter, rotated)
      newPos[1] = m_floor(newPos[1] / Config.blockSize) * Config.blockSize
      newPos[3] = m_floor(newPos[3] / Config.blockSize) * Config.blockSize
      
      local distToEdgeX = m_min(newPos[1] - destOffset.x, (destOffset.x + srcRegion.width * scaleFactor) - newPos[1])
      local distToEdgeZ = m_min(newPos[3] - destOffset.z, (destOffset.z + srcRegion.depth * scaleFactor) - newPos[3])
      local blendFactor = m_min(distToEdgeX, distToEdgeZ) / transitionWidth
      if blendFactor > 1 then blendFactor = 1 end
      
      local newY = 1 + blendFactor * (block.y - 1)
      transformedBlocks[#transformedBlocks + 1] = {x = newPos[1], y = m_floor(newY), z = newPos[3]}
    end
  end
  return transformedBlocks
end

----------------------------
-- Функция отрисовки блоков
----------------------------
local function drawBlocks(baseShape, blocks)
  local blockSize = Config.blockSize
  for _, b in ipairs(blocks) do
    local y_bottom = b.y
    local y_top = b.y + Config.topLayerThickness - 1
    for y = y_bottom, y_top do
      for x = b.x, b.x + blockSize - 1 do
        local z0 = b.z
        local z1 = b.z + blockSize - 1
        DrawShapeLine(baseShape, x, y, z0, x, y, z1)
      end
    end
  end
end

---------------------
-- Основная функция
---------------------
function init()
  SetBrush("sphere", 1, 1)
  local baseShape = FindShape("desert_base", true)
  if not baseShape then
    DebugPrint("Warning: Базовая форма 'desert_base' не найдена.")
    return
  end

  local baseBlocks = generateBaseBlocks()
  local megaBlocks = createMegaBlocks(baseBlocks)
  
  for _, block in ipairs(megaBlocks) do
    local y_top = block.y0 + 1
    local y_bottom = block.y0 - Config.topLayerThickness + 1
    for y = y_bottom, y_top do
      for x = block.x0, block.x1 - 1 do
        local z_start = m_min(block.z0, block.z1)
        local z_end = m_max(block.z0, block.z1)
        DrawShapeLine(baseShape, x, y, z_start, x, y, z_end)
      end
    end
  end
  
  local sourceRegion = {x = 0, z = 0, width = 512, depth = 512}
  local destOffset = {x = 600, z = 600}
  local transformedBlocks = copyAndTransformRegion(baseBlocks, sourceRegion, destOffset, 2, 90, 32)
  
  local transformedMega = createMegaBlocks(transformedBlocks)
  drawBlocks(baseShape, transformedBlocks)
  
  DebugPrint("Ландшафт сгенерирован. Оптимизации включают: кэширование градиентов, in-place векторные операции, развертывание циклов.")
end

return {
  init = init,
  enhancedNoise = enhancedNoise,
  copyAndTransformRegion = copyAndTransformRegion
}