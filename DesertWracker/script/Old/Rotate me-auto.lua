local bodies = {
    {tag = "val_body1", dir = 1},    -- По часовой
    {tag = "val_body2", dir = 1}    -- Против часовой
}

function init()
    -- Предварительная загрузка хендлов тел
    for _, v in pairs(bodies) do
        v.handle = FindBody(v.tag, true)
        if IsHandleValid(v.handle) then
            SetBodyDynamic(v.handle, false)
        end
    end
end

function tick(dt)
    -- Угол для 228 градусов/сек с дельтой времени
    local angle = math.rad(2280) * dt
    
    -- Вращение тел с разным направлением
    for _, v in pairs(bodies) do
        if IsHandleValid(v.handle) then
            local t = GetBodyTransform(v.handle)
            t.rot = QuatRotateQuat(t.rot, QuatEuler(angle * v.dir, 0, 0))
            SetBodyTransform(v.handle, t)
        end
    end
end
