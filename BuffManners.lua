-- Buff Manners: one small prompt in the DaylightUI look offering the buff you can give to the
-- player who needs it most right now: someone who just buffed you, then your target, then your
-- group, then players right beside you. Click it, or press its key (Key Bindings, AddOns, Daylight
-- Essentials), and the buff goes out; your own target comes back to you. Right-click it for "Not
-- now" and "Never offer". Optionally a /thank or a short line for players who buffed you, which
-- is also offered on its own when you have nothing they're missing. Move it with /dui unlock.
-- (The idea is from Manners by fpsacha, MIT licensed; this is written from scratch.)
--
-- The prompt lists up to "Players Listed" people (rows), each row its own secure button; the key
-- gives the top row's buff. A buff of yours on you that is running out is offered too, on a row
-- of its own that casts it on you, and so is one missing on you altogether: worn off in a dungeon,
-- gone with a death ("Rebuff Me When Missing or Low"). "Disable When Busy" lists
-- nobody else while more players than its number want your buff (a crowded city).
--
-- Nothing is ever cast by itself: the game only lets an addon cast from a click or a key press, so
-- the prompt is a secure button (SecureActionButtonTemplate) whose macro is set out of a fight
-- only. In a fight the prompt is hidden (a state driver hides its secure part), and comes back
-- after it. (Daylight UI's buff reminder shows missing group buffs only on a ready check and on
-- entering a dungeon, for a few seconds: a buff that wears off or is lost to a death later in the
-- run was never offered. The row here stays until the buff is back.)
--
-- Who buffed you: the game names the caster of each new buff on you (its sourceUnit) when that
-- player is one of your units (group, target, mouseover, a nameplate). Friendly nameplates help it
-- see more players. In a fight, or under the game's restrictions, these reads can be secret: then
-- nothing is read (every read is wrapped in pcall and checked with ns.Safe).
--
-- What it costs: nothing while it's off. On, it looks when the game says something changed (a
-- buff, a target, a nameplate, the mouse over a player, the group, a mount...). A look every 1.5
-- seconds runs only while it waits on something the game sends no word of: a prompt on screen (its
-- player may walk off, your rebuff counts down), or a player who wants your buff but is out of
-- reach (range has no event). With nobody to offer, nothing runs; something due later (your own
-- buff reaching its rebuff time, a "Not Now" running out) wakes it once, then. The buffs of each
-- player are read once and kept until that player's buffs change (UNIT_AURA). No timers in a fight.

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "buffManners"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["Buff Manners"] })

P.defaults = {
	enabled = true,
	buffedYou = true,
	target = true,
	group = true,
	nearby = "beside",
	skipFlagged = true,
	quietResting = false,
	quietInstances = false,
	priestSpirit = true,
	priestShadow = false,
	thorns = "tanks",
	blessing = "kings",
	emote = false,
	say = "off",
	line = "thanks",
	scale = 1,
	rows = 3,
	busyHide = false,
	busyCount = 10,
	selfTopUp = true,
	selfMinutes = 3,
}

local MAX_ROWS = 6   -- the most rows (secure buttons) the prompt can list

local function BusyOff() return not (G("enabled") and G("busyHide")) end
local function SelfOff() return not (G("enabled") and G("selfTopUp")) end

local class   -- the player's class token, read at login

-- The lines of thanks ({name} = their name). "custom" is typed with /manners line.
local LINES = {
	thanks = L["Thanks for the buff!"],
	name = L["Thank you, {name}!"],
	appreciated = L["Much appreciated!"],
}

P.page = { id = KEY, label = L["Buff Manners"],
	desc = L["One click to buff players who buffed you, and others near you."],
	groups = {
		{ label = L["Buff Manners"],
		  desc = L["Click the prompt, or press its key (Key Bindings, AddOns, Glowey's Essentials). Right-click it for Not Now and Never Offer. Hidden in a fight."],
		  items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "toggle", key = KEY .. ".buffedYou", label = L["Show Who Buffed Me"],
			  desc = L["First in line, for a few minutes after their buff lands. Friendly nameplates help it see them."] },
			{ type = "toggle", key = KEY .. ".target", label = L["My Target"] },
			{ type = "toggle", key = KEY .. ".group", label = L["My Group"],
			  desc = L["Party or raid members missing your buff. Checked again at once on a ready check."] },
			{ type = "dropdown", key = KEY .. ".nearby", label = L["Nearby Players"],
			  values = { off = L["Off"], beside = L["Right Beside Me"], range = L["In Spell Range"] },
			  desc = L["Passers-by missing your buff, seen through friendly nameplates and the mouse. Right Beside Me: about 10 yards. Friends and guildmates come first."] },
			{ type = "slider", key = KEY .. ".rows", label = L["Players Listed"], min = 1, max = MAX_ROWS, step = 1,
			  desc = L["The most players the prompt lists at once, one row each. Click any row; its key gives the top row's buff."] },
			{ type = "toggle", key = KEY .. ".busyHide", label = L["Disable When Busy"],
			  desc = L["Lists nobody while more players than the number below want your buff, as in a crowded city. Your own rebuff still shows."] },
			{ type = "slider", key = KEY .. ".busyCount", label = L["Busy Above This Many Players"], min = 2, max = 40, step = 1,
			  desc = L["Counts everyone the prompt would offer your buff to: who buffed you, your target, group and passers-by."],
			  disabled = BusyOff },
			{ type = "toggle", key = KEY .. ".skipFlagged", label = L["Skip Flagged Players"],
			  desc = L["While you aren't flagged yourself: buffing them would flag you."] },
			{ type = "toggle", key = KEY .. ".quietResting", label = L["Mute in Towns and Inns"] },
			{ type = "toggle", key = KEY .. ".quietInstances", label = L["Mute in Dungeons and Raids"] },
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
		{ label = L["My Buffs"],
		  desc = L["Mages give Arcane Intellect, Priests Fortitude, Druids Mark of the Wild, Paladins a blessing, Warlocks Unending Breath (only while you're swimming). Intellect, Wisdom and Divine Spirit only go to players who use mana."],
		  items = {
			{ type = "toggle", key = KEY .. ".selfTopUp", label = L["Rebuff Me When Missing or Low"],
			  desc = L["When a buff you can cast is missing on you or running out, the prompt offers it on a row of its own: click it, or its key when it's on top, to cast it on yourself."] },
			{ type = "slider", key = KEY .. ".selfMinutes", label = L["Minutes Left to Rebuff Me"], min = 1, max = 10, step = 1,
			  desc = L["In minutes. Never earlier than halfway through the buff."], disabled = SelfOff },
			-- Other languages: the spell and the class in the game's own words.
			{ type = "toggle", key = KEY .. ".priestSpirit", label = ns.GameTagged("Divine Spirit (Priests)", 14752, "PRIEST") },
			{ type = "toggle", key = KEY .. ".priestShadow", label = ns.GameTagged("Shadow Protection (Priests)", 976, "PRIEST") },
			{ type = "dropdown", key = KEY .. ".thorns", label = ns.GameTagged("Thorns (Druids)", 467, "DRUID"),
			  values = { tanks = L["Tanks"], off = L["Off"] },
			  desc = L["Tanks: only players given the tank role in your group."] },
			{ type = "dropdown", key = KEY .. ".blessing", label = ns.GameTagged("Blessing (Paladins)", L["Blessing"], "PALADIN"),
			  values = { kings = L["Kings First"], class = L["Wisdom or Might"] },
			  desc = L["Kings First: Kings when you know it, else Wisdom or Might. Wisdom or Might: Might for warriors and rogues, Wisdom for the rest. Never over a blessing of yours already on them."] },
		} },
		{ label = L["Thanks"],
		  desc = L["For players who buffed you. When they already have all you can give, or your class has no buffs to give, the prompt shows who buffed you and offers a thank-you on its own: a /thank even with these off. Sent with the buff you give back only when switched on. Never in a dungeon or raid, except a whisper."],
		  items = {
			{ type = "toggle", key = KEY .. ".emote", label = L["Thank Them with /thank"],
			  desc = L["Also with the buff you give back. A thank-you on its own is always a /thank (plus your line)."] },
			{ type = "dropdown", key = KEY .. ".say", label = L["How to Thank"],
			  values = { off = L["Off"], say = L["Say"], whisper = L["Whisper"] } },
			{ type = "dropdown", key = KEY .. ".line", label = L["What to Say"],
			  values = { thanks = L["Thanks!"], name = L["Thank you, Name"], appreciated = L["Appreciated"], custom = L["Custom"] },
			  desc = L["Thanks!: \"Thanks for the buff!\" Thank you, Name: \"Thank you, Glowey!\" Appreciated: \"Much appreciated!\" Custom: your own, typed with /manners line Your words ({name} for their name). Used when How to Thank is Say or Whisper."] },
			{ type = "button", label = L["Clear Block List"],
			  desc = L["Everyone you chose Never Offer for is offered again."],
			  func = function() P.ClearNever() end },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- The buffs
-- ---------------------------------------------------------------------------------------------
-- Each: id = the spell (its first rank: casting it by name takes your highest rank), also = the
-- same buff's group version (Prayer, Gift, Greater), who = "all" | "mana" | "tank" | "physical",
-- setting = the switch it needs, swim = only while you're swimming.

local BUFFS = {
	MAGE = { { id = 1459, also = { 23028 }, who = "mana" } },                          -- Arcane Intellect
	PRIEST = {
		{ id = 1243, also = { 21562 }, who = "all" },                                    -- Fortitude
		{ id = 14752, also = { 27681 }, who = "mana", setting = "priestSpirit" },         -- Divine Spirit
		{ id = 976, also = { 27683 }, who = "all", setting = "priestShadow" },            -- Shadow Protection
	},
	DRUID = {
		{ id = 1126, also = { 21849 }, who = "all" },                                    -- Mark of the Wild
		{ id = 467, who = "tank", setting = "thorns" },                                   -- Thorns
	},
	WARLOCK = { { id = 5697, who = "all", swim = true } },                             -- Unending Breath
}

-- Paladin blessings: one per paladin on a player, so never one over a blessing of ours.
local KINGS = { id = 20217, also = { 25898 }, who = "all" }
local WISDOM = { id = 19742, also = { 25894 }, who = "mana" }
local MIGHT = { id = 19740, also = { 25782 }, who = "physical" }
local OTHER_BLESSINGS = { 1038, 25895, 19977, 25890, 20911, 25899 }  -- Salvation, Light, Sanctuary

local MANA = { MAGE = true, PRIEST = true, WARLOCK = true, DRUID = true, PALADIN = true, SHAMAN = true, HUNTER = true }
local PHYSICAL = { WARRIOR = true, ROGUE = true }

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and type(name) == "string" then return name end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, id)
		if ok and type(name) == "string" then return name end
	end
	return nil
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, icon = pcall(C_Spell.GetSpellTexture, id)
		if ok and icon then return icon end
	end
	return 134400   -- the question mark
end

local function Known(id)
	return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

-- Fills in an entry's names (they can be missing until the game has the spell's data).
local function Prepare(b)
	if b.name then return b.name ~= false end
	local name = SpellName(b.id)
	if not name then return false end
	b.name = name
	b.names = { [name] = true }
	for _, id in ipairs(b.also or {}) do
		local n = SpellName(id)
		if n then b.names[n] = true end
	end
	b.icon = SpellIcon(b.id)
	return true
end

local blessingNames
local function BlessingNames()
	if blessingNames then return blessingNames end
	local t, all = {}, true
	for _, b in ipairs({ KINGS, WISDOM, MIGHT }) do
		if Prepare(b) then for n in pairs(b.names) do t[n] = true end else all = false end
	end
	for _, id in ipairs(OTHER_BLESSINGS) do
		local n = SpellName(id)
		if n then t[n] = true else all = false end
	end
	if all then blessingNames = t end
	return t
end

-- ---------------------------------------------------------------------------------------------
-- Reading players (every read wrapped: in a fight or under restrictions they can be secret)
-- ---------------------------------------------------------------------------------------------

local function Read(fn, ...)
	local ok, a, b = pcall(fn, ...)
	if not ok or not Safe(a) or not Safe(b) then return nil end
	return a, b
end

-- A player's buffs: { names = set, mine = set of names cast by you }, or nil if unreadable.
-- Kept per unit until UNIT_AURA says that unit's buffs changed (or the unit is someone else now).
local auraCache = {}

local function Buffs(unit)
	local c = auraCache[unit]
	if c then return c end
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local names, mine = {}, {}
	for i = 1, 40 do
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
		if not ok or not Safe(data) then return nil end
		if data == nil then break end
		local name, src = data.name, data.sourceUnit
		if not Safe(name) or not Safe(src) then return nil end
		if type(name) == "string" then
			names[name] = true
			if src == "player" then mine[name] = true end
		end
	end
	c = { names = names, mine = mine }
	-- (Not the mouseover: it changes without a word from the game.)
	if unit ~= "mouseover" then auraCache[unit] = c end
	return c
end

local function Forget(unit)
	if unit then auraCache[unit] = nil else wipe(auraCache) end
end

local function Has(buffs, b)
	for n in pairs(b.names) do
		if buffs.names[n] then return true end
	end
	return false
end

local function UnitClassOf(unit)
	local _, token = Read(UnitClass, unit)
	return token
end

local function Wants(b, unit)
	local who = b.who
	if who == "all" then return true end
	local c = UnitClassOf(unit)
	if who == "mana" then return c ~= nil and MANA[c] == true end
	if who == "physical" then return c ~= nil and PHYSICAL[c] == true end
	if who == "tank" then
		return UnitGroupRolesAssigned and Read(UnitGroupRolesAssigned, unit) == "TANK" or false
	end
	return false
end

local function Usable(name)
	if C_Spell and C_Spell.IsSpellUsable then
		local usable = Read(C_Spell.IsSpellUsable, name)
		return usable ~= false
	end
	return true
end

-- Whether a buff's own switch lets it be offered now (a warlock's breath only while swimming).
local function Switched(b)
	if b.setting == "thorns" then
		if G("thorns") ~= "tanks" then return false end
	elseif b.setting and G(b.setting) ~= true then
		return false
	end
	if b.swim and not (IsSwimming and IsSwimming()) then return false end
	return true
end

-- The buff of yours this player is missing (an entry of BUFFS), or nil.
local function Pick(unit, buffs)
	if class == "PALADIN" then
		local mine = buffs.mine
		for n in pairs(BlessingNames()) do
			if mine[n] then return nil end   -- one blessing of ours is on them already
		end
		local order
		local c = UnitClassOf(unit)
		local fits = (c and PHYSICAL[c]) and MIGHT or WISDOM
		if G("blessing") == "class" then order = { fits } else order = { KINGS, fits } end
		for _, b in ipairs(order) do
			if Known(b.id) and Prepare(b) and not Has(buffs, b) and Usable(b.name) then return b end
		end
		return nil
	end
	for _, b in ipairs(BUFFS[class] or {}) do
		if Switched(b) and Known(b.id) and Prepare(b) and Wants(b, unit) and not Has(buffs, b) and Usable(b.name) then
			return b
		end
	end
	return nil
end

-- A buff of yours on you that runs out within "Minutes Left to Rebuff Me" (never earlier than
-- halfway through it): the entry to cast again and the seconds left, or nil. Else one missing on
-- you: the entry, 0 and true. Read fresh each look
-- (time passes without a UNIT_AURA). Out of a fight only, and any field the game keeps secret
-- (Safe) passes that aura over: the same reads as the game's own buff frame, expirationTime minus
-- GetTime() and duration 0 for a buff that never runs out (Blizzard_BuffFrame/BuffFrame.lua 733-734).
-- What a look leaves behind: whether it waits on something with no event (a player out of
-- reach), and the soonest time something is due without one (Wake): see Settle.
local reach, wakeAt = false, nil
local function Wake(t)
	if not wakeAt or t < wakeAt then wakeAt = t end
end

local function SelfDue()
	if not G("selfTopUp") or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local list = class == "PALADIN" and { KINGS, WISDOM, MIGHT } or BUFFS[class]
	if not list then return nil end
	local lead = (tonumber(G("selfMinutes")) or 3) * 60
	local now = GetTime()
	local best, bestLeft
	for i = 1, 40 do
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok or not Safe(data) or type(data) ~= "table" then break end
		local name, ends, length, src = data.name, data.expirationTime, data.duration, data.sourceUnit
		if Safe(name) and Safe(ends) and Safe(length) and Safe(src) and type(name) == "string"
			and type(ends) == "number" and ends > 0 and type(length) == "number" and length > 0 then
			local left = ends - now
			local due = math.min(lead, length / 2)
			if left > 0 and (not bestLeft or left < bestLeft) then
				for _, b in ipairs(list) do
					-- (A paladin's: only a blessing of ours, as one per paladin is allowed.)
					if (class ~= "PALADIN" or src == "player") and Switched(b) and Known(b.id) and Prepare(b)
						and b.names[name] and Wants(b, "player") and Usable(b.name) then
						if left <= due then
							best, bestLeft = b, left
						else
							Wake(ends - due)   -- (not due yet: a look then)
						end
						break
					end
				end
			end
		end
	end
	if best then return best, bestLeft end
	-- Missing on you altogether (worn off, gone with a death): the same choice as for anyone else
	-- (Pick: its switch, known, wanted by your class, none of its names on you, castable now; a
	-- paladin's, only with no blessing of its own on you). Left 0: the row says it's missing.
	local buffs = Buffs("player")
	local b = buffs and Pick("player", buffs)
	if b then return b, 0, true end
	return nil
end

-- Whether a unit is a player we may offer anything to (not range: that's per spell).
local tried, snoozed = {}, {}   -- GUID -> time: just tried (skip a while), "Not Now" (skip longer)
local TRIED, SNOOZE = 20, 600

local neverFolded = false
local function NeverDB()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if type(db.mannersNever) ~= "table" then db.mannersNever = {} end
	-- (Names kept before 1.2.0 were lowered A to Z only: once a session they move to ns.Fold's key.)
	if not neverFolded then
		neverFolded = true
		ns.FoldKeys(db.mannersNever)
	end
	return db.mannersNever
end

local function FullName(unit)
	local name = Read(GetUnitName, unit, true)
	if type(name) == "string" and name ~= "" and name ~= UNKNOWNOBJECT then return name end
	return nil
end

local function Candidate(unit)
	if not Read(UnitExists, unit) or not Read(UnitIsPlayer, unit) then return nil end
	if Read(UnitIsUnit, unit, "player") then return nil end
	if not Read(UnitIsConnected, unit) or Read(UnitIsDeadOrGhost, unit) then return nil end
	if not Read(UnitCanAssist, "player", unit) or not Read(UnitIsVisible, unit) then return nil end
	if G("skipFlagged") and Read(UnitIsPVP, unit) and not Read(UnitIsPVP, "player") then return nil end
	local guid, name = Read(UnitGUID, unit), FullName(unit)
	if type(guid) ~= "string" or not name then return nil end
	local now = GetTime()
	if tried[guid] and now - tried[guid] < TRIED then Wake(tried[guid] + TRIED) return nil end
	if snoozed[guid] and now - snoozed[guid] < SNOOZE then Wake(snoozed[guid] + SNOOZE) return nil end
	if NeverDB()[ns.Fold(name)] then return nil end
	return guid, name
end

local function InRange(spell, unit)
	if not (C_Spell and C_Spell.IsSpellInRange) then return true end
	return Read(C_Spell.IsSpellInRange, spell, unit) == true
end

local function Beside(unit)
	if not CheckInteractDistance then return false end
	return Read(CheckInteractDistance, unit, 3) == true
end

-- ---------------------------------------------------------------------------------------------
-- Players who buffed you
-- ---------------------------------------------------------------------------------------------

local buffedBy = {}   -- GUID -> { name, short, class, icon, at }
local BUFFED_FOR = 180

local function NoteBuffs(updateInfo)
	if not G("enabled") or InCombatLockdown() then return end
	-- (The update can come with its fields hidden by the game: then there's nothing to read.)
	if type(updateInfo) ~= "table" or not Safe(updateInfo) then return end
	local full, added = updateInfo.isFullUpdate, updateInfo.addedAuras
	if not Safe(full) or full or not Safe(added) or type(added) ~= "table" then return end
	local before = next(buffedBy)
	for _, data in ipairs(added) do
		if Safe(data) and type(data) == "table" then
			local src, helpful, duration = data.sourceUnit, data.isHelpful, data.duration
			-- Only a buff someone cast on you, which runs out: not an aura that's there while they're
			-- near (a paladin's auras, Trueshot Aura), which has no duration. (A duration the game
			-- hides is passed over too.)
			local timed = Safe(duration) and type(duration) == "number" and duration > 0
			if timed and Safe(src) and Safe(helpful) and helpful and type(src) == "string"
				and src ~= "player" and src ~= "pet" and src ~= "vehicle" then
				local guid = Read(UnitGUID, src)
				local name = FullName(src)
				if Read(UnitIsPlayer, src) and not Read(UnitIsUnit, src, "player") and type(guid) == "string" and name then
					local icon = data.icon
					buffedBy[guid] = { name = name, short = Read(UnitName, src) or name, class = UnitClassOf(src),
						icon = Safe(icon) and icon or nil, at = GetTime() }
				end
			end
		end
	end
	-- (A class with no buffs to give rests until someone buffs it: looking again now.)
	if not before and next(buffedBy) and P.Wake then P.Wake() end
end

-- ---------------------------------------------------------------------------------------------
-- The prompt
-- ---------------------------------------------------------------------------------------------

local frame, body     -- frame: what /dui unlock moves; body: the look
local rows = {}       -- rows[i]: { icon, iconEdge, title, sub } painted in the body, top to bottom
local holder          -- the secure part, laid over the body out of a fight
local buttons = {}    -- buttons[i]: row i's secure button (1 is the one the key clicks)
local W, H, ICON, PAD, GAP = 200, 40, 28, 6, 8
local DEFAULT = { "CENTER", UIParent, "CENTER", 0, -170 }
-- What the prompt offers now, a row each: { guid, unit, name, short, class, spell, reason, thanks,
-- left }. A row the pointer holds whose player has gone is { blank = true } (see Hold).
local offers = {}
local previewing = false

-- (Whole lines: "%s" is the player's name, in their class color.)
local REASON = { buffed = L["%s  buffed you"], target = L["%s  your target"], group = L["%s  your group"], nearby = L["%s  nearby"] }

-- The time left on a buff of yours: whole minutes, or seconds under one.
local function Left(seconds)
	if seconds >= 60 then return L["%d min left on you"]:format(math.ceil(seconds / 60)) end
	return L["%d sec left on you"]:format(math.max(1, math.floor(seconds)))
end

local function Say(msg) print("|cff73a0ffBuff Manners|r: " .. msg) end

-- The words of thanks for this player, or nil.
local function Line(short)
	local key = G("line")
	NeverDB()   -- (makes sure DaylightEssentialsDB is there)
	local text = key == "custom" and _G.DaylightEssentialsDB.mannersLine or LINES[key]
	if type(text) ~= "string" or text == "" then text = LINES.thanks end
	return (text:gsub("{name}", short or ""))
end

-- How to thank them: emote (true or false) and a line's channel (or nil). onlyThanks: the prompt
-- is a thank-you on its own (nothing of yours they're missing), so it's at least a /thank even with
-- both switched off (never in a dungeon or raid, where a whisper is the only way).
local function ThanksWanted(inInstance, onlyThanks)
	local emote = G("emote") and not inInstance
	local say = G("say")
	if say == "say" and inInstance then say = "off" end
	if say == "off" then say = nil end
	if onlyThanks and not emote and not say and not inInstance then emote = true end
	return emote, say
end

-- A macro holds 255 bytes, and a letter in another language takes two to four of them: the words
-- of thanks get the room the rest leaves, cut at the end of a whole letter.
local MACRO_MAX = 255

local function Macro(o)
	-- Your own buff running out: cast on you, your target left alone.
	if o.reason == "self" then return "/cast [@player] " .. o.spell.name end
	local lines = {}
	local inInstance = IsInInstance and IsInInstance() or false
	local emote, say = nil, nil
	if o.thanks then emote, say = ThanksWanted(inInstance, o.spell == nil) end
	local isTarget = Read(UnitIsUnit, o.unit, "target")
	local swap = not isTarget and (emote or not o.unit:match("^party%d") and not o.unit:match("^raid%d"))
	if swap then lines[#lines + 1] = "/targetexact " .. o.name end
	if o.spell then
		if swap or isTarget then
			-- ([help]: if the name wasn't found, an enemy you had targeted gets nothing)
			lines[#lines + 1] = "/cast [@target,help] " .. o.spell.name
		else
			lines[#lines + 1] = "/cast [@" .. o.unit .. "] " .. o.spell.name
		end
	end
	if emote then lines[#lines + 1] = "/thank" end
	local chat
	if say == "say" then chat = "/s "
	elseif say == "whisper" then chat = "/w " .. o.name .. " " end
	local back = swap and (Read(UnitExists, "target") and "/targetlasttarget" or "/cleartarget") or nil
	if chat then
		local used = #table.concat(lines, "\n") + (#lines > 0 and 1 or 0) + #chat + (back and #back + 1 or 0)
		local words = ns.CutBytes(Line(o.short), MACRO_MAX - used)
		if words ~= "" then lines[#lines + 1] = chat .. words end
	end
	if back then lines[#lines + 1] = back end
	return table.concat(lines, "\n")
end

-- One row's words and icon (a BLANK row shows nothing: the pointer holds its place).
local function PaintRow(r, o)
	local shown = not o.blank
	r.icon:SetShown(shown)
	r.iconEdge:SetShown(shown)
	r.title:SetShown(shown)
	r.sub:SetShown(shown)
	if not shown then return 0 end
	local spell = o.spell
	r.icon:SetTexture(spell and spell.icon or o.icon or 136243)
	r.title:SetText(spell and spell.name or L["Thank %s"]:format(o.short))
	if o.reason == "self" then
		r.sub:SetText(o.missing and L["Missing on you"] or Left(o.left or 0))
	else
		local cr, cg, cb = 1, 1, 1
		if o.class then cr, cg, cb = API.ClassColor(o.class) end
		r.sub:SetText((REASON[o.reason] or "%s  "):format(("|cff%02x%02x%02x%s|r"):format(math.floor(cr * 255),
			math.floor(cg * 255), math.floor(cb * 255), o.short or o.name)))
	end
	ns.Ink(r.title, "TITLE")
	ns.Ink(r.sub, "LABEL")
	return math.max(ns.TextWidth(r.title) or 0, ns.TextWidth(r.sub) or 0)
end

-- The rows on show. The frame (what /dui unlock moves) stays one row high and the rows below hang
-- from its top, so the top row never moves as the list grows or shrinks.
local sizedAs   -- the box's last size and scale (skinned again only when they change)
local function Paint(list)
	local tw = 0
	for i = 1, MAX_ROWS do
		local r, o = rows[i], list[i]
		if o then
			tw = math.max(tw, PaintRow(r, o))
		else
			r.icon:Hide()
			r.iconEdge:Hide()
			r.title:Hide()
			r.sub:Hide()
		end
	end
	-- The box fits its words: nothing is cut short.
	local w = math.max(W, math.ceil(PAD * 2 + ICON + GAP + tw + 2))
	local n = math.max(1, #list)
	local scale = G("scale") or 1
	local sig = w .. ":" .. n .. ":" .. scale
	if sig == sizedAs then return end
	sizedAs = sig
	body:SetSize(w, H * n)
	body:SetScale(scale)
	frame:SetSize(w * scale, H * scale)
	ns.SkinWindow(body, nil, KEY)
end

-- The secure part over the body (out of a fight only): one button per row.
local placedAs                -- the secure part's last spot (set again only when changed)
local macroText = {}          -- each button's last macro (set again only when changed)
local function HideButtons(from)
	for i = from, MAX_ROWS do
		local b = buttons[i]
		if b and b:IsShown() then b:Hide() end
	end
end

local function PlaceButton()
	if InCombatLockdown() or not holder then return end
	local l, t = body:GetLeft(), body:GetTop()
	if not l or not t or not body:IsVisible() or previewing or not offers[1] then
		HideButtons(1)
		placedAs = nil
		return
	end
	local s = body:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local w, h = body:GetWidth() * s, body:GetHeight() * s
	local rowH = H * s
	local spot = l * s .. ":" .. t * s .. ":" .. w .. ":" .. h
	if spot ~= placedAs then
		placedAs = spot
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
		holder:SetSize(w, h)
		holder:SetFrameStrata(frame:GetFrameStrata())
		holder:SetFrameLevel(frame:GetFrameLevel() + 20)
		for i = 1, MAX_ROWS do
			local b = buttons[i]
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * rowH)
			b:SetSize(w, rowH)
		end
	end
	for i = 1, MAX_ROWS do
		local o, b = offers[i], buttons[i]
		if o then
			-- (A blank row stays under the pointer, holding its place, and casts nothing.)
			local m = o.blank and "" or Macro(o)
			if m ~= macroText[i] then
				macroText[i] = m
				b:SetAttribute("macrotext1", m)
			end
			if not b:IsShown() then b:Show() end
		elseif b:IsShown() then
			b:Hide()
		end
	end
end

local shownAs   -- the offers on show (who, which buff, why): painted again only when they change
local function ShowOffers(list)
	offers = list or {}
	if offers[1] then
		local keys = { previewing and "p" or "", tostring(G("scale") or 1) }
		for _, o in ipairs(offers) do
			if o.blank then
				keys[#keys + 1] = "-"
			else
				keys[#keys + 1] = (o.guid or o.name) .. ":" .. (o.spell and o.spell.name or "") .. ":" .. o.reason
					.. (o.thanks and ":t" or "") .. (o.reason == "self" and ":" .. (o.missing and "missing" or Left(o.left or 0)) or "")
			end
		end
		local key = table.concat(keys, "|")
		if key ~= shownAs or not body:IsShown() then
			shownAs = key
			Paint(offers)
		end
		body:Show()
		if not frame:IsShown() then frame:Show() end
	else
		shownAs = nil
		body:Hide()
	end
	PlaceButton()
end

-- ---------------------------------------------------------------------------------------------
-- Looking for someone to buff
-- ---------------------------------------------------------------------------------------------

local function Quiet()
	if not G("enabled") then return true end
	if Read(UnitIsDeadOrGhost, "player") then return true end
	if IsMounted and IsMounted() then return true end
	if UnitOnTaxi and UnitOnTaxi("player") then return true end
	if G("quietResting") and IsResting() then return true end
	if G("quietInstances") then
		local inside, kind = IsInInstance()
		if inside and (kind == "party" or kind == "raid") then return true end
	end
	return false
end

-- The group's unit tokens, made once (read only: never changed by whoever asks).
local RAID_UNITS, PARTY_UNITS, NO_UNITS = {}, {}, {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end
for i = 1, 4 do PARTY_UNITS[i] = "party" .. i end

local function GroupUnits()
	if IsInRaid() then return RAID_UNITS end
	if IsInGroup() then return PARTY_UNITS end
	return NO_UNITS
end

local plates = {}   -- nameplate unit tokens on screen now

local function Try(unit, reason, seen, thanksFor)
	local guid, name = Candidate(unit)
	if not guid or seen[guid] then return nil end
	seen[guid] = true
	-- (A passer-by too far away: not offered. Their buffs are kept per player, so whether they
	-- want yours is a cheap read: if they do, the look waits for them to come close.)
	local far = reason == "nearby" and G("nearby") == "beside" and not Beside(unit)
	local buffs = Buffs(unit)
	if not buffs then return nil end
	local spell = Pick(unit, buffs)
	if far then
		if spell then reach = true end
		return nil
	end
	local thanks = thanksFor and thanksFor[guid] or nil
	if spell then
		if not InRange(spell.name, unit) then
			reach = true
			return nil
		end
	elseif thanks then
		local inInstance = IsInInstance and IsInInstance() or false
		local emote, say = ThanksWanted(inInstance, true)
		if not (emote or say) then return nil end
		-- (An emote or a line in say: only to someone close enough to see it, about 28 yards.)
		if say ~= "whisper" and CheckInteractDistance and Read(CheckInteractDistance, unit, 4) ~= true then
			reach = true
			return nil
		end
	else
		return nil
	end
	return { guid = guid, unit = unit, name = name, short = Read(UnitName, unit) or name, class = UnitClassOf(unit),
		spell = spell, reason = thanks and "buffed" or reason, thanks = thanks and true or nil,
		icon = thanks and thanks.icon or nil }
end

-- The units that could be someone who buffed you: group, target, focus, mouseover, nameplates.
-- (One list, filled again on each look: nothing that walks it looks again meanwhile.)
local known = {}
local function KnownUnits()
	wipe(known)
	known[1], known[2], known[3] = "target", "focus", "mouseover"
	for _, u in ipairs(GroupUnits()) do known[#known + 1] = u end
	for u in pairs(plates) do known[#known + 1] = u end
	return known
end

-- Whether your class has a buff to give right now (a warlock's breath only while swimming).
local function CanGive()
	if class == "PALADIN" then return true end
	local list = BUFFS[class]
	if not list then return false end
	if class == "WARLOCK" then return (IsSwimming and IsSwimming()) and true or false end
	return true
end

-- How many rows the prompt lists ("Players Listed").
local function Limit()
	return math.max(1, math.min(MAX_ROWS, math.floor(tonumber(G("rows")) or 1)))
end

-- Your own buff running out, as a row of its own, or nil.
local function SelfOffer()
	local spell, left, missing = SelfDue()
	if not spell then return nil end
	local guid = Read(UnitGUID, "player")
	if type(guid) ~= "string" then return nil end
	local now = GetTime()
	if tried[guid] and now - tried[guid] < TRIED then Wake(tried[guid] + TRIED) return nil end
	if snoozed[guid] and now - snoozed[guid] < SNOOZE then Wake(snoozed[guid] + SNOOZE) return nil end
	local short = Read(UnitName, "player") or ""
	return { guid = guid, unit = "player", name = FullName("player") or short, short = short, class = class,
		spell = spell, reason = "self", left = left, missing = missing }
end

-- Everyone to offer, in order, as a list of rows (at most "Players Listed"): who buffed you, your
-- own buff running out, your target, your group, then players nearby. With Disable When Busy on,
-- the others are counted up to its number and, past it, left out (your own row stays).
local function Find()
	local seen = {}
	local now = GetTime()
	for guid, e in pairs(buffedBy) do
		if now - e.at > BUFFED_FOR then buffedBy[guid] = nil end
	end
	local limit = Limit()
	local busy = G("busyHide") and math.max(1, math.floor(tonumber(G("busyCount")) or 10)) or nil
	-- (Busy: counted one past its number, to know it's passed; else no more than the rows.)
	local cap = busy and math.max(limit, busy + 1) or limit
	local others = {}
	local function Add(o)
		if o then others[#others + 1] = o end
		return #others >= cap
	end
	-- 1. Someone who buffed you.
	local full = false
	if G("buffedYou") and next(buffedBy) then
		for _, u in ipairs(KnownUnits()) do
			local guid = Read(UnitGUID, u)
			if type(guid) == "string" and buffedBy[guid] and not seen[guid] then
				full = Add(Try(u, "buffed", seen, buffedBy))
				if full then break end
			end
		end
	end
	local thanked = #others
	-- 2. Your own buff running out (not one of the others: never counted as busy).
	local mine = SelfOffer()
	-- Nothing of yours to give: only the thank-yous above.
	if not full and CanGive() then
		-- 3. Your target.
		if G("target") then full = Add(Try("target", "target", seen)) end
		-- 4. Your group.
		if not full and G("group") then
			for _, u in ipairs(GroupUnits()) do
				full = Add(Try(u, "group", seen))
				if full then break end
			end
		end
		-- 5. Players nearby: friends and guildmates first.
		if not full and G("nearby") ~= "off" then
			local first, rest = {}, {}
			for u in pairs(plates) do
				local guid = Read(UnitGUID, u)
				local close = (UnitIsInMyGuild and Read(UnitIsInMyGuild, u))
					or (type(guid) == "string" and C_FriendList and C_FriendList.IsFriend and Read(C_FriendList.IsFriend, guid))
				if close then first[#first + 1] = u else rest[#rest + 1] = u end
			end
			rest[#rest + 1] = "mouseover"
			for _, list in ipairs({ first, rest }) do
				for _, u in ipairs(list) do
					full = Add(Try(u, "nearby", seen))
					if full then break end
				end
				if full then break end
			end
		end
	end
	if busy and #others > busy then others, thanked = {}, 0 end
	local out = {}
	for i = 1, thanked do out[#out + 1] = others[i] end
	if mine then out[#out + 1] = mine end
	for i = thanked + 1, #others do out[#out + 1] = others[i] end
	for i = limit + 1, #out do out[i] = nil end
	return out
end

-- While the pointer is on a row, that row keeps the player it named (the list is found again
-- every look, and in a crowd its order moves, so a click meant for one name would go to whoever
-- slid into the row). Someone still listed stays in their row; someone gone leaves it blank, and
-- a blank row casts nothing. The others fill the rest in order. The pointer gone, the order comes
-- back at the next look. (Manners does the same; this is our own.)
local hovered = {}   -- row index -> true while the pointer is on its button

local function Id(o) return o.held or o.guid or o.name end

local function Hold(list, limit)
	if not next(hovered) then return list end
	local out, used, last = {}, {}, 0
	for i = 1, limit do
		local was = hovered[i] and offers[i]
		if was then
			local id = Id(was)
			for j, o in ipairs(list) do
				if not used[j] and Id(o) == id then
					out[i], used[j] = o, true
					break
				end
			end
			if not out[i] then out[i] = { blank = true, held = id } end
			last = i
		end
	end
	if last == 0 then return list end
	local j = 1
	for i = 1, limit do
		if not out[i] then
			while used[j] do j = j + 1 end
			if list[j] then
				out[i], used[j] = list[j], true
			elseif i < last then
				out[i] = { blank = true }
			else
				break
			end
		end
	end
	return out
end

local looking = false
local Settle   -- below
local function Look()
	looking = false
	if not frame or InCombatLockdown() then return end
	reach, wakeAt = false, nil
	previewing = G("enabled") and ns.Previewing(KEY) or false
	if previewing then
		-- A buff of yours to give, or for a class with none, the thank-you on its own; then as many
		-- sample rows as Players Listed shows.
		local sample = (BUFFS[class] and BUFFS[class][1]) or (class == "PALADIN" and KINGS) or nil
		if sample and not Prepare(sample) then sample = nil end
		local list = { { unit = "player", name = "Glowey", short = "Glowey", class = "PRIEST", reason = "buffed",
			spell = sample, icon = 135987, thanks = true } }
		local limit = Limit()
		if sample and G("selfTopUp") and #list < limit then
			list[#list + 1] = { unit = "player", name = "self", short = "", class = class, reason = "self",
				spell = sample, left = 120 }
		end
		local names = { { "Daylight", "MAGE", "group" }, { "Aurora", "DRUID", "nearby" }, { "Ember", "WARRIOR", "nearby" },
			{ "Solstice", "PALADIN", "nearby" }, { "Halo", "ROGUE", "nearby" } }
		for _, e in ipairs(names) do
			if #list >= limit or not sample then break end
			list[#list + 1] = { unit = "player", name = e[1], short = e[1], class = e[2], reason = e[3], spell = sample }
		end
		ShowOffers(list)
		Settle()
		return
	end
	if Quiet() or not class then
		ShowOffers(nil)
		Settle()
		return
	end
	local limit = Limit()
	ShowOffers(Hold(Find(), limit))
	Settle()
end

local function LookSoon(delay)
	if looking then return end
	looking = true
	C_Timer.After(delay or 0.1, Look)
end

-- A look every 1.5 seconds only while it waits on what the game sends no word of: the prompt
-- showing someone (they may walk off; your rebuff's minutes count down), a player who wants your
-- buff out of reach, or a warlock on the move (swimming has no event: looked at while you move).
-- Else it rests, woken by events, and once at the soonest time something falls due (Wake).
local ticker
-- (Someone out of reach and nothing on screen: looked at for 30 seconds after the last word from
-- the game, then it rests until the next one. In a city someone always wants a buff from afar.)
local REACH_LOOKS = 20
local reachLeft = REACH_LOOKS
local moving = false   -- a warlock moving (PLAYER_STARTED_MOVING .. PLAYER_STOPPED_MOVING)
local wakeSet, wakeToken = nil, 0
local function Rest()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	wakeSet, wakeToken = nil, wakeToken + 1
end
Settle = function()
	local held = offers[1] ~= nil or (class == "WARLOCK" and moving)
	local waiting = not previewing and (held or (reach and reachLeft > 0))
	if waiting and G("enabled") and not InCombatLockdown() then
		if not ticker then
			ticker = C_Timer.NewTicker(1.5, function()
				if not (offers[1] ~= nil or (class == "WARLOCK" and moving)) then reachLeft = reachLeft - 1 end
				if not looking then Look() end
			end)
		end
		return
	end
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	-- (Only an earlier time than the one already set: one wake waiting at most.)
	if wakeAt and G("enabled") and (not wakeSet or wakeAt < wakeSet - 0.05) then
		wakeSet, wakeToken = wakeAt, wakeToken + 1
		local mine = wakeToken
		C_Timer.After(math.max(0.1, wakeAt - GetTime() + 0.05), function()
			if mine ~= wakeToken then return end
			wakeSet = nil
			if not looking then Look() end
		end)
	end
end

function P.Wake()
	if frame and G("enabled") and not InCombatLockdown() then
		LookSoon()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Right-click, never list, slash command
-- ---------------------------------------------------------------------------------------------

function P.ClearNever()
	wipe(NeverDB())
	Say(L["your Never list is empty again."])
	LookSoon()
end

local function Never(name, on)
	local db = NeverDB()
	if on then db[ns.Fold(name)] = name else db[ns.Fold(name)] = nil end
	LookSoon()
end

local function NotNow(o)
	if not o or o.blank then return end
	if o.guid then snoozed[o.guid] = GetTime() end
	buffedBy[o.guid or ""] = nil
	LookSoon()
end

local function Menu(owner, o)
	if not o or o.blank or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(o.reason == "self" and o.spell.name or o.name)
		root:CreateButton(L["Not Now"], function() NotNow(o) end)
		-- (Never Offer is for other players: your own rebuff has its switch on the page.)
		if o.reason == "self" then return end
		root:CreateButton(L["Never Offer %s"]:format(o.short or o.name), function()
			Never(o.name, true)
			Say(L["%s won't be offered again (/manners allow %s to undo)."]:format(o.short or o.name, o.name))
		end)
	end)
end

local function Command(rest)
	rest = type(rest) == "string" and rest or ""
	local word, arg = rest:match("^%s*(%S*)%s*(.-)%s*$")
	word = string.lower(word or "")
	if word == "never" or word == "allow" then
		local name = arg ~= "" and arg or (UnitExists("target") and FullName("target"))
		if not name then
			Say(word == "never" and L["/manners never Name (or target a player)."] or L["/manners allow Name (or target a player)."])
		else
			Never(name, word == "never")
			Say((word == "never" and L["%s won't be offered."] or L["%s can be offered again."]):format(name))
		end
	elseif word == "list" then
		local names = {}
		for _, n in pairs(NeverDB()) do names[#names + 1] = n end
		table.sort(names)
		Say(#names == 0 and L["your Never list is empty."] or L["Never offer: %s"]:format(table.concat(names, L[", "])))
	elseif word == "line" then
		-- One line, no links or slash commands in it.
		local text = arg:gsub("[\r\n|]", ""):gsub("^/+", "")
		text = ns.CutBytes(text, 200)
		if text == "" then
			Say(L["your line: %s. Type /manners line Your words ({name} for their name)."]:format(Line(L["Name"])))
		else
			NeverDB()
			_G.DaylightEssentialsDB.mannersLine = text
			Say(L["your line is now: %s (pick Custom under Thanks to use it)."]:format(text))
		end
	else
		Say(L["/manners never Name, /manners allow Name, /manners list, /manners line Your words."])
	end
end

-- ---------------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------------

-- (What the old steady look used to catch, now heard: a group member coming in or out of range,
-- online, into your phase; the mouse onto a player; a flight path's start and end; a buff castable
-- again with the mana for it.)
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
	"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_AURA", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
	"READY_CHECK", "SPELLS_CHANGED", "PLAYER_UPDATE_RESTING", "PLAYER_MOUNT_DISPLAY_CHANGED", "ZONE_CHANGED_NEW_AREA",
	"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION", "UNIT_PHASE",
	"UPDATE_MOUSEOVER_UNIT", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "SPELL_UPDATE_USABLE" }
-- A warlock's breath is offered only while swimming, which has no event: moving is.
local WARLOCK_EVENTS = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }

-- Heard only out of a fight: nothing reads players' buffs or the nameplates in one (Look waits,
-- NoteBuffs too), and the end of the fight forgets every buff read before it. The nameplates up
-- then are read again (SeePlates).
local QUIET_IN_COMBAT = { "UNIT_AURA", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_IN_RANGE_UPDATE",
	"UNIT_CONNECTION", "UNIT_PHASE", "UPDATE_MOUSEOVER_UNIT", "SPELL_UPDATE_USABLE" }

local function SeePlates()
	wipe(plates)
	if C_NamePlate and C_NamePlate.GetNamePlates then
		for _, p in ipairs(C_NamePlate.GetNamePlates() or {}) do
			if p.namePlateUnitToken then plates[p.namePlateUnitToken] = true end
		end
	end
end

local function QuietInCombat(on)
	for _, e in ipairs(QUIET_IN_COMBAT) do
		if on then pcall(frame.UnregisterEvent, frame, e) else pcall(frame.RegisterEvent, frame, e) end
	end
end

local SLOW_WORD = { SPELL_UPDATE_USABLE = true, UPDATE_MOUSEOVER_UNIT = true, UNIT_IN_RANGE_UPDATE = true }
local function OnEvent(_, event, unit, info)
	if event == "UNIT_AURA" then
		-- Only a buff added or taken away changes what we read (refreshed timers and stacks don't).
		local changed = true
		if type(info) == "table" and Safe(info) and Safe(info.isFullUpdate) and not info.isFullUpdate then
			local added, removed = info.addedAuras, info.removedAuraInstanceIDs
			-- (Hidden lists: counted as a change, to be safe.)
			if Safe(added) and Safe(removed) then
				changed = (type(added) == "table" and #added > 0) or (type(removed) == "table" and #removed > 0)
			end
		end
		if changed then Forget(unit) end
		if unit == "player" then NoteBuffs(info) end
		return
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		Forget(unit)
		plates[unit] = true
		return
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		Forget(unit)
		plates[unit] = nil
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		QuietInCombat(true)
		wipe(plates)
		Rest()
		offers = {}
		wipe(hovered)
		body:Hide()   -- (the secure part is hidden by its state driver)
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		QuietInCombat(false)
		SeePlates()
		Forget()
		LookSoon(0.5)
		return
	elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
		Forget()
		if event == "PLAYER_ENTERING_WORLD" then wipe(plates) end
	elseif event == "PLAYER_TARGET_CHANGED" then
		Forget("target")
	elseif event == "PLAYER_FOCUS_CHANGED" then
		Forget("focus")
	elseif event == "SPELLS_CHANGED" then
		blessingNames = nil
	elseif event == "PLAYER_STARTED_MOVING" then
		moving = true
	elseif event == "PLAYER_STOPPED_MOVING" then
		moving = false
	end
	reachLeft = REACH_LOOKS
	-- (The chatty ones, a mana tick, a mouseover, a range flip: half a second, so a stream of them
	-- is two looks a second at most.)
	LookSoon(SLOW_WORD[event] and 0.5 or nil)
end

local function Build()
	frame = CreateFrame("Frame", "DaylightEssentialsBuffManners", UIParent)
	frame:SetSize(W, H)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	body = CreateFrame("Frame", nil, frame)
	body:SetSize(W, H)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	body:Hide()
	-- The rows, top to bottom, each H high: icon, then the buff over who and why.
	for i = 1, MAX_ROWS do
		local r = {}
		r.iconEdge = body:CreateTexture(nil, "ARTWORK", nil, 1)
		r.iconEdge:SetSize(ICON + 2, ICON + 2)
		r.iconEdge:SetPoint("LEFT", body, "TOPLEFT", PAD - 1, -(i - 0.5) * H)
		r.iconEdge:SetColorTexture(0, 0, 0, 1)
		r.icon = body:CreateTexture(nil, "ARTWORK", nil, 2)
		r.icon:SetSize(ICON, ICON)
		r.icon:SetPoint("CENTER", r.iconEdge, "CENTER", 0, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.title = API.Text(body, "body", "LEFT")
		r.title:SetPoint("BOTTOMLEFT", r.iconEdge, "RIGHT", GAP - 1, 1)
		r.sub = API.Text(body, "small", "LEFT")
		r.sub:SetPoint("TOPLEFT", r.iconEdge, "RIGHT", GAP - 1, -1)
		rows[i] = r
	end

	-- The secure part: hidden in every fight by its state driver; shown, placed and given its macros
	-- out of a fight only. One secure button per row, all made here (never in a fight); the first
	-- keeps the name the key binding clicks (Bindings.xml).
	holder = CreateFrame("Frame", "DaylightEssentialsBuffMannersHolder", UIParent, "SecureHandlerStateTemplate")
	holder:SetSize(W, H)
	RegisterStateDriver(holder, "visibility", "[combat] hide; show")
	for i = 1, MAX_ROWS do
		local b = CreateFrame("Button", "DaylightEssentialsBuffMannersButton" .. (i == 1 and "" or i), holder,
			"SecureActionButtonTemplate")
		b.row = i
		b:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * H)
		b:SetSize(W, H)
		-- Both: the template itself acts on the one the game's "cast on key down" choice says.
		b:RegisterForClicks("AnyUp", "AnyDown")
		b:SetAttribute("type1", "macro")
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
		b:Hide()
		b:HookScript("OnClick", function(self, which, down)
			local o = offers[self.row]
			if which == "RightButton" then
				if not down then Menu(self, o) end
				return
			end
			if o and o.guid and not o.blank then
				tried[o.guid] = GetTime()
				buffedBy[o.guid] = nil
			end
			LookSoon(0.4)
		end)
		b:SetScript("OnEnter", function(self)
			hovered[self.row] = true
			ns.Host.Tip(self, L["Buff Manners"], self.row == 1 and L["Click (or its key) to give the buff. Right-click: Not Now or Never Offer."]
				or L["Click to give the buff. Right-click: Not Now or Never Offer."], nil, "ANCHOR_TOP")
		end)
		b:SetScript("OnLeave", function(self)
			hovered[self.row] = nil
			GameTooltip:Hide()
			-- (The rows held for the pointer go back to their order.)
			LookSoon(0.3)
		end)
		buttons[i] = b
	end

	frame:SetPoint(unpack(DEFAULT))
	ns.me.RegisterMover(frame, KEY, L["Buff Prompt"], DEFAULT)
	-- Comes up with DaylightUI's fade-in on login and /reload (the inner box: the frame's own alpha is left alone).
	ns.FadeIn(KEY, function() return { body } end)
	ns.me.RegisterTestPart(KEY, L["Buff Prompt"])
	-- When the prompt is moved (a profile, the mover), the secure part follows it.
	hooksecurefunc(frame, "SetPoint", function() LookSoon() end)
	ns.me.RegisterCommand("manners", Command, L["manners never|allow|list Name, manners line Words: Buff Manners"])
	-- Its own command too, with no "/dui" in front (the /dui one stays for macros made before).
	_G.SLASH_GLOWEYMANNERS1 = "/manners"
	_G.SlashCmdList.GLOWEYMANNERS = function(msg) Command(msg or "") end

	frame:SetScript("OnEvent", OnEvent)
end

local function Listen(on)
	for _, e in ipairs(EVENTS) do
		if on then pcall(frame.RegisterEvent, frame, e) else pcall(frame.UnregisterEvent, frame, e) end
	end
	if class == "WARLOCK" then
		for _, e in ipairs(WARLOCK_EVENTS) do
			if on then pcall(frame.RegisterEvent, frame, e) else pcall(frame.UnregisterEvent, frame, e) end
		end
		moving = on and _G.IsPlayerMoving and _G.IsPlayerMoving() and true or false
	end
	if not on then
		wipe(plates)
		Forget()
	else
		-- Nameplates already up (a /reload, the part switched on).
		SeePlates()
		-- (Switched on in a fight: the buffs and nameplates wait for its end.)
		if InCombatLockdown() then QuietInCombat(true) end
	end
	-- (On: the next look decides whether anything waits. Off: nothing runs.)
	if not on then Rest() end
end

-- "Not Now" on a key too (Key Bindings, AddOns), so the offer can be turned down without a
-- right-click: a controller's button. The prompt sits on the screen like the rest of the HUD, so a
-- controller's cursor never goes to it (that would hold the D-pad and face buttons while it shows):
-- both answers are keys instead. Not a secure button: it only puts the offer off.
local notNowKey = CreateFrame("Button", "DaylightEssentialsBuffMannersNotNow", UIParent)
notNowKey:Hide()
notNowKey:SetScript("OnClick", function() NotNow(offers[1]) end)

-- The key bindings' words (Key Bindings, AddOns).
_G.BINDING_HEADER_DAYLIGHTESSENTIALS = "Glowey's Essentials"
_G["BINDING_NAME_CLICK DaylightEssentialsBuffMannersButton:LeftButton"] = L["Buff Manners: Give the Offered Buff"]
_G["BINDING_NAME_CLICK DaylightEssentialsBuffMannersNotNow:LeftButton"] = L["Buff Manners: Not Now"]

function P.Login()
	local _, token = UnitClass("player")
	class = token
	Build()
	Listen(G("enabled"))
	LookSoon(1)
end

function P.Setting()
	if not frame then return end
	Listen(G("enabled"))
	Forget()
	LookSoon()
end

function P.Style()
	-- The look changed: everything painted and skinned again.
	shownAs, sizedAs = nil, nil
	if frame and offers[1] then LookSoon() end
end

function P.Preview()
	if frame then LookSoon() end
end
