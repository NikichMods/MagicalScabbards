-- SPDX-License-Identifier: MPL-2.0
local new = dofile("Scripts/reconcile.lua")
local PASS, HIDE = "PASS-THROUGH", "SUPPRESSED"
local function stowed(identity) return {phase = "STOWED", identity = identity} end
local a, b = stowed("pawn1/cudgel/staff"), stowed("pawn1/staff/dual-main+off")
local unknown, drawn, drawing = {phase="UNKNOWN"}, {phase="DRAWN"}, {phase="DRAWING"}
local controller
local checks = 0
local function step(t, snapshot, expected, fresh)
    assert(controller.observe(snapshot, t, function() return fresh or snapshot end) == expected,
        ("unexpected decision at %s for %s"):format(t, snapshot.identity or snapshot.phase))
    checks = checks + 1
end
local function start()
    controller = new(250)
end
local function accumulate(snapshot, origin)
    for t = origin, origin + 2900, 100 do step(t, snapshot, PASS) end
    step(origin + 2999, snapshot, PASS)
end

start()
accumulate(a, 0)
step(3000, a, HIDE)
step(3100, drawing, PASS)
accumulate(a, 3200)
step(6200, a, HIDE)

-- Missing offhand, a visible outgoing held mesh or an incomplete registry
-- are UNKNOWN inputs. An old actor retained only in memory does not change the key.
for _, interruption in ipairs({unknown, drawn, drawing, b, stowed("new-pawn/cudgel/staff")}) do
    for _, at in ipairs({1, 1500, 2999}) do
        start()
        for t = 0, at - 1, 100 do step(t, a, PASS) end
        step(at, interruption, PASS)
        accumulate(a, at + 1)
        step(at + 3001, a, HIDE)
    end
end

-- No event history is supplied for menu, button or combo transitions.
start()
accumulate(a, 0)
step(3000, a, PASS, drawing)
accumulate(b, 3100)
step(6100, b, HIDE)
step(6200, b, PASS, a)
accumulate(b, 6300)
step(9300, b, HIDE)

-- A generic pre-event invalidates the window even if no draw ensues.
controller.reset()
accumulate(b, 9400)
step(12400, b, HIDE)
controller.reset() -- STOP/reload; the caller must suppress old callbacks.
step(12500, b, PASS)

-- A missed observation or a clock jump cannot complete a window.
start()
accumulate(a, 0)
step(4000, a, PASS)
step(3990, a, PASS)
step(4000, a, PASS)
step(math.huge, a, PASS)
step(4010, a, PASS)
step(4100, {phase="STOWED", identity=""}, PASS)

-- Unsupported/empty kits and new pickups are supplied as independent snapshots.
start()
for t = 0, 4000, 100 do step(t, unknown, PASS) end
accumulate(a, 4100)
step(7100, a, HIDE)
print(("PASS %s reconciliation assertions (%s)"):format(checks, _VERSION))
