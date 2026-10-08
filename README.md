# XPBar Island

A standalone World of Warcraft addon (Classic-era client, `Interface: 16001`) that shows
experience, reputation, honor, pet experience and skills in one "island" flush to the top
centre of the screen. Built from scratch for the Live mockup: no other
addon is required and no other addon's code, strings or art is used.

Pure Lua, no XML, no build step. The art shipped is the small 32-bit power-of-two TGAs in
`Media/` (rounded corners, gloss, ring, disk, caution stripes, gear) plus the TTFs in
`Media/Fonts/`: Open Sans Bold/ExtraBold/Medium (shipped as `UIFont-*`) as the primary face
and Alegreya Sans as the fallback, with a final fallback to the game's `Fonts\FRIZQT__.TTF`.
The progress-bar texture comes from the game client (`Interface\TargetingFrame\UI-StatusBar`).

The bundled fonts are third-party open fonts and keep their own licences. Alegreya Sans and
Open Sans Medium are SIL OFL 1.1 (`Media/Fonts/OFL.txt`); Open Sans Bold and ExtraBold are
Apache License 2.0 (`Media/Fonts/LICENSE-OpenSans-Apache-2.0.txt`). See
`Media/Fonts/CREDITS.txt` for the per-file attribution.

## Install

1. Close the game.
2. Copy the `XPBarIsland` folder into:
   `World of Warcraft\_classic_beta_\Interface\AddOns\`
   (use whatever client folder you run; the folder name must stay `XPBarIsland`).
3. Start the game and enable **XPBar Island** on the character screen (AddOns button).
4. Optional: `/console scriptErrors 1` before logging in to see any Lua error in chat.

Settings are stored in the `XPBarIslandDB` saved variable: `XPBarIslandDB.profile`
holds the account-wide settings and `XPBarIslandDB.char` holds per-character data.
Old flat saves are migrated automatically.

The settings page registers under **Options → AddOns → XPBar Island** when the client
provides the options API; otherwise it opens in a themed standalone window. `/xpbar`,
the gear on the island and the minimap button all open it.

## Use

| Action | Result |
| --- | --- |
| Mouse over the island | Expands (springy tween) with the full panel |
| Click the island | Pins the panel open / unpins it |
| Shift-click the island | Posts your progress to the share channel |
| Click a type chip | Switches between Experience, Reputation, Honor, Pet Exp, Skills |
| Gear button on the island | Opens the settings window |
| Minimap button, left-click | Opens the settings window |
| Minimap button, right-click | Toggles move mode (drag the island sideways) |
| `/xpbar` | Opens the settings window |
| `/xpbar reset` | Resets session counters (xp/hr, session totals) |
| `/xpbar share` | Posts your progress to chat |
| `/xpbar party` | Prints the stored party members |
| `/xpbar fakeparty` | Fills three fake members to preview the party section |
| `/xpbar testlevelup` | Plays the level-up animation |
| `/xpbar move` | Toggles move mode |
| `/xpbar font` | Prints `font ok` or `font fallback` |
| `/xpbar debug` | Prints the current data |

## Layout

```
XPBarIsland/
  XPBarIsland.toc
  Core/      Capabilities, Media, Fonts, Util, Init, Events, Comms, Share, Slash, Boot
  Data/      XP + session, Quests, Reputation, Honor, PetXP, Skills, Data (assembler)
  UI/        Bar, Island, Panel, Gain, LevelUp, Tooltip, Minimap
  Settings/  Widgets, Settings
  Locale/    enUS.lua
  Media/     32-bit TGA textures
```

## Guarded APIs (may be missing on this client)

Every API is probed in `Core/Capabilities.lua` (or wrapped in `pcall` at the call site) and
has a working fallback:

| API / event | Fallback |
| --- | --- |
| `C_ChatInfo.SendAddonMessage` / `RegisterAddonMessagePrefix` | legacy globals; comms disabled if neither exists |
| `GetXPExhaustion` | rested shows 0 |
| `GetQuestLogRewardXP` + `SelectQuestLogEntry` + `GetQuestLogSelection` | quest XP scan degrades to a log count |
| `GetWatchedFactionInfo` | reputation type reports "No watched faction" |
| `UnitHonor` / `UnitHonorMax` / `UnitHonorLevel` / `GetHonorLevel` / `UnitPVPRank` | honor chip hidden if none exist |
| `GetPetExperience` | pet type reports "No active pet" |
| `RequestTimePlayed` | played values show `--` |
| `Texture:SetColorTexture` | flat colours via `WHITE8X8` + vertex colour |
| `Texture:SetGradient` (both signatures tried) | flat fill |
| global `SetPortraitTexture` / `Texture:SetPortraitTexture` | portrait falls back to a plain dark level square (no mask) |
| `Texture:SetRotation` | milestone diamond / sparkline drawn unrotated |
| `Frame:SetClipsChildren` | panel pieces stay inside during the grow tween; skipped if absent |
| `InCombatLockdown` | combat hiding skipped |
| `C_Timer` | OnUpdate scheduler in `Core/Util.lua` |
| `IsInGroup` / `IsInRaid` / `GetNumGroupMembers` / `GetNumPartyMembers` / `GetNumRaidMembers` | chain of checks; sharing falls back to `/say` |
| unknown event names | `RegisterEvent` wrapped in `pcall`; skipped instead of erroring |
| `SOUNDKIT.UI_LEVELUP` | legacy `PlaySound("LEVELUP")` |

## Textures (Media/)

All 32-bit uncompressed, power-of-two where applicable.

| File | Size | Depth |
| --- | --- | --- |
| CornerEdge14.tga | 14x14 | 32-bit |
| CornerFill14.tga | 14x14 | 32-bit |
| Disk.tga | 64x64 | 32-bit |
| Gear.tga | 32x32 | 32-bit |
| Gloss.tga | 8x64 | 32-bit |
| RadialDark.tga | 64x64 | 32-bit |
| Ring.tga | 64x64 | 32-bit |
| RingThick.tga | 64x64 | 32-bit |
| Shadow.tga | 128x64 | 32-bit |
| ShineBand.tga | 32x8 | 32-bit |
| Stripe.tga | 16x16 | 32-bit |
| idle_dot.tga | 16x16 | 32-bit |
| levelup_ring.tga | 128x128 | 32-bit |
| levelup_segment.tga | 32x16 | 32-bit |
| levelup_spark.tga | 16x16 | 32-bit |
| levelup_sweep.tga | 128x32 | 32-bit |

The extra Alegreya weights and the unused drop-fade / star / glow / portrait-mask /
20px-corner / heartbeat textures were removed for the release build.

## Contact

Need help or have a suggestion? Reach me on X (Twitter): **@mainlek** —
<https://x.com/mainlek>. The same link is in **Settings -> Help -> Contact @mainlek**
and via `/xpbar contact`.

## Party sync

Original protocol, written from scratch: prefix `XPBI1`, one message
`v1:level:xp:xpMax:rested:classToken`, at most one per 5s plus a 15s heartbeat. Only level
and XP leave the client. Members without the addon are still listed by class colour and level.
