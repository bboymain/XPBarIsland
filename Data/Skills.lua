local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Skills (professions and weapon skills).
--
-- Classic-era clients list every skill through GetNumSkillLines/GetSkillLineInfo.
-- Modern-engine clients (retail and "Classic Forever") removed that pair and
-- expose professions through GetProfessions/GetProfessionInfo instead, so fall
-- back to the professions API when the classic one is missing or empty.
-- ---------------------------------------------------------------------------
local snapshot = {}
local target = nil   -- { name=, rank=, max= }
ns.skillTarget = nil

local function buildPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%s", "(.+)")
    p = p:gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local skillPattern = buildPattern(_G.SKILL_RANK_UP)

-- Modern professions -> { name=, rank=, max= } list, or nil when unavailable.
local function professionsList()
    local getProfs, getInfo = ns.API.GetProfessions, ns.API.GetProfessionInfo
    if not (getProfs and getInfo) then return nil end
    local ok, p1, p2, arch, fish, cook = pcall(getProfs)
    if not ok then return nil end
    local list = {}
    for _, idx in ipairs({ p1, p2, arch, fish, cook }) do
        if idx then
            local iok, name, _, rank, maxRank = pcall(getInfo, idx)
            if iok and name and (maxRank or 0) > 0 then
                list[#list + 1] = { name = name, rank = rank or 0, max = maxRank }
            end
        end
    end
    return list
end

-- Every skill/profession line this client can report, classic first.
local function collect()
    if ns.API.GetNumSkillLines and ns.API.GetSkillLineInfo then
        local num = ns.API.GetNumSkillLines() or 0
        local list = {}
        for i = 1, num do
            local name, isHeader, _, rank, _, _, maxRank = ns.API.GetSkillLineInfo(i)
            if name and not isHeader and maxRank and maxRank > 0 then
                list[#list + 1] = { name = name, rank = rank or 0, max = maxRank }
            end
        end
        if #list > 0 then return list end
    end
    return professionsList() or {}
end

function ns.skill()
    local list = collect()
    if #list == 0 then return { available = false } end

    local t = target
    if not t then
        -- Default to the first (usually primary profession).
        t = list[1]
    end
    -- Make sure the target still exists.
    local found = false
    for _, s in ipairs(list) do
        if s.name == t.name then found = true; t = s end
    end
    if not found then t = list[1] end

    return {
        available = true,
        name = t.name,
        rank = t.rank,
        max = t.max,
        pct = (t.max > 0) and (t.rank / t.max) or 0,
        list = list,
        badge = tostring(t.rank),
    }
end

local function detectChange()
    local list = collect()
    if #list == 0 then return end
    for _, s in ipairs(list) do
        local prev = snapshot[s.name]
        if prev and s.rank > prev then
            target = { name = s.name, rank = s.rank, max = s.max }
            ns.skillTarget = target
        end
        snapshot[s.name] = s.rank
    end
    ns.TouchData()
    ns.MarkDirty()
end

ns.On("SKILL_LINES_CHANGED", detectChange)
-- modern clients fire this from the profession window instead
ns.On("TRADE_SKILL_UPDATE", detectChange)
ns.On("PLAYER_ENTERING_WORLD", function()
    snapshot = {}
    detectChange()
end)

ns.On("CHAT_MSG_SKILL", function(_, msg)
    if not msg then return end
    local name, rank
    if skillPattern then
        name, rank = msg:match(skillPattern)
    end
    if not name then
        name, rank = msg:match("(.+):%s*(%d+)")
    end
    if name then
        rank = tonumber((tostring(rank) or ""):gsub("[^%d]", "")) or 0
        target = { name = name, rank = rank, max = (target and target.max) or rank }
        ns.skillTarget = target
        if ns.ShowGain then ns.ShowGain("+" .. rank .. " " .. name) end
        if ns.AutoSwitch then ns.AutoSwitch("skills", 3) end
        ns.MarkDirty()
    end
end)
