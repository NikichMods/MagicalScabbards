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
    mesh.GetAttachParent = function() return nil end
    hud.GetOwningPlayerPawn = function() return s.hudPawn end
    hud.IsInViewport = function() return not s.noHUD end
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
        f.GetFunctionFlags = function() return (p:match(":EquipModeChange$") or p:find(":BndEvt__",1,true)) and 0 or 0x400 end
        return f
    end
    s.components = {main, sheath, s.A, s.B, s.spear, s.staff, s.dual}
    for _, c in ipairs(s.components) do
        objects[c:GetFullName():match("^[^ ]+ (.+)$")] = c
    end
    function s.addComponent(resource, localOwner, packageRoot)
        local index = #s.components
        local path = "/World/Extra" .. index
        local c = obj("Component " .. path, 100+index, "Class /Script/Engine.SkeletalMeshComponent")
        c.SkeletalMesh = obj("SkeletalMesh " .. (packageRoot or asset) .. resource .. "." .. resource, 200+index)
        c.GetOwner = function() return localOwner and pawn or actor end
        c.GetAttachParent = function() return mesh end
        c.GetAttachSocketName = function() return name("scabbard_a") end
        c.bVisible, c.bHiddenInGame = true, false
        c.SetVisibility = function() error("unexpected catalogue write") end
        s.components[#s.components+1], objects[path] = c, c
        return c
    end
    env.FindAllOf = function(n)
        if n == "SkeletalMeshComponent" then
            s.scans = (s.scans or 0)+1
            return s.components
        end
        return n == "HUDMainUMG_BP_C" and {hud} or actors[n]
    end
    env.IsKeyBindRegistered = function() return false end
    env.RegisterKeyBind = function(k, _, f) s.keys[k] = f end
    env.RegisterHook = function(p, a, b)
        s.hooks[p:match(":(.+)$")] = {a,b}
        if b then return 1,2 end
        return 3,3
    end
    env.UnregisterHook = function()
        if s.rejectUnhook then return false end
        s.unhooks = (s.unhooks or 0)+1
    end
    env.RegisterLoadMapPreHook = function(f) s.loadMap = f end
    env.RegisterLoadMapPostHook = function(f) s.loadPost = f end
    env.RegisterEndPlayPreHook = function(f) s.endPlay = f end
    env.ExecuteInGameThread = function(f) s.work[#s.work+1] = f end
    function s.flush()
        while #s.work>0 do table.remove(s.work,1)() end
    end
    function s.press(k) s.keys[k](); s.flush() end
    s.mesh=mesh
    for _, label in ipairs({"sheath", "A", "B", "spear", "staff", "dual", "mesh", "main"}) do
        local function unexpectedWrite()
            s.writes[#s.writes+1]=label
            error("unexpected write "..label)
        end
        s[label].SetVisibility=s[label].SetVisibility or unexpectedWrite
        s[label].SetHiddenInGame=unexpectedWrite
    end
    function s.ending(owner, reason) s.endPlay(param(owner),reason~=nil and param(reason) or nil) end
    function s.slot()
        s.hooks.BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature[1](param(pawn))
    end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end

local s=new()
s.press(7)
assert(s.has("stage=manual attached_matches=6 tracked=4 errors=0"),table.concat(s.logs))
local root=s.dualActor.RootComponent
s.dualActor.IsActorBeingDestroyed=function() return false end
assert(s.hooks.K2_DetachFromComponent[1]({get=function() return root end})==nil)
assert(s.has("stage=root-detach-wrapper-pre resource=hilda_dual_unuse status=attached-local endplay=false"))
assert(s.scans==1)
s.dualActor.IsActorBeingDestroyed=function() return true end
s.ending(s.dualActor,0)
assert(s.has('reason="Destroyed"'))
assert(s.has("stage=endplay-pre resource=hilda_dual_unuse status=attached-local endplay=true"))
assert(s.scans==1)
root.GetAttachParent=function() return nil end
s.slot()
assert(s.has("stage=equipment-post resource=hilda_dual_unuse status=resolved-outside-catalogue endplay=true lookup_gap=false"))
s.press(7)
assert(s.has("stage=manual resource=hilda_dual_unuse status=resolved-outside-catalogue endplay=true lookup_gap=false"))
root.GetAttachParent=function() return s.mesh end
s.dual.bVisible,s.dual.bHiddenInGame=false,true
s.slot()
local last=table.concat(s.logs,"\n"):match(".*(stage=equipment%-post resource=hilda_dual_unuse[^\n]+)")
assert(last and last:find("status=attached-local endplay=true lookup_gap=false",1,true),tostring(last))
assert(last:find("visible=false hidden=true",1,true))

s.ending(s.dualActor,99)
assert(s.has('reason="unknown"'))
s.dual.IsValid=function() return false end
s.press(7)
assert(s.has("resource=hilda_dual_unuse status=not-resolved endplay=true lookup_gap=true"))
s.dual.IsValid=function() return true end
s.press(7)
assert(s.has("resource=hilda_dual_unuse status=attached-local endplay=true lookup_gap=true"))
s.dual.GetAddress=function() return 22222 end
s.slot()
assert(s.has("resource=hilda_dual_unuse status=fingerprint-mismatch endplay=true lookup_gap=true"))
assert(s.has("stage=equipment-post attached_matches=6 tracked=5"))

local foreign=s.addComponent("hilda_dual_use",false)
s.slot()
assert(not s.has("resource=hilda_dual_use"))
assert(foreign.bVisible and #s.writes==0)
local scans=s.scans
s.loadMap()
s.press(7)
assert(s.scans==scans and s.has("no current local Hilda"))
s.pawn.GetAddress=function() return 2222 end
s.press(7)
assert(s.has('event=GENERATION pawn="Pawn /World/Hilda@2222"'))
s.rejectUnhook=true
s.press(8)
assert(s.has("event=CLEANUP_PENDING writes=0"))
scans=s.scans
s.press(7)
assert(s.scans==scans and s.has("event=CLEANUP_PENDING reason=previous-hooks"))
s.rejectUnhook=false
s.press(8)
assert(s.has("event=CLEANED writes=0"))
scans=s.scans
s.slot()
s.ending(s.dualActor,0)
assert(s.scans==scans and #s.writes==0)
s.press(7); s.press(8)
assert(s.scans==scans+1)
print("PASS: equipment lifetime across multiple switches, flags, lookup gaps, replacement, reload and STOP; zero writes")
