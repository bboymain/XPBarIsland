# KNOWN_GAPS

APIs that may not exist on every client are probed in `Core/Capabilities.lua` or wrapped in
`pcall` at the call site, with a working fallback. Nothing here throws if the API is absent.

| API / event | Where | Fallback |
| --- | --- | --- |
| `C_ChatInfo.SendAddonMessage` / `RegisterAddonMessagePrefix` | Capabilities.lua | legacy `SendAddonMessage`/`RegisterAddonMessagePrefix`; party sync disabled if neither |
| global `SetPortraitTexture` / `Texture:SetPortraitTexture` | UI/Island.lua | portrait hidden, plain dark level square shown instead (no mask used) |
| `Texture:SetColorTexture` | Core/Media.lua | `WHITE8X8` + vertex colour |
| `Texture:SetGradient` (modern table and legacy 7-arg tried) | Core/Media.lua, UI/Bar.lua | flat fill / vertex colour |
| `Texture:SetRotation` | UI/Bar.lua, UI/Panel.lua | milestone diamond / sparkline drawn unrotated |
| `Frame:SetClipsChildren` | UI/Bar.lua (shine), UI/Island.lua (mini badge) | shine band stays within the fill by construction; no clipping |
| `GetXPExhaustion` | Data/XP.lua | rested shows 0 |
| `GetQuestLogRewardXP` + `SelectQuestLogEntry` + `GetQuestLogSelection` | Data/Quests.lua | quest XP scan degrades to log counts |
| `GetWatchedFactionInfo` / `C_Reputation.GetWatchedFactionData` / `GetNumFactions`+`GetFactionInfo` | Capabilities.lua, Data/Reputation.lua | modern clients read `C_Reputation` (`currentStanding` + thresholds); if nothing is watched the view auto-picks one known faction (session-stable, all calls pcalled); only when every list API is missing does it show the empty state |
| `UnitHonor` / `UnitHonorMax` / `UnitHonorLevel` / `GetHonorLevel` | Data/Honor.lua | `GetPVPRankInfo`/`UnitPVPRank` rank; `GetPVPThisWeekStats` week honour; else honour chip hides |
| `GetPetExperience` | Data/PetXP.lua | pet type reports unavailable |
| `C_SpellBook.GetCurrentLevelSpells` (next-level spell list) | Data/Spells.lua | bundled per-class level table in `ns.classSpells`; `GetSpellInfo`/`IsSpellKnown` wrapped in pcall, unknown IDs skipped |
| `RequestTimePlayed` | Data/XP.lua | played values show `--` |
| `InCombatLockdown` / combat events | Core/Events.lua | combat hiding skipped |
| `C_Timer` | Core/Capabilities.lua | OnUpdate scheduler in Core/Util.lua |
| `IsInGroup` / `IsInRaid` / group counts | Core/Capabilities.lua, Core/Comms.lua | chain of checks; sharing falls back to `/say` |
| unknown event names | Core/Events.lua | `RegisterEvent` wrapped in `pcall`; skipped |
| `Settings.RegisterCanvasLayoutCategory` | Settings/Settings.lua | legacy `InterfaceOptions_AddCategory`; else standalone themed window |
| `Settings.OpenToCategory` | Settings/Settings.lua | `InterfaceOptionsFrame_OpenToCategory` |
| `SOUNDKIT.UI_LEVELUP` | UI/LevelUp.lua | legacy `PlaySound("LEVELUP")` |
| Alegreya Sans (from `Media/Fonts/`, load-tested once) | Core/Fonts.lua | FRIZQT fallback if unavailable; `/xpbar` prints `font ok`/`font fallback` |
| `ToggleCharacter` / `TogglePVPUI` | UI/Tooltip.lua | clickable rep/honor links do nothing |

## Notes

- The game-accurate look uses no `Media/Glow.tga`, `Media/Shadow.tga` or `Media/BottomFade.tga`
  (badge glow, bar glint glow, minimap highlight glow, drop shadow and bottom fade have been
  removed). The TGA files are still shipped but unused.
- The XP bar animation spec was written for "XPBar Island"; it is implemented here for
  **XPBar Island**, reading `XPBarIslandDB.profile.animations`.
