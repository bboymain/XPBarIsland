local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- The island: a frame flush to the top centre of the screen, with square top
-- corners and rounded bottom corners, a bronze trim on the left/right/bottom,
-- a gradient background and the collapsed row (badge, name, range, percent,
-- bar, divider, rate/eta).  Hovering tweens it open into the panel.
-- ---------------------------------------------------------------------------
local C_W, C_H = 460, 60
local E_W = 620
local THIN_H = 26
local PAD_L, PAD_R = 10, 16
local BADGE = 40
local GAP = 12
local DIV_W = 1
local CENTER_LEFT = PAD_L + BADGE + GAP            -- 62
-- right block: fixed 72px wide; hidden inset 16, shown inset 16 + 85 = 101
local RIGHT_MIN, RIGHT_MAX = 72, 72
local RB_GAP = 6                                   -- divider<->block and col<->divider
local FADE_ALPHA = 0.4                             -- alpha while "Fade until hovered" is idle

local FEEL = {
    -- exact curves from the mockup's CSS transitions
    Springy = { dur = 0.55, ease = ns.cubicBezier(0.34, 1.45, 0.5, 1) },
    Snappy  = { dur = 0.26, ease = ns.cubicBezier(0.2, 0.9, 0.3, 1) },
    Smooth  = { dur = 0.85, ease = ns.cubicBezier(0.4, 0, 0.2, 1) },
}

local island = {}
ns.island = island

island.openReasons = {}
island.expanded = false
island.pinned = false
island.mouseOver = false
island.radius = 14

local f = CreateFrame("Frame", "XPBarIslandFrame", UIParent)
f:SetSize(C_W, C_H)
f:SetPoint("TOP", UIParent, "TOP", 0, 0)
f:SetFrameStrata("MEDIUM")
f:EnableMouse(true)
if ns.API.canClip then pcall(f.SetClipsChildren, f, true) end
island.frame = f

local function tex(layer, sub, parent)
    return (parent or f):CreateTexture(nil, layer, nil, sub)
end

-- --- background -----------------------------------------------------------
-- gradient sits at the very back; the rounded bottom corners + the straight
-- strip between them are painted the same bottom colour (see ApplyTheme)
island.bg = tex("BACKGROUND", -8)

-- soft dark shadow, used only by the thin Minimal strip
island.thinShadow = tex("BACKGROUND", -3)
island.thinShadow:SetTexture(ns.Media.shadow)
island.thinShadow:SetVertexColor(0, 0, 0, 0.55)
island.thinShadow:Hide()

island.borderL = tex("BORDER", 1)
island.borderR = tex("BORDER", 1)
island.borderB = tex("BORDER", 1)
island.innerL = tex("BORDER", 2)
island.innerR = tex("BORDER", 2)
island.innerB = tex("BORDER", 2)

island.cornerFillBL = tex("BACKGROUND", 0)
island.cornerFillBR = tex("BACKGROUND", 0)
island.cornerEdgeBL = tex("BORDER", 3)
island.cornerEdgeBR = tex("BORDER", 3)

-- --- badge ----------------------------------------------------------------
local badge = CreateFrame("Frame", nil, f)
badge:SetSize(BADGE, BADGE)
island.badge = badge

island.badgeBG = badge:CreateTexture(nil, "BACKGROUND", nil, -1)
island.badgeBG:SetAllPoints(badge)
ns.Paint(island.badgeBG, 0.08, 0.06, 0.03, 1)

-- square 36x36 portrait inside the 40x40 slot
island.portrait = badge:CreateTexture(nil, "ARTWORK", nil, 0)
island.portrait:SetPoint("TOPLEFT", badge, "TOPLEFT", 2, -2)
island.portrait:SetSize(36, 36)
island.portrait:Hide()

-- 2px square ring around the badge slot, drawn as four edge textures
island.badgeRing = {}
island.badgeRing[1] = badge:CreateTexture(nil, "OVERLAY", nil, 0)
island.badgeRing[1]:SetPoint("TOPLEFT", badge, "TOPLEFT", 0, 0)
island.badgeRing[1]:SetPoint("TOPRIGHT", badge, "TOPRIGHT", 0, 0)
island.badgeRing[1]:SetHeight(2)
island.badgeRing[2] = badge:CreateTexture(nil, "OVERLAY", nil, 0)
island.badgeRing[2]:SetPoint("BOTTOMLEFT", badge, "BOTTOMLEFT", 0, 0)
island.badgeRing[2]:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 0, 0)
island.badgeRing[2]:SetHeight(2)
island.badgeRing[3] = badge:CreateTexture(nil, "OVERLAY", nil, 1)
island.badgeRing[3]:SetPoint("TOPLEFT", badge, "TOPLEFT", 0, 0)
island.badgeRing[3]:SetPoint("BOTTOMLEFT", badge, "BOTTOMLEFT", 0, 0)
island.badgeRing[3]:SetWidth(2)
island.badgeRing[4] = badge:CreateTexture(nil, "OVERLAY", nil, 1)
island.badgeRing[4]:SetPoint("TOPRIGHT", badge, "TOPRIGHT", 0, 0)
island.badgeRing[4]:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 0, 0)
island.badgeRing[4]:SetWidth(2)
for i = 1, 4 do ns.Paint(island.badgeRing[i], 1, 0.82, 0, 1) end

island.badgeText = badge:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.badgeText, 17, "bold")
island.badgeText:SetPoint("CENTER", badge, "CENTER", 0, 0)
island.badgeText:SetTextColor(1, 0.82, 0, 1)

-- small round-style level badge at the bottom right of the portrait
island.mini = CreateFrame("Frame", nil, badge)
island.mini:SetSize(18, 18)
island.mini:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 5, -5)
if ns.API.canClip then pcall(island.mini.SetClipsChildren, island.mini, true) end
island.miniBG = island.mini:CreateTexture(nil, "BACKGROUND", nil, 0)
island.miniBG:SetAllPoints(island.mini)
island.miniBG:SetTexture(ns.Media.radial)
island.miniRing = island.mini:CreateTexture(nil, "OVERLAY", nil, 0)
island.miniRing:SetAllPoints(island.mini)
island.miniRing:SetTexture(ns.Media.ring)
island.miniText = island.mini:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.miniText, 11, "bold")
island.miniText:SetPoint("CENTER", island.mini, "CENTER", 0, 0)
island.miniText:SetTextColor(1, 0.82, 0, 1)
island.miniText:SetText("1")
island.miniTextOld = island.mini:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.miniTextOld, 11, "bold")
island.miniTextOld:SetPoint("CENTER", island.mini, "CENTER", 0, 0)
island.miniTextOld:SetTextColor(1, 0.82, 0, 1)
island.miniTextOld:SetAlpha(0)

-- gold outline shown while move mode is on
island.moveOutline = {}
for i = 1, 4 do
    local t = tex("OVERLAY", 7)
    ns.Paint(t, 1, 0.82, 0, 0.9)
    t:Hide()
    island.moveOutline[i] = t
end

-- --- centre column --------------------------------------------------------
local col = CreateFrame("Frame", nil, f)
col:SetHeight(31)
island.col = col

island.nameFS = col:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.nameFS, 12, "extrabold")
island.nameFS:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
island.nameFS:SetJustifyH("LEFT")
island.nameFS:SetTextColor(1, 0.82, 0, 1)

island.rangeFS = col:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.rangeFS, 12, "medium")
island.rangeFS:SetPoint("LEFT", island.nameFS, "RIGHT", 6, 0)
island.rangeFS:SetTextColor(0.62, 0.62, 0.62, 1)

island.restTag = col:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.restTag, 11, "medium")
island.restTag:SetPoint("LEFT", island.rangeFS, "RIGHT", 8, 0)
island.restTag:SetTextColor(0.30, 0.61, 1.0, 1)
island.restTag:SetText("Resting")
island.restTag:SetAlpha(0)

island.pctFS = col:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.pctFS, 13, "bold")
island.pctFS:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, 0)
island.pctFS:SetJustifyH("RIGHT")
island.pctFS:SetTextColor(1, 1, 1, 1)

island.barsFS = col:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.barsFS, 11, "medium")
island.barsFS:SetPoint("RIGHT", island.pctFS, "LEFT", -8, 0)
island.barsFS:SetJustifyH("RIGHT")
island.barsFS:SetTextColor(0.62, 0.62, 0.62, 1)
island.barsFS:SetText("")

island.qpFS = col:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.qpFS, 12, "bold")
island.qpFS:SetPoint("RIGHT", island.barsFS, "LEFT", -8, 0)
island.qpFS:SetJustifyH("RIGHT")
island.qpFS:SetTextColor(1, 0.82, 0, 1)
island.qpFS:SetAlpha(0)

island.bar = ns.NewBar(col, 12)
island.bar.frame:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -19)
island.bar.frame:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, -19)

-- --- thin (Minimal) content: level chip, name, percent, optional items -----
local barFrame = island.bar.frame
-- the level chip sits OUTSIDE the bar, at the left end of the row (child of f)
local thinChip = CreateFrame("Frame", nil, f)
thinChip:SetFrameLevel((barFrame:GetFrameLevel() or 0) + 5)
thinChip.bg = thinChip:CreateTexture(nil, "BACKGROUND", nil, 0)
ns.Paint(thinChip.bg, 0, 0, 0, 0.4)
thinChip.bg:SetAllPoints(thinChip)
thinChip.border = {}
for i = 1, 4 do
    local t = thinChip:CreateTexture(nil, "BORDER", nil, 1)
    t:SetTexture(ns.Media.white)
    thinChip.border[i] = t
end
thinChip.text = thinChip:CreateFontString(nil, "OVERLAY")
ns.StyleText(thinChip.text, 11, "bold", "OUTLINE")
thinChip.text:SetPoint("CENTER", thinChip, "CENTER", 0, 0)
thinChip:Hide()
island.thinChip = thinChip

local function thinFS(justify, r, g, b)
    local t = barFrame:CreateFontString(nil, "OVERLAY")
    ns.StyleText(t, 11, "bold", "OUTLINE")
    t:SetJustifyH(justify or "LEFT")
    t:SetTextColor(r or 1, g or 1, b or 1, 1)
    t:Hide()
    return t
end
island.thinNameFS = thinFS("LEFT", 1, 1, 1)
island.thinPctFS = thinFS("RIGHT", 1, 1, 1)
island.thinBarsFS = thinFS("LEFT", 0.902, 0.902, 0.902)
island.thinGainFS = thinFS("LEFT", 1, 0.902, 0.502)
island.thinStreakFS = thinFS("LEFT", 1, 0.82, 0)
island.thinRestedFS = thinFS("LEFT", 0.549, 0.769, 1.0)
island.thinRateFS = thinFS("LEFT", 1, 0.902, 0.502)
island.thinEtaFS = thinFS("LEFT", 0.902, 0.902, 0.902)

function island:LayoutThinChipBorder(chip)
    local b = chip.border
    b[1]:ClearAllPoints(); b[1]:SetPoint("TOPLEFT", chip, "TOPLEFT", 0, 0); b[1]:SetPoint("TOPRIGHT", chip, "TOPRIGHT", 0, 0); b[1]:SetHeight(1)
    b[2]:ClearAllPoints(); b[2]:SetPoint("BOTTOMLEFT", chip, "BOTTOMLEFT", 0, 0); b[2]:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", 0, 0); b[2]:SetHeight(1)
    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPLEFT", chip, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMLEFT", chip, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(1)
    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPRIGHT", chip, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(1)
end

-- Rebuild the thin bar's text; called on data updates and while counting.
function island:UpdateThin(pct)
    local ok, err = pcall(function()
        if not self.thin then return end
        local d = self.data
        local p = ns.clamp(pct or (d and d.pct) or 0, 0, 1)
        local barF = self.bar.frame
        local th = ns.Theme()
        local ring = ns.HexA(th.ring)
        local gap = 6

        -- level chip OUTSIDE the bar, at the left end of the row, vertically centred
        local chip = self.thinChip
        local chipW = 0
        if ns.db.mLevel ~= false then
            chip.text:SetText(tostring((d and d.level) or UnitLevel("player") or "?"))
            chipW = math.max(20, (chip.text:GetStringWidth() or 10) + 8)
            chip:SetSize(chipW, 18)
            chip:ClearAllPoints(); chip:SetPoint("LEFT", f, "LEFT", 7, 0)
            for i = 1, 4 do chip.border[i]:SetVertexColor(ring[1], ring[2], ring[3], 1) end
            self:LayoutThinChipBorder(chip)
            chip:Show()
        else
            chip:Hide()
        end

        -- the bar starts 8px after the chip, and ends 7px from the right edge
        local barLeft = 7 + (chip:IsShown() and (chipW + 8) or 0)
        self._thinBarLeft = barLeft
        local inset = 5 + (self.thinBoost or 0) * (((ns.db and ns.db.strength) or 100) / 100)
        barF:ClearAllPoints()
        barF:SetPoint("TOPLEFT", f, "TOPLEFT", barLeft, -(inset))
        barF:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -7, (inset))
        local bw = barF:GetWidth() or 100
        local pad = 2

        -- left group inside the bar: name (white), then Resting (blue)
        local lx = pad
        local nameFS = self.thinNameFS
        if ns.db.mName ~= false then
            nameFS:SetText((d and d.name) or "")
            nameFS:SetTextColor(1, 1, 1, 1)
            nameFS:ClearAllPoints(); nameFS:SetPoint("LEFT", barF, "LEFT", lx, 0)
            nameFS:Show(); lx = lx + (nameFS:GetStringWidth() or 0) + gap
        else nameFS:Hide() end
        local restFS = self.thinRestedFS
        if ns.db.mRested ~= false and d and d.resting then
            restFS:SetText("Resting")
            restFS:SetTextColor(0.549, 0.769, 1.0, 1)
            restFS:ClearAllPoints(); restFS:SetPoint("LEFT", barF, "LEFT", lx, 0)
            restFS:Show(); lx = lx + (restFS:GetStringWidth() or 0) + gap
        else restFS:Hide() end

        -- right group, right to left: percent, bars, eta, rate, streak, gain
        local C_WHITE, C_LIGHT, C_WARM = { 1, 1, 1 }, { 0.902, 0.902, 0.902 }, { 1, 0.902, 0.502 }
        local items = {}
        if ns.db.mPct ~= false then
            items[#items + 1] = { key = "pct", fs = self.thinPctFS, text = ns.Percent(p, 0), col = C_WHITE }
        end
        if ns.db.mBars ~= false then
            local bars = math.max(0, math.ceil((1 - p) * 20))
            items[#items + 1] = { key = "bars", fs = self.thinBarsFS, text = bars .. " bars", col = C_LIGHT }
        end
        if ns.db.mEta then
            items[#items + 1] = { key = "eta", fs = self.thinEtaFS, col = C_LIGHT,
                text = (d and d.eta and d.eta ~= "--") and d.eta or "" }
        end
        if ns.db.mRate then
            items[#items + 1] = { key = "rate", fs = self.thinRateFS, col = C_WARM,
                text = (d and d.rate and d.rate ~= "--") and d.rate or "" }
        end
        if ns.db.mStreak ~= false then
            local active, n = ns.StreakActive()
            local sc = (n >= 8) and { 1, 0.416, 0.29 } or (n >= 5) and { 1, 0.604, 0.18 } or { 1, 0.82, 0 }
            items[#items + 1] = { key = "streak", fs = self.thinStreakFS, text = active and ("x" .. n) or "", col = sc }
        end
        if ns.db.mGain ~= false then
            items[#items + 1] = { key = "gain", fs = self.thinGainFS, text = self._thinGainText or "", col = C_WARM }
        end

        -- overflow: hide eta, then rate, then bars
        local function totalWidth()
            local t = 0
            for _, it in ipairs(items) do
                it.w = (it.text ~= "" and it.fs:GetStringWidth()) or 0
                if it.w > 0 then t = t + it.w + gap end
            end
            return t
        end
        local avail = bw - pad - lx
        local order = { "eta", "rate", "bars" }
        local oi = 1
        while totalWidth() > avail and oi <= #order do
            local k = order[oi]; oi = oi + 1
            for _, it in ipairs(items) do if it.key == k then it.text = "" end end
        end

        -- place from the right
        local rx = pad
        for _, it in ipairs(items) do
            if it.text ~= "" then
                it.fs:SetText(it.text)
                it.fs:SetTextColor(it.col[1], it.col[2], it.col[3], 1)
                it.fs:ClearAllPoints()
                it.fs:SetPoint("RIGHT", barF, "RIGHT", -rx, 0)
                it.fs:Show()
                rx = rx + (it.fs:GetStringWidth() or 0) + gap
            else
                it.fs:Hide()
            end
        end
    end)
    if not ok then ns.ReportError("island:UpdateThin", err) end
end

local THIN_BASE = 26
local THIN_POP = ns.cubicBezier(0.34, 1.45, 0.5, 1)
local THIN_SETTLE = ns.cubicBezier(0.34, 1.8, 0.5, 1)

local function strengthScale()
    return ((ns.db and ns.db.strength) or 100) / 100
end

function island:ThinBoostTo(target, dur, ease, absH)
    if self._thinBoostTween then ns.KillTween(self._thinBoostTween) end
    local from = self.thinBoost or 0
    self._thinBoostTween = ns.Tween({
        dur = dur, from = from, to = target, ease = ease,
        set = function(v)
            if not self.thin then return end
            self.thinBoost = v
            -- gain growth is strength-scaled; level-up uses a fixed height
            local h
            if absH then h = THIN_BASE + (absH - THIN_BASE) * v
            else h = THIN_BASE + 6 * v * strengthScale() end
            f:SetHeight(h)
            self:LayoutBorders()
            self:UpdateThin()
        end,
        done = function() self._thinBoostTween = nil; self.thinBoost = target end,
    })
end

-- Grow the thin island on a gain, hold, then ease back.
function island:ThinGain(amount)
    local ok, err = pcall(function()
        if not self.thin then return end
        self._thinGainText = (amount and amount > 0) and ("+" .. ns.Comma(amount) .. " XP") or "+XP"
        -- gain text slides/fades in over 0.4s
        if self._thinGainFade then ns.KillTween(self._thinGainFade) end
        self._thinGainAlpha = 0
        if self.thinGainFS then self.thinGainFS:SetAlpha(0) end
        self._thinGainFade = ns.Tween({
            dur = 0.4, from = 0, to = 1, ease = ns.easeOutCubic,
            set = function(v)
                self._thinGainAlpha = v
                if self.thinGainFS then self.thinGainFS:SetAlpha(v) end
            end,
            done = function() self._thinGainFade = nil; self._thinGainAlpha = 1 end,
        })
        self:ThinBoostTo(1, 0.3, THIN_POP)
        if self._thinHoldTimer then ns.CancelTimer(self._thinHoldTimer) end
        self._thinHoldTimer = ns.After(1.4, function()
            if not self.thin then return end
            self:ThinBoostTo(0, 0.4, ns.easeOutCubic)
            if self._thinGainClear then ns.CancelTimer(self._thinGainClear) end
            self._thinGainClear = ns.After(0.45, function()
                self._thinGainText = nil
                self:UpdateThin()
            end)
        end)
        -- percent pop (strength-scaled)
        if self.thinPctFS then
            if self._thinPctPop then ns.KillTween(self._thinPctPop) end
            local amp = 1 + 0.28 * strengthScale()
            self.thinPctFS:SetScale(amp)
            self._thinPctPop = ns.Tween({
                dur = 0.5, from = amp, to = 1.0, ease = THIN_SETTLE,
                set = function(v) self.thinPctFS:SetScale(v) end,
            })
        end
    end)
    if not ok then ns.ReportError("island:ThinGain", err) end
end

-- Thin level-up: grow to 38 for ~3s and pop the level chip.
function island:ThinLevelUp()
    local ok, err = pcall(function()
        if not self.thin then return end
        self:ThinBoostTo(1, 0.3, THIN_POP, 38)
        if self.thinChip then
            if self._thinChipPop then ns.KillTween(self._thinChipPop) end
            self.thinChip:SetScale(1.0)
            self._thinChipPop = ns.Tween({
                dur = 0.5, from = 1.0, to = 1.5, ease = THIN_POP,
                set = function(v) self.thinChip:SetScale(v) end,
                done = function()
                    self._thinChipPop = ns.Tween({
                        dur = 0.4, from = 1.5, to = 1.0, ease = ns.easeOutCubic,
                        set = function(v) self.thinChip:SetScale(v) end,
                    })
                end,
            })
        end
        if self._thinLUHold then ns.CancelTimer(self._thinLUHold) end
        self._thinLUHold = ns.After(3.0, function()
            if not self.thin then return end
            self:ThinBoostTo(0, 0.4, ns.easeOutCubic)
        end)
    end)
    if not ok then ns.ReportError("island:ThinLevelUp", err) end
end

-- "8 bars to level up" text for the collapsed row's first line.
function island:UpdateBarsText(pct)
    local ok, err = pcall(function()
        if not self.barsFS then return end
        if self.thin then self.barsFS:Hide(); return end
        local showBars = not (ns.db and ns.db.barsText == false)
        if showBars then
            local p = ns.clamp(pct or 0, 0, 1)
            local bars = math.max(0, math.ceil((1 - p) * 20))
            self.barsFS._long = (bars == 1) and "1 bar to level up" or (bars .. " bars to level up")
            self.barsFS._short = bars .. " bars"
            self.barsFS:SetText(self.barsFS._long)
            self.barsFS:Show()
        else
            self.barsFS:SetText("")
            self.barsFS:Hide()
        end

        -- fit: drop the range first, then shorten the bars text, then drop it
        local colW = self.col:GetWidth() or 0
        if colW <= 0 then return end
        local gap = 8
        local nameW = (self.nameFS:IsShown() and (self.nameFS:GetStringWidth() or 0)) or 0
        local pctW = (self.pctFS:IsShown() and (self.pctFS:GetStringWidth() or 0)) or 0
        local rangeW = 0
        if self.rangeFS:IsShown() and (self.rangeFS:GetStringWidth() or 0) > 0 then
            rangeW = (self.rangeFS:GetStringWidth() or 0) + 6
        end
        local restW = 0
        if self.restTag:IsShown() and (self.restTag:GetAlpha() or 0) > 0.05 then
            restW = (self.restTag:GetStringWidth() or 0) + 8
        end
        local qpW = 0
        if self.qpFS:IsShown() and (self.qpFS:GetAlpha() or 0) > 0.05 then
            qpW = (self.qpFS:GetStringWidth() or 0) + 8
        end
        local barsW = (showBars and (self.barsFS:GetStringWidth() or 0)) or 0
        local function over()
            return nameW + rangeW + restW + qpW + barsW + pctW + gap * 2 > colW
        end
        if over() then
            self.rangeFS:SetText("")
            rangeW = 0
            if over() and showBars then
                self.barsFS:SetText(self.barsFS._short)
                barsW = self.barsFS:GetStringWidth() or 0
            end
            if over() and showBars then
                self.barsFS:SetText("")
                self.barsFS:Hide()
            end
        end
    end)
    if not ok then ns.ReportError("island:UpdateBarsText", err) end
end

-- The bar drives the "cur / max" and percent text while a gain counts up.
island.bar.onTick = function(cur, max, pct, counting)
    local compact = ns.db and ns.db.compact
    if island.thin then
        island:UpdateThin(pct)
        if island.barsFS then island.barsFS:Hide() end
    else
        island.rangeFS:SetText(ns.Short(cur, compact) .. " / " .. ns.Short(max, compact))
        island.pctFS:SetText(ns.Percent(pct, 1))
        local th = ns.Theme()
        if counting then
            local g = ns.HexA(th.gold)
            island.pctFS:SetTextColor(g[1], g[2], g[3], 1)
        else
            island.pctFS:SetTextColor(1, 1, 1, 1)
        end
        island:UpdateBarsText(pct)
    end
end

-- --- divider + right block ------------------------------------------------
island.divider = tex("ARTWORK", 1)
ns.Paint(island.divider, 0.29, 0.23, 0.11, 1)
island.divider:SetSize(DIV_W, 30)

local rightBlock = CreateFrame("Frame", nil, f)
rightBlock:SetSize(RIGHT_MIN, 32)
island.rightBlock = rightBlock
island.rateFS = rightBlock:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.rateFS, 14, "bold")
island.rateFS:SetPoint("TOPRIGHT", rightBlock, "TOPRIGHT", 0, 0)
island.rateFS:SetJustifyH("RIGHT")
island.rateFS:SetTextColor(1, 0.82, 0, 1)
island.etaFS = rightBlock:CreateFontString(nil, "OVERLAY")
ns.StyleText(island.etaFS, 11, "medium")
island.etaFS:SetPoint("BOTTOMRIGHT", rightBlock, "BOTTOMRIGHT", 0, 0)
island.etaFS:SetJustifyH("RIGHT")
island.etaFS:SetTextColor(0.62, 0.62, 0.62, 1)

-- --- kill streak tag (parented to UIParent so the island's clipping does not
-- hide it under the island)
local streakTag = CreateFrame("Frame", nil, UIParent)
streakTag:SetPoint("TOP", f, "BOTTOM", 0, -8)
streakTag:SetHeight(20)
streakTag:SetFrameStrata("MEDIUM")
streakTag:SetFrameLevel((f:GetFrameLevel() or 0) + 6)
streakTag:Hide()
island.streakTag = streakTag
streakTag.bg = streakTag:CreateTexture(nil, "BACKGROUND", nil, 0)
ns.Paint(streakTag.bg, 0.051, 0.043, 0.031, 1)
streakTag.bg:SetAllPoints(streakTag)
streakTag.border = {}
for i = 1, 4 do
    local t = streakTag:CreateTexture(nil, "BORDER", nil, 1)
    t:SetTexture(ns.Media.white)
    t:SetVertexColor(1, 0.82, 0, 1)
    streakTag.border[i] = t
end
streakTag.label = streakTag:CreateFontString(nil, "OVERLAY")
ns.StyleText(streakTag.label, 14, "bold")
streakTag.label:SetPoint("CENTER", streakTag, "CENTER", 0, 0)
streakTag.track = streakTag:CreateTexture(nil, "BACKGROUND", nil, -1)
ns.Paint(streakTag.track, 0.133, 0.118, 0.098, 1)
streakTag.track:SetHeight(2)
streakTag.fill = streakTag:CreateTexture(nil, "ARTWORK", nil, 0)
streakTag.fill:SetHeight(2)

local STREAK_GOLD = ns.HexA("#FFD100")
local function streakColor(n)
    local tier = ns.StreakTier and ns.StreakTier(n)
    if tier and tier.color then return ns.HexA(tier.color) end
    return STREAK_GOLD
end

function island:LayoutStreakTag()
    local tag = self.streakTag
    if not tag then return end
    local b = tag.border
    b[1]:ClearAllPoints(); b[1]:SetPoint("TOPLEFT", tag, "TOPLEFT", 0, 0); b[1]:SetPoint("TOPRIGHT", tag, "TOPRIGHT", 0, 0); b[1]:SetHeight(1)
    b[2]:ClearAllPoints(); b[2]:SetPoint("BOTTOMLEFT", tag, "BOTTOMLEFT", 0, 0); b[2]:SetPoint("BOTTOMRIGHT", tag, "BOTTOMRIGHT", 0, 0); b[2]:SetHeight(1)
    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPLEFT", tag, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMLEFT", tag, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(1)
    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPRIGHT", tag, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMRIGHT", tag, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(1)
    tag.track:ClearAllPoints(); tag.track:SetPoint("TOPLEFT", tag, "BOTTOMLEFT", 0, -1); tag.track:SetPoint("TOPRIGHT", tag, "BOTTOMRIGHT", 0, -1)
    tag.fill:ClearAllPoints(); tag.fill:SetPoint("TOPLEFT", tag.track, "TOPLEFT", 0, 0)
end

function island:OnStreakKill()
    local s = ns.streak
    if not s or s.n < 2 then return end
    local tag = self.streakTag
    if self._streakPop then ns.KillTween(self._streakPop) end
    local amp = 1 + 0.4 * strengthScale()
    tag:SetScale(amp)
    self._streakPop = ns.Tween({
        dur = 0.5, from = amp, to = 1.0, ease = ns.cubicBezier(0.34, 1.8, 0.5, 1),
        set = function(v) tag:SetScale(v) end,
        done = function() self._streakPop = nil end,
    })
end

function island:UpdateStreak()
    local ok, err = pcall(function()
        local tag = self.streakTag
        if not tag then return end
        local on = (ns.db and ns.db.streak ~= false) and ((ns.db and ns.db.animations) ~= "Off")
        local active, n = ns.StreakActive()
        local key = ns.data and ns.data.ActiveKey and ns.data:ActiveKey()
        local lv = ns.levelUpUntil and GetTime() < ns.levelUpUntil
        local show = on and active and key == "xp" and not lv

        if not show then
            if tag:IsShown() and not self._streakFade then
                self._streakFade = true
                if self._streakFadeTween then ns.KillTween(self._streakFadeTween) end
                self._streakFadeTween = ns.Tween({
                    dur = 0.25, from = 1, to = 0, ease = ns.easeOutCubic,
                    set = function(v) tag:SetAlpha(v) end,
                    done = function()
                        tag:Hide(); tag:SetAlpha(1)
                        self._streakFade = false; self._streakFadeTween = nil
                    end,
                })
            end
            if self._streakBarSig ~= 0 and self.bar and self.bar.SetStreak then
                self._streakBarSig = 0
                self.bar:SetStreak(false, 0)
            end
            return
        end

        if self._streakFadeTween then ns.KillTween(self._streakFadeTween); self._streakFadeTween = nil end
        self._streakFade = false
        tag:SetAlpha(1)

        local col = streakColor(n)
        local tier = ns.StreakTier and ns.StreakTier(n)
        local title = tier and ((ns.StreakTitle and ns.StreakTitle(tier)) or tier.title)
        local base = title and (title .. "  x" .. n) or ("x" .. n)
        if ns.streak and ns.streak.newBest then base = base .. " - best!" end
        if tag._base ~= base then
            tag._base = base
            -- next-goal hint, appended only while it still fits comfortably
            local txt = base
            local nextTier = ns.NextStreakTier and ns.NextStreakTier(n)
            if nextTier then
                local nextTitle = (ns.StreakTitle and ns.StreakTitle(nextTier)) or nextTier.title
                if nextTitle then
                    local withHint = base .. "   " .. (nextTier.n - n) .. " more to " .. nextTitle
                    tag.label:SetText(withHint)
                    if (tag.label:GetStringWidth() or 0) <= 360 then txt = withHint end
                end
            end
            tag._txt = txt
            tag.label:SetText(txt)
            tag.label:SetTextColor(col[1], col[2], col[3], 1)
        end
        local w = (tag.label:GetStringWidth() or 40) + 16
        tag:SetWidth(w); tag:SetHeight(20)
        self:LayoutStreakTag()
        for i = 1, 4 do tag.border[i]:SetVertexColor(col[1], col[2], col[3], 1) end
        tag.fill:SetVertexColor(col[1], col[2], col[3], 1)
        local frac = ns.clamp(1 - (GetTime() - (ns.streak.lastAt or 0)) / 20, 0, 1)
        tag.fill:SetWidth(math.max(0, w * frac))
        if not tag:IsShown() then tag:Show() end

        if self._streakN ~= n then
            self._streakN = n
            self:OnStreakKill()
        end

        if self._streakBarSig ~= n and self.bar and self.bar.SetStreak then
            self._streakBarSig = n
            self.bar:SetStreak(true, n, col)
        end
    end)
    if not ok then ns.ReportError("island:UpdateStreak", err) end
end

-- --- geometry -------------------------------------------------------------
-- Bottom corner radius is fixed at 14 (CornerFill14 / CornerEdge14).
local CORNER = 14
function island:ApplyRadius(r, h)
    r = self.thin and 7 or CORNER

    for _, t in ipairs({ self.cornerFillBL, self.cornerFillBR, self.cornerEdgeBL, self.cornerEdgeBR }) do
        t:SetSize(r, r)
    end
    if not self._cornersSet then
        self._cornersSet = true
        self.cornerFillBL:SetTexture(ns.Media.cornerFill14)
        self.cornerFillBR:SetTexture(ns.Media.cornerFill14)
        self.cornerEdgeBL:SetTexture(ns.Media.cornerEdge14)
        self.cornerEdgeBR:SetTexture(ns.Media.cornerEdge14)
        -- mirror the right-hand corners horizontally
        self.cornerFillBR:SetTexCoord(1, 0, 0, 1)
        self.cornerEdgeBR:SetTexCoord(1, 0, 0, 1)
    end

    self.cornerFillBL:ClearAllPoints()
    self.cornerFillBL:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    self.cornerEdgeBL:ClearAllPoints()
    self.cornerEdgeBL:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    self.cornerFillBR:ClearAllPoints()
    self.cornerFillBR:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    self.cornerEdgeBR:ClearAllPoints()
    self.cornerEdgeBR:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    -- straight lower fill between the two corners
    self.betweenFill = self.betweenFill or tex("BACKGROUND", 0)
    self.betweenFill:ClearAllPoints()
    self.betweenFill:SetPoint("TOPLEFT", f, "TOPLEFT", r, -(h - r))
    self.betweenFill:SetPoint("TOPRIGHT", f, "TOPRIGHT", -r, -(h - r))
    self.betweenFill:SetHeight(r)
    local bg2 = ns.HexA(ns.Theme().bg2)
    ns.Paint(self.betweenFill, bg2[1], bg2[2], bg2[3], 1)
end

-- ---------------------------------------------------------------------------
-- Right block (divider + rate + eta).  Hidden when there is nothing to show,
-- and the centre column then extends to the island's right padding.
-- ---------------------------------------------------------------------------
local RIGHT_DUR = 0.5
local RIGHT_FADE = 0.3
local RIGHT_EASE = ns.cubicBezier(0.34, 1.45, 0.5, 1)

local function rightContent(d)
    if not d then return false end
    if d.key == "xp" then
        local s = ns.session
        local gain = (s and s.gain) or 0
        local elapsed = (s and s:Elapsed()) or 0
        -- need at least one gain and the first 60s count as "no rate"
        if gain <= 0 or elapsed < 60 then return false end
        if not d.rateValue then return false end
        -- hide again after five minutes with no new XP
        return (GetTime() - (island._gainAt or 0)) < 300
    end
    -- the pet bar runs the full width and has no right block
    if d.key == "pet" then return false end
    -- other types: show on a session gain or a real second-line text
    local gain = 0
    if d.key == "rep" then
        local rec = d.name and ns.repSession and ns.repSession[d.name]
        gain = (rec and rec.gained) or 0
    elseif d.key == "honor" then
        gain = (ns.honorSession and ns.honorSession.gained()) or 0
    end
    local hasEta = d.eta and d.eta ~= "" and d.eta ~= "--"
    local hasRate = d.rate and d.rate ~= "" and d.rate ~= "--"
    return gain ~= 0 or hasEta or hasRate
end

-- Position the divider and size the block from its measured width.
function island:ApplyRightGeometry()
    local bw = self.rightW or RIGHT_MIN
    if self.rightBlock then
        self.rightBlock:ClearAllPoints()
        self.rightBlock:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD_R, -14)
        self.rightBlock:SetWidth(bw)
    end
    if self.divider then
        self.divider:ClearAllPoints()
        self.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD_R + bw + RB_GAP + DIV_W), -15)
    end
end

-- Distance from the island's right edge to the centre column's right edge
-- while the block is shown: PAD_R + blockWidth + gap + divider + gap.
function island:RightShownInset()
    return PAD_R + (self.rightW or RIGHT_MIN) + RB_GAP + DIV_W + RB_GAP
end

-- Measure the block text; only when it changes, tween width + inset over 0.2s.
function island:UpdateRightSize()
    local ok, err = pcall(function()
        local rate = (self.rateFS and self.rateFS:GetText()) or ""
        local eta = (self.etaFS and self.etaFS:GetText()) or ""
        if rate == self._rightRate and eta == self._rightEta then return end
        self._rightRate, self._rightEta = rate, eta

        local wr = (self.rateFS and self.rateFS:GetStringWidth()) or 0
        local we = (self.etaFS and self.etaFS:GetStringWidth()) or 0
        local target = math.ceil(ns.clamp(math.max(wr, we), RIGHT_MIN, RIGHT_MAX))
        local from = self.rightW or target
        if self.rightWTween then ns.KillTween(self.rightWTween); self.rightWTween = nil end

        if math.abs(target - from) < 0.5 or (not ns.db) or ns.db.animations == "Off" then
            self.rightW = target
            self:ApplyRightGeometry()
            if self.rightShown then
                self.rightInset = self:RightShownInset()
                self:LayoutBorders()
            end
            return
        end

        self.rightW = from
        self.rightWTween = ns.Tween({
            dur = 0.2, from = from, to = target, ease = ns.easeOutCubic,
            set = function(v)
                self.rightW = v
                self:ApplyRightGeometry()
                if self.rightShown then
                    self.rightInset = self:RightShownInset()
                    self:LayoutBorders()
                end
            end,
            done = function()
                self.rightW = target
                self.rightWTween = nil
                self:ApplyRightGeometry()
                if self.rightShown then
                    self.rightInset = self:RightShownInset()
                    self:LayoutBorders()
                end
            end,
        })
    end)
    if not ok then ns.ReportError("island:UpdateRightSize", err) end
end

function island:SetRightAlpha(a)
    a = ns.clamp(a or 0, 0, 1)
    self.divider:SetAlpha(a)
    self.rightBlock:SetAlpha(a)
end

function island:ShowRight(shown)
    if shown then
        self.divider:Show()
        self.rightBlock:Show()
    else
        self.divider:Hide()
        self.rightBlock:Hide()
    end
end

function island:SetRightBlock(show)
    local ok, err = pcall(function()
        if self.thin then
            -- Classic display mode keeps hiding the right block
            self.rightShown = false
            self.rightInset = PAD_R
            self:ShowRight(false)
            self:SetRightAlpha(0)
            return
        end
        if self.rightShown == show and not self.rightAnimating then return end

        local instant = (not ns.db) or ns.db.animations == "Off" or self.rightShown == nil
        if self.rightSlideTween then ns.KillTween(self.rightSlideTween); self.rightSlideTween = nil end
        if self.rightFadeTween then ns.KillTween(self.rightFadeTween); self.rightFadeTween = nil end

        self.rightShown = show
        if instant then
            self.rightAnimating = false
            self.rightInset = show and self:RightShownInset() or PAD_R
            self:ShowRight(show)
            self:SetRightAlpha(show and 1 or 0)
            self:LayoutBorders()
            return
        end

        self.rightAnimating = true
        if show then
            self:ShowRight(true)
            self:SetRightAlpha(0)
            local from = self.rightInset or PAD_R
            self.rightFadeTween = ns.Tween({
                dur = RIGHT_FADE, from = 0, to = 1, ease = ns.easeOutCubic,
                set = function(a) self:SetRightAlpha(a) end,
                done = function() self.rightFadeTween = nil end,
            })
            self.rightSlideTween = ns.Tween({
                dur = RIGHT_DUR, from = 0, to = 1, ease = RIGHT_EASE,
                set = function(eased)
                    local to = self:RightShownInset()
                    self.rightInset = from + (to - from) * eased
                    self:LayoutBorders()
                end,
                done = function()
                    self.rightInset = self:RightShownInset()
                    self:LayoutBorders()
                    self.rightSlideTween = nil
                    self.rightAnimating = false
                end,
            })
        else
            self.rightFadeTween = ns.Tween({
                dur = RIGHT_FADE, from = 1, to = 0, ease = ns.easeOutCubic,
                set = function(a) self:SetRightAlpha(a) end,
                done = function()
                    self.rightFadeTween = nil
                    self:ShowRight(false)
                    local from = self.rightInset or self:RightShownInset()
                    self.rightSlideTween = ns.Tween({
                        dur = RIGHT_DUR, from = from, to = PAD_R, ease = RIGHT_EASE,
                        set = function(v) self.rightInset = v; self:LayoutBorders() end,
                        done = function() self.rightSlideTween = nil; self.rightAnimating = false end,
                    })
                end,
            })
        end
    end)
    if not ok then ns.ReportError("island:SetRightBlock", err) end
end

-- Thin-only pieces (level chip + the in-bar text row). Hidden whenever the
-- island is not in thin mode, so they cannot leak into the Full layout.
function island:HideThinPieces()
    for _, name in ipairs({ "thinNameFS", "thinPctFS", "thinBarsFS", "thinGainFS",
                            "thinStreakFS", "thinRestedFS", "thinRateFS", "thinEtaFS" }) do
        local fs = self[name]
        if fs then fs:Hide() end
    end
    if self.thinChip then self.thinChip:Hide() end
end

function island:LayoutBorders()
    local w, h = f:GetWidth(), f:GetHeight()
    local th = ns.Theme()
    local r = self.thin and 7 or CORNER
    local bw = th.bw

    -- body gradient (top area, up to where the rounded corners begin).
    -- The gradient itself is set in ApplyTheme; resizing just stretches it.
    self.bg:ClearAllPoints()
    self.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    self.bg:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    self.bg:SetHeight(math.max(1, h - r))

    -- left / right border strips
    self.borderL:ClearAllPoints()
    self.borderL:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    self.borderL:SetSize(bw, math.max(1, h - r))
    self.borderR:ClearAllPoints()
    self.borderR:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    self.borderR:SetSize(bw, math.max(1, h - r))

    self.innerL:ClearAllPoints()
    self.innerL:SetPoint("TOPLEFT", f, "TOPLEFT", bw, 0)
    self.innerL:SetSize(1, math.max(1, h - r))
    self.innerR:ClearAllPoints()
    self.innerR:SetPoint("TOPRIGHT", f, "TOPRIGHT", -bw, 0)
    self.innerR:SetSize(1, math.max(1, h - r))

    -- bottom straight border + inner line (between corners)
    self.borderB:ClearAllPoints()
    self.borderB:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", r, 0)
    self.borderB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -r, 0)
    self.borderB:SetHeight(bw)
    self.innerB:ClearAllPoints()
    self.innerB:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", r, bw)
    self.innerB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -r, bw)
    self.innerB:SetHeight(1)

    -- thin shadow (shown only in the thin Minimal strip)
    self.thinShadow:ClearAllPoints()
    self.thinShadow:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -6, 2)
    self.thinShadow:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 6, 2)
    self.thinShadow:SetHeight(12)

    -- element anchors
    self.badge:ClearAllPoints()
    self.badge:SetPoint("CENTER", f, "TOPLEFT", PAD_L + BADGE / 2, -(C_H / 2))
    if self.thin then
        self.badge:Hide()
    else
        self.badge:Show()
    end

    -- right block: divider + block, sized from the measured text width
    self:ApplyRightGeometry()

    if self.thin then
        -- Classic mode always hides the right block and uses the thin row.
        self.rightInset = PAD_R
        self.divider:Hide()
        self.rightBlock:Hide()
        self.col:ClearAllPoints()
        self.col:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -1)
        self.col:SetPoint("TOPRIGHT", f, "TOPRIGHT", -7, -1)
        self.col:SetHeight(THIN_H - 2)
        self.nameFS:Hide(); self.rangeFS:Hide(); self.pctFS:Hide()
        self.qpFS:Hide(); self.restTag:Hide(); self.barsFS:Hide()
        -- no trim in thin mode: a plain dark rounded strip with a soft shadow
        self.borderL:Hide(); self.borderR:Hide(); self.borderB:Hide()
        self.innerL:Hide(); self.innerR:Hide(); self.innerB:Hide()
        self.thinShadow:Show()
        self.bar:SetThinBorder(false)
        -- side padding 7, vertical 5 (bar 16px at the 26px idle height and
        -- 16 + 4*strength during a gain); bar starts after the level chip
        local inset = 5 + (self.thinBoost or 0) * strengthScale()
        local barLeft = self._thinBarLeft or 7
        self.bar.frame:ClearAllPoints()
        self.bar.frame:SetPoint("TOPLEFT", f, "TOPLEFT", barLeft, -(inset))
        self.bar.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -7, (inset))
        self.bar:ShowThinText(false)
        self:UpdateThin()
    else
        self.col:ClearAllPoints()
        self.col:SetPoint("TOPLEFT", f, "TOPLEFT", CENTER_LEFT, -15)
        -- the right inset shrinks the centre column only while the block shows
        self.col:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(self.rightInset or PAD_R), -15)
        self.col:SetHeight(31)
        if ns.db.showName ~= false then self.nameFS:Show() else self.nameFS:Hide() end
        if ns.db.showRange ~= false then self.rangeFS:Show() else self.rangeFS:Hide() end
        if ns.db.showPercent ~= false then self.pctFS:Show() else self.pctFS:Hide() end
        self.barsFS:Show()
        self.borderL:Show(); self.borderR:Show(); self.borderB:Show()
        self.innerL:Show(); self.innerR:Show(); self.innerB:Show()
        self.thinShadow:Hide()
        self:HideThinPieces()
        self.bar:SetThinBorder(true)
        self.bar.frame:ClearAllPoints()
        self.bar.frame:SetPoint("TOPLEFT", self.col, "TOPLEFT", 0, -19)
        self.bar.frame:SetPoint("TOPRIGHT", self.col, "TOPRIGHT", 0, -19)
        self.bar:ShowThinText(false)
    end

    self:ApplyRadius(r, h)

    -- Minimal (thin) bar: no island background while collapsed and not hovered.
    -- The XP bar keeps its own backing; hovering (or expanding) restores it.
    local showBg = (not self.thin) or self.mouseOver
    if self.bg then
        if showBg then self.bg:Show() else self.bg:Hide() end
    end
    for _, t in ipairs({ self.cornerFillBL, self.cornerFillBR, self.cornerEdgeBL, self.cornerEdgeBR }) do
        if showBg then t:Show() else t:Hide() end
    end
    if self.betweenFill then
        if showBg then self.betweenFill:Show() else self.betweenFill:Hide() end
    end
end

function island:ApplyTheme()
    local th = ns.Theme()
    local trim = ns.HexA(th.trim)
    local inner = ns.HexA(th.inner or "#2A1F0E")

    for _, t in ipairs({ self.borderL, self.borderR, self.borderB }) do
        ns.Paint(t, trim[1], trim[2], trim[3], 1)
    end
    for _, t in ipairs({ self.cornerEdgeBL, self.cornerEdgeBR }) do
        t:SetVertexColor(trim[1], trim[2], trim[3], 1)
    end
    for _, t in ipairs({ self.innerL, self.innerR, self.innerB }) do
        ns.Paint(t, inner[1], inner[2], inner[3], 1)
    end
    local bg2 = ns.HexA(th.bg2)
    self.cornerFillBL:SetVertexColor(bg2[1], bg2[2], bg2[3], 1)
    self.cornerFillBR:SetVertexColor(bg2[1], bg2[2], bg2[3], 1)
    if self.betweenFill then ns.Paint(self.betweenFill, bg2[1], bg2[2], bg2[3], 1) end

    -- body background gradient (set once; the texture stretches as it resizes)
    ns.WhiteTexture(self.bg)
    -- this client's VERTICAL gradient takes the first colour at the bottom, so
    -- pass bg2 (bottom) first and bg1 (top) last.  The rounded corners and the
    -- straight strip are filled with bg2, so the gradient meets them cleanly.
    ns.Gradient(self.bg, bg2, ns.HexA(th.bg1), false)
    if self.bg.SetTexelSnappingBias then pcall(self.bg.SetTexelSnappingBias, self.bg, 0) end
    if self.bg.SetSnapToPixelGrid then pcall(self.bg.SetSnapToPixelGrid, self.bg, false) end

    local ring = ns.HexA(th.ring)
    for i = 1, 4 do self.badgeRing[i]:SetVertexColor(ring[1], ring[2], ring[3], 1) end
    self.miniRing:SetVertexColor(ring[1], ring[2], ring[3], 1)
    local gold = ns.HexA(th.gold)
    for _, t in ipairs({ self.nameFS, self.badgeText, self.miniText, self.rateFS, self.qpFS }) do
        t:SetTextColor(gold[1], gold[2], gold[3], 1)
    end
    self.pctFS:SetTextColor(1, 1, 1, 1)
    local dim = ns.HexA(th.dim or "#9D9D9D")
    self.rangeFS:SetTextColor(dim[1], dim[2], dim[3], 1)
    self.etaFS:SetTextColor(dim[1], dim[2], dim[3], 1)
    local rest = ns.HexA(th.restTag or "#4D9BFF")
    self.restTag:SetTextColor(rest[1], rest[2], rest[3], 1)

    ns.StyleText(self.nameFS, 12, "extrabold")
    ns.StyleText(self.rangeFS, 12, "medium")
    ns.StyleText(self.pctFS, 13, "bold")
    ns.StyleText(self.badgeText, 17, "bold")
    ns.StyleText(self.rateFS, 14, "bold")
    ns.StyleText(self.etaFS, 11, "medium")

    if self.bar and self.bar.ApplyTheme then self.bar:ApplyTheme(th) end

    self:LayoutBorders()
end

-- ---------------------------------------------------------------------------
-- Portrait vs plain level circle
-- ---------------------------------------------------------------------------
function island:ApplyPortrait()
    local key = (self.data and self.data.key) or (ns.data and ns.data:ActiveKey())
    local unit = (key == "pet") and "pet" or "player"
    local canPortrait = (type(_G.SetPortraitTexture) == "function")
        or (self.portrait.SetPortraitTexture ~= nil)
    local show = ns.db and ns.db.portrait and canPortrait
        and ns.API.UnitExists and ns.API.UnitExists(unit)

    if show then
        if type(_G.SetPortraitTexture) == "function" then
            pcall(_G.SetPortraitTexture, self.portrait, unit)
        else
            pcall(self.portrait.SetPortraitTexture, self.portrait, unit)
        end
        self.portrait:Show()
        self.badgeText:Hide()
        self.mini:Show()
    else
        self.portrait:Hide()
        self.badgeText:Show()
        self.mini:Hide()
    end
end

-- Slide the small level badge number when the level changes.
function island:RollLevel(level)
    level = tonumber(level) or level
    if self.levelShown == nil then
        self.levelShown = level
        self.miniText:SetText(tostring(level))
        return
    end
    if self.levelShown == level then
        self.miniText:SetText(tostring(level))
        return
    end
    local old = self.levelShown
    self.levelShown = level
    self.miniTextOld:SetText(tostring(old))
    self.miniText:SetText(tostring(level))
    self.miniTextOld:SetAlpha(1)
    self.miniText:SetAlpha(0)
    self.miniTextOld:ClearAllPoints()
    self.miniTextOld:SetPoint("CENTER", self.mini, "CENTER", 0, 0)
    self.miniText:ClearAllPoints()
    self.miniText:SetPoint("CENTER", self.mini, "CENTER", 0, -10)
    if self.levelRoll then ns.KillTween(self.levelRoll) end
    self.levelRoll = ns.Tween({
        dur = 0.5, from = 0, to = 1, ease = ns.easeOutBack,
        set = function(_, p)
            self.miniTextOld:SetAlpha(1 - p)
            self.miniTextOld:ClearAllPoints()
            self.miniTextOld:SetPoint("CENTER", self.mini, "CENTER", 0, 10 * p)
            self.miniText:SetAlpha(p)
            self.miniText:ClearAllPoints()
            self.miniText:SetPoint("CENTER", self.mini, "CENTER", 0, -10 * (1 - p))
        end,
    })
end

-- ---------------------------------------------------------------------------
-- Data update
-- ---------------------------------------------------------------------------
function island:UpdateMoveOutline()
    local on = ns.db and ns.db.move
    local o = self.moveOutline
    for i = 1, 4 do
        if on then o[i]:Show() else o[i]:Hide() end
    end
    if not on then return end
    o[1]:ClearAllPoints(); o[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    o[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); o[1]:SetHeight(2)
    o[2]:ClearAllPoints(); o[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    o[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); o[2]:SetHeight(2)
    o[3]:ClearAllPoints(); o[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    o[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); o[3]:SetWidth(2)
    o[4]:ClearAllPoints(); o[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    o[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); o[4]:SetWidth(2)
end

-- Throttle refreshes to at most ten per second, coalescing the newest data.
local UPDATE_INTERVAL = 0.1
function island:Update(d)
    if not d then return end
    local now = GetTime()
    if self._lastUpdate and (now - self._lastUpdate) < UPDATE_INTERVAL then
        self._pendingData = d
        if not self._pendingUpdate then
            self._pendingUpdate = ns.After(UPDATE_INTERVAL, function()
                self._pendingUpdate = nil
                local pd = self._pendingData
                self._pendingData = nil
                if pd then self:UpdateNow(pd) end
            end)
        end
        return
    end
    self:UpdateNow(d)
end

function island:UpdateNow(d)
    if not d then return end
    self._lastUpdate = GetTime()
    self.data = d

    -- remember when XP last increased (the right block hides after 5 minutes)
    local gain = (ns.session and ns.session.gain) or 0
    if gain > (self._seenGain or 0) then self._gainAt = GetTime() end
    self._seenGain = gain

    -- /xpbar testxp fakes a gain for a few seconds without changing real XP
    local fake = ns.barFake
    if fake and d.key == "xp" and fake.expires > GetTime() then
        d.cur = fake.cur
        d.max = fake.max
        d.pct = fake.pct
    end

    self.badgeText:SetText(d.badge or "?")
    ns.StyleText(self.badgeText, 17, "bold")
    self:ApplyPortrait()
    if d.level then
        self:RollLevel(d.level)
    else
        self.miniText:SetText(tostring(d.badge or ""))
    end

    -- a hovered completed quest previews only that quest's ghost segment
    local qp = ns.questPreview
    if d.key == "xp" and qp then
        local remaining = math.max(0, (d.max or 1) - (d.cur or 0))
        d.questTotal = qp.xp or 0
        d.ghostPct = math.min(qp.xp or 0, remaining) / (d.max or 1)
    end

    local counting = (d.key == "xp" and self.bar.animating)
    if d.key == "xp" then
        self.nameFS:SetText(d.name or "Experience")
        ns.StyleText(self.nameFS, 12, "extrabold")
        if not counting then
            self.rangeFS:SetText(ns.Short(d.cur, ns.db.compact) .. " / " .. ns.Short(d.max, ns.db.compact))
        end
    else
        self.nameFS:SetText(d.name or d.label or "")
        ns.StyleText(self.nameFS, 12, "extrabold")
        -- a bar with no data right now (no watched faction, no pet) shows its
        -- short note in the range slot instead of a blank
        self.rangeFS:SetText(d.available == false and (d.note or "") or "")
    end
    if not counting then
        self.pctFS:SetText(ns.Percent(d.pct, (d.key == "xp") and 1 or 0))
    end
    -- never show a placeholder dash in the right block
    self.rateFS:SetText((d.rate and d.rate ~= "--") and d.rate or "")
    self.etaFS:SetText((d.eta and d.eta ~= "--") and d.eta or "")
    self:UpdateRightSize()
    self:SetRightBlock((ns.db.showRate ~= false) and rightContent(d))
    self.qpFS:SetText((d.questTotal and d.questTotal > 0) and ("+" .. ns.Comma(d.questTotal) .. " XP") or "")
    self.qpFS:SetAlpha((d.key == "xp" and d.questTotal and d.questTotal > 0) and 1 or 0)
    self.restTag:SetAlpha((ns.db.showRested ~= false and d.key == "xp" and d.resting) and 1 or 0)
    if d.key == "xp" then self:UpdateBarsText(d.pct) end

    self:UpdateMoveOutline()

    -- party markers on the main bar (xp only, members at your level)
    local markers = {}
    if d.key == "xp" and ns.db.party and ns.db.showDots ~= false then
        local mine = d.level or 0
        for _, m in ipairs(ns.comms:List()) do
            if m.level == mine and m.xpMax and m.xpMax > 0 then
                markers[#markers + 1] = { class = m.class, pct = m.xp / m.xpMax }
            end
        end
    end
    d.party = markers

    self.bar:SetData(d)

    -- thin gain reaction: grow when a gain animation starts
    local wasAnim = self._thinAnimating
    self._thinAnimating = self.bar.animating
    if self.bar.animating and not wasAnim and (not ns.db or ns.db.dip ~= false) then
        self._dipAt = GetTime()
    end
    if self.thin and self.bar.animating and not wasAnim then
        local amt = (d.cur or 0) - (self._thinLastCur or d.cur or 0)
        self:ThinGain(amt)
    end
    self._thinLastCur = d.cur

    -- thin level-up reaction
    local luActive = ns.levelUpUntil and GetTime() < ns.levelUpUntil
    if self.thin and luActive and not self._thinLU then
        self._thinLU = true
        self:ThinLevelUp()
    elseif not luActive then
        self._thinLU = false
    end

    if self.thin then self:UpdateThin() end

    if ns.panel and ns.panel.Update then ns.panel:Update(d) end

    -- grow/shrink the open panel to fit its content (e.g. party rows appear),
    -- but never while an open/close or peek tween is running
    if self.expanded and not self.tween and not self.peekTween
        and ns.panel and ns.panel.NeededHeight then
        local ph = ns.panel:NeededHeight()
        if ph and math.abs((f:GetHeight() or 0) - ph) > 1 then
            f:SetHeight(ph)
            self:LayoutBorders()
        end
    end

    if ns.Tooltip then ns.Tooltip:Update(d) end
    self:UpdateFade()
end

-- ---------------------------------------------------------------------------
-- Open / close tween
-- ---------------------------------------------------------------------------
function island:TargetWidth(open)
    local w = (ns.db and ns.db.width) or C_W
    return open and math.max(620, w + 160) or w
end

function island:TargetSize(open)
    local w = self:TargetWidth(open)
    local th = (ns.db and ns.db.barThickness) or 12
    if open then
        local ph = (ns.panel and ns.panel.NeededHeight and ns.panel:NeededHeight()) or 268
        return w, ph
    end
    if (ns.db.mode == "Classic") then
        return w, THIN_H
    end
    return w, math.max(60, 48 + th)
end

function island:ApplyThickness()
    local th = (ns.db and ns.db.barThickness) or 12
    if self.bar then
        self.bar.height = th
        if self.bar.frame then self.bar.frame:SetHeight(th) end
    end
end

function island:AnimateTo(open)
    local ok, err = pcall(function()
        -- thin only while collapsed in Classic mode, so the bar never stretches
        -- to the expanded panel height
        self.thin = (ns.db.mode == "Classic") and not open
        local toW, toH = self:TargetSize(open)
        -- start from the current size, so a new tween mid-flight never jumps
        local fromW, fromH = f:GetWidth(), f:GetHeight()
        if fromH <= 1 then fromH = C_H end
        local feel = FEEL[ns.db.feel] or FEEL.Springy
        local instant = (ns.db.animations == "Off")

        if self.tween then ns.KillTween(self.tween); self.tween = nil end

        if open and ns.panel then
            ns.panel:ShowPanel()
            ns.panel:PlayIntro()
        elseif ns.panel then
            -- details hide instantly when collapsing
            ns.panel:HidePanel()
        end

        if instant then
            f:SetSize(toW, toH)
            self:LayoutBorders()
            if ns.panel then
                ns.panel:Layout(self.data)
                ns.panel:ResetGroups()
            end
            return
        end

        local function lerp(a, b, t) return a + (b - a) * t end
        self.tween = ns.Tween({
            dur = feel.dur,
            from = 0, to = 1,
            ease = feel.ease,
            -- `eased` is the cubic-bezier output (it overshoots ~8%, then settles)
            set = function(eased)
                local sok, serr = pcall(function()
                    -- sub-pixel sizes keep the motion smooth (no 1px stepping)
                    f:SetSize(lerp(fromW, toW, eased), lerp(fromH, toH, eased))
                    self:LayoutBorders()
                    if ns.panel then ns.panel:Reflow() end
                end)
                if not sok then ns.ReportError("island:AnimateTo.set", serr) end
            end,
            done = function()
                self.tween = nil
                -- redraw the sparkline once, now that the final width is known
                if ns.panel then ns.panel:DrawSpark(ns.xp().samples) end
            end,
        })
    end)
    if not ok then ns.ReportError("island:AnimateTo", err) end
end

function island:SetOpen(open, reason)
    if open then self.openReasons[reason or "manual"] = true
    else self.openReasons[reason or "manual"] = nil end
    local shouldOpen = self:Pinned() or next(self.openReasons) ~= nil
    if shouldOpen ~= self.expanded then
        self.expanded = shouldOpen
        self:AnimateTo(shouldOpen)
    end
    if self.bar then self.bar:SetExpanded(self.expanded) end
    self:UpdateFade()
end

function island:Pinned()
    return self.pinned or (ns.db.mode == "Always open")
end

function island:TogglePin()
    self.pinned = not self.pinned
    self.openReasons.pin = nil
    if self.pinned then
        self:SetOpen(true, "pin")
    elseif self.mouseOver and ns.db.hoverExpand then
        -- unpinning returns to hover behaviour: stay open while the mouse is
        -- over the island, then close on leave
        self.openReasons.peek = nil
        self:SetOpen(true, "hover")
    else
        self.openReasons.hover = nil
        self.openReasons.peek = nil
        self:SetOpen(false, "pin")
    end
    if ns.panel and ns.panel.RefreshPin then ns.panel:RefreshPin() end
end

function island:Peek()
    local ok, err = pcall(function()
        if ns.db.mode == "Always open" then return end
        if ns.db.hideCombat and ns.inCombat then return end
        if not ns.db.hoverExpand then return end
        if self.expanded then return end
        local feel = FEEL[ns.db.feel] or FEEL.Springy
        local base = (ns.db and ns.db.width) or C_W
        if self.peekTween then ns.KillTween(self.peekTween); self.peekTween = nil end
        -- widen by 60 on the Motion feel curve, then settle back to the
        -- configured width
        self.peekTween = ns.Tween({
            dur = feel.dur, from = f:GetWidth(), to = base + 60, ease = feel.ease,
            set = function(v)
                if self.expanded then return end
                local sok, serr = pcall(function()
                    f:SetWidth(v)
                    self:LayoutBorders()
                    if ns.panel then ns.panel:Reflow() end
                end)
                if not sok then ns.ReportError("island:Peek.set", serr) end
            end,
        })
        if self.peekTimer then ns.CancelTimer(self.peekTimer) end
        self.peekTimer = ns.After(1.8, function()
            if self.expanded then return end
            -- hold 1.8s, then settle back over 0.3s
            self.peekTween = ns.Tween({
                dur = 0.3, from = f:GetWidth(), to = base, ease = ns.easeOutCubic,
                set = function(v)
                    if self.expanded then return end
                    local sok, serr = pcall(function()
                        f:SetWidth(v)
                        self:LayoutBorders()
                    end)
                    if not sok then ns.ReportError("island:Peek.return", serr) end
                end,
                done = function() self.peekTween = nil end,
            })
        end)
    end)
    if not ok then ns.ReportError("island:Peek", err) end
end

-- ---------------------------------------------------------------------------
-- Fade / combat / mode
-- ---------------------------------------------------------------------------
local COMBAT_FADE = 0.25

function island:StopCombatFade()
    if self._combatFadeTween then ns.KillTween(self._combatFadeTween); self._combatFadeTween = nil end
    self._combatFadeTo = nil
end

function island:SetCombatFade(target)
    if self._combatFadeTween then
        if self._combatFadeTo == target then return end
        ns.KillTween(self._combatFadeTween)
        self._combatFadeTween = nil
    end
    self._combatFadeTo = target
    local from = f:GetAlpha() or 0
    if (ns.db.animations == "Off") or math.abs(from - target) < 0.001 then
        f:SetAlpha(target)
        return
    end
    self._combatFadeTween = ns.Tween({
        dur = COMBAT_FADE, from = from, to = target, ease = ns.easeOutCubic,
        set = function(v) f:SetAlpha(v) end,
        done = function()
            f:SetAlpha(target)
            self._combatFadeTween = nil
        end,
    })
end

function island:UpdateFade()
    if not ns.db.enabled then
        self:StopCombatFade()
        f:SetAlpha(0)
        f:EnableMouse(false)
        return
    end
    f:EnableMouse(true)

    -- while the settings panel is open the island stays visible and collapsed
    if self.previewOpen then
        self:StopCombatFade()
        f:SetAlpha(1)
        if self.hoverStrip then self.hoverStrip:Hide() end
        return
    end

    if ns.db.hideCombat and ns.inCombat then
        self:SetCombatFade(0)
        return
    end

    -- "Hide out of combat": fade away while relaxed, fade back in when fighting
    if ns.db.hideOutOfCombat then
        f:EnableMouse(ns.inCombat)
        self:SetCombatFade(ns.inCombat and 1 or 0)
        return
    end
    self:StopCombatFade()

    -- Auto-hide: slide the island up off the top edge; a thin strip brings it back
    local hy = (ns.db.mode == "Auto-hide" and not self.expanded) and 60 or 0
    if hy ~= self.hiddenY then
        self.hiddenY = hy
        self:ApplyPosition()
    end

    if ns.db.mode == "Auto-hide" and not self.expanded then
        f:SetAlpha(0)
        if self.hoverStrip then self.hoverStrip:Show() end
        return
    end
    if self.hoverStrip then self.hoverStrip:Hide() end

    -- "Fade until hovered": faint while the mouse is away and the island is
    -- collapsed; full alpha on hover or while the panel is open.
    local dim = ns.db.fade and not self.mouseOver and not self.expanded
    local base = dim and FADE_ALPHA or 1
    -- "Hide in combat" restores smoothly once the fight is over
    if ns.db.hideCombat then
        self:SetCombatFade(base)
        return
    end
    f:SetAlpha(base)
end

-- The island's only scale is the Size setting.  The gain dip is a translate
-- (see the island OnUpdate), so the island never changes size while playing.
function island:CurrentScale()
    return ((ns.db and ns.db.scale) or 100) / 100
end

function island:ApplyScale(force)
    local sc = self:CurrentScale()
    if force or math.abs((self._appliedScale or -1) - sc) > 0.0001 then
        self._appliedScale = sc
        f:SetScale(sc)
    end
end

function island:SetScale()
    self._appliedScale = nil
    self:ApplyScale(true)
end

function island:ApplyPosition()
    local off = (ns.db.posX or 0) + (ns.db.posOffset or 0) + (self._shakeX or 0)
    local offY = (ns.db.posY or 0) + (self.hiddenY or 0) + (self._dipY or 0) + (self._shakeY or 0)
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", off, offY)
end

-- One clean-up pass when the Display mode (or preset) changes: stop every
-- running growth tween, put the thin-only pieces away, bring the Full pieces
-- back, restore the bar/trim/radius for the mode, and reset the scale.
function island:ResetLayoutState()
    local ok, err = pcall(function()
        -- cancel every running thin-gain / level-up tween and timer
        for _, k in ipairs({ "_thinBoostTween", "_thinGainFade", "_thinPctPop", "_thinChipPop" }) do
            if self[k] then ns.KillTween(self[k]); self[k] = nil end
        end
        for _, k in ipairs({ "_thinHoldTimer", "_thinGainClear", "_thinLUHold" }) do
            if self[k] then ns.CancelTimer(self[k]); self[k] = nil end
        end
        -- while collapsed, stop any in-flight size tweens so one SetSize wins
        if not self.expanded then
            if self.tween then ns.KillTween(self.tween); self.tween = nil end
            if self.peekTween then ns.KillTween(self.peekTween); self.peekTween = nil end
            if self.peekTimer then ns.CancelTimer(self.peekTimer); self.peekTimer = nil end
        end
        self.thinBoost = 0
        self._thinGainText = nil
        self._thinGainAlpha = nil
        if self.thinChip then self.thinChip:SetScale(1) end
        if self.thinPctFS then self.thinPctFS:SetScale(1) end

        -- idle size for the current mode
        local th = (ns.db and ns.db.barThickness) or 12
        if self.thin then
            self.bar.height = 16
        else
            self.bar.height = th
            if self.bar.frame then self.bar.frame:SetHeight(th) end
        end
        if not self.expanded then
            local w, h = self:TargetSize(false)
            f:SetSize(w, h)
        end

        -- thin-only pieces are visible only while self.thin
        if not self.thin then
            self:HideThinPieces()
            self:ApplyPortrait()
        end
        if self.thinShadow then
            if self.thin then self.thinShadow:Show() else self.thinShadow:Hide() end
        end

        self._dipUntil = nil
        self._dipAt = nil
        self._dipY = 0
        self:ApplyPosition()
        -- LayoutBorders re-shows the Full pieces (name/range/bars/percent, trim,
        -- corners, bar ring) and, in thin mode, UpdateThin shows the thin row
        self:LayoutBorders()

        if not self.thin and self.SetRightBlock then
            local d = self.data or (ns.data and ns.data:Current())
            self:SetRightBlock((ns.db and ns.db.showRate ~= false) and rightContent(d))
        end

        self._appliedScale = nil
        self:ApplyScale(true)
    end)
    if not ok then ns.ReportError("island:ResetLayoutState", err) end
end

function island:ApplyMode()
    if self._applyingMode then return end
    self._applyingMode = true
    local ok, err = pcall(function()
        self.thin = (ns.db.mode == "Classic") and not self.expanded
        if ns.db.mode == "Always open" then
            self.autoPinned = true
            self.pinned = true
            if not self.expanded then self:SetOpen(true, "mode") end
        else
            if self.autoPinned then
                self.pinned = false
                self.autoPinned = false
            end
            self.openReasons.mode = nil
            if self.expanded and not self.pinned and not next(self.openReasons) then
                self:SetOpen(false, "mode")
            end
        end
        self:ResetLayoutState()
        if self.bar then self.bar:SetExpanded(self.expanded) end
    end)
    self._applyingMode = false
    if not ok then ns.ReportError("island:ApplyMode", err) end
end

-- ---------------------------------------------------------------------------
-- Hover strip for Auto-hide
-- ---------------------------------------------------------------------------
local strip = CreateFrame("Frame", nil, UIParent)
strip:SetPoint("TOP", UIParent, "TOP", 0, 0)
strip:SetSize(C_W, 18)
strip:EnableMouse(true)
strip:Hide()
island.hoverStrip = strip
strip:SetScript("OnEnter", function() island:SetOpen(true, "hover") end)

-- ---------------------------------------------------------------------------
-- Mouse handling
-- ---------------------------------------------------------------------------
local dragging, dragStartX, dragStartY, dragStartPosX, dragStartPosY

-- Hover handling.  A plain OnLeave would fire whenever the mouse moves onto a
-- child frame (a chip or the gear), collapsing the island mid-hover.  When the
-- client supports IsMouseOver we poll it (it reports the frame and its
-- children); otherwise we fall back to the enter/leave pair.
function island:SetHover(over)
    if over == self.mouseOver then return end
    self.mouseOver = over
    if over then
        if ns.db.hoverExpand or ns.db.mode == "Always open" then
            self:SetOpen(true, "hover")
        elseif ns.Tooltip then
            ns.Tooltip:Show(self.data)
        end
    else
        if not self.pinned then
            self:SetOpen(false, "hover")
            self.openReasons.peek = nil
        end
        if ns.Tooltip then ns.Tooltip:Hide() end
    end
    self:UpdateFade()
    -- thin (Classic) bar toggles its island background with hover
    if ns.db.mode == "Classic" then self:LayoutBorders() end
end

local canPoll = type(f.IsMouseOver) == "function"
if not canPoll then
    f:SetScript("OnEnter", function() island:SetHover(true) end)
    f:SetScript("OnLeave", function() island:SetHover(false) end)
end

f:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then return end
    if ns.db.move then
        dragging = true
        dragStartX, dragStartY = GetCursorPosition()
        dragStartPosX = ns.db.posX or 0
        dragStartPosY = ns.db.posY or 0
    end
end)

f:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
        return
    end
    if dragging then
        dragging = false
        return
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
        ns.Share()
    elseif button == "LeftButton" then
        island:TogglePin()
    end
end)

f:SetScript("OnUpdate", function(_, elapsed)
    if not ns.db then return end
    if canPoll then
        local over = f:IsMouseOver()
        if not over and ns.Tooltip and ns.Tooltip.shown and ns.Tooltip.frame then
            over = ns.Tooltip.frame:IsMouseOver()
        end
        island:SetHover(over)
    end

    if dragging and ns.db.move then
        local cx, cy = GetCursorPosition()
        local scale = f:GetEffectiveScale() or 1
        -- free 2D placement: X to the right, Y up (the top anchor offset grows
        -- upward, and the cursor's Y grows upward too)
        ns.db.posX = dragStartPosX + (cx - dragStartX) / scale
        ns.db.posY = dragStartPosY + (cy - dragStartY) / scale
        island:ApplyPosition()
    end

    -- rested / quest pulse
    local anim = ns.db.animations
    local pulseAllowed = (anim == "Always") or (anim == "On hover only" and island.expanded)
    local alpha
    if anim == "Off" or not pulseAllowed then
        alpha = 0.70
    else
        alpha = 0.70 + 0.15 * math.sin(ns.animClock * (math.pi * 2 / 1.2))
    end
    island.bar:Pulse(alpha)
    island:UpdateStreak()
    if ns.panel and ns.panel.UpdatePartyBob then ns.panel:UpdatePartyBob() end

    -- scale (Size setting only)
    island:ApplyScale(false)

    -- gain dip: shift 5px down, then spring back up. A translate, not a scale,
    -- so the XP bar never grows/shrinks when XP is gained.
    local dipY = 0
    if ns.db and ns.db.dip == false then
        -- "Gain dip" is off: never start or continue the translate
        island._dipAt = nil
    elseif island._dipAt then
        local t = GetTime() - island._dipAt
        local str = (ns.db.strength or 100) / 100
        if t < 0.15 then
            dipY = -5 * str * (t / 0.15)
        elseif t < 0.65 then
            dipY = -5 * str * (1 - ns.easeOutBack((t - 0.15) / 0.5))
        else
            island._dipAt = nil
        end
    end
    if dipY ~= (island._dipY or 0) then
        island._dipY = dipY
        island:ApplyPosition()
    end
end)

-- Escape cancels move mode.
ns.On("MODIFIER_STATE_CHANGED", function() end)

-- ---------------------------------------------------------------------------
-- Theme / scale application entry point
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Hide (or restore) Blizzard's default XP and reputation bars so the island
-- can be the only progress bar.  Classic-era clients name the bars MainMenu*;
-- the modern engine moved them under StatusTrackingBarManager, so both shapes
-- are covered.  Nothing here changes any saved Blizzard setting or CVar, and
-- every bar is restored the moment the option is switched off.
local BLIZZ_BAR_FRAMES = {
    -- classic-era XP + reputation bars
    "MainMenuExpBar", "MainMenuBarXPText", "MainMenuBarMaxLevelBar",
    "ReputationWatchBar", "ReputationWatchStatusBar",
    -- modern status-tracking containers (XP + reputation)
    "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
}
-- Hook each bar once (frames can appear later, so this is re-checked every
-- apply rather than guarded by a single flag).
local function hookBlizzBars()
    for i = 1, #BLIZZ_BAR_FRAMES do
        local frame = _G[BLIZZ_BAR_FRAMES[i]]
        if frame and frame.HookScript and not frame._xpbarHooked then
            frame._xpbarHooked = true
            -- Blizzard re-shows the bar on level-up etc.; keep it hidden
            frame:HookScript("OnShow", function(self)
                if ns.db and ns.db.hideBlizzXp then pcall(self.Hide, self) end
            end)
        end
    end
    -- modern manager: alpha 0 is the supported way to hide the XP/rep bars
    local mgr = _G.StatusTrackingBarManager
    if mgr and mgr.HookScript and not mgr._xpbarHooked then
        mgr._xpbarHooked = true
        mgr:HookScript("OnShow", function(self)
            if ns.db and ns.db.hideBlizzXp then pcall(self.SetAlpha, self, 0) end
        end)
    end
end

function ns.ApplyBlizzBar()
    hookBlizzBars()
    local hide = ns.db and ns.db.hideBlizzXp
    local was = ns._blizzBarHidden
    ns._blizzBarHidden = hide
    for i = 1, #BLIZZ_BAR_FRAMES do
        local frame = _G[BLIZZ_BAR_FRAMES[i]]
        if frame then
            if hide then
                pcall(frame.Hide, frame)
            elseif was then
                if frame.SetAlpha then pcall(frame.SetAlpha, frame, 1) end
                pcall(frame.Show, frame)
            end
        end
    end
    local mgr = _G.StatusTrackingBarManager
    if mgr then
        if hide then
            -- remember the original alpha so restoring never overrides a bar
            -- the player had already dimmed/hidden with Blizzard's own option
            if ns._blizzMgrAlpha == nil and mgr.GetAlpha then
                local ok, a = pcall(mgr.GetAlpha, mgr)
                ns._blizzMgrAlpha = (ok and a) or 1
            end
            pcall(mgr.SetAlpha, mgr, 0)
        elseif was then
            pcall(mgr.SetAlpha, mgr, ns._blizzMgrAlpha or 1)
        end
    end
end

function island:Refresh()
    if not ns.db then return end
    if self._refreshing then return end
    self._refreshing = true
    local ok, err = pcall(function()
        self:SetScale()
        self:ApplyPosition()
        self:ApplyPortrait()
        self:ApplyThickness()
        self:ApplyTheme()
        self:ApplyMode()
        self:UpdateFade()
        self:Update(ns.data and ns.data:Current())
    end)
    self._refreshing = false
    if not ok then ns.ReportError("island:Refresh", err) end
    if ns.ApplyBlizzBar then ns.ApplyBlizzBar() end
    -- refresh-rate sampling for /xpbar debug
    self._refreshTimes = self._refreshTimes or {}
    self._refreshTimes[#self._refreshTimes + 1] = GetTime()
    if #self._refreshTimes > 30 then table.remove(self._refreshTimes, 1) end
end

function island:RefreshCountLastSecond()
    local now = GetTime()
    local times = self._refreshTimes or {}
    while times[1] and now - times[1] > 1 do table.remove(times, 1) end
    return #times
end

-- Called once when a settings batch ends: apply the mode + clean layout state,
-- then one notification and one data update.
function ns.FlushBatch()
    if ns.island then
        ns.island:ApplyMode()
        ns.island:ResetLayoutState()
    end
    ns.Notify()
    ns.MarkDirty()
end

ns.OnUpdateLayout(function() island:Refresh() end)

ns.On("UNIT_PORTRAIT_UPDATE", function(_, unit)
    if unit == "player" or unit == "pet" or unit == nil then
        if ns.db then island:ApplyPortrait() end
    end
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.db then island:ApplyPortrait() end
    if ns.ApplyBlizzBar then ns.ApplyBlizzBar() end
end)

-- the XP bar swaps to the reputation bar at max level, and Blizzard can redraw
-- the status bars on other transitions; re-apply so they stay hidden
ns.On("PLAYER_LEVEL_UP", function()
    if ns.ApplyBlizzBar then ns.ApplyBlizzBar() end
end)
ns.On("UPDATE_FACTION", function()
    if ns.db and ns.db.hideBlizzXp and ns.ApplyBlizzBar then ns.ApplyBlizzBar() end
end)
