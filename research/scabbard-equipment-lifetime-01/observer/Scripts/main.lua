-- SPDX-License-Identifier: MPL-2.0
-- Read-only. Keep fingerprints, never UObject wrappers, between callbacks.
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local PAWN = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local SLOT = PAWN:match("^[^ ]+ (.+)$")
    .. ":BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature"
local catalogue = {}
for _, n in ipairs({"hilda_shield_sheath","hilda_scabbard_A","hilda_scabbard_B"}) do
    catalogue[MESH..n.."."..n]=n
end
for _, family in ipairs({"cudgel","dual","spear","staff"}) do
    for _, suffix in ipairs({"sheath","use","unuse"}) do
        local n="hilda_"..family.."_"..suffix
        catalogue[MESH..n.."."..n]=n
    end
end
local reasons = {[0]="Destroyed","LevelTransition","EndPlayInEditor","RemovedFromWorld","Quit"}
local active, context, retiredPawn = false, nil, nil
local rows, owners, hooks = {}, {}, {}
local serial, count = 0, 0

local function log(event, fields)
    print("MS_LIFETIME id=scabbard-equipment-lifetime-01 sample="..serial.." event="..event.." "..(fields or "").."\n")
end
local function q(value) return string.format("%q",tostring(value)) end
local function valid(o) return o~=nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (name(o).."@"..tostring(o:GetAddress())) or nil end
local function class(o) return valid(o) and name(o:GetClass()) or nil end
local function path(o) return assert(name(o):match("^[^ ]+ (.+)$")) end
local function socket(o) return o:GetAttachSocketName():ToString() end
local function guarded(stage, fn)
    local ok, err=pcall(fn)
    if not ok then log("SKIPPED_UNSAFE","stage="..stage.." detail="..q(err)) end
end
local function clear()
    context,rows,owners,count=nil,{},{},0
end
local function pawnContext(hud)
    assert(valid(hud) and hud:IsInViewport(),"no gameplay HUD")
    local pawn=hud:GetOwningPlayerPawn()
    assert(class(pawn)==PAWN and id(pawn)~=retiredPawn,"no current local Hilda")
    local mesh=pawn.Mesh
    assert(class(mesh)==SKELETAL and id(mesh:GetOwner())==id(pawn)
        and name(mesh):match("%.CharacterMesh0$"),"no local CharacterMesh0")
    return pawn,mesh
end
local function current()
    local pawn,mesh=pawnContext(StaticFindObject(context.hud))
    assert(id(pawn)==context.pawn and id(mesh)==context.mesh,"context changed")
    return pawn,mesh
end
local function attachment(c, owner, pawn, mesh)
    local parent=c:GetAttachParent()
    if id(owner)==id(pawn) then
        if id(parent)==id(mesh) then return socket(c) end
    elseif valid(owner) and valid(parent) and id(owner:GetOwner())==id(pawn)
        and id(owner.RootComponent)==id(parent) and id(parent:GetOwner())==id(owner)
        and id(parent:GetAttachParent())==id(mesh) then
        return socket(parent)
    end
end
local function sample(row, pawn, mesh, stage)
    local c=StaticFindObject(row.path)
    local status, fields="not-resolved",""
    if valid(c) then
        if id(c)==row.component and class(c)==SKELETAL and id(c.SkeletalMesh)==row.asset then
            local owner=c:GetOwner()
            local sameOwner=id(owner)==row.owner
            local mount=sameOwner and attachment(c,owner,pawn,mesh) or nil
            status=mount and "attached-local" or "resolved-outside-catalogue"
            local destroying, rootParent="unknown",nil
            if sameOwner then
                local ok, value=pcall(function() return owner:IsActorBeingDestroyed() end)
                if ok and type(value)=="boolean" then destroying=tostring(value) end
                local root=owner.RootComponent
                if valid(root) then rootParent=id(root:GetAttachParent()) end
            end
            fields=" owner_match="..tostring(sameOwner).." mount="..q(mount)
                .." parent="..q(id(c:GetAttachParent())).." socket="..q(socket(c))
                .." root_parent="..q(rootParent)
                .." visible="..tostring(c.bVisible).." hidden="..tostring(c.bHiddenInGame)
                .." destroying="..destroying
        else
            status="fingerprint-mismatch"
        end
    end
    if status=="not-resolved" or status=="fingerprint-mismatch" then row.gap=true end
    log("TARGET","stage="..stage.." resource="..row.resource.." status="..status
        .." endplay="..tostring(row.ended).." lookup_gap="..tostring(row.gap)
        .." identity="..q(row.component)..fields)
end
local function scan(stage, expectedPawn)
    local hud
    for _, o in ipairs(FindAllOf("HUDMainUMG_BP_C") or {}) do
        if valid(o) and o:IsInViewport() then assert(not hud,"ambiguous gameplay HUD"); hud=o end
    end
    local pawn,mesh=pawnContext(hud)
    if expectedPawn and expectedPawn~=id(pawn) then return end
    if not context or context.pawn~=id(pawn) or context.mesh~=id(mesh) then
        clear()
        context={pawn=id(pawn),mesh=id(mesh),hud=path(hud)}
        log("GENERATION","pawn="..q(context.pawn))
    else
        context.hud=path(hud)
    end
    serial=serial+1
    local matches, errors, overflow=0,0,false
    for _, c in ipairs(FindAllOf("SkeletalMeshComponent") or {}) do
        local ok,err=pcall(function()
            if class(c)~=SKELETAL then return end
            local asset=c.SkeletalMesh
            local resource=catalogue[name(asset)]
            if not resource then return end
            local owner=c:GetOwner()
            if not attachment(c,owner,pawn,mesh) then return end
            matches=matches+1
            -- The two pawn shells are already proved. Follow only equipment lifetimes.
            if id(owner)==context.pawn then return end
            local component,ownerKey,assetKey=id(c),id(owner),id(asset)
            local key=table.concat({component,ownerKey,assetKey},"|")
            if rows[key] then return end
            if count>=64 then overflow=true; return end
            local row={component=component,owner=ownerKey,asset=assetKey,resource=resource,
                path=path(c),ended=false,gap=false}
            rows[key]=row
            owners[ownerKey]=owners[ownerKey] or {}
            owners[ownerKey][key]=row
            count=count+1
            log("TRACKED","stage="..stage.." resource="..resource.." identity="..q(component)
                .." owner="..q(ownerKey).." asset="..q(assetKey))
        end)
        if not ok then errors=errors+1; if errors==1 then log("SCAN_READ_FAILED","detail="..q(err)) end end
    end
    for _, row in pairs(rows) do
        guarded("target-"..stage,function() sample(row,pawn,mesh,stage) end)
    end
    log("SCAN","stage="..stage.." attached_matches="..matches.." tracked="..count
        .." errors="..errors.." overflow="..tostring(overflow))
end
local function ownerEvent(stage, key, reason)
    if not owners[key] then return end
    serial=serial+1
    log("OWNER_EVENT","stage="..stage.." owner="..q(key).." reason="..q(reason))
    if stage=="endplay-pre" then
        for _, row in pairs(owners[key]) do row.ended=true end
    end
    local pawn,mesh=current()
    for _, row in pairs(owners[key]) do
        guarded(stage,function() sample(row,pawn,mesh,stage) end)
    end
end
local function hook(n, native, callback)
    if hooks[n] then return end
    local f=StaticFindObject(n)
    assert(valid(f) and f:type()=="UFunction" and name(f)=="Function "..n
        and ((f:GetFunctionFlags() & 0x400)~=0)==native,"unavailable "..n)
    local a,b
    if native then a,b=RegisterHook(n,callback,function() end) else a,b=RegisterHook(n,callback) end
    if math.type(a)=="integer" and math.type(b)=="integer" and a>0 and b>0 then hooks[n]={a,b} end
    assert(hooks[n] and ((a~=b)==native),"unexpected hook ids "..n)
    log("HOOK_READY","path="..n)
end
local function start()
    if not active and next(hooks) then log("CLEANUP_PENDING","reason=previous-hooks"); return end
    active=true
    guarded("manual",function() scan("manual") end)
    guarded("hook-slot",function() hook(SLOT,false,function(param)
        if active then guarded("equipment-post",function()
            local key=id(param:get())
            if key then scan("equipment-post",key) end
        end) end
    end) end)
    for _, spec in ipairs({
        {"/Script/Engine.Actor:K2_DestroyActor","destroy-wrapper-pre",false},
        {"/Script/Engine.Actor:K2_DetachFromActor","actor-detach-wrapper-pre",false},
        {"/Script/Engine.SceneComponent:K2_DetachFromComponent","root-detach-wrapper-pre",true},
    }) do
        local n,stage,root=table.unpack(spec)
        guarded("hook-"..stage,function() hook(n,true,function(param)
            if active and context then guarded(stage,function()
                local object=param:get()
                local key=id(object)
                if root and key then
                    local owner=object:GetOwner()
                    local ownerKey=id(owner)
                    if not owners[ownerKey] or id(owner.RootComponent)~=key then return end
                    key=ownerKey
                end
                ownerEvent(stage,key)
            end) end
        end) end)
    end
end
local function stop()
    active=false
    clear()
    retiredPawn=nil
    for n, ids in pairs(hooks) do
        local ok, result=pcall(UnregisterHook,n,ids[1],ids[2])
        if ok and result~=false then hooks[n]=nil end
    end
    log(next(hooks) and "CLEANUP_PENDING" or "CLEANED","writes=0")
end
local function dispatch(fn)
    guarded("dispatch",function() ExecuteInGameThread(fn,EGameThreadMethod.EngineTick) end)
end
local mods={ModifierKey.CONTROL,ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7,mods) and not IsKeyBindRegistered(Key.F8,mods),"test chord occupied")
assert(EngineTickAvailable and type(RegisterEndPlayPreHook)=="function"
    and type(RegisterLoadMapPreHook)=="function","required lifecycle APIs unavailable")
RegisterEndPlayPreHook(function(param, reason)
    if not active or not context then return end
    guarded("endplay-pre",function()
        local key=id(param:get())
        if key==context.pawn then
            retiredPawn=key
            clear()
            log("BOUNDARY","reason=pawn-endplay")
        elseif owners[key] then
            local ok, code=pcall(function() return reason:get() end)
            ownerEvent("endplay-pre",key,ok and reasons[code] or "unknown")
        end
    end)
end)
RegisterLoadMapPreHook(function()
    if active and context then
        retiredPawn=context.pawn
        clear()
        log("BOUNDARY","reason=load-map")
    end
end)
RegisterKeyBind(Key.F7,mods,function() dispatch(start) end)
RegisterKeyBind(Key.F8,mods,function() dispatch(stop) end)
log("LOADED","snapshot=Ctrl+Alt+F7 stop=Ctrl+Alt+F8 writes=0")
