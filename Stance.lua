-- Stance text: your stance, form or paladin aura by name ("Battle Stance"), as one of DaylightUI's
-- unit frame texts (API's AddText). Its page's switch puts it on your player frame (below); on any
-- frame it can also be picked as an extra text's part, and is placed like DaylightUI's own texts.
-- Its color is whichever of white or near-black reads best on that frame's health fill, at both
-- ends of a gradient (the Daylight gradient, your accent's, a class gradient or one color).

local _, ns = ...
if ns.off then return end

local L, API, me = ns.L, ns.API, ns.me
if type(me.AddText) ~= "function" then return end

local GetShapeshiftForm, GetShapeshiftFormInfo = GetShapeshiftForm, GetShapeshiftFormInfo

local function SpellName(id)
	if not id then return nil end
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and name then return name end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, id)
		if ok and name then return name end
	end
end

-- Paladin auras (first ranks: every rank has the name). They aren't forms on this client, so
-- they're read from your own buffs.
local PALADIN_AURAS = { 465, 7294, 19746, 19876, 19888, 19891, 20218, 32223 }
local auraNames
local function PaladinAura()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	if not auraNames then
		auraNames = {}
		for _, id in ipairs(PALADIN_AURAS) do
			local name = SpellName(id)
			if name then auraNames[name] = true end
		end
	end
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok or not a then return nil end
		local name, from = a.name, a.sourceUnit
		if ns.Safe(name) and ns.Safe(from) and from == "player" and auraNames[name] then return name end
	end
end

local function StanceName()
	local form = type(GetShapeshiftForm) == "function" and GetShapeshiftForm() or 0
	if ns.Safe(form) and type(form) == "number" and form > 0 and type(GetShapeshiftFormInfo) == "function" then
		local _, _, _, spellID = GetShapeshiftFormInfo(form)
		local name = ns.Safe(spellID) and SpellName(spellID)
		if name then return name end
	end
	return PaladinAura()
end

-- ---------------------------------------------------------------------------------------------
-- A color that reads on the health fill
-- ---------------------------------------------------------------------------------------------
-- The fill's colors as DaylightUI painted them (its two ends, or every stop of a gradient in more
-- colors). Not part of DaylightUI's promised API, so read with care: white when it can't be read.

local WHITE, DARK = { 1, 1, 1 }, { 0.08, 0.08, 0.08 }

local function Luminance(c)
	local function ch(v)
		v = math.max(0, math.min(1, v or 0))
		return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end

local function Contrast(a, b)
	local la, lb = Luminance(a), Luminance(b)
	if la < lb then la, lb = lb, la end
	return (la + 0.05) / (lb + 0.05)
end

local function FillColors(frame)
	local Style = ns.DUI and ns.DUI.Style
	if not (Style and Style.FillColors) then return nil end
	local tex = API.GetPart and API.GetPart(frame, "healthFill")
	if not tex then return nil end
	local ok, lo, hi = pcall(Style.FillColors, tex)
	if not ok or type(lo) ~= "table" then return nil end
	local out = { lo, type(hi) == "table" and hi or lo }
	if Style.FillStops then
		local got, stops = pcall(Style.FillStops, tex)
		if got and type(stops) == "table" then
			for _, c in ipairs(stops) do
				if type(c) == "table" then out[#out + 1] = c end
			end
		end
	end
	return out
end

-- White or near-black: the one whose worst contrast across the fill is best.
local function Ink(frame)
	local colors = FillColors(frame)
	if not colors then return WHITE end
	local white, dark = math.huge, math.huge
	for _, c in ipairs(colors) do
		local rgb = { c[1] or c.r, c[2] or c.g, c[3] or c.b }
		if type(rgb[1]) ~= "number" or not (ns.Safe(rgb[1]) and ns.Safe(rgb[2]) and ns.Safe(rgb[3])) then
			return WHITE
		end
		white = math.min(white, Contrast(WHITE, rgb))
		dark = math.min(dark, Contrast(DARK, rgb))
	end
	return dark > white * 1.15 and DARK or WHITE
end

-- ---------------------------------------------------------------------------------------------
-- Its page: one switch that puts it on your player frame (or takes it off)
-- ---------------------------------------------------------------------------------------------
-- DaylightUI's Add piece menu can't add a plugin's text (its menu choice "text:<kind>" is read
-- with a pattern that stops at the second colon of "DaylightEssentials:stance"), so the switch adds
-- it through the Unit Frames module's own Texts.Add, the function that menu calls. Placed in
-- DaylightUI's first free extra text slot; drag it where you like in Frames, Player, Design mode.

local KEY = "stance"
local KIND = ns.ADDON .. ":stance"

local P = ns.Part({ key = KEY, label = L["Stance / Aura / Form"] })
P.defaults = { player = false, spot = "left", size = 11, x = 3, y = 7 }

-- Where it sits: the same choices as DaylightUI's extra text card (its Spots), else these.
local Spots = ns.DUI and ns.DUI.Spots
local SPOT_LABELS = type(Spots) == "table" and type(Spots.LABELS) == "table" and Spots.LABELS
	or { left = "Left", center = "Center", right = "Right" }
local SPOT_ORDER = type(Spots) == "table" and type(Spots.ORDER) == "table" and Spots.ORDER
	or { "left", "center", "right" }
local function off(get) return get(KEY .. ".player") ~= true end
P.page = { id = KEY, label = L["Stance / Aura / Form"],
	desc = L["Your stance, form or paladin aura by name, on your player frame."],
	groups = {
		{ label = L["Stance / Aura / Form"], items = {
			{ type = "toggle", key = KEY .. ".player", label = L["On my player frame"],
			  desc = L["Adds it to your player frame as one of DaylightUI's extra texts. Move it in Frames, Player, with Design mode on. Its color is white or dark, whichever reads best on your health bar."] },
			{ type = "dropdown", key = KEY .. ".spot", label = L["Position"], values = SPOT_LABELS, order = SPOT_ORDER,
			  desc = L["Where it sits on your player frame, or just outside it."], disabled = off },
			{ type = "slider", key = KEY .. ".size", label = L["Text size"], min = 6, max = 30, step = 1, disabled = off },
			{ type = "slider", key = KEY .. ".x", label = L["Text left / right"], min = -50, max = 50, step = 1, unit = "px",
			  desc = L["Nudges it sideways from its position."], disabled = off },
			{ type = "slider", key = KEY .. ".y", label = L["Text up / down"], min = -50, max = 50, step = 1, unit = "px",
			  desc = L["Nudges it up or down from its position."], disabled = off },
		} },
	} }

-- Its place, from this page: written into the slot's own settings (what its card in Frames,
-- Player shows) as it's added and each time one of them changes here.
local PLACE = { "spot", "size", "x", "y" }

local function Place(slot)
	local base = "player.texts." .. slot .. "."
	for _, field in ipairs(PLACE) do
		local v = ns.API.GetSetting(ns.ADDON, KEY .. "." .. field)
		if v ~= nil then pcall(ns.DUI.Set, ns.DUI, "UnitFrames", base .. field, v) end
	end
end

local function UFTexts()
	local DUI = ns.DUI
	local mod = DUI and DUI.GetModule and DUI:GetModule("UnitFrames")
	local T = type(mod) == "table" and type(mod.ns) == "table" and mod.ns.Texts
	if type(T) == "table" and type(T.Add) == "function" and type(T.Remove) == "function" then return T, mod.ns end
end

-- The player frame's extra text slots showing it.
local function SlotsShowing(UFns)
	local out = {}
	for _, slot in ipairs(UFns.TEXT_SLOTS or {}) do
		local base = "player.texts." .. slot .. "."
		local ok, show = pcall(API.GetSetting, "UnitFrames", base .. "show")
		if ok and show == true then
			for _, part in ipairs({ "kind", "kind2", "kind3" }) do
				local got, kind = pcall(API.GetSetting, "UnitFrames", base .. part)
				if got and kind == KIND then out[#out + 1] = slot break end
			end
		end
	end
	return out
end

function P.Setting(path)
	local T, UFns = UFTexts()
	if not T then return end
	if path ~= KEY .. ".player" then
		-- (Its place changed here: the text on your frame follows.)
		for _, field in ipairs(PLACE) do
			if path == KEY .. "." .. field then
				for _, slot in ipairs(SlotsShowing(UFns)) do Place(slot) end
			end
		end
		return
	end
	local want = ns.API.GetSetting(ns.ADDON, KEY .. ".player") == true
	local have = SlotsShowing(UFns)
	if want and #have == 0 then
		local slot = T.Add("player", KIND)
		if slot then
			Place(slot)
		else
			if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff73a0ffEssentials|r: " .. L["All four extra texts on your player frame are in use: remove one first."]) end
		end
	elseif not want then
		for _, slot in ipairs(have) do T.Remove("player", "texts", slot) end
	end
end

me.AddText("stance", {
	label = L["Stance/Aura/Form"],
	-- (Stances and forms are auras on you: UNIT_AURA; a form's new power type and a stance's rage
	-- cut too. "health" and "identity" so a gradient that follows your health, or a new color
	-- pick, gets its ink again.)
	on = { "identity", "health", "power", "flags" },
	events = { "UNIT_AURA", "UNIT_DISPLAYPOWER" },
	sample = SpellName(2457) or "Battle Stance",
	text = function(unit, frame)
		if unit ~= "player" then return nil end
		local name = StanceName()
		if not name then return nil end
		local c = Ink(frame)
		return name, c[1], c[2], c[3]
	end,
})
