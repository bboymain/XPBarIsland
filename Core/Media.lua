local ADDON, ns = ...

local PATH = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

ns.Media = {
    white      = "Interface\\Buttons\\WHITE8X8",
    radial     = PATH .. "RadialDark",
    disk       = PATH .. "Disk",
    ring       = PATH .. "Ring",
    ringThick  = PATH .. "RingThick",
    gloss      = PATH .. "Gloss",
    shadow     = PATH .. "Shadow",
    stripe     = PATH .. "Stripe",
    gear       = PATH .. "Gear",
    shineBand  = PATH .. "ShineBand",

    cornerFill14 = PATH .. "CornerFill14",
    cornerEdge14 = PATH .. "CornerEdge14",

    statusBar = "Interface\\TargetingFrame\\UI-StatusBar",
    tooltipBorder = "Interface\\Tooltips\\UI-Tooltip-Border",

    -- Agent Kit - New Features (white 32-bit TGAs, tinted at runtime)
    levelupSegment = PATH .. "levelup_segment",
    levelupSpark   = PATH .. "levelup_spark",
    levelupRing    = PATH .. "levelup_ring",
    levelupSweep   = PATH .. "levelup_sweep",
    idleDot        = PATH .. "idle_dot",

    -- Social / support logos (white PNGs, tinted at runtime)
    xIcon          = PATH .. "icons\\x.png",
    curseforgeIcon = PATH .. "icons\\curseforge.png",
}

-- Flat colour a texture. Prefer SetColorTexture, fall back to a white
-- texture + vertex colour on clients that do not have it.
function ns.Paint(tex, r, g, b, a)
    if not tex then return end
    a = a or 1
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    else
        tex:SetTexture(ns.Media.white)
        tex:SetVertexColor(r, g, b, a)
    end
end

-- Vertical or horizontal gradient. Tries the modern table signature first,
-- then the legacy r,g,b triple signature, then a flat fill.
function ns.Gradient(tex, c1, c2, horizontal)
    if not tex then return end
    local o = horizontal and "HORIZONTAL" or "VERTICAL"
    if tex.SetGradient then
        local function col(c) return { r = c[1] or 1, g = c[2] or 1, b = c[3] or 1, a = c[4] or 1 } end
        local ok = pcall(tex.SetGradient, tex, o, col(c1), col(c2))
        if ok then return end
        ok = pcall(tex.SetGradient, tex, o, c1[1], c1[2], c1[3], c2[1], c2[2], c2[3])
        if ok then return end
    end
    tex:SetTexture(ns.Media.white)
    tex:SetVertexColor(c1[1], c1[2], c1[3], c1[4] or 1)
end

-- A white texture used for gradients / vertex colouring.
function ns.WhiteTexture(tex)
    if tex and tex.SetTexture then tex:SetTexture(ns.Media.white) end
    return tex
end

-- Parse "#rrggbb" into normalized r,g,b.
function ns.Hex(hex)
    if type(hex) == "table" then return hex[1], hex[2], hex[3], hex[4] end
    hex = tostring(hex or "ffffff"):gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return r / 255, g / 255, b / 255
end

function ns.HexA(hex, a)
    local r, g, b = ns.Hex(hex)
    return { r, g, b, a or 1 }
end
