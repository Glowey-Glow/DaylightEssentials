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
-- The cooldown is read the way the game allows in a fight: a time it keeps secret goes to the
-- cooldown sweep untouched (the game draws it), and the global cooldown is told apart by the
-- game's own flag for it.
-- What it costs: a look at a handful of spells when the game says cooldowns changed; while an icon
-- shows, the icons follow the pointer each frame (one position read).

local _, ns = ...
if ns.off then return end

local API = ns.API
local KEY = "cursorCooldowns"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = "Cursor Cooldowns" })

P.defaults = {
	enabled = true,
	taunts = true,
	dispels = true,
	onlyCombat = false,
	size = 26,
	distance = 22,
}

P.page = { id = KEY, label = "Cursor Cooldowns",
	desc = "Your taunt's and dispels' cooldowns beside the mouse pointer while they cool down.",
	groups = {
		{ label = "Cursor Cooldowns", items = {
			{ type = "toggle", key = KEY .. ".enabled", label = "On" },
			{ type = "toggle", key = KEY .. ".taunts", label = "Taunts",
			  desc = "Taunt, Mocking Blow, Challenging Shout, Growl, Challenging Roar." },
			{ type = "toggle", key = KEY .. ".dispels", label = "Dispels",
			  desc = "Dispel Magic, Cure and Abolish Disease, Cleanse, Purify, Remove Curse, Remove Lesser Curse, Cure and Abolish Poison, Purge. One with no cooldown of its own never shows." },
			{ type = "toggle", key = KEY .. ".onlyCombat", label = "Only in a fight" },
		} },
		{ label = "Look", items = {
			{ type = "slider", key = KEY .. ".size", label = "Icon size", min = 18, max = 44, step = 1, unit = "px" },
			{ type = "slider", key = KEY .. ".distance", label = "Distance from the pointer", min = 8, max = 60, step = 1, unit = "px" },
		} },
	} }

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
			Sweep(icon.cd, id, start, duration)
			if not icon:IsShown() then
				icon:Show()
				changed = true
			end
		elseif icon:IsShown() then
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

local function OnEvent(_, event)
	if event == "SPELL_UPDATE_COOLDOWN" then
		Refresh()
	elseif event == "PLAYER_REGEN_DISABLED" then
		inFight = true
		Refresh()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inFight = false
		Refresh()
	else
		Track()
	end
end

function P.Login()
	holder = CreateFrame("Frame", "DaylightEssentialsCursorCooldowns", UIParent)
	holder:SetFrameStrata("TOOLTIP")
	holder:EnableMouse(false)
	holder:Hide()
	inFight = InCombatLockdown()
	holder:SetScript("OnEvent", OnEvent)
	for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED", "LEARNED_SPELL_IN_SKILL_LINE" }) do
		pcall(holder.RegisterEvent, holder, e)
	end
	Track()
end

function P.Setting()
	if holder then Track() end
end
