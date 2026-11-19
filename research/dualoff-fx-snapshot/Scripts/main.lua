-- SPDX-License-Identifier: MPL-2.0
local PATH = "/Game/MainContent/Assets/fx/bp/skill/hilda/_dual/private/dualoff_fx.dualoff_fx"
local PREFIX = "[DualoffFxSnapshot]"

local function log(event, detail)
    print(("%s %s %s\n"):format(PREFIX, event, detail or ""))
end

local function valid(object)
    return object ~= nil and object:IsValid()
end

local function name(object)
    return valid(object) and object:GetFullName() or "<null>"
end

local function value(v)
    if v == nil then return "<unavailable>" end
    if type(v) == "number" then return ("%.9g"):format(v) end
    return tostring(v)
end

local function read(object, key)
    local ok, field = pcall(function() return object[key] end)
    if ok then return field end
end

local function fields(object, keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = key .. "=" .. value(read(object, key))
    end
    return table.concat(parts, " ")
end

local function vector(v)
    if v == nil then return "<unavailable>" end
    return ("(%s,%s,%s)"):format(value(v.X), value(v.Y), value(v.Z))
end

local function each(array, visit)
    assert(array, "reflected array unavailable")
    local count = array:GetArrayNum()
    for index = 1, count do
        -- UE4SS 83330635 can grow a TArray on an out-of-range indexed read.
        assert(index <= array:GetArrayNum(), "array shrank during snapshot")
        visit(array[index], index)
    end
    return count
end

local function distribution(tag, field, raw, isVector)
    local render = isVector and vector or value
    local object = raw.Distribution
    local detail = ("%s field=%s distribution=%q %s"):format(
        tag, field, name(object), fields(raw, {"MinValue", "MaxValue"}))
    if isVector then
        detail = detail .. " MinValueVec=" .. vector(raw.MinValueVec)
            .. " MaxValueVec=" .. vector(raw.MaxValueVec)
    end
    if valid(object) then
        for _, key in ipairs({"Constant", "Min", "Max", "MinInput", "MaxInput", "MinOutput", "MaxOutput"}) do
            local entry = read(object, key)
            if entry ~= nil then detail = detail .. " " .. key .. "=" .. render(entry) end
        end
    end
    log("DISTRIBUTION", detail)
    local curve = valid(object) and read(object, "ConstantCurve")
    if curve then
        each(curve.Points, function(point, index)
            log("CURVE", ("%s field=%s point=%d in=%s out=%s arrive=%s leave=%s mode=%s"):format(
                tag, field, index, value(point.InVal), render(point.OutVal), render(point.ArriveTangent),
                render(point.LeaveTangent), value(point.InterpMode)))
        end)
    end
end

local vectorDistributions = {
    "StartColor", "ColorOverLife", "ColorScaleOverLife", "StartSize", "SizeScale", "LifeMultiplier",
    "StartLocation", "StartVelocity",
}
local floatDistributions = {
    "LifeTime", "StartAlpha", "AlphaOverLife", "AlphaScaleOverLife",
    "Rate", "RateScale", "BurstScale", "SpawnPerUnit", "StartVelocityRadial",
    "BrightnessOverLife", "RadiusScale", "LightExponent",
}

local function module(tag, object)
    if not valid(object) then
        log("MODULE", tag .. " object=<null>")
        return
    end
    log("MODULE", ("%s class=%q object=%q %s"):format(tag, name(object:GetClass()), name(object),
        fields(object, {"bEnabled", "SpawnFraction", "bHighQualityLights", "bShadowCastingLights"})))
    for _, group in ipairs({vectorDistributions, floatDistributions}) do
        for _, key in ipairs(group) do
            local raw = read(object, key)
            if raw then distribution(tag, key, raw, group == vectorDistributions) end
        end
    end
    local bursts = read(object, "BurstList")
    if bursts then
        each(bursts, function(burst, index)
            log("BURST", ("%s index=%d %s"):format(tag, index, fields(burst, {"Time", "Count", "CountLow"})))
        end)
    end
end

local function snapshot()
    local system = StaticFindObject(PATH)
    if not valid(system) then
        log("MISS", "asset is not loaded; equip dual daggers in gameplay and retry")
        return false
    end
    assert(name(system) == "ParticleSystem " .. PATH, "unexpected asset identity")
    log("BEGIN", ("%s %s"):format(name(system),
        fields(system, {"WarmupTime", "Delay", "DelayLow", "bUseDelayRange", "bAutoDeactivate", "LODMethod"})))
    local emitters = each(system.Emitters, function(emitter, i)
        local tag = ("emitter=%d"):format(i)
        log("EMITTER", ("%s object=%q %s"):format(tag, name(emitter), valid(emitter)
            and fields(emitter, {"bCookedOut", "bDisabledLODsKeepEmitterAlive", "PeakActiveParticles"}) or ""))
        if not valid(emitter) then return end
        each(emitter.LODLevels, function(lod, j)
            assert(valid(lod), "invalid LOD at " .. tag .. " index=" .. j)
            local context = ("%s lod=%d"):format(tag, j)
            log("LOD", context .. " " .. fields(lod, {"Level", "bEnabled"}))
            local required = lod.RequiredModule
            assert(valid(required), "required module unavailable at " .. context)
            log("REQUIRED", ("%s material=%q %s"):format(context, name(required.Material), fields(required, {
                "bEnabled", "EmitterLoops", "EmitterDuration", "EmitterDurationLow", "bEmitterDurationUseRange",
                "bDurationRecalcEachLoop", "EmitterDelay", "EmitterDelayLow", "bEmitterDelayUseRange",
                "bDelayFirstLoopOnly", "bUseLocalSpace", "bKillOnCompleted", "bKillOnDeactivate",
            })))
            module(context .. " slot=spawn", lod.SpawnModule)
            module(context .. " slot=type", lod.TypeDataModule)
            each(lod.Modules, function(entry, k) module(context .. " slot=" .. k, entry) end)
        end)
    end)
    assert(emitters > 0, "loaded asset has no readable emitters")
    log("COMPLETE", "emitters=" .. emitters)
    return true
end

local queued, stopped = false, false
local ok, problem = pcall(function()
    assert(EngineTickAvailable == true, "engine-tick dispatch unavailable")
    local modifiers = {ModifierKey.CONTROL, ModifierKey.ALT}
    assert(Key.F11 and not IsKeyBindRegistered(Key.F11, modifiers), "Ctrl+Alt+F11 unavailable")
    RegisterKeyBind(Key.F11, modifiers, function()
        if queued or stopped then return end
        queued = true
        local dispatched, failure = pcall(ExecuteInGameThread, function()
            local sampled, result = pcall(snapshot)
            queued = false
            stopped = not sampled or result == true
            if not sampled then log("INCOMPLETE", tostring(result)) end
        end, EGameThreadMethod.EngineTick)
        if not dispatched then
            stopped = true
            log("INCOMPLETE", "dispatch: " .. tostring(failure))
        end
    end)
end)
if ok then log("ARMED", "equip dual daggers in gameplay; snapshot=Ctrl+Alt+F11")
else log("INCOMPLETE", "setup: " .. tostring(problem)) end
