-- SPDX-License-Identifier: MPL-2.0
-- MSVfxBrowser01: research-only, user-triggered, no changes to scabbard visibility.
-- Stock Cascade previews only; no guessing of asset classes and no production hook.
local catalog = require("catalog")
local ROOT = "/Game/MainContent/Assets/fx/bp/"
local WIDGET = "/Game/MainContent/Template/UMG/Debug/PostionItemUMG_BP.PostionItemUMG_BP_C"
local HUD = "/Game/MainContent/Template/UMG/HUD/HUDMainUMG_BP.HUDMainUMG_BP_C"
local HILDA = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local MESH = "Class /Script/Engine.SkeletalMeshComponent"
local PSC = "Class /Script/Engine.ParticleSystemComponent"
local STAFF_SPARK = ROOT.."skill/hilda_ult/_stf01/private/stf01_spark.stf01_spark"
-- Independent unmodified keys; no Ctrl/Alt chords.
local KEYS = {{Key.F6,"PREVIOUS"},{Key.F7,"NEXT"},{Key.F9,"REPLAY"}}
local entries, selected = nil, 0
local scalePercent = 40
-- Staff cast spark only: change preview animation rate, never a stock asset.
local TIME_RATES = {0.2,0.3,0.5}
local timeRateIndex = 2 -- initial 0.3
local ui, labelRef, particle = nil, nil, nil
local uiFault, particleFault, busy, disabled = false, false, false, false
local alive, spawn = nil, nil
local inspectedStaffSpark = false

local function log(event, details)
    print(("[MSVfxBrowser01] %s %s\n"):format(event, details or ""))
end
local function valid(o) return o ~= nil and o:IsValid() end
local function full(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and tostring(o:GetAddress()) or nil end
local function ref(o)
    local n = assert(full(o), "object reference missing")
    return {path=assert(n:match("^[^ ]+ (.+)$")), address=id(o)}
end
local function resolve(x)
    if not x then return nil end
    local o = StaticFindObject(x.path)
    return valid(o) and id(o)==x.address and o or nil
end
local function static(cls,method,scope)
    scope = scope or "Engine"
    local path = "/Script/"..scope.."."..cls..":"..method
    local fn = StaticFindObject(path)
    local cdo = StaticFindObject("/Script/"..scope..".Default__"..cls)
    assert(full(fn) == "Function "..path and valid(cdo), "static API unavailable "..path)
    assert((fn:GetFunctionFlags() & 0x400) ~= 0, "non-native function "..path)
    return function(...) return fn(cdo,...) end
end
local function hilda()
    local found = nil
    local huds = FindAllOf("HUDMainUMG_BP_C") or {}
    assert(#huds<=8, "too many HUD candidates")
    for _,h in ipairs(huds) do
        local c=valid(h) and full(h:GetClass()) or nil
        if c and c:match("^[^ ]+ (.+)$")==HUD and h:IsInViewport() then
            local pawn = h:GetOwningPlayerPawn()
            if full(valid(pawn) and pawn:GetClass())==HILDA and pawn.bHidden==false then
                local mesh=pawn.Mesh
                if full(valid(mesh) and mesh:GetClass())==MESH
                    and (full(mesh) or ""):match("%.CharacterMesh0$")
                    and valid(mesh:GetOwner()) and mesh:GetOwner():GetAddress()==pawn:GetAddress() then
                    assert(not found, "multiple gameplay HUDs")
                    found={hud=h,pawn=pawn,mesh=mesh}
                end
            end
        end
    end
    assert(found, "controllable Hilda HUD not available")
    return found
end

-- Independent UMG label based on the accepted IIP host on this exact Steam/UE4SS build.
-- No changes are made to Hilda's own HUD/WidgetTree.
local function createUI(context)
    if uiFault or ui then return end
    local ok, err=pcall(function()
        local cls=StaticFindObject(WIDGET)
        if not valid(cls) then
            local asset,found,loaded=LoadAsset(WIDGET)
            assert(found==true and loaded==true and valid(asset), "widget class not loadable")
            cls=asset
        end
        assert(full(cls)=="WidgetBlueprintGeneratedClass "..WIDGET
            or (cls:type()=="UClass" and (full(cls) or ""):match(" "..WIDGET.."$")),
            "wrong widget class")
        local create=static("WidgetBlueprintLibrary","Create","UMG")
        local w=create(context.hud,cls,nil)
        assert(valid(w) and w:GetClass():GetAddress()==cls:GetAddress()
            and not w:IsInViewport(), "wrong/new viewport host")
        ui=ref(w) -- cleanup can now detach the new instance, even after partial failure.
        local t=w.WidgetTree
        local root=valid(t) and t.RootWidget
        local main=valid(root) and root:GetChildAt(0)
        local sample=w.Value_Text
        assert(valid(t) and valid(root) and valid(main) and valid(sample)
            and full(root:GetClass())=="Class /Script/UMG.CanvasPanel"
            and root:GetChildrenCount()==1, "unexpected private widget layout")
        main:SetVisibility(1) -- Only our own placeholder.
        local textClass=StaticFindObject("/Script/UMG.TextBlock")
        assert(valid(textClass), "native TextBlock unavailable")
        local label=StaticConstructObject(textClass,t,FName("MSVfxBrowserLabel"),EObjectFlags.RF_Transient)
        assert(valid(label) and label:GetOuter():GetAddress()==t:GetAddress(),"own TextBlock failed")
        labelRef=ref(label)
        label:SetVisibility(3)
        label:SetFont(sample.Font)
        label.Font.Size=21
        label:SetFont(label.Font)
        label:SetJustification(1)
        label:SetText(FText("MS VFX Browser"))
        local slot=root:AddChildToCanvas(label)
        assert(valid(slot) and slot.Content:GetAddress()==label:GetAddress(),"own slot unavailable")
        slot:SetAutoSize(false)
        slot:SetAnchors({Minimum={X=0.5,Y=0.5}, Maximum={X=0.5,Y=0.5}})
        slot:SetAlignment({X=0.5,Y=0.5})
        slot:SetPosition({X=0,Y=0})
        slot:SetSize({X=880,Y=55})
        w:SetDesiredSizeInViewport({X=900,Y=90})
        w:SetAnchorsInViewport({Minimum={X=0.5,Y=0.09},Maximum={X=0.5,Y=0.09}})
        w:SetAlignmentInViewport({X=0.5,Y=0.5})
        w:AddToViewport(110)
        assert(w:IsInViewport(),"own viewport host not attached")
        w:SetVisibility(3)
        assert(w.Visibility==3,"own UMG host invisible")
        log("UI_READY","own viewport widget, original HUD untouched")
    end)
    if not ok then
        uiFault=true
        log("UI_UNAVAILABLE",tostring(err):sub(1,260).." (UE4SS log remains authoritative)")
    end
end
local function message(text)
    log("SELECT",text)
    if uiFault then return end
    local ok,err=pcall(function()
        local w=resolve(ui)
        local label=resolve(labelRef)
        if w and label and w:IsInViewport() then label:SetText(FText(text)) end
    end)
    if not ok then uiFault=true; log("UI_UPDATE_FAILED",tostring(err):sub(1,180)) end
end
local function clearUI()
    if not ui then return true end
    local ok,err=pcall(function()
        local w=resolve(ui)
        if w then
            w:SetVisibility(1)
            local label=resolve(labelRef)
            if label then
                local parent=label:GetParent()
                if valid(parent) then
                    assert(parent:GetAddress()==w.WidgetTree.RootWidget:GetAddress(),"foreign label parent")
                    assert(parent:RemoveChild(label),"own label removal failed")
                end
            end
            w:RemoveFromParent()
            assert(not w:IsInViewport(),"own viewport detach unconfirmed")
        end
    end)
    if ok then ui,labelRef=nil,nil;log("UI_CLEANED","own viewport released") return true end
    log("UI_CLEANUP_PENDING",tostring(err):sub(1,230))
    return false
end
local function clearParticle(reason)
    if not particle then return true end
    local item=particle
    local ok,err=pcall(function()
        local c=resolve(item)
        if c and alive(c) then
            assert(full(c:GetClass())==PSC,"preview component class changed")
            c:K2_DestroyComponent(c)
            assert(not alive(c),"preview destruction not confirmed")
        end
    end)
    if not ok then
        particleFault=true
        log("CLEANUP_PENDING",reason.." "..tostring(err):sub(1,210))
        return false
    end
    particle=nil
    log("CLEANED","reason="..reason)
    return true
end
local function close()
    local p=clearParticle("user-or-map")
    local u=clearUI()
    if p and u then
        entries,selected=nil,0
        log("CLOSED","press F7 to open with a fresh loaded-assets snapshot")
    end
end
local function loadedPaths()
    local all=FindAllOf("ParticleSystem") or {}
    assert(type(all)=="table" and #all<6000, "unexpected particle count")
    local out={}
    for _,o in ipairs(all) do
        local n=full(o)
        if n and n:match("^ParticleSystem ") then out[#out+1]=n:sub(16) end
    end
    return out
end
local function ensureCatalog()
    if entries then return end
    local ok,paths=pcall(loadedPaths)
    if not ok then
        log("SCAN_UNAVAILABLE",tostring(paths):sub(1,220))
        paths={}
    end
    entries=catalog.build(paths,20)
    log("CATALOG",("entries=%d loaded_examined=%d max=20; all entries require exact verification"):format(#entries,#paths))
    for i,e in ipairs(entries) do
        log("ENTRY",("%02d %s source=%s path=%s"):format(i,e.label,e.origin,e.path))
    end
end
local function finite(asset)
    -- Conservative acceptance: every inspected enabled Cascade LOD must finish.
    -- Never traverse uncertain module-distribution graphs.
    local emitters=asset.Emitters
    assert(emitters, "emitter array not exposed")
    local count=emitters:GetArrayNum()
    assert(count>0 and count<=10, "emitter count out of bounds")
    local inspected=0
    for i=1,count do
        assert(i<=emitters:GetArrayNum(),"emitter count changed")
        local e=emitters[i]
        assert(valid(e),"emitter unavailable")
        local levels=e.LODLevels
        assert(levels,"LOD array unavailable")
        local n=levels:GetArrayNum()
        assert(n>0 and n<=6,"LOD count out of bounds")
        for j=1,n do
            assert(j<=levels:GetArrayNum(),"LOD count changed")
            local lod=levels[j]
            assert(valid(lod),"LOD unavailable")
            if lod.bEnabled~=false then
                local req=lod.RequiredModule
                assert(valid(req),"required module unavailable")
                local loops=req.EmitterLoops
                local duration=req.EmitterDuration
                if type(loops)~="number" or loops~=1 then
                    return false,"not-one-shot-emitter-"..i.." LOD-"..j
                end
                if type(duration)~="number" or duration<0 or duration>2.5 then
                    return false,"long-or-unknown-duration-emitter-"..i.." LOD-"..j
                end
                inspected=inspected+1
            end
        end
    end
    assert(inspected>0,"no enabled LOD verified")
    return true,("enabled_LODs=%d finite"):format(inspected)
end
local function assetFor(e)
    local o=StaticFindObject(e.path)
    if not valid(o) then
        local ok,asset,found=pcall(LoadAsset,e.path)
        if not ok then return nil,"LoadAsset-error "..tostring(asset) end
        if not found or not valid(asset) then return nil,"package/object unavailable" end
        o=asset
    end
    if full(o)~="ParticleSystem "..e.path then return nil,"not an exact ParticleSystem UObject" end
    local ok,allowed,info=pcall(finite,o)
    if not ok then return nil,"finite-preflight-unavailable "..tostring(allowed) end
    if not allowed then return nil,info end
    return o,info
end
local function inspectStaffSpark(asset)
    local fields={"StartLocation","StartRadius","StartHeight","VelocityScale",
        "StartVelocity","StartVelocityRadial","Velocity","VelOverLife","Acceleration",
        "StartSize","SizeScale","LifeMultiplier","LifeTime","BrightnessOverLife","RadiusScale"}
    local function reportModule(module, location)
        if not valid(module) then return end
        local class=full(module:GetClass())
        log("STAFF_MODULE",location.." class="..class.." enabled="..tostring(module.bEnabled))
        local reflection=module:Reflection()
        for _,key in ipairs(fields) do
            local prop=reflection:GetProperty(key)
            local signature=prop and prop:GetFullName()
            if type(signature)=="string" and signature:match("^StructProperty .+:"..key.."$") then
                local raw=module[key]
                local distribution=raw.Distribution
                local kind=valid(distribution) and full(distribution:GetClass()) or "unexposed"
                local parameter=""
                if kind=="Class /Script/Engine.DistributionFloatParticleParameter"
                    or kind=="Class /Script/Engine.DistributionVectorParticleParameter" then
                    parameter=" parameter="..distribution.ParameterName:ToString()
                end
                log("STAFF_DISTRIBUTION",("%s field=%s class=%s min=%s max=%s%s"):format(
                    location,key,kind,tostring(raw.MinValue),tostring(raw.MaxValue),parameter))
            end
        end
    end
    local function each(array, limit, visit)
        local count=array:GetArrayNum()
        assert(count<=limit,"staff diagnostic array too large")
        for i=1,count do
            assert(i<=array:GetArrayNum(),"staff diagnostic array changed")
            visit(array[i],i)
        end
    end
    log("STAFF_INSPECT","path="..STAFF_SPARK)
    each(asset.Emitters,10,function(emitter,i)
        each(emitter.LODLevels,6,function(lod,j)
            if lod.bEnabled~=false then
                local tag=("emitter=%d lod=%d"):format(i,j)
                log("STAFF_LOD",tag.." local_space="..tostring(lod.RequiredModule.bUseLocalSpace)
                    .." type="..tostring(full(lod.TypeDataModule)))
                each(lod.Modules,32,function(module,k) reportModule(module,tag.." module="..k) end)
            end
        end)
    end)
    log("STAFF_INSPECT_DONE","read-only")
end
local function anchor(mesh)
    for _,socketName in ipairs({"scabbard_b","scabbard_a"}) do
        local socket=FName(socketName,EFindName.FNAME_Find)
        if socket:ToString()==socketName and mesh:DoesSocketExist(socket) then return socket,socketName end
    end
    error("no tested scabbard socket present")
end
local function preview(step, scaleDelta)
    if disabled or particleFault or ui and not resolve(ui) then
        log("BLOCKED","disabled/cleanup fault; stop and restart game")
        return
    end
    if busy then return end
    busy=true
    local ok,err=pcall(function()
        local context=hilda()
        ensureCatalog()
        createUI(context)
        if not clearParticle("switch") then return end
        if selected==0 then
            selected=step<0 and #entries or 1
        elseif step~=0 then
            selected=((selected-1+step) % #entries)+1
        end
        scalePercent=math.max(10,math.min(60,scalePercent+scaleDelta))
        local size=scalePercent/100
        local e=entries[selected]
        assert(e,"no candidate")
        local isStaff=e.path==STAFF_SPARK
        local rate=isStaff and TIME_RATES[timeRateIndex] or 1.0
        local cutoffMs=isStaff and 1000 or 1600
        local title=("%02d/%02d  %s  scale=%.2f%s"):format(selected,#entries,e.label,size,
            isStaff and ("  time=%.1f  cutoff=1.0s"):format(rate) or "")
        message(title.." | checking...")
        local asset,info=assetFor(e)
        if not asset then
            message(title.." | SKIP: "..tostring(info):sub(1,65))
            log("SKIPPED",("id=%02d path=%s reason=%s"):format(selected,e.path,tostring(info)))
            return
        end
        if isStaff and not inspectedStaffSpark then
            inspectedStaffSpark=true
            local inspected,issue=pcall(inspectStaffSpark,asset)
            if not inspected then log("STAFF_INSPECT_FAILED",tostring(issue):sub(1,240)) end
        end
        alive=alive or static("KismetSystemLibrary","IsValid")
        spawn=spawn or static("GameplayStatics","SpawnEmitterAttached")
        assert(alive(context.pawn) and alive(context.mesh) and alive(asset),"context invalidated")
        local socket,socketName=anchor(context.mesh)
        local scale={X=size,Y=size,Z=size}
        local c=spawn(asset,context.mesh,socket,{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},scale,0,true,0,false)
        assert(alive(c) and full(c:GetClass())==PSC,"spawn returned unexpected component")
        particle=ref(c)
        assert(c.Template:GetAddress()==asset:GetAddress() and c:GetAttachParent():GetAddress()==context.mesh:GetAddress()
            and c:GetAttachSocketName():ToString()==socketName, "spawn attachment verification failed")
        if isStaff then
            -- PSC is ours and spawned with autoActivate=false; do not mutate Template or CDO.
            assert(type(c.CustomTimeDilation)=="number","PSC CustomTimeDilation unavailable")
            c.CustomTimeDilation=rate
            assert(math.abs(c.CustomTimeDilation-rate)<0.0001,
                "PSC CustomTimeDilation readback mismatch")
            log("TIME_SET",("id=%02d rate=%.1f cutoff_ms=%d"):format(selected,rate,cutoffMs))
        end
        local item=particle
        local handle=ExecuteInGameThreadWithDelay(cutoffMs,function()
            if particle==item then clearParticle("watchdog") end
        end)
        assert(math.type(handle)=="integer" and IsValidDelayedActionHandle(handle),"watchdog unavailable")
        c:Activate(false)
        message(title.." | PLAY  "..socketName)
        log("PLAY",("id=%02d path=%s scale=%.2f rate=%.1f cutoff_ms=%d %s"):format(
            selected,e.path,size,rate,cutoffMs,info))
    end)
    if not ok then
        log("FAILED",tostring(err):sub(1,300))
        clearParticle("error")
    end
    busy=false
end
local function selectCandidate(action)
    if disabled then return end
    local step = action=="NEXT" and 1 or action=="PREVIOUS" and -1 or 0
    local scaleDelta = action=="SMALLER" and -5 or action=="LARGER" and 5 or 0
    local ok,err=pcall(ExecuteInGameThread,function()
        if action=="TIME" then
            if not entries or not entries[selected] or entries[selected].path~=STAFF_SPARK then
                log("TIME_SKIPPED","select Staff cast spark (id=02) first")
                return
            end
            timeRateIndex=(timeRateIndex % #TIME_RATES)+1
        end
        preview(step,scaleDelta)
    end,EGameThreadMethod.EngineTick)
    if not ok then log("DISPATCH_FAILED",tostring(err):sub(1,200));disabled=true end
end
local ok,err=pcall(function()
    assert(EngineTickAvailable and EGameThreadMethod and EGameThreadMethod.EngineTick,"game thread unavailable")
    assert(type(ExecuteInGameThread)=="function" and type(ExecuteInGameThreadWithDelay)=="function"
        and type(RegisterKeyBind)=="function" and type(IsKeyBindRegistered)=="function"
        and type(StaticFindObject)=="function" and type(LoadAsset)=="function"
        and type(FindAllOf)=="function" and type(StaticConstructObject)=="function"
        and type(RegisterLoadMapPreHook)=="function","required UE4SS API missing")
    assert(FName and EFindName and FText and EObjectFlags and EObjectFlags.RF_Transient,"UMG/FName unavailable")
    for _,pair in ipairs(KEYS) do
        assert(pair[1] and not IsKeyBindRegistered(pair[1]),
            "unmodified research key occupied: "..pair[2])
    end
    RegisterLoadMapPreHook(function()
        local checked,problem=pcall(close)
        if not checked then log("MAP_CLEANUP_FAULT",tostring(problem):sub(1,220)) end
    end)
    for _,pair in ipairs(KEYS) do
        RegisterKeyBind(pair[1],function() selectCandidate(pair[2]) end)
    end
end)
if ok then
    log("ARMED","F6 previous / F7 next / F9 replay; no modifiers")
    local scaleReady=false
    local scaleOk,scaleErr=pcall(function()
        assert(Key.F2 and Key.F3 and not IsKeyBindRegistered(Key.F2) and not IsKeyBindRegistered(Key.F3),
            "F2/F3 unavailable")
        RegisterKeyBind(Key.F2,function() if scaleReady then selectCandidate("SMALLER") end end)
        RegisterKeyBind(Key.F3,function() if scaleReady then selectCandidate("LARGER") end end)
        scaleReady=true
    end)
    if scaleOk then log("SCALE_READY","F2 smaller / F3 larger")
    else log("SCALE_UNAVAILABLE",tostring(scaleErr):sub(1,220)) end
    local timeReady=false
    local timeOk,timeErr=pcall(function()
        assert(Key.F4 and not IsKeyBindRegistered(Key.F4),"F4 unavailable")
        RegisterKeyBind(Key.F4,function() if timeReady then selectCandidate("TIME") end end)
        timeReady=true
    end)
    if timeOk then log("TIME_READY","F4 cycles 0.3 -> 0.5 -> 0.2 -> 0.3 on Staff cast spark only")
    else log("TIME_UNAVAILABLE",tostring(timeErr):sub(1,220)) end
else
    disabled=true
    log("UNAVAILABLE",tostring(err):sub(1,300))
end
