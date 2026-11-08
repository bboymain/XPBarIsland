local ADDON, ns = ...

-- Completed quests share one cache for the bar, stats and quest list.
local cache = { valid = false, at = -math.huge, total = 0, list = {}, count = 0, inLog = 0 }
ns.questCache = cache
local pending, scanning = false, false

function ns.InvalidateQuests()
    if pending or scanning then return end
    pending = true
    local after = C_Timer and C_Timer.After or ns.After
    after(0.2, function()
        pending = false
        cache.valid = false
        ns.MarkDirty()
    end)
end

local function scan(canSelect)
    local api = ns.API
    local max = api.UnitXPMax and api.UnitXPMax("player") or 0
    local cap = (api.GetMaxPlayerLevel and api.GetMaxPlayerLevel()) or _G.MAX_PLAYER_LEVEL or 0
    if max <= 0 or (cap > 0 and api.UnitLevel and api.UnitLevel("player") >= cap) then return end

    local modern = C_QuestLog and C_QuestLog.GetInfo
    local num = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries()
        or (api.GetNumQuestLogEntries and api.GetNumQuestLogEntries()) or 0
    for i = 1, num do
        local title, isHeader, complete, questID
        if modern then
            local info = C_QuestLog.GetInfo(i)
            if info then
                title, isHeader, questID = info.title, info.isHeader, info.questID
                if not isHeader and questID then
                    if C_QuestLog.ReadyForTurnIn then complete = C_QuestLog.ReadyForTurnIn(questID) end
                    if complete ~= true and complete ~= 1 and C_QuestLog.IsComplete then complete = C_QuestLog.IsComplete(questID) end
                end
            end
        elseif api.GetQuestLogTitle then
            local level, tag, collapsed, state
            title, level, tag, isHeader, collapsed, state = api.GetQuestLogTitle(i)
            complete = state == 1
        end
        if title and not isHeader then
            cache.inLog = cache.inLog + 1
            if complete == true or complete == 1 then
                local xp = 0
                if api.GetQuestLogRewardXP then
                    if modern then
                        local ok, reward = pcall(api.GetQuestLogRewardXP, questID)
                        if ok and type(reward) == "number" then xp = reward end
                        if not ok or type(reward) ~= "number" then xp = nil end
                    else
                        xp = nil
                    end
                    if xp == nil and canSelect and api.SelectQuestLogEntry then
                        api.SelectQuestLogEntry(i)
                        xp = api.GetQuestLogRewardXP() or 0
                    end
                end
                xp = math.max(0, xp or 0)
                cache.count = cache.count + 1
                cache.total = cache.total + xp
                cache.list[#cache.list + 1] = { title = title, xp = xp }
            end
        end
    end
end

function ns.quests()
    if not scanning and (not cache.valid or GetTime() - cache.at > 5)
        and GetTime() - cache.at >= 0.2 then
        scanning = true
        cache.total, cache.count, cache.inLog, cache.list = 0, 0, 0, {}
        local ok, prev = false, nil
        if ns.API.GetQuestLogSelection then ok, prev = pcall(ns.API.GetQuestLogSelection) end
        local scanned = pcall(scan, ok and prev ~= nil)
        -- Restore even if a legacy reward API failed halfway through the scan.
        if ok and prev ~= nil and ns.API.SelectQuestLogEntry then pcall(ns.API.SelectQuestLogEntry, prev) end
        if not scanned then cache.total, cache.count, cache.inLog, cache.list = 0, 0, 0, {} end
        cache.at, cache.valid = GetTime(), true
        scanning = false
    end
    return cache
end

function ns.GetTurnInXP()
    local q = ns.quests()
    return q.total, q.count
end

for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED",
    "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
    ns.On(event, ns.InvalidateQuests)
end
