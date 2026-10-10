# Changelog

Every update to XPBar Island, in plain (and slightly caffeinated) English.

## 1.0.11: The "Now You See XP" Update

* **One last look:** The XP bar hangs out for a beat after combat, then takes a smooth 1.5-second bow. No more missing that last mob's XP!
* **Smooth entrance:** The bar fades in when combat starts instead of popping into view.
* **Cursor summon:** Hover over or near its hiding spot to bring it back. Move away and it fades away again.
* Huge thanks to **@andygoyap** for the great ideas! 🙌

## 1.0.10: The "Smooth Operator" Update

Thanks to **@gridrek** for the three fixes in this release.

* **Fixed: Kills to level counted a quest turn-in as a kill** - a big quest made the estimate collapse to about 1 kill left, because quest XP replaced the per-kill value. Only a named mob kill updates it now, and group and raid kill messages count too. (Thanks @gridrek!)
* **Fixed: one low-level mob could swing Kills to level** - the estimate now averages your last 10 kills at the current level and works the rested pool into the maths, so it stays steady and no longer doubles when rested runs out. The recent kills survive /reload and reset on level-up. (Thanks @gridrek!)
* **Fixed: the idle comet sweep was choppy** - it now steps every frame like the other pulses instead of ticking at about 15 updates per second. (Thanks @gridrek!)
* **Fixed: the level-up summary could error on clients that keep health and stat values secret** - "attempt to perform arithmetic on a secret number value" took the whole card down. A secret or missing value now drops only its own row. (GitHub issue #4 - thanks @andoys!)

## 1.0.9: The "Helping Hands" Update

Thanks to **@dstjohniii** for both fixes in this release.

* **Fixed: battleground chat taint** - the /played chat suppression no longer overrides `ChatFrame1.AddMessage`, so protected battleground join and leave messages are not blocked any more, and repeated join messages stop. (Thanks @dstjohniii!)
* **Fixed: next-spell tooltip and layout** - the "+N" spell tooltip now lists only the spells you cannot already see, and the row makes room for the `+N` badge instead of overflowing. The visible count also stays stable while the panel opens. (Thanks @dstjohniii!)

## 1.0.8: The "Your Call" Update

* **New: a "Level-up summary" toggle** (Settings > Behavior). The stats card that appears under the island when you level up can now be switched off if you only want the celebration, or kept on if you like seeing exactly what the level gave you. On by default.

## 1.0.7: The "Personal Space" Update

* **Fixed: the blue "Resting" tag could overlap "X bars to level up"** on the collapsed bar (GitHub issue #1 - thanks @andoys). The row now measures the Resting tag and the quest XP text when fitting, and drops the current / max text or shortens the bars text instead of letting them collide.

## 1.0.6: The "Fight Club" Update

* **Fixed: "No skill lines / Train a profession" on Skills even though you have professions.** The latest client update changed how skill and profession data is exposed. The island now reads every API the client offers - the classic skill lines, the new `C_SkillInfo` lines and the `C_TradeSkillUI` professions - and merges them, so your professions show up again. Nothing to sync, nothing to reload twice.
* **New: "Hide out of combat"** (Settings > Behavior). The island fades out while you are out of combat and fades back in the moment a fight starts. Handy for screenshots, roleplay, or a calmer questing HUD. "Hide in combat" now fades just as smoothly, so both options work either way round.
* **New: a level-up summary card.** Ding and a small card appears under the island with the health, mana and attribute gains for the level, plus the talent point and any spells waiting at your trainer.

## 1.0.5: The "Squash Them All" Update

**Bug fixes.**

* Fixed: XP bar showed a stray purple fill at very low XP (thanks to the CurseForge commenter who reported this).
* Fixed: "Played this level" now matches /played and survives /reload.
* Fixed: session sparkline not drawing on newer clients.
* Fixed: "Gain dip" toggle now actually turns the dip off.
* Fixed: custom island width no longer snaps back to 460 after an XP-gain peek.
* Fixed: rapid XP gains could cancel each other's flash animation.

## 1.0.4: The "WoW Forever" Update

*Status: unreleased. This is what is next.*

**Kill streaks, minus the spam.** Streaks are still off by default, but when you switch them on the tiers are fewer and further apart, so each one actually feels like an event. The ladder is now:
`TRIPLE PULL` (3) → `FACTION CRY` (5, shouts for your side) → `EXECUTE!` (8, with a class flavoured jab) → `BLOODLUST!` (12) → `LEEROY!` (16) → `ONE MAN RAID` (20) → `WORLD FIRST` (30) → `LEGENDARY` (50). The window is a tight 20 seconds, so keep pulling.

**A quieter announcement.** No more centre screen fireworks. A small banner pops in under the island, holds for a beat, and fades. No sound. It respects the Animations setting (instant on or off when set to Off) and can sit out while you are in combat.

**The tag tells you what is next.** Under the island you will see `xN` early on, then `TITLE xN` once you hit a tier, plus a little "N more to NEXT TITLE" nudge so you always know what you are chasing.

**Bug reports you can actually send.** Hit **Copy report** and a tidy popup opens with the whole report preselected. Ctrl+C, Escape, paste, done. No more wrestling a text box.

**Say hi without leaving the game.** The settings footer now has **X (Twitter)** and **CurseForge** logos. Click one, copy the link from the popup, and you are off. (Addons cannot launch a browser directly. That is a Blizzard thing, so this is the fastest route.)

**WoW Forever is the new default theme.** Fresh installs start in WoW Forever. Already picked a theme? Nothing changes. Your choice is left exactly as it was.

## 1.0.2: The "Put It Anywhere" Update

* **Move mode** finally lets you drag the island **anywhere on screen** (`/xpbar move`). Before, it could only shuffle along the top edge like it was on rails.

## 1.0.1: The "Get Out of the Way" Update

* Blizzard's default **XP and reputation bars are hidden by default**, so the island is the only progress bar you need. Works on classic era clients (`MainMenuExpBar` / `ReputationWatchBar`) and modern ones (`StatusTrackingBarManager`), and puts them straight back if you flip the option off.
* **Skills work on modern clients**: professions are read through the new `GetProfessions` / `GetProfessionInfo` API when the old skill line API is missing. No more "No skill lines / Train a profession" on Classic Forever.
* A **pin button** for the expanded panel: keep the island open, or click again to go back to hover open and close.
* The **minimap button** got a makeover: hidden by default, sits properly on the ring (scale and client aware, drag it anywhere), with a cleaner dark disk and gold rim. Find it under Settings > Social.

## 1.0.0: First Light

The debut. What shipped:

* A top centre HUD island for **Experience, Reputation, Honor, Pet Exp and Skills**.
* Switchable types with a chip row, auto switch on change, and an option to watch the reputation bar at max level.
* An expanded panel: 8 cell stat grid, reputation standing ladder (Hated → Exalted) with the current tier highlighted, session XP graph, next level spell preview, party comparison and footer.
* XP bar flair: animated fill, count up numbers, gain flash, edge glint, segment flashes, charge up glow and the kill streak tag.
* Level up celebration: flash, badge pop, expanding rings, banner and sound.
* Four themes (Default, WoW, Classic, WoW Forever) plus custom trim / bar / text accent colours and a font picker.
* Display modes: Full, Classic (thin bar), Auto hide, Always open.
* Behaviour options: Hide in combat, Fade until hovered, Hide the default XP bar, Move mode, Animations, Motion feel, Kill streak, Level up animation, Show tips.
* Party sync: see the level and XP of other players running the addon, live. Only level and XP are shared, and you can turn it off.
* Named profiles with optional per character and per spec switching, plus minimap button, movable island and scale control.
* Lightweight, pure Lua, with a working fallback for every modern API it probes.
* In game settings via `/xpbar` (also under Options → AddOns), plus a "Contact @mainlek" link in the footer.
* `/xpbar contact` opens the author's X page: https://x.com/mainlek
