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
local SETTINGS_KEY = "NikichMods.MagicalScabbards.StaffSpark.v1"
local COLOR_INPUTS = {1.0,0.75,0.50} -- First step is the untouched stock instance.
local colorIndex, staffColorVerified = 1, false
-- Independent unmodified keys; no Ctrl/Alt chords.
local entries, selected = nil, 0
local scalePercent = 50
local staffScalePercent = 60
-- Staff cast spark only: change preview animation rate, never a stock asset.
local TIME_RATES = {0.2,0.3,0.5}
local timeRateIndex = 3 -- initial 0.5
-- Real-time browser cleanup cutoff, independently selectable from particle dilation.
-- Integer milliseconds avoid rounding drift at quarter-second steps.
local CUTOFF_MIN_MS, CUTOFF_MAX_MS, CUTOFF_STEP_MS = 250, 3000, 250
local cutoffMsStaff = 1500
local ui, labelRef, particle = nil, nil, nil
local uiFault, particleFault, busy, disabled = false, false, false, false
local tuning = false
local alive, spawn = nil, nil
local inspectedStaffSpark = false

local function log(event, details)
    print(("[MSVfxBrowser01] %s %s\n"):format(event, details or ""))
end
local function shareSettings()
    local value=("%d:%d:%d"):format(staffScalePercent,TIME_RATES[timeRateIndex]*10,cutoffMsStaff)
    local ok,err=pcall(function()
        ModRef:SetSharedVariable(SETTINGS_KEY,value)
        assert(ModRef:GetSharedVariable(SETTINGS_KEY)==value,"shared settings readback mismatch")
    end)
    if ok then log("SETTINGS_SHARED",value)
    else log("SETTINGS_UNAVAILABLE",tostring(err):sub(1,180)) end
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
    tuning = false
    local p=clearParticle("user-or-map")
    local u=clearUI()
    if p and u then
        entries,selected=nil,0
        log("CLOSED","press F4 to open with a fresh loaded-assets snapshot")
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
local function reportColorMapping(distribution, location)
    local ok, detail=pcall(function()
        local function rgb(vector)
            return ("%.3g,%.3g,%.3g"):format(vector.X,vector.Y,vector.Z)
        end
        return ("constant=%s input=%s..%s output=%s..%s"):format(rgb(distribution.Constant),
            rgb(distribution.MinInput),rgb(distribution.MaxInput),rgb(distribution.MinOutput),rgb(distribution.MaxOutput))
    end)
    local modesOk, modes=pcall(function()
        local value=distribution.ParamModes
        if type(value)=="number" then return "first_only:"..tostring(value) end
        if (type(value)=="table" or type(value)=="userdata")
            and type(value[1])=="number" and type(value[2])=="number" and type(value[3])=="number" then
            return ("%d,%d,%d"):format(value[1],value[2],value[3])
        end
        return "unexposed"
    end)
    log("COLOR_MAPPING",location.." "..(ok and detail or "range=unavailable")
        .." modes="..(modesOk and modes or "unexposed"))
end
local function inspectStaffSpark(asset)
    local fields={"StartLocation","StartRadius","StartHeight","VelocityScale",
        "StartVelocity","StartVelocityRadial","Velocity","VelOverLife","Acceleration",
        "StartSize","SizeScale","LifeMultiplier","LifeTime","BrightnessOverLife","RadiusScale",
        "ColorOverLife","AlphaOverLife","ColorScaleOverLife","AlphaScaleOverLife"}
    local function reportModule(module, location)
        if not valid(module) then return end
        local class=full(module:GetClass())
        local namedColor=false
        log("STAFF_MODULE",location.." class="..class.." enabled="..tostring(module.bEnabled))
        local reflection=module:Reflection()
        for _,key in ipairs(fields) do
            local prop=reflection:GetProperty(key)
            local signature=prop and prop:GetFullName()
            if type(signature)=="string" and signature:match("^StructProperty .+:"..key.."$") then
                local raw=module[key]
                local distribution=raw.Distribution
                local kind=valid(distribution) and full(distribution:GetClass()) or "unexposed"
                local parameter
                if kind=="Class /Script/Engine.DistributionFloatParticleParameter"
                    or kind=="Class /Script/Engine.DistributionVectorParticleParameter" then
                    parameter=distribution.ParameterName:ToString()
                end
                log("STAFF_DISTRIBUTION",("%s field=%s class=%s min=%s max=%s%s"):format(
                    location,key,kind,tostring(raw.MinValue),tostring(raw.MaxValue),
                    parameter and " parameter="..parameter or ""))
                if class=="Class /Script/Engine.ParticleModuleColorScaleOverLife"
                    and module.bEnabled==true and key=="ColorScaleOverLife" and parameter=="Color"
                    and kind=="Class /Script/Engine.DistributionVectorParticleParameter" then
                    namedColor=true
                    reportColorMapping(distribution,location)
                end
            end
        end
        return namedColor
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
    local emittersWithColor, complete=0,true
    each(asset.Emitters,10,function(emitter,i)
        local activeLods=0
        each(emitter.LODLevels,6,function(lod,j)
            if lod.bEnabled~=false then
                activeLods=activeLods+1
                local tag=("emitter=%d lod=%d"):format(i,j)
                log("STAFF_LOD",tag.." local_space="..tostring(lod.RequiredModule.bUseLocalSpace)
                    .." type="..tostring(full(lod.TypeDataModule)))
                local found=false
                each(lod.Modules,32,function(module,k)
                    if reportModule(module,tag.." module="..k) then found=true end
                end)
                complete=complete and found
            end
        end)
        if activeLods>0 then emittersWithColor=emittersWithColor+1 end
    end)
    log("STAFF_INSPECT_DONE","read-only")
    return complete and emittersWithColor==2
end
local function setPreviewColor(component, factor)
    assert(staffColorVerified,"staff Color distribution unverified")
    local parameter=FName("Color",EFindName.FNAME_Find)
    assert(parameter:ToString()=="Color","Color FName unavailable")
    component:SetVectorParameter(parameter,{X=factor,Y=factor,Z=factor})
    local params=component.InstanceParameters
    local count=params:GetArrayNum()
    assert(count<=32,"unexpected instance-parameter count")
    for i=1,count do
        assert(i<=params:GetArrayNum(),"instance parameter array changed")
        local row=params[i]
        if row.Name:ToString()=="Color" and row.ParamType==3 then -- PSPT_Vector
            local rgb=row.Vector
            assert(math.abs(rgb.X-factor)<0.0001 and math.abs(rgb.Y-factor)<0.0001
                and math.abs(rgb.Z-factor)<0.0001,"Color vector readback mismatch")
            log("COLOR_SET",("input=%.2f,%.2f,%.2f instance_readback=ok"):format(factor,factor,factor))
            return
        end
    end
    error("Color vector missing from owned component")
end
local function anchor(mesh)
    for _,socketName in ipairs({"scabbard_b","scabbard_a"}) do
        local socket=FName(socketName,EFindName.FNAME_Find)
        if socket:ToString()==socketName and mesh:DoesSocketExist(socket) then return socket,socketName end
    end
    error("no tested scabbard socket present")
end
local function preview(step, scaleDelta, staffTimingChanged)
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
            selected=2 -- Fixed catalog entry: Staff cast spark.
        elseif step~=0 then
            selected=((selected-1+step) % #entries)+1
        end
        local e=entries[selected]
        assert(e,"no candidate")
        local isStaff=e.path==STAFF_SPARK
        local size
        if isStaff then
            staffScalePercent=math.max(10,math.min(60,staffScalePercent+scaleDelta))
            size=staffScalePercent/100
            if scaleDelta~=0 or staffTimingChanged then shareSettings() end
        else
            scalePercent=math.max(10,math.min(60,scalePercent+scaleDelta))
            size=scalePercent/100
        end
        local rate=isStaff and TIME_RATES[timeRateIndex] or 1.0
        local cutoffMs=isStaff and cutoffMsStaff or 1600
        local colorLabel=colorIndex==1 and "stock" or ("%.2f"):format(COLOR_INPUTS[colorIndex])
        local title=("%02d/%02d  %s  scale=%.2f%s"):format(selected,#entries,e.label,size,
            isStaff and ("  time=%.1f  cutoff=%.2fs  Color=%s"):format(rate,cutoffMs/1000,colorLabel) or "")
        message(title.." | checking...")
        local asset,info=assetFor(e)
        if not asset then
            message(title.." | SKIP: "..tostring(info):sub(1,65))
            log("SKIPPED",("id=%02d path=%s reason=%s"):format(selected,e.path,tostring(info)))
            return
        end
        if isStaff and not inspectedStaffSpark then
            inspectedStaffSpark=true
            local inspected,result=pcall(inspectStaffSpark,asset)
            staffColorVerified=inspected and result==true
            if not inspected then log("STAFF_INSPECT_FAILED",tostring(result):sub(1,240)) end
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
        if isStaff and colorIndex~=1 then setPreviewColor(c,COLOR_INPUTS[colorIndex]) end
        c:Activate(false)
        message(title.." | PLAY  "..socketName)
        log("PLAY",("id=%02d path=%s scale=%.2f rate=%.1f cutoff_ms=%d %s"):format(
            selected,e.path,size,rate,cutoffMs,info)..(isStaff and " color="..colorLabel or ""))
    end)
    if not ok then
        log("FAILED",tostring(err):sub(1,300))
        clearParticle("error")
    end
    busy=false
end
local function handleKey(action)
    if disabled then return end
    local step = action=="NEXT" and 1 or action=="PREVIOUS" and -1 or 0
    local scaleDelta = action=="SMALLER" and -5 or action=="LARGER" and 5 or 0
    local ok,err=pcall(ExecuteInGameThread,function()
        if action=="TOGGLE" then
            if tuning then close(); return end
            tuning=true
            log("TUNING","NumPad 4/6 effects, 7/9 speed, 1/3 cutoff, 2/8 Color input; F2/F3 scale, F9 replay")
        elseif not tuning then
            return
        end
        if action=="COLOR_DOWN" or action=="COLOR_UP" then
            local e=entries and entries[selected]
            if not e or e.path~=STAFF_SPARK or not staffColorVerified then
                if e then message(("%02d/%02d  %s | Color unavailable"):format(selected,#entries,e.label)) end
                log("COLOR_UNAVAILABLE","select verified Staff cast spark (id=02)")
                return
            end
            local delta=action=="COLOR_DOWN" and 1 or -1
            colorIndex=math.max(1,math.min(#COLOR_INPUTS,colorIndex+delta))
        end
        local staffTiming = action=="SLOWER" or action=="FASTER"
            or action=="CUTOFF_SHORTER" or action=="CUTOFF_LONGER"
        if staffTiming then
            if not entries or not entries[selected] or entries[selected].path~=STAFF_SPARK then
                log("STAFF_CONTROL_SKIPPED","select Staff cast spark (id=02) first action="..action)
                return
            end
            if action=="SLOWER" or action=="FASTER" then
                local delta=action=="SLOWER" and -1 or 1
                timeRateIndex=math.max(1,math.min(#TIME_RATES,timeRateIndex+delta))
            else
                local delta=action=="CUTOFF_SHORTER" and -CUTOFF_STEP_MS or CUTOFF_STEP_MS
                cutoffMsStaff=math.max(CUTOFF_MIN_MS,math.min(CUTOFF_MAX_MS,cutoffMsStaff+delta))
                log("CUTOFF_SET",("id=02 cutoff_ms=%d range_ms=%d..%d step_ms=%d"):format(
                    cutoffMsStaff,CUTOFF_MIN_MS,CUTOFF_MAX_MS,CUTOFF_STEP_MS))
            end
        end
        preview(step,scaleDelta,staffTiming)
    end,EGameThreadMethod.EngineTick)
    if not ok then log("DISPATCH_FAILED",tostring(err):sub(1,200));disabled=true end
end
local function bind(group, bindings)
    local ready=false
    local ok,err=pcall(function()
        for _,binding in ipairs(bindings) do
            local key=Key[binding[1]]
            assert(type(key)=="number" and not IsKeyBindRegistered(key),binding[1].." unavailable")
        end
        for _,binding in ipairs(bindings) do
            RegisterKeyBind(Key[binding[1]],function()
                if ready and (tuning or binding[2]=="TOGGLE") then handleKey(binding[2]) end
            end)
        end
        ready=true
    end)
    if not ok then log(group.."_UNAVAILABLE",tostring(err):sub(1,220)) end
    return ok
end
local ok,err=pcall(function()
    assert(EngineTickAvailable and EGameThreadMethod and EGameThreadMethod.EngineTick,"game thread unavailable")
    assert(type(ExecuteInGameThread)=="function" and type(ExecuteInGameThreadWithDelay)=="function"
        and type(RegisterKeyBind)=="function" and type(IsKeyBindRegistered)=="function"
        and type(StaticFindObject)=="function" and type(LoadAsset)=="function"
        and type(FindAllOf)=="function" and type(StaticConstructObject)=="function"
        and type(RegisterLoadMapPreHook)=="function","required UE4SS API missing")
    assert(FName and EFindName and FText and EObjectFlags and EObjectFlags.RF_Transient,"UMG/FName unavailable")
    RegisterLoadMapPreHook(function()
        local checked,problem=pcall(close)
        if not checked then log("MAP_CLEANUP_FAULT",tostring(problem):sub(1,220)) end
    end)
end)
if not ok then
    disabled=true
    log("UNAVAILABLE",tostring(err):sub(1,300))
elseif bind("TUNING",{{"F4","TOGGLE"}}) then
    bind("NAVIGATION",{{"NUM_FOUR","PREVIOUS"},{"NUM_SIX","NEXT"}})
    bind("TIME",{{"NUM_SEVEN","SLOWER"},{"NUM_NINE","FASTER"}})
    bind("CUTOFF",{{"NUM_ONE","CUTOFF_SHORTER"},{"NUM_THREE","CUTOFF_LONGER"}})
    bind("COLOR",{{"NUM_TWO","COLOR_DOWN"},{"NUM_EIGHT","COLOR_UP"}})
    bind("SCALE",{{"F2","SMALLER"},{"F3","LARGER"}})
    bind("REPLAY",{{"F9","REPLAY"}})
    log("ARMED","F4 opens/closes tuning; controls inside the mode only, no modifiers")
end
