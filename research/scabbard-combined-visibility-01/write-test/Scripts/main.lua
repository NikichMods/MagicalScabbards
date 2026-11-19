-- SPDX-License-Identifier: MPL-2.0
-- One-session research harness. Only the verified stowed cudgel sheath and pawn scabbards A/B may be written.
local BASE = "/Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C"
local EQUIP = BASE .. ":EquipModeChange"
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local HIDDEN = "/Script/Engine.SceneComponent:SetHiddenInGame"
local WEAPONS = "/Game/MainContent/Assets/creature/03_weapon/"
local phase, queued, stopping = "idle", false, false
local hooks, target = {}, nil
local deadline, ownCall
local retired = false
local owned, uncertain = {}, {}
local parts = {"sheath", "A", "B"}
local function log(event, fields)
    print("MS_ISOLATE id=combined-visibility-01 event=" .. event .. " " .. (fields or "") .. "\n")
end
local function valid(o) return o ~= nil and o:IsValid() end
local function identity(o)
    if valid(o) then return o:GetFullName() .. "@" .. tostring(o:GetAddress()) end
end
local function path(o) return assert(o:GetFullName():match("^[^ ]+ (.+)$"), "object path unavailable") end
local function class(o) return valid(o) and o:GetClass():GetFullName() or nil end
local function resolve()
    if retired then return end
    local hud = StaticFindObject(target.hudPath)
    local actor = StaticFindObject(target.actorPath)
    if identity(hud) ~= target.hud or not hud:IsInViewport() or identity(actor) ~= target.actor then return end
    local pawn = hud:GetOwningPlayerPawn()
    if identity(pawn) ~= target.pawn or identity(actor:GetOwner()) ~= target.pawn or pawn.bHidden ~= false then return end
    local mesh, root, sheath, main = pawn.Mesh, actor.RootComponent, actor.hilda_cudgel_sheath, actor.SkeletalMesh
    if identity(mesh) ~= target.mesh or identity(root) ~= target.root
        or identity(sheath) ~= target.sheath or identity(main) ~= target.main then return end
    if identity(root:GetAttachParent()) ~= target.mesh or identity(sheath:GetOwner()) ~= target.actor
        or identity(main:GetOwner()) ~= target.actor or identity(sheath.SkeletalMesh) ~= target.sheathAsset
        or identity(main.SkeletalMesh) ~= target.mainAsset or actor.bHidden ~= false then return end
    return actor, sheath, main, root:GetAttachSocketName():ToString(), pawn
end
local function targetPart(label, pawn, mesh)
    local socket = label == "A" and "scabbard_a" or "scabbard_b"
    local part = pawn[socket]
    local asset = "hilda_scabbard_" .. label
    assert(class(part) == "Class /Script/Engine.SkeletalMeshComponent"
        and identity(part:GetOwner()) == identity(pawn)
        and identity(part:GetAttachParent()) == identity(mesh)
        and part:GetAttachSocketName():ToString() == socket
        and path(part.SkeletalMesh) == WEAPONS .. asset .. "." .. asset, "invalid " .. label)
    return part
end
local function components()
    local actor, sheath, main, socket, pawn = resolve()
    assert(actor and identity(pawn.Mesh:GetAnimInstance()) == target.anim, "context changed")
    local a, b = targetPart("A", pawn, pawn.Mesh), targetPart("B", pawn, pawn.Mesh)
    assert(identity(a) == target.A and identity(b) == target.B
        and identity(a.SkeletalMesh) == target.assetA and identity(b.SkeletalMesh) == target.assetB, "identity changed")
    return {A=a, B=b, actor=actor, sheath=sheath, main=main, socket=socket}
end
local function snapshot(p)
    local flags = {}
    for _, name in ipairs({"A", "B", "sheath", "main"}) do
        local part = p[name]
        assert(type(part.bVisible) == "boolean" and type(part.bHiddenInGame) == "boolean", "flag binding")
        flags[name] = {part.bVisible, part.bHiddenInGame}
    end
    return flags
end
local function checkStowed(p)
    assert(p.actor.equipMode == 1 and p.socket == "scabbard_a", "not stowed")
    local flags = snapshot(p)
    for name, bits in pairs(flags) do
        assert(bits[1] == (not owned[name] and name ~= "main") and bits[2] == false, "unexpected flags " .. name)
    end
end
local function write(label, value, probe)
    local before = components()
    if probe or not value then checkStowed(before) end
    local flags = snapshot(before)
    assert(flags[label][1] == (probe or not value), "unexpected write source")
    local call = {label=label, value=value}
    ownCall = call
    if not value then owned[label] = true end
    local ok, problem = pcall(function() before[label]:SetVisibility(value, false) end)
    ownCall = nil
    if call.pre ~= true or call.post ~= true then
        -- Without the observed pair a changed value alone does not establish ownership.
        uncertain[label] = owned[label] or uncertain[label]
    end
    local after = snapshot(components())
    if after[label][1] and not uncertain[label] then owned[label] = nil end
    assert(ok, problem)
    assert(call.pre and call.post and not call.foreign and not uncertain[label], "setter ownership unverified")
    for name, bits in pairs(flags) do
        local expected = bits[1]
        if name == label then expected = value end
        assert(after[name][1] == expected and after[name][2] == bits[2], "readback changed " .. name)
    end
    log(probe and "SETTER_VERIFIED" or (value and "RESTORED" or "HIDDEN"), "part=" .. label .. " A=" .. tostring(after.A[1])
        .. " B=" .. tostring(after.B[1]) .. " sheath=" .. tostring(after.sheath[1]) .. " main=" .. tostring(after.main[1]))
end
local function release()
    local restored = true
    for i = #parts, 1, -1 do
        local label = parts[i]
        if owned[label] then
            local ok, err = pcall(function()
                assert(not uncertain[label], "ownership uncertain")
                write(label, true)
            end)
            if not ok then log("FAILED", "rollback=" .. label .. " detail=" .. string.format("%q", tostring(err))) end
            restored = restored and ok
        end
    end
    return restored
end
local function stop(reason)
    if phase == "done" then return end
    phase, stopping = "done", true
    log("STOP", "reason=" .. reason)
    local clean = release() and next(owned) == nil and next(uncertain) == nil
    if deadline then
        local ok, inactive = pcall(function()
            if IsValidDelayedActionHandle(deadline) then CancelDelayedAction(deadline) end
            return not IsValidDelayedActionHandle(deadline)
        end)
        clean = clean and ok and inactive
        deadline = nil
    end
    for _, h in ipairs(hooks) do
        local ok = pcall(UnregisterHook, h.path, h.pre, h.post)
        clean = clean and ok
    end
    log(clean and "CLEANED" or "CLEANUP_PENDING", "keys=inert owned=" .. tostring(next(owned) ~= nil))
end
local function stopLater(reason)
    if stopping or phase == "done" then return end
    stopping = true
    local ok = pcall(ExecuteInGameThread, function() stop(reason) end, EGameThreadMethod.EngineTick)
    if not ok then log("CLEANUP_PENDING", "reason=dispatch until=process-exit") end
end
local function guarded(fn)
    if stopping or phase == "idle" or phase == "done" then return end
    local ok, err = pcall(fn)
    if not ok then log("FAILED", "detail=" .. string.format("%q", tostring(err))); stopLater("callback-failure") end
end
local function watch(channel, stage, context, flag, propagation)
    if not target or (phase == "done" and not ownCall) then return end
    local ok, err = pcall(function()
        local object = context:get()
        if not valid(object) then return end
        local address = tostring(object:GetAddress())
        local label = target.address[address]
        if not label then return end
        assert(identity(object) == target[label], "watched address changed identity")
        local call = ownCall
        if channel == "visible" and call and call.label == label and not call[stage]
            and (stage == "pre" or call.pre) and flag:get() == call.value and propagation:get() == false then
            call[stage] = true
            return
        end
        if call then call.foreign = true end
        if channel == "visible" then owned[label], uncertain[label] = nil, nil end
        log("FOREIGN", "channel=" .. channel .. " stage=" .. stage .. " part=" .. label)
        stopLater("foreign-writer")
    end)
    if not ok then
        for label in pairs(owned) do uncertain[label] = true end
        if ownCall then ownCall.foreign = true end
        log("FAILED", "detail=" .. string.format("%q", tostring(err)))
        stopLater("writer-binding")
    end
end
local function hook(name, native, pre, post)
    local f = StaticFindObject(name)
    assert(valid(f) and f:type() == "UFunction" and f:GetFullName() == "Function " .. name
        and ((f:GetFunctionFlags() & 0x400) ~= 0) == native, "hook signature mismatch")
    local a, b
    if native then a, b = RegisterHook(name, pre, post) else a, b = RegisterHook(name, post) end
    hooks[#hooks + 1] = {path=name, pre=a, post=b}
    assert(math.type(a) == "integer" and math.type(b) == "integer" and a > 0 and b > 0
        and (a ~= b) == native, "hook IDs mismatch")
end
local function selectOne(name, predicate)
    local matches, selected = 0, nil
    local list = FindAllOf(name) or {}
    assert(#list <= 8, "lookup budget")
    for _, o in ipairs(list) do
        if valid(o) and predicate(o) then matches, selected = matches + 1, o end
    end
    assert(matches == 1, "expected one " .. name)
    return selected
end
local function start()
    local hud = selectOne("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
    local pawn = hud:GetOwningPlayerPawn()
    assert(class(pawn) == "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C", "pawn class")
    local actor = selectOne("HildaCudgel_BP_C", function(o)
        return class(o) == "BlueprintGeneratedClass " .. BASE and identity(o:GetOwner()) == identity(pawn)
    end)
    local main, sheath, mesh, root = actor.SkeletalMesh, actor.hilda_cudgel_sheath, pawn.Mesh, actor.RootComponent
    assert(valid(main) and valid(sheath) and valid(mesh) and valid(root)
        and identity(main) ~= identity(sheath), "missing cudgel components")
    assert(path(main.SkeletalMesh) == WEAPONS .. "hilda_cudgel.hilda_cudgel"
        and path(sheath.SkeletalMesh) == WEAPONS .. "hilda_cudgel_sheath.hilda_cudgel_sheath", "non-stock asset")
    local anim = mesh:GetAnimInstance()
    assert(valid(anim) and class(anim):match("%.hilda_AnimBP_C$"), "anim identity")
    local a, b = targetPart("A", pawn, mesh), targetPart("B", pawn, mesh)
    assert(identity(a) ~= identity(b) and identity(a) ~= identity(sheath) and identity(b) ~= identity(sheath)
        and identity(a) ~= identity(main) and identity(b) ~= identity(main), "overlapping targets")
    target = {hud=identity(hud), hudPath=path(hud), pawn=identity(pawn), actor=identity(actor), actorPath=path(actor),
        main=identity(main), sheath=identity(sheath), mesh=identity(mesh), root=identity(root), anim=identity(anim),
        sheathAsset=identity(sheath.SkeletalMesh), mainAsset=identity(main.SkeletalMesh),
        A=identity(a), B=identity(b), assetA=identity(a.SkeletalMesh), assetB=identity(b.SkeletalMesh),
        address={[tostring(a:GetAddress())]="A", [tostring(b:GetAddress())]="B",
            [tostring(sheath:GetAddress())]="sheath", [tostring(main:GetAddress())]="main"}}
    checkStowed(components())
    RegisterEndPlayPreHook(function(arg)
        if phase == "done" and not ownCall then return end
        local ok, ended = pcall(function() return identity(arg:get()) end)
        if ok and ended ~= target.actor and ended ~= target.pawn then return end
        retired = true
        stopLater("end-play")
    end)
    RegisterLoadMapPreHook(function()
        if phase == "done" and not ownCall then return end
        retired = true
        stopLater("load-map")
    end)
    hook(DRAW, true, function(c)
        guarded(function()
            if identity(c:get()) == target.anim then stopLater("skill") end
        end)
    end, function() end)
    hook(EQUIP, false, nil, function(c)
        guarded(function()
            if identity(c:get()) == target.actor then stopLater("equip-transition") end
        end)
    end)
    hook(VIS, true, function(c,v,p) watch("visible","pre",c,v,p) end,
        function(c,v,p) watch("visible","post",c,v,p) end)
    hook(HIDDEN, true, function(c,v,p) watch("hidden","pre",c,v,p) end,
        function(c,v,p) watch("hidden","post",c,v,p) end)
    deadline = ExecuteInGameThreadWithDelay(120000, function() deadline = nil; stop("time-limit") end)
    assert(math.type(deadline) == "integer" and IsValidDelayedActionHandle(deadline), "timeout handle unavailable")
    phase = "baseline"
    log("BASELINE", "A=" .. target.A .. " B=" .. target.B .. " sheath=" .. target.sheath .. " A_visible=true B_visible=true sheath_visible=true")
end
local function nextStep()
    if phase == "idle" then start(); return end
    if phase == "baseline" then
        for _, label in ipairs(parts) do
            if stopping then return end
            write(label, true, true)
        end
        for _, label in ipairs(parts) do
            if stopping then return end
            write(label, false)
        end
        if stopping then return end
        checkStowed(components())
        phase = "hidden"
        log("GROUP_HIDDEN", "sheath=false A=false B=false main=false")
    elseif phase == "hidden" then
        stop("complete")
    end
end
assert(EngineTickAvailable == true and type(RegisterEndPlayPreHook) == "function"
    and type(RegisterLoadMapPreHook) == "function" and type(ExecuteInGameThreadWithDelay) == "function"
    and type(CancelDelayedAction) == "function" and type(IsValidDelayedActionHandle) == "function",
    "required scheduler or lifecycle capability unavailable")
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7, mods) and not IsKeyBindRegistered(Key.F8, mods), "test chord occupied")
local function bind(key, fn, isStop)
    RegisterKeyBind(key, mods, function()
        if stopping or phase == "done" or (queued and not isStop) then return end
        queued = true
        if isStop then stopping = true end
        local ok = pcall(ExecuteInGameThread, function()
            queued = false
            if phase == "done" or (stopping and not isStop) then return end
            local good, err = pcall(fn)
            if not good then log("FAILED", "detail=" .. string.format("%q", tostring(err))); stop("control-failure") end
        end, EGameThreadMethod.EngineTick)
        if not ok then
            stopping = true
            log("CLEANUP_PENDING", "reason=key-dispatch until=process-exit")
        end
    end)
end
bind(Key.F7, nextStep, false)
bind(Key.F8, function() stop("user") end, true)
log("LOADED", "step=Ctrl+Alt+F7 stop=Ctrl+Alt+F8 seconds=120")
