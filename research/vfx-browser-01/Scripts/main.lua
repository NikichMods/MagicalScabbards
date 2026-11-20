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
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
local keys = {{Key.F5,"CLOSE"},{Key.F6,"PREV"},{Key.F7,"NEXT"},{Key.F9,"REPLAY"}}
local entries, selected = nil, 0
local ui, labelRef, particle = nil, nil, nil
local uiFault, particleFault, busy, disabled = false, false, false, false
local alive, spawn = nil, nil

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
        log("CLOSED","press Ctrl+Alt+F7 to open with a fresh loaded-assets snapshot")
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
local function anchor(mesh)
    for _,socketName in ipairs({"scabbard_b","scabbard_a"}) do
        local socket=FName(socketName,EFindName.FNAME_Find)
        if socket:ToString()==socketName and mesh:DoesSocketExist(socket) then return socket,socketName end
    end
    error("no tested scabbard socket present")
end
local function preview(step)
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
        local e=entries[selected]
        assert(e,"no candidate")
        local title=("%02d/%02d  %s"):format(selected,#entries,e.label)
        message(title.." | checking...")
        local asset,info=assetFor(e)
        if not asset then
            message(title.." | SKIP: "..tostring(info):sub(1,65))
            log("SKIPPED",("id=%02d path=%s reason=%s"):format(selected,e.path,tostring(info)))
            return
        end
        alive=alive or static("KismetSystemLibrary","IsValid")
        spawn=spawn or static("GameplayStatics","SpawnEmitterAttached")
        assert(alive(context.pawn) and alive(context.mesh) and alive(asset),"context invalidated")
        local socket,socketName=anchor(context.mesh)
        local scale={X=0.40,Y=0.40,Z=0.40}
        local c=spawn(asset,context.mesh,socket,{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},scale,0,true,0,false)
        assert(alive(c) and full(c:GetClass())==PSC,"spawn returned unexpected component")
        particle=ref(c)
        assert(c.Template:GetAddress()==asset:GetAddress() and c:GetAttachParent():GetAddress()==context.mesh:GetAddress()
            and c:GetAttachSocketName():ToString()==socketName, "spawn attachment verification failed")
        local item=particle
        local handle=ExecuteInGameThreadWithDelay(1600,function()
            if particle==item then clearParticle("watchdog") end
        end)
        assert(math.type(handle)=="integer" and IsValidDelayedActionHandle(handle),"watchdog unavailable")
        c:Activate(false)
        message(title.." | PLAY  scale=.40  "..socketName)
        log("PLAY",("id=%02d path=%s %s"):format(selected,e.path,info))
    end)
    if not ok then
        log("FAILED",tostring(err):sub(1,300))
        clearParticle("error")
    end
    busy=false
end
local function execute(action)
    if disabled then return end
    local ok,err=pcall(ExecuteInGameThread,function()
        if action=="CLOSE" then close()
        elseif action=="NEXT" then preview(1)
        elseif action=="PREV" then preview(-1)
        else preview(0) end
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
    for _,pair in ipairs(keys) do
        assert(pair[1] and not IsKeyBindRegistered(pair[1],mods),"research key occupied: "..pair[2])
    end
    RegisterLoadMapPreHook(function()
        local checked,problem=pcall(close)
        if not checked then log("MAP_CLEANUP_FAULT",tostring(problem):sub(1,220)) end
    end)
    for _,pair in ipairs(keys) do RegisterKeyBind(pair[1],mods,function() execute(pair[2]) end) end
end)
if ok then
    log("ARMED","Ctrl+Alt+F7 next / F6 previous / F9 replay / F5 close; game-thread only")
else
    disabled=true
    log("UNAVAILABLE",tostring(err):sub(1,300))
end
