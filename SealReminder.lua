-- Seal Reminder: for paladins, a warning line ("Seal Missing") while no seal of yours is up, in a
-- gentle pulse like the Pet Reminder's. Quiet while you're mounted, on a flight, dead, in a
-- vehicle, resting in a town or inn (a choice), and out of a fight if you only want it in one
-- (a choice). Only once you know a seal. Move it with /dui unlock.
--
-- How it knows: out of a fight your buffs can be read, so it looks for a seal among them by name
-- (every rank has the name). In a fight the game keeps buffs secret from addons
-- (C_Secrets.ShouldAurasBeSecret), so there it goes by Judgement instead: with no seal up the game
-- itself marks Judgement as not usable (and not for want of mana). Where neither can be read, it
-- says nothing rather than guess.
-- What it costs: nothing for other classes; for a paladin, a look when your buffs, your usable
-- spells, your mount or your resting change (gathered to one look a moment later). No timers.

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "sealReminder"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["Seal Reminder"] })

P.defaults = {
	enabled = true,
	combatOnly = false,
	notResting = true,
	scale = 1,
}

P.page = { id = KEY, label = L["Seal Reminder"],
	desc = L["For paladins: a warning while you have no seal up."],
	groups = {
		{ label = L["Seal Reminder"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "toggle", key = KEY .. ".combatOnly", label = L["Only in a Fight"],
			  desc = L["No warning until a fight starts."] },
			{ type = "toggle", key = KEY .. ".notResting", label = L["Mute in Towns and Inns"],
			  desc = L["No warning while you're resting."] },
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
	} }

-- The seals, one rank of each (every rank has the name; the ones this game doesn't have are
-- skipped): Righteousness, the Crusader, Command, Light, Wisdom, Justice, Blood, Vengeance,
-- the Martyr, Corruption.
local SEALS = { 21084, 20154, 21082, 20375, 20165, 20166, 20164, 31892, 31801, 348700, 348704, 53720, 53736 }
local JUDGEMENT = 20271

local frame, body, text, pulse   -- frame: what /dui unlock moves; body: the line, sized by its setting
local W, H = 220, 30
local DEFAULT = { "CENTER", UIParent, "CENTER", 0, 110 }
local class
local looking = false

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, id)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	return nil
end

-- The seals' names in the game's language (asked again until the game has named one).
local sealNames
local function SealNames()
	if sealNames then return sealNames end
	local list, seen = {}, {}
	for _, id in ipairs(SEALS) do
		local name = SpellName(id)
		if name and not seen[name] then
			seen[name] = true
			list[#list + 1] = name
		end
	end
	if #list > 0 then sealNames = list end
	return list
end

-- Whether you know a seal yet (any rank).
local function KnowsSeal()
	for _, id in ipairs(SEALS) do
		if (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) then return true end
	end
	-- (A higher rank only: the spellbook finds a spell you know by its name.)
	local find = C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell
	if find then
		for _, name in ipairs(SealNames()) do
			local ok, slot = pcall(find, name)
			if ok and slot ~= nil then return true end
		end
	end
	return false
end

-- Whether your buffs can't be read now (a fight, or the game's restrictions).
local function AurasSecret()
	if C_Secrets and C_Secrets.ShouldAurasBeSecret then
		local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
		if not ok or not Safe(secret) or secret ~= false then return true end
	end
	return false
end

-- Whether a seal is up: true, false, or nil when it can't be told.
local function SealUp()
	local find = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if find and not AurasSecret() then
		local names = SealNames()
		if #names == 0 then return nil end
		for _, name in ipairs(names) do
			local ok, aura = pcall(find, "player", name, "HELPFUL")
			if not ok or not Safe(aura) then return nil end
			if aura then return true end
		end
		return false
	end
	-- Buffs hidden: Judgement tells. It needs a seal, so the game marks it not usable without one
	-- (and "not enough mana" is its own answer, which says nothing about the seal).
	local usable = C_Spell and C_Spell.IsSpellUsable
	if not usable then return nil end
	if not ((IsPlayerSpell and IsPlayerSpell(JUDGEMENT)) or (IsSpellKnown and IsSpellKnown(JUDGEMENT))) then return nil end
	local ok, can, noMana = pcall(usable, JUDGEMENT)
	if not ok or not Safe(can) or not Safe(noMana) or type(can) ~= "boolean" then return nil end
	if can then return true end
	if noMana then return nil end
	return false
end

local function Quiet()
	if UnitIsDeadOrGhost("player") then return true end
	if IsMounted and IsMounted() then return true end
	if UnitOnTaxi and UnitOnTaxi("player") then return true end
	if UnitInVehicle and UnitInVehicle("player") then return true end
	if G("notResting") and IsResting() then return true end
	if G("combatOnly") and not UnitAffectingCombat("player") then return true end
	return false
end

-- What to warn about now, or nil.
local function Warning()
	if not G("enabled") or class ~= "PALADIN" or Quiet() or not KnowsSeal() then return nil end
	if SealUp() == false then return L["Seal Missing"] end
	return nil
end

local function Show(word)
	if word then
		-- (The words always at full, and in a font.)
		if not text:GetFont() and _G.GameFontNormalLarge then text:SetFontObject(_G.GameFontNormalLarge) end
		text:SetText(word)
		text:SetAlpha(1)
		text:Show()
		body:SetAlpha(1)
		body:Show()
		local scale = G("scale")
		if type(scale) ~= "number" or scale < 0.5 or scale > 3 then scale = 1 end
		body:SetScale(scale)
		frame:SetSize(W * scale, H * scale)
		if not frame:IsShown() then
			frame:SetAlpha(1)
			frame:Show()
			if ns.MotionOn() then pulse:Play() end   -- (no pulse with motion off)
		end
	elseif frame:IsShown() then
		pulse:Stop()
		frame:Hide()
	end
end

local function Look()
	looking = false
	if ns.Previewing(KEY) and G("enabled") then
		Show(L["Seal Missing"])
		return
	end
	Show(Warning())
end

local function LookSoon()
	if looking then return end
	looking = true
	C_Timer.After(0.1, Look)
end

local EVENTS = { "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD", "PLAYER_MOUNT_DISPLAY_CHANGED",
	"PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_DEAD",
	"SPELLS_CHANGED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "SPELL_UPDATE_USABLE" }

local function OnEvent() LookSoon() end

-- The line, its mover and its test part. Made at login for a paladin; for any other class only
-- when unlock or test mode asks for the sample (so it can be placed from any character), and then
-- it never warns: Warning() has nothing for another class.
local function Build()
	if frame then return end
	frame = CreateFrame("Frame", "DaylightEssentialsSealReminder", UIParent)
	frame:SetSize(W, H)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:Hide()
	body = CreateFrame("Frame", nil, frame)
	body:SetSize(W, H)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	text = API.Text(body, "head", "CENTER")
	text:SetPoint("CENTER", body, "CENTER", 0, 0)
	ns.Host.Ink(text, "WARN")   -- (the look's warning ink, again on every look change)
	pulse = frame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local a = pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.45)
	a:SetDuration(0.9)
	a:SetSmoothing("IN_OUT")
	-- Placed now: after a /reload in a fight, the mover only places it once the fight ends.
	frame:SetPoint(unpack(DEFAULT))
	ns.me.RegisterMover(frame, KEY, L["Seal Reminder"], DEFAULT)
	-- (Not handed to DaylightUI's login fade-in: a paladin with no seal has the warning up the moment
	-- the game loads, and the fade-in starts what it's given at nothing. The words are kept at full
	-- by Show above; the frame's own alpha is the pulse.)
	frame:SetScript("OnEvent", OnEvent)
	-- (The game's events only matter to a paladin.)
	if class == "PALADIN" then
		for _, e in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, e) end
		frame:RegisterUnitEvent("UNIT_AURA", "player")
	end
end

function P.Login()
	local _, token = UnitClass("player")
	class = token
	-- The test part for every class (test mode lists it, and its sample can be placed from anyone).
	ns.me.RegisterTestPart(KEY, L["Seal Reminder"])
	if class ~= "PALADIN" then
		-- (Unlock mode: the sample too, so it can be moved from any character.)
		if ns.Previewing(KEY) then
			Build()
			Look()
		end
		return
	end
	Build()
	LookSoon()
end

function P.Setting()
	if frame then LookSoon() end
end

function P.Preview()
	if not frame and ns.Previewing(KEY) then Build() end
	if frame then Look() end
end
