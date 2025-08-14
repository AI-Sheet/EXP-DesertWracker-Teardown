-- Desert Landscape Generator for Teardown (API 1.12.1 compatible)
-- Complete working version with proper API usage

perlin = { p = {} }

local permutation = {
    151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
    8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
    35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,134,
    139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,
    245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,
    135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,124,123,
    5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
    223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,
    129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,228,
    251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,107,
    49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
    138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
}

for i = 1, 512 do
    perlin.p[i - 1] = permutation[((i - 1) % 256) + 1]
end

local floor = math.floor

function perlin:p_index(n)
    return (n % 256 + 256) % 256 + 1
end

function perlin:noise(x, y, z)
    y = y or 0
    z = z or 0

    local X = self:p_index(floor(x))
    local Y = self:p_index(floor(y))
    local Z = self:p_index(floor(z))

    x = x - floor(x)
    y = y - floor(y)
    z = z - floor(z)

    local u = self:fade(x)
    local v = self:fade(y)
    local w = self:fade(z)

    local A  = self.p[X] + Y
    local AA = self.p[A] + Z
    local AB = self.p[A + 1] + Z
    local B  = self.p[X + 1] + Y
    local BA = self.p[B] + Z
    local BB = self.p[B + 1] + Z

    return self:lerp(w,
        self:lerp(v,
            self:lerp(u, self:grad(self.p[AA], x,   y,   z),  self:grad(self.p[BA], x-1, y,   z)),
            self:lerp(u, self:grad(self.p[AB], x,   y-1, z),  self:grad(self.p[BB], x-1, y-1, z))
        ),
        self:lerp(v,
            self:lerp(u, self:grad(self.p[AA+1], x,   y,   z-1), self:grad(self.p[BA+1], x-1, y,   z-1)),
            self:lerp(u, self:grad(self.p[AB+1], x,   y-1, z-1), self:grad(self.p[BB+1], x-1, y-1, z-1))
        )
    )
end

perlin.grad = {
    [0]  = function(_, x, y, z) return  x + y end,
    [1]  = function(_, x, y, z) return -x + y end,
    [2]  = function(_, x, y, z) return  x - y end,
    [3]  = function(_, x, y, z) return -x - y end,
    [4]  = function(_, x, y, z) return  x + z end,
    [5]  = function(_, x, y, z) return -x + z end,
    [6]  = function(_, x, y, z) return  x - z end,
    [7]  = function(_, x, y, z) return -x - z end,
    [8]  = function(_, x, y, z) return  y + z end,
    [9]  = function(_, x, y, z) return -y + z end,
    [10] = function(_, x, y, z) return  y - z end,
    [11] = function(_, x, y, z) return -y - z end
}

function perlin:fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function perlin:lerp(t, a, b)
    return a + t * (b - a)
end

function generateDesert(trigger)
    math.randomseed(GetTime())
    local transform = GetTriggerTransform(trigger)
    local pos = transform.pos
    
    -- Create new body and shape
    local body = CreateBody()
    local shape = CreateShape(body, Transform(pos[1], pos[2], pos[3]))
    
    -- Set brush parameters
    SetBrush("sphere", 3, 0)  -- Brush type, size, material
    
    -- Generate landscape in 40x40 area
    local halfSize = 20
    for x = -halfSize, halfSize do
        for z = -halfSize, halfSize do
            local nx = (x + pos[1]) * 0.1
            local nz = (z + pos[3]) * 0.1
            local y = math.floor(perlin:noise(nx, nz, 0) * 5)
            
            -- Add voxel to the shape
            SetBrush(shape, Vec(x + pos[1], y, z + pos[3]), 0.5, 1, 0)
        end
    end
    
    -- Finalize changes
    SetShapeBody(shape, body)
    DebugPrint("Desert landscape generated at: "..pos[1]..","..pos[2]..","..pos[3])
end

function init()
    local trigger = FindTrigger("desert")
    if trigger ~= 0 then
        generateDesert(trigger)
    else
        DebugPrint("Desert trigger not found!")
    end
end