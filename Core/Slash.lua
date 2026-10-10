local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Slash commands: /xpbar and /xpbarisland
-- ---------------------------------------------------------------------------
local function print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100XPBar Island|r: " .. tostring(msg))
    end
end

local function handler(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
        print(ns.fontOK and "font ok" or "font fallback - check Media/Fonts")
        ns.ToggleSettings()
    elseif msg == "reset" then
        ns.session:Reset()
        print("session reset")
    elseif msg == "share" then
        ns.Share()
    elseif msg == "party" then
        local list = ns.comms:List()
        if #list == 0 then print("no party data") end
        for _, m in ipairs(list) do
            print(string.format("%s  Lv %d  %d/%d", m.name, m.level or 0, m.xp or 0, m.xpMax or 0))
        end
    elseif msg == "fakeparty" then
        ns.db.party = true
        if ns.data and ns.data.SetActive then ns.data:SetActive("xp") end
        ns.comms:FillFake()
        ns.TouchData()
        ns.Notify(); ns.MarkDirty()
        print(("filled four fake members (party=%s, members=%d) - hover the island to see them")
            :format(tostring(ns.db.party), #ns.comms:List()))
    elseif msg == "testlevelup" then
        ns.PlayLevelUp(UnitLevel("player") or 1)
        if ns.TestLevelUpSummary and ns.TestLevelUpSummary() then
            print("sample level-up stats preview (no character stats changed)")
        else
            print("enable Level-up animation and Level-up summary to preview stats")
        end
    elseif msg == "testxp" then
        ns.TestXPGain(1200)
        print("faked a 1,200 XP gain")
    elseif msg == "move" then
        ns.db.move = not ns.db.move
        print("move mode " .. (ns.db.move and "on" or "off"))
    elseif msg == "font" then
        print(ns.fontOK and "font ok" or "font fallback - check Media/Fonts")
    elseif msg == "studio" then
        ns.db.settingsUi = "Studio"
        print("settings UI: Studio")
        ns.CloseSettings()
        ns.OpenSettings()
    elseif msg == "quick" then
        ns.db.settingsUi = "Quick"
        print("settings UI: Quick")
        ns.CloseSettings()
        ns.OpenSettings()
    elseif msg == "classic" then
        ns.db.settingsUi = "Classic"
        print("settings UI: Classic")
        ns.CloseSettings()
        ns.OpenSettings()
    elseif msg == "selftest" then
        if ns.SelfTestSettings then ns.SelfTestSettings() else print("selftest unavailable") end
    elseif msg == "teststreak" then
        ns.TestStreak(20)
        print("simulating 20 kills, 0.4s apart")
    elseif msg == "testsamples" then
        local total, level = 0, UnitLevel("player") or 1
        ns.session.samples = {}
        for i = 1, 8 do
            total = total + ((i == 4) and 2500 or 600)
            ns.session.samples[i] = { t = total, level = level }
            if i == 5 then level = level + 1 end
        end
        ns.session.gain = total
        ns.session.start = GetTime() - 240
        if ns.island then
            ns.island._seenGain = total
            ns.island._gainAt = GetTime()
            if ns.island.Update and ns.data then ns.island:Update(ns.data:Current()) end
        end
        ns.MarkDirty()
        print("seeded 8 graph samples - hover the island")
    elseif msg == "v1" then
        ns.db.v1 = not ns.db.v1
        print("Version 1 view " .. (ns.db.v1 and "on" or "off"))
        ns.Notify()
        ns.MarkDirty()
    elseif msg == "contact" then
        print("opening " .. tostring(ns.CONTACT_HANDLE) .. " - " .. tostring(ns.CONTACT_URL))
        ns.OpenContact()
    elseif msg == "report" then
        ns.ShowReport(false)
    elseif msg == "report errors" then
        ns.ShowReport(true)
    elseif msg == "clear errors" then
        ns.ClearErrors()
        print("cleared captured errors")
    elseif msg == "testerror" then
        ns.TestError()
    elseif msg == "perf on" then
        ns.SetPerf(true)
    elseif msg == "perf off" then
        ns.SetPerf(false)
    elseif msg == "reset all" then
        ns.ResetEverything()
    elseif msg == "safe" then
        ns.SafeMode()
    elseif msg == "debug" then
        local d = ns.data:Current()
        print("type=" .. tostring(d and d.key) .. " xp=" .. tostring(d and d.cur) .. "/" .. tostring(d and d.max))
        print("rate=" .. tostring(d and d.rate) .. " members=" .. tostring(#ns.comms:List()))
        print("sparkline=" .. tostring(ns.db and ns.db.sparkline) .. " v1=" .. tostring(ns.db and ns.db.v1) ..
            " samples=" .. tostring(#((ns.session and ns.session.samples) or {})) ..
            " sparkShown=" .. tostring(ns.panel and ns.panel.spark and ns.panel.spark:IsShown()))
        if ns.island then
            print("thin=" .. tostring(ns.island.thin) .. " expanded=" .. tostring(ns.island.expanded))
            print("scale=" .. string.format("%.3f", ns.island._appliedScale or (ns.island.frame and ns.island.frame:GetScale()) or 1))
            print("refreshes last second=" .. tostring(ns.island.RefreshCountLastSecond and ns.island:RefreshCountLastSecond() or 0))
        end
        if ns.PerfPrint then ns.PerfPrint() end
    else
        print("commands: reset, reset all, share, party, fakeparty, testlevelup, testxp, teststreak, testsamples, move, font, v1, debug, report, report errors, clear errors, testerror, perf on, perf off, safe, contact")
    end
end

SLASH_XPBARISLAND1 = "/xpbar"
SLASH_XPBARISLAND2 = "/xpbarisland"
SLASH_XPBARISLAND3 = "/xpbi"
SlashCmdList["XPBARISLAND"] = handler
