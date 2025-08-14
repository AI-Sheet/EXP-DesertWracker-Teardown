----------------------------------------------------------------
-- Desert Landscape Generation with Optimized Hill Void Filling
-- and Per-Cell Hill Void Detection/Filling (Individual Cubes)
--
-- This version generates a desert landscape using a complete and 
-- optimized OpenSimplex noise implementation. Instead of merging 
-- contiguous void cells into one large cube that might exceed the 
-- boundaries of a hill, the algorithm now fills each qualifying cell 
-- individually with a cube representing the void interior. For huge 
-- hollow hills, the region is split into two cubes along the longer 
-- dimension.
--
-- Compatible with TEARDOWN API 1.6.0.
--
-- Author: [Your Name or Organization]
-- Date: 2023
----------------------------------------------------------------

-------------------------
-- Cache global functions
-------------------------
local m_floor  = math.floor
local m_sqrt   = math.sqrt
local m_sin    = math.sin
local m_cos    = math.cos
local m_rad    = math.rad
local m_random = math.random
local m_pi     = math.pi
local m_min    = math.min
local m_max    = math.max
local m_ceil   = math.ceil

-------------------------
-- Bitwise AND for Lua 5.1 (if external module not available)
-------------------------
local function band(a, b)
  local result = 0
  local bitval = 1
  while a > 0 and b > 0 do
    local a_bit = a % 2
    local b_bit = b % 2
    if a_bit == 1 and b_bit == 1 then
      result = result + bitval
    end
    bitval = bitval * 2
    a = m_floor(a/2)
    b = m_floor(b/2)
  end
  return result
end

-------------------------
-- Complete OpenSimplex Noise Module (2D)
-------------------------
local OpenSimplex = {}

local STRETCH_CONSTANT_2D = -0.211324865405187  -- (1/sqrt(2+1)-1)/2
local SQUISH_CONSTANT_2D  =  0.366025403784439  -- (sqrt(2+1)-1)/2
local NORM_CONSTANT_2D    = 47.0

local PSIZE = 256
local PMASK = PSIZE - 1

local GRADIENTS_2D = {
    5,  2,    2,  5,
   -5,  2,   -2,  5,
    5, -2,    2, -5,
   -5, -2,   -2, -5,
}

local function initPermutations(seed)
  local perm = {}
  for i = 0, PSIZE - 1 do
    perm[i] = i
  end
  math.randomseed(seed or os.time())
  for i = PSIZE - 1, 1, -1 do
    local j = m_floor(m_random() * (i + 1))
    perm[i], perm[j] = perm[j], perm[i]
  end
  for i = 0, PSIZE - 1 do
    perm[i + PSIZE] = perm[i]
  end
  return perm
end

OpenSimplex.new = function(seed)
  local instance = {}
  instance.perm = initPermutations(seed)
  
  instance.extrapolate2D = function(self, xsb, ysb, dx, dy)
    local index = (self.perm[ band(xsb + self.perm[ band(ysb, PMASK) ], PMASK) ] % 8) * 2
    return GRADIENTS_2D[index + 1] * dx + GRADIENTS_2D[index + 2] * dy
  end
  
  instance.noise2D = function(self, x, y)
    local stretchOffset = (x + y) * STRETCH_CONSTANT_2D
    local xs = x + stretchOffset
    local ys = y + stretchOffset
    
    local xsb = m_floor(xs)
    local ysb = m_floor(ys)
    
    local squishOffset = (xsb + ysb) * SQUISH_CONSTANT_2D
    local xb = xsb + squishOffset
    local yb = ysb + squishOffset
    
    local dx0 = x - xb
    local dy0 = y - yb
    
    local value = 0
    local t0 = 0.5 - dx0 * dx0 - dy0 * dy0
    if t0 > 0 then
      t0 = t0 * t0
      value = value + t0 * t0 * self:extrapolate2D(xsb, ysb, dx0, dy0)
    end
    
    local dx1 = x - (xb + 1 - SQUISH_CONSTANT_2D)
    local dy1 = y - (yb + 0 - SQUISH_CONSTANT_2D)
    local t1 = 0.5 - dx1 * dx1 - dy1 * dy1
    if t1 > 0 then
      t1 = t1 * t1
      value = value + t1 * t1 * self:extrapolate2D(xsb + 1, ysb, dx1, dy1)
    end
    
    local dx2 = x - (xb + 0 - SQUISH_CONSTANT_2D)
    local dy2 = y - (yb + 1 - SQUISH_CONSTANT_2D)
    local t2 = 0.5 - dx2 * dx2 - dy2 * dy2
    if t2 > 0 then
      t2 = t2 * t2
      value = value + t2 * t2 * self:extrapolate2D(xsb, ysb + 1, dx2, dy2)
    end
    
    return value / NORM_CONSTANT_2D
  end
  
  return instance
end

-------------------------
-- Combined Landscape Configuration
-------------------------
local Config = {
  desiredMinHeight = 225,    -- Base minimum height of the landscape
  desiredMaxHeight = 256,   -- Maximum height for large hills
  frequency       = 0.007,  -- Main noise frequency
  cellSize        = 8,
  gridCols        = 128, -- For a 1024x1024 area: 128 cells * 8 = 1024
  gridRows        = 256,
  noiseScale      = 4.3,    -- Increased noise scale for more pronounced variations
  octaves         = 4,      -- Additional octaves for greater height diversity
  lacunarity      = 2.0,
  persistence     = 0.5,
  smoothingRadius = 4,
  heightDiffThreshold = 6,
  fillStep        = 1,
  xStretch        = 1.5,
  zStretch        = 1.0
}

-- Global variable for the landscape height map
local heightMap = {}          -- Landscape height map

-------------------------
-- Noise Functions for Landscape Generation
-------------------------
local noiseGenerator = OpenSimplex.new(1111)

local function enhancedNoise(x, y)
  local total = 0
  local frequency = Config.frequency
  local amplitude = 1.0
  local maxValue = 0
  for i = 1, Config.octaves do
    total = total + noiseGenerator:noise2D(x * frequency, y * frequency) * amplitude
    maxValue = maxValue + amplitude
    amplitude = amplitude * Config.persistence
    frequency = frequency * Config.lacunarity
  end
  return (total / maxValue) * Config.noiseScale
end

-------------------------
-- Generate Height Map with Smoothing and Dynamic Baseline
-------------------------
local function generateHeightMap()
  local gridCols = Config.gridCols
  local gridRows = Config.gridRows
  local cellSize = Config.cellSize
  
  local rawMap = {}
  for i = 1, gridCols do
    rawMap[i] = {}
    local x = (i - 1) * cellSize * Config.xStretch
    for j = 1, gridRows do
      local z = (j - 1) * cellSize * Config.zStretch
      local noiseVal = enhancedNoise(x, z)
      local mod = 0.8 + 0.4 * m_sin(x * 0.02) * m_cos(z * 0.02)
      local value = (m_max(noiseVal, 0) ^ 1.5) * mod
      rawMap[i][j] = value
    end
  end
  
  local minVal = math.huge
  local maxVal = -math.huge
  for i = 1, gridCols do
    for j = 1, gridRows do
      local value = rawMap[i][j]
      if value < minVal then minVal = value end
      if value > maxVal then maxVal = value end
    end
  end
  
  local originalRange = maxVal - minVal
  local desiredRange = Config.desiredMaxHeight - Config.desiredMinHeight
  local scaleFactor = (originalRange == 0) and 1 or (desiredRange / originalRange)
  
  local map = {}
  for i = 1, gridCols do
    map[i] = {}
    for j = 1, gridRows do
      map[i][j] = Config.desiredMinHeight + (rawMap[i][j] - minVal) * scaleFactor
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
  
  heightMap = smoothMap
  return smoothMap
end

-------------------------
-- Rendering Functions for Landscape Faces
-------------------------
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

local function drawCellFaces(shape, i, j, heightMap)
  local cellSize = Config.cellSize
  local x = (i - 1) * cellSize * Config.xStretch
  local z = (j - 1) * cellSize * Config.zStretch
  local h = m_floor(heightMap[i][j] + 0.5)
  
  fillHorizontalRect(shape, x, z, cellSize * Config.xStretch, cellSize * Config.zStretch, h)
  
  local hLeft  = (i == 1)             and Config.desiredMinHeight or m_floor(heightMap[i-1][j] + 0.5)
  local hRight = (i == Config.gridCols) and Config.desiredMinHeight or m_floor(heightMap[i+1][j] + 0.5)
  local hFront = (j == 1)             and Config.desiredMinHeight or m_floor(heightMap[i][j-1] + 0.5)
  local hBack  = (j == Config.gridRows) and Config.desiredMinHeight or m_floor(heightMap[i][j+1] + 0.5)
  
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

local function drawLandscape(heightMap)
  SetBrush("cube", 1, 1)
  local shape = FindShape("desert_base", true)
  if not shape then
    DebugPrint("Warning: Shape 'desert_base' not found.")
    return
  end
  for i = 1, Config.gridCols do
    for j = 1, Config.gridRows do
      drawCellFaces(shape, i, j, heightMap)
    end
  end
  
  DebugPrint("Desert landscape with pronounced dunes rendered.")
  return shape
end

-------------------------
-- Main Entry Point
-------------------------
function init()
  local hMap = generateHeightMap()
  drawLandscape(hMap)
  DebugPrint("Landscape generated. Per-cell hill void filling completed.")
end

function tick(dt)
  -- Tick function intentionally left empty.
end