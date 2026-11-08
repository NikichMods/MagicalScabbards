-- SPDX-License-Identifier: MPL-2.0
-- Integrated research candidate. Stock-cudgel transition evidence gates all writes.
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
local function catalogueRow(c, pawn, mesh)
    if class(c) ~= SKELETAL then return end
    local resource = catalogue[name(c.SkeletalMesh)]
    if not resource then return end
    local owner, parent = c:GetOwner(), c:GetAttachParent()
    local ownerId, parentId = id(owner), id(parent)
    if not ownerId or not parentId then return end
    if ownerId == id(pawn) then
        if parentId ~= id(mesh) then return end
    elseif id(owner:GetOwner()) ~= id(pawn) or id(owner.RootComponent) ~= parentId
        or id(parent:GetOwner()) ~= ownerId or id(parent:GetAttachParent()) ~= id(mesh) then
        return
    end
    return {
        path=path(c), component=id(c), owner=ownerId, resource=resource, socket=socket(c),
        mount=ownerId == id(pawn) and socket(c) or socket(parent),
        key=table.concat({id(c), id(c.SkeletalMesh), ownerId, parentId}, "|"),
    }
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
local EQUIP = bp("HildaCudgel_BP")..":EquipModeChange"
local CUDGEL = "BlueprintGeneratedClass "..bp("HildaCudgel_BP")
-- Observed roles, not a selector based on the equipped weapon.
local proofs = {
    hilda_scabbard_A={false,"scabbard_a","scabbard_a"},
    hilda_scabbard_B={false,"scabbard_b","scabbard_b"},
    hilda_cudgel_sheath={"HildaCudgel_BP","hilda_cudgel_sheath","scabbard_a",1},
    hilda_staff_sheath={"HildaStaff_BP","hilda_staff_sheath","scabbard_b",1},
    hilda_dual_unuse={"HildaDual_Unuse_BP","SkeletalMesh","scabbard_b",2},
    hilda_spear_unuse={"HildaSpear_Unuse_BP","SkeletalMesh","scabbard_a",2},
}
local state, active, epoch, token = "PASS-THROUGH", false, 0, 0
local bound, anchor, suppression, timer, timerDebt, call, pair, retiredPawn
local drawPending, transition, refreshQueued, fault = false, false, false, false
local hooks, hookReady, leases, owners, ending = {}, {}, {}, {}, {}
local hookDebt=false
local retiredCount = 0
local function log(category,event,fields)
    print("MS_INTEGRATED id=scabbard-integrated-01 epoch="..epoch.." state="..state
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
        pair=nil
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
local function stowed(pawn,mesh,actor,post)
    assert(class(actor)==CUDGEL and id(actor:GetOwner())==id(pawn)
        and actor.bHidden==false and actor:IsActorBeingDestroyed()==false
        and (post or actor.equipMode==1),"stock stowed actor unavailable")
    local root, held, sheath=actor.RootComponent,actor.SkeletalMesh,actor.hilda_cudgel_sheath
    assert(visible(root) and id(root:GetOwner())==id(actor) and id(root:GetAttachParent())==id(mesh)
        and socket(root)=="scabbard_a","stock root unavailable")
    assert(valid(held) and valid(sheath),"missing stock mesh")
    for _, component in ipairs({held,sheath}) do
        assert(class(component)==SKELETAL and id(component:GetOwner())==id(actor)
            and id(component:GetAttachParent())==id(root) and socket(component)=="None","stock mesh unavailable")
    end
    assert(asset(held,"hilda_cudgel") and held.bVisible==false and held.bHiddenInGame==false
        and asset(sheath,"hilda_cudgel_sheath"),"held mesh not stowed")
    local anim=mesh:GetAnimInstance()
    assert(post or (anim:GetDoingSkill():ToString()=="None" and anim:GetToDoSkill():ToString()=="None"),"skill active")
    return table.concat({id(actor),id(root),id(held),id(sheath)},"|")
end
local function admitted(c,row,pawn,allowPost)
    local rule=proofs[row.resource]
    if not rule or rule[3]~=row.mount then return false end
    local owner=c:GetOwner()
    if rule[1]==false then return id(owner)==id(pawn) and id(pawn[rule[2]])==row.component end
    return not ending[row.owner] and class(owner)=="BlueprintGeneratedClass "..bp(rule[1])
        and owner:IsActorBeingDestroyed()==false and owner.bHidden==false
        and (owner.equipMode==rule[4] or (allowPost and row.owner==anchor.owner))
        and visible(owner.RootComponent) and row.socket=="None" and id(owner[rule[2]])==row.component
end
local function collect(pawn,mesh,stage,allowPost)
    local candidates, keys, foundOwners, matches, errors={}, {}, {}, 0, 0
    for _, c in ipairs(FindAllOf("SkeletalMeshComponent") or {}) do
        local ok,err=pcall(function()
            local row=catalogueRow(c,pawn,mesh)
            if not row then return end
            matches=matches+1
            foundOwners[row.owner]=true
            if admitted(c,row,pawn,allowPost) then
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
            pair=nil
            return
        end
        if not anchor or (key~=anchor.held and key~=anchor.sheath) then return end
        if stage=="pre" then
            cancel("stock-writer")
            pair=key==anchor.sheath and propagation:get()==false and {value=value:get()} or nil
        elseif key==anchor.sheath and pair and pair.value==value:get() and propagation:get()==false then
            pair.post=c.bVisible==pair.value
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
    local _,_,_,animKey=current()
    if id(anim)~=animKey then return end
    local actor=anchor and StaticFindObject(anchor.path)
    if not valid(actor) or actor.equipMode~=0 then drawPending=true end
    pair=nil
    pass("local-skill-pre")
    log("OBSERVED_ONLY","SKILL_PRE","skill="..anim:GetToDoSkill():ToString())
end
local function equip(param, modeParam)
    local actor=param:get()
    if not anchor or id(actor)~=anchor.owner then return end
    local mode=modeParam:get()
    local seen=pair
    pair=nil
    if mode~=1 then
        pass("non-sheath")
        if mode==0 then drawPending=false end
        return
    end
    if drawPending or transition or not (seen and seen.post and seen.value==true) then
        cancel("unconfirmed-sheath")
        log("SKIPPED_UNSAFE","SHEATH","reason=draw-transition-or-writer")
        return
    end
    local pawn,mesh=current()
    local signature=stowed(pawn,mesh,actor,true)
    if state=="SUPPRESSED" then pass("repeated-sheath") end
    local _,keys=collect(pawn,mesh,"sheath",true)
    schedule(signature,keys)
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
        anchor,pair,drawPending=nil,nil,false
    end
    bound={hud=path(hud),pawn=id(pawn),generation=generation}
    local previous=anchor
    anchor=nil
    local ok,actor=pcall(one,"HildaCudgel_BP_C",function(o)
        local root=o.RootComponent
        return class(o)==CUDGEL and not ending[id(o)] and id(o:GetOwner())==id(pawn)
            and o:IsActorBeingDestroyed()==false and valid(root) and id(root:GetAttachParent())==id(mesh)
    end)
    if ok then
        anchor={owner=id(actor),path=path(actor),held=id(actor.SkeletalMesh),sheath=id(actor.hilda_cudgel_sheath)}
    end
    if not previous or not anchor or previous.owner~=anchor.owner then drawPending,pair=false,nil end
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
    log(anchor and "OBSERVED_ONLY" or "SKIPPED_UNSAFE","CONTEXT",
        "stage="..stage.." stock_cudgel="..tostring(anchor~=nil))
end
local function queueRefresh(stage)
    if refreshQueued then return end
    refreshQueued=true
    local session=epoch
    if not dispatch(function()
        if session~=epoch then return end
        refreshQueued=false
        if active and not guarded(stage,function() refresh(stage) end) then pass(stage.."-failed") end
    end) then refreshQueued=false end
end
local function setup()
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
            transition,pair=true,nil
            queueRefresh("equipment-post")
        end)
    end)
    hook(EQUIP,false,nil,function(...)
        if not active or not hookReady[EQUIP] or not hookReady[SLOT]
            or not hookReady[DRAW] or not hookReady[VIS] then return end
        local param,mode=...
        if not guarded("equip",function() equip(param,mode) end) then pass("equip-guard") end
    end)
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
        bound,anchor,pair,drawPending,transition=nil,nil,nil,false,false
        owners,ending={},{}
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
        if not localPawn and not owners[key] then
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
            bound,anchor,pair=nil,nil,nil
            state,suppression,transition="PASS-THROUGH",nil,false
            for _,row in pairs(leases) do
                row.uncertain=true
                log("CLEANUP_PENDING","PAWN_RETIRED","asset="..row.resource)
            end
        elseif bound then
            transition,pair=true,nil
            release("equipment-endplay",true)
            queueRefresh("equipment-endplay")
        end
    end)
end)
RegisterLoadMapPreHook(function()
    if not active then return end
    pass("load-map")
    if bound then retiredPawn=bound.pawn end
    bound,anchor,pair,drawPending=nil,nil,nil,false
    log("OBSERVED_ONLY","LOAD_BOUNDARY")
end)
RegisterLoadMapPostHook(function() if active then queueRefresh("load-map-post") end end)
RegisterKeyBind(Key.F7,mods,function() dispatch(start) end)
RegisterKeyBind(Key.F8,mods,function() dispatch(stop) end)
log("OBSERVED_ONLY","LOADED","start=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
