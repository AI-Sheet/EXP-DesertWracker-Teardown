--[[
    Система автоматического затемнения пещер для Teardown
    
    Этот скрипт автоматически создает эффект темноты, когда игрок
    находится ниже уровня 0 по оси Y (в пещере). Система плавно
    переключается между обычным освещением и темнотой пещеры.
]]

-- Настройки системы затемнения пещер
local caveSettings = {
    -- Основные настройки
    caveDetectionHeight = 10,     -- Высота, ниже которой считается, что игрок в пещере (0 по Y)
    transitionSpeed = 0.01,      -- Скорость перехода между обычным и пещерным освещением (0-1)
    
    -- Настройки пещерного освещения
    fogColor = {0.05, 0.05, 0.1}, -- Цвет тумана в пещере (темно-синий)
    fogParams = {0.2, 0.1, 0.5},  -- Параметры тумана (плотность)
    skyboxBrightness = 0,     -- Яркость неба в пещере (почти черное)
    nightlight = 0,              -- Отключить ночное освещение в пещере (0 = выкл)
    
    -- Настройки постобработки для пещеры
    brightness = 0.4,            -- Яркость (0-1)
    saturation = 0.9,            -- Насыщенность (0-1)
    colorBalance = {0.7, 0.7, 1.0}, -- Цветовой баланс (синеватый оттенок)
    bloom = 0.5,                 -- Свечение (0-1)
    
    -- Отладка
    debugMode = true             -- Показывать отладочную информацию
}

-- Переменные состояния
local playerInCave = false       -- Находится ли игрок в пещере
local transitionValue = 0        -- Значение перехода (0 = обычное освещение, 1 = пещерное)
local originalSettings = {}      -- Оригинальные настройки для восстановления

-- Сохраняет оригинальные настройки окружения
function SaveOriginalSettings()
    -- Инициализируем таблицы для хранения цветов
    originalSettings.fogColor = {0, 0, 0}
    originalSettings.fogParams = {0, 0, 0}
    originalSettings.colorBalance = {1, 1, 1}
    
    -- Сохраняем настройки окружения
    local fogR, fogG, fogB = GetEnvironmentProperty("fogcolor")
    if fogR and fogG and fogB then
        originalSettings.fogColor[1] = fogR
        originalSettings.fogColor[2] = fogG
        originalSettings.fogColor[3] = fogB
    end
    
    local fogP1, fogP2, fogP3 = GetEnvironmentProperty("fogparams")
    if fogP1 and fogP2 and fogP3 then
        originalSettings.fogParams[1] = fogP1
        originalSettings.fogParams[2] = fogP2
        originalSettings.fogParams[3] = fogP3
    end
    
    originalSettings.skyboxBrightness = GetEnvironmentProperty("skyboxbrightness") or 1
    originalSettings.nightlight = GetEnvironmentProperty("nightlight") or 0
    
    -- Сохраняем настройки постобработки
    originalSettings.brightness = GetPostProcessingProperty("brightness") or 1
    originalSettings.saturation = GetPostProcessingProperty("saturation") or 1
    
    local cbR, cbG, cbB = GetPostProcessingProperty("colorbalance")
    if cbR and cbG and cbB then
        originalSettings.colorBalance[1] = cbR
        originalSettings.colorBalance[2] = cbG
        originalSettings.colorBalance[3] = cbB
    end
    
    originalSettings.bloom = GetPostProcessingProperty("bloom") or 0
    
    if caveSettings.debugMode then
        DebugPrint("Оригинальные настройки окружения сохранены")
    end
end

-- Линейная интерполяция между двумя значениями
function Lerp(a, b, t)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a + (b - a) * t
end

-- Применяет настройки освещения пещеры с учетом интенсивности перехода
function ApplyCaveLighting(intensity)
    -- Ограничиваем интенсивность от 0 до 1
    intensity = math.max(0, math.min(1, intensity))
    
    -- Настройки окружения
    -- Интерполируем цвет тумана
    local fogR = Lerp(originalSettings.fogColor[1], caveSettings.fogColor[1], intensity)
    local fogG = Lerp(originalSettings.fogColor[2], caveSettings.fogColor[2], intensity)
    local fogB = Lerp(originalSettings.fogColor[3], caveSettings.fogColor[3], intensity)
    SetEnvironmentProperty("fogcolor", fogR, fogG, fogB)
    
    -- Интерполируем параметры тумана
    local fogP1 = Lerp(originalSettings.fogParams[1], caveSettings.fogParams[1], intensity)
    local fogP2 = Lerp(originalSettings.fogParams[2], caveSettings.fogParams[2], intensity)
    local fogP3 = Lerp(originalSettings.fogParams[3], caveSettings.fogParams[3], intensity)
    SetEnvironmentProperty("fogparams", fogP1, fogP2, fogP3)
    
    -- Интерполируем яркость неба
    local skyBrightness = Lerp(originalSettings.skyboxBrightness, caveSettings.skyboxBrightness, intensity)
    SetEnvironmentProperty("skyboxbrightness", skyBrightness)
    
    -- Настройка ночного освещения
    if intensity > 0.5 then
        SetEnvironmentProperty("nightlight", caveSettings.nightlight)
    else
        SetEnvironmentProperty("nightlight", originalSettings.nightlight)
    end
    
    -- Настройки постобработки
    local brightness = Lerp(originalSettings.brightness, caveSettings.brightness, intensity)
    SetPostProcessingProperty("brightness", brightness)
    
    local saturation = Lerp(originalSettings.saturation, caveSettings.saturation, intensity)
    SetPostProcessingProperty("saturation", saturation)
    
    -- Интерполируем цветовой баланс
    local cbR = Lerp(originalSettings.colorBalance[1], caveSettings.colorBalance[1], intensity)
    local cbG = Lerp(originalSettings.colorBalance[2], caveSettings.colorBalance[2], intensity)
    local cbB = Lerp(originalSettings.colorBalance[3], caveSettings.colorBalance[3], intensity)
    SetPostProcessingProperty("colorbalance", cbR, cbG, cbB)
    
    local bloom = Lerp(originalSettings.bloom, caveSettings.bloom, intensity)
    SetPostProcessingProperty("bloom", bloom)
end

-- Восстанавливает оригинальные настройки окружения
function RestoreOriginalSettings()
    -- Восстанавливаем настройки окружения
    SetEnvironmentProperty("fogcolor", originalSettings.fogColor[1], originalSettings.fogColor[2], originalSettings.fogColor[3])
    SetEnvironmentProperty("fogparams", originalSettings.fogParams[1], originalSettings.fogParams[2], originalSettings.fogParams[3])
    SetEnvironmentProperty("skyboxbrightness", originalSettings.skyboxBrightness)
    SetEnvironmentProperty("nightlight", originalSettings.nightlight)
    
    -- Восстанавливаем настройки постобработки
    SetPostProcessingProperty("brightness", originalSettings.brightness)
    SetPostProcessingProperty("saturation", originalSettings.saturation)
    SetPostProcessingProperty("colorbalance", originalSettings.colorBalance[1], originalSettings.colorBalance[2], originalSettings.colorBalance[3])
    SetPostProcessingProperty("bloom", originalSettings.bloom)
    
    if caveSettings.debugMode then
        DebugPrint("Восстановлены оригинальные настройки окружения")
    end
end

-- Проверяет, находится ли игрок в пещере (ниже уровня 0 по Y)
function IsPlayerInCave()
    local playerTransform = GetPlayerTransform()
    
    -- Проверяем, что трансформация получена успешно
    if not playerTransform or not playerTransform.pos then
        return false
    end
    
    -- Получаем Y-координату игрока (высоту)
    local playerY = playerTransform.pos[2]
    
    -- Проверяем высоту игрока
    return playerY < caveSettings.caveDetectionHeight
end

-- Инициализация
function init()
    -- Сохраняем оригинальные настройки окружения
    SaveOriginalSettings()
    
    if caveSettings.debugMode then
        DebugPrint("Система затемнения пещер инициализирована")
        DebugPrint("Порог высоты пещеры: " .. caveSettings.caveDetectionHeight)
    end
end

-- Основной цикл
function tick(dt)
    -- Проверяем, находится ли игрок в пещере
    local inCave = IsPlayerInCave()
    
    -- Если статус изменился, выводим сообщение
    if inCave ~= playerInCave and caveSettings.debugMode then
        if inCave then
            DebugPrint("Игрок вошел в пещеру")
        else
            DebugPrint("Игрок вышел из пещеры")
        end
    end
    
    -- Обновляем статус
    playerInCave = inCave
    
    -- Обновляем значение перехода
    if playerInCave then
        transitionValue = math.min(1, transitionValue + caveSettings.transitionSpeed)
    else
        transitionValue = math.max(0, transitionValue - caveSettings.transitionSpeed)
    end
    
    -- Применяем настройки освещения пещеры с учетом значения перехода
    ApplyCaveLighting(transitionValue)
    
    -- Отображаем отладочную информацию
    if caveSettings.debugMode then
        DebugWatch("Игрок в пещере", inCave)
        DebugWatch("Значение перехода", transitionValue)
        
        local playerTransform = GetPlayerTransform()
        if playerTransform then
            DebugWatch("Высота игрока", playerTransform[2])
        else
            DebugWatch("Высота игрока", "Недоступно")
        end
        
        DebugWatch("Порог высоты пещеры", caveSettings.caveDetectionHeight)
    end
end

-- Очистка при завершении
function cleanup()
    -- Восстанавливаем оригинальные настройки окружения
    RestoreOriginalSettings()
    
    if caveSettings.debugMode then
        DebugPrint("Система затемнения пещер завершена")
    end
end