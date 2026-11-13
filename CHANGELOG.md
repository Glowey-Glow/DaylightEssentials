# Daylight Essentials

## 1.1.0
- New: Enemy Nearby, a small list of the enemy players seen near you lately (level, name in class colour, guild), the newest at the top. Names fade while unseen and leave after a minute (a choice). It sees players through their nameplates, your target, focus and mouseover, so enemy nameplates have to be shown: its page has the switch.
- Click a name to target that player. In a fight the list keeps its order and players seen during it are added below, clickable once it ends.
- Kill on Sight: right-click a name, or type /dui kos add Name, /dui kos remove Name or /dui kos list. Shared by all your characters; its names are marked in red.
- Alerts: a line in the middle of the screen and a sound when someone on your Kill on Sight list shows up, and if you like when any new enemy does. The same player alerts again only after two minutes (a choice).
- Rests in battlegrounds and dungeons unless you ask otherwise. /dui unlock shows sample names and a sample alert to place them.
- New: Secondary Stats, a small box of the stats that matter for how you play: attack power, crit, hit and haste for melee, their ranged ones for hunters, spell power, spell crit and mana regen for casters and healers, armor, defense, dodge, parry and block for tanks. Auto picks by your group role or your class.
- Custom: pick up to six stats of your own, resistances included, in the order you like.
- Crit, haste, armor, dodge and the like stay live in a fight; attack power, hit, defense and mana regen keep their numbers from before it, dimmed (a choice). As a list or on one line, always or only in or out of a fight; stats at 0 can hide.
- Dock it to the minimap (the default), your player frame or your target frame: it sits flush against that frame's side at a corner, level with it (for the minimap: against the panel's left edge, bottoms together), by default the corner facing the middle of the screen or one you pick, grows away from it, and slides out of that corner and back in from a tab on its edge, the way DaylightUI's damage meter slides out of the minimap panel (the tab shows when the mouse is near). Two nudge sliders fine-tune the spot. Or set it free to place it anywhere with /dui unlock, windowless if you like.
- Each stat's name in its own colour (crits gold, hit blue, haste green, attack power orange, spell power violet...), your class colour, or plain; the numbers can take the same colour. The text has a slightly heavier outline and a shadow you can size (1 px to start, 0 for none), so the colours read on any ground, and the box fits its text.
- Fixed: no more "unknown unit" lines in chat about Combat Alert's "Stays for" and Combat Timer's "Keep the last fight's time" sliders.

## 1.0.0
- New: Daylight Essentials, small combat aids in the DaylightUI look, each with its own switch and page in DaylightUI's options (Plugins, Essentials).
- Healer Mana: your group's healers and the mana each has left (class icon, name in class colour, mana in percent, yellow when low and red when nearly out). It keeps working in a fight, when the game hides other players' mana from addons. Healers are the players given the healer role; with no roles set, priests, druids, shamans and paladins (or nobody).
- Combat Timer: how long you've been fighting, and the last fight's length for a few seconds after (tenths of a second and the window ground are choices).
- Combat Alert: "+ Combat" as a fight starts and "- Combat" as it ends, in the middle of the screen (other words, a sound and the size are choices).
- Pet Reminder: for hunters and warlocks, "No pet" or "Pet is passive" until it's sorted. Quiet while mounted, flying, dead, resting in a town (a choice) or under Demonic Sacrifice.
- Cursor Cooldowns: your taunt's and dispels' cooldowns as small icons beside the mouse pointer while they cool down, with the game's own sweep and countdown.
- Everything that shows can be moved with /dui unlock, where samples show to place them; /dui test shows them too.
