-- SPDX-License-Identifier: MPL-2.0
-- Bounded research write-test for one verified stock cudgel loadout.
local ITEM = "/Game/MainContent/Act/Item_BP/"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local PAWN = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local HIDDEN = "/Script/Engine.SceneComponent:SetHiddenInGame"
local order = {"sheath", "A", "B", "spear", "staff", "dual"}
local specs = {
    sheath={"HildaCudgel_BP", "hilda_cudgel_sheath", "hilda_cudgel_sheath", "scabbard_a", 1},
    A={false, "scabbard_a", "hilda_scabbard_A", "scabbard_a"},
    B={false, "scabbard_b", "hilda_scabbard_B", "scabbard_b"},
    spear={"HildaSpear_Unuse_BP", "SkeletalMesh", "hilda_spear_unuse", "scabbard_a", 2},
    staff={"HildaStaff_BP", "hilda_staff_sheath", "hilda_staff_sheath", "scabbard_b", 1},
    dual={"HildaDual_Unuse_BP", "SkeletalMesh", "hilda_dual_unuse", "scabbard_b", 2},
}
local phase, queued, stopping, retired = 0, false, false, false
local session, call
local token, timer, writerPair, drawPending = 0, nil, nil, false
local dynamic = 4
local timerUncertain = false
local attack = "hilda_cudgel_atk1_idle"
local sockets = {[0]="cudgel_r_hand", [1]="scabbard_a", [3]="dual_l_hand"}
local hooks, owned, uncertain = {}, {}, {}
local function log(event, fields)
    print("MS_DYNAMIC id=scabbard-dynamic-cudgel-01 event=" .. event .. " " .. (fields or "") .. "\n")
end
local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (name(o) .. "@" .. tostring(o:GetAddress())) or nil end
local function class(o) return valid(o) and name(o:GetClass()) or nil end
local function path(o) return assert(name(o):match("^[^ ]+ (.+)$")) end
local function socket(o) return o:GetAttachSocketName():ToString() end
local function asset(o, n) return name(o.SkeletalMesh) == MESH .. n .. "." .. n end
local function bp(n) return ITEM .. n .. "." .. n .. "_C" end
local function visible(o)
    return valid(o) and o.bVisible == true and o.bHiddenInGame == false
end
local function one(n, predicate)
    local found
    local list = FindAllOf(n) or {}
    assert(#list <= 16, "lookup budget " .. n)
    for _, o in ipairs(list) do
        if valid(o) and predicate(o) then
            assert(not found, "ambiguous " .. n)
            found = o
        end
    end
    return assert(found, "missing " .. n)
end

local function context(hud, idle)
    assert(not retired and valid(hud) and hud:IsInViewport(), "retired or no gameplay HUD")
    local pawn = hud:GetOwningPlayerPawn()
    assert(class(pawn) == PAWN and pawn.bHidden == false, "invalid local pawn")
    local mesh = pawn.Mesh
    assert(class(mesh) == SKELETAL and name(mesh):match("%.CharacterMesh0$")
        and id(mesh:GetOwner()) == id(pawn) and visible(mesh), "invalid CharacterMesh0")
    local anim = mesh:GetAnimInstance()
    assert((class(anim) or ""):match("%.hilda_AnimBP_C$"), "anim unavailable")
    if idle then
        assert(anim:GetToDoSkill():ToString() == "None" and anim:GetDoingSkill():ToString() == "None", "skill active")
    end
    local generation = table.concat({id(hud), id(pawn), id(mesh), id(anim)}, "|")
    return pawn, mesh, generation, id(anim)
end
local function resolve(label, pawn, mesh, actor, observedMode)
    local spec = specs[label]
    local parent, attach = mesh, spec[4]
    if spec[1] then
        local expectedMode = observedMode or spec[5]
        assert(class(actor) == "BlueprintGeneratedClass " .. bp(spec[1])
            and id(actor:GetOwner()) == id(pawn) and actor.bHidden == false
            and (observedMode ~= nil or actor.equipMode == expectedMode), "actor context changed " .. label)
        parent, attach = actor.RootComponent, "None"
        assert(visible(parent) and id(parent:GetOwner()) == id(actor)
            and id(parent:GetAttachParent()) == id(mesh) and socket(parent) == (observedMode and sockets[observedMode] or spec[4]), "root changed " .. label)
    end
    local c = actor[spec[2]]
    assert(class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and asset(c, spec[3])
        and id(c:GetAttachParent()) == id(parent) and socket(c) == attach
        and type(c.bVisible) == "boolean" and c.bHiddenInGame == false, "component changed " .. label)
    local generation = table.concat({id(actor), id(parent), id(c), id(c.SkeletalMesh)}, "|")
    return c, generation
end
local function held(actor, out)
    local c = actor.SkeletalMesh
    assert(class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and asset(c, "hilda_cudgel")
        and id(c:GetAttachParent()) == id(actor.RootComponent) and socket(c) == "None"
        and c.bVisible == (out == true) and c.bHiddenInGame == false, "held mesh changed")
    return c, id(c) .. "|" .. id(c.SkeletalMesh)
end
local function current(idle)
    local pawn, mesh, generation = context(StaticFindObject(session.hudPath), idle)
    assert(generation == session.generation, "pawn generation changed")
    return pawn, mesh
end
local function part(label, pawn, mesh, observedMode)
    local saved = session.parts[label]
    local actor = specs[label][1] and StaticFindObject(saved.actorPath) or pawn
    local c, generation = resolve(label, pawn, mesh, actor, observedMode)
    assert(generation == saved.generation, "instance changed " .. label)
    return c, actor
end
local function checkHeld(actor, out)
    local _, key = held(actor, out)
    assert(key == session.held, "held identity changed")
end
local function all(idle, post)
    local pawn, mesh = current(idle)
    local parts = {}
    for _, label in ipairs(order) do
        local c, actor = part(label, pawn, mesh, label == "sheath" and post or nil)
        if label == "sheath" then checkHeld(actor) end
        assert(c.bVisible == not owned[label], "visibility differs " .. label)
        parts[label] = c
    end
    return parts
end
local function rollbackTarget(label)
    local pawn, mesh = current()
    -- Stowed cudgel is still required. Resolve each restoration independently.
    local saved = session.parts.sheath
    local cudgel = StaticFindObject(saved.actorPath)
    assert(id(cudgel) == saved.actor, "cudgel generation changed")
    local root = cudgel.RootComponent
    assert(cudgel.equipMode == 1 and cudgel.bHidden == false and id(cudgel:GetOwner()) == id(pawn)
        and id(root) == saved.root and id(root:GetOwner()) == id(cudgel) and visible(root)
        and id(root:GetAttachParent()) == id(mesh) and socket(root) == "scabbard_a", "not stowed for rollback")
    checkHeld(cudgel)
    return part(label, pawn, mesh)
end

local function write(label, value, probe, rollback)
    assert(not uncertain[label] and (rollback or not stopping), "write blocked " .. label)
    local function checked()
        if rollback then return rollbackTarget(label) end
        return all()[label]
    end
    local c = checked()
    assert(c.bVisible == (not owned[label]) and (probe or value == (owned[label] == true)),
        "unexpected source state " .. label)
    local pending = {label=label, value=value}
    call = pending
    if not value then owned[label] = true end
    local ok, err = pcall(function() c:SetVisibility(value, false) end)
    call = nil
    if not (pending.pre and pending.post and not pending.foreign) then
        if owned[label] then uncertain[label] = true end
        error(err or ("setter ownership unverified " .. label))
    end
    -- Read back the same live target before releasing ownership.
    local readOK, after = pcall(rollbackTarget, label)
    if not readOK or after.bVisible ~= value then
        if owned[label] then uncertain[label] = true end
        error(readOK and ("setter readback differs " .. label) or after)
    end
    if value then owned[label] = nil end
    assert(ok, err)
    if not rollback then all() end
    if probe then log("SETTER_VERIFIED", "part=" .. label) end
end

local function invalidate(reason)
    token = token + 1
    local old = timer
    timer = nil
    if not old then return end
    local ok = pcall(CancelDelayedAction, old)
    local checked, active = pcall(IsValidDelayedActionHandle, old)
    log("CANCEL", "reason=" .. reason .. " token=" .. token)
    timerUncertain = not (ok and checked and not active)
    assert(not timerUncertain, "timer cancellation unverified")
end
local function stop(reason)
    if phase == -1 then return end
    phase, stopping = -1, true
    log("STOP", "reason=" .. reason)
    for i = #order, 1, -1 do
        local label = order[i]
        if owned[label] then
            local ok, err = pcall(write, label, true, false, true)
            if ok then log("ROLLBACK_PART", "part=" .. label)
            else log("FAILED", "rollback=" .. label .. " detail=" .. string.format("%q", tostring(err))) end
        end
    end
    local clean = pcall(invalidate, "stop") and not timerUncertain and next(owned) == nil and next(uncertain) == nil
    for _, h in ipairs(hooks) do
        local ok = pcall(UnregisterHook, h[1], h[2], h[3])
        clean = clean and ok
    end
    log(clean and "CLEANED" or "CLEANUP_PENDING", clean and "keys=inert owned=false" or "exit_without_saving=true")
end
local function stopLater(reason)
    if stopping or phase == -1 then return end
    stopping = true
    token = token + 1
    local ok = pcall(ExecuteInGameThread, function() stop(reason) end, EGameThreadMethod.EngineTick)
    if not ok then log("CLEANUP_PENDING", "reason=dispatch exit_without_saving=true") end
end
local function failCallback(err)
    for label in pairs(owned) do uncertain[label] = true end
    if call then call.foreign = true end
    log("FAILED", "callback=" .. string.format("%q", tostring(err)))
    stopLater("callback-failure")
end
local function watch(channel, stage, contextParam, flag, propagate)
    if phase == -1 and not call then return end
    local ok, err = pcall(function()
        local o = contextParam:get()
        if not valid(o) then return end
        local watched = session.watch[tostring(o:GetAddress())]
        if not watched then return end
        local label = watched.label
        assert(id(o) == watched.id, "watched address reused")
        if channel == "visible" and call and call.label == label and not call[stage]
            and (stage == "pre" or call.pre) and flag:get() == call.value and propagate:get() == false then
            call[stage] = true
            return
        end
        if phase == dynamic and not stopping and not call and (label == "sheath" or label == "held")
            and channel == "visible" and not next(owned) then
            local value, prop = flag:get(), propagate:get()
            assert(type(value) == "boolean" and prop == false, "unexpected stock sheath writer")
            if label == "held" then
                if stage == "pre" then invalidate("stock-held-setter") end
                return
            end
            if stage == "pre" then
                invalidate("stock-setter")
                writerPair = {value=value}
            elseif writerPair and writerPair.value == value then
                writerPair.post = o.bVisible == value
            end
            return
        end
        if call then call.foreign = true end
        if channel == "visible" and label then owned[label], uncertain[label] = nil, nil end
        log("FOREIGN", "channel=" .. channel .. " stage=" .. stage .. " part=" .. (label or "boundary"))
        stopLater("foreign-writer")
    end)
    if not ok then failCallback(err) end
end
local function hook(n, native, pre, post)
    local f = StaticFindObject(n)
    assert(valid(f) and f:type() == "UFunction" and name(f) == "Function " .. n
        and ((f:GetFunctionFlags() & 0x400) ~= 0) == native, "hook signature mismatch " .. n)
    local a, b
    if native then a, b = RegisterHook(n, pre, post) else a, b = RegisterHook(n, post) end
    hooks[#hooks+1] = {n, a, b}
    assert(math.type(a) == "integer" and math.type(b) == "integer" and a > 0 and b > 0
        and (a ~= b) == native, "hook IDs mismatch " .. n)
end
local function guarded(fn)
    if stopping or phase == -1 then return end
    local ok, err = pcall(fn)
    if not ok then
        log("FAILED", "detail=" .. string.format("%q", tostring(err)))
        stopLater("dynamic-guard")
    end
end
local function setGroup(value)
    for i = 1, #order do write(order[value and #order + 1 - i or i], value) end
end
local function schedule()
    invalidate("fresh-sheath")
    local mine = token
    local handle = ExecuteInGameThreadWithDelay(2000, function()
        if stopping or phase ~= dynamic or token ~= mine or drawPending then return end
        timer = nil
        token = token + 1
        guarded(function()
            all(true)
            setGroup(false)
            log("HIDDEN", "targets=6 token=" .. mine)
        end)
    end)
    assert(math.type(handle) == "integer" and IsValidDelayedActionHandle(handle), "timer handle unavailable")
    timer = handle
    log("SCHEDULE", "delay_ms=2000 token=" .. mine)
end
local function weapon(mode)
    assert(sockets[mode], "unsupported equip mode")
    local pawn, mesh = current()
    local sheath, actor = part("sheath", pawn, mesh, mode)
    checkHeld(actor, mode ~= 1)
    if mode ~= 1 then assert(sheath.bVisible == false, "unexpected stock sheath in hand/floating") end
    return actor
end
local function onDraw(param, animId)
    guarded(function()
        local anim = param:get()
        if id(anim) ~= animId then return end
        assert(phase == dynamic, "skill during visual stage")
        local actor = StaticFindObject(session.parts.sheath.actorPath)
        assert(valid(actor), "draw actor unavailable")
        local mode = actor.equipMode
        weapon(mode)
        local skill = anim:GetToDoSkill():ToString()
        if mode == 0 then
            assert(not next(owned) and not timer and not drawPending, "inconsistent in-hand skill")
            log("SKILL_IN_HAND", "skill=" .. skill)
            return
        end
        invalidate("draw")
        writerPair = nil
        assert(skill == attack, "unsupported draw skill")
        drawPending = true
        if next(owned) then
            assert(mode == 1, "owned mask outside stowed")
            setGroup(true)
        end
        log("DRAW_RELEASED", "owned=false")
    end)
end
local function onEquip(param, modeParam)
    guarded(function()
        if id(param:get()) ~= session.parts.sheath.actor then return end
        assert(phase == dynamic, "equip transition during visual stage")
        local mode = modeParam:get()
        weapon(mode)
        local pair = writerPair
        writerPair = nil
        assert(pair and pair.post and pair.value == (mode == 1), "unpaired equip post")
        assert(not next(owned), "equip post with owned mask")
        if mode == 1 then
            if drawPending then
                invalidate("late-sheath")
                log("SHEATH_SKIP", "reason=draw-pending")
            else
                all(false, 1)
                schedule()
            end
        else
            invalidate("non-sheath")
            if mode == 0 then drawPending = false end
        end
        log("EQUIP_POST", "mode=" .. mode)
    end)
end
local function start()
    local hud = one("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
    local pawn, mesh, generation, anim = context(hud, true)
    session = {hudPath=path(hud), generation=generation, parts={}, watch={}, actors={[id(pawn)]=true}}
    local function watchObject(o, label)
        local address = tostring(o:GetAddress())
        local entry = session.watch[address]
        assert(not entry or (not label and entry.id == id(o)), "overlapping target")
        session.watch[address] = entry or {label=label, id=id(o)}
    end
    watchObject(mesh)
    for _, label in ipairs(order) do
        local n = specs[label][1]
        local actor = n and one(n .. "_C", function(o)
            return class(o) == "BlueprintGeneratedClass " .. bp(n) and id(o:GetOwner()) == id(pawn)
        end) or pawn
        local c, key = resolve(label, pawn, mesh, actor)
        assert(visible(c), "not native visible " .. label)
        session.parts[label] = {actorPath=path(actor), actor=id(actor),
            root=n and id(actor.RootComponent) or nil, generation=key}
        watchObject(c, label)
        session.actors[id(actor)] = true
        if n then watchObject(actor.RootComponent) end
        if label == "sheath" then
            local main, heldKey = held(actor)
            session.held = heldKey
            watchObject(main, "held")
        end
        log("TARGET", "part=" .. label .. " identity=" .. string.format("%q", key))
    end
    RegisterEndPlayPreHook(function(arg)
        if phase == -1 then return end
        local ok, ended = pcall(function() return id(arg:get()) end)
        if not ok or not ended or session.actors[ended] then
            retired = true
            stopLater("end-play")
        end
    end)
    RegisterLoadMapPreHook(function()
        if phase == -1 then return end
        retired = true
        stopLater("load-map")
    end)
    hook(DRAW, true, function(c) onDraw(c, anim) end, function() end)
    hook(bp("HildaCudgel_BP") .. ":EquipModeChange", false, nil, onEquip)
    for _, item in ipairs({{VIS, "visible"}, {HIDDEN, "hidden"}}) do
        local channel = item[2]
        hook(item[1], true, function(c,v,p) watch(channel, "pre", c,v,p) end,
            function(c,v,p) watch(channel, "post", c,v,p) end)
    end
    for _, label in ipairs(order) do write(label, true, true) end
    phase = 1
    log("PREFLIGHT_PASS", "targets=6 held=hidden")
end
local function nextStep()
    if phase == 0 then start(); return end
    if phase == dynamic then return end
    all(true)
    if phase == 1 then
        setGroup(false)
        log("VISUAL_HIDDEN", "targets=6 held=hidden")
    elseif phase == 2 then
        setGroup(true)
        log("VISUAL_RESTORED", "targets=6 held=hidden awaiting_manual_acceptance=true")
    elseif phase == 3 then
        -- Separate deliberate press after the user visually accepts the reversible test.
        setGroup(false)
        log("DYNAMIC_ARMED", "initial_stowed_hidden=true")
    end
    phase = phase + 1
end
local function bind(key, isStop)
    RegisterKeyBind(key, {ModifierKey.CONTROL, ModifierKey.ALT}, function()
        if phase == -1 or stopping then return end
        if isStop then stopLater("user"); return end
        if queued then return end
        queued = true
        local ok = pcall(ExecuteInGameThread, function()
            queued = false
            if stopping or phase == -1 then return end
            local good, err = pcall(nextStep)
            if not good then
                log("FAILED", "detail=" .. string.format("%q", tostring(err)))
                stop("control-failure")
            end
        end, EGameThreadMethod.EngineTick)
        if not ok then
            stopping = true
            log("CLEANUP_PENDING", "reason=key-dispatch exit_without_saving=true")
        end
    end)
end
assert(EngineTickAvailable == true and type(RegisterEndPlayPreHook) == "function"
    and type(RegisterLoadMapPreHook) == "function" and type(ExecuteInGameThreadWithDelay) == "function"
    and type(CancelDelayedAction) == "function" and type(IsValidDelayedActionHandle) == "function",
    "required lifecycle or scheduler API unavailable")
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7, mods) and not IsKeyBindRegistered(Key.F8, mods), "test chord occupied")
bind(Key.F7, false)
bind(Key.F8, true)
log("LOADED", "step=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
