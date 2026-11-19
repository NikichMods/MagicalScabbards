-- SPDX-License-Identifier: MPL-2.0
-- Integrated research candidate. Class adapters supply evidence to one visibility controller.
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
    HildaCudgel_BP={family="cudgel", mount="scabbard_a", held="hilda_cudgel"},
    HildaStaff_BP={family="staff", mount="scabbard_b", held="hilda_staff"},
    HildaDualMain_BP={family="dual", mount="scabbard_b", held="hilda_dualmain_mesh", off=true},
    HildaDualOff_BP={held="hilda_dualoff_mesh"},
    HildaSpear_BP={held="hilda_spear"},
    HildaShield_BP={held="hilda_shield"},
}
local stockClass = {}
local drawClass = {}
for n,adapter in pairs(adapters) do
    adapter.event=bp(n)..":EquipModeChange"
    stockClass["BlueprintGeneratedClass "..bp(n)]=adapter
    if adapter.family then drawClass[adapter.family]=n.."_C" end
end
-- Observed roles, not a selector based on the equipped weapon.
local proofs = {
    hilda_scabbard_A={false,"scabbard_a","scabbard_a"},
    hilda_scabbard_B={false,"scabbard_b","scabbard_b"},
    hilda_cudgel_sheath={"HildaCudgel_BP","hilda_cudgel_sheath","scabbard_a",1},
    hilda_staff_sheath={"HildaStaff_BP","hilda_staff_sheath","scabbard_b",1},
    hilda_dual_sheath={"HildaDualMain_BP","hilda_dual_sheath","scabbard_b",1},
    hilda_dual_unuse={"HildaDual_Unuse_BP","SkeletalMesh","scabbard_b",2},
    hilda_spear_unuse={"HildaSpear_Unuse_BP","SkeletalMesh","scabbard_a",2},
}
local state, active, epoch, token = "PASS-THROUGH", false, 0, 0
local bound, anchor, suppression, timer, timerDebt, call, retiredPawn, earlyOwner
local drawPending, transition, refreshQueued, fault = false, false, false, false
local actors, watched, observedDraw = {}, {}, {}
local setup, queueRefresh
local hooks, hookReady, leases, owners, ending = {}, {}, {}, {}, {}
local hookDebt=false
local retiredCount = 0
local function clearPairs()
    for _,row in pairs(actors) do row.pair=nil end
end
local function log(category,event,fields)
    print("MS_INTEGRATED id=scabbard-integrated-03 epoch="..epoch.." state="..state
        .." category="..category.." event="..event.." "..(fields or "").."\n")
end
local function detail(err) return string.format("%q",tostring(err)) end
local function cancel(reason)
    token=token+1
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
        if earlyOwner==key then earlyOwner=nil end
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
    local ids={id(actor),id(root),id(held),id(sheath)}
    if adapter.off then
        local blade=actor.hilda_dualblade_mesh
        assert(meshOnRoot(blade,actor,root,"hilda_dualblade_mesh") and blade.bVisible==false,"main blade not stowed")
        ids[#ids+1]=id(blade)
        local off=one("HildaDualOff_BP_C",function(o)
            return stockClass[class(o)]==adapters.HildaDualOff_BP and equipmentActor(o,pawn)
        end)
        local offRoot,offMesh=off.RootComponent,off.SkeletalMesh
        assert(valid(offRoot) and id(offRoot:GetOwner())==id(off) and meshOnRoot(offMesh,off,offRoot,"hilda_dualoff_mesh"),
            "offhand identity unavailable")
        assert(post or (off.equipMode==1 and offMesh.bVisible==false),"offhand not stowed")
        ids[#ids+1]=table.concat({id(off),id(offRoot),id(offMesh)},"|")
    end
    if not post then
        for key,row in pairs(actors) do
            if key~=id(actor) and not ending[key] then
                local other=StaticFindObject(row.path)
                assert(id(other)==key and equipmentActor(other,pawn),"equipment identity changed")
                assert(other.equipMode==1 or other.equipMode==2 or other.equipMode==4,"another weapon not stowed")
            end
        end
    end
    local anim=mesh:GetAnimInstance()
    assert(post or (anim:GetDoingSkill():ToString()=="None" and anim:GetToDoSkill():ToString()=="None"),"skill active")
    return table.concat(ids,"|")
end
local function admitted(c,row,pawn,allowPost)
    local rule=proofs[row.resource]
    if not rule then return false,"role-unproven" end
    if rule[3]~=row.mount then return false,"mount-mismatch" end
    local owner=c:GetOwner()
    if rule[1]==false then
        if id(owner)~=id(pawn) then return false,"pawn-owner-mismatch" end
    else
        if class(owner)~="BlueprintGeneratedClass "..bp(rule[1]) then return false,"owner-class-mismatch" end
        if ending[row.owner] or owner:IsActorBeingDestroyed()~=false then return false,"owner-ending" end
        if owner.bHidden~=false then return false,"owner-hidden" end
        if owner.equipMode~=rule[4] and not (allowPost and anchor and row.owner==anchor.owner) then
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
                local role=proofs[row.resource] and "known-rule" or row.resource:match("_([^_]+)$")
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
    cancel(reason)
    release(reason)
end
local function safeOwnership()
    if timerDebt or hookDebt or fault then return false end
    for _, row in pairs(leases) do if row.uncertain or ending[row.owner] then return false end end
    return true
end
local function apply(candidates,signature,reason)
    assert(safeOwnership() and not drawPending and not transition,"write guard unavailable")
    for key,row in pairs(candidates) do
        if not leases[key] then
            local c=checked(row)
            if visible(c) then
                local ok,err=pcall(function()
                    local pawn,mesh=current()
                    assert(stowed(pawn,mesh,StaticFindObject(anchor.path),false)==signature,"stowed changed before probe")
                    write(row,true,"probe")
                    pawn,mesh=current()
                    assert(stowed(pawn,mesh,StaticFindObject(anchor.path),false)==signature
                        and safeOwnership() and not drawPending and not transition,"stowed changed after probe")
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
local function schedule(signature,keys)
    cancel("new-sheath")
    if not safeOwnership() then return end
    local mine,session=token,epoch
    local handle=ExecuteInGameThreadWithDelay(2000,function()
        if not active or mine~=token or session~=epoch or not timer then return end
        timer=nil
        if not guarded("expiry",function()
            assert(not drawPending and not transition and safeOwnership(),"expiry guard")
            local pawn,mesh=current()
            assert(stowed(pawn,mesh,StaticFindObject(anchor.path),false)==signature,"stowed identity changed")
            local candidates,latest=collect(pawn,mesh,"expiry",false)
            assert(latest==keys,"target generation changed")
            apply(candidates,signature,"sheath-delay")
        end) then pass("expiry-guard") end
    end)
    timer=handle
    assert(math.type(handle)=="integer" and IsValidDelayedActionHandle(handle),"unverified delay handle")
    log("PASS","SCHEDULE","delay_ms=2000 token="..mine)
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
        if not entry then return end
        local requested=value:get()
        if stage=="pre" then
            if (entry.sheath and requested~=true) or (not entry.sheath and requested~=false) then
                cancel("stock-writer")
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
    local family=skill:match("^hilda_(%a+)_atk1_idle$")
    earlyOwner=nil
    if family=="cudgel" or family=="staff" or family=="dual" then
        drawPending=family
        local ok,actor=pcall(one,drawClass[family],function(o)
            local adapter=stockClass[class(o)]
            local root=o.RootComponent
            return adapter and adapter.family==family and equipmentActor(o,pawn) and o.equipMode==1
                and valid(root) and id(root:GetAttachParent())==id(mesh)
                and valid(o.SkeletalMesh) and o.SkeletalMesh.bVisible==false
        end)
        if ok then
            local key=id(actor)
            local previous=actors[key]
            bindActor(actor,stockClass[class(actor)],previous)
            earlyOwner=key
            if not previous then
                log("PASS","ADAPTER_REBOUND","stage=draw identity="..detail(earlyOwner))
            end
        end
    else
        local inHand=false
        for _, row in pairs(actors) do
            local f=row.adapter.family
            if f and skill:match("^hilda_"..f.."_") then
                local actor=StaticFindObject(row.path)
                if id(actor)==row.owner and actor.equipMode==0 then inHand=true end
            end
        end
        if not inHand then drawPending=true end
    end
    clearPairs()
    pass("local-skill-pre")
    log("OBSERVED_ONLY","SKILL_PRE","skill="..skill)
end
local function equip(adapter,param,modeParam)
    local actor=param:get()
    local key=id(actor)
    local mode=modeParam:get()
    local row=actors[key]
    local info=" class="..detail(class(actor)).." identity="..detail(key).." mode="..tostring(mode)
    log("OBSERVED_ONLY","ADAPTER_POST",info.." tracked="..tostring(row~=nil)
        .." transition="..tostring(transition).." draw_pending="..tostring(drawPending)
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
            cancel("untracked-local-actor")
            transition=true
            queueRefresh("untracked-adapter-post")
        end
        return
    end
    local seen=row.pair
    row.pair=nil
    if mode~=1 then
        if mode~=2 and mode~=4 or (anchor and anchor.owner==key) then pass("non-sheath") end
        if mode==0 and adapter.family and drawPending==adapter.family and (not earlyOwner or earlyOwner==key) then
            if earlyOwner==key then
                observedDraw[key]=true
                log("PASS","DRAW_ROUTE","family="..adapter.family)
            end
            drawPending=false
            earlyOwner=nil
        end
        return
    end
    if not adapter.family then
        reject(adapter==adapters.HildaDualOff_BP and "offhand-companion" or "route-unsupported")
        return
    end
    if drawPending or transition or not (seen and seen.post and seen.value==true) then
        cancel("unconfirmed-sheath")
        reject(drawPending and "draw-pending" or (transition and "equipment-transition" or "writer-pair-unverified"))
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
    schedule(signature,keys)
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
        anchor,earlyOwner,drawPending=nil,nil,false
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
    if state=="SUPPRESSED" then
        local ready,signature=pcall(stowed,pawn,mesh,actor,false)
        if ready and signature==suppression and safeOwnership() and not drawPending then
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
            if safeOwnership() then apply(candidates,signature,stage); return end
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
            cancel("equipment-post")
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
        bound,anchor,earlyOwner,drawPending,transition=nil,nil,nil,false,false
        owners,ending={},{}
        actors,watched,observedDraw={},{},{}
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
        cancel("end-play")
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
            bound,anchor,earlyOwner=nil,nil,nil
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
    bound,anchor,earlyOwner,drawPending=nil,nil,nil,false
    actors,watched,observedDraw={},{},{}
    log("OBSERVED_ONLY","LOAD_BOUNDARY")
end)
RegisterLoadMapPostHook(function() if active then queueRefresh("load-map-post") end end)
RegisterKeyBind(Key.F7,mods,function() dispatch(start) end)
RegisterKeyBind(Key.F8,mods,function() dispatch(stop) end)
log("OBSERVED_ONLY","LOADED","start=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
