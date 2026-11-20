-- SPDX-License-Identifier: MPL-2.0
local emit = print
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
assert(s.has("[MagicalScabbards 0.1.1-test.1] INFO START"))
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

s = fixture({quiet=true, setup=function()
    local find = StaticFindObject
    local asset = "/Game/MainContent/Assets/fx/bp/skill/hilda/_staff/private/astral_missile_shoot.astral_missile_shoot"
    StaticFindObject = function(path)
        if path == asset then
            return {IsValid=function() return true end, GetFullName=function() return "ParticleSystem " .. asset end}
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
