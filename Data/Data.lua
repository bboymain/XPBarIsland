local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Assembles the displayed type from the individual data modules, and handles
-- auto-switching (reputation gain, battleground, skill up) with a hold time.
-- ---------------------------------------------------------------------------
local data = {}
ns.data = data

local ORDER = { "xp", "rep", "honor", "pet", "skills" }
local LABEL = {
    xp = "Experience", rep = "Reputation", honor = "Honor",
    pet = "Pet Exp", skills = "Skills",
}

data.lastUserPick = 0
data.auto = { type = nil, until_ = 0 }

local function atMaxLevel()
    local maxL = (ns.API.GetMaxPlayerLevel and ns.API.GetMaxPlayerLevel()) or _G.MAX_PLAYER_LEVEL or 0
    return maxL > 0 and (UnitLevel("player") or 0) >= maxL
end

function ns.AutoSwitch(key, secs)
    if not (ns.db and ns.db.autoSwitch) then return end
    if GetTime() - data.lastUserPick < 10 then return end
    data.auto.type = key
    data.auto.until_ = GetTime() + (secs or 3)
    ns.MarkDirty()
end

function data:SetActive(key)
    ns.db.activeType = key
    data.lastUserPick = GetTime()
    data.auto.type = nil
    ns.MarkDirty()
end

function data:Enabled(key)
    if key == "rep" then return ns.rep().available end
    if key == "honor" then return ns.honorAvailable() end
    if key == "pet" then return ns.petClass() end
    if key == "skills" then
        local s = ns.skill()
        return s.available
    end
    return true
end

-- Enforce the type rules: at least one enabled type, and a valid current type.
-- A type stays selectable even when it has no data right now (no watched
-- faction, no pet) so the chip is always there and shows an empty state.
function data:Sanitize()
    local types = ns.db and ns.db.types
    if type(types) ~= "table" then return end
    local enabledCount, firstEnabled = 0, nil
    for _, key in ipairs(ORDER) do
        if types[key] then
            enabledCount = enabledCount + 1
            if not firstEnabled then firstEnabled = key end
        end
    end
    if enabledCount == 0 then
        -- fall back to Experience
        types.xp = true
        firstEnabled = "xp"
    end
    local cur = ns.db.activeType
    if not (cur and types[cur]) then
        ns.db.activeType = firstEnabled
    end
end

function data:List()
    self:Sanitize()
    -- at max level with "Reputation bar at max level" on, only the rep bar shows
    if ns.db.repAtMax and atMaxLevel() then
        local r = ns.rep()
        if r.available then return { "rep" } end
    end
    local v1 = ns.db.v1
    local out = {}
    for _, key in ipairs(ORDER) do
        local hidden = v1 and (key == "honor" or key == "skills")
        -- the pet bar is pointless for a class with no pet
        local noPet = (key == "pet") and not ns.petClass()
        -- the reputation chip always shows (even with no watched faction) so
        -- the view is reachable; it fills in once "Show as Experience Bar" is on
        if not hidden and not noPet and ns.db.types[key] then
            out[#out + 1] = key
        end
    end
    if #out == 0 then out[1] = "xp" end
    return out
end

local function pvpInstance()
    if not ns.API.IsInInstance then return false end
    local ok, _, kind = pcall(ns.API.IsInInstance)
    return ok and kind == "pvp"
end

function data:ActiveKey()
    local list = self:List()
    local key = ns.db.activeType

    -- "Reputation bar at max level": show the watched faction once XP is capped
    if ns.db.repAtMax and atMaxLevel() then
        local r = ns.rep()
        if r.available then return "rep" end
    end

    -- battleground overrides while inside
    if ns.db.autoSwitch and not ns.db.v1 and pvpInstance() and ns.db.types.honor and ns.honorAvailable()
        and GetTime() - data.lastUserPick >= 10 then
        return "honor"
    end

    if data.auto.type and GetTime() < data.auto.until_ then
        for _, k in ipairs(list) do
            if k == data.auto.type then return k end
        end
    end

    for _, k in ipairs(list) do
        if k == key then return k end
    end
    return list[1]
end

-- ---------------------------------------------------------------------------
-- Per-type builders
-- ---------------------------------------------------------------------------
local function buildXP()
    local x = ns.xp()
    local q = ns.quests()
    local cur, max = x.cur, x.max
    local v1 = ns.db.v1
    local remaining = math.max(0, max - cur)
    local restedPct = math.min(x.rested or 0, remaining) / max
    local ghostPct = v1 and 0 or math.min(q.total or 0, remaining) / max
    local compact = ns.db.compact

    local rate = x.rate
    local rateText = rate and (ns.Short(ns.round(rate), compact) .. "/hr") or "--"
    local rateValue = rate

    -- killXP is the recent average without rested bonus.  Rested doubles each
    -- kill until the pool runs out, so it covers up to half of what's left.
    local kills
    if x.killXP and x.killXP > 0 then
        local restedBonus = math.min(x.rested or 0, remaining / 2)
        kills = math.ceil((remaining - restedBonus) / x.killXP)
    end
    local eta = kills and ("~" .. kills .. " kills") or "--"

    local timeToLevel
    if rate and rate > 0 then
        timeToLevel = ns.Time(remaining / (rate / 3600))
    end

    local rested = "--"
    if x.rested and x.rested > 0 then
        if v1 then
            rested = ns.Short(x.rested, compact)
        else
            local at = x.resting and 0.05 or 0.025
            local perHour = max * at / 8
            local cap = max * 1.5
            if x.rested >= cap then
                rested = ns.Short(x.rested, compact) .. " \194\183 Full"
            else
                local hours = (cap - x.rested) / perHour
                rested = ns.Short(x.rested, compact) .. " \194\183 " .. ns.Time(hours * 3600)
            end
        end
    end

    local turnIn = { k = "Turn-in", v = ns.Comma(q.total or 0), c = ns.Colors.quest }
    if v1 then turnIn = { k = "Quests in Log", v = tostring(q.inLog or 0) } end

    local played = "--"
    if ns.session.playedTotal and ns.session.playedAt then
        played = ns.Time(ns.session.playedTotal + (GetTime() - ns.session.playedAt))
    end

    -- "This level" comes from the server (TIME_PLAYED_MSG) so it survives
    -- /reload; advance it locally between server updates.
    local levelPlayed = "--"
    local levelSecs = ns.session:LevelElapsed()
    if levelSecs then levelPlayed = ns.Time(levelSecs) end

    local stats = {
        { k = "Current / Max", v = ns.Short(cur, compact) .. " / " .. ns.Short(max, compact) },
        { k = "Rested", v = rested, c = ns.Colors.restTag },
        turnIn,
        { k = "XP/hr", v = rateText, c = { 1, 0.82, 0 } },
        { k = "Session", v = ns.Time(x.elapsed) },
        { k = "This level", v = levelPlayed },
        { k = "Played", v = played },
        { k = "Kills to level", v = kills and ("~" .. kills) or "--" },
    }

    -- the milestone/spell preview is a nice-to-have: never let it break the
    -- core XP stat grid if a client API is missing or misbehaves
    local md = { text = "", spells = {} }
    if ns.MilestoneData then
        local mok, mres = pcall(ns.MilestoneData, x.level)
        if mok and type(mres) == "table" then md = mres end
    end
    return {
        key = "xp", label = LABEL.xp, name = UnitName("player") or "Experience",
        badge = tostring(x.level), level = x.level,
        cur = cur, max = max, pct = x.pct,
        fill = ns.Colors.xp, restedPct = restedPct, ghostPct = ghostPct,
        resting = x.resting,
        rate = rateText, rateValue = rateValue, eta = eta, timeToLevel = timeToLevel,
        killXP = x.killXP,
        questTotal = v1 and 0 or (q.total or 0), questList = q.list, questCount = q.count,
        stats = stats, milestone = md.text, milestoneLevel = md.level,
        nextSpellLevel = md.level, nextReward = md.reward, spells = md.spells,
        quest = true,
        shortLine = string.format("%d%% to level %d", ns.round(x.pct * 100), x.level),
    }
end

local function buildRep()
    local r = ns.rep()
    if not r.available then
        return {
            key = "rep", label = LABEL.rep, name = "Reputation", available = false,
            note = "No watched faction", fill = ns.Colors.rep,
            stats = {
                { k = "Status", v = "No watched faction" },
                { k = "Tip", v = "Reputation > Show as Experience Bar" },
                { k = "Current", v = "0" },
                { k = "Needed", v = "0" },
                { k = "Remaining", v = "0" },
                { k = "Session", v = "0" },
                { k = "Updated", v = ns.Ago(ns.repLast) },
                { k = "Window", v = "Reputation" },
            },
            shortLine = "No watched faction",
        }
    end
    local compact = ns.db.compact
    local cur = r.value - r.min
    local needed = r.max - r.min
    local remaining = math.max(0, needed - cur)
    local session = 0
    local rec = ns.repSession[r.name]
    if rec then session = rec.gained end

    local nextStanding = r.nextStanding or "--"
    local progressLine = ns.round(r.pct * 100) .. "% to " .. nextStanding
    local hint = r.fallback and "Auto-picked - watch a faction to change" or nil
    local stats = {
        { k = "Standing", v = r.standing, c = ns.Colors.rep[1] },
        { k = "Next", v = nextStanding },
        { k = "To next", v = r.exalted and "--" or ns.Short(r.toNext or 0, compact) },
        { k = "Progress", v = ns.round(r.pct * 100) .. "%" },
        { k = "Current", v = ns.Short(cur, compact) },
        { k = "Needed", v = ns.Short(needed, compact) },
        { k = "This session", v = (session ~= 0) and ("+" .. ns.Comma(session)) or "0" },
        { k = "Updated", v = ns.Ago(ns.repLast) },
    }
    return {
        key = "rep", label = LABEL.rep, name = r.name,
        badge = r.badge, standing = r.standing, nextStanding = nextStanding,
        standingID = r.standingID, tierPct = r.pct, exalted = r.exalted,
        fallback = r.fallback,
        cur = cur, max = needed, needed = needed, remaining = remaining,
        pct = r.pct, fill = ns.Colors.rep,
        rate = (session ~= 0) and ("+" .. ns.Comma(session)) or "--",
        stats = stats, milestone = hint or progressLine,
        shortLine = hint or progressLine,
    }
end

local function buildHonor()
    local h = ns.honor()
    if not h.available then
        return {
            key = "honor", label = LABEL.honor, name = "Honor", available = false,
            note = "Honor unavailable", fill = ns.Colors.honor,
            stats = {
                { k = "Status", v = "Honor unavailable" },
                { k = "Current", v = "0" },
                { k = "Needed", v = "0" },
                { k = "Remaining", v = "0" },
                { k = "Session", v = "0" },
                { k = "Rank", v = "--" },
                { k = "Updated", v = ns.Ago(ns.honorLast) },
                { k = "Window", v = "PvP" },
            },
            shortLine = "Honor unavailable",
        }
    end
    local compact = ns.db.compact
    local remaining = math.max(0, h.max - h.cur)
    local stats = {
        { k = "Current", v = ns.Short(h.cur, compact) },
        { k = "Needed", v = ns.Short(h.max, compact) },
        { k = "Remaining", v = ns.Short(remaining, compact) },
        { k = "Session", v = "+" .. ns.Comma(ns.honorSession.gained()) },
        { k = "Rank", v = tostring(h.rank) },
        { k = "Window", v = "PvP" },
        { k = "Updated", v = ns.Ago(ns.honorLast) },
        { k = "Next", v = "Rank " .. tostring((tonumber(h.rank) or 0) + 1) },
    }
    return {
        key = "honor", label = LABEL.honor, name = "Honor Rank " .. tostring(h.rank),
        badge = h.badge, cur = h.cur, max = h.max, pct = h.pct, fill = ns.Colors.honor,
        rate = "+" .. ns.Comma(ns.honorSession.gained()), eta = "this session",
        stats = stats, milestone = "Next reward at rank up",
        shortLine = "Rank " .. tostring(h.rank),
    }
end

local function buildPet()
    local p = ns.pet()
    if not p.available then
        return {
            key = "pet", label = LABEL.pet, name = "Pet Experience", available = false,
            note = p.note or "No pet", fill = ns.Colors.pet,
            stats = {
                { k = "Status", v = p.note or "No pet" },
                { k = "Tip", v = "Tame or summon a pet" },
                { k = "Level", v = "--" },
                { k = "Health", v = "--" },
                { k = "Happiness", v = "--" },
                { k = "Session", v = "0" },
                { k = "Updated", v = ns.Ago(ns.lastUpdate) },
                { k = "Window", v = "Pet" },
            },
            shortLine = p.note or "No pet",
        }
    end
    local hasXP = p.hasXP
    local session = ns.petSession.gained()
    local toFull = math.max(0, (p.healthMax or 0) - (p.health or 0))
    local stats = {
        { k = hasXP and "Current" or "Health", v = ns.Comma(p.cur) },
        { k = hasXP and "Needed" or "Health max", v = ns.Comma(p.max) },
        { k = "Remaining", v = hasXP and ns.Comma(math.max(0, p.max - p.cur)) or ns.Comma(toFull) },
        { k = "Pet level", v = tostring(p.level) },
        { k = "Health", v = ns.Comma(p.health or 0) .. " / " .. ns.Comma(p.healthMax or 0) },
        { k = "Happiness", v = p.happiness or "--" },
        { k = "Session", v = "+" .. ns.Comma(session) },
        { k = "Updated", v = ns.Ago(ns.lastUpdate) },
    }
    return {
        key = "pet", label = LABEL.pet,
        name = hasXP and "Pet Experience" or ((p.name or "Pet") .. " - Health"),
        badge = p.badge, cur = p.cur, max = p.max, pct = p.pct, fill = ns.Colors.pet,
        stats = stats, milestone = hasXP and "Next pet level" or "Keep your pet healthy",
        shortLine = hasXP and (ns.round(p.pct * 100) .. "%")
            or (ns.Comma(p.health or 0) .. " / " .. ns.Comma(p.healthMax or 0)),
    }
end

local function buildSkills()
    local s = ns.skill()
    if not s.available then
        return {
            key = "skills", label = LABEL.skills, name = "Skills", available = false,
            note = "No skills yet", fill = ns.Colors.skills,
            stats = {
                { k = "Status", v = "No skill lines" },
                { k = "Tip", v = "Train a profession" },
            },
            shortLine = "No skills yet",
        }
    end
    local remaining = math.max(0, s.max - s.rank)
    local stats = {}
    local list = s.list or {}
    for i = 1, math.min(8, #list) do
        stats[#stats + 1] = { k = list[i].name, v = list[i].rank .. " / " .. list[i].max }
    end
    return {
        key = "skills", label = LABEL.skills, name = s.name,
        badge = s.badge, cur = s.rank, max = s.max, pct = s.pct, fill = ns.Colors.skills,
        rate = s.rank .. " / " .. s.max, eta = remaining .. " to go",
        stats = stats, milestone = "Keep training",
        shortLine = s.name .. " " .. s.rank .. "/" .. s.max,
    }
end

local builders = { xp = buildXP, rep = buildRep, honor = buildHonor, pet = buildPet, skills = buildSkills }

function data:Build(key)
    local b = builders[key]
    if not b then return nil end
    local ok, res = pcall(b)
    if not ok then
        ns.ReportError("build:" .. tostring(key), res)
        -- never render an empty panel: show the failure in the stat grid
        return {
            key = key, label = LABEL[key] or key, name = LABEL[key] or key, available = false,
            fill = ns.Colors[key] or ns.Colors.gray,
            stats = {
                { k = "Status", v = "Data error" },
                { k = "Detail", v = tostring(res) },
            },
            shortLine = "Data error",
            milestone = tostring(res),
        }
    end
    return res
end

function data:Current()
    return self:Build(self:ActiveKey())
end

-- /xpbar testxp: fake a gain on the displayed XP bar without touching real XP.
function ns.TestXPGain(amount)
    amount = amount or 1200
    local d = data:Build("xp")
    local max = d.max or 1
    local cur = math.min((d.cur or 0) + amount, max)
    ns.barFake = { expires = GetTime() + 3.5, cur = cur, max = max, pct = ns.clamp(cur / max, 0, 1) }
    ns.MarkDirty()
end
