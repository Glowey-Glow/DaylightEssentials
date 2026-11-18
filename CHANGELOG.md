# Daylight Essentials

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
