-- SPDX-License-Identifier: MPL-2.0
-- Bounded research write-test for one stationary, stowed stock cudgel session.
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
local hooks, owned, uncertain = {}, {}, {}
local function log(event, fields)
    print("MS_RESIDUAL id=scabbard-residual-isolation-01 event=" .. event .. " " .. (fields or "") .. "\n")
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

local function context(hud)
    assert(not retired and valid(hud) and hud:IsInViewport(), "retired or no gameplay HUD")
    local pawn = hud:GetOwningPlayerPawn()
    assert(class(pawn) == PAWN and pawn.bHidden == false, "invalid local pawn")
    local mesh = pawn.Mesh
    assert(class(mesh) == SKELETAL and name(mesh):match("%.CharacterMesh0$")
        and id(mesh:GetOwner()) == id(pawn) and visible(mesh), "invalid CharacterMesh0")
    local anim = mesh:GetAnimInstance()
    assert((class(anim) or ""):match("%.hilda_AnimBP_C$") and anim:GetToDoSkill():ToString() == "None"
        and anim:GetDoingSkill():ToString() == "None", "anim unavailable or skill active")
    local generation = table.concat({id(hud), id(pawn), id(mesh), id(anim)}, "|")
    return pawn, mesh, generation, id(anim)
end
local function resolve(label, pawn, mesh, actor)
    local spec = specs[label]
    local parent, attach = mesh, spec[4]
    if spec[1] then
        assert(class(actor) == "BlueprintGeneratedClass " .. bp(spec[1])
            and id(actor:GetOwner()) == id(pawn) and actor.bHidden == false
            and actor.equipMode == spec[5], "actor context changed " .. label)
        parent, attach = actor.RootComponent, "None"
        assert(visible(parent) and id(parent:GetOwner()) == id(actor)
            and id(parent:GetAttachParent()) == id(mesh) and socket(parent) == spec[4], "root changed " .. label)
    end
    local c = actor[spec[2]]
    assert(class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and asset(c, spec[3])
        and id(c:GetAttachParent()) == id(parent) and socket(c) == attach
        and type(c.bVisible) == "boolean" and c.bHiddenInGame == false, "component changed " .. label)
    local generation = table.concat({id(actor), id(parent), id(c), id(c.SkeletalMesh)}, "|")
    return c, generation
end
local function held(actor)
    local c = actor.SkeletalMesh
    assert(class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and asset(c, "hilda_cudgel")
        and id(c:GetAttachParent()) == id(actor.RootComponent) and socket(c) == "None"
        and c.bVisible == false and c.bHiddenInGame == false, "held mesh changed")
    return c, id(c) .. "|" .. id(c.SkeletalMesh)
end
local function current()
    local pawn, mesh, generation = context(StaticFindObject(session.hudPath))
    assert(generation == session.generation, "pawn generation changed")
    return pawn, mesh
end
local function part(label, pawn, mesh)
    local saved = session.parts[label]
    local actor = specs[label][1] and StaticFindObject(saved.actorPath) or pawn
    local c, generation = resolve(label, pawn, mesh, actor)
    assert(generation == saved.generation, "instance changed " .. label)
    return c, actor
end
local function checkHeld(actor)
    local _, key = held(actor)
    assert(key == session.held, "held identity changed")
end
local function all()
    local pawn, mesh = current()
    local parts = {}
    for _, label in ipairs(order) do
        local c, actor = part(label, pawn, mesh)
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
    local clean = next(owned) == nil and next(uncertain) == nil
    for _, h in ipairs(hooks) do
        local ok = pcall(UnregisterHook, h[1], h[2], h[3])
        clean = clean and ok
    end
    log(clean and "CLEANED" or "CLEANUP_PENDING", clean and "keys=inert owned=false" or "exit_without_saving=true")
end
local function stopLater(reason)
    if stopping or phase == -1 then return end
    stopping = true
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
local function start()
    local hud = one("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
    local pawn, mesh, generation, anim = context(hud)
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
            watchObject(main)
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
    local function boundary(param, ids, reason)
        if phase == -1 then return end
        local ok, key = pcall(function() return id(param:get()) end)
        if not ok then failCallback(key)
        elseif key and ids[key] then stopLater(reason) end
    end
    local animIds = {[anim]=true}
    hook(DRAW, true, function(c) boundary(c, animIds, "draw-or-skill") end, function() end)
    hook(bp("HildaCudgel_BP") .. ":EquipModeChange", false, nil,
        function(c) boundary(c, session.actors, "equip-transition") end)
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
    all()
    if phase == 1 then
        for i = 1, 3 do write(order[i], false) end
        log("BASE_HIDDEN", "sheath=false A=false B=false")
        log("RESIDUAL_BASELINE", "spear=true staff=true dual=true")
    elseif phase <= 7 then
        local label = order[4 + (phase - 2) // 2]
        local restore = phase % 2 == 1
        write(label, restore)
        log(restore and "CANDIDATE_RESTORED" or "CANDIDATE_HIDDEN", "part=" .. label .. " base=hidden")
    else
        for i = 3, 1, -1 do write(order[i], true) end
        all()
        log("BASE_RESTORED", "all_six=visible held=hidden")
        stop("complete")
        return
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
    and type(RegisterLoadMapPreHook) == "function", "required lifecycle or dispatch API unavailable")
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7, mods) and not IsKeyBindRegistered(Key.F8, mods), "test chord occupied")
bind(Key.F7, false)
bind(Key.F8, true)
log("LOADED", "step=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
