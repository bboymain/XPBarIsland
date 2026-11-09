"""Pet provider and displayed stats with simulated WoW APIs (requires lupa)."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()


def load(name):
    lua.execute('local ADDON, ns = "XPBarIsland", ns\n' +
                (ROOT / name).read_text(encoding='utf-8-sig').replace('local ADDON, ns = ...', ''))


lua.execute('''
handlers, class, present = {}, "HUNTER", true
CreateFrame = function() return {SetScript = function() end, Hide = function() end} end
GetTime = function() return 0 end
xp, xpMax, health, healthMax, level, happiness = 250, 1000, 800, 1200, 20, 3
-- Stock Lua has no WoW secrets. Model a value that survives tonumber but
-- rejects arithmetic/comparisons, as Forever's restricted numbers do.
secret = setmetatable({}, {
    __lt = function() error("secret comparison") end,
    __le = function() error("secret comparison") end,
    __div = function() error("secret arithmetic") end,
    __sub = function() error("secret arithmetic") end,
    __concat = function() error("secret concatenation") end,
    __tostring = function() error("secret formatting") end,
})
local nativeTonumber = tonumber
tonumber = function(v, ...)
    if rawequal(v, secret) then return v end
    return nativeTonumber(v, ...)
end
issecretvalue = function(v) return rawequal(v, secret) end
UnitClass = function() return "Hunter", class end
UnitExists = function(unit) assert(unit == "pet"); return present end
UnitName = function() return "Bear" end
UnitLevel = function() return level end
UnitHealth = function() return health end
UnitHealthMax = function() return healthMax end
GetPetExperience = function() return xp, xpMax end
C_PetInfo = {GetPetHappiness = function() return happiness, 1.25, 20 end}
ns = {API = {UnitExists = UnitExists, GetPetExperience = GetPetExperience},
    On = function(event, fn) handlers[event] = fn end,
    TouchData = function() end, MarkDirty = function() end,
    Colors = {pet = {}}, Ago = function() return "now" end,
    ReportError = function(_, err) error(err) end}
''')
load('Core/Util.lua')
load('Data/PetXP.lua')
load('Data/Data.lua')
lua.execute('''
local p = ns.pet()
assert(p.available and p.hasXP and p.cur == 250 and p.max == 1000 and p.pct == 0.25)
assert(p.name == "Bear" and p.level == 20 and p.hasHealth and p.happiness == "Happy")

-- The reported failure: health must not take readable hunter XP down with it.
for _, values in ipairs({{secret, 1200}, {800, secret}, {secret, secret}}) do
    health, healthMax = values[1], values[2]
    p = ns.pet()
    assert(p.available and p.hasXP and p.pct == 0.25, "restricted health disabled pet XP")
    local d = ns.data:Build("pet")
    assert(d.name == "Pet Experience" and d.pct == 0.25 and d.stats[5].v == "--")
end
-- Secrets still have type "number" in WoW; type checks alone are insufficient.
local isSecret = issecretvalue
issecretvalue = function(v) return isSecret(v) or rawequal(v, 987654) end
health, healthMax = 987654, 987654
assert(ns.pet().hasXP and not ns.pet().hasHealth)
assert(ns.data:Build("pet").stats[5].v == "--")
issecretvalue = isSecret
health, healthMax = secret, secret
handlers.PLAYER_ENTERING_WORLD()
xp = 300; handlers.UNIT_PET_EXPERIENCE()
assert(ns.petSession.gained() == 50)
xp = secret; handlers.UNIT_PET_EXPERIENCE()
assert(ns.petSession.gained() == 50)
xp = 350; handlers.PET_XP_UPDATE()
assert(ns.petSession.gained() == 100)

-- Readable health remains the fallback for clients/pets without XP.
health, healthMax = 800, 1200
class, xp, xpMax = "WARLOCK", 0, 0
p = ns.pet(); assert(p.available and not p.hasXP and p.cur == 800 and p.max == 1200)
local d = ns.data:Build("pet")
assert(d.stats[1].v == "800" and d.stats[5].v == "800 / 1,200")
health, healthMax = secret, secret
d = ns.data:Build("pet")
assert(d.shortLine == "Pet health unavailable" and d.stats[1].v == "--" and d.stats[2].v == "--")

class, xp, xpMax, health, healthMax = "HUNTER", 250, 1000, 800, 1200
for _, values in ipairs({{secret, 1000}, {250, secret}, {false, false}, {-1, 1000}, {0, 0}}) do
    xp, xpMax = values[1], values[2]
    p = ns.pet(); assert(p.available and not p.hasXP and p.hasHealth)
end
ns.API.GetPetExperience = nil
assert(ns.pet().available and not ns.pet().hasXP)
ns.API.GetPetExperience = function() error("API unavailable") end
assert(ns.pet().available and not ns.pet().hasXP)
ns.API.GetPetExperience = GetPetExperience
xp, xpMax = "250", "1000"
assert(ns.pet().hasXP and ns.pet().cur == 250)

-- Optional health/happiness APIs and metadata must never disable XP.
UnitHealth = function() error("health unavailable") end
UnitHealthMax = nil
level, happiness = secret, secret
UnitName = function() return secret end
p = ns.pet(); assert(p.available and p.hasXP and p.level == 0 and p.name == "Pet" and not p.happiness)
assert(ns.data:Build("pet").stats[5].v == "--")
C_PetInfo = nil
GetPetHappiness = function() return 2 end
assert(ns.pet().happiness == "Content")
GetPetHappiness = nil
assert(ns.pet().happiness == nil)

present = false
assert(not ns.pet().available and ns.pet().note == "No pet")
assert(ns.data:Build("pet").stats[2].v == "Tame or summon a pet")
present = true
assert(ns.pet().available and ns.pet().hasXP)
-- Legacy clients do not expose the secret-value API.
issecretvalue, level, health, healthMax = nil, 20, 800, 1200
UnitHealth = function() return health end
UnitHealthMax = function() return healthMax end
assert(ns.pet().available and ns.pet().hasXP and ns.pet().hasHealth)
class = "MAGE"
assert(not ns.pet().available and ns.pet().note == "No pet class")
''')
print('PASS: pet XP, restricted health/XP, displayed stats, session events, health fallback, missing APIs, happiness, dismissal/summoning')
