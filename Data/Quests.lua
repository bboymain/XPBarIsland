local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Completed-quest XP preview.  Sums the XP reward of every finished quest in
-- the log; the ghost bar segment and the "+N XP" text use the total.
-- ---------------------------------------------------------------------------
local cache = { valid = false, at = 0, total = 0, list = {}, count = 0, inLog = 0 }
ns.questCache = cache

function ns.InvalidateQuests()
    cache.valid = false
    ns.MarkDirty()
end

local function scan()
    cache.valid = true
    cache.at = GetTime()
    cache.list = {}
    cache.total = 0
    cache.count = 0
    cache.inLog = 0

    if not ns.API.GetNumQuestLogEntries or not ns.API.GetQuestLogTitle then return end
    local num = ns.API.GetNumQuestLogEntries() or 0
    local prev = ns.API.GetQuestLogSelection and ns.API.GetQuestLogSelection() or 1
    for i = 1, num do
        local title, _, _, isHeader, _, isComplete = ns.API.GetQuestLogTitle(i)
        if title and not isHeader then
            cache.inLog = cache.inLog + 1
            if isComplete then
                cache.count = cache.count + 1
                local xp = 0
                if ns.API.GetQuestLogRewardXP then
                    if ns.API.SelectQuestLogEntry then pcall(ns.API.SelectQuestLogEntry, i) end
                    xp = ns.API.GetQuestLogRewardXP() or 0
                end
                cache.total = cache.total + xp
                cache.list[#cache.list + 1] = { title = title, xp = xp }
            end
        end
    end
    if ns.API.SelectQuestLogEntry then pcall(ns.API.SelectQuestLogEntry, prev or 1) end
end

function ns.quests()
    if not cache.valid or (GetTime() - cache.at) > 5 then
        pcall(scan)
    end
    return cache
end

ns.On("QUEST_LOG_UPDATE", ns.InvalidateQuests)
ns.On("QUEST_TURNED_IN", ns.InvalidateQuests)
ns.On("QUEST_ACCEPTED", ns.InvalidateQuests)
ns.On("PLAYER_ENTERING_WORLD", ns.InvalidateQuests)
