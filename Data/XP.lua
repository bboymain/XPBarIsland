local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Experience + session tracking.
-- ---------------------------------------------------------------------------
local session = {
    start = GetTime(),
    gain = 0,              -- xp gained this session
    lastXP = nil,
    lastMax = nil,
    lastLevel = nil,
    levelStart = GetTime(),
    killXP = nil,
    killName = nil,
    samples = {},          -- { {t=cumXP, v=...}, ... }  (last 13)
    playedTotal = nil,
    playedLevel = nil,     -- seconds played at the current level (TIME_PLAYED_MSG)
    playedAt = nil,        -- GetTime() when playedTotal/playedLevel were received
    lastSample = 0,
    lastSeen = nil,        -- wall-clock time() of the last XP gain
}
ns.session = session

-- ---------------------------------------------------------------------------
-- Kill streak (in-memory only, not saved across logins).
-- ---------------------------------------------------------------------------
ns.streak = { n = 0, lastAt = 0, newBest = false, tier = 0 }
ns.streakBest = 0

-- WoW-flavoured streak tiers: fewer and further apart, each with a title, a
-- short sub and a colour, awarded the first time the running kill count reaches
-- its threshold.  Tier 5's title depends on the player's faction, so it is
-- resolved when announced (ns.StreakTitle) rather than at load.
ns.StreakTiers = {
    { n = 3,  title = "TRIPLE PULL",  sub = "Chain-pulling like a pro", color = "#FFD100" },
    { n = 5,  title = "FACTION CRY",  sub = "For your side",            color = "#FF9A2E" },
    { n = 8,  title = "EXECUTE!",     sub = "Finish them",              color = "#FF5544" },
    { n = 12, title = "BLOODLUST!",   sub = "Everything's faster",      color = "#D46AFF" },
    { n = 16, title = "LEEROY!",      sub = "At least I have chicken",  color = "#6FE3FF" },
    { n = 20, title = "ONE-MAN RAID", sub = "Who needs a tank?",        color = "#FF6AD5" },
    { n = 30, title = "WORLD FIRST",  sub = "The server's watching",    color = "#FFD100" },
    { n = 50, title = "LEGENDARY",    sub = "Drops are for mortals",    color = "#FF9A2E" },
}

-- Optional per-class subtitle for tier 8.  Kept small and safe; an unknown
-- class simply falls back to the tier's default sub.
local classSub = {
    WARRIOR = "Execute!",
    HUNTER  = "Kill Command",
    MAGE    = "Polymorph party",
}

local function factionTitle()
    local ok, f = pcall(UnitFactionGroup, "player")
    if ok and f == "Horde" then return "FOR THE HORDE!" end
    if ok and f == "Alliance" then return "FOR THE ALLIANCE!" end
    return "VICTORY!"
end

-- Resolve a tier's title at announce time (tier 5 is faction-dependent).
function ns.StreakTitle(tier)
    if not tier then return nil end
    if tier.n == 5 then return factionTitle() end
    return tier.title
end

-- Resolve a tier's subtitle (tier 8 may use a class-flavoured line).
function ns.StreakSub(tier)
    if not tier then return nil end
    if tier.n == 8 then
        local ok, _, class = pcall(UnitClass, "player")
        local s = ok and class and classSub[class]
        if s then return s end
    end
    return tier.sub
end

-- The highest tier reached at or below the given kill count, or nil.
function ns.StreakTier(n)
    n = n or 0
    local best
    for i = 1, #ns.StreakTiers do
        if n >= ns.StreakTiers[i].n then best = ns.StreakTiers[i] else break end
    end
    return best
end

-- The next tier above the given kill count, or nil when past the top.
function ns.NextStreakTier(n)
    n = n or 0
    for i = 1, #ns.StreakTiers do
        if ns.StreakTiers[i].n > n then return ns.StreakTiers[i] end
    end
    return nil
end

function ns.CountKill()
    local s = ns.streak
    local now = GetTime()
    if now - (s.lastAt or 0) <= 20 then s.n = (s.n or 0) + 1 else s.n = 1 end
    s.lastAt = now
    -- best streak this session only (not saved across logins)
    s.newBest = (s.n > (ns.streakBest or 0))
    if s.newBest then ns.streakBest = s.n end
    -- celebrate the first time each tier threshold is crossed
    local tier = ns.StreakTier(s.n)
    local tn = tier and tier.n or 0
    if tier and tn > (s.tier or 0) then
        s.tier = tn
        if ns.StreakAnnounce then ns.StreakAnnounce(tier, s.n, s.newBest) end
    elseif tn < (s.tier or 0) then
        s.tier = tn
    end
    if ns.island and ns.island.OnStreakKill then ns.island:OnStreakKill() end
    ns.MarkDirty()
end

function ns.StreakActive()
    local s = ns.streak
    if not s then return false, 0 end
    return (s.n >= 2 and (GetTime() - (s.lastAt or 0)) < 20), (s.n or 0)
end

function ns.TestStreak(count)
    count = count or 20
    for i = 1, count do
        ns.After((i - 1) * 0.4, function() ns.CountKill() end)
    end
end

function session:Reset()
    self.start = GetTime()
    self.gain = 0
    self.killXP = nil
    self.killName = nil
    self.samples = {}
    self.lastSample = 0
    self.levelStart = GetTime()
    self.lastSeen = nil
    if type(ns.char) == "table" then ns.char.session = nil end
    ns.streak.n = 0
    ns.streak.lastAt = 0
    ns.streak.newBest = false
    ns.streak.tier = 0
    ns.streakBest = 0
    if ns.island and ns.island.UpdateStreak then ns.island:UpdateStreak() end
    ns.MarkDirty()
end

-- Persist across logins so the session (gain, elapsed, last gain time) is
-- restored.  lastSeen is wall-clock time() so it can be converted back to a
-- GetTime()-relative age on the next login.
function session:Save()
    if type(ns.char) ~= "table" then return end
    ns.char.session = {
        gain = self.gain or 0,
        elapsed = self:Elapsed(),
        lastSeen = self.lastSeen,
    }
end

function session:Restore()
    local s = (type(ns.char) == "table") and ns.char.session or nil
    if type(s) ~= "table" then return end
    self.gain = tonumber(s.gain) or 0
    local elapsed = tonumber(s.elapsed) or 0
    if elapsed < 0 then elapsed = 0 end
    self.start = GetTime() - elapsed
    self.lastSeen = tonumber(s.lastSeen)
    if ns.island then
        ns.island._seenGain = self.gain
        if self.lastSeen then
            local age = time() - self.lastSeen
            if age < 0 then age = 0 end
            -- wall-clock age -> GetTime() terms
            ns.island._gainAt = GetTime() - age
        end
    end
end

function session:Elapsed()
    return GetTime() - self.start
end

-- Time played at the current level: the server's authoritative value from
-- TIME_PLAYED_MSG, advanced locally since it was received.  Survives /reload
-- and relog because it does not depend on when the UI loaded.  Returns nil
-- until the first TIME_PLAYED_MSG arrives.
function session:LevelElapsed()
    if self.playedLevel and self.playedAt then
        local e = self.playedLevel + (GetTime() - self.playedAt)
        if e < 0 then e = 0 end
        return e
    end
    return nil
end

function session:Rate()
    local e = self:Elapsed()
    if e < 60 then return nil end
    return self.gain / (e / 3600)
end

function session:AddSample(total)
    local now = GetTime()
    self.samples[#self.samples + 1] = { t = total }
    if #self.samples > 13 then table.remove(self.samples, 1) end
    self.lastSample = now
end

-- ---------------------------------------------------------------------------
-- Kill XP text parsing (bonus: the XP amount itself comes from the delta).
-- ---------------------------------------------------------------------------
local function buildPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%s", "(.+)")
    p = p:gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

local killPatterns = {}
local function initPatterns()
    local names = {
        "COMBATLOG_XPGAIN_FIRSTPERSON",
        "COMBATLOG_XPGAIN_FIRSTPERSON_FULL",
        "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED",
        "COMBATLOG_XPGAIN_EXHAUSTION1",
        "COMBATLOG_XPGAIN_EXHAUSTION1_UNNAMED",
    }
    for _, n in ipairs(names) do
        local fmt = _G[n]
        local p = buildPattern(fmt)
        if p then killPatterns[#killPatterns + 1] = p end
    end
end
initPatterns()

local function parseKill(msg)
    for _, p in ipairs(killPatterns) do
        local a, b = msg:match(p)
        if a then
            local name, amount = a, b
            if tonumber(a) and not tonumber(b) then
                name, amount = nil, a
            end
            local amt = tonumber((amount or ""):gsub("[^%d]", ""))
            if amt then return name, amt end
        end
    end
    -- Last resort: any group of digits in an "XP gain" style message.
    local amt = msg:match("(%d[%d,]*%d)")
    if amt then
        return nil, tonumber((amt:gsub("[^%d]", "")))
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Snapshots
-- ---------------------------------------------------------------------------
function ns.xp()
    local cur = (ns.API.UnitXP and UnitXP("player")) or 0
    local max = (ns.API.UnitXPMax and UnitXPMax("player")) or 1
    if max <= 0 then max = 1 end
    local level = UnitLevel("player") or 0
    local rested = (ns.API.GetXPExhaustion and ns.API.GetXPExhaustion()) or 0
    local resting = (ns.API.IsResting and IsResting()) or false
    local pct = cur / max
    return {
        cur = cur,
        max = max,
        level = level,
        rested = rested,
        resting = resting,
        pct = pct,
        elapsed = session:Elapsed(),
        rate = session:Rate(),
        gain = session.gain,
        killXP = session.killXP,
        killName = session.killName,
        samples = session.samples,
    }
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local function onXP()
    local cur = (ns.API.UnitXP and UnitXP("player")) or 0
    local max = (ns.API.UnitXPMax and UnitXPMax("player")) or 1
    local level = UnitLevel("player") or 0
    if session.lastXP ~= nil and session.lastLevel == level then
        local d = cur - session.lastXP
        if d > 0 then
            session.gain = session.gain + d
            session.lastSeen = time()
            if ns.island and ns.island.Peek then ns.island:Peek() end
        end
    end
    session.lastXP = cur
    session.lastMax = max
    session.lastLevel = level
    ns.TouchData()
    ns.MarkDirty()
end

ns.On("PLAYER_XP_UPDATE", function()
    -- grab kill info first so we can name the gain text
    onXP()
end)

ns.On("UPDATE_EXHAUSTION", ns.MarkDirty)
ns.On("PLAYER_UPDATE_RESTING", ns.MarkDirty)

ns.On("PLAYER_LEVEL_UP", function(_, newLevel)
    session.lastXP = 0
    session.lastMax = (ns.API.UnitXPMax and UnitXPMax("player")) or 1
    session.lastLevel = newLevel or UnitLevel("player")
    session.killXP = nil
    session.killName = nil
    session.levelStart = GetTime()
    -- the server's "this level" timer resets on level-up: clear the locally
    -- advanced value now and refresh from TIME_PLAYED_MSG
    session.playedLevel = 0
    session.playedAt = GetTime()
    if ns.RequestPlayed then ns.RequestPlayed() end
    if ns.char and ns.char.levelTimes then
        ns.char.levelTimes[session.lastLevel] = GetTime()
    end
    ns.MarkDirty()
end)

ns.On("CHAT_MSG_COMBAT_XP_GAIN", function(_, msg)
    if not msg then return end
    local name, amt = parseKill(msg)
    if amt then session.killXP = amt end
    if name then session.killName = name end
    -- gain text: prefer the parsed kill, fall back to plain XP
    local d = ns.xp()
    local text
    if name then
        text = "+" .. ns.Comma(amt or 0) .. " XP " .. name
    else
        text = "+" .. ns.Comma(amt or 0) .. " XP"
    end
    if ns.ShowGain then ns.ShowGain(text) end
    -- a counted kill: the gain message names the mob and the amount
    if name and amt then ns.CountKill() end
    ns.MarkDirty()
end)

ns.On("TIME_PLAYED_MSG", function(_, total, level)
    if total then
        session.playedTotal = total
    end
    if level then
        session.playedLevel = level
    end
    session.playedAt = GetTime()
    ns.MarkDirty()
end)

-- Ask the client for /played data (total + this level).  The response is
-- delivered as TIME_PLAYED_MSG.  The request would print the stock chat
-- lines, so mark a short window in which they are hidden.
local function requestPlayed()
    if not ns.API.RequestTimePlayed then return end
    ns._suppressPlayed = GetTime() + 3
    pcall(ns.API.RequestTimePlayed)
end
ns.RequestPlayed = requestPlayed

-- Suppress only played-time output. Replacing AddMessage taints Blizzard's
-- caller, including the protected battleground join/leave message queues.
local function suppressPlayedChat()
    if ns._timePlayedHooked then return end
    local function wrap(orig)
        return function(...)
            if ns._suppressPlayed and GetTime() <= ns._suppressPlayed then return end
            return orig(...)
        end
    end
    local hooked = false
    if _G.ChatFrameUtil and type(ChatFrameUtil.DisplayTimePlayed) == "function" then
        ChatFrameUtil.DisplayTimePlayed = wrap(ChatFrameUtil.DisplayTimePlayed)
        hooked = true
    end
    if type(_G.ChatFrame_DisplayTimePlayed) == "function" then
        ChatFrame_DisplayTimePlayed = wrap(ChatFrame_DisplayTimePlayed)
        hooked = true
    end
    ns._timePlayedHooked = hooked
end

-- Refresh "played" on every login, reload and zone, then keep it fresh every
-- five minutes.  PLAYER_ENTERING_WORLD fires repeatedly (zones, instances),
-- so the previous loop is cancelled first instead of stacking timers.
ns.On("PLAYER_ENTERING_WORLD", function()
    suppressPlayedChat()
    requestPlayed()
    if ns._playedRefresh then
        ns.CancelTimer(ns._playedRefresh)
        ns._playedRefresh = nil
    end
    local function re()
        ns._playedRefresh = nil
        requestPlayed()
        ns._playedRefresh = ns.After(300, re)
    end
    ns._playedRefresh = ns.After(300, re)
end)

-- Sample the sparkline every 30s and persist the session alongside it.
ns.On("PLAYER_LOGIN", function()
    local function sample()
        session:AddSample(session.gain)
        session:Save()
        ns.After(30, sample)
    end
    ns.After(30, sample)
end)

ns.On("PLAYER_LOGOUT", function()
    session:Save()
end)
