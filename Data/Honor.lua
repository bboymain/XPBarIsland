local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Honor.  Modern clients expose UnitHonor / UnitHonorMax; Classic-era clients
-- only expose the old rank API.  When neither is available the type is hidden.
-- ---------------------------------------------------------------------------
local honorSession = 0
ns.honorSession = { gained = function() return honorSession end }

-- timestamp of the last honor change, for the panel's "Updated" cell
ns.honorLast = ns.honorLast or GetTime()

function ns.honorAvailable()
    return ns.API.UnitHonor ~= nil or ns.API.UnitPVPRank ~= nil
end

function ns.honor()
    local available = ns.honorAvailable()
    if not available then return { available = false } end

    local cur, max, rank

    if ns.API.UnitHonor and ns.API.UnitHonorMax then
        local ok1, c = pcall(ns.API.UnitHonor, "player")
        local ok2, m = pcall(ns.API.UnitHonorMax, "player")
        if ok1 then cur = c end
        if ok2 then max = m end
    end

    -- older clients without UnitHonor: fall back to this week's honor total
    if (not cur or cur == 0) and ns.API.GetPVPThisWeekStats then
        local ok, _, honor = pcall(ns.API.GetPVPThisWeekStats)
        if ok and honor and honor > 0 then cur = honor end
    end

    if ns.API.UnitHonorLevel then
        local ok, r = pcall(ns.API.UnitHonorLevel, "player")
        if ok then rank = r end
    elseif ns.API.GetHonorLevel then
        local ok, r = pcall(ns.API.GetHonorLevel)
        if ok then rank = r end
    end

    if not rank and ns.API.UnitPVPRank and ns.API.GetPVPRankInfo then
        local ok, pvpRank = pcall(ns.API.UnitPVPRank, "player")
        if ok and pvpRank then
            local ok2, name = pcall(ns.API.GetPVPRankInfo, pvpRank)
            if ok2 and name then rank = name end
            rank = rank or pvpRank
        end
    end

    rank = rank or 0
    cur = cur or 0
    max = max or 0
    local pct = (max > 0) and (cur / max) or 0

    return {
        available = true,
        cur = cur,
        max = max,
        rank = rank,
        pct = ns.clamp(pct, 0, 1),
        badge = tostring(rank),
    }
end

-- Parse "You have been awarded N honor" style messages for the session total.
local function buildPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

local honorPatterns = {}
local function init()
    local names = { "HONOR_GAINED", "COMBATLOG_HONORGAIN", "FACTION_STANDING_INCREASED" }
    for _, n in ipairs(names) do
        local p = buildPattern(_G[n] and (_G[n] .. "") or nil)
        -- only keep simple single-number honour patterns
        if _G[n] and _G[n]:find("%%d") and not _G[n]:find("%%s") then
            honorPatterns[#honorPatterns + 1] = p
        end
    end
end
init()

ns.On("CHAT_MSG_COMBAT_HONOR_GAIN", function(_, msg)
    if not msg then return end
    local amt = msg:match("(%d[%d,]*)")
    if amt then
        amt = tonumber((amt:gsub("[^%d]", ""))) or 0
        if amt > 0 then
            honorSession = honorSession + amt
            if ns.ShowGain then ns.ShowGain("+" .. ns.Comma(amt) .. " Honor") end
        end
    end
    ns.honorLast = GetTime()
    ns.TouchData()
    ns.MarkDirty()
end)

local function honorChanged()
    ns.honorLast = GetTime()
    ns.TouchData()
    ns.MarkDirty()
end
ns.On("HONOR_XP_UPDATE", honorChanged)
ns.On("PLAYER_PVP_KILLS_CHANGED", honorChanged)
ns.On("HONOR_LEVEL_UPDATE", honorChanged)
