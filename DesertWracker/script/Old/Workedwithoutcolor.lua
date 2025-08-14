--------------------------------------------------------------------------------
-- Teardown Lua script (Enhanced Deformation with Platform-Based Timer)
-- Simplified version without roller-based deformation
--------------------------------------------------------------------------------

---@diagnostic disable: lowercase-global, param-type-mismatch

local TRIGGER_NAME = "trg"
local triggerHandle = 0

-- Platform shape: "inprogress"
local inprogressShape = 0

--------------------------------------------------------------------------------
-- CONFIGURATION CONSTANTS
--------------------------------------------------------------------------------

local SPEED_THRESHOLD   = 1            -- Shredder speed threshold to start deformation
local CLEANUP_DELAY     = 5            -- 5-second timer per object after deformation starts
local CUBE_MASS         = 20
local FIXED_SPAWN_POS   = Vec(0, 0, 0) -- This will be updated based on the trigger's position

-- Spawning cubes
local cubeSpawnQueue = {}
local spawnTimer = 0
local SPAWN_INTERVAL = 1.0  -- Интервал между спавном кубов (в секундах)

-- Brush size logic
local MIN_BRUSH_SIZE  = 1
local MAX_BRUSH_SIZE  = 6

-- Downward speed factors for sinking when platform is removed.
local DOWNWARD_SPEED_AT_MAX_FACTOR = -0.03
local DOWNWARD_SPEED_AT_MIN_FACTOR = -0.001

--------------------------------------------------------------------------------
-- SCRIPT STATE
--------------------------------------------------------------------------------

local spawnQueue      = 0
local spawnIndex      = 0

local processingItems = {}
local leftoverMass    = 0

local originalInprogressTransform = nil
local inprogressShifted           = false

--------------------------------------------------------------------------------
-- SPAWNING CUBES FUNCTIONALITY (OPTIMIZED)
--------------------------------------------------------------------------------

local cubePrototype = "<voxbox size='3 3 1' prop='true' material='hardmetal'/>"
function queueCubes(num)
    for i = 1, num do
        table.insert(cubeSpawnQueue, {}) -- Просто добавляем placeholder в очередь
    end
    DebugPrint(string.format("queueCubes() -> Queued %d, total in queue=%d", num, #cubeSpawnQueue))
end

function spawnCubes(num)
    queueCubes(num) -- Добавляем кубы в очередь, а не спавним сразу
end
local function spawnOneCubeFromQueue()
    if #cubeSpawnQueue > 0 then
        table.remove(cubeSpawnQueue, 1) -- Удаляем первый элемент из очереди
        spawnIndex = spawnIndex + 1
        local spawnPos = Vec(
            FIXED_SPAWN_POS[1],
            FIXED_SPAWN_POS[2],
            FIXED_SPAWN_POS[3]
        )

        local angleDeg = math.random(0, 359)
        local rad      = math.rad(angleDeg)
        local sidewaysImpulse = Vec(
            1,
            0,
            0
        )

        local spawnTransform = Transform(spawnPos, QuatEuler(0, math.random(0, 360), 0))
        local entities = Spawn(cubePrototype, spawnTransform)

        if #entities < 2 then
            DebugPrint("spawnOneCube() -> Failed to spawn voxbox.")
            return
        end

        local shape = entities[2]
        SetBrush("noise", 1, 0)
        for z = 0, 0 do -- Ограничиваем z только значением 0 (одна сторона)
            for x = 0, 2 do
                for y = 0, 2 do
                    if (x == 0 or x == 2 or y == 0 or y == 2) and math.random() < 0.4 then
                        DrawShapeBox(shape, x, y, z, x, y, z)
                    end
                end
            end
        end
        
        

        SetTag(shape, "sell")
        local body = GetShapeBody(shape)
        if body then
            SetBodyVelocity(body, sidewaysImpulse)
            local mass = GetBodyMass(body) or 0
            DebugPrint(string.format("spawnOneCube() -> Spawned cube #%d at Y=%.2f, mass=%.2f, angle=%d",
                spawnIndex, spawnPos[2], mass, angleDeg))
        end
    end
end
--------------------------------------------------------------------------------
-- PLATFORM LOGIC (INPROGRESS)
--------------------------------------------------------------------------------

local function moveInprogressDown()
    if inprogressShape == 0 or inprogressShifted then return end
    if not originalInprogressTransform then
        originalInprogressTransform = GetShapeLocalTransform(inprogressShape)
    end
    local tr = TransformCopy(originalInprogressTransform)
    tr.pos[2] = tr.pos[2] - 10
    SetShapeLocalTransform(inprogressShape, tr)
    inprogressShifted = true
    DebugPrint("moveInprogressDown() -> 'inprogress' platform lowered by 10.")
end

local function moveInprogressUp()
    if inprogressShape == 0 or not inprogressShifted then return end
    if originalInprogressTransform then
        SetShapeLocalTransform(inprogressShape, originalInprogressTransform)
        inprogressShifted = false
        DebugPrint("moveInprogressUp() -> 'inprogress' platform returned to original position.")
    end
end

--------------------------------------------------------------------------------
-- DEFORMATION HANDLING FOR OBJECTS IN TRIGGER
--------------------------------------------------------------------------------

function initDeformation(shape)
    if processingItems[shape] then return end
    local bdy = GetShapeBody(shape)
    local mass = 0
    if bdy then mass = GetBodyMass(bdy) or 0 end
    processingItems[shape] = {
        mass         = mass,
        isProcessing = false,
        chunkRemoved = false,
        deformTimer  = 0.0,
        descentTimer = nil,
        initialY = 0
    }
    if bdy then
        local bodyTransform = GetBodyTransform(bdy)
        if bodyTransform and bodyTransform.pos then
            processingItems[shape].initialY = bodyTransform.pos[2]
        else
            DebugPrint("initDeformation() -> bodyTransform or bodyTransform.pos is nil")
        end
    else
        local tr = GetShapeLocalTransform(shape)
        if tr and tr.pos then
            processingItems[shape].initialY = tr.pos[2]
        else
            DebugPrint("initDeformation() -> tr or tr.pos is nil")
        end
    end

    DebugPrint(string.format("initDeformation() -> Shape %s added with mass %.2f", tostring(shape), mass))
end

function startDeformation(data)
    if data.isProcessing then return end
    data.isProcessing = true
    data.descentTimer = CLEANUP_DELAY
    DebugPrint("startDeformation() -> Deformation started; 5-sec timer initiated.")
end

-- Simplified deformation function without roller-based logic
local function deformShape(shape, data, speed, dt)
    if not data.isProcessing then return end

    local bdy = GetShapeBody(shape)
    if not bdy then
        DebugPrint("deformShape() -> Shape " .. tostring(shape) .. " has no body!")
        return
    end

    local factor = speed / 25
    factor = math.max(0, math.min(factor, 1))

    if (not data.chunkRemoved) and factor > 0 then
        data.chunkRemoved = true
        moveInprogressDown()
        DebugPrint("deformShape() -> First deformation; platform removed.")
    end

    local sinkSpeed = DOWNWARD_SPEED_AT_MIN_FACTOR * (1 - factor) +
                      DOWNWARD_SPEED_AT_MAX_FACTOR * factor

    local velocity = GetBodyVelocity(bdy)
    velocity[2] = sinkSpeed

    SetBodyVelocity(bdy, velocity)
    data.deformTimer = data.deformTimer + dt

    local tries = math.random(20, 40)
    SetBrush("sphere", math.floor(MIN_BRUSH_SIZE + (MAX_BRUSH_SIZE - MIN_BRUSH_SIZE) * (1 - factor)), 0)

    for j = 1, tries do
        local x = math.random(0, 20)
        local y = math.random(0, 20)
        local z = math.random(0, 10)
        DrawShapeBox(shape, x, y, z, x, y, z)
    end
end

--------------------------------------------------------------------------------
-- PER-OBJECT CLEANUP
--------------------------------------------------------------------------------

local function cleanupObject(shape)
    if not IsHandleValid(shape) then return end
    DebugPrint("cleanupObject() -> Removing shape " .. tostring(shape))
    local data = processingItems[shape] or {}
    local shapeMass = data.mass or 0
    local bdy = GetShapeBody(shape)
    local canProduce = HasTag(shape, "resy") or (bdy and HasTag(bdy, "resy"))

    if canProduce then
        leftoverMass = leftoverMass + shapeMass
        DebugPrint(string.format("cleanupObject() -> Shape %s (resy): accumulated mass=%.2f", tostring(shape), leftoverMass))
    else
        DebugPrint("cleanupObject() -> Shape " .. tostring(shape) .. " not marked 'resy'; no cubes spawned.")
    end

    local toSpawn = math.floor(leftoverMass / CUBE_MASS)
    leftoverMass = leftoverMass % CUBE_MASS

    if canProduce and toSpawn > 0 then
        spawnCubes(toSpawn)
    end

    if bdy then
        Delete(bdy)
    else
        Delete(shape)
    end
    processingItems[shape] = nil
end

--------------------------------------------------------------------------------
-- PROCESS PER-OBJECT TIMERS
--------------------------------------------------------------------------------
local function processObjectTimers(dt)
    local count = 0
    for shape, data in pairs(processingItems) do
        count = count + 1
        if data.isProcessing and data.descentTimer then
            data.descentTimer = data.descentTimer - dt
            if data.descentTimer <= 0 then
                cleanupObject(shape)
            end
        end
    end

    if count == 0 and inprogressShifted then
        moveInprogressUp()
    end
end

--------------------------------------------------------------------------------
-- MAIN TICK FUNCTION
--------------------------------------------------------------------------------
function tick()
    if not triggerHandle then return end
    local dt = GetTimeStep()
    local speed = GetFloat("shredderSpeed") or 0

    for shape in pairs(processingItems) do
        if not IsHandleValid(shape) then
            processingItems[shape] = nil
        end
    end

    local shapes = FindShapes("", true)
    for i = 1, #shapes do
        local shp = shapes[i]
        local bdy = GetShapeBody(shp)
        if bdy and IsBodyInTrigger(triggerHandle, bdy) then
            local data = processingItems[shp]
            if not data then
                initDeformation(shp)
                data = processingItems[shp]
            end

            if data then
                if not data.isProcessing and speed > SPEED_THRESHOLD then
                    startDeformation(data)
                end

                if data.isProcessing then
                    deformShape(shp, data, speed, dt)
                end
            end
        end
    end
    spawnTimer = spawnTimer + dt
    if spawnTimer >= SPAWN_INTERVAL then
        spawnOneCubeFromQueue()
        spawnTimer = 0
    end
    processObjectTimers(dt)
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------
function init()
    triggerHandle   = FindTrigger(TRIGGER_NAME, true)
    inprogressShape = FindShape("inprogress", true)

    if triggerHandle ~= 0 then
        local triggerTransform = GetTriggerTransform(triggerHandle)
        FIXED_SPAWN_POS = Vec(triggerTransform.pos[1] + 3, triggerTransform.pos[2] - 0.3, triggerTransform.pos[3] - 0.5)    end

    if inprogressShape ~= 0 then
        originalInprogressTransform = GetShapeLocalTransform(inprogressShape)
    end

    DebugPrint("init() -> Trigger: " .. tostring(triggerHandle) .. ", inprogress: " .. tostring(inprogressShape))
end