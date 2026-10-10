local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Level-up gains: a single, borderless text line under the island.
-- Health, Mana and the strongest gained base attribute are drawn from the
-- same guarded snapshots used by the former level-up summary card.
-- ---------------------------------------------------------------------------
local islandFrame = ns.island.frame

-- UIParent prevents the island's clipped children from cutting off the line.
-- Anchoring both edges keeps the line exactly as wide as the island, including
-- while the island is resized, moved or scaled.
local line = CreateFrame("Frame", nil, UIParent)
line:SetFrameStrata("MEDIUM")
line:SetFrameLevel((islandFrame:GetFrameLevel() or 0) + 8)
if line.SetMouseClickEnabled then line:SetMouseClickEnabled(false) end
if line.SetMouseMotionEnabled then line:SetMouseMotionEnabled(false) end
line:EnableMouse(false)
ns.island:RegisterUnderLine("stats", line, 30)

-- Only the decoration moves 6px on entrance. The 30px stack slot remains
-- fixed, so its animation never pushes another announcement into this line.
local visual = CreateFrame("Frame", nil, line)
visual:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
visual:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)

local textGroup = CreateFrame("Frame", nil, visual)
textGroup:SetSize(1, 24)
textGroup:SetPoint("CENTER", line, "CENTER", 0, 0)

local leftRule = visual:CreateTexture(nil, "ARTWORK")
leftRule:SetTexture(ns.Media.white)
leftRule:SetHeight(1)
leftRule:SetPoint("LEFT", visual, "LEFT", 0, 0)
leftRule:SetPoint("RIGHT", textGroup, "LEFT", -16, 0)

local rightRule = visual:CreateTexture(nil, "ARTWORK")
rightRule:SetTexture(ns.Media.white)
rightRule:SetHeight(1)
rightRule:SetPoint("LEFT", textGroup, "RIGHT", 16, 0)
rightRule:SetPoint("RIGHT", visual, "RIGHT", 0, 0)

local LABEL_COLOR = ns.HexA("#B8B0A0")
local STAT_GAP = 26
local PART_GAP = 7
local MIN_RULE = 12
local parts = {}
local shownEntries

local function getPart(index)
    if parts[index] then return parts[index] end
    local part = {}
    for _, spec in ipairs({
        { key = "label", weight = "medium" },
        { key = "total", weight = "bold" },
        { key = "gain", weight = "bold" },
    }) do
        local fs = textGroup:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        part[spec.key] = fs
    end
    parts[index] = part
    return part
end

local function styleFont(fs, weight)
    ns.StyleText(fs, 16, weight)
    -- StyleText deliberately removes the outline used nowhere else in the UI.
    -- Add it locally so the floating line remains legible on world backgrounds.
    local font, size = fs:GetFont()
    if not (font and size and pcall(fs.SetFont, fs, font, size, "OUTLINE")) then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
end

local function fitText()
    local maxWidth = math.max(1, (line:GetWidth() or islandFrame:GetWidth() or 460) - 2 * (16 + MIN_RULE))
    local natural = textGroup:GetWidth() or 1
    textGroup:SetScale(math.min(1, maxWidth / math.max(1, natural)))
end

local function drawEntries(entries)
    shownEntries = entries
    local th = ns.Theme()
    local ring = ns.HexA(th.ring)
    local gold = ns.HexA(th.gold) -- includes the optional custom text accent
    ns.Gradient(leftRule, { ring[1], ring[2], ring[3], 0 },
        { ring[1], ring[2], ring[3], 1 }, true)
    ns.Gradient(rightRule, { ring[1], ring[2], ring[3], 1 },
        { ring[1], ring[2], ring[3], 0 }, true)

    local x = 0
    for i, entry in ipairs(entries) do
        if i > 1 then x = x + STAT_GAP end
        local part = getPart(i)
        local specs = {
            { fs = part.label, value = entry.label, weight = "medium", color = LABEL_COLOR },
            { fs = part.total, value = entry.total, weight = "bold", color = { 1, 1, 1 } },
            { fs = part.gain, value = entry.gain, weight = "bold", color = gold },
        }
        for j, spec in ipairs(specs) do
            if j > 1 then x = x + PART_GAP end
            local fs = spec.fs
            styleFont(fs, spec.weight)
            fs:SetText(spec.value)
            fs:SetTextColor(spec.color[1], spec.color[2], spec.color[3], 1)
            fs:SetWidth(1000) -- measure the entire string without wrapping
            local width = math.ceil(fs:GetStringWidth() or 0) + 2
            fs:SetWidth(width)
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", textGroup, "LEFT", x, 0)
            fs:Show()
            x = x + width
        end
    end
    for i = #entries + 1, #parts do
        parts[i].label:Hide()
        parts[i].total:Hide()
        parts[i].gain:Hide()
    end
    textGroup:SetWidth(math.max(1, x))
    fitText()
end

-- Slide the art inside its reserved stack slot; never move the slot itself.
local function position(y)
    visual:ClearAllPoints()
    visual:SetPoint("TOPLEFT", line, "TOPLEFT", 0, y)
    visual:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, y)
end

local delayTimer, holdTimer, tween
local function stop()
    if delayTimer then ns.CancelTimer(delayTimer); delayTimer = nil end
    if holdTimer then ns.CancelTimer(holdTimer); holdTimer = nil end
    if tween then ns.KillTween(tween); tween = nil end
    ns.island:SetUnderLineVisible("stats", false)
    line:SetAlpha(1)
    position(0)
end

local function enabled()
    return ns.db and ns.db.enabled and ns.db.levelUpFx ~= false
        and ns.db.levelUpSummary ~= false
end

local function present(entries)
    stop()
    if not enabled() or #entries == 0 then return end
    -- Reserve the first slot as the Supernova begins. Other visible lines have
    -- 0.4s to spring downward before the stats start fading into view.
    line:SetAlpha(0)
    ns.island:SetUnderLineVisible("stats", true)

    -- Supernova begins in the same PLAYER_LEVEL_UP event; the stat line enters
    -- 0.4s later, holds for 2.7s after its entrance and fades out in 0.5s.
    delayTimer = ns.After(0.4, function()
        delayTimer = nil
        if not enabled() or not islandFrame:IsShown()
            or (islandFrame:GetAlpha() or 1) < 0.1 then
            stop()
            return
        end

        drawEntries(entries)
        line:SetAlpha(0)
        position(6)
        local animate = ns.db.animations ~= "Off"
        if animate then
            tween = ns.Tween({
                dur = 0.4, from = 0, to = 1, ease = ns.easeOutCubic,
                set = function(v, p)
                    line:SetAlpha(v)
                    position(6 - 6 * p)
                end,
                done = function() tween = nil; line:SetAlpha(1); position(0) end,
            })
        else
            line:SetAlpha(1)
            position(0)
        end

        holdTimer = ns.After(3.1, function()
            holdTimer = nil
            if not animate then stop(); return end
            if tween then ns.KillTween(tween); tween = nil end
            tween = ns.Tween({
                dur = 0.5, from = line:GetAlpha() or 1, to = 0,
                ease = ns.easeOutCubic,
                set = function(v) line:SetAlpha(v) end,
                done = function() tween = nil; ns.island:SetUnderLineVisible("stats", false) end,
            })
        end)
    end)
end

line:SetScript("OnSizeChanged", function() fitText() end)
ns.OnUpdateLayout(function()
    if not enabled() then
        stop()
    elseif shownEntries and line:IsShown() then
        -- Follow live theme, font and custom-accent changes during the effect.
        drawEntries(shownEntries)
    end
end)

-- ---- snapshot / gain reading (same APIs and secret-value guards) ----------
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }

local function plainNumber(v)
    if type(v) ~= "number" then return nil end
    local isSecret = _G.issecretvalue
    if isSecret and isSecret(v) then return nil end
    return v
end

local function readStats()
    local t = { stats = {} }
    t.health = plainNumber(UnitHealthMax("player"))
    t.mana = plainNumber(UnitPowerMax and UnitPowerMax("player", 0))
    for i = 1, 5 do
        t.stats[i] = plainNumber(UnitStat and UnitStat("player", i))
    end
    return t
end

local baseline
local function updateBaseline(cur)
    local snap = { stats = {} }
    snap.health = cur.health or (baseline and baseline.health)
    snap.mana = cur.mana or (baseline and baseline.mana)
    for i = 1, 5 do
        snap.stats[i] = cur.stats[i] or (baseline and baseline.stats[i])
    end
    baseline = snap
end

local function captureBaseline()
    updateBaseline(readStats())
end

local function buildEntries(cur, prev)
    local entries = {}
    local function addGain(label, value, gain)
        if value and gain and gain > 0 then
            entries[#entries + 1] = {
                label = label,
                total = ns.Comma(value),
                gain = "+" .. ns.Comma(gain),
            }
        end
    end
    local function delta(a, b)
        if a and b then return a - b end
        return nil
    end

    addGain("Health", cur.health, delta(cur.health, prev.health))
    if cur.mana and prev.mana and cur.mana > 0 and prev.mana > 0 then
        addGain("Mana", cur.mana, cur.mana - prev.mana)
    end

    -- All five base attributes are still sampled. Pick the largest positive
    -- attribute increase as the optional third stat so the line stays compact.
    local bestStat, bestGain
    for i = 1, 5 do
        local gain = delta(cur.stats[i], prev.stats[i])
        if gain and gain > 0 and (not bestGain or gain > bestGain) then
            bestStat, bestGain = i, gain
        end
    end
    if bestStat then addGain(STAT_NAMES[bestStat], cur.stats[bestStat], bestGain) end
    return entries
end

local function onLevelUp()
    if not (ns.db and ns.db.enabled) then return end
    local cur = readStats()
    local prev = baseline
    updateBaseline(cur)
    if not enabled() or not prev then return end
    if not islandFrame:IsShown() then return end
    if (islandFrame:GetAlpha() or 1) < 0.1 then return end

    present(buildEntries(cur, prev))
end

-- Command-only preview: demonstrate the floating line without modifying
-- character levels, health, mana, attributes, or the live gain baseline.
function ns.TestLevelUpSummary()
    if not enabled() or not islandFrame:IsShown() then return false end
    local now = readStats()
    local prev = { health = now.health or 1200, mana = now.mana, stats = {} }
    local demo = { health = prev.health + 35, stats = {} }
    if prev.mana and prev.mana > 0 then demo.mana = prev.mana + 20 end
    for i = 1, 5 do
        prev.stats[i] = now.stats[i]
        demo.stats[i] = now.stats[i]
    end
    prev.stats[3] = prev.stats[3] or 100
    demo.stats[3] = prev.stats[3] + 3
    present(buildEntries(demo, prev))
    return true
end

ns.On("PLAYER_LEVEL_UP", onLevelUp)
ns.On("PLAYER_ENTERING_WORLD", captureBaseline)
ns.On("PLAYER_LOGIN", captureBaseline)
