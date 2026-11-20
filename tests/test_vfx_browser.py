# SPDX-License-Identifier: MPL-2.0
"""Offline Lua 5.4 syntax and deterministic catalogue policy for VFX viewer.
Does not claim the UMG/particle host actually works in Steam 1.09.
"""
from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "research" / "vfx-browser-01" / "Scripts"
lua = LuaRuntime(unpack_returned_tuples=True)

# Compile only: the host-bound main script must not run outside UE4SS.
for file in (BASE / "main.lua", BASE / "catalog.lua"):
    result = lua.globals().load(file.read_text(encoding="utf-8"), f"@{file.name}")
    if isinstance(result, tuple):
        raise AssertionError(f"Lua 5.4 compile failure for {file.name}: {result!r}")
    assert callable(result), f"no callable Lua chunk: {file.name}"

# Navigation has three required keys; scale, time-rate and cutoff are independent optional controls.
main_text = (BASE / "main.lua").read_text(encoding="utf-8")
assert 'local KEYS = {{Key.F6,"PREVIOUS"},{Key.F7,"NEXT"},{Key.F9,"REPLAY"}}' in main_text
assert 'action=="NEXT" and 1 or action=="PREVIOUS" and -1 or 0' in main_text
assert "selectCandidate(pair[2])" in main_text
assert "RegisterKeyBind(pair[1]" in main_text
assert "IsKeyBindRegistered(pair[1])" in main_text
assert "preview(step,scaleDelta)" in main_text
assert "ModifierKey." not in main_text
assert 'local TIME_RATES = {0.2,0.3,0.5}' in main_text
assert 'local timeRateIndex = 2' in main_text
assert 'c.CustomTimeDilation=rate' in main_text
assert 'math.abs(c.CustomTimeDilation-rate)' in main_text
assert 'cutoffMs=isStaff and cutoffMsStaff or 1600' in main_text
assert 'local CUTOFF_MIN_MS, CUTOFF_MAX_MS, CUTOFF_STEP_MS = 250, 3000, 250' in main_text
assert 'local cutoffMsStaff = 1000' in main_text
assert 'RegisterKeyBind(Key.F10' in main_text and 'RegisterKeyBind(Key.F11' in main_text
assert 'CUTOFF_UNAVAILABLE' in main_text and 'CUTOFF_SET' in main_text
assert 'RegisterKeyBind(Key.F4' in main_text
# A zero step in preview must preserve the currently selected index for replay.
assert "elseif step~=0 then" in main_text
assert "selected=((selected-1+step) % #entries)+1" in main_text

catalog = lua.execute((BASE / "catalog.lua").read_text(encoding="utf-8"))
build = catalog["build"]

def rows(values=(), limit=20):
    return build(lua.table_from(list(values)), limit)

a = rows()
assert len(a) == 6, len(a)
assert len(set(a[i]["path"] for i in range(1, len(a) + 1))) == 6
assert "throw_spark_astral" in a[1]["path"]
assert "astral_missile_shoot" in a[6]["path"]
assert all(a[i]["origin"] != "loaded" for i in range(1, 7))

prefix = "/Game/MainContent/Assets/fx/bp/anything/"
dyn = [f"{prefix}spark_{i:02d}.spark_{i:02d}" for i in reversed(range(30))]
dyn += [f"{prefix}spark_05.spark_05", f"{prefix}twinkle_cloud.twinkle_cloud"]
dyn += ["/Game/OtherContent/Assets/fx/spark_01.spark_01", f"{prefix}splash_splash.splash_splash"]
b = rows(dyn)
assert len(b) == 20
assert len(set(b[i]["path"] for i in range(1, 21))) == 20
assert b[7]["path"].endswith("spark_00.spark_00"), b[7]["path"]
assert b[20]["path"].endswith("spark_13.spark_13"), b[20]["path"]
assert all(b[i]["origin"] == "loaded" for i in range(7, 21))
assert not any("OtherContent" in b[i]["path"] for i in range(1, 21))

assert len(rows([], 2)) == 2
for bad in (0, 21, -1):
    try:
        rows([], bad)
        raise AssertionError(f"bad cap {bad} accepted")
    except AssertionError as e:
        if "accepted" in str(e):
            raise
    except Exception:
        pass

# Drive the installed entry point through real key callbacks with a minimal host.
lua.globals().browserCatalog = catalog
lua.execute(r"""
package.loaded.catalog=browserCatalog
Key={F2=2,F3=3,F4=4,F6=6,F7=7,F9=9,F10=10,F11=11}
EngineTickAvailable=true
EGameThreadMethod={EngineTick=1}
EObjectFlags={RF_Transient=1}
EFindName={FNAME_Find=0}
function FName(s) return {ToString=function() return s end} end
FText=FName
local function object(name, class)
    return {alive=true, IsValid=function(o) return o.alive end,
        GetFullName=function() return name end, GetAddress=function(o) return tostring(o) end,
        GetClass=function() return class end}
end
local function array(values)
    function values:GetArrayNum() return #self end
    return values
end
local db={}
local hud=object("HUD /World.HUD",object("Class /Game/MainContent/Template/UMG/HUD/HUDMainUMG_BP.HUDMainUMG_BP_C"))
local pawn=object("Hilda /World.Hilda",object("BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"))
pawn.bHidden=false
pawn.Mesh=object("Mesh /World.Hilda.CharacterMesh0", object("Class /Script/Engine.SkeletalMeshComponent"))
function pawn.Mesh:GetOwner() return pawn end
function pawn.Mesh:DoesSocketExist() return true end
function hud:IsInViewport() return true end
function hud:GetOwningPlayerPawn() return pawn end
function FindAllOf(class) return class=="HUDMainUMG_BP_C" and {hud} or {} end
function StaticFindObject(path) return db[path] end
function StaticConstructObject() error("UI not exercised") end
function LoadAsset() return nil,false,false end
local function api(class, method, callback)
    local path="/Script/Engine."..class..":"..method
    db[path]=setmetatable(object("Function "..path),{__call=function(_,_,...) return callback(...) end})
    db[path].GetFunctionFlags=function() return 0x400 end
    db["/Script/Engine.Default__"..class]=object(class.." CDO")
end
api("KismetSystemLibrary","IsValid",function(o) return o.alive end)
local entries=browserCatalog.build({})
for i=1,2 do
    local path=entries[i].path
    db[path]=object("ParticleSystem "..path)
    local required=object("Required module")
    required.EmitterLoops,required.EmitterDuration=1,1
    local lod=object("LOD")
    lod.bEnabled,lod.RequiredModule=true,required
    local velocity=object("Velocity",object("Class /Script/Engine.ParticleModuleVelocity"))
    velocity.bEnabled=true
    local distribution=object("Speed",object("Class /Script/Engine.DistributionVectorParticleParameter"))
    distribution.ParameterName=FName("TestVelocity")
    velocity.StartVelocity={Distribution=distribution,MinValue=0,MaxValue=40}
    function velocity:Reflection()
        return {GetProperty=function(_,key)
            if key=="StartVelocity" then return object("StructProperty /Script/Engine.ParticleModuleVelocity:StartVelocity") end
        end}
    end
    lod.Modules=array({velocity})
    local emitter=object("Emitter")
    emitter.LODLevels=array({lod})
    db[path].Emitters=array({emitter})
end
keys, played, logs, delays={}, {}, {}, {}
api("GameplayStatics","SpawnEmitterAttached",function(asset,mesh,socket,_,_,scale)
    assert(not db["/World.Preview"] or not db["/World.Preview"].alive)
    assert(scale.X==scale.Y and scale.Y==scale.Z)
    local c=object("PSC /World.Preview",object("Class /Script/Engine.ParticleSystemComponent"))
    c.Template=asset
    c.CustomTimeDilation=1.0
    function c:GetAttachParent() return mesh end
    function c:GetAttachSocketName() return socket end
    function c:K2_DestroyComponent(component)
        assert(component==self)
        self.alive=false
    end
    function c:Activate()
        played[#played+1]={asset=asset,scale=scale.X,rate=self.CustomTimeDilation}
    end
    db["/World.Preview"]=c
    return c
end)
function ExecuteInGameThread(callback) callback() end
function ExecuteInGameThreadWithDelay(ms)
    delays[#delays+1]=ms
    return 1
end
function IsValidDelayedActionHandle() return true end
function RegisterLoadMapPreHook() end
function IsKeyBindRegistered() return false end
function RegisterKeyBind(key, callback) keys[key]=callback end
function print(line) logs[#logs+1]=line end
""")
lua.execute(main_text)
lua.execute("""
local function last() return played[#played] end
keys[7](); assert(last().scale==0.40)
local first=last().asset
keys[2](); assert(last().asset==first and last().scale==0.35)
keys[3](); assert(last().asset==first and last().scale==0.40)
for i=1,10 do keys[2]() end
assert(last().scale==0.10)
keys[7](); assert(last().asset~=first and last().scale==0.10)
local second=last().asset
assert(last().rate==0.3 and delays[#delays]==1000)
-- Cutoff is independently adjustable while keeping rate, scale, asset and selection.
keys[10](); assert(last().asset==second and last().rate==0.3 and delays[#delays]==750)
keys[10](); assert(last().asset==second and last().rate==0.3 and delays[#delays]==500)
keys[11](); assert(last().asset==second and last().rate==0.3 and delays[#delays]==750)
keys[11](); assert(last().asset==second and last().rate==0.3 and delays[#delays]==1000)
keys[4](); assert(last().asset==second and last().rate==0.5 and delays[#delays]==1000)
keys[4](); assert(last().asset==second and last().rate==0.2 and delays[#delays]==1000)
keys[4](); assert(last().asset==second and last().rate==0.3 and delays[#delays]==1000)
for i=1,12 do keys[3]() end
assert(last().asset==second and last().scale==0.60)
keys[9](); assert(last().asset==second and last().scale==0.60)
-- Lower and upper bounds; every bounded change restarts the same component.
for i=1,30 do keys[10]() end
assert(last().asset==second and delays[#delays]==250)
keys[9](); assert(last().asset==second and delays[#delays]==250)
for i=1,30 do keys[11]() end
assert(last().asset==second and delays[#delays]==3000)
keys[9](); assert(last().asset==second and delays[#delays]==3000)
keys[6](); assert(last().asset==first and last().scale==0.60)
assert(delays[#delays]==1600 and last().rate==1.0)
-- Controls must not mutate the selected non-Staff candidate, or the staff setting.
local oldPlayCount=#played
keys[10](); keys[11]()
assert(#played==oldPlayCount and delays[#delays]==1600)
keys[7](); assert(last().asset==second and delays[#delays]==3000)
assert(table.concat(logs):find("scale=0.60",1,true))
assert(table.concat(logs):find("TIME_SET",1,true))
assert(table.concat(logs):find("rate=0.3 cutoff_ms=1000",1,true))
assert(table.concat(logs):find("CUTOFF_SET",1,true))
assert(table.concat(logs):find("cutoff_ms=250",1,true))
assert(table.concat(logs):find("cutoff_ms=3000",1,true))
local text=table.concat(logs)
assert(text:find("field=StartVelocity",1,true) and text:find("parameter=TestVelocity",1,true))
local _,inspections=text:gsub("STAFF_INSPECT_DONE","")
assert(inspections==1)
""")
lua.execute("keys,logs={},{}; function IsKeyBindRegistered(key) return key==3 end")
lua.execute(main_text)
lua.execute("""
assert(keys[6] and keys[7] and keys[9] and keys[4] and keys[10] and keys[11]
    and not keys[2] and not keys[3])
assert(table.concat(logs):find("SCALE_UNAVAILABLE",1,true))
""")
lua.execute("keys,logs={},{}; function IsKeyBindRegistered(key) return key==11 end")
lua.execute(main_text)
lua.execute("""
assert(keys[6] and keys[7] and keys[9] and keys[2] and keys[3] and keys[4]
    and not keys[10] and not keys[11])
assert(table.concat(logs):find("CUTOFF_UNAVAILABLE",1,true))
""")
print("VFX_BROWSER_POLICY_PASS: Lua syntax, catalog, navigation, staff time-rates and adjustable cutoff with boundary and collision checks")
