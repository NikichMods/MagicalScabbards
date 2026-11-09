-- SPDX-License-Identifier: MPL-2.0
-- Integrated 07 RESEARCH DRAFT (NOT EXECUTED). One stock Sheath event; native registry proves the full kit before any write.
local ITEM = "/Game/MainContent/Act/Item_BP/"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local PAWN = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local catalogue = {}
local function addAsset(n)
    catalogue[MESH .. n .. "." .. n] = n
end
for _, family in ipairs({"cudgel", "dual", "spear", "staff"}) do
    for _, suffix in ipairs({"sheath", "use", "unuse"}) do
        addAsset("hilda_" .. family .. "_" .. suffix)
    end
end
for _, n in ipairs({"hilda_shield_sheath", "hilda_scabbard_A", "hilda_scabbard_B"}) do
    addAsset(n)
end
local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (name(o) .. "@" .. tostring(o:GetAddress())) or nil end
local function class(o) return valid(o) and name(o:GetClass()) or nil end
local function path(o) return assert(name(o):match("^[^ ]+ (.+)$")) end
local function socket(o) return o:GetAttachSocketName():ToString() end
local function asset(o, n) return name(o.SkeletalMesh) == MESH .. n .. "." .. n end
local function catalogueRow(c, pawn, mesh, includeRejected)
    if class(c) ~= SKELETAL then return end
    local resource = catalogue[name(c.SkeletalMesh)]
    if not resource then return end
    local owner, parent = c:GetOwner(), c:GetAttachParent()
    local ownerId, parentId = id(owner), id(parent)
    if not ownerId then return end
    local pawnOwned=ownerId==id(pawn)
    if not pawnOwned and id(owner:GetOwner())~=id(pawn) then return end
    local reason
    if not parentId then reason="attach-parent-missing"
    elseif pawnOwned and parentId~=id(mesh) then reason="pawn-parent-mismatch"
    elseif not pawnOwned and (id(owner.RootComponent)~=parentId or id(parent:GetOwner())~=ownerId
        or id(parent:GetAttachParent())~=id(mesh)) then reason="root-attachment-mismatch" end
    if reason and not includeRejected then return end
    return {
        path=path(c), component=id(c), owner=ownerId, resource=resource, socket=socket(c), parent=parentId,
        mount=pawnOwned and socket(c) or (parentId and socket(parent) or nil),
        key=table.concat({id(c), id(c.SkeletalMesh), ownerId, parentId or ""}, "|"),
    },reason
end
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
    assert(valid(hud) and hud:IsInViewport(), "retired or no gameplay HUD")
    local pawn = hud:GetOwningPlayerPawn()
    assert(class(pawn) == PAWN and pawn.bHidden == false, "invalid local pawn")
    local mesh = pawn.Mesh
    assert(class(mesh) == SKELETAL and name(mesh):match("%.CharacterMesh0$")
        and id(mesh:GetOwner()) == id(pawn) and visible(mesh), "invalid CharacterMesh0")
    local anim = mesh:GetAnimInstance()
    assert((class(anim) or ""):match("%.hilda_AnimBP_C$"), "anim unavailable")
    local generation = table.concat({id(hud), id(pawn), id(mesh), id(anim)}, "|")
    return pawn, mesh, generation, id(anim)
end

local SLOT = PAWN:match("^[^ ]+ (.+)$")
    .. ":BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature"
local adapters = {
    HildaCudgel_BP={weapon=2, family="cudgel", mount="scabbard_a", held="hilda_cudgel"},
    HildaStaff_BP={weapon=4, family="staff", mount="scabbard_b", held="hilda_staff", switchSkill="hilda_staff_atk1"},
    HildaDualMain_BP={weapon=1, family="dual", mount="scabbard_b", held="hilda_dualmain_mesh", off=true},
    HildaDualOff_BP={weapon=1, held="hilda_dualoff_mesh"},
    HildaSpear_BP={weapon=3, held="hilda_spear"},
    HildaShield_BP={weapon=0, held="hilda_shield"},
}
local stockClass = {}
local drawClass = {}
local drawSignals = {}
for n,adapter in pairs(adapters) do
    adapter.event=bp(n)..":EquipModeChange"
    stockClass["BlueprintGeneratedClass "..bp(n)]=adapter
    if adapter.family then
        drawClass[adapter.family]=n.."_C"
        drawSignals["hilda_"..adapter.family.."_atk1_idle"]=adapter.family
        if adapter.switchSkill then drawSignals[adapter.switchSkill]=adapter.family end
    end
end
-- One structural role factory for all 15 stock assets, not an historical allowlist.
local stockMount={cudgel="scabbard_a",dual="scabbard_b",spear="scabbard_a",staff="scabbard_b"}
local function titlePart(s) return s:sub(1,1):upper()..s:sub(2) end
local function proof(resource)
    if resource=="hilda_scabbard_A" then return {false,"scabbard_a","scabbard_a"} end
    if resource=="hilda_scabbard_B" then return {false,"scabbard_b","scabbard_b"} end
    if resource=="hilda_shield_sheath" then
        return {"HildaShield_BP","hilda_shield_sheath","scabbard_any",1}
    end
    local family,suffix=resource:match("^hilda_(%a+)_(%a+)$")
    local mount=stockMount[family]
    if not mount then return nil end
    if suffix=="sheath" then
        local actor=family=="dual" and "HildaDualMain_BP" or "Hilda"..titlePart(family).."_BP"
        return {actor,resource,mount,1}
    elseif suffix=="unuse" or suffix=="use" then
        return {"Hilda"..titlePart(family).."_"..titlePart(suffix).."_BP",
            "SkeletalMesh",mount,suffix=="unuse" and 2 or "attached-use"}
    end
end
local state, active, epoch, token = "PASS-THROUGH", false, 0, 0
local bound, anchor, suppression, timer, timerDebt, call, retiredPawn
local drawPending, transition, refreshQueued, fault = false, false, false, false
local pendingSheath
local actors, watched, observedDraw, catalogueWatch = {}, {}, {}, {}
local setup, queueRefresh, safeOwnership
local hooks, hookReady, leases, owners, ending = {}, {}, {}, {}, {}
local hookDebt=false
local retiredCount = 0
local function clearPairs()
    for _,row in pairs(actors) do row.pair=nil end
end
local function log(category,event,fields)
    print("MS_INTEGRATED id=scabbard-integrated-07 epoch="..epoch.." state="..state
        .." category="..category.." event="..event.." "..(fields or "").."\n")
end
local function detail(err) return string.format("%q",tostring(err)) end
local function cancel(reason)
    token=token+1
    pendingSheath=nil
    if not timer then return end
    local old=timer
    timer=nil
    local ok=pcall(CancelDelayedAction,old)
    local checked, live=pcall(IsValidDelayedActionHandle,old)
    if not (ok and checked and live==false) then
        timerDebt=old
        log("CLEANUP_PENDING","TIMER_CANCEL","reason="..reason)
    else log("PASS","CANCEL","reason="..reason) end
end
local function guarded(where,fn)
    local ok, err=pcall(fn)
    if not ok then
        cancel(where)
        clearPairs()
        log("SKIPPED_UNSAFE","GUARD","where="..where.." detail="..detail(err))
    end
    return ok
end
local function current()
    assert(bound,"no bound generation")
    local pawn,mesh,generation,anim=context(StaticFindObject(bound.hud))
    assert(generation==bound.generation and id(pawn)~=retiredPawn,"generation changed")
    return pawn,mesh,generation,anim
end
local function equipmentActor(actor,pawn)
    return valid(actor) and id(actor:GetOwner())==id(pawn) and not ending[id(actor)]
        and actor:IsActorBeingDestroyed()==false
end
local function bindActor(actor,adapter,previous)
    local key=id(actor)
    local row={owner=key,path=path(actor),adapter=adapter,root=id(actor.RootComponent),held=id(actor.SkeletalMesh)}
    if adapter.off then row.blade=id(actor.hilda_dualblade_mesh) end
    if adapter.family then row.sheath=id(actor["hilda_"..adapter.family.."_sheath"]) end
    if previous and previous.owner==key and previous.path==row.path and previous.adapter==adapter
        and previous.root==row.root and previous.held==row.held
        and previous.blade==row.blade and previous.sheath==row.sheath then
        row.pair=previous.pair
    else
        observedDraw[key]=nil
        if type(drawPending)=="table" and drawPending.owner==key then drawPending=true end
        if previous then
            if previous.held then watched[previous.held]=nil end
            if previous.blade then watched[previous.blade]=nil end
            if previous.sheath then watched[previous.sheath]=nil end
        end
    end
    actors[key]=row
    if row.held then watched[row.held]={actor=row} end
    if row.blade then watched[row.blade]={actor=row} end
    if row.sheath then watched[row.sheath]={actor=row,sheath=true} end
end
local function meshOnRoot(component,actor,root,resource)
    return class(component)==SKELETAL and id(component:GetOwner())==id(actor)
        and id(component:GetAttachParent())==id(root) and socket(component)=="None" and asset(component,resource)
end
local function stowed(pawn,mesh,actor,post)
    local adapter=stockClass[class(actor)]
    assert(adapter and adapter.family and equipmentActor(actor,pawn)
        and actor.bHidden==false
        and (post or actor.equipMode==1),"stock stowed actor unavailable")
    local resource="hilda_"..adapter.family.."_sheath"
    local root, held, sheath=actor.RootComponent,actor.SkeletalMesh,actor[resource]
    assert(visible(root) and id(root:GetOwner())==id(actor) and id(root:GetAttachParent())==id(mesh)
        and socket(root)==adapter.mount,"stock root unavailable")
    assert(meshOnRoot(held,actor,root,adapter.held) and meshOnRoot(sheath,actor,root,resource)
        and held.bVisible==false and held.bHiddenInGame==false,"held mesh not stowed")
    -- Capture the emitting stock actor only. A companion can legitimately
    -- appear after this Sheath event; native registry validation in canHideNow
    -- proves every selected held component before a write, not at event intake.
    local ids={id(actor),id(root),id(held),id(sheath)}
    if adapter.off then
        local blade=actor.hilda_dualblade_mesh
        assert(meshOnRoot(blade,actor,root,"hilda_dualblade_mesh") and blade.bVisible==false,
            "main blade not stowed")
        ids[#ids+1]=id(blade)
    end
    return table.concat(ids,"|")
end

-- These reflected getters read the same native equipment state as the mode dispatcher.
local function canHideNow(pawn,mesh,actor,signature,previous)
    assert(not drawPending and safeOwnership(),"write guard unavailable")
    local global=StaticFindObject("/Script/Genesis.Default__GameGlobal")
    assert(name(global)=="GameGlobal /Script/Genesis.Default__GameGlobal","equipment getters unavailable")
    local hand=global:GetInHandWeaponType(pawn)
    assert(math.type(hand)=="integer" and (hand>=0 and hand<=5 or hand==7),"invalid hand enum")
    local selected, found={},false
    for slot=0,1 do
        local weapon=global:GetInUseWeaponType(pawn,slot)
        assert(math.type(weapon)=="integer" and (weapon>=0 and weapon<=5 or weapon==7),"invalid slot enum")
        if weapon~=7 then
            local count=0
            local dualMain,dualOff=false,false
            for handSlot=0,1 do
                local item=global:GetWeaponObject(pawn,weapon,handSlot)
                if valid(item) then
                    local adapter=stockClass[class(item)]
                    assert(adapter and adapter.weapon==weapon and equipmentActor(item,pawn),"unverified selected actor")
                    selected[id(item)]=item
                    count=count+1
                    dualMain=dualMain or adapter==adapters.HildaDualMain_BP
                    dualOff=dualOff or adapter==adapters.HildaDualOff_BP
                    if id(item)==id(actor) then found=true end
                end
            end
            if count==0 or (weapon==1 and not (dualMain and dualOff)) then return false,"slot-objects-pending" end
        end
    end
    if not found then return false,"sheath-actor-not-selected" end
    if hand~=7 then return false,"native-hand-active" end
    for _,item in pairs(selected) do
        local adapter=stockClass[class(item)]
        local root,held=item.RootComponent,item.SkeletalMesh
        assert(valid(root) and id(root:GetOwner())==id(item)
            and meshOnRoot(held,item,root,adapter.held)
            and type(held.bVisible)=="boolean" and type(held.bHiddenInGame)=="boolean",
            "selected held identity unavailable")
        if adapter~=adapters.HildaDualOff_BP and id(root:GetAttachParent())~=id(mesh) then
            return false,"selected-root-not-attached"
        end
        local blade=adapter.off and item.hilda_dualblade_mesh
        if adapter.off then
            assert(meshOnRoot(blade,item,root,"hilda_dualblade_mesh")
                and type(blade.bVisible)=="boolean" and type(blade.bHiddenInGame)=="boolean","selected blade identity unavailable")
        end
        if item.equipMode~=1 or visible(held) or (blade and visible(blade)) then
            return false,"selected-actor-not-stowed"
        end
    end
    local function oldHeld(rows)
        for key,row in pairs(rows) do
            if not selected[key] then
                local old=StaticFindObject(row.path)
                if id(old)==key then
                    local root=old.RootComponent
                    if valid(root) and id(root:GetAttachParent())==id(mesh) then
                        assert(id(root)==row.root and id(old.SkeletalMesh)==row.held,"old held identity changed")
                        assert(valid(old.SkeletalMesh) and type(old.SkeletalMesh.bVisible)=="boolean"
                            and type(old.SkeletalMesh.bHiddenInGame)=="boolean","old held visibility unknown")
                        if old.bHidden~=true and (visible(old.SkeletalMesh)
                            or (row.blade and visible(old.hilda_dualblade_mesh))) then return true end
                    end
                end
            end
        end
    end
    if oldHeld(previous) or oldHeld(actors) then return false,"old-held-visible" end
    if transition or actor.equipMode~=1 then return false,"transition-active" end
    local anim=mesh:GetAnimInstance()
    if anim:GetDoingSkill():ToString()~="None" or anim:GetToDoSkill():ToString()~="None" then
        return false,"skill-active"
    end
    assert(stowed(pawn,mesh,actor,false)==signature,"stowed identity changed")
    return true
end
local function admitted(c,row,pawn,allowPost)
    local rule=proof(row.resource)
    if not rule then return false,"role-unproven" end
    if rule[3]=="scabbard_any" then
        if row.mount~="scabbard_a" and row.mount~="scabbard_b" then return false,"mount-mismatch" end
    elseif rule[3]~=row.mount then return false,"mount-mismatch" end
    local owner=c:GetOwner()
    if rule[1]==false then
        if id(owner)~=id(pawn) then return false,"pawn-owner-mismatch" end
    else
        if class(owner)~="BlueprintGeneratedClass "..bp(rule[1]) then return false,"owner-class-mismatch" end
        if ending[row.owner] or owner:IsActorBeingDestroyed()~=false then return false,"owner-ending" end
        if owner.bHidden~=false then return false,"owner-hidden" end
        if rule[4]=="attached-use" then
            -- Some Use helpers carry FX on the scabbard; class alone is not a held location.
            -- Their root must already pass the exact current-pawn scabbard attachment check.
            if owner.equipMode~=1 and owner.equipMode~=2 then return false,"use-mode-mismatch" end
        elseif owner.equipMode~=rule[4] and not (allowPost and anchor and row.owner==anchor.owner) then
            return false,"equip-mode-mismatch"
        end
        if not visible(owner.RootComponent) then return false,"root-not-visible" end
        if row.socket~="None" then return false,"component-socket-mismatch" end
    end
    if id(owner[rule[2]])~=row.component then return false,"component-field-mismatch" end
    return true
end
local function collect(pawn,mesh,stage,allowPost)
    local candidates, keys, foundOwners, matches, errors={}, {}, {}, 0, 0
    for _, c in ipairs(FindAllOf("SkeletalMeshComponent") or {}) do
        local ok,err=pcall(function()
            local row,attachmentReason=catalogueRow(c,pawn,mesh,true)
            if not row then return end
            local accepted,reason=false,attachmentReason
            if not reason then
                matches=matches+1
                foundOwners[row.owner]=true
                accepted,reason=admitted(c,row,pawn,allowPost)
            end
            if accepted then
                row.generation=bound.generation
                row.ancestors={}
                local parent,depth=c:GetAttachParent(),0
                while valid(parent) do
                    depth=depth+1
                    assert(depth<=16,"attachment depth exceeded")
                    local key=id(parent)
                    assert(not row.ancestors[key],"attachment cycle")
                    row.ancestors[key]=true
                    parent=parent:GetAttachParent()
                end
                candidates[row.component]=row
                keys[#keys+1]=row.key.."|"..row.mount.."|"..row.socket
            else
                local owner=c:GetOwner()
                local role=proof(row.resource) and "stock-role" or row.resource:match("_([^_]+)$")
                local mode="pawn"
                if row.owner~=id(pawn) then mode=tostring(owner.equipMode) end
                log("OBSERVED_ONLY","CATALOGUE_REJECT","stage="..stage.." asset="..row.resource
                    .." role="..tostring(role).." owner_class="..detail(class(owner)).." mode="..mode
                    .." parent="..detail(row.parent).." mount="..detail(row.mount).." socket="..detail(row.socket)
                    .." visible="..tostring(c.bVisible).." hidden="..tostring(c.bHiddenInGame)
                    .." reason="..reason.." identity="..detail(row.component))
            end
        end)
        if not ok then errors=errors+1; if errors==1 then log("FAIL","CATALOGUE_ROW","detail="..detail(err)) end end
    end
    owners=foundOwners
    catalogueWatch=candidates
    table.sort(keys)
    log("OBSERVED_ONLY","CATALOGUE","stage="..stage.." matches="..matches.." eligible="..#keys.." errors="..errors)
    assert(errors==0,"catalogue incomplete")
    return candidates,table.concat(keys,";")
end
local function checked(row)
    local pawn,mesh,generation=current()
    assert(generation==row.generation and not ending[row.owner],"target generation retired")
    local c=StaticFindObject(row.path)
    local now=catalogueRow(c,pawn,mesh)
    assert(now and now.key==row.key and now.mount==row.mount and now.socket==row.socket
        and admitted(c,now,pawn,false) and type(c.bVisible)=="boolean","target changed "..row.resource)
    return c
end
local function write(row,value,operation)
    assert(not call and not row.uncertain,"mask ownership uncertain")
    local c=checked(row)
    assert(c.bVisible==(operation~="release"),"source flag changed")
    if operation~="release" then assert(c.bHiddenInGame==false,"host hidden") end
    local request={key=row.component,value=value}
    if operation=="hide" then leases[row.component]=row end
    call=request
    local ok,err=pcall(function() c:SetVisibility(value,false) end)
    call=nil
    local readOK,after=pcall(checked,row)
    if not (request.pre and request.post and not request.foreign and readOK and after.bVisible==value) then
        if leases[row.component] then row.uncertain=true end
        error(err or ("setter proof failed "..row.resource))
    end
    if operation=="release" then
        leases[row.component]=nil
        if not ok then log("FAIL","SETTER_AFTER_READBACK","detail="..detail(err)) end
        return
    end
    assert(ok,err)
end
local function release(reason, pawnOnly, keep)
    if call then call.foreign=true; fault=true; return end
    for key,row in pairs(leases) do
        if not ending[row.owner] and (not pawnOnly or (bound and row.owner==bound.pawn))
            and (not keep or not keep[key]) then
            local ok,err=pcall(write,row,true,"release")
            if ok then log("RELEASED","MASK","reason="..reason.." asset="..row.resource)
            elseif leases[key] then
                row.uncertain=true
                log("CLEANUP_PENDING","RELEASE_REFUSED","reason="..reason.." asset="..row.resource.." detail="..detail(err))
            end
        end
    end
end
local function pass(reason)
    state,suppression,transition="PASS-THROUGH",nil,false
    pendingSheath=nil
    cancel(reason)
    release(reason)
end
safeOwnership=function()
    if timerDebt or hookDebt or fault then return false end
    for _, row in pairs(leases) do if row.uncertain or ending[row.owner] then return false end end
    return true
end
local function apply(candidates,signature,reason,previous)
    assert(safeOwnership() and not drawPending and not transition,"write guard unavailable")
    for key,row in pairs(candidates) do
        if not leases[key] then
            local c=checked(row)
            if visible(c) then
                local ok,err=pcall(function()
                    local pawn,mesh=current()
                    local ready,why=canHideNow(pawn,mesh,StaticFindObject(anchor.path),signature,previous)
                    assert(ready,"equipment changed before probe: "..tostring(why))
                    write(row,true,"probe")
                    pawn,mesh=current()
                    ready,why=canHideNow(pawn,mesh,StaticFindObject(anchor.path),signature,previous)
                    assert(ready and not transition,"equipment changed after probe: "..tostring(why))
                    write(row,false,"hide")
                    log("PASS","MASK_APPLIED","asset="..row.resource.." identity="..detail(key))
                end)
                if not ok then
                    fault=true
                    pass("hide-failure")
                    log("FAIL","HIDE","asset="..row.resource.." detail="..detail(err))
                    return
                end
            end
        end
    end
    state,suppression="SUPPRESSED",signature
    local count=0
    for _ in pairs(leases) do count=count+1 end
    log("PASS","HIDDEN","reason="..reason.." targets="..count)
end
local function schedule(actor,signature,keys,menu)
    cancel("new-sheath")
    if not safeOwnership() then return end
    local pending={owner=id(actor),path=path(actor),generation=bound.generation,signature=signature,
        root=id(actor.RootComponent),held=id(actor.SkeletalMesh),
        sheath=id(actor["hilda_"..stockClass[class(actor)].family.."_sheath"]),
        keys=keys,menu=menu,previous=actors,remaining=24}
    pendingSheath=pending
    local mine,session=token,epoch
    local arm
    local function attempt(marker)
        if not active or session~=epoch or mine~=token or not timer
            or pendingSheath~=pending or pending.attempt~=marker then return end
        timer=nil
        if not guarded("sheath-expiry",function()
            local now=os.time()
            pending.started=pending.started or now
            if now-pending.started>=6 then
                cancel("sheath-timeout")
                log("SKIPPED_UNSAFE","SHEATH_TIMEOUT","reason=wall-clock")
                return
            end
            local pawn,mesh,generation=current()
            assert(generation==pending.generation,"sheath generation changed")
            local item=StaticFindObject(pending.path)
            assert(id(item)==pending.owner and equipmentActor(item,pawn),"sheath actor changed")
            local adapter=assert(stockClass[class(item)],"sheath class changed")
            assert(id(item.RootComponent)==pending.root and id(item.SkeletalMesh)==pending.held
                and id(item["hilda_"..adapter.family.."_sheath"])==pending.sheath,"stowed identity changed")
            local ready,reason=canHideNow(pawn,mesh,item,pending.signature,pending.previous)
            if not ready then
                if pending.remaining==0 then
                    cancel("sheath-timeout")
                    log("SKIPPED_UNSAFE","SHEATH_TIMEOUT","reason="..reason)
                    return
                end
                pending.remaining=pending.remaining-1
                arm(250)
                if pending.lastReason~=reason then log("OBSERVED_ONLY","SHEATH_WAIT","reason="..reason) end
                pending.lastReason=reason
                return
            end
            anchor=assert(actors[pending.owner],"sheath actor untracked")
            local candidates,latest=collect(pawn,mesh,"expiry",false)
            assert(not pending.keys or latest==pending.keys,"target generation changed")
            assert(canHideNow(pawn,mesh,item,pending.signature,pending.previous),"equipment changed during catalogue")
            pendingSheath=nil
            apply(candidates,pending.signature,menu and "menu-sheath-delay" or "sheath-delay",pending.previous)
        end) then pass("expiry-guard") end
    end
    arm=function(delay)
        local marker={}
        pending.attempt=marker
        timer=ExecuteInGameThreadWithDelay(delay,function() attempt(marker) end)
        assert(math.type(timer)=="integer" and IsValidDelayedActionHandle(timer),"unverified delay handle")
    end
    arm(2000)
    log("PASS","SCHEDULE","delay_ms=2000 token="..mine)
    if menu then log("PASS","MENU_SHEATH_PENDING","identity="..detail(pending.owner)) end
end

local function dispatch(fn)
    local ok,err=pcall(ExecuteInGameThread,fn,EGameThreadMethod.EngineTick)
    if not ok then log("FAIL","DISPATCH","detail="..detail(err)) end
    return ok
end
local function watch(stage,param,value,propagation)
    if not active then return end
    local ok,err=pcall(function()
        local c=param:get()
        local key=id(c)
        if not key then return end
        if call and key==call.key and not call[stage] and (stage=="pre" or call.pre)
            and value:get()==call.value and propagation:get()==false then
            call[stage]=true
            return
        end
        local lease=leases[key]
        local propagated=false
        if next(leases) and propagation:get()~=false then
            for _, row in pairs(leases) do
                if row.ancestors[key] then row.uncertain=true; propagated=true end
            end
        end
        if lease or propagated or (call and call.key==key) then
            if call then call.foreign=true end
            if lease then lease.uncertain=true end
            if stage=="pre" then
                log("SKIPPED_UNSAFE","FOREIGN_WRITER","identity="..detail(key))
                local session=epoch
                dispatch(function() if active and epoch==session then pass("foreign-writer") end end)
            end
            fault=true
            cancel("foreign-writer")
            clearPairs()
            return
        end
        local entry=watched[key]
        if stage=="pre" and pendingSheath and not entry then
            local affected=catalogueWatch[key]~=nil
            if not affected and propagation:get()==true then
                for _,row in pairs(catalogueWatch) do
                    if row.ancestors[key] then affected=true; break end
                end
            end
            if affected then cancel("pending-visibility-writer"); return end
        end
        if not entry then return end
        local requested=value:get()
        if stage=="pre" then
            if (entry.sheath and requested~=true) or (not entry.sheath and requested~=false) then
                -- Teardown of the OLD weapon is expected during a new actor's menu Sheath.
                if not (pendingSheath and pendingSheath.menu and entry.sheath and pendingSheath.owner~=entry.actor.owner
                    and pendingSheath.previous[entry.actor.owner]) then
                    cancel("stock-writer")
                end
            end
            if entry.sheath then
                entry.actor.pair=propagation:get()==false and {value=requested} or nil
            end
        elseif entry.sheath then
            local seen=entry.actor.pair
            if seen and seen.value==requested and propagation:get()==false then seen.post=c.bVisible==requested end
        end
    end)
    if not ok then
        if call then call.foreign=true end
        for _,row in pairs(leases) do row.uncertain=true end
        fault=true
        cancel("writer-guard")
        log("FAIL","WRITER_GUARD","detail="..detail(err))
    end
end
local function draw(param)
    local anim=param:get()
    if not (class(anim) or ""):match("%.hilda_AnimBP_C$") then return end
    local pawn,mesh,_,animKey=current()
    if id(anim)~=animKey then return end
    local skill=anim:GetToDoSkill():ToString()
    local family=drawSignals[skill]
    local inHandFamily=skill:match("^hilda_(%a+)_")
    local inHand=false
    for _,row in pairs(actors) do
        if row.adapter.family and row.adapter.family==inHandFamily then
            local actor=StaticFindObject(row.path)
            if id(actor)==row.owner and equipmentActor(actor,pawn) and actor.equipMode==0 then
                inHand=true
            end
        end
    end
    if family and not inHand then
        drawPending=true
        local ok,actor=pcall(one,drawClass[family],function(o)
            local adapter=stockClass[class(o)]
            local root=o.RootComponent
            if not (adapter and adapter.family==family and equipmentActor(o,pawn)
                and valid(root) and id(root:GetOwner())==id(o) and id(root:GetAttachParent())==id(mesh)
                and meshOnRoot(o.SkeletalMesh,o,root,adapter.held)) then return false end
            return (o.equipMode==1 and socket(root)==adapter.mount and o.SkeletalMesh.bVisible==false)
                or o.equipMode==3
        end)
        if ok then
            local key=id(actor)
            local previous=actors[key]
            bindActor(actor,stockClass[class(actor)],previous)
            drawPending={owner=key,root=id(actor.RootComponent),held=id(actor.SkeletalMesh),
                generation=bound.generation,early=actor.equipMode==1}
            if not previous then
                log("PASS","ADAPTER_REBOUND","stage=draw identity="..detail(key))
            end
        end
    elseif not inHand then
        drawPending=true
    end
    clearPairs()
    pass("local-skill-pre")
    log("OBSERVED_ONLY","SKILL_PRE","skill="..skill)
end
local function armMenuSheath(actor,adapter)
    if not adapter.family or not bound then return false end
    local pawn,mesh=current()
    local ready,signature=pcall(stowed,pawn,mesh,actor,true)
    if not ready then
        log("SKIPPED_UNSAFE","MENU_SHEATH_GUARD","detail="..detail(signature))
        return false
    end
    schedule(actor,signature,nil,true)
    return true
end
local function equip(adapter,param,modeParam)
    local actor=param:get()
    local key=id(actor)
    local mode=modeParam:get()
    local row=actors[key]
    local info=" class="..detail(class(actor)).." identity="..detail(key).." mode="..tostring(mode)
    local drawIdentity=type(drawPending)=="table" and detail(drawPending.owner) or tostring(drawPending)
    log("OBSERVED_ONLY","ADAPTER_POST",info.." tracked="..tostring(row~=nil)
        .." transition="..tostring(transition).." draw_pending="..drawIdentity
        .." observed_draw="..tostring(observedDraw[key]==true))
    local function reject(reason)
        log("SKIPPED_UNSAFE","ADAPTER_REJECT",info.." reason="..reason)
    end
    if not hookReady[adapter.event] or not hookReady[SLOT] or not hookReady[DRAW] or not hookReady[VIS] then
        reject("hooks-unready"); return
    end
    if not key or stockClass[class(actor)]~=adapter then reject("class-or-identity"); return end
    if ending[key] then reject("actor-ending"); return end
    if not row or row.adapter~=adapter then
        reject("actor-untracked")
        local ok,pawn,mesh=pcall(current)
        if ok and equipmentActor(actor,pawn) and valid(actor.RootComponent)
            and id(actor.RootComponent:GetAttachParent())==id(mesh) then
            transition=true
            queueRefresh("untracked-adapter-post")
            if mode==1 then armMenuSheath(actor,adapter) end
        end
        return
    end
    local seen=row.pair
    row.pair=nil
    if mode~=1 then
        if not (pendingSheath and pendingSheath.menu and pendingSheath.owner~=key and pendingSheath.previous[key] and mode~=0) then
            if mode~=2 and mode~=4 or (anchor and anchor.owner==key) then pass("non-sheath") end
        end
        if mode==0 and type(drawPending)=="table" and drawPending.owner==key then
            local pawn,mesh,generation=current()
            local root=actor.RootComponent
            if generation~=drawPending.generation or not equipmentActor(actor,pawn)
                or id(root)~=drawPending.root or id(root:GetAttachParent())~=id(mesh)
                or id(actor.SkeletalMesh)~=drawPending.held or actor.SkeletalMesh.bVisible~=true then
                drawPending=true
                reject("draw-identity-or-held")
                return
            end
            if drawPending.early then
                observedDraw[key]=true
                log("PASS","DRAW_ROUTE","family="..adapter.family)
            end
            drawPending=false
        end
        return
    end
    if not adapter.family then
        reject(adapter==adapters.HildaDualOff_BP and "offhand-companion" or "route-unsupported")
        return
    end
    if drawPending or transition or not (seen and seen.post and seen.value==true) then
        if mode==1 and transition and not drawPending and armMenuSheath(actor,adapter) then
            reject("menu-sheath-pending")
        else
            cancel("unconfirmed-sheath")
            reject(drawPending and "draw-pending" or (transition and "equipment-transition" or "writer-pair-unverified"))
        end
        return
    end
    if adapter.family~="cudgel" and not observedDraw[key] then
        reject("early-draw-unverified")
        return
    end
    local pawn,mesh=current()
    local signature=stowed(pawn,mesh,actor,true)
    if state=="SUPPRESSED" then pass("repeated-sheath") end
    anchor=row
    local _,keys=collect(pawn,mesh,"sheath",true)
    schedule(actor,signature,keys,false)
    log("OBSERVED_ONLY","SHEATH_ADAPTER","family="..adapter.family)
end
local function hook(n,native,pre,post)
    if hookReady[n] then return end
    assert(not hookDebt and not hooks[n],"unresolved hook registration")
    local f=StaticFindObject(n)
    assert(valid(f) and f:type()=="UFunction" and name(f)=="Function "..n
        and ((f:GetFunctionFlags() & 0x400)~=0)==native,"unavailable "..n)
    local a,b
    if native then a,b=RegisterHook(n,pre,post) else a,b=RegisterHook(n,post) end
    if math.type(a)=="integer" and math.type(b)=="integer" and a>0 and b>0 then hooks[n]={a,b} end
    if not hooks[n] then hookDebt=true end
    assert(hooks[n] and ((a~=b)==native),"unexpected hook ids")
    hookReady[n]=true
end
local function refresh(stage, expectedPawn)
    local hud=one("HUDMainUMG_BP_C",function(o) return o:IsInViewport() end)
    local pawn,mesh,generation=context(hud)
    if expectedPawn and id(pawn)~=expectedPawn then return end
    assert(id(pawn)~=retiredPawn,"retired pawn")
    if bound and bound.generation~=generation then
        pass("new-generation")
        anchor,drawPending=nil,false
        observedDraw={}
    end
    bound={hud=path(hud),pawn=id(pawn),generation=generation}
    local previous=anchor
    local oldActors=actors
    actors,watched={},{}
    for n,adapter in pairs(adapters) do
        for _,actor in ipairs(FindAllOf(n.."_C") or {}) do
            if stockClass[class(actor)]==adapter and equipmentActor(actor,pawn) then
                local key=id(actor)
                bindActor(actor,adapter,oldActors[key])
            end
        end
    end
    anchor=previous and actors[previous.owner] or nil
    for key in pairs(oldActors) do if not actors[key] then observedDraw[key]=nil end end
    local actor=anchor and StaticFindObject(anchor.path)
    local candidates=collect(pawn,mesh,stage,false)
    transition=false
    if pendingSheath then
        pendingSheath.refreshed=true
    end
    if state=="SUPPRESSED" then
        local checkedState,ready=pcall(canHideNow,pawn,mesh,actor,suppression,oldActors)
        if checkedState and ready then
            for key,row in pairs(leases) do
                if candidates[key] then
                    local resolved,c=pcall(checked,row)
                    if not resolved or c.bVisible~=false then
                        row.uncertain=true
                        log("CLEANUP_PENDING","MASK_CHANGED","asset="..row.resource)
                    end
                end
            end
            release(stage,false,candidates)
            if safeOwnership() then apply(candidates,suppression,stage,oldActors); return end
        end
        pass("stowed-not-retained")
    end
    log("OBSERVED_ONLY","CONTEXT","stage="..stage.." equipped_adapter="..tostring(next(actors)~=nil))
end
queueRefresh=function(stage)
    if refreshQueued then return end
    refreshQueued=true
    local session=epoch
    if not dispatch(function()
        if session~=epoch then return end
        refreshQueued=false
        if active then
            guarded("setup",setup)
            if not guarded(stage,function() refresh(stage) end) then pass(stage.."-failed") end
        end
    end) then refreshQueued=false end
end
setup=function()
    hook(VIS,true,function(...) watch("pre",...) end,function(...) watch("post",...) end)
    hook(DRAW,true,function(param)
        if active and not guarded("draw",function() draw(param) end) then pass("draw-guard") end
    end,function() end)
    hook(SLOT,false,nil,function(param)
        if not active then return end
        guarded("equipment-post",function()
            local key=id(param:get())
            if bound and key~=bound.pawn then return end
            if not bound and class(param:get())~=PAWN then return end
            if not pendingSheath or not pendingSheath.menu or pendingSheath.refreshed then cancel("equipment-post") end
            transition=true
            clearPairs()
            queueRefresh("equipment-post")
        end)
    end)
    for _,adapter in pairs(adapters) do
        guarded("adapter-hook",function()
            hook(adapter.event,false,nil,function(param,mode)
                if not active then return end
                if not guarded("equip",function() equip(adapter,param,mode) end) then pass("equip-guard") end
            end)
        end)
    end
end
local function start()
    if not active then
        if next(leases) or next(hooks) or timerDebt or hookDebt then log("CLEANUP_PENDING","START_BLOCKED"); return end
        active,epoch,fault=true,epoch+1,false
        log("OBSERVED_ONLY","START")
    end
    guarded("setup",setup)
    if not guarded("start",function() refresh("start") end) then pass("start-guard") end
end
local function stop()
    if active then pass("stop") end
    active,refreshQueued=false,false
    if timerDebt then
        local ok,live=pcall(IsValidDelayedActionHandle,timerDebt)
        if ok and live==false then timerDebt=nil end
    end
    for n,ids in pairs(hooks) do
        local ok,result=pcall(UnregisterHook,n,ids[1],ids[2])
        if ok and result~=false then hooks[n],hookReady[n]=nil,nil end
    end
    local pending=timerDebt or hookDebt or next(hooks) or next(leases)
    if not pending then
        bound,anchor,drawPending,transition=nil,nil,false,false
        pendingSheath=nil
        owners,ending={},{}
        actors,watched,observedDraw,catalogueWatch={},{},{},{}
    end
    log(pending and "CLEANUP_PENDING" or "PASS",pending and "STOP" or "CLEANED","retired="..retiredCount)
    if not pending then retiredCount=0 end
end
local mods={ModifierKey.CONTROL,ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7,mods) and not IsKeyBindRegistered(Key.F8,mods),"test chord occupied")
assert(EngineTickAvailable and type(RegisterEndPlayPreHook)=="function"
    and type(RegisterLoadMapPreHook)=="function" and type(RegisterLoadMapPostHook)=="function"
    and type(ExecuteInGameThreadWithDelay)=="function" and type(CancelDelayedAction)=="function"
    and type(IsValidDelayedActionHandle)=="function","required lifecycle APIs unavailable")
RegisterEndPlayPreHook(function(param,reason)
    if not active then return end
    guarded("end-play",function()
        local actor=param:get()
        local key=id(actor)
        if not key then return end
        local localPawn=bound and key==bound.pawn
        if not localPawn and not owners[key] and not actors[key] then
            local leased=false
            for _,row in pairs(leases) do if row.owner==key then leased=true; break end end
            if not leased then return end
        end
        local ok, code=pcall(function() return reason:get() end)
        local destructionOK,destroying=pcall(function() return actor:IsActorBeingDestroyed() end)
        local destroyed=ok and code==0 and destructionOK and destroying==true
        ending[key]=true
        if localPawn or not pendingSheath or pendingSheath.owner==key then
            cancel("end-play")
        end
        if call then call.foreign=true; fault=true end
        for component,row in pairs(leases) do
            if row.owner==key then
                if destroyed then
                    leases[component]=nil
                    retiredCount=retiredCount+1
                    log("RETIRED","DESTROYED_OWNER","asset="..row.resource.." identity="..detail(component))
                else
                    row.uncertain=true
                    log("CLEANUP_PENDING","UNKNOWN_ENDPLAY","asset="..row.resource.." identity="..detail(component))
                end
            end
        end
        if localPawn then
            retiredPawn=key
            bound,anchor,drawPending=nil,nil,false
            state,suppression,transition="PASS-THROUGH",nil,false
            for _,row in pairs(leases) do
                row.uncertain=true
                log("CLEANUP_PENDING","PAWN_RETIRED","asset="..row.resource)
            end
        elseif bound then
            transition=true
            clearPairs()
            release("equipment-endplay",true)
            queueRefresh("equipment-endplay")
        end
    end)
end)
RegisterLoadMapPreHook(function()
    if not active then return end
    pass("load-map")
    if bound then retiredPawn=bound.pawn end
    bound,anchor,drawPending=nil,nil,false
    pendingSheath=nil
    actors,watched,observedDraw,catalogueWatch={},{},{},{}
    log("OBSERVED_ONLY","LOAD_BOUNDARY")
end)
RegisterLoadMapPostHook(function() if active then queueRefresh("load-map-post") end end)
RegisterKeyBind(Key.F7,mods,function() dispatch(start) end)
RegisterKeyBind(Key.F8,mods,function() dispatch(stop) end)
log("OBSERVED_ONLY","LOADED","research=scabbard-integrated-07 start=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
