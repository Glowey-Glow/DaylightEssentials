-- Buff Manners: one small prompt in the DaylightUI look offering the buff you can give to the
-- player who needs it most right now: someone who just buffed you, then your target, then your
-- group, then players right beside you. Click it, or press its key (Key Bindings, AddOns, Daylight
-- Essentials), and the buff goes out; your own target comes back to you. Right-click it for "Not
-- now" and "Never offer". Optionally a /thank or a short line for players who buffed you, which
-- is also offered on its own when you have nothing they're missing. Move it with /dui unlock.
-- (The idea is from Manners by fpsacha, MIT licensed; this is written from scratch.)
--
-- Nothing is ever cast by itself: the game only lets an addon cast from a click or a key press, so
-- the prompt is a secure button (SecureActionButtonTemplate) whose macro is set out of a fight
-- only. In a fight the prompt is hidden (a state driver hides its secure part), and comes back
-- after it. Your own missing buffs are left to DaylightUI's buff reminder.
--
-- Who buffed you: the game names the caster of each new buff on you (its sourceUnit) when that
-- player is one of your units (group, target, mouseover, a nameplate). Friendly nameplates help it
-- see more players. In a fight, or under the game's restrictions, these reads can be secret: then
-- nothing is read (every read is wrapped in pcall and checked with ns.Safe).
--
-- What it costs: nothing while it's off. On, out of a fight, one look every 1.5 seconds; the buffs
-- of each player are read once and kept until that player's buffs change (UNIT_AURA). No timers in
-- a fight.

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
}

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
		  desc = L["Click the prompt, or press its key (Key Bindings, AddOns, Glowey's Essentials). Right-click it for Not Now and Never Offer. Hidden in a fight. Your own missing buffs are left to Daylight UI's buff reminder."],
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
			{ type = "toggle", key = KEY .. ".skipFlagged", label = L["Skip Flagged Players"],
			  desc = L["While you aren't flagged yourself: buffing them would flag you."] },
			{ type = "toggle", key = KEY .. ".quietResting", label = L["Mute in Towns and Inns"] },
			{ type = "toggle", key = KEY .. ".quietInstances", label = L["Mute in Dungeons and Raids"] },
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
		{ label = L["My Buffs"],
		  desc = L["Mages give Arcane Intellect, Priests Fortitude, Druids Mark of the Wild, Paladins a blessing, Warlocks Unending Breath (only while you're swimming). Intellect, Wisdom and Divine Spirit only go to players who use mana."],
		  items = {
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
		local on = true
		if b.setting == "thorns" then on = G("thorns") == "tanks"
		elseif b.setting then on = G(b.setting) == true end
		if b.swim and not (IsSwimming and IsSwimming()) then on = false end
		if on and Known(b.id) and Prepare(b) and Wants(b, unit) and not Has(buffs, b) and Usable(b.name) then
			return b
		end
	end
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
	if tried[guid] and now - tried[guid] < TRIED then return nil end
	if snoozed[guid] and now - snoozed[guid] < SNOOZE then return nil end
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

local frame, body, icon, iconEdge, title, sub   -- frame: what /dui unlock moves; body: the look
local holder, button                            -- the secure part, laid over the body out of a fight
local W, H, ICON, PAD, GAP = 200, 40, 28, 6, 8
local DEFAULT = { "CENTER", UIParent, "CENTER", 0, -170 }
local offer          -- what the prompt offers now: { guid, unit, name, short, class, spell, reason, thanks }
local previewing = false

-- (Whole lines: "%s" is the player's name, in their class color.)
local REASON = { buffed = L["%s  buffed you"], target = L["%s  your target"], group = L["%s  your group"], nearby = L["%s  nearby"] }

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

local sizedAs   -- the box's last size and scale (skinned again only when they change)
local function Paint(o)
	local spell = o.spell
	icon:SetTexture(spell and spell.icon or o.icon or 136243)
	title:SetText(spell and spell.name or L["Thank %s"]:format(o.short))
	local r, g, b = 1, 1, 1
	if o.class then r, g, b = API.ClassColor(o.class) end
	sub:SetText((REASON[o.reason] or "%s  "):format(("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255),
		math.floor(g * 255), math.floor(b * 255), o.short or o.name)))
	ns.Ink(title, "TITLE")
	ns.Ink(sub, "LABEL")
	-- The box fits its words: nothing is cut short.
	local tw = math.max(ns.TextWidth(title) or 0, ns.TextWidth(sub) or 0)
	local w = math.max(W, math.ceil(PAD * 2 + ICON + GAP + tw + 2))
	local scale = G("scale") or 1
	local sig = w .. ":" .. scale
	if sig == sizedAs then return end
	sizedAs = sig
	body:SetSize(w, H)
	body:SetScale(scale)
	frame:SetSize(w * scale, H * scale)
	ns.SkinWindow(body, nil, KEY)
end

-- The secure part over the body (out of a fight only).
local placedAs, macroText   -- the secure part's last spot and macro (set again only when changed)
local function PlaceButton()
	if InCombatLockdown() or not holder then return end
	local l, t = body:GetLeft(), body:GetTop()
	if not l or not t or not body:IsVisible() or previewing or not offer then
		if button:IsShown() then button:Hide() end
		placedAs = nil
		return
	end
	local s = body:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local w, h = body:GetWidth() * s, body:GetHeight() * s
	local spot = l * s .. ":" .. t * s .. ":" .. w .. ":" .. h
	if spot ~= placedAs then
		placedAs = spot
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
		holder:SetSize(w, h)
		holder:SetFrameStrata(frame:GetFrameStrata())
		holder:SetFrameLevel(frame:GetFrameLevel() + 20)
	end
	local m = Macro(offer)
	if m ~= macroText then
		macroText = m
		button:SetAttribute("macrotext1", m)
	end
	if not button:IsShown() then button:Show() end
end

local shownAs   -- the offer on show (who, which buff, why): painted again only when it changes
local function ShowOffer(o)
	offer = o
	if o then
		local key = (o.guid or o.name) .. ":" .. (o.spell and o.spell.name or "") .. ":" .. o.reason
			.. (o.thanks and ":t" or "") .. (previewing and ":p" or "") .. ":" .. (G("scale") or 1)
		if key ~= shownAs or not body:IsShown() then
			shownAs = key
			Paint(o)
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

local function GroupUnits()
	local units = {}
	if IsInRaid() then
		for i = 1, 40 do units[#units + 1] = "raid" .. i end
	elseif IsInGroup() then
		for i = 1, 4 do units[#units + 1] = "party" .. i end
	end
	return units
end

local plates = {}   -- nameplate unit tokens on screen now

local function Try(unit, reason, seen, thanksFor)
	local guid, name = Candidate(unit)
	if not guid or seen[guid] then return nil end
	seen[guid] = true
	-- (A passer-by too far away: no need to read their buffs.)
	if reason == "nearby" and G("nearby") == "beside" and not Beside(unit) then return nil end
	local buffs = Buffs(unit)
	if not buffs then return nil end
	local spell = Pick(unit, buffs)
	local thanks = thanksFor and thanksFor[guid] or nil
	if spell then
		if not InRange(spell.name, unit) then return nil end
	elseif thanks then
		local inInstance = IsInInstance and IsInInstance() or false
		local emote, say = ThanksWanted(inInstance, true)
		if not (emote or say) then return nil end
		-- (An emote or a line in say: only to someone close enough to see it, about 28 yards.)
		if say ~= "whisper" and CheckInteractDistance and Read(CheckInteractDistance, unit, 4) ~= true then return nil end
	else
		return nil
	end
	return { guid = guid, unit = unit, name = name, short = Read(UnitName, unit) or name, class = UnitClassOf(unit),
		spell = spell, reason = thanks and "buffed" or reason, thanks = thanks and true or nil,
		icon = thanks and thanks.icon or nil }
end

-- The units that could be someone who buffed you: group, target, focus, mouseover, nameplates.
local function KnownUnits()
	local units = { "target", "focus", "mouseover" }
	for _, u in ipairs(GroupUnits()) do units[#units + 1] = u end
	for u in pairs(plates) do units[#units + 1] = u end
	return units
end

-- Whether your class has a buff to give right now (a warlock's breath only while swimming).
local function CanGive()
	if class == "PALADIN" then return true end
	local list = BUFFS[class]
	if not list then return false end
	if class == "WARLOCK" then return (IsSwimming and IsSwimming()) and true or false end
	return true
end

local function Find()
	local seen = {}
	local now = GetTime()
	for guid, e in pairs(buffedBy) do
		if now - e.at > BUFFED_FOR then buffedBy[guid] = nil end
	end
	-- 1. Someone who buffed you.
	if G("buffedYou") and next(buffedBy) then
		for _, u in ipairs(KnownUnits()) do
			local guid = Read(UnitGUID, u)
			if type(guid) == "string" and buffedBy[guid] and not seen[guid] then
				local o = Try(u, "buffed", seen, buffedBy)
				if o then return o end
			end
		end
	end
	-- Nothing of yours to give: only the thank-yous above.
	if not CanGive() then return nil end
	-- 2. Your target.
	if G("target") then
		local o = Try("target", "target", seen)
		if o then return o end
	end
	-- 3. Your group.
	if G("group") then
		for _, u in ipairs(GroupUnits()) do
			local o = Try(u, "group", seen)
			if o then return o end
		end
	end
	-- 4. Players nearby: friends and guildmates first.
	if G("nearby") ~= "off" then
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
				local o = Try(u, "nearby", seen)
				if o then return o end
			end
		end
	end
	return nil
end

local looking = false
local function Look()
	looking = false
	if not frame or InCombatLockdown() then return end
	previewing = G("enabled") and ns.Previewing(KEY) or false
	if previewing then
		-- A buff of yours to give, or for a class with none, the thank-you on its own.
		local sample = (BUFFS[class] and BUFFS[class][1]) or (class == "PALADIN" and KINGS) or nil
		if sample and not Prepare(sample) then sample = nil end
		ShowOffer({ unit = "player", name = "Glowey", short = "Glowey", class = "PRIEST", reason = "buffed",
			spell = sample, icon = 135987, thanks = true })
		return
	end
	if Quiet() or not class then
		ShowOffer(nil)
		return
	end
	ShowOffer(Find())
end

local function LookSoon(delay)
	if looking then return end
	looking = true
	C_Timer.After(delay or 0.1, Look)
end

-- One look every 1.5 seconds while on and out of a fight.
local ticker
local function Tick(on)
	if on and not ticker then
		ticker = C_Timer.NewTicker(1.5, function()
			if not looking then Look() end
			-- Nothing to give and nobody to thank: rests until someone buffs you (NoteBuffs wakes
			-- it). A warlock keeps looking: swimming has no event of its own.
			if not previewing and class ~= "WARLOCK" and not CanGive() and not next(buffedBy) and ticker then
				ticker:Cancel()
				ticker = nil
			end
		end)
	elseif not on and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

function P.Wake()
	if frame and G("enabled") and not InCombatLockdown() then
		Tick(true)
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
	if not o then return end
	if o.guid then snoozed[o.guid] = GetTime() end
	buffedBy[o.guid or ""] = nil
	LookSoon()
end

local function Menu(owner)
	local o = offer
	if not o or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(o.name)
		root:CreateButton(L["Not Now"], function() NotNow(o) end)
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

local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
	"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_AURA", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
	"READY_CHECK", "SPELLS_CHANGED", "PLAYER_UPDATE_RESTING", "PLAYER_MOUNT_DISPLAY_CHANGED", "ZONE_CHANGED_NEW_AREA",
	"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }

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
		Tick(false)
		offer = nil
		body:Hide()   -- (the secure part is hidden by its state driver)
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		Forget()
		Tick(G("enabled"))
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
	end
	LookSoon()
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
	iconEdge = body:CreateTexture(nil, "ARTWORK", nil, 1)
	iconEdge:SetSize(ICON + 2, ICON + 2)
	iconEdge:SetPoint("LEFT", body, "LEFT", PAD - 1, 0)
	iconEdge:SetColorTexture(0, 0, 0, 1)
	icon = body:CreateTexture(nil, "ARTWORK", nil, 2)
	icon:SetSize(ICON, ICON)
	icon:SetPoint("CENTER", iconEdge, "CENTER", 0, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	title = API.Text(body, "body", "LEFT")
	title:SetPoint("BOTTOMLEFT", iconEdge, "RIGHT", GAP - 1, 1)
	sub = API.Text(body, "small", "LEFT")
	sub:SetPoint("TOPLEFT", iconEdge, "RIGHT", GAP - 1, -1)

	-- The secure part: hidden in every fight by its state driver; shown, placed and given its macro
	-- out of a fight only.
	holder = CreateFrame("Frame", "DaylightEssentialsBuffMannersHolder", UIParent, "SecureHandlerStateTemplate")
	holder:SetSize(W, H)
	RegisterStateDriver(holder, "visibility", "[combat] hide; show")
	button = CreateFrame("Button", "DaylightEssentialsBuffMannersButton", holder, "SecureActionButtonTemplate")
	button:SetAllPoints(holder)
	-- Both: the template itself acts on the one the game's "cast on key down" choice says.
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("type1", "macro")
	local hl = button:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.08)
	button:Hide()
	button:HookScript("OnClick", function(self, which, down)
		if which == "RightButton" then
			if not down then Menu(self) end
			return
		end
		local o = offer
		if o and o.guid then
			tried[o.guid] = GetTime()
			buffedBy[o.guid] = nil
		end
		LookSoon(0.4)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L["Buff Manners"])
		GameTooltip:AddLine(L["Click (or its key) to give the buff. Right-click: Not Now or Never Offer."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
	if not on then
		wipe(plates)
		Forget()
	else
		-- Nameplates already up (a /reload, the part switched on).
		if C_NamePlate and C_NamePlate.GetNamePlates then
			for _, p in ipairs(C_NamePlate.GetNamePlates() or {}) do
				if p.namePlateUnitToken then plates[p.namePlateUnitToken] = true end
			end
		end
	end
	Tick(on and not InCombatLockdown())
end

-- "Not Now" on a key too (Key Bindings, AddOns), so the offer can be turned down without a
-- right-click: a controller's button. The prompt sits on the screen like the rest of the HUD, so a
-- controller's cursor never goes to it (that would hold the D-pad and face buttons while it shows):
-- both answers are keys instead. Not a secure button: it only puts the offer off.
local notNowKey = CreateFrame("Button", "DaylightEssentialsBuffMannersNotNow", UIParent)
notNowKey:Hide()
notNowKey:SetScript("OnClick", function() NotNow(offer) end)

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
	if frame and offer then LookSoon() end
end

function P.Preview()
	if frame then LookSoon() end
end
