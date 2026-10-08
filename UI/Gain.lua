local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Floating gain text: 18px gold with a black outline, to the right of the
-- island, fades after two seconds with a small upward drift.
-- ---------------------------------------------------------------------------
local gain = CreateFrame("Frame", nil, UIParent)
gain:SetPoint("TOPLEFT", ns.island.frame, "TOPRIGHT", 20, -12)
gain:SetWidth(300)
gain:SetHeight(24)
local fs = gain:CreateFontString(nil, "OVERLAY")
ns.StyleText(fs, 18, "bold", "THICKOUTLINE")
fs:SetPoint("LEFT", gain, "LEFT", 0, 0)
fs:SetJustifyH("LEFT")

local handle
function ns.ShowGain(text, color)
    if not (ns.db and ns.db.enabled) then return end
    fs:SetText(text)
    fs:SetTextColor(color and color[1] or 1, color and color[2] or 0.82, color and color[3] or 0, 1)
    if handle then ns.KillTween(handle) end
    handle = ns.Tween({
        dur = 2,
        from = 0, to = 1,
        ease = ns.easeLinear,
        set = function(_, p)
            local a
            if p < 0.7 then a = 1 else a = 1 - (p - 0.7) / 0.3 end
            fs:SetAlpha(ns.clamp(a, 0, 1))
            gain:SetScale(0.85 + 0.15 * math.min(1, p / 0.12))
            local y = -12 - 12 * p
            gain:ClearAllPoints()
            gain:SetPoint("TOPLEFT", ns.island.frame, "TOPRIGHT", 20, y)
        end,
        done = function()
            fs:SetText("")
            gain:SetScale(1)
        end,
    })
end
