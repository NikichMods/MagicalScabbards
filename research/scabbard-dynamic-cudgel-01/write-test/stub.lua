-- SPDX-License-Identifier: MPL-2.0
-- Run with stock Lua 5.4: lua stub.lua path/to/Scripts/main.lua
local file = assert(io.open(assert(arg[1]), "r"))
local source = file:read("*a")
file:close()
local function new()
    local s = {keys={}, hooks={}, logs={}, work={}, writes={}, reads=0}
    local env = setmetatable({}, {__index=_G})
    local function obj(name, address, class)
        return {IsValid=function() return true end, GetFullName=function() return name end,
            GetAddress=function() return address end,
            GetClass=function() return {IsValid=function() return true end, GetFullName=function() return class end} end}
    end
    local function param(v) return {get=function() return v end} end
    local function name(v) return {ToString=function() return v end} end
    local base = "/Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C"
    local asset = "/Game/MainContent/Assets/creature/03_weapon/"
    local hud = obj("HUD /World/HUD", 1)
    local pawn = obj("Pawn /World/Hilda", 2, "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C")
    local actor = obj("Actor /World/Cudgel", 3, "BlueprintGeneratedClass " .. base)
    local mesh, root = obj("Mesh /World/Hilda.CharacterMesh0", 4, "Class /Script/Engine.SkeletalMeshComponent"), obj("Root /World/Cudgel.Root", 5)
    local main, sheath = obj("Component /World/Cudgel.Main", 6, "Class /Script/Engine.SkeletalMeshComponent"), obj("Component /World/Cudgel.Sheath", 7, "Class /Script/Engine.SkeletalMeshComponent")
    local anim = obj("Anim /World/Hilda.Anim", 8, "Anim /Game/hilda_AnimBP.hilda_AnimBP_C")
    s.socket, s.pawn, s.actor, s.sheath, s.main, s.hudPawn = "scabbard_a", pawn, actor, sheath, main, pawn
    s.skill, s.anim = "None", anim
    pawn.Mesh, actor.RootComponent, actor.SkeletalMesh, actor.hilda_cudgel_sheath = mesh, root, main, sheath
    actor.bHidden, actor.equipMode = false, 1
    main.bVisible, sheath.bVisible, main.bHiddenInGame, sheath.bHiddenInGame = false, true, false, false
    main.SkeletalMesh = obj("SkeletalMesh " .. asset .. "hilda_cudgel.hilda_cudgel", 9)
    sheath.SkeletalMesh = obj("SkeletalMesh " .. asset .. "hilda_cudgel_sheath.hilda_cudgel_sheath", 10)
    pawn.bHidden = false
    for i, label in ipairs({"A", "B"}) do
        local part = obj("Component /World/Hilda.Scabbard" .. label, 10+i, "Class /Script/Engine.SkeletalMeshComponent")
        local socket = "scabbard_" .. label:lower()
        part.bVisible, part.bHiddenInGame = true, false
        part.GetOwner = function() return pawn end
        part.GetAttachParent = function() return mesh end
        part.GetAttachSocketName = function() return name(socket) end
        local meshName = "hilda_scabbard_" .. label
        part.SkeletalMesh = obj("SkeletalMesh " .. asset .. meshName .. "." .. meshName, 12+i)
        pawn[socket], s[label] = part, part
    end
    mesh.bVisible, root.bVisible = true, true
    mesh.bHiddenInGame, root.bHiddenInGame = false, false
    mesh.GetOwner = function() return pawn end
    root.GetOwner = function() return actor end
    main.GetAttachParent = function() return root end
    sheath.GetAttachParent = main.GetAttachParent
    main.GetAttachSocketName = function() return name("None") end
    sheath.GetAttachSocketName = main.GetAttachSocketName
    local actors, objects = {HildaCudgel_BP_C={actor}}, {["/World/Cudgel"]=actor}
    for i, spec in ipairs({
        {"spear","HildaSpear_Unuse_BP","SkeletalMesh","hilda_spear_unuse","scabbard_a",2},
        {"staff","HildaStaff_BP","hilda_staff_sheath","hilda_staff_sheath","scabbard_b",1},
        {"dual","HildaDual_Unuse_BP","SkeletalMesh","hilda_dual_unuse","scabbard_b",2},
    }) do
        local label, n, property, meshName, attach, mode = table.unpack(spec)
        local a = obj("Actor /World/" .. n, 20+i*4,
            "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/" .. n .. "." .. n .. "_C")
        local r = obj("SceneComponent /World/" .. n .. ".DefaultSceneRoot", 21+i*4)
        local c = obj("SkeletalMeshComponent /World/" .. n .. "." .. property, 22+i*4,
            "Class /Script/Engine.SkeletalMeshComponent")
        a.RootComponent, a[property], a.equipMode, a.bHidden = r, c, mode, false
        a.GetOwner = function() return pawn end
        r.GetOwner = function() return a end
        r.GetAttachParent = function() return mesh end
        r.GetAttachSocketName = function() return name(attach) end
        r.bVisible, r.bHiddenInGame = true, false
        c.GetOwner = r.GetOwner
        c.GetAttachParent = function() return r end
        c.GetAttachSocketName = main.GetAttachSocketName
        c.bVisible, c.bHiddenInGame = true, false
        c.SkeletalMesh = obj("SkeletalMesh " .. asset .. meshName .. "." .. meshName, 23+i*4)
        s[label], s[label.."Actor"] = c, a
        actors[n .. "_C"], objects["/World/" .. n] = {a}, a
    end
    mesh.GetAnimInstance = function() return anim end
    hud.GetOwningPlayerPawn = function() return s.hudPawn end
    hud.IsInViewport = function() return true end
    actor.GetOwner = function() return s.actorOwner or pawn end
    sheath.GetOwner = function() return actor end
    main.GetOwner = sheath.GetOwner
    root.GetAttachParent = function() return mesh end
    root.GetAttachSocketName = function() return name(s.socket) end
    anim.GetToDoSkill = function() return name(s.skill) end
    anim.GetDoingSkill = anim.GetToDoSkill
    env.EngineTickAvailable = true
    env.EGameThreadMethod = {EngineTick=1}
    env.Key, env.ModifierKey = {F7=7,F8=8}, {CONTROL=1,ALT=2}
    env.print = function(line) s.logs[#s.logs+1] = line end
    env.StaticFindObject = function(p)
        s.reads = s.reads + 1
        if p == "/World/HUD" then return hud end
        if objects[p] then return objects[p] end
        local f = obj("Function " .. p, 20)
        f.type = function() return "UFunction" end
        f.GetFunctionFlags = function() return p:match(":EquipModeChange$") and 0 or 0x400 end
        return f
    end
    env.FindAllOf = function(n) return n == "HUDMainUMG_BP_C" and {hud} or actors[n] end
    env.IsKeyBindRegistered = function() return false end
    env.RegisterKeyBind = function(k, _, f) s.keys[k] = f end
    env.RegisterHook = function(p, a, b)
        s.hooks[p:match(":(.+)$")] = {a,b}
        if b then return 1,2 end
        return 3,3
    end
    env.UnregisterHook = function() s.unhooks = (s.unhooks or 0)+1 end
    env.RegisterLoadMapPreHook = function(f) s.loadMap = f end
    env.RegisterEndPlayPreHook = function(f) s.endPlay = f end
    env.ExecuteInGameThread = function(f) s.work[#s.work+1] = f end
    s.timers = {}
    env.ExecuteInGameThreadWithDelay = function(ms, fn)
        assert(ms == 2000)
        local i = #s.timers + 1
        s.timers[i] = {active=true, run=fn}
        return i
    end
    env.IsValidDelayedActionHandle = function(i) return s.timers[i].active end
    env.CancelDelayedAction = function(i)
        if not s.rejectCancel then s.timers[i].active = false end
    end
    function s.fire(i)
        s.timers[i].active = false
        s.timers[i].run()
        s.flush()
    end
    function s.flush()
        while #s.work>0 do table.remove(s.work,1)() end
    end
    function s.press(k) s.keys[k](); s.flush() end
    function s.emit(label, field, value, skip)
        local part = s[label]
        local property = field == "SetVisibility" and "bVisible" or "bHiddenInGame"
        local pair = s.hooks[field]
        if not skip then assert(pair[1](param(part),param(value),param(false))==nil) end
        part[property] = value
        if not skip then assert(pair[2](param(part),param(value),param(false))==nil) end
    end
    for _, label in ipairs({"sheath", "A", "B", "spear", "staff", "dual"}) do
        s[label].SetVisibility = function(_, value, propagation)
            assert(propagation == false)
            s.writes[#s.writes+1] = label .. tostring(value)
            if s.rejectRestore == label and value then error("restore refused") end
            s.emit(label,"SetVisibility",value,s.noDelivery == label or (s.missingHide == label and not value))
            if s.partial == label and not value then error("setter after write") end
        end
    end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end
local function flags(s, visible)
    for _, n in ipairs({"sheath","A","B","spear","staff","dual"}) do
        assert(s[n].bVisible == visible, n .. ": " .. table.concat(s.logs))
        assert(not s[n].bHiddenInGame)
    end
    assert(not s.main.bVisible)
end
local function advance(count)
    local s = new()
    for _ = 1, count do s.press(7) end
    return s
end
local function draw(s)
    s.skill = "hilda_cudgel_atk1_idle"
    s.hooks.BeginDoSkill[1]({get=function() return s.anim end})
    s.skill = "None"
    s.flush()
end
local function equip(s, mode, keepOldMode)
    local socket = ({[0]="cudgel_r_hand", [1]="scabbard_a", [3]="dual_l_hand"})[mode]
    s.socket = socket
    if not keepOldMode then s.actor.equipMode = mode end
    s.emit("main","SetVisibility",mode ~= 1)
    s.emit("sheath","SetVisibility",mode == 1)
    s.hooks.EquipModeChange[1]({get=function() return s.actor end}, {get=function() return mode end})
    s.actor.equipMode = mode
    s.flush()
end
local function stow(s)
    equip(s, 0); equip(s, 3); equip(s, 1, true)
end
do
    local s = advance(1); flags(s,true)
    s.press(7); flags(s,false); assert(s.has("VISUAL_HIDDEN"))
    s.press(7); flags(s,true); assert(s.has("VISUAL_RESTORED") and #s.timers == 0)
    s.press(7); flags(s,false); assert(s.has("DYNAMIC_ARMED"))
    draw(s); flags(s,true); assert(s.has("DRAW_RELEASED"))
    equip(s,0); draw(s); assert(s.has("SKILL_IN_HAND") and not s.has("STOP") and s.main.bVisible, table.concat(s.logs))
    equip(s,3); equip(s,1,true); flags(s,true); assert(s.timers[1].active)
    s.fire(1); flags(s,false); assert(s.has("HIDDEN targets=6 token="))
    s.press(8); flags(s,true); assert(s.has("CLEANED"))
end
do
    local s = advance(4); draw(s); equip(s,1); flags(s,true)
    assert(s.has("SHEATH_SKIP") and #s.timers == 0)
    stow(s); s.fire(1); flags(s,false)
end
do
    local s = advance(4); draw(s); stow(s); equip(s,1)
    assert(#s.timers == 2 and not s.timers[1].active and s.timers[2].active)
    s.fire(1); flags(s,true)
    s.fire(2); flags(s,false)
end
do
    local s = advance(4); draw(s); stow(s); draw(s); flags(s,true)
    assert(not s.timers[1].active)
    s.fire(1); flags(s,true)
    stow(s); s.fire(2); flags(s,false)
end
for stage = 0, 4 do
    local s = advance(stage); s.press(8); flags(s,true)
    assert(s.has("CLEANED") and not s.has("CLEANUP_PENDING"))
end
for _, change in ipairs({
    function(s) s.hudPawn=nil end,
    function(s) s.staff.GetAddress=function() return 999 end end,
    function(s) s.dualActor.equipMode=1 end,
    function(s) s.socket="cudgel_r_hand" end,
    function(s) s.skill="unknown" end,
}) do
    local s = advance(4); draw(s); stow(s)
    local writes = #s.writes
    change(s); s.fire(1)
    assert(#s.writes == writes and s.has("STOP") and not s.has("HIDDEN targets=6 token="))
end
for _, phase in ipairs({"manual","timer"}) do
    local s = advance(phase == "manual" and 1 or 4)
    if phase == "timer" then draw(s); stow(s) end
    s.partial = "staff"
    if phase == "manual" then s.press(7) else s.fire(1) end
    flags(s,true); assert(s.has("FAILED") and s.has("CLEANED"))
end
do
    local s = advance(1); s.missingHide = "staff"; s.press(7)
    assert(not s.staff.bVisible and s.spear.bVisible and s.A.bVisible and s.has("CLEANUP_PENDING"))
end
do
    local s = advance(4); s.rejectRestore="staff"; draw(s)
    assert(not s.staff.bVisible and s.spear.bVisible and s.A.bVisible and s.has("CLEANUP_PENDING"))
end
do
    local s = advance(4); s.emit("spear","SetVisibility",false); s.flush()
    assert(not s.spear.bVisible and s.staff.bVisible and s.has("FOREIGN") and s.has("CLEANED"))
end
do
    local s = advance(4); draw(s); stow(s); s.loadMap(); s.flush()
    s.fire(1); flags(s,true); assert(s.has("CLEANED"))
end
do
    local s = advance(4); draw(s); stow(s); s.rejectCancel = true; draw(s)
    s.fire(1); flags(s,true); assert(s.has("STOP") and s.has("timer cancellation unverified"))
end
do
    local s = new(); s.noDelivery="dual"; s.press(7)
    flags(s,true); assert(not s.has("PREFLIGHT_PASS") and s.has("CLEANED"))
end
print("PASS: 22 dynamic-cudgel scenarios")
