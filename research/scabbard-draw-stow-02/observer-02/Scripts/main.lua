-- SPDX-License-Identifier: MPL-2.0
-- Read-only, one local pawn and one cudgel cycle. No UE wrappers retained.
local PREFIX = "MS_DRAW02 id=draw-stow-observer-02"
local BASE = "/Script/Genesis.BaseCharacterAnimInstance:"
local HILDA = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local classes = { "HildaCudgel_BP_C", "HildaCudgel_Use_BP_C", "HildaCudgel_Unuse_BP_C" }
local hooks = {}
local active, done, queued, fault = false, false, false, false
local pawnId, animId
local samples, events, sequence = 0, 0, 0

local function log(event, data)
    sequence = sequence + 1
    print(PREFIX .. " event=" .. event .. " seq=" .. sequence .. " time=" .. os.time() .. " " .. (data or "") .. "\n")
end
local function q(v) return string.format("%q", tostring(v):gsub("%c", "?"):sub(1, 300)) end
local function valid(o) return o ~= nil and o:IsValid() end
local function id(o)
    return valid(o) and (o:GetFullName() .. "@" .. tostring(o:GetAddress())) or "none"
end
local function same(a, b) return valid(a) and valid(b) and a:GetAddress() == b:GetAddress() end

local function stop(reason)
    if done then return end
    active, done = false, true
    log("STOP", "reason=" .. q(reason) .. " samples=" .. samples .. " callbacks=" .. events)
    local cleaned = true
    for _, h in ipairs(hooks) do
        local ok, err = pcall(UnregisterHook, h.path, h.pre, h.post)
        if not ok then cleaned = false; log("UNHOOK_ERROR", "detail=" .. q(err)) end
    end
    log(cleaned and "CLEANED" or "CLEANUP_PENDING", "keys=inert")
end
local function fail(err)
    if fault or done then return end
    active, fault = false, true
    log("FAILED", "detail=" .. q(err))
    local ok = pcall(ExecuteInGameThread, function() stop("failure") end, EGameThreadMethod.EngineTick)
    if not ok then log("CLEANUP_PENDING", "until=process-exit") end
end
local function readSkill(anim)
    local pending, doing = anim:GetToDoSkill():ToString(), anim:GetDoingSkill():ToString()
    assert(type(pending) == "string" and type(doing) == "string", "invalid skill result")
    return pending, doing
end
local function callback(method, phase, context, ...)
    local label = method .. "_" .. phase
    if not active then return end
    local extra = select("#", ...)
    local ok, err = pcall(function()
        local anim = context:get()
        if id(anim) ~= animId then return end
        assert(extra == 0, "unexpected inputs to " .. label)
        events = events + 1
        local pending, doing = readSkill(anim)
        log("SKILL", "hook=" .. label .. " pending=" .. q(pending)
            .. " doing=" .. q(doing) .. " anim=" .. q(animId))
        if events >= 32 then
            active = false
            ExecuteInGameThread(function() stop("callback-limit") end, EGameThreadMethod.EngineTick)
        end
    end)
    if not ok then fail(err) end
end
local function hook(method)
    local path = BASE .. method
    local fn = StaticFindObject(path)
    assert(valid(fn) and fn:type() == "UFunction" and fn:GetFullName() == "Function " .. path,
        "missing " .. path)
    assert((fn:GetFunctionFlags() & 0x400) ~= 0, "expected native function")
    log("HOOK_BEGIN", "method=" .. method)
    local pre, post = RegisterHook(path, function(context, ...) callback(method, "pre", context, ...) end,
        function(context, ...) callback(method, "post", context, ...) end)
    hooks[#hooks + 1] = {path = path, pre = pre, post = post}
    assert(math.type(pre) == "integer" and math.type(post) == "integer" and pre > 0 and post > 0 and pre ~= post,
        "unexpected native hook IDs")
    log("HOOK_END", "method=" .. method)
end
local function describe(slot, component)
    assert(valid(component), "missing component " .. slot)
    local hidden, visible = component.bHiddenInGame, component.bVisible
    assert(type(hidden) == "boolean" and type(visible) == "boolean", "visibility fields unavailable")
    log("COMPONENT", "sample=" .. samples .. " slot=" .. slot .. " object=" .. q(id(component))
        .. " owner=" .. q(id(component:GetOwner())) .. " asset=" .. q(id(component.SkeletalMesh))
        .. " parent=" .. q(id(component:GetAttachParent()))
        .. " socket=" .. q(component:GetAttachSocketName():ToString())
        .. " hidden=" .. tostring(hidden) .. " visible=" .. tostring(visible))
end
local function find(class)
    log("LOOKUP_BEGIN", "class=" .. class)
    local found = FindAllOf(class) or {}
    log("LOOKUP_END", "class=" .. class .. " found=" .. #found)
    assert(#found <= 8, "class candidate budget")
    return found
end
local function sample()
    local pawn, count = nil, 0
    for _, hud in ipairs(find("HUDMainUMG_BP_C")) do
        if valid(hud) and hud:IsInViewport() then count, pawn = count + 1, hud:GetOwningPlayerPawn() end
    end
    assert(count == 1 and valid(pawn) and pawn:GetClass():GetFullName() == HILDA, "local gameplay pawn unavailable")
    local mesh = pawn.Mesh
    assert(valid(mesh) and same(mesh:GetOwner(), pawn), "pawn mesh ownership unavailable")
    local anim = mesh:GetAnimInstance()
    assert(valid(anim) and anim:GetClass():GetFullName():match("%.hilda_AnimBP_C$"), "unexpected anim instance")
    if samples == 0 then
        pawnId, animId = id(pawn), id(anim)
        hook("BeginDoSkill")
        hook("EndDoSkill")
        ExecuteInGameThreadWithDelay(120000, function() stop("timeout") end)
        active = true
    end
    assert(id(pawn) == pawnId and id(anim) == animId, "pawn or anim generation changed")
    samples = samples + 1
    local pending, doing = readSkill(anim)
    log("SNAPSHOT", "sample=" .. samples .. " pawn=" .. q(pawnId) .. " pending=" .. q(pending) .. " doing=" .. q(doing))
    describe("scabbard_a", pawn.scabbard_a)
    describe("scabbard_b", pawn.scabbard_b)
    for _, class in ipairs(classes) do
        for _, actor in ipairs(find(class)) do
            if valid(actor) and actor:GetClass():GetFullName():match("%." .. class .. "$") and same(actor:GetOwner(), pawn) then
                local root = actor.RootComponent
                if valid(root) and same(root:GetAttachParent(), mesh) then
                    log("ACTOR", "sample=" .. samples .. " object=" .. q(id(actor))
                        .. " root_socket=" .. q(root:GetAttachSocketName():ToString())
                        .. " actor_hidden=" .. tostring(actor.bHidden))
                    describe("SkeletalMesh", actor.SkeletalMesh)
                    if class == classes[1] then describe("hilda_cudgel_sheath", actor.hilda_cudgel_sheath) end
                end
            end
        end
    end
    if samples >= 3 then stop("sample-limit") end
end

local function bind(key, fn, mods)
    RegisterKeyBind(key, mods, function()
        if done or queued or fault then return end
        queued = true
        local ok, err = pcall(ExecuteInGameThread, function()
            queued = false
            if done or fault then return end
            local success, problem = pcall(fn)
            if not success then fail(problem) end
        end, EGameThreadMethod.EngineTick)
        if not ok then fail(err) end
    end)
end
assert(EngineTickAvailable == true, "EngineTick required")
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F9, mods) and not IsKeyBindRegistered(Key.F10, mods), "observer chord occupied")
bind(Key.F9, sample, mods)
bind(Key.F10, function() stop("user") end, mods)
log("ARMED", "samples=3 callbacks=32 seconds=120 sample=Ctrl+Alt+F9 stop=Ctrl+Alt+F10")
