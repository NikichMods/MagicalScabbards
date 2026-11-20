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

# Navigation has three required keys and scale adds two optional keys.
main_text = (BASE / "main.lua").read_text(encoding="utf-8")
assert 'local KEYS = {{Key.F6,"PREVIOUS"},{Key.F7,"NEXT"},{Key.F9,"REPLAY"}}' in main_text
assert 'action=="NEXT" and 1 or action=="PREVIOUS" and -1 or 0' in main_text
assert "selectCandidate(pair[2])" in main_text
assert "RegisterKeyBind(pair[1]" in main_text
assert "IsKeyBindRegistered(pair[1])" in main_text
assert "preview(step,scaleDelta)" in main_text
assert "ModifierKey." not in main_text
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
Key={F2=2,F3=3,F6=6,F7=7,F9=9}
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
    local emitter=object("Emitter")
    emitter.LODLevels=array({lod})
    db[path].Emitters=array({emitter})
end
keys, played, logs={}, {}, {}
api("GameplayStatics","SpawnEmitterAttached",function(asset,mesh,socket,_,_,scale)
    assert(not db["/World.Preview"] or not db["/World.Preview"].alive)
    assert(scale.X==scale.Y and scale.Y==scale.Z)
    local c=object("PSC /World.Preview",object("Class /Script/Engine.ParticleSystemComponent"))
    c.Template=asset
    function c:GetAttachParent() return mesh end
    function c:GetAttachSocketName() return socket end
    function c:K2_DestroyComponent(component)
        assert(component==self)
        self.alive=false
    end
    function c:Activate() played[#played+1]={asset=asset,scale=scale.X} end
    db["/World.Preview"]=c
    return c
end)
function ExecuteInGameThread(callback) callback() end
function ExecuteInGameThreadWithDelay() return 1 end
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
for i=1,12 do keys[3]() end
assert(last().asset==second and last().scale==0.60)
keys[9](); assert(last().asset==second and last().scale==0.60)
keys[6](); assert(last().asset==first and last().scale==0.60)
assert(table.concat(logs):find("scale=0.60",1,true))
""")
lua.execute("keys,logs={},{}; function IsKeyBindRegistered(key) return key==3 end")
lua.execute(main_text)
lua.execute("""
assert(keys[6] and keys[7] and keys[9] and not keys[2] and not keys[3])
assert(table.concat(logs):find("SCALE_UNAVAILABLE",1,true))
""")
print("VFX_BROWSER_POLICY_PASS: Lua syntax, catalog, navigation, bounded scale and scale key collision")
