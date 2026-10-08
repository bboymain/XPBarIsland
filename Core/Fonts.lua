local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- UI font.  Primary is a heavy system face (Open Sans ExtraBold/Bold/Medium,
-- copied into Media/Fonts as UIFont-*), with the shipped Alegreya Sans as the
-- fallback, then Fonts\FRIZQT__.TTF.  Every FontString is styled through
-- ns.StyleText so the font + shadow rule lives in one place.
-- ---------------------------------------------------------------------------
local PATH = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Fonts\\"
local FALLBACK = "Fonts\\FRIZQT__.TTF"

local CANDIDATES = {
    bold      = { PATH .. "UIFont-Bold.ttf", PATH .. "AlegreyaSans-Bold.ttf" },
    medium    = { PATH .. "UIFont-Medium.ttf", PATH .. "AlegreyaSans-Medium.ttf", PATH .. "AlegreyaSans-Bold.ttf" },
    extrabold = { PATH .. "UIFont-ExtraBold.ttf", PATH .. "AlegreyaSans-ExtraBold.ttf", PATH .. "AlegreyaSans-Bold.ttf" },
}

-- Load-test a font path with a hidden FontString.  A bad asset raises on this
-- client; on success the return value is unreliable (some clients return
-- nothing, some return false), so only the pcall result matters.
local function loads(path)
    local fs = UIParent and UIParent:CreateFontString(nil, "BACKGROUND")
    if not fs then return false end
    local ok = pcall(fs.SetFont, fs, path, 12, "")
    fs:Hide()
    return ok
end

local resolved = {}
local function resolve(key)
    if not resolved[key] then
        local list = CANDIDATES[key]
        local font = FALLBACK
        for i = 1, #list do
            if loads(list[i]) then font = list[i]; break end
        end
        resolved[key] = font
    end
    return resolved[key]
end

-- Test bold once at load; if it fails, everything uses FRIZQT.
ns.fontOK = loads(CANDIDATES.bold[1]) or loads(CANDIDATES.bold[2])

function ns.Font(weight)
    if not ns.fontOK then return FALLBACK end
    if weight == "medium" then return resolve("medium") end
    if weight == "extrabold" then return resolve("extrabold") end
    return resolve("bold")
end

-- The single font application point.  No outline and no shadow (the outline /
-- drop shadow read as a black border around the glyphs).
function ns.StyleText(fs, size, weight, flags)
    if not fs then return fs end
    local font = ns.Font(weight)
    local choice = ns.db and ns.db.font
    if choice == "Friz" then font = "Fonts\\FRIZQT__.TTF"
    elseif choice == "Morpheus" then font = "Fonts\\MORPHEUS.TTF" end
    local sc = ((ns.db and ns.db.textSize) or 100) / 100
    if sc ~= 1 then size = math.max(1, size * sc) end
    local ok = pcall(fs.SetFont, fs, font, size, "")
    if not ok and font ~= FALLBACK then
        pcall(fs.SetFont, fs, FALLBACK, size, "")
    end
    pcall(fs.SetShadowColor, fs, 0, 0, 0, 0)
    pcall(fs.SetShadowOffset, fs, 0, 0)
    return fs
end
