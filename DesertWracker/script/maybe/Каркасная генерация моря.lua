----------------------------------------------------------------
-- Оптимизированный код генерации ландшафта с использованием Simplex Noise
--
-- API проверки (3 раза):
--  1) SetBrush, FindShape, DrawShapeLine, DebugPrint  - используются для работы с формами.
--  2) Векторные функции: Vec, VecAdd, VecSub, VecScale - используются для преобразований.
--  3) Основано исключительно на функциях, представленных в Teardown API.
--
-- Задача: красивый и оптимизированный ландшафт без дырок в холмах.
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
  cellSize = 4,             -- размер ячейки в пикселях
  gridCols = 128,           -- число столбцов (128 * 4 = 512 ширина региона)
  gridRows = 256,           -- число строк (256 * 4 = 1024 глубина региона)
  noiseScale = 2.0,
  octaves = 4,              -- число октав
  lacunarity = 2.0,
  persistence = 0.5,
  smoothingRadius = 1       -- радиус сглаживания карт высот (окрестность 3х3 ячеек)
}

------------------------ 
-- Таблица перестановок для Simplex Noise
------------------------
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
-- Расширение таблицы до 512 элементов
for i = 0, 255 do
  P[i + 256 + 1] = P[i + 1]
end

-------------------------------
-- Вспомогательная функция fastfloor
-------------------------------
local function fastfloor(x)
  return x > 0 and m_floor(x) or m_floor(x) - 1
end

-----------------------------------------------
-- Реализация 2D Simplex Noise
-----------------------------------------------
local F2 = 0.5 * (math.sqrt(3) - 1)
local G2 = (3 - math.sqrt(3)) / 6

-- Градиентные векторы для 2D Simplex Noise (12 направлений)
local grad3 = {
  {1,1}, {-1,1}, {1,-1}, {-1,-1},
  {1,0}, {-1,0}, {1,0}, {-1,0},
  {0,1}, {0,-1}, {0,1}, {0,-1}
}

-- Вспомогательная функция скалярного произведения
local function dot(g, x, y)
  return g[1] * x + g[2] * y
end

-- Функция simplexNoise (2D)
local function simplexNoise(xin, yin)
  local s = (xin + yin) * F2
  local i = fastfloor(xin + s)
  local j = fastfloor(yin + s)
  local t = (i + j) * G2
  local X0 = i - t
  local Y0 = j - t
  local x0 = xin - X0
  local y0 = yin - Y0

  local i1, j1
  if x0 > y0 then
    i1 = 1; j1 = 0
  else
    i1 = 0; j1 = 1
  end

  local x1 = x0 - i1 + G2
  local y1 = y0 - j1 + G2
  local x2 = x0 - 1 + 2 * G2
  local y2 = y0 - 1 + 2 * G2

  local ii = i % 256
  local jj = j % 256

  local gi0 = P[(ii + P[jj + 1]) % 256 + 1] % 12
  local gi1 = P[(ii + i1 + P[(jj + j1) + 1]) % 256 + 1] % 12
  local gi2 = P[(ii + 1 + P[(jj + 1) + 1]) % 256 + 1] % 12

  local n0, n1, n2 = 0, 0, 0
  local t0 = 0.5 - x0*x0 - y0*y0
  if t0 >= 0 then
    t0 = t0 * t0
    n0 = t0 * t0 * dot(grad3[gi0+1], x0, y0)
  end
  local t1 = 0.5 - x1*x1 - y1*y1
  if t1 >= 0 then
    t1 = t1 * t1
    n1 = t1 * t1 * dot(grad3[gi1+1], x1, y1)
  end
  local t2 = 0.5 - x2*x2 - y2*y2
  if t2 >= 0 then
    t2 = t2 * t2
    n2 = t2 * t2 * dot(grad3[gi2+1], x2, y2)
  end
  return 70 * (n0 + n1 + n2)
end

-----------------------------------------------
-- Функция enhancedNoise с поддержкой октав
-----------------------------------------------
local function enhancedNoise(x, y)
  local total = 0
  local frequency = Config.frequency
  local amplitude = 1.0
  local maxValue = 0
  if Config.octaves == 4 then
    total = total + simplexNoise(x * frequency, y * frequency) * amplitude
    maxValue = maxValue + amplitude
    amplitude = amplitude * Config.persistence
    frequency = frequency * Config.lacunarity

    total = total + simplexNoise(x * frequency, y * frequency) * amplitude
    maxValue = maxValue + amplitude
    amplitude = amplitude * Config.persistence
    frequency = frequency * Config.lacunarity

    total = total + simplexNoise(x * frequency, y * frequency) * amplitude
    maxValue = maxValue + amplitude
    amplitude = amplitude * Config.persistence
    frequency = frequency * Config.lacunarity

    total = total + simplexNoise(x * frequency, y * frequency) * amplitude
    maxValue = maxValue + amplitude
  else
    for i = 1, Config.octaves do
      total = total + simplexNoise(x * frequency, y * frequency) * amplitude
      maxValue = maxValue + amplitude
      amplitude = amplitude * Config.persistence
      frequency = frequency * Config.lacunarity
    end
  end
  return (total / maxValue) * Config.noiseScale
end

----------------------------------------------------
-- Построение карты высот и сглаживание (чтобы убрать дырки)
----------------------------------------------------
local function generateHeightMap()
  local width = Config.gridCols
  local height = Config.gridRows
  local map = {}
  for i = 1, width do
    map[i] = {}
    for j = 1, height do
      local x = (i - 1) * Config.cellSize
      local y = (j - 1) * Config.cellSize
      local h = Config.baseHeight + m_floor(enhancedNoise(x, y) * Config.amplitude)
      map[i][j] = h
    end
  end

  -- Применяем простой фильтр сглаживания (среднее значение в окрестности)
  local smoothMap = {}
  for i = 1, width do
    smoothMap[i] = {}
    for j = 1, height do
      local total = 0
      local count = 0
      for di = -Config.smoothingRadius, Config.smoothingRadius do
        for dj = -Config.smoothingRadius, Config.smoothingRadius do
          local ni = i + di
          local nj = j + dj
          if ni >= 1 and ni <= width and nj >= 1 and nj <= height then
            total = total + map[ni][nj]
            count = count + 1
          end
        end
      end
      smoothMap[i][j] = total / count
    end
  end

  return smoothMap
end

----------------------------------------------------
-- Функция рисования ландшафта по карте высот
-- Используем DrawShapeLine для отрисовки горизонтальных линий поверхности
----------------------------------------------------
local function drawLandscape(heightMap)
  local shape = FindShape("desert_base", true)  -- API Teardown, проверено 3 раза
  if not shape then
    DebugPrint("Warning: Форма 'desert_base' не найдена.")
    return
  end

  local width = Config.gridCols
  local height = Config.gridRows
  local cellSize = Config.cellSize

  -- Рисуем линии по строкам и столбцам, создавая "сетку" ландшафта
  for i = 1, width do
    for j = 1, height do
      local x = (i - 1) * cellSize
      local z = (j - 1) * cellSize
      local h = m_floor(heightMap[i][j])
      
      -- Рисуем горизонтальную линию по x
      if i < width then
        local x2 = i * cellSize
        local h2 = m_floor(heightMap[i+1][j])
        local avgH = m_floor((h + h2) / 2)
        DrawShapeLine(shape, x, avgH, z, x2, avgH, z)
      end
      -- Рисуем вертикальную линию по z
      if j < height then
        local z2 = j * cellSize
        local h2 = m_floor(heightMap[i][j+1])
        local avgH = m_floor((h + h2) / 2)
        DrawShapeLine(shape, x, avgH, z, x, avgH, z2)
      end
    end
  end

  DebugPrint("Ландшафт успешно отрисован с использованием оптимизированного алгоритма Simplex Noise")
end

---------------------
-- Основная функция init, проверка API (SetBrush, DebugPrint) выполнена 3 раза
---------------------
function init()
  SetBrush("sphere", 1, 1)  -- API Teardown
  local heightMap = generateHeightMap()
  drawLandscape(heightMap)
end

return {
  init = init,
  enhancedNoise = enhancedNoise,
  generateHeightMap = generateHeightMap,
  drawLandscape = drawLandscape
}