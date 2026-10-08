local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Event bus.  Modules call ns.On(event, handler); the bus registers each
-- event once (guarded, because not every event exists on every client) and
-- dispatches to every handler inside pcall so one bad handler cannot break
-- the rest of the addon.
-- ---------------------------------------------------------------------------
local bus = CreateFrame("Frame")
ns.bus = bus

local handlers = {}
ns.handlers = handlers

local registered = {}

local function registerEvent(event)
    if registered[event] then return end
    registered[event] = true
    pcall(bus.RegisterEvent, bus, event)
end

function ns.On(event, handler)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], handler)
    registerEvent(event)
end

bus:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            ns.ReportError(event, err)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Throttled refresh.  Anything that changes data calls ns.MarkDirty(); the
-- UI is rebuilt at most ten times per second.  A one second tick keeps
-- time-based values (xp/hr, time to level, "updated Ns ago") fresh.
-- ---------------------------------------------------------------------------
ns.dirty = true

function ns.MarkDirty()
    -- during a batch, the refresh runs once when the batch ends
    if ns.BatchActive and ns.BatchActive() then return end
    ns.dirty = true
end

local accum = 0
local clockAccum = 0
bus:SetScript("OnUpdate", function(_, elapsed)
    accum = accum + elapsed
    clockAccum = clockAccum + elapsed
    if clockAccum >= 1 then
        clockAccum = 0
        ns.dirty = true
    end
    if ns.dirty and accum >= 0.1 then
        accum = 0
        ns.dirty = false
        ns.RefreshUI()
    end
end)

-- ---------------------------------------------------------------------------
-- Errors are reported once per event, to chat, then forgotten.
-- ---------------------------------------------------------------------------
local reported = {}
function ns.ReportError(where, err)
    local key = tostring(where) .. tostring(err)
    if reported[key] then return end
    reported[key] = true
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555XPBar Island|r: " .. tostring(err) .. " (" .. tostring(where) .. ")")
    end
end

function ns.RefreshUI() end -- replaced in Boot.lua

-- ---------------------------------------------------------------------------
-- Combat state (used by hide-in-combat and auto-switch).
-- ---------------------------------------------------------------------------
ns.inCombat = false
ns.On("PLAYER_REGEN_DISABLED", function() ns.inCombat = true; ns.MarkDirty() end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.inCombat = false; ns.MarkDirty() end)

ns.On("PLAYER_ENTERING_WORLD", function()
    ns.MarkDirty()
end)
