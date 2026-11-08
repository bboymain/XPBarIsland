"""Turn-in projection behavior checks with mocked WoW APIs (requires lupa)."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()

def load(name):
    lua.execute('local ADDON, ns = "XPBarIsland", ns\n' +
                (ROOT / name).read_text(encoding='utf-8-sig').replace('local ADDON, ns = ...', ''))

lua.execute('''
now, selected, scans, maxXP, level = 0, 4, 0, 1000, 20
timers, handlers = {}, {}
GetTime = function() return now end
ns = { API = {}, MarkDirty = function() end,
    On = function(event, fn) handlers[event] = fn end }
C_Timer = { After = function(delay, fn) timers[#timers + 1] = {delay, fn} end }
ns.After = C_Timer.After
function advance()
    now = now + 0.21
    local pending = timers; timers = {}
    for _, t in ipairs(pending) do assert(t[1] == 0.2); t[2]() end
end
ns.API.UnitXPMax = function() return maxXP end
ns.API.UnitLevel = function() return level end
ns.API.GetMaxPlayerLevel = function() return 60 end
entries = {
    {title = "Header", isHeader = true},
    {title = "Ready", questID = 102, state = 1, xp = 180},
    {title = "Failed", questID = 103, state = -1, xp = 900},
    {title = "Incomplete", questID = 104, state = 0, xp = 400},
    {title = "Ready 2", questID = 105, state = 1, xp = 1000},
}
ns.API.GetNumQuestLogEntries = function() scans = scans + 1; return #entries end
ns.API.GetQuestLogTitle = function(i)
    local q = entries[i]; return q.title, nil, nil, q.isHeader, nil, q.state
end
ns.API.GetQuestLogSelection = function() return selected end
ns.API.SelectQuestLogEntry = function(i) selected = i; handlers.QUEST_LOG_UPDATE() end
ns.API.GetQuestLogRewardXP = function() return entries[selected].xp end
''')
load('Data/Quests.lua')
lua.execute('''
local xp, count = ns.GetTurnInXP()
assert(xp == 1180 and count == 2 and selected == 4)
assert(#timers == 0) -- selection changes must not create a scan loop
for _, event in ipairs({"QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED",
    "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD"}) do assert(handlers[event]) end
for i = 1, 100 do handlers.QUEST_LOG_UPDATE(); ns.GetTurnInXP() end
assert(scans == 1 and #timers == 1)
advance(); assert(ns.GetTurnInXP() == 1180 and scans == 2)
entries[2].state = 0; entries[5].state = 0
handlers.QUEST_TURNED_IN(); advance(); assert(ns.GetTurnInXP() == 0)
entries[2].state = 1
handlers.QUEST_ACCEPTED(); advance(); assert(ns.GetTurnInXP() == 180)
local reward = ns.API.GetQuestLogRewardXP
ns.API.GetQuestLogRewardXP = function() error("reward unavailable") end
handlers.QUEST_LOG_UPDATE(); advance(); assert(ns.GetTurnInXP() == 0 and selected == 4)
ns.API.GetQuestLogRewardXP = reward
ns.API.GetQuestLogSelection = function() error("selection unavailable") end
handlers.QUEST_LOG_UPDATE(); advance(); assert(ns.GetTurnInXP() == 0 and selected == 4)
ns.API.GetQuestLogSelection = function() return selected end
C_QuestLog = {
    GetInfo = function(i) return entries[i] end,
    GetNumQuestLogEntries = function() return #entries end,
    ReadyForTurnIn = function(id) return id == 102 end,
}
ns.API.GetQuestLogRewardXP = function(id) assert(id == 102); return 180 end
handlers.QUEST_LOG_UPDATE(); advance(); assert(ns.GetTurnInXP() == 180)
C_QuestLog.ReadyForTurnIn = nil
C_QuestLog.IsComplete = function(id) return id == 102 end
handlers.QUEST_LOG_UPDATE(); advance(); assert(ns.GetTurnInXP() == 180)
-- A modern log can coexist with the selected-entry reward API.
ns.API.GetQuestLogRewardXP = function(id) assert(id == nil); return entries[selected].xp end
handlers.QUEST_LOG_UPDATE(); advance(); assert(ns.GetTurnInXP() == 180 and selected == 4)
maxXP = 0; handlers.PLAYER_XP_UPDATE(); advance(); assert(ns.GetTurnInXP() == 0)
maxXP, level = 1000, 60; handlers.PLAYER_LEVEL_UP(); advance(); assert(ns.GetTurnInXP() == 0)
level = 20; C_QuestLog = nil; ns.API.GetQuestLogRewardXP = nil; C_Timer = nil
handlers.QUEST_LOG_UPDATE(); advance(); assert(ns.GetTurnInXP() == 0)
ns.API.GetNumQuestLogEntries = nil
handlers.QUEST_LOG_UPDATE(); advance(); assert(ns.GetTurnInXP() == 0)
''')

lua.execute('''
function texture()
    return setmetatable({width = 102, height = 12, shown = false, scripts = {}}, {__index = function(t, k)
        if k == "SetPropagateMouseClicks" and legacyClicks then return nil end
        if k == "SetScript" then return function(_, event, fn)
            t.scripts = t.scripts or {}; t.scripts[event] = fn
        end end
        if k == "GetScript" then return function(_, event) return t.scripts and t.scripts[event] end end
        if k == "GetWidth" then return function() return t.width end end
        if k == "GetHeight" then return function() return t.height end end
        if k == "SetWidth" then return function(_, w) t.width = w end end
        if k == "Show" then return function() t.shown = true end end
        if k == "Hide" then return function() t.shown = false end end
        if k == "SetShown" then return function(_, b)
            local wasShown = t.shown; t.shown = b
            if wasShown and not b and t.scripts and t.scripts.OnHide then t.scripts.OnHide(t) end
        end end
        if k == "IsShown" then return function() return t.shown end end
        if k == "CreateTexture" or k == "CreateFontString" then return texture end
        return function(_, ...) t[k .. "Args"] = {...} end
    end})
end
CreateFrame = texture
ns.Media = {stripe = "Stripe", white = "white"}
ns.Paint = function() end; ns.Gradient = function() end; ns.StyleText = function() end
ns.HexA = function() return {1,1,1,1} end
ns.clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
ns.round = function(v) return math.floor(v + 0.5) end
ns.Theme = function() return {} end
ns.db = {animations = "Off", showTurnInXP = true, segFlash = false}
ns.KillTween = function(t) t.killed = true end
ns.Tween = function(t) return t end
''')
load('UI/Bar.lua')
lua.execute('''
bar = ns.NewBar({})
for _, w in ipairs({2, 2.4, 102, 461.5}) do
    bar.frame.width = w
    for _, pct in ipairs({0, 0.25, 0.9, 1}) do
        for _, turn in ipairs({0, 0.001, 0.2, 2}) do
            bar.pct, bar.turnInPct, bar.restedPct = pct, turn, 1
            bar:LayoutFill()
            local fw, inner = bar.fill.width, w - 2
            local tw = bar.turnInBar.shown and bar.turnInBar.width or 0
            local rw = bar.rested.shown and bar.rested.width or 0
            assert(bar.turnInHover.shown == (tw > 0))
            assert(bar.turnInIcon.shown == (tw >= 12))
            assert(fw + tw + rw <= inner + 0.000001)
            if tw > 0 then assert(bar.turnInBar.SetPointArgs[4] == 1 + fw) end
            if rw > 0 then assert(bar.rested.SetPointArgs[4] == 1 + fw + tw) end
            if turn == 0 then assert(not bar.turnInBar.shown) end
        end
    end
end
bar.frame.width = 102
bar.UpdateEffects = function() end
bar:SetData({key="xp", pct=0.25, turnInPct=0.2, restedPct=0.6, level=20})
assert(bar.turnInBar.width == 20 and bar.rested.width == 55)
ns.db.animations = "Always"
bar:SetData({key="xp", pct=0.25, turnInPct=0.4, restedPct=0.6, level=20})
assert(bar.turnInTween and bar.turnInBar.width == 20)
bar.turnInTween.set(0.3)
assert(bar.turnInBar.width == 30 and bar.rested.width == 45)
ns.db.showTurnInXP = false
bar:SetData({key="xp", pct=0.25, turnInPct=0, restedPct=0.6, level=20})
assert(not bar.turnInBar.shown and bar.rested.width == 60)
assert(bar.rested.SetPointArgs[4] == 26)
ns.db.showTurnInXP, ns.db.animations = true, "Off"
bar:SetData({key="xp", pct=0.25, turnInPct=0.2, restedPct=0.6, level=20})
ns.db.animations = "Always"
bar:SetData({key="xp", pct=0.45, turnInPct=0, restedPct=0.6, cur=450, max=1000, level=20})
bar.gainTween.set(0.5); bar.turnInTween.set(0.1)
assert(bar.fill.width == 35 and bar.turnInBar.width == 10)
assert(bar.rested.SetPointArgs[4] == 46)
bar.gainTween.set(1); bar.turnInTween.set(0)
assert(bar.fill.width == 45 and not bar.turnInBar.shown and bar.rested.width == 55)

''')

lua.execute('''
ns.Colors = {quest={0.25,0.86,0.43}, xp={}, restTag={}}
ns.session = {LevelElapsed=function() return nil end}
ns.Time = tostring; ns.Short = function(n) return tostring(n) end
ns.quests = function() return {total=1180, count=2, list={}} end
ns.xp = function() return {cur=250, max=1000, pct=0.25, level=20, rested=600, elapsed=0} end
UnitName = function() return "Tester" end
''')
load('Data/Data.lua')
lua.execute('''
ns.db.showTurnInXP = true
local d = ns.data:Build("xp")
assert(d.questTotal == 1180 and d.turnInPct == 0.75 and d.turnInLevel)
assert(d.stats[3].k == "Turn-in" and d.stats[3].c == ns.Colors.quest)
ns.db.showTurnInXP = false
d = ns.data:Build("xp")
assert(d.turnInPct == 0 and d.questTotal == 0 and not d.turnInLevel)
for _, stat in ipairs(d.stats) do assert(stat.k ~= "Turn-in") end
''')
lua.execute('''
UIParent = {GetHeight = function() return 1000 end}
GameTooltip = {
    SetOwner = function(t, owner, anchor) t.owner, t.anchor = owner, anchor end,
    IsOwned = function(t, owner) return t.owner == owner end,
    SetText = function(t, title) t.title, t.lines, t.height = title, {}, 32 end,
    AddLine = function(t, ...) t.lines[#t.lines+1] = {...}; t.height = t.height + 16 end,
    AddDoubleLine = function(t, ...) t.lines[#t.lines+1] = {...}; t.height = t.height + 16 end,
    Show = function(t) t.shown = true end,
    Hide = function(t) t.shown = false end,
    GetHeight = function(t) return t.height end,
}
ns.db.showTurnInXP = true
bar.data = ns.data:Build("xp")
bar.data.questList = {{title="Ready", xp=180}, {title="Ready 2", xp=1000}}
bar.pct, bar.turnInPct = 0.25, 0.5
bar:LayoutFill()
assert(bar.turnInIcon.SetTextureArgs[1] == "Interface\\\\GossipFrame\\\\ActiveQuestIcon")
assert(bar.turnInIcon.SetSizeArgs[1] == 12 and bar.turnInIcon.SetSizeArgs[2] == 12)
assert(bar.turnInIcon.SetPointArgs[1] == "CENTER" and bar.turnInIcon.SetPointArgs[2] == bar.turnInBar)
assert(bar.turnInHover.EnableMouseArgs[1] == true)
assert(bar.shineFrame.EnableMouseArgs[1] == false)
bar.turnInHover.scripts.OnEnter()
assert(GameTooltip.shown and GameTooltip.title == "Quest turn-in")
assert(GameTooltip.owner == bar.turnInHover and GameTooltip.anchor == "ANCHOR_TOP")
assert(GameTooltip.lines[1][1] == "+1180 XP from 2 completed quests")
assert(GameTooltip.lines[1][2] == 0.25 and GameTooltip.lines[1][3] == 0.86)
assert(GameTooltip.lines[2][1] == "Turning these in will level you up")
assert(GameTooltip.lines[3][1] == "Ready" and GameTooltip.lines[3][2] == "180 XP")
assert(GameTooltip.lines[4][1] == "Ready 2")
bar.turnInHover.scripts.OnLeave()
assert(not GameTooltip.shown and not bar.turnInHovered)
bar.data.turnInLevel = false
bar.turnInHover.scripts.OnEnter()
assert(GameTooltip.lines[2][1] == "Ready")
UIParent.GetHeight = function() return 100 end
bar:ShowTurnInTooltip()
assert(GameTooltip.lines[2][1] == "Ready" and GameTooltip.lines[3][1] == "+1 more quests")
bar.turnInPct = 0.119; bar:LayoutFill(); assert(not bar.turnInIcon.shown and bar.turnInHover.shown)
bar.turnInPct = 0.12; bar:LayoutFill(); assert(bar.turnInIcon.shown)
bar.turnInIcon.GetLeft = function() return 48 end
bar.turnInIcon.GetRight = function() return 60 end
local label = texture()
label.shown = true
label.GetStringWidth = function() return 20 end
label.GetLeft = function() return 50 end
label.GetRight = function() return 70 end
ns.island = {bar=bar, thin=true, thinNameFS=label}
bar:LayoutTurnInIcon()
assert(not bar.turnInIcon.shown and bar.turnInHover.shown)
label.GetLeft = function() return 65 end
bar:LayoutTurnInIcon(); assert(bar.turnInIcon.shown)
label.GetLeft = function() return 50 end
label.shown = false
bar:LayoutTurnInIcon(); assert(bar.turnInIcon.shown)
label.shown = true; ns.island.thin = false
bar:LayoutTurnInIcon(); assert(bar.turnInIcon.shown)
ns.island = nil
bar.turnInPct = 0; bar:LayoutFill()
assert(not GameTooltip.shown and not bar.turnInHovered and not bar.turnInHover.shown)
legacyClicks = true
ns.island = {frame = texture()}
local down, up
ns.island.frame:SetScript("OnMouseDown", function(frame, button) assert(frame == ns.island.frame); down = button end)
ns.island.frame:SetScript("OnMouseUp", function(frame, button) assert(frame == ns.island.frame); up = button end)
local legacyBar = ns.NewBar({})
legacyBar.turnInHover.scripts.OnMouseDown(nil, "LeftButton")
legacyBar.turnInHover.scripts.OnMouseUp(nil, "LeftButton")
assert(down == "LeftButton" and up == "LeftButton")
''')

# Run the actual background layout for Minimal, hovered and unhovered.
source = (ROOT / 'UI/Island.lua').read_text(encoding='utf-8-sig')
start = source.index('function island:LayoutBorders()')
end = source.index('\nend', start) + 4
lua.execute('''
island = texture(); f = texture()
CORNER, PAD_L, BADGE, C_H, PAD_R, CENTER_LEFT, THIN_H = 14, 7, 20, 60, 7, 40, 26
ns.Theme = function() return {bw=2} end
for _, k in ipairs({"bg", "borderL", "borderR", "borderB", "innerL", "innerR", "innerB",
    "thinShadow", "badge", "divider", "rightBlock", "nameFS", "rangeFS", "pctFS", "qpFS",
    "restTag", "barsFS", "col", "cornerFillBL", "cornerFillBR", "cornerEdgeBL", "cornerEdgeBR",
    "betweenFill"}) do island[k] = texture() end
island.bar = texture(); island.bar.frame = texture()
island.tween = true
island.thinBoost, island._thinBarLeft, island.rightInset = 0, 7, 7
strengthScale = function() return 1 end
''')
lua.execute(source[start:end])
lua.execute('''
for _, thin in ipairs({true, false}) do
    for _, hover in ipairs({true, false}) do
        island.thin, island.mouseOver = thin, hover
        island:LayoutBorders()
        assert(island.bg.shown == not thin)
        assert(island.cornerFillBL.shown == not thin)
        assert(island.betweenFill.shown == not thin)
    end
end
''')
print('PASS: Lua 5.1 quests, throttle, geometry, animation, toggle, stats, icon, tooltip and Minimal hover background')
