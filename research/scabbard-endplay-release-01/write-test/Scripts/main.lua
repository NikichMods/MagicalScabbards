-- SPDX-License-Identifier: MPL-2.0
-- One-shot research fixture. Writes are restricted to the two pawn-owned shells.
local ITEM = "/Game/MainContent/Act/Item_BP/"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local PAWN = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local HIDDEN = "/Script/Engine.SceneComponent:SetHiddenInGame"
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
local CUDGEL = "BlueprintGeneratedClass " .. bp("HildaCudgel_BP")
local targets = {{"scabbard_a", "hilda_scabbard_A"}, {"scabbard_b", "hilda_scabbard_B"}}
local hooks, leases, ancestors = {}, {}, {}
local session, snapshot, retiredPawn, call
local active, spent, locked = false, false, false
local function log(event, fields)
    print("MS_ENDPLAY id=scabbard-endplay-release-01 event="..event.." "..(fields or "").."\n")
end
local function detail(err)
    return string.format("%q", tostring(err))
end
local function localContext()
    local hud = one("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
    local pawn, mesh, generation, anim = context(hud)
    assert(id(pawn) ~= retiredPawn, "retired pawn")
    return pawn, mesh, generation, anim, path(hud)
end
local function collect(pawn, mesh, generation, stage)
    local rows, owners, count, errors = {}, {}, 0, 0
    for _, c in ipairs(FindAllOf("SkeletalMeshComponent") or {}) do
        local ok, row = pcall(catalogueRow, c, pawn, mesh)
        if not ok then
            errors = errors + 1
        elseif row then
            rows[row.key], owners[row.owner] = row, true
            count = count + 1
            log("CATALOGUE", "stage="..stage.." resource="..row.resource
                .." identity="..detail(row.key).." mount="..row.mount)
        end
    end
    log("CATALOGUE_SCAN", "stage="..stage.." matches="..count.." errors="..errors)
    return {rows=rows, owners=owners, ending={}, generation=generation, errors=errors}
end
local function assertStowed(pawn, mesh)
    local anim = mesh:GetAnimInstance()
    assert(anim:GetToDoSkill():ToString()=="None" and anim:GetDoingSkill():ToString()=="None", "skill active")
    local actor = one("HildaCudgel_BP_C", function(o)
        return class(o)==CUDGEL and id(o:GetOwner())==id(pawn)
    end)
    local root, sheath, held = actor.RootComponent, actor.hilda_cudgel_sheath, actor.SkeletalMesh
    assert(actor.equipMode==1 and actor.bHidden==false and visible(root)
        and id(root:GetOwner())==id(actor) and id(root:GetAttachParent())==id(mesh)
        and socket(root)=="scabbard_a", "cudgel not stowed")
    assert(class(sheath)==SKELETAL and visible(sheath) and asset(sheath,"hilda_cudgel_sheath")
        and id(sheath:GetOwner())==id(actor) and id(sheath:GetAttachParent())==id(root)
        and socket(sheath)=="None", "stock sheath unavailable")
    assert(class(held)==SKELETAL and asset(held,"hilda_cudgel")
        and id(held:GetOwner())==id(actor) and id(held:GetAttachParent())==id(root)
        and socket(held)=="None" and held.bVisible==false and held.bHiddenInGame==false, "held mesh unsafe")
end
local function current()
    assert(session and not session.retired, "write generation retired")
    local pawn, mesh, generation = context(StaticFindObject(session.hud))
    assert(generation==session.generation, "write generation changed")
    return pawn, mesh
end
local function checked(row)
    local pawn, mesh = current()
    local c = pawn[row.field]
    local now = catalogueRow(c, pawn, mesh)
    assert(now and now.key==row.key and now.socket==row.field and now.owner==session.pawn
        and c.bHiddenInGame==false and type(c.bVisible)=="boolean", "target changed "..row.field)
    return c
end
local function write(row, value, operation)
    assert(not call and not row.uncertain, "unproven ownership "..row.field)
    local c = checked(row)
    assert(c.bVisible == (operation~="release"), "unexpected visibility "..row.field)
    local request = {key=row.component, value=value}
    if operation=="hide" then leases[row.field]=row end
    call = request
    local ok, err = pcall(function() c:SetVisibility(value, false) end)
    call = nil
    local readOK, after = pcall(checked, row)
    if not (request.pre and request.post and not request.foreign and readOK and after.bVisible==value) then
        if leases[row.field] then row.uncertain=true end
        error("setter proof failed "..row.field.." "..detail(err or after))
    end
    if operation=="release" then leases[row.field]=nil end
    log("SETTER_VERIFIED", "part="..row.field.." operation="..operation.." value="..tostring(value))
    if not ok and operation=="release" then
        log("SETTER_ERROR_AFTER_READBACK","part="..row.field.." detail="..detail(err))
        return
    end
    assert(ok, err)
end
local function release(reason)
    if not next(leases) then return end
    for i=#targets,1,-1 do
        local row=leases[targets[i][1]]
        if row then
            local ok, err=pcall(write,row,true,"release")
            if ok then log("RELEASED","reason="..reason.." part="..row.field)
            else
                row.uncertain=true
                log("RELEASE_REFUSED","reason="..reason.." part="..row.field.." detail="..detail(err))
            end
        end
    end
    log(next(leases) and "CLEANUP_PENDING" or "RELEASE_COMPLETE", "reason="..reason)
end
local function retire(reason)
    if not session or session.retired then return end
    session.retired, retiredPawn = true, session.pawn
    if call then call.foreign=true end
    if next(leases) then log("CLEANUP_PENDING","reason="..reason.." generation_retired=true") end
end
local function watch(channel, stage, param, flag, propagate)
    if not active or (not call and not next(leases)) then return end
    local ok, err = pcall(function()
        local key=id(param:get())
        if call and key==call.key and channel=="visible" and not call[stage]
            and (stage=="pre" or call.pre) and flag:get()==call.value and propagate:get()==false then
            call[stage]=true
            return
        end
        local inherited = ancestors[key] and propagate:get()~=false
        for _, row in pairs(leases) do
            if row.component==key or inherited then
                row.uncertain=true
                if call then call.foreign=true end
                if stage=="pre" then log("FOREIGN_WRITER","part="..row.field.." channel="..channel) end
            end
        end
        if call and (key==call.key or inherited) then call.foreign=true end
    end)
    if not ok then
        if call then call.foreign=true end
        for _, row in pairs(leases) do row.uncertain=true end
        log("WATCH_FAILED","detail="..detail(err))
    end
end
local function guarded(event, fn)
    if not active then return end
    local ok, err = pcall(fn)
    if not ok then log("SKIPPED_UNSAFE","where="..event.." detail="..detail(err)) end
end
local function observeEquipment(param, stage)
    local pawn, mesh, generation = localContext()
    if param and id(param:get())~=id(pawn) then return end
    if call then call.foreign=true end
    if stage=="equipment-post" and not call then release(stage) end
    local old = snapshot
    snapshot = collect(pawn, mesh, generation, stage)
    if old and old.generation==generation then
        for key, row in pairs(old.rows) do
            local new = snapshot.rows[key]
            local ending=old.ending[row.owner]==true
            local attached=new~=nil and new.mount==row.mount and new.socket==row.socket
            log("CATALOGUE_DELTA","resource="..row.resource.." ending_owner="..tostring(ending)
                .." same_attachment="..tostring(attached))
            if ending then
                local ok, same=pcall(function() return id(StaticFindObject(row.path))==row.component end)
                log("ENDING_TARGET_POST","resource="..row.resource
                    .." lookup="..(not ok and "failed" or (same and "same-instance" or "not-resolved"))
                    .." attached="..tostring(attached).." writes=0")
            end
        end
    end
end
local function hook(n, native, pre, post)
    local f=StaticFindObject(n)
    assert(valid(f) and f:type()=="UFunction" and name(f)=="Function "..n
        and ((f:GetFunctionFlags() & 0x400)~=0)==native, "hook signature mismatch "..n)
    local a,b
    if native then a,b=RegisterHook(n,pre,post) else a,b=RegisterHook(n,post) end
    if math.type(a)=="integer" and math.type(b)=="integer" and a>0 and b>0 then hooks[n]={a,b} end
    assert(hooks[n] and ((a~=b)==native), "unexpected hook ids "..n)
end
local function stop()
    if active then release("stop") end
    active, snapshot = false, nil
    for n, ids in pairs(hooks) do
        local ok,result=pcall(UnregisterHook,n,ids[1],ids[2])
        if ok and result~=false then hooks[n]=nil end
    end
    locked=next(leases)~=nil or next(hooks)~=nil
    log(locked and "CLEANUP_PENDING" or "CLEANED", "reason=stop")
end
local function arm()
    if spent then
        if active and not next(leases) then guarded("manual-refresh",function()
            observeEquipment(nil,"manual-refresh")
        end) end
        return
    end
    local pawn, mesh, generation, anim, hud = localContext()
    assertStowed(pawn,mesh)
    local rows={}
    session={pawn=id(pawn), generation=generation, anim=anim, hud=hud}
    for _, target in ipairs(targets) do
        local field, resource=table.unpack(target)
        local c=pawn[field]
        local row=catalogueRow(c,pawn,mesh)
        assert(row and row.owner==session.pawn and row.resource==resource and row.socket==field and visible(c),
            "stock shell unavailable "..field)
        row.field=field
        rows[#rows+1]=row
    end
    ancestors={}
    local parent, depth=mesh, 0
    while valid(parent) do
        depth=depth+1
        assert(depth<=16, "attachment depth exceeded")
        local key=id(parent)
        assert(not ancestors[key], "attachment cycle")
        ancestors[key]=true
        parent=parent:GetAttachParent()
    end
    snapshot=collect(pawn,mesh,generation,"arm")
    assert(snapshot.errors==0, "incomplete starting catalogue")
    for _, row in ipairs(rows) do assert(snapshot.rows[row.key], "shell absent from starting catalogue") end
    spent,active=true,true
    hook(SLOT,false,nil,function(param) guarded("equipment-post",function()
        observeEquipment(param,"equipment-post")
    end) end)
    hook(DRAW,true,function(param) guarded("skill",function()
        if id(param:get())==session.anim and not call then release("local-skill") end
    end) end,function() end)
    for _, spec in ipairs({{VIS,"visible"},{HIDDEN,"hidden"}}) do
        local channel=spec[2]
        hook(spec[1],true,function(...) watch(channel,"pre",...) end,function(...) watch(channel,"post",...) end)
    end
    for _, row in ipairs(rows) do write(row,true,"probe") end
    for _, row in ipairs(rows) do
        local currentPawn,currentMesh=current()
        assertStowed(currentPawn,currentMesh)
        write(row,false,"hide")
    end
    log("ARMED","targets="..#rows.." setup=manual")
end
local function dispatch(fn)
    local ok,err=pcall(ExecuteInGameThread,fn,EGameThreadMethod.EngineTick)
    if not ok then log(next(leases) and "CLEANUP_PENDING" or "DISPATCH_FAILED", "detail="..detail(err)) end
end

local mods={ModifierKey.CONTROL,ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7,mods) and not IsKeyBindRegistered(Key.F8,mods),"test chord occupied")
assert(EngineTickAvailable and type(RegisterEndPlayPreHook)=="function"
    and type(RegisterLoadMapPreHook)=="function" and type(RegisterLoadMapPostHook)=="function",
    "required lifecycle APIs unavailable")
RegisterEndPlayPreHook(function(param)
    guarded("end-play",function()
        local ended=id(param:get())
        assert(ended,"ending actor unavailable")
        if ended==session.pawn then
            retire("pawn-end-play")
            snapshot=nil
        elseif snapshot and snapshot.owners[ended] then
            snapshot.ending[ended]=true
            log("EQUIPMENT_ENDPLAY","owner="..detail(ended).." ending_owner_writes=0")
            if not call then release("equipment-endplay") else retire("reentrant-endplay") end
        end
    end)
end)
RegisterLoadMapPreHook(function()
    if not active then return end
    if not call then release("load-map-pre") end
    retire("load-map")
    snapshot=nil
    log("LOAD_BOUNDARY")
end)
RegisterLoadMapPostHook(function()
    if not active then return end
    dispatch(function() guarded("load-map-post",function() observeEquipment(nil,"load-map-post") end) end)
end)
RegisterKeyBind(Key.F7,mods,function()
    dispatch(function()
        if locked then return end
        local ok,err=pcall(arm)
        if not ok then
            log("ARM_FAILED","detail="..detail(err))
            if active then stop() end
        end
    end)
end)
RegisterKeyBind(Key.F8,mods,function() dispatch(stop) end)
log("LOADED","arm=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
