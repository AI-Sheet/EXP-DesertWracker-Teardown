-- Extended Teardown Tunnel Generator
-- Creates a tunnel system with vertical and horizontal segments, spawns a voxbox at the tunnel end,
-- and then spawns a second voxbox on top of the first with a passage connecting them.
-- This script uses the same functions as in the provided code to demonstrate spawning multiple cubes
-- and carving tunnels through them via the Teardown API.

-- Configuration
local TUNNEL_WIDTH = 15            -- Tunnel width
local VERTICAL_DEPTH = 10         -- How deep to dig the vertical segment
local VOXBOX_SIZE = "64 64 64"     -- Default voxbox dimensions (width, height, depth)
local OVERLAP_OFFSET = 0.2         -- Fixed offset to prevent voxel gaps (do not change)
local CUBE_OFFSET = 6.4  
-- Global state
local targetShape = nil
local targetBody = nil
local shapeWidth, shapeHeight, shapeDepth = 0, 0, 0
local tunnelCreated = false
local shapeSpawned = false
local secondCubeSpawned = false
local thirdCubeSpawned = false
local tunnelNodes = {}             -- For debug visualization

-- Utility functions
function DebugLog(message)
    DebugPrint("[TunnelGenerator] " .. message)
end

function ParseVoxboxSize(sizeStr)
    local x, y, z = string.match(sizeStr, "(%d+)%s+(%d+)%s+(%d+)")
    return tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
end

-- Shape-finding and dimension querying
function FindTargetShape()
    local shape = FindShape("desert_base") or FindShape("desert_base", true)
    
    if shape == 0 then
        DebugLog("WARNING: Could not find target shape!")
        return 0
    end
    
    DebugLog("Found target shape: " .. shape)
    targetBody = GetShapeBody(shape)
    
    if targetBody == 0 then
        DebugLog("WARNING: Shape has no body!")
        return 0
    end
    
    shapeWidth, shapeHeight, shapeDepth = GetShapeSize(shape)
    DebugLog("Shape dimensions: " .. shapeWidth .. "x" .. shapeHeight .. "x" .. shapeDepth)
    return shape
end

-- Tunnel drawing and creation
function CreateTunnelSegment(x1, y1, z1, x2, y2, z2, shapeOverride)
    local workingShape = shapeOverride or targetShape
    SetBrush("sphere", TUNNEL_WIDTH, 0)
    DrawShapeBox(workingShape, x1, y1, z1, x2, y2, z2)
    
    table.insert(tunnelNodes, {
        start = Vec(x1, y1, z1),
        finish = Vec(x2, y2, z2)
    })
end

function CreateTunnel()
    DebugLog("Creating tunnel...")
    tunnelNodes = {}

    local centerX = shapeWidth / 2
    local centerZ = shapeDepth / 2

    -- Vertical segment from surface to VERTICAL_DEPTH
    local verticalStart = Vec(centerX, shapeHeight, centerZ)
    local verticalEnd = Vec(centerX, VERTICAL_DEPTH, centerZ)
    CreateTunnelSegment(
        verticalStart[1] - TUNNEL_WIDTH/2, verticalStart[2], verticalStart[3] - TUNNEL_WIDTH/2,
        verticalEnd[1] + TUNNEL_WIDTH/2, verticalEnd[2], verticalEnd[3] + TUNNEL_WIDTH/2
    )

    -- Horizontal segment from center to edge
    local horizontalStart = Vec(centerX, VERTICAL_DEPTH, centerZ)
    local horizontalEnd = Vec(shapeWidth, VERTICAL_DEPTH, centerZ)
    CreateTunnelSegment(
        horizontalStart[1] - TUNNEL_WIDTH/2, horizontalStart[2] - TUNNEL_WIDTH/2, horizontalStart[3] - TUNNEL_WIDTH/2,
        horizontalEnd[1], horizontalEnd[2] + TUNNEL_WIDTH/2, horizontalEnd[3] + TUNNEL_WIDTH/2
    )

    tunnelCreated = true
    DebugLog("Tunnel created successfully")
    SpawnShapeAtTunnelEnd()
end

-- Spawning cubes and extending tunnels
-- Spawning cubes and extending tunnels
function SpawnShapeAtTunnelEnd()
    if not tunnelCreated then return end

    local shapeMin, shapeMax = GetShapeBounds(targetShape)
    local actualWidth = shapeMax[1] - shapeMin[1]
    local actualHeight = shapeMax[2] - shapeMin[2]
    local actualDepth = shapeMax[3] - shapeMin[3]
    local scaleX = actualWidth / shapeWidth
    local scaleY = actualHeight / shapeHeight
    local scaleZ = actualDepth / shapeDepth

    local centerZ = shapeDepth / 2
    local exitPointLocal = Vec(shapeWidth, VERTICAL_DEPTH, centerZ)

    -- Get voxbox dimensions
    local voxSizeX, voxSizeY, voxSizeZ = ParseVoxboxSize(VOXBOX_SIZE)
    
    -- Apply offsets
    local offsetY = voxSizeY / 2
    local offsetZ = voxSizeZ / 2
    exitPointLocal[2] = exitPointLocal[2] - offsetY
    exitPointLocal[3] = exitPointLocal[3] + offsetZ
    exitPointLocal[1] = exitPointLocal[1] - OVERLAP_OFFSET

    -- Convert to world coordinates
    local exitPointWorld = Vec(
        shapeMin[1] + exitPointLocal[1] * scaleX,
        shapeMin[2] + exitPointLocal[2] * scaleY,
        shapeMin[3] + exitPointLocal[3] * scaleZ
    )

    -- Spawn the first voxbox
    local spawnTransform = Transform(exitPointWorld, QuatEuler(0, 90, 0))
    local voxboxXml = "<voxbox size='" .. VOXBOX_SIZE .. "' prop='false' material='wood'/>"
    local entities = Spawn(voxboxXml, spawnTransform, true, true)

    if entities and #entities > 0 then
        DebugLog("Successfully spawned first voxbox")
        shapeSpawned = true
        ExtendTunnelIntoCube(entities[1])

        -- Spawn second cube above first cube with fixed offset
        local secondCubePos = Vec(
            exitPointWorld[1],
            exitPointWorld[2] + CUBE_OFFSET,  -- Using fixed offset for vertical positioning
            exitPointWorld[3]
        )
        local secondCubeTransform = Transform(secondCubePos, QuatEuler(0, 90, 0))
        local secondEntities = Spawn(voxboxXml, secondCubeTransform, true, true)

        if secondEntities and #secondEntities > 0 then
            secondCubeSpawned = true
            CarvePassageBetweenCubes(entities[1], secondEntities[1])

            -- Spawn third cube to the right of second cube with fixed offset
            local thirdCubePos = Vec(
                secondCubePos[1],  -- Using fixed offset for horizontal positioning
                secondCubePos[2],
                secondCubePos[3] - CUBE_OFFSET
            )
            local thirdCubeTransform = Transform(thirdCubePos, QuatEuler(0, 90, 0))
            local thirdEntities = Spawn(voxboxXml, thirdCubeTransform, true, true)

            if thirdEntities and #thirdEntities > 0 then
                thirdCubeSpawned = true
                CreateHorizontalPassage(secondEntities[1], thirdEntities[1])
            end
        end
    end
end

-- New function to create horizontal passage between cubes
function CreateHorizontalPassage(leftCube, rightCube)
    local w1, h1, d1 = GetShapeSize(leftCube)
    local w2, h2, d2 = GetShapeSize(rightCube)

    -- Прорезаем туннель в левом кубе (от центра до правого края)
    CreateTunnelSegment(
        w1/2 - TUNNEL_WIDTH/2,     -- начало X
        h1/2 - TUNNEL_WIDTH/2,     -- начало Y
        d1/2 - TUNNEL_WIDTH/2,     -- начало Z
        w1 + TUNNEL_WIDTH,         -- конец X (с запасом)
        h1/2 + TUNNEL_WIDTH/2,     -- конец Y
        d1/2 + TUNNEL_WIDTH/2,     -- конец Z
        leftCube
    )

    -- Прорезаем туннель в правом кубе (от левого края до центра)
    CreateTunnelSegment(
        -TUNNEL_WIDTH,             -- начало X (с запасом)
        h2/2 - TUNNEL_WIDTH/2,     -- начало Y
        d2/2 - TUNNEL_WIDTH/2,     -- начало Z
        w2/2 + TUNNEL_WIDTH/2,     -- конец X
        h2/2 + TUNNEL_WIDTH/2,     -- конец Y
        d2/2 + TUNNEL_WIDTH/2,     -- конец Z
        rightCube
    )
end

function ExtendTunnelIntoCube(cubeShape)
    local w, h, d = GetShapeSize(cubeShape)
    
    -- Прорезаем туннель через весь куб
    CreateTunnelSegment(
        w/2 - TUNNEL_WIDTH/2,      -- начало X
        h/2 - TUNNEL_WIDTH/2,      -- начало Y
        -TUNNEL_WIDTH,             -- начало Z (с запасом)
        w/2 + TUNNEL_WIDTH/2,      -- конец X
        h/2 + TUNNEL_WIDTH/2,      -- конец Y
        d + TUNNEL_WIDTH,          -- конец Z (с запасом)
        cubeShape
    )
end

-- Spawning and connecting second cube
-- Исправленная функция создания вертикального прохода между кубами
function CarvePassageBetweenCubes(lowerShape, upperShape)
    local w1, h1, d1 = GetShapeSize(lowerShape)
    local w2, h2, d2 = GetShapeSize(upperShape)

    -- Прорезаем туннель в нижнем кубе (от центра до верха)
    CreateTunnelSegment(
        w1/2 - TUNNEL_WIDTH/2,     -- начало X
        h1/2 - TUNNEL_WIDTH/2,     -- начало Y
        d1/2 - TUNNEL_WIDTH/2,     -- начало Z
        w1/2 + TUNNEL_WIDTH/2,     -- конец X
        h1 + TUNNEL_WIDTH,         -- конец Y (с запасом)
        d1/2 + TUNNEL_WIDTH/2,     -- конец Z
        lowerShape
    )

    -- Прорезаем туннель в верхнем кубе (от низа до центра)
    CreateTunnelSegment(
        w2/2 - TUNNEL_WIDTH/2,     -- начало X
        -TUNNEL_WIDTH,             -- начало Y (с запасом)
        d2/2 - TUNNEL_WIDTH/2,     -- начало Z
        w2/2 + TUNNEL_WIDTH/2,     -- конец X
        h2/2 + TUNNEL_WIDTH/2,     -- конец Y
        d2/2 + TUNNEL_WIDTH/2,     -- конец Z
        upperShape
    )
end

-- Debug visualization
function DrawDebugVisualization()
    if not targetShape or targetShape == 0 then return end

    local shapeMin, shapeMax = GetShapeBounds(targetShape)
    
    -- Draw shape bounds
    DebugLine(Vec(shapeMin[1], shapeMin[2], shapeMin[3]), Vec(shapeMax[1], shapeMin[2], shapeMin[3]), 0, 1, 1, 0.8)
    DebugLine(Vec(shapeMin[1], shapeMin[2], shapeMax[3]), Vec(shapeMax[1], shapeMin[2], shapeMax[3]), 0, 1, 1, 0.8)
    DebugLine(Vec(shapeMin[1], shapeMin[2], shapeMin[3]), Vec(shapeMin[1], shapeMin[2], shapeMax[3]), 0, 1, 1, 0.8)
    DebugLine(Vec(shapeMax[1], shapeMin[2], shapeMin[3]), Vec(shapeMax[1], shapeMin[2], shapeMax[3]), 0, 1, 1, 0.8)

    -- Calculate scale factors
    local scaleX = (shapeMax[1] - shapeMin[1]) / shapeWidth
    local scaleY = (shapeMax[2] - shapeMin[2]) / shapeHeight
    local scaleZ = (shapeMax[3] - shapeMin[3]) / shapeDepth

    -- Draw tunnel nodes
    for _, node in ipairs(tunnelNodes) do
        local worldStart = Vec(
            shapeMin[1] + node.start[1] * scaleX,
            shapeMin[2] + node.start[2] * scaleY,
            shapeMin[3] + node.start[3] * scaleZ
        )
        local worldEnd = Vec(
            shapeMin[1] + node.finish[1] * scaleX,
            shapeMin[2] + node.finish[2] * scaleY,
            shapeMin[3] + node.finish[3] * scaleZ
        )
        DebugLine(worldStart, worldEnd, 0, 1, 0, 0.8)
        DebugCross(worldStart, 0, 1, 0, 1)
        DebugCross(worldEnd, 0, 1, 0, 1)
    end

    -- Draw spawn point if tunnel exists
    if tunnelCreated then
        local centerZ = shapeDepth / 2
        local exitPointLocal = Vec(shapeWidth, VERTICAL_DEPTH, centerZ)
        local voxSizeX, voxSizeY, voxSizeZ = ParseVoxboxSize(VOXBOX_SIZE)
        
        exitPointLocal[2] = exitPointLocal[2] - voxSizeY / 2
        exitPointLocal[3] = exitPointLocal[3] + voxSizeZ / 2
        exitPointLocal[1] = exitPointLocal[1] - OVERLAP_OFFSET

        local exitPointWorld = Vec(
            shapeMin[1] + exitPointLocal[1] * scaleX,
            shapeMin[2] + exitPointLocal[2] * scaleY,
            shapeMin[3] + exitPointLocal[3] * scaleZ
        )
        DebugCross(exitPointWorld, 1, 0, 1, 1)
    end
end

-- Lifecycle functions
function init()
    DebugLog("Extended Tunnel Generator initialized. Press 'G' to create tunnel")
    targetShape = FindTargetShape()
    if targetShape and targetShape ~= 0 then
        DebugLog("Ready to create tunnel in target shape")
    else
        DebugLog("No target shape found! Tunnel creation will not work")
    end
end

function tick()
    -- Create tunnel on G press
    if InputPressed("g") and targetShape and targetShape ~= 0 and not tunnelCreated then
        CreateTunnel()
    end

    -- Reset on R press
    if InputPressed("r") and tunnelCreated then
        tunnelCreated = false
        shapeSpawned = false
        secondCubeSpawned = false
        tunnelNodes = {}
        DebugLog("Reset complete. Press 'G' to create a new tunnel")
    end

    -- Draw debug visualization
    DrawDebugVisualization()

    -- Show status message
    if tunnelCreated then
        if shapeSpawned and secondCubeSpawned then
            DebugPrint("Two cubes spawned and passages created. Press 'R' to reset.")
        elseif shapeSpawned then
            DebugPrint("Tunnel and first cube spawned. Second not spawned. Press 'R' to reset.")
        else
            DebugPrint("Tunnel created but no cubes spawned. Press 'R' to reset.")
        end
    else
        DebugPrint("Press 'G' to create tunnel")
    end
end