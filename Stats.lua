-- Secondary Stats: a small box of the stats that matter for how you play, in the DaylightUI look:
-- a row per stat, its name on the left and its value on the right (or all of them on one line).
-- Which stats: by your group role or your class (Auto), a fixed set for melee, ranged, casters,
-- healers or tanks, or a list of up to six you pick yourself (Custom). It hangs off the minimap's
-- corner with a fold tab, or is set free (moved with /dui unlock, windowless if you like).
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
-- on values ns.Safe says can be read. The box fits its text, measured only while the widths can
-- be read; in a fight the last measured widths stay.
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
	{ id = "ap", label = "Attack power", tag = "Atk Pwr", short = "AP", kind = "int", sample = 1234,
	  sum = function() return Sum(Call("UnitAttackPower", "player")) end },
	{ id = "crit", label = "Crit", short = "Crit", kind = "pct", sample = 12.4,
	  live = function() return First("GetCritChance") end },
	{ id = "hit", label = "Hit", short = "Hit", kind = "pct", sample = 5,
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_MELEE), First("GetHitModifier")) end },
	{ id = "speed", label = "Attack speed", tag = "Atk Speed", short = "Speed", kind = "sec", sample = 2.6,
	  live = function() return First("UnitAttackSpeed", "player") end },
	{ id = "haste", label = "Haste", short = "Haste", kind = "pct", sample = 3.15, zero = true,
	  live = function() return First("GetMeleeHaste") end },
	{ id = "expertise", label = "Expertise", short = "Exp", kind = "pct", sample = 1.5, zero = true,
	  live = function() return First("GetExpertise") end },
	{ id = "armorpen", label = "Armor penetration", tag = "Armor Pen", short = "ArP", kind = "int", sample = 140, zero = true,
	  live = function() return First("GetArmorPenetration") end },

	{ id = "rap", label = "Ranged AP", tag = "Rng Atk Pwr", short = "RAP", kind = "int", sample = 1480,
	  sum = function() return Sum(Call("UnitRangedAttackPower", "player")) end },
	{ id = "rcrit", label = "Ranged crit", tag = "Rng Crit", short = "RCrit", kind = "pct", sample = 14.25,
	  live = function() return First("GetRangedCritChance") end },
	{ id = "rhit", label = "Ranged hit", tag = "Rng Hit", short = "RHit", kind = "pct", sample = 6,
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_RANGED), First("GetRangedHitModifier")) end },
	{ id = "rspeed", label = "Ranged speed", tag = "Rng Speed", short = "RSpeed", kind = "sec", sample = 2.9,
	  live = function() return First("UnitRangedDamage", "player") end },
	-- The weapon's haste plus the quiver's.
	{ id = "rhaste", label = "Ranged haste", tag = "Rng Haste", short = "RHaste", kind = "pct", sample = 15, zero = true,
	  sum = function() return Sum(Call("GetRangedHaste")) end },

	{ id = "sp", label = "Spell power", tag = "Spell Pwr", short = "SP", kind = "int", sample = 612,
	  live = function() return First("GetSpellBonusDamage", BestSchool("GetSpellBonusDamage")) end },
	{ id = "heal", label = "Healing", short = "Heal", kind = "int", sample = 1105,
	  live = function() return First("GetSpellBonusHealing") end },
	{ id = "scrit", label = "Spell crit", tag = "Spell Crit", short = "SCrit", kind = "pct", sample = 9.8,
	  live = function() return First("GetSpellCritChance", BestSchool("GetSpellCritChance")) end },
	{ id = "shit", label = "Spell hit", tag = "Spell Hit", short = "SHit", kind = "pct", sample = 7,
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_SPELL), First("GetSpellHitModifier")) end },
	{ id = "shaste", label = "Spell haste", tag = "Spell Haste", short = "SHaste", kind = "pct", sample = 4.2, zero = true,
	  live = function() return First("UnitSpellHaste", "player") end },
	-- While casting (the regen that counts in a fight), per second, so times five.
	{ id = "regen", label = "Mana regen", tag = "Regen", short = "MP5", kind = "mp5", sample = 48,
	  sum = function()
		local _, casting = Call("GetManaRegen")
		local v = Sum(casting)
		if v then v = math.floor(v * 5 + 0.5) end
		return v
	  end },
	{ id = "spen", label = "Spell penetration", tag = "Spell Pen", short = "SPen", kind = "int", sample = 10, zero = true,
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
	{ id = "blockvalue", label = "Block value", tag = "Block Value", short = "BV", kind = "int", sample = 162, shield = true,
	  live = function() return First("GetShieldBlock") end },
}

-- Resistances (base, ?, effective): the effective one, live.
for _, r in ipairs({ { 2, "fire", "Fire" }, { 3, "nature", "Nature" }, { 4, "frost", "Frost" },
	{ 5, "shadow", "Shadow" }, { 6, "arcane", "Arcane" } }) do
	local school = r[1]
	CATALOG[#CATALOG + 1] = { id = "res_" .. r[2], label = r[3] .. " resistance", tag = r[3] .. " Res", short = r[3], kind = "int", sample = 35,
		live = function() return Third("UnitResistance", "player", school) end }
end

local BY_ID = {}
for _, s in ipairs(CATALOG) do BY_ID[s.id] = s end

-- Each stat's own colour for its name (a family shares one: every crit is gold, every hit blue).
local AP, CRIT, HIT, HASTE, SPEED = { 1, 0.55, 0.3 }, { 1, 0.82, 0.2 }, { 0.45, 0.78, 1 }, { 0.35, 0.9, 0.4 }, { 0.65, 0.95, 0.5 }
local PEN, BLOCK = { 0.75, 0.55, 1 }, { 0.8, 0.8, 0.92 }
local STAT_COLOR = {
	ap = AP, rap = AP, crit = CRIT, rcrit = CRIT, scrit = CRIT, hit = HIT, rhit = HIT, shit = HIT,
	haste = HASTE, rhaste = HASTE, shaste = HASTE, speed = SPEED, rspeed = SPEED,
	expertise = PEN, armorpen = PEN, spen = PEN,
	sp = { 0.62, 0.6, 1 }, heal = { 0.4, 1, 0.78 }, regen = { 0.35, 0.62, 1 },
	armor = { 0.86, 0.78, 0.6 }, defense = { 0.65, 0.8, 0.95 }, dodge = { 0.95, 0.75, 0.45 },
	parry = { 1, 0.6, 0.4 }, block = BLOCK, blockvalue = BLOCK,
	res_fire = { 1, 0.45, 0.25 }, res_nature = { 0.45, 0.9, 0.35 }, res_frost = { 0.55, 0.85, 1 },
	res_shadow = { 0.7, 0.45, 0.95 }, res_arcane = { 0.95, 0.65, 1 },
}

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
	dock = "minimap",
	corner = "auto",
	nudgeX = 0,
	nudgeY = 0,
	windowless = false,
	nameColors = "stat",
	colorValues = false,
}

local SLOT_VALUES, SLOT_ORDER = { none = "None" }, { "none" }
for _, s in ipairs(CATALOG) do
	SLOT_VALUES[s.id] = s.label
	SLOT_ORDER[#SLOT_ORDER + 1] = s.id
end

local function Off(get) return get(KEY .. ".enabled") == false end
local function NotFree(get) return Off(get) or get(KEY .. ".dock") ~= "free" end
local function Free(get) return Off(get) or get(KEY .. ".dock") == "free" end
local function NotCustom(get) return Off(get) or get(KEY .. ".role") ~= "custom" end

local slotItems = {}
for i = 1, SLOTS do
	slotItems[i] = { type = "dropdown", key = KEY .. ".slot" .. i, label = "Stat " .. i,
		values = SLOT_VALUES, order = SLOT_ORDER, disabled = NotCustom }
end

P.page = { id = KEY, label = "Secondary Stats",
	desc = "A small box of the stats that matter for how you play: by your role or class, or your own pick. Crit, haste, armor and the like stay live in a fight; stats the game gives in parts (attack power, hit, defense, mana regen) keep their numbers from before the fight. It sits under the minimap with a tab to fold it away, or anywhere you like. DaylightUI's info bar has small Crit, AP, SP and Hit texts too, if you'd rather have something smaller.",
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
		{ label = "Where", items = {
			{ type = "dropdown", key = KEY .. ".dock", label = "Dock to", disabled = Off,
			  values = { minimap = "The minimap", player = "Your player frame", target = "Your target frame",
				free = "Nothing: free (move it with /dui unlock)" },
			  order = { "minimap", "player", "target", "free" },
			  desc = "Docked, it hangs off a corner of that frame and grows away from it, with a tab at the corner to fold it away." },
			{ type = "dropdown", key = KEY .. ".corner", label = "Corner", disabled = Free,
			  values = { auto = "Auto (the one facing the middle of the screen)", BOTTOMLEFT = "Bottom-left",
				BOTTOMRIGHT = "Bottom-right", TOPLEFT = "Top-left", TOPRIGHT = "Top-right" },
			  order = { "auto", "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT" } },
			{ type = "slider", key = KEY .. ".nudgeX", label = "Nudge sideways", min = -60, max = 60, step = 1, unit = "px",
			  disabled = Free, desc = "Fine-tunes the docked spot: right is more." },
			{ type = "slider", key = KEY .. ".nudgeY", label = "Nudge up or down", min = -60, max = 60, step = 1, unit = "px",
			  disabled = Free, desc = "Up is more." },
			{ type = "toggle", key = KEY .. ".windowless", label = "Windowless", disabled = NotFree,
			  desc = "Just the text, with no window behind it. Only when it's free: by the minimap it keeps its window." },
		} },
		{ label = "Custom", desc = "Your own list, in this order, when Stats for is Custom.",
		  items = slotItems },
		{ label = "Look", items = {
			{ type = "dropdown", key = KEY .. ".layout", label = "Layout", disabled = Off,
			  values = { list = "A list", line = "One line" }, order = { "list", "line" } },
			{ type = "dropdown", key = KEY .. ".nameColors", label = "Name colours", disabled = Off,
			  values = { stat = "Each stat its own", class = "Your class colour", plain = "Plain" },
			  order = { "stat", "class", "plain" },
			  desc = "Each stat its own: crits gold, hit blue, haste green, attack power orange, spell power violet, and so on." },
			{ type = "toggle", key = KEY .. ".colorValues", label = "Numbers in the same colour", disabled = Off },
			{ type = "slider", key = KEY .. ".decimals", label = "Decimals on percents", min = 0, max = 2, step = 1, disabled = Off },
			{ type = "toggle", key = KEY .. ".dim", label = "Dim numbers from before the fight", disabled = Off,
			  desc = "Attack power, hit, defense and mana regen can't be worked out in a fight; their last numbers stay, dimmed." },
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

local ROW_H, PAD, GAP, SLACK = 18, 6, 14, 6

local frame, body, line   -- frame: what /dui unlock moves; body: the box, sized to its text
local shell, content             -- in body: the window (can be left off), and the text over it
local tab                        -- the fold tab, beside the box while it's under the minimap
local rows = {}
local previewing = false
local inFight = false

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, content)
	row:SetHeight(ROW_H)
	row.value = API.Text(row, "body", "RIGHT")
	row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.value:SetWordWrap(false)
	row.label = API.Text(row, "body", "LEFT")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
	row.label:SetWordWrap(false)
	rows[i] = row
	return row
end

local function PlaceRow(row, i)
	local y = -(PAD + (i - 1) * ROW_H)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, y)
	row:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, y)
end

local function Hex(role)
	local c = type(role) == "table" and role or ns.Colors()[role] or { 1, 1, 1 }
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

-- A text's width, or nil while it can't be read (a text holding a secret number has a secret width).
local function Measure(fs)
	local ok, w = pcall(fs.GetUnboundedStringWidth, fs)
	if not ok or not Safe(w) or type(w) ~= "number" then
		ok, w = pcall(fs.GetStringWidth, fs)
		if not ok or not Safe(w) or type(w) ~= "number" then return nil end
	end
	return w
end

-- The box fits its text. Values are measured whenever they can be read; in a fight, when some
-- can't, the widths measured last stay (a little slack covers a number growing by a digit).
local lastValueW, lastLineW = 40, 120
local function Size(n, oneLine)
	local w, h
	if oneLine then
		local lw = Measure(line)
		if lw then lastLineW = lw end
		w = math.ceil(lastLineW + SLACK) + PAD * 2
		h = ROW_H + PAD * 2
	else
		local labelW, valueW, readable = 0, 0, true
		for i = 1, n do
			local row = rows[i]
			if row then   -- none yet when it's first built
				labelW = math.max(labelW, Measure(row.label) or 0)
				local vw = Measure(row.value)
				if vw then valueW = math.max(valueW, vw) else readable = false end
			end
		end
		if readable then lastValueW = valueW else valueW = math.max(valueW, lastValueW) end
		valueW = math.ceil(valueW + SLACK)
		for i = 1, n do if rows[i] then rows[i].value:SetWidth(valueW) end end
		w = math.ceil(labelW) + GAP + valueW + PAD * 2
		h = PAD * 2 + n * ROW_H
	end
	local scale = G("scale") or 1
	body:SetSize(w, h)
	body:SetScale(scale)
	frame:SetSize(w * scale, h * scale)
	API.Skin(shell, { window = true })
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

-- ---------------------------------------------------------------------------------------------
-- By the minimap, with a fold tab
-- ---------------------------------------------------------------------------------------------
-- Docked to the minimap (DaylightUI's panel round it), the player frame or the target frame, the
-- box hangs off a corner of that frame (the one facing the middle of the screen, or one picked)
-- and grows away from it, nudged by the player's sliders if they like. A small tab at that corner folds it away and
-- brings it back; the tab never moves. /dui unlock leaves a docked box alone. Free, DaylightUI's
-- mover places it as before.

local TAB_W, TAB_H, TUCK, DOCK_GAP = 14, 34, 3, 3

local function DB()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	return db
end
local function Folded() return DB().statsFolded == true end

-- The frame it docks to, or nil (free, or that frame isn't there). For the minimap that's
-- DaylightUI's panel round it (its border and the data texts under the map), else the map itself.
local function DockFrame()
	local to = G("dock") or "minimap"
	local f
	if to == "minimap" then
		f = _G.DaylightUIInfoPanelBody
		if not (type(f) == "table" and f.IsShown and f:IsShown()) then f = _G.Minimap end
	elseif to == "player" then
		f = ns.MoverFrame("unitframes.player")
	elseif to == "target" then
		f = ns.MoverFrame("unitframes.target")
	end
	if type(f) == "table" and f.GetCenter and f:GetCenter() then return f end
	return nil
end
local function Docked() return DockFrame() ~= nil end

local suspended = nil
local function Suspend(on)
	if suspended == on then return end
	suspended = on
	-- Released, DaylightUI places it again (its saved spot or Home); without that, Home here.
	if not ns.SuspendMover(KEY, on) and not on and frame then
		frame:ClearAllPoints()
		frame:SetPoint(unpack(Home()))
	end
end

-- The tab on the map's corner facing the middle of the screen, the box beside the tab, both
-- growing away from the map. Positions are plain numbers, never secret.
local function PlaceDocked()
	local mm = DockFrame()
	local corner = G("corner") or "auto"
	local right, top = true, true   -- right: the box goes left; top: the box goes down
	if corner == "auto" then
		local mx, my = mm:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if mx and ux then
			local ms, us = mm:GetEffectiveScale(), UIParent:GetEffectiveScale()
			right = mx * ms > ux * us
			top = my * ms > uy * us
		end
	else
		right = corner:find("LEFT") ~= nil
		top = corner:find("BOTTOM") ~= nil
	end
	local near = right and "LEFT" or "RIGHT"    -- the map's side the box sits on
	local far = right and "RIGHT" or "LEFT"     -- the box's side against the tab
	local edge = top and "BOTTOM" or "TOP"      -- the map's edge it hangs from
	local back = top and "TOP" or "BOTTOM"      -- the box's edge level with the map's
	tab:ClearAllPoints()
	local nx, ny = G("nudgeX") or 0, G("nudgeY") or 0
	tab:SetPoint(back .. far, mm, edge .. near, (right and -DOCK_GAP or DOCK_GAP) + nx, (top and -DOCK_GAP or DOCK_GAP) + ny)
	frame:ClearAllPoints()
	frame:SetPoint(back .. far, tab, back .. near, right and TUCK or -TUCK, 0)
end

local function PaintGrip(hover)
	if not tab then return end
	local r, g, b
	if hover then
		r, g, b = API.Accent()
	else
		local c = ns.Colors().LABEL or { 0.7, 0.7, 0.7 }
		r, g, b = c[1], c[2], c[3]
	end
	for _, bar in ipairs(tab.bars) do bar:SetColorTexture(r, g, b, 1) end
end

local Paint
local function BuildTab()
	tab = CreateFrame("Button", "DaylightEssentialsStatsTab", UIParent)
	tab:SetSize(TAB_W, TAB_H)
	API.Skin(tab, { noBevel = true })
	tab.bars = {}
	for i = 1, 3 do
		local bar = tab:CreateTexture(nil, "OVERLAY")
		bar:SetSize(6, 2)
		bar:SetPoint("CENTER", tab, "CENTER", 0, (2 - i) * 4)
		tab.bars[i] = bar
	end
	PaintGrip(false)
	tab:SetScript("OnClick", function()
		local open = Folded()
		DB().statsFolded = (not open) or nil
		GameTooltip:Hide()
		if open then frame:SetAlpha(0) end
		Paint()
		if open then API.Fade(frame, 1, "FAST") end
	end)
	tab:SetScript("OnEnter", function(self)
		PaintGrip(true)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(Folded() and "Show your stats" or "Fold your stats away")
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function()
		PaintGrip(false)
		GameTooltip:Hide()
	end)
	tab:Hide()
end

-- Shows or hides the box (and its tab), docked or free.
local function Present(on)
	local docked = Docked()
	Suspend(docked)
	if docked then
		if not tab then BuildTab() end
		PlaceDocked()
	end
	shell:SetShown(docked or G("windowless") ~= true)
	if docked and on then
		tab:SetFrameStrata(frame:GetFrameStrata())
		tab:SetFrameLevel(math.max(0, frame:GetFrameLevel()))
		tab:Show()
	elseif tab then
		tab:Hide()
	end
	frame:SetShown(on and not (docked and Folded()))
end

-- ---------------------------------------------------------------------------------------------
-- Colours
-- ---------------------------------------------------------------------------------------------

local classColor
local function NameColor(stat)
	local mode = G("nameColors") or "stat"
	if mode == "stat" then return STAT_COLOR[stat.id] end
	if mode == "class" then
		if not classColor then
			local ok, _, token = pcall(UnitClass, "player")
			if ok and Safe(token) and token then
				local r, g, b = API.ClassColor(token)
				if r then classColor = { r, g, b } end
			end
		end
		return classColor
	end
	return nil
end

-- The outline one step thicker than the player's (none to thin, thin to thick), so the coloured
-- names read on any ground. Checked on every paint: DaylightUI sets the player's font back when
-- it changes.
local function Thicken(fs)
	local font, size, flags = fs:GetFont()
	if not font then return end
	flags = flags or ""
	if flags:find("THICK") then return end
	local want
	if flags:find("OUTLINE") then
		want = (flags:gsub("OUTLINE", "THICKOUTLINE"))
	else
		want = flags == "" and "OUTLINE" or (flags .. ",OUTLINE")
	end
	fs:SetFont(font, size, want)
end

local function Ink(fs, color, role)
	if color then fs:SetTextColor(color[1], color[2], color[3]) else ns.Ink(fs, role) end
end

-- ---------------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------------

local args = {}
function Paint()
	if not frame then return end
	if not previewing and not Wanted() then
		Present(false)
		return
	end
	local n = Collect()
	if n == 0 then
		Present(false)
		return
	end
	local dim = G("dim") ~= false
	local colorValues = G("colorValues") == true
	local oneLine = G("layout") == "line"
	if oneLine then
		-- One text, formatted by the game so live values may be secret: "|cLABEL|cAP |cVALUE1234|r · ..."
		for i = 1, #rows do rows[i]:Hide() end
		local labelHex, valueHex, offHex = Hex("LABEL"), Hex("VALUE"), Hex("OFF")
		local fmt = ""
		wipe(args)
		for i = 1, n do
			local d = drawn[i]
			local s = d.stat
			local c = NameColor(s)
			local nameHex = c and Hex(c) or labelHex
			if i > 1 then fmt = fmt .. labelHex .. "  \194\183  |r" end
			fmt = fmt .. nameHex .. s.short .. "|r "
			local vHex = (d.stale and dim) and offHex or ((colorValues and c) and nameHex or valueHex)
			if d.how == "live" then
				fmt = fmt .. vHex .. FormatOf(s) .. "|r"
			else
				fmt = fmt .. vHex .. "%s|r"
			end
			args[#args + 1] = d.value
		end
		Thicken(line)
		local ok = pcall(line.SetFormattedText, line, fmt, unpack(args, 1, n))
		if not ok then line:SetText("--") end
		line:Show()
		Size(n, true)
	else
		line:Hide()
		for i = 1, n do
			local d = drawn[i]
			local row = Row(i)
			PlaceRow(row, i)
			local c = NameColor(d.stat)
			Thicken(row.label)
			Thicken(row.value)
			row.label:SetText(d.stat.tag or d.stat.label)
			Ink(row.label, c, "LABEL")
			if d.how == "live" then
				local ok = pcall(row.value.SetFormattedText, row.value, FormatOf(d.stat), d.value)
				if not ok then row.value:SetText("--") end
			else
				row.value:SetText(d.value)
			end
			if d.stale and dim then
				ns.Ink(row.value, "OFF")
			else
				Ink(row.value, colorValues and c or nil, "VALUE")
			end
			row:Show()
		end
		for i = n + 1, #rows do rows[i]:Hide() end
		Size(n, false)
	end
	Present(true)
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
		if tab then tab:Hide() end
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
	-- The window on its own layer so it can be left off; the text on a layer over it.
	shell = CreateFrame("Frame", nil, body)
	shell:SetAllPoints()
	shell:SetFrameLevel(body:GetFrameLevel())
	content = CreateFrame("Frame", nil, body)
	content:SetAllPoints()
	content:SetFrameLevel(body:GetFrameLevel() + 5)
	line = API.Text(content, "body", "LEFT")
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
	classColor = nil
	if tab then
		API.Skin(tab, { noBevel = true })
		PaintGrip(false)
	end
	Paint()
end

function P.Preview()
	Refresh()
end
