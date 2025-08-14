-- Optimized script to remove a single layer with a hole in the middle using MakeHole

-- Configuration
local layerHeight = -10 -- Fixed height for the layer to be removed
local holeRadius = 2   -- Radius of the hole to be created
local repetitions = 10 -- Number of times to call MakeHole for a clean hole

-- Global variables
local desertShape = 0       -- Handle for the main object
local objectBounds = {min = Vec(0,0,0), max = Vec(0,0,0)} -- Object bounds

-- Improved debug print function
function DebugLog(message)
    DebugPrint("[LayerRemoval] " .. message)
end

-- Finds the "desert_base" object and merges it with other objects
function FindAndMergeDesertBase()
    DebugLog("Searching for 'desert_base' object...")
    local shape = FindShape("desert_base", true)
    if shape == 0 then
        DebugLog("ERROR: Object 'desert_base' not found!")
        return false
    else
        desertShape = shape
        local boundsMin, boundsMax = GetShapeBounds(desertShape)
        if boundsMin and boundsMax then
            objectBounds.min = boundsMin
            objectBounds.max = boundsMax
            DebugLog("Object bounds: min=" .. VecStr(boundsMin) .. ", max=" .. VecStr(boundsMax))
        else
            DebugLog("WARNING: Failed to get shape bounds!")
            objectBounds.min = Vec(-10, -10, -10)
            objectBounds.max = Vec(10, 10, 10)
        end
        return true
    end
end

-- Creates a clean hole by calling MakeHole multiple times
function CreateCleanHole(position, radius, repetitions)
    for i = 1, repetitions do
        MakeHole(position, radius, radius, radius, true)
    end
end

-- Initialization function
function init()
    if not FindAndMergeDesertBase() then
        return
    end

end
function tick()
    
    -- Calculate the center position for the hole
    local centerX = (objectBounds.min[1] + objectBounds.max[1]) / 2
    local centerZ = (objectBounds.min[3] + objectBounds.max[3]) / 2
    local position = Vec(centerX, layerHeight, centerZ)

    -- Create a single clean hole in the middle
    CreateCleanHole(position, holeRadius, repetitions)


    -- Add a debug cross to visualize the hole position
    DebugCross(position, 1, 0, 0, 1) -- Red cross for visibility

    -- Add a debug line to visualize the layer removal
    DebugLine(Vec(centerX - holeRadius, layerHeight, centerZ), Vec(centerX + holeRadius, layerHeight, centerZ), 0, 1, 0, 1) -- Green line for visibility

    DebugLog("Single hole created at height: " .. layerHeight)
end