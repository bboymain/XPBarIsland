local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Expanded panel: fading rule, type chips + gear, stat grid (or a reputation
-- faction list), session sparkline, party comparison, quest overlay and the
-- footer.
-- ---------------------------------------------------------------------------
local PAD = 18
local panel = {}
ns.panel = panel

-- math.atan2 is gone on the modern Lua the newer clients ship; math.atan(y, x)
-- is equivalent and present everywhere.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local f = ns.island.frame
local p = CreateFrame("Frame", nil, f)
p:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
p:Hide()
panel.frame = p

local function text(parent, size, hex, justify, layer, weight)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    ns.StyleText(fs, size, weight or "bold")
    if hex then fs:SetTextColor(ns.Hex(hex)) end
    if justify then fs:SetJustifyH(justify) end
    return fs
end

local function framedBox(parent, drawLayer)
    local box = CreateFrame("Frame", nil, parent)
    box.bg = box:CreateTexture(nil, drawLayer or "BACKGROUND", nil, 0)
    box.bg:SetAllPoints(box)
    box.bd = box:CreateTexture(nil, "BACKGROUND", nil, -1)
    box.bd:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
    box.bd:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
    return box
end

-- --- rule (symmetric gold fade) ------------------------------------------
local ruleL = p:CreateTexture(nil, "ARTWORK", nil, 0)
local ruleR = p:CreateTexture(nil, "ARTWORK", nil, 0)
ruleL:SetHeight(1)
ruleR:SetHeight(1)

-- --- chips ----------------------------------------------------------------
local chipRow = CreateFrame("Frame", nil, p)
chipRow:SetHeight(26)
chipRow:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, 0)
chipRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, 0)
panel.chipRow = chipRow
local chips = {}

-- Active/inactive chip styling, applied on theme change and whenever the
-- active type changes (Layout no longer calls ApplyTheme every update).
local function styleChip(c)
    local th = ns.Theme()
    c.label:SetTextColor(ns.Hex(c.active and (th.btnText or th.gold) or (th.pillOff or "#9D9D9D")))
    ns.WhiteTexture(c.bg)
    if c.active then
        ns.Gradient(c.bg, ns.HexA(th.btnPrimary1 or "#3A2C12"), ns.HexA(th.btnPrimary2 or "#1A1409"), false)
        ns.Paint(c.bd, ns.Hex(th.btnRing or th.ring))
    else
        ns.Gradient(c.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
        ns.Paint(c.bd, 0.29, 0.23, 0.11, 1)
    end
end

local function makeChip()
    local c = CreateFrame("Frame", nil, chipRow)
    c:SetHeight(26)
    c.bg = c:CreateTexture(nil, "BACKGROUND", nil, 0)
    c.bg:SetAllPoints(c)
    c.bd = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.bd:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1)
    c.bd:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
    c.label = text(c, 12, "#9D9D9D", "CENTER")
    c.label:SetPoint("CENTER", c, "CENTER", 0, 0)
    c:EnableMouse(true)
    c:SetScript("OnMouseUp", function() if c.key then ns.data:SetActive(c.key) end end)
    return c
end

local gear = CreateFrame("Frame", nil, chipRow)
gear:SetSize(26, 26)
gear.bg = gear:CreateTexture(nil, "BACKGROUND", nil, 0)
gear.bg:SetAllPoints(gear)
gear.bd = gear:CreateTexture(nil, "BACKGROUND", nil, -1)
gear.bd:SetPoint("TOPLEFT", gear, "TOPLEFT", -1, 1)
gear.bd:SetPoint("BOTTOMRIGHT", gear, "BOTTOMRIGHT", 1, -1)
gear.icon = gear:CreateTexture(nil, "ARTWORK", nil, 2)
gear.icon:SetPoint("CENTER", gear, "CENTER")
gear.icon:SetSize(16, 16)
gear.icon:SetTexture(ns.Media.gear)
gear:EnableMouse(true)
gear:SetScript("OnMouseUp", function() ns.OpenSettings() end)
gear:SetScript("OnEnter", function(self)
    if not _G.GameTooltip then return end
    _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    _G.GameTooltip:SetText("Settings", 1, 0.82, 0, 1, true)
    _G.GameTooltip:AddLine("Open the XP Bar Island options", 1, 1, 1, true)
    _G.GameTooltip:Show()
end)
gear:SetScript("OnLeave", function()
    if _G.GameTooltip then _G.GameTooltip:Hide() end
end)
panel.gear = gear

-- Pin button: keeps the island open (same toggle as left-clicking the island).
-- Hidden in the "Always open" display mode, which already pins it.
local pin = CreateFrame("Frame", nil, chipRow)
pin:SetSize(26, 26)
pin.bg = pin:CreateTexture(nil, "BACKGROUND", nil, 0)
pin.bg:SetAllPoints(pin)
pin.bd = pin:CreateTexture(nil, "BACKGROUND", nil, -1)
pin.bd:SetPoint("TOPLEFT", pin, "TOPLEFT", -1, 1)
pin.bd:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 1, -1)
pin.head = pin:CreateTexture(nil, "ARTWORK", nil, 2)
pin.head:SetTexture(ns.Media.disk)
pin.head:SetSize(10, 10)
pin.head:SetPoint("CENTER", pin, "CENTER", 0, 3)
pin.needle = pin:CreateTexture(nil, "ARTWORK", nil, 2)
pin.needle:SetTexture(ns.Media.white)
pin.needle:SetSize(2, 9)
pin.needle:SetPoint("TOP", pin.head, "BOTTOM", 0, 1)
pin:EnableMouse(true)
pin:SetScript("OnMouseUp", function() if ns.island then ns.island:TogglePin() end end)
pin:SetScript("OnEnter", function(self)
    if not _G.GameTooltip then return end
    local on = ns.island and ns.island.pinned
    _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    _G.GameTooltip:SetText(on and "Unpin" or "Pin open", 1, 0.82, 0, 1, true)
    _G.GameTooltip:AddLine(on and "Let the island close when the mouse leaves"
        or "Keep the island open until you unpin it", 1, 1, 1, true)
    _G.GameTooltip:Show()
end)
pin:SetScript("OnLeave", function()
    if _G.GameTooltip then _G.GameTooltip:Hide() end
end)
panel.pin = pin

-- Style the pin button from the current pinned state (active = pinned).
local function stylePin()
    local th = ns.Theme()
    local pinned = ns.island and ns.island.pinned
    ns.WhiteTexture(pin.bg)
    if pinned then
        ns.Gradient(pin.bg, ns.HexA(th.btnPrimary1 or "#3A2C12"), ns.HexA(th.btnPrimary2 or "#1A1409"), false)
        ns.Paint(pin.bd, ns.Hex(th.btnRing or th.ring))
    else
        ns.Gradient(pin.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
        ns.Paint(pin.bd, 0.29, 0.23, 0.11, 1)
    end
    local gold = ns.HexA(th.gold)
    pin.head:SetVertexColor(gold[1], gold[2], gold[3], 1)
    pin.needle:SetVertexColor(gold[1], gold[2], gold[3], 1)
end
panel.RefreshPin = stylePin

-- --- stat grid ------------------------------------------------------------
local grid = CreateFrame("Frame", nil, p)
panel.grid = grid
local cells = {}
for i = 1, 8 do
    local cell = CreateFrame("Frame", nil, grid)
    cell.k = text(cell, 11, "#FFD100", "LEFT")
    cell.k:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
    cell.v = text(cell, 14, "#FFFFFF", "LEFT")
    cell.v:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -15)
    cells[i] = cell
end

-- --- reputation faction list ---------------------------------------------
local repList = CreateFrame("Frame", nil, p)
panel.repList = repList
repList.rows = {}
local function makeRepRow(i)
    local r = CreateFrame("Frame", nil, repList)
    r.name = text(r, 12, "#FFD100", "LEFT")
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.standing = text(r, 11, "#9D9D9D", "LEFT", nil, "medium")
    r.standing:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.gain = text(r, 12, "#22C43C", "RIGHT")
    r.gain:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 0)
    r.track = CreateFrame("Frame", nil, r)
    r.track:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -16)
    r.track:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -16)
    r.track:SetHeight(6)
    r.trackBG = r.track:CreateTexture(nil, "BACKGROUND", nil, 0)
    r.trackBG:SetAllPoints(r.track)
    ns.Paint(r.trackBG, 0, 0, 0, 1)
    r.trackEdge = r.track:CreateTexture(nil, "BACKGROUND", nil, -1)
    r.trackEdge:SetPoint("TOPLEFT", r.track, "TOPLEFT", -1, 1)
    r.trackEdge:SetPoint("BOTTOMRIGHT", r.track, "BOTTOMRIGHT", 1, -1)
    ns.Paint(r.trackEdge, 0.29, 0.23, 0.11, 1)
    r.fill = r.track:CreateTexture(nil, "ARTWORK", nil, 0)
    r.fill:SetPoint("TOPLEFT", r.track, "TOPLEFT", 0, 0)
    r.fill:SetPoint("BOTTOMLEFT", r.track, "BOTTOMLEFT", 0, 0)
    r.fill:SetWidth(0)
    repList.rows[i] = r
    return r
end

-- --- reputation standing ladder (Hated .. Exalted) ------------------------
-- A row of the eight standing tier names; the current tier is lit and a thin
-- track underneath shows where the player sits across the whole ladder.
local repLadder = CreateFrame("Frame", nil, p)
panel.repLadder = repLadder
repLadder.labels = {}
for i = 1, (ns.repTierCount or 8) do
    local fs = text(repLadder, 10, "#8F8777", "CENTER", nil, "medium")
    fs:SetWordWrap(false)
    repLadder.labels[i] = fs
end
repLadder.track = CreateFrame("Frame", nil, repLadder)
repLadder.trackBG = repLadder.track:CreateTexture(nil, "BACKGROUND", nil, 0)
repLadder.trackBG:SetAllPoints(repLadder.track)
ns.Paint(repLadder.trackBG, 0, 0, 0, 1)
repLadder.fill = repLadder.track:CreateTexture(nil, "ARTWORK", nil, 0)
repLadder.fill:SetTexture(ns.Media.white)
repLadder.fill:SetPoint("TOPLEFT", repLadder.track, "TOPLEFT", 0, 0)
repLadder.fill:SetPoint("BOTTOMLEFT", repLadder.track, "BOTTOMLEFT", 0, 0)
repLadder.fill:SetWidth(0)
repLadder.marker = repLadder.track:CreateTexture(nil, "OVERLAY", nil, 1)
repLadder.marker:SetTexture(ns.Media.white)
repLadder.marker:SetSize(3, 7)
ns.Paint(repLadder.marker, 1, 0.82, 0, 1)
repLadder:Hide()

-- --- sparkline (Session XP graph) ----------------------------------------
local SPARK_GRAPH_H = 40
local spark = CreateFrame("Frame", nil, p)
panel.spark = spark
spark.title = text(spark, 11, "#FFD100", "LEFT")
spark.title:SetPoint("TOPLEFT", spark, "TOPLEFT", 0, 0)
spark.sub = text(spark, 11, "#9D9D9D", "RIGHT", nil, "medium")
spark.sub:SetPoint("TOPRIGHT", spark, "TOPRIGHT", 0, 0)
-- rate arrow, on the same title line just left of the session total
spark.arrow = text(spark, 11, "#7BE8C3", "RIGHT", nil, "medium")
spark.arrow:SetPoint("RIGHT", spark.sub, "LEFT", -8, 0)
spark.arrow:Hide()

spark.graph = CreateFrame("Frame", nil, spark)
spark.graph:SetPoint("TOPLEFT", spark, "TOPLEFT", 0, -16)
spark.graph:SetPoint("BOTTOMRIGHT", spark, "BOTTOMRIGHT", 0, 0)
spark.graph:EnableMouse(true)

local sparkLines = {}
local sparkAreas = {}
local sparkGuides = {}
for i = 1, 2 do
    local gl = spark.graph:CreateTexture(nil, "BACKGROUND", nil, 0)
    gl:SetTexture(ns.Media.white)
    gl:SetVertexColor(1, 1, 1, 0.05)
    gl:SetHeight(1)
    gl:Hide()
    sparkGuides[i] = gl
end

spark.empty = text(spark.graph, 11, "#8F8777", "CENTER", nil, "medium")
spark.empty:SetPoint("CENTER", spark.graph, "CENTER", 0, 0)
spark.empty:SetText("Gain some XP to see the graph")
spark.empty:Hide()

-- --- idle resting fireflies (session XP still 0) --------------------------
-- A calm flat baseline with soft gold motes drifting and fading along it,
-- like the XP sparkles that trail a rested player. Replaces the old EKG.
local idle = CreateFrame("Frame", nil, spark.graph)
idle:SetAllPoints(spark.graph)
if idle.SetClipsChildren then idle:SetClipsChildren(true) end
idle:Hide()

local idleBase = idle:CreateTexture(nil, "BACKGROUND", nil, 0)
idleBase:SetTexture(ns.Media.white)
idleBase:SetVertexColor(1, 0.82, 0, 0.12)
idleBase:SetHeight(1)
idleBase:SetPoint("BOTTOMLEFT", spark.graph, "BOTTOMLEFT", 0, 0)
idleBase:SetPoint("BOTTOMRIGHT", spark.graph, "BOTTOMRIGHT", 0, 0)

local FLY_N = 14
local flies = {}
for i = 1, FLY_N do
    local tex = idle:CreateTexture(nil, "ARTWORK", nil, 2)
    tex:SetTexture(ns.Media.idleDot)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(1, 0.85, 0.4)
    tex:Hide()
    flies[i] = {
        tex = tex,
        x0 = 0.05 + math.random() * 0.9,
        phase = math.random(),
        speed = 0.10 + math.random() * 0.14,
        drift = (math.random() < 0.5 and -1 or 1) * (0.10 + math.random() * 0.22),
        sway = 0.8 + math.random() * 1.2,
        swayAmp = 0.008 + math.random() * 0.022,
        rise = 0.30 + math.random() * 0.28,
        size = 3 + math.random() * 4,
        maxA = 0.35 + math.random() * 0.45,
    }
end

local idleLeft = text(idle, 11, "#9D9D9D", "LEFT", nil, "medium")
idleLeft:SetPoint("TOPLEFT", spark.graph, "TOPLEFT", 2, -3)
idleLeft:SetText("Waiting for XP")
local idleDots = {}
for i = 1, 3 do
    local d = text(idle, 12, "#FFD100", "LEFT", nil, "bold")
    d:SetText(".")
    d:SetPoint("LEFT", idleLeft, "RIGHT", (i - 1) * 4, 0)
    idleDots[i] = d
end
local idleRight = text(idle, 11, "#8F8777", "RIGHT", nil, "medium")
idleRight:SetWordWrap(false)
idleRight:SetPoint("TOPRIGHT", spark.graph, "TOPRIGHT", -20, -3)
idleRight:SetText("Kill, quest or explore to start the line")

panel.idle = idle
panel.idleDots = idleDots

-- live end dot: 10px black disk behind an 8px pale-gold disk
local sparkDotBG = spark.graph:CreateTexture(nil, "OVERLAY", nil, 5)
sparkDotBG:SetTexture(ns.Media.disk)
sparkDotBG:SetSize(10, 10)
sparkDotBG:SetVertexColor(0, 0, 0, 1)
sparkDotBG:Hide()
local sparkDot = spark.graph:CreateTexture(nil, "OVERLAY", nil, 6)
sparkDot:SetTexture(ns.Media.disk)
sparkDot:SetSize(8, 8)
sparkDot:SetVertexColor(1, 0.965, 0.784, 1)
sparkDot:Hide()

-- ripple ring
local sparkRing = spark.graph:CreateTexture(nil, "OVERLAY", nil, 4)
sparkRing:SetTexture(ns.Media.ring)
sparkRing:SetVertexColor(1, 0.82, 0, 1)
sparkRing:Hide()

-- best streak diamond (gold 6px over a black 8px edge, both rotated 45)
local sparkBestEdge = spark.graph:CreateTexture(nil, "OVERLAY", nil, 2)
sparkBestEdge:SetTexture(ns.Media.white)
sparkBestEdge:SetSize(8, 8)
sparkBestEdge:SetVertexColor(0, 0, 0, 1)
if sparkBestEdge.SetRotation then sparkBestEdge:SetRotation(math.rad(45)) end
sparkBestEdge:Hide()
local sparkBest = spark.graph:CreateTexture(nil, "OVERLAY", nil, 3)
sparkBest:SetTexture(ns.Media.white)
sparkBest:SetSize(6, 6)
sparkBest:SetVertexColor(1, 0.82, 0, 1)
if sparkBest.SetRotation then sparkBest:SetRotation(math.rad(45)) end
sparkBest:Hide()
local sparkBestLabel = text(spark.graph, 10, "#FFD100", "CENTER")
sparkBestLabel:Hide()

-- pooled level-up flags (a dashed 1px gold line + a label)
local sparkFlags = {}
local function makeFlag()
    local fl = {
        dashes = {},
        label = text(spark.graph, 10, "#FFD100", "CENTER"),
    }
    fl.label:Hide()
    return fl
end

local function flagDash(fl, i)
    local d = fl.dashes[i]
    if not d then
        d = spark.graph:CreateTexture(nil, "OVERLAY", nil, 1)
        d:SetTexture(ns.Media.white)
        d:SetVertexColor(1, 0.82, 0, 0.8)
        d:SetWidth(1)
        d:Hide()
        fl.dashes[i] = d
    end
    return d
end

local function hideFlag(fl)
    for i = 1, #fl.dashes do fl.dashes[i]:Hide() end
    fl.label:Hide()
end

-- hover cursor + readout box
local sparkCursor = spark.graph:CreateTexture(nil, "OVERLAY", nil, 7)
sparkCursor:SetTexture(ns.Media.white)
sparkCursor:SetVertexColor(1, 1, 1, 0.55)
sparkCursor:SetWidth(1)
sparkCursor:Hide()

local sparkTip = CreateFrame("Frame", nil, spark.graph)
sparkTip:SetFrameLevel((spark.graph:GetFrameLevel() or 0) + 5)
sparkTip:SetHeight(16)
sparkTip.bg = sparkTip:CreateTexture(nil, "BACKGROUND", nil, 0)
ns.Paint(sparkTip.bg, 0.051, 0.043, 0.031, 1)
sparkTip.bd = sparkTip:CreateTexture(nil, "BACKGROUND", nil, -1)
sparkTip.bd:SetPoint("TOPLEFT", sparkTip, "TOPLEFT", -1, 1)
sparkTip.bd:SetPoint("BOTTOMRIGHT", sparkTip, "BOTTOMRIGHT", 1, -1)
ns.Paint(sparkTip.bd, 0.29, 0.227, 0.11, 1)
sparkTip.label = text(sparkTip, 10, "#FFFFFF", "CENTER")
sparkTip.label:SetPoint("CENTER", sparkTip, "CENTER", 0, 0)
sparkTip:Hide()

spark.lines, spark.areas = sparkLines, sparkAreas
spark.guides, spark.flags, spark._makeFlag = sparkGuides, sparkFlags, makeFlag
spark.dotBG, spark.dot, spark.ring = sparkDotBG, sparkDot, sparkRing
spark.best, spark.bestEdge, spark.bestLabel = sparkBest, sparkBestEdge, sparkBestLabel
spark.cursor, spark.tip = sparkCursor, sparkTip

spark.graph:SetScript("OnEnter", function()
    spark.graph:SetScript("OnUpdate", function() panel:SparkHoverUpdate() end)
end)
spark.graph:SetScript("OnLeave", function()
    spark.graph:SetScript("OnUpdate", nil)
    spark.cursor:Hide()
    spark.tip:Hide()
end)

-- --- party ----------------------------------------------------------------
local party = CreateFrame("Frame", nil, p)
panel.party = party
party.title = text(party, 11, "#FFD100", "LEFT")
party.title:SetPoint("TOPLEFT", party, "TOPLEFT", 0, 0)
party.sub = text(party, 11, "#9D9D9D", "RIGHT", nil, "medium")
party.sub:SetPoint("TOPRIGHT", party, "TOPRIGHT", 0, 0)
party.rows = {}

local function makePartyRow(i)
    local r = CreateFrame("Frame", nil, party)
    r.name = text(r, 12, "#FFFFFF", "LEFT")
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.value = text(r, 11, "#9D9D9D", "RIGHT", nil, "medium")
    r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 0)
    r.track = CreateFrame("Frame", nil, r)
    r.track:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -16)
    r.track:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -16)
    r.track:SetHeight(6)
    r.trackBG = r.track:CreateTexture(nil, "BACKGROUND", nil, 0)
    r.trackBG:SetAllPoints(r.track)
    ns.Paint(r.trackBG, 0, 0, 0, 1)
    r.trackEdge = r.track:CreateTexture(nil, "BACKGROUND", nil, -1)
    r.trackEdge:SetPoint("TOPLEFT", r.track, "TOPLEFT", -1, 1)
    r.trackEdge:SetPoint("BOTTOMRIGHT", r.track, "BOTTOMRIGHT", 1, -1)
    ns.Paint(r.trackEdge, 0.29, 0.23, 0.11, 1)
    r.fill = r.track:CreateTexture(nil, "ARTWORK", nil, 0)
    r.fill:SetPoint("TOPLEFT", r.track, "TOPLEFT", 0, 0)
    r.fill:SetPoint("BOTTOMLEFT", r.track, "BOTTOMLEFT", 0, 0)
    r.fill:SetWidth(0)
    party.rows[i] = r
    return r
end

-- --- quest overlay --------------------------------------------------------
local quest = framedBox(p)
quest:SetSize(240, 60)
-- draw the popup above the stat cells and the sparkline textures, whose child
-- frames sit a level higher than the panel (otherwise their text shows through)
quest:SetFrameLevel((p:GetFrameLevel() or 0) + 20)
quest:Hide()
quest.title = text(quest, 12, "#FFD100", "LEFT")
quest.title:SetPoint("TOPLEFT", quest, "TOPLEFT", 10, -8)
quest.rows = {}
local function makeQuestRow(i)
    local r = CreateFrame("Frame", nil, quest)
    r.name = text(r, 12, "#FFFFFF", "LEFT")
    r.name:SetPoint("LEFT", r, "LEFT", 10, 0)
    r.xp = text(r, 12, "#E0A800", "RIGHT")
    r.xp:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function()
        if r.entry then ns.questPreview = r.entry; ns.MarkDirty() end
    end)
    r:SetScript("OnLeave", function()
        ns.questPreview = nil; ns.MarkDirty()
    end)
    quest.rows[i] = r
    return r
end

local questHideTimer
local function hideQuest()
    if questHideTimer then ns.CancelTimer(questHideTimer) end
    questHideTimer = ns.After(0.2, function()
        quest:Hide()
        ns.questPreview = nil
        ns.MarkDirty()
    end)
end

local function showQuest()
    if questHideTimer then ns.CancelTimer(questHideTimer) questHideTimer = nil end
    local list = ns.quests().list or {}
    if #list == 0 then
        quest.title:SetText("No completed quests")
        for _, r in ipairs(quest.rows) do r:Hide() end
        quest:SetHeight(30)
    else
        quest.title:SetText("Completed quests (" .. #list .. ")")
        local y = 26
        for i, q in ipairs(list) do
            if i > 7 then break end
            local r = quest.rows[i] or makeQuestRow(i)
            r.entry = q
            r:SetHeight(18)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", quest, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", quest, "TOPRIGHT", 0, -y)
            r.name:SetText(q.title or "?")
            r.xp:SetText("+" .. ns.Comma(q.xp or 0))
            r:Show()
            y = y + 18
        end
        for i = #list + 1, #quest.rows do quest.rows[i]:Hide() end
        quest:SetHeight(y + 8)
    end
    quest:Show()
end

-- Turn-in cell hover (only for the XP type)
local turnInIndex = 3
for i, cell in ipairs(cells) do
    cell:EnableMouse(false)
    cell:SetScript("OnEnter", function()
        if ns.db.questList and cell.isTurnIn and ns.data:ActiveKey() == "xp" then showQuest() end
    end)
    cell:SetScript("OnLeave", function()
        if cell.isTurnIn then hideQuest() end
    end)
end
quest:EnableMouse(true)
quest:SetScript("OnEnter", function()
    if questHideTimer then ns.CancelTimer(questHideTimer) questHideTimer = nil end
end)
quest:SetScript("OnLeave", hideQuest)
panel.ShowQuest = showQuest
panel.HideQuest = hideQuest

-- --- footer ---------------------------------------------------------------
local footerLeft = text(p, 11, "#9D9D9D", "LEFT", nil, "medium")
local footerRight = text(p, 11, "#9D9D9D", "RIGHT", nil, "medium")
panel.footerLeft = footerLeft
panel.footerRight = footerRight

-- --- next-level spell row (gold Lv tag, icon chips, next reward) ----------
local spellStrip = CreateFrame("Frame", nil, p)
spellStrip:Hide()

local spellTag = CreateFrame("Frame", nil, spellStrip)
spellTag:SetHeight(20)
spellTag.bg = spellTag:CreateTexture(nil, "BACKGROUND", nil, 0)
spellTag.bg:SetAllPoints(spellTag)
ns.Paint(spellTag.bg, 0.16, 0.12, 0.04, 1)
spellTag.bd = spellTag:CreateTexture(nil, "BORDER", nil, 1)
spellTag.bd:SetPoint("TOPLEFT", spellTag, "TOPLEFT", -1, 1)
spellTag.bd:SetPoint("BOTTOMRIGHT", spellTag, "BOTTOMRIGHT", 1, -1)
spellTag.text = text(spellTag, 11, "#FFD100", "CENTER")
spellTag.text:SetPoint("CENTER", spellTag, "CENTER", 0, 0)

local spellReward = text(spellStrip, 11, "#8F8777", "RIGHT", nil, "medium")

local spellChips = {}
local spellPlus

local function makeSpellChip()
    local c = CreateFrame("Frame", nil, spellStrip)
    c:SetHeight(26)
    c.outer = c:CreateTexture(nil, "BACKGROUND", nil, 0)
    c.outer:SetSize(26, 26)
    c.outer:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    ns.Paint(c.outer, 1, 0.82, 0, 1)
    c.bd = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.bd:SetSize(24, 24)
    c.bd:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
    ns.Paint(c.bd, 0, 0, 0, 1)
    c.icon = c:CreateTexture(nil, "ARTWORK", nil, 2)
    c.icon:SetSize(22, 22)
    c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
    c.label = text(c, 11, "#ECE6D8", "LEFT", nil, "medium")
    c.label:SetPoint("LEFT", c, "LEFT", 30, 0)
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(self)
        if not (self.spell and _G.GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local ok = false
        if GameTooltip.SetSpellByID then ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spell.id) end
        if not ok then GameTooltip:SetText(self.spell.name or "Spell") end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
    spellChips[#spellChips + 1] = c
    return c
end

local function makePlusChip()
    local c = CreateFrame("Frame", nil, spellStrip)
    c:SetHeight(20)
    c.bd = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.bd:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1)
    c.bd:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
    ns.Paint(c.bd, 0.29, 0.23, 0.11, 1)
    c.label = text(c, 11, "#FFD100", "CENTER")
    c.label:SetPoint("CENTER", c, "CENTER", 0, 0)
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(self)
        if not (_G.GameTooltip and self.list) then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("More spells at this level", 1, 0.82, 0, 1, true)
        for _, s in ipairs(self.list) do GameTooltip:AddLine(s.name or "?", 1, 1, 1) end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
    spellPlus = c
    return c
end

-- ---------------------------------------------------------------------------
-- Staggered intro: the detail pieces fade in with a 6px slide, one group
-- after another.  On collapse the panel is hidden instantly.
-- ---------------------------------------------------------------------------
panel.g = { 0, 0, 0 }        -- per-group vertical offset used by Layout
panel.intro = {}
local groups = {
    { delay = 0.08, els = { ruleL, ruleR, chipRow, gear } },
    { delay = 0.16, els = { grid, repList, repLadder } },
    { delay = 0.24, els = { spark, party, footerLeft, footerRight, spellStrip } },
}
panel.groups = groups

local function setGroupAlpha(i, a)
    for _, e in ipairs(groups[i].els) do e:SetAlpha(a) end
end
panel.SetGroupAlpha = setGroupAlpha

function panel:PlayIntro()
    local ok, err = pcall(function()
        local instant = (not ns.db) or ns.db.animations == "Off"
        for i = 1, 3 do
            if self.intro[i] then ns.KillTween(self.intro[i]); self.intro[i] = nil end
            if instant then
                self.g[i] = 0
                setGroupAlpha(i, 1)
            else
                -- start hidden and 10px higher than the final position
                self.g[i] = -10
                setGroupAlpha(i, 0)
                local idx = i
                ns.After(groups[idx].delay, function()
                    self.intro[idx] = ns.Tween({
                        dur = 0.4, from = 0, to = 1, ease = ns.easeOutCubic,
                        -- `eased` is the easeOutCubic output, not the linear progress
                        set = function(eased)
                            local sok, serr = pcall(function()
                                self.g[idx] = -10 * (1 - eased)
                                setGroupAlpha(idx, eased)
                            end)
                            if not sok then ns.ReportError("panel:PlayIntro.set", serr) end
                        end,
                    })
                end)
            end
        end
        -- reveal the graph from left to right as the panel opens
        if self.DrawSpark then self:DrawSpark(ns.xp().samples, true) end
        if self.PlayPartyMotion then self:PlayPartyMotion() end
    end)
    if not ok then ns.ReportError("panel:PlayIntro", err) end
end

-- Party rows: staggered slide-in and fill ease (partyMotion), else instant.
function panel:PlaceRow(r)
    if not r._mx then return end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", party, "TOPLEFT", r._mx + (r._slide or 0), r._my)
end

function panel:PlayPartyMotion()
    local ok, err = pcall(function()
        local motion = (ns.db == nil) or (ns.db.partyMotion ~= false)
        local anim = (ns.db and ns.db.animations) or "Always"
        local animate = motion and anim ~= "Off"
        local idx = 0
        for _, r in ipairs(party.rows) do
            if r:IsShown() then
                idx = idx + 1
                if r._slideTween then ns.KillTween(r._slideTween); r._slideTween = nil end
                if r._fillTween then ns.KillTween(r._fillTween); r._fillTween = nil end
                if animate then
                    local target = r._fillTarget or 0
                    r._slide = -26
                    self:PlaceRow(r)
                    r.fill:SetWidth(0)
                    local delay = 0.28 + (idx - 1) * 0.07
                    ns.After(delay, function()
                        if not r:IsShown() then return end
                        r._slideTween = ns.Tween({
                            dur = 0.5, from = -26, to = 0, ease = ns.cubicBezier(0.34, 1.8, 0.5, 1),
                            set = function(v) r._slide = v; self:PlaceRow(r) end,
                            done = function() r._slideTween = nil; r._slide = 0; self:PlaceRow(r) end,
                        })
                    end)
                    r._fillTween = ns.Tween({
                        dur = 0.7, from = 0, to = target, ease = ns.easeOutCubic,
                        set = function(v) r.fill:SetWidth(v) end,
                        done = function() r._fillTween = nil end,
                    })
                else
                    r._slide = 0
                    self:PlaceRow(r)
                    r.fill:SetWidth(r._fillTarget or r.fill:GetWidth())
                    r.value:ClearAllPoints()
                    r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 0)
                end
            end
        end
    end)
    if not ok then ns.ReportError("panel:PlayPartyMotion", err) end
end

function panel:UpdatePartyBob()
    local anim = (ns.db and ns.db.animations) or "Always"
    if ns.db == nil or ns.db.partyMotion == false or anim ~= "Always" then return end
    local off = 1.5 * math.sin((ns.animClock or 0) * (math.pi * 2 / 1.3))
    for _, r in ipairs(party.rows) do
        if r:IsShown() and r._bob then
            r.value:ClearAllPoints()
            r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, off)
        end
    end
end

function panel:ResetGroups()
    for i = 1, 3 do
        self.g[i] = 0
        setGroupAlpha(i, 1)
    end
end

-- ---------------------------------------------------------------------------
-- Theme
-- ---------------------------------------------------------------------------
function panel:ApplyTheme()
    self.themed = true
    self._themeName = ns.db and ns.db.theme
    local th = ns.Theme()
    local gold = ns.HexA(th.gold)
    local bg1 = ns.HexA(th.bg1)
    local bg2 = ns.HexA(th.bg2)
    local rule = ns.HexA(th.rule or "#8A6A2C")

    ruleL:SetTexture(ns.Media.white)
    ruleR:SetTexture(ns.Media.white)
    ns.Gradient(ruleL, { rule[1], rule[2], rule[3], 0 }, { rule[1], rule[2], rule[3], 0.9 }, true)
    ns.Gradient(ruleR, { rule[1], rule[2], rule[3], 0.9 }, { rule[1], rule[2], rule[3], 0 }, true)

    for _, c in ipairs(chips) do styleChip(c) end
    ns.WhiteTexture(gear.bg)
    ns.Gradient(gear.bg, bg1, bg2, false)
    ns.Paint(gear.bd, 0.29, 0.23, 0.11, 1)
    gear.icon:SetVertexColor(gold[1], gold[2], gold[3], 1)
    self:RefreshPin()

    for _, cell in ipairs(cells) do
        cell.k:SetTextColor(gold[1], gold[2], gold[3], 1)
    end
    for _, r in ipairs(repList.rows) do
        r.name:SetTextColor(gold[1], gold[2], gold[3], 1)
    end
    spark.title:SetTextColor(gold[1], gold[2], gold[3], 1)
    party.title:SetTextColor(gold[1], gold[2], gold[3], 1)

    -- quest overlay box
    ns.WhiteTexture(quest.bg)
    ns.Gradient(quest.bg, bg1, bg2, false)
    ns.Paint(quest.bd, ns.Hex(th.trim))

    for _, cell in ipairs(cells) do
        ns.StyleText(cell.k, 11, "bold")
        ns.StyleText(cell.v, 14, "bold")
    end
end

-- ---------------------------------------------------------------------------
-- Party gathering
-- ---------------------------------------------------------------------------
local function rosterMembers()
    local out = {}
    if not (ns.API.InGroup and ns.API.InGroup()) then return out end
    local nRaid = 0
    if ns.API.InRaid and ns.API.InRaid() then
        nRaid = (ns.API.GetNumRaidMembers and ns.API.GetNumRaidMembers()) or 0
    end
    local nParty = (ns.API.GetNumPartyMembers and ns.API.GetNumPartyMembers()) or 0
    local function add(unit)
        local name = UnitName(unit)
        if name and name ~= UnitName("player") then
            local _, class = UnitClass(unit)
            out[#out + 1] = { name = name, level = UnitLevel(unit) or 0, class = class }
        end
    end
    if nRaid > 0 then
        for i = 1, nRaid do add("raid" .. i) end
    else
        for i = 1, nParty do add("party" .. i) end
    end
    return out
end

local function noteFor(mine, theirs)
    if theirs.level > mine.level then
        local d = theirs.level - mine.level
        return ("%d level%s ahead"):format(d, d == 1 and "" or "s"), ns.Colors.rep[1], true
    elseif theirs.level < mine.level then
        local d = mine.level - theirs.level
        return ("%d level%s behind"):format(d, d == 1 and "" or "s"), ns.HexA("#FF6A4A"), false
    end
    local dif = ((mine.pct or 0) - (theirs.pct or 0)) * 100
    if math.abs(dif) < 2 then
        return "= level", ns.Colors.gray, false
    elseif dif > 0 then
        return ("%d%% behind"):format(ns.round(dif)), ns.HexA("#FF6A4A"), false
    end
    return ("%d%% ahead"):format(ns.round(-dif)), ns.Colors.rep[1], true
end

function panel:GatherParty()
    local byName = {}
    local list = {}
    for _, m in ipairs(ns.comms:List()) do
        m.hasAddon = true
        if m.xpMax and m.xpMax > 0 then m.pct = m.xp / m.xpMax end
        byName[m.name] = m
        list[#list + 1] = m
    end
    for _, r in ipairs(rosterMembers()) do
        if not byName[r.name] then
            r.hasAddon = false
            list[#list + 1] = r
        end
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Layout + content
-- ---------------------------------------------------------------------------
local function updatedAgo()
    local t = ns.lastUpdate or GetTime()
    local s = math.max(0, math.floor(GetTime() - t))
    if s < 2 then return "Updated just now" end
    if s < 60 then return "Updated " .. s .. "s ago" end
    return "Updated " .. ns.Time(s) .. " ago"
end

-- Signature of the party rows so we only rebuild them when the roster or a
-- member's values actually change.
local function partySignature(members)
    local parts = {}
    for i = 1, #members do
        local m = members[i]
        parts[i] = table.concat({
            tostring(m.name), tostring(m.level), tostring(m.xp),
            tostring(m.xpMax), tostring(m.class), tostring(m.hasAddon),
        }, ":")
    end
    return table.concat(parts, "|")
end

-- Draws one row of next-level spell chips, with a +N chip for overflow.
-- Returns the height used (0 when there is nothing to show).
function panel:LayoutSpells(d, innerW, top)
    -- Use the final open width so the visible spells and +N count stay
    -- stable while the island expands or its spring animation overshoots.
    innerW = ns.island:TargetWidth(true) - PAD * 2
    local spells = (d and d.spells) or {}
    local lvl = d and d.nextSpellLevel
    if not lvl or #spells == 0 then
        spellStrip:Hide()
        for _, c in ipairs(spellChips) do c:Hide() end
        if spellPlus then spellPlus:Hide() end
        return 0
    end

    spellTag.text:SetText("Lv " .. tostring(lvl))
    local tagW = math.max(36, (spellTag.text:GetStringWidth() or 20) + 16)
    spellTag:SetWidth(tagW)
    spellTag:ClearAllPoints()
    spellTag:SetPoint("TOPLEFT", spellStrip, "TOPLEFT", 0, -3)
    spellTag:Show()

    local reward = d.nextReward or ""
    spellReward:SetText(reward)
    local rewardW = (reward ~= "") and ((spellReward:GetStringWidth() or 0) + 10) or 0

    local avail = innerW - tagW - 10 - 4
    local plusW = 44
    local x, shown = 0, 0
    local overflow = false
    for i = 1, #spells do
        local s = spells[i]
        local c = spellChips[i] or makeSpellChip()
        c.icon:SetTexture(s.icon)
        c.label:SetText(s.name or "?")
        local w = 30 + (c.label:GetStringWidth() or 40) + 8
        if x + w > avail then overflow = true; break end
        c:SetWidth(w)
        c.spell = s
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", spellStrip, "TOPLEFT", tagW + 10 + x, 0)
        c:Show()
        x = x + w + 6
        shown = i
    end
    -- If spells overflow, move trailing chips into the tooltip until the
    -- +N badge and its gap also fit inside the row.
    if overflow then
        while shown > 0 and x + 2 + plusW > avail do
            x = x - spellChips[shown]:GetWidth() - 6
            shown = shown - 1
        end
    end
    for i = shown + 1, #spellChips do spellChips[i]:Hide() end

    local endX = tagW + 10 + x
    local rest = #spells - shown
    if overflow and rest > 0 then
        local p = spellPlus or makePlusChip()
        p.label:SetText("+" .. rest)
        p:SetWidth(plusW)

        -- List only hidden spells so the tooltip matches +N without repeating visible chips.
        p.list = {}
        for i = shown + 1, #spells do
            p.list[#p.list + 1] = spells[i]
        end
        p:ClearAllPoints()
        p:SetPoint("LEFT", spellStrip, "LEFT", endX + 2, 0)
        p:Show()
        endX = endX + plusW + 8
    elseif spellPlus then
        spellPlus:Hide()
    end

    -- the next big reward sits after the last chip, only if there is room
    if reward ~= "" and endX + rewardW <= innerW then
        spellReward:ClearAllPoints()
        spellReward:SetPoint("LEFT", spellStrip, "LEFT", endX + 6, 0)
        spellReward:Show()
    else
        spellReward:Hide()
    end

    spellStrip:ClearAllPoints()
    spellStrip:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -top)
    spellStrip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -top)
    spellStrip:SetHeight(28)
    spellStrip:Show()
    return 28
end

-- Draws the 8-cell info grid at the given y and returns the new y.  Used by
-- every type, including Reputation (which shows the faction bar above it).
local function renderStatGrid(d, innerW, y, g2)
    local colGap, rowGap = 16, 12
    local colW = (innerW - colGap * 3) / 4
    grid:ClearAllPoints()
    grid:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + g2))
    grid:SetSize(innerW, 72)
    for i = 1, 8 do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local cell = cells[i]
        cell:SetSize(colW, 30)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (colW + colGap), -(row * (30 + rowGap)))
        cell.isTurnIn = (d.key == "xp" and i == turnInIndex and ns.db.questList and not ns.db.v1)
        cell:EnableMouse(cell.isTurnIn and true or false)
        local s = d.stats and d.stats[i]
        if s then
            local k, v = s.k or "", s.v or ""
            if cell._k ~= k then cell.k:SetText(k); cell._k = k end
            if cell._v ~= v then cell.v:SetText(v); cell._v = v end
            local c = s.c or { 1, 1, 1, 1 }
            local cc = cell._c
            if not cc or cc[1] ~= c[1] or cc[2] ~= c[2] or cc[3] ~= c[3] or (cc[4] or 1) ~= (c[4] or 1) then
                cell.v:SetTextColor(c[1], c[2], c[3], c[4] or 1)
                cell._c = { c[1], c[2], c[3], c[4] or 1 }
            end
            cell:Show()
        else
            cell:Hide()
        end
    end
    return y + 72
end

function panel:Layout(d)
    d = d or (ns.data and ns.data:Current())
    if not d then return 268 end
    local W = f:GetWidth() or 460
    local innerW = W - PAD * 2
    local y = 58

    -- rule
    y = y + 6
    local half = math.floor(innerW / 2)
    ruleL:ClearAllPoints()
    ruleL:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[1]))
    ruleL:SetWidth(half)
    ruleR:ClearAllPoints()
    ruleR:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[1]))
    ruleR:SetWidth(innerW - half)

    -- chips
    y = y + 16
    chipRow:ClearAllPoints()
    chipRow:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[1]))
    chipRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[1]))

    local list = ns.data:List()
    local activeKey = ns.data:ActiveKey()
    local cx = 0
    for i = 1, #list do
        local c = chips[i] or makeChip()
        chips[i] = c
        c.key = list[i]
        c.active = (list[i] == activeKey)
        if c._styledActive ~= c.active then c._styledActive = c.active; styleChip(c) end
        c:SetHeight(26)
        c.label:SetText(ns.L[list[i]])
        local lw = c.label:GetStringWidth() or 60
        c:SetWidth(lw + 24)
        c:SetPoint("LEFT", chipRow, "LEFT", cx, 0)
        cx = cx + c:GetWidth() + 6
        c:Show()
    end
    for i = #list + 1, #chips do chips[i]:Hide() end

    gear:ClearAllPoints()
    gear:SetPoint("RIGHT", chipRow, "RIGHT", 0, 0)

    pin:ClearAllPoints()
    pin:SetPoint("RIGHT", gear, "LEFT", -4, 0)
    if ns.db and ns.db.mode == "Always open" then
        pin:Hide()
    else
        pin:Show()
        stylePin()
    end

    y = y + 26

    -- body: Reputation shows the watched faction bar(s) and then the same
    -- 8-cell info grid; every other type is just the grid.
    local isRep = (d.key == "rep") and (d.available ~= false)
    self.last = self.last or {}
    self.last.isRep = isRep
    self.last.innerW = innerW
    grid:Show()
    repList:Hide()
    repLadder:Hide()

    if isRep then
        y = y + 14
        repList:ClearAllPoints()
        repList:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[2]))
        repList:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[2]))
        -- the watched faction always leads, then this session's other gains
        local list2 = ns.repList()
        local watched = ns.rep()
        if watched.available then
            local gained = 0
            for _, e in ipairs(list2) do if e.name == watched.name then gained = e.gained or 0 end end
            local merged = { { name = watched.name, gained = gained, standing = watched.standing, pct = watched.pct } }
            for _, e in ipairs(list2) do
                if e.name ~= watched.name then merged[#merged + 1] = e end
            end
            list2 = merged
        end
        while #list2 > 4 do table.remove(list2) end
        local maxGain = 1
        for _, r in ipairs(list2) do maxGain = math.max(maxGain, math.abs(r.gained or 0)) end
        local h = math.max(40, 8 + #list2 * 22)
        repList:SetHeight(h)
        for i, e in ipairs(list2) do
            local r = repList.rows[i] or makeRepRow(i)
            r:SetHeight(22)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", repList, "TOPLEFT", 0, -((i - 1) * 22))
            r:SetPoint("TOPRIGHT", repList, "TOPRIGHT", 0, -((i - 1) * 22))
            r.name:SetText(e.name or "?")
            r.standing:SetText(e.standing or "")
            r.gain:SetText((e.gained and e.gained ~= 0) and ("+" .. ns.Comma(e.gained)) or "")
            r.track:SetWidth(innerW)
            local pct = (e.pct ~= nil) and e.pct or (math.abs(e.gained or 0) / maxGain)
            r.fill:SetWidth(ns.round(innerW * ns.clamp(pct, 0, 1)))
            r.fill:SetTexture(ns.Media.white)
            r.fill:SetVertexColor(0.13, 0.77, 0.24, 0.85)
            r:Show()
        end
        for i = #list2 + 1, #repList.rows do repList.rows[i]:Hide() end
        repList:Show()
        y = y + h
        -- standing ladder: every tier, current lit, track shows overall progress
        local tierN = ns.repTierCount or 8
        local sid = d.standingID or 0
        repLadder:ClearAllPoints()
        repLadder:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[2]))
        repLadder:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[2]))
        repLadder:SetHeight(30)
        local slot = innerW / tierN
        for i = 1, tierN do
            local fs = repLadder.labels[i]
            fs:SetWidth(slot)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", repLadder, "TOPLEFT", (i - 1) * slot, 0)
            fs:SetText((ns.repStandingName and ns.repStandingName(i)) or ("Tier " .. i))
            local weight = (i == sid) and "bold" or "medium"
            ns.StyleText(fs, 10, weight)
            if i == sid then
                fs:SetTextColor(1, 0.82, 0, 1)
            elseif sid > 0 and i < sid then
                fs:SetTextColor(0.72, 0.62, 0.36, 1)
            else
                fs:SetTextColor(0.55, 0.55, 0.55, 1)
            end
        end
        repLadder.track:ClearAllPoints()
        repLadder.track:SetPoint("TOPLEFT", repLadder, "TOPLEFT", 0, -15)
        repLadder.track:SetPoint("TOPRIGHT", repLadder, "TOPRIGHT", 0, -15)
        repLadder.track:SetHeight(4)
        local overall = 0
        if sid > 0 then overall = ((sid - 1) + (d.tierPct or 0)) / tierN end
        local fillW = ns.round(innerW * ns.clamp(overall, 0, 1))
        repLadder.fill:SetVertexColor(0.55, 0.72, 1, 0.85)
        repLadder.fill:SetWidth(fillW)
        repLadder.marker:ClearAllPoints()
        repLadder.marker:SetPoint("CENTER", repLadder.track, "LEFT", fillW, 0)
        repLadder:Show()
        y = y + 34
        -- full detail for the watched faction under the ladder
        y = y + 14
        y = renderStatGrid(d, innerW, y, self.g[2])
    else
        y = y + 14
        y = renderStatGrid(d, innerW, y, self.g[2])
    end

    -- sparkline
    local showSpark = (d.key == "xp") and ns.db.sparkline and not ns.db.v1
    if showSpark then
        y = y + 14
        spark:ClearAllPoints()
        spark:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[3]))
        spark:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[3]))
        spark:SetHeight(56)
        spark.title:SetText("Session XP")
        local gain = (ns.session and ns.session.gain) or 0
        spark.sub:SetText("+" .. ns.Short(gain, ns.db.compact) .. " this session")
        spark:Show()
        if gain <= 0 then
            -- idle: heartbeat mode instead of the real graph
            self:SetIdle(true)
            spark.arrow:Hide()
            for _, l in ipairs(sparkLines) do l:Hide() end
            for _, a in ipairs(sparkAreas) do a:Hide() end
            spark.dot:Hide(); spark.dotBG:Hide(); spark.ring:Hide()
            spark.best:Hide(); spark.bestEdge:Hide(); spark.bestLabel:Hide()
            spark.cursor:Hide(); spark.tip:Hide()
        else
            self:SetIdle(false)
            self:DrawSpark(ns.xp().samples)
            -- fade the real graph in on the first gain of the session
            if self._idleWas then
                spark:SetAlpha(0)
                if spark._idleFade then ns.KillTween(spark._idleFade) end
                spark._idleFade = ns.Tween({
                    dur = 0.4, from = 0, to = 1, ease = ns.easeOutCubic,
                    set = function(v) spark:SetAlpha(v) end,
                    done = function() spark:SetAlpha(1); spark._idleFade = nil end,
                })
            end
        end
        self._idleWas = (gain <= 0)
        if self.StartSparkLoop then self:StartSparkLoop() end
        y = y + 56
    else
        spark:Hide()
        self:SetIdle(false)
        if self.StopSparkLoop then self:StopSparkLoop() end
    end

    -- party
    local members = self:GatherParty()
    local showParty = (d.key == "xp") and ns.db.party and #members > 0
    if showParty then
        y = y + 14
        party:ClearAllPoints()
        party:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[3]))
        party:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[3]))
        local perRow = math.min(#members, 4)
        local rows = math.ceil(#members / perRow)
        local rowH = 38
        self.last.partyShown = true
        self.last.partyCount = #members
        self.last.partyRowH = rowH
        self.last.partyPerRow = perRow
        party:SetHeight(16 + rows * rowH)
        party:Show()
        party.title:SetText("Party")
        party.sub:SetText("Members running XPBar Island")
        local sig = partySignature(members)
        if self.last.partySig ~= sig then
            self.last.partySig = sig
            local gapP = 10
            local colWp = (innerW - (perRow - 1) * gapP) / perRow
            for i, m in ipairs(members) do
                local r = party.rows[i] or makePartyRow(i)
                local col = (i - 1) % perRow
                local row = math.floor((i - 1) / perRow)
                r:SetSize(colWp, 32)
                r._mx = col * (colWp + gapP)
                r._my = -(16 + row * rowH)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", party, "TOPLEFT", r._mx + (r._slide or 0), r._my)
                local cr, cg, cb = ns.ClassColor(m.class)
                if m.hasAddon then
                    local note, color, ahead = noteFor(d, m)
                    r.name:SetText(m.name)
                    r.name:SetTextColor(cr, cg, cb, 1)
                    r.value:SetText(note)
                    r.value:SetTextColor(color[1], color[2], color[3], 1)
                    r.track:Show()
                    r.track:SetWidth(colWp)
                    r._fillTarget = ns.round(colWp * ns.clamp(m.pct or 0, 0, 1))
                    r.fill:SetWidth(r._fillTarget)
                    r.fill:SetTexture(ns.Media.white)
                    r.fill:SetVertexColor(cr, cg, cb, 0.85)
                    r._bob = ahead
                else
                    r.name:SetText(m.name)
                    r.name:SetTextColor(cr, cg, cb, 1)
                    r.value:SetText("no XPBar Island")
                    r.value:SetTextColor(0.62, 0.62, 0.62, 1)
                    r.track:Hide()
                    r._bob = false
                end
                r:Show()
            end
            for i = #members + 1, #party.rows do party.rows[i]:Hide() end
        end
        y = y + party:GetHeight()
    else
        party:Hide()
        self.last.partyShown = false
        self.last.partySig = nil
    end

    -- footer: the XP bar gets the next-spells row with "Updated" below it;
    -- every other type keeps the single-line milestone footer.
    y = y + 12
    local spellH = 0
    if ns.db.v1 then
        footerLeft:ClearAllPoints()
        footerLeft:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[3]))
        footerLeft:SetText("Click to open - Shift-Click to Share")
        footerLeft:Show()
        footerRight:ClearAllPoints()
        footerRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[3]))
        footerRight:SetText("")
        self:LayoutSpells(nil, innerW, y + self.g[3])
    else
        spellH = self:LayoutSpells(d, innerW, y + self.g[3])
        if spellH > 0 then
            footerLeft:SetText("")
            footerLeft:Hide()
            footerRight:ClearAllPoints()
            footerRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[3] + spellH + 2))
            footerRight:SetText(updatedAgo())
            footerRight:Show()
        else
            footerLeft:ClearAllPoints()
            footerLeft:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + self.g[3]))
            footerLeft:SetText("|cffFFD100\226\151\134|r " .. (d.milestone or ""))
            footerLeft:Show()
            footerRight:ClearAllPoints()
            footerRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + self.g[3]))
            footerRight:SetText(updatedAgo())
            footerRight:Show()
        end
    end

    -- keep the quest overlay below the whole stat grid so it cannot sit on
    -- (and latch open over) the second-row cells
    quest:ClearAllPoints()
    quest:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -4)
    if d.key ~= "xp" or not ns.db.questList or ns.db.v1 then
        quest:Hide()
        ns.questPreview = nil
    end

    local total = y + (spellH > 0 and (spellH + 16) or 16) + 12
    self.height = total
    return total
end

-- Light reflow used every frame of the expand/collapse tween: it only
-- repositions the width-dependent pieces (no text/party/sparkline rebuild).
function panel:Reflow()
    local st = self.last
    if not st then return end
    local W = f:GetWidth() or 460
    local innerW = W - PAD * 2
    if math.abs(innerW - (st.innerW or -1)) < 0.5 then return end
    st.innerW = innerW

    local half = math.floor(innerW / 2)
    ruleL:SetWidth(half)
    ruleR:SetWidth(innerW - half)

    if not st.isRep then
        local colGap, rowGap = 16, 12
        local colW = (innerW - colGap * 3) / 4
        for i = 1, 8 do
            local col = (i - 1) % 4
            local row = math.floor((i - 1) / 4)
            local cell = cells[i]
            cell:SetSize(colW, 30)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (colW + colGap), -(row * (30 + rowGap)))
        end
    else
        for i = 1, #repList.rows do repList.rows[i].track:SetWidth(innerW) end
    end

    if st.partyShown then
        local perRow = st.partyPerRow or 3
        local gapP = 10
        local colWp = (innerW - (perRow - 1) * gapP) / perRow
        for i = 1, st.partyCount do
            local r = party.rows[i]
            if r then
                local col = (i - 1) % perRow
                local row = math.floor((i - 1) / perRow)
                r:SetSize(colWp, 32)
                r._mx = col * (colWp + gapP)
                r._my = -(16 + row * (st.partyRowH or 38))
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", party, "TOPLEFT", r._mx + (r._slide or 0), r._my)
                r.track:SetWidth(colWp)
            end
        end
    end
    -- the sparkline is redrawn once when the expand/collapse tween finishes
end

function panel:NeededHeight()
    return self:Layout(ns.data and ns.data:Current())
end

-- ---------------------------------------------------------------------------
-- Session XP graph
-- ---------------------------------------------------------------------------
local SPARK_DRAWIN = 0.9
local SPARK_EASE = ns.cubicBezier(0.3, 1, 0.4, 1)
local SPARK_HEAT_LO = { 138 / 255, 63 / 255, 168 / 255 }   -- dim (theme graph1)
local SPARK_HEAT_HI = { 1, 209 / 255, 0 }                  -- bright (theme graph2)
local SPARK_AREA_COL = { 0.69, 0.16, 0.82 }

-- Pull the graph colours from the active theme (called before each draw).
local function refreshGraphColors()
    local th = ns.Theme()
    local lo = ns.HexA(th.graph1 or "#8A3FA8")
    local hi = ns.HexA(th.graph2 or "#FFD100")
    SPARK_HEAT_LO[1], SPARK_HEAT_LO[2], SPARK_HEAT_LO[3] = lo[1], lo[2], lo[3]
    SPARK_HEAT_HI[1], SPARK_HEAT_HI[2], SPARK_HEAT_HI[3] = hi[1], hi[2], hi[3]
    local ar = ns.HexA(th.area or "#B02AD0")
    SPARK_AREA_COL[1], SPARK_AREA_COL[2], SPARK_AREA_COL[3] = ar[1], ar[2], ar[3]
end

local function sparkHeat(h)
    h = ns.clamp(h or 0, 0, 1)
    return SPARK_HEAT_LO[1] + (SPARK_HEAT_HI[1] - SPARK_HEAT_LO[1]) * h,
           SPARK_HEAT_LO[2] + (SPARK_HEAT_HI[2] - SPARK_HEAT_LO[2]) * h,
           SPARK_HEAT_LO[3] + (SPARK_HEAT_HI[3] - SPARK_HEAT_LO[3]) * h
end

local function sparkScale(samples, h, w)
    local n = #samples
    local maxV = 1
    for i = 1, n do maxV = math.max(maxV, samples[i].t or 0) end
    local function X(i) return (i - 1) / (n - 1) * w end
    local function Y(i) return (samples[i].t or 0) / maxV * (h - 4) end
    return X, Y
end

function panel:LayoutSparkDot()
    local g = spark.graph
    local x = spark._lastX or 0
    local y = (spark._lastY or 0) + (spark._bumpRise or 0)
    spark.dotBG:ClearAllPoints(); spark.dotBG:SetPoint("CENTER", g, "BOTTOMLEFT", x, y)
    spark.dot:ClearAllPoints(); spark.dot:SetPoint("CENTER", g, "BOTTOMLEFT", x, y)
    spark.dotBG:Show()
    spark.dot:Show()
end

function panel:LayoutSparkBest(gains, bestIdx, X, Y)
    local g = spark.graph
    local h = g:GetHeight() or SPARK_GRAPH_H
    if not bestIdx or (gains[bestIdx] or 0) <= 0 then
        spark.best:Hide(); spark.bestEdge:Hide(); spark.bestLabel:Hide()
        return
    end
    local mx = (X(bestIdx) + X(bestIdx + 1)) / 2
    local my = (Y(bestIdx) + Y(bestIdx + 1)) / 2
    spark.bestEdge:ClearAllPoints(); spark.bestEdge:SetPoint("CENTER", g, "BOTTOMLEFT", mx, my); spark.bestEdge:Show()
    spark.best:ClearAllPoints(); spark.best:SetPoint("CENTER", g, "BOTTOMLEFT", mx, my); spark.best:Show()
    local label = "Best +" .. ns.Short(gains[bestIdx], ns.db and ns.db.compact)
    if spark._bumpOn and spark._lastGainIsBest then label = "New best!" end
    spark.bestLabel:SetText(label)
    local lw = spark.bestLabel:GetStringWidth() or 0
    spark.bestLabel:ClearAllPoints()
    spark.bestLabel:SetPoint("BOTTOM", g, "BOTTOMLEFT", ns.clamp(mx, lw / 2, (g:GetWidth() or 100) - lw / 2), h - 2)
    spark.bestLabel:Show()
end

function panel:LayoutSparkFlags(samples, X, h)
    local g = spark.graph
    local used = 0
    for i = 2, #samples do
        local lv, plv = samples[i].level, samples[i - 1].level
        if lv and plv and lv > plv then
            used = used + 1
            local fl = spark.flags[used] or spark._makeFlag()
            spark.flags[used] = fl
            local x = X(i)
            -- dashed 1px gold line from the baseline to the top of the graph
            local dash, gap = 3, 4
            local y, d = 0, 0
            while y < h do
                d = d + 1
                local t = flagDash(fl, d)
                t:ClearAllPoints()
                t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x, y)
                t:SetHeight(math.min(dash, h - y))
                t:Show()
                y = y + dash + gap
            end
            for k = d + 1, #fl.dashes do fl.dashes[k]:Hide() end
            fl.label:SetText("Lv " .. tostring(lv))
            fl.label:ClearAllPoints()
            fl.label:SetPoint("BOTTOM", g, "BOTTOMLEFT", x, h + 1)
            fl.label:Show()
        end
    end
    for i = used + 1, #spark.flags do
        hideFlag(spark.flags[i])
    end
end

function panel:UpdateSparkArrow(samples)
    local n = #samples
    if n < 6 then spark.arrow:Hide(); return end
    local last = (samples[n].t or 0) - (samples[n - 1].t or 0)
    -- average of the intervals before the last one (clamped so index 0 never
    -- happens with exactly 6 samples)
    local firstIdx = math.max(1, n - 6)
    local span = math.max(1, (n - 1) - firstIdx)
    local prev = ((samples[n - 1].t or 0) - (samples[firstIdx].t or 0)) / span
    if prev <= 0 then spark.arrow:Hide(); return end
    local pct = (last - prev) / prev * 100
    local up = pct >= 0
    local txt = (up and "\226\150\178 " or "\226\150\188 ") .. (up and "+" or "") ..
        ns.round(pct) .. "% vs 5m"
    spark.arrow:SetText(txt)
    if up then spark.arrow:SetTextColor(0.30, 0.85, 0.30, 1)
    else spark.arrow:SetTextColor(1, 0.416, 0.29, 1) end
    spark.arrow:Show()
end

function panel:DrawSpark(samples, intro)
    if self._idle then return end
    local ok, err = pcall(function()
        samples = samples or {}
        local g = spark.graph
        local w = g:GetWidth() or 100
        local h = g:GetHeight() or SPARK_GRAPH_H
        local n = #samples
        local gain = (ns.session and ns.session.gain) or 0

        -- cost guard: redraw only when data, width or gain changed (or on intro)
        local sig = n .. ":" .. math.floor(gain) .. ":" .. math.floor(w) ..
            ":" .. tostring((samples[n] and samples[n].t) or 0)
        if not intro and sig == spark._sig then return end
        spark._sig = sig
        refreshGraphColors()

        -- record the level with each sample
        local level = UnitLevel("player") or 0
        for i = 1, n do
            if samples[i].level == nil then samples[i].level = level end
        end
        spark.samples = samples

        if n < 2 then
            for _, l in ipairs(sparkLines) do l:Hide() end
            for _, a in ipairs(sparkAreas) do a:Hide() end
            for _, f in ipairs(spark.flags) do hideFlag(f) end
            spark.dot:Hide(); spark.dotBG:Hide(); spark.ring:Hide()
            spark.best:Hide(); spark.bestEdge:Hide(); spark.bestLabel:Hide()
            spark.guides[1]:Hide(); spark.guides[2]:Hide()
            spark.cursor:Hide(); spark.tip:Hide(); spark.arrow:Hide()
            spark.empty:Show()
            return
        end
        spark.empty:Hide()

        local X, Y = sparkScale(samples, h, w)

        -- faint guide lines at 30% and 60% of the graph height
        for i = 1, 2 do
            local gl = spark.guides[i]
            local gh = math.floor(h * (i == 1 and 0.3 or 0.6))
            gl:ClearAllPoints()
            gl:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, gh)
            gl:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, gh)
            gl:Show()
        end

        local nseg = n - 1
        local maxGain = 0
        local gains = {}
        local bestIdx = 1
        for i = 1, nseg do
            local gI = (samples[i + 1].t or 0) - (samples[i].t or 0)
            gains[i] = gI
            if gI > maxGain then maxGain = gI; bestIdx = i end
        end
        spark._bestGain = gains[bestIdx]
        spark._lastGainIsBest = (gains[nseg] or 0) >= maxGain and maxGain > 0

        -- start the gain bump when XP increased since the last draw
        if gain > (spark._seenGain or 0) and nseg >= 1 then
            spark._bumpOn = true
            spark._bumpT = 0
        end
        spark._seenGain = gain

        local stagger = SPARK_DRAWIN / nseg
        for i = 1, nseg do
            local x1, x2 = X(i), X(i + 1)
            local y1, y2 = Y(i), Y(i + 1)
            local segW = math.max(1, x2 - x1)
            local avg = math.max(1, (y1 + y2) / 2)
            local fadeA = 0.45 + 0.55 * i / nseg
            local heat = (maxGain > 0) and (gains[i] / maxGain) or 0
            local cr, cg, cb = sparkHeat(heat)

            local a = sparkAreas[i] or g:CreateTexture(nil, "ARTWORK", nil, 0)
            sparkAreas[i] = a
            a:SetTexture(ns.Media.white)
            a:ClearAllPoints()
            a:SetWidth(segW); a:SetHeight(avg)
            a:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x1, 0)
            ns.Gradient(a, { SPARK_AREA_COL[1], SPARK_AREA_COL[2], SPARK_AREA_COL[3], 0.5 },
                { SPARK_AREA_COL[1], SPARK_AREA_COL[2], SPARK_AREA_COL[3], 0 }, false)
            a._fade = fadeA
            a:Show()

            local l = sparkLines[i] or g:CreateTexture(nil, "OVERLAY", nil, 2)
            sparkLines[i] = l
            l:SetTexture(ns.Media.white)
            l:SetVertexColor(cr, cg, cb, 1)
            local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
            l:ClearAllPoints()
            l:SetWidth(math.max(1, len)); l:SetHeight(2)
            l:SetPoint("CENTER", g, "BOTTOMLEFT", (x1 + x2) / 2, (y1 + y2) / 2)
            if l.SetRotation then l:SetRotation(atan2(y2 - y1, x2 - x1)) end
            l._fade = fadeA
            l._heat = heat
            l:Show()
        end
        for i = nseg + 1, #sparkLines do sparkLines[i]:Hide() end
        for i = nseg + 1, #sparkAreas do sparkAreas[i]:Hide() end

        -- draw-in on open; keep it while its tween runs
        local animOff = (not ns.db) or ns.db.animations == "Off"
        if intro and not animOff then
            if spark._introTween then ns.KillTween(spark._introTween) end
            for i = 1, nseg do
                sparkLines[i]:SetAlpha(0)
                if sparkAreas[i] then sparkAreas[i]:SetAlpha(0) end
            end
            spark._introTween = ns.Tween({
                dur = SPARK_DRAWIN, from = 0, to = 1, ease = ns.easeLinear,
                set = function(_, p)
                    local elapsed = p * SPARK_DRAWIN
                    for i = 1, nseg do
                        local u = ns.clamp((elapsed - (i - 1) * stagger) / stagger, 0, 1)
                        local e = SPARK_EASE(u)
                        local al = (sparkLines[i]._fade or 1) * e
                        sparkLines[i]:SetAlpha(al)
                        if sparkAreas[i] then sparkAreas[i]:SetAlpha(al) end
                    end
                end,
                done = function() spark._introTween = nil end,
            })
        elseif not spark._introTween then
            for i = 1, nseg do
                sparkLines[i]:SetAlpha(sparkLines[i]._fade or 1)
                if sparkAreas[i] then sparkAreas[i]:SetAlpha(sparkAreas[i]._fade or 1) end
            end
        end

        spark._lastX, spark._lastY = X(n), Y(n)
        spark._bumpRise = spark._bumpRise or 0
        self:LayoutSparkDot()
        self:LayoutSparkBest(gains, bestIdx, X, Y)
        self:LayoutSparkFlags(samples, X, h)
        self:UpdateSparkArrow(samples)

        spark.ring:ClearAllPoints()
        spark.ring:SetPoint("CENTER", g, "BOTTOMLEFT",
            spark._lastX, (spark._lastY or 0) + (spark._bumpRise or 0))
    end)
    if not ok then ns.ReportError("panel:DrawSpark", err) end
end

-- Re-draw just the last (bumping) segment + dot during the gain bump.
-- Wrapped in pcall: an error here must not stop SparkTick from rescheduling.
function panel:UpdateSparkLive()
    local ok, err = pcall(function()
        refreshGraphColors()
        local samples = spark.samples
        if not samples or #samples < 2 then return end
        local g = spark.graph
        local w = g:GetWidth() or 100
        local h = g:GetHeight() or SPARK_GRAPH_H
        local n = #samples
        local X, Y = sparkScale(samples, h, w)
        local i = n - 1
        local l = sparkLines[i]
        if not l then return end
        local x1, y1 = X(i), Y(i)
        local x2 = X(n)
        local y2 = Y(n) + (spark._bumpRise or 0)
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        l:ClearAllPoints()
        l:SetWidth(math.max(1, len)); l:SetHeight(2)
        l:SetPoint("CENTER", g, "BOTTOMLEFT", (x1 + x2) / 2, (y1 + y2) / 2)
        if l.SetRotation then l:SetRotation(atan2(y2 - y1, x2 - x1)) end
        local hh = ns.clamp((l._heat or 0) + (spark._bumpRise or 0) / 4 * 0.5, 0, 1)
        local cr, cg, cb = sparkHeat(hh)
        l:SetVertexColor(cr, cg, cb, 1)
        spark._lastX, spark._lastY = x2, Y(n)
        self:LayoutSparkDot()
        if spark.bestLabel:IsShown() and spark._bumpOn and spark._lastGainIsBest then
            spark.bestLabel:SetText("New best!")
        end
    end)
    if not ok then ns.ReportError("panel:UpdateSparkLive", err) end
end

function panel:SparkHoverUpdate()
    local ok, err = pcall(function()
        local g = spark.graph
        local w = g:GetWidth() or 100
        local samples = spark.samples
        local n = samples and #samples or 0
        if n < 2 then spark.cursor:Hide(); spark.tip:Hide(); return end
        local scale = (g.GetEffectiveScale and g:GetEffectiveScale()) or 1
        local cx = GetCursorPosition()
        local left = g:GetLeft() or 0
        local x = ns.clamp(cx / scale - left, 0, w)
        local idx = ns.clamp(math.floor(x / w * (n - 1) + 0.5), 1, n)
        local px = (idx - 1) / (n - 1) * w
        local gh = g:GetHeight() or SPARK_GRAPH_H

        spark.cursor:ClearAllPoints()
        spark.cursor:SetPoint("TOP", g, "BOTTOMLEFT", px, gh)
        spark.cursor:SetPoint("BOTTOM", g, "BOTTOMLEFT", px, 0)
        spark.cursor:Show()

        local when = (idx == n) and "now" or (ns.Time((n - idx) * 30) .. " ago")
        spark.tip.label:SetText(when .. " \194\183 +" ..
            ns.Short(samples[idx].t or 0, ns.db and ns.db.compact))
        local tw = (spark.tip.label:GetStringWidth() or 40) + 10
        spark.tip:SetWidth(tw)
        local tx = ns.clamp(px - tw / 2, 0, math.max(0, w - tw))
        spark.tip:ClearAllPoints()
        spark.tip:SetPoint("BOTTOM", g, "BOTTOMLEFT", tx + tw / 2, gh + 2)
        spark.tip:Show()
    end)
    if not ok then ns.ReportError("panel:SparkHoverUpdate", err) end
end

-- Idle resting fireflies: shown while session XP is still 0.
function panel:SetIdle(on)
    on = on and true or false
    if self._idle == on then return end
    self._idle = on
    self._idleT = 0
    if on then
        idle:Show()
        spark.empty:Hide()
        local g = spark.graph
        local h = g:GetHeight() or SPARK_GRAPH_H
        for i = 1, 2 do
            local gl = spark.guides[i]
            local gh = math.floor(h * (i == 1 and 0.3 or 0.6))
            gl:ClearAllPoints()
            gl:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, gh)
            gl:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, gh)
            gl:Show()
        end
    else
        idle:Hide()
    end
end

-- 20 Hz driver for the ripple + gain bump; stops when the panel closes.
function panel:StartSparkLoop()
    if not p:IsShown() then return end
    if self._sparkLoop then return end
    self._sparkLoop = true
    self._rippleT = 0
    self:SparkTick()
end

function panel:StopSparkLoop()
    self._sparkLoop = false
    if self._sparkTimer then ns.CancelTimer(self._sparkTimer); self._sparkTimer = nil end
    spark.ring:Hide()
    idle:Hide()
    self._idle = false
end

function panel:SparkTick()
    local ok, err = pcall(function()
        if self._sparkTimer then ns.CancelTimer(self._sparkTimer); self._sparkTimer = nil end
        if not self._sparkLoop then return end
        local anim = (ns.db and ns.db.animations) or "Always"
        local allow = (anim == "Always") or (anim == "On hover only" and self.expanded)
        if anim == "Off" or not allow or not p:IsShown() or not spark:IsShown() then
            self:StopSparkLoop()
            return
        end

        if self._idle then
            self._idleT = (self._idleT or 0) + 0.05
            local t = self._idleT
            local gw = spark.graph:GetWidth() or 400
            local gh = spark.graph:GetHeight() or SPARK_GRAPH_H
            -- breathe the baseline so the empty graph feels alive, not frozen
            idleBase:SetAlpha(0.10 + 0.05 * (0.5 - 0.5 * math.cos(t * 1.7)))
            for i = 1, #flies do
                local m = flies[i]
                local life = (t * m.speed + m.phase) % 1
                local a = math.sin(math.pi * life)
                local sway = m.swayAmp * math.sin(t * m.sway + m.phase * 6.28318)
                local x = ns.clamp(m.x0 + (life - 0.5) * m.drift + sway, 0.01, 0.99)
                local y = life * m.rise
                local sc = m.size * (0.55 + 0.75 * a)
                m.tex:ClearAllPoints()
                m.tex:SetPoint("CENTER", spark.graph, "LEFT", x * gw, y * gh)
                m.tex:SetSize(sc, sc)
                m.tex:SetAlpha(a * m.maxA)
            end
            idleRight:SetWidth(math.max(60, gw - 170))
            for i = 1, #idleDots do
                local ph = (t / 1.5 + (i - 1) * 0.2) % 1
                idleDots[i]:SetAlpha(0.2 + 0.8 * (0.5 - 0.5 * math.cos(2 * math.pi * ph)))
            end
            self._sparkTimer = ns.After(0.05, function() self:SparkTick() end)
            return
        end

        local n = spark.samples and #spark.samples or 0

        if n >= 2 then
            self._rippleT = (self._rippleT or 0) + 0.05
            if self._rippleT >= 1.5 then self._rippleT = self._rippleT - 1.5 end
            local r = self._rippleT / 1.5
            spark.ring:SetSize(8 + 22 * r, 8 + 22 * r)
            spark.ring:SetAlpha(0.9 * (1 - r))
            spark.ring:ClearAllPoints()
            spark.ring:SetPoint("CENTER", spark.graph, "BOTTOMLEFT",
                spark._lastX or 0, (spark._lastY or 0) + (spark._bumpRise or 0))
            spark.ring:Show()
        else
            spark.ring:Hide()
        end

        if spark._bumpOn then
            spark._bumpT = (spark._bumpT or 0) + 0.05
            local u = spark._bumpT / 1.4
            if u >= 1 then
                spark._bumpOn = false
                spark._bumpRise = 0
                self:UpdateSparkLive()
                if spark.bestLabel:IsShown() then
                    spark.bestLabel:SetText("Best +" ..
                        ns.Short(spark._bestGain or 0, ns.db and ns.db.compact))
                end
            else
                spark._bumpRise = 4 * math.sin(math.pi * u)
                self:UpdateSparkLive()
            end
        end

        self._sparkTimer = ns.After(0.05, function() self:SparkTick() end)
    end)
    if not ok then ns.ReportError("panel:SparkTick", err) end
end

function panel:Update(d)
    if not d then return end
    self:Layout(d)
end

function panel:SetAlpha(a) p:SetAlpha(a) end
function panel:ShowPanel()
    p:Show()
    p:SetAlpha(1)
    if not self.themed then
        self.themed = true
        self:ApplyTheme()
    end
    if self.StartSparkLoop then self:StartSparkLoop() end
end
function panel:HidePanel()
    p:Hide()
    quest:Hide()
    ns.questPreview = nil
    if self.StopSparkLoop then self:StopSparkLoop() end
    if spark._introTween then ns.KillTween(spark._introTween); spark._introTween = nil end
end

ns.OnUpdateLayout(function()
    -- theme change only (first show applies it via ShowPanel)
    if ns.db and ns.db.theme ~= panel._themeName then panel:ApplyTheme() end
end)
