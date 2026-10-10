local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- WoW-flavoured kill-streak announcement.  When the running kill count crosses
-- a tier (see ns.StreakTiers in Data/XP.lua) a small, non-blocking banner pops
-- in just below the island with the tier title, a short sub and the tier
-- colour, then fades out.  Created once and reused; respects the Kill streak
-- toggle and the Animations setting, and plays no sound.
-- ---------------------------------------------------------------------------
local banner = CreateFrame("Frame", nil, UIParent)
banner:SetFrameStrata("MEDIUM")
if banner.SetMouseClickEnabled then banner:SetMouseClickEnabled(false) end
if banner.SetMouseMotionEnabled then banner:SetMouseMotionEnabled(false) end
if banner.EnableMouse then banner:EnableMouse(false) end
ns.island:RegisterUnderLine("tier", banner, 42)

-- Pop the text only; the full-width, 42px stack slot must never scale away
-- from the island's edges while the announcement animates.
local content = CreateFrame("Frame", nil, banner)
content:SetSize(360, 42)
content:SetPoint("CENTER", banner, "CENTER", 0, 0)

local function outlined(fs, size, weight)
    ns.StyleText(fs, size, weight)
    local font, sz = fs:GetFont()
    if not (font and sz and pcall(fs.SetFont, fs, font, sz, "OUTLINE")) then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
end

banner.title = content:CreateFontString(nil, "OVERLAY")
outlined(banner.title, 20, "extrabold")
banner.title:SetPoint("CENTER", content, "CENTER", 0, 9)

banner.sub = content:CreateFontString(nil, "OVERLAY")
outlined(banner.sub, 11, "bold")
banner.sub:SetPoint("CENTER", content, "CENTER", 0, -13)
banner.sub:SetTextColor(1, 1, 1, 1)

-- Pop-in 0.2s, hold 1.0s, fade 0.3s (1.5s total).
local ANIM_IN, HOLD, ANIM_OUT = 0.2, 1.0, 0.3

local tween, hideTimer

function ns.StreakAnnounce(tier, n, newBest)
    if not tier then return end
    if ns.db and ns.db.streak == false then return end
    if ns.db and ns.db.hideCombat then
        local fighting = ns.inCombat or (UnitAffectingCombat and UnitAffectingCombat("player"))
        if fighting then return end
    end

    local col = (ns.HexA and ns.HexA(tier.color or "#FFD100")) or { 1, 0.82, 0 }
    local title = (ns.StreakTitle and ns.StreakTitle(tier)) or tier.title or ""
    local sub = (ns.StreakSub and ns.StreakSub(tier)) or tier.sub or ""
    banner.title:SetText(title)
    banner.title:SetTextColor(col[1], col[2], col[3], 1)
    banner.sub:SetText(sub .. (newBest and "  -  New best!" or ""))

    if tween and ns.KillTween then ns.KillTween(tween) end
    tween = nil
    if hideTimer and ns.CancelTimer then ns.CancelTimer(hideTimer) end
    hideTimer = nil

    ns.island:SetUnderLineVisible("tier", true)
    local animate = ns.db and ns.db.animations ~= "Off" and ns.Tween and ns.easeOutBack
    if not animate then
        banner:SetAlpha(1)
        content:SetScale(1)
    else
        banner:SetAlpha(0)
        content:SetScale(0.9)
        tween = ns.Tween({
            dur = ANIM_IN, from = 0, to = 1, ease = ns.easeOutBack,
            set = function(v)
                banner:SetAlpha(ns.clamp and ns.clamp(v, 0, 1) or v)
                content:SetScale(0.9 + 0.1 * v)
            end,
            done = function() tween = nil end,
        })
    end

    if not ns.After then return end
    hideTimer = ns.After(ANIM_IN + HOLD, function()
        hideTimer = nil
        if tween and ns.KillTween then ns.KillTween(tween) end
        tween = nil
        if not animate or not (ns.Tween and ns.easeOutCubic) then
            ns.island:SetUnderLineVisible("tier", false)
            return
        end
        tween = ns.Tween({
            dur = ANIM_OUT, from = 1, to = 0, ease = ns.easeOutCubic,
            set = function(v) banner:SetAlpha(v) end,
            done = function() tween = nil; ns.island:SetUnderLineVisible("tier", false) end,
        })
    end)
end
