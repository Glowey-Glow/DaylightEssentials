-- Stance text: your stance, form or paladin aura by name ("Battle Stance"), and a shaman's weapon
-- imbues ("Windfury Weapon"), as one of DaylightUI's
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

local _, playerClass = UnitClass("player")

local function FormName()
	local form = type(GetShapeshiftForm) == "function" and GetShapeshiftForm() or 0
	if ns.Safe(form) and type(form) == "number" and form > 0 and type(GetShapeshiftFormInfo) == "function" then
		local _, _, _, spellID = GetShapeshiftFormInfo(form)
		local name = ns.Safe(spellID) and SpellName(spellID)
		if name then return name end
	end
	-- (Only a paladin has an aura: the walk through your buffs is skipped for everyone else.)
	if playerClass ~= "PALADIN" then return nil end
	return PaladinAura()
end

-- A shaman's weapon imbues (Rockbiter, Flametongue, Frostbrand, Windfury): on this client a kind of
-- weapon enchant of their own (C_Item.GetWeaponEnchantInfo, enchantType 3 "Imbue"; oils, stones and
-- poisons are 2). The game names one only in the weapon's tooltip, its green line ("Windfury 1"),
-- which is turned into the spell's name ("Windfury Weapon") when one of the imbue spells starts
-- with it. Read once per enchant: names are kept by enchant ID.
local IMBUE_TYPE = 3
local IMBUE_SPELLS = { 8017, 8024, 8033, 8232 }   -- Rockbiter, Flametongue, Frostbrand, Windfury Weapon
local HANDS = { { weapon = 0, slot = 16 }, { weapon = 1, slot = 17 } }
local imbueNames = {}      -- enchant ID -> its name
local spellNames

local function NameFromTooltip(slot)
	if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
	local ok, info = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
	local lines = ok and type(info) == "table" and info.lines
	if type(lines) ~= "table" then return nil end
	if not spellNames then
		spellNames = {}
		for _, id in ipairs(IMBUE_SPELLS) do spellNames[#spellNames + 1] = SpellName(id) end
	end
	-- Green lines are the weapon's own "Equip:" bonuses too, so only one that names an imbue spell
	-- counts; else (a language where the line and the spell are worded apart) the green line with a
	-- time left in brackets, which a temporary enchant has and an equip bonus never does.
	local timed
	for i = 2, #lines do
		local line = lines[i]
		local text, c = line and line.leftText, line and line.leftColor
		if type(text) == "string" and ns.Safe(text) and type(c) == "table" then
			local r, g, bl = c.r, c.g, c.b
			if ns.Safe(g) and type(g) == "number" and g > 0.9 and (r or 0) < 0.2 and (bl or 0) < 0.2 then
				-- "Windfury 1 (5 min)" -> "Windfury"
				local base = text:gsub("%s*%(.-%)%s*$", ""):gsub("%s*%d+$", "")
				if base ~= "" then
					for _, name in ipairs(spellNames) do
						if name:sub(1, #base) == base then return name end
					end
					if not timed and text:find("%(.-%)%s*$") then timed = base end
				end
			end
		end
	end
	return timed
end

local function Imbues()
	if not (C_Item and C_Item.GetWeaponEnchantInfo) then return nil end
	local out
	for _, hand in ipairs(HANDS) do
		local ok, list = pcall(C_Item.GetWeaponEnchantInfo, hand.weapon)
		if ok and type(list) == "table" then
			for _, e in ipairs(list) do
				if type(e) == "table" and e.hasEnchant == true and e.enchantType == IMBUE_TYPE and ns.Safe(e.enchantID) then
					local id = e.enchantID
					local name = imbueNames[id]
					if name == nil then
						name = NameFromTooltip(hand.slot) or false
						if name then imbueNames[id] = name end
					end
					if name then
						out = out or {}
						-- (The same imbue on both hands is said once.)
						if out[1] ~= name then out[#out + 1] = name end
					end
				end
			end
		end
	end
	return out
end

-- Everything it says: the stance, form or aura, then a shaman's imbues, joined by " / ".
local function StanceName()
	local form = FormName()
	if playerClass ~= "SHAMAN" then return form end
	local ok, imbues = pcall(Imbues)
	if not ok then imbues = nil end
	if not imbues then return form end
	if form then table.insert(imbues, 1, form) end
	return table.concat(imbues, " / ")
end

-- ---------------------------------------------------------------------------------------------
-- A color that reads on the health fill
-- ---------------------------------------------------------------------------------------------
-- The fill's colors as DaylightUI painted them (its two ends, or every stop of a gradient in more
-- colors). Not part of DaylightUI's promised API, so read with care: white when it can't be read.

local WHITE, DARK = { 1, 1, 1 }, { 0.08, 0.08, 0.08 }

local function Channel(v)
	v = math.max(0, math.min(1, v or 0))
	return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
end

local function Luminance(r, g, b)
	return 0.2126 * Channel(r) + 0.7152 * Channel(g) + 0.0722 * Channel(b)
end

local function Contrast(la, lb)
	if la < lb then la, lb = lb, la end
	return (la + 0.05) / (lb + 0.05)
end

local WHITE_LUM, DARK_LUM = Luminance(WHITE[1], WHITE[2], WHITE[3]), Luminance(DARK[1], DARK[2], DARK[3])

-- Each frame's ink and the fill colors it was worked out from, flat (r, g, b of each in turn). The
-- text is drawn again on every health change (for a gradient that follows your health), so the
-- ink is worked out again only when one of the fill's colors has changed.
local inks = setmetatable({}, { __mode = "k" })

-- Notes one fill color (the i-th) in the frame's memo. Returns false when it can't be read (a
-- secret or no number), else whether it differs from the one noted before.
local function Note(memo, i, c)
	if type(c) ~= "table" then return nil end
	local r, g, b = c[1] or c.r, c[2] or c.g, c[3] or c.b
	if type(r) ~= "number" or not (ns.Safe(r) and ns.Safe(g) and ns.Safe(b)) then return false end
	local k = i * 3
	if memo[k - 2] == r and memo[k - 1] == g and memo[k] == b then return nil end
	memo[k - 2], memo[k - 1], memo[k] = r, g, b
	return true
end

-- White or near-black: the one whose worst contrast across the fill is best. The fill's colors as
-- DaylightUI painted them (its two ends, or every stop of a gradient in more colors).
local function Ink(frame)
	local Style = ns.DUI and ns.DUI.Style
	if not (Style and Style.FillColors) then return WHITE end
	local tex = API.GetPart and API.GetPart(frame, "healthFill")
	if not tex then return WHITE end
	local ok, lo, hi = pcall(Style.FillColors, tex)
	if not ok or type(lo) ~= "table" then return WHITE end
	local stops
	if Style.FillStops then
		local got, list = pcall(Style.FillStops, tex)
		if got and type(list) == "table" then stops = list end
	end
	local memo = inks[frame]
	if not memo then memo = {} inks[frame] = memo end
	local n, changed = 2, false
	local seen = Note(memo, 1, lo)
	if seen == false then memo.n = nil return WHITE end
	changed = changed or seen
	seen = Note(memo, 2, type(hi) == "table" and hi or lo)
	if seen == false then memo.n = nil return WHITE end
	changed = changed or seen
	if stops then
		for _, c in ipairs(stops) do
			if type(c) == "table" then
				n = n + 1
				seen = Note(memo, n, c)
				if seen == false then memo.n = nil return WHITE end
				changed = changed or seen
			end
		end
	end
	if not changed and memo.n == n then return memo.ink end
	local white, dark = math.huge, math.huge
	for i = 1, n do
		local k = i * 3
		local l = Luminance(memo[k - 2], memo[k - 1], memo[k])
		white = math.min(white, Contrast(WHITE_LUM, l))
		dark = math.min(dark, Contrast(DARK_LUM, l))
	end
	memo.n, memo.ink = n, dark > white * 1.15 and DARK or WHITE
	return memo.ink
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
P.daylightOnly = true   -- a text on Daylight UI's player frame: no page without it (Options.lua)
P.defaults = { player = false, spot = "left", size = 11, x = 3, y = 7 }

-- Where it sits: the same choices as DaylightUI's extra text card (its Spots), else these.
local Spots = ns.DUI and ns.DUI.Spots
local SPOT_LABELS = type(Spots) == "table" and type(Spots.LABELS) == "table" and Spots.LABELS
	or { left = "Left", center = "Center", right = "Right" }
local SPOT_ORDER = type(Spots) == "table" and type(Spots.ORDER) == "table" and Spots.ORDER
	or { "left", "center", "right" }
local function off(get) return get(KEY .. ".player") ~= true end
P.page = { id = KEY, label = L["Stance / Aura / Form"],
	desc = L["Your stance, form, aura or shaman weapon imbue on your player frame."],
	groups = {
		{ label = L["Stance / Aura / Form"], items = {
			{ type = "toggle", key = KEY .. ".player", label = L["On My Player Frame"],
			  desc = L["Adds it to your player frame as one of Daylight UI's extra texts. Move it in Frames, Player, with Design mode on. Its color is white or dark, whichever reads best on your health bar."] },
			{ type = "dropdown", key = KEY .. ".spot", label = L["Position"], values = SPOT_LABELS, order = SPOT_ORDER,
			  desc = L["Where it sits on your player frame, or just outside it."], disabled = off },
			{ type = "slider", key = KEY .. ".size", label = L["Text Size"], min = 6, max = 30, step = 1, disabled = off },
			{ type = "slider", key = KEY .. ".x", label = L["Text Left / Right"], min = -50, max = 50, step = 1, unit = "px",
			  desc = L["Nudges it sideways from its position."], disabled = off },
			{ type = "slider", key = KEY .. ".y", label = L["Text Up / Down"], min = -50, max = 50, step = 1, unit = "px",
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
	local DUI = ns.DUI or _G.DaylightUI   -- (ns.DUI: Host.lua; the global only in the offline tests)
	local okM, mod = false, nil
	if type(DUI) == "table" and type(DUI.GetModule) == "function" then okM, mod = pcall(DUI.GetModule, DUI, "UnitFrames") end
	if not okM then return nil end
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
		-- (Daylight UI's UnitFrames texts are inside it, not its API: called carefully.)
		local ok, slot = pcall(T.Add, "player", KIND)
		if not ok then return end
		if slot then
			Place(slot)
		else
			if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff73a0ffEssentials|r: " .. L["All four extra texts on your player frame are in use: remove one first."]) end
		end
	elseif not want then
		for _, slot in ipairs(have) do pcall(T.Remove, "player", "texts", slot) end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The name, worked out again only when it can have changed
-- ---------------------------------------------------------------------------------------------
-- The text is drawn again many times a second in combat (with your health and the other parts of
-- its slot), while the name changes only with a form, an aura or a weapon. So it's kept, and
-- worked out again after one of the events below. Daylight UI draws the text on those events too,
-- maybe before this frame has heard of them, so a name that turns out new is drawn again here
-- (through Unit Frames' Texts.Update, as Texts.Add above: called carefully). Without that call
-- the name is worked out on every draw, as before.

local name, dirty = nil, true
local drawn = setmetatable({}, { __mode = "k" })   -- frames it was drawn on
local redraw                                        -- Texts.Update, false without it, nil until asked

local watch = CreateFrame("Frame")
watch:Hide()
-- (One look per frame, however many events came in it.)
watch:SetScript("OnUpdate", function(self)
	self:Hide()
	if not dirty then return end
	-- (A failure is left for the next draw, where Daylight UI reports it.)
	local ok, now = pcall(StanceName)
	if not ok then return end
	local before = name
	name, dirty = now, false
	if name ~= before and redraw then
		for f in pairs(drawn) do pcall(redraw, f, KIND) end
	end
end)
watch:SetScript("OnEvent", function(self, event, _, info)
	-- (A buff's timer or stacks refreshed change no stance, aura or form: only one added or taken
	-- away does. Hidden lists count as a change.)
	if event == "UNIT_AURA" and type(info) == "table" and ns.Safe(info) and ns.Safe(info.isFullUpdate)
		and not info.isFullUpdate then
		local added, removed = info.addedAuras, info.removedAuraInstanceIDs
		if ns.Safe(added) and ns.Safe(removed) and not (type(added) == "table" and #added > 0)
			and not (type(removed) == "table" and #removed > 0) then
			return
		end
	end
	dirty = true
	if redraw then self:Show() end
end)

local added = me.AddText("stance", {
	label = L["Stance/Aura/Form"],
	-- (Stances and forms are auras on you: UNIT_AURA; a form's new power type too. "health" and
	-- "identity" so a gradient that follows your health, or a new color pick, gets its ink again.
	-- A stance's rage cut needs no "power": the stance's own aura and form events come with it.)
	on = { "identity", "health", "flags" },
	-- (A weapon imbue put on or run out: the weapon changes, UNIT_INVENTORY_CHANGED.)
	events = { "UNIT_AURA", "UNIT_DISPLAYPOWER", "UNIT_INVENTORY_CHANGED" },
	sample = SpellName(2457) or "Battle Stance",
	text = function(unit, frame)
		if unit ~= "player" then return nil end
		if redraw == nil then
			local T = UFTexts()
			redraw = T and type(T.Update) == "function" and T.Update or false
		end
		if frame then drawn[frame] = true end
		if dirty or not redraw then name, dirty = StanceName(), false end
		if not name then return nil end
		local c = Ink(frame)
		return name, c[1], c[2], c[3]
	end,
})

if added then
	watch:RegisterUnitEvent("UNIT_AURA", "player")
	watch:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	watch:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
	watch:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	watch:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	-- (A weapon imbue run out, where the client has the event.)
	pcall(watch.RegisterEvent, watch, "WEAPON_ENCHANT_CHANGED")
end
