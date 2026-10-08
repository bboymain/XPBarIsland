local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Custom tooltip: dark panel with a thin border, gold section titles, grey
-- labels and white values, plus the green "Shift-Click to Share" footer.
-- ---------------------------------------------------------------------------
local TT = {}
ns.Tooltip = TT
local W = 270
local PAD_X, PAD_Y = 12, 10

local frame = CreateFrame("Frame", "XPBarIslandTooltip", UIParent)
frame:SetFrameStrata("TOOLTIP")
frame:SetWidth(W)
frame:EnableMouse(false)
frame:SetScript("OnMouseUp", function()
    if TT.noteAction then TT.noteAction() end
end)
TT.frame = frame

local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
bg:SetAllPoints(frame)
ns.Paint(bg, 0.031, 0.039, 0.078, 0.94)

local bd = {}
for i = 1, 4 do
    bd[i] = frame:CreateTexture(nil, "BORDER", nil, 1)
    ns.Paint(bd[i], 0.604, 0.604, 0.604, 1)
end
bd[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
bd[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
bd[1]:SetHeight(1)
bd[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
bd[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
bd[2]:SetHeight(1)
bd[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
bd[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
bd[3]:SetWidth(1)
bd[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
bd[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
bd[4]:SetWidth(1)

local slots = {}
local function slot(i)
    local s = slots[i]
    if not s then
        s = {}
        s.title = frame:CreateFontString(nil, "OVERLAY")
        ns.StyleText(s.title, 14, "bold")
        s.title:SetTextColor(1, 0.82, 0, 1)
        s.k = frame:CreateFontString(nil, "OVERLAY")
        ns.StyleText(s.k, 13, "medium")
        s.k:SetTextColor(0.62, 0.62, 0.62, 1)
        s.v = frame:CreateFontString(nil, "OVERLAY")
        ns.StyleText(s.v, 13, "bold")
        s.v:SetTextColor(1, 1, 1, 1)
        s.v:SetJustifyH("RIGHT")
        slots[i] = s
    end
    return s
end

-- ---------------------------------------------------------------------------
-- Content builders
-- ---------------------------------------------------------------------------
local function addRow(rows, k, v, color)
    rows[#rows + 1] = { k = k, v = v, c = color }
end

function TT:Build(d)
    local sections = {}
    if not d then return sections end
    local compact = ns.db and ns.db.compact

    if d.key == "xp" then
        local bars = math.max(0, math.ceil((1 - (d.pct or 0)) * 20))
        local progress = {}
        addRow(progress, "Current", ns.Comma(d.cur))
        addRow(progress, "Bars to level up", bars .. " of 20")
        addRow(progress, "Remaining", ns.Comma(math.max(0, d.max - d.cur)))
        addRow(progress, "Rested", ns.Comma(ns.xp().rested or 0), ns.Colors.restTag)
        addRow(progress, "After Turn-In", ns.Percent(math.min(1, (d.cur + (d.questTotal or 0)) / (d.max or 1)), 1))
        sections[#sections + 1] = { title = "Progress", rows = progress }

        local pace = {}
        local levelSecs = ns.session:LevelElapsed()
        addRow(pace, "Time This Level", levelSecs and ns.Time(levelSecs) or "--")
        addRow(pace, "Session", ns.Time(ns.session:Elapsed()))
        addRow(pace, "XP per Hour", ns.Comma(ns.round(d.rateValue or 0)))
        addRow(pace, "Time to Level", d.timeToLevel or "--")
        sections[#sections + 1] = { title = "Pace", rows = pace }
    else
        local rows = {}
        for _, s in ipairs(d.stats or {}) do
            addRow(rows, s.k, s.v, s.c)
        end
        sections[#sections + 1] = { title = d.label or "Progress", rows = rows }
    end

    -- Compared with you (real squad members or the fake test party)
    if d.key == "xp" and ns.db.party then
        local rows = {}
        for _, m in ipairs(ns.comms:List()) do
            if m.level and m.xpMax and m.xpMax > 0 then
                local myPct = d.pct or 0
                local theirPct = m.xp / m.xpMax
                local text, color
                if m.level > (d.level or 0) then
                    text, color = (m.level - (d.level or 0)) .. " levels ahead", ns.Colors.rep[1]
                elseif m.level < (d.level or 0) then
                    text, color = ((d.level or 0) - m.level) .. " levels behind", ns.HexA("#FF6A4A")
                else
                    local dif = (myPct - theirPct) * 100
                    if math.abs(dif) < 2 then
                        text, color = "= level with you", ns.Colors.gray
                    elseif dif > 0 then
                        text, color = ns.round(dif) .. "% behind", ns.HexA("#FF6A4A")
                    else
                        text, color = ns.round(-dif) .. "% ahead", ns.Colors.rep[1]
                    end
                end
                addRow(rows, m.name, text, color)
            end
        end
        if #rows > 0 then
            sections[#sections + 1] = { title = ns.L["Compared with You"], rows = rows }
        end
    end

    return sections
end

-- Accepts either the data table (from island) or an explicit title + lines.
function TT:Update(d)
    if self.shown and self.mode == "data" then
        self:Show(d)
    end
end

function TT:Render(sections, note)
    local y = -PAD_Y
    local idx = 0
    for si, sec in ipairs(sections) do
        idx = idx + 1
        local s = slot(idx)
        s.title:ClearAllPoints()
        s.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, y)
        s.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD_X, y)
        s.title:SetText(sec.title or "")
        s.k:SetText(""); s.v:SetText("")
        y = y - 20
        for _, row in ipairs(sec.rows or {}) do
            idx = idx + 1
            local r = slot(idx)
            r.title:SetText("")
            r.k:ClearAllPoints()
            r.k:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, y)
            r.v:ClearAllPoints()
            r.v:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD_X, y)
            r.v:SetWidth(W - PAD_X * 2)
            r.k:SetText(row.k or "")
            r.v:SetText(row.v or "")
            local c = row.c
            if c then r.v:SetTextColor(c[1], c[2], c[3], c[4] or 1)
            else r.v:SetTextColor(1, 1, 1, 1) end
            y = y - 17
        end
        y = y - 6
    end

    if note then
        idx = idx + 1
        local r = slot(idx)
        r.title:SetText("")
        r.k:ClearAllPoints(); r.k:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, y)
        r.v:SetText("")
        r.k:SetText(note)
        r.k:SetTextColor(1, 0.82, 0, 1)
        y = y - 17
    end

    idx = idx + 1
    local foot = slot(idx)
    foot.title:SetText("")
    foot.k:ClearAllPoints()
    foot.k:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, y - 4)
    foot.k:SetTextColor(0.118, 1.0, 0, 1)
    foot.k:SetText("Shift-Click to Share")
    foot.v:SetText("")
    y = y - 22

    for i = idx + 1, #slots do
        slots[i].title:SetText(""); slots[i].k:SetText(""); slots[i].v:SetText("")
    end

    frame:SetHeight(math.abs(y) + PAD_Y)
end

function TT:Position()
    frame:ClearAllPoints()
    frame:SetPoint("TOP", ns.island.frame, "BOTTOM", 0, -8)
end

function TT:Show(d)
    self.mode = "data"
    self.shown = true
    self:Position()
    local note, action
    if d and d.key == "rep" then
        note = "Click to Open the Reputation Panel"
        action = function()
            if _G.ToggleCharacter then pcall(_G.ToggleCharacter, "ReputationFrame")
            elseif _G.ToggleFrame then pcall(_G.ToggleFrame, "ReputationFrame") end
        end
    elseif d and d.key == "honor" then
        note = "Click to Open the PvP Window"
        action = function()
            if _G.TogglePVPUI then pcall(_G.TogglePVPUI)
            elseif _G.ToggleCharacter then pcall(_G.ToggleCharacter, "PVPFrame")
            elseif _G.ToggleFrame then pcall(_G.ToggleFrame, "PVPFrame") end
        end
    end
    self.noteAction = action
    frame:EnableMouse(action ~= nil)
    if d then self:Render(self:Build(d), note) end
    frame:Show()
end

function TT:ShowLines(title, lines)
    self.mode = "lines"
    self.shown = true
    self.noteAction = nil
    frame:EnableMouse(false)
    local sec = { title = title, rows = {} }
    for _, l in ipairs(lines or {}) do addRow(sec.rows, l.k, l.v, l.c) end
    self:Render({ sec }, nil)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", _G.Minimap or UIParent, "BOTTOMRIGHT", 6, 0)
    frame:Show()
end

function TT:Hide()
    self.shown = false
    frame:Hide()
end
