local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Base colour tokens (used by every theme)
-- ---------------------------------------------------------------------------
ns.Colors = {
    gray       = ns.HexA("#9D9D9D"),
    grayDim    = ns.HexA("#8F8777"),
    white      = ns.HexA("#FFFFFF"),
    green      = ns.HexA("#1EFF00"),
    inner      = ns.HexA("#2A1F0E"),
    divider    = ns.HexA("#4A3A1C"),
    goldRule   = ns.HexA("#8A6A2C"),
    bgTop      = ns.HexA("#17120C"),
    bgBottom   = ns.HexA("#0D0B08"),
    barBG      = ns.HexA("#050403"),
    rested     = ns.HexA("#1A6FE0"),
    restTag    = ns.HexA("#4D9BFF"),
    quest      = ns.HexA("#E0A800"),
    xp         = { ns.HexA("#B02AD0"), ns.HexA("#7A1496") },
    rep        = { ns.HexA("#22C43C"), ns.HexA("#0F7A22") },
    honor      = { ns.HexA("#FF9A2E"), ns.HexA("#C25A00") },
    pet        = { ns.HexA("#5DB4FF"), ns.HexA("#1F6FB8") },
    skills     = { ns.HexA("#3FE0CC"), ns.HexA("#1B8F80") },
}

-- Four themes.  Every theme-dependent colour lives here; UI files read
-- ns.Theme() and never test the theme name.  "Default" reproduces the original
-- look exactly.  font stays Alegreya/UI Sans for readability in every theme.
ns.ThemeList = { "Default", "WoW", "Classic", "WoW Forever" }

-- WoW theme XP-bar colour variants (db.wowBar).  Each is a 4-stop vertical
-- gradient plus the rgb used for its outer glow.
ns.WowBars = {
    Azure  = { c = { "#D9FBFF", "#6FE3FF", "#1FA8E8", "#0D5FB0" }, glow = { 60 / 255, 190 / 255, 255 / 255 } },
    Violet = { c = { "#E4CDFF", "#A875FF", "#6A35E0", "#3E1A9C" }, glow = { 130 / 255, 90 / 255, 255 / 255 } },
    Gold   = { c = { "#FFF3B0", "#FFD24A", "#E09A14", "#A35A08" }, glow = { 255 / 255, 200 / 255, 60 / 255 } },
}

ns.Themes = {
    ["Default"] = {
        bg1 = "#17120C", bg2 = "#0D0B08", trim = "#6F5326", ring = "#B08A3E", gold = "#FFD100", bw = 2,
        grey = "#8F8777", dim = "#9D9D9D", inner = "#2A1F0E", rule = "#8A6A2C",
        rested = "#1A6FE0", restTag = "#4D9BFF",
        barXP1 = "#B02AD0", barXP2 = "#7A1496",
        barRep1 = "#22C43C", barRep2 = "#0F7A22",
        barHonor1 = "#FF9A2E", barHonor2 = "#C25A00",
        barPet1 = "#5DB4FF", barPet2 = "#1F6FB8",
        track = "#050403", groove = "#0C0016", grooveA = 0.5,
        glint = "#FFF6C8", flash = "#FFF2B8", spark = "#FFD100", comet = "#FFFFFF",
        barRing = "#4A3B1C",
        btn1 = "#1A150E", btn2 = "#0C0A08", btnText = "#ECE6D8", btnRing = "#6F5326",
        btnPrimary1 = "#7A5A16", btnPrimary2 = "#3A2C12",
        pillOn1 = "#3A2C12", pillOn2 = "#1A1409", pillText = "#FFD100", pillOff = "#9D9D9D",
        switchOn = "#FFD100", switchOff = "#6B6354", switchTrack1 = "#5A431A", switchTrack2 = "#2A1D09",
        graph1 = "#8A3FA8", graph2 = "#FFD100", area = "#B02AD0",
        font = ns.Font("bold"),
    },
    ["WoW Forever"] = {
        bg1 = "#10302F", bg2 = "#2B2218", trim = "#B08D57", ring = "#E0C48A", gold = "#F3E2B3", bw = 2,
        grey = "#A89F8A", dim = "#A89F8A", inner = "#3A2C1A", rule = "#8A6A3A",
        rested = "#2AA59A", restTag = "#7FD6CB",
        barXP1 = "#F9D878", barXP2 = "#C4791A",
        barRep1 = "#8FE3B4", barRep2 = "#2F8F6A",
        barHonor1 = "#F0A95A", barHonor2 = "#A8571A",
        barPet1 = "#8AD3E0", barPet2 = "#2B7F99",
        track = "#050403", groove = "#301800", grooveA = 0.55,
        glint = "#FFF6C8", flash = "#FFE9A8", spark = "#FFD100", comet = "#FFF6C8",
        barRing = "#8A6A3A",
        btn1 = "#B5503A", btn2 = "#7A2A1C", btnText = "#F3E2B3", btnRing = "#E0C48A",
        btnPrimary1 = "#B5503A", btnPrimary2 = "#7A2A1C",
        pillOn1 = "#A8432F", pillOn2 = "#7A2A1C", pillText = "#F3E2B3", pillOff = "#B9AE98",
        switchOn = "#F3E2B3", switchOff = "#6B6454", switchTrack1 = "#5A431A", switchTrack2 = "#2A1D09",
        graph1 = "#2F8F82", graph2 = "#FFD100", area = "#2AA59A",
        font = ns.Font("bold"),
    },
    ["Classic"] = {
        bg1 = "#3A2916", bg2 = "#1E140B", trim = "#9A7440", ring = "#D6A95A", gold = "#F5D98A", bw = 3,
        grey = "#B3A68A", dim = "#B3A68A", inner = "#2A1F0E", rule = "#8A6A2C",
        rested = "#1A6FE0", restTag = "#4D9BFF",
        barXP1 = "#B08CFF", barXP2 = "#4A1FA0",
        barRep1 = "#5BD65B", barRep2 = "#1A7A1A",
        barHonor1 = "#E06A3A", barHonor2 = "#8A2A10",
        barPet1 = "#6FB0F0", barPet2 = "#1F5F9F",
        track = "#160D06", groove = "#281900", grooveA = 0.6,
        glint = "#FFF0B8", flash = "#FFE9A8", spark = "#FFD100", comet = "#FFF0B8",
        barRing = "#4A3B1C",
        btn1 = "#A3231A", btn2 = "#5C0F0A", btnText = "#F5D98A", btnRing = "#D6A95A",
        btnPrimary1 = "#A3231A", btnPrimary2 = "#5C0F0A",
        pillOn1 = "#8F2A1C", pillOn2 = "#52120B", pillText = "#F5D98A", pillOff = "#B3A68A",
        switchOn = "#F5D98A", switchOff = "#6B6454", switchTrack1 = "#5A431A", switchTrack2 = "#2A1D09",
        graph1 = "#966432", graph2 = "#FFD100", area = "#A8793A",
        font = ns.Font("bold"),
    },
    ["WoW"] = {
        bg1 = "#101A2B", bg2 = "#070C15", trim = "#8D7A3F", ring = "#D9B45A", gold = "#FFD100", bw = 1,
        grey = "#9AA8BD", dim = "#9AA8BD", inner = "#22304A", rule = "#8D7A3F",
        rested = "#3A8CFF", restTag = "#7FD6FF",
        barXP1 = "#D9FBFF", barXP2 = "#6FE3FF", barXP3 = "#1FA8E8", barXP4 = "#0D5FB0",
        barRep1 = "#6FE0A0", barRep2 = "#1F8A55",
        barHonor1 = "#FFB25A", barHonor2 = "#C25A00",
        barPet1 = "#7FE0F0", barPet2 = "#1F8AB0",
        track = "#060A14", groove = "#040A23", grooveA = 0.6,
        glint = "#EAF6FF", flash = "#FFE9A8", spark = "#FFD100", comet = "#EAF3FF",
        barRing = "#42557A", barGlow = { 60 / 255, 190 / 255, 255 / 255 },
        rim = true, shade = true, halo = { 150 / 255, 215 / 255, 255 / 255 },
        btn1 = "#3F7FCF", btn2 = "#1B3F78", btnText = "#FFD100", btnRing = "#FFD100",
        btnPrimary1 = "#3F7FCF", btnPrimary2 = "#1B3F78",
        pillOn1 = "#2F6FB8", pillOn2 = "#173A6E", pillText = "#FFD100", pillOff = "#9AA8BD",
        switchOn = "#FFD100", switchOff = "#6B7280", switchTrack1 = "#1B2740", switchTrack2 = "#0C1424",
        graph1 = "#4678BE", graph2 = "#FFD100", area = "#3A7FD0",
        font = ns.Font("bold"),
    },
}

function ns.Theme()
    local name = (ns.db and ns.db.theme) or "WoW Forever"
    local t = ns.Themes[name] or ns.Themes["WoW Forever"]
    local th = {}
    for k, v in pairs(t) do th[k] = v end
    th.name = name
    if ns.db then
        if ns.db.trimColor then th.trim = ns.db.trimColor; th.ring = ns.db.trimColor end
        if ns.db.textAccent then th.gold = ns.db.textAccent end
        if name == "WoW" and not ns.db.barColor then
            local vb = ns.WowBars[ns.db.wowBar or "Azure"] or ns.WowBars.Azure
            th.barXP1, th.barXP2, th.barXP3, th.barXP4 = vb.c[1], vb.c[2], vb.c[3], vb.c[4]
            th.barGlow = vb.glow
        end
    end
    return th
end

-- ---------------------------------------------------------------------------
-- Saved variables and defaults
-- ---------------------------------------------------------------------------
ns.defaults = {
    enabled      = true,
    theme        = "WoW Forever",
    mode         = "Full",          -- Full | Classic | Auto-hide | Always open
    scale        = 100,
    hoverExpand  = false,
    types        = { xp = true, rep = true, honor = true, pet = true, skills = true },
    hideCombat   = false,
    fade         = false,           -- fade until hovered
    hideBlizzXp  = true,            -- hide Blizzard's XP/rep bars, use the island instead
    compact      = true,
    autoSwitch   = true,
    repAtMax     = false,
    portrait     = true,
    move         = false,
    party        = true,
    sparkline    = true,
    questList    = true,
    shareChannel = "Party",         -- Party | Guild | Say
    animations   = "Always",        -- Always | On hover only | Off
    feel         = "Springy",       -- Springy | Snappy | Smooth
    preset       = "Custom",
    activeType   = "xp",
    posX         = 0,
    posY         = 0,
    minimap      = { hide = true, angle = 220 },   -- minimap button hidden by default
    v1           = false,           -- hidden Version 1 view (/xpbar v1)
    -- Quick panel
    settingsUi   = "Studio",        -- Studio | Quick | Classic
    cometOn      = true,
    barFx        = "Comet",         -- Comet | Flow | Shine (idle effect on the XP fill)
    segFlash     = true,
    charge       = true,
    barsText     = true,
    streak       = false,
    dip          = true,
    partyMotion  = true,
    tips         = true,
    levelUpFx    = true,            -- Agent Kit: Supernova level-up animation
    -- thin (Minimal) bar
    mLevel       = true, mName = true, mPct = true, mBars = true, mGain = true,
    mStreak      = true, mRested = true, mRate = false, mEta = false,
    -- layout switches
    showName     = true, showRange = true, showPercent = true,
    showRested   = true, showRate = true, showDots = true,
    -- customize
    trimColor    = false, barColor = false, textAccent = false,   -- false = Auto
    wowBar       = "Azure",         -- WoW theme XP bar: Azure | Violet | Gold
    width        = 460, barThickness = 12, textSize = 100, posOffset = 0,
    font         = "Theme", speed = 100, strength = 100,
    profiles     = { Default = {} }, profile = "Default",
    switchPerChar = false, switchPerSpec = false,
}

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.CopyDefaults = copyDefaults

function ns.WarnSafeMode()
    if ns._safeModeWarned then return end
    ns._safeModeWarned = true
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100XPBar Island|r: a saved setting was broken and was reset. /xpbar report to send details.")
    end
end

function ns.InitDB()
    if type(XPBarIslandDB) ~= "table" then XPBarIslandDB = {} end
    local DB = XPBarIslandDB

    -- migrate a flat (pre-profile) save into DB.profile
    if type(DB.profile) ~= "table" then
        local profile = {}
        for k, v in pairs(DB) do
            if k ~= "char" and k ~= "profile" then
                profile[k] = v
                DB[k] = nil
            end
        end
        DB.profile = profile
    end
    if type(DB.char) ~= "table" then DB.char = {} end

    ns.db = DB.profile
    -- the kill streak setting was renamed from streakOn to streak
    if ns.db.streak == nil and ns.db.streakOn ~= nil then ns.db.streak = ns.db.streakOn end
    ns.db.streakOn = nil

    -- Safe mode: loading the profile must never leave the island blank.
    local loaded = pcall(copyDefaults, ns.db, ns.defaults)
    if not loaded then
        ns.db = {}
        copyDefaults(ns.db, ns.defaults)
        DB.profile = ns.db
        ns.WarnSafeMode()
    end

    -- Reset only the keys whose saved type does not match the default.
    if type(ns.db.backup) ~= "table" then ns.db.backup = {} end
    local broken = 0
    for k, def in pairs(ns.defaults) do
        local v = ns.db[k]
        if v ~= nil and type(v) ~= type(def) then
            ns.db.backup[k] = v
            ns.db[k] = def
            broken = broken + 1
        end
    end
    if broken > 0 then ns.WarnSafeMode() end

    ns.db.accent = nil
    -- one-time: "Expand on hover" now defaults off
    if ns.db.hoverExpand == true and ns.db.hoverExpandMigrated == nil then
        ns.db.hoverExpand = false
    end
    ns.db.hoverExpandMigrated = true
    -- one-time: the default settings UI is now the Studio window
    if ns.db.settingsUi == "Quick" and ns.db.settingsUiMigrated == nil then
        ns.db.settingsUi = "Studio"
    end
    ns.db.settingsUiMigrated = true
    -- one-time: the island now stays visible in combat by default; users who
    -- want it to fade while fighting can turn "Hide in combat" back on.
    if ns.db.hideCombatMigrated == nil then
        ns.db.hideCombatMigrated = true
        ns.db.hideCombat = false
    end
    -- one-time: hide Blizzard's default XP and reputation bars by default so the
    -- island is the only progress bar; users can switch it back off in Settings.
    if ns.db.hideBlizzXpMigrated == nil then
        ns.db.hideBlizzXpMigrated = true
        ns.db.hideBlizzXp = true
    end
    -- one-time: the minimap button is now hidden by default (it can be turned
    -- back on under Settings > Social).
    if ns.db.minimapHideMigrated == nil then
        ns.db.minimapHideMigrated = true
        ns.db.minimap = ns.db.minimap or {}
        ns.db.minimap.hide = true
    end
    -- one-time: an old save can have the Reputation and Pet bars switched off,
    -- and with them off no chip appears at all.  They are core to the island
    -- (the mockup always offers them), so restore them unless the XP-only
    -- Minimal preset is deliberately selected.
    if ns.db.typesRepPetMigrated == nil then
        ns.db.typesRepPetMigrated = true
        if ns.db.preset ~= "Minimal" and type(ns.db.types) == "table" then
            if not ns.db.types.xp then ns.db.types.xp = true end
            ns.db.types.rep = true
            ns.db.types.pet = true
        end
    end
    -- enforce the progress-type rules on login
    if ns.data and ns.data.Sanitize then ns.data:Sanitize() end

    local name = UnitName("player") or "Player"
    local realm = GetRealmName and GetRealmName() or "Realm"
    local key = name .. "-" .. realm
    ns.charKey = key
    ns.char = DB.char[key]
    if type(ns.char) ~= "table" then
        ns.char = { levelTimes = {} }
        DB.char[key] = ns.char
    end
    if type(ns.char.levelTimes) ~= "table" then ns.char.levelTimes = {} end
end

function ns.Set(key, value)
    if ns.db then ns.db[key] = value end
end

function ns.Get(key)
    if ns.db then return ns.db[key] end
end

-- ---------------------------------------------------------------------------
-- UI refresh notification.  Panels/widgets subscribe to this.
-- ---------------------------------------------------------------------------
ns.listeners = {}

function ns.OnUpdateLayout(fn)
    ns.listeners[#ns.listeners + 1] = fn
end

function ns.Notify()
    -- during a batch, listeners run once when the batch ends
    if ns.BatchActive and ns.BatchActive() then return end
    for i = 1, #ns.listeners do
        pcall(ns.listeners[i])
    end
end

-- Timestamp of the last data change, used by the panel footer ("Updated Ns ago").
ns.lastUpdate = GetTime()
function ns.TouchData()
    ns.lastUpdate = GetTime()
end
