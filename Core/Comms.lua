local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Original party sync protocol.
--   Prefix: XPBI1
--   Message: v1:level:xp:xpMax:rested:classToken   (6 colon separated fields)
-- One message per 5s on xp change, immediately on level up, on roster change
-- after 2s, plus a 15s heartbeat while grouped.  Nothing else leaves the
-- client.  Messages older than 30s (or members who left) are dropped.
-- ---------------------------------------------------------------------------
local PREFIX = "XPBI1"
local TTL = 30

local comms = { members = {} }
ns.comms = comms

if ns.API.RegisterAddonMessagePrefix then
    ns.API.RegisterAddonMessagePrefix(PREFIX)
end

local lastSend = 0
local lastXPSend = 0
local pending

local function channel()
    if ns.API.InRaid and ns.API.InRaid() then return "RAID" end
    if ns.API.IsInInstance then
        local ok, _, kind = pcall(ns.API.IsInInstance)
        if ok and kind == "pvp" then return "INSTANCE_CHAT" end
    end
    return "PARTY"
end

function comms:Enabled()
    return ns.db and ns.db.party and ns.API.SendAddonMessage ~= nil
end

local function build()
    local level = UnitLevel("player") or 0
    local xp = UnitXP("player") or 0
    local xpMax = UnitXPMax("player") or 1
    local rested = (ns.API.GetXPExhaustion and ns.API.GetXPExhaustion()) or 0
    local _, class = UnitClass("player")
    return string.format("v1:%d:%d:%d:%d:%s", level, xp, xpMax, rested, class or "NONE")
end

function comms:Send(force)
    if not self:Enabled() then return end
    if not ns.API.InGroup or not ns.API.InGroup() then return end
    if ns.inCombat then return end
    local now = GetTime()
    if not force and now - lastSend < 1 then return end
    lastSend = now
    lastXPSend = now
    ns.API.SendAddonMessage(PREFIX, build(), channel())
end

function comms:ScheduleSend(delay)
    if pending then ns.CancelTimer(pending) end
    pending = ns.After(delay or 0, function()
        pending = nil
        self:Send(true)
    end)
end

local function parse(msg)
    if type(msg) ~= "string" then return nil end
    local f = { strsplit(":", msg) }
    if #f ~= 6 or f[1] ~= "v1" then return nil end
    local level = tonumber(f[2])
    local xp = tonumber(f[3])
    local xpMax = tonumber(f[4])
    local rested = tonumber(f[5])
    local class = f[6]
    if not level or not xp or not xpMax or xpMax <= 0 then return nil end
    return { level = level, xp = xp, xpMax = xpMax, rested = rested or 0, class = class }
end

function comms:Receive(prefix, msg, sender)
    if prefix ~= PREFIX then return end
    if not self:Enabled() then return end
    if not sender or sender == "" then return end
    local me = UnitName("player")
    if sender == me then return end
    local data = parse(msg)
    if not data then return end
    data.lastSeen = GetTime()
    self.members[sender] = data
    ns.MarkDirty()
end

local function inGroup(name)
    if not ns.API.InGroup or not ns.API.InGroup() then return false end
    if not name then return false end
    if UnitName("player") == name then return true end
    local units = {}
    for i = 1, 40 do units[#units + 1] = "party" .. i end
    for i = 1, 40 do units[#units + 1] = "raid" .. i end
    for i = 1, #units do
        if UnitName(units[i]) == name then return true end
    end
    return false
end

function comms:Prune()
    local now = GetTime()
    for name, m in pairs(self.members) do
        if not m.fake and (now - (m.lastSeen or 0) > TTL or not inGroup(name)) then
            self.members[name] = nil
        end
    end
end

function comms:List()
    self:Prune()
    local out = {}
    for name, m in pairs(self.members) do
        out[#out + 1] = {
            name = name, level = m.level, xp = m.xp, xpMax = m.xpMax,
            rested = m.rested, class = m.class,
        }
    end
    return out
end

-- Test helper: /xpbar fakeparty
function comms:FillFake()
    local lvl = UnitLevel("player") or 1
    local fake = {
        { name = "Jaina",  level = lvl + 1, xp = 3000, xpMax = 10000, class = "MAGE" },
        { name = "Rexxar", level = lvl,     xp = 6000, xpMax = 10000, class = "HUNTER" },
        { name = "Sylvanas", level = lvl,   xp = 6600, xpMax = 10000, class = "ROGUE" },
        { name = "Thrall", level = math.max(1, lvl - 1), xp = 4500, xpMax = 10000, class = "SHAMAN" },
    }
    for _, f in ipairs(fake) do
        f.lastSeen = GetTime()
        f.fake = true
        self.members[f.name] = f
    end
    ns.MarkDirty()
end

ns.On("CHAT_MSG_ADDON", function(_, prefix, msg, chan, sender)
    ns.comms:Receive(prefix, msg, sender)
end)

ns.On("PLAYER_XP_UPDATE", function()
    local now = GetTime()
    if now - lastXPSend >= 5 then ns.comms:Send(true) end
end)

ns.On("PLAYER_LEVEL_UP", function()
    ns.comms:Send(true)
end)

local function roster()
    ns.comms:ScheduleSend(2)
end
ns.On("GROUP_ROSTER_UPDATE", roster)
ns.On("PARTY_MEMBERS_CHANGED", roster)
ns.On("RAID_ROSTER_UPDATE", roster)
ns.On("PLAYER_ENTERING_WORLD", function() ns.comms:ScheduleSend(3) end)

-- Recurring heartbeat built on the tween driver timer helper.
local function heartbeat()
    if ns.comms.Enabled and ns.comms:Enabled() and ns.API.InGroup and ns.API.InGroup() then
        ns.comms:Send(true)
    end
    ns.After(15, heartbeat)
end
ns.After(15, heartbeat)
