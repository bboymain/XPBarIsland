local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Settings.  The page (header, four tabs, rows, footer) is built once and can
-- be hosted either inside the game's own options window (registered under
-- AddOns) or, when that API is missing, inside a standalone themed window.
-- ---------------------------------------------------------------------------
local W = ns.Widgets

local TABS = { "Display", "Bars", "Behavior", "Social" }
local TYPE_ORDER = { "xp", "rep", "honor", "pet", "skills" }

local PRESETS = {
    Minimal = {
        types = { xp = true },
        hideCombat = true, hideOutOfCombat = false, fade = true, compact = true, autoSwitch = false,
        sparkline = false, party = false, questList = false,
        mode = "Classic", hoverExpand = false,
    },
    Standard = {
        types = { xp = true, rep = true, honor = true, pet = true, skills = true },
        hideCombat = false, hideOutOfCombat = false, fade = false, compact = true, autoSwitch = true,
        sparkline = true, party = true, questList = true,
        mode = "Full", hoverExpand = false,
    },
    Full = {
        types = { xp = true, rep = true, honor = true, pet = true, skills = true },
        hideCombat = false, hideOutOfCombat = false, fade = false, compact = false, autoSwitch = true,
        sparkline = true, party = true, questList = true,
        mode = "Always open", hoverExpand = false,
    },
}

local function setAndRefresh(key, value)
    ns.db[key] = value
    ns.Notify()
    ns.MarkDirty()
end

local function applyPreset(page, name)
    local p = PRESETS[name]
    if not p then return end
    ns.BeginBatch()
    local ok, err = pcall(function()
        for k, v in pairs(p) do
            if k == "types" then
                ns.db.types = ns.db.types or {}
                for _, tk in ipairs(TYPE_ORDER) do
                    ns.db.types[tk] = (p.types[tk] and true) or false
                end
            else
                ns.db[k] = v
            end
        end
        ns.db.preset = name
        if page then page:refreshAll() end
    end)
    ns.EndBatch()
    if not ok then ns.ReportError("applyPreset", err) end
end

local BUILDERS = {}

-- ---------------------------------------------------------------------------
-- Page factory
-- ---------------------------------------------------------------------------
local function fs(parent, size, hex, justify, weight)
    local t = parent:CreateFontString(nil, "OVERLAY")
    ns.StyleText(t, size, weight or "bold", "")
    if hex then t:SetTextColor(ns.Hex(hex)) end
    if justify then t:SetJustifyH(justify) end
    return t
end

local function CreatePage(parent, width, height)
    local page = { rows = {}, tabButtons = {}, activeTab = "Display", width = width, height = height }
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    page.frame = f

    page.title = fs(f, 20, "#FFD100", "LEFT")
    page.title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
    page.title:SetText("XPBar Island")
    page.desc = fs(f, 12, "#9D9D9D", "LEFT", "medium")
    page.desc:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -3)
    page.desc:SetText("Changes apply right away. Type /xpbar to open this page.")

    -- tabs
    local tabRow = CreateFrame("Frame", nil, f)
    tabRow:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
    tabRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -40)
    tabRow:SetHeight(28)
    page.tabRow = tabRow
    local tabLine = tabRow:CreateTexture(nil, "BACKGROUND", nil, 0)
    tabLine:SetPoint("BOTTOMLEFT", tabRow, "BOTTOMLEFT", 0, 0)
    tabLine:SetPoint("BOTTOMRIGHT", tabRow, "BOTTOMRIGHT", 0, 0)
    tabLine:SetHeight(1)
    ns.Paint(tabLine, 0.16, 0.14, 0.09, 1)
    local tx = 0
    for _, name in ipairs(TABS) do
        local b = CreateFrame("Frame", nil, tabRow)
        b:SetHeight(28)
        b.label = fs(b, 13, "#9D9D9D", "CENTER")
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.label:SetText(name)
        b:SetWidth((b.label:GetStringWidth() or 40) + 30)
        b.underline = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        b.underline:SetHeight(2)
        ns.Paint(b.underline, 1, 0.82, 0, 1)
        b.underline:Hide()
        b:EnableMouse(true)
        b.tab = name
        b:SetScript("OnMouseUp", function() page:selectTab(name) end)
        b:SetPoint("LEFT", tabRow, "LEFT", tx, 0)
        tx = tx + b:GetWidth() + 4
        page.tabButtons[#page.tabButtons + 1] = b
    end

    -- scroll + content
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -74)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 44)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - 4, 300)
    scroll:SetScrollChild(content)
    page.scroll = scroll
    page.content = content
    local function onWheel(_, delta)
        local cur = scroll:GetVerticalScroll()
        local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(ns.clamp(cur - delta * 30, 0, maxScroll))
    end
    scroll:SetScript("OnMouseWheel", onWheel)

    -- footer
    local foot = CreateFrame("Frame", nil, f)
    foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(40)
    page.footer = foot
    local fb = foot:CreateTexture(nil, "BACKGROUND", nil, 0)
    fb:SetAllPoints(foot)
    ns.Paint(fb, 0, 0, 0, 0.3)
    local fl = foot:CreateTexture(nil, "BACKGROUND", nil, 1)
    fl:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
    fl:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
    fl:SetHeight(1)
    ns.Paint(fl, 0, 0, 0, 1)
    page.version = fs(foot, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium")
    page.version:SetPoint("LEFT", foot, "LEFT", 0, 0)
    page.version:SetText("XPBar Island " .. ((ns.AddonVersion and ns.AddonVersion()) or "1.0.8"))
    page.contact = W.IconLink(foot, ns.Media.xIcon, ns.OpenContact, "Contact @mainlek on X.com (Twitter)", "Click to copy the link")
    page.contact:SetPoint("LEFT", page.version, "RIGHT", 16, 0)
    page.curseforge = W.IconLink(foot, ns.Media.curseforgeIcon, ns.OpenCurseForge, "CurseForge page", "Click to copy the link")
    page.curseforge:SetPoint("LEFT", page.contact, "RIGHT", 8, 0)

    local okay = W.Button(foot, "Okay", function() ns.CloseSettings() end)
    okay:SetPoint("RIGHT", foot, "RIGHT", -14, 0)
    local apply = W.Button(foot, "Apply", function() ns.Notify(); ns.MarkDirty() end)
    apply:SetPoint("RIGHT", okay, "LEFT", -6, 0)
    local resetPos = W.Button(foot, "Reset position", function()
        ns.db.posX = 0
        ns.db.posY = 0
        ns.island:ApplyPosition()
    end)
    resetPos:SetPoint("RIGHT", apply, "LEFT", -6, 0)
    local resetSession = W.Button(foot, "Reset session", function() ns.session:Reset(); ns.MarkDirty() end)
    resetSession:SetPoint("RIGHT", resetPos, "LEFT", -6, 0)
    page.footerButtons = { resetSession, resetPos, apply, okay, page.contact }

    -- methods
    function page:addRow(row)
        self.rows[#self.rows + 1] = row
        row:Show()
        return row
    end

    function page:layoutRows()
        local y = 0
        for _, r in ipairs(self.rows) do
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            y = y + r:GetHeight()
        end
        content:SetHeight(math.max(1, y + 8))
    end

    function page:clearRows()
        for _, r in ipairs(self.rows) do r:Hide() end
        self.rows = {}
    end

    function page:refreshAll()
        for _, r in ipairs(self.rows) do if r.Refresh then r.Refresh() end end
        local th = ns.Theme()
        for _, b in ipairs(self.tabButtons) do
            b.label:SetTextColor(ns.Hex(b.tab == self.activeTab and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
            if b.tab == self.activeTab then
                ns.Paint(b.underline, ns.Hex(th.gold))
                b.underline:Show()
            else
                b.underline:Hide()
            end
        end
    end

    function page:selectTab(tab)
        self.activeTab = tab
        self:clearRows()
        local b = BUILDERS[tab]
        if b then b(self) end
        self:layoutRows()
        self:refreshAll()
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
    end

    function page:ApplyTheme()
        local th = ns.Theme()
        local gold = ns.HexA(th.gold)
        self.title:SetTextColor(gold[1], gold[2], gold[3], 1)
        ns.StyleText(self.title, 20, "bold")
        for _, r in ipairs(self.footerButtons) do r.Refresh() end
        self:refreshAll()
    end

    return page
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------
local function typesRow(page)
    local row = CreateFrame("Frame", nil, page.content)
    row:SetHeight(46)
    row.label = fs(row, 14, "#ECE6D8", "LEFT")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.label:SetText("Progress types")
    local desc = fs(row, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium")
    desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    desc:SetText("Choose which bars you can switch between")
    row.div = row:CreateTexture(nil, "ARTWORK", nil, 0)
    row.div:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.div:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.div:SetHeight(1)
    ns.Paint(row.div, 0.13, 0.12, 0.09, 1)

    local order = { { "xp", "Experience" }, { "rep", "Reputation" }, { "honor", "Honor" }, { "pet", "Pet Exp" }, { "skills", "Skills" } }
    local holder = CreateFrame("Frame", nil, row)
    holder:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    holder:SetHeight(26)
    local btns = {}
    for i, o in ipairs(order) do
        local b = CreateFrame("Frame", nil, holder)
        b:SetHeight(26)
        b.label = fs(b, 12, "#9D9D9D", "CENTER")
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.label:SetText(o[2])
        b:SetWidth((b.label:GetStringWidth() or 40) + 20)
        b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
        b.bg:SetAllPoints(b)
        b.bd = b:CreateTexture(nil, "BORDER", nil, 1)
        b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
        b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        b:EnableMouse(true)
        b.key = o[1]
        b:SetScript("OnMouseUp", function()
            -- count every enabled type; a type stays selectable even when it
            -- has no data right now, so only block turning off the last one
            local enabled = 0
            for _, tk in ipairs(TYPE_ORDER) do
                if ns.db.types[tk] then enabled = enabled + 1 end
            end
            if ns.db.types[b.key] and enabled <= 1 then return end
            ns.db.types[b.key] = not ns.db.types[b.key]
            ns.data:Sanitize()
            row.Refresh()
            ns.Notify(); ns.MarkDirty()
        end)
        if i == 1 then b:SetPoint("LEFT", holder, "LEFT", 0, 0)
        else b:SetPoint("LEFT", btns[i - 1], "RIGHT", -1, 0) end
        btns[i] = b
    end
    local function refresh()
        local th = ns.Theme()
        for _, b in ipairs(btns) do
            local on = ns.db.types[b.key]
            b.label:SetTextColor(ns.Hex(on and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
            ns.WhiteTexture(b.bg)
            if on then
                ns.Gradient(b.bg, ns.HexA(th.btnPrimary1 or "#3A2C12"), ns.HexA(th.btnPrimary2 or "#1A1409"), false)
                ns.Paint(b.bd, ns.Hex(th.btnRing or th.ring))
            else
                ns.Gradient(b.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
                ns.Paint(b.bd, 0.29, 0.23, 0.11, 1)
            end
        end
    end
    row.Refresh = refresh
    return row
end

local function buildDisplay(page)
    if not ns.db.v1 then
        page:addRow(W.Segmented(page.content, "Preset", "Start from a ready-made setup",
            { { label = "Minimal", value = "Minimal" }, { label = "Standard", value = "Standard" }, { label = "Full", value = "Full" } },
            function() return ns.db.preset end, function(v) applyPreset(page, v) end))
    end

    page:addRow(W.Segmented(page.content, "Theme", "Colours and fonts of the island",
        { { label = "Default", value = "Default" }, { label = "WoW", value = "WoW" }, { label = "Classic", value = "Classic" }, { label = "WoW Forever", value = "WoW Forever" } },
        function() return ns.db.theme end, function(v) setAndRefresh("theme", v) end))

    page:addRow(W.Segmented(page.content, "Display mode", "Classic is a thin bar. Auto-hide appears at the top edge.",
        { { label = "Full", value = "Full" }, { label = "Classic", value = "Classic" }, { label = "Auto-hide", value = "Auto-hide" }, { label = "Always open", value = "Always open" } },
        function() return ns.db.mode end, function(v)
            ns.db.mode = v
            ns.island:ApplyMode()
            ns.Notify(); ns.MarkDirty()
        end))

    page:addRow(W.Slider(page.content, "Size", "Scale of the whole island", 70, 150, 5,
        function() return ns.db.scale end, function(v) setAndRefresh("scale", v) end,
        function(v) return ns.round(v) .. "%" end))

    page:addRow(W.Checkbox(page.content, "Expand on hover", "Off keeps the island small and shows the tooltip only",
        function() return ns.db.hoverExpand end, function(v) setAndRefresh("hoverExpand", v) end))
end

local function buildBars(page)
    page:addRow(typesRow(page))
    page:addRow(W.Checkbox(page.content, "Auto-switch bar", "Show reputation, honor or skills briefly when they change",
        function() return ns.db.autoSwitch end, function(v) setAndRefresh("autoSwitch", v) end))
    if not ns.db.v1 then
        page:addRow(W.Checkbox(page.content, "Reputation bar at max level", "Replace the XP bar with your watched faction",
            function() return ns.db.repAtMax end, function(v) setAndRefresh("repAtMax", v) end))
    end
    page:addRow(W.Checkbox(page.content, "Show portrait", "Your character face next to the bar",
        function() return ns.db.portrait end, function(v) setAndRefresh("portrait", v); ns.island:ApplyPortrait() end))
    page:addRow(W.Checkbox(page.content, "Compact numbers", "Show 9.9K instead of 9,900",
        function() return ns.db.compact end, function(v) setAndRefresh("compact", v) end))
end

local function buildBehavior(page)
    page:addRow(W.Checkbox(page.content, "Hide in combat", "Fade the island out while fighting",
        function() return ns.db.hideCombat end, function(v) setAndRefresh("hideCombat", v) end))
    page:addRow(W.Checkbox(page.content, "Hide out of combat", "Fade the island out while not fighting",
        function() return ns.db.hideOutOfCombat end, function(v) setAndRefresh("hideOutOfCombat", v) end))
    page:addRow(W.Checkbox(page.content, "Fade until hovered", "Keep the island faint until the mouse is over it",
        function() return ns.db.fade end, function(v) setAndRefresh("fade", v); if ns.island then ns.island:UpdateFade() end end))
    page:addRow(W.Checkbox(page.content, "Hide default XP and rep bars", "Use only the island for XP and reputation",
        function() return ns.db.hideBlizzXp end, function(v) setAndRefresh("hideBlizzXp", v) end))
    page:addRow(W.Checkbox(page.content, "Move mode", "Drag the island anywhere on screen",
        function() return ns.db.move end, function(v) setAndRefresh("move", v) end))
    page:addRow(W.Segmented(page.content, "Animations", "Pulsing glow and spring motion",
        { { label = "Always", value = "Always" }, { label = "On hover only", value = "On hover only" }, { label = "Off", value = "Off" } },
        function() return ns.db.animations end, function(v) setAndRefresh("animations", v) end))
    page:addRow(W.Checkbox(page.content, "Kill streak", "Count kills, tag the streak and glow the bar",
        function() return ns.db.streak ~= false end, function(v) setAndRefresh("streak", v) end))
    page:addRow(W.Checkbox(page.content, "Level-up animation", "Supernova burst when you level up",
        function() return ns.db.levelUpFx ~= false end, function(v) setAndRefresh("levelUpFx", v) end))
    page:addRow(W.Checkbox(page.content, "Level-up summary", "Show the stats gained in a card when you level up",
        function() return ns.db.levelUpSummary ~= false end, function(v) setAndRefresh("levelUpSummary", v) end))
    page:addRow(W.Checkbox(page.content, "Show tips", "Welcome and update hints under the island",
        function() return ns.db.tips ~= false end, function(v) setAndRefresh("tips", v) end))
    page:addRow(W.Segmented(page.content, "Bar effect", "Idle effect on the XP fill",
        { { label = "Comet", value = "Comet" }, { label = "Flow", value = "Flow" }, { label = "Shine", value = "Shine" } },
        function() return ns.db.barFx or "Comet" end, function(v) setAndRefresh("barFx", v) end))
    if not ns.db.v1 then
        page:addRow(W.Segmented(page.content, "Motion feel", "How the island expands",
            { { label = "Springy", value = "Springy" }, { label = "Snappy", value = "Snappy" }, { label = "Smooth", value = "Smooth" } },
            function() return ns.db.feel end, function(v) setAndRefresh("feel", v) end))
    end
end

local function buildSocial(page)
    page:addRow(W.Checkbox(page.content, "Party comparison", "See party members who also run XPBar Island",
        function() return ns.db.party end, function(v) setAndRefresh("party", v) end))
    page:addRow(W.Segmented(page.content, "Share channel", "Where Shift-Click posts your progress",
        { { label = "Party", value = "Party" }, { label = "Guild", value = "Guild" }, { label = "Say", value = "Say" } },
        function() return ns.db.shareChannel end, function(v) setAndRefresh("shareChannel", v) end))
    if not ns.db.v1 then
        page:addRow(W.Checkbox(page.content, "Session sparkline", "XP graph in the expanded panel",
            function() return ns.db.sparkline end, function(v) setAndRefresh("sparkline", v) end))
        page:addRow(W.Checkbox(page.content, "Quest list on hover", "Hover Turn-in to see XP per quest",
            function() return ns.db.questList end, function(v) setAndRefresh("questList", v) end))
    end
    page:addRow(W.Checkbox(page.content, "Hide minimap button", "Hide the round button next to the minimap",
        function() return ns.db.minimap and ns.db.minimap.hide end, function(v)
            ns.db.minimap = ns.db.minimap or {}
            ns.db.minimap.hide = v
            ns.UpdateMinimapButton()
        end))
end

BUILDERS.Display = buildDisplay
BUILDERS.Bars = buildBars
BUILDERS.Behavior = buildBehavior
BUILDERS.Social = buildSocial

-- ---------------------------------------------------------------------------
-- Standalone themed window (fallback when the game has no options API)
-- ---------------------------------------------------------------------------
local win, winPage

local function buildWindow()
    win = CreateFrame("Frame", "XPBarIslandSettings", UIParent)
    win:SetSize(740, 410)
    win:SetPoint("TOP", UIParent, "TOP", 0, -60)
    win:SetFrameStrata("DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:EnableMouseWheel(true)
    win:Hide()
    ns.settingsWin = win

    win.bg = win:CreateTexture(nil, "BACKGROUND", nil, 0)
    win.bg:SetAllPoints(win)
    win.trim = win:CreateTexture(nil, "BORDER", nil, 1)
    win.trim:SetPoint("TOPLEFT", win, "TOPLEFT", -2, 2)
    win.trim:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 2, -2)
    win.inner = win:CreateTexture(nil, "BORDER", nil, 2)
    win.inner:SetPoint("TOPLEFT", win, "TOPLEFT", -1, 1)
    win.inner:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 1, -1)

    local titleBar = CreateFrame("Frame", nil, win)
    titleBar:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(34)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() win:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
    local tb = titleBar:CreateTexture(nil, "BACKGROUND", nil, 0)
    tb:SetAllPoints(titleBar)
    ns.Paint(tb, 0, 0, 0, 0.35)
    local tbline = titleBar:CreateTexture(nil, "BACKGROUND", nil, 1)
    tbline:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    tbline:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    tbline:SetHeight(1)
    ns.Paint(tbline, 0, 0, 0, 1)

    win.title = fs(titleBar, 15, "#FFD100", "LEFT")
    win.title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    win.title:SetText("Options")
    win.subtitle = fs(titleBar, 12, "#9D9D9D", "LEFT", "medium")
    win.subtitle:SetPoint("LEFT", win.title, "RIGHT", 8, 0)
    win.subtitle:SetText("AddOns \226\128\186 XPBar Island")

    local close = CreateFrame("Frame", nil, titleBar)
    close:SetSize(22, 22)
    close:SetPoint("RIGHT", titleBar, "RIGHT", -10, 0)
    close.bd = close:CreateTexture(nil, "BORDER", nil, 1)
    close.bd:SetPoint("TOPLEFT", close, "TOPLEFT", -1, 1)
    close.bd:SetPoint("BOTTOMRIGHT", close, "BOTTOMRIGHT", 1, -1)
    close.x = fs(close, 13, "#FFD100", "CENTER")
    close.x:SetPoint("CENTER", close, "CENTER", 0, 0)
    close.x:SetText("x")
    close:EnableMouse(true)
    close:SetScript("OnMouseUp", function() ns.CloseSettings() end)
    win.close = close

    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -34)
    side:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0)
    side:SetWidth(150)
    local sb = side:CreateTexture(nil, "BACKGROUND", nil, 0)
    sb:SetAllPoints(side)
    ns.Paint(sb, 0, 0, 0, 0.3)
    local sline = side:CreateTexture(nil, "BACKGROUND", nil, 1)
    sline:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, 0)
    sline:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
    sline:SetWidth(1)
    ns.Paint(sline, 0, 0, 0, 1)
    local entries = {
        { "Game", false }, { "Interface", false }, { "AddOns", true },
        { "XPBar Island", "sel", true },
    }
    local sy = -10
    for _, e in ipairs(entries) do
        local t = fs(side, 13, "#9D9D9D", "LEFT", "medium")
        t:SetPoint("TOPLEFT", side, "TOPLEFT", e[3] and 26 or 14, sy)
        t:SetText(e[1])
        if e[2] == "sel" then
            t:SetTextColor(1, 1, 1, 1)
            ns.StyleText(t, 13, "bold")
            local hl = side:CreateTexture(nil, "BACKGROUND", nil, 2)
            hl:SetPoint("TOPLEFT", side, "TOPLEFT", 0, sy + 6)
            hl:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, sy + 6)
            hl:SetHeight(20)
            ns.Paint(hl, 1, 0.82, 0, 0.12)
            local bar = side:CreateTexture(nil, "BACKGROUND", nil, 3)
            bar:SetPoint("TOPLEFT", side, "TOPLEFT", 0, sy + 6)
            bar:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 0, sy - 14)
            bar:SetWidth(2)
            ns.Paint(bar, 1, 0.82, 0, 1)
        elseif e[2] then
            t:SetTextColor(1, 0.82, 0, 1)
            ns.StyleText(t, 13, "bold")
        end
        sy = sy - 20
    end

    winPage = CreatePage(win, 554, 372)
    winPage.frame:SetPoint("TOPLEFT", win, "TOPLEFT", 170, -34)

    function win:ApplyTheme()
        local th = ns.Theme()
        local gold = ns.HexA(th.gold)
        ns.WhiteTexture(self.bg)
        ns.Gradient(self.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
        ns.Paint(self.trim, ns.Hex(th.trim))
        ns.Paint(self.inner, ns.Hex(ns.Theme().inner or "#2A1F0E"))
        self.title:SetTextColor(gold[1], gold[2], gold[3], 1)
        ns.Paint(self.close.bd, ns.Hex(th.trim))
        self.close.x:SetTextColor(gold[1], gold[2], gold[3], 1)
        winPage:ApplyTheme()
    end
end

-- ---------------------------------------------------------------------------
-- Blizzard options page
-- ---------------------------------------------------------------------------
local panel, panelPage, optionsCategory
local optionsTried, hasBlizzard = false, false

local function buildOptionsPanel()
    panel = CreateFrame("Frame", "XPBarIslandOptionsPanel", UIParent)
    panel.name = "XPBar Island"
    panel:SetSize(560, 380)
    panelPage = CreatePage(panel, 560, 380)
    panelPage.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.refresh = function() panelPage:ApplyTheme() end
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end

    if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
        local ok, cat = pcall(_G.Settings.RegisterCanvasLayoutCategory, panel, "XPBar Island")
        if ok and cat then
            pcall(_G.Settings.RegisterAddOnCategory, cat)
            optionsCategory = cat
            return true
        end
    end
    if _G.InterfaceOptions_AddCategory then
        local ok = pcall(_G.InterfaceOptions_AddCategory, panel)
        if ok then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function ns.OpenSettings()
    local ui = (ns.db and ns.db.settingsUi) or "Studio"
    if ui == "Classic" then
        -- fall through to the Blizzard/standalone window
    elseif ui == "Quick" then
        ns.OpenQuick()
        return
    else
        ns.OpenStudio()
        return
    end
    if not optionsTried then
        optionsTried = true
        hasBlizzard = buildOptionsPanel()
    end
    if hasBlizzard then
        panelPage:ApplyTheme()
        panelPage:selectTab(panelPage.activeTab)
        if _G.Settings and _G.Settings.OpenToCategory then
            local id = optionsCategory and optionsCategory.GetID and optionsCategory:GetID() or "XPBar Island"
            pcall(_G.Settings.OpenToCategory, id)
        elseif _G.InterfaceOptionsFrame_OpenToCategory then
            pcall(_G.InterfaceOptionsFrame_OpenToCategory, panel)
            pcall(_G.InterfaceOptionsFrame_OpenToCategory, panel)
        end
        return
    end
    if not win then buildWindow() end
    win:ApplyTheme()
    win:Show()
    winPage:selectTab(winPage.activeTab)
end

function ns.CloseSettings()
    if ns.CloseQuick then ns.CloseQuick() end
    if ns.CloseStudio then ns.CloseStudio() end
    if win then win:Hide() end
    if hasBlizzard then
        if _G.InterfaceOptionsFrame then pcall(HideUIPanel, _G.InterfaceOptionsFrame) end
        if _G.SettingsPanel then pcall(HideUIPanel, _G.SettingsPanel) end
    end
end

-- forward declaration: the Quick panel frame (defined further down), referenced
-- by ToggleSettings before the Quick section is reached
local qp, qpContent, qpScroll

function ns.ToggleSettings()
    if (ns.studioPanel and ns.studioPanel:IsShown()) or (qp and qp:IsShown()) or (win and win:IsShown()) then
        ns.CloseSettings()
    else
        ns.OpenSettings()
    end
end

function ns.SelectSettingsTab(tab)
    if panelPage then panelPage:selectTab(tab) end
    if winPage then winPage:selectTab(tab) end
end

-- ===========================================================================
-- Quick panel
-- ===========================================================================
local Quick = { rows = {}, sections = {}, built = false }
ns.Quick = Quick

local function qset(key, value)
    ns.db[key] = value
    ns.db.preset = "Custom"
    ns.Notify()
    ns.MarkDirty()
end

local function qtext(parent, size, hex, justify, weight)
    local t = parent:CreateFontString(nil, "OVERLAY")
    ns.StyleText(t, size, weight or "bold", "")
    if hex then t:SetTextColor(ns.Hex(hex)) end
    if justify then t:SetJustifyH(justify) end
    return t
end

local QP_PRESETS = {
    Minimal = {
        mode = "Classic", hideCombat = true, hideOutOfCombat = false, fade = true, compact = true, autoSwitch = false,
        sparkline = false, party = false, questList = false, portrait = false,
        streak = true, cometOn = true, segFlash = true, charge = true, barsText = true,
        dip = true, partyMotion = false, showDots = false, showRate = false,
        mLevel = true, mName = true, mPct = true, mBars = true, mGain = true,
        mStreak = true, mRested = true, mRate = false, mEta = false,
    },
    Standard = {
        mode = "Full", hideCombat = false, hideOutOfCombat = false, fade = false, compact = true, autoSwitch = true,
        sparkline = true, party = true, questList = true, portrait = true,
        cometOn = true, segFlash = true, charge = true, barsText = true, streak = true,
        dip = true, partyMotion = true,
        showName = true, showRange = true, showPercent = true, showRate = true, showRested = true, showDots = true,
        mLevel = true, mName = true, mPct = true, mBars = true, mGain = true,
        mStreak = true, mRested = true, mRate = false, mEta = false,
    },
    Full = {
        mode = "Full", hideCombat = false, hideOutOfCombat = false, fade = false, compact = false, autoSwitch = true,
        sparkline = true, party = true, questList = true, portrait = true,
        cometOn = true, segFlash = true, charge = true, barsText = true, streak = true,
        dip = true, partyMotion = true,
        showName = true, showRange = true, showPercent = true, showRate = true, showRested = true, showDots = true,
        mLevel = true, mName = true, mPct = true, mBars = true, mGain = true,
        mStreak = true, mRested = true, mRate = true, mEta = true,
    },
}

local function applyQuickPreset(name)
    local p = QP_PRESETS[name]
    if not p then return end
    ns.BeginBatch()
    local ok, err = pcall(function()
        for k, v in pairs(p) do ns.db[k] = v end
        ns.db.preset = name
        if Quick.refresh then Quick.refresh() end
    end)
    ns.EndBatch()
    if not ok then ns.ReportError("applyQuickPreset", err) end
end

-- Deep copy so saved profiles never share nested tables (types, minimap,
-- backup) with the live settings; otherwise editing a setting or applying a
-- profile silently mutates every stored profile.
local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do c[k] = deepCopy(val) end
    return c
end

local function profileSnapshot()
    local t = {}
    for k, v in pairs(ns.db) do
        if k ~= "profiles" and k ~= "profile" and type(v) ~= "function" then t[k] = deepCopy(v) end
    end
    return t
end

local function applyProfile(name)
    local p = ns.db.profiles and ns.db.profiles[name]
    if type(p) ~= "table" then return end
    ns.BeginBatch()
    local ok, err = pcall(function()
        for k, v in pairs(p) do ns.db[k] = deepCopy(v) end
        ns.db.profile = name
        if ns.char then
            if ns.db.switchPerChar then ns.char.profile = name end
            if ns.db.switchPerSpec and _G.GetActiveTalentGroup then
                ns.char.profilesBySpec = ns.char.profilesBySpec or {}
                local spec = _G.GetActiveTalentGroup()
                if spec then ns.char.profilesBySpec[spec] = name end
            end
        end
        if Quick._rebuildProfiles then Quick._rebuildProfiles() end
        if ns.Studio and ns.Studio._rebuildProfiles then ns.Studio._rebuildProfiles() end
        if Quick.refresh then Quick.refresh() end
    end)
    ns.EndBatch()
    if not ok then ns.ReportError("applyProfile", err) end
end
ns.ApplyProfile = applyProfile

ns.On("PLAYER_LOGIN", function()
    if ns.db.switchPerChar and ns.char and ns.char.profile then
        applyProfile(ns.char.profile)
    end
end)

ns.On("ACTIVE_TALENT_GROUP_CHANGED", function()
    if not ns.db.switchPerSpec or not _G.GetActiveTalentGroup then return end
    local spec = _G.GetActiveTalentGroup()
    if not spec or not ns.char then return end
    ns.char.profilesBySpec = ns.char.profilesBySpec or {}
    applyProfile(ns.char.profilesBySpec[spec] or ns.db.profile)
end)

function ns.SaveProfile(name)
    name = name or ns.db.profile or "Default"
    ns.db.profiles = ns.db.profiles or {}
    ns.db.profiles[name] = profileSnapshot()
end

-- Profile pills, built once and reused (pooled).  Returns a rebuild function.
local function makeProfilePills(holder)
    local pool = {}
    local rebuild
    local function ensure(i)
        local b = pool[i]
        if not b then
            b = CreateFrame("Frame", nil, holder)
            b:SetHeight(24)
            b.label = qtext(b, 12, "#9D9D9D", "CENTER")
            b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0); b.bg:SetAllPoints(b)
            b.bd = b:CreateTexture(nil, "BORDER", nil, 1)
            b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1); b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
            b:EnableMouse(true)
            b:SetScript("OnMouseUp", function() if b._click then b._click() end end)
            pool[i] = b
        end
        return b
    end
    rebuild = function()
        local names = {}
        for name in pairs(ns.db.profiles or {}) do names[#names + 1] = name end
        table.sort(names)
        local entries = {}
        for _, name in ipairs(names) do
            entries[#entries + 1] = { text = name, on = (name == ns.db.profile), gap = 2,
                click = function() applyProfile(name) end }
        end
        entries[#entries + 1] = { text = "Save", on = false, gap = 6,
            click = function() ns.SaveProfile(ns.db.profile); rebuild(); ns.Notify() end }
        entries[#entries + 1] = { text = "New", on = false, gap = 2, click = function()
            ns.db.profiles = ns.db.profiles or {}
            local i = 1
            while ns.db.profiles["Profile " .. i] do i = i + 1 end
            ns.db.profiles["Profile " .. i] = profileSnapshot()
            ns.db.profile = "Profile " .. i
            rebuild(); ns.Notify()
        end }
        entries[#entries + 1] = { text = "Delete", on = false, gap = 2, click = function()
            local name = ns.db.profile
            if name and name ~= "Default" and ns.db.profiles[name] then
                ns.db.profiles[name] = nil
                applyProfile("Default")
            end
            rebuild(); ns.Notify()
        end }
        local th = ns.Theme()
        local prev
        for i, e in ipairs(entries) do
            local b = ensure(i)
            b._click = e.click
            b.label:SetText(e.text)
            b:SetWidth((b.label:GetStringWidth() or 40) + 16)
            b:ClearAllPoints()
            if prev then b:SetPoint("LEFT", prev, "RIGHT", e.gap, 0) else b:SetPoint("LEFT", holder, "LEFT", 0, 0) end
            b.label:SetTextColor(ns.Hex(e.on and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
            ns.WhiteTexture(b.bg)
            if e.on then
                ns.Gradient(b.bg, ns.HexA(th.btnPrimary1 or "#3A2C12"), ns.HexA(th.btnPrimary2 or "#1A1409"), false)
                ns.Paint(b.bd, ns.Hex(th.btnRing or th.ring))
            else
                ns.Gradient(b.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
                ns.Paint(b.bd, 0.29, 0.23, 0.11, 1)
            end
            b:Show()
            prev = b
        end
        for i = #entries + 1, #pool do pool[i]:Hide() end
    end
    return rebuild
end

local function addRow(s, row)
    row:SetParent(s.body)
    s.rows[#s.rows + 1] = row
    Quick.rows[#Quick.rows + 1] = row
    return row
end

local function qsect(key, title, summary, build)
    local s = { key = key, title = title, summary = summary, rows = {}, open = (key == "Display") }
    local header = CreateFrame("Frame", nil, qpContent)
    header:SetHeight(36)
    header.name = qtext(header, 14, "#FFD100", "LEFT")
    header.name:SetPoint("LEFT", header, "LEFT", 0, 0)
    header.name:SetText(title)
    header.sum = qtext(header, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium")
    header.sum:SetPoint("LEFT", header.name, "RIGHT", 8, 0)
    header.sum:SetText(summary or "")
    header.arrow = qtext(header, 12, "#9D9D9D", "RIGHT")
    header.arrow:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    header.div = header:CreateTexture(nil, "ARTWORK", nil, 0)
    header.div:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    header.div:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    header.div:SetHeight(1)
    ns.Paint(header.div, 0.13, 0.12, 0.09, 1)
    header:EnableMouse(true)
    header:SetScript("OnMouseUp", function() Quick:toggle(key) end)
    s.header = header
    s.body = CreateFrame("Frame", nil, qpContent)
    Quick.sections[#Quick.sections + 1] = s
    build(s)
    return s
end

local function qswitch(s, key, label, desc, invert)
    return addRow(s, W.Switch(s.body, label, desc,
        function() return invert and (ns.db[key] == false) or (ns.db[key] ~= false) end,
        function(v) qset(key, invert and (not v) or v) end))
end

-- "Fade until hovered" needs to re-apply the alpha immediately, so it gets a
-- dedicated row instead of the generic qswitch.
local function qfade(s)
    return addRow(s, W.Switch(s.body, "Fade until hovered", "Keep the island faint until the mouse is over it",
        function() return ns.db.fade end,
        function(v)
            ns.db.fade = v
            ns.db.preset = "Custom"
            ns.Notify(); ns.MarkDirty()
            if ns.island then ns.island:UpdateFade() end
        end))
end

local function qseg(s, key, label, desc, options, default)
    return addRow(s, W.Segmented(s.body, label, desc, options,
        function() return ns.db[key] or default end,
        function(v) qset(key, v) end))
end

local function qslider(s, key, label, desc, min, max, step, fmt, default)
    return addRow(s, W.Slider(s.body, label, desc, min, max, step,
        function() return ns.db[key] or default end,
        function(v) qset(key, v) end, fmt))
end

local function typesRowQuick(s)
    local row = CreateFrame("Frame", nil, s.body)
    row:SetHeight(46)
    row.label = qtext(row, 14, "#ECE6D8", "LEFT")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.label:SetText("Progress types")
    local desc = qtext(row, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium")
    desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    desc:SetText("Choose which bars you can switch between")
    local holder = CreateFrame("Frame", nil, row)
    holder:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    holder:SetHeight(26)
    local order = { { "xp", "Experience" }, { "rep", "Reputation" }, { "honor", "Honor" }, { "pet", "Pet Exp" }, { "skills", "Skills" } }
    local btns = {}
    for i, o in ipairs(order) do
        local b = CreateFrame("Frame", nil, holder)
        b:SetHeight(26)
        b.label = qtext(b, 12, "#9D9D9D", "CENTER")
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.label:SetText(o[2])
        b:SetWidth((b.label:GetStringWidth() or 40) + 20)
        b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
        b.bg:SetAllPoints(b)
        b.bd = b:CreateTexture(nil, "BORDER", nil, 1)
        b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
        b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        b:EnableMouse(true)
        b.key = o[1]
        b:SetScript("OnMouseUp", function()
            local enabled = 0
            for _, tk in ipairs(TYPE_ORDER) do
                if ns.db.types[tk] then enabled = enabled + 1 end
            end
            if ns.db.types[b.key] and enabled <= 1 then
                b.bd:SetVertexColor(1, 0.2, 0.2, 1)
                ns.After(0.3, function() row.Refresh() end)
                return
            end
            ns.db.types[b.key] = not ns.db.types[b.key]
            ns.data:Sanitize()
            row.Refresh(); ns.Notify(); ns.MarkDirty()
        end)
        if i == 1 then b:SetPoint("LEFT", holder, "LEFT", 0, 0)
        else b:SetPoint("LEFT", btns[i - 1], "RIGHT", -1, 0) end
        btns[i] = b
    end
    row.Refresh = function()
        local th = ns.Theme()
        for _, b in ipairs(btns) do
            local on = ns.db.types[b.key]
            b.label:SetTextColor(ns.Hex(on and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
            ns.WhiteTexture(b.bg)
            if on then
                ns.Gradient(b.bg, ns.HexA(th.btnPrimary1 or "#3A2C12"), ns.HexA(th.btnPrimary2 or "#1A1409"), false)
                ns.Paint(b.bd, ns.Hex(th.btnRing or th.ring))
            else
                ns.Gradient(b.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
                ns.Paint(b.bd, 0.29, 0.23, 0.11, 1)
            end
        end
    end
    row.Refresh()
    return addRow(s, row)
end

local function buildQuick()
    qp = CreateFrame("Frame", "XPBarIslandQuickPanel", UIParent)
    qp:SetSize(490, 520)
    qp:SetPoint("TOP", UIParent, "TOP", 0, -70)
    qp:SetFrameStrata("DIALOG")
    qp:SetClampedToScreen(true)
    qp:SetMovable(true)
    qp:EnableMouse(true)
    qp:EnableMouseWheel(true)
    qp:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "XPBarIslandQuickPanel") end
    ns.quickPanel = qp

    qp.bg = qp:CreateTexture(nil, "BACKGROUND", nil, 0)
    qp.bg:SetAllPoints(qp)
    qp.trim = {}
    for i = 1, 4 do qp.trim[i] = qp:CreateTexture(nil, "BORDER", nil, 1) end
    qp.outer = {}
    for i = 1, 4 do qp.outer[i] = qp:CreateTexture(nil, "BORDER", nil, 2) end
    local function qpEdges()
        local t = qp.trim
        t[1]:ClearAllPoints(); t[1]:SetPoint("TOPLEFT", qp, "TOPLEFT", 0, 0); t[1]:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 0, 0); t[1]:SetHeight(2)
        t[2]:ClearAllPoints(); t[2]:SetPoint("BOTTOMLEFT", qp, "BOTTOMLEFT", 0, 0); t[2]:SetPoint("BOTTOMRIGHT", qp, "BOTTOMRIGHT", 0, 0); t[2]:SetHeight(2)
        t[3]:ClearAllPoints(); t[3]:SetPoint("TOPLEFT", qp, "TOPLEFT", 0, 0); t[3]:SetPoint("BOTTOMLEFT", qp, "BOTTOMLEFT", 0, 0); t[3]:SetWidth(2)
        t[4]:ClearAllPoints(); t[4]:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 0, 0); t[4]:SetPoint("BOTTOMRIGHT", qp, "BOTTOMRIGHT", 0, 0); t[4]:SetWidth(2)
        local o = qp.outer
        o[1]:ClearAllPoints(); o[1]:SetPoint("TOPLEFT", qp, "TOPLEFT", -1, 1); o[1]:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 1, 1); o[1]:SetHeight(1)
        o[2]:ClearAllPoints(); o[2]:SetPoint("BOTTOMLEFT", qp, "BOTTOMLEFT", -1, -1); o[2]:SetPoint("BOTTOMRIGHT", qp, "BOTTOMRIGHT", 1, -1); o[2]:SetHeight(1)
        o[3]:ClearAllPoints(); o[3]:SetPoint("TOPLEFT", qp, "TOPLEFT", -1, 1); o[3]:SetPoint("BOTTOMLEFT", qp, "BOTTOMLEFT", -1, -1); o[3]:SetWidth(1)
        o[4]:ClearAllPoints(); o[4]:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 1, 1); o[4]:SetPoint("BOTTOMRIGHT", qp, "BOTTOMRIGHT", 1, -1); o[4]:SetWidth(1)
    end
    qpEdges()

    local bar = CreateFrame("Frame", nil, qp)
    bar:SetPoint("TOPLEFT", qp, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 0, 0)
    bar:SetHeight(38)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() qp:StartMoving() end)
    bar:SetScript("OnDragStop", function() qp:StopMovingOrSizing() end)
    qp.title = qtext(bar, 17, "#FFD100", "LEFT")
    qp.title:SetPoint("LEFT", bar, "LEFT", 12, 0)
    qp.title:SetText("XPBar Island")
    qp.sub = qtext(bar, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium")
    qp.sub:SetPoint("LEFT", qp.title, "RIGHT", 8, 0)
    qp.sub:SetText("Live")
    local close = CreateFrame("Frame", nil, bar)
    close:SetSize(26, 26)
    close:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    close.bd = close:CreateTexture(nil, "BORDER", nil, 1)
    close.bd:SetPoint("TOPLEFT", close, "TOPLEFT", -1, 1)
    close.bd:SetPoint("BOTTOMRIGHT", close, "BOTTOMRIGHT", 1, -1)
    close.x = qtext(close, 14, "#FFD100", "CENTER")
    close.x:SetPoint("CENTER", close, "CENTER", 0, 0)
    close.x:SetText("x")
    close:EnableMouse(true)
    close:SetScript("OnMouseUp", function() ns.CloseSettings() end)

    -- presets
    local pres = CreateFrame("Frame", nil, qp)
    pres:SetPoint("TOPLEFT", qp, "TOPLEFT", 12, -42)
    pres:SetPoint("TOPRIGHT", qp, "TOPRIGHT", -12, -42)
    pres:SetHeight(40)
    qp.presetButtons = {}
    local defs = { { "Minimal", "Thin bar, light effects" }, { "Standard", "Balanced" }, { "Full", "Everything on" } }
    local px = 0
    for _, d in ipairs(defs) do
        local b = CreateFrame("Frame", nil, pres)
        b:SetSize(150, 38)
        b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0); b.bg:SetAllPoints(b)
        b.bd = b:CreateTexture(nil, "BORDER", nil, 1)
        b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1); b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        b.name = qtext(b, 13, "#9D9D9D", "CENTER")
        b.name:SetPoint("TOP", b, "TOP", 0, -5)
        b.name:SetText(d[1])
        b.desc = qtext(b, 9, (ns.Theme().grey or "#8F8777"), "CENTER", "medium")
        b.desc:SetPoint("BOTTOM", b, "BOTTOM", 0, 5)
        b.desc:SetText(d[2])
        b:EnableMouse(true)
        b.key = d[1]
        b:SetScript("OnMouseUp", function() applyQuickPreset(b.key) end)
        b:SetPoint("LEFT", pres, "LEFT", px, 0)
        px = px + 156
        qp.presetButtons[#qp.presetButtons + 1] = b
    end

    -- preview
    local pv = CreateFrame("Frame", nil, qp)
    pv:SetPoint("TOPLEFT", qp, "TOPLEFT", 12, -88)
    pv:SetPoint("TOPRIGHT", qp, "TOPRIGHT", -12, -88)
    pv:SetHeight(24)
    local pl = qtext(pv, 12, (ns.Theme().grey or "#8F8777"), "LEFT", "medium")
    pl:SetPoint("LEFT", pv, "LEFT", 0, 0)
    pl:SetText("Preview")
    local pd = qtext(pv, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium")
    pd:SetPoint("LEFT", pl, "RIGHT", 8, 0)
    pd:SetText("The island above updates live")
    local playXP = W.Button(pv, "Play XP gain", function() if ns.TestXPGain then ns.TestXPGain(1200) end end)
    playXP:SetPoint("RIGHT", pv, "RIGHT", -100, 0)
    local playLU = W.Button(pv, "Play level-up", function() if ns.PlayLevelUp then ns.PlayLevelUp(UnitLevel("player") or 1) end end)
    playLU:SetPoint("RIGHT", pv, "RIGHT", 0, 0)

    -- scroll
    qpScroll = CreateFrame("ScrollFrame", nil, qp)
    qpScroll:SetPoint("TOPLEFT", qp, "TOPLEFT", 12, -116)
    qpScroll:SetPoint("BOTTOMRIGHT", qp, "BOTTOMRIGHT", -12, 46)
    qpScroll:EnableMouseWheel(true)
    qpContent = CreateFrame("Frame", nil, qpScroll)
    qpContent:SetSize(460, 300)
    qpScroll:SetScrollChild(qpContent)
    qpScroll:SetScript("OnMouseWheel", function(_, delta)
        local cur = qpScroll:GetVerticalScroll()
        local maxS = math.max(0, qpContent:GetHeight() - qpScroll:GetHeight())
        qpScroll:SetVerticalScroll(ns.clamp(cur - delta * 30, 0, maxS))
    end)

    -- sections
    qsect("Display", "Display", "Theme, mode, size", function(s)
        qseg(s, "theme", "Theme", "Colours and fonts", {
            { label = "Default", value = "Default" }, { label = "WoW", value = "WoW" },
            { label = "Classic", value = "Classic" }, { label = "WoW Forever", value = "WoW Forever" } }, "Default")
        qseg(s, "mode", "Display mode", "Classic is a thin bar", {
            { label = "Full", value = "Full" }, { label = "Classic", value = "Classic" },
            { label = "Auto-hide", value = "Auto-hide" }, { label = "Always open", value = "Always open" } }, "Full")
        qslider(s, "scale", "Size", "Scale of the whole island", 70, 150, 5, function(v) return ns.round(v) .. "%" end, 100)
        qswitch(s, "hoverExpand", "Expand on hover", "Open the panel when hovered")
    end)

    qsect("Bars", "Bars", "Types, portrait, numbers", function(s)
        typesRowQuick(s)
        qswitch(s, "autoSwitch", "Auto-switch bar", "Show a type briefly when it changes")
        qswitch(s, "repAtMax", "Reputation bar at max level", "Replace XP with your watched faction")
        qswitch(s, "portrait", "Show portrait", "Your character face next to the bar")
        qswitch(s, "compact", "Compact numbers", "Show 9.9K instead of 9,900")
    end)

    qsect("Behavior", "Behavior", "Combat, motion, level-up", function(s)
        qswitch(s, "hideCombat", "Hide in combat", "Fade out while fighting")
        qswitch(s, "hideOutOfCombat", "Hide out of combat", "Fade out while not fighting")
        qfade(s)
        qswitch(s, "hideBlizzXp", "Hide default XP and rep bars", "Use only the island for XP and reputation")
        qswitch(s, "move", "Move mode", "Drag the island anywhere on screen")
        qseg(s, "animations", "Animations", "Pulsing and motion", {
            { label = "Always", value = "Always" }, { label = "On hover only", value = "On hover only" },
            { label = "Off", value = "Off" } }, "Always")
        qseg(s, "feel", "Motion feel", "How the island expands", {
            { label = "Springy", value = "Springy" }, { label = "Snappy", value = "Snappy" },
            { label = "Smooth", value = "Smooth" } }, "Springy")
        qswitch(s, "streak", "Kill streak", "Count kills and glow the bar")
        qswitch(s, "levelUpFx", "Level-up animation", "Supernova burst when you level up")
        qswitch(s, "levelUpSummary", "Level-up summary", "Card with the stats gained on level-up")
    end)

    qsect("Effects", "Effects", "Idle and gain effects", function(s)
        local h1 = qtext(s.body, 11, "#FFD100", "LEFT")
        h1:SetText("XP BAR")
        addRow(s, h1)
        qswitch(s, "cometOn", "Comet pulse", "Idle sweep on the XP fill")
        qswitch(s, "segFlash", "Segment flashes", "Flash each segment the fill crosses")
        qswitch(s, "charge", "Charge-up glow", "Gold glow past 80%")
        qswitch(s, "barsText", "Bars to level up", "Show the bars count")
        qswitch(s, "streak", "Kill streak", "Streak tag and bar glow")
        local h2 = qtext(s.body, 11, "#FFD100", "LEFT")
        h2:SetText("ISLAND")
        addRow(s, h2)
        qswitch(s, "dip", "Gain dip", "Island nudges down on a gain")
        local h3 = qtext(s.body, 11, "#FFD100", "LEFT")
        h3:SetText("PARTY")
        addRow(s, h3)
        qswitch(s, "partyMotion", "Party motion", "Animate party dots")
    end)

    qsect("Customize", "Customize", "Colors, layout, size, profiles", function(s)
        local pcol = { "#6F5326", "#2F6577", "#4D6B2F", "#53487A", "#7A2F2F", "#8A8A8A", "#C79C6E", "#2F7A63" }
        local bcol = { "#8A1FB0", "#1F6FB8", "#22A03A", "#C25A00", "#B01F3A", "#D6B100", "#2FA89A" }
        local tcol = { "#FFD100", "#FFFFFF", "#7BE8C3", "#69CCF0", "#FF9A2E", "#F5D98A" }
        addRow(s, W.ColorRow(s.body, "Trim color", "Border, ring and dividers", pcol,
            function() return ns.db.trimColor end, function(v) qset("trimColor", v) end))
        addRow(s, W.ColorRow(s.body, "Bar color", "The XP fill only", bcol,
            function() return ns.db.barColor end, function(v) qset("barColor", v) end))
        addRow(s, W.ColorRow(s.body, "Text accent", "Name, titles and numbers", tcol,
            function() return ns.db.textAccent end, function(v) qset("textAccent", v) end))
        qswitch(s, "showName", "Name", "Show the type name")
        qswitch(s, "showRange", "Range", "Show current / max")
        qswitch(s, "showPercent", "Percent", "Show the percentage")
        qswitch(s, "showRested", "Rested tag", "Show the Resting tag")
        qswitch(s, "showRate", "Rate block", "Show XP/hr and kills")
        qswitch(s, "showDots", "Party dots", "Show party markers on the bar")
        qswitch(s, "portrait", "Portrait", "Show the portrait")
        qslider(s, "width", "Width", "Island width", 380, 560, 10, function(v) return ns.round(v) .. "px" end, 460)
        qslider(s, "barThickness", "Bar thickness", "Bar height", 8, 18, 1, function(v) return ns.round(v) .. "px" end, 12)
        qslider(s, "textSize", "Text size", "Font scale", 80, 130, 5, function(v) return ns.round(v) .. "%" end, 100)
        qslider(s, "speed", "Speed", "Animation speed", 50, 150, 10, function(v) return ns.round(v) .. "%" end, 100)
        qslider(s, "strength", "Strength", "Animation strength", 0, 150, 10, function(v) return ns.round(v) .. "%" end, 100)
        qseg(s, "font", "Font", "Text font", {
            { label = "Theme", value = "Theme" }, { label = "Alegreya Sans", value = "Alegreya" },
            { label = "Friz Quadrata", value = "Friz" }, { label = "Morpheus", value = "Morpheus" } }, "Theme")
        addRow(s, W.Button(s.body, "Reset customization", function()
            ns.BeginBatch()
            local ok, err = pcall(function()
                qset("trimColor", false); qset("barColor", false); qset("textAccent", false); qset("wowBar", "Azure")
                qset("width", 460); qset("barThickness", 12); qset("textSize", 100)
                qset("speed", 100); qset("strength", 100); qset("font", "Theme")
                if Quick.refresh then Quick.refresh() end
            end)
            ns.EndBatch()
            if not ok then ns.ReportError("resetCustomization", err) end
        end))

        -- profiles
        local profRow = CreateFrame("Frame", nil, s.body)
        profRow:SetHeight(30)
        local pl = qtext(profRow, 14, "#ECE6D8", "LEFT")
        pl:SetPoint("LEFT", profRow, "LEFT", 0, 0); pl:SetText("Profile")
        local pholder = CreateFrame("Frame", nil, profRow)
        pholder:SetPoint("RIGHT", profRow, "RIGHT", 0, 0); pholder:SetHeight(24)
        local rebuildProfiles = makeProfilePills(pholder)
        rebuildProfiles()
        addRow(s, profRow)
        qswitch(s, "switchPerChar", "Switch per character", "Remember the profile per character")
        if _G.GetActiveTalentGroup then
            qswitch(s, "switchPerSpec", "Switch per spec", "Remember the profile per spec")
        end

        -- position
        local posRow = CreateFrame("Frame", nil, s.body)
        posRow:SetHeight(30)
        local posl = qtext(posRow, 14, "#ECE6D8", "LEFT")
        posl:SetPoint("LEFT", posRow, "LEFT", 0, 0); posl:SetText("Position")
        local posh = CreateFrame("Frame", nil, posRow)
        posh:SetPoint("RIGHT", posRow, "RIGHT", 0, 0); posh:SetHeight(24)
        local prevp
        local function posBtn(text, fn, w)
            local b = CreateFrame("Frame", nil, posh)
            b:SetHeight(24)
            b.label = qtext(b, 12, "#FFD100", "CENTER")
            b.label:SetPoint("CENTER", b, "CENTER", 0, 0); b.label:SetText(text)
            b:SetWidth(w or ((b.label:GetStringWidth() or 20) + 16))
            b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0); b.bg:SetAllPoints(b)
            b.bd = b:CreateTexture(nil, "BORDER", nil, 1)
            b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1); b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
            ns.Paint(b.bd, 0.29, 0.23, 0.11, 1)
            b:EnableMouse(true)
            b:SetScript("OnMouseUp", fn)
            if prevp then b:SetPoint("LEFT", prevp, "RIGHT", 2, 0) else b:SetPoint("LEFT", posh, "LEFT", 0, 0) end
            prevp = b
        end
        posBtn("Left", function() qset("posOffset", -330); if ns.island then ns.island:ApplyPosition() end end)
        posBtn("Center", function() qset("posOffset", 0); if ns.island then ns.island:ApplyPosition() end end)
        posBtn("Right", function() qset("posOffset", 330); if ns.island then ns.island:ApplyPosition() end end)
        local function nudge(d)
            qset("posOffset", ns.clamp((ns.db.posOffset or 0) + d, -380, 380))
            if ns.island then ns.island:ApplyPosition() end
        end
        posBtn("\226\151\128", function() nudge(-30) end, 24)
        posBtn("\226\150\182", function() nudge(30) end, 24)
        addRow(s, posRow)
        Quick._rebuildProfiles = rebuildProfiles
    end)

    qsect("Minimal", "Minimal", "Choose what the thin bar shows", function(s)
        local h = qtext(s.body, 11, "#FFD100", "LEFT")
        h:SetText("SHOWN ON THE THIN BAR")
        addRow(s, h)
        qswitch(s, "mLevel", "Level", "Level box")
        qswitch(s, "mName", "Name", "Type name")
        qswitch(s, "mPct", "Percent", "Percentage")
        qswitch(s, "mBars", "Bars to level up", "e.g. 8 bars")
        qswitch(s, "mGain", "Gain text", "+N XP on a gain")
        qswitch(s, "mStreak", "Kill streak", "xN while a streak runs")
        qswitch(s, "mRested", "Rested", "Blue Resting")
        qswitch(s, "mRate", "XP per hour", "e.g. 41.2k/hr")
        qswitch(s, "mEta", "Time or kills to level", "e.g. ~38 kills")
        addRow(s, W.Button(s.body, "Reset Minimal", function()
            qset("mLevel", true); qset("mName", true); qset("mPct", true); qset("mBars", true)
            qset("mGain", true); qset("mStreak", true); qset("mRested", true)
            qset("mRate", false); qset("mEta", false)
            if Quick.refresh then Quick.refresh() end
        end))
    end)

    qsect("Social", "Social", "Party and sharing", function(s)
        qswitch(s, "party", "Party comparison", "See party members running the addon")
        qseg(s, "shareChannel", "Share channel", "Where Shift-Click posts", {
            { label = "Party", value = "Party" }, { label = "Guild", value = "Guild" },
            { label = "Say", value = "Say" } }, "Party")
        qswitch(s, "sparkline", "Session sparkline", "XP graph in the panel")
        qswitch(s, "questList", "Quest list on hover", "Hover Turn-in for XP per quest")
        addRow(s, W.Switch(s.body, "Minimap button", "Show the round button next to the minimap",
            function() return not (ns.db.minimap and ns.db.minimap.hide) end,
            function(v)
                ns.db.minimap = ns.db.minimap or {}
                ns.db.minimap.hide = not v
                if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
                ns.Notify(); ns.MarkDirty()
            end))
    end)

    -- footer
    local foot = CreateFrame("Frame", nil, qp)
    foot:SetPoint("BOTTOMLEFT", qp, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", qp, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(40)
    local fb = foot:CreateTexture(nil, "BACKGROUND", nil, 0)
    fb:SetAllPoints(foot)
    ns.Paint(fb, 0, 0, 0, 0.3)
    local resetS = W.Button(foot, "Reset session", function() if ns.session then ns.session:Reset() end; ns.MarkDirty() end)
    resetS:SetPoint("LEFT", foot, "LEFT", 12, 0)
    local resetP = W.Button(foot, "Reset position", function() ns.db.posX = 0; ns.db.posY = 0; ns.db.posOffset = 0; if ns.island then ns.island:ApplyPosition() end end)
    resetP:SetPoint("LEFT", resetS, "RIGHT", 6, 0)
    local contact = W.IconLink(foot, ns.Media.xIcon, ns.OpenContact, "Contact @mainlek on X.com (Twitter)", "Click to copy the link")
    contact:SetPoint("LEFT", resetP, "RIGHT", 14, 0)
    local curseforge = W.IconLink(foot, ns.Media.curseforgeIcon, ns.OpenCurseForge, "CurseForge page", "Click to copy the link")
    curseforge:SetPoint("LEFT", contact, "RIGHT", 8, 0)
    local okay = W.Button(foot, "Okay", function() ns.CloseSettings() end)
    okay:SetPoint("RIGHT", foot, "RIGHT", -12, 0)
    local apply = W.Button(foot, "Apply", function() ns.Notify(); ns.MarkDirty() end)
    apply:SetPoint("RIGHT", okay, "LEFT", -6, 0)
    okay.Refresh = function()
        local th = ns.Theme()
        ns.WhiteTexture(okay.bg)
        ns.Gradient(okay.bg, ns.HexA(th.btnPrimary1 or "#7A5A16"), ns.HexA(th.btnPrimary2 or "#3A2C12"), false)
        for i = 1, 4 do ns.Paint(okay.bd[i], ns.Hex(th.ring)) end
        okay.label:SetTextColor(ns.Hex(th.btnText or th.pillText or th.gold))
    end
    qp.footerButtons = { resetS, resetP, apply, okay, contact, curseforge }

    Quick:layout()
    Quick.refresh = function()
        for _, r in ipairs(Quick.rows) do if r.Refresh then r.Refresh() end end
        local th = ns.Theme()
        for _, s in ipairs(Quick.sections) do
            s.header.name:SetTextColor(ns.Hex(s.open and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
            s.header.arrow:SetText(s.open and "\226\150\178" or "\226\150\188")
        end
        for _, b in ipairs(qp.presetButtons) do
            local on = (ns.db.preset == b.key)
            ns.WhiteTexture(b.bg)
            if on then ns.Gradient(b.bg, ns.HexA(th.btnPrimary1 or "#3A2C12"), ns.HexA(th.btnPrimary2 or "#1A1409"), false); ns.Paint(b.bd, ns.Hex(th.btnRing or th.ring))
            else ns.Gradient(b.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false); ns.Paint(b.bd, 0.29, 0.23, 0.11, 1) end
            b.name:SetTextColor(ns.Hex(on and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
        end
        for _, b in ipairs(qp.footerButtons) do if b.Refresh then b.Refresh() end end
    end
    Quick.applyTheme = function()
        local th = ns.Theme()
        ns.WhiteTexture(qp.bg)
        ns.Gradient(qp.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
        for i = 1, 4 do ns.Paint(qp.trim[i], ns.Hex(th.trim)) end
        for i = 1, 4 do ns.Paint(qp.outer[i], 0, 0, 0, 1) end
        qp.title:SetTextColor(ns.Hex(th.gold))
        Quick.refresh()
    end
    Quick.built = true
end

function Quick:toggle(key)
    for _, s in ipairs(self.sections) do s.open = (s.key == key and not s.open) end
    self:layout()
    if self.refresh then self:refresh() end
end

function Quick:layout()
    local y = 0
    for _, s in ipairs(self.sections) do
        s.header:ClearAllPoints()
        s.header:SetPoint("TOPLEFT", qpContent, "TOPLEFT", 0, -y)
        s.header:SetPoint("TOPRIGHT", qpContent, "TOPRIGHT", 0, -y)
        y = y + 36
        if s.open then
            s.body:ClearAllPoints()
            s.body:SetPoint("TOPLEFT", qpContent, "TOPLEFT", 0, -y)
            s.body:SetPoint("TOPRIGHT", qpContent, "TOPRIGHT", 0, -y)
            local by = 0
            for _, r in ipairs(s.rows) do
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", s.body, "TOPLEFT", 0, -by)
                r:SetPoint("TOPRIGHT", s.body, "TOPRIGHT", 0, -by)
                by = by + r:GetHeight()
            end
            s.body:SetHeight(math.max(1, by))
            s.body:Show()
            y = y + by
        else
            s.body:Hide()
        end
    end
    qpContent:SetHeight(math.max(1, y + 8))
end

function ns.SelfTestSettings()
    local checks = {
        { key = "theme", alt = "WoW" }, { key = "mode", alt = "Classic" },
        { key = "compact", alt = false }, { key = "animations", alt = "Off" },
        { key = "cometOn", alt = false }, { key = "segFlash", alt = false },
        { key = "charge", alt = false }, { key = "dip", alt = false }, { key = "barsText", alt = false },
        { key = "streak", alt = false }, { key = "mName", alt = false },
        { key = "showRate", alt = false }, { key = "width", alt = 500 },
        { key = "barThickness", alt = 16 }, { key = "textSize", alt = 110 },
        { key = "font", alt = "Friz" }, { key = "trimColor", alt = "#2F6577" },
    }
    local failed = {}
    for _, c in ipairs(checks) do
        local old = ns.db[c.key]
        ns.db[c.key] = c.alt
        if ns.db[c.key] ~= c.alt then failed[#failed + 1] = c.key end
        ns.db[c.key] = old
    end
    if #failed == 0 then
        print("settings ok")
    else
        print("settings failed: " .. table.concat(failed, ", "))
    end
end

function ns.OpenQuick()
    if not Quick.built then buildQuick() end
    if Quick.applyTheme then Quick.applyTheme() end
    qp:Show()
    if ns.island then ns.island.previewOpen = true; ns.island:UpdateFade() end
end

function ns.CloseQuick()
    if qp then qp:Hide() end
    if ns.island then ns.island.previewOpen = false; ns.island:UpdateFade() end
end

-- register a single button in the Blizzard AddOns list
ns.On("ADDON_LOADED", function(_, name)
    if name ~= "XPBarIsland" then return end
    local p = CreateFrame("Frame")
    p.name = "XPBar Island"
    local title = p:CreateFontString(nil, "OVERLAY")
    ns.StyleText(title, 14, "bold", "")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("XPBar Island")
    local info = p:CreateFontString(nil, "OVERLAY")
    ns.StyleText(info, 11, "medium", "")
    info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    info:SetText("Settings open in their own window.")
    local okb, b = pcall(CreateFrame, "Button", nil, p, "UIPanelButtonTemplate")
    if not okb or not b then return end
    if b.SetText then b:SetText("Open XPBar Island settings") end
    b:SetSize(240, 24)
    b:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -12)
    b:SetScript("OnClick", function()
        if _G.GameMenuFrame and HideUIPanel then pcall(HideUIPanel, _G.GameMenuFrame) end
        if _G.SettingsPanel and _G.SettingsPanel.Hide then pcall(_G.SettingsPanel.Hide, _G.SettingsPanel) end
        if _G.InterfaceOptionsFrame and HideUIPanel then pcall(HideUIPanel, _G.InterfaceOptionsFrame) end
        ns.OpenSettings()
    end)
    if ns.ReportBug then
        local okr, rb = pcall(CreateFrame, "Button", nil, p, "UIPanelButtonTemplate")
        if okr and rb then
            if rb.SetText then rb:SetText("Report a bug") end
            rb:SetSize(120, 22)
            rb:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -6)
            rb:SetScript("OnClick", function() ns.ReportBug() end)
        end
    end
    if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
        local ok, cat = pcall(_G.Settings.RegisterCanvasLayoutCategory, p, "XPBar Island")
        if ok and cat then pcall(_G.Settings.RegisterAddOnCategory, cat) end
    elseif _G.InterfaceOptions_AddCategory then
        pcall(_G.InterfaceOptions_AddCategory, p)
    end
end)

-- ===========================================================================
-- Studio window
-- ===========================================================================
local Studio = { pages = {}, order = {}, rows = {}, navButtons = {}, built = false }
ns.Studio = Studio
local sw, sNav, sHeader, sGrid, sGridContent, sSearch

local STUDIO_NAV = {
    { group = "XPBar Island", items = {
        "Overview", "Layout", "Colors", "Minimal", "Bars",
        "Motion", "Behavior", "Party & share", "Profiles",
    } },
}
local STUDIO_DESC = {
    ["Overview"] = "Start from a preset, then pick the look of the island.",
    ["Layout"] = "What the island shows, how big it is and where it sits.",
    ["Colors"] = "Colors of the trim, the bar and the text.",
    ["Minimal"] = "What the thin bar shows when Display mode is Classic.",
    ["Bars"] = "Which bars you can switch between.",
    ["Motion"] = "Which animations play, and how fast and strong they are.",
    ["Behavior"] = "When the island hides, fades or celebrates.",
    ["Party & share"] = "Party comparison, sharing and the XP graph.",
    ["Profiles"] = "Save your setup and switch between setups.",
}
local STUDIO_RESET = { Layout = true, Colors = true, Minimal = true, Motion = true }

local function sSect(frame) return { body = frame, rows = {} } end

local STUDIO_BUILD = {
    ["Overview"] = function(s)
        addRow(s, W.Segmented(s.body, "Preset", "Start from a ready-made setup",
            { { label = "Minimal", value = "Minimal" }, { label = "Standard", value = "Standard" }, { label = "Full", value = "Full" } },
            function() return ns.db.preset or "Custom" end, function(v) applyQuickPreset(v) end))
        qseg(s, "theme", "Theme", "Colours and fonts", {
            { label = "Default", value = "Default" }, { label = "WoW", value = "WoW" },
            { label = "Classic", value = "Classic" }, { label = "WoW Forever", value = "WoW Forever" } }, "Default")
        qseg(s, "mode", "Display mode", "Classic is a thin bar", {
            { label = "Full", value = "Full" }, { label = "Classic", value = "Classic" },
            { label = "Auto-hide", value = "Auto-hide" }, { label = "Always open", value = "Always open" } }, "Full")
        qslider(s, "scale", "Size", "Scale of the whole island", 70, 150, 5, function(v) return ns.round(v) .. "%" end, 100)
        qswitch(s, "hoverExpand", "Expand on hover", "Open the panel when hovered")
    end,
    ["Layout"] = function(s)
        qswitch(s, "showName", "Name", "Show the type name")
        qswitch(s, "showRange", "Range", "Show current / max")
        qswitch(s, "showPercent", "Percent", "Show the percentage")
        qswitch(s, "showRested", "Rested tag", "Show the Resting tag")
        qswitch(s, "showRate", "Rate block", "Show XP/hr and kills")
        qswitch(s, "showDots", "Party dots", "Show party markers")
        qswitch(s, "portrait", "Portrait", "Show the portrait")
        qslider(s, "width", "Width", "Island width", 380, 560, 10, function(v) return ns.round(v) .. "px" end, 460)
        qslider(s, "barThickness", "Bar thickness", "Bar height", 8, 18, 1, function(v) return ns.round(v) .. "px" end, 12)
        qslider(s, "textSize", "Text size", "Font scale", 80, 130, 5, function(v) return ns.round(v) .. "%" end, 100)
        qseg(s, "font", "Font", "Text font", {
            { label = "Theme", value = "Theme" }, { label = "Alegreya Sans", value = "Alegreya" },
            { label = "Friz Quadrata", value = "Friz" }, { label = "Morpheus", value = "Morpheus" } }, "Theme")
    end,
    ["Colors"] = function(s)
        addRow(s, W.ColorRow(s.body, "Trim color", "Border, ring and dividers",
            { "#6F5326", "#2F6577", "#4D6B2F", "#53487A", "#7A2F2F", "#8A8A8A", "#C79C6E", "#2F7A63" },
            function() return ns.db.trimColor end, function(v) qset("trimColor", v) end))
        addRow(s, W.ColorRow(s.body, "Bar color", "The XP fill only",
            { "#8A1FB0", "#1F6FB8", "#22A03A", "#C25A00", "#B01F3A", "#D6B100", "#2FA89A" },
            function() return ns.db.barColor end, function(v) qset("barColor", v) end))
        addRow(s, W.ColorRow(s.body, "Text accent", "Name, titles and numbers",
            { "#FFD100", "#FFFFFF", "#7BE8C3", "#69CCF0", "#FF9A2E", "#F5D98A" },
            function() return ns.db.textAccent end, function(v) qset("textAccent", v) end))
        addRow(s, W.Segmented(s.body, "WoW bar colour", "XP bar while the WoW theme is active (Bar color on Auto)",
            { { label = "Azure", value = "Azure" }, { label = "Violet", value = "Violet" }, { label = "Gold", value = "Gold" } },
            function() return ns.db.wowBar or "Azure" end, function(v) qset("wowBar", v) end))
    end,
    ["Minimal"] = function(s)
        local h = qtext(s.body, 11, "#FFD100", "LEFT"); h:SetText("SHOWN ON THE THIN BAR"); addRow(s, h)
        qswitch(s, "mLevel", "Level", "Level box")
        qswitch(s, "mName", "Name", "Type name")
        qswitch(s, "mPct", "Percent", "Percentage")
        qswitch(s, "mBars", "Bars to level up", "e.g. 8 bars")
        qswitch(s, "mGain", "Gain text", "+N XP on a gain")
        qswitch(s, "mStreak", "Kill streak", "xN while a streak runs")
        qswitch(s, "mRested", "Rested", "Blue Resting")
        qswitch(s, "mRate", "XP per hour", "e.g. 41.2k/hr")
        qswitch(s, "mEta", "Time or kills to level", "e.g. ~38 kills")
        addRow(s, W.Button(s.body, "Reset Minimal", function()
            qset("mLevel", true); qset("mName", true); qset("mPct", true); qset("mBars", true)
            qset("mGain", true); qset("mStreak", true); qset("mRested", true)
            qset("mRate", false); qset("mEta", false)
            if Studio.refresh then Studio.refresh() end
        end))
    end,
    ["Bars"] = function(s)
        typesRowQuick(s)
        qswitch(s, "autoSwitch", "Auto-switch bar", "Show a type briefly when it changes")
        qswitch(s, "repAtMax", "Reputation bar at max level", "Replace XP with your watched faction")
        qswitch(s, "portrait", "Show portrait", "Your character face next to the bar")
        qswitch(s, "compact", "Compact numbers", "Show 9.9K instead of 9,900")
    end,
    ["Motion"] = function(s)
        local h1 = qtext(s.body, 11, "#FFD100", "LEFT"); h1:SetText("XP BAR"); addRow(s, h1)
        qswitch(s, "cometOn", "Comet pulse", "Idle sweep on the XP fill")
        qswitch(s, "segFlash", "Segment flashes", "Flash each segment the fill crosses")
        qswitch(s, "charge", "Charge-up glow", "Gold glow past 80%")
        qswitch(s, "barsText", "Bars to level up", "Show the bars count")
        qswitch(s, "streak", "Kill streak", "Streak tag and bar glow")
        local h2 = qtext(s.body, 11, "#FFD100", "LEFT"); h2:SetText("ISLAND"); addRow(s, h2)
        qswitch(s, "dip", "Gain dip", "Island nudges down on a gain")
        local h3 = qtext(s.body, 11, "#FFD100", "LEFT"); h3:SetText("PARTY"); addRow(s, h3)
        qswitch(s, "partyMotion", "Party motion", "Animate party dots")
        qslider(s, "speed", "Speed", "Animation speed", 50, 150, 10, function(v) return ns.round(v) .. "%" end, 100)
        qslider(s, "strength", "Strength", "Animation strength", 0, 150, 10, function(v) return ns.round(v) .. "%" end, 100)
    end,
    ["Behavior"] = function(s)
        qswitch(s, "hideCombat", "Hide in combat", "Fade out while fighting")
        qswitch(s, "hideOutOfCombat", "Hide out of combat", "Fade out while not fighting")
        qfade(s)
        qswitch(s, "hideBlizzXp", "Hide default XP and rep bars", "Use only the island for XP and reputation")
        qswitch(s, "move", "Move mode", "Drag the island anywhere on screen")
        qseg(s, "animations", "Animations", "Pulsing and motion", {
            { label = "Always", value = "Always" }, { label = "On hover only", value = "On hover only" }, { label = "Off", value = "Off" } }, "Always")
        qseg(s, "feel", "Motion feel", "How the island expands", {
            { label = "Springy", value = "Springy" }, { label = "Snappy", value = "Snappy" }, { label = "Smooth", value = "Smooth" } }, "Springy")
        qswitch(s, "streak", "Kill streak", "Count kills and glow the bar")
        qswitch(s, "levelUpFx", "Level-up animation", "Supernova burst when you level up")
        qswitch(s, "levelUpSummary", "Level-up summary", "Card with the stats gained on level-up")
        qswitch(s, "tips", "Show tips", "Chat hints about new features")
    end,
    ["Party & share"] = function(s)
        qswitch(s, "party", "Party comparison", "See party members running the addon")
        qseg(s, "shareChannel", "Share channel", "Where Shift-Click posts", {
            { label = "Party", value = "Party" }, { label = "Guild", value = "Guild" }, { label = "Say", value = "Say" } }, "Party")
        qswitch(s, "sparkline", "Session sparkline", "XP graph in the panel")
        qswitch(s, "questList", "Quest list on hover", "Hover Turn-in for XP per quest")
        addRow(s, W.Switch(s.body, "Minimap button", "Show the round button next to the minimap",
            function() return not (ns.db.minimap and ns.db.minimap.hide) end,
            function(v)
                ns.db.minimap = ns.db.minimap or {}
                ns.db.minimap.hide = not v
                if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
                ns.Notify(); ns.MarkDirty()
            end))
    end,
    ["Profiles"] = function(s)
        local profRow = CreateFrame("Frame", nil, s.body); profRow:SetHeight(34)
        local pl = qtext(profRow, 14, "#ECE6D8", "LEFT"); pl:SetPoint("LEFT", profRow, "LEFT", 0, 0); pl:SetText("Profile")
        local pholder = CreateFrame("Frame", nil, profRow); pholder:SetPoint("RIGHT", profRow, "RIGHT", 0, 0); pholder:SetHeight(24)
        local rebuild = makeProfilePills(pholder)
        Studio._rebuildProfiles = rebuild
        rebuild()
        addRow(s, profRow)
        qswitch(s, "switchPerChar", "Switch per character", "Remember the profile per character")
        if _G.GetActiveTalentGroup then qswitch(s, "switchPerSpec", "Switch per spec", "Remember the profile per spec") end
        -- help
        local help = CreateFrame("Frame", nil, s.body); help:SetHeight(34)
        local hl = qtext(help, 14, "#ECE6D8", "LEFT"); hl:SetPoint("LEFT", help, "LEFT", 0, 0); hl:SetText("Help")
        local hh = CreateFrame("Frame", nil, help); hh:SetPoint("RIGHT", help, "RIGHT", 0, 0); hh:SetHeight(24)
        local prevh
        local function hbtn(text, fn)
            if not fn then return end
            local th = ns.Theme()
            local b = CreateFrame("Frame", nil, hh); b:SetHeight(24)
            b.label = qtext(b, 12, (th.btnText or "#ECE6D8"), "CENTER"); b.label:SetPoint("CENTER", b, "CENTER", 0, 0); b.label:SetText(text)
            b:SetWidth((b.label:GetStringWidth() or 40) + 16)
            b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0); b.bg:SetAllPoints(b)
            b.bd = b:CreateTexture(nil, "BORDER", nil, 1); b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1); b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
            ns.Paint(b.bd, ns.Hex(th.btnRing or th.trim)); b:EnableMouse(true); b:SetScript("OnMouseUp", fn)
            if prevh then b:SetPoint("LEFT", prevh, "RIGHT", 4, 0) else b:SetPoint("LEFT", hh, "LEFT", 0, 0) end
            prevh = b
        end
        hbtn("Report a bug", ns.ReportBug)
        hbtn("Reset everything", ns.ResetEverything)
        hbtn("Safe mode", ns.SafeMode)
        if prevh then addRow(s, help) end
    end,
}

local function buildStudio()
    sw = CreateFrame("Frame", "XPBarIslandStudio", UIParent)
    local screenH = (UIParent.GetHeight and UIParent:GetHeight()) or 900
    local h = math.min(580, (screenH or 900) - 100)
    sw:SetSize(900, h)
    sw:SetPoint("TOP", UIParent, "TOP", 0, -56)
    sw:SetFrameStrata("DIALOG")
    sw:SetToplevel(true)
    sw:SetClampedToScreen(true)
    sw:SetMovable(true)
    sw:EnableMouse(true)
    sw:EnableMouseWheel(true)
    sw:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "XPBarIslandStudio") end
    ns.studioPanel = sw
    if screenH and screenH < 700 then pcall(sw.SetScale, sw, math.max(0.7, screenH / 900)) end

    sw.bg = sw:CreateTexture(nil, "BACKGROUND", nil, 0); sw.bg:SetAllPoints(sw)
    sw.trim = {}
    for i = 1, 4 do sw.trim[i] = sw:CreateTexture(nil, "BORDER", nil, 1) end
    sw.outer = {}
    for i = 1, 4 do sw.outer[i] = sw:CreateTexture(nil, "BORDER", nil, 2) end
    local function edges()
        local t, o = sw.trim, sw.outer
        t[1]:SetPoint("TOPLEFT", sw, "TOPLEFT", 0, 0); t[1]:SetPoint("TOPRIGHT", sw, "TOPRIGHT", 0, 0); t[1]:SetHeight(2)
        t[2]:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", 0, 0); t[2]:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 0, 0); t[2]:SetHeight(2)
        t[3]:SetPoint("TOPLEFT", sw, "TOPLEFT", 0, 0); t[3]:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", 0, 0); t[3]:SetWidth(2)
        t[4]:SetPoint("TOPRIGHT", sw, "TOPRIGHT", 0, 0); t[4]:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 0, 0); t[4]:SetWidth(2)
        o[1]:SetPoint("TOPLEFT", sw, "TOPLEFT", -1, 1); o[1]:SetPoint("TOPRIGHT", sw, "TOPRIGHT", 1, 1); o[1]:SetHeight(1)
        o[2]:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", -1, -1); o[2]:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 1, -1); o[2]:SetHeight(1)
        o[3]:SetPoint("TOPLEFT", sw, "TOPLEFT", -1, 1); o[3]:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", -1, -1); o[3]:SetWidth(1)
        o[4]:SetPoint("TOPRIGHT", sw, "TOPRIGHT", 1, 1); o[4]:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 1, -1); o[4]:SetWidth(1)
    end
    edges()

    -- title bar
    local tb = CreateFrame("Frame", nil, sw)
    tb:SetPoint("TOPLEFT", sw, "TOPLEFT", 0, 0); tb:SetPoint("TOPRIGHT", sw, "TOPRIGHT", 0, 0); tb:SetHeight(42)
    tb:EnableMouse(true); tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() sw:StartMoving() end)
    tb:SetScript("OnDragStop", function() sw:StopMovingOrSizing() end)
    sw.title = qtext(tb, 17, "#FFD100", "LEFT"); sw.title:SetPoint("LEFT", tb, "LEFT", 14, 0); sw.title:SetText("XPBar Island")
    sw.ver = qtext(tb, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium"); sw.ver:SetPoint("LEFT", sw.title, "RIGHT", 8, 0)
    sw.ver:SetText((ns.AddonVersion and ns.AddonVersion()) or "1.0.8")
    local cb = CreateFrame("Frame", nil, tb); cb:SetSize(26, 26); cb:SetPoint("RIGHT", tb, "RIGHT", -10, 0)
    cb.bd = cb:CreateTexture(nil, "BORDER", nil, 1); cb.bd:SetPoint("TOPLEFT", cb, "TOPLEFT", -1, 1); cb.bd:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", 1, -1)
    ns.Paint(cb.bd, 0.29, 0.23, 0.11, 1)
    cb.x = qtext(cb, 14, "#FFD100", "CENTER"); cb.x:SetPoint("CENTER", cb, "CENTER", 0, 0); cb.x:SetText("x")
    cb:EnableMouse(true); cb:SetScript("OnMouseUp", function() ns.CloseSettings() end)
    -- search
    sSearch = CreateFrame("EditBox", nil, tb)
    sSearch:SetSize(260, 26); sSearch:SetPoint("RIGHT", cb, "LEFT", -10, 0)
    sSearch:SetAutoFocus(false); ns.StyleText(sSearch, 13, "bold", "")
    sSearch:SetTextColor(1, 1, 1, 1)
    local sb = sSearch:CreateTexture(nil, "BACKGROUND", nil, 0); sb:SetAllPoints(sSearch); ns.Paint(sb, 0.047, 0.039, 0.031, 1)
    local sbe = {}
    for i = 1, 4 do
        local t = sSearch:CreateTexture(nil, "BORDER", nil, 1); t:SetTexture(ns.Media.white); sbe[i] = t
    end
    local function sEdges(col)
        local e = sbe
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", sSearch, "TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", sSearch, "TOPRIGHT", 0, 0); e[1]:SetHeight(1)
        e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", sSearch, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", sSearch, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(1)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", sSearch, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMLEFT", sSearch, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(1)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", sSearch, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMRIGHT", sSearch, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(1)
        for i = 1, 4 do ns.Paint(e[i], col[1], col[2], col[3], col[4] or 1) end
    end
    -- magnifier: 9px ring + a 1px line
    local mag = CreateFrame("Frame", nil, sSearch); mag:SetSize(14, 14); mag:SetPoint("LEFT", sSearch, "LEFT", 7, 0)
    mag.ring = mag:CreateTexture(nil, "ARTWORK", nil, 0); mag.ring:SetTexture(ns.Media.ring); mag.ring:SetSize(11, 11); mag.ring:SetPoint("CENTER", mag, "CENTER", -1, 1); mag.ring:SetVertexColor(0.62, 0.62, 0.62, 1)
    mag.line = mag:CreateTexture(nil, "ARTWORK", nil, 0); mag.line:SetTexture(ns.Media.white); mag.line:SetSize(6, 1); mag.line:SetVertexColor(0.62, 0.62, 0.62, 1)
    mag.line:SetPoint("CENTER", mag.ring, "BOTTOMRIGHT", 1, -2)
    if mag.line.SetRotation then pcall(mag.line.SetRotation, mag.line, math.rad(45)) end
    -- hint
    local hint = sSearch:CreateFontString(nil, "OVERLAY"); ns.StyleText(hint, 12, "medium", "")
    hint:SetPoint("LEFT", sSearch, "LEFT", 24, 0); hint:SetTextColor(0.62, 0.62, 0.62, 1); hint:SetText("Search settings")
    -- clear button
    local clear = CreateFrame("Frame", nil, sSearch); clear:SetSize(18, 18); clear:SetPoint("RIGHT", sSearch, "RIGHT", -4, 0)
    clear.x = sSearch:CreateFontString(nil, "OVERLAY"); ns.StyleText(clear.x, 12, "bold", "")
    clear.x:SetPoint("CENTER", clear, "CENTER", 0, 0); clear.x:SetText("x"); clear.x:SetTextColor(0.62, 0.62, 0.62, 1)
    clear:EnableMouse(true)
    clear:SetScript("OnMouseUp", function() sSearch:SetText(""); Studio:search(""); sSearch:ClearFocus() end)
    sSearch:SetTextInsets(24, 24, 0, 0)
    local function refreshSearch()
        local txt = sSearch:GetText() or ""
        if txt == "" and not sSearch._focused then hint:Show() else hint:Hide() end
        if txt ~= "" then clear:Show() else clear:Hide() end
        sEdges(sSearch._focused and ns.HexA(ns.Theme().gold) or ns.HexA(ns.Theme().trim))
    end
    sSearch:SetScript("OnTextChanged", function(self) Studio:search(self:GetText() or ""); refreshSearch() end)
    sSearch:SetScript("OnEditFocusGained", function() sSearch._focused = true; refreshSearch() end)
    sSearch:SetScript("OnEditFocusLost", function() sSearch._focused = false; refreshSearch() end)
    sSearch:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText(""); Studio:search("")
        else
            self:ClearFocus(); ns.CloseSettings()
        end
    end)
    sEdges(ns.HexA(ns.Theme().trim)); hint:Show(); clear:Hide()

    -- nav
    sNav = CreateFrame("Frame", nil, sw)
    sNav:SetPoint("TOPLEFT", sw, "TOPLEFT", 0, -42)
    sNav:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", 0, 40)
    sNav:SetWidth(190)
    local nbg = sNav:CreateTexture(nil, "BACKGROUND", nil, 0); nbg:SetAllPoints(sNav); ns.Paint(nbg, 0, 0, 0, 0.25)
    local ny = -8
    for _, g in ipairs(STUDIO_NAV) do
        local gh = qtext(sNav, 10, (ns.Theme().grey or "#8F8777"), "LEFT", "medium"); gh:SetPoint("TOPLEFT", sNav, "TOPLEFT", 14, ny); gh:SetText(g.group)
        ny = ny - 16
        for _, key in ipairs(g.items) do
            local b = CreateFrame("Frame", nil, sNav); b:SetHeight(26)
            b:SetPoint("TOPLEFT", sNav, "TOPLEFT", 0, ny); b:SetPoint("TOPRIGHT", sNav, "TOPRIGHT", 0, ny)
            b.label = qtext(b, 13, "#9D9D9D", "LEFT"); b.label:SetPoint("LEFT", b, "LEFT", 14, 0); b.label:SetText(key)
            b.hl = b:CreateTexture(nil, "BACKGROUND", nil, 0); b.hl:SetAllPoints(b); ns.Paint(b.hl, 1, 0.82, 0, 0)
            b.bar = b:CreateTexture(nil, "BACKGROUND", nil, 1); b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0); b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0); b.bar:SetWidth(3); ns.Paint(b.bar, 1, 0.82, 0, 0)
            b:EnableMouse(true); b.key = key
            b:SetScript("OnMouseUp", function() Studio:showPage(key) end)
            Studio.navButtons[#Studio.navButtons + 1] = b
            ny = ny - 26
        end
        ny = ny - 6
    end

    -- header
    sHeader = CreateFrame("Frame", nil, sw)
    sHeader:SetPoint("TOPLEFT", sw, "TOPLEFT", 200, -42)
    sHeader:SetPoint("TOPRIGHT", sw, "TOPRIGHT", -10, -42)
    sHeader:SetHeight(40)
    sHeader.name = qtext(sHeader, 20, "#FFD100", "LEFT"); sHeader.name:SetPoint("TOPLEFT", sHeader, "TOPLEFT", 0, 0)
    sHeader.desc = qtext(sHeader, 12, (ns.Theme().grey or "#8F8777"), "LEFT", "medium"); sHeader.desc:SetPoint("TOPLEFT", sHeader.name, "BOTTOMLEFT", 0, -2)
    sHeader.reset = W.Button(sHeader, "Reset page", function() if Studio.resetPage then Studio:resetPage() end end)
    sHeader.reset:SetPoint("RIGHT", sHeader, "RIGHT", 0, 0)

    -- grid
    sGrid = CreateFrame("ScrollFrame", nil, sw)
    sGrid:SetPoint("TOPLEFT", sw, "TOPLEFT", 200, -90)
    sGrid:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -10, 40)
    sGrid:EnableMouseWheel(true)
    sGridContent = CreateFrame("Frame", nil, sGrid)
    sGridContent:SetSize(680, 300)
    sGrid:SetScrollChild(sGridContent)
    sGrid:SetScript("OnMouseWheel", function(_, d)
        local cur = sGrid:GetVerticalScroll()
        local maxS = math.max(0, sGridContent:GetHeight() - sGrid:GetHeight())
        sGrid:SetVerticalScroll(ns.clamp(cur - d * 30, 0, maxS))
    end)

    -- footer
    local foot = CreateFrame("Frame", nil, sw)
    foot:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", 0, 0); foot:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 0, 0); foot:SetHeight(40)
    local fb = foot:CreateTexture(nil, "BACKGROUND", nil, 0); fb:SetAllPoints(foot); ns.Paint(fb, 0, 0, 0, 0.3)
    local fl = foot:CreateTexture(nil, "BACKGROUND", nil, 1); fl:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0); fl:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0); fl:SetHeight(1); ns.Paint(fl, 0, 0, 0, 1)
    local applies = qtext(foot, 11, (ns.Theme().grey or "#8F8777"), "LEFT", "medium"); applies:SetPoint("LEFT", foot, "LEFT", 12, 0)
    local contact = W.IconLink(foot, ns.Media.xIcon, ns.OpenContact, "Contact @mainlek on X.com (Twitter)", "Click to copy the link")
    contact:SetPoint("LEFT", applies, "RIGHT", 18, 0)
    local curseforge = W.IconLink(foot, ns.Media.curseforgeIcon, ns.OpenCurseForge, "CurseForge page", "Click to copy the link")
    curseforge:SetPoint("LEFT", contact, "RIGHT", 8, 0)
    local resetS = W.Button(foot, "Reset session", function() if ns.session then ns.session:Reset() end; ns.MarkDirty() end)
    local done = W.Button(foot, "Done", function() ns.CloseSettings() end)
    done:SetPoint("RIGHT", foot, "RIGHT", -12, 0)
    local apply = W.Button(foot, "Apply", function() ns.Notify(); ns.MarkDirty() end)
    apply:SetPoint("RIGHT", done, "LEFT", -6, 0)
    resetS:SetPoint("RIGHT", apply, "LEFT", -6, 0)
    sw.footerButtons = { resetS, apply, done, contact, curseforge }

    -- build pages
    for _, g in ipairs(STUDIO_NAV) do
        for _, key in ipairs(g.items) do
            local page = CreateFrame("Frame", nil, sGridContent)
            page:SetSize(660, 300)
            local s = sSect(page)
            STUDIO_BUILD[key](s)
            Studio.pages[key] = { frame = page, rows = s.rows, desc = STUDIO_DESC[key] }
            Studio.order[#Studio.order + 1] = key
            for _, r in ipairs(s.rows) do Studio.rows[#Studio.rows + 1] = { row = r, page = key, label = r.label and r.label:GetText() or "", desc = r.desc and r.desc:GetText() or "" } end
            page:Hide()
        end
    end

    Studio.applyTheme = function()
        local th = ns.Theme()
        ns.WhiteTexture(sw.bg); ns.Gradient(sw.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
        for i = 1, 4 do ns.Paint(sw.trim[i], ns.Hex(th.trim)) end
        for i = 1, 4 do ns.Paint(sw.outer[i], 0, 0, 0, 1) end
        sw.title:SetTextColor(ns.Hex(th.gold))
        sw.ver:SetTextColor(ns.Hex(th.grey or "#8F8777"))
        for _, b in ipairs(sw.footerButtons or {}) do if b.Refresh then b.Refresh() end end
    end
    Studio.built = true
end

function Studio:showPage(key)
    -- clearing the search box below fires OnTextChanged -> search("") -> showPage,
    -- so guard against re-entering and just let the outer call finish
    if self._inShowPage then return end
    self._inShowPage = true
    if not self.pages[key] then key = "Overview" end
    self.activePage = key
    self.searchText = nil
    if sSearch and (sSearch:GetText() or "") ~= "" then sSearch:SetText("") end
    for _, p in pairs(self.pages) do p.frame:Hide() end
    local p = self.pages[key]
    if p then
        p.frame:ClearAllPoints(); p.frame:SetPoint("TOPLEFT", sGridContent, "TOPLEFT", 0, 0); p.frame:Show()
        self:layoutRows(p.frame, p.rows)
        sHeader.name:SetText(key)
        sHeader.desc:SetText(p.desc or "")
        if STUDIO_RESET[key] == true then sHeader.reset:Show() else sHeader.reset:Hide() end
    end
    self:styleNav()
    if self.refresh then self:refresh() end
    self._inShowPage = false
end

function Studio:layoutRows(frame, rows)
    local y = 0
    local col = 0
    local colW = 316
    for _, r in ipairs(rows) do
        r:ClearAllPoints()
        local isSwitch = r.label and r.desc and r.control == "switch"
        -- a plain W.Button row keeps its natural width
        local isButton = (r.control == "button")
        if isSwitch then
            r:SetPoint("TOPLEFT", frame, "TOPLEFT", col * (colW + 28), -y)
            r:SetWidth(colW)
            col = col + 1
            if col >= 2 then col = 0; y = y + r:GetHeight() + 1 end
        elseif isButton then
            if col == 1 then y = y + 34 + 1; col = 0 end
            r:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
            y = y + r:GetHeight() + 1
        else
            if col == 1 then y = y + 34 + 1; col = 0 end
            r:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
            r:SetWidth(colW * 2 + 28)
            y = y + r:GetHeight() + 1
        end
    end
    frame:SetHeight(math.max(1, y + 40))
end

function Studio:styleNav()
    local th = ns.Theme()
    for _, b in ipairs(self.navButtons) do
        local on = (b.key == self.activePage)
        b.label:SetTextColor(ns.Hex(on and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
        b.hl:SetAlpha(on and 0.08 or 0)
        if on then ns.Paint(b.bar, 1, 0.82, 0, 1) else ns.Paint(b.bar, 1, 0.82, 0, 0) end
    end
end

local function studioHighlight(label, text)
    if not text or text == "" then return label end
    local l = label:lower()
    local s, e = l:find(text, 1, true)
    if not s then return label end
    return label:sub(1, s - 1) .. "|cffffd100" .. label:sub(s, e) .. "|r" .. label:sub(e + 1)
end

function Studio:search(text)
    text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        if self.resultsFrame then self.resultsFrame:Hide() end
        if self.activePage then self:showPage(self.activePage) end
        return
    end
    self.searchText = text
    for _, p in pairs(self.pages) do p.frame:Hide() end
    local matches = {}
    for _, e in ipairs(self.rows) do
        local lbl = (e.label or ""):lower()
        local dsc = (e.desc or ""):lower()
        if lbl:find(text, 1, true) or dsc:find(text, 1, true) then matches[#matches + 1] = e end
    end
    local frame = self.resultsFrame
    if not frame then
        frame = CreateFrame("Frame", nil, sGridContent); frame:SetSize(660, 300)
        self.resultsFrame = frame
        self.resultEntries = {}
    end
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", sGridContent, "TOPLEFT", 0, 0)
    local pool = self.resultEntries
    local y = 0
    for i, e in ipairs(matches) do
        local entry = pool[i]
        if not entry then
            entry = CreateFrame("Frame", nil, frame)
            entry:EnableMouse(true)
            entry.bg = entry:CreateTexture(nil, "BACKGROUND", nil, 0)
            entry.bg:SetAllPoints(entry)
            ns.Paint(entry.bg, 1, 0.82, 0, 1)
            entry.bg:SetAlpha(0)
            entry.label = entry:CreateFontString(nil, "OVERLAY")
            ns.StyleText(entry.label, 14, "bold", ""); entry.label:SetJustifyH("LEFT")
            entry.page = entry:CreateFontString(nil, "OVERLAY")
            ns.StyleText(entry.page, 11, "medium", ""); entry.page:SetJustifyH("LEFT")
            entry.page:SetTextColor(0.62, 0.62, 0.62, 1)
            local function activate()
                if entry._page then Studio:showPage(entry._page) end
            end
            entry:SetScript("OnMouseUp", activate)
            entry:SetScript("OnEnter", function()
                entry.bg:SetAlpha(0.08)
                entry.page:SetTextColor(1, 0.82, 0, 1)
            end)
            entry:SetScript("OnLeave", function()
                entry.bg:SetAlpha(0)
                entry.page:SetTextColor(0.62, 0.62, 0.62, 1)
            end)
            pool[i] = entry
        end
        entry._page = e.page
        entry.label:SetText(studioHighlight(e.label or "", text))
        entry.page:SetText(e.page)
        entry:SetHeight(34)
        entry:ClearAllPoints(); entry:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y); entry:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
        entry.label:ClearAllPoints(); entry.label:SetPoint("TOPLEFT", entry, "TOPLEFT", 0, 0)
        entry.page:ClearAllPoints(); entry.page:SetPoint("TOPLEFT", entry.label, "BOTTOMLEFT", 0, -2)
        entry:Show()
        y = y + 34 + 1
    end
    for i = #matches + 1, #pool do pool[i]:Hide() end
    frame:SetHeight(math.max(1, y + 40)); frame:Show()
    sHeader.name:SetText("Search results")
    sHeader.desc:SetText(#matches .. " matching settings")
    sHeader.reset:Hide()
    self:styleNav()
    if self.refresh then self:refresh() end
end

function Studio:refresh()
    for _, r in ipairs(self.rows) do if r.row.Refresh then r.row.Refresh() end end
    if self.styleNav then self:styleNav() end
    local th = ns.Theme()
    if sHeader then
        if sHeader.name then sHeader.name:SetTextColor(ns.Hex(th.gold)) end
        if sHeader.desc then sHeader.desc:SetTextColor(ns.Hex(th.grey or "#8F8777")) end
        if sHeader.reset and sHeader.reset.Refresh then sHeader.reset:Refresh() end
    end
end

function Studio:resetPage()
    local key = self.activePage
    ns.BeginBatch()
    local ok, err = pcall(function()
        if key == "Layout" then
            for _, k in ipairs({ "showName", "showRange", "showPercent", "showRested", "showRate", "showDots", "portrait" }) do qset(k, true) end
            qset("width", 460); qset("barThickness", 12); qset("textSize", 100); qset("posOffset", 0); qset("posX", 0); qset("posY", 0); qset("font", "Theme")
        elseif key == "Colors" then
            qset("trimColor", false); qset("barColor", false); qset("textAccent", false); qset("wowBar", "Azure")
        elseif key == "Minimal" then
            for _, k in ipairs({ "mLevel", "mName", "mPct", "mBars", "mGain", "mStreak", "mRested" }) do qset(k, true) end
            qset("mRate", false); qset("mEta", false)
        elseif key == "Motion" then
            for _, k in ipairs({ "cometOn", "segFlash", "charge", "barsText", "streak", "dip", "partyMotion" }) do qset(k, true) end
            qset("speed", 100); qset("strength", 100)
        end
        if self.refresh then self:refresh() end
    end)
    ns.EndBatch()
    if not ok then ns.ReportError("Studio:resetPage", err) end
end

function ns.OpenStudio()
    if not Studio.built then buildStudio() end
    if Studio.applyTheme then Studio.applyTheme() end
    sw:Show()
    Studio:showPage(Studio.activePage or "Overview")
    if ns.island then ns.island.previewOpen = true; ns.island:UpdateFade() end
end

function ns.CloseStudio()
    if sw then sw:Hide() end
    if ns.island then ns.island.previewOpen = false; ns.island:UpdateFade() end
end

ns.OnUpdateLayout(function()
    if win and win:IsShown() then win:ApplyTheme() end
    if panelPage then panelPage:ApplyTheme() end
    if qp and qp:IsShown() then
        if Quick.applyTheme then Quick.applyTheme() end
        if Quick.refresh then Quick.refresh() end
    end
    -- the Studio window must re-theme in place (it is the theme picker)
    if sw and sw:IsShown() then
        if Studio.applyTheme then Studio.applyTheme() end
        if Studio.refresh then Studio:refresh() end
    end
end)
