# Daylight Essentials

A plugin for DaylightUI on WoW: Forever: small combat aids in the DaylightUI look, each one switched on or off on its own.

- **Healer Mana:** your group's healers and the mana each has left, working in a fight too.
- **Combat Timer:** how long you've been fighting, and how long the last fight took.
- **Combat Alert:** "+ Combat" and "- Combat" in the middle of the screen as fights start and end.
- **Pet Reminder:** for hunters and warlocks, a warning while your pet is missing or set to passive.
- **Cursor Cooldowns:** your taunt's and dispels' cooldowns beside the mouse pointer while they cool down, and the abilities you pick shown there while they're ready to cast.
- **Enemy Nearby:** the enemy players seen near you lately, click to target, with a Kill on Sight list and an alert when one of them shows up.
- **Secondary Stats:** the stats that matter for how you play (melee, ranged, caster, healer, tank, or your own pick of six) in a small box docked to the minimap, the damage meters or the chat that folds away with a tab (or free, windowless if you like), live in a fight.
- **Buff Manners:** one click (or one key) to buff a player who buffed you, your target, your group or a passer-by missing your buff, with an optional thank-you.
- **Halo:** hold a key for a ring of your own spells, items and macros at the mouse; point or scroll, let go, and it fires.

## Requirements

- DaylightUI.

## Installing

Install it from CurseForge (or WowUp), or unzip it into `World of Warcraft\_forever_\Interface\AddOns`. Make sure it's ticked in the AddOns list on the character screen, then log in or `/reload`.

## How to use it

Everything is on from the start and shows by itself when it's needed: the healer list in a group with a healer, the timer and alert in a fight, the pet warning when your pet is missing or passive, and a cooldown icon at your pointer after you taunt or dispel.

**Moving things:** type `/dui unlock`. Samples of the healer list, timer, alerts, pet warning, enemy list and stats box (when it's set free) show so you can place them; `/dui lock` when you're done. The cursor icons follow your pointer.

**Enemies nearby:** the list fills from enemy nameplates, so keep them shown (the switch on its page, or V). Click a name to target; right-click it to add it to your Kill on Sight list, or type `/dui kos add Name`, `/dui kos remove Name`, `/dui kos list`.

**Who counts as a healer:** players the group gave the healer role (the group finder, or a leader's role check). When nobody has a role, it lists priests, druids, shamans and paladins, or nobody if you choose so.

## Settings

Open the DaylightUI options and go to **Plugins → Essentials**. Each part has its own page with an **On** switch and its choices.

## Updates

What's new in each version is in [CHANGELOG.md](CHANGELOG.md).

## License

Copyright (c) 2026 Glowey. All rights reserved. Free to download and play with; see [LICENSE](LICENSE).
