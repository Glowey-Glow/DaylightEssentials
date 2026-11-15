-- Cursor Cooldowns: your taunt's and your dispels' cooldowns as small icons beside the mouse
-- pointer while they're cooling down, each with the game's own sweep and countdown, so you know
-- when the next one is up without looking away from the fight. An icon goes as its cooldown ends.
-- The global cooldown alone (the second after any spell) never shows one.
--
-- Which spells: those you know of a taunt (Taunt, Mocking Blow, Challenging Shout, Growl,
-- Challenging Roar) and of a dispel (Dispel Magic, Cure and Abolish Disease, Cleanse, Purify,
-- Remove Curse, Remove Lesser Curse, Cure and Abolish Poison, Purge). Each is followed once,
-- whatever rank you know. A dispel with no cooldown of its own only ever has the global one, so
-- it shows nothing.
--
-- Ready at the cursor: up to six abilities you pick (per class: all your characters of that class
-- share the picks) show their icons in a line by the pointer while each is ready to cast: off its
-- cooldown (the global cooldown doesn't count) and usable now (enough mana, rage or energy, and an
-- ability like Overpower or Execute only while the game allows it). A usability the game keeps
-- secret in a fight counts as usable. The line sits on the side of the pointer you choose and
-- runs away from it: to the left for the three left-hand spots, to the right for the right-hand
-- ones, centered above or below for Top and Bottom. Kept by spell id and followed by its name in
-- the game's language, so a new rank still counts and a change of language keeps the picks.
--
-- The cooldown is read the way the game allows in a fight: a time it keeps secret goes to the
-- cooldown sweep untouched (the game draws it), and the global cooldown is told apart by the
-- game's own flag for it.
-- What it costs: a look at a handful of spells when the game says cooldowns changed; while an icon
-- shows, the icons follow the pointer each frame (one position read).

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "cursorCooldowns"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["Cursor Cooldowns"] })

P.defaults = {
	enabled = true,
	taunts = true,
	dispels = true,
	onlyCombat = false,
	size = 26,
	distance = 22,
	ready = true,
	readyOnlyCombat = true,
	readyAnchor = "TOP",
	readySize = 24,
}

-- ---------------------------------------------------------------------------------------------
-- Ready at the cursor: the picks (DaylightEssentialsDB.ready[CLASS][slot] = spell id; a name
-- before 1.2.0)
-- ---------------------------------------------------------------------------------------------

local READY_SLOTS = 6
local NONE = "none"
local RefreshReady   -- below

local function PlayerClass()
	local _, token = UnitClass("player")
	return token or "UNKNOWN"
end

local function Picks()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if type(db.ready) ~= "table" then db.ready = {} end
	local class = PlayerClass()
	if type(db.ready[class]) ~= "table" then db.ready[class] = {} end
	return db.ready[class]
end

-- The abilities you know (your spellbook, not passives), by name: name -> the highest spell id.
local known, knownDirty = {}, true
local function Known()
	if not knownDirty then return known end
	knownDirty = false
	wipe(known)
	local book = C_SpellBook
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
	if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo) then
		return known
	end
	local okN, lines = pcall(book.GetNumSpellBookSkillLines)
	for i = 1, (okN and type(lines) == "number") and lines or 0 do
		local okL, line = pcall(book.GetSpellBookSkillLineInfo, i)
		if okL and type(line) == "table" and not line.shouldHide then
			local first = (line.itemIndexOffset or 0) + 1
			for slot = first, first + (line.numSpellBookItems or 0) - 1 do
				local okI, info = pcall(book.GetSpellBookItemInfo, slot, bank)
				if okI and type(info) == "table" and info.itemType == spellType and not info.isPassive
					and type(info.name) == "string" and info.name ~= "" and type(info.spellID) == "number" then
					local have = known[info.name]
					if not have or info.spellID > have then known[info.name] = info.spellID end
				end
			end
		end
	end
	return known
end

-- A long name made to fit the option box (the list itself shows names in full): every word but
-- the last cut to its first letter: "Blessing of Sanctuary" -> "B. o. Sanctuary". Letters are
-- counted and cut whole (a letter in another language takes two to four bytes).
local function Short(name)
	if type(name) ~= "string" or ns.CharCount(name) <= 16 then return name end
	local words = {}
	for w in string.gmatch(name, "%S+") do words[#words + 1] = w end
	if #words < 2 then return name end
	for i = 1, #words - 1 do words[i] = ns.FirstChar(words[i]) .. "." end
	return table.concat(words, " ")
end

local function SpellNameOf(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, id)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
end

-- A slot's pick by name, in the game's language (nil for none). A pick kept by name (before 1.2.0)
-- becomes the id of the rank you know once its name is found in your spellbook.
local function PickName(picks, slot)
	local v = picks[slot]
	if type(v) == "number" then return SpellNameOf(v) end
	if type(v) == "string" then
		local id = Known()[v]
		if id then picks[slot] = id end
		return v
	end
end

local function ReadyOff(get) return get(KEY .. ".enabled") == false or get(KEY .. ".ready") == false end

local function SlotRow(i)
	return { type = "dropdown", label = L["Ability %d"]:format(i),
		desc = i == 1 and L["Shows by the pointer while it's ready to cast. Lists the abilities you know; your picks are kept for each class."] or nil,
		default = function() return NONE end,
		get = function()
			return PickName(Picks(), i) or NONE
		end,
		set = function(v)
			local picks = Picks()
			if v == NONE or type(v) ~= "string" then
				picks[i] = nil
			elseif v ~= PickName(picks, i) then
				picks[i] = Known()[v] or v
			end
			if RefreshReady then RefreshReady(true) end
			return true
		end,
		shownAs = function(v) return v == NONE and L["None"] or Short(v) end,
		choices = function()
			local values, keys = { [NONE] = L["None"] }, {}
			for name in pairs(Known()) do values[name] = name end
			-- A pick this character doesn't know (yet) stays listed.
			local cur = PickName(Picks(), i)
			if cur then values[cur] = cur end
			for k in pairs(values) do if k ~= NONE then keys[#keys + 1] = k end end
			table.sort(keys)
			table.insert(keys, 1, NONE)
			return values, keys
		end,
		disabled = ReadyOff }
end

P.page = { id = KEY, label = L["Cursor Cooldowns"],
	desc = L["Your cooldowns, and abilities ready to cast, beside the mouse pointer."],
	groups = {
		{ label = L["Cursor Cooldowns"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "toggle", key = KEY .. ".taunts", label = L["Taunts"],
			  desc = L["Taunt, Mocking Blow, Challenging Shout, Growl, Challenging Roar."] },
			{ type = "toggle", key = KEY .. ".dispels", label = L["Dispels"],
			  desc = L["Dispel Magic, Cure and Abolish Disease, Cleanse, Purify, Remove Curse, Remove Lesser Curse, Cure and Abolish Poison, Purge. One with no cooldown of its own never shows."] },
			{ type = "toggle", key = KEY .. ".onlyCombat", label = L["Only in Combat"] },
		} },
		{ label = L["Look"], items = {
			{ type = "slider", key = KEY .. ".size", label = L["Icon size"], min = 18, max = 44, step = 1, unit = "px" },
			{ type = "slider", key = KEY .. ".distance", label = L["Distance from the pointer"], min = 8, max = 60, step = 1, unit = "px" },
		} },
		{ label = L["Ready at the cursor"],
		  desc = L["Abilities you pick show by the pointer while they're ready to cast: off cooldown and usable now (enough power, or an ability like Execute while it's allowed)."],
		  items = {
			{ type = "toggle", key = KEY .. ".ready", label = L["On"] },
			{ type = "toggle", key = KEY .. ".readyOnlyCombat", label = L["Only in Combat"], disabled = ReadyOff },
			{ type = "dropdown", key = KEY .. ".readyAnchor", label = L["Cursor Anchor Point"], disabled = ReadyOff,
			  values = { TOPLEFT = L["Top left"], TOP = L["Top"], TOPRIGHT = L["Top right"], RIGHT = L["Right"],
				BOTTOMRIGHT = L["Bottom right"], BOTTOM = L["Bottom"], BOTTOMLEFT = L["Bottom left"], LEFT = L["Left"] },
			  order = { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT" },
			  desc = L["The line runs away from the pointer: leftward on the left side, rightward on the right, centered for Top and Bottom. Bottom right sits under the cooldown icons."] },
			{ type = "slider", key = KEY .. ".readySize", label = L["Icon size"], min = 16, max = 48, step = 1, unit = "px", disabled = ReadyOff },
		  } },
	} }

do
	local items = P.page.groups[#P.page.groups].items
	for i = 1, READY_SLOTS do items[#items + 1] = SlotRow(i) end
end

-- Each family: its ranks' spell ids (any one known puts the family in).
local TAUNTS = {
	{ 355 },                                     -- Taunt
	{ 694, 7400, 7402, 20559, 20560 },           -- Mocking Blow
	{ 1161 },                                    -- Challenging Shout
	{ 6795 },                                    -- Growl
	{ 5209 },                                    -- Challenging Roar
}
local DISPELS = {
	{ 527, 988 },                                -- Dispel Magic
	{ 528 },                                     -- Cure Disease (priest)
	{ 552 },                                     -- Abolish Disease
	{ 4987 },                                    -- Cleanse
	{ 1152 },                                    -- Purify
	{ 2782 },                                    -- Remove Curse (druid)
	{ 475 },                                     -- Remove Lesser Curse (mage)
	{ 8946 },                                    -- Cure Poison (druid)
	{ 2893 },                                    -- Abolish Poison
	{ 526 },                                     -- Cure Poison (shaman)
	{ 2870 },                                    -- Cure Disease (shaman)
	{ 370, 8012 },                               -- Purge
}

local GCD = 1.6          -- a cooldown this short or shorter is only the global one

local holder
local tracked = {}       -- the spell ids followed (one per family known)
local icons = {}         -- spell id -> its icon
local shownList = {}     -- the icons showing, in order (reused)
local inFight = false

local function KnownOf(family)
	for i = #family, 1, -1 do
		local id = family[i]
		if (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) then return id end
	end
	return nil
end

local function Texture(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	if GetSpellTexture then return GetSpellTexture(id) end
	return nil
end

local Layout   -- below

local function Icon(id)
	local icon = icons[id]
	if icon then return icon end
	icon = CreateFrame("Frame", nil, holder)
	icon.art = icon:CreateTexture(nil, "ARTWORK")
	icon.art:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
	icon.art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
	icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.art:SetTexture(Texture(id))
	API.Skin(icon, { noBevel = true, borderPx = 2, bgAlpha = 0.85 })
	icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cd:SetAllPoints(icon.art)
	icon.cd:SetDrawEdge(false)
	if icon.cd.SetHideCountdownNumbers then icon.cd:SetHideCountdownNumbers(false) end
	icon.cd:SetScript("OnCooldownDone", function()
		icon:Hide()
		Layout()
	end)
	icon:Hide()
	icons[id] = icon
	return icon
end

-- The follow: the holder sits just below-right of the pointer (moved only when the pointer has).
local lastX, lastY
local function Follow()
	local x, y = GetCursorPosition()
	if x == lastX and y == lastY then return end
	lastX, lastY = x, y
	local scale = UIParent:GetEffectiveScale()
	local d = G("distance") or 22
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + d, y / scale - d)
end

Layout = function()
	wipe(shownList)
	local size = G("size") or 26
	for _, id in ipairs(tracked) do
		local icon = icons[id]
		if icon and icon:IsShown() then shownList[#shownList + 1] = icon end
	end
	for i, icon in ipairs(shownList) do
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (size + 3), 0)
	end
	if #shownList > 0 then
		holder:SetSize(#shownList * (size + 3), size)
		lastX = nil
		Follow()
		holder:SetScript("OnUpdate", Follow)
		holder:Show()
	else
		holder:SetScript("OnUpdate", nil)
		holder:Hide()
	end
end

-- Whether a cooldown is a real one (not the global cooldown), from what the game gives. Its
-- isActive and isOnGCD flags are never secret (isOnGCD is true on the global cooldown alone, and
-- not there on a real one); the times can be, so they're only read when the flags aren't given.
local function Cooling(start, duration, info)
	if info and type(info.isActive) == "boolean" then
		return info.isActive and info.isOnGCD ~= true
	end
	if Safe(start) and Safe(duration) then
		return type(start) == "number" and type(duration) == "number" and start > 0 and duration > GCD
	end
	return false
end

-- The sweep and countdown, drawn by the game from the cooldown as it is (secret or not).
local function Sweep(cd, id, start, duration)
	if C_Spell and C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
		local ok, d = pcall(C_Spell.GetSpellCooldownDuration, id)
		if ok and type(d) ~= "nil" and pcall(cd.SetCooldownFromDurationObject, cd, d, true) then return end
	end
	pcall(cd.SetCooldown, cd, start, duration)
end

local function ReadCooldown(id)
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(id)
		if type(info) ~= "table" then return nil end
		return info.startTime, info.duration, info
	end
	if GetSpellCooldown then
		local start, duration = GetSpellCooldown(id)
		return start, duration, nil
	end
	return nil
end

local function Refresh()
	if not holder then return end
	local allowed = G("enabled") and (not G("onlyCombat") or inFight)
	local changed = false
	for _, id in ipairs(tracked) do
		local icon = Icon(id)
		local start, duration, info = ReadCooldown(id)
		local on = allowed and (info ~= nil or type(start) ~= "nil") and Cooling(start, duration, info)
		if on then
			-- Which cooldown this is: its start and length when readable, else the game's flags
			-- (never secret). Drawn again only when that changes or the icon comes up.
			local key
			if Safe(start) and Safe(duration) then
				key = tostring(start) .. ":" .. tostring(duration)
			elseif info and Safe(info.isActive) and Safe(info.isOnGCD) then
				key = tostring(info.isActive) .. ":" .. tostring(info.isOnGCD)
			end
			if not icon:IsShown() or key == nil or key ~= icon.swept then
				icon.swept = key
				Sweep(icon.cd, id, start, duration)
			end
			if not icon:IsShown() then
				icon:Show()
				changed = true
			end
		elseif icon:IsShown() then
			icon.swept = nil
			icon.cd:Clear()
			icon:Hide()
			changed = true
		end
	end
	if changed then Layout() end
end

-- The spells to follow, from what you know now.
local function Track()
	wipe(tracked)
	if G("taunts") then
		for _, family in ipairs(TAUNTS) do
			local id = KnownOf(family)
			if id then tracked[#tracked + 1] = id end
		end
	end
	if G("dispels") then
		for _, family in ipairs(DISPELS) do
			local id = KnownOf(family)
			if id then tracked[#tracked + 1] = id end
		end
	end
	for id, icon in pairs(icons) do
		local kept = false
		for _, t in ipairs(tracked) do if t == id then kept = true break end end
		if not kept and icon:IsShown() then
			icon.cd:Clear()
			icon:Hide()
		end
	end
	Layout()
	Refresh()
end

-- ---------------------------------------------------------------------------------------------
-- Ready at the cursor: the line
-- ---------------------------------------------------------------------------------------------

local readyHolder
local readyIcons = {}    -- slot -> its icon
local readyIds = {}      -- slot -> the spell id followed (nil: empty or not known)
local readyShown = {}    -- the icons showing, in slot order (reused)

-- Where the line sits: the holder's point put on the pointer, the x and y signs of the distance,
-- and which way the icons run (-1 leftward, 1 rightward, 0 centered).
local SIDES = {
	TOPLEFT     = { "BOTTOMRIGHT", -1,  1, -1 },
	TOP         = { "BOTTOM",       0,  1,  0 },
	TOPRIGHT    = { "BOTTOMLEFT",   1,  1,  1 },
	RIGHT       = { "LEFT",         1,  0,  1 },
	BOTTOMRIGHT = { "TOPLEFT",      1, -1,  1 },
	BOTTOM      = { "TOP",          0, -1,  0 },
	BOTTOMLEFT  = { "TOPRIGHT",    -1, -1, -1 },
	LEFT        = { "RIGHT",       -1,  0, -1 },
}

local function Side()
	return SIDES[G("readyAnchor") or "TOP"] or SIDES.TOP
end

local rLastX, rLastY
local function ReadyFollow()
	local x, y = GetCursorPosition()
	if x == rLastX and y == rLastY then return end
	rLastX, rLastY = x, y
	local scale = UIParent:GetEffectiveScale()
	local d = G("distance") or 22
	local side = Side()
	local dy = side[3] * d
	-- Bottom right is where the cooldown icons are: the line goes under them.
	if G("readyAnchor") == "BOTTOMRIGHT" then dy = dy - ((G("size") or 26) + 4) end
	readyHolder:ClearAllPoints()
	readyHolder:SetPoint(side[1], UIParent, "BOTTOMLEFT", x / scale + side[2] * d, y / scale + dy)
end

local function ReadyIcon(slot)
	local icon = readyIcons[slot]
	if icon then return icon end
	icon = CreateFrame("Frame", nil, readyHolder)
	icon.art = icon:CreateTexture(nil, "ARTWORK")
	icon.art:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
	icon.art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
	icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	API.Skin(icon, { noBevel = true, borderPx = 2, bgAlpha = 0.85 })
	icon:Hide()
	readyIcons[slot] = icon
	return icon
end

local function ReadyLayout()
	wipe(readyShown)
	for slot = 1, READY_SLOTS do
		local icon = readyIcons[slot]
		if icon and icon:IsShown() then readyShown[#readyShown + 1] = icon end
	end
	local n = #readyShown
	if n == 0 then
		readyHolder:SetScript("OnUpdate", nil)
		readyHolder:Hide()
		return
	end
	local size, gap = G("readySize") or 24, 3
	local run = Side()[4]
	readyHolder:SetSize(n * size + (n - 1) * gap, size)
	for i, icon in ipairs(readyShown) do
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		local step = (i - 1) * (size + gap)
		if run < 0 then
			-- The first pick nearest the pointer, the rest running left.
			icon:SetPoint("TOPRIGHT", readyHolder, "TOPRIGHT", -step, 0)
		else
			icon:SetPoint("TOPLEFT", readyHolder, "TOPLEFT", step, 0)
		end
	end
	rLastX = nil
	ReadyFollow()
	readyHolder:SetScript("OnUpdate", ReadyFollow)
	readyHolder:Show()
end

-- Usable now (enough power, a reactive ability allowed). A secret or unknown answer counts as yes.
local function Usable(id)
	if not (C_Spell and C_Spell.IsSpellUsable) then return true end
	local ok, can = pcall(C_Spell.IsSpellUsable, id)
	if not ok or not Safe(can) or type(can) ~= "boolean" then return true end
	return can
end

local function Ready(id)
	local start, duration, info = ReadCooldown(id)
	if (info ~= nil or type(start) ~= "nil") and Cooling(start, duration, info) then return false end
	return Usable(id)
end

-- Which spell each slot follows, from the picks and what you know now.
local readyListening = false
local function ReadyEvents(on)
	if on == readyListening or not holder then return end
	readyListening = on
	if on then
		pcall(holder.RegisterEvent, holder, "PLAYER_TARGET_CHANGED")
		pcall(holder.RegisterUnitEvent, holder, "UNIT_POWER_FREQUENT", "player")
	else
		pcall(holder.UnregisterEvent, holder, "PLAYER_TARGET_CHANGED")
		pcall(holder.UnregisterEvent, holder, "UNIT_POWER_FREQUENT")
	end
end

local function ReadyTrack()
	local picks = Picks()
	if not (G("enabled") and G("ready")) or next(picks) == nil then
		wipe(readyIds)
		ReadyEvents(false)
		return
	end
	local book = Known()
	for slot = 1, READY_SLOTS do
		local name = PickName(picks, slot)
		local id = name and book[name] or nil
		readyIds[slot] = id   -- (nil entries leave the table empty when nothing is picked)
		if id then ReadyIcon(slot).art:SetTexture(Texture(id)) end
	end
	ReadyEvents(next(readyIds) ~= nil)
end

function RefreshReady(retrack)
	if not readyHolder then return end
	if retrack then ReadyTrack() end
	local allowed = G("enabled") and G("ready") and (not G("readyOnlyCombat") or inFight)
		and not UnitIsDeadOrGhost("player")
	local changed = false
	for slot = 1, READY_SLOTS do
		local id = readyIds[slot]
		local on = allowed and id ~= nil and Ready(id)
		local icon = readyIcons[slot]
		if on and not icon:IsShown() then
			icon:Show()
			changed = true
		elseif not on and icon and icon:IsShown() then
			icon:Hide()
			changed = true
		end
	end
	if changed or retrack then ReadyLayout() end
end

-- Power changes come many times a second: the ready line is looked at once per 0.1 s at most.
local powerQueued = false
local function PowerLook()
	powerQueued = false
	if next(readyIds) ~= nil then RefreshReady() end
end

-- Spells learned or changed (forms and stances too): looked at once, a moment after the last.
local trackQueued = false
local function Retrack()
	trackQueued = false
	knownDirty = true
	Track()
	RefreshReady(true)
end

local function OnEvent(_, event)
	if event == "SPELL_UPDATE_COOLDOWN" then
		Refresh()
		RefreshReady()
	elseif event == "UNIT_POWER_FREQUENT" then
		if not powerQueued then
			powerQueued = true
			C_Timer.After(0.1, PowerLook)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		if next(readyIds) ~= nil then RefreshReady() end
	elseif event == "SPELL_UPDATE_USABLE" or event == "PLAYER_DEAD" or event == "PLAYER_ALIVE"
		or event == "PLAYER_UNGHOST" then
		RefreshReady()
	elseif event == "PLAYER_REGEN_DISABLED" then
		inFight = true
		Refresh()
		RefreshReady()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inFight = false
		Refresh()
		RefreshReady()
	else
		if not trackQueued then
			trackQueued = true
			C_Timer.After(0.3, Retrack)
		end
	end
end

function P.Login()
	holder = CreateFrame("Frame", "DaylightEssentialsCursorCooldowns", UIParent)
	holder:SetFrameStrata("TOOLTIP")
	holder:EnableMouse(false)
	holder:Hide()
	inFight = InCombatLockdown()
	holder:SetScript("OnEvent", OnEvent)
	readyHolder = CreateFrame("Frame", "DaylightEssentialsCursorReady", UIParent)
	readyHolder:SetFrameStrata("TOOLTIP")
	readyHolder:EnableMouse(false)
	readyHolder:Hide()
	for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_USABLE", "PLAYER_DEAD",
		"PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
		pcall(holder.RegisterEvent, holder, e)
	end
	-- (Target and power changes: registered by ReadyTrack while an ability is picked.)
	Track()
	RefreshReady(true)
end

function P.Setting()
	if holder then
		Track()
		RefreshReady(true)
	end
end
