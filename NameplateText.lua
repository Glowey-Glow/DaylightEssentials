-- Nameplate Text: the numbers of a fight pop off the enemies' nameplates (in the spirit of the
-- Nameplate Scrolling Combat Text addon), in DaylightUI's font, colored by the hit's school, crits
-- bigger, and quieter on enemies you aren't targeting. Misses, dodges and parries show their word.
--
-- Where the hits come from: this client gives addons no combat log, so the numbers can't come from
-- it the way Nameplate SCT's do. The game still reports each hit on a unit it shows (UNIT_COMBAT,
-- for every nameplate): what happened (a hit, a miss...), a crit or not, and the school, all
-- readable; the amount is secret, so it's only handed whole to the game's own number formatting
-- and to a font string, never read. That report doesn't say who struck, and the combat log (which
-- would) is closed to addons here (COMBAT_LOG_EVENT_UNFILTERED is restricted in the Forever API).
-- Alone, the hits on a hostile plate are yours and your pet's. In a group they'd be everyone's, so
-- there "In a Group: the Game's Numbers" (on to start) pauses ours and turns the game's own damage
-- numbers on: the game draws only yours and your pet's, which no addon here can tell apart.
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
-- piece to jump to its settings; in Design mode drag "Where the Numbers Start" (or select it and
-- nudge it with the arrow keys) to set the Sideways and Height spot over every plate.
--
-- Spell icons: the hit report doesn't name the spell either, so the icon beside a number is worked
-- out from your own and your pet's casts (UNIT_SPELLCAST_SUCCEEDED, whose spell the game does tell
-- for those two). A cast at a plate waits up to 1.5 s for its hit (travel time); a cast with no
-- enemy targeted (an area spell) takes the first hit on each plate in the next 0.4 s. The first hit
-- of a spell teaches its school, so a later cast only takes a hit of that school. A hit nothing
-- claims takes the last damage over time spell of yours of its school that hit that plate in the
-- past 20 s (a tick; direct hits never stand in, or your pet's hits took their icon), else your
-- pet's last spell of that school in the past 12 s (pet out), except physical ones: those are melee, shown with your main-hand weapon's icon (no
-- icon while your pet is out: its swings and yours can't be told apart). So it's a good guess, not
-- a record: casts that overlap, or a spell that applies a bleed and deals nothing at first, can put
-- the wrong icon on a hit now and then. Misses show an icon only when a cast claims them.
--
-- What it costs: one check per hit on a shown plate while it's on; a light update each frame only
-- while numbers are in the air; with icons on, a few table lookups per cast and per hit.

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
	groupGame = true,
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
	icons = "left",
	iconScale = 0.9,
	anchor = "above",       -- hits' start (Numbers Start before each kind had its own)
	critAnchor = "above",
	missAnchor = "above",
	selfDamage = true,          -- damage taken and healing received, on you (On You)
	selfHeal = true,
	selfDamageAt = "left",
	selfHealAt = "right",
	selfAnim = "up",
	selfSize = 18,
	selfX = 200,
	selfY = -40,
	selfSigns = true,
	numbers = "short",
	speed = 1,
	x = 0,
	height = 20,
}

local function Off(get) return get(KEY .. ".enabled") ~= true end

local ANIMS = { up = L["Rise"], down = L["Fall"], fountain = L["Fountain"], rain = L["Rainfall"] }
local ANIM_ORDER = { "fountain", "up", "down", "rain" }
local ANCHORS = { above = L["Above Plate"], below = L["Below Plate"], left = L["Plate's Left"], right = L["Plate's Right"] }
local ANCHOR_ORDER = { "above", "below", "left", "right" }

local fontRow
if API.FontRow then
	local ok, row = pcall(API.FontRow, KEY .. ".font", L["Font"], L["The font of the numbers."])
	if ok and type(row) == "table" then
		fontRow = row
		fontRow.disabled = Off
	end
end

local SPOTS = { player = L["Player Frame"], left = L["Left of Center"], right = L["Right of Center"] }
local SPOT_ORDER = { "player", "left", "right" }
local function SelfOff(get)
	return Off(get) or (get(KEY .. ".selfDamage") == false and get(KEY .. ".selfHeal") == false)
end
local SELF_ITEMS = {
	{ type = "toggle", key = KEY .. ".selfDamage", label = L["Damage Taken"], disabled = Off,
	  desc = L["Hits on you, and your dodges, parries and other misses. Shows in a group too."] },
	{ type = "dropdown", key = KEY .. ".selfDamageAt", label = L["Where Damage Shows"], values = SPOTS, order = SPOT_ORDER,
	  disabled = function(get) return Off(get) or get(KEY .. ".selfDamage") == false end },
	{ type = "toggle", key = KEY .. ".selfHeal", label = L["Healing Received"], disabled = Off,
	  desc = L["Heals on you, in green. Shows in a group too."] },
	{ type = "dropdown", key = KEY .. ".selfHealAt", label = L["Where Healing Shows"], values = SPOTS, order = SPOT_ORDER,
	  disabled = function(get) return Off(get) or get(KEY .. ".selfHeal") == false end },
	{ type = "dropdown", key = KEY .. ".selfAnim", label = L["Motion"], values = ANIMS, order = ANIM_ORDER, disabled = SelfOff },
	{ type = "toggle", key = KEY .. ".selfSigns", label = L["Show + and -"], disabled = SelfOff,
	  desc = L["A minus before damage taken and a plus before healing."] },
	{ type = "slider", key = KEY .. ".selfSize", label = L["Text Size"], min = 10, max = 40, step = 1, disabled = SelfOff },
	{ type = "slider", key = KEY .. ".selfX", label = L["Distance From Center"], min = 40, max = 600, step = 5, unit = "px",
	  disabled = SelfOff, desc = L["How far the left and right spots are from the middle of the screen."] },
	{ type = "slider", key = KEY .. ".selfY", label = L["Vertical Shift"], min = -300, max = 300, step = 5, unit = "px",
	  disabled = SelfOff, desc = L["Up or down from the middle of the screen, for the left and right spots."] },
}

local looks = {
	{ type = "slider", key = KEY .. ".size", label = L["Text Size"], min = 10, max = 40, step = 1, disabled = Off },
	{ type = "slider", key = KEY .. ".critScale", label = L["Crit Size"], min = 1, max = 2.5, step = 0.05, unit = "%",
	  disabled = Off, desc = L["How much bigger a critical hit is."] },
	{ type = "toggle", key = KEY .. ".schools", label = L["Color by Element"], disabled = Off,
	  desc = L["Fire orange, frost blue, nature green, shadow violet... Off: Daylight UI's value ink."] },
	{ type = "dropdown", key = KEY .. ".icons", label = L["Spell Icons"], disabled = Off,
	  values = { left = L["Left of Number"], right = L["Right of Number"], off = L["Off"] },
	  order = { "left", "right", "off" },
	  desc = L["The spell behind each hit, worked out from your own and your pet's casts: now and then a guess."] },
	{ type = "slider", key = KEY .. ".iconScale", label = L["Spell Icon Size"], min = 0.5, max = 2, step = 0.05, unit = "%",
	  disabled = function(get) return Off(get) or get(KEY .. ".icons") == "off" end,
	  desc = L["Measured against the number's size, and bigger on crits too."] },
	{ type = "dropdown", key = KEY .. ".numbers", label = L["Numbers"], disabled = Off,
	  values = { short = L["Short (1.2K)"], full = L["Full (1,234)"] }, order = { "short", "full" } },
}
if fontRow then table.insert(looks, 1, fontRow) end

P.page = { id = KEY, label = L["Nameplate Dmg Text"],
	desc = L["Damage numbers that pop off enemy nameplates."],
	groups = {
		{ label = L["Nameplate Dmg Text"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"],
			  desc = L["Numbers over enemy nameplates as they're hit: yours and your pet's while you're alone. Keep enemy nameplates shown."] },
			{ type = "toggle", key = KEY .. ".groupGame", label = L["In a Group: the Game's Numbers"], disabled = Off,
			  desc = L["The game doesn't tell addons who struck a hit, so in a party or raid the nameplates would show everyone's. On: in a group these pause and the game's own damage numbers show instead, which are only yours and your pet's. Off: everyone's hits show."] },
			{ type = "toggle", key = KEY .. ".replace", label = L["Turn Off Daylight UI's Combat Text"], disabled = Off,
			  desc = L["While this is on, all of Daylight UI's combat text is off: the damage numbers (its Damage numbers page) and its scrolling combat text around your character. They come back as they were when this is off."] },
			{ type = "dropdown", key = KEY .. ".plates", label = L["Show On"], disabled = Off,
			  values = { all = L["Every Enemy Nameplate"], target = L["Your Target Only"] }, order = { "all", "target" } },
			{ type = "toggle", key = KEY .. ".misses", label = L["Show Misses, Dodges, and Parries"], disabled = Off },
		} },
		{ label = L["Look"], items = looks },
		{ label = L["Motion"], items = {
			{ type = "dropdown", key = KEY .. ".anim", label = L["Hits"], values = ANIMS, order = ANIM_ORDER, disabled = Off },
			{ type = "dropdown", key = KEY .. ".anchor", label = L["Hits Start"], values = ANCHORS, order = ANCHOR_ORDER,
			  disabled = Off, desc = L["Where around the nameplate the numbers start. The shifts below move them out from there."] },
			{ type = "dropdown", key = KEY .. ".critAnim", label = L["Crits"], values = ANIMS, order = ANIM_ORDER, disabled = Off },
			{ type = "dropdown", key = KEY .. ".critAnchor", label = L["Crits Start"], values = ANCHORS, order = ANCHOR_ORDER,
			  disabled = Off, desc = L["Where around the nameplate the numbers start. The shifts below move them out from there."] },
			{ type = "dropdown", key = KEY .. ".missAnim", label = L["Misses"], values = ANIMS, order = ANIM_ORDER, disabled = Off },
			{ type = "dropdown", key = KEY .. ".missAnchor", label = L["Misses Start"], values = ANCHORS, order = ANCHOR_ORDER,
			  disabled = Off, desc = L["Where around the nameplate the numbers start. The shifts below move them out from there."] },
			{ type = "slider", key = KEY .. ".speed", label = L["Display Time"], min = 0.5, max = 2, step = 0.1, disabled = Off,
			  desc = L["How many seconds each number stays on screen."] },
			{ type = "slider", key = KEY .. ".x", label = L["Horizontal Shift"], min = -80, max = 80, step = 1, unit = "px", disabled = Off,
			  desc = L["Or drag it in the preview above, in Design mode."] },
			{ type = "slider", key = KEY .. ".height", label = L["Vertical Shift"], min = -40, max = 80, step = 1, unit = "px", disabled = Off,
			  desc = L["Or drag it in the preview above, in Design mode."] },
		} },
		{ label = L["Other Enemies"], items = {
			{ type = "toggle", key = KEY .. ".offTarget", label = L["Display on Off Targets"], disabled = Off,
			  desc = L["Numbers on enemies you aren't targeting are smaller and fainter."] },
			{ type = "slider", key = KEY .. ".offScale", label = L["Size"], min = 0.4, max = 1, step = 0.05, unit = "%",
			  disabled = function(get) return Off(get) or get(KEY .. ".offTarget") == false end },
			{ type = "slider", key = KEY .. ".offAlpha", label = L["Opacity"], min = 0.1, max = 1, step = 0.05, unit = "%",
			  disabled = function(get) return Off(get) or get(KEY .. ".offTarget") == false end },
		} },
		{ label = L["On You"], items = SELF_ITEMS },
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
-- Which spell landed a hit (see the top: worked out from your own and your pet's casts)
-- ---------------------------------------------------------------------------------------------

local CAST_WAIT, AREA_WAIT, TICK_WAIT = 1.5, 0.4, 20
local MAX_CASTS = 16
local casts = {}                                         -- oldest first: { tex, id, t, plate, used }
local schoolOf = {}                                      -- [spellID] = the school mask its hits had
local lastHit = setmetatable({}, { __mode = "k" })       -- [plate] = { [school] = { tex, t } }: your DoTs
local petLast = {}                                       -- [school] = { tex, t }: your pet's spells
local PET_WAIT = 12        -- a pet's spell of a school stands for its unclaimed hits this long (autocasts repeat)
local periodic = {}        -- [spellID] = true/false: deals damage over time (its description says so)

-- Whether a spell deals damage over time, from its description: Daylight UI's DoT tracker reads it
-- in every language it knows (DaylightUI.Dots.Parse, guarded), else the English wording. Only those
-- stand for a later hit nothing claims (a tick); a direct hit never does, or your pet's hits of the
-- same school took your last spell's icon.
local function Periodic(spellID)
	if type(spellID) ~= "number" then return false end
	local v = periodic[spellID]
	if v ~= nil then return v end
	v = false
	local getDesc = C_Spell and C_Spell.GetSpellDescription
	local ok, desc = pcall(getDesc, spellID)
	if ok and type(desc) == "string" and not Secret(desc) and desc ~= "" then
		local D = _G.DaylightUI and _G.DaylightUI.Dots
		if type(D) == "table" and type(D.Parse) == "function" then
			local okP, total = pcall(D.Parse, desc)
			v = okP and type(total) == "number" and total > 0 or false
		end
		if not v then
			v = desc:find("damage over %d") ~= nil or desc:find("damage every %d") ~= nil
		end
	end
	-- (A description not loaded yet reads empty: asked again next time instead of kept as "no".)
	if ok and type(desc) == "string" and not Secret(desc) and desc ~= "" then periodic[spellID] = v end
	return v
end

local function Texture(spellID)
	local get = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
	if not get then return nil end
	local ok, tex = pcall(get, spellID)
	if ok then return tex end
	return nil
end

-- A plain yes or no from a spell question, nil when it can't be read.
local function Ask(fn, spellID)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, spellID)
	if not ok or Secret(v) then return nil end
	return v
end

local function OnCast(unit, spellID)
	if spellID == nil then return end
	local readable = not Secret(spellID)
	if readable then
		if type(spellID) ~= "number" then return end
		local S = C_Spell or {}
		if Ask(S.IsSpellPassive or IsPassiveSpell, spellID) == true then return end
		if Ask(S.IsSpellHarmful or IsHarmfulSpell, spellID) == false then return end
	end
	local tex = Texture(spellID)
	if tex == nil then return end
	local at = unit == "pet" and "pettarget" or "target"
	local plate = Plate(at)
	if plate and Hostile(at) ~= true then plate = nil end
	if #casts >= MAX_CASTS then table.remove(casts, 1) end
	casts[#casts + 1] = { tex = tex, id = readable and spellID or nil, t = GetTime(), plate = plate, pet = unit == "pet" }
end

-- A cast whose spell's school is known only claims a hit of that school.
local function Fits(c, school)
	if not c.id or school == nil then return true end
	local known = schoolOf[c.id]
	return known == nil or known == school
end

-- The icon for a hit on a plate (nil: none). school: the hit's mask, nil when secret.
local function IconFor(plate, school, missed)
	local now = GetTime()
	for i = #casts, 1, -1 do
		local c = casts[i]
		if c.used or now - c.t > (c.plate and CAST_WAIT or AREA_WAIT) then table.remove(casts, i) end
	end
	for i = 1, #casts do
		local c = casts[i]
		if (c.plate == plate or c.plate == nil) and Fits(c, school) then
			if c.plate then c.used = true end
			if c.id and school ~= nil and not missed and schoolOf[c.id] == nil then schoolOf[c.id] = school end
			if school ~= nil and not missed then
				if c.pet then
					petLast[school] = { tex = c.tex, t = now }
				elseif Periodic(c.id) then
					local mine = lastHit[plate] or {}
					lastHit[plate] = mine
					mine[school] = { tex = c.tex, t = now }
				end
			end
			return c.tex
		end
	end
	if missed or school == nil then return nil end
	if school == 1 then
		if UnitExists("pet") then return nil end
		return GetInventoryItemTexture("player", 16)
	end
	-- Unclaimed: a tick of one of your DoTs of that school on this plate, else (pet out) your pet's
	-- spell of that school, else no icon rather than a wrong one.
	local last = lastHit[plate] and lastHit[plate][school]
	if last and now - last.t <= TICK_WAIT then
		last.t = now
		return last.tex
	end
	local pet = petLast[school]
	if pet and now - pet.t <= PET_WAIT and UnitExists("pet") then return pet.tex end
	return nil
end

local function ForgetPlate(plate)
	if not plate then return end
	lastHit[plate] = nil
	for i = #casts, 1, -1 do
		if casts[i].plate == plate then table.remove(casts, i) end
	end
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

local PlaceSelfSpots   -- (On You: puts the left and right spots where the settings say)
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
	look.icons = G("icons") or "left"
	look.iconScale = G("iconScale") or 0.9
	local icons = G("icons")
	look.icons = (icons == "right" or icons == "off") and icons or "left"   -- (any other: left of the number)
	-- Where each kind starts: hits, crits, misses (each kind's own Start, beside its motion).
	local function Where(key)
		local a = G(key)
		return ANCHORS[a] and a or "above"
	end
	look.anchor = Where("anchor")
	look.critAnchor = Where("critAnchor")
	look.missAnchor = Where("missAnchor")
	look.ink = ns.Colors().VALUE or { 1, 1, 1 }
	look.selfSize = G("selfSize") or 18
	look.selfCrit = math.floor(look.selfSize * (G("critScale") or 1.5) + 0.5)
	look.selfX = G("selfX") or 200
	look.selfY = G("selfY") or -40
	look.selfSigns = G("selfSigns") ~= false
	if PlaceSelfSpots then PlaceSelfSpots() end
end

-- The outline flags, as DaylightUI's own combat text draws them. Only DaylightUI 1.9.5 has
-- Style.Slug ("OUTLINE, SLUG", the game's slug renderer); 1.9.6 took it out again (it drew every
-- outline much heavier) and, like the versions before 1.9.5, uses the plain outline.
local function Outline()
	local Style = ns.DUI and ns.DUI.Style
	if type(Style) == "table" and type(Style.Slug) == "function" then
		local ok, flags = pcall(Style.Slug, "OUTLINE")
		if ok and type(flags) == "string" and flags ~= "" then return flags end
	end
	return "OUTLINE"
end

local function Font(fs, size)
	size = math.max(6, math.floor(size + 0.5))
	if fs.daylightFile ~= look.file or fs.daylightSize ~= size then
		local flags = Outline()
		if not fs:SetFont(look.file, size, flags) then fs:SetFont(API.Font(), size, flags) end
		fs.daylightFile, fs.daylightSize = look.file, size
	end
end

-- Where the numbers start (each kind's Start, and the two shifts): the number's point, the plate's
-- point, x, y. Above and below: from the plate's middle, Vertical Shift out from the plate (up
-- above it, down below it), Horizontal Shift left or right. Left and right: the number's near edge
-- held off the plate's edge (never over its bar), Horizontal Shift further out, Vertical Shift up
-- or down from the plate's middle. a: the kind's spot (look.anchor, critAnchor or missAnchor); the
-- two shifts are shared by all three.
local EDGE_GAP = 6
local function Start(a)
	if a == "self" then return "CENTER", "CENTER", 0, 0 end   -- (On You: the spot itself)
	if a == "below" then return "CENTER", "CENTER", look.x, -look.height end
	if a == "left" then return "RIGHT", "LEFT", -(EDGE_GAP + math.max(0, look.x)), look.height end
	if a == "right" then return "LEFT", "RIGHT", EDGE_GAP + math.max(0, look.x), look.height end
	return "CENTER", "CENTER", look.x, look.height
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
	if n.icon then n.icon:Hide() end
	n.iconOn = false
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
			local point, rel, bx, by = Start(n.where)
			n.fs:SetPoint(point, n.plate, rel, bx + x, by + y)
			-- A crit pops: bigger for its first sixth, then its own size.
			if n.pop and n.fs.SetTextScale then
				local q = p * 6
				local pop = q < 1 and (1 + 0.5 * math.sin(q * math.pi)) or 1
				n.fs:SetTextScale(pop)
				if n.iconOn then n.icon:SetSize(n.iconSize * pop, n.iconSize * pop) end
			end
			local fade = p > 0.6 and (1 - p) / 0.4 or 1
			n.fs:SetAlpha(n.alpha * fade)
			if n.iconOn then n.icon:SetAlpha(n.alpha * fade) end
		end
	end
end

local function WorldStep(_, dt)
	Step(world, dt)
	if #world.live == 0 then world.frame:SetScript("OnUpdate", nil) end
end

-- A number (or word) on a plate. value: secret or plain, only shown.
-- icon: a texture for the spell, beside the number (left or right, per Spell Icons), or nil.
local ICON_GAP = 3
-- where: the kind's start around the plate (look.anchor, critAnchor or missAnchor), or "self" for
-- On You (plate is then the spot: the player frame or a spot beside the screen's middle). sign: "+"
-- or "-" written before the number by the game's own formatting (the amount stays unread).
local function Spawn(stage, plate, unit, value, color, crit, anim, quiet, icon, where, sign)
	local live = stage.live
	if #live >= MAX_LIVE then Drop(stage, 1) end
	local n = table.remove(stage.spare)
	if not n then
		n = { fs = stage.frame:CreateFontString(nil, "OVERLAY") }
	end
	local fs = n.fs
	local scale = quiet and look.offScale or 1
	local size = (crit and look.crit or look.size) * scale
	if where == "self" then size = crit and look.selfCrit or look.selfSize end
	Font(fs, size)
	n.iconOn = false
	n.iconSize = math.max(6, math.floor(size * look.iconScale + 0.5))
	if icon ~= nil and look.icons ~= "off" then
		if not n.icon then
			n.icon = stage.frame:CreateTexture(nil, "OVERLAY")
			n.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		local t = n.icon
		if pcall(t.SetTexture, t, icon) then
			t:SetSize(n.iconSize, n.iconSize)
			t:ClearAllPoints()
			if look.icons == "right" then
				t:SetPoint("LEFT", fs, "RIGHT", ICON_GAP, 0)
			else
				t:SetPoint("RIGHT", fs, "LEFT", -ICON_GAP, 0)
			end
			t:SetAlpha(0)
			t:Show()
			n.iconOn = true
		end
	end
	if n.icon and not n.iconOn then n.icon:Hide() end
	if fs.SetTextScale then fs:SetTextScale(1) end
	if not (sign and pcall(fs.SetFormattedText, fs, sign .. "%s", value)) then fs:SetText(value) end
	fs:SetTextColor(color[1], color[2], color[3])
	n.plate, n.unit = plate, unit
	n.t, n.life = 0, look.life
	n.anim = anim
	n.pop = crit
	n.alpha = quiet and look.offAlpha or 1
	n.dir = math.random() < 0.5 and -1 or 1
	n.x0 = (math.random() * 2 - 1) * 8
	-- Beside the plate, sideways motion only goes away from it (never back over its bar).
	n.where = where or look.anchor
	local out = n.where == "self" and plate.daylightOut or nil
	if out then
		n.dir = out
		n.x0 = math.abs(n.x0) * out
	elseif n.where == "left" or n.where == "right" then
		n.dir = n.where == "left" and -1 or 1
		n.x0 = math.abs(n.x0) * n.dir
	end
	n.side = 40 + math.random() * 50
	n.peak = 25 + math.random() * 25
	fs:SetAlpha(0)
	fs:Show()
	live[#live + 1] = n
	if stage == world then world.frame:SetScript("OnUpdate", WorldStep) end
end

local handed = false   -- in a group: ours paused, the game's own numbers (yours and your pet's) on
local sctOff      -- DaylightUI's override handle while its scrolling combat text is held off

-- ---------------------------------------------------------------------------------------------
-- On You: damage taken and healing received
-- ---------------------------------------------------------------------------------------------
-- The game reports each hit and heal on you (UNIT_COMBAT for "player"): no doubt whose they are, so
-- unlike the plates' numbers these keep showing in a group. They show at the player frame
-- (DaylightUI's, through its mover) or at a spot left or right of the screen's middle. DaylightUI's
-- own combat text shows these too: while it's on (Turn Off DaylightUI's Combat Text off, and its
-- own switch on), ours step aside so nothing shows twice.
local DAMAGE_RED = { 1, 0.3, 0.25 }
local HEAL_GREEN = { 0.35, 1, 0.45 }
local selfLeft, selfRight   -- the spots beside the screen's middle (1 px frames on UIParent)

PlaceSelfSpots = function()
	if not selfLeft then return end
	selfLeft:ClearAllPoints()
	selfLeft:SetPoint("CENTER", UIParent, "CENTER", -look.selfX, look.selfY)
	selfRight:ClearAllPoints()
	selfRight:SetPoint("CENTER", UIParent, "CENTER", look.selfX, look.selfY)
end

local function SelfSpot(at)
	if at == "player" then
		local f = ns.MoverFrame("unitframes.player")
		if f and f.IsVisible and f:IsVisible() then return f end
		at = "left"
	end
	return at == "right" and selfRight or selfLeft
end

-- DaylightUI's own combat text is showing (not held off by us): it already shows these.
local function DaylightShowsIncoming()
	if sctOff then return false end
	local ok, on = pcall(API.GetSetting, "general", "sct.enabled")
	return ok and on == true
end

local function OnSelf(action, flag, amount, school)
	if not selfLeft or Secret(action) or type(action) ~= "string" then return end
	local heal = action == "HEAL"
	local avoided = AVOIDED[action]
	if not heal and action ~= "WOUND" and not avoided then return end
	if G(heal and "selfHeal" or "selfDamage") == false then return end
	if DaylightShowsIncoming() then return end
	local spot = SelfSpot(G(heal and "selfHealAt" or "selfDamageAt") or (heal and "right" or "left"))
	local anim = G("selfAnim") or "up"
	if avoided then
		Spawn(world, spot, nil, AvoidWord(action), look.ink, false, anim, false, nil, "self")
		return
	end
	if type(amount) == "nil" then return end
	local crit = not Secret(flag) and flag == "CRITICAL"
	local color = HEAL_GREEN
	if not heal then
		-- (Physical stays red: the school's own color, a light yellow, reads as a hit you dealt.)
		local c = look.schools and SchoolColor(school)
		color = (c and c ~= SCHOOLS[1]) and c or DAMAGE_RED
	end
	local sign = look.selfSigns and (heal and "+" or "-") or nil
	Spawn(world, spot, nil, Amount(amount), color, crit, anim, false, nil, "self", sign)
end

local function OnCombat(unit, action, flag, amount, school)
	if not Secret(unit) and unit == "player" then
		OnSelf(action, flag, amount, school)
		return
	end
	if handed then return end
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
	local mask = (type(school) == "number" and not Secret(school)) and school or nil
	local icon = look.icons ~= "off" and IconFor(plate, mask, avoided) or nil
	if avoided then
		Spawn(world, plate, unit, AvoidWord(action), look.ink, false, G("missAnim") or "up", quiet, icon, look.missAnchor)
		return
	end
	if type(amount) == "nil" then return end
	local crit = not Secret(flag) and flag == "CRITICAL"
	local color = look.schools and SchoolColor(school) or look.ink
	Spawn(world, plate, unit, Amount(amount), color, crit, crit and (G("critAnim") or "up") or (G("anim") or "fountain"), quiet,
		icon, crit and look.critAnchor or look.anchor)
end

-- A plate going away takes its numbers with it (its frame is handed to the next unit).
local function OnPlateGone(unit)
	ForgetPlate(Plate(unit))
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

local function ApplyReplace()
	if InCombatLockdown() then
		waiting = true   -- (set once the fight ends)
		return
	end
	waiting = false
	local saved = Saved()
	local on = G("enabled") == true
	-- (Changed only out of combat, with the switches: ours keep showing until the game's are on.)
	handed = on and G("groupGame") ~= false and IsInGroup() == true
	local want = on and G("replace") ~= false and not handed
	for _, name in ipairs(GAME_NUMBERS) do
		local ok, now = pcall(C_CVar.GetCVar, name)
		if ok and now ~= nil then
			if want then
				if saved[name] == nil then saved[name] = now end
				if now ~= "0" then pcall(C_CVar.SetCVar, name, "0") end
			elseif handed then
				-- In a group: the game's own numbers on (what they were is still given back later).
				if saved[name] == nil then saved[name] = now end
				if now ~= "1" then pcall(C_CVar.SetCVar, name, "1") end
			elseif saved[name] ~= nil then
				if now ~= saved[name] then pcall(C_CVar.SetCVar, name, saved[name]) end
				saved[name] = nil
			end
		end
	end
	-- DaylightUI's own scrolling combat text (its "Show combat text"), which shows damage and healing
	-- on you. In a group the plates' numbers are the game's, but On You's keep showing: it stays off
	-- then too, so those don't show twice.
	local selfOn = G("selfDamage") ~= false or G("selfHeal") ~= false
	local wantText = want or (on and G("replace") ~= false and handed and selfOn)
	if wantText and not sctOff then
		local ok, handle = pcall(ns.me.Override, "general", "sct.enabled", false)
		sctOff = ok and handle or nil
	elseif not wantText and sctOff then
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
local SAMPLE_ICONS = {   -- a spell of each school, for the preview's icons
	[1] = "Interface\\Icons\\Ability_MeleeDamage", [2] = "Interface\\Icons\\Spell_Holy_HolyBolt",
	[4] = "Interface\\Icons\\Spell_Fire_FlameBolt", [8] = "Interface\\Icons\\Spell_Nature_Lightning",
	[16] = "Interface\\Icons\\Spell_Frost_FrostBolt02", [32] = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
	[64] = "Interface\\Icons\\Spell_Nature_StarFall",
}
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
	-- Where the numbers start: a still number, the piece Design mode drags. Its dot is where the
	-- shifts count from: the plate's middle, or its edge on the hits' Start side (kept by Look).
	local start = f:CreateFontString(nil, "OVERLAY")
	local home = { spot = "home", x = PLATE_W / 2, y = PLATE_H / 2 }

	local function Look()
		ReadLook()
		ns.Ink(name, "TEXT")
		Font(start, look.size)
		start:SetText((AbbreviateNumbers or tostring)(1234))
		local c = look.schools and SCHOOLS[1] or look.ink
		start:SetTextColor(c[1], c[2], c[3])
		start:SetAlpha(0.35)
		start:ClearAllPoints()
		-- (One marker, at the hits' start: crits and misses share the shifts, from their own spots.)
		local point, rel, x, y = Start(look.anchor)
		start:SetPoint(point, plate, rel, x, y)
		local a = look.anchor
		home.x = a == "left" and 0 or a == "right" and PLATE_W or PLATE_W / 2
	end

	-- On You's samples: a spot each side of the strip, standing in for the screen's left and right of
	-- middle (and the player frame, shown on the damage side).
	local youLeft = CreateFrame("Frame", nil, f)
	youLeft:SetSize(1, 1)
	youLeft.daylightOut = -1
	local youRight = CreateFrame("Frame", nil, f)
	youRight:SetSize(1, 1)
	youRight.daylightOut = 1
	local function SampleSelf(heal, crit)
		if G(heal and "selfHeal" or "selfDamage") == false then return end
		local at = G(heal and "selfHealAt" or "selfDamageAt") or (heal and "right" or "left")
		local spot = at == "right" and youRight or youLeft
		local value = crit and math.random(900, 1600) or math.random(150, 600)
		local text = (G("numbers") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or tostring)(value)
		local color = heal and HEAL_GREEN or DAMAGE_RED
		if not heal and look.schools and n % 3 == 0 then color = SCHOOLS[4] end
		local sign = look.selfSigns and (heal and "+" or "-") or nil
		Spawn(stage, spot, nil, text, color, crit, G("selfAnim") or "up", false, nil, "self", sign)
	end

	local function SpawnOne()
		n = n + 1
		if n % 3 == 0 then SampleSelf(n % 6 == 0, n % 9 == 0) end
		local crit = n % 4 == 0
		local quiet = look.off and n % 5 == 0       -- now and then as an enemy you aren't targeting
		if n % 7 == 0 and G("misses") ~= false then
			Spawn(stage, plate, nil, AvoidWord("DODGE"), look.ink, false, G("missAnim") or "up", quiet, nil, look.missAnchor)
			return
		end
		local value = crit and math.random(1800, 3200) or math.random(300, 1200)
		local text = (G("numbers") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or tostring)(value)
		local school = SAMPLE_SCHOOLS[n % #SAMPLE_SCHOOLS + 1]
		local color = look.schools and SCHOOLS[school] or look.ink
		Spawn(stage, plate, nil, text, color, crit, crit and (G("critAnim") or "up") or (G("anim") or "fountain"), quiet,
			SAMPLE_ICONS[school], crit and look.critAnchor or look.anchor)
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
		youLeft:ClearAllPoints()
		youLeft:SetPoint("CENTER", f, "BOTTOMLEFT", math.floor(width * 0.14), math.floor(h * 0.35))
		youRight:ClearAllPoints()
		youRight:SetPoint("CENTER", f, "BOTTOMRIGHT", -math.floor(width * 0.14), math.floor(h * 0.35))
		return h
	end

	function s.Parts()
		local dots = { home }
		return {
			{ region = plate, label = L["Nameplate Dmg Text"],
			  keys = { KEY .. ".enabled", KEY .. ".plates", KEY .. ".misses", KEY .. ".offTarget" } },
			{ region = start, label = L["Where the Numbers Start"],
			  keys = { KEY .. ".x", KEY .. ".height", KEY .. ".anim", KEY .. ".critAnim", KEY .. ".missAnim",
			           KEY .. ".speed", KEY .. ".size", KEY .. ".critScale", KEY .. ".schools", KEY .. ".icons", KEY .. ".iconScale", KEY .. ".anchor", KEY .. ".critAnchor", KEY .. ".missAnchor", KEY .. ".numbers" },
			  move = { owner = plate, dots = dots, xKey = KEY .. ".x", yKey = KEY .. ".height",
			           drop = function(x, y)
			               -- (y is down from the plate's top.) Back to the shifts, as Start reads them.
			               local dx, up = x - home.x, home.y - y
			               local a = look.anchor
			               if a == "below" then
			                   up = -up
			               elseif a == "left" then
			                   dx = math.max(0, -dx - EDGE_GAP)
			               elseif a == "right" then
			                   dx = math.max(0, dx - EDGE_GAP)
			               end
			               return "home", math.floor(dx + 0.5), math.floor(up + 0.5)
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
	local on = G("enabled") == true
	if on then
		events:RegisterEvent("UNIT_COMBAT")
		events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		events:RegisterEvent("GROUP_ROSTER_UPDATE")
	else
		events:UnregisterEvent("UNIT_COMBAT")
		events:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
		events:UnregisterEvent("GROUP_ROSTER_UPDATE")
		DropAll(world)
	end
	-- Your and your pet's casts, for the spell icons (only while those show).
	if on and (G("icons") or "left") ~= "off" then
		events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
	else
		events:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		wipe(casts)
	end
end

function P.Login()
	-- (While 1.5.0 was made there was one Numbers Start for all three kinds: its choice, saved as
	-- "anchor", becomes the crits' and misses' too, once. And "Fall from below" was a motion of its
	-- own: it's that kind's Below plate with Fall.)
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if not db.plateTextStarts then
		db.plateTextStarts = true
		local was = G("anchor")
		if was and was ~= "above" then
			pcall(ns.DUI.Set, ns.DUI, ns.ADDON, KEY .. ".critAnchor", was)
			pcall(ns.DUI.Set, ns.DUI, ns.ADDON, KEY .. ".missAnchor", was)
		end
	end
	for anim, where in pairs({ anim = "anchor", critAnim = "critAnchor", missAnim = "missAnchor" }) do
		if G(anim) == "below" then
			pcall(ns.DUI.Set, ns.DUI, ns.ADDON, KEY .. "." .. anim, "down")
			pcall(ns.DUI.Set, ns.DUI, ns.ADDON, KEY .. "." .. where, "below")
		end
	end
	local holder = CreateFrame("Frame", "DaylightEssentialsNameplateText", UIParent)
	holder:SetAllPoints(UIParent)
	holder:SetFrameStrata("HIGH")
	world = NewStage(holder)
	selfLeft = CreateFrame("Frame", nil, UIParent)
	selfLeft:SetSize(1, 1)
	selfLeft.daylightOut = -1    -- (sideways motion goes away from the middle)
	selfRight = CreateFrame("Frame", nil, UIParent)
	selfRight:SetSize(1, 1)
	selfRight.daylightOut = 1
	ReadLook()
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", function(_, event, a, b, c, d, e)
		if event == "UNIT_COMBAT" then
			OnCombat(a, b, c, d, e)
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			if not handed and not Secret(a) and (a == "player" or a == "pet") then OnCast(a, c) end
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			if not Secret(a) then OnPlateGone(a) end
		elseif event == "PLAYER_REGEN_ENABLED" then
			if waiting then ApplyReplace() end
		elseif event == "GROUP_ROSTER_UPDATE" then
			-- Joining or leaving a group: ours or the game's numbers (after the fight, if in one).
			if handed ~= (G("groupGame") ~= false and IsInGroup() == true) then ApplyReplace() end
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
