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
    actor.IsActorBeingDestroyed=function() return s.destroying==actor end
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
        a.IsActorBeingDestroyed=function() return s.destroying==a end
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
    mesh.GetAttachSocketName = function() return name("None") end
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
        if n=="HildaCudgel_BP_C" and s.noCudgel then return {} end
        return n == "HUDMainUMG_BP_C" and {hud} or actors[n]
    end
    env.IsKeyBindRegistered = function() return false end
    env.RegisterKeyBind = function(k, _, f) s.keys[k] = f end
    s.equipHooks={}
    env.RegisterHook = function(p, a, b)
        local equipClass=p:match("%.([%w_]+)_C:EquipModeChange$")
        if equipClass then s.equipHooks[equipClass]=a else s.hooks[p:match(":(.+)$")] = {a,b} end
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
    s.timers={}
    env.ExecuteInGameThreadWithDelay=function(ms,fn)
        assert(ms==2000)
        s.timers[#s.timers+1]={live=true,fn=fn}
        return #s.timers
    end
    env.CancelDelayedAction=function(i) if not s.rejectCancel then s.timers[i].live=false end end
    env.IsValidDelayedActionHandle=function(i) return s.timers[i].live end
    function s.fire(i)
        s.timers[i].live=false
        s.timers[i].fn()
        s.flush()
    end
    function s.flush()
        while #s.work>0 do table.remove(s.work,1)() end
    end
    function s.press(k) s.keys[k](); s.flush() end
    s.mesh=mesh
    function s.stock(part,value,propagate,skip)
        local pair=s.hooks.SetVisibility
        if not skip then assert(pair[1](param(part),param(value),param(propagate==true))==nil) end
        part.bVisible=value
        if not skip then assert(pair[2](param(part),param(value),param(propagate==true))==nil) end
    end
    local function setter(part,label)
        part.SetVisibility=function(_,value,propagate)
            assert(label~="mesh" and label~="main","attempt to write held/pawn mesh")
            assert(propagate==false,"unexpected propagation")
            s.writes[#s.writes+1]=label..tostring(value)
            s.stock(part,value,false,s.noDelivery==label and value==false)
            if s.failHide==label and not value then error("failed after hide") end
        end
    end
    for _, label in ipairs({"sheath", "A", "B", "spear", "staff", "dual", "mesh", "main"}) do
        local function unexpectedWrite()
            s.writes[#s.writes+1]=label
            error("unexpected write "..label)
        end
        setter(s[label],label)
        s[label].SetHiddenInGame=unexpectedWrite
    end
    function s.ending(owner, reason) s.endPlay(param(owner),reason~=nil and param(reason) or nil) end
    function s.slot()
        s.hooks.BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature[1](param(pawn))
    end
    function s.draw(family)
        s.skill="hilda_"..(family or "cudgel").."_atk1_idle"
        s.hooks.BeginDoSkill[1](param(anim))
        s.skill="None"
    end
    function s.equip(mode)
        s.socket=({[0]="cudgel_r_hand",[1]="scabbard_a",[3]="dual_l_hand"})[mode]
        s.stock(main,mode~=1)
        s.stock(sheath,mode==1)
        s.equipHooks.HildaCudgel_BP(param(actor),param(mode))
        actor.equipMode=mode
        s.flush()
    end
    function s.addWeapon(className,family,heldAsset,mount,index)
        local actorPath="/World/Weapon_"..className
        local owner=obj("Actor "..actorPath,index,
            "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/"..className.."."..className.."_C")
        local root=obj("Root "..actorPath..".Root",index+1)
        owner.GetOwner=function() return pawn end
        owner.IsActorBeingDestroyed=function() return s.destroying==owner end
        owner.RootComponent,owner.equipMode,owner.bHidden=root,1,false
        root.GetOwner=function() return owner end
        root.GetAttachParent=function() return mesh end
        root.GetAttachSocketName=function() return name(owner.equipMode==1 and mount or "held") end
        root.bVisible,root.bHiddenInGame=true,false
        local function component(field,resource,address,shown)
            local p=actorPath.."."..field
            local c=obj("Component "..p,address,"Class /Script/Engine.SkeletalMeshComponent")
            c.GetAttachParent=function() return root end
            c.GetAttachSocketName=function() return name("None") end
            c.GetOwner=root.GetOwner
            c.SkeletalMesh=obj("SkeletalMesh "..asset..resource.."."..resource,address+10)
            c.bVisible,c.bHiddenInGame=shown,false
            owner[field],objects[p]=c,c
            s.components[#s.components+1]=c
            return c
        end
        local held=component("SkeletalMesh",heldAsset,index+2,false)
        local sheath
        if family then
            local resource="hilda_"..family.."_sheath"
            sheath=component(resource,resource,index+3,true)
            setter(sheath,family.."-sheath")
        end
        local blade
        if family=="dual" then blade=component("hilda_dualblade_mesh","hilda_dualblade_mesh",index+4,false) end
        actors[className.."_C"],objects[actorPath]={owner},owner
        local function equip(mode)
            -- Attachment moves before the Blueprint dispatch, field commits after it.
            root.GetAttachSocketName=function() return name(mode==1 and mount or "held") end
            s.stock(held,mode==0)
            if sheath then s.stock(sheath,mode==1) end
            if blade then s.stock(blade,mode==3) end
            s.equipHooks[className](param(owner),param(mode))
            owner.equipMode=mode
        end
        return {owner=owner,root=root,held=held,sheath=sheath,blade=blade,equip=equip}
    end
    function s.removeWeapon(className,weapon)
        s.destroying=weapon.owner
        s.ending(weapon.owner,0)
        weapon.root.GetAttachParent=function() return nil end
        actors[className.."_C"]=nil
    end
    function s.newSpear()
        local owner=obj("Actor /World/NewSpear",888,s.spearActor:GetClass():GetFullName())
        owner.IsActorBeingDestroyed=function() return false end
        owner.GetOwner=function() return pawn end
        owner.equipMode,owner.bHidden=2,false
        local r=obj("Root /World/NewSpear.Root",889)
        r.GetAttachParent=function() return mesh end
        r.GetAttachSocketName=function() return name("scabbard_a") end
        r.GetOwner=function() return owner end
        r.bVisible,r.bHiddenInGame=true,false
        local c=obj("Component /World/NewSpear.Mesh",890,"Class /Script/Engine.SkeletalMeshComponent")
        c.GetAttachParent=function() return r end
        c.GetAttachSocketName=function() return name("None") end
        c.GetOwner=r.GetOwner
        c.SkeletalMesh,c.bVisible,c.bHiddenInGame=s.spear.SkeletalMesh,true,false
        owner.RootComponent,owner.SkeletalMesh=r,c
        s.components[#s.components+1],objects["/World/NewSpear.Mesh"]=c,c
        setter(c,"new-spear")
        return c
    end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end

local function started()
    local s=new()
    s.press(7)
    assert(s.has("equipped_adapter=true"),table.concat(s.logs))
    return s
end
local function suppress(s)
    s.equip(1)
    assert(s.timers[#s.timers] and s.timers[#s.timers].live,table.concat(s.logs))
    s.fire(#s.timers)
end

local s=started()
assert(#s.writes==0)
s.equip(1); s.equip(1)
assert(#s.timers==2 and not s.timers[1].live and s.timers[2].live)
s.fire(1)
assert(#s.writes==0)
s.draw(); s.fire(2)
assert(#s.writes==0 and s.has("reason=local-skill-pre"))
s.equip(1)
assert(#s.timers==2 and s.has("reason=draw-pending"))
s.equip(0); s.equip(3)
suppress(s)
assert(s.has("state=SUPPRESSED category=PASS event=HIDDEN reason=sheath-delay targets=6"),table.concat(s.logs))
assert(not s.A.bVisible and not s.B.bVisible and not s.main.bVisible)
s.draw()
assert(s.A.bVisible and s.B.bVisible and s.sheath.bVisible and not s.main.bVisible)
s.press(8); s.press(7); s.press(8)
assert(s.has("epoch=2 state=PASS-THROUGH category=PASS event=CLEANED"))

local partial=started()
partial.components={partial.A,partial.sheath,partial.main}
local resources={"hilda_cudgel_use","hilda_cudgel_unuse","hilda_dual_sheath","hilda_dual_use","hilda_dual_unuse",
    "hilda_spear_sheath","hilda_spear_use","hilda_spear_unuse","hilda_staff_sheath","hilda_staff_use",
    "hilda_staff_unuse","hilda_shield_sheath","hilda_scabbard_B"}
local excluded={}
for _, resource in ipairs(resources) do excluded[#excluded+1]=partial.addComponent(resource,true) end
excluded[#excluded+1]=partial.addComponent("hilda_scabbard_A",false)
excluded[#excluded+1]=partial.addComponent("hilda_scabbard_A",true,"/Game/Other/")
suppress(partial)
assert(partial.has("matches=15 eligible=2") and partial.has("reason=sheath-delay targets=2"),table.concat(partial.logs))
for _,c in ipairs(excluded) do assert(c.bVisible) end
partial.press(8)

local replaced=started()
suppress(replaced)
local old=replaced.spear
replaced.destroying=replaced.spearActor
replaced.ending(replaced.spearActor,0)
assert(replaced.A.bVisible and replaced.B.bVisible and not old.bVisible)
replaced.spearActor.RootComponent.GetAttachParent=function() return nil end
local incoming=replaced.newSpear()
replaced.slot(); replaced.flush()
assert(replaced.has("category=RETIRED event=DESTROYED_OWNER asset=hilda_spear_unuse"))
assert(replaced.has("reason=equipment-endplay targets=6"),table.concat(replaced.logs))
assert(not incoming.bVisible and #replaced.timers==1 and not old.bVisible)
replaced.press(8)
assert(incoming.bVisible and not old.bVisible and replaced.has("event=CLEANED retired=1"))

local change=started()
suppress(change)
change.destroying=change.dualActor; change.ending(change.dualActor,0)
change.destroying=change.actor; change.ending(change.actor,0)
change.noCudgel=true
change.slot(); change.flush()
assert(change.has("reason=stowed-not-retained"))
assert(change.A.bVisible and change.B.bVisible and change.spear.bVisible and change.staff.bVisible)
assert(not change.dual.bVisible and not change.sheath.bVisible)
change.press(8)
assert(change.has("event=CLEANED retired=2"))

local unknown=started()
suppress(unknown)
unknown.ending(unknown.dualActor,3)
unknown.slot(); unknown.flush(); unknown.press(8)
assert(unknown.has("event=UNKNOWN_ENDPLAY") and not unknown.has("event=CLEANED"))
assert(unknown.A.bVisible and unknown.spear.bVisible and not unknown.dual.bVisible)
unknown.press(7)
assert(unknown.has("event=START_BLOCKED"))

local reload=started()
suppress(reload)
reload.loadMap()
assert(reload.A.bVisible and reload.B.bVisible and reload.has("reason=load-map"))
local writes=#reload.writes
reload.noHUD=true
reload.loadPost(); reload.flush()
assert(#reload.writes==writes)
reload.noHUD=false
reload.pawn.GetAddress=function() return 1999 end
reload.press(7)
suppress(reload)
assert(not reload.A.bVisible)
reload.press(8)
assert(reload.has("event=CLEANED"))

local lost=started()
suppress(lost)
local oldCount=#lost.writes
lost.noHUD=true
lost.loadMap()
lost.press(8)
assert(#lost.writes==oldCount and lost.has("event=RELEASE_REFUSED") and not lost.has("event=CLEANED"))

local conflict=started()
suppress(conflict)
conflict.stock(conflict.A,false)
conflict.flush()
assert(conflict.has("event=FOREIGN_WRITER") and conflict.B.bVisible and not conflict.A.bVisible)
conflict.press(8)
assert(not conflict.has("event=CLEANED"))

local failure=started()
failure.failHide="staff"
suppress(failure)
assert(failure.has("event=HIDE") and failure.staff.bVisible and failure.A.bVisible)
failure.press(8)
assert(failure.has("event=CLEANED"))

local missing=started()
missing.noDelivery="staff"
suppress(missing)
assert(missing.has("event=HIDE") and not missing.staff.bVisible and missing.A.bVisible)
missing.press(8)
assert(not missing.has("event=CLEANED"))

local stale=started()
stale.equip(1)
stale.A.GetAddress=function() return 7777 end
stale.fire(1)
assert(#stale.writes==0 and stale.has("target generation changed"))
stale.press(8)

local timerFault=started()
timerFault.equip(1)
timerFault.rejectCancel=true
timerFault.draw()
timerFault.press(8)
assert(timerFault.has("event=TIMER_CANCEL") and not timerFault.has("event=CLEANED"))
timerFault.fire(1)
assert(#timerFault.writes==0)
timerFault.press(8); timerFault.press(7)
assert(timerFault.has("event=CLEANED") and timerFault.has("epoch=2"))

local multi=started()
local staff=multi.addWeapon("HildaStaff_BP","staff","hilda_staff","scabbard_b",3000)
multi.slot(); multi.flush()
staff.equip(1)
assert(#multi.timers==0,"staff armed before observed early draw")
multi.draw("staff"); staff.equip(0); staff.equip(1)
assert(#multi.timers==1 and multi.has("event=DRAW_ROUTE family=staff"))
multi.draw("staff"); multi.fire(1)
assert(#multi.writes==0)
staff.equip(1)
assert(#multi.timers==1,"late staff Sheath bypassed draw latch")
staff.equip(0); staff.equip(1); staff.equip(1)
assert(#multi.timers==3 and not multi.timers[2].live)
multi.fire(3)
assert(not staff.sheath.bVisible and not staff.held.bVisible and multi.has("event=HIDDEN"),table.concat(multi.logs))

multi.removeWeapon("HildaStaff_BP",staff)
local dual=multi.addWeapon("HildaDualMain_BP","dual","hilda_dualmain_mesh","scabbard_b",3100)
local off=multi.addWeapon("HildaDualOff_BP",nil,"hilda_dualoff_mesh","scabbard_b",3200)
multi.slot(); multi.flush()
assert(multi.A.bVisible and multi.has("event=DESTROYED_OWNER asset=hilda_staff_sheath"))
multi.draw("dual"); off.equip(0); dual.equip(0); dual.equip(1)
assert(#multi.timers==4)
multi.fire(4)
assert(dual.sheath.bVisible and off.held.bVisible and multi.has("offhand not stowed"))
off.equip(1); dual.equip(1); multi.fire(5)
assert(not dual.sheath.bVisible and not dual.held.bVisible and not dual.blade.bVisible and not off.held.bVisible)
multi.draw("cudgel"); multi.equip(0); multi.equip(1)
multi.fire(6)
assert(not multi.A.bVisible and not multi.main.bVisible)
multi.press(8)
assert(multi.A.bVisible and multi.has("event=CLEANED"))

local unsupported=started()
local spear=unsupported.addWeapon("HildaSpear_BP","spear","hilda_spear","scabbard_a",3300)
unsupported.slot(); unsupported.flush()
unsupported.draw("spear"); spear.equip(0); spear.equip(1)
assert(#unsupported.timers==0 and #unsupported.writes==0)
unsupported.press(8)

local residual=started()
local extra=residual.addWeapon("HildaStaff_Unuse_BP",nil,"hilda_staff_unuse","scabbard_b",3400)
extra.owner.equipMode=2
extra.held.bVisible=true
suppress(residual)
assert(residual.has("asset=hilda_staff_unuse role=unuse") and residual.has("reason=role-unproven"))
assert(extra.held.bVisible and not residual.main.bVisible)
extra.root.GetAttachParent=function() return nil end
residual.slot(); residual.flush()
assert(residual.has("reason=root-attachment-mismatch"))
residual.press(8)

local sixth=started()
sixth.staffActor.equipMode=2
suppress(sixth)
assert(sixth.has("asset=hilda_staff_sheath role=known-rule") and sixth.has("reason=equip-mode-mismatch"))
assert(sixth.staff.bVisible and sixth.has("reason=sheath-delay targets=5"))
sixth.draw(); sixth.equip(0)
sixth.staffActor.equipMode=1
suppress(sixth)
assert(not sixth.staff.bVisible and sixth.has("reason=sheath-delay targets=6") and not sixth.main.bVisible)
sixth.press(8)

local swap=started()
local blade=swap.addWeapon("HildaDualMain_BP","dual","hilda_dualmain_mesh","scabbard_b",3500)
local second=swap.addWeapon("HildaDualOff_BP",nil,"hilda_dualoff_mesh","scabbard_b",3600)
swap.slot(); swap.flush()
swap.draw("dual"); second.equip(0); blade.equip(0)
local scans=swap.scans
swap.removeWeapon("HildaDualOff_BP",second)
swap.flush()
assert(swap.scans>scans,"known offhand with no catalogue mesh must still trigger refresh")
swap.removeWeapon("HildaDualMain_BP",blade)
swap.flush()
local replacement=swap.addWeapon("HildaStaff_BP","staff","hilda_staff","scabbard_b",3700)
replacement.equip(1) -- delivered before the catalogue has seen the new instance
assert(swap.has("event=ADAPTER_POST") and swap.has("reason=actor-untracked"))
assert(#swap.timers==0 and #swap.writes==0)
swap.flush()
replacement.equip(1)
assert(#swap.timers==0)
swap.draw("staff"); replacement.equip(0); replacement.equip(1)
swap.fire(1)
assert(not replacement.sheath.bVisible and not replacement.held.bVisible,table.concat(swap.logs))
swap.press(8)
assert(swap.has("event=CLEANED"))

local late=started()
local lateStaff=late.addWeapon("HildaStaff_BP","staff","hilda_staff","scabbard_b",3800)
late.draw("staff") -- no slot post or EndPlay refresh yet
assert(late.has("event=ADAPTER_REBOUND stage=draw"))
lateStaff.equip(0); lateStaff.equip(1); late.fire(1)
assert(not lateStaff.sheath.bVisible)
late.press(8)
print("PASS: integrated catalogue, two policies, timers, retirement, new instances, reload, cleanup, conflicts and partial rollback")
