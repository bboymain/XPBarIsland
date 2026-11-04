"""Targeted Lua behavior checks without a running WoW client (requires lupa)."""
from pathlib import Path
from lupa import LuaRuntime
from luaparser import ast
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
for path in ROOT.rglob('*.lua'):
    ast.parse(path.read_text(encoding='utf-8-sig'))
lua = LuaRuntime()
lua.execute('ns = { Font = function() return "font" end, HexA = function() return {1,1,1,1} end }; island = {}; f = {}; UIParent = {}')
init = (ROOT / 'Core/Init.lua').read_text()
lua.execute('local ADDON, ns = "XPBarIsland", ns\n' + init.split('-- Saved variables and defaults')[0].replace('local ADDON, ns = ...', ''))
source = (ROOT / 'UI/Island.lua').read_text()
for name in ('PillRadius', 'LayoutPill', 'CurrentScale', 'ApplyPosition', 'UpdateFade'):
    start = source.index('function island:' + name + '(')
    end = source.index('\nend', start) + 4
    lua.execute(source[start:end])
lua.execute('''
local function texture()
    return setmetatable({}, { __index = function(t, k)
        return function(_, ...) t[k .. "Args"] = {...} end
    end })
end
tex = function() return texture() end
ns.Hex = function() return 1, 1, 1 end
ns.HexA = function() return {1, 1, 1, 1} end
ns.Paint = function() end; ns.Gradient = function() end; ns.WhiteTexture = function() end
ns.Media = {cornerFill14 = "CornerFill14"}
for _, k in ipairs({"bg", "betweenFill", "borderL", "borderR", "borderB", "innerL", "innerR", "innerB", "cornerFillBL", "cornerFillBR", "cornerEdgeBL", "cornerEdgeBR"}) do island[k] = texture() end
f = texture(); f.GetHeight = function() return 60 end
island.CancelCombatHold = function() end; island.StopCombatFade = function() end
island.hoverStrip = texture()
ns.db = {enabled = true, theme = "Default", shape = "Attached", posY = 60, scale = 100, mode = "Full", animations = "Off"}
assert(not ns.PillOn() and ns.TopOffset() == 0)
island:ApplyPosition(); assert(f.SetPointArgs[5] == 0)
ns.db.theme = "Pill"; ns.db.posY = nil
assert(ns.PillOn() and ns.TopOffset() == 12)
assert(ns.Theme().bg1 == ns.Themes.Default.bg1 and ns.Theme().bw == 2)
ns.db.theme = "Classic"; ns.db.shape = "Pill"; ns.db.posY = 60
assert(ns.PillOn() and ns.Theme().bw == 3)
for _, scale in ipairs({70, 100, 150}) do
    ns.db.scale = scale; island:ApplyPosition()
    assert(math.abs(f.SetPointArgs[5] * scale / 100 + 60) < 0.001)
end
assert(island:PillRadius(true) == 30 and island:PillRadius(false) == 30)
ns.db.barThickness = 18; assert(island:PillRadius(false) == 33)
ns.db.mode = "Classic"; assert(island:PillRadius(false) == 14)
for _, thin in ipairs({false, true}) do
    island.thin = thin; island:LayoutPill(460, thin and 26 or 60)
    assert(#island.pillParts == 15)
    assert(#island.pillParts[2].SetTextureArgs == 1)
    assert(island.pillParts[2].SetTextureArgs[1] == (thin and "PillCorner1" or "PillCorner3"))
end
ns.db.mode = "Auto-hide"; ns.db.scale = 100
island:UpdateFade(); assert(island.hiddenY == 180)
assert(f.SetPointArgs[5] >= 120) -- whole pill clears the screen
island.expanded = true; island:UpdateFade(); assert(island.hiddenY == 0)
ns.db.shape = "Attached"; island:LayoutPill(460, 60)
assert(island.pillParts[1].SetShownArgs[1] == false)
''')
for width in range(4):
    image = Image.open(ROOT / 'Media' / f'PillCorner{width}.tga')
    assert image.size == (512, 512) and image.mode == 'RGBA'
print('PASS: Lua syntax, theme/shape, offsets/scaling, radii, border widths, auto-hide, skin toggle, assets')
