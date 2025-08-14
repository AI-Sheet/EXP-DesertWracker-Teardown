--------------------------------------------------------------------------------
-- Скрипт Teardown (Контроль шредера: фиксированное вращение валов)
-- В этой версии валов фиксируется позиция путем сохранения изначальной позиции и
-- обнуления линейной и угловой скоростей каждого тика.
---@diagnostic disable: lowercase-global, param-type-mismatch

-- Определение валов; разное направление вращения.
local bodies = {
    { tag = "val_body1", dir = 1 },    -- Вращение по часовой
    { tag = "val_body2", dir = 1 }       -- Вращение против часовой
}

-- Параметры управления рукояткой.
local handleBody = 0
local handleJoint = 0
local isRotating = false
local isGrabbed = false              
local maxAngularVelocity = 5.0
local interactionDistance = 3.0

-- Отслеживание вращения рукоятки.
local lastHandleAngle = 0
local totalHandleRotation = 0
local partialRotation = 0

-- Параметры шредера для контроля скорости.
local shredder = {
    speed = 0,
    maxSpeed = 180,
    minSpeed = 5,
    baseSpeed = 20,
    speedPerRotation = 50,
    decayRate = 180/110,  -- Изменено: decayRate уменьшен до 1, что в 2 раза медленнее затухание
    working = false
}

--------------------------------------------------------------------------------
-- ИНИЦИАЛИЗАЦИЯ
--------------------------------------------------------------------------------
function init()
    -- Инициализация рукоятки и соединения.
    handleBody = FindBody("rychug", true)
    handleJoint = FindJoint("rychug_joint")
    
    if not (IsHandleValid(handleBody) and handleJoint ~= 0) then 
        return 
    end

    -- Установка рукоятки в динамическое состояние для управления.
    SetBodyDynamic(handleBody, true)
    SetBodyVelocity(handleBody, Vec(0, 0, 0))
    SetBodyAngularVelocity(handleBody, Vec(0, 0, 0))
    lastHandleAngle = GetBodyTransform(handleBody).rot[1]
    
    -- Инициализация валов.
    for _, v in pairs(bodies) do
        v.handle = FindBody(v.tag, true)
        if IsHandleValid(v.handle) then
            SetBodyDynamic(v.handle, false)  -- делаем валы статичными
            v.rotation = 0
            -- Сохраняем полную трансформацию вала
            v.initialTransform = GetBodyTransform(v.handle)
            -- Обнуляем скорости
            SetBodyVelocity(v.handle, Vec(0, 0, 0))
            SetBodyAngularVelocity(v.handle, Vec(0, 0, 0))
        end
    end
end

--------------------------------------------------------------------------------
-- УПРАВЛЕНИЕ ВРАЩЕНИЕМ РУКОЯТКИ
--------------------------------------------------------------------------------
-- Функция для подсчета изменения угла рукоятки и обновления скорости шредера.
function UpdateHandleRotationCount()
    local transform = GetBodyTransform(handleBody)
    local currentAngle = transform.rot[1]
    local deltaAngle = currentAngle - lastHandleAngle
    
    totalHandleRotation = totalHandleRotation + math.abs(deltaAngle)
    partialRotation = partialRotation + math.abs(deltaAngle)
    
    -- Если достигнут поворот на четверть оборота, запускаем шредер.
    if partialRotation >= 1.57 and shredder.speed == 0 then
        shredder.speed = shredder.baseSpeed
        partialRotation = 0
    end
    
    -- За полный оборот увеличиваем скорость.
    if totalHandleRotation >= 6.28 then
        totalHandleRotation = 0
        partialRotation = 0
        local speedIncrease = shredder.speedPerRotation
        shredder.speed = math.min(shredder.speed + speedIncrease, shredder.maxSpeed)
    end
    
    lastHandleAngle = currentAngle
end

-- Функция вычисления целевой угловой скорости для соединения.
function HandleRotation(dt)
    local transform = GetBodyTransform(handleBody)
    local currentAngle = transform.rot[1]
    local deltaAngle = currentAngle - lastHandleAngle
    
    local targetVelocity = deltaAngle / dt
    targetVelocity = math.min(math.max(targetVelocity, -maxAngularVelocity), maxAngularVelocity)
    SetJointMotor(handleJoint, targetVelocity, 500.0)
    
    UpdateHandleRotationCount()
end

--------------------------------------------------------------------------------
-- ОБНОВЛЕНИЕ ВРАЩЕНИЯ ВАЛОВ
--------------------------------------------------------------------------------
-- Функция выполняет вращение валов с использованием сохраненной изначальной позиции.
function UpdateShafts(dt)
    if shredder.speed > 0 then
        local step = shredder.speed * dt
        
        for _, v in pairs(bodies) do
            if IsHandleValid(v.handle) then
                -- Обновляем только угол вращения
                v.rotation = (v.rotation or 0) + step
                -- Создаем новый кватернион вращения
                local rotationQuat = QuatEuler(v.rotation * v.dir, 0, 0)
                -- Комбинируем с начальным вращением вала
                local finalRot = QuatRotateQuat(v.initialTransform.rot, rotationQuat)
                -- Устанавливаем трансформацию, сохраняя начальную позицию
                SetBodyTransform(v.handle, Transform(v.initialTransform.pos, finalRot))
                -- Обнуляем скорости для предотвращения дрифта
                SetBodyVelocity(v.handle, Vec(0, 0, 0))
                SetBodyAngularVelocity(v.handle, Vec(0, 0, 0))
            end
        end
        
        if not isRotating then
            shredder.speed = math.max(0, shredder.speed - shredder.decayRate * dt)
        end
        
        if shredder.speed < shredder.minSpeed then
            shredder.speed = 0
            totalHandleRotation = 0
            partialRotation = 0
        end
        
        SetFloat("shredderSpeed", shredder.speed)
    else
        SetFloat("shredderSpeed", 0)
    end
end

--------------------------------------------------------------------------------
-- ОСНОВНАЯ ФУНКЦИЯ TICK
--------------------------------------------------------------------------------
function tick(dt)
    if not (IsHandleValid(handleBody) and handleJoint ~= 0) then 
        return 
    end

    -- Определяем взаимодействие, исходя из положения игрока.
    local isThirdPerson = GetBool("game.thirdperson")
    local playerPos = isThirdPerson and GetPlayerTransform().pos or GetPlayerCameraTransform().pos
    local handlePos = GetBodyTransform(handleBody).pos
    local distance = VecLength(VecSub(playerPos, handlePos))
    
    -- Подсветка рукоятки при близком расстоянии.
    if distance < 5.0 then
        DrawBodyOutline(handleBody, 0, 1, 0, 1)
    end

    -- Обработка ввода: включение управления при нажатии ПКМ, если игрок рядом.
    if InputPressed("rmb") and distance < interactionDistance then
        isGrabbed = true
        SetJointMotor(handleJoint, 0, 0)
    elseif InputReleased("rmb") then
        isGrabbed = false
        isRotating = false
    end

    if isGrabbed and (distance < interactionDistance or isThirdPerson) then
        isRotating = true
        HandleRotation(dt)
        DrawBodyOutline(handleBody, 1, 1, 1, 0.5)  -- Подсветка активной рукоятки.
    else
        isRotating = false
        SetJointMotor(handleJoint, 0, 300.0)
    end
    UpdateShafts(dt)
end

--------------------------------------------------------------------------------
-- МОДУЛЬНЫЙ ВОЗВРАТ
--------------------------------------------------------------------------------
return {
    init = init,
    tick = tick
}