local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Shift-click share: posts a one line summary of the current progress to
-- the channel chosen in the settings (party / guild / say).
-- ---------------------------------------------------------------------------
local function channelKey()
    local c = (ns.db and ns.db.shareChannel) or "Party"
    if c == "Guild" then return "GUILD" end
    if c == "Say" then return "SAY" end
    return "PARTY"
end

local function channelAvailable(key)
    local inGroup = ns.API.InGroup and ns.API.InGroup()
    if key == "PARTY" then return inGroup end
    if key == "GUILD" then return (IsInGuild and IsInGuild()) end
    return true
end

function ns.Share()
    local d = ns.data and ns.data:Current()
    if not d then return end
    local name = UnitName("player") or "Player"
    local msg
    if d.key == "xp" then
        local pct = ns.round((d.pct or 0) * 100)
        local bars = math.max(0, math.ceil((100 - pct) / 5))
        msg = string.format("%s: %d%% to level %d - %d bar%s to level up",
            name, pct, d.level or 0, bars, bars == 1 and "" or "s")
        if d.rateValue and d.rateValue > 0 then
            msg = msg .. " - " .. ns.Short(ns.round(d.rateValue), ns.db.compact) .. " XP/hr"
        end
    else
        msg = string.format("%s: %s - %s", name, d.label or "Progress", d.shortLine or (ns.round((d.pct or 0) * 100) .. "%"))
    end

    local key = channelKey()
    if not channelAvailable(key) then key = "SAY" end
    if SendChatMessage then
        pcall(SendChatMessage, msg, key)
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100XPBar Island|r: " .. msg)
    end
end
