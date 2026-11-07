-- SPDX-License-Identifier: MPL-2.0
-- Research only. Live write gate is blocked for unrestricted equipment changes.
local ITEM = "/Game/MainContent/Act/Item_BP/"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local PAWN = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local HIDDEN = "/Script/Engine.SceneComponent:SetHiddenInGame"
local order = {"sheath", "A", "B", "spear", "staff", "dual"}
local specs = {
    sheath={"HildaCudgel_BP", "hilda_cudgel_sheath", "hilda_cudgel_sheath", "scabbard_a", 1},
    A={false, "scabbard_a", "hilda_scabbard_A", "scabbard_a"},
    B={false, "scabbard_b", "hilda_scabbard_B", "scabbard_b"},
    spear={"HildaSpear_Unuse_BP", "SkeletalMesh", "hilda_spear_unuse", "scabbard_a", 2},
    staff={"HildaStaff_BP", "hilda_staff_sheath", "hilda_staff_sheath", "scabbard_b", 1},
    dual={"HildaDual_Unuse_BP", "SkeletalMesh", "hilda_dual_unuse", "scabbard_b", 2},
}
local sockets = {[0]="cudgel_r_hand", [1]="scabbard_a", [3]="dual_l_hand"}
local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (name(o) .. "@" .. tostring(o:GetAddress())) or nil end
local function class(o) return valid(o) and name(o:GetClass()) or nil end
local function path(o) return assert(name(o):match("^[^ ]+ (.+)$")) end
local function socket(o) return o:GetAttachSocketName():ToString() end
local function asset(o, n) return name(o.SkeletalMesh) == MESH .. n .. "." .. n end
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

local function context(hud, idle)
    assert(valid(hud) and hud:IsInViewport(), "retired or no gameplay HUD")
    local pawn = hud:GetOwningPlayerPawn()
    assert(class(pawn) == PAWN and pawn.bHidden == false, "invalid local pawn")
    local mesh = pawn.Mesh
    assert(class(mesh) == SKELETAL and name(mesh):match("%.CharacterMesh0$")
        and id(mesh:GetOwner()) == id(pawn) and visible(mesh), "invalid CharacterMesh0")
    local anim = mesh:GetAnimInstance()
    assert((class(anim) or ""):match("%.hilda_AnimBP_C$"), "anim unavailable")
    if idle then
        assert(anim:GetToDoSkill():ToString() == "None" and anim:GetDoingSkill():ToString() == "None", "skill active")
    end
    local generation = table.concat({id(hud), id(pawn), id(mesh), id(anim)}, "|")
    return pawn, mesh, generation, id(anim)
end
local function resolve(label, pawn, mesh, actor, observedMode)
    local spec = specs[label]
    local parent, attach = mesh, spec[4]
    if spec[1] then
        local expectedMode = observedMode or spec[5]
        assert(class(actor) == "BlueprintGeneratedClass " .. bp(spec[1])
            and id(actor:GetOwner()) == id(pawn) and actor.bHidden == false
            and (observedMode ~= nil or actor.equipMode == expectedMode), "actor context changed " .. label)
        parent, attach = actor.RootComponent, "None"
        assert(visible(parent) and id(parent:GetOwner()) == id(actor)
            and id(parent:GetAttachParent()) == id(mesh) and socket(parent) == (observedMode and sockets[observedMode] or spec[4]), "root changed " .. label)
    end
    local c = actor[spec[2]]
    assert(class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and asset(c, spec[3])
        and id(c:GetAttachParent()) == id(parent) and socket(c) == attach
        and type(c.bVisible) == "boolean" and c.bHiddenInGame == false, "component changed " .. label)
    local generation = table.concat({id(actor), id(parent), id(c), id(c.SkeletalMesh)}, "|")
    return c, generation
end
local function held(actor, out)
    local c = actor.SkeletalMesh
    assert(class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and asset(c, "hilda_cudgel")
        and id(c:GetAttachParent()) == id(actor.RootComponent) and socket(c) == "None"
        and c.bVisible == (out == true) and c.bHiddenInGame == false, "held mesh changed")
    return c, id(c) .. "|" .. id(c.SkeletalMesh)
end
local EQUIP = bp("HildaCudgel_BP") .. ":EquipModeChange"
local SLOT = PAWN:match("^[^ ]+ (.+)$")
    .. ":BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature"
local state, epoch, token = "idle", 0, 0
local bound, timer, drawPending, pair, cleanup, queued, retiredPawn
local hooks, last = {}, {}
local function log(category, event, fields)
    print("MS_FREE id=scabbard-freeplay-01 time=" .. os.date("%H:%M:%S")
        .. " epoch=" .. epoch .. " state=" .. state .. " category=" .. category
        .. " event=" .. event .. " " .. (fields or "") .. "\n")
end
local function report(key, category, event, fields)
    if last[key] == fields then return end
    last[key] = fields
    log(category,event,fields)
end
local function active() return state ~= "idle" and state ~= "stopped" end
local function cancel(reason)
    token = token + 1
    local old = timer
    if not old then return end
    timer = nil
    local ok = pcall(CancelDelayedAction, old.handle)
    local checked, live = pcall(IsValidDelayedActionHandle, old.handle)
    if ok and checked and not live then
        log("PASS","SHADOW_CANCEL","reason=" .. reason .. " token=" .. old.token)
    else
        cleanup = old
        state = "cleanup_pending"
        log("FAIL","CLEANUP_PENDING","reason=timer-cancel token=" .. old.token .. " writes=0")
    end
end
local function boundary(reason)
    cancel(reason)
    if bound and (reason == "load-map" or reason == "pawn-end-play") then retiredPawn = bound.pawn end
    bound, drawPending, pair = nil, false, nil
    if state ~= "cleanup_pending" then state = "recovering" end
    log("OBSERVED_ONLY","BOUNDARY","reason=" .. reason)
end
local function guarded(label, fn)
    if not active() then return end
    local ok, err = pcall(fn)
    if not ok then
        cancel(label)
        pair, drawPending = nil, true
        if state ~= "cleanup_pending" then state = "diagnostics_only" end
        report("error:"..label,"FAIL","GUARD","where="..label.." detail="..string.format("%q",tostring(err)))
    else
        last["error:"..label] = nil
    end
end
local function contextNow()
    if bound then
        local ok, pawn, mesh, key, anim = pcall(context, StaticFindObject(bound.hud), false)
        if ok and key == bound.key then return pawn, mesh, key, anim end
        boundary("context-changed")
    end
    local hud = one("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
    local pawn, mesh, key, anim = context(hud, false)
    assert(id(pawn) ~= retiredPawn,"retired pawn still in viewport")
    retiredPawn = nil
    bound = {hud=path(hud), key=key, pawn=id(pawn), anim=anim, actors={}, watch={}}
    if state ~= "cleanup_pending" then state = "diagnostics_only" end
    log("OBSERVED_ONLY","GENERATION","identity=" .. string.format("%q",key))
    return pawn, mesh, key, anim
end
local function discover(pawn, mesh)
    local actors, watch = {}, {}
    for _, label in ipairs(order) do
        local spec = specs[label]
        local ok, actor = pcall(function()
            local n = spec[1]
            return n and one(n.."_C", function(o)
                return class(o) == "BlueprintGeneratedClass " .. bp(n) and id(o:GetOwner()) == id(pawn)
            end) or pawn
        end)
        if ok then
            local exact, _, generation = pcall(resolve,label,pawn,mesh,actor)
            actors[label] = {path=path(actor), key=id(actor), generation=exact and generation or nil}
            local c = actor[spec[2]]
            if valid(c) and id(c:GetOwner()) == id(actor) and asset(c,spec[3]) then watch[id(c)] = label end
            if label == "sheath" then
                local main = actor.SkeletalMesh
                if valid(main) and id(main:GetOwner()) == id(actor) and asset(main,"hilda_cudgel") then watch[id(main)] = "held" end
            end
        end
    end
    watch[id(mesh)] = "character"
    bound.actors, bound.watch = actors, watch
end
local function target(label, pawn, mesh, mode)
    local old = assert(bound.actors[label],"missing "..label)
    local actor = specs[label][1] and StaticFindObject(old.path) or pawn
    assert(id(actor) == old.key,"actor changed "..label)
    local c, key = resolve(label,pawn,mesh,actor,mode)
    return c, key, actor
end
local function group(pawn,mesh,post)
    local keys = {}
    for _, label in ipairs(order) do
        local c, key, actor = target(label,pawn,mesh,label == "sheath" and post or nil)
        assert(c.bVisible == true,"non-stock visible "..label)
        keys[#keys+1] = key
        if label == "sheath" then
            local _, heldKey = held(actor,false)
            keys[#keys+1] = heldKey
        end
    end
    return table.concat(keys,"|")
end
local function boundaryRows(pawn,mesh,stage)
    for _, label in ipairs(order) do
        local row = bound.actors[label]
        local ok, c, key, actor = pcall(target,label,pawn,mesh)
        local fields = "stage="..stage.." part="..label.." exact="..tostring(ok)
            .." same="..tostring(ok and row.generation==key)
            .." actor="..string.format("%q",tostring(row and row.key))
        if ok then fields = fields .. " identity="..string.format("%q",key)
            .." visible="..tostring(c.bVisible).." hidden="..tostring(c.bHiddenInGame)
        else fields = fields .. " detail="..string.format("%q",tostring(c)) end
        report("boundary:"..stage..label,"OBSERVED_ONLY","TARGET",fields)
    end
end
local function schedule(key, generation)
    cancel("new-sheath")
    if cleanup then return end
    local mine, session = token, epoch
    local handle = ExecuteInGameThreadWithDelay(2000,function()
        if not active() or epoch ~= session or token ~= mine or not timer then return end
        timer = nil
        guarded("expiry",function()
            local pawn,mesh,current = contextNow()
            assert(current == generation and not drawPending,"stale generation/draw")
            local anim = mesh:GetAnimInstance()
            assert(anim:GetToDoSkill():ToString()=="None" and anim:GetDoingSkill():ToString()=="None","skill active")
            assert(group(pawn,mesh) == key,"target generation changed")
            log("SKIPPED_UNSAFE","SHADOW_HIDE","token="..mine.." reason=equipment-boundary-unverified writes=0")
        end)
    end)
    timer = {handle=handle, token=mine}
    assert(math.type(handle)=="integer" and IsValidDelayedActionHandle(handle),"unverified timer handle")
    log("OBSERVED_ONLY","SHADOW_SCHEDULE","token="..mine.." delay_ms=2000")
end
local function draw(param)
    guarded("draw",function()
        local anim = param:get()
        if not (class(anim) or ""):match("%.hilda_AnimBP_C$") then return end
        local pawn,mesh,_,animId = contextNow()
        if id(anim) ~= animId then return end
        if not bound.actors.sheath then discover(pawn,mesh) end
        local s = bound.actors.sheath
        local actor = s and StaticFindObject(s.path)
        local mode = valid(actor) and actor.equipMode
        local skill = anim:GetToDoSkill():ToString()
        log("OBSERVED_ONLY","SKILL","skill="..skill.." mode="..tostring(mode).." pawn="..string.format("%q",bound.pawn))
        if mode == 0 then
            cancel("in-hand")
            return
        end
        cancel("draw")
        pair = nil
        drawPending = skill == "hilda_cudgel_atk1_idle" and (mode == 1 or mode == 3)
        if not drawPending then log("SKIPPED_UNSAFE","DRAW","reason=unsupported-state writes=0") end
    end)
end
local function writer(channel,stage,param,flag,propagate)
    if not bound then return end
    guarded("writer",function()
        local c = param:get()
        local label = bound.watch[id(c)]
        if not label then return end
        local value, prop = flag:get(), propagate:get()
        assert(type(value)=="boolean" and type(prop)=="boolean","writer flags unavailable")
        report("writer:"..channel..stage..label,"OBSERVED_ONLY","WRITER",
            "part="..label.." channel="..channel.." stage="..stage.." value="..tostring(value).." propagate="..tostring(prop))
        if stage == "pre" then
            cancel("writer-"..label)
            pair = channel=="visible" and label=="sheath" and not prop and {value=value} or nil
        elseif channel=="visible" and label=="sheath" and pair and pair.value==value and not prop then
            pair.post = c.bVisible == value
        end
    end)
end
local function equip(param,arg)
    guarded("equip-mode",function()
        local actor = param:get()
        local pawn,mesh,key = contextNow()
        if not valid(actor) or id(actor:GetOwner()) ~= id(pawn) then return end
        local mode = arg:get()
        assert(math.type(mode)=="integer","mode unavailable")
        local seen = pair
        pair = nil
        local root = actor.RootComponent
        log("OBSERVED_ONLY","EQUIP_POST","mode="..mode.." socket="..(valid(root) and socket(root) or "unknown")
            .." actor="..string.format("%q",id(actor)))
        if mode ~= 1 then
            cancel("non-sheath")
            if mode == 0 then drawPending=false end
            return
        end
        if drawPending then
            cancel("late-sheath")
            log("PASS","SHADOW_SHEATH_SKIP","reason=draw-pending")
            return
        end
        discover(pawn,mesh)
        assert(bound.actors.sheath and bound.actors.sheath.key == id(actor),"unverified cudgel identity")
        if not (seen and seen.post and seen.value) then
            cancel("unpaired-sheath")
            log("SKIPPED_UNSAFE","SHEATH","reason=writer-pair-unavailable")
            return
        end
        schedule(group(pawn,mesh,1),key)
    end)
end
local function equipment(param,arg)
    guarded("equipment-slot",function()
        local pawn,mesh = contextNow()
        if id(param:get()) ~= id(pawn) then return end
        cancel("equipment-post")
        drawPending,pair=false,nil
        local value = arg:get()
        log("OBSERVED_ONLY","SETTING_EQUIP_POST","weapon_type="..tostring(value).." pawn="..string.format("%q",bound.pawn))
        boundaryRows(pawn,mesh,"old-at-post")
        discover(pawn,mesh)
        boundaryRows(pawn,mesh,"current-at-post")
        log("SKIPPED_UNSAFE","EQUIPMENT","reason=post-order-unverified writes=0")
    end)
end
local function attach(pathName,native,first,second)
    if hooks[pathName] then return end
    local f = StaticFindObject(pathName)
    assert(valid(f) and f:type()=="UFunction" and name(f)=="Function "..pathName
        and ((f:GetFunctionFlags() & 0x400)~=0)==native,"hook unavailable "..pathName)
    local a,b
    if native then a,b=RegisterHook(pathName,first,second) else a,b=RegisterHook(pathName,first) end
    if math.type(a)=="integer" and math.type(b)=="integer" and a>0 and b>0 then hooks[pathName]={a,b} end
    assert(hooks[pathName] and ((a~=b)==native),"unexpected hook ids")
end
local function installHooks()
    guarded("hook-draw",function() attach(DRAW,true,draw,function() end) end)
    guarded("hook-mode",function() attach(EQUIP,false,equip) end)
    guarded("hook-slot",function() attach(SLOT,false,equipment) end)
    for _, item in ipairs({{VIS,"visible"},{HIDDEN,"hidden"}}) do
        local channel=item[2]
        guarded("hook-"..channel,function()
            attach(item[1],true,function(...) writer(channel,"pre",...) end,function(...) writer(channel,"post",...) end)
        end)
    end
end
local function refresh()
    installHooks()
    guarded("refresh",function()
        local pawn,mesh=contextNow()
        discover(pawn,mesh)
        boundaryRows(pawn,mesh,"refresh")
    end)
end
local function dispatch(fn)
    local ok,err = pcall(ExecuteInGameThread,fn,EGameThreadMethod.EngineTick)
    if not ok then log("FAIL","DISPATCH","detail="..string.format("%q",tostring(err))) end
    return ok
end
local function start()
    if active() then refresh(); return end
    if cleanup or next(hooks) then
        log("FAIL","CLEANUP_PENDING","reason=previous-session writes=0")
        return
    end
    epoch, state, last = epoch+1,"recovering",{}
    log("SKIPPED_UNSAFE","START","control=blocked reason=equipment-boundary-unverified writes=0")
    refresh()
end
local function stop()
    state = "stopped"
    cancel("stop")
    state = "stopped"
    if cleanup then
        local ok, live = pcall(IsValidDelayedActionHandle,cleanup.handle)
        if ok and not live then cleanup=nil end
    end
    bound,drawPending,pair,retiredPawn=nil,false,nil,nil
    for hook,ids in pairs(hooks) do
        local ok, result = pcall(UnregisterHook,hook,ids[1],ids[2])
        if ok and result ~= false then hooks[hook]=nil end
    end
    local pending = cleanup or next(hooks)
    log(pending and "FAIL" or "PASS",pending and "CLEANUP_PENDING" or "CLEANED","writes=0")
end
assert(EngineTickAvailable and type(RegisterLoadMapPreHook)=="function"
    and type(RegisterEndPlayPreHook)=="function","required lifecycle API unavailable")
RegisterLoadMapPreHook(function() guarded("load-map",function() boundary("load-map") end) end)
if type(RegisterLoadMapPostHook)=="function" then
    RegisterLoadMapPostHook(function()
        if not active() then return end
        local mine=epoch
        dispatch(function() if active() and epoch==mine then refresh() end end)
    end)
end
RegisterEndPlayPreHook(function(param)
    guarded("end-play",function()
        if not bound then return end
        local key=id(param:get())
        if key==bound.pawn then boundary("pawn-end-play"); return end
        for _, a in pairs(bound.actors) do
            if key==a.key then boundary("equipment-end-play"); return end
        end
    end)
end)
local mods={ModifierKey.CONTROL,ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7,mods) and not IsKeyBindRegistered(Key.F8,mods),"test chord occupied")
RegisterKeyBind(Key.F7,mods,function()
    if queued then return end
    queued=true
    if not dispatch(function() queued=false; start() end) then queued=false end
end)
RegisterKeyBind(Key.F8,mods,function() dispatch(stop) end)
log("OBSERVED_ONLY","LOADED","start=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
