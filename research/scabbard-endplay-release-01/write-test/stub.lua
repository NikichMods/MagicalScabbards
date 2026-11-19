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
    env.UnregisterHook = function() s.unhooks = (s.unhooks or 0)+1 end
    env.RegisterLoadMapPreHook = function(f) s.loadMap = f end
    env.RegisterLoadMapPostHook = function(f) s.loadPost = f end
    env.RegisterEndPlayPreHook = function(f) s.endPlay = f end
    env.ExecuteInGameThread = function(f) s.work[#s.work+1] = f end
    function s.flush()
        while #s.work>0 do table.remove(s.work,1)() end
    end
    function s.press(k) s.keys[k](); s.flush() end
    function s.emit(label, field, value, skip, propagate)
        local part = s[label]
        local property = field == "SetVisibility" and "bVisible" or "bHiddenInGame"
        local pair = s.hooks[field]
        if not skip then assert(pair[1](param(part),param(value),param(propagate==true))==nil) end
        part[property] = value
        if not skip then assert(pair[2](param(part),param(value),param(propagate==true))==nil) end
    end
    s.mesh=mesh
    for _, label in ipairs({"sheath", "A", "B", "spear", "staff", "dual", "mesh", "main"}) do
        s[label].SetVisibility = function(_, value, propagation)
            assert(label=="A" or label=="B","unexpected write "..label)
            assert(propagation == false)
            s.writes[#s.writes+1] = label .. tostring(value)
            if s.rejectRestore == label and value and not s[label].bVisible then error("restore refused") end
            s.emit(label,"SetVisibility",value,s.noDelivery == label or (s.missingHide == label and not value))
            if s.partial == label and not value then error("setter after write") end
        end
    end
    function s.ending(owner) s.endPlay(param(owner)) end
    function s.slot()
        s.hooks.BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature[1](param(pawn))
    end
    function s.draw() s.hooks.BeginDoSkill[1](param(anim)) end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end

local function armed(s)
    s = s or new()
    s.press(7)
    assert(s.has("event=ARMED targets=2") and not s.A.bVisible and not s.B.bVisible,table.concat(s.logs))
    assert(table.concat(s.writes,",")=="Atrue,Btrue,Afalse,Bfalse")
    return s
end
local function clean(s)
    s.press(8)
    assert(s.has("event=CLEANED") and s.A.bVisible and s.B.bVisible,table.concat(s.logs))
end

local s=armed()
s.ending(s.dualActor)
assert(s.A.bVisible and s.B.bVisible and #s.work==0)
assert(s.has("reason=equipment-endplay part=scabbard_a") and s.has("ending_owner_writes=0"))
s.dual.IsValid=function() return false end
s.addComponent("hilda_dual_sheath",true)
s.slot()
assert(s.has("resource=hilda_dual_unuse lookup=not-resolved attached=false writes=0"))
assert(s.has("stage=equipment-post resource=hilda_dual_sheath") and s.scans==2)
assert(table.concat(s.writes,",")=="Atrue,Btrue,Afalse,Bfalse,Btrue,Atrue")
clean(s)
s.press(7)
assert(#s.writes==6)

local retained=armed()
retained.ending(retained.dualActor)
retained.slot()
assert(retained.has("resource=hilda_dual_unuse lookup=same-instance attached=true writes=0"))
clean(retained)

local subset=new()
subset.components={subset.A,subset.B}
armed(subset)
assert(subset.has("stage=arm matches=2 errors=0"))
subset.slot()
assert(subset.has("reason=equipment-post part=scabbard_a"))
clean(subset)

local load=armed()
load.loadMap()
assert(load.has("reason=load-map-pre part=scabbard_a"))
load.noHUD=true
load.loadPost(); load.flush()
assert(load.has("where=load-map-post"))
load.noHUD=false
load.pawn.GetAddress=function() return 2000 end
load.press(7)
assert(load.has("stage=manual-refresh matches=6"))
clean(load)
assert(#load.writes==6)

local missing=armed()
missing.noHUD=true
missing.loadMap()
missing.noHUD=false
missing.pawn.GetAddress=function() return 2000 end
missing.loadPost(); missing.flush()
missing.press(8); missing.press(8)
assert(#missing.writes==4 and missing.has("event=CLEANUP_PENDING") and not missing.has("event=CLEANED"))
assert(missing.has("stage=load-map-post matches=6"))

local retired=armed()
retired.ending(retired.pawn)
retired.press(8)
assert(#retired.writes==4 and retired.has("reason=pawn-end-play generation_retired=true"))

local changed=armed()
changed.A.GetAddress=function() return 7000 end
changed.ending(changed.dualActor)
changed.press(8)
assert(#changed.writes==5 and changed.B.bVisible and not changed.A.bVisible)
assert(changed.has("event=CLEANUP_PENDING"))

local direct=armed()
direct.emit("A","SetVisibility",false)
direct.ending(direct.dualActor)
direct.press(8)
assert(#direct.writes==5 and direct.B.bVisible and not direct.A.bVisible and direct.has("FOREIGN_WRITER"))

local inherited=armed()
inherited.emit("mesh","SetHiddenInGame",false,false,true)
inherited.press(8)
assert(#inherited.writes==4 and inherited.has("event=CLEANUP_PENDING"))

local partial=new()
partial.partial="B"
partial.press(7)
assert(partial.has("event=ARM_FAILED") and partial.has("event=CLEANED"))
assert(partial.A.bVisible and partial.B.bVisible and #partial.writes==6)

local undelivered=new()
undelivered.missingHide="B"
undelivered.press(7)
assert(#undelivered.writes==5 and undelivered.A.bVisible and not undelivered.B.bVisible)
assert(undelivered.has("event=CLEANUP_PENDING"))

local refused=armed()
refused.rejectRestore="B"
refused.ending(refused.dualActor)
refused.press(8)
assert(#refused.writes==6 and refused.A.bVisible and not refused.B.bVisible)
assert(refused.has("event=CLEANUP_PENDING") and not refused.has("event=CLEANED"))

local draw=armed()
draw.draw()
assert(draw.has("reason=local-skill part=scabbard_a"))
clean(draw)
clean(armed())

local unsafe=new()
unsafe.actor.equipMode=0
unsafe.press(7)
assert(unsafe.has("event=ARM_FAILED") and #unsafe.writes==0)

print("PASS: 15 EndPlay-release scenarios; synchronous survivor-only writes, retirement, reload, conflicts and STOP")
