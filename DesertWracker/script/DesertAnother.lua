----------------------------------------------------------------
-- Desert Landscape Generation with Integrated Alien Plant Spawning
-- 
-- This module generates a desert landscape using Simplex Noise
-- (with smooth, drivable hills) and then spawns alien wireframe plants
-- on the correct terrain height (sampled from the generated height map).
--
-- IMPORTANT: Always cross-check with API TEARDOWN 1.6.0 for any changes.
----------------------------------------------------------------

------------------------- 
-- Caching Global Functions
-------------------------
local m_floor = math.floor
local m_min   = math.min
local m_max   = math.max
local m_sqrt  = math.sqrt
local m_sin   = math.sin
local m_cos   = math.cos
local m_rad   = math.rad
local m_random= math.random
local m_pi    = math.pi

------------------------- 
-- Combined Configuration
-------------------------
local Config = {
  -- Landscape configuration
  baseHeight      = 100,
  amplitude       = 12,            -- Reduced amplitude for lower height variation
  frequency       = 0.004,         -- Lower frequency for longer, smooth segments
  cellSize        = 8,
  gridCols        = 128,
  gridRows        = 128,
  noiseScale      = 2.0,
  octaves         = 4,
  lacunarity      = 2.0,
  persistence     = 0.5,           -- Softer transitions between octaves
  smoothingRadius = 4,             -- Increased radius for smoother transitions
  fillStep        = 1,
  xStretch        = 1.5,           -- X-axis scaling
  zStretch        = 1.0,           -- Z-axis scaling
  
  -- Plant configuration
  numPlants       = 30,         
  minPlantHeight  = 5,          -- Minimum plant height (unused, using height map value)
  maxPlantHeight  = 26,          -- Maximum plant height (unused, using height map value)
  minBranches     = 5,
  maxBranches     = 12,
  branchLength    = 8,
  branchVariation = 6,
  subBranchChance = 0.5,
  minSubBranches  = 1,
  maxSubBranches  = 4,
  enableTypes     = {
    [2] = true,   -- Spiral tower
    [3] = true    -- Lattice structure
  }
}

------------------------- 
-- Simplex Noise Permutation Table
-------------------------
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
  P[i + 256 + 1] = P[i + 1]
end

------------------------------- 
-- Fast Floor Function
-------------------------------
local function fastfloor(x)
  return x > 0 and m_floor(x) or m_floor(x) - 1
end

-----------------------------------------------
-- 2D Simplex Noise Implementation
-----------------------------------------------
local F2 = 0.5 * (m_sqrt(3) - 1)
local G2 = (3 - m_sqrt(3)) / 6

local grad3 = {
  {1,1}, {-1,1}, {1,-1}, {-1,-1},
  {1,0}, {-1,0}, {1,0}, {-1,0},
  {0,1}, {0,-1}, {0,1}, {0,-1}
}

local function dot(g, x, y)
  return g[1]*x + g[2]*y
end

local function simplexNoise(xin, yin)
  local s = (xin + yin) * F2
  local i = fastfloor(xin + s)
  local j = fastfloor(yin + s)
  local t = (i + j) * G2
  local X0 = i - t
  local Y0 = j - t
  local x0 = xin - X0
  local y0 = yin - Y0

  local i1, j1 = 0, 0
  if x0 > y0 then
    i1, j1 = 1, 0
  else
    i1, j1 = 0, 1
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
-- Enhanced Noise with Octaves
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
-- Generate Height Map with Smoothing Filter
----------------------------------------------------
local function generateHeightMap()
  local gridCols = Config.gridCols
  local gridRows = Config.gridRows
  local cellSize = Config.cellSize
  local baseHeight = Config.baseHeight
  local amplitude = Config.amplitude

  local map = {}
  for i = 1, gridCols do
    map[i] = {}
    local x = (i - 1) * cellSize * Config.xStretch  -- X-axis stretch
    for j = 1, gridRows do
      local z = (j - 1) * cellSize * Config.zStretch  -- Z-axis stretch
      local noiseVal = enhancedNoise(x, z)
      -- Apply smoothstep function for smoothing transitions
      local easedVal = noiseVal * noiseVal * (3 - 2 * noiseVal)
      map[i][j] = baseHeight + (easedVal * amplitude)
    end
  end

  local smoothMap = {}
  local radius = Config.smoothingRadius
  for i = 1, gridCols do
    smoothMap[i] = {}
    for j = 1, gridRows do
      local total, count = 0, 0
      for di = -radius, radius do
        local ni = i + di
        if ni >= 1 and ni <= gridCols then
          for dj = -radius, radius do
            local nj = j + dj
            if nj >= 1 and nj <= gridRows then
              total = total + map[ni][nj]
              count = count + 1
            end
          end
        end
      end
      smoothMap[i][j] = total / count
    end
  end
  return smoothMap
end

----------------------------------------------------
-- Functions to Draw Rectangular Faces
----------------------------------------------------
local function fillHorizontalRect(shape, startX, startZ, w, d, constY)
  for offset = 0, d, Config.fillStep do
    DrawShapeLine(shape, startX, constY, startZ + offset, startX + w, constY, startZ + offset)
  end
end

local function fillVerticalRectX(shape, constX, startY, startZ, h, d)
  for offset = 0, h, Config.fillStep do
    DrawShapeLine(shape, constX, startY + offset, startZ, constX, startY + offset, startZ + d)
  end
end

local function fillVerticalRectZ(shape, constZ, startX, startY, w, h)
  for offset = 0, h, Config.fillStep do
    DrawShapeLine(shape, startX, startY + offset, constZ, startX + w, startY + offset, constZ)
  end
end

----------------------------------------------------
-- Draw Faces for a Single Cell
----------------------------------------------------
local function drawCellFaces(shape, i, j, heightMap)
  local cellSize = Config.cellSize
  local x = (i - 1) * cellSize * Config.xStretch
  local z = (j - 1) * cellSize * Config.zStretch
  local h = m_floor(heightMap[i][j] + 0.5)
  
  -- Top face
  fillHorizontalRect(shape, x, z, cellSize * Config.xStretch, cellSize * Config.zStretch, h)
  
  local hLeft  = (i == 1)                and Config.baseHeight or m_floor(heightMap[i-1][j] + 0.5)
  local hRight = (i == Config.gridCols)    and Config.baseHeight or m_floor(heightMap[i+1][j] + 0.5)
  local hFront = (j == 1)                and Config.baseHeight or m_floor(heightMap[i][j-1] + 0.5)
  local hBack  = (j == Config.gridRows)    and Config.baseHeight or m_floor(heightMap[i][j+1] + 0.5)
  
  if h > hLeft then
    fillVerticalRectX(shape, x, hLeft, z, h - hLeft, cellSize * Config.zStretch)
  end
  if h > hRight then
    fillVerticalRectX(shape, x + cellSize * Config.xStretch, hRight, z, h - hRight, cellSize * Config.zStretch)
  end
  if h > hFront then
    fillVerticalRectZ(shape, z, x, hFront, cellSize * Config.xStretch, h - hFront)
  end
  if h > hBack then
    fillVerticalRectZ(shape, z + cellSize * Config.zStretch, x, hBack, cellSize * Config.xStretch, h - hBack)
  end
end

----------------------------------------------------
-- Draw the Entire Landscape
----------------------------------------------------
local function drawLandscape(heightMap)
  SetBrush("cube", 1, 1)
  local shape = FindShape("desert_base", true)
  if not shape then
    DebugPrint("Warning: Форма 'desert_base' не найдена.")
    return
  end
  
  for i = 1, Config.gridCols do
    for j = 1, Config.gridRows do
      drawCellFaces(shape, i, j, heightMap)
    end
  end
  DebugPrint("Пустынный ландшафт отрисован (плавные холмы для проходимости)")
end

----------------------------------------------------
-- Plant Generation Helper Functions
----------------------------------------------------
local function drawLine(shape, x1, y1, z1, x2, y2, z2)
  DrawShapeLine(shape, x1, y1, z1, x2, y2, z2)
end

local function drawSpiralTower(shape, baseX, baseY, baseZ, height, radius)
  local turns = m_random(3, 6)
  local segments = m_random(Config.minSubBranches, Config.maxSubBranches)  -- reuse as segments count
  local verticalSegments = m_random(3, 6)
  
  local prevX, prevY, prevZ = baseX, baseY, baseZ
  for i = 1, segments do
    local ratio = i / segments
    local angle = ratio * turns * 2 * m_pi
    local currRadius = radius * (1 - ratio * 0.3) -- narrowing spiral
    local currHeight = baseY + height * ratio
    
    local x = baseX + currRadius * m_cos(angle)
    local z = baseZ + currRadius * m_sin(angle)
    
    drawLine(shape, prevX, prevY, prevZ, x, currHeight, z)
    prevX, prevY, prevZ = x, currHeight, z
  end
  
  for i = 1, verticalSegments do
    local angle = (i / verticalSegments) * 2 * m_pi
    local x = baseX + radius * 0.8 * m_cos(angle)
    local z = baseZ + radius * 0.8 * m_sin(angle)
    
    drawLine(shape, x, baseY, z, x, baseY + height, z)
    if i > 1 then
      local prevAngle = ((i-1) / verticalSegments) * 2 * m_pi
      local prevX = baseX + radius * 0.8 * m_cos(prevAngle)
      local prevZ = baseZ + radius * 0.8 * m_sin(prevAngle)
      local levels = m_random(1, 3)
      for level = 0, levels do
        local levelY = baseY + (height * level / levels)
        drawLine(shape, x, levelY, z, prevX, levelY, prevZ)
      end
    end
  end
  
  return true
end

local function drawLatticeStructure(shape, x, y, z, width, height, depth)
  local halfWidth = width / 2
  local halfDepth = depth / 2
  
  drawLine(shape, x - halfWidth, y, z - halfDepth, x - halfWidth, y + height, z - halfDepth)
  drawLine(shape, x + halfWidth, y, z - halfDepth, x + halfWidth, y + height, z - halfDepth)
  drawLine(shape, x + halfWidth, y, z + halfDepth, x + halfWidth, y + height, z + halfDepth)
  drawLine(shape, x - halfWidth, y, z + halfDepth, x - halfWidth, y + height, z + halfDepth)
  
  local levels = m_random(2, 4)
  for i = 0, levels do
    local levelY = y + (height * i / levels)
    drawLine(shape, x - halfWidth, levelY, z - halfDepth, x + halfWidth, levelY, z - halfDepth)
    drawLine(shape, x + halfWidth, levelY, z - halfDepth, x + halfWidth, levelY, z + halfDepth)
    drawLine(shape, x + halfWidth, levelY, z + halfDepth, x - halfWidth, levelY, z + halfDepth)
    drawLine(shape, x - halfWidth, levelY, z + halfDepth, x - halfWidth, levelY, z - halfDepth)
    if m_random() < 0.5 then
      if m_random() < 0.5 then
        drawLine(shape, x - halfWidth, levelY, z - halfDepth, x + halfWidth, levelY, z + halfDepth)
      else
        drawLine(shape, x + halfWidth, levelY, z - halfDepth, x - halfWidth, levelY, z + halfDepth)
      end
    end
  end
  
  local diagonalCount = m_random(1, 2)
  local diagonals = {1, 2, 3, 4}
  for i = #diagonals, 2, -1 do
    local j = m_random(1, i)
    diagonals[i], diagonals[j] = diagonals[j], diagonals[i]
  end
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
  
  return true
end

local function generateWireframeSubBranches(shape, x, y, z, direction, length)
  local subBranchCount = m_random(Config.minSubBranches, Config.maxSubBranches)
  local connectedBranches = 0
  for i = 1, subBranchCount do
    local angleOffset = m_random(-45, 45)
    local newAngle = direction + angleOffset
    local subLength = length * m_random(0.4, 0.8)
    local endX = x + subLength * m_cos(m_rad(newAngle))
    local endY = y + m_random(-2, 2)
    local endZ = z + subLength * m_sin(m_rad(newAngle))
    if endY <= y + 3 then
      drawLine(shape, x, y, z, endX, endY, endZ)
      connectedBranches = connectedBranches + 1
    end
  end
  return connectedBranches > 0
end

local function generateAlienPlant(shape, x, y, z)
  local plantHeight = m_random(Config.minPlantHeight, Config.maxPlantHeight)
  local topX, topZ = x, z
  local structureType
  repeat
    structureType = m_random(1, 5)
  until Config.enableTypes[structureType]
  
  local structureCreated = false
  if structureType == 2 then
    structureCreated = drawSpiralTower(shape, x, y, z, plantHeight, plantHeight * 0.3)
  elseif structureType == 3 then
    local width = plantHeight * m_random(0.4, 0.8)
    local depth = width * m_random(0.8, 1.2)
    structureCreated = drawLatticeStructure(shape, x, y, z, width, plantHeight, depth)
  end
  
  if not structureCreated then
    return
  end
  
  local topY = y + plantHeight
  local branchCount = m_random(Config.minBranches, Config.maxBranches)
  for i = 1, branchCount do
    local branchY = y + m_random(plantHeight * 0.3, plantHeight * 0.9)
    local angle = m_random(0, 360)
    local branchLength = Config.branchLength + m_random(-Config.branchVariation, Config.branchVariation)
    local branchEndX = topX + branchLength * m_cos(m_rad(angle))
    local branchEndZ = topZ + branchLength * m_sin(m_rad(angle))
    local branchEndY = branchY + m_random(-3, 3)
    if branchEndY <= branchY + 3 then
      drawLine(shape, topX, branchY, topZ, branchEndX, branchEndY, branchEndZ)
      if m_random() < Config.subBranchChance then
        generateWireframeSubBranches(shape, branchEndX, branchEndY, branchEndZ, angle, branchLength * 0.6)
      end
    end
  end
end


----------------------------------------------------
-- Spawn Plants Based on Height Map (Avoiding Borders)
----------------------------------------------------
local function SpawnPlants(heightMap)
  local shape = FindShape("desert_base", true)
  if not shape then
    DebugPrint("Warning: Форма 'desert_base' не найдена.")
    return
  end
  SetBrush("sphere", 1, 4)
  
  local cellSize = Config.cellSize
  local worldWidth = Config.gridCols * cellSize * Config.xStretch
  local worldDepth = Config.gridRows * cellSize * Config.zStretch
  
  for i = 1, Config.numPlants do
    local x = m_random(0, worldWidth)
    local z = m_random(0, worldDepth)
    local gridX = m_floor(x / (cellSize * Config.xStretch)) + 1
    local gridZ = m_floor(z / (cellSize * Config.zStretch)) + 1
    if gridX < 1 then gridX = 1 end
    if gridX > Config.gridCols then gridX = Config.gridCols end
    if gridZ < 1 then gridZ = 1 end
    if gridZ > Config.gridRows then gridZ = Config.gridRows end

    -- Only spawn plants if not at the border cells
    if gridX ~= 1 and gridX ~= Config.gridCols and gridZ ~= 1 and gridZ ~= Config.gridRows then
      local groundY = heightMap[gridX][gridZ]
      generateAlienPlant(shape, x, groundY, z)
    else
      DebugPrint("Пропуск растения у границы (gridX: " .. gridX .. ", gridZ: " .. gridZ .. ")")
    end
  end
end

----------------------------------------------------
-- Main Initialization Function
----------------------------------------------------
function init()
  -- Set initial brush for landscape rendering
  local heightMap = generateHeightMap()
  drawLandscape(heightMap)
  -- Spawn plants after landscape generation, using the height map for accurate placement.
  SpawnPlants(heightMap)
end
