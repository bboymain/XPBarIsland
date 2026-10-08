local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Pet experience (hunters and warlocks only).
-- ---------------------------------------------------------------------------
function ns.petClass()
    local _, class = UnitClass("player")
    return class == "HUNTER" or class == "WARLOCK"
end

local petSession = 0
ns.petSession = { gained = function() return petSession end }

local HAPPINESS = { "Unhappy", "Content", "Happy" }

local function petHappiness()
    local f = _G.GetPetHappiness
    if type(f) ~= "function" then return nil end
    local ok, h = pcall(f)
    if not ok or h == nil then return nil end
    -- h is normally 1..3; guard the lookup in case a client returns anything else
    local label
    local ok2, res = pcall(function() return _G["PET_HAPPINESS" .. h] end)
    if ok2 then label = res end
    if not label and type(h) == "number" then label = HAPPINESS[h] end
    return label
end

-- pcall + tonumber a possibly-missing client API so a bad/renamed return can
-- never throw inside the pet builder.
local function petNum(fn, unit)
    if type(fn) ~= "function" then return nil end
    -- the call and the tonumber both run inside pcall (some clients hand back
    -- values that cannot be arithmetically used)
    local ok, v = pcall(function() return tonumber(fn(unit)) end)
    if not ok then return nil end
    return v
end

function ns.pet()
    local ok, res = pcall(function()
        if not ns.petClass() then return { available = false, note = "No pet class" } end

        local present = false
        if ns.API.UnitExists then
            local eok, exists = pcall(ns.API.UnitExists, "pet")
            present = (eok and exists) and true or false
        end
        if not present then return { available = false, note = "No pet" } end

        local name = "Pet"
        if type(UnitName) == "function" then
            local nok, n = pcall(UnitName, "pet")
            if nok and type(n) == "string" and n ~= "" then name = n end
        end

        local level = petNum(UnitLevel, "pet") or 0
        local hp = petNum(UnitHealth, "pet") or 0
        local hpMax = petNum(UnitHealthMax, "pet") or 0
        if hpMax <= 0 then hpMax = 1 end
        local happiness = petHappiness()

        -- Hunters' pets gain XP; warlock pets do not.  When there is no pet XP
        -- (warlock, or a client without the API) fall back to the pet's health.
        local cur, max = 0, 0
        if ns.API.GetPetExperience then
            local xok, c, m = pcall(ns.API.GetPetExperience)
            if xok then
                local cok, cn = pcall(tonumber, c)
                local mok, mn = pcall(tonumber, m)
                cur = (cok and cn) or 0
                max = (mok and mn) or 0
            end
        end
        local hasXP = max > 0
        if not hasXP then cur, max = hp, hpMax end

        return {
            available = true, hasXP = hasXP,
            cur = cur, max = max, pct = ns.clamp(cur / max, 0, 1),
            level = level, badge = tostring(level), name = name,
            health = hp, healthMax = hpMax, hpPct = ns.clamp(hp / hpMax, 0, 1),
            happiness = happiness,
        }
    end)
    if not ok then return { available = false, note = "Pet data unavailable" } end
    return res
end

local function petChanged()
    if ns.petClass() and ns.API.GetPetExperience and ns.API.UnitExists and UnitExists("pet") then
        local ok, cur = pcall(ns.API.GetPetExperience)
        if ok then
            local tok, tn = pcall(tonumber, cur)
            cur = tok and tn or nil
        else
            cur = nil
        end
        if cur then
            local delta = cur - (ns._petLastXP or 0)
            if ns._petLastXP ~= nil and delta > 0 then petSession = petSession + delta end
            ns._petLastXP = cur
        end
    end
    ns.TouchData()
    ns.MarkDirty()
end
ns.On("UNIT_PET_EXPERIENCE", petChanged)
ns.On("PET_XP_UPDATE", petChanged)
ns.On("UNIT_PET", petChanged)
ns.On("PLAYER_ENTERING_WORLD", petChanged)
