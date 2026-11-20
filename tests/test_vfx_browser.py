# SPDX-License-Identifier: MPL-2.0
"""Offline Lua 5.4 syntax and deterministic catalogue policy for VFX viewer.
Does not claim the UMG/particle host actually works in Steam 1.09.
"""
from pathlib import Path
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "research" / "vfx-browser-01" / "Scripts"
lua = LuaRuntime(unpack_returned_tuples=True)

# Compile only: the host-bound main script must not run outside UE4SS.
for file in (BASE / "main.lua", BASE / "catalog.lua"):
    result = lua.globals().load(file.read_text(encoding="utf-8"), f"@{file.name}")
    if isinstance(result, tuple):
        raise AssertionError(f"Lua 5.4 compile failure for {file.name}: {result!r}")
    assert callable(result), f"no callable Lua chunk: {file.name}"

main_text = (BASE / "main.lua").read_text(encoding="utf-8")
assert "ModifierKey." not in main_text

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
Key={F2=2,F3=3,F4=4,F9=9,NUM_ONE=97,NUM_TWO=98,NUM_THREE=99,NUM_FOUR=100,
    NUM_SIX=102,NUM_SEVEN=103,NUM_EIGHT=104,NUM_NINE=105}
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
catalogEntries=browserCatalog.build({})
for i=1,2 do
    local path=catalogEntries[i].path
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
sharedSettings, sharedCount=nil,0
ModRef={}
function ModRef:SetSharedVariable(key, value)
    assert(key=="NikichMods.MagicalScabbards.StaffSpark.v1")
    sharedSettings,sharedCount=value,sharedCount+1
end
function ModRef:GetSharedVariable(key)
    assert(key=="NikichMods.MagicalScabbards.StaffSpark.v1")
    return sharedSettings
end
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
function RegisterLoadMapPreHook(callback) loadMap=callback end
function IsKeyBindRegistered() return false end
function RegisterKeyBind(key, callback) keys[key]=callback end
function print(line) logs[#logs+1]=line end
""")
lua.execute(main_text)
lua.execute("""
local function last() return played[#played] end
local function press(key) keys[Key[key]]() end
press("NUM_SIX"); press("F9"); assert(#played==0)
press("F4")
local second=last().asset
assert(second:GetFullName()=="ParticleSystem "..catalogEntries[2].path)
assert(last().scale==0.60 and last().rate==0.5 and delays[#delays]==1500)
assert(sharedCount==0)
press("NUM_ONE")
assert(last().asset==second and last().rate==0.5 and delays[#delays]==1250)
assert(sharedSettings=="60:5:1250")
press("NUM_THREE"); assert(delays[#delays]==1500)
press("NUM_SEVEN"); assert(last().rate==0.3 and delays[#delays]==1500)
press("NUM_SEVEN"); assert(last().rate==0.2 and delays[#delays]==1500)
press("NUM_SEVEN"); assert(last().rate==0.2)
press("NUM_NINE"); assert(last().rate==0.3)
press("NUM_NINE"); assert(last().rate==0.5)
press("NUM_NINE"); assert(last().rate==0.5)
press("F2"); assert(last().scale==0.55 and sharedSettings=="55:5:1500")
for i=1,12 do press("F3") end
assert(last().asset==second and last().scale==0.60)
press("F9"); assert(last().asset==second and last().scale==0.60)
for i=1,20 do press("NUM_ONE") end
assert(last().asset==second and delays[#delays]==250)
for i=1,20 do press("NUM_THREE") end
assert(last().asset==second and delays[#delays]==3000)
local beforeBrightness=#played
press("NUM_TWO"); press("NUM_EIGHT")
assert(#played==beforeBrightness and delays[#delays]==3000)
press("NUM_FOUR")
assert(last().asset:GetFullName()=="ParticleSystem "..catalogEntries[1].path)
assert(delays[#delays]==1600 and last().rate==1.0 and last().scale==0.50)
local beforeOther=#played
local sharedBeforeOther=sharedCount
press("NUM_ONE"); press("NUM_THREE"); press("NUM_SEVEN"); press("NUM_NINE")
assert(#played==beforeOther)
press("F2")
assert(last().scale==0.45 and sharedCount==sharedBeforeOther)
press("NUM_SIX"); assert(last().asset==second and delays[#delays]==3000)
assert(last().scale==0.60 and sharedCount==sharedBeforeOther)
press("F4")
local beforeClosed=#played
press("NUM_SIX"); press("F9"); assert(#played==beforeClosed)
press("F4"); assert(#played==beforeClosed+1 and last().asset==second)
loadMap()
press("F9"); assert(#played==beforeClosed+1)
local text=table.concat(logs)
assert(text:find("rate=0.3 cutoff_ms=1500",1,true))
assert(text:find("BRIGHTNESS_UNAVAILABLE",1,true) and text:find("brightness unavailable",1,true))
assert(text:find("field=StartVelocity",1,true) and text:find("parameter=TestVelocity",1,true))
local _,inspections=text:gsub("STAFF_INSPECT_DONE","")
assert(inspections==1)
""")
for group, conflict, available, unavailable in [
    ("SCALE", "F3", ("F4", "F9", "NUM_ONE", "NUM_THREE"), ("F2", "F3")),
    ("CUTOFF", "NUM_THREE", ("F4", "F9", "NUM_TWO", "NUM_SIX"), ("NUM_ONE", "NUM_THREE")),
    ("TUNING", "F4", (), ("F4", "F9", "NUM_ONE", "NUM_SIX")),
]:
    lua.execute(f"keys,logs={{}},{{}}; function IsKeyBindRegistered(key) return key==Key.{conflict} end")
    lua.execute(main_text)
    for name in available:
        assert lua.eval(f"keys[Key.{name}] ~= nil"), (group, name)
    for name in unavailable:
        assert lua.eval(f"keys[Key.{name}] == nil"), (group, name)
    assert lua.eval(f'string.find(table.concat(logs), "{group}_UNAVAILABLE", 1, true)')

print("VFX_BROWSER_POLICY_PASS: Lua 5.4, catalog, tuning lifecycle, safe brightness status, rate/cutoff bounds and key collisions")
