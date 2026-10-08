local ADDON, ns = ...

-- English strings. Other locales can be added later with the same keys.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L

L["Experience"]      = "Experience"
L["Reputation"]      = "Reputation"
L["Honor"]           = "Honor"
L["Pet Exp"]         = "Pet Experience"
L["Skills"]          = "Skills"
-- short keys used for the switchable type chips
L["xp"]              = "Experience"
L["rep"]             = "Reputation"
L["honor"]           = "Honor"
L["pet"]             = "Pet Exp"
L["skills"]          = "Skills"
L["Resting"]         = "Resting"
L["Options"]         = "Options"
L["AddOns"]          = "AddOns"
L["Progress"]        = "Progress"
L["Pace"]            = "Pace"
L["Compared with You"] = "Compared with you"
L["Shift-Click to Share"] = "Shift-Click to Share"
L["Click to open"]   = "Click to open"
L["No watched faction"] = "No watched faction"
L["No active pet"]   = "No active pet"
L["unavailable"]     = "unavailable"
