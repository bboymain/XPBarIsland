local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Number / text formatting
-- ---------------------------------------------------------------------------

function ns.round(n)
    n = tonumber(n) or 0
    if n >= 0 then return math.floor(n + 0.5) end
    return math.ceil(n - 0.5)
end

function ns.clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

-- 1250000 -> "1,250,000"
function ns.Comma(n)
    n = math.floor(tonumber(n) or 0)
    local neg = n < 0
    local s = tostring(math.abs(n))
    local k
    repeat
        s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    until k == 0
    if neg then s = "-" .. s end
    return s
end

-- Compact form: 9900 -> "9.9K", 1250000 -> "1.25M".
function ns.Short(n, compact)
    n = tonumber(n) or 0
    if not compact then return ns.Comma(n) end
    local sign = n < 0 and "-" or ""
    n = math.abs(n)
    if n >= 1e6 then
        local v = n / 1e6
        local s = (v >= 100) and string.format("%.0f", v) or string.format("%.2f", v)
        s = s:gsub("%.?0+$", "")
        return sign .. s .. "M"
    elseif n >= 1e3 then
        local v = n / 1e3
        local s = (v >= 100) and string.format("%.0f", v) or string.format("%.1f", v)
        s = s:gsub("%.0$", "")
        return sign .. s .. "K"
    end
    return sign .. tostring(math.floor(n))
end

-- 0.989 -> "98.9%"
function ns.Percent(pct, decimals)
    decimals = decimals or 1
    return string.format("%." .. decimals .. "f%%", (tonumber(pct) or 0) * 100)
end

-- Seconds -> "1h 12m", "24m", "2d 6h", "45s".
function ns.Time(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    if sec >= 86400 then
        local d = math.floor(sec / 86400)
        local h = math.floor((sec % 86400) / 3600)
        return d .. "d " .. h .. "h"
    elseif sec >= 3600 then
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        return h .. "h " .. m .. "m"
    elseif sec >= 60 then
        local m = math.floor(sec / 60)
        return m .. "m"
    end
    return sec .. "s"
end

-- Timestamp -> "12s ago", "3m ago", "just now".
function ns.Ago(t)
    local s = math.max(0, math.floor(GetTime() - (tonumber(t) or GetTime())))
    if s < 2 then return "just now" end
    if s < 60 then return s .. "s ago" end
    return ns.Time(s) .. " ago"
end

function ns.Text(hex, str)
    if hex and hex:sub(1, 2) == "|c" then return hex .. tostring(str) .. "|r" end
    return "|cff" .. tostring(hex or "ffffff"):gsub("#", "") .. tostring(str) .. "|r"
end

function ns.ClassColor(token)
    local c = token and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[token]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- ---------------------------------------------------------------------------
-- Small animation / timer driver (single OnUpdate frame)
-- ---------------------------------------------------------------------------

local driver = CreateFrame("Frame")
local tweens = {}
local timers = {}

function ns.easeLinear(p) return p end
function ns.easeOutCubic(p) return 1 - (1 - p) ^ 3 end
function ns.easeInOutCubic(p)
    if p < 0.5 then return 4 * p * p * p end
    return 1 - ((-2 * p + 2) ^ 3) / 2
end
function ns.easeOutBack(p)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (p - 1) ^ 3 + c1 * (p - 1) ^ 2
end
function ns.easeOutQuad(p) return 1 - (1 - p) * (1 - p) end

-- CSS cubic-bezier easing (same curves the mockup uses).  Solves x(s)=t with
-- Newton-Raphson, then returns y(s).
function ns.cubicBezier(x1, y1, x2, y2)
    local function A(a1, a2) return 1 - 3 * a2 + 3 * a1 end
    local function B(a1, a2) return 3 * a2 - 6 * a1 end
    local function C(a1) return 3 * a1 end
    local function calc(t, a1, a2) return ((A(a1, a2) * t + B(a1, a2)) * t + C(a1)) * t end
    local function slope(t, a1, a2) return 3 * A(a1, a2) * t * t + 2 * B(a1, a2) * t + C(a1) end
    return function(t)
        if t <= 0 then return 0 end
        if t >= 1 then return 1 end
        local s = t
        for _ = 1, 8 do
            local x = calc(s, x1, x2) - t
            if math.abs(x) < 1e-5 then break end
            local d = slope(s, x1, x2)
            if math.abs(d) < 1e-6 then break end
            s = s - x / d
        end
        return calc(s, y1, y2)
    end
end

-- ns.Tween{ dur=, from=, to=, ease=, set=function(value,p), done=}
-- Returns a handle that can be passed to ns.KillTween.
local ensureDriver -- forward declaration (defined below)

function ns.Tween(a)
    a.t = 0
    a.from = a.from or 0
    a.to = a.to or 1
    -- Animation speed: every tween duration is divided by speed/100.
    local sp = (ns.db and ns.db.speed) or 100
    if a.dur and a.dur > 0 and sp ~= 100 then a.dur = a.dur / (sp / 100) end
    tweens[a] = true
    ensureDriver()
    return a
end

function ns.KillTween(handle)
    if handle then tweens[handle] = nil end
end

-- Number of tweens currently animating (used by /xpbar debug and perf).
function ns.ActiveTweenCount()
    local n = 0
    for _ in pairs(tweens) do n = n + 1 end
    return n
end

function ns.After(delay, cb)
    local t = { t = 0, d = delay or 0, fn = cb }
    timers[t] = true
    ensureDriver()
    return t
end

function ns.CancelTimer(handle)
    if handle then timers[handle] = nil end
end

-- ---------------------------------------------------------------------------
-- Batch mode: while a preset/profile writes many settings, defer Notify and
-- MarkDirty so listeners and island:Refresh run exactly once (see EndBatch).
-- ---------------------------------------------------------------------------
local batchDepth = 0
function ns.BatchActive() return batchDepth > 0 end
function ns.BeginBatch() batchDepth = batchDepth + 1 end
function ns.EndBatch()
    if batchDepth > 0 then batchDepth = batchDepth - 1 end
    if batchDepth > 0 then return end
    if ns.FlushBatch then
        local ok, err = pcall(ns.FlushBatch)
        if not ok and ns.ReportError then ns.ReportError("EndBatch", err) end
    end
end

-- Fractional elapsed used for free-running pulses.
ns.animClock = 0

-- The driver only runs while there is a tween or timer pending; it turns its
-- OnUpdate off again when everything has settled, so there is no idle cost.
local function driverUpdate(_, elapsed)
    ns.animClock = ns.animClock + elapsed

    -- Iterate over snapshots: callbacks may add or remove tweens/timers, which
    -- would otherwise rehash the table mid-traversal ("invalid key to 'next'").
    local tlist = {}
    for a in pairs(tweens) do tlist[#tlist + 1] = a end
    for i = 1, #tlist do
        local a = tlist[i]
        if tweens[a] then
            a.t = a.t + elapsed
            local p = a.dur and a.dur > 0 and (a.t / a.dur) or 1
            if p > 1 then p = 1 end
            local e = a.ease and a.ease(p) or p
            local v = a.from + (a.to - a.from) * e
            if a.set then a.set(v, p) end
            if p >= 1 then
                tweens[a] = nil
                if a.done then a.done() end
            end
        end
    end

    local mlist = {}
    for t in pairs(timers) do mlist[#mlist + 1] = t end
    for i = 1, #mlist do
        local t = mlist[i]
        if timers[t] then
            t.t = t.t + elapsed
            if t.t >= t.d then
                timers[t] = nil
                if t.fn then t.fn() end
            end
        end
    end

    if not next(tweens) and not next(timers) then
        driver.__running = false
        driver:SetScript("OnUpdate", nil)
    end
end

function ensureDriver()
    if not driver.__running then
        driver.__running = true
        driver:SetScript("OnUpdate", driverUpdate)
    end
end

-- ---------------------------------------------------------------------------
-- Contact / support links.
--
-- WoW has no addon API that opens a browser, so instead of a dead "url:" link
-- we show a small XPBar Island-styled popup with the URL/report in a focused,
-- pre-selected EditBox: Ctrl+C copies it, Escape or a click outside closes.
-- ---------------------------------------------------------------------------
ns.CONTACT_URL = "https://x.com/mainlek"
ns.CONTACT_HANDLE = "@mainlek"
ns.CURSEFORGE_URL = "https://www.curseforge.com/wow/addons/xpbar-island"

local linkPopup, linkBackdrop

local function hideLinkPopup()
    if linkPopup then linkPopup:Hide() end
    if linkBackdrop then linkBackdrop:Hide() end
end

local function paintEdges(frame, r, g, b, a, thick)
    thick = thick or 1
    local e = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(ns.Media.white)
        ns.Paint(t, r, g, b, a or 1)
        e[i] = t
    end
    e[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    e[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    e[1]:SetHeight(thick)
    e[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    e[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    e[2]:SetHeight(thick)
    e[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    e[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    e[3]:SetWidth(thick)
    e[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    e[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    e[4]:SetWidth(thick)
    return e
end

local function buildLinkPopup()
    local th = (ns.Theme and ns.Theme()) or {}
    local gold = ns.HexA(th.gold or "#FFD100")
    local trim = ns.HexA(th.trim or th.ring or "#6F5326")
    local grey = ns.HexA(th.grey or "#9D9D9D")
    local ir, ig, ib = ns.Hex(th.inner or "#2A1F0E")

    linkBackdrop = CreateFrame("Button", nil, _G.UIParent)
    linkBackdrop:SetFrameStrata("FULLSCREEN_DIALOG")
    linkBackdrop:SetFrameLevel(900)
    linkBackdrop:SetAllPoints(_G.UIParent)
    local bdTex = linkBackdrop:CreateTexture(nil, "BACKGROUND")
    bdTex:SetAllPoints()
    ns.Paint(bdTex, 0, 0, 0, 0.35)
    linkBackdrop:RegisterForClicks("AnyUp")
    linkBackdrop:SetScript("OnClick", hideLinkPopup)
    linkBackdrop:Hide()

    linkPopup = CreateFrame("Frame", nil, _G.UIParent)
    linkPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    linkPopup:SetFrameLevel(901)
    linkPopup:SetSize(420, 150)
    linkPopup:SetMovable(true)
    linkPopup:EnableMouse(true)
    linkPopup:SetClampedToScreen(true)
    linkPopup:RegisterForDrag("LeftButton")
    linkPopup:SetScript("OnDragStart", function(self) self:StartMoving() end)
    linkPopup:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local bg = linkPopup:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    ns.WhiteTexture(bg)
    ns.Gradient(bg, ns.HexA(th.bg1 or "#17120C"), ns.HexA(th.bg2 or "#0D0B08"), false)
    paintEdges(linkPopup, trim[1], trim[2], trim[3], 1, 2)

    local title = linkPopup:CreateFontString(nil, "OVERLAY")
    ns.StyleText(title, 14, "extrabold")
    title:SetPoint("TOPLEFT", linkPopup, "TOPLEFT", 14, -11)
    title:SetText("Copy link")
    title:SetTextColor(gold[1], gold[2], gold[3], 1)
    linkPopup._title = title

    local rule = linkPopup:CreateTexture(nil, "ARTWORK", nil, 1)
    rule:SetPoint("TOPLEFT", linkPopup, "TOPLEFT", 14, -34)
    rule:SetPoint("TOPRIGHT", linkPopup, "TOPRIGHT", -14, -34)
    rule:SetHeight(1)
    ns.Paint(rule, trim[1], trim[2], trim[3], 0.7)

    local closeX = CreateFrame("Button", nil, linkPopup)
    closeX:SetSize(18, 18)
    closeX:SetPoint("TOPRIGHT", linkPopup, "TOPRIGHT", -8, -8)
    closeX.label = closeX:CreateFontString(nil, "OVERLAY")
    ns.StyleText(closeX.label, 14, "bold")
    closeX.label:SetPoint("CENTER")
    closeX.label:SetText("x")
    closeX.label:SetTextColor(grey[1], grey[2], grey[3], 1)
    closeX:SetScript("OnEnter", function() closeX.label:SetTextColor(gold[1], gold[2], gold[3], 1) end)
    closeX:SetScript("OnLeave", function() closeX.label:SetTextColor(grey[1], grey[2], grey[3], 1) end)
    closeX:SetScript("OnClick", hideLinkPopup)

    local hint = linkPopup:CreateFontString(nil, "OVERLAY")
    ns.StyleText(hint, 11, "medium")
    hint:SetPoint("TOPLEFT", linkPopup, "TOPLEFT", 14, -42)
    hint:SetPoint("TOPRIGHT", linkPopup, "TOPRIGHT", -14, -42)
    hint:SetJustifyH("LEFT")
    hint:SetText("Press Ctrl+C to copy, then Escape to close.")
    hint:SetTextColor(grey[1], grey[2], grey[3], 1)

    local eb = CreateFrame("EditBox", nil, linkPopup)
    eb:SetPoint("TOPLEFT", linkPopup, "TOPLEFT", 14, -62)
    eb:SetPoint("TOPRIGHT", linkPopup, "TOPRIGHT", -14, -62)
    eb:SetHeight(26)
    ns.StyleText(eb, 12, "medium", "")
    eb:SetAutoFocus(false)
    eb:SetJustifyH("LEFT")
    eb:SetTextColor(1, 1, 1, 1)
    eb:SetTextInsets(8, 8, 5, 5)
    local ebBg = eb:CreateTexture(nil, "BACKGROUND", nil, -1)
    ebBg:SetAllPoints()
    ns.Paint(ebBg, ir, ig, ib, 1)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); hideLinkPopup() end)
    eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    linkPopup:SetScript("OnMouseDown", function()
        linkPopup._eb:SetFocus()
        linkPopup._eb:HighlightText()
    end)
    linkPopup._eb = eb

    local close = CreateFrame("Button", nil, linkPopup)
    close:SetSize(96, 24)
    close:SetPoint("BOTTOMRIGHT", linkPopup, "BOTTOMRIGHT", -14, 12)
    close.bg = close:CreateTexture(nil, "BACKGROUND", nil, 0)
    close.bg:SetAllPoints()
    ns.WhiteTexture(close.bg)
    ns.Gradient(close.bg, ns.HexA(th.btnPrimary1 or th.btn1 or "#7A5A16"), ns.HexA(th.btnPrimary2 or th.btn2 or "#3A2C12"), false)
    paintEdges(close, trim[1], trim[2], trim[3], 1, 1)
    close.label = close:CreateFontString(nil, "OVERLAY")
    ns.StyleText(close.label, 12, "bold")
    close.label:SetPoint("CENTER")
    close.label:SetText("Close")
    close.label:SetTextColor(ns.Hex(th.btnText or th.gold or "#FFD100"))
    close:SetScript("OnClick", hideLinkPopup)
    linkPopup._close = close

    return linkPopup
end

-- text = what to copy; multiline = tall box for the report; always centred so
-- it sits above the settings/report windows.
function ns.LinkPopup(text, _, multiline)
    if type(text) ~= "string" or text == "" then return end
    if not linkPopup then buildLinkPopup() end
    local eb = linkPopup._eb
    eb:SetText(text)
    if linkPopup._title then linkPopup._title:SetText(multiline and "Copy report" or "Copy link") end
    if multiline then
        local _, lines = string.gsub(text, "\n", "\n")
        local h = math.min(220, math.max(30, (lines + 1) * 16 + 8))
        eb:SetMultiLine(true)
        eb:SetHeight(h)
        linkPopup:SetHeight(62 + h + 44)
    else
        eb:SetMultiLine(false)
        eb:SetHeight(26)
        linkPopup:SetHeight(150)
    end
    linkPopup:ClearAllPoints()
    linkPopup:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    linkBackdrop:Show()
    linkPopup:Show()
    if linkPopup.Raise then linkPopup:Raise() end
    eb:SetFocus()
    eb:HighlightText()
end

function ns.OpenContact()
    if ns.LinkPopup then ns.LinkPopup(ns.CONTACT_URL) end
end

function ns.OpenCurseForge()
    if ns.LinkPopup then ns.LinkPopup(ns.CURSEFORGE_URL) end
end

-- Kept for callers that just want the URL shown in the copy popup.
function ns.OpenURL(url)
    if type(url) ~= "string" or url == "" then return end
    if ns.LinkPopup then ns.LinkPopup(url) end
end
