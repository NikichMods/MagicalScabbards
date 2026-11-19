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
local function advance(count)
    local s = new()
    for _ = 1, count do s.press(7) end
    return s
end
local function flags(s, baseVisible, hidden)
    assert(s.sheath.bVisible == baseVisible and s.A.bVisible == baseVisible and s.B.bVisible == baseVisible)
    for _, n in ipairs({"spear","staff","dual"}) do assert(s[n].bVisible == (n ~= hidden), n) end
    assert(not s.main.bVisible and not s.main.bHiddenInGame)
end
do
    local s = advance(1)
    flags(s, true)
    assert(s.has("PREFLIGHT_PASS") and #s.writes == 6, table.concat(s.logs))
    s.press(7)
    flags(s, false)
    assert(s.has("BASE_HIDDEN") and s.has("RESIDUAL_BASELINE"))
    for _, label in ipairs({"spear","staff","dual"}) do
        s.press(7); flags(s, false, label); assert(s.has("CANDIDATE_HIDDEN part=" .. label))
        s.press(7); flags(s, false); assert(s.has("CANDIDATE_RESTORED part=" .. label))
    end
    s.press(7); flags(s, true)
    assert(s.has("BASE_RESTORED") and s.has("CLEANED") and s.unhooks == 4)
    assert(table.concat(s.writes,",") == "sheathtrue,Atrue,Btrue,speartrue,stafftrue,dualtrue,"
        .. "sheathfalse,Afalse,Bfalse,spearfalse,speartrue,stafffalse,stafftrue,dualfalse,dualtrue,Btrue,Atrue,sheathtrue")
end
for stage = 0, 8 do
    local s = advance(stage)
    s.press(8)
    flags(s, true)
    assert(s.has("CLEANED") and not s.has("CLEANUP_PENDING"))
    local writes = #s.writes
    s.press(7)
    assert(#s.writes == writes)
end
do
    local s = advance(2); s.keys[7](); s.keys[8](); s.flush()
    flags(s, true); assert(not s.has("CANDIDATE_HIDDEN") and s.has("CLEANED"))
end
do
    local s = new(); s.noDelivery = "dual"; s.press(7)
    flags(s, true); assert(#s.writes == 6 and not s.has("PREFLIGHT_PASS"))
end
for _, label in ipairs({"A","spear"}) do
    local s = advance(label == "A" and 1 or 2); s.partial = label; s.press(7)
    flags(s, true); assert(s.has("FAILED") and s.has("CLEANED"))
end
do
    local s = advance(2); s.missingHide = "spear"; s.press(7)
    flags(s, true, "spear"); assert(s.has("CLEANUP_PENDING"))
end
do
    local s = advance(3); s.rejectRestore = "spear"; s.press(7)
    flags(s, true, "spear"); assert(s.has("CLEANUP_PENDING") and not s.has("CANDIDATE_RESTORED"))
end
do
    local s = advance(3); s.emit("spear","SetVisibility",false); s.flush()
    flags(s, true, "spear"); assert(s.has("FOREIGN") and s.has("CLEANED"))
end
do
    local s = advance(3); s.emit("spear","SetHiddenInGame",true); s.flush()
    flags(s, true, "spear"); assert(s.spear.bHiddenInGame and s.has("CLEANUP_PENDING"))
end
for _, retire in ipairs({
    function(s) s.loadMap() end,
    function(s) s.endPlay({get=function() return s.dualActor end}) end,
    function(s) s.hudPawn = nil; s.press(7) end,
    function(s) s.pawn.GetAddress = function() return 100 end; s.press(7) end,
    function(s) s.actor.equipMode = 2; s.press(7) end,
    function(s) s.skill = "draw"; s.press(7) end,
    function(s) s.socket = "cudgel_r_hand"; s.press(7) end,
}) do
    local s = advance(3); local writes = #s.writes
    retire(s); s.flush()
    assert(#s.writes == writes and s.has("CLEANUP_PENDING"))
end
for _, mutate in ipairs({
    function(s) s.spear.GetAddress = function() return 100 end end,
    function(s) s.spearActor.GetOwner = function() return nil end end,
    function(s) s.spearActor.equipMode = 1 end,
    function(s) s.spearActor.RootComponent.GetAttachSocketName = function() return {ToString=function() return "wrong" end} end end,
}) do
    local s = advance(3); mutate(s); s.press(7)
    flags(s, true, "spear"); assert(s.has("CLEANUP_PENDING"))
end
do
    local s = advance(3)
    s.hooks.BeginDoSkill[1]({get=function() return s.anim end})
    s.flush()
    flags(s, true)
    assert(s.has("reason=draw-or-skill") and s.has("CLEANED"))
end
do
    local s = advance(3)
    s.actor.equipMode = 2
    s.hooks.EquipModeChange[1]({get=function() return s.actor end})
    s.flush()
    flags(s, false, "spear")
    assert(s.has("reason=equip-transition") and s.has("CLEANUP_PENDING"))
end
print("PASS: full sequence, all 9 STOP boundaries, queued STOP, 20 fault/lifecycle cases")
