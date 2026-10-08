local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Progress bar with animations:
--   - fill eases from old to new width over 0.9s (easeOutCubic)
--   - cur/max and percent count up over the same time
--   - a pale-gold "fresh XP" flash over the newly gained part
--   - a leading-edge glint (with an additive glow) that fades after a gain
--   - the glint breathes at 90%+ and a shine band sweeps the fill every 4s
-- Textures are created once and reused; all timing goes through the shared
-- ns.Tween/ns.After driver, which stops itself when nothing is animating.
-- ---------------------------------------------------------------------------
local Bar = {}
Bar.__index = Bar
ns.Bar = Bar

local GAIN_DUR = 0.9
local FADE_DUR = 1.4
local PULSE_LO = 0.35
local PULSE_HI = 0.70

local function animMode()
    return (ns.db and ns.db.animations) or "Always"
end

local function barFxName()
    return (ns.db and ns.db.barFx) or "Comet"
end

local function strengthScale()
    return ((ns.db and ns.db.strength) or 100) / 100
end

-- Comet pulse timing (20 updates per second via the shared driver)
local COMET_LOOP = 2.0
local COMET_TRAVEL = 1.4
local COMET_ARRIVE = 0.5
local COMET_HZ = 0.05

function ns.NewBar(parent, height)
    height = height or 9
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)

    local outer = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    outer:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    outer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    ns.Paint(outer, 0.29, 0.23, 0.11, 1)

    local black = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    black:SetAllPoints(f)
    ns.Paint(black, 0, 0, 0, 1)

    local inner = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    inner:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    ns.Paint(inner, 0.02, 0.016, 0.012, 1)

    local fill = f:CreateTexture(nil, "ARTWORK", nil, 0)
    fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(0)

    -- lower half of a 4-stop fill (WoW theme); hidden for 2-stop themes
    local fillLower = f:CreateTexture(nil, "ARTWORK", nil, 0)
    fillLower:Hide()

    -- WoW rim light (1px top) + inner bottom shade (2px)
    local rimTop = f:CreateTexture(nil, "OVERLAY", nil, 3)
    rimTop:SetTexture(ns.Media.white)
    rimTop:SetHeight(1)
    rimTop:Hide()
    local shadeBottom = f:CreateTexture(nil, "ARTWORK", nil, 2)
    shadeBottom:SetTexture(ns.Media.white)
    shadeBottom:SetHeight(2)
    shadeBottom:Hide()

    local rested = f:CreateTexture(nil, "ARTWORK", nil, 1)
    rested:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    rested:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
    rested:SetWidth(0)
    rested:SetTexture(ns.Media.white)
    rested:SetVertexColor(0.10, 0.44, 0.88, 0.75)
    rested:Hide()

    local ghost = f:CreateTexture(nil, "ARTWORK", nil, 2)
    ghost:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 1)
    ghost:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, -1)
    ghost:SetWidth(0)
    ghost:SetTexture(ns.Media.stripe)
    ghost:Hide()

    -- fresh XP flash (pale gold, horizontal alpha 0.15 -> 0.95)
    local flash = f:CreateTexture(nil, "ARTWORK", nil, 3)
    flash:SetTexture(ns.Media.white)
    flash:SetBlendMode("ADD")
    flash:SetVertexColor(1, 0.95, 0.72, 1)
    ns.Gradient(flash, { 1, 0.95, 0.72, 0.15 }, { 1, 0.95, 0.72, 0.95 }, true)
    flash:Hide()

    -- leading-edge glint
    local glint = f:CreateTexture(nil, "OVERLAY", nil, 1)
    glint:SetTexture(ns.Media.white)
    glint:SetVertexColor(1, 0.965, 0.784, 1)
    glint:SetWidth(3)
    glint:SetPoint("TOP", fill, "TOP", 0, 2)
    glint:SetPoint("BOTTOM", fill, "BOTTOM", 0, -2)
    glint:SetPoint("LEFT", fill, "RIGHT", 0, 0)
    glint:Hide()

    -- cool halo flanking the leading-edge glint (WoW theme)
    local haloL = f:CreateTexture(nil, "OVERLAY", nil, 1)
    local haloR = f:CreateTexture(nil, "OVERLAY", nil, 1)
    for _, h in ipairs({ haloL, haloR }) do
        h:SetTexture(ns.Media.white)
        h:SetWidth(1)
        h:SetPoint("TOP", fill, "TOP", 0, 2)
        h:SetPoint("BOTTOM", fill, "BOTTOM", 0, -2)
        h:Hide()
    end
    haloL:SetPoint("RIGHT", glint, "LEFT", 0, 0)
    haloR:SetPoint("LEFT", glint, "RIGHT", 0, 0)

    -- idle shine: clipped child frame over the fill
    local shineFrame = CreateFrame("Frame", nil, f)
    shineFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    shineFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    shineFrame:SetWidth(0)
    if ns.API.canClip then pcall(shineFrame.SetClipsChildren, shineFrame, true) end
    shineFrame:Hide()
    local shine = shineFrame:CreateTexture(nil, "ARTWORK", nil, 0)
    shine:SetTexture(ns.Media.shineBand)
    shine:SetBlendMode("ADD")
    shine:SetHeight(height - 2)

    local gloss = f:CreateTexture(nil, "OVERLAY", nil, 2)
    gloss:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    gloss:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    gloss:SetTexture(ns.Media.gloss)

    -- comet pulse: bright head + gradient trail + three pooled sparks
    local cometHead = f:CreateTexture(nil, "OVERLAY", nil, 6)
    cometHead:SetTexture(ns.Media.white)
    cometHead:SetVertexColor(1, 1, 1, 1)
    cometHead:SetBlendMode("ADD")
    cometHead:Hide()

    local cometTrail = f:CreateTexture(nil, "OVERLAY", nil, 5)
    cometTrail:SetTexture(ns.Media.white)
    cometTrail:SetBlendMode("ADD")
    ns.Gradient(cometTrail, { 1, 1, 1, 0 }, { 1, 1, 1, 0.6 }, true)
    cometTrail:Hide()

    local cometSparks = {}
    for i = 1, 3 do
        local s = f:CreateTexture(nil, "OVERLAY", nil, 7)
        s:SetTexture(ns.Media.disk)
        s:SetSize(4, 4)
        s:SetVertexColor(1, 0.82, 0, 1)
        s:SetBlendMode("ADD")
        s:Hide()
        cometSparks[i] = s
    end

    local self = setmetatable({
        frame = f, height = height,
        outer = outer, black = black, inner = inner,
        fill = fill, fillLower = fillLower, rested = rested, ghost = ghost, gloss = gloss,
        flash = flash, glint = glint, halo = { haloL, haloR },
        rimTop = rimTop, shadeBottom = shadeBottom,
        shineFrame = shineFrame, shine = shine,
        cometHead = cometHead, cometTrail = cometTrail, cometSparks = cometSparks,
        cometT = 0, cometOn = false, cometFlow = false,
        ticks = {}, markers = {},
        pct = 0, targetPct = nil, restedPct = 0, ghostPct = 0,
        showMilestone = false, party = {}, expanded = false,
        animating = false, counting = false, flashOn = false,
    }, Bar)

    -- engraved groove marks: dark violet left edge + faint white right edge
    for k = 1, 19 do
        local gl = f:CreateTexture(nil, "OVERLAY", nil, 3)
        gl:SetTexture(ns.Media.white)
        gl:SetVertexColor(12 / 255, 0, 22 / 255, 0.5)
        gl:SetWidth(1)
        local gr = f:CreateTexture(nil, "OVERLAY", nil, 3)
        gr:SetTexture(ns.Media.white)
        gr:SetVertexColor(1, 1, 1, 0.14)
        gr:SetWidth(1)
        self.ticks[k] = { left = gl, right = gr }
    end

    -- lit segment the fill is currently inside
    self.segPulse = f:CreateTexture(nil, "ARTWORK", nil, 4)
    self.segPulse:SetTexture(ns.Media.white)
    self.segPulse:SetBlendMode("ADD")
    self.segPulse:SetVertexColor(1, 1, 1, 0)
    self.segPulse:Hide()

    -- charge-up: gold overlay from the 80% mark to the fill edge
    self.charge = f:CreateTexture(nil, "ARTWORK", nil, 5)
    self.charge:SetTexture(ns.Media.white)
    self.charge:SetBlendMode("ADD")
    ns.Gradient(self.charge, { 1, 0.82, 0, 0 }, { 1, 0.82, 0, 0.6 }, true)
    self.charge:SetAlpha(0)
    self.charge:Hide()

    -- pooled segment-cross flashes and their sparks
    self.flashes = {}
    self.flashSparks = {}
    for k = 1, 19 do
        local fl = f:CreateTexture(nil, "OVERLAY", nil, 4)
        fl:SetTexture(ns.Media.white)
        fl:SetVertexColor(1, 1, 1, 1)
        fl:SetBlendMode("ADD")
        fl:Hide()
        self.flashes[k] = fl
        local sp = f:CreateTexture(nil, "OVERLAY", nil, 7)
        sp:SetTexture(ns.Media.disk)
        sp:SetSize(4, 4)
        sp:SetVertexColor(1, 0.82, 0, 1)
        sp:SetBlendMode("ADD")
        sp:Hide()
        self.flashSparks[k] = sp
    end

    -- kill-streak frame glow: four 1px edges just outside the bar
    self.streakGlow = {}
    for i = 1, 4 do
        local t = f:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetTexture(ns.Media.white)
        t:SetVertexColor(1, 0.82, 0, 0)
        t:Hide()
        self.streakGlow[i] = t
    end
    -- theme outer glow (WoW): four 1px edges, replaced by the streak glow
    self.barGlow = {}
    for i = 1, 4 do
        local t = f:CreateTexture(nil, "OVERLAY", nil, 0)
        t:SetTexture(ns.Media.white)
        t:Hide()
        self.barGlow[i] = t
    end
    -- streak brighten: additive white over the fill (never touches the gradient)
    self.streakFill = f:CreateTexture(nil, "ARTWORK", nil, 6)
    self.streakFill:SetTexture(ns.Media.white)
    self.streakFill:SetBlendMode("ADD")
    self.streakFill:SetVertexColor(1, 1, 1, 1)
    self.streakFill:SetAlpha(0)
    self.streakFill:Hide()

    local ms = f:CreateTexture(nil, "OVERLAY", nil, 4)
    ms:SetTexture(ns.Media.white)
    ms:SetSize(8, 8)
    ms:SetPoint("TOPRIGHT", f, "TOPRIGHT", 4, 2)
    if ms.SetRotation then ms:SetRotation(math.rad(45)) end
    ms:SetVertexColor(1, 0.82, 0, 1)
    ms:Hide()
    self.milestone = ms

    local left = f:CreateFontString(nil, "OVERLAY")
    ns.StyleText(left, 10, "bold")
    left:SetPoint("LEFT", f, "LEFT", 6, 0)
    left:SetJustifyH("LEFT")
    left:Hide()
    local right = f:CreateFontString(nil, "OVERLAY")
    ns.StyleText(right, 10, "bold")
    right:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    right:SetJustifyH("RIGHT")
    right:Hide()
    self.textLeft, self.textRight = left, right

    f:SetScript("OnSizeChanged", function() self:Layout() end)
    return self
end

-- Thin mode: no outer ring / black border around the bar.
function Bar:SetThinBorder(show)
    if self.outer then
        if show then self.outer:Show() else self.outer:Hide() end
    end
end

function Bar:SetTexts(left, right)
    self.textLeft:SetText(left or "")
    self.textRight:SetText(right or "")
end

function Bar:ShowThinText(show)
    if show then self.textLeft:Show(); self.textRight:Show()
    else self.textLeft:Hide(); self.textRight:Hide() end
end

local function applyVerticalGradient(tex, c1, c2)
    tex:SetTexture(ns.Media.statusBar)
    local done = false
    if tex.SetGradient then
        done = pcall(tex.SetGradient, tex, "VERTICAL",
            { r = c1[1], g = c1[2], b = c1[3], a = c1[4] or 1 },
            { r = c2[1], g = c2[2], b = c2[3], a = c2[4] or 1 })
        if not done then
            done = pcall(tex.SetGradient, tex, "VERTICAL",
                c1[1], c1[2], c1[3], c2[1], c2[2], c2[3])
        end
    end
    if not done then tex:SetVertexColor(c1[1], c1[2], c1[3], c1[4] or 1) end
end

function Bar:SetGradientColors(c1, c2)
    self:SetFillColors(c1, c2)
end

-- 2-stop (c1..c2) or 4-stop (c1..c2 upper half, c3..c4 lower half) fill.
function Bar:SetFillColors(c1, c2, c3, c4)
    if not (c1 and c2) then return end
    self._fill4 = (c3 ~= nil and c4 ~= nil)
    applyVerticalGradient(self.fill, c1, c2)
    if self._fill4 then
        applyVerticalGradient(self.fillLower, c3, c4)
        self.fillLower:Show()
    else
        self.fillLower:Hide()
    end
    self:LayoutFill()
end

-- All theme-driven bar colours in one place; called from island:ApplyTheme.
function Bar:ApplyTheme(th)
    th = th or ns.Theme()
    self.theme = th
    ns.Paint(self.outer, ns.Hex(th.barRing or "#4A3B1C"))
    ns.Paint(self.black, 0, 0, 0, 1)
    ns.Paint(self.inner, ns.Hex(th.track or "#050403"))

    local rested = ns.HexA(th.rested or "#1A6FE0")
    self._restedColor = rested
    self.rested:SetVertexColor(rested[1], rested[2], rested[3], 0.75)

    local flash = ns.HexA(th.flash or "#FFF2B8")
    ns.Gradient(self.flash, { flash[1], flash[2], flash[3], 0.15 }, { flash[1], flash[2], flash[3], 0.95 }, true)

    local glint = ns.HexA(th.glint or "#FFF6C8")
    self.glint:SetVertexColor(glint[1], glint[2], glint[3], 1)

    local comet = ns.HexA(th.comet or "#FFFFFF")
    ns.Gradient(self.cometTrail, { comet[1], comet[2], comet[3], 0 }, { comet[1], comet[2], comet[3], 0.6 }, true)
    self.cometHead:SetVertexColor(comet[1], comet[2], comet[3], 1)

    local spark = ns.HexA(th.spark or "#FFD100")
    for i = 1, #self.cometSparks do self.cometSparks[i]:SetVertexColor(spark[1], spark[2], spark[3], 1) end
    for i = 1, #self.flashSparks do self.flashSparks[i]:SetVertexColor(spark[1], spark[2], spark[3], 1) end
    ns.Gradient(self.charge, { spark[1], spark[2], spark[3], 0 }, { spark[1], spark[2], spark[3], 0.6 }, true)
    self.milestone:SetVertexColor(spark[1], spark[2], spark[3], 1)

    local groove = ns.HexA(th.groove or "#0C0016")
    local ga = th.grooveA or 0.5
    for k = 1, 19 do
        local t = self.ticks[k]
        if t then
            t.left:SetVertexColor(groove[1], groove[2], groove[3], ga)
            t.right:SetVertexColor(1, 1, 1, 0.14)
        end
    end

    -- WoW extras: rim light, inner shade, outer glow, glint halo
    local wow = th.barGlow ~= nil
    if wow then
        self.rimTop:SetVertexColor(1, 1, 1, 0.55); self.rimTop:Show()
        self.shadeBottom:SetVertexColor(25 / 255, 0, 80 / 255, 0.45); self.shadeBottom:Show()
        local g = th.barGlow
        for i = 1, 4 do self.barGlow[i]:SetVertexColor(g[1], g[2], g[3], 0.35) end
        local h = th.halo
        if h then
            self.halo[1]:SetVertexColor(h[1], h[2], h[3], 0.5)
            self.halo[2]:SetVertexColor(h[1], h[2], h[3], 0.5)
        end
    else
        self.rimTop:Hide(); self.shadeBottom:Hide()
        for i = 1, 4 do self.barGlow[i]:Hide() end
        self.halo[1]:Hide(); self.halo[2]:Hide()
    end
    self._wowBar = wow
    if not self._streakMul or self._streakMul <= 1.001 then self:SetGlowVisible(true) end
end

-- Show/hide the theme outer glow (the streak glow overrides it).
function Bar:SetGlowVisible(show)
    if not self.barGlow then return end
    local on = show and self._wowBar
    for i = 1, 4 do
        if on then self.barGlow[i]:Show() else self.barGlow[i]:Hide() end
    end
end

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------
function Bar:SetData(d)
    self.data = d
    if not d then self:Layout(); return end

    self.restedPct = d.restedPct or 0
    self.ghostPct = d.ghostPct or 0
    self.showMilestone = (d.key == "xp") and not (ns.db and ns.db.v1)
    local th = ns.Theme()
    if d.key == "xp" and ns.db and ns.db.barColor then
        local c = ns.HexA(ns.db.barColor)
        self:SetFillColors(c, c)
    elseif d.key == "xp" then
        self:SetFillColors(ns.HexA(th.barXP1), ns.HexA(th.barXP2),
            th.barXP3 and ns.HexA(th.barXP3), th.barXP4 and ns.HexA(th.barXP4))
    elseif d.key == "rep" and th.barRep1 then
        self:SetFillColors(ns.HexA(th.barRep1), ns.HexA(th.barRep2))
    elseif d.key == "honor" and th.barHonor1 then
        self:SetFillColors(ns.HexA(th.barHonor1), ns.HexA(th.barHonor2))
    elseif d.key == "pet" and th.barPet1 then
        self:SetFillColors(ns.HexA(th.barPet1), ns.HexA(th.barPet2))
    elseif d.fill and d.fill[1] and d.fill[2] then
        self:SetFillColors(d.fill[1], d.fill[2])
    end
    self.party = d.party or {}
    self:ApplyStreak(self._streakMul or 1, self._streakAlpha or 0, self._streakColor)

    local anim = animMode()
    local newPct = ns.clamp(d.pct or 0, 0, 1)
    local levelChanged = (self.lastLevel ~= nil and d.level ~= self.lastLevel)
    local sameTarget = self.targetPct ~= nil and math.abs(newPct - self.targetPct) <= 0.0005

    if d.key == "xp" and anim ~= "Off" and not levelChanged and self.targetPct ~= nil and not sameTarget then
        local oldCur = self.dispCur or d.cur or 0
        local oldMax = self.dispMax or d.max or 1
        self:StartGain(self.pct or 0, newPct, oldCur, oldMax, d.cur or 0, d.max or 1)
    elseif self.animating and sameTarget then
        -- a gain animation is already running toward this value; leave it
    else
        if self.gainTween then ns.KillTween(self.gainTween); self.gainTween = nil end
        self.animating = false
        self.counting = false
        self.pct = newPct
        self.dispCur = d.cur or 0
        self.dispMax = d.max or 1
        if self.onTick then self.onTick(self.dispCur, self.dispMax, self.pct, false) end
    end

    self.targetPct = newPct
    self.lastLevel = d.level
    self:Layout()
    self:UpdateEffects()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------
function Bar:Layout()
    local w = self.frame:GetWidth() or 0
    local innerW = math.max(0, w - 2)
    for k = 1, 19 do
        local mark = 1 + ns.round(innerW * (k * 0.05))
        local t = self.ticks[k]
        t.left:ClearAllPoints()
        t.left:SetPoint("TOP", self.frame, "TOPLEFT", mark - 1, -1)
        t.left:SetPoint("BOTTOM", self.frame, "BOTTOMLEFT", mark - 1, 1)
        t.right:ClearAllPoints()
        t.right:SetPoint("TOP", self.frame, "TOPLEFT", mark, -1)
        t.right:SetPoint("BOTTOM", self.frame, "BOTTOMLEFT", mark, 1)
    end
    if self.showMilestone then self.milestone:Show() else self.milestone:Hide() end
    -- streak glow edges sit just outside the bar
    local g = self.streakGlow
    if g then
        g[1]:ClearAllPoints(); g[1]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -1, 1); g[1]:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 1, 1); g[1]:SetHeight(1)
        g[2]:ClearAllPoints(); g[2]:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", -1, -1); g[2]:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 1, -1); g[2]:SetHeight(1)
        g[3]:ClearAllPoints(); g[3]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -1, 1); g[3]:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", -1, -1); g[3]:SetWidth(1)
        g[4]:ClearAllPoints(); g[4]:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 1, 1); g[4]:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 1, -1); g[4]:SetWidth(1)
    end
    self:LayoutFill()
    self:LayoutMarkers(innerW)
end

function Bar:LayoutFill()
    local w = self.frame:GetWidth() or 0
    local innerW = math.max(0, w - 2)
    local h = self.height
    local pct = ns.clamp(self.pct or 0, 0, 1)
    local fw = ns.round(innerW * pct)
    self.fill:SetWidth(fw)
    -- A zero width can make a texture render at its native size, so hide the
    -- fill entirely when there is nothing to draw (e.g. 0.1% in a small layout)
    -- and show it again as soon as it has a positive width.
    self.fill:SetShown(fw > 0)

    -- 4-stop fill: split the fill into an upper and a lower texture
    local H = self.frame:GetHeight() or h
    local split = 1 + math.max(0, (H - 2) / 2)
    self.fill:ClearAllPoints()
    self.fill:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1, -1)
    if self._fill4 then
        self.fill:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1, split)
        self.fillLower:ClearAllPoints()
        self.fillLower:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1, -(1 + (H - 2) / 2))
        self.fillLower:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1, 1)
        self.fillLower:SetWidth(fw)
        self.fillLower:SetShown(fw > 0)
    else
        self.fill:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1, 1)
        self.fillLower:Hide()
    end

    -- rim light / bottom shade and the theme outer glow follow the fill width
    if self.rimTop then
        self.rimTop:ClearAllPoints()
        self.rimTop:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1, -1)
        self.rimTop:SetWidth(math.max(1, fw))
    end
    if self.shadeBottom then
        self.shadeBottom:ClearAllPoints()
        self.shadeBottom:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1, 1)
        self.shadeBottom:SetWidth(math.max(1, fw))
    end
    if self.barGlow then
        local bg = self.barGlow
        bg[1]:ClearAllPoints(); bg[1]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -2, 2); bg[1]:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 2, 2); bg[1]:SetHeight(1)
        bg[2]:ClearAllPoints(); bg[2]:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", -2, -2); bg[2]:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 2, -2); bg[2]:SetHeight(1)
        bg[3]:ClearAllPoints(); bg[3]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -2, 2); bg[3]:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", -2, -2); bg[3]:SetWidth(1)
        bg[4]:ClearAllPoints(); bg[4]:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 2, 2); bg[4]:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 2, -2); bg[4]:SetWidth(1)
    end

    if self.streakFill then
        self.streakFill:ClearAllPoints()
        self.streakFill:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1, -1)
        self.streakFill:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1, 1)
        self.streakFill:SetWidth(fw)
    end

    -- rested / ghost span the full bar height, at the fill's right edge
    if self.restedPct and self.restedPct > 0 then
        self.rested:Show()
        self.rested:ClearAllPoints()
        self.rested:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1 + fw, -1)
        self.rested:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1 + fw, 1)
        self.rested:SetWidth(ns.round(innerW * ns.clamp(self.restedPct, 0, 1)))
    else
        self.rested:Hide()
    end

    if self.ghostPct and self.ghostPct > 0 then
        self.ghost:Show()
        self.ghost:ClearAllPoints()
        self.ghost:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1 + fw, 0)
        self.ghost:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1 + fw, 0)
        self.ghost:SetWidth(math.max(1, ns.round(innerW * ns.clamp(self.ghostPct, 0, 1))))
    else
        self.ghost:Hide()
    end

    if self.flashOn then
        local left = ns.round(innerW * ns.clamp(self.flashFrom or 0, 0, 1))
        local fwid = math.max(0, fw - left)
        self.flash:SetWidth(fwid)
        self.flash:SetHeight(h - 2)
        self.flash:ClearAllPoints()
        self.flash:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1 + left, 1)
        if fwid > 0 then self.flash:Show() else self.flash:Hide() end
    end

    -- the segment the fill is currently inside
    local segW = innerW * 0.05
    local segIdx = ns.clamp(math.floor(pct / 0.05), 0, 19)
    self.segPulse:ClearAllPoints()
    self.segPulse:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1 + segIdx * segW, -1)
    self.segPulse:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1 + segIdx * segW, 1)
    self.segPulse:SetWidth(segW)
    self.segPulse:Show()

    -- charge-up: the fill beyond 80%
    if pct > 0.8 and (ns.db == nil or ns.db.charge ~= false) then
        local leftMark = (pct >= 1) and 0 or (innerW * 0.8)
        local x = 1 + leftMark
        local cwid = math.max(0, fw - leftMark)
        self.charge:ClearAllPoints()
        self.charge:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -1)
        self.charge:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, 1)
        self.charge:SetWidth(cwid)
        self.charge:Show()
    else
        self.charge:Hide()
    end

    self.shineFrame:SetWidth(fw)
end

function Bar:LayoutMarkers(innerW)
    local list = self.party
    for i = 1, #list do
        local m = self.markers[i]
        if not m then
            m = {}
            m.back = self.frame:CreateTexture(nil, "OVERLAY", nil, 5)
            m.back:SetTexture(ns.Media.disk)
            m.back:SetSize(15, 15)
            m.back:SetVertexColor(0, 0, 0, 1)
            m.dot = self.frame:CreateTexture(nil, "OVERLAY", nil, 6)
            m.dot:SetTexture(ns.Media.disk)
            m.dot:SetSize(11, 11)
            self.markers[i] = m
        end
        local cr, cg, cb = ns.ClassColor(list[i].class)
        m.dot:SetVertexColor(cr, cg, cb, 1)
        local x = 1 + ns.round(innerW * ns.clamp(list[i].pct or 0, 0, 1))
        m.back:ClearAllPoints()
        m.back:SetPoint("CENTER", self.frame, "TOPLEFT", x, -self.height / 2)
        m.dot:ClearAllPoints()
        m.dot:SetPoint("CENTER", m.back, "CENTER", 0, 0)
        m.back:Show(); m.dot:Show()
    end
    for i = #list + 1, #self.markers do
        self.markers[i].back:Hide()
        self.markers[i].dot:Hide()
    end
end

-- Rested / quest pulse, called every frame by the island's OnUpdate.
function Bar:Pulse(alpha)
    if self.rested:IsShown() then
        local rc = self._restedColor or { 0.10, 0.44, 0.88 }
        self.rested:SetVertexColor(rc[1], rc[2], rc[3], alpha or 0.75)
    end
    if self.ghost:IsShown() then
        self.ghost:SetAlpha(alpha or 0.7)
    end

    local anim = animMode()
    local allow = (anim == "Always") or (anim == "On hover only" and self.expanded)

    -- lit segment pulse (0.06 .. 0.16 over 1.6s)
    if self.segPulse and self.segPulse:IsShown() and allow and anim ~= "Off" then
        local a = 0.11 + 0.05 * math.sin(ns.animClock * (math.pi * 2 / 1.6))
        self.segPulse:SetAlpha(a)
    elseif self.segPulse then
        self.segPulse:SetAlpha(0)
    end

    -- charge-up pulse (0.05 .. 0.65; faster nearer the level)
    if self.charge and self.charge:IsShown() and allow and anim ~= "Off" then
        local p = ns.clamp(self.pct or 0, 0, 1)
        local period = 1.8
        if p >= 1 then period = 0.6
        elseif p > 0.8 then period = 1.8 - (p - 0.8) / 0.2 * 1.2 end
        local a = 0.35 + 0.30 * math.sin(ns.animClock * (math.pi * 2 / period))
        self.charge:SetAlpha(ns.clamp(a, 0.05, 0.65))
    elseif self.charge then
        self.charge:SetAlpha(0)
    end

    -- WoW cooling halo tracks the leading-edge glint
    if self.halo then
        if self._wowBar and self.glint and self.glint:IsShown() then
            local ga = self.glint:GetAlpha() or 1
            self.halo[1]:SetAlpha(ga); self.halo[2]:SetAlpha(ga)
            self.halo[1]:Show(); self.halo[2]:Show()
        else
            self.halo[1]:Hide(); self.halo[2]:Hide()
        end
    end
end

-- Kill-streak brightening + frame glow, eased over 0.4s.
function Bar:SetStreak(active, n, color)
    local m = active and math.min(1.6, 1 + 0.06 * (n or 0)) or 1
    local a = active and math.min(0.9, 0.15 + 0.08 * (n or 0)) or 0
    color = color or ns.HexA("#FFD100")
    self._streakColor = color
    if self._streakTween then ns.KillTween(self._streakTween) end
    local fm, fa = self._streakMul or 1, self._streakAlpha or 0
    self._streakTween = ns.Tween({
        dur = 0.4, from = 0, to = 1, ease = ns.easeOutCubic,
        set = function(p)
            local mm = fm + (m - fm) * p
            local aa = fa + (a - fa) * p
            self._streakMul, self._streakAlpha = mm, aa
            self:ApplyStreak(mm, aa, color)
        end,
        done = function()
            self._streakTween = nil
            self._streakMul, self._streakAlpha = m, a
            self:ApplyStreak(m, a, color)
        end,
    })
end

function Bar:ApplyStreak(m, a, color)
    -- brighten with an additive overlay so the fill's gradient is never replaced
    local extra = math.max(0, (m or 1) - 1)
    if self.streakFill then
        self.streakFill:SetAlpha(extra)
        if extra > 0.001 then self.streakFill:Show() else self.streakFill:Hide() end
    end
    local c = color or ns.HexA("#FFD100")
    if self.streakGlow then
        for i = 1, 4 do
            local t = self.streakGlow[i]
            t:SetVertexColor(c[1], c[2], c[3], a or 0)
            if a and a > 0.001 then t:Show() else t:Hide() end
        end
    end
    -- the streak glow replaces the theme outer glow while a streak runs
    self:SetGlowVisible(not (a and a > 0.001))
end

-- ---------------------------------------------------------------------------
-- Gain animation
-- ---------------------------------------------------------------------------
function Bar:StartGain(fromPct, toPct, oldCur, oldMax, newCur, newMax)
    if self.gainTween then ns.KillTween(self.gainTween) end
    if self.flashFade then ns.KillTween(self.flashFade); self.flashFade = nil end
    self:StopPulse()
    self:StopComet()
    self.animating = true
    self.counting = true
    self.flashFrom = fromPct
    self.targetPct = toPct
    self._gainFrom = fromPct
    self._gainTo = toPct
    self._flashed = {}
    self._flashTweens = self._flashTweens or {}
    self._sparkTweens = self._sparkTweens or {}

    if animMode() ~= "Off" then
        self.flashOn = true
        self.flash:Show()
        self.flash:SetAlpha(1)
        self.glint:Show()
        self.glint:SetAlpha(1)
        self:GlintFade()
    end

    if self.onTick then self.onTick(oldCur, oldMax, fromPct, true) end

    self.gainTween = ns.Tween({
        dur = GAIN_DUR, from = 0, to = 1, ease = ns.easeOutCubic,
        -- `eased` is the easeOutCubic output that the fill sweeps along
        set = function(eased)
            self.pct = fromPct + (toPct - fromPct) * eased
            self:LayoutFill()
            self:CheckFlashes(self.pct)
            local cur = oldCur + (newCur - oldCur) * eased
            local max = oldMax + (newMax - oldMax) * eased
            self.dispCur, self.dispMax = cur, max
            if self.onTick then self.onTick(cur, max, self.pct, true) end
        end,
        done = function()
            self.pct = toPct
            self.dispCur, self.dispMax = newCur, newMax
            self.animating = false
            self.counting = false
            self:LayoutFill()
            if self.onTick then self.onTick(newCur, newMax, toPct, false) end
            self.flashFade = ns.Tween({
                dur = FADE_DUR, from = 1, to = 0, ease = ns.easeOutCubic,
                set = function(v) self.flash:SetAlpha(v) end,
                done = function() self.flashOn = false; self.flash:Hide() end,
            })
            -- pause the comet, then restart the loop one second after the gain
            self.cometDelayUntil = GetTime() + 1
            self:UpdateEffects()
            ns.After(1, function()
                if self.UpdateEffects then self:UpdateEffects() end
            end)
        end,
    })
end

-- Flash each segment line as the sweeping fill first crosses it.
function Bar:CheckFlashes(pct)
    if ns.db and ns.db.segFlash == false then return end
    local from = self._gainFrom or 0
    for k = 1, 19 do
        local th = k * 0.05
        if th > from + 0.0001 and pct >= th - 0.0001 and not self._flashed[k] then
            self._flashed[k] = true
            self:FlashLine(k)
        end
    end
end

function Bar:FlashLine(k)
    local innerW = math.max(0, (self.frame:GetWidth() or 0) - 2)
    local mark = 1 + ns.round(innerW * (k * 0.05))

    local fl = self.flashes[k]
    fl:ClearAllPoints()
    fl:SetPoint("TOP", self.frame, "TOPLEFT", mark, 2)
    fl:SetPoint("BOTTOM", self.frame, "BOTTOMLEFT", mark, -2)
    fl:SetWidth(3)
    fl:SetAlpha(1)
    fl:Show()
    if self._flashTweens[k] then ns.KillTween(self._flashTweens[k]) end
    self._flashTweens[k] = ns.Tween({
        dur = 0.6, from = 1, to = 0, ease = ns.easeOutCubic,
        set = function(v)
            local ok = pcall(fl.SetAlpha, fl, v)
            if not ok then ns.KillTween(self._flashTweens[k]) end
        end,
        done = function() fl:Hide(); self._flashTweens[k] = nil end,
    })

    -- big gains spark on every second line only
    local big = (self._gainTo or 0) - (self._gainFrom or 0) > 0.25
    if (not big) or (k % 2 == 0) then
        local sp = self.flashSparks[k]
        sp:ClearAllPoints()
        sp:SetPoint("CENTER", self.frame, "TOPLEFT", mark, 0)
        sp:SetAlpha(1)
        sp:Show()
        if self._sparkTweens[k] then ns.KillTween(self._sparkTweens[k]) end
        self._sparkTweens[k] = ns.Tween({
            dur = 0.5, from = 0, to = 1, ease = ns.easeLinear,
            set = function(_, p)
                local ok = pcall(function()
                    sp:SetPoint("CENTER", self.frame, "TOPLEFT", mark, 8 * p * strengthScale())
                    sp:SetAlpha(1 - p)
                end)
                if not ok then ns.KillTween(self._sparkTweens[k]) end
            end,
            done = function() sp:Hide(); self._sparkTweens[k] = nil end,
        })
    end
end

function Bar:GlintFade()
    if self.glintFade then ns.KillTween(self.glintFade) end
    self.glintFading = true
    self.glintFade = ns.Tween({
        dur = FADE_DUR, from = 1, to = 0, ease = ns.easeOutCubic,
        set = function(v)
            self.glint:SetAlpha(v)
        end,
        done = function()
            self.glintFading = false
            if not self.pulsing then self.glint:Hide() end
        end,
    })
end

function Bar:StartPulse()
    if self.pulsing then return end
    self.pulsing = true
    self.glint:Show()
    local up = true
    local function step()
        if not self.pulsing then return end
        local a = up and PULSE_LO or PULSE_HI
        local b = up and PULSE_HI or PULSE_LO
        up = not up
        self.pulseTween = ns.Tween({
            dur = 0.8, from = a, to = b, ease = ns.easeInOutCubic,
            set = function(v)
                self.pulseAlpha = v
                self.glint:SetAlpha(v)
            end,
            done = step,
        })
    end
    step()
end

function Bar:StopPulse()
    self.pulsing = false
    self.pulseAlpha = 0
    if self.pulseTween then ns.KillTween(self.pulseTween); self.pulseTween = nil end
end

function Bar:StartShine()
    if self.shining then return end
    self.shining = true
    self.shineTimer = ns.After(0.2, function() self:SweepShine() end)
end

function Bar:StopShine()
    self.shining = false
    if self.shineTimer then ns.CancelTimer(self.shineTimer); self.shineTimer = nil end
    if self.shineTween then ns.KillTween(self.shineTween); self.shineTween = nil end
    self.shineFrame:Hide()
end

function Bar:SweepShine()
    if not self.shining then return end
    local fw = self.fill:GetWidth()
    local w = self.frame:GetWidth()
    if fw < w * 0.05 then
        self.shineFrame:Hide()
        self.shineTimer = ns.After(1.0, function() self:SweepShine() end)
        return
    end
    local bandW = math.max(6, fw * 0.28)
    self.shine:SetWidth(bandW)
    self.shine:SetHeight(self.height - 2)
    self.shineFrame:Show()
    if self.shineTween then ns.KillTween(self.shineTween) end
    self.shineTween = ns.Tween({
        dur = 1.6, from = -bandW, to = fw, ease = ns.easeInOutCubic,
        set = function(v)
            self.shine:ClearAllPoints()
            self.shine:SetPoint("BOTTOMLEFT", self.shineFrame, "BOTTOMLEFT", v, 0)
        end,
        done = function()
            self.shineFrame:Hide()
            if self.shining then
                self.shineTimer = ns.After(2.4, function() self:SweepShine() end)
            end
        end,
    })
end

-- ---------------------------------------------------------------------------
-- Comet pulse (idle effect on the fill).  Clips by geometry: every update it
-- computes each texture's own left edge and width, so it needs neither
-- SetClipsChildren nor texture scrolling.
-- ---------------------------------------------------------------------------
function Bar:StartComet(flow)
    local ok, err = pcall(function()
        self.cometFlow = flow and true or false
        if self.cometOn then return end
        self.cometOn = true
        self.cometT = 0
        self:CometStep()
    end)
    if not ok then ns.ReportError("bar:StartComet", err) end
end

function Bar:StopComet()
    local ok, err = pcall(function()
        self.cometOn = false
        if self.cometTimer then ns.CancelTimer(self.cometTimer); self.cometTimer = nil end
        if self.cometHead then self.cometHead:Hide() end
        if self.cometTrail then self.cometTrail:Hide() end
        if self.cometSparks then
            for i = 1, #self.cometSparks do self.cometSparks[i]:Hide() end
        end
    end)
    if not ok then ns.ReportError("bar:StopComet", err) end
end

function Bar:CometStep()
    local ok, err = pcall(function()
        if self.cometTimer then ns.CancelTimer(self.cometTimer); self.cometTimer = nil end
        if not self.cometOn then return end

        local anim = animMode()
        local visible = (not self.frame.IsVisible) or self.frame:IsVisible()
        if anim == "Off" or self.animating or not visible then
            self:StopComet()
            return
        end

        local w = self.frame:GetWidth() or 0
        local innerW = math.max(0, w - 2)
        local fw = innerW * ns.clamp(self.pct or 0, 0, 1)
        if fw < w * 0.05 then
            self:StopComet()
            return
        end

        local flow = self.cometFlow
        local loop = flow and COMET_TRAVEL or COMET_LOOP
        self.cometT = (self.cometT or 0) + COMET_HZ
        if self.cometT >= loop then self.cometT = self.cometT - loop end

        if flow or self.cometT < COMET_TRAVEL then
            self:LayoutComet(self.cometT / COMET_TRAVEL, fw)
        else
            -- head and trail vanish instantly; the edge flashes and sparks pop
            self:LayoutComet(nil, fw)
            self:LayoutArrival((self.cometT - COMET_TRAVEL) / COMET_ARRIVE, fw)
        end

        self.cometTimer = ns.After(COMET_HZ, function() self:CometStep() end)
    end)
    if not ok then ns.ReportError("bar:CometStep", err) end
end

function Bar:LayoutComet(u, fw)
    local head, trail = self.cometHead, self.cometTrail
    if not (head and trail) then return end
    if not u then
        head:Hide(); trail:Hide()
        return
    end
    local s = u * u * (3 - 2 * u)        -- smoothstep
    local x = fw * s

    -- head: 3px wide, full bar height, right edge at x
    local hl = math.max(0, x - 3)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1 + hl, -1)
    head:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1 + hl, 1)
    head:SetWidth(math.max(0, x - hl))
    if x > 0 then head:Show() else head:Hide() end

    -- trail: ends at x, 32% of the fill wide, clamped so it never leaves the fill
    local tw = fw * 0.32
    local tl = math.max(0, x - tw)
    trail:ClearAllPoints()
    trail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1 + tl, -1)
    trail:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 1 + tl, 1)
    trail:SetWidth(math.max(0, x - tl))
    if x > 0 then trail:Show() else trail:Hide() end

    for i = 1, #self.cometSparks do self.cometSparks[i]:Hide() end
end

function Bar:LayoutArrival(a, fw)
    a = ns.clamp(a, 0, 1)
    -- leading-edge glint flashes to 1 then back to 0.3, over any near-level pulse
    local flash = 1 - 0.7 * a
    local base = self.pulseAlpha or 0
    if self.glint then
        self.glint:Show()
        self.glint:SetAlpha(math.max(base, flash))
    end

    local hx = 1 + fw
    local cy = self.height / 2
    local s = strengthScale()
    local heights = { 8 * s, 13 * s, 18 * s }
    local drifts = { -7 * s, 0, 7 * s }
    for i = 1, 3 do
        local s = self.cometSparks[i]
        if s then
            s:ClearAllPoints()
            s:SetPoint("CENTER", self.frame, "TOPLEFT", hx + drifts[i] * a, -cy + heights[i] * a)
            s:SetAlpha(1 - a)
            s:Show()
        end
    end
end

function Bar:UpdateEffects()
    local anim = animMode()
    if anim == "Off" then
        self.flashOn = false; self.flash:Hide()
        self.glint:Hide()
        self:StopPulse(); self:StopShine(); self:StopComet()
        return
    end
    local allow = (anim == "Always") or (anim == "On hover only" and self.expanded)
    local near = (self.pct or 0) >= 0.90
    local fx = barFxName()
    local cometActive = (fx ~= "Shine")

    if near and allow and not self.animating then
        self:StartPulse()
    else
        self:StopPulse()
        if not self.glintFading and not self.animating then
            -- the comet keeps the leading-edge glint for its arrival flash
            if not (cometActive and self.cometOn) then self.glint:Hide() end
        end
    end

    local fw = self.fill:GetWidth()
    local enough = fw >= (self.frame:GetWidth() * 0.05)

    if fx == "Shine" then
        self:StopComet()
        if enough and allow then self:StartShine() else self:StopShine() end
    else
        self:StopShine()
        if (ns.db == nil or ns.db.cometOn ~= false) and enough and allow
            and not self.animating and GetTime() >= (self.cometDelayUntil or 0) then
            self:StartComet(fx == "Flow")
        else
            self:StopComet()
        end
    end
end

function Bar:SetExpanded(v)
    if self.expanded == v then return end
    self.expanded = v
    self:UpdateEffects()
end
