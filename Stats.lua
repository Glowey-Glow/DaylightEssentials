-- Secondary Stats: a small box of the stats that matter for how you play, in the DaylightUI look:
-- a row per stat, its name on the left and its value on the right (or all of them on one line).
-- Which stats: by your group role or your class (Auto), a fixed set for melee, ranged, casters,
-- healers or tanks, or a list of up to six you pick yourself (Custom). Move it with /dui unlock.
--
-- Secret values: in a fight the game keeps your own stats secret from addons. A secret can't be
-- compared, added or turned into text by an addon's own code, but the game's own text formatting
-- takes it. So a stat the game gives as one number (crit, haste, armor, dodge...) goes straight
-- into the text's formatting (SetFormattedText) and stays live through a fight. A stat that has
-- to be added up from parts (attack power is base plus buffs, defense is skill plus bonus, mana
-- regen is per second times five) keeps its last readable text in a fight, dimmed if you like,
-- and is worked out again as the fight ends. Spell power and spell crit come per school: the best
-- school is found out of a fight and remembered, and in a fight that school's number is read live.
-- Nothing secret is ever compared, added or measured here: every sum and every check is made only
-- on values ns.Safe says can be read, and the box takes its size from its settings, never from
-- the width of its text.
--
-- What it costs: nothing while it's off. On, it listens to the game's stat events for you alone;
-- a burst of them paints the box once at once and once more 0.3 s later. No timers otherwise.

local _, ns = ...
if ns.off then return end

local API = ns.API
local KEY = "stats"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = "Secondary Stats" })

-- ---------------------------------------------------------------------------------------------
-- Reading the game
-- ---------------------------------------------------------------------------------------------

-- One read from the game by name: nothing when the function is missing or fails. Values come back
-- untouched (maybe secret).
local function Call(name, ...)
	local fn = _G[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d
end

-- Adds up plain parts. Returns nil when any part is secret (the caller keeps its last text) and
-- false when nothing could be read at all (the stat isn't there).
local function Sum(...)
	local total, any = 0, false
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if not Safe(v) then return nil end
		if type(v) == "number" then
			total = total + v
			any = true
		end
	end
	if not any then return false end
	return total
end

-- Spell schools 2 (holy) to 7 (arcane). The best one, worked out while the numbers can be read.
local best = { GetSpellBonusDamage = 2, GetSpellCritChance = 2 }
local function BestSchool(getter)
	local top, school = nil, nil
	for s = 2, 7 do
		local v = Call(getter, s)
		if not Safe(v) then return best[getter] end   -- secret: keep the one we know
		if type(v) == "number" and (top == nil or v > top) then top, school = v, s end
	end
	if school then best[getter] = school end
	return best[getter]
end

local function HasShield()
	local pdi = C_PaperDollInfo
	if not (pdi and type(pdi.OffhandHasShield) == "function") then return false end
	local ok, yes = pcall(pdi.OffhandHasShield)
	if not ok or not Safe(yes) then return nil end   -- unknown: keep the last answer
	return yes == true
end

-- ---------------------------------------------------------------------------------------------
-- The stats
-- ---------------------------------------------------------------------------------------------
-- Each: id, label, short (for one line), kind ("pct", "int", "sec", "mp5"), sample (for unlock),
--   live()  one value straight from the game (maybe secret), or
--   sum()   a plain number when it can be read, nil while secret, false when it isn't there;
--   zero    hidden at 0 when "Hide stats at 0" is on;
--   shield  shown only with a shield on.

local CR_MELEE = _G.CR_HIT_MELEE or 6
local CR_RANGED = _G.CR_HIT_RANGED or 7
local CR_SPELL = _G.CR_HIT_SPELL or 8
local function First(name, ...) return (Call(name, ...)) end
local function Second(name, ...) local _, b = Call(name, ...) return b end
local function Third(name, ...) local _, _, c = Call(name, ...) return c end

local CATALOG = {
	{ id = "ap", label = "Attack power", short = "AP", kind = "int", sample = 1234,
	  sum = function() return Sum(Call("UnitAttackPower", "player")) end },
	{ id = "crit", label = "Crit", short = "Crit", kind = "pct", sample = 12.4,
	  live = function() return First("GetCritChance") end },
	{ id = "hit", label = "Hit", short = "Hit", kind = "pct", sample = 5,
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_MELEE), First("GetHitModifier")) end },
	{ id = "speed", label = "Attack speed", short = "Speed", kind = "sec", sample = 2.6,
	  live = function() return First("UnitAttackSpeed", "player") end },
	{ id = "haste", label = "Haste", short = "Haste", kind = "pct", sample = 3.15, zero = true,
	  live = function() return First("GetMeleeHaste") end },
	{ id = "expertise", label = "Expertise", short = "Exp", kind = "pct", sample = 1.5, zero = true,
	  live = function() return First("GetExpertise") end },
	{ id = "armorpen", label = "Armor penetration", short = "ArP", kind = "int", sample = 140, zero = true,
	  live = function() return First("GetArmorPenetration") end },

	{ id = "rap", label = "Ranged AP", short = "RAP", kind = "int", sample = 1480,
	  sum = function() return Sum(Call("UnitRangedAttackPower", "player")) end },
	{ id = "rcrit", label = "Ranged crit", short = "RCrit", kind = "pct", sample = 14.25,
	  live = function() return First("GetRangedCritChance") end },
	{ id = "rhit", label = "Ranged hit", short = "RHit", kind = "pct", sample = 6,
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_RANGED), First("GetRangedHitModifier")) end },
	{ id = "rspeed", label = "Ranged speed", short = "RSpeed", kind = "sec", sample = 2.9,
	  live = function() return First("UnitRangedDamage", "player") end },
	-- The weapon's haste plus the quiver's.
	{ id = "rhaste", label = "Ranged haste", short = "RHaste", kind = "pct", sample = 15, zero = true,
	  sum = function() return Sum(Call("GetRangedHaste")) end },

	{ id = "sp", label = "Spell power", short = "SP", kind = "int", sample = 612,
	  live = function() return First("GetSpellBonusDamage", BestSchool("GetSpellBonusDamage")) end },
	{ id = "heal", label = "Healing", short = "Heal", kind = "int", sample = 1105,
	  live = function() return First("GetSpellBonusHealing") end },
	{ id = "scrit", label = "Spell crit", short = "SCrit", kind = "pct", sample = 9.8,
	  live = function() return First("GetSpellCritChance", BestSchool("GetSpellCritChance")) end },
	{ id = "shit", label = "Spell hit", short = "SHit", kind = "pct", sample = 7,
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_SPELL), First("GetSpellHitModifier")) end },
	{ id = "shaste", label = "Spell haste", short = "SHaste", kind = "pct", sample = 4.2, zero = true,
	  live = function() return First("UnitSpellHaste", "player") end },
	-- While casting (the regen that counts in a fight), per second, so times five.
	{ id = "regen", label = "Mana regen", short = "MP5", kind = "mp5", sample = 48,
	  sum = function()
		local _, casting = Call("GetManaRegen")
		local v = Sum(casting)
		if v then v = math.floor(v * 5 + 0.5) end
		return v
	  end },
	{ id = "spen", label = "Spell penetration", short = "SPen", kind = "int", sample = 10, zero = true,
	  live = function() return First("GetSpellPenetration") end },

	{ id = "armor", label = "Armor", short = "Armor", kind = "int", sample = 7320,
	  live = function() return Second("UnitArmor", "player") end },
	{ id = "defense", label = "Defense", short = "Def", kind = "int", sample = 415,
	  sum = function() return Sum(Call("UnitDefenseSkill", "player")) end },
	{ id = "dodge", label = "Dodge", short = "Dodge", kind = "pct", sample = 11.6,
	  live = function() return First("GetDodgeChance") end },
	{ id = "parry", label = "Parry", short = "Parry", kind = "pct", sample = 10.2,
	  live = function() return First("GetParryChance") end },
	{ id = "block", label = "Block", short = "Block", kind = "pct", sample = 14.8, shield = true,
	  live = function() return First("GetBlockChance") end },
	{ id = "blockvalue", label = "Block value", short = "BV", kind = "int", sample = 162, shield = true,
	  live = function() return First("GetShieldBlock") end },
}

-- Resistances (base, ?, effective): the effective one, live.
for _, r in ipairs({ { 2, "fire", "Fire" }, { 3, "nature", "Nature" }, { 4, "frost", "Frost" },
	{ 5, "shadow", "Shadow" }, { 6, "arcane", "Arcane" } }) do
	local school = r[1]
	CATALOG[#CATALOG + 1] = { id = "res_" .. r[2], label = r[3] .. " resistance", short = r[3], kind = "int", sample = 35,
		live = function() return Third("UnitResistance", "player", school) end }
end

local BY_ID = {}
for _, s in ipairs(CATALOG) do BY_ID[s.id] = s end

local ROLE_LISTS = {
	melee = { "ap", "crit", "hit", "speed", "haste", "expertise" },
	ranged = { "rap", "rcrit", "rhit", "rspeed", "rhaste" },
	caster = { "sp", "scrit", "shit", "shaste", "regen", "spen" },
	healer = { "heal", "scrit", "regen", "shaste", "sp" },
	tank = { "armor", "defense", "dodge", "parry", "block", "blockvalue" },
}
local CLASS_ROLE = { WARRIOR = "melee", ROGUE = "melee", HUNTER = "ranged", MAGE = "caster", WARLOCK = "caster",
	PRIEST = "healer", DRUID = "healer", SHAMAN = "healer", PALADIN = "healer" }
local SLOTS = 6

-- ---------------------------------------------------------------------------------------------
-- Settings and page
-- ---------------------------------------------------------------------------------------------

P.defaults = {
	enabled = true,
	role = "auto",
	slot1 = "crit", slot2 = "hit", slot3 = "ap", slot4 = "none", slot5 = "none", slot6 = "none",
	hideZero = true,
	shows = "always",
	layout = "list",
	decimals = 2,
	dim = true,
	width = 170,
	scale = 1,
}

local SLOT_VALUES, SLOT_ORDER = { none = "None" }, { "none" }
for _, s in ipairs(CATALOG) do
	SLOT_VALUES[s.id] = s.label
	SLOT_ORDER[#SLOT_ORDER + 1] = s.id
end

local function Off(get) return get(KEY .. ".enabled") == false end
local function NotCustom(get) return Off(get) or get(KEY .. ".role") ~= "custom" end

local slotItems = {}
for i = 1, SLOTS do
	slotItems[i] = { type = "dropdown", key = KEY .. ".slot" .. i, label = "Stat " .. i,
		values = SLOT_VALUES, order = SLOT_ORDER, disabled = NotCustom }
end

P.page = { id = KEY, label = "Secondary Stats",
	desc = "A small box of the stats that matter for how you play: by your role or class, or your own pick. Crit, haste, armor and the like stay live in a fight; stats the game gives in parts (attack power, hit, defense, mana regen) keep their numbers from before the fight. Move it with /dui unlock. DaylightUI's info bar has small Crit, AP, SP and Hit texts too, if you'd rather have something smaller.",
	groups = {
		{ label = "Secondary Stats", items = {
			{ type = "toggle", key = KEY .. ".enabled", label = "On" },
			{ type = "dropdown", key = KEY .. ".role", label = "Stats for", disabled = Off,
			  values = { auto = "Auto (your role or class)", melee = "Melee", ranged = "Ranged", caster = "Caster",
				healer = "Healer", tank = "Tank", custom = "Custom (pick them below)" },
			  order = { "auto", "melee", "ranged", "caster", "healer", "tank", "custom" },
			  desc = "Auto: the healer or tank stats when the group gave you that role, else your class's: melee for warriors and rogues, ranged for hunters, caster for mages and warlocks, healer for priests, druids, shamans and paladins." },
			{ type = "toggle", key = KEY .. ".hideZero", label = "Hide stats at 0", disabled = Off,
			  desc = "Haste, expertise, armor penetration and spell penetration leave the box while you have none. Decided out of a fight and kept through it." },
			{ type = "dropdown", key = KEY .. ".shows", label = "Shows", disabled = Off,
			  values = { always = "Always", combat = "In a fight only", calm = "Out of a fight only" },
			  order = { "always", "combat", "calm" } },
		} },
		{ label = "Custom", desc = "Your own list, in this order, when Stats for is Custom.",
		  items = slotItems },
		{ label = "Look", items = {
			{ type = "dropdown", key = KEY .. ".layout", label = "Layout", disabled = Off,
			  values = { list = "A list", line = "One line" }, order = { "list", "line" } },
			{ type = "slider", key = KEY .. ".decimals", label = "Decimals on percents", min = 0, max = 2, step = 1, disabled = Off },
			{ type = "toggle", key = KEY .. ".dim", label = "Dim numbers from before the fight", disabled = Off,
			  desc = "Attack power, hit, defense and mana regen can't be worked out in a fight; their last numbers stay, dimmed." },
			{ type = "slider", key = KEY .. ".width", label = "Width", min = 120, max = 320, step = 5, unit = "px", disabled = Off,
			  desc = "On one line the box grows with the number of stats." },
			{ type = "slider", key = KEY .. ".scale", label = "Size", min = 0.7, max = 1.6, step = 0.05, unit = "%", disabled = Off },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- Which stats
-- ---------------------------------------------------------------------------------------------

local function AutoRole()
	if UnitGroupRolesAssigned then
		local ok, role = pcall(UnitGroupRolesAssigned, "player")
		if ok and Safe(role) then
			if role == "HEALER" then return "healer" end
			if role == "TANK" then return "tank" end
		end
	end
	local _, class = UnitClass("player")
	if not Safe(class) then class = nil end
	return CLASS_ROLE[class or ""] or "melee"
end

local chosen = {}   -- the stats to show now, in order (catalog entries)
local function Choose()
	wipe(chosen)
	local role = G("role") or "auto"
	if role == "custom" then
		for i = 1, SLOTS do
			local s = BY_ID[G("slot" .. i) or "none"]
			if s then chosen[#chosen + 1] = s end
		end
		return
	end
	if role == "auto" or not ROLE_LISTS[role] then role = AutoRole() end
	for _, id in ipairs(ROLE_LISTS[role]) do chosen[#chosen + 1] = BY_ID[id] end
end

-- ---------------------------------------------------------------------------------------------
-- Values
-- ---------------------------------------------------------------------------------------------

local FMT_FIXED = { int = "%.0f", sec = "%.2f s", mp5 = "%.0f / 5 s" }
local PCT = { [0] = "%.0f%%", [1] = "%.1f%%", [2] = "%.2f%%" }
local function FormatOf(s)
	if s.kind == "pct" then
		local d = math.floor((G("decimals") or 2) + 0.5)
		return PCT[d] or PCT[2]
	end
	return FMT_FIXED[s.kind] or "%.0f"
end

local lastText = {}   -- id -> the last readable text of a summed stat
local zeroed = {}     -- id -> true when hidden at 0 at the last readable read
local shieldOn = false

-- One stat now: how to draw it.
--   "live", value          a single game value (maybe secret), formatted by the game
--   "text", text, stale    a plain string; stale = from before the fight
--   nil                    leave the row out
local function Value(s)
	if s.live then
		local v = s.live()
		if type(v) == "nil" then return nil end
		if Safe(v) then
			if type(v) ~= "number" then return nil end
			if s.zero then zeroed[s.id] = v == 0 end
		end
		return "live", v
	end
	local v = s.sum()
	if v == false then return nil end
	if v == nil then
		-- Secret now: the last readable text, if any.
		return "text", lastText[s.id] or "--", true
	end
	if s.zero then zeroed[s.id] = v == 0 end
	local text = string.format(FormatOf(s), v)
	lastText[s.id] = text
	return "text", text, false
end

-- ---------------------------------------------------------------------------------------------
-- The box
-- ---------------------------------------------------------------------------------------------

local ROW_H, PAD, TITLE_H, VALUE_W, LINE_STAT_W = 18, 6, 16, 84, 92

local frame, body, title, line   -- frame: what /dui unlock moves; body: the box, sized by its settings
local rows = {}
local previewing = false
local inFight = false

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, body)
	row:SetHeight(ROW_H)
	row.value = API.Text(row, "body", "RIGHT")
	row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.value:SetWidth(VALUE_W)
	row.value:SetWordWrap(false)
	row.label = API.Text(row, "body", "LEFT")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
	row.label:SetWordWrap(false)
	rows[i] = row
	return row
end

local function PlaceRow(row, i)
	local y = -(PAD + TITLE_H + (i - 1) * ROW_H)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, y)
	row:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, y)
end

local function Hex(role)
	local c = ns.Colors()[role] or { 1, 1, 1 }
	return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5))
end

-- Where it starts (until it's moved): under the player frame, left edges together; the left of
-- the screen without it.
local function Home()
	local player = ns.MoverFrame("unitframes.player")
	if player then return { "TOPLEFT", player, "BOTTOMLEFT", 0, -4 } end
	return { "LEFT", UIParent, "LEFT", 40, -40 }
end

-- The size comes from the settings and the number of rows only (a secret text can't be measured).
local function Size(n, oneLine)
	local w, h
	if oneLine then
		w = math.max(math.floor(G("width") or 170), n * LINE_STAT_W) + PAD * 2
		h = ROW_H + PAD * 2
	else
		w = math.floor(G("width") or 170)
		h = PAD * 2 + TITLE_H + n * ROW_H
	end
	local scale = G("scale") or 1
	body:SetSize(w, h)
	body:SetScale(scale)
	frame:SetSize(w * scale, h * scale)
	API.Skin(body, { window = true })
end

-- Whether the box shows now (outside unlock).
local function Wanted()
	if not G("enabled") then return false end
	local shows = G("shows")
	if shows == "combat" then return inFight end
	if shows == "calm" then return not inFight end
	return true
end

-- The rows to draw now: { stat, how, value, stale } (reused).
local drawn = {}
local function Collect()
	local n = 0
	local hideZero = G("hideZero") ~= false
	local shield = HasShield()
	if shield ~= nil then shieldOn = shield end
	for _, s in ipairs(chosen) do
		local keep = true
		if s.shield and not shieldOn and not previewing then keep = false end
		local how, v, stale
		if keep then
			if previewing then
				how, v, stale = "live", s.sample, false
			else
				how, v, stale = Value(s)
				if how == nil then keep = false
				elseif hideZero and s.zero and zeroed[s.id] then keep = false end
			end
		end
		if keep then
			n = n + 1
			local d = drawn[n]
			if not d then d = {} drawn[n] = d end
			d.stat, d.how, d.value, d.stale = s, how, v, stale
		end
	end
	for i = n + 1, #drawn do drawn[i].value = nil end
	return n
end

local args = {}
local function Paint()
	if not frame then return end
	if not previewing and not Wanted() then
		frame:Hide()
		return
	end
	local n = Collect()
	if n == 0 then
		frame:Hide()
		return
	end
	local dim = G("dim") ~= false
	local oneLine = G("layout") == "line"
	if oneLine then
		-- One text, formatted by the game so live values may be secret: "|cLABEL|cAP |cVALUE1234|r · ..."
		title:Hide()
		for i = 1, #rows do rows[i]:Hide() end
		local labelHex, valueHex, offHex = Hex("LABEL"), Hex("VALUE"), Hex("OFF")
		local fmt = ""
		wipe(args)
		for i = 1, n do
			local d = drawn[i]
			local s = d.stat
			if i > 1 then fmt = fmt .. labelHex .. "  \194\183  |r" end
			fmt = fmt .. labelHex .. s.short .. "|r "
			if d.how == "live" then
				fmt = fmt .. valueHex .. FormatOf(s) .. "|r"
			else
				fmt = fmt .. ((d.stale and dim) and offHex or valueHex) .. "%s|r"
			end
			args[#args + 1] = d.value
		end
		local ok = pcall(line.SetFormattedText, line, fmt, unpack(args, 1, n))
		if not ok then line:SetText("--") end
		line:Show()
		Size(n, true)
	else
		line:Hide()
		title:Show()
		for i = 1, n do
			local d = drawn[i]
			local row = Row(i)
			PlaceRow(row, i)
			row.label:SetText(d.stat.label)
			ns.Ink(row.label, "LABEL")
			if d.how == "live" then
				local ok = pcall(row.value.SetFormattedText, row.value, FormatOf(d.stat), d.value)
				if not ok then row.value:SetText("--") end
				ns.Ink(row.value, "VALUE")
			else
				row.value:SetText(d.value)
				ns.Ink(row.value, (d.stale and dim) and "OFF" or "VALUE")
			end
			row:Show()
		end
		for i = n + 1, #rows do rows[i]:Hide() end
		Size(n, false)
	end
	frame:Show()
end

-- A burst of events: paint at once, then once more 0.3 s later for whatever came after.
local pending = false
local function Later()
	pending = false
	Paint()
end
local function PaintSoon()
	if pending then return end
	pending = true
	Paint()
	C_Timer.After(0.3, Later)
end

-- ---------------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------------

local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_ATTACK_SPEED",
	"UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "UNIT_SPELL_HASTE", "UNIT_RESISTANCES", "UNIT_DEFENSE",
	"PLAYER_DAMAGE_DONE_MODS", "UNIT_MAXPOWER" }
local EVENTS = { "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
	"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }
local ROLE_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }

local listening, listeningRoles = false, false

local function Listen(on, roles)
	if on ~= listening then
		listening = on
		for _, e in ipairs(UNIT_EVENTS) do
			if on then
				-- Some of these may not exist on this client: a missing one is just left out.
				if not pcall(frame.RegisterUnitEvent, frame, e, "player") then pcall(frame.RegisterEvent, frame, e) end
			else
				pcall(frame.UnregisterEvent, frame, e)
			end
		end
		for _, e in ipairs(EVENTS) do
			if on then pcall(frame.RegisterEvent, frame, e) else pcall(frame.UnregisterEvent, frame, e) end
		end
	end
	roles = on and roles or false
	if roles ~= listeningRoles then
		listeningRoles = roles
		for _, e in ipairs(ROLE_EVENTS) do
			if roles then pcall(frame.RegisterEvent, frame, e) else pcall(frame.UnregisterEvent, frame, e) end
		end
	end
end

local function OnEvent(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		inFight = true
		Paint()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inFight = false
		Paint()   -- everything readable again: a full paint, the sums and the hidden-at-0 ones too
	elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
		Choose()
		PaintSoon()
	elseif event == "PLAYER_ENTERING_WORLD" then
		inFight = InCombatLockdown() == true
		Choose()
		PaintSoon()
	else
		PaintSoon()
	end
end

-- Everything again from the settings.
local function Refresh()
	if not frame then return end
	local on = G("enabled") == true
	previewing = on and ns.Previewing(KEY)
	Listen(on, (G("role") or "auto") == "auto")
	if not on then
		frame:Hide()
		return
	end
	Choose()
	Paint()
end

local function Build()
	if frame then return end
	frame = CreateFrame("Frame", "DaylightEssentialsStats", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:Hide()
	body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	title = API.Text(body, "small", "LEFT")
	title:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + 1, -PAD)
	title:SetText("Stats")
	ns.Ink(title, "LABEL")
	line = API.Text(body, "body", "LEFT")
	line:SetPoint("LEFT", body, "LEFT", PAD, 0)
	line:SetPoint("RIGHT", body, "RIGHT", -PAD, 0)
	line:SetWordWrap(false)
	line:Hide()
	frame:SetScript("OnEvent", OnEvent)
	inFight = InCombatLockdown() == true
	Size(1, false)
	-- Placed now: after a /reload in a fight, the mover only places it once the fight ends.
	frame:SetPoint(unpack(Home()))
	ns.me.RegisterMover(frame, KEY, "Secondary stats", Home)
	ns.me.RegisterTestPart(KEY, "Secondary stats")
end

function P.Login()
	Build()
	Refresh()
end

function P.Setting()
	Refresh()
end

function P.Style()
	if not frame then return end
	ns.Ink(title, "LABEL")
	Paint()
end

function P.Preview()
	Refresh()
end
