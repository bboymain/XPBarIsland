local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Level-up summary: a small card under the island listing what the new level
-- brought - health, mana and attribute gains, the talent point and any spells
-- waiting at the trainer.  Created once and reused; fades out on its own.
-- Every stat is read with a guarded fallback so a missing API only drops a
-- row, never the whole card.
-- ---------------------------------------------------------------------------
local islandFrame = ns.island.frame

local card = CreateFrame("Frame", nil, UIParent)
card:SetSize(280, 120)
card:SetFrameStrata("MEDIUM")
if card.SetMouseClickEnabled then card:SetMouseClickEnabled(false) end
if card.SetMouseMotionEnabled then card:SetMouseMotionEnabled(false) end
if card.EnableMouse then card:EnableMouse(false) end
card:SetPoint("TOP", islandFrame, "BOTTOM", 0, -10)
card:Hide()

card.bg = card:CreateTexture(nil, "BACKGROUND", nil, 0)
card.bg:SetAllPoints(card)
card.border = {}
for i = 1, 4 do
    local t = card:CreateTexture(nil, "BORDER", nil, 1)
    t:SetTexture(ns.Media.white)
    card.border[i] = t
end
local function layoutBorder()
    local b = card.border
    b[1]:ClearAllPoints(); b[1]:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0); b[1]:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0); b[1]:SetHeight(2)
    b[2]:ClearAllPoints(); b[2]:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0); b[2]:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0); b[2]:SetHeight(2)
    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(2)
    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(2)
end
layoutBorder()

card.title = card:CreateFontString(nil, "OVERLAY")
ns.StyleText(card.title, 15, "extrabold")
card.title:SetPoint("TOP", card, "TOP", 0, -7)

local rows = {}
local function getRow(i)
    local r = rows[i]
    if not r then
        r = {}
        r.label = card:CreateFontString(nil, "OVERLAY")
        ns.StyleText(r.label, 12, "medium")
        r.label:SetJustifyH("LEFT")
        r.value = card:CreateFontString(nil, "OVERLAY")
        ns.StyleText(r.value, 12, "bold")
        r.value:SetJustifyH("RIGHT")
        rows[i] = r
    end
    return r
end

local function applyTheme()
    local th = ns.Theme()
    local gold = ns.HexA(th and th.gold or "#FFD100")
    ns.Paint(card.bg, 0.051, 0.043, 0.031, 0.92)
    for i = 1, 4 do ns.Paint(card.border[i], gold[1], gold[2], gold[3], 1) end
    card.title:SetTextColor(gold[1], gold[2], gold[3], 1)
    return gold
end

local tween, hideTimer
local HOLD = 9

local function stop()
    if tween then ns.KillTween(tween); tween = nil end
    if hideTimer then ns.CancelTimer(hideTimer); hideTimer = nil end
end

local function fill(level, entries)
    local gold = applyTheme()
    card.title:SetText("Level " .. level .. "!")
    local y = -30
    for i = 1, #entries do
        local e = entries[i]
        local r = getRow(i)
        r.label:ClearAllPoints()
        r.label:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
        r.label:SetText(e.label)
        if e.special then
            r.label:SetTextColor(gold[1], gold[2], gold[3], 1)
            r.value:SetText("")
        else
            r.label:SetTextColor(0.93, 0.90, 0.85, 1)
            r.value:ClearAllPoints()
            r.value:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, y)
            r.value:SetText(e.value)
            r.value:SetTextColor(1, 1, 1, 1)
        end
        r.label:Show()
        r.value:Show()
        y = y - 17
    end
    for i = #entries + 1, #rows do
        rows[i].label:Hide()
        rows[i].value:Hide()
    end
    card:SetHeight(34 + #entries * 17 + 8)
    layoutBorder()
end

local function present(level, entries)
    stop()
    fill(level, entries)
    card:Show()
    local animate = ns.db and ns.db.animations ~= "Off"
    if not animate then
        card:SetAlpha(1)
    else
        card:SetAlpha(0)
        tween = ns.Tween({
            dur = 0.3, from = 0, to = 1, ease = ns.easeOutCubic,
            set = function(v) card:SetAlpha(v) end,
            done = function() tween = nil end,
        })
    end
    hideTimer = ns.After(HOLD + 0.3, function()
        hideTimer = nil
        if not animate then card:Hide(); return end
        if tween then ns.KillTween(tween) end
        tween = ns.Tween({
            dur = 0.4, from = card:GetAlpha() or 1, to = 0, ease = ns.easeOutCubic,
            set = function(v) card:SetAlpha(v) end,
            done = function() tween = nil; card:Hide() end,
        })
    end)
end

-- ---- snapshot / gain reading ----------------------------------------------
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }

local function readStats()
    local t = { stats = {} }
    t.health = UnitHealthMax("player") or 0
    t.mana = (UnitPowerMax and UnitPowerMax("player", 0)) or 0
    for i = 1, 5 do
        t.stats[i] = (UnitStat and UnitStat("player", i)) or 0
    end
    return t
end

local baseline

local function captureBaseline()
    baseline = readStats()
end

local function buildEntries(level, cur, prev)
    local entries = {}
    local function addGain(label, value, gain)
        if gain and gain > 0 then
            entries[#entries + 1] = {
                label = label,
                value = ns.Comma(value) .. "  |cff7BE8C3+" .. ns.Comma(gain) .. "|r",
            }
        end
    end
    addGain("Health", cur.health, cur.health - prev.health)
    if cur.mana > 0 and prev.mana > 0 then
        addGain("Mana", cur.mana, cur.mana - prev.mana)
    end
    for i = 1, 5 do
        addGain(STAT_NAMES[i], cur.stats[i], cur.stats[i] - prev.stats[i])
    end

    if level >= 10 then
        entries[#entries + 1] = { label = "1 Talent Point is now available", special = true }
    end
    if ns.SpellsForLevel then
        local n = #ns.SpellsForLevel(level)
        if n > 0 then
            entries[#entries + 1] = {
                label = n .. (n == 1 and " new spell" or " new spells") .. " - visit your trainer",
                special = true,
            }
        end
    end
    return entries
end

local function onLevelUp(level)
    if not (ns.db and ns.db.enabled) then return end
    if type(level) ~= "number" then level = UnitLevel("player") or 0 end

    local cur = readStats()
    local prev = baseline
    baseline = cur
    if ns.db.levelUpSummary == false then return end
    if not prev then return end
    if not islandFrame:IsShown() then return end
    if (islandFrame:GetAlpha() or 1) < 0.1 then return end

    local entries = buildEntries(level, cur, prev)
    if #entries > 0 then present(level, entries) end
end

ns.On("PLAYER_LEVEL_UP", function(_, level) onLevelUp(level) end)
ns.On("PLAYER_ENTERING_WORLD", captureBaseline)
ns.On("PLAYER_LOGIN", captureBaseline)
