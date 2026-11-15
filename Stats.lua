-- Secondary Stats: a small box of the stats that matter for how you play, in the DaylightUI look:
-- a row per stat, its name on the left and its value on the right (or all of them on one line).
-- Which stats: by your group role or your class (Auto), a fixed set for melee, ranged, casters,
-- healers or tanks, or a list of up to six you pick yourself (Custom). It docks against the side
-- of the minimap, the damage meter or the chat with a fold tab, or is set free (moved with /dui
-- unlock). Windowless (just the text) works docked or free.
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

local L = ns.L

local API = ns.API
local KEY = "stats"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["Secondary Stats"] })

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
	{ id = "ap", label = "Attack power", tag = L["Atk Pwr"], short = L["AP"], kind = "int", sample = 1234,
	  sum = function() return Sum(Call("UnitAttackPower", "player")) end },
	{ id = "crit", label = L["Crit"], short = L["Crit"], kind = "pct", sample = 12.4,
	  live = function() return First("GetCritChance") end },
	{ id = "hit", label = L["Hit"], short = L["Hit"], kind = "pct", sample = 5, cap = "melee",
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_MELEE), First("GetHitModifier")) end },
	{ id = "speed", label = "Attack speed", tag = L["Atk Speed"], short = L["Speed"], kind = "sec", sample = 2.6,
	  live = function() return First("UnitAttackSpeed", "player") end },
	{ id = "haste", label = L["Haste"], short = L["Haste"], kind = "pct", sample = 3.15, zero = true,
	  live = function() return First("GetMeleeHaste") end },
	{ id = "expertise", label = L["Expertise"], short = L["Exp"], kind = "pct", sample = 1.5, zero = true,
	  live = function() return First("GetExpertise") end },
	{ id = "armorpen", label = "Armor penetration", tag = L["Armor Pen"], short = L["ArP"], kind = "int", sample = 140, zero = true,
	  live = function() return First("GetArmorPenetration") end },

	{ id = "rap", label = "Ranged AP", tag = L["Rng Atk Pwr"], short = L["RAP"], kind = "int", sample = 1480,
	  sum = function() return Sum(Call("UnitRangedAttackPower", "player")) end },
	{ id = "rcrit", label = "Ranged crit", tag = L["Rng Crit"], short = L["RCrit"], kind = "pct", sample = 14.25,
	  live = function() return First("GetRangedCritChance") end },
	{ id = "rhit", label = "Ranged hit", tag = L["Rng Hit"], short = L["RHit"], kind = "pct", sample = 6, cap = "ranged",
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_RANGED), First("GetRangedHitModifier")) end },
	{ id = "rspeed", label = "Ranged speed", tag = L["Rng Speed"], short = L["RSpeed"], kind = "sec", sample = 2.9,
	  live = function() return First("UnitRangedDamage", "player") end },
	-- The weapon's haste plus the quiver's.
	{ id = "rhaste", label = "Ranged haste", tag = L["Rng Haste"], short = L["RHaste"], kind = "pct", sample = 15, zero = true,
	  sum = function() return Sum(Call("GetRangedHaste")) end },

	{ id = "sp", label = "Spell power", tag = L["Spell Pwr"], short = L["SP"], kind = "int", sample = 612,
	  live = function() return First("GetSpellBonusDamage", BestSchool("GetSpellBonusDamage")) end },
	{ id = "heal", label = L["Healing"], short = L["Heal"], kind = "int", sample = 1105,
	  live = function() return First("GetSpellBonusHealing") end },
	{ id = "scrit", label = "Spell crit", tag = L["Spell Crit"], short = L["SCrit"], kind = "pct", sample = 9.8,
	  live = function() return First("GetSpellCritChance", BestSchool("GetSpellCritChance")) end },
	{ id = "shit", label = "Spell hit", tag = L["Spell Hit"], short = L["SHit"], kind = "pct", sample = 7, cap = "spell",
	  sum = function() return Sum(First("GetCombatRatingBonus", CR_SPELL), First("GetSpellHitModifier")) end },
	{ id = "shaste", label = "Spell haste", tag = L["Spell Haste"], short = L["SHaste"], kind = "pct", sample = 4.2, zero = true,
	  live = function() return First("UnitSpellHaste", "player") end },
	-- While casting (the regen that counts in a fight), per second, so times five.
	{ id = "regen", label = "Mana regen", tag = L["Regen"], short = L["MP5"], kind = "mp5", sample = 48,
	  sum = function()
		local _, casting = Call("GetManaRegen")
		local v = Sum(casting)
		if v then v = math.floor(v * 5 + 0.5) end
		return v
	  end },
	{ id = "spen", label = "Spell penetration", tag = L["Spell Pen"], short = L["SPen"], kind = "int", sample = 10, zero = true,
	  live = function() return First("GetSpellPenetration") end },

	{ id = "armor", label = ns.GameText("STAT_ARMOR", L["Armor"]), short = L["Armor"], kind = "int", sample = 7320,
	  live = function() return Second("UnitArmor", "player") end },
	{ id = "defense", label = ns.GameText("DEFENSE", L["Defense"]), short = L["Def"], kind = "int", sample = 415,
	  sum = function() return Sum(Call("UnitDefenseSkill", "player")) end },
	{ id = "dodge", label = ns.GameText("STAT_DODGE", L["Dodge"]), short = L["Dodge"], kind = "pct", sample = 11.6,
	  live = function() return First("GetDodgeChance") end },
	{ id = "parry", label = ns.GameText("STAT_PARRY", L["Parry"]), short = L["Parry"], kind = "pct", sample = 10.2,
	  live = function() return First("GetParryChance") end },
	{ id = "block", label = ns.GameText("STAT_BLOCK", L["Block"]), short = L["Block"], kind = "pct", sample = 14.8, shield = true,
	  live = function() return First("GetBlockChance") end },
	{ id = "blockvalue", label = "Block value", tag = L["Block Value"], short = L["BV"], kind = "int", sample = 162, shield = true,
	  live = function() return First("GetShieldBlock") end },
}

-- Resistances (base, ?, effective): the effective one, live.
-- (Each name whole, in the game's words on other clients: RESISTANCE2_NAME is Fire Resistance.)
for _, r in ipairs({ { 2, "fire", L["Fire resistance"], L["Fire Res"], L["Fire"] },
	{ 3, "nature", L["Nature resistance"], L["Nature Res"], L["Nature"] },
	{ 4, "frost", L["Frost resistance"], L["Frost Res"], L["Frost"] },
	{ 5, "shadow", L["Shadow resistance"], L["Shadow Res"], L["Shadow"] },
	{ 6, "arcane", L["Arcane resistance"], L["Arcane Res"], L["Arcane"] } }) do
	local school = r[1]
	CATALOG[#CATALOG + 1] = { id = "res_" .. r[2], label = ns.GameText("RESISTANCE" .. school .. "_NAME", r[3]), tag = r[4], short = r[5], kind = "int", sample = 35,
		live = function() return Third("UnitResistance", "player", school) end }
end

local BY_ID = {}
for _, s in ipairs(CATALOG) do BY_ID[s.id] = s end

-- Each stat's own color for its name (a family shares one: every crit is gold, every hit blue).
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
	meterCorner = "BOTTOMLEFT",
	chatFade = false,
	nudgeX = 0,
	nudgeY = 0,
	windowless = false,
	nameColors = "stat",
	colorValues = false,
	hitCap = true,
	shadow = 1,
}

local SLOT_VALUES, SLOT_ORDER = { none = L["None"] }, { "none" }
for _, s in ipairs(CATALOG) do
	SLOT_VALUES[s.id] = s.tag or s.label
	SLOT_ORDER[#SLOT_ORDER + 1] = s.id
end

local function Off(get) return get(KEY .. ".enabled") == false end
local function Free(get) return Off(get) or get(KEY .. ".dock") == "free" end
local function DockIs(to) return function(get) return get(KEY .. ".dock") == to end end
local function DockIsNot(to) return function(get) return get(KEY .. ".dock") ~= to end end
local function NotCustom(get) return Off(get) or get(KEY .. ".role") ~= "custom" end

local slotItems = {}
for i = 1, SLOTS do
	slotItems[i] = { type = "dropdown", key = KEY .. ".slot" .. i, label = L["Stat %d"]:format(i),
		values = SLOT_VALUES, order = SLOT_ORDER, disabled = NotCustom }
end

P.page = { id = KEY, label = L["Secondary Stats"],
	desc = L["The stats that matter for how you play, by role, class or your own pick."],
	groups = {
		{ label = L["Secondary Stats"],
		  desc = L["Crit, haste, armor and the like stay live in a fight; stats the game gives in parts (attack power, hit, defense, mana regen) keep their numbers from before the fight. DaylightUI's info bar has small Crit, AP, SP and Hit texts too, if you'd rather have something smaller."],
		  items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "dropdown", key = KEY .. ".role", label = L["Stats for"], disabled = Off,
			  values = { auto = L["Auto"], melee = L["Melee"], ranged = L["Ranged"], caster = L["Caster"],
				healer = L["Healer"], tank = L["Tank"], custom = L["Custom"] },
			  order = { "auto", "melee", "ranged", "caster", "healer", "tank", "custom" },
			  desc = L["Auto: the healer or tank stats when the group gave you that role, else your class's: melee for warriors and rogues, ranged for hunters, caster for mages and warlocks, healer for priests, druids, shamans and paladins. Custom: the six stats you pick below."] },
			{ type = "toggle", key = KEY .. ".hideZero", label = L["Hide stats at 0"], disabled = Off,
			  desc = L["Haste, expertise, armor penetration and spell penetration leave the box while you have none. Decided out of a fight and kept through it."] },
			{ type = "dropdown", key = KEY .. ".shows", label = L["Shows"], disabled = Off,
			  values = { always = L["Always"], combat = L["In a fight"], calm = L["Out of a fight"] },
			  order = { "always", "combat", "calm" } },
		} },
		{ label = L["Where"], items = {
			{ type = "dropdown", key = KEY .. ".dock", label = L["Dock to"], disabled = Off,
			  values = { minimap = L["Minimap"], meters = L["Damage meters"], chat = L["Chat"], free = L["Free"] },
			  order = { "minimap", "meters", "chat", "free" },
			  desc = L["Docked, it sits against that frame's side at a corner, level with it, and slides out of it and back in with a tab on its edge. Damage meters: their own window when detached, else the minimap panel they sit in. Chat: DaylightUI's chat window. Free: move it anywhere with /dui unlock."] },
			{ type = "dropdown", key = KEY .. ".meterCorner", label = L["Corner"], disabled = Off,
			  hidden = DockIsNot("meters"),
			  desc = L["A bottom corner only: the threat meter slides out of the top. When it grows down past the stats, they step down under it, or out beside it when there's no room below."],
			  values = { BOTTOMLEFT = L["Bottom-left"], BOTTOMRIGHT = L["Bottom-right"] },
			  order = { "BOTTOMLEFT", "BOTTOMRIGHT" } },
			{ type = "toggle", key = KEY .. ".chatFade", label = L["Fade with the chat"], disabled = Off,
			  hidden = DockIsNot("chat"),
			  desc = L["The stats fade out and back in along with DaylightUI's chat window."] },
			{ type = "dropdown", key = KEY .. ".corner", label = L["Corner"], disabled = Free, hidden = DockIs("meters"),
			  desc = L["Auto: the corner facing the middle of the screen."],
			  values = { auto = L["Auto"], BOTTOMLEFT = L["Bottom-left"],
				BOTTOMRIGHT = L["Bottom-right"], TOPLEFT = L["Top-left"], TOPRIGHT = L["Top-right"] },
			  order = { "auto", "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT" } },
			{ type = "slider", key = KEY .. ".nudgeX", label = L["Horizontal Shift"], min = -60, max = 60, step = 1, unit = "px",
			  disabled = Free, desc = L["Fine-tunes the docked spot: right is more."] },
			{ type = "slider", key = KEY .. ".nudgeY", label = L["Vertical Shift"], min = -60, max = 60, step = 1, unit = "px",
			  disabled = Free, desc = L["Up is more."] },
			{ type = "toggle", key = KEY .. ".windowless", label = L["Windowless"], disabled = Off,
			  desc = L["Just the text, with no window behind it, docked or free. Docked, the fold tab stays."] },
		} },
		{ label = L["Custom"], desc = L["Your own list, in this order, when Stats for is Custom."],
		  items = slotItems },
		{ label = L["Look"], items = {
			{ type = "dropdown", key = KEY .. ".layout", label = L["Layout"], disabled = Off,
			  values = { list = L["A list"], line = L["One line"] }, order = { "list", "line" } },
			{ type = "dropdown", key = KEY .. ".nameColors", label = L["Stat Colors"], disabled = Off,
			  values = { stat = L["Per stat"], class = L["Class color"], plain = L["Plain"] },
			  order = { "stat", "class", "plain" },
			  desc = L["Per stat: crits gold, hit blue, haste green, attack power orange, spell power violet, and so on."] },
			{ type = "toggle", key = KEY .. ".colorValues", label = L["Match Numbers to Stat Color"], disabled = Off },
			{ type = "toggle", key = KEY .. ".hitCap", label = L["Green when Hit Capped"], disabled = Off,
			  desc = L["Melee, ranged and spell hit turn green when you have enough to never miss your current target, by its level: the same numbers as the game's Hit Chance tooltip (5% melee and 4% spells at your level, 8% and 17% against raid bosses)."] },
			{ type = "slider", key = KEY .. ".shadow", label = L["Text shadow"], min = 0, max = 4, step = 1, unit = "px", disabled = Off,
			  desc = L["How far the dark shadow under the text reaches. 0 for none."] },
			{ type = "slider", key = KEY .. ".decimals", label = L["Number of Decimal Places"], min = 0, max = 2, step = 1, disabled = Off },
			{ type = "toggle", key = KEY .. ".dim", label = L["Desaturate Numbers in Fight"], disabled = Off,
			  desc = L["Attack power, hit, defense and mana regen can't be worked out in a fight; their last numbers stay, dimmed."] },
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 1.6, step = 0.05, unit = "%", disabled = Off },
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

local FMT_FIXED = { int = "%.0f", sec = L["%.2f s"], mp5 = L["%.0f / 5 s"] }
local PCT = { [0] = "%.0f%%", [1] = "%.1f%%", [2] = "%.2f%%" }
local function FormatOf(s)
	if s.kind == "pct" then
		local d = math.floor((G("decimals") or 2) + 0.5)
		return PCT[d] or PCT[2]
	end
	return FMT_FIXED[s.kind] or "%.0f"
end

local lastText = {}   -- id -> the last readable text of a summed stat
local lastNum = {}   -- the last readable number of each added-up stat (hit's cap check uses it)

-- The hit you need to never miss your current enemy target (percent), or nil (no such target).
-- The game's own rule, as its Hit Chance tooltip gives it: melee and ranged miss 5% at your
-- level, +0.1% per point of defense over your weapon skill (5 a level) up to 10 points, 0.2% a
-- point for the whole gap past that (8% against a raid boss, 3 levels up), 0.04% less a point below you. Spells
-- miss 4% at your level, 1% more a level up to 2 levels, then 11% a level against creatures (17%
-- for a raid boss) or 7% against players; never under 1%.
local function HitNeed(kind)
	if not (UnitExists("target") and UnitCanAttack("player", "target")) then return nil end
	local ok, dead = pcall(UnitIsDeadOrGhost, "target")
	if ok and Safe(dead) and dead then return nil end
	local mine, theirs = UnitLevel("player"), UnitLevel("target")
	if not (Safe(mine) and Safe(theirs)) or type(mine) ~= "number" or type(theirs) ~= "number" then return nil end
	local okC, kind2 = pcall(UnitClassification, "target")
	if theirs <= 0 or (okC and Safe(kind2) and kind2 == "worldboss") then theirs = mine + 3 end
	local d = theirs - mine
	if kind == "spell" then
		local okP, player = pcall(UnitIsPlayer, "target")
		player = okP and Safe(player) and player
		local miss
		if d <= 2 then miss = 4 + d else miss = 6 + (player and 7 or 11) * (d - 2) end
		return math.max(1, miss)
	end
	local skill = 5 * d
	local miss
	if skill > 10 then miss = 5 + skill * 0.2
	elseif skill >= 0 then miss = 5 + skill * 0.1
	else miss = 5 + skill * 0.04 end
	return math.max(0, miss)
end

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
	lastNum[s.id] = v
	local text = string.format(FormatOf(s), v)
	lastText[s.id] = text
	return "text", text, false
end

-- ---------------------------------------------------------------------------------------------
-- The box
-- ---------------------------------------------------------------------------------------------

local ROW_H, PAD, GAP, SLACK = 18, 6, 14, 6

local frame, body, line   -- frame: what /dui unlock moves; body: the box, sized to its text
local watcher             -- in frame: the threat meter and chat fade watch (Watching)
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
	-- Anchored once: a row's spot depends only on its number.
	local y = -(PAD + (i - 1) * ROW_H)
	row:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, y)
	row:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, y)
	rows[i] = row
	return row
end

-- A color's "|cff......" code, kept until the style changes (wiped in P.Style).
local hexOf = {}
local WHITE = { 1, 1, 1 }
local function Hex(role)
	local h = hexOf[role]
	if h then return h end
	local c = type(role) == "table" and role or ns.Colors()[role] or WHITE
	h = string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5))
	hexOf[role] = h
	return h
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
local fullW, fullH = 1, 1   -- the box's whole size on screen, for the slide
local sizedW, sizedH, sizedScale   -- what Size last set (nil: set it again, e.g. after a style change)
local placeDirty = true            -- Present places the box (dock, slide) again on its next call
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
	if w == sizedW and h == sizedH and scale == sizedScale then return end
	sizedW, sizedH, sizedScale = w, h, scale
	body:SetSize(w, h)
	body:SetScale(scale)
	fullW, fullH = w * scale, h * scale
	frame:SetSize(fullW, fullH)   -- docked, the slide narrows it again (Present)
	ns.SkinWindow(shell, nil, KEY)
	placeDirty = true
end

-- A whisper conversation is open: DaylightUI's conversation card slides out beside the whisper
-- tiles, over where the box sits. The box steps aside while it's up and comes back once it has slid
-- away.
local talking = false

-- Whether the box shows now (outside unlock).
local function Wanted()
	if not G("enabled") then return false end
	if talking then return false end
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
-- Docked to the minimap (DaylightUI's panel round it), the damage meter or the chat window, the
-- box sits flush against that frame's side at a corner (the one facing the middle of the screen,
-- or one picked), level with it, and grows away from it, nudged by the player's sliders. A small tab at that corner folds it away and
-- brings it back; the tab never moves. /dui unlock leaves a docked box alone. Free, DaylightUI's
-- mover places it as before.

local TAB_W, TAB_H, TUCK, DOCK_GAP, SLIDE = 14, 34, 3, 1, 0.3
local TAB_GREY = { 0.55, 0.55, 0.58 }

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
	if to == "minimap" or to == "player" or to == "target" then   -- (the last two: retired choices)
		f = _G.DaylightUIInfoPanelBody
		if not (type(f) == "table" and f.IsShown and f:IsShown()) then f = _G.Minimap end
	elseif to == "meters" then
		-- The meter's own window while it's detached; in the minimap's panel, that panel.
		f = _G.DaylightUIDamageMeter
		if not (type(f) == "table" and f.IsShown and f:IsShown()) then
			f = _G.DaylightUIInfoPanelBody
			if not (type(f) == "table" and f.IsShown and f:IsShown()) then f = nil end
		end
	elseif to == "chat" then
		f = _G.DaylightUIChatPanel
		if not (type(f) == "table" and f.IsShown and f:IsShown()) then f = nil end
	end
	if type(f) == "table" and f.GetCenter and f:GetCenter() then return f end
	return nil
end

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

-- Which way the box goes from the corner: goesLeft (the frame is on the screen's right), goesDown
-- (it's in the top half). Auto picks the corner facing the middle of the screen.
local goesLeft, goesDown = true, true
local function PickCorner(dock)
	local corner = G("corner") or "auto"
	-- By the damage meters, a bottom corner only (the threat meter slides out over the top ones).
	if G("dock") == "meters" then corner = G("meterCorner") == "BOTTOMRIGHT" and "BOTTOMRIGHT" or "BOTTOMLEFT" end
	if corner ~= "auto" then
		goesLeft = corner:find("LEFT") ~= nil
		goesDown = corner:find("BOTTOM") ~= nil
		return
	end
	local mx, my = dock:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if mx and ux then
		local ms, us = dock:GetEffectiveScale(), UIParent:GetEffectiveScale()
		goesLeft = mx * ms > ux * us
		goesDown = my * ms > uy * us
	end
end

-- The slide: 0 folded away, 1 out. Docked, the outer frame is a clip as wide as p times the box;
-- the box rides its outer edge, so it comes out from the corner (fading in) rather than popping
-- up, and the tab rides that edge too. Eased in and out over 0.3 s, as DaylightUI's own panels
-- slide; straight there when the player has DaylightUI's motion off.
local slideP, slideFrom, slideGoal, slideT
local slider
local tabAt   -- docked: { the tab's point, the box's point } at the shared corner (PlaceDocked)
local function ApplySlide()
	if not frame then return end
	local p = slideP or 1
	-- The tab sits on the box's outer edge, level with the corner: tucked behind the box's border
	-- while it's out, flush against the box's edge (so against the frame's corner) once folded.
	if tab and tabAt then
		tab:ClearAllPoints()
		tab:SetPoint(tabAt[1], frame, tabAt[2], (goesLeft and TUCK or -TUCK) * p, 0)
	end
	-- Clipped only while it's partly out: fully out, its window's edge and shadow show whole.
	frame:SetClipsChildren(p < 1)
	frame:SetWidth(math.max(0.01, p * fullW))
	frame:SetHeight(fullH)
	body:SetAlpha(p)
	body:SetShown(p > 0)
end
local function Smooth(t) return t * t * (3 - 2 * t) end
local function SlideTo(goal)
	if not ns.MotionOn() or slideP == nil then
		slideP, slideT = goal, nil
		if slider then slider:Hide() end
		ApplySlide()
		return
	end
	slideFrom, slideGoal, slideT = slideP, goal, 0
	if not slider then
		slider = CreateFrame("Frame")
		slider:SetScript("OnUpdate", function(self, dt)
			if not slideT then
				self:Hide()
				return
			end
			slideT = math.min(1, slideT + (dt or 0) / SLIDE)
			slideP = slideFrom + (slideGoal - slideFrom) * Smooth(slideT)
			if slideT >= 1 then
				slideP, slideT = slideGoal, nil
				self:Hide()
			end
			ApplySlide()
		end)
	end
	slider:Show()
end

-- The tab's chevron points down as drawn: turned a quarter toward the frame it's docked to while
-- the box is out (click to fold it in), away from it while folded (click to bring it out).
local function TurnChevron()
	if not (tab and tab.icon) then return end
	local towardDock = not Folded()
	local pointRight = (goesLeft and towardDock) or (not goesLeft and not towardDock)
	tab.icon:SetRotation(pointRight and math.pi / 2 or -math.pi / 2)
end

local function PaintGrip(hover)
	if not tab then return end
	local r, g, b
	if hover then r, g, b = API.Accent() else r, g, b = TAB_GREY[1], TAB_GREY[2], TAB_GREY[3] end
	if tab.icon then
		tab.icon:SetVertexColor(r, g, b)
	else
		for _, bar in ipairs(tab.bars) do bar:SetColorTexture(r, g, b, 1) end
	end
end

-- The tab shows while the mouse is near: over the box, the tab or the frame it's docked to.
local tabNear, hoverWait = nil, 0
local dockNow   -- the frame it's docked to, as Present last found it
local function WatchHover(self, dt)
	hoverWait = hoverWait + (dt or 0)
	if hoverWait < 0.05 and tabNear ~= nil then return end
	hoverWait = 0
	local dock = dockNow
	local near = self:IsMouseOver() or (body:IsVisible() and body:IsMouseOver())
		or (dock and dock:IsMouseOver()) or false
	if near ~= tabNear then
		tabNear = near
		API.Fade(self, near and 1 or 0, "FAST")
	end
end

local Paint
local function BuildTab()
	tab = CreateFrame("Button", "DaylightEssentialsStatsTab", UIParent)
	tab:SetSize(TAB_W + TUCK, TAB_H)
	API.Skin(tab, { borderPx = 3 })
	local chevron = ns.DaylightMedia("ui-chevron.png")
	if chevron then
		tab.icon = tab:CreateTexture(nil, "OVERLAY")
		tab.icon:SetTexture(chevron)
		tab.icon:SetSize(12, 12)
	else
		tab.bars = {}
		for i = 1, 3 do
			local bar = tab:CreateTexture(nil, "OVERLAY")
			bar:SetSize(6, 2)
			bar:SetPoint("CENTER", tab, "CENTER", 0, (2 - i) * 4)
			tab.bars[i] = bar
		end
	end
	PaintGrip(false)
	tab:SetScript("OnClick", function()
		local open = Folded()
		DB().statsFolded = (not open) or nil
		GameTooltip:Hide()
		TurnChevron()
		SlideTo(open and 1 or 0)
	end)
	tab:SetScript("OnEnter", function(self)
		PaintGrip(true)
		GameTooltip:SetOwner(self, goesLeft and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
		GameTooltip:SetText(Folded() and L["Show your stats"] or L["Fold your stats away"])
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function()
		PaintGrip(false)
		GameTooltip:Hide()
	end)
	tab:SetScript("OnUpdate", WatchHover)
	tab:SetScript("OnShow", function(self)
		tabNear = nil
		WatchHover(self, 0)
	end)
	tab:SetAlpha(0)
	tab:Hide()
end

-- Docked: flush against the frame's side, level with its corner (for a top-right minimap: against
-- the panel's left edge, bottoms together), so it grows up and outward and slides out of that
-- edge as DaylightUI's meter slides out of the panel. The box rides the clip's outer edge, and the
-- tab that edge too, level with the corner (ApplySlide). Positions are plain numbers, never secret.
local makeWay = 0    -- docked by the meters: how far down it stepped to clear the threat meter
local makeWayX = 0   -- or how far out sideways (away from the meter), when there's no room below
local function PlaceDocked(dock)
	PickCorner(dock)
	local level = goesDown and "BOTTOM" or "TOP"      -- the corner's edge, shared with the frame
	local inner = goesLeft and "RIGHT" or "LEFT"      -- the box's side against the frame
	local outer = goesLeft and "LEFT" or "RIGHT"      -- the side it grows to
	local nx, ny = G("nudgeX") or 0, G("nudgeY") or 0
	frame:ClearAllPoints()
	local x = (goesLeft and -(DOCK_GAP + makeWayX) or (DOCK_GAP + makeWayX)) + nx
	frame:SetPoint(level .. inner, dock, level .. outer, x, ny - makeWay)
	body:ClearAllPoints()
	body:SetPoint(level .. outer, frame, level .. outer)
	tabAt = { level .. inner, level .. outer }
	if tab.icon then
		tab.icon:ClearAllPoints()
		tab.icon:SetPoint("CENTER", tab, "CENTER", (goesLeft and -TUCK or TUCK) / 2, 0)
	end
	TurnChevron()
end

-- Docked to the damage meters, the threat meter slides out of the same edge from the top and
-- grows down a row per group member, while the box grows up from the bottom. When the threat
-- meter's bottom reaches the box, the box steps down just enough to sit under it (still flush
-- against the meter's side), and back up as it shrinks or slides away. Nothing of DaylightUI's is
-- changed or covered. Screen positions are plain numbers, never secret.
local THREAT_GAP = 2
function P.MakeWay()
	local want, wantX = 0, 0
	local dock = suspended and G("dock") == "meters" and DockFrame() or nil
	local threat = _G.DaylightUIThreatMeter
	local clip = dock and type(threat) == "table" and threat.IsVisible and threat:IsVisible() and threat:GetParent()
	if clip and clip.GetRect then
		-- Everything in screen pixels. The threat window's bottom and outer side (not its clip's,
		-- which has room for a shadow), and its clip's sides (how far it has slid out). The box's
		-- spot worked out from the meter, as if it hadn't moved: the same every time.
		local fs, ds = frame:GetEffectiveScale(), dock:GetEffectiveScale()
		local cs, ts = clip:GetEffectiveScale(), threat:GetEffectiveScale()
		local cl, cr = clip:GetLeft(), clip:GetRight()
		local tl, tr, tb = threat:GetLeft(), threat:GetRight(), threat:GetBottom()
		local dl, dr, db = dock:GetLeft(), dock:GetRight(), dock:GetBottom()
		if cl and cr and tl and tr and tb and dl and dr and db and cr > cl then
			cl, cr, tl, tr, tb = cl * cs, cr * cs, tl * ts, tr * ts, tb * ts
			-- What shows of the threat window: inside both its clip and its own edges.
			local vl, vr = math.max(cl, tl), math.min(cr, tr)
			local nx, ny = G("nudgeX") or 0, G("nudgeY") or 0
			local bw, bh = (fullW or 0) * fs, (fullH or 0) * fs
			local left
			if goesLeft then
				left = dl * ds + (nx - DOCK_GAP) * fs - bw
			else
				left = dr * ds + (nx + DOCK_GAP) * fs
			end
			local bottom = db * ds + ny * fs
			if vr > vl and vl < left + bw and vr > left and tb < bottom + bh then
				want = math.ceil((bottom + bh - tb) / fs + THREAT_GAP)
				-- No room below (the meter near the screen's bottom): out beside the threat
				-- window instead, bottoms still level with the meter. That side has room: the
				-- threat meter opened that way.
				if bottom - want * fs < 0 then
					want = 0
					if goesLeft then
						wantX = math.ceil(((left + bw) - vl) / fs + THREAT_GAP)
					else
						wantX = math.ceil((vr - left) / fs + THREAT_GAP)
					end
				end
			end
		end
	end
	if want ~= makeWay or wantX ~= makeWayX then
		makeWay, makeWayX = want, wantX
		local to = suspended and DockFrame()
		if to then PlaceDocked(to) end
	end
end

-- Shows or hides the box (and its tab), docked or free.
-- Placed again (PlaceDocked, ApplySlide, or the free spot) only when something changed: the
-- settings or style (Refresh, P.Style), the box's size (Size), or the frame it docks to (another
-- one, or moved). A plain repaint of the numbers leaves it where it is.
local placedDock, placedX, placedY, placedOn
local function Present(on)
	local dock = DockFrame()
	local docked = dock ~= nil
	dockNow = dock
	Suspend(docked)
	if docked then
		local x, y = dock:GetCenter()
		if dock ~= placedDock or x ~= placedX or y ~= placedY then placeDirty = true end
		placedDock, placedX, placedY = dock, x, y
	elseif placedDock then
		placedDock, placedX, placedY = nil, nil, nil
		placeDirty = true
	end
	if on ~= placedOn then placeDirty = true end
	placedOn = on
	if placeDirty then
		placeDirty = false
		if docked then
			if not tab then BuildTab() end
			PlaceDocked(dock)
			if slideP == nil then slideP = Folded() and 0 or 1 end
			if not slideT then ApplySlide() end
		else
			body:ClearAllPoints()
			body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
			body:SetAlpha(1)
			body:Show()
			frame:SetClipsChildren(false)
			frame:SetSize(fullW, fullH)
		end
		if docked and on then
			tab:SetFrameStrata(frame:GetFrameStrata())
			tab:SetFrameLevel(math.max(0, frame:GetFrameLevel()))
			tab:Show()
		elseif tab then
			tab:Hide()
		end
	end
	shell:SetShown(G("windowless") ~= true)
	frame:SetShown(on)
end

-- ---------------------------------------------------------------------------------------------
-- Colors
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

-- The thicker outline goes on through a font family made from the one the text has: each
-- alphabet keeps the font DaylightUI gave it, so Russian, Korean and Chinese letters still draw. (A
-- plain SetFont would fix the text to the one font file, which shows those letters as boxes.) One
-- family per set of fonts, size and outline, made once a session (the game never frees one).
local ALPHABETS = { "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" }
local thickFamilies, thickCount = {}, 0   -- key -> family, or false when it couldn't be made

-- (Paths may come back with other slashes or case.)
local function SamePath(a, b)
	return type(a) == "string" and type(b) == "string"
		and string.lower((a:gsub("/", "\\"))) == string.lower((b:gsub("/", "\\")))
end

-- nil when the text's font isn't its font object's (a plain SetFont put it there): then the old
-- way, a plain SetFont, keeps that face.
local function ThickFamily(fs, font, size, flags)
	local obj = fs.GetFontObject and fs:GetFontObject()
	if type(CreateFontFamily) ~= "function" or type(obj) ~= "table" or not obj.GetFontObjectForAlphabet then
		return nil
	end
	size = math.floor(size * 4 + 0.5) / 4
	local members, files = {}, {}
	for i, alphabet in ipairs(ALPHABETS) do
		local ok, member = pcall(obj.GetFontObjectForAlphabet, obj, alphabet)
		local file = ok and type(member) == "table" and member.GetFont and member:GetFont()
		if not Safe(file) or type(file) ~= "string" then return nil end
		if alphabet == "roman" and not SamePath(file, font) then return nil end
		members[i] = { alphabet = alphabet, file = file, height = size, flags = flags }
		files[i] = file
	end
	local key = table.concat(files, "|") .. "|" .. size .. "|" .. flags
	local fam = thickFamilies[key]
	if fam ~= nil then return fam or nil end
	thickCount = thickCount + 1
	local ok, made = pcall(CreateFontFamily, "DaylightEssentialsStatsFont" .. thickCount, members)
	thickFamilies[key] = (ok and made) or false
	return ok and made or nil
end

-- The outline one step thicker than the player's (none to thin, thin to thick), so the colored
-- names read on any ground. Checked on every paint: DaylightUI sets the player's font back when
-- it changes.
local function Thicken(fs)
	local font, size, flags = fs:GetFont()
	if not font or not Safe(font) or not Safe(size) or not Safe(flags) then return end
	flags = flags or ""
	if flags:find("THICK") then return end
	local want
	if flags:find("OUTLINE") then
		want = (flags:gsub("OUTLINE", "THICKOUTLINE"))
	else
		want = flags == "" and "OUTLINE" or (flags .. ",OUTLINE")
	end
	local fam = type(size) == "number" and ThickFamily(fs, font, size, want)
	if not fam then
		fs:SetFont(font, size, want)
		return
	end
	-- (A font object resets the text's justification and color: they're handed back. The shadow
	-- is set right after, by Shadow.)
	local justifyH = fs:GetJustifyH()
	local justifyV = fs:GetJustifyV()
	local r, g, b, a = fs:GetTextColor()
	fs:SetFontObject(fam)
	if type(justifyH) == "string" then fs:SetJustifyH(justifyH) end
	if type(justifyV) == "string" then fs:SetJustifyV(justifyV) end
	if type(r) == "number" and Safe(r) then fs:SetTextColor(r, g, b, a) end
end

-- The text shadow the player picked (in px, down and to the right), on every paint as well.
local function Shadow(fs)
	local px = G("shadow") or 1
	local alpha = px > 0 and 1 or 0
	-- Set only when it differs from what the text has now (DaylightUI may set it back on a style
	-- change): reading it costs nothing, setting it every paint did.
	local x, y = fs:GetShadowOffset()
	local _, _, _, a = fs:GetShadowColor()
	if x == px and y == -px and a == alpha then return end
	fs:SetShadowColor(0, 0, 0, alpha)
	fs:SetShadowOffset(px, -px)
end

-- Whether a hit line has enough for the current target (always with the samples).
local function HitEnough(s)
	if not s.cap or G("hitCap") == false then return false end
	local v = previewing and s.sample or lastNum[s.id]
	local need = HitNeed(s.cap)
	if previewing and not need then need = s.cap == "spell" and 4 or 5 end
	return type(v) == "number" and need ~= nil and v + 0.005 >= need
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
			if HitEnough(s) then vHex = Hex("GOOD") end
			if d.how == "live" then
				fmt = fmt .. vHex .. FormatOf(s) .. "|r"
			else
				fmt = fmt .. vHex .. "%s|r"
			end
			args[#args + 1] = d.value
		end
		Thicken(line)
		Shadow(line)
		local ok = pcall(line.SetFormattedText, line, fmt, unpack(args, 1, n))
		if not ok then line:SetText("--") end
		line:Show()
		Size(n, true)
	else
		line:Hide()
		for i = 1, n do
			local d = drawn[i]
			local row = Row(i)
			local c = NameColor(d.stat)
			Thicken(row.label)
			Thicken(row.value)
			Shadow(row.label)
			Shadow(row.value)
			row.label:SetText(d.stat.tag or d.stat.label)
			Ink(row.label, c, "LABEL")
			if d.how == "live" then
				local ok = pcall(row.value.SetFormattedText, row.value, FormatOf(d.stat), d.value)
				if not ok then row.value:SetText("--") end
			else
				row.value:SetText(d.value)
			end
			if HitEnough(d.stat) then
				ns.Ink(row.value, "GOOD")   -- enough hit for the target (its last number, in a fight)
			elseif d.stale and dim then
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

-- A burst of events: paint at once, then once more 0.3 s later if more came meanwhile.
local pending, again = false, false
local function Later()
	pending = false
	if again then
		again = false
		Paint()
	end
end
local function PaintSoon()
	if pending then
		again = true
		return
	end
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
local EVENTS = { "PLAYER_TARGET_CHANGED", "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
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

-- The watch runs by the meters or by the chat with its fade; turned off, the stats are back to
-- full (no chat fade) and in their own spot (no threat meter to make way for).
local function Watching()
	if not watcher then return end
	local to = G("dock")
	local on = G("enabled") == true and (to == "meters" or (to == "chat" and G("chatFade") == true))
	if on then
		watcher:Show()
	elseif watcher:IsShown() then
		watcher:Hide()
		P.MakeWay()
		frame:SetAlpha(1)
	end
end

-- Everything again from the settings.
local function Refresh()
	if not frame then return end
	local on = G("enabled") == true
	previewing = on and ns.Previewing(KEY)
	Listen(on, (G("role") or "auto") == "auto")
	sizedW, placeDirty = nil, true
	Watching()
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
	-- Docked to the chat with "Fade with the chat": as see-through as the chat window is now.
	-- Docked to the damage meters: making way for the threat meter (MakeWay). A small child frame
	-- does it, shown only for those two (Watching), so nothing runs otherwise.
	local fadeWait = 0
	watcher = CreateFrame("Frame", nil, frame)
	watcher:Hide()
	watcher:SetScript("OnUpdate", function(_, dt)
		fadeWait = fadeWait + (dt or 0)
		if fadeWait < 0.03 then return end
		fadeWait = 0
		P.MakeWay()
		local a = 1
		if G("chatFade") and G("dock") == "chat" then
			local chat = _G.DaylightUIChatPanel
			if type(chat) == "table" and chat.GetEffectiveAlpha then
				local ok, v = pcall(chat.GetEffectiveAlpha, chat)
				if ok and Safe(v) and type(v) == "number" then a = v end
			end
		end
		if math.abs(frame:GetAlpha() - a) > 0.01 then frame:SetAlpha(a) end
	end)
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
	ns.me.RegisterMover(frame, KEY, L["Secondary stats"], Home)
	-- Comes up with DaylightUI's fade-in on login and /reload: its window and text layers (the
	-- frame fades with the chat, the box with its slide).
	ns.FadeIn(KEY, function() return { shell, content } end)
	ns.me.RegisterTestPart(KEY, L["Secondary stats"])
end

function P.Login()
	-- (Before 1.1.0's release it could dock to the player and target frames: those go to the minimap.)
	local was = G("dock")
	if was == "player" or was == "target" then
		pcall(ns.DUI.Set, ns.DUI, ns.ADDON, KEY .. ".dock", "minimap")
		ns.Forget()
	end
	Build()
	-- DaylightUI's conversation card (made the first time a conversation opens): followed from its
	-- opening (a hook on DaylightUI's own function, through its API), then by its own show and hide.
	local okMod, chat = pcall(ns.DUI.GetModule, ns.DUI, "Chat")
	local convo = okMod and type(chat) == "table" and type(chat.ns) == "table" and chat.ns.Convo
	if type(convo) == "table" and type(convo.Open) == "function" and ns.me.Hook then
		local watched = false
		local function Follow()
			local card = _G.DaylightUIChatTalk
			if type(card) ~= "table" or not card.HookScript then return end
			if not watched then
				watched = true
				card:HookScript("OnShow", function()
					talking = true
					C_Timer.After(0, Refresh)
				end)
				card:HookScript("OnHide", function()
					talking = false
					C_Timer.After(0, Refresh)
				end)
			end
			local before = talking
			talking = card:IsShown() == true
			if talking ~= before then Refresh() end
		end
		pcall(ns.me.Hook, convo, "Open", Follow)
	end
	-- The meter detached or put back, the chat or the panel shown or hidden: docked again.
	for _, name in ipairs({ "DaylightUIDamageMeter", "DaylightUIChatPanel", "DaylightUIInfoPanelBody" }) do
		local f = _G[name]
		if type(f) == "table" and f.HookScript then
			f:HookScript("OnShow", function() C_Timer.After(0, Refresh) end)
			f:HookScript("OnHide", function() C_Timer.After(0, Refresh) end)
		end
	end
	Refresh()
end

function P.Setting()
	Refresh()
end

function P.Style()
	if not frame then return end
	classColor = nil
	wipe(hexOf)
	sizedW, placeDirty = nil, true
	if tab then
		API.Skin(tab, { borderPx = 3 })   -- (as BuildTab made it)
		PaintGrip(false)
	end
	Paint()
end

function P.Preview()
	Refresh()
end
