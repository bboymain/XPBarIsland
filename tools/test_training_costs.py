"""Training price and row regression checks using simulated WoW Lua 5.1 APIs."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
from luaparser import ast

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
def load(path):
    source = (ROOT / path).read_text(encoding='utf-8-sig')
    ast.parse(source)
    lua.execute('local ADDON, ns = "XPBarIsland", ns\n' + source.replace('local ADDON, ns = ...', ''))

lua.execute('''
handlers = {}
ns = {On = function(e, fn) handlers[e] = fn end, MarkDirty = function() end}
UnitClass = function() return "Rogue", "ROGUE" end
GetSpellInfo = function(id) return "Spell" .. id, "Rank 1", "icon" end
XPBarIslandDB = {trainerCosts = {}}
''')
load('Data/Spells.lua')
load('Data/TrainingCosts.lua')
lua.execute('''
local classes, entries = 0, 0
for _, prices in pairs(ns.trainingCosts) do
    classes = classes + 1
    for id, entry in pairs(prices) do
        assert(type(id) == "number" and id > 0)
        assert(entry.level >= 1 and entry.level <= 60)
        assert(entry.cost >= 0 and entry.cost == math.floor(entry.cost))
        entries = entries + 1
    end
end
assert(classes == 9 and entries > 1400)
local total = 0
for _, id in ipairs({1725, 1856, 8631, 1759}) do
    local entry = ns.trainingCosts.ROGUE[id]
    assert(entry.level == 22 and entry.cost == 4500)
    local cost, source = ns.TrainingCost({id = id, name = "test"})
    assert(cost == 4500 and source == "bundled")
    total = total + cost
end
assert(total == 18000)
assert(ns.trainingCosts.MAGE[116].cost == 100)
assert(ns.trainingCosts.WARRIOR[100].cost == 100)
-- Isolate the synthetic cache/unknown/layout cases from shipped prices.
ns.trainingCosts = {ROGUE = {}}
for _, spell in ipairs(ns.SpellsForLevel(22)) do
    ns.trainingCosts.ROGUE[spell.id] = {level = 22}
end
''')
lua.execute('''
spells = ns.SpellsForLevel(22)
assert(#spells > 1 and spells[1].level == 22 and spells[1].rank == "Rank 1")
assert(ns.TrainingCost(spells[1]) == nil)
assert(ns.TrainingTotal(spells) == "~" .. ns.TrainingMoney(0) .. "+")
ns.trainingCosts.ROGUE[spells[1].id].cost = 100
assert(ns.TrainingCost(spells[1]) == 100)
GetNumTrainerServices = function() return #spells + 3 end
GetTrainerServiceInfo = function(i)
    if i == #spells + 1 then return "Profession", "", "header" end
    if i == #spells + 2 then return "Extra class spell", "Rank 2", "unavailable" end
    if i == #spells + 3 then return spells[1].name, "Rank 2", "available" end
    return spells[i].name, spells[i].rank, "unavailable"
end
GetTrainerServiceLevelReq = function() return 22 end
GetTrainerServiceCost = function(i) return i * 100 end
IsTradeskillTrainer = function() return true end
handlers.TRAINER_SHOW(); assert(next(XPBarIslandDB.trainerCosts) == nil)
IsTradeskillTrainer = function() return false end
GetTrainerServiceCost = nil
handlers.TRAINER_UPDATE(); assert(next(XPBarIslandDB.trainerCosts) == nil)
GetTrainerServiceCost = function(i) return i == 1 and 0 or i * 100 end
handlers.TRAINER_SHOW()
assert(ns.TrainingCost(spells[1]) == 0, "free cached price beats built-in")
assert(XPBarIslandDB.trainerCosts.ROGUE["Extra class spell\\tRank 2"] > 0)
local sum = 0
for _, s in ipairs(spells) do sum = sum + ns.TrainingCost(s) end
local total, unknown = ns.TrainingTotal(spells)
assert(not unknown and total == ns.TrainingMoney(sum))
savedTotal = total
local id = spells[2].id
XPBarIslandDB.trainerCosts.ROGUE[id] = nil
XPBarIslandDB.trainerCosts.ROGUE[spells[2].name .. "\\t" .. spells[2].rank] = nil
assert(ns.TrainingCost(spells[2]) == nil)
assert(select(2, ns.TrainingTotal(spells)))
XPBarIslandDB.trainerCosts.ROGUE[id] = 200
-- An unrelated trainer cannot overwrite the class cache.
GetTrainerServiceInfo = function() return "Riding", "", "available" end
GetTrainerServiceCost = function() return 99999 end
handlers.TRAINER_UPDATE(); assert(ns.TrainingCost(spells[1]) == 0)
-- Invalid prices never become totals.
XPBarIslandDB.trainerCosts.ROGUE[id] = -1
assert(ns.TrainingCost(spells[2]) == nil)
XPBarIslandDB.trainerCosts.ROGUE[id] = 200
GetCoinTextureString = function(n) return tostring(n) .. " coins" end
assert(ns.TrainingMoney(200) == "200 coins" and ns.TrainingMoney(nil) == "?")
GetCoinTextureString = nil
local fallback = ns.TrainingMoney(12345)
assert(fallback:find("1|TInterface", 1, true) and fallback:find("UI-GoldIcon", 1, true))
assert(fallback:find("23|TInterface", 1, true) and fallback:find("UI-SilverIcon", 1, true))
assert(fallback:find("45|TInterface", 1, true) and fallback:find("UI-CopperIcon", 1, true))
assert(not ns.TrainingMoney(4500):find("UI-GoldIcon", 1, true))
assert(ns.TrainingMoney(0):find("0|TInterface", 1, true))
GetCoinTextureString = function() return "" end
assert(ns.TrainingMoney(12345) == fallback)
GetCoinTextureString = function() error("unavailable") end
assert(ns.TrainingMoney(12345) == fallback)
GetCoinTextureString = nil

-- Minimal frame objects retain text, widths and tooltip hooks for row checks.
local methods = {}
function methods:SetText(t) self.value = t end
function methods:GetText() return self.value end
function methods:GetStringWidth()
    local value = self.value or ""
    local plain, icons = value:gsub("|T.-|t", "")
    return #plain * 6 + icons * 10
end
function methods:SetWidth(w) self.width = w end
function methods:GetWidth() return self.width end
function methods:Show() self.visible = true end
function methods:Hide() self.visible = false end
function methods:SetShown(v) self.visible = v end
function methods:SetScript(e, fn) self[e] = fn end
function methods:SetPoint(...) self.point = {...} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetStringHeight()
    return math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self.width or self:GetStringWidth()))) * 11
end
function frame()
    return setmetatable({}, {__index = function(_, k) return methods[k] or function() end end})
end
methods.CreateTexture = frame
CreateFrame = function() return frame() end
text = function() return frame() end
p, f, panel, PAD = frame(), frame(), {}, 20
ns.Paint = function() end
ns.db = {showTrainingCosts = true}
rowWidth = 460
ns.island = {TargetWidth = function() return rowWidth end}
balance = 0
GetMoney = function() return balance end
GameTooltip = {lines = {}, SetOwner = function() end, Show = function() end, Hide = function() end,
    SetText = function(self, t) self.lines = {{t}} end,
    AddLine = function(self, ...) self.lines[#self.lines+1] = {...} end}
''')
source = (ROOT / 'UI/Panel.lua').read_text()
block = source[source.index('local spellStrip ='):source.index('-- ---------------------------------------------------------------------------', source.index('local function makeSpellChip'))]
layout = source[source.index('function panel:LayoutSpells('):source.index('-- Draws the 8-cell')]
lua.execute(block + '\n' + layout + '''
local d = {spells = spells, nextSpellLevel = 22}
for _, width in ipairs({320, 460, 600, 900}) do
    rowWidth = width
    local height = panel:LayoutSpells(d, 1, 0)
    assert(height >= 28)
    assert(spellTotal.visible and spellTotal.label:GetText() == "Total " .. savedTotal)
    assert(spellTotal.point[4] + spellTotal.width <= width - PAD * 2)
    for i = 1, #spells do
        local c = spellChips[i]
        assert(c.visible and c.spell == spells[i], "every spell must stay visible")
        assert(c.point[4] + c.width <= width - PAD * 2)
        assert(-c.point[5] + c.height <= height)
        if i > 1 then
            local prev = spellChips[i-1]
            assert(c.point[5] < prev.point[5] or c.point[4] >= prev.point[4] + prev.width)
        end
    end
    assert(-spellTotal.point[5] + 20 <= height)
    if width == 320 then assert(height > 28, "narrow panel must grow for all spells") end
end
-- Long names wrap, and shrinking spell lists hides previously created chips.
local firstName = spells[1].name
spells[1].name = string.rep("Long spell name ", 12)
rowWidth = 320
assert(panel:LayoutSpells(d, 1, 0) > 60)
assert(spellChips[1].visible and spellChips[1].height > 26)
spells[1].name = firstName
panel:LayoutSpells({spells = {spells[1]}, nextSpellLevel = 22}, 1, 0)
assert(spellChips[1].visible and not spellChips[2].visible)
rowWidth = 2000; assert(panel:LayoutSpells(d, 1, 0) == 28)
local c = spellChips[2]
for _, money in ipairs({0, 200}) do
    balance = money; c:OnEnter()
    local line = GameTooltip.lines[#GameTooltip.lines]
    assert(line[1] == (money >= 200 and "You can afford this" or "Not enough money"))
    assert(line[2] == (money >= 200 and 0.12 or 1))
end
XPBarIslandDB.trainerCosts.ROGUE[spells[2].id] = nil
-- The bundled price works without a visit, and its tooltip identifies base pricing.
ns.trainingCosts.ROGUE[spells[2].id].cost = 250
panel:LayoutSpells(d, 1, 0)
assert(c.cost:GetText() == ns.TrainingMoney(250))
c:OnEnter()
assert(GameTooltip.lines[4][1] == "Base training price; trainer discounts may apply")
ns.trainingCosts.ROGUE[spells[2].id].cost = nil
panel:LayoutSpells(d, 1, 0)
assert(spellTotal.unknown and c.cost:GetText() == "?")
spellTotal:OnEnter()
assert(GameTooltip.lines[2][1] == "Visit your class trainer to update prices")
ns.db.showTrainingCosts = false
panel:LayoutSpells(d, 1, 0)
assert(not spellTotal.visible and not c.cost.visible)
c:OnEnter(); assert(#GameTooltip.lines == 3)
ns.db.showNextAbilities = false
assert(panel:LayoutSpells(d, 1, 0) == 0 and not spellStrip.visible)
''')
# Exercise the real saved-variable migration without loading theme/UI helpers.
init = (ROOT / 'Core/Init.lua').read_text()
start = init.index('ns.defaults =')
end = init.index('function ns.Set(')
lua.execute('local ns = ns\n' + init[start:end])
lua.execute('''
UnitName = function() return "Test" end
local prices = XPBarIslandDB.trainerCosts
XPBarIslandDB.profile = nil
ns.InitDB()
assert(XPBarIslandDB.trainerCosts == prices)
assert(ns.db.showTrainingCosts and ns.db.showNextAbilities)
ns.db.showTrainingCosts = false
ns.InitDB()
assert(not ns.db.showTrainingCosts and XPBarIslandDB.trainerCosts == prices)
''')
for path in ('Core/Init.lua', 'Settings/Settings.lua'):
    ast.parse((ROOT / path).read_text())
print('PASS: trainer guards/cache/ranks, fallback/free/unknown costs, totals, wrapped rows/all spells/long names, tooltips, affordability, toggles, Lua syntax')

