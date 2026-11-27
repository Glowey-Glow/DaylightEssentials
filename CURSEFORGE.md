# Glowey's Essentials

**Small combat and play aids for Daylight UI on WoW: Forever, in the Daylight UI look.** Each one has its own switch and settings page, so you only run what you want.

By Glowey. A standalone addon that **integrates with Daylight UI** when it's installed: its pages sit in Daylight UI's options window, in its look, and ride in its profiles (not part of Daylight UI itself: report its bugs here, not to Daylight UI). Without Daylight UI, its settings are in the Glowey's Plugins window (**/glowey**, or Options > AddOns).

---

## New in 1.14.0
- **New: XP Bar** (off to start). An experience bar with the numbers you level by: time to level at your rate, XP per hour, XP per kill, kills to level, the quests ready to turn in and where they take the bar, your quest log's XP and rested XP. It docks under the quest tracker, flush with the minimap panel, and fades with it; or set it free, with or without its window.
- **Casts Left fades with its button:** when a bar fades out or a button dims (out of range, short of mana, on cooldown), its number goes with it.
---

## What's in it

### Healer Mana
Your group's healers and the mana each has left, with class icon, name in class color and mana in percent (yellow when low, red when nearly out). It keeps working in a fight, when the game hides other players' mana from addons. Healers are the players given the healer role; with no roles set, it lists priests, druids, shamans and paladins (or nobody, if you prefer). **New in 1.4.0:** a healer's line glows red below 20% mana. The box widens to fit long names, so nothing is cut off. **While a healer drinks**, their line becomes their mana bar, filling as they drink, with "Drinking" on it; a dead or offline healer's line is grayed out with "Dead" or "Offline".

### Combat Timer
How long you've been fighting, and the last fight's length for a few seconds after. Tenths of a Second and the window behind it are your choice.

### Combat Alert
"+ Combat" as a fight starts and "- Combat" as it ends, in the middle of the screen. Other words, a sound and the size are your choice.

### Pet Reminder
For hunters and warlocks: "No pet" or "Pet is passive" until it's sorted. Quiet while you're mounted, flying, dead, resting in a town (your choice) or under Demonic Sacrifice. Its sample shows on every character in test mode, so you can place it from anyone. **New in 1.4.0:** it glows while it shows.

### Seal Reminder
For paladins: "Seal Missing" while you have no seal up, in the same gentle pulse as the Pet Reminder. Quiet while you're mounted, flying, dead or resting in a town (your choice), and it can wait for a fight (Only in a Fight). In a fight the game hides your buffs from addons, so there it goes by whether Judgement can be used.

### Cursor Cooldowns
- Your taunt and dispel cooldowns as small icons beside the mouse pointer while they cool down, with the game's own sweep and countdown.
- **Ready at the Cursor (new):** pick up to six abilities, and their icons show in a line beside the pointer while each is ready to cast (off cooldown and usable now). Choose the side (top left through left, 8 spots) and the icon size (24 px to start). Picks are kept per class. **New in 1.4.0:** an icon glows for a moment as it becomes ready.

### Enemy Nearby (new)
- A small list of enemy players seen near you lately: level and name in class color, newest at the top. Names fade while unseen and leave after a minute (your choice).
- **Click a name to target that player.** In a fight the list keeps its order, and players seen during it are added below.
- **Kill on Sight:** right-click a name, or use `/kos add Name`, `/kos remove Name`, `/kos list`. Shared by all your characters, and marked in red.
- **New in 1.4.0:** the alert glows while it's up, red for Kill on Sight.
- **Alerts:** a line mid-screen and a sound when someone on your Kill on Sight list shows up, and, if you like, when any new enemy does.
- **Windowless** if you prefer just the names. Rests in battlegrounds and dungeons unless you ask otherwise.
- It sees players through nameplates, your target, focus and mouseover, so keep enemy nameplates shown (the switch is on its page).

### Secondary Stats (new)
- A small box of the stats that matter for how you play: attack power, crit, hit and haste for melee; ranged stats for hunters; spell power, spell crit and mana regen for casters and healers; armor, defense, dodge, parry and block for tanks. **Auto** picks by your group role or your class.
- **Custom:** pick up to six stats of your own, resistances included, in your order.
- Crit, haste, armor, dodge and the like stay live in a fight; stats the game gives in parts keep their numbers from before it, dimmed (your choice).
- **Hit turns green** when it's enough to never miss your current target, matching the game's Hit Chance tooltip (5% melee and 4% spells at your level, 8% and 17% against raid bosses).
- **Dock it** flush against the minimap (the default), the damage meters or Daylight UI's chat, at the corner you pick. It slides out of that edge and back in from a fold tab, like Daylight UI's damage meter. By the minimap it slides Daylight UI's buffs aside at a top corner and its debuffs at a bottom one (new in 1.3.5); by the damage meters it steps out of the threat meter's way as your group grows; by the chat it can fade with the chat window. Or set it free anywhere.
- **Windowless** (just the text) docked or free. Per-stat name colors (crit gold, hit blue, haste green...), your class color or plain; a heavier outline and a text shadow you can size; one list or one line.
- **Fold Away in Combat (new in 1.4.0):** docked, it folds when a fight starts and comes back after.
- **Whisper windows:** it steps aside while a whisper conversation is open, and comes back when it closes.

### Buff Manners (new)
- One prompt offering the buff you can give to whoever needs it most: **a player who just buffed you**, then your target, your group (checked again at a ready check), then players right beside you (friends and guildmates first).
- **Click it or press its key** (Key Bindings > AddOns > Glowey's Essentials) and the buff goes out; your own target comes back to you. Nothing is ever cast by itself, and it hides in a fight.
- Mages give Arcane Intellect; priests Fortitude (Divine Spirit and Shadow Protection are choices); druids Mark of the Wild (and Thorns for tanks); paladins Kings first or Wisdom or Might by class, never over a blessing of their own; warlocks Unending Breath while swimming.
- **Thanks:** a /thank and/or a line in say or a whisper ("Thanks for the buff!", "Thank you, Name!", "Much appreciated!" or your own with `/manners line`). For a class with no buffs to give, or a player who already has yours, the prompt still shows who buffed you and offers the thank-you on its own. Only buffs cast on you count, not auras that are there while someone is near (paladin auras, Trueshot Aura).
- Skips PvP-flagged players while you aren't flagged, and can be quiet in towns, dungeons and raids. Right-click the prompt for **Not Now** or **Never Offer**; `/manners never Name`, `/manners allow Name`, `/manners list`.
- The idea comes from Manners by fpsacha.

### Halo
- **Hold a key and your own spells, items, macros, mounts and pets open in a Halo around the cursor.** Point at one or scroll to it, then let go to use it. Let go in the middle to close it without using anything. Works in a fight.
- **Its own key:** **Set Key** on its page takes the next key or mouse button you press, without touching your key bindings (or bind it under Key Bindings).
- **Up to four Halos (new in 1.2.0):** the base Halo, plus a **Shift, Alt and Ctrl Halo**. Hold the modifier with Halo's key to open that one. Each has its own slots, **its own color** (rim, highlight and label) and **a label** of up to 16 letters.
- Fill the slots by dragging spells, items, macros, **mounts, companion pets and your pet's abilities and commands** onto them in **Edit Halos** (a tab per Halo, or `/halo edit`), or click a slot to choose from a list.
- Choose the shape (circle or arc), the number of slots (2 to 12), the Halo's size, the icon size and where it opens (around the cursor or the screen's center).

### Stance / Aura / Form (new in 1.7.0)
- **Your stance, form or paladin aura by name** on your player frame ("Battle Stance", "Bear Form", "Devotion Aura"). Turn it on from its page, and set its position, size and nudges right there.
- **Shaman weapon imbues (new in 1.7.1):** Rockbiter, Flametongue, Frostbrand or Windfury Weapon, both hands when they differ.
- **Always readable:** white or dark, whichever reads best across your health bar's colors, gradients included.

### Nameplate Dmg Text (new in 1.3.0)
- **Damage numbers pop off enemy nameplates** as they're hit, in Daylight UI's font, colored by school (fire orange, frost blue...), crits bigger with a quick pop, misses, dodges and parries as words.
- **Spell icons (new in 1.5.0):** the spell's icon left or right of each number, at the size you pick. The game doesn't say which spell landed a hit, so it's worked out from your own and your pet's casts: right nearly always, a guess now and then.
- **On You (new in 1.5.0):** damage taken and healing received in the same look, left and right of the screen's middle or on your player frame, with a minus or plus. They keep showing in a group.
- **Quieter off your target:** numbers on other enemies are smaller and fainter, or show on your target only.
- **Motion:** Fountain, Rise, Fall or Rainfall, set apart for hits, crits and misses, each starting above, below, left or right of the plate (new in 1.5.0); how long they stay, their height, size, and short (1.2K) or full numbers.
- **See and place it:** a live preview on its page shows a nameplate with numbers coming off it as you change the settings; in Design mode, drag where the numbers start.
- **Turn Off Daylight UI's Combat Text:** all of Daylight UI's combat text (damage numbers and the scrolling text around you) switches off while it's on, so no hit shows twice, and comes back as it was when it's off.
- **Only yours and your pet's:** the game gives addons no combat log on Forever, only each hit on a nameplate without who struck it. Alone, that's yours and your pet's; in a group (new in 1.3.1) the nameplate numbers pause and the game's own damage numbers show instead, which are only yours and your pet's. Off to start: turn it on on its page.

### XP Bar (new in 1.14.0)
- **An experience bar with the numbers you level by:** your level and percent on the bar, with the XP from quests ready to turn in (green) and rested XP (purple) right after the fill.
- **Under it, each on its own switch:** time to level at your rate, XP per hour, XP per kill over the last hour, kills to level, the quests ready to turn in (their XP and where the bar goes when you do), your whole quest log's XP, rested XP and this session's totals. Hover it for everything at once, including the time to level after turning in your quests.
- **Docked under the quest tracker:** as wide as the minimap panel when the tracker hangs under it, following the tracker as it grows and moves, and under RestedXP's guide when that's docked there. Or **Free**, anywhere you move it, with or without its window (Windowless).
- **Fades with the UI:** out and back with the quest tracker, by the tracker's fade choices (free, with Daylight UI's XP bar's).
- **Replace Other XP Bars:** Daylight UI's XP bar (or the game's) steps aside while it shows, and comes back at the level cap, where this one hides. Off to start: turn it on on its page.

---

## How to use it

- Everything is on from the start and shows itself when it's needed.
- **Move things:** **Move Window** on a part's page (or `/dui unlock`, `/glowey unlock` without Daylight UI) shows samples to place; press it again (or `/dui lock`) when you're done. `/dui test` shows them too.
- **Settings:** Daylight UI options > **Plugins > Essentials**, one page per part.
- **Key bindings:** Key Bindings > AddOns > Glowey's Essentials (Buff Manners and Halo).

---

*Copyright (c) 2026 Glowey. All rights reserved. Free to download and play with.*
