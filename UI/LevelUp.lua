local ADDON, ns = ...

-- ===========================================================================
-- Level-up animation - "Supernova".
--   charge (0-0.9s) -> detonate -> shatter + shockwave + sweep + sparks
--   -> reset at 2.4s.  No text: the game already announces the level.
-- All particle frames, textures and animation groups are created once and
-- reused (no objects are created per level-up).  If the client has no
-- AnimationGroup API, it degrades to a flash + ring + sound.
-- ===========================================================================
local f = ns.island.frame
local barFrame = ns.island.bar.frame
local badge = ns.island.badge

-- parented to UIParent so the island's clipping cannot cut the burst
local fx = CreateFrame("Frame", nil, UIParent)
fx:SetAllPoints(f)
fx:SetFrameStrata("MEDIUM")
fx:SetFrameLevel((f:GetFrameLevel() or 0) + 8)
if fx.SetMouseClickEnabled then fx:SetMouseClickEnabled(false) end
if fx.SetMouseMotionEnabled then fx:SetMouseMotionEnabled(false) end

local animProbe = CreateFrame("Frame")
local canAnim = type(animProbe.CreateAnimationGroup) == "function"

local running = false
local timers = {}
local function clearTimers()
    for i = 1, #timers do ns.CancelTimer(timers[i]) end
    timers = {}
end
local function after(t, fn) timers[#timers + 1] = ns.After(t, fn) end

-- ---- bar-spanning overlays -------------------------------------------------
local charge = fx:CreateTexture(nil, "ARTWORK", nil, 1)
charge:SetTexture(ns.Media.white)
charge:SetBlendMode("ADD")
charge:SetVertexColor(1, 0.95, 0.7, 0)

local detonate = fx:CreateTexture(nil, "ARTWORK", nil, 3)
detonate:SetTexture(ns.Media.white)
detonate:SetBlendMode("ADD")
detonate:SetVertexColor(1, 1, 1, 1)

local borderGlow = fx:CreateTexture(nil, "BACKGROUND", nil, 4)
borderGlow:SetTexture(ns.Media.white)
borderGlow:SetBlendMode("ADD")
borderGlow:SetVertexColor(1, 0.82, 0, 1)

local function hideOverlays()
    charge:SetAlpha(0); charge:Hide()
    detonate:SetAlpha(0); detonate:Hide()
    borderGlow:SetAlpha(0); borderGlow:Hide()
end

local function spanBar(tex, pad)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", barFrame, "TOPLEFT", -pad, pad)
    tex:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", pad, -pad)
end

hideOverlays()

-- ---- particle factory ------------------------------------------------------
local function newParticle(tex, w, h, blend)
    local fr = CreateFrame("Frame", nil, fx)
    fr:SetSize(w, h)
    fr:Hide()
    local t = fr:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(fr)
    t:SetTexture(tex)
    if blend then t:SetBlendMode(blend) end
    fr.texture = t
    if canAnim then
        local ag = fr:CreateAnimationGroup()
        if ag then
            ag:SetLooping("NONE")
            ag:SetScript("OnFinished", function() fr:Hide() end)
            fr.ag = ag
        end
    end
    return fr
end

local segments, sparks, rings, sweeps = {}, {}, {}, {}
for i = 1, 20 do segments[i] = newParticle(ns.Media.levelupSegment, 32, 16) end
for i = 1, 34 do sparks[i] = newParticle(ns.Media.levelupSpark, 16, 16, "ADD") end
for i = 1, 2 do rings[i] = newParticle(ns.Media.levelupRing, 128, 128, "ADD") end
sweeps[1] = newParticle(ns.Media.levelupSweep, 128, 32, "ADD")

-- build each particle's animations once
local function setupAnim(fr, hasRot, hasScale)
    if not fr.ag then return end
    fr.tr = fr.ag:CreateAnimation("Translation")
    fr.tr:SetDuration(1)
    fr.al = fr.ag:CreateAnimation("Alpha")
    fr.al:SetDuration(1); fr.al:SetFromAlpha(1); fr.al:SetToAlpha(0)
    if hasRot then fr.rot = fr.ag:CreateAnimation("Rotation"); fr.rot:SetDuration(1) end
    if hasScale then
        fr.sc = fr.ag:CreateAnimation("Scale")
        fr.sc:SetDuration(0.9); fr.sc:SetScaleFrom(0.1, 0.1); fr.sc:SetScaleTo(5, 5)
    end
end
for i = 1, #segments do setupAnim(segments[i], true, false) end
for i = 1, #sparks do setupAnim(sparks[i], false, false) end
for i = 1, #rings do setupAnim(rings[i], false, true) end
setupAnim(sweeps[1], false, false)

local function stopParticles()
    local groups = {}
    for i = 1, #segments do groups[#groups + 1] = segments[i] end
    for i = 1, #sparks do groups[#groups + 1] = sparks[i] end
    for i = 1, #rings do groups[#groups + 1] = rings[i] end
    for i = 1, #sweeps do groups[#groups + 1] = sweeps[i] end
    for _, fr in ipairs(groups) do
        if fr.ag then pcall(fr.ag.Stop, fr.ag) end
        fr:Hide()
    end
end

-- ---- helpers ---------------------------------------------------------------
local function barWidth()
    return (barFrame and barFrame:GetWidth()) or 200
end

local function barTint()
    local th = ns.Theme()
    return ns.HexA((ns.db and ns.db.barColor) or th.barXP1 or "#B02AD0")
end

local function islandScale()
    return (ns.db and ns.db.scale or 100) / 100
end

local function shake(dur, amp)
    if ns._luShake then ns.KillTween(ns._luShake) end
    ns._luShake = ns.Tween({
        dur = dur, from = 0, to = 1, ease = ns.easeLinear,
        set = function(p)
            local a = amp * (1 - p) * islandScale()
            ns.island._shakeX = math.sin(p * math.pi * 12) * a
            ns.island._shakeY = math.cos(p * math.pi * 14) * a
            ns.island:ApplyPosition()
        end,
        done = function()
            ns.island._shakeX = 0; ns.island._shakeY = 0
            ns.island:ApplyPosition()
        end,
    })
end

local function dip(px, dur)
    if ns._luDip then ns.KillTween(ns._luDip) end
    ns._luDip = ns.Tween({
        dur = dur, from = 0, to = 1, ease = ns.easeOutCubic,
        set = function(p)
            ns.island._dipY = -px * math.sin(p * math.pi)
            ns.island:ApplyPosition()
        end,
        done = function()
            ns.island._dipY = 0
            ns.island:ApplyPosition()
        end,
    })
end

-- ---- sequence steps --------------------------------------------------------
local function doCharge(dur)
    spanBar(charge, 2)
    charge:SetAlpha(0.15)
    charge:Show()
    if ns._luCharge then ns.KillTween(ns._luCharge) end
    ns._luCharge = ns.Tween({
        dur = dur, from = 0.15, to = 0.7, ease = ns.easeInQuad,
        set = function(v) charge:SetAlpha(v) end,
    })
    shake(dur, 2.2)
    if ns._luBadge then ns.KillTween(ns._luBadge) end
    ns._luBadge = ns.Tween({
        dur = dur, from = 1, to = 1.15, ease = ns.easeOutCubic,
        set = function(v) badge:SetScale(v) end,
    })
end

local function doDetonate()
    charge:SetAlpha(0); charge:Hide()
    spanBar(detonate, 2)
    detonate:SetAlpha(1); detonate:Show()
    if ns._luDet then ns.KillTween(ns._luDet) end
    ns._luDet = ns.Tween({
        dur = 0.5, from = 1, to = 0, ease = ns.easeOutCubic,
        set = function(v) detonate:SetAlpha(v) end,
        done = function() detonate:Hide() end,
    })
    dip(6, 0.35)
    spanBar(borderGlow, 6)
    borderGlow:SetAlpha(0.35); borderGlow:Show()
    if ns._luBorder then ns.KillTween(ns._luBorder) end
    ns._luBorder = ns.Tween({
        dur = 1.6, from = 0.35, to = 0, ease = ns.easeOutCubic,
        set = function(v) borderGlow:SetAlpha(v) end,
        done = function() borderGlow:Hide() end,
    })
    if ns._luBadge then ns.KillTween(ns._luBadge) end
    ns._luBadge = ns.Tween({
        dur = 0.5, from = 1.15, to = 1, ease = ns.easeOutCubic,
        set = function(v) badge:SetScale(v) end,
    })
end

local function doShatter()
    local col = barTint()
    local w = barWidth()
    for i = 1, #segments do
        local fr = segments[i]
        if fr.ag then
            fr.texture:SetVertexColor(col[1], col[2], col[3], 0.95)
            fr:SetScale(islandScale())
            fr:ClearAllPoints()
            fr:SetPoint("CENTER", barFrame, "LEFT", w * (i / (#segments + 1)), 0)
            local outward = (i - (#segments + 1) / 2) * 9
            fr.tr:SetOffset(outward * islandScale(), -260 * islandScale())
            fr.tr:SetDuration(1)
            fr.tr:SetStartDelay((i - 1) * 0.02)
            if fr.rot then
                local deg = (i % 2 == 0) and 260 or -260
                fr.rot:SetDegrees(deg)
                fr.rot:SetDuration(1)
                fr.rot:SetStartDelay((i - 1) * 0.02)
            end
            fr.al:SetFromAlpha(1); fr.al:SetToAlpha(0); fr.al:SetDuration(1)
            fr.al:SetStartDelay((i - 1) * 0.02)
            fr:Show()
            fr.ag:Stop()
            fr.ag:Play()
        end
    end
end

local function doShockwave()
    for i = 1, #rings do
        local fr = rings[i]
        if fr.ag then
            fr.texture:SetVertexColor(1, 0.82, 0, 0.9)
            fr:SetScale(1)
            fr:ClearAllPoints()
            fr:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
            fr.sc:SetScaleFrom(0.1, 0.1)
            fr.sc:SetScaleTo(5 * islandScale(), 5 * islandScale())
            fr.sc:SetDuration(0.9)
            fr.sc:SetStartDelay(i == 2 and 0.15 or 0)
            fr.al:SetFromAlpha(0.9); fr.al:SetToAlpha(0); fr.al:SetDuration(0.9)
            fr.al:SetStartDelay(i == 2 and 0.15 or 0)
            fr:Show()
            fr.ag:Stop()
            fr.ag:Play()
        end
    end
end

local function doSweep()
    local fr = sweeps[1]
    if not fr.ag then return end
    local w = (f:GetWidth() or 460)
    fr.texture:SetVertexColor(1, 0.93, 0.72, 0.75)
    fr:SetScale(islandScale())
    fr:ClearAllPoints()
    fr:SetPoint("CENTER", f, "LEFT", -(64 * islandScale()), 0)
    fr.tr:SetOffset((w + 128) * islandScale(), 0)
    fr.tr:SetDuration(0.9)
    fr.tr:SetStartDelay(0)
    fr.al:SetFromAlpha(0.8); fr.al:SetToAlpha(0); fr.al:SetDuration(0.9)
    fr.al:SetStartDelay(0)
    fr:Show()
    fr.ag:Stop()
    fr.ag:Play()
end

local function doSparks()
    local w = barWidth()
    local purple = barTint()
    for i = 1, #sparks do
        local fr = sparks[i]
        if fr.ag then
            local pick = (i % 3)
            local cr, cg, cb
            if pick == 0 then cr, cg, cb = 1, 0.82, 0
            elseif pick == 1 then cr, cg, cb = 1, 1, 1
            else cr, cg, cb = purple[1], purple[2], purple[3] end
            fr.texture:SetVertexColor(cr, cg, cb, 0.95)
            fr:SetScale(islandScale())
            fr:ClearAllPoints()
            fr:SetPoint("CENTER", barFrame, "LEFT", w * ((i % 10) / 10), math.random(-8, 8))
            local life = 0.8 + math.random() * 0.6
            local dx = (math.random() - 0.5) * 2 * 300
            fr.tr:SetOffset(dx * islandScale(), -280 * islandScale())
            fr.tr:SetDuration(life)
            fr.tr:SetStartDelay(0)
            fr.al:SetFromAlpha(1); fr.al:SetToAlpha(0); fr.al:SetDuration(life)
            fr.al:SetStartDelay(0)
            fr:Show()
            fr.ag:Stop()
            fr.ag:Play()
        end
    end
end

local function sound()
    local kit = _G.SOUNDKIT and _G.SOUNDKIT.UI_LEVELUP
    if kit and PlaySound then pcall(PlaySound, kit)
    elseif PlaySound then pcall(PlaySound, "LEVELUP") end
end

local function resetFX()
    clearTimers()
    hideOverlays()
    stopParticles()
    if ns._luCharge then ns.KillTween(ns._luCharge) ns._luCharge = nil end
    if ns._luDet then ns.KillTween(ns._luDet) ns._luDet = nil end
    if ns._luBorder then ns.KillTween(ns._luBorder) ns._luBorder = nil end
    if ns._luBadge then ns.KillTween(ns._luBadge) ns._luBadge = nil end
    if ns._luShake then ns.KillTween(ns._luShake) ns._luShake = nil end
    if ns._luDip then ns.KillTween(ns._luDip) ns._luDip = nil end
    ns.island._shakeX, ns.island._shakeY, ns.island._dipY = 0, 0, 0
    if badge then badge:SetScale(1) end
    ns.island:ApplyPosition()
    running = false
end

function ns.PlayLevelUp(newLevel)
    if not (ns.db and ns.db.enabled) then return end
    if ns.db.levelUpFx == false then return end
    if not f:IsShown() then return end

    if running then resetFX() end
    running = true
    ns.levelUpUntil = GetTime() + 2.6

    if not canAnim then
        -- fallback: a single flash and a dip
        spanBar(detonate, 2)
        detonate:SetAlpha(1); detonate:Show()
        ns._luDet = ns.Tween({ dur = 0.6, from = 1, to = 0, ease = ns.easeOutCubic,
            set = function(v) detonate:SetAlpha(v) end, done = function() detonate:Hide(); running = false end })
        dip(6, 0.35)
        sound()
        return
    end

    doCharge(0.9)
    after(0.9, doDetonate)
    after(0.9, doShatter)
    after(0.9, doShockwave)
    after(1.05, doSweep)
    after(1.0, doSparks)
    after(2.4, resetFX)
    sound()
end

ns.On("PLAYER_LEVEL_UP", function(_, level)
    ns.PlayLevelUp(level)
end)
