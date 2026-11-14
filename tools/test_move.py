"""Free movement regression checks using simulated WoW Lua 5.1 APIs."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.execute('''
ns = {Font = function() return "font" end, HexA = function() return {} end}
island = {CancelCombatHold = function() end, StopCombatFade = function() end}
f = {scripts = {}, GetHeight = function() return 60 end,
    GetEffectiveScale = function() return effectiveScale end,
    SetScript = function(self, name, fn) self.scripts[name] = fn end,
    SetPoint = function(self, ...) self.point = {...} end,
    ClearAllPoints = function() end, EnableMouse = function() end,
    SetAlpha = function(self, alpha) self.alpha = alpha end}
UIParent = {}
GetCursorPosition = function() return cursorX, cursorY end
island.TogglePin = function() error("drag must not pin the panel") end
''')
init = (ROOT / 'Core/Init.lua').read_text(encoding='utf-8-sig')
lua.execute('local ADDON, ns = "XPBarIsland", ns\n' +
            init.split('-- Saved variables and defaults')[0].replace('local ADDON, ns = ...', ''))
source = (ROOT / 'UI/Island.lua').read_text(encoding='utf-8-sig')
for name in ('CurrentScale', 'ApplyPosition', 'UpdateFade'):
    start = source.index('function island:' + name + '(')
    lua.execute(source[start:source.index('\nend', start) + 4])

# Keep the real mouse callbacks and drag update in one Lua scope.
start = source.index('local dragging, dragStartX')
end = source.index('f:SetScript("OnUpdate"', start)
drag = source.index('    if dragging and ns.db.move then', end)
drag_end = source.index('\n    end', drag) + len('\n    end')
lua.execute(source[start:end] + '\nf:SetScript("OnUpdate", function()\n' +
            source[drag:drag_end] + '\nend)')
lua.execute('''
for _, shape in ipairs({"Attached", "Pill"}) do
    for _, scale in ipairs({70, 100, 150}) do
        for _, parentScale in ipairs({0.64, 1}) do
            ns.db = {enabled = true, shape = shape, theme = "Default", scale = scale,
                posY = 12, posX = 30, moveY = -20, move = true,
                mode = "Full", animations = "Off"}
            effectiveScale = scale / 100 * parentScale
            cursorX, cursorY = 900, 800
            f.scripts.OnMouseDown(f, "LeftButton")
            cursorX, cursorY = 1140, 300
            f.scripts.OnUpdate()
            assert(math.abs((ns.db.posX - 30) * effectiveScale - 240) < 0.001)
            assert(math.abs((ns.db.moveY + 20) * effectiveScale + 500) < 0.001)
            assert(ns.db.posY == 12) -- Pill spacing stays independent.
            assert(math.abs(f.point[5] - (ns.db.moveY - ns.TopOffset() / (scale / 100))) < 0.001)
            cursorX, cursorY = 800, 700
            f.scripts.OnUpdate() -- also move back up and left
            assert(math.abs((ns.db.posX - 30) * effectiveScale + 100) < 0.001)
            assert(math.abs((ns.db.moveY + 20) * effectiveScale + 100) < 0.001)
            f.scripts.OnMouseUp(f, "LeftButton")
            local x, y = ns.db.posX, ns.db.moveY
            cursorX, cursorY = 600, 100
            f.scripts.OnUpdate()
            assert(ns.db.posX == x and ns.db.moveY == y) -- release stops dragging
            ns.db.move = false
            f.scripts.OnMouseDown(f, "LeftButton"); f.scripts.OnUpdate()
            assert(ns.db.posX == x and ns.db.moveY == y) -- locked stays put
            ns.db.move = true
            f.scripts.OnMouseDown(f, "RightButton"); f.scripts.OnUpdate()
            assert(ns.db.posX == x and ns.db.moveY == y)

            ns.db.mode = "Auto-hide"; ns.db.move = false
            island:UpdateFade()
            assert(f.point[5] >= 60) -- moved Pill must still clear the screen
            ns.db.move = true; island:UpdateFade()
            assert(island.hiddenY == 0 and f.alpha == 1) -- unlocked is draggable
        end
    end
end
ns.db = {shape = "Attached", scale = 100}
island.hiddenY = 0; island:ApplyPosition()
assert(f.point[5] == 0) -- old saves keep their original top placement
ns.db.shape = "Pill"; island:ApplyPosition()
assert(f.point[5] == -12)
Quick = {}
ns.BeginBatch = function() end; ns.EndBatch = function() end
''')
settings = (ROOT / 'Settings/Settings.lua').read_text(encoding='utf-8-sig')
start = settings.index('local function deepCopy(')
end = settings.index('ns.ApplyProfile = applyProfile', start) + len('ns.ApplyProfile = applyProfile')
profile_source = settings[start:end]
start = settings.index('function ns.SaveProfile(')
lua.execute(profile_source + '\n' + settings[start:settings.index('\nend', start) + 4])
lua.execute('''
ns.db = {shape = "Pill", posY = 12, posX = 125, moveY = -450}
ns.SaveProfile("Moved")
ns.db.moveY = -10; ns.ApplyProfile("Moved")
assert(ns.db.moveY == -450 and ns.db.posX == 125 and ns.db.posY == 12)
ns.db.profiles.Old = {shape = "Attached", posX = 0}
ns.ApplyProfile("Old")
assert(ns.db.moveY == 0) -- older profiles do not inherit the last profile's height
''')
assert settings.count('ns.db.moveY = 0') == 2  # Classic and Quick position resets
assert 'qset("moveY", 0)' in settings  # Studio layout reset
print('PASS: Lua 5.1 free movement, both shapes, addon/UI scales, lock/release, auto-hide, profiles and resets')
