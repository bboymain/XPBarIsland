local ADDON, ns = ...

-- Central place for every API that may or may not exist in this client.
-- Each accessor returns nil when the client does not provide the function so
-- the feature can be hidden cleanly instead of throwing a Lua error.
local API = {}
ns.API = API

local function fn(name)
    local f = _G[name]
    if type(f) == "function" then return f end
    return nil
end

API.GetXPExhaustion      = fn("GetXPExhaustion")
API.GetWatchedFactionInfo = fn("GetWatchedFactionInfo")
-- modern clients replaced GetWatchedFactionInfo with a C_Reputation query
API.GetWatchedFactionData = (_G.C_Reputation and type(_G.C_Reputation.GetWatchedFactionData) == "function")
    and _G.C_Reputation.GetWatchedFactionData or nil
-- legacy reputation list (used only for the blank-fallback faction)
API.GetNumFactions        = fn("GetNumFactions")
API.GetFactionInfo        = fn("GetFactionInfo")
API.GetPetExperience     = fn("GetPetExperience")
API.RequestTimePlayed    = fn("RequestTimePlayed")
API.GetQuestLogRewardXP  = fn("GetQuestLogRewardXP")
API.GetRewardXP          = fn("GetRewardXP")
API.SelectQuestLogEntry  = fn("SelectQuestLogEntry")
API.GetQuestLogSelection = fn("GetQuestLogSelection")
API.GetNumQuestLogEntries = fn("GetNumQuestLogEntries")
API.GetQuestLogTitle     = fn("GetQuestLogTitle")
API.GetNumSkillLines     = fn("GetNumSkillLines")
API.GetSkillLineInfo     = fn("GetSkillLineInfo")
-- modern-engine clients replaced the skill-line pair with the professions API
API.GetProfessions       = fn("GetProfessions")
API.GetProfessionInfo    = fn("GetProfessionInfo")
-- newest clients (12.0 engine) expose skill lines and professions through
-- C_SkillInfo and C_TradeSkillUI instead
local skillInfo = _G.C_SkillInfo
API.CSkillInfoGetNumSkillLines = (skillInfo and type(skillInfo.GetNumSkillLines) == "function")
    and skillInfo.GetNumSkillLines or nil
API.CSkillInfoGetSkillLineInfo = (skillInfo and type(skillInfo.GetSkillLineInfo) == "function")
    and skillInfo.GetSkillLineInfo or nil
local tradeSkill = _G.C_TradeSkillUI
API.GetAllProfessionTradeSkillLines = (tradeSkill and type(tradeSkill.GetAllProfessionTradeSkillLines) == "function")
    and tradeSkill.GetAllProfessionTradeSkillLines or nil
API.GetProfessionInfoBySkillLineID = (tradeSkill and type(tradeSkill.GetProfessionInfoBySkillLineID) == "function")
    and tradeSkill.GetProfessionInfoBySkillLineID or nil
API.GetPVPRankInfo       = fn("GetPVPRankInfo")
API.UnitPVPRank          = fn("UnitPVPRank")
API.GetPVPThisWeekStats  = fn("GetPVPThisWeekStats")
API.GetMaxPlayerLevel    = fn("GetMaxPlayerLevel")
API.InCombatLockdown     = fn("InCombatLockdown")
API.IsResting            = fn("IsResting")
API.UnitXP               = fn("UnitXP")
API.UnitXPMax            = fn("UnitXPMax")
API.UnitLevel            = fn("UnitLevel")
API.UnitExists           = fn("UnitExists")
API.UnitHonor            = fn("UnitHonor")
API.UnitHonorMax         = fn("UnitHonorMax")
API.UnitHonorLevel       = fn("UnitHonorLevel")
API.GetHonorLevel        = fn("GetHonorLevel")
API.IsInGroup            = fn("IsInGroup")
API.IsInRaid             = fn("IsInRaid")
API.UnitClass            = fn("UnitClass")
API.UnitName             = fn("UnitName")
API.IsInInstance         = fn("IsInInstance")
API.GetNumPartyMembers   = fn("GetNumPartyMembers")
API.GetNumRaidMembers    = fn("GetNumRaidMembers")
API.GetNumGroupMembers   = fn("GetNumGroupMembers")

-- Group size, newest API first, then the classic split between party/raid.
function API.GroupSize()
    if API.GetNumGroupMembers then
        local n = API.GetNumGroupMembers()
        if n and n > 0 then return n end
    end
    local raid = API.GetNumRaidMembers and API.GetNumRaidMembers() or 0
    if raid and raid > 0 then return raid end
    local party = API.GetNumPartyMembers and API.GetNumPartyMembers() or 0
    return party or 0
end

function API.InGroup()
    if API.IsInGroup then
        local ok, res = pcall(API.IsInGroup)
        if ok then return res end
    end
    return (API.GroupSize() or 0) > 0
end

function API.InRaid()
    if API.IsInRaid then
        local ok, res = pcall(API.IsInRaid)
        if ok then return res end
    end
    return (API.GetNumRaidMembers and API.GetNumRaidMembers() or 0) > 0
end

-- C_ChatInfo (retail/modern) with the legacy globals as fallback.
local CC = _G.C_ChatInfo
if CC and CC.SendAddonMessage then
    API.SendAddonMessage = function(prefix, msg, kind)
        local ok = pcall(CC.SendAddonMessage, prefix, msg, kind)
        return ok
    end
elseif fn("SendAddonMessage") then
    API.SendAddonMessage = function(prefix, msg, kind)
        local ok = pcall(SendAddonMessage, prefix, msg, kind)
        return ok
    end
end

if CC and CC.RegisterAddonMessagePrefix then
    API.RegisterAddonMessagePrefix = function(prefix)
        pcall(CC.RegisterAddonMessagePrefix, prefix)
    end
elseif fn("RegisterAddonMessagePrefix") then
    API.RegisterAddonMessagePrefix = function(prefix)
        pcall(RegisterAddonMessagePrefix, prefix)
    end
end

-- Timer: C_Timer when present, otherwise the OnUpdate scheduler in Util.lua.
if _G.C_Timer and _G.C_Timer.After then
    API.After = function(delay, cb) C_Timer.After(delay, cb) end
else
    API.After = function(delay, cb) ns.After(delay, cb) end
end

-- Feature probes for method families that differ between client versions.
local probe = CreateFrame("Frame")
local probeTex = probe:CreateTexture()
API.canClip = type(probe.SetClipsChildren) == "function"
API.canBackdrop = type(probe.SetBackdrop) == "function"
API.canSetColorTexture = type(probeTex.SetColorTexture) == "function"
API.canSetMask = type(probeTex.SetMask) == "function"
API.canSetGradient = type(probeTex.SetGradient) == "function"
API.canSetRotation = type(probeTex.SetRotation) == "function"
API.canGetTexCoord = type(probeTex.GetTexCoord) == "function"

return API
