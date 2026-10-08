local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Boot: load saved variables, then wire the refresh cycle once the player is
-- in the world.
-- ---------------------------------------------------------------------------
ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    ns.InitDB()
end)

function ns.RefreshUI()
    if not ns.db then return end
    if not ns.db.enabled then
        ns.island.frame:Hide()
        if ns.Tooltip then ns.Tooltip:Hide() end
        return
    end
    ns.island.frame:Show()

    local d = ns.data:Current()
    ns.island:Update(d)
    if ns.Tooltip and ns.Tooltip.shown then ns.Tooltip:Update(d) end
end

ns.On("PLAYER_LOGIN", function()
    if not ns.db then ns.InitDB() end
    if ns.session and ns.session.Restore then ns.session:Restore() end
    ns.island:Refresh()
    ns.UpdateMinimapButton()
    ns.MarkDirty()
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.island and ns.db then
        ns.island:ApplyPortrait()
        ns.island:Refresh()
    end
end)
