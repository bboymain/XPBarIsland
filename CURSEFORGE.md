# XPBar Island — CurseForge Submission Pack

## 1. Project name (recommended)

**XPBar Island**  (slug: `xpbar-island`)

Note: the first pick, **XP Island** (slug `xp-island`), is already taken by a
different WoW addon (curseforge.com/wow/addons/xp-island). Submit as **XPBar
Island** — the slug `xpbar-island` was checked on 2026-10-06 and is still free.
**XPBar Island** keeps the island brand *and* adds the literal highest-volume
search phrase **"XP bar"**, so it is arguably even more searchable.

Why: brandable, memorable, and keyword-rich. "Island" matches exactly what the addon
looks like (a single HUD islet floating flush to the top of the screen), and "XPBar"
is what players type into search. The summary + description carry the other terms
("experience", "leveling", "reputation", "honor", "HUD").

If `xpbar-island` is also taken, try these in order:
- **Island XP** (`island-xp`) — softer, more brandable.
- **XP Isle** (`xp-isle`) — same concept, different word.
- **XP Ascent** (`xp-ascent`) — distinct, leveling-coded.
- **XP Crown** (`xp-crown`) — catchy, "sits at the top" pun.

> CurseForge rule reminder: do **not** put "WoW", "World of Warcraft", "Classic",
> a version number, or a category name in the title. "XPBar Island" passes cleanly.

---

## 2. Summary (one line, English, required)

```
A sleek top-center XP bar island for WoW Classic, tracking experience, reputation, honor, pet XP and skills with live rates and party comparison.
```

Shorter alternates (if you want under ~100 chars):
- `One sleek top-center XP bar for experience, reputation, honor, pet XP and skills.`
- `A polished XP / reputation / honor / pet XP / skills island HUD for WoW Classic.`

---

## 3. Main category and additional categories

**Class (fixed):** Addons

**Main category (pick one):**
- **Quests & Leveling**  ← recommended (matches XP / leveling search intent)

**Additional categories:**
- **HUDs**
- **Unit Frames**
- **Miscellaneous**

Notes:
- The addon replaces/augments the default XP bar and tracks several progression
  types, so HUDs + Unit Frames + Miscellaneous describe it honestly without
  keyword stuffing.
- Do **not** add Action Bars or Artwork; neither fits.
- CurseForge has no free-text tags for WoW; categories + the summary/description
  keywords are how discovery works.

---

## 4. Description (paste into the Description tab)

```
XPBar Island puts experience, reputation, honor, pet experience and skills into one
compact HUD "island" that sits flush to the top of your screen. Hover it and it
springs open into a full panel; leave it alone and it stays out of the way.

Built from scratch for WoW Classic. No other addon, library or shared media is
required - just drop it in and play. It is lightweight, pure Lua, and safe on
clients that are missing modern APIs (everything has a fallback).


WHAT IT TRACKS
- Experience: current / max, percentage, rested XP, quest XP, XP per hour,
  kills to level, time to level and a live session graph.
- Reputation: your watched faction, its full standing ladder (Hated, Hostile,
  Unfriendly, Neutral, Friendly, Honored, Revered, Exalted), the bar, the next
  tier and how much is left to it.
- Honor: rank, honor progress and weekly honor where the client exposes it.
- Pet experience: your active pet's XP or health, its level and happiness.
- Skills: the progress of your skill-ups in one place.


PARTY SYNC - SEE YOUR GROUP
If the other players in your party also have XPBar Island, the island reads their
level and XP and shows a live party comparison right inside the panel, so you can
see who is about to ding. Group members who do NOT have the addon are still shown
by class colour and level.

Only your level and XP are ever shared - nothing else leaves your client - and you
can switch the whole feature off at any time in Settings > Party & share.


SWITCH ON THE FLY
Click a chip to flip between Experience, Reputation, Honor, Pet Exp and Skills.
Auto-switch can briefly show a type whenever it changes, and at max level the bar
can replace XP with your watched reputation.


FEATURES
- HUD island with a springy expand-on-hover panel (or pin it open).
- Four built-in themes (Default, WoW, Classic, WoW Forever) plus custom trim,
  bar and text-accent colours and a font picker.
- Display modes: Full, Classic (thin bar), Auto-hide, and Always open.
- XP bar effects: animated fill, count-up numbers, gain flash, edge glint,
  segment flashes, charge-up glow and a kill-streak tag.
- Level-up celebration with a flash, badge pop, rings, banner and sound, plus a
  level-up summary card showing the health, mana and attribute gains, talent
  points and any spells waiting at your trainer.
- Optional "Fade until hovered" so the island stays faint until you mouse over it.
- "Hide in combat", "Hide out of combat" and "Hide the default XP and rep bars" options (on by default).
- A live session graph of your XP gains.
- Optional minimap button (hidden by default), movable island, scale control and named profiles
  (switch per character, and per spec where supported).
- Everything is configurable in game: /xpbar opens the settings window, which
  registers under Options -> AddOns when the client supports it.


DISPLAY MODES
- Full: island + full expanded panel.
- Classic: thin, minimal bar.
- Auto-hide: appears at the top edge only when needed.
- Always open: the panel is permanently expanded.


SLASH COMMANDS
/xpbar          open settings
/xpbar reset    reset session counters
/xpbar share    post your progress to your share channel
/xpbar move     toggle move mode
/xpbar font     confirm the bundled font loaded
/xpbar debug    print current data
/xpbar contact  open the author's X (Twitter) page


INSTALL
1. Close World of Warcraft.
2. Copy the XPBarIsland folder into:
   World of Warcraft\<your classic client>\Interface\AddOns\
3. Start the game and enable "XPBar Island" on the character screen (AddOns button).
4. Optional: /console scriptErrors 1 to see any Lua error in chat.

The addon folder name stays XPBarIsland (required); the SavedVariables are
XPBarIslandDB. Existing saves migrate automatically.


COMPATIBILITY
Written for the Classic-era client. Every modern API is probed and has a working
fallback, so the island still renders on clients that lack them.


FEEDBACK, BUGS AND CONTACT
- Found a bug, or have an idea to make it better? Please leave a comment on this
  CurseForge page - I read them all and it is the fastest way to get something fixed.
- You can also reach me on X (Twitter): @mainlek  -  https://x.com/mainlek
- In game there is a subtle "Contact @mainlek" link in the settings footer, and
  /xpbar contact opens my X page directly.
```

---

## 5. Logo

- File: `logo.png` (512x512 PNG, square) in the addon folder.
- Simple, on-brand: gold "XP" on a dark rounded plaque with a purple progress
  bar, milestone diamond and "ISLAND" caption.
- Upload it on the General tab (Logo -> Upload image). It is not a solid block
  of colour, not a game/trademark asset, and NSFW-free, so it should pass
  moderation.

---

## 6. License

Pick one on the License tab. Recommended for maximum reach / simplest:
- **All Rights Reserved** — default, fine for a first release; nobody may
  redistribute or reuse files.
- **MIT** — if you want other authors to be free to reuse code; most permissive
  and popular with addon devs.

(Whichever you choose, the shipped Alegreya Sans font is SIL OFL; keep the font
licence file if you enable reuse.)

---

## 7. Game version / interface

- `.toc` `## Interface: 16001` — Classic-era client.
- Set the matching game version when uploading the first file.

---

## 8. Upload checklist

- [ ] General tab: Project name = **XPBar Island**
- [ ] General tab: Logo = upload `logo.png`
- [ ] General tab: Summary = the one-liner above
- [ ] General tab: Main category = **Quests & Leveling**
- [ ] General tab: Additional categories = **HUDs**, **Unit Frames**, **Miscellaneous**
- [ ] General tab: Allow Comments = on (recommended, helps feedback)
- [ ] Description tab: paste section 4
- [ ] License tab: choose a licence
- [ ] Upload the first file/version (zip of the XPBarIsland folder)
- [ ] Add at least one screenshot of the island in game (Gallery) once available

## 9. Browser status (this session)

The live form at https://authors.curseforge.com/#/projects/create/general already holds:
- Project name: `XP Island`  ← **change this to `XPBar Island`** (that is the slug collision)
- Logo: an image preview is already attached
- Summary: the recommended one-liner
- Main category: `Quests & Leveling`  ✓
- Additional categories: `HUDs`, `Unit Frames`, `Miscellaneous`  ✓
- Allow Comments: on  ✓

Remaining manual steps: set the name to **XPBar Island**, then click **Next**. If it
reports `xpbar-island` taken, try the fallbacks in section 1 (Island XP, XP Isle,
XP Ascent, XP Crown) and I will sync the `.toc`/logo to whatever you land on.
Description + License tabs are still to be completed (paste section 4 for the description).
