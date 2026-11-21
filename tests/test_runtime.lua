-- SPDX-License-Identifier: MPL-2.0
local emit = print
local source = assert(io.open("Scripts/main.lua", "r"))
local version = assert(source:read("a"):match('local VERSION = "([^"]+)"'))
source:close()
local s = fixture({quiet=true, setup=function(state)
    local find = FindAllOf
    state.noHud = true
    FindAllOf = function(kind)
        if kind == "HUDMainUMG_BP_C" and state.noHud then return {} end
        return find(kind)
    end
end})
for t=0,5000,100 do s.tick(t) end
assert(s.hides == 0 and s.scans == 0 and not s.has("ERROR"))
s.loadPre(); s.noHud = false; s.loadPost()
s.arm(5100); assert(s.hides == 0); s.tick(8100); assert(s.hides == 6)
s.keys[8](); s.visible()
s = fixture({quiet=true})
assert(s.keys[7] == nil and s.keys[8] and #s.ticks == 1 and next(s.hooks))
assert(s.has(("[MagicalScabbards %s] INFO START"):format(version)))
s.arm(0); s.tick(3000)
assert(s.hides == 6 and s.has("HIDDEN targets=6"))
assert(not s.has("WINDOW_START") and not s.has("CENSUS_BEGIN") and not s.has("ADMISSION"))
local stale = s.ticks[1].callback
s.keys[8](); s.visible()
assert(s.has("CLEANED disabled") and not s.has("CLEANUP_PENDING") and not next(s.hooks))
stale(); assert(s.scans == 1 and s.hides == 6)
s.loadPre(); s.loadPost(); stale(); assert(#s.ticks == 1 and s.hides == 6)
s.keys[8](); assert(#s.ticks == 2 and next(s.hooks))
s.arm(3100); assert(s.hides == 6); s.tick(6100); assert(s.hides == 12)
stale(); assert(s.hides == 12)
s.loadPre(); s.visible(); s.tick(6200); assert(s.restores == 12)
s.loadPost(); s.arm(6300); assert(s.hides == 12); s.tick(9300); assert(s.hides == 18)
s.keys[8](); s.visible(); assert(not s.has("CLEANUP_PENDING"))

-- A streaming stall neither releases an intact mask nor counts toward a new hide.
s = fixture({quiet=true})
s.arm(0); s.tick(3000)
s.tick(3337); s.tick(3671)
assert(s.hides==6 and s.restores==0 and s.scans==1)
for _, target in ipairs(s.targets) do assert(not target.bVisible) end
s.pendingSkill = "hilda_cudgel_atk1_idle"
s.draw(); s.visible()
assert(s.restores==6 and s.has("draw-pre skill=hilda_cudgel_atk1_idle"))
s.keys[8]()

s = fixture({quiet=true})
s.arm(0); s.tick(3000)
s.hand = 4
s.tick(3337)
assert(s.restores==6 and s.has("phase-DRAWN")); s.visible()
s.keys[8]()

s = fixture({quiet=true})
for t=0,2800,100 do s.tick(t) end
s.tick(3137)
for t=3237,6037,100 do s.tick(t) end
assert(s.hides==0)
s.tick(6137)
assert(s.hides==6)
s.tick(6000)
assert(s.restores==6 and s.has("clock-regressed")); s.visible()
s.keys[8]()

-- Item skill phases preserve the mask, but an actual draw still releases it.
s = fixture({quiet=true})
s.arm(0); s.tick(3000)
for i,skill in ipairs({"hilda_drink_hp_rate", "hilda_useitem_throwlocator_begin",
    "hilda_useitem_throwlocator_loop", "hilda_useitem_throwlocator_release", "hilda_useitem_throwlocator_end",
    "hilda_switch_light", "enhance_astral", "enhance_fire", "enhance_ice", "enhance_thunder",
    "hilda_useitem_throwknife_begin", "hilda_useitem_throwbomb_release", "hilda_useitem_teleport_a"}) do
    s.pendingSkill = skill
    s.draw()
    s.doing, s.pendingSkill = skill, nil
    s.tick(3000+100*i)
    assert(s.hides==6 and s.restores==0 and s.scans==1)
    assert(s.has("ITEM preserving mask for skill="..skill))
end
s.pendingSkill = "hilda_staff_atk1_idle"
s.draw(); s.visible()
assert(s.restores==6 and s.has("draw-pre skill=hilda_staff_atk1_idle"))
s.keys[8]()

s = fixture({quiet=true})
s.arm(0); s.tick(3000)
s.pendingSkill = "hilda_useitem_unverified"
s.draw(); s.visible()
assert(s.restores==6 and s.has("draw-pre skill=hilda_useitem_unverified"))
s.keys[8]()

s = fixture({quiet=true})
s.arm(0); s.tick(3000)
s.doing, s.hand = "hilda_drink_hp_rate", 4
s.tick(3100); s.visible()
assert(s.restores==6 and s.has("phase-DRAWN"))
s.keys[8]()

-- Pure movement can also preserve a mask and the existing stowed window.
s = fixture({quiet=true})
for t=0,2800,100 do s.tick(t) end
s.pendingSkill = "hilda_dodge"
s.draw()
s.doing, s.pendingSkill = s.pendingSkill, nil
s.tick(2900); s.tick(3000)
assert(s.hides==6 and s.restores==0)
for i,skill in ipairs({"hilda_dodge_early", "hilda_step", "hilda_step_early"}) do
    s.pendingSkill = skill
    s.draw()
    s.doing, s.pendingSkill = skill, nil
    s.tick(3000+100*i)
    assert(s.hides==6 and s.restores==0 and s.has("preserving mask for skill="..skill))
end
s.pendingSkill = "hilda_dual_dodgeatk"
s.draw()
s.visible()
assert(s.restores==6 and s.has("draw-pre skill=hilda_dual_dodgeatk"))
s.doing, s.pendingSkill = nil, nil
s.arm(3400); s.tick(6400)
s.pendingSkill = "hilda_dual_shiftatk1"
s.draw()
s.visible()
assert(s.restores==12 and s.has("draw-pre skill=hilda_dual_shiftatk1"))
s.doing, s.pendingSkill = nil, nil
s.arm(6500); s.tick(9500)
s.doing, s.hand = "hilda_step", 4
s.tick(9600)
assert(s.restores==18 and s.has("phase-DRAWN"))
s.keys[8]()

-- The preview belongs to the same uninterrupted stowed window as hide.
local previewTimes = {}
local originalPreview = package.loaded.vfx.preview
package.loaded.vfx.preview = function(_, elapsed)
    previewTimes[#previewTimes+1] = elapsed
end
s = fixture({quiet=true})
for t=0,2800,100 do s.tick(t) end
s.tick(2899)
assert(#previewTimes == 0 and s.hides == 0)
s.tick(2900); s.tick(2999)
assert(#previewTimes == 1 and previewTimes[1] == 2900 and s.hides == 0)
s.draw() -- An already-started cosmetic burst does not commit the mask.
s.hand = 4
s.tick(3000)
assert(#previewTimes == 1 and s.hides == 0)
s.hand = 7
s.arm(3100)
assert(#previewTimes == 2 and s.hides == 0)
s.tick(6100)
assert(#previewTimes == 2 and s.hides == 6)
s.keys[8](); s.visible()
package.loaded.vfx.preview = originalPreview

-- A resident Staff cast spark uses only the new owned component and leaves mask timing intact.
local sparkPath = "/Game/MainContent/Assets/fx/bp/skill/hilda_ult/_stf01/private/stf01_spark.stf01_spark"
local sparks, watchdogs = {}, {}
local wantedScale, wantedRate, wantedCutoff = 0.60, 0.5, 1500
local allowAssetLoad, loadCalls = true, 0
s = fixture({quiet=true, setup=function(state)
    package.loaded.vfx = nil
    local function object(name)
        return {IsValid=function(self) return not self.dead end,
            GetFullName=function() return name end, GetAddress=function(self) return tostring(self) end}
    end
    local function api(class, method, callback)
        local base = "/Script/Engine."
        local path = base .. class .. ":" .. method
        local cdo = base .. "Default__" .. class
        state.objects[cdo] = object(class .. " " .. cdo)
        local fn = object("Function " .. path)
        fn.GetFunctionFlags = function() return 0x400 end
        state.objects[path] = setmetatable(fn, {__call=function(_, receiver, ...)
            assert(receiver == state.objects[cdo])
            return callback(...)
        end})
    end
    local asset = object("ParticleSystem " .. sparkPath)
    state.objects[sparkPath] = asset
    LoadAsset = function(path)
        assert(path == sparkPath)
        loadCalls = loadCalls + 1
        if not allowAssetLoad then return nil, false, false end
        state.objects[sparkPath] = asset
        return asset, true, true
    end
    FName = function(name) return {ToString=function() return name end} end
    EFindName = {FNAME_Find=0}
    local mesh = state.objects["pawn"].Mesh
    mesh.DoesSocketExist = function(_, socket) return socket:ToString()=="scabbard_b" end
    api("KismetSystemLibrary", "IsValid", function(value) return value and value:IsValid() end)
    api("GameplayStatics", "SpawnEmitterAttached", function(template, parent, socket, _, _, scale,
            attachment, autoDestroy, pooling, autoActivate)
        assert(template==asset and parent==mesh and socket:ToString()=="scabbard_b")
        assert(scale.X==wantedScale and scale.Y==wantedScale and scale.Z==wantedScale and attachment==0)
        assert(autoDestroy and pooling==0 and autoActivate==false)
        local c = object("Component pawn.spark")
        local class = object("Class /Script/Engine.ParticleSystemComponent")
        c.Template, c.CustomTimeDilation = template, 1
        c.GetClass = function() return class end
        c.GetAttachParent = function() return parent end
        c.GetAttachSocketName = function() return socket end
        c.K2_DestroyComponent = function(self, owner) assert(self==owner); self.dead=true end
        c.Activate = function(self, reset)
            assert(self.CustomTimeDilation==wantedRate and reset==false and #watchdogs==#sparks)
            self.activated = true
        end
        state.objects["pawn.spark"] = c
        sparks[#sparks+1] = c
        return c
    end)
    ExecuteInGameThreadWithDelay = function(ms, callback)
        assert(ms==wantedCutoff)
        watchdogs[#watchdogs+1] = callback
        return 100+#watchdogs
    end
    local isDelayed = IsValidDelayedActionHandle
    IsValidDelayedActionHandle = function(id) return id > 100 or isDelayed(id) end
end})
s.arm(0)
assert(#sparks==1 and sparks[1].activated and s.hides==0)
assert(s.has("scale=0.60 rate=0.5 cutoff_ms=1500"))
assert(loadCalls == 0)
s.tick(3000)
assert(s.hides==6)
watchdogs[1]()
assert(sparks[1].dead and s.restores==0)
-- Fixed settings survive successive windows, and stale watchdogs do not destroy new VFX.
s.draw(); s.visible()
s.arm(3100)
assert(#sparks==2 and sparks[2].activated)
watchdogs[1]()
assert(not sparks[2].dead)
s.tick(6100)
watchdogs[2]()
s.draw(); s.visible()
s.arm(6200)
assert(#sparks==3 and sparks[3].activated)
s.keys[8](); s.visible()
assert(sparks[3].dead and not s.has("CLEANUP_PENDING"))

-- Exact mixed-family fixtures; no Staff-only gate may remain in VFX.
s.addFamilies()
s.bracer.owner, s.bracer.RootComponent.parent = s.pawn, s.pawn.Mesh
s.keys[8]() -- restart
local t = 9500
for _, pair in ipairs({{0,1},{1,2},{2,3},{3,4},{4,5},{5,0},{5,7},{7,5},{1,7},{3,7}}) do
    s.first, s.second = pair[1], pair[2]
    local beforeBurst, beforeHide = #sparks, s.hides
    s.arm(t)
    assert(#sparks == beforeBurst+1, ("VFX missing on %d/%d"):format(pair[1],pair[2]))
    assert(sparks[#sparks].activated and loadCalls==0)
    s.tick(t+3000)
    assert(s.hides>beforeHide, ("hide missing on %d/%d"):format(pair[1],pair[2]))
    watchdogs[#watchdogs]()
    s.draw(); s.visible()
    t = t + 3200
end

-- Bounded exact-load fallback for nonresident template and cosmetic-only failure.
s.objects[sparkPath] = nil
s.first, s.second = 0, 2
local beforeBurst = #sparks
s.arm(t)
assert(#sparks==beforeBurst+1 and loadCalls==1 and s.has("ASSET_LOADED"))
s.tick(t+3000)
watchdogs[#watchdogs]()
s.draw(); s.visible()
t = t + 3200
s.loadPre(); s.loadPost()
s.objects[sparkPath] = nil
allowAssetLoad = false
beforeBurst = #sparks
local beforeHide = s.hides
s.arm(t)
assert(#sparks==beforeBurst and loadCalls==2 and s.has("MISS"))
s.tick(t+3000)
assert(s.hides>beforeHide)
s.draw(); s.visible()
s.keys[8]()
assert(not s.has("CLEANUP_PENDING"))

s = fixture({quiet=true, setup=function()
    package.loaded.vfx = nil
    local find = StaticFindObject
    StaticFindObject = function(path)
        if path == sparkPath then
            return {IsValid=function() return true end, GetFullName=function() return "ParticleSystem " .. sparkPath end}
        end
        return find(path)
    end
end})
s.arm(0)
assert(s.has("[MagicalScabbards VFX] FAILED") and s.hides == 0)
s.tick(3000)
assert(s.hides == 6 and not s.has("ERROR FAULT"))
s.keys[8](); s.visible()

-- Deferred autostart and key events both select EngineTick, never input-thread setters.
local jobs = {}
s = fixture({quiet=true, setup=function()
    ExecuteInGameThread = function(fn, method)
        assert(method == EGameThreadMethod.EngineTick)
        jobs[#jobs+1] = fn
    end
end})
assert(#s.ticks == 0 and #jobs == 1)
jobs[1](); assert(#s.ticks == 1)
s.keys[8](); assert(#jobs == 2 and s.ticks[1].live)
jobs[2](); assert(not s.ticks[1].live and not next(s.hooks))
s.keys[8](); jobs[3](); assert(#s.ticks == 2)
s.keys[8](); jobs[4]()

for _, setup in ipairs({
    function() EngineTickAvailable = false end,
    function() IsKeyBindRegistered = function() return true end end,
    function() CancelDelayedAction = nil end,
}) do
    s = fixture({quiet=true, setup=setup})
    assert(#s.ticks == 0 and not next(s.hooks) and s.keys[8] == nil)
    assert(s.has("ERROR START_FAILED") and s.hides == 0)
end
s = fixture({quiet=true, setup=function()
    RegisterHook = function() error("injected registration failure") end
end})
assert(s.has("START_FAILED") and s.has("CLEANED") and not s.has("CLEANUP_PENDING"))
s = fixture({quiet=true, setup=function()
    RegisterHook = function() return nil, nil end
end})
assert(s.has("START_FAILED") and s.has("CLEANUP_PENDING") and not s.has("CLEANED"))
s.keys[8](); assert(#s.ticks == 0 and s.has("CLEANUP_PENDING"))

-- Cancellation/unregister failure must prevent a duplicate session.
for _, setup in ipairs({
    function() CancelDelayedAction = function() return false end end,
    function() CancelDelayedAction = function() error("injected cancel failure") end end,
    function() UnregisterHook = function() return false end end,
    function() UnregisterHook = function() error("injected unregister failure") end end,
}) do
    s = fixture({quiet=true, setup=setup})
    s.arm(0); s.tick(3000); s.keys[8](); s.visible()
    assert(s.has("CLEANUP_PENDING") and not s.has("CLEANED"))
    s.keys[8](); assert(#s.ticks == 1)
    s.ticks[1].callback(); assert(s.hides == 6)
end
s = fixture({quiet=true}); s.failAfter=2
s.arm(0); s.tick(3000)
assert(s.restores == 2 and s.has("ERROR WRITE_FAILED") and s.has("RELEASED"))
s.keys[8](); assert(s.has("CLEANED") and not s.has("CLEANUP_PENDING"))
s = fixture({quiet=true}); s.arm(0); s.tick(3000)
s.targets[1].address = "replacement"
s.keys[8](); assert(s.has("ERROR CLEANUP_PENDING") and not s.has("CLEANED"))
s.keys[8](); assert(#s.ticks == 1)

-- Persistent refusal stays visible once, without one warning for each poll/retry.
s = fixture({quiet=true}); s.outgoing.bVisible=true
s.arm(0)
for t=3000,9000,100 do s.tick(t) end
local warnings = 0
for _, line in ipairs(s.logs) do if line:find("PASS_THROUGH",1,true) then warnings=warnings+1 end end
assert(warnings == 1 and s.hides == 0)
emit("PASS current runtime: autostart, toggle/restart, map reset, stale callbacks, startup/cleanup failures, quiet errors")
