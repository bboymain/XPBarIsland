local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Milestones shown in the expanded footer ("Lv 14: new spell").  Edit freely.
-- Keyed by level; the footer shows the next entry above the player's level.
-- ---------------------------------------------------------------------------
ns.milestones = {
    [10] = "new talent tier",
    [12] = "new ability",
    [14] = "new spell",
    [16] = "new armor type",
    [20] = "mount",
    [30] = "new ability",
    [40] = "mount",
    [50] = "new ability",
    [60] = "new ability",
}

function ns.NextMilestone(level)
    local best
    for lvl in pairs(ns.milestones) do
        if lvl > level and (not best or lvl < best) then best = lvl end
    end
    return best
end

function ns.Milestone(level)
    local best = ns.NextMilestone(level)
    if best then return "Lv " .. best .. ": " .. ns.milestones[best] end
    return "Max level"
end

-- The next spell level plus the spells unlocked there, and the next big
-- milestone reward shown in gray after the chips.
function ns.MilestoneData(level)
    local spellLevel = ns.NextSpellLevel and ns.NextSpellLevel(level)
    local spells = (spellLevel and ns.SpellsForLevel and ns.SpellsForLevel(spellLevel)) or {}
    -- the next big reward AFTER the spell level, so it does not repeat the tag
    local reward = spellLevel and ns.Milestone(spellLevel) or ns.Milestone(level)
    return {
        level = spellLevel,
        text = reward,
        reward = reward,
        spells = spells,
    }
end
