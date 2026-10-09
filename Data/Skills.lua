local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Skills (professions and weapon skills).
--
-- Classic-era clients list every skill through GetNumSkillLines/GetSkillLineInfo.
-- Modern-engine clients replaced that pair with the C_SkillInfo attributes
-- tables and expose professions through C_TradeSkillUI, while older modern
-- clients only offer GetProfessions/GetProfessionInfo.  Every source the client
-- provides is collected and merged, with duplicate names dropped.
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

-- Modern skill lines: C_SkillInfo returns a SkillLineAttributes table per line.
local function modernSkillList()
    local getNum, getInfo = ns.API.CSkillInfoGetNumSkillLines, ns.API.CSkillInfoGetSkillLineInfo
    if not (getNum and getInfo) then return nil end
    local nok, num = pcall(getNum)
    if not nok or type(num) ~= "number" then return nil end
    local list = {}
    for i = 1, num do
        local iok, info = pcall(getInfo, i)
        if iok and type(info) == "table" and info.name and not info.isHeader and (info.maxRank or 0) > 0 then
            list[#list + 1] = { name = info.name, rank = info.rank or 0, max = info.maxRank }
        end
    end
    if #list > 0 then return list end
    return nil
end

-- Modern professions: trade skill line IDs -> ProfessionInfo tables.
local function modernProfessionsList()
    local getLines, getInfo = ns.API.GetAllProfessionTradeSkillLines, ns.API.GetProfessionInfoBySkillLineID
    if not (getLines and getInfo) then return nil end
    local lok, lines = pcall(getLines)
    if not lok or type(lines) ~= "table" then return nil end
    local list = {}
    for _, id in ipairs(lines) do
        local iok, info = pcall(getInfo, id)
        if iok and type(info) == "table" then
            local name = info.professionName or info.name
            local rank = info.skillLevel or info.rank
            local max = info.maxSkillLevel or info.maxRank
            if name and max and max > 0 then
                list[#list + 1] = { name = name, rank = rank or 0, max = max }
            end
        end
    end
    if #list > 0 then return list end
    return nil
end

-- Legacy skill globals, tolerating both the classic multi-return shape and a
-- single SkillLineAttributes table (some builds alias the global this way).
local function legacySkillList()
    local getNum, getInfo = ns.API.GetNumSkillLines, ns.API.GetSkillLineInfo
    if not (getNum and getInfo) then return nil end
    local nok, num = pcall(getNum)
    if not nok or type(num) ~= "number" then return nil end
    local list = {}
    for i = 1, num do
        local iok, name, isHeader, _, rank, _, _, maxRank = pcall(getInfo, i)
        if iok then
            if type(name) == "table" then
                local info = name
                name, isHeader, rank, maxRank = info.name, info.isHeader, info.rank, info.maxRank
            end
            if name and not isHeader and maxRank and maxRank > 0 then
                list[#list + 1] = { name = name, rank = rank or 0, max = maxRank }
            end
        end
    end
    if #list > 0 then return list end
    return nil
end

-- Legacy professions globals.  Some modern clients return more than the five
-- historic slots (e.g. two primary plus five secondary professions), and an
-- empty primary slot must not hide the secondary ones, so every slot is
-- checked explicitly instead of through ipairs.
local function legacyProfessionsList()
    local getProfs, getInfo = ns.API.GetProfessions, ns.API.GetProfessionInfo
    if not (getProfs and getInfo) then return nil end
    local ok, p1, p2, p3, p4, p5, p6, p7 = pcall(getProfs)
    if not ok then return nil end
    local list = {}
    local function add(idx)
        if not idx then return end
        local iok, name, _, rank, maxRank = pcall(getInfo, idx)
        if iok and name and type(name) == "string" and (maxRank or 0) > 0 then
            list[#list + 1] = { name = name, rank = rank or 0, max = maxRank }
        end
    end
    if type(p1) == "table" then
        for i = 1, #p1 do add(p1[i]) end
    else
        add(p1); add(p2); add(p3); add(p4); add(p5); add(p6); add(p7)
    end
    if #list > 0 then return list end
    return nil
end

-- Every skill/profession line this client can report, merged and deduplicated.
local function collect()
    local list = legacySkillList() or {}
    local modern = modernSkillList()
    if modern then
        for _, s in ipairs(modern) do list[#list + 1] = s end
    end
    local profs = modernProfessionsList()
    if profs then
        for _, s in ipairs(profs) do list[#list + 1] = s end
    end
    if #list == 0 then
        list = legacyProfessionsList() or {}
    end
    local seen, out = {}, {}
    for _, s in ipairs(list) do
        if s.name and not seen[s.name] then
            seen[s.name] = true
            out[#out + 1] = s
        end
    end
    return out
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
