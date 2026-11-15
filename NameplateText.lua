-- Nameplate Text: the numbers of a fight pop off the enemies' nameplates (in the spirit of the
-- Nameplate Scrolling Combat Text addon), in DaylightUI's font, colored by the hit's school, crits
-- bigger, and quieter on enemies you aren't targeting. Misses, dodges and parries show their word.
--
-- Where the hits come from: this client gives addons no combat log, so the numbers can't come from
-- it the way Nameplate SCT's do. The game still reports each hit on a unit it shows (UNIT_COMBAT,
-- for every nameplate): what happened (a hit, a miss...), a crit or not, and the school, all
-- readable; the amount is secret, so it's only handed whole to the game's own number formatting
-- and to a font string, never read. That report doesn't say who struck: in a group, everyone's
-- hits on a mob show on its plate, not only yours ("Your target only" keeps it to one plate).
--
-- Turn Off DaylightUI's Combat Text (on to start): while Nameplate Dmg Text is on, all of
-- DaylightUI's combat text is off: the game's own damage numbers (the ones DaylightUI's Damage
-- numbers page styles) and pet numbers, so each hit isn't shown twice, and DaylightUI's scrolling
-- combat text around your character (its "Show combat text", overridden through DaylightUI's
-- plugin API: ns.me.Override, put back with API.Off, and by DaylightUI itself at logout). The
-- game's switches are kept and given back as they were when Nameplate Dmg Text or this is off;
-- changing DaylightUI's switch yourself ends the override.
--
-- Seeing and placing it: its options page has a live preview at the top, the way DaylightUI's own
-- nameplate pages do (DaylightUI's sample strip): a training dummy's nameplate in DaylightUI's
-- look with numbers coming off it from the current settings, redrawn as they change. Click a
-- piece to jump to its settings; in Design mode drag "Where the numbers start" (or select it and
-- nudge it with the arrow keys) to set the Sideways and Height spot over every plate.
--
-- What it costs: one check per hit on a shown plate while it's on; a light update each frame only
-- while numbers are in the air.

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "plateText"
local G = ns.Reader(KEY)

local P = ns.Part({ key = KEY, label = L["Nameplate Dmg Text"] })

P.defaults = {
	enabled = false,
	replace = true,
	plates = "all",
	font = "general",
	size = 20,
	critScale = 1.5,
	offTarget = true,
	offScale = 0.75,
	offAlpha = 0.5,
	anim = "fountain",
	critAnim = "up",
	missAnim = "up",
	misses = true,
	schools = true,
	numbers = "short",
	speed = 1,
	x = 0,
	height = 20,
}

local function Off(get) return get(KEY .. ".enabled") ~= true end

local ANIMS = { up = L["Rise"], down = L["Fall"], fountain = L["Fountain"], rain = L["Rainfall"] }
local ANIM_ORDER = { "fountain", "up", "down", "rain" }

local fontRow
if API.FontRow then
	local ok, row = pcall(API.FontRow, KEY .. ".font", L["Font"], L["The font of the numbers."])
	if ok and type(row) == "table" then
		fontRow = row
		fontRow.disabled = Off
	end
end

local looks = {
	{ type = "slider", key = KEY .. ".size", label = L["Text size"], min = 10, max = 40, step = 1, disabled = Off },
	{ type = "slider", key = KEY .. ".critScale", label = L["Crit size"], min = 1, max = 2.5, step = 0.05, unit = "%",
	  disabled = Off, desc = L["How much bigger a critical hit is."] },
	{ type = "toggle", key = KEY .. ".schools", label = L["Color By Element"], disabled = Off,
	  desc = L["Fire orange, frost blue, nature green, shadow violet... Off: DaylightUI's value ink."] },
	{ type = "dropdown", key = KEY .. ".numbers", label = L["Numbers"], disabled = Off,
	  values = { short = L["Short (1.2K)"], full = L["Full (1,234)"] }, order = { "short", "full" } },
}
if fontRow then table.insert(looks, 1, fontRow) end

P.page = { id = KEY, label = L["Nameplate Dmg Text"],
	desc = L["Damage numbers that pop off enemy nameplates."],
	groups = {
		{ label = L["Nameplate Dmg Text"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"],
			  desc = L["Numbers over enemy nameplates as they're hit. The game doesn't tell addons who struck, so in a group everyone's hits show. Keep enemy nameplates shown."] },
			{ type = "toggle", key = KEY .. ".replace", label = L["Turn Off DaylightUI's Combat Text"], disabled = Off,
			  desc = L["While this is on, all of DaylightUI's combat text is off: the damage numbers (its Damage numbers page) and its scrolling combat text around your character. They come back as they were when this is off."] },
			{ type = "dropdown", key = KEY .. ".plates", label = L["Show On"], disabled = Off,
			  values = { all = L["Every enemy nameplate"], target = L["Your target only"] }, order = { "all", "target" } },
			{ type = "toggle", key = KEY .. ".misses", label = L["Show Misses, Dodges, and Parries"], disabled = Off },
		} },
		{ label = L["Look"], items = looks },
		{ label = L["Motion"], items = {
			{ type = "dropdown", key = KEY .. ".anim", label = L["Hits"], values = ANIMS, order = ANIM_ORDER, disabled = Off },
			{ type = "dropdown", key = KEY .. ".critAnim", label = L["Crits"], values = ANIMS, order = ANIM_ORDER, disabled = Off },
			{ type = "dropdown", key = KEY .. ".missAnim", label = L["Misses"], values = ANIMS, order = ANIM_ORDER, disabled = Off },
			{ type = "slider", key = KEY .. ".speed", label = L["Display Time"], min = 0.5, max = 2, step = 0.1, disabled = Off,
			  desc = L["How many seconds each number stays on screen."] },
			{ type = "slider", key = KEY .. ".x", label = L["Horizontal Shift"], min = -80, max = 80, step = 1, unit = "px", disabled = Off,
			  desc = L["Or drag it in the preview above, in Design mode."] },
			{ type = "slider", key = KEY .. ".height", label = L["Vertical Shift"], min = -40, max = 80, step = 1, unit = "px", disabled = Off,
			  desc = L["Or drag it in the preview above, in Design mode."] },
		} },
		{ label = L["Other enemies"], items = {
			{ type = "toggle", key = KEY .. ".offTarget", label = L["Display on Off Targets"], disabled = Off,
			  desc = L["Numbers on enemies you aren't targeting are smaller and fainter."] },
			{ type = "slider", key = KEY .. ".offScale", label = L["Size"], min = 0.4, max = 1, step = 0.05, unit = "%",
			  disabled = function(get) return Off(get) or get(KEY .. ".offTarget") == false end },
			{ type = "slider", key = KEY .. ".offAlpha", label = L["Opacity"], min = 0.1, max = 1, step = 0.05, unit = "%",
			  disabled = function(get) return Off(get) or get(KEY .. ".offTarget") == false end },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- Reading the hits
-- ---------------------------------------------------------------------------------------------

local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- The school colors (by UNIT_COMBAT's school mask bit), lightened to read over any plate.
local SCHOOLS = {
	[1] = { 1, 0.9, 0.45 },     -- physical
	[2] = { 1, 0.93, 0.6 },     -- holy
	[4] = { 1, 0.56, 0.2 },     -- fire
	[8] = { 0.45, 1, 0.45 },    -- nature
	[16] = { 0.5, 0.95, 1 },    -- frost
	[32] = { 0.65, 0.6, 1 },    -- shadow
	[64] = { 1, 0.55, 1 },      -- arcane
}
local SCHOOL_ORDER = { 64, 32, 16, 8, 4, 2, 1 }   -- (a mixed school takes its magic part)

local function SchoolColor(mask)
	if type(mask) ~= "number" or Secret(mask) then return nil end
	for _, b in ipairs(SCHOOL_ORDER) do
		if bit.band(mask, b) ~= 0 then return SCHOOLS[b] end
	end
	return nil
end

-- What UNIT_COMBAT calls a hit that dealt nothing, and the game's word for it.
local AVOIDED = { MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true, IMMUNE = true,
	EVADE = true, ABSORB = true, DEFLECT = true, REFLECT = true }
local function AvoidWord(action)
	local w = _G["COMBAT_TEXT_" .. action] or _G[action]
	if type(w) == "string" and w ~= "" then return w end
	return ns.UpperFirst(action:lower())
end

-- A secret amount, as the game writes numbers (kept secret: it's only ever shown).
local function Amount(v)
	if G("numbers") == "full" then
		if BreakUpLargeNumbers then return BreakUpLargeNumbers(v) end
	elseif AbbreviateNumbers then
		return AbbreviateNumbers(v)
	end
	return v
end

local function Is(unit, other)
	local ok, same = pcall(UnitIsUnit, unit, other)
	if not ok or Secret(same) then return nil end
	return same
end

local function Hostile(unit)
	local ok, can = pcall(UnitCanAttack, "player", unit)
	if not ok or Secret(can) then return true end   -- (can't tell: the plate is shown, so show it)
	return can
end

-- The nameplate a unit's numbers ride on (never a forbidden one).
local function Plate(unit)
	if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if not ok or type(plate) ~= "table" or (plate.IsForbidden and plate:IsForbidden()) then return nil end
	return plate
end

-- ---------------------------------------------------------------------------------------------
-- The numbers in the air
-- ---------------------------------------------------------------------------------------------

-- A stage: where numbers are drawn (its frame holds their texts) and the ones in the air on it.
-- One for the real plates (over the whole screen), one for the options page's preview.
local function NewStage(frame)
	return { frame = frame, live = {}, spare = {} }
end

local world            -- the real plates' stage
local MAX_LIVE = 40
local look = {}

local function ReadLook()
	look.file = API.FontFile and API.FontFile(G("font") or "general") or API.Font()
	look.size = G("size") or 20
	look.crit = math.floor(look.size * (G("critScale") or 1.5) + 0.5)
	look.life = G("speed") or 1
	look.x = G("x") or 0
	look.height = G("height") or 20
	look.off = G("offTarget") ~= false
	look.offScale = G("offScale") or 0.75
	look.offAlpha = G("offAlpha") or 0.5
	look.schools = G("schools") ~= false
	look.ink = ns.Colors().VALUE or { 1, 1, 1 }
end

local function Font(fs, size)
	size = math.max(6, math.floor(size + 0.5))
	if fs.daylightFile ~= look.file or fs.daylightSize ~= size then
		if not fs:SetFont(look.file, size, "OUTLINE") then fs:SetFont(API.Font(), size, "OUTLINE") end
		fs.daylightFile, fs.daylightSize = look.file, size
	end
end

-- Where a number is t seconds in (0 to 1 of its life), from where it started.
local function Motion(n, p)
	local kind = n.anim
	if kind == "up" then
		return n.x0, 60 * (1 - (1 - p) * (1 - p))
	elseif kind == "down" then
		return n.x0, -60 * p * p
	elseif kind == "rain" then
		return n.x0 + n.dir * 40 * p, -10 - 70 * p * p
	end
	-- fountain: out to the side in an arc, then down
	return n.x0 + n.dir * n.side * p, n.peak * 4 * p * (1 - p) - 20 * p * p
end

local function Drop(stage, i)
	local n = stage.live[i]
	n.fs:Hide()
	n.fs:ClearAllPoints()
	table.remove(stage.live, i)
	n.plate, n.unit = nil, nil
	stage.spare[#stage.spare + 1] = n
end

local function DropAll(stage)
	for i = #stage.live, 1, -1 do Drop(stage, i) end
end

-- Moves every number on a stage on by dt seconds. (The start spot is the plate's middle plus
-- Sideways and Height, on a real plate and on the preview's alike.)
local function Step(stage, dt)
	local live = stage.live
	for i = #live, 1, -1 do
		local n = live[i]
		n.t = n.t + dt
		local p = n.t / n.life
		if p >= 1 or not n.plate:IsVisible() then
			Drop(stage, i)
		else
			local x, y = Motion(n, p)
			n.fs:ClearAllPoints()
			n.fs:SetPoint("CENTER", n.plate, "CENTER", x + look.x, y + look.height)
			-- A crit pops: bigger for its first sixth, then its own size.
			if n.pop and n.fs.SetTextScale then
				local q = p * 6
				n.fs:SetTextScale(q < 1 and (1 + 0.5 * math.sin(q * math.pi)) or 1)
			end
			local fade = p > 0.6 and (1 - p) / 0.4 or 1
			n.fs:SetAlpha(n.alpha * fade)
		end
	end
end

local function WorldStep(_, dt)
	Step(world, dt)
	if #world.live == 0 then world.frame:SetScript("OnUpdate", nil) end
end

-- A number (or word) on a plate. value: secret or plain, only shown.
local function Spawn(stage, plate, unit, value, color, crit, anim, quiet)
	local live = stage.live
	if #live >= MAX_LIVE then Drop(stage, 1) end
	local n = table.remove(stage.spare)
	if not n then
		n = { fs = stage.frame:CreateFontString(nil, "OVERLAY") }
	end
	local fs = n.fs
	local scale = quiet and look.offScale or 1
	Font(fs, (crit and look.crit or look.size) * scale)
	if fs.SetTextScale then fs:SetTextScale(1) end
	fs:SetText(value)
	fs:SetTextColor(color[1], color[2], color[3])
	n.plate, n.unit = plate, unit
	n.t, n.life = 0, look.life
	n.anim = anim
	n.pop = crit
	n.alpha = quiet and look.offAlpha or 1
	n.dir = math.random() < 0.5 and -1 or 1
	n.x0 = (math.random() * 2 - 1) * 8
	n.side = 40 + math.random() * 50
	n.peak = 25 + math.random() * 25
	fs:SetAlpha(0)
	fs:Show()
	live[#live + 1] = n
	if stage == world then world.frame:SetScript("OnUpdate", WorldStep) end
end

local function OnCombat(unit, action, flag, amount, school)
	if Secret(unit) or type(unit) ~= "string" or unit:sub(1, 9) ~= "nameplate" then return end
	if Secret(action) or type(action) ~= "string" then return end
	local avoided = AVOIDED[action]
	if action ~= "WOUND" and not avoided then return end
	if avoided and G("misses") == false then return end
	if Is(unit, "player") or not Hostile(unit) then return end
	local isTarget = Is(unit, "target")
	if G("plates") == "target" and isTarget ~= true then return end
	local plate = Plate(unit)
	if not plate then return end
	local quiet = look.off and isTarget == false
	if avoided then
		Spawn(world, plate, unit, AvoidWord(action), look.ink, false, G("missAnim") or "up", quiet)
		return
	end
	if type(amount) == "nil" then return end
	local crit = not Secret(flag) and flag == "CRITICAL"
	local color = look.schools and SchoolColor(school) or look.ink
	Spawn(world, plate, unit, Amount(amount), color, crit, crit and (G("critAnim") or "up") or (G("anim") or "fountain"), quiet)
end

-- A plate going away takes its numbers with it (its frame is handed to the next unit).
local function OnPlateGone(unit)
	for i = #world.live, 1, -1 do
		if world.live[i].unit == unit then Drop(world, i) end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Replacing the game's (DaylightUI's) damage numbers
-- ---------------------------------------------------------------------------------------------
-- The game's switches, saved as they were before we turned them off
-- (DaylightEssentialsDB.plateTextCVars[name] = "1"), given back when we stop.
local GAME_NUMBERS = { "floatingCombatTextCombatDamage_v2", "floatingCombatTextPetMeleeDamage_v2",
	"floatingCombatTextPetSpellDamage_v2" }

local function Saved()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	db.plateTextCVars = type(db.plateTextCVars) == "table" and db.plateTextCVars or {}
	return db.plateTextCVars
end

local waiting = false
local sctOff      -- DaylightUI's override handle while its scrolling combat text is held off

local function ApplyReplace()
	if InCombatLockdown() then
		waiting = true   -- (set once the fight ends)
		return
	end
	waiting = false
	local saved = Saved()
	local want = G("enabled") == true and G("replace") ~= false
	for _, name in ipairs(GAME_NUMBERS) do
		local ok, now = pcall(C_CVar.GetCVar, name)
		if ok and now ~= nil then
			if want then
				if saved[name] == nil then saved[name] = now end
				if now ~= "0" then pcall(C_CVar.SetCVar, name, "0") end
			elseif saved[name] ~= nil then
				if now ~= saved[name] then pcall(C_CVar.SetCVar, name, saved[name]) end
				saved[name] = nil
			end
		end
	end
	-- DaylightUI's own scrolling combat text (its "Show combat text").
	if want and not sctOff then
		local ok, handle = pcall(ns.me.Override, "general", "sct.enabled", false)
		sctOff = ok and handle or nil
	elseif not want and sctOff then
		pcall(API.Off, sctOff)
		sctOff = nil
	end
end

-- ---------------------------------------------------------------------------------------------
-- The preview at the top of the options page (DaylightUI's sample strip)
-- ---------------------------------------------------------------------------------------------
-- A sample, as the strip asks for one: s.frame; s.Refresh(width, maxHeight) -> height used;
-- s.Parts() -> { { region, label, keys, move }, ... }, a hotspot over each piece (click: jump to its
-- settings). move (Design mode): owner (the frame its dots are measured in, px from its top left,
-- y down), dots, drop(x, y) -> spot, x, y, and the settings xKey / yKey a drop writes. The single
-- dot is the plate's middle: a drop there is Sideways 0, Height 0.
local SAMPLE_SCHOOLS = { 1, 1, 4, 16, 8, 32, 64, 2 }
local SAMPLE_EVERY = 0.45      -- s between sample numbers
local PLATE_W, PLATE_H = 150, 12
local SAMPLE_HEIGHT = 200      -- room for numbers to fly; the strip may give less

local function NewSample(parent)
	local s = {}
	local f = CreateFrame("Frame", nil, parent)
	s.frame = f
	if f.SetClipsChildren then f:SetClipsChildren(true) end
	local stage = NewStage(f)
	local n, clock = 0, 0

	-- The dummy's plate: its name over a health bar, in DaylightUI's look.
	local plate = CreateFrame("Frame", nil, f)
	plate:SetSize(PLATE_W, PLATE_H)
	local bar = API.Bar(plate)
	bar:SetAllPoints(plate)
	if bar.SetMinMaxValues then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0.72)
	end
	if bar.SetStatusBarColor then bar:SetStatusBarColor(0.85, 0.28, 0.22) end
	local name = API.Text(plate, "small", "CENTER")
	name:SetPoint("BOTTOM", plate, "TOP", 0, 3)
	name:SetText(L["Training Dummy"])
	-- Where the numbers start: a still number, the piece Design mode drags.
	local start = f:CreateFontString(nil, "OVERLAY")

	local function Look()
		ReadLook()
		ns.Ink(name, "TEXT")
		Font(start, look.size)
		start:SetText((AbbreviateNumbers or tostring)(1234))
		local c = look.schools and SCHOOLS[1] or look.ink
		start:SetTextColor(c[1], c[2], c[3])
		start:SetAlpha(0.35)
		start:ClearAllPoints()
		start:SetPoint("CENTER", plate, "CENTER", look.x, look.height)
	end

	local function SpawnOne()
		n = n + 1
		local crit = n % 4 == 0
		local quiet = look.off and n % 5 == 0       -- now and then as an enemy you aren't targeting
		if n % 7 == 0 and G("misses") ~= false then
			Spawn(stage, plate, nil, AvoidWord("DODGE"), look.ink, false, G("missAnim") or "up", quiet)
			return
		end
		local value = crit and math.random(1800, 3200) or math.random(300, 1200)
		local text = (G("numbers") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or tostring)(value)
		local color = look.schools and SCHOOLS[SAMPLE_SCHOOLS[n % #SAMPLE_SCHOOLS + 1]] or look.ink
		Spawn(stage, plate, nil, text, color, crit, crit and (G("critAnim") or "up") or (G("anim") or "fountain"), quiet)
	end

	-- (Runs only while the page shows: OnUpdate stops with the frame.)
	f:SetScript("OnUpdate", function(_, dt)
		clock = clock + dt
		if clock >= SAMPLE_EVERY then
			clock = 0
			SpawnOne()
		end
		Step(stage, dt)
	end)
	f:SetScript("OnShow", Look)
	f:SetScript("OnHide", function() DropAll(stage) end)

	function s.Refresh(width, maxHeight)
		Look()
		local h = math.min(SAMPLE_HEIGHT, maxHeight or SAMPLE_HEIGHT)
		f:SetSize(width, h)
		plate:ClearAllPoints()
		-- Low in the box, so numbers have room to rise over it.
		plate:SetPoint("BOTTOM", f, "BOTTOM", 0, math.floor(h * 0.3))
		return h
	end

	function s.Parts()
		local home = { spot = "home", x = PLATE_W / 2, y = PLATE_H / 2 }
		local dots = { home }
		return {
			{ region = plate, label = L["Nameplate Dmg Text"],
			  keys = { KEY .. ".enabled", KEY .. ".plates", KEY .. ".misses", KEY .. ".offTarget" } },
			{ region = start, label = L["Where the numbers start"],
			  keys = { KEY .. ".x", KEY .. ".height", KEY .. ".anim", KEY .. ".critAnim", KEY .. ".missAnim",
			           KEY .. ".speed", KEY .. ".size", KEY .. ".critScale", KEY .. ".schools", KEY .. ".numbers" },
			  move = { owner = plate, dots = dots, xKey = KEY .. ".x", yKey = KEY .. ".height",
			           drop = function(x, y)
			               return "home", math.floor(x - home.x + 0.5), math.floor(home.y - y + 0.5)
			           end } },
		}
	end

	Look()
	return s
end

P.page.sample = function(parent) return NewSample(parent) end

-- ---------------------------------------------------------------------------------------------
-- Start, settings
-- ---------------------------------------------------------------------------------------------

local events

local function Listen()
	if G("enabled") == true then
		events:RegisterEvent("UNIT_COMBAT")
		events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	else
		events:UnregisterEvent("UNIT_COMBAT")
		events:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
		DropAll(world)
	end
end

function P.Login()
	local holder = CreateFrame("Frame", "DaylightEssentialsNameplateText", UIParent)
	holder:SetAllPoints(UIParent)
	holder:SetFrameStrata("HIGH")
	world = NewStage(holder)
	ReadLook()
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", function(_, event, a, b, c, d, e)
		if event == "UNIT_COMBAT" then
			OnCombat(a, b, c, d, e)
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			if not Secret(a) then OnPlateGone(a) end
		elseif event == "PLAYER_REGEN_ENABLED" then
			if waiting then ApplyReplace() end
		end
	end)
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	Listen()
	ApplyReplace()
end

function P.Setting()
	if not world then return end
	ReadLook()
	Listen()
	ApplyReplace()
end

function P.Style()
	if world then ReadLook() end
end
