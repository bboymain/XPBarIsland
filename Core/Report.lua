local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Polish: bug report + error capture, performance readout, reset / safe mode
-- and the first-run / update welcome tip.
-- Loaded right after Core/Util.lua (before Init/Events), so it only defines
-- things at load time and registers its own events on a private frame.
-- ---------------------------------------------------------------------------

local function chat(msg)
    if _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100XPBar Island|r: " .. tostring(msg))
    end
end
ns.ReportChat = chat

function ns.AddonVersion()
    local v
    if _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata then
        local ok, res = pcall(_G.C_AddOns.GetAddOnMetadata, ADDON, "Version")
        if ok then v = res end
    end
    if not v and _G.GetAddOnMetadata then
        local ok, res = pcall(_G.GetAddOnMetadata, ADDON, "Version")
        if ok then v = res end
    end
    return tostring(v or "1.0.10")
end

-- ===========================================================================
-- 1. Error capture
-- ===========================================================================
ns.errors = {}
local MAX_ERRORS = 10

local function firstLines(s, n)
    local out = {}
    for line in tostring(s or ""):gmatch("[^\r\n]+") do
        out[#out + 1] = line
        if #out >= (n or 3) then break end
    end
    return table.concat(out, " / ")
end

local function nowStamp()
    if _G.date then
        local ok, res = pcall(_G.date, "%Y-%m-%d %H:%M:%S")
        if ok then return tostring(res) end
    end
    return "?"
end

function ns.CaptureError(msg)
    local text = tostring(msg or "")
    local stack = ""
    if _G.debugstack then
        local ok, s = pcall(_G.debugstack, 2, 3, 0)
        if ok then stack = tostring(s or "") end
    end
    if not (text .. stack):find("XPBarIsland") then return end
    ns.errors[#ns.errors + 1] = {
        time = nowStamp(),
        msg = text,
        stack = firstLines(stack, 3),
    }
    while #ns.errors > MAX_ERRORS do table.remove(ns.errors, 1) end
end

function ns.ClearErrors()
    ns.errors = {}
end

function ns.TestError()
    error("XPBarIsland: harmless test error")
end

local function installErrorHandler()
    if ns._errorHandlerInstalled then return end
    if not _G.seterrorhandler or not _G.geterrorhandler then return end
    ns._errorHandlerInstalled = true
    local prev
    pcall(function() prev = _G.geterrorhandler() end)
    pcall(_G.seterrorhandler, function(msg)
        pcall(ns.CaptureError, msg)
        if prev then return prev(msg) end
    end)
end
installErrorHandler()

-- ===========================================================================
-- 2. Performance stats
-- ===========================================================================
ns._cpuSamples = {}

local function cpuSampler()
    if _G.GetScriptCPUUsage then
        local ok, u = pcall(_G.GetScriptCPUUsage)
        if ok and type(u) == "number" then
            ns._cpuSamples[#ns._cpuSamples + 1] = u
            if #ns._cpuSamples > 6 then table.remove(ns._cpuSamples, 1) end
        end
    end
    if ns.API and ns.API.After then ns.API.After(1, cpuSampler) end
end

local function profilingOn()
    return (_G.GetCVar and _G.GetCVar("scriptProfile") == "1") or false
end

local function addonIndex()
    local num = (_G.C_AddOns and _G.C_AddOns.GetNumAddOns and _G.C_AddOns.GetNumAddOns())
        or (_G.GetNumAddOns and _G.GetNumAddOns()) or 0
    for i = 1, num do
        local name
        if _G.C_AddOns and _G.C_AddOns.GetAddOnInfo then
            local ok, n = pcall(_G.C_AddOns.GetAddOnInfo, i)
            if ok then name = n end
        elseif _G.GetAddOnInfo then
            local ok, n = pcall(_G.GetAddOnInfo, i)
            if ok then name = n end
        end
        if name == ADDON then return i end
    end
    return nil
end

local function memKB()
    if _G.UpdateAddOnMemoryUsage then pcall(_G.UpdateAddOnMemoryUsage) end
    if not _G.GetAddOnMemoryUsage then return nil end
    local ok, kb = pcall(_G.GetAddOnMemoryUsage, ADDON)
    if ok and type(kb) == "number" then return kb end
    local idx = addonIndex()
    if idx then
        local ok2, kb2 = pcall(_G.GetAddOnMemoryUsage, idx)
        if ok2 and type(kb2) == "number" then return kb2 end
    end
    return nil
end

local function cpuPerSec()
    local s = ns._cpuSamples
    if not s or #s < 2 then return nil end
    local d = 0
    for i = 2, #s do d = d + (s[i] - s[i - 1]) end
    return d / (#s - 1)
end

local function visCount(t)
    local n = 0
    if type(t) == "table" then
        for _, v in pairs(t) do
            if type(v) == "table" and v.IsShown and v:IsShown() then n = n + 1 end
        end
    end
    return n
end

function ns.CountPooledTextures()
    local ok, res = pcall(function()
        local n = 0
        local bar = ns.island and ns.island.bar
        if bar then
            for _, pair in pairs(bar.ticks or {}) do
                if pair.left and pair.left:IsShown() then n = n + 1 end
                if pair.right and pair.right:IsShown() then n = n + 1 end
            end
            n = n + visCount(bar.flashes)
            n = n + visCount(bar.flashSparks)
            n = n + visCount(bar.cometSparks)
            n = n + visCount(bar.streakGlow)
        end
        local spark = ns.panel and ns.panel.spark
        if spark then
            n = n + visCount(spark.lines)
            n = n + visCount(spark.areas)
            for _, fl in pairs(spark.flags or {}) do
                n = n + visCount(fl.dashes)
            end
        end
        return n
    end)
    return (ok and res) or 0
end

function ns.PerfStats()
    local memNow = memKB()
    if _G.collectgarbage then pcall(_G.collectgarbage, "collect") end
    local memAfter = memKB()
    return {
        memNow = memNow,
        memAfter = memAfter,
        cpu = cpuPerSec(),
        tweens = (ns.ActiveTweenCount and ns.ActiveTweenCount()) or 0,
        pooled = ns.CountPooledTextures(),
        effectsOff = (ns.db and ns.db.animations == "Off") and true or false,
    }
end

function ns.PerfPrint()
    local ok, err = pcall(function()
        local s = ns.PerfStats()
        local function kb(v) return v and tostring(ns.round(v)) or "?" end
        chat("memory: " .. kb(s.memNow) .. " KB now, " .. kb(s.memAfter) .. " KB after a GC pass")
        if profilingOn() then
            if s.cpu then
                chat(string.format("CPU: %.2f ms/s over the last %ds", s.cpu * 1000, math.max(1, #ns._cpuSamples - 1)))
            else
                chat("CPU: no samples yet (profiling is on; wait a few seconds)")
            end
        else
            chat("CPU: enable with /console scriptProfile 1 then /reload")
        end
        chat("active tweens: " .. tostring(s.tweens))
        chat("pooled textures in use: " .. tostring(s.pooled))
        chat("effects off because Animations = Off: " .. (s.effectsOff and "yes" or "no"))
    end)
    if not ok then chat("perf failed: " .. tostring(err)) end
end

ns._perf = false
function ns.SetPerf(on)
    ns._perf = on and true or false
    if ns._perf then
        chat("perf on (one line every 10s)")
        ns.PerfLoop()
    else
        chat("perf off")
    end
end

function ns.PerfLoop()
    if not ns._perf then return end
    ns.PerfPrint()
    if ns.API and ns.API.After then ns.API.After(10, ns.PerfLoop) end
end

-- ===========================================================================
-- Report text + window
-- ===========================================================================
ns.reportLink = "https://www.curseforge.com/wow/addons/xpbar-island/comments"

local EFFECT_KEYS = {
    "animations", "feel", "barFx", "cometOn", "segFlash", "charge",
    "barsText", "streak", "dip", "partyMotion", "hideCombat", "hideOutOfCombat",
    "autoSwitch", "sparkline", "party", "questList", "portrait",
}

local function addonNames()
    local out = {}
    local num = (_G.C_AddOns and _G.C_AddOns.GetNumAddOns and _G.C_AddOns.GetNumAddOns())
        or (_G.GetNumAddOns and _G.GetNumAddOns()) or 0
    for i = 1, num do
        local name, enabled
        if _G.C_AddOns and _G.C_AddOns.GetAddOnInfo then
            local ok, n, _, _, e = pcall(_G.C_AddOns.GetAddOnInfo, i)
            if ok then name, enabled = n, e end
        elseif _G.GetAddOnInfo then
            local ok, n, _, _, e = pcall(_G.GetAddOnInfo, i)
            if ok then name, enabled = n, e end
        end
        if enabled and name and name ~= ADDON then out[#out + 1] = name end
        if #out >= 30 then break end
    end
    return out
end

function ns.BuildReport(errorsOnly)
    local L = {}
    local function add(s) L[#L + 1] = s end
    add("XPBar Island report")
    add("====================")
    add("report page: " .. tostring(ns.reportLink or ""))

    if not errorsOnly then
        add("addon version: " .. ns.AddonVersion())
        local base = "game: unknown"
        if _G.GetBuildInfo then
            local ok, ver, build, _, toc = pcall(_G.GetBuildInfo)
            if ok then
                base = "game: " .. tostring(ver) .. " build " .. tostring(build) .. " interface " .. tostring(toc)
            end
        end
        add(base)
        local scale = (_G.UIParent and _G.UIParent.GetScale and _G.UIParent:GetScale())
            or (_G.GetCVar and _G.GetCVar("uiScale"))
        add("ui scale: " .. tostring(scale or "?"))

        local db = ns.db or {}
        add("preset: " .. tostring(db.preset or "?") .. "   display mode: " .. tostring(db.mode or "?")
            .. "   theme: " .. tostring(db.theme or "?"))
        add("profile: " .. tostring(db.profile or "Default"))
        add("size: " .. tostring(db.scale or "?") .. "%   width: " .. tostring(db.width or "?")
            .. "px   bar thickness: " .. tostring(db.barThickness or "?") .. "px")
        add("font: " .. tostring(db.font or "Theme") .. "   text size: " .. tostring(db.textSize or "?")
            .. "%   speed: " .. tostring(db.speed or "?") .. "%   strength: " .. tostring(db.strength or "?") .. "%")
        add("colors: trim " .. tostring(db.trimColor or "auto") .. ", bar " .. tostring(db.barColor or "auto")
            .. ", text " .. tostring(db.textAccent or "auto"))

        local flags = {}
        for _, k in ipairs(EFFECT_KEYS) do flags[#flags + 1] = k .. "=" .. tostring(db[k]) end
        add("effects: " .. table.concat(flags, " "))

        local key = (ns.data and ns.data.ActiveKey and ns.data:ActiveKey()) or "?"
        local level = (_G.UnitLevel and _G.UnitLevel("player")) or 0
        local maxL = (_G.GetMaxPlayerLevel and _G.GetMaxPlayerLevel()) or _G.MAX_PLAYER_LEVEL or 0
        add("bar type: " .. tostring(key) .. "   level: " .. tostring(level)
            .. "   max level: " .. ((maxL > 0 and level >= maxL) and "yes" or "no"))
        local inGroup = (ns.API and ns.API.InGroup and ns.API.InGroup()) and true or false
        add("in combat: " .. (ns.inCombat and "yes" or "no") .. "   in group: " .. (inGroup and "yes" or "no"))
        add("font status: " .. (ns.fontOK and "font ok" or "fallback"))

        local memNow = memKB()
        add("memory: " .. (memNow and (ns.round(memNow) .. " KB") or "?"))
        if profilingOn() then
            local c = cpuPerSec()
            add("cpu: " .. (c and string.format("%.2f ms/s", c * 1000) or "no samples yet"))
        else
            add("cpu: profiling off")
        end

        add("errors captured: " .. tostring(#ns.errors))
        local names = addonNames()
        add("other addons (" .. #names .. "): " .. table.concat(names, ", "))
    end

    add("")
    if errorsOnly then
        add("XPBar Island captured errors (" .. #ns.errors .. "):")
    else
        add("recent XPBar Island errors (" .. #ns.errors .. "):")
    end
    if #ns.errors == 0 then
        add("  (none captured)")
    else
        for i = 1, #ns.errors do
            local e = ns.errors[i]
            add("  [" .. tostring(e.time) .. "] " .. tostring(e.msg))
            if e.stack and e.stack ~= "" then add("      " .. e.stack) end
        end
    end
    return table.concat(L, "\n")
end

local rwin, rnote

local function buildReportWindow()
    local win = CreateFrame("Frame", "XPBarIslandReport", _G.UIParent)
    win:SetSize(580, 440)
    win:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:Hide()
    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "XPBarIslandReport") end

    local bg = win:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(win)
    ns.Paint(bg, 0.031, 0.027, 0.02, 1)
    local bd = win:CreateTexture(nil, "BORDER", nil, 1)
    bd:SetPoint("TOPLEFT", win, "TOPLEFT", -1, 1)
    bd:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 1, -1)
    ns.Paint(bd, 0.29, 0.23, 0.11, 1)

    local title = win:CreateFontString(nil, "OVERLAY")
    ns.StyleText(title, 15, "bold")
    title:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -10)
    title:SetText("XPBar Island report")

    local close = CreateFrame("Frame", nil, win)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -8, -8)
    close.x = close:CreateFontString(nil, "OVERLAY")
    ns.StyleText(close.x, 13, "bold")
    close.x:SetPoint("CENTER")
    close.x:SetText("x")
    close:EnableMouse(true)
    close:SetScript("OnMouseUp", function() win:Hide() end)

    local sf = CreateFrame("ScrollFrame", "XPBarIslandReportScroll", win)
    sf:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -36)
    sf:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 70)
    sf:EnableMouseWheel(true)
    local sfbg = sf:CreateTexture(nil, "BACKGROUND", nil, 0)
    sfbg:SetAllPoints(sf)
    ns.Paint(sfbg, 0.012, 0.012, 0.012, 1)

    local eb = CreateFrame("EditBox", "XPBarIslandReportText", sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetWidth(540)
    ns.StyleText(eb, 11, "medium", "")
    eb:SetJustifyH("LEFT")
    eb:SetTextColor(0.9, 0.9, 0.9, 1)
    eb:SetTextInsets(6, 6, 6, 6)
    sf:SetScrollChild(eb)

    eb._body = ""
    eb._lock = false
    eb:SetScript("OnTextChanged", function(self, user)
        if user and self._lock then
            self._lock = false
            self:SetText(self._body or "")
            self._lock = true
        end
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScript("OnMouseWheel", function(_, delta)
        local cur = sf:GetVerticalScroll() or 0
        local maxS = math.max(0, (eb:GetHeight() or 0) - (sf:GetHeight() or 0))
        sf:SetVerticalScroll(ns.clamp(cur - delta * 30, 0, maxS))
    end)
    sf:SetScript("OnSizeChanged", function()
        if eb then eb:SetWidth(math.max(100, (sf:GetWidth() or 540) - 12)) end
    end)

    local note = win:CreateFontString(nil, "OVERLAY")
    ns.StyleText(note, 11, "medium")
    note:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 12, 44)
    note:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 44)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.62, 0.62, 0.62, 1)

    local function button(label, w, onClick)
        local b = CreateFrame("Frame", nil, win)
        b:SetSize(w, 24)
        b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
        b.bg:SetAllPoints(b)
        ns.Gradient(b.bg, ns.HexA("#1A150E"), ns.HexA("#0C0A08"), false)
        b.bd = b:CreateTexture(nil, "BORDER", nil, 1)
        b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
        b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        ns.Paint(b.bd, 0.29, 0.23, 0.11, 1)
        b.label = b:CreateFontString(nil, "OVERLAY")
        ns.StyleText(b.label, 12, "bold")
        b.label:SetPoint("CENTER")
        b.label:SetText(label)
        b:EnableMouse(true)
        b:SetScript("OnMouseUp", function() onClick() end)
        return b
    end

    -- There is no addon API that opens a browser, so this shows the report in
    -- the fast copy popup (Ctrl+C to copy, Escape to close).
    local copyBtn
    copyBtn = button("Copy report", 100, function()
        if ns.LinkPopup then
            ns.LinkPopup(eb._body or ns.BuildReport(false), copyBtn, true)
        else
            eb:SetFocus()
            eb:HighlightText()
        end
    end)
    copyBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    local closeBtn = button("Close", 70, function() win:Hide() end)
    closeBtn:SetPoint("BOTTOMRIGHT", copyBtn, "BOTTOMLEFT", -6, 0)

    win.setBody = function(text)
        text = text or ""
        eb._body = text
        local _, count = string.gsub(text, "\n", "\n")
        eb:SetWidth(math.max(100, (sf:GetWidth() or 540) - 12))
        eb:SetHeight(math.max((sf:GetHeight() or 300), (count + 1) * 15 + 12))
        eb._lock = false
        eb:SetText(text)
        eb._lock = true
        eb:SetCursorPosition(0)
        eb:SetFocus()
        eb:HighlightText()
    end

    return win, note
end

function ns.ShowReport(errorsOnly)
    local ok, err = pcall(function()
        if not rwin then rwin, rnote = buildReportWindow() end
        rwin.setBody(ns.BuildReport(errorsOnly))
        rnote:SetText("Click \"Copy report\", press Ctrl+C, then paste it at "
            .. tostring(ns.reportLink or "") .. " with a short description of what happened.")
        rwin:Show()
        if rwin.Raise then rwin:Raise() end
    end)
    if not ok then chat("report failed: " .. tostring(err)) end
end

function ns.ReportBug()
    ns.ShowReport(false)
end

-- ===========================================================================
-- 3. Reset all (confirm popup) + safe mode
-- ===========================================================================
function ns.DoResetAll()
    pcall(function()
        local DB = _G.XPBarIslandDB
        if type(DB) == "table" then
            local backup = DB.profile and DB.profile.backup
            local profile = {}
            if ns.CopyDefaults then ns.CopyDefaults(profile, ns.defaults) end
            profile.backup = backup
            profile.profiles = { Default = {} }
            profile.profile = "Default"
            DB.profile = profile
            ns.db = profile
        end
    end)
    if _G.ReloadUI then pcall(_G.ReloadUI) end
end

local RESET_ALL_POPUP = "XPBarIslandResetAll"
function ns.ResetEverything()
    local ok = pcall(function()
        if not (_G.StaticPopup_Show and _G.StaticPopupDialogs) then
            ns.DoResetAll()
            return
        end
        if not _G.StaticPopupDialogs[RESET_ALL_POPUP] then
            _G.StaticPopupDialogs[RESET_ALL_POPUP] = {
                text = "Reset every XPBar Island setting and profile?",
                button1 = "Reset",
                button2 = "Cancel",
                OnAccept = function() ns.DoResetAll() end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
        end
        _G.StaticPopup_Show(RESET_ALL_POPUP)
    end)
    if not ok then ns.DoResetAll() end
end

local safeBackup, safeKeys = nil, nil
function ns.SafeMode()
    local ok, err = pcall(function()
        if not ns.db and ns.InitDB then ns.InitDB() end
        if not ns.db then return end
        safeBackup = safeBackup or {}
        safeKeys = safeKeys or {}
        local keys = {
            "mode", "animations", "cometOn", "segFlash", "charge", "streak",
            "dip", "partyMotion", "barFx", "hideCombat", "hideOutOfCombat", "autoSwitch",
            "sparkline", "party", "questList", "portrait", "showRate", "showDots",
            "compact", "hoverExpand", "scale",
            "mLevel", "mName", "mPct", "mBars", "mGain", "mStreak", "mRested", "mRate", "mEta",
        }
        for _, k in ipairs(keys) do
            if not safeKeys[k] then safeKeys[k] = true; safeBackup[k] = ns.db[k] end
        end
        -- Minimal preset
        ns.db.mode = "Classic"
        ns.db.hideCombat = true; ns.db.hideOutOfCombat = false; ns.db.compact = true; ns.db.autoSwitch = false
        ns.db.sparkline = false; ns.db.party = false; ns.db.questList = false; ns.db.portrait = false
        ns.db.showDots = false; ns.db.showRate = false
        ns.db.mLevel = true; ns.db.mName = true; ns.db.mPct = true; ns.db.mBars = true
        ns.db.mGain = true; ns.db.mStreak = true; ns.db.mRested = true
        ns.db.mRate = false; ns.db.mEta = false
        -- all effects off
        ns.db.animations = "Off"; ns.db.cometOn = false; ns.db.segFlash = false; ns.db.charge = false
        ns.db.streak = false; ns.db.dip = false; ns.db.partyMotion = false
        if ns.island and ns.island.Refresh then pcall(ns.island.Refresh, ns.island) end
        if ns.MarkDirty then ns.MarkDirty() end
        chat("safe mode on for this session (all effects off, Minimal preset). Reload to undo.")
    end)
    if not ok then chat("safe mode failed: " .. tostring(err)) end
end

function ns.RestoreSafeMode()
    if safeBackup and safeKeys and ns.db then
        for k in pairs(safeKeys) do ns.db[k] = safeBackup[k] end
    end
    safeBackup, safeKeys = nil, nil
end

-- ===========================================================================
-- 4. First-run / update welcome tip
-- ===========================================================================
ns.changelog = {
    ["1.0.0"] = "Kill streaks, Comet/Flow bar effects, segment flashes, the upgraded session XP graph and the settings Studio.",
    ["1.0.1"] = "Blizzard's XP and rep bars are now hidden by default, professions show on Skills, and there's a pin button plus a tidier (hidden-by-default) minimap button.",
    ["1.0.2"] = "Move mode now lets you drag the island anywhere on screen.",
    ["1.0.4"] = "New installs now default to the WoW Forever theme. Kill-streak tiers (off by default), a compact under-island announcement (no sound), a one-click bug-report copy popup, and X/CurseForge logo links.",
    ["1.0.6"] = "Skills show your professions again on the latest client, plus a Hide out of combat option and a level-up stats card.",
    ["1.0.7"] = "The collapsed bar no longer lets the Resting tag overlap the bars-to-level text.",
    ["1.0.8"] = "New Level-up summary toggle under Behavior if you want the stats card off.",
    ["1.0.9"] = "Battleground chat and next-spell tooltip fixes, thanks to @dstjohniii.",
    ["1.0.10"] = "Kills to level ignores quest XP and handles the rested pool, the comet sweep is smoother, and the level-up summary no longer errors on clients with secret values.",
}

local tip

function ns.HideTip()
    if not tip or not tip:IsShown() then return end
    if tip._timer then ns.CancelTimer(tip._timer); tip._timer = nil end
    if tip._fade then ns.KillTween(tip._fade) end
    tip._fade = ns.Tween({
        dur = 0.25, from = tip:GetAlpha() or 1, to = 0, ease = ns.easeOutCubic,
        set = function(v) tip:SetAlpha(v) end,
        done = function() tip:Hide(); tip._fade = nil end,
    })
end

local function buildTip()
    local f = CreateFrame("Frame", nil, _G.UIParent)
    f:SetPoint("TOP", (ns.island and ns.island.frame) or _G.UIParent, "BOTTOM", 0, -8)
    f:SetFrameStrata("MEDIUM")
    f:SetHeight(24)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    ns.Paint(f.bg, 0.051, 0.043, 0.031, 1)
    local gold = ns.HexA("#FFD100")
    f.bd = {}
    for i = 1, 4 do
        local t = f:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(ns.Media.white)
        ns.Paint(t, gold[1], gold[2], gold[3], 1)
        f.bd[i] = t
    end
    f.bd[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); f.bd[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); f.bd[1]:SetHeight(1)
    f.bd[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); f.bd[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); f.bd[2]:SetHeight(1)
    f.bd[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); f.bd[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); f.bd[3]:SetWidth(1)
    f.bd[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); f.bd[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); f.bd[4]:SetWidth(1)

    f.label = f:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.label, 12, "bold")
    f.label:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.label:SetTextColor(gold[1], gold[2], gold[3], 1)

    f.open = CreateFrame("Frame", nil, f)
    f.open:SetSize(96, 18)
    f.open.bg = f.open:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.open.bg:SetAllPoints(f.open)
    ns.Gradient(f.open.bg, ns.HexA("#5A431A"), ns.HexA("#2A1D09"), false)
    f.open.label = f.open:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.open.label, 11, "bold")
    f.open.label:SetPoint("CENTER")
    f.open.label:SetText("Open settings")
    f.open.label:SetTextColor(gold[1], gold[2], gold[3], 1)
    f.open:EnableMouse(true)
    f.open:SetScript("OnMouseUp", function()
        ns.HideTip()
        if ns.OpenSettings then pcall(ns.OpenSettings) end
    end)

    f.x = CreateFrame("Frame", nil, f)
    f.x:SetSize(16, 16)
    f.x.label = f.x:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.x.label, 11, "bold")
    f.x.label:SetPoint("CENTER")
    f.x.label:SetText("x")
    f.x.label:SetTextColor(0.62, 0.62, 0.62, 1)
    f.x:EnableMouse(true)
    f.x:SetScript("OnMouseUp", function() ns.HideTip() end)

    f:Hide()
    return f
end

function ns.ShowTip(text)
    local ok, err = pcall(function()
        if not tip then tip = buildTip() end
        tip.label:SetText(text or "")
        local lw = tip.label:GetStringWidth() or 120
        tip.open:ClearAllPoints()
        tip.open:SetPoint("LEFT", tip.label, "RIGHT", 10, 0)
        tip.x:ClearAllPoints()
        tip.x:SetPoint("LEFT", tip.open, "RIGHT", 6, 0)
        tip:SetWidth(lw + 10 + 96 + 6 + 16 + 10)
        if tip._timer then ns.CancelTimer(tip._timer) end
        if tip._fade then ns.KillTween(tip._fade); tip._fade = nil end
        tip:SetAlpha(1)
        tip:Show()
        tip._timer = ns.After(12, function() ns.HideTip() end)
    end)
    if not ok then chat("tip failed: " .. tostring(err)) end
end

local welcomeShown = false
function ns.MaybeWelcomeTip()
    if welcomeShown then return end
    if not ns.db then return end
    if ns.db.tips == false then return end
    local version = ns.AddonVersion()
    local seen = ns.db.seenWelcome
    local text
    if seen == nil then
        text = "Type /xpbar to open settings"
    elseif seen ~= version then
        text = ns.changelog and ns.changelog[version]
        if not text then return end
    else
        return
    end
    welcomeShown = true
    ns.db.seenWelcome = version
    local after = (ns.API and ns.API.After) or ns.After
    after(3, function() ns.ShowTip(text) end)
end

-- ===========================================================================
-- Private event frame (Report loads before Core/Events.lua, so it cannot use
-- the shared ns.On bus).
-- ===========================================================================
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if profilingOn() and not ns._cpuStarted then
            ns._cpuStarted = true
            if ns.API and ns.API.After then ns.API.After(1, cpuSampler) end
        end
        ns.MaybeWelcomeTip()
    elseif event == "PLAYER_LOGOUT" then
        ns.RestoreSafeMode()
    end
end)
