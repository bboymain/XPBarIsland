local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Minimap button: a dark disk, gold ring and gold "XP".  Left-click opens the
-- settings, right-click toggles move mode, drag to reposition it around the
-- ring.  Hidden by default (Settings > Social > "Hide minimap button").
-- ---------------------------------------------------------------------------
local host = _G.Minimap or UIParent
local btn = CreateFrame("Button", "XPBarIslandMinimapButton", host)
btn:SetSize(30, 30)
btn:SetFrameStrata("MEDIUM")
btn:Hide()   -- don't flash on load; shown by UpdateMinimapButton when enabled

btn.bg = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
btn.bg:SetAllPoints(btn)
btn.bg:SetTexture(ns.Media.disk)

btn.ring = btn:CreateTexture(nil, "OVERLAY", nil, 0)
btn.ring:SetAllPoints(btn)
btn.ring:SetTexture(ns.Media.ringThick)

-- thin inner accent ring, inset so it reads as a rim inside the gold border
btn.inner = btn:CreateTexture(nil, "OVERLAY", nil, 1)
btn.inner:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
btn.inner:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
btn.inner:SetTexture(ns.Media.ring)

btn.hl = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
btn.hl:SetAllPoints(btn)
btn.hl:SetTexture(ns.Media.disk)
btn.hl:SetVertexColor(1, 1, 1, 0.22)

btn.label = btn:CreateFontString(nil, "OVERLAY")
ns.StyleText(btn.label, 11, "bold")
btn.label:SetPoint("CENTER", btn, "CENTER", 0, 1)
btn.label:SetText("XP")

function btn:ApplyTheme()
    local th = ns.Theme()
    local gold = ns.HexA(th.gold)
    local ring = ns.HexA(th.ring)
    local trim = ns.HexA(th.trim)
    local bg2 = ns.HexA(th.bg2)
    ns.StyleText(self.label, 11, "bold")
    self.label:SetTextColor(gold[1], gold[2], gold[3], 1)
    self.bg:SetVertexColor(bg2[1], bg2[2], bg2[3], 0.96)
    self.ring:SetVertexColor(trim[1], trim[2], trim[3], 1)
    self.inner:SetVertexColor(ring[1], ring[2], ring[3], 0.55)
end

-- math.atan2 is gone on the modern Lua the newer clients ship; math.atan(y, x)
-- is equivalent and present everywhere.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function updatePos()
    if not _G.Minimap then
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 20)
        return
    end
    local angle = (ns.db and ns.db.minimap and ns.db.minimap.angle) or 220
    local rad = math.rad(angle)
    -- sit the button on the ring: derive the radius from the actual minimap so
    -- it lands correctly on every UI scale and client instead of a fixed 80
    local r = (_G.Minimap:GetWidth() or 140) * 0.5 - 2
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", _G.Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

function ns.UpdateMinimapButton()
    if not btn then return end
    local hide = ns.db and ns.db.minimap and ns.db.minimap.hide
    if hide then btn:Hide() else btn:Show() end
    btn:ApplyTheme()
    updatePos()
end

local dragging = false
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForDrag("LeftButton")

btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        ns.db.move = not ns.db.move
        ns.MarkDirty()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100XPBar Island|r: move mode " .. (ns.db.move and "on" or "off"))
        end
    else
        ns.OpenSettings()
    end
end)

btn:SetScript("OnDragStart", function() dragging = true end)
btn:SetScript("OnDragStop", function() dragging = false end)

btn:SetScript("OnUpdate", function()
    if not dragging or not _G.Minimap then return end
    local mx, my = _G.Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = _G.Minimap:GetEffectiveScale() or 1
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(atan2(cy - my, cx - mx))
    ns.db.minimap = ns.db.minimap or {}
    ns.db.minimap.angle = angle
    updatePos()
end)

btn:SetScript("OnEnter", function()
    ns.Tooltip:ShowLines("XPBar Island", {
        { k = "Left-click", v = "open settings" },
        { k = "Right-click", v = "toggle move mode" },
        { k = "Drag", v = "move this button" },
    })
end)
btn:SetScript("OnLeave", function() ns.Tooltip:Hide() end)

-- keep it pinned to the ring when the minimap is resized / the UI scale changes
if _G.Minimap and _G.Minimap.HookScript then
    _G.Minimap:HookScript("OnSizeChanged", updatePos)
end

ns.OnUpdateLayout(function() if ns.db then ns.UpdateMinimapButton() end end)
