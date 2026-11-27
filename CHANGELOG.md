# Glowey's Essentials

## 1.14.0
- New: XP Bar (off to start). An experience bar with the numbers you level by: time to level at your rate, XP per hour, XP per kill over the last hour, kills to level, the quests ready to turn in (their XP, and where the bar goes when you do), your whole quest log's XP, rested XP and this session's totals, each on its own switch. It docks under the quest tracker (or RestedXP's guide docked there) at its width and follows it, or is free to move anywhere; with its window or Windowless. Replace Other XP Bars puts Daylight UI's XP bar (or the game's) away while it shows; at the level cap it hides and they come back. Docked, it lines up flush with the minimap panel's edges and fits its text to that width, and it fades out and back with Daylight UI's quest tracker (free, with Daylight UI's XP bar's fade).
- Casts Left: the number fades with its button instead of staying bright: when Daylight UI dims the button's icon (out of range, short of mana, Opacity on Cooldown, a form that's off), when its whole bar fades out (mouseover, out of a fight and the rest of its fade choices) and when the bar is put away. The Cooldown Manager's numbers already went with their icons.
## 1.13.0
- Casts Left also shows on the Cooldown Manager's icons (Daylight UI's, or the game's own without it), with its own On the Cooldown Manager switch.
- Buff Manners: Rows Grow up or down from the prompt, and Blessing by Class picks the blessing each class gets from you (As Above follows your Paladin blessing, None offers none).
- With another of Glowey's plugins on, Essentials' pages sit under one "Glowey's" entry on Daylight UI's options rail.

## 1.12.1
- Casts Left is lighter in a fight: an absorb ticking down on Mana Shield or Ice Barrier no longer re-reads every spell's cost and repaints every button (only a cost that changed does), hidden buttons wait until they show, and nothing runs while Only in a Fight has it hidden.
- Buff Manners no longer looks every 1.5 seconds for the whole session in a crowd because someone far off wants your buff: it looks for 30 seconds after the game's last word, and at most twice a second on mana ticks and mouseovers.
- The Stance text no longer works its name out again when a buff's timer or stacks refresh.
- The welcome no longer keeps asking every 5 seconds for the whole session while Daylight UI is busy: it gives up after ten minutes and asks at the next login.

## 1.12.0
- New: Casts Left (mages). How many more casts your mana allows, as a small number on each attack and defense spell's button (Daylight UI's bars, the game's bars and Halo), in a fight too. It turns the warning color at Warn At casts and red at 0, reads Free while a cast costs nothing (Clearcasting), and can show only when low or only in a fight, in the corner you pick. Main Spell shows one spell's count as a larger line of its own, moved with /dui unlock.
- Secondary Stats docked to the minimap, the meters or the chat no longer hooks frames there that don't take the mouse, so data text panels and addon drawers near it get their hovers and clicks again.
- Settings dropdowns no longer catch the click outside them: a click on a data text, an addon drawer or anything else closes the menu and reaches what you clicked the first time.
- After Escape closes a tour card, the card no longer keeps your keys to itself (it could stop movement keys in a later fight).
- BugSack reports now end with this addon's name and version on its own errors, so a report says which version it came from.

## 1.11.2
- No more checking several times a second while nothing happens. Secondary Stats docked to the meters or the chat no longer re-measures its place up to 30 times a second; it follows the threat meter and the chat's fade as they change. Its fold tab shows as the mouse comes near and stops looking once it's gone. Buff Manners no longer looks every 1.5 seconds for the whole session: it listens to range, group, aura and movement changes, and looks on a timer only while someone it can't reach yet wants your buff.
- Quick Loot no longer counts a loot addon that's switched off for this character.
- While Secondary Stats is docked, its box notices the mouse (clicks still pass through), so a unit standing right behind it doesn't show its mouseover tooltip.

## 1.11.1
- Buff Manners offers your own buff when it's missing on you, not only when it's running out: a Fortitude or Mark of the Wild that wore off or was lost to a death mid-dungeon gets a row of its own ("Missing on you") that casts it on you, until it's back. The option is now Rebuff Me When Missing or Low. Daylight UI's buff reminder only shows missing buffs on a ready check and on entering a dungeon, so these were never offered.
- Lighter in combat: the Stance text, Healer Mana's low-mana glow, Buff Manners, Cursor Cooldowns and the nameplate numbers do less work on every update, so fights run smoother.
- Parts you've switched off (Cursor Cooldowns, Seal Reminder, Pet Reminder) no longer listen to the game at all.

## 1.11.0
- Buff Manners lists several players at once, a row each, instead of one. Players Listed (1 to 6, 3 to start) sets how many; click any row to give that player the buff, and the key gives the top row's.
- Buff Manners: Rebuff Me Before Mine Run Out (on to start). When a buff you can cast is running out on you, the prompt offers it on a row of its own that casts it on you, on the same button and key. Minutes Left to Rebuff Me (1 to 10, 3 to start) sets how early, never earlier than halfway through the buff. Paladins are offered only their own blessing again.
- Buff Manners: Disable When Busy (off to start). While more players than Busy Above This Many Players (10 to start) want your buff, as in a crowded city, nobody else is listed. Your own rebuff still shows.
- While the pointer is on a row, that row keeps its player, so a crowd moving the list around never slides someone else under your click. A row whose player has gone stays blank and casts nothing until the pointer leaves.
- Follows Daylight UI's language, colors, scale, tooltips and motion switch when it's installed, and its own language and look choices without it. Combat Alert and Enemy Nearby each get an alert sound choice (the same sounds as before to start), and Halo's editor and list close with Escape.
- Every page with a window of its own (Combat Timer, Combat Alert, Healer Mana, Enemy Nearby, Secondary Stats, Buff Manners, Pet Reminder, Seal Reminder) has a Move Window button that unlocks the windows to drag them, and locks them again on a second press. With Daylight UI it is /dui unlock.
- Secondary Stats: the Layout choices read List and Line.
- Without Daylight UI: dropdown menus fit their words. Each menu is as wide as its longest choice, its rows are as tall as the font, and in Blizzard Style it keeps the game's own margins (8 at the sides and top, 15 at the foot), so the last choice no longer runs past the bottom edge. Menus are solid, so the setting underneath no longer shows through.
- Without Daylight UI: a dropdown on a settings page is wide enough for its longest choice.
- Without Daylight UI: sliders on the settings pages can be dragged and clicked again. They were made without taking the mouse, so none of them moved.
- Without Daylight UI: a slider can be dragged all the way. The page was drawn again on every step, which let go of the slider under the mouse; it now waits until the slider is let go.
- Blizzard Style: bars are the profession window's own (its skill bar's border and fill, 14 high), such as the Chance of Skill Up bar.
- What's New after an update, and the welcome names Move Window and the new Buff Manners.
- Blizzard Style: scroll bars are the game's own (its minimal scroll bar, with arrows at both ends): drag the thumb, click the track or the arrows, as in the game's windows.
- New: Quick Loot. With Auto Loot on (or its key held), everything is taken the moment the loot window opens, instead of one item after another. It starts off when another addon that does the same is installed (Daylight UI's Quality of Life, Polestar, Leatrix Plus and the like), and its page names which; turn it on there if you'd rather Essentials did it.
- Works without Daylight UI. Daylight UI is no longer required: with it installed nothing changes, and without it the plugin runs on its own. Its settings are then in a Glowey's Plugins window (/glowey, or the game's Options > AddOns), shared by every Glowey plugin you have, with a General page for the accent color, window opacity and moving frames. Frames move with /glowey unlock (drag; right-click puts one back), and /glowey <command> stands in for /dui <command>.
- Your settings are kept either way: they are now also saved in the plugin's own saved variable, so taking Daylight UI out keeps them, and settings made without it are taken into Daylight UI when it comes back.
- Without Daylight UI: a Look choice on the General page of /glowey for every Glowey window: Glowey's own, Blizzard Style (Blizzard's own window frames from this client: the metal frame with its title bar and red close button, dialog borders, tooltip boxes, red buttons, edit boxes, check boxes, sliders, tabs and gold text), or Polestar's when Polestar is loaded. With Polestar, Polestar itself paints the windows in the look you picked in its settings, and they change when you change it there. And a minimap button: click it for the settings, right-click to move frames, drag it round the map. It also appears in the game's addon menu, and Minimap Icon on the General page hides it.
- Blizzard Style fits its borders to each window: a small box (Essentials' combat timer, the tabs) gets the tooltip's thin border instead of the dialog's, which overlapped itself there, and the border sits round the outside of a window so it never covers what's inside.
- Without Daylight UI: every part works except Stance / Aura / Form, which is a text on Daylight UI's player frame and so has no page without it. Secondary Stats docks to the minimap or sits free, the Turn Off Daylight UI's Combat Text switch and Daylight UI's opacity switches are left out, and the samples show while frames are unlocked (/glowey unlock).
- Controller navigation of the plugin's windows comes from Daylight UI's controller support, so it needs Daylight UI.

## 1.10.0
- New: Seal Reminder, for paladins. "Seal Missing" shows while you have no seal up, in the same pulse as the Pet Reminder, on its own page with its own switch. Quiet while you're mounted, on a flight, dead or resting in a town (Mute in Towns and Inns), and with Only in a Fight on it waits for a fight. Out of a fight it reads your buffs; in a fight the game hides buffs from addons, so it goes by whether Judgement can be used, and says nothing where it can't tell. Move it with /dui unlock.
- Fixed: Halo didn't take mounts or companion pets. A slot only knew spells, items and macros, and the game hands a mount or a pet over as a kind of its own, so dropping one did nothing. Both can now be dragged in from the mount and pet journal, and both have a list of their own in Choose for Slot (Mounts, with Random Favorite Mount first, and Pets). Letting go on a mount you're riding dismounts; on a pet that's out, sends it away.
- Halo takes your combat pet's actions too: a hunter pet's or a warlock demon's abilities, and its commands (Attack, Follow, Stay, Passive and the rest), dragged from the pet bar or the pet's spellbook, or chosen from the new Pet Actions list while the pet is out. They dim while no pet is out.

## 1.9.1
- Commands of their own, with no "/dui" in front: /halo, /kos and /manners. The old /dui halo, /dui kos and /dui manners still work, so macros keep working.
- Fixed: Halo slots looked empty after 2026-11-20. The game stopped giving realm names that day, and Halo kept each character's slots under its name and realm. Every character gets its slots, modifier Halos and labels back at its next login, and nothing was lost. Slots are now kept by character, so a change like this can't unhook them again.
- Checked against Daylight UI 2.1.2. Nothing else to change.

## 1.9.0
- Halo: an icon that is cooling down shows the time left on it, for spells and items alike (the game's own countdown, so it also counts in a fight). On by default; switch it off with "Cooldown Time on Icon" on Halo's page.
- Checked against Daylight UI 1.9.6. Nameplate Dmg Text and Secondary Stats follow its outline again: 1.9.6 went back to the plain outline (1.9.5 drew every outline much heavier), and so do they, with nothing to set.

## 1.8.2
- Nameplate Dmg Text and Secondary Stats draw their outlined text the way Daylight UI 1.9.5 does (the game's sharper outline), so they match its combat text. Older Daylight UI versions keep the plain outline.

## 1.8.1
- Daylight Essentials is now Glowey's Essentials (DaylightUI Plugin), so it's clear it's a plugin and not part of Daylight UI. Inside Daylight UI the section is Glowey's Essentials, and its key bindings are under that name. Your settings and key bindings are kept.

## 1.8.0
- Halo, new Bar layout (Layout: Ring or Bar on its page): your slots in a row. Hold the key and step through them with the D-pad or LB / RB, let go to use the lit one, B to cancel. It works in a fight too. With a controller the Bar is used by itself (Bar With a Controller, on to start).
- Halo, Choose for Slot: click an empty slot in the editor (or press A on one with a controller) to pick a spell, item or macro from a list, no dragging needed. The editor works with a controller too.
- Halo's Set Key takes a controller button as the key; Start cancels.
- Nameplate Dmg Text: your pet's hits no longer take the icon of your last spell. Only your damage over time spells stand in for later ticks, and your pet's own spells show their own icons.
- New key bindings (Key Bindings, AddOns, Daylight Essentials), handy on a controller: Buff Manners: Not Now, and Secondary Stats: Show or Fold Away.
- The tours and the welcome work with a controller.
- Labels and buttons in Title Case, and "Daylight UI" written with a space.

## 1.7.1
- Stance / Aura / Form now shows a shaman's weapon imbues too: Rockbiter, Flametongue, Frostbrand or Windfury Weapon, by the spell's name. A different imbue on each hand shows both, and a form comes first ("Ghost Wolf / Windfury Weapon"). Oils, stones and poisons aren't shown.

## 1.7.0
- New: Stance / Aura / Form text on your player frame: your stance, form or paladin aura by name ("Battle Stance"). Turn it on from its page (On My Player Frame); Position, Text Size and the left / right and up / down nudges there move it (it starts on the left of the health bar). Its color is white or dark, whichever reads best across your health bar's colors (the Daylight gradient, your accent, a class gradient or one color). It's also in each frame's extra text parts in Daylight UI.

## 1.6.0
- Everyone, including players who had Daylight Essentials before, sees the welcome once with this version.
- New: a welcome on first launch listing what Daylight Essentials adds: which parts show on your screen from the start, Buff Manners, Halo (pick its key first) and Nameplate Dmg Text (off to start; turned on, it stands in for Daylight UI's combat text). Open Options takes you to its pages.
- New: tells you when a newer version is out. Your copy and those of players in your guild and group trade version numbers in the background, and one chat line says when there is a newer one to get through CurseForge or WowUp (once a session). Turn it off with "Tell Me When a Newer Version Is Out" on the plugin's first options page; then nothing is sent either.

## 1.5.0
- Nameplate Dmg Text: On You, damage taken and healing received in the same look (on to start). Damage shows left of the screen's middle and healing right of it to start; either can go to the player frame or the other side, with their own motion and size, how far from the middle and how high. Damage takes the school's color with Color by Element (physical stays red), healing is green, with a minus or plus before them (switchable). Your dodges, parries and other misses show their word with the damage. These keep showing in a group, and Daylight UI's own combat text stays off then too so they don't show twice; with Daylight UI's combat text on, ours step aside.
- Nameplate Dmg Text: spell icons with the numbers (on its Look settings; left of the number to start). Left or right of the number, riding with it. A Spell Icon Size slider (50% to 200% of the number's size) sets them, and crits make them bigger too. The game doesn't say which spell landed a hit, so the icon is worked out from your own and your pet's casts: a cast's hit within 1.5 s, an area spell's hits within 0.4 s, a damage over time tick from the last spell of its school on that enemy, and melee with your main-hand weapon's icon (no melee icon while your pet is out, since its swings and yours can't be told apart). Overlapping casts can now and then put the wrong icon on a hit. The preview shows them too.
- Nameplate Dmg Text: hits, crits and misses each pick where they start, beside their motion (on its Motion settings): above the plate (as before), below it, or beside it on the left or right, where they're held clear of the plate's bar. The shifts are shared and count out from each spot, and every motion plays from there. The preview shows each kind from its own spot; Design mode's marker and drag follow the hits' spot.

## 1.4.0
- Glows, with Daylight UI 1.8.4 or later: Daylight UI's animated glow, in the style you picked for its main buttons, now marks the moments that matter. Each one has its own switch, on by default, and all of them follow Daylight UI's Motion setting.
  - Cursor Cooldowns: a "Ready at the Cursor" icon glows for a moment as it comes ready.
  - Pet Reminder: the warning glows while it shows.
  - Enemy Nearby: the alert glows in its own color while it's up, red for Kill on Sight.
  - Healer Mana: a healer's line glows red below 20% mana, but not while they drink. This works in a fight too, as far as the game allows reading their mana.
- Secondary Stats: new "Fold Away in Combat" (off by default). While docked, Stats folds away when a fight starts and comes back when it ends, and your own folded choice stays as it was. A buff or debuff bar it had moved aside goes back just before the fight locks it. Click the tab mid-fight to bring Stats back for the rest of that fight.

## 1.3.5
- Secondary Stats: docked to the minimap on the panel's left side, it now makes room for Daylight UI's bars at both corners. At a top corner the buffs slide aside, and at a bottom corner the debuffs do. They slide back as Stats folds away, and a bar you moved yourself stays where you put it. A bar waits for the fight to end before it moves. This works through two anchor frames that aren't part of Daylight UI's plugin API, so a future Daylight UI update could stop the bars from moving. Nothing breaks if that happens.

## 1.3.4
- Translations tidied: lines for text the plugin no longer shows are taken out of all six languages.

## 1.3.3
- Translations: the new Nameplate Dmg Text setting (In a Group: the Game's Numbers) in German, French, Spanish, Russian, Korean and Simplified Chinese.

## 1.3.2
- Its own icon: in the game's AddOns list and other menus (instead of the blank "?"), and on its page in Daylight UI's options.

## 1.3.1
- Nameplate Dmg Text shows only your and your pet's damage. This game doesn't tell addons who struck a hit, so in a party or raid the plates also showed your group's hits. New In a Group: the Game's Numbers (on to start): in a group the nameplate numbers pause and the game's own damage numbers show instead, which are only yours and your pet's (Daylight UI's Damage numbers page styles them). Alone, nothing changes. Turn it off to see everyone's hits in a group.

## 1.3.0
- On German, French, Spanish, Russian, Korean and Chinese clients, words the game already translates (like Size, Opacity, Off, Dodge, class and spell names) use the game's own translation instead of our draft.
- Buff Manners: What to Say can be picked any time (it was grayed out, showing your saved line, while How to Thank was Off); it's used once How to Thank is Say or Whisper.
- Shorter setting names: Pet Reminder (Pet Missing, Pet on Passive, Mute in Towns and Inns), Combat Alert (When Combat Ends, Alert Style, Sound on Combat Start), Combat Timer (Show Background, Display Time After Combat), Cursor Cooldowns (Only in Combat, Cursor Anchor Point), Enemy Nearby (Display in Battlegrounds and Dungeons, List Configuration, Max Names Shown, Alert Kill on Sight Targets, Alert on All Enemies...), Secondary Stats (Horizontal and Vertical Shift, Stat Colors, Match Numbers to Stat Color, Green When Hit Capped, Number of Decimal Places, Desaturate Numbers in Fight), Buff Manners (Show Who Buffed Me, Nearby Players, Skip Flagged Players, Mute in Towns and Inns, How to Thank, What to Say, Clear Block List...), Halo (Text in Middle, Dim Icon on Cooldown), Healer Mana (In Party, In Raid, Raid Healer List Count, Show Self, Set Healer, Color Mana Percent, Show Drinking Status) and Nameplate Dmg Text. Healer Mana's "When the group has no roles" is now a switch, Show All Healing Classes (Nobody carries over as off).
- Window opacity is now set on each part's own page (Healer Mana, Combat Timer, Enemy Nearby, Secondary Stats, Buff Manners, Halo), in its Look or Window group; the separate Look page is gone. An opacity of your own from 1.2.0 carries over to every part.
- New: Nameplate Dmg Text (off to start, on its own page). Damage numbers pop off enemy nameplates as they're hit, in Daylight UI's font (or one you pick), colored by school (fire orange, frost blue...), crits bigger with a quick pop, and misses, dodges and parries as words. Numbers on enemies you aren't targeting are smaller and fainter (your choice), or show on your target only. Fountain, Rise, Fall or Rainfall, each set apart for hits, crits and misses, with how long they stay, their height, size and short (1.2K) or full numbers. Its page has a live preview at the top, like Daylight UI's nameplate pages: a training dummy's nameplate with numbers coming off it from your settings, changing as you change them. Click a piece to jump to its settings; in Design mode, drag where the numbers start (or nudge it with the arrow keys) to set their spot over every plate (also the Sideways and Height sliders).
- Turn Off Daylight UI's Combat Text (on to start): while Nameplate Dmg Text is on, all of Daylight UI's combat text is off (its damage numbers, pet numbers and the scrolling combat text around your character) so no hit shows twice; it all comes back as it was when it's off.
- The game gives addons no combat log here, only each hit on a nameplate, without who struck: in a group, everyone's hits on a mob show on its plate.

## 1.2.0
- Halo has a key of its own: Set Key on its page opens a small box that takes the next key you press (a mouse's middle or side button works too); Escape cancels and Clear takes it off. It never changes your saved key bindings, and a key set under Key Bindings, AddOns, Daylight Essentials keeps working beside it. Shift, Alt and Ctrl on their own can't be the key: they open the other Halos. Also /dui halo key.
- Up to three more Halos: Shift Halo, Alt Halo and Ctrl Halo, each switched on on Halo's page (off to start). Hold Shift, Alt or Ctrl with Halo's key to open that Halo instead, in a fight too; a Halo that's off or empty leaves its modifier to the base Halo. Each Halo has its own button, so the one you press is the one that opens, and pressing or letting go of a modifier while you hold the key never switches it. Using Key Bindings instead of Halo's own key? Each Halo has its own entry there (Halo: Shift Halo, Alt Halo, Ctrl Halo). Each has its own slots, kept per character like the base Halo's, which keeps the slots you already had.
- Edit Halos has a tab for each Halo (the ones that are off are dimmed, with a hint to turn them on). Halo's page has a Clear button for each Halo (Clear Base Halo, Clear Shift Halo...), dimmed while that Halo is off; /dui halo clear shift, alt or ctrl empties that one.
- Pointing reads the whole screen from where the Halo opened, so a long flick past it still picks the slot in that direction.
- Each Halo has its own color, so you can tell which one is open: a rim around its icons, the one you point at and its label take it. The base Halo follows your Daylight UI accent unless you pick its own; Shift is blue, Alt green and Ctrl orange to start. All four are on Halo's page, and the editor's tabs show them.
- Each Halo can have a label of up to 16 letters, typed in the slot editor under its tab and kept per character. It shows over the open Halo in the Halo's color, whole at any Halo size, and under the Halo's tab in the editor.
- Fixes for non-English game clients: Cursor Cooldowns keeps your Ready at the Cursor picks by spell, so they stay when the game's language changes (picks saved by name move over the first time the spell is found), and long ability names are shortened at whole letters. Kill on Sight and Buff Manners' Never list match names with accented and Cyrillic capitals (É and é, Д and д) whatever way they were typed; lists you already have keep working. Secondary Stats' thicker outline keeps Daylight UI's fonts for each alphabet, so Russian, Korean and Chinese letters no longer show as boxes. Buff Manners' thank-you line is cut at a whole letter to fit a macro's 255 bytes, and so is a custom line.
- Window Opacity: follows Daylight UI's by default, or set your own on the options page.
- Daylight Essentials speaks German, French, Spanish, Russian, Korean and Simplified Chinese (machine drafts, corrections welcome).

## 1.1.5
- Pet Reminder's sample (unlock and test mode) takes turns showing both warnings, "No pet" and "Pet is passive", and shows on every class, so it can be placed from any character (the warnings themselves stay for hunters and warlocks).
- Secondary Stats steps aside while a whisper conversation is open (Daylight UI's conversation card slides out over where it sits) and comes back once the card has slid away.

## 1.1.4
- Buff Manners no longer offers to thank someone for a passive aura that's there while they're near (a paladin's auras, Trueshot Aura); only buffs cast on you that run out count.

## 1.1.3
- Fixed a Lua error in Buff Manners ("attempt to perform boolean test on field 'isFullUpdate'") when the game hides a buff update's details. Healer Mana's drinking check is guarded the same way.

## 1.1.2
- Fixed the "Binding header DAYLIGHTESSENTIALS was attempted to be loaded more than once" warning at login. The key bindings still sit under Key Bindings, AddOns, Daylight Essentials.

## 1.1.1
- Healer Mana: while a healer is drinking, their line becomes their mana bar, filling as they drink, with "Drinking" on it in place of the percent, so you can see who is getting their mana back and how far along they are; it ends by itself as a fight starts (a switch on its page, on to start).
- Healer Mana: a dead or offline healer's whole line is grayed out (name and class icon), with "Dead" in red or "Offline" in gray in place of the percent, so it reads at a glance.

## 1.1.0
- New: Enemy Nearby, a small list of the enemy players seen near you lately (level and name in class color), the newest at the top. Names fade while unseen and leave after a minute (a choice). It sees players through their nameplates, your target, focus and mouseover, so enemy nameplates have to be shown: its page has the switch.
- Click a name to target that player. In a fight the list keeps its order and players seen during it are added below, clickable once it ends.
- Kill on Sight: right-click a name, or type /dui kos add Name, /dui kos remove Name or /dui kos list. Shared by all your characters; its names are marked in red.
- Alerts: a line in the middle of the screen and a sound when someone on your Kill on Sight list shows up, and if you like when any new enemy does. The same player alerts again only after two minutes (a choice).
- Windowless if you like: just the names, with no window behind them; click and right-click work the same.
- Rests in battlegrounds and dungeons unless you ask otherwise. /dui unlock shows sample names and a sample alert to place them.
- New: Secondary Stats, a small box of the stats that matter for how you play: attack power, crit, hit and haste for melee, their ranged ones for hunters, spell power, spell crit and mana regen for casters and healers, armor, defense, dodge, parry and block for tanks. Auto picks by your group role or your class.
- Custom: pick up to six stats of your own, resistances included, in the order you like.
- Crit, haste, armor, dodge and the like stay live in a fight; attack power, hit, defense and mana regen keep their numbers from before it, dimmed (a choice). As a list or on one line, always or only in or out of a fight; stats at 0 can hide.
- Dock it to the minimap (the default), the damage meters (their own window when detached, else the minimap panel they sit in) or Daylight UI's chat window: it sits flush against that frame's side at a corner, level with it (for the minimap: against the panel's left edge, bottoms together), by default the corner facing the middle of the screen or one you pick, grows away from it, and slides out of that corner and back in from a tab on its edge, the way Daylight UI's damage meter slides out of the minimap panel (the tab shows when the mouse is near). Two nudge sliders fine-tune the spot. Or set it free to place it anywhere with /dui unlock. Windowless (just the text) works docked or free; docked, the fold tab stays. By the damage meters it takes a bottom corner only (bottom-left to start), so the threat meter never slides out over it from the top. When the threat meter grows down past the stats (a bigger group), they step down just enough to sit under it, or, with no room below (a meter at the bottom of the screen), step out to sit beside the threat window, bottoms still level with the meter; they go back as it shrinks or slides away. By the chat it can fade out and back in with the chat window (off to start).
- Hit in green when it's enough: melee, ranged and spell hit turn green when you have enough to never miss your current target, by its level, matching the game's Hit Chance tooltip (5% melee and 4% spells at your level, 8% and 17% against raid bosses). In a fight it goes by your hit from before the fight. A switch on the Look card, on to start.
- Each stat's name in its own color (crits gold, hit blue, haste green, attack power orange, spell power violet...), your class color, or plain; the numbers can take the same color. The text has a slightly heavier outline and a shadow you can size (1 px to start, 0 for none), so the colors read on any ground, and the box fits its text.
- New: Buff Manners, one prompt offering the buff you can give to whoever needs it most: a player who just buffed you, then your target, your group (checked again at a ready check), then players right beside you (friends and guildmates first). Click it or press its key (Key Bindings, AddOns, Daylight Essentials); your own target comes back to you. Nothing is ever cast by itself, and it hides in a fight. Mages give Arcane Intellect, priests Fortitude (Divine Spirit and Shadow Protection are choices), druids Mark of the Wild (and Thorns for tanks), paladins Kings first or Wisdom or Might by class, never over a blessing of their own, warlocks Unending Breath while swimming. Skips PvP-flagged players while you aren't flagged, and can be quiet in towns, dungeons and raids. The idea is from Manners by fpsacha.
- Thanks, for players who buffed you: a /thank and a line in say or a whisper ("Thanks for the buff!", "Thank you, Name!", "Much appreciated!" or your own with /dui manners line), never in a dungeon or raid except a whisper. When they already have everything you can give, or your class has no buffs to give (warriors, rogues, hunters...), the prompt still shows who buffed you and offers a thank-you on its own: a /thank, plus your line if you picked one. With the buff you give back, the thanks go out only once you switch them on.
- Right-click the prompt for Not Now or Never Offer; /dui manners never Name, /dui manners allow Name and /dui manners list manage the Never list.
- New: Halo. Hold a key (Key Bindings, AddOns, Daylight Essentials) for a ring of your own spells, items and macros around the mouse; point at one or scroll to it, then let go to use it. Fill its slots by dragging onto them (the Edit the slots button or /dui halo edit). Choose the shape, the number of slots, the ring size, the icon size and where it opens.
- Cursor Cooldowns: Ready at the Cursor. Pick up to six abilities, and their icons show in a line beside the mouse pointer while each is ready to cast (off cooldown and usable now). You choose the side (Top Left through Left) and the icon size (24 px by default). Picks are kept per class.
- Healer Mana, Combat Timer, Pet Reminder, Enemy Nearby, Secondary Stats and the Buff Manners prompt come up with Daylight UI's own fade-in on login and /reload, instead of popping in (only when Daylight UI's fade-in is on).
- Lighter in play: Secondary Stats only redraws what changed and only watches the threat meter or chat while docked to them; Healer Mana listens to its healers only, not every unit around; Enemy Nearby ignores friendly nameplates; Buff Manners rests when your class has nothing to give and nobody has buffed you, and only touches its button when the offer changes; Cursor Cooldowns and Halo no longer re-read the spellbook or rebuild on every stance change, or refresh on every point of rage or energy.
- Fixed: Halo's mouse wheel picks a slot again; Secondary Stats' fold tab keeps its border after a style change; Enemy Nearby no longer counts the same enemy as new every second with a full list in a fight.
- Nothing is cut short any more: Healer Mana and Enemy Nearby grow wider to fit a long name or "Offline" (their Width is now the least they take), and the option pages' descriptions and dropdown choices fit in full, with the detail in their tooltips.
- Fixed: no more "unknown unit" lines in chat about Combat Alert's "Stays for" and Combat Timer's "Keep the last fight's time" sliders.

## 1.0.0
- New: Daylight Essentials, small combat aids in the Daylight UI look, each with its own switch and page in Daylight UI's options (Plugins, Essentials).
- Healer Mana: your group's healers and the mana each has left (class icon, name in class color, mana in percent, yellow when low and red when nearly out). It keeps working in a fight, when the game hides other players' mana from addons. Healers are the players given the healer role; with no roles set, priests, druids, shamans and paladins (or nobody).
- Combat Timer: how long you've been fighting, and the last fight's length for a few seconds after (tenths of a second and the window ground are choices).
- Combat Alert: "+ Combat" as a fight starts and "- Combat" as it ends, in the middle of the screen (other words, a sound and the size are choices).
- Pet Reminder: for hunters and warlocks, "No pet" or "Pet is passive" until it's sorted. Quiet while mounted, flying, dead, resting in a town (a choice) or under Demonic Sacrifice.
- Cursor Cooldowns: your taunt's and dispels' cooldowns as small icons beside the mouse pointer while they cool down, with the game's own sweep and countdown.
- Everything that shows can be moved with /dui unlock, where samples show to place them; /dui test shows them too.
