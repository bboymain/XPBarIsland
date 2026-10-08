local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Reputation: current watched faction plus a session list of factions gained.
-- ---------------------------------------------------------------------------
local repSession = {}   -- [faction] = { gained = n, standing = label }
ns.repSession = repSession

-- timestamp of the last reputation change, for the panel's "Updated" cell
ns.repLast = ns.repLast or GetTime()

function ns.InvalidateRep()
    ns.MarkDirty()
end

local function standingLabel(id)
    if not id then return nil end
    return _G["FACTION_STANDING_LABEL" .. id] or _G["FACTION_STANDING_LABEL" .. id .. "_MALE"]
end

-- Ordered standing tiers (1 = Hated ... 8 = Exalted) for the panel ladder.
ns.repStandingName = standingLabel
ns.repTierCount = 8

-- Normalise a modern C_Reputation FactionData into name, standingID,
-- bandMin, bandMax, bandValue (bandValue relative to bandMin).
local function modernTuple(data)
    if type(data) ~= "table" or not data.name then return nil end
    local mn = tonumber(data.currentReactionThreshold) or 0
    local mx = tonumber(data.nextReactionThreshold) or (mn + 1)
    if mx <= mn then mx = mn + 1 end
    local span = mx - mn
    local v = tonumber(data.currentStanding)
    if v == nil then v = tonumber(data.currentRep) end
    if v == nil then v = 0 end
    -- some builds report the value relative to the standing band already
    if (v - mn) < 0 or (v - mn) > span then mn, mx, v = 0, span, v end
    return data.name, data.reaction, mn, mx, v
end

-- When nothing is watched, show one faction so the reputation view is never
-- blank. The choice is remembered for the session and re-read live; as soon as
-- the player watches a faction, that one takes over.
local fbID
function ns.repFallbackFaction()
    local CRep = _G.C_Reputation

    -- re-read the faction we already picked (modern), if it still exists
    if fbID and CRep and CRep.GetFactionDataByID then
        local ok, data = pcall(CRep.GetFactionDataByID, fbID)
        if ok then
            local n, sid, mn, mx, v = modernTuple(data)
            if n then return n, sid, mn, mx, v end
        end
        fbID = nil
    end
    if CRep and CRep.GetNumFactions and CRep.GetFactionDataByIndex then
        local ok, count = pcall(CRep.GetNumFactions)
        if ok and count then
            for i = 1, count do
                local dok, data = pcall(CRep.GetFactionDataByIndex, i)
                if dok and type(data) == "table" and data.name and not data.isHeader then
                    fbID = data.factionID
                    local n, sid, mn, mx, v = modernTuple(data)
                    if n then return n, sid, mn, mx, v end
                end
            end
        end
    end

    -- legacy list fallback
    if ns.API.GetNumFactions and ns.API.GetFactionInfo then
        local ok, count = pcall(ns.API.GetNumFactions)
        if ok and count then
            for i = 1, count do
                local fok, n, _, sid, mn, mx, v, _, _, isHeader = pcall(ns.API.GetFactionInfo, i)
                if fok and n and not isHeader then
                    return n, sid, mn, mx, v
                end
            end
        end
    end
    return nil
end

function ns.rep()
    local name, standingID, min, max, value
    local fallback = false

    -- modern clients (C_Reputation): currentStanding is the absolute
    -- reputation and the two thresholds bound the current standing band.
    local getWatchedData = ns.API.GetWatchedFactionData
        or (_G.C_Reputation and _G.C_Reputation.GetWatchedFactionData)
    if getWatchedData then
        local ok, data = pcall(getWatchedData)
        if ok then name, standingID, min, max, value = modernTuple(data) end
    end

    -- classic/legacy global
    if not name and ns.API.GetWatchedFactionInfo then
        local ok, n, sid, mn, mx, v = pcall(ns.API.GetWatchedFactionInfo)
        if ok and n then name, standingID, min, max, value = n, sid, mn, mx, v end
    end

    -- nothing watched: fall back to one faction so the view is never blank
    if not name then
        name, standingID, min, max, value = ns.repFallbackFaction()
        fallback = (name ~= nil)
    end

    if not name then
        return { available = false }
    end
    min = min or 0
    max = max or 1
    value = value or 0
    if max <= min then max = min + 1 end
    local pct = (value - min) / (max - min)
    local label = standingLabel(standingID) or ""
    local badge = label ~= "" and label:sub(1, 2) or "?"

    -- "Next" tier name (Max once Exalted) and how much is left in this tier.
    local nextStanding
    if standingID then
        if standingID >= ns.repTierCount then nextStanding = "Max"
        else nextStanding = standingLabel(standingID + 1) or "?" end
    end

    return {
        available = true,
        name = name,
        standingID = standingID,
        standing = label,
        min = min, max = max, value = value,
        pct = ns.clamp(pct, 0, 1),
        badge = badge,
        tierValue = value - min,
        tierSpan  = max - min,
        toNext    = math.max(0, max - value),
        nextStanding = nextStanding,
        exalted   = (standingID == ns.repTierCount),
        fallback  = fallback,
    }
end

-- Parse "Your reputation with X has increased by N."
local function buildPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%s", "(.+)")
    p = p:gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

local patterns = {}
local function init()
    local up = buildPattern(_G.FACTION_STANDING_INCREASED)
    if up then
        patterns[#patterns + 1] = { p = up, sign = 1 }
    end
    local down = buildPattern(_G.FACTION_STANDING_DECREASED)
    if down then
        patterns[#patterns + 1] = { p = down, sign = -1 }
    end
end
init()

ns.On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(_, msg)
    if not msg then return end
    for _, entry in ipairs(patterns) do
        local faction, amount = msg:match(entry.p)
        if faction then
            local amt = tonumber((amount or ""):gsub("[^%d]", ""))
            if amt then
                amt = amt * entry.sign
                local rec = repSession[faction] or { gained = 0, standing = "" }
                rec.gained = rec.gained + amt
                repSession[faction] = rec
                if ns.ShowGain and amt > 0 then
                    ns.ShowGain("+" .. ns.Comma(amt) .. " " .. faction)
                end
                if ns.AutoSwitch then ns.AutoSwitch("rep", 3) end
            end
            break
        end
    end
    ns.repLast = GetTime()
    ns.TouchData()
    ns.MarkDirty()
end)

local function repChanged()
    ns.repLast = GetTime()
    ns.TouchData()
    ns.MarkDirty()
end
ns.On("UPDATE_FACTION", repChanged)
ns.On("REPUTATION_UPDATE", repChanged)
ns.On("FACTION_STANDING_CHANGED", repChanged)

function ns.repList()
    local out = {}
    for name, rec in pairs(repSession) do
        out[#out + 1] = { name = name, gained = rec.gained, standing = rec.standing }
    end
    table.sort(out, function(a, b) return a.gained > b.gained end)
    return out
end
