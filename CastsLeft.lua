-- Casts Left: for mages, how many more times your mana lets you cast each of your attack and
-- defense spells, as a small number on its button: on Daylight UI's action bars, the game's own
-- bars, and Halo's icons. Buffs, armors, conjures, teleports and portals have none.
--   * Colors: the value ink, the warning ink once you're down to Warn At casts, the bad red at 0.
--   * Only Show When Low: the number stays hidden until you're down to Show at casts.
--   * Only in a Fight: no numbers out of one.
--   * Corner: where on the button the number sits.
--   * Free: a cast that costs nothing just now (Clearcasting) reads "Free".
--   * Main Spell: one spell's count as a larger line of its own ("Frostbolt 14"), moved with
--     /dui unlock, for watching one spell without looking at the bars.
--
-- In a fight the game keeps your mana secret from addons: it can't be compared, divided or turned
-- into text by an addon's own code (Daylight UI's player power bar says the same,
-- DaylightUI_UnitFrames\PowerBar.lua:221). What stays readable: a spell's cost
-- (C_Spell.GetSpellPowerCost, no secrecy flag: Blizzard_APIDocumentationGenerated
-- \SpellDocumentation.lua), your maximum mana (secret only for units that aren't player-controlled:
-- SecretPredicatesDocumentation.lua, SecretWhenUnitPowerMaxRestricted), and which spell a button
-- holds (C_ActionBar.GetSpell). So for each cost two step curves are made, from your mana as a
-- fraction of its maximum: one to the number of casts (the step to k casts sits at
-- (k x cost) / max), one to the color, whose alpha also hides the number above Show at. The game
-- reads the (maybe secret) mana through them (UnitPowerPercent with a curve, as Healer Mana and
-- Daylight UI's own bars do) and the answers go straight into the text's own formatting and color.
-- Nothing secret is ever looked at here, so it works the same in a fight and out of one. Counts
-- stop at 99.
--
-- The spells: Arcane, Fire and Frost spells that cost mana, every rank, read from this client's
-- own tables (SkillLineAbility / SpellName / SpellPower, build 1.60.1.71091): attacks and crowd
-- control, and the defensive ones (Blink, Mana Shield, Ice Barrier, Ice Block, Fire Ward,
-- Frost Ward).
--
-- What it costs: nothing for other classes. For a mage: on a mana change, two curve reads by the
-- game per spell on your bars and a text set per button; the curves are made again only when a
-- cost, your maximum mana or a setting changes (a buff, a level, gear, a new spell). What sits on
-- the bars is looked at again when a bar changes. No timers.

-- luacheck: read globals C_ActionBar C_SpellBook IsSpellKnown IsPlayerSpell
local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "castsLeft"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["Casts Left"] })

-- The spells, by name (every rank: the name is what the Main Spell picker lists). The first id
-- names it in the game's language.
local GROUPS = {
	-- Arcane
	{ "arcaneMissiles", { 5143, 5144, 5145, 8416, 8417, 10211, 10212, 25345 } },
	{ "arcaneExplosion", { 1449, 8437, 8438, 8439, 10201, 10202 } },
	{ "arcaneBlast", { 400574, 1239696, 1239697, 1239699, 1239700 } },
	{ "arcaneBarrage", { 400610 } },
	{ "arcaneWrath", { 1326079, 1326080, 1326081, 1326082 } },
	{ "counterspell", { 2139 } },
	{ "polymorph", { 118, 12824, 12825, 12826, 28271, 28272 } },
	{ "polymorphCow", { 28270 } },
	-- Fire
	{ "fireball", { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 } },
	{ "fireBlast", { 2136, 2137, 2138, 8412, 8413, 10197, 10199, 400616, 400618, 400619, 400620, 400621, 400622, 400623 } },
	{ "scorch", { 2948, 8444, 8445, 8446, 10205, 10206, 10207 } },
	{ "pyroblast", { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 } },
	{ "flamestrike", { 2120, 2121, 8422, 8423, 10215, 10216 } },
	{ "blastWave", { 11113, 13018, 13019, 13020, 13021 } },
	{ "livingBomb", { 400613, 400614 } },
	{ "livingFlame", { 401556, 401558 } },
	{ "balefireBolt", { 428878 } },
	{ "frostfireBolt", { 401502, 1237312, 1237313 } },
	-- Frost
	{ "frostbolt", { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 } },
	{ "frostNova", { 122, 865, 6131, 10230 } },
	{ "coneOfCold", { 120, 8492, 10159, 10160, 10161 } },
	{ "blizzard", { 10, 6141, 8427, 10185, 10186, 10187 } },
	{ "iceLance", { 400640, 1240044, 1240045, 1240046, 1240047, 1312002 } },
	{ "frozenOrb", { 440802, 440809 } },
	{ "spellfrostBolt", { 412532 } },
	{ "icyVeins", { 425121 } },
	-- Defense
	{ "blink", { 1953 } },
	{ "manaShield", { 1463, 8494, 8495, 10191, 10192, 10193 } },
	{ "iceBarrier", { 11426, 13031, 13032, 13033 } },
	{ "iceBlock", { 11958 } },
	{ "fireWard", { 543, 8457, 8458, 10223, 10225 } },
	{ "frostWard", { 6143, 8461, 8462, 10177, 28609 } },
}
local TRACKED, GROUP_OF = {}, {}
for _, g in ipairs(GROUPS) do
	GROUP_OF[g[1]] = g[2]
	for _, id in ipairs(g[2]) do TRACKED[id] = true end
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and Safe(name) and type(name) == "string" and name ~= "" then return name end
	end
	return nil
end

-- The Main Spell picker's choices: each spell by its name in the game's language.
local MAIN_VALUES = { off = L["Off"] }
for _, g in ipairs(GROUPS) do MAIN_VALUES[g[1]] = SpellName(g[2][1]) or g[1] end

local CORNERS = { TOPLEFT = L["Top Left"], TOPRIGHT = L["Top Right"], BOTTOMLEFT = L["Bottom Left"], CENTER = L["Middle"] }

P.defaults = {
	enabled = true,
	bars = true,
	halo = true,
	size = 11,
	corner = "TOPLEFT",
	warnAt = 2,
	lowOnly = false,
	lowAt = 5,
	combatOnly = false,
	main = "off",
	mainScale = 1,
}

P.page = { id = KEY, label = L["Casts Left"],
	desc = L["For mages: how many more casts your mana allows, on each spell's button."],
	groups = {
		{ label = L["Casts Left"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"],
			  desc = L["Attack and defense spells only. It reads 0 in red once you can't afford another cast."] },
			{ type = "toggle", key = KEY .. ".bars", label = L["On Action Bars"] },
			{ type = "toggle", key = KEY .. ".halo", label = L["On Halo"] },
			{ type = "toggle", key = KEY .. ".combatOnly", label = L["Only in a Fight"],
			  desc = L["No numbers until a fight starts."] },
		} },
		{ label = L["Look"], items = {
			{ type = "dropdown", key = KEY .. ".corner", label = L["Corner"], values = CORNERS },
			{ type = "slider", key = KEY .. ".size", label = L["Text Size"], min = 8, max = 18, step = 1 },
			{ type = "slider", key = KEY .. ".warnAt", label = L["Warn At (Casts)"], min = 0, max = 5, step = 1,
			  desc = L["The number turns the warning color at this many casts left, and red at 0. 0: only the red."] },
			{ type = "toggle", key = KEY .. ".lowOnly", label = L["Only Show When Low"],
			  desc = L["Each number stays hidden until you're down to Show At casts of that spell."] },
			{ type = "slider", key = KEY .. ".lowAt", label = L["Show At (Casts)"], min = 1, max = 20, step = 1 },
		} },
		{ label = L["Main Spell"], items = {
			{ type = "dropdown", key = KEY .. ".main", label = L["Main Spell"], values = MAIN_VALUES,
			  desc = L["One spell's casts left as a larger line of its own. Move it with /dui unlock."] },
			{ type = "slider", key = KEY .. ".mainScale", label = L["Size"], min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
	} }

local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local CAP = 99

-- The bars: Daylight UI's own (DaylightUI_ActionBars\Buttons.lua: "DaylightUIBar<n>Button<i>"),
-- then the game's (each Daylight UI bar keeps one of these hidden as its twin, Bars.lua).
local BAR_NAMES = {}
for n = 1, 8 do BAR_NAMES[#BAR_NAMES + 1] = "DaylightUIBar" .. n .. "Button" end
for _, name in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
	"MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }) do
	BAR_NAMES[#BAR_NAMES + 1] = name
end

local class
local driver                                          -- the event frame
local spots = setmetatable({}, { __mode = "k" })      -- owner -> { fs, spell = id or name, kind, scale }
local costs = {}                                      -- spell -> its mana cost now (0: free), when known
local curves = {}                                     -- cost -> { count = curve, color = curve }
local curvesMax                                       -- the maximum mana the curves were made for
local mainFrame, mainText                             -- the Main Spell line
local MAIN_W, MAIN_H = 200, 30
local MAIN_DEFAULT = { "CENTER", UIParent, "CENTER", 0, -150 }

local function On() return class == "MAGE" and G("enabled") and true or false end
local function Showing() return On() and not (G("combatOnly") and not InCombatLockdown()) end

-- ---------------------------------------------------------------------------------------------
-- Costs and curves
-- ---------------------------------------------------------------------------------------------

-- The spell's mana cost now, or nil when the game won't say (as Daylight UI's UnitFrames reads it:
-- the mana entry, unless it asks for an aura you don't have). 0 when it costs nothing just now.
local function CostOf(spell)
	local api = C_Spell and C_Spell.GetSpellPowerCost
	if type(api) ~= "function" then return nil end
	local ok, list = pcall(api, spell)
	if not ok then return nil end
	if type(list) ~= "table" then return 0 end
	for _, c in ipairs(list) do
		if type(c) == "table" and Safe(c.type) and c.type == MANA then
			local aura, has = c.requiredAuraID, c.hasRequiredAura
			local needsAura = Safe(aura) and type(aura) == "number" and aura ~= 0
			if not (needsAura and Safe(has) and has ~= true) then
				local cost = c.cost
				if Safe(cost) and type(cost) == "number" then return cost end
				return nil
			end
		end
	end
	return 0
end

local function MaxMana()
	local max = UnitPowerMax("player", MANA)
	if Safe(max) and type(max) == "number" and max > 0 then return max end
	return nil
end

local function Ink(role)
	local c = ns.Colors()[role]
	if type(c) == "table" then return c[1], c[2], c[3] end
	return 1, 1, 1
end

-- Where on the mana scale (0 to 1) you have exactly k casts' worth: half a point early, as mana is
-- whole numbers, so exactly k casts' worth always reads k.
local function At(k, cost, max) return math.max(0, math.min(1, (k * cost - 0.5) / max)) end

-- The two curves for a cost at the maximum mana now. Count: a step up at each cast's worth.
-- Color: the bad red below one cast, the warning ink up to Warn At casts, the value ink above;
-- its alpha is 0 above Show At casts when Only Show When Low is on.
local function CurvesFor(cost)
	local max = MaxMana()
	if not max then return nil end
	if curvesMax ~= max then
		wipe(curves)
		curvesMax = max
	end
	local c = curves[cost]
	if c ~= nil then return c or nil end
	curves[cost] = false
	local U = C_CurveUtil
	if not (U and U.CreateCurve and U.CreateColorCurve and CreateColor and Enum and Enum.LuaCurveType) then return nil end
	local okC, count = pcall(U.CreateCurve)
	local okK, color = pcall(U.CreateColorCurve)
	if not (okC and count and okK and color) then return nil end
	pcall(count.SetType, count, Enum.LuaCurveType.Step)
	pcall(color.SetType, color, Enum.LuaCurveType.Step)
	count:AddPoint(0, 0)
	for k = 1, CAP do
		local x = (k * cost - 0.5) / max
		if x > 1 then break end
		count:AddPoint(x, k)
	end
	-- The color's steps, each with the alpha it has there: (casts from, ink).
	local warnAt = G("warnAt") or 2
	local hideAbove = G("lowOnly") and (G("lowAt") or 5) or nil
	local steps = { { 0, "BAD" } }
	if warnAt >= 1 then steps[#steps + 1] = { 1, "WARN" } end
	steps[#steps + 1] = { warnAt + 1, "VALUE" }
	local marks = {}
	for _, s in ipairs(steps) do marks[#marks + 1] = { s[1], s[2] } end
	if hideAbove then marks[#marks + 1] = { hideAbove + 1, false } end
	table.sort(marks, function(a, b) return a[1] < b[1] end)
	local ink = "BAD"
	for _, m in ipairs(marks) do
		if m[2] then ink = m[2] end
		-- (A step past full mana is never reached: left out.)
		if m[1] * cost - 0.5 <= max then
			local hidden = hideAbove and m[1] > hideAbove
			local r, g, b = Ink(ink)
			color:AddPoint(At(m[1], cost, max), CreateColor(r, g, b, hidden and 0 or 1))
		end
	end
	c = { count = count, color = color }
	curves[cost] = c
	return c
end

-- ---------------------------------------------------------------------------------------------
-- The numbers
-- ---------------------------------------------------------------------------------------------

local function Place(s)
	local corner = G("corner") or "TOPLEFT"
	local x = (corner == "TOPLEFT" or corner == "BOTTOMLEFT") and 2 or (corner == "TOPRIGHT" and -2 or 0)
	local y = (corner == "TOPLEFT" or corner == "TOPRIGHT") and -2 or (corner == "BOTTOMLEFT" and 2 or 0)
	s.fs:ClearAllPoints()
	s.fs:SetPoint(corner, s.owner, corner, x, y)
end

local function Font(fs, scale)
	local size = math.floor((G("size") or 11) * (scale or 1) + 0.5)
	if not fs:SetFont(API.Font(), size, "OUTLINE") then fs:SetFontObject("NumberFontNormalSmall") end
end

local function Spot(owner, host, scale, kind)
	local s = spots[owner]
	if s then return s end
	local fs = host:CreateFontString(nil, "OVERLAY")
	fs:SetJustifyH("LEFT")
	s = { fs = fs, scale = scale, kind = kind, owner = owner }
	Font(fs, scale)
	Place(s)
	spots[owner] = s
	return s
end

-- One spell's count and color now, worked out once a paint and shared by its buttons.
local function Read(spell, cache)
	local r = cache[spell]
	if r then return r end
	r = {}
	cache[spell] = r
	local cost = costs[spell]
	if cost == nil then
		cost = CostOf(spell)
		costs[spell] = cost or false
	end
	if not cost then return r end
	if cost <= 0 then
		r.free = true
		return r
	end
	local c = CurvesFor(cost)
	if c and UnitPowerPercent then
		local ok, n = pcall(UnitPowerPercent, "player", MANA, false, c.count)
		if ok then r.n = n end
		local okC, col = pcall(UnitPowerPercent, "player", MANA, false, c.color)
		if okC and type(col) == "table" and col.GetRGBA then r.col = col end
		return r
	end
	-- (A client without curves: the plain numbers while they can be read.)
	local cur, max = UnitPower("player", MANA), MaxMana()
	if Safe(cur) and type(cur) == "number" and max then
		r.n = math.min(CAP, math.floor(cur / cost))
		r.plain = true
	end
	return r
end

-- Writes r into a text: the count (or "Free"), in its color, shown or hidden by its alpha.
local function Write(fs, r, prefix)
	if r.free then
		fs:SetText(prefix and (prefix .. " " .. L["Free"]) or L["Free"])
		fs:SetTextColor(API.Accent())
		fs:SetAlpha(1)
		return true
	end
	if r.n == nil then return false end
	-- (Formatted by the game itself: a secret count is fine here.)
	local ok
	if prefix then
		ok = pcall(fs.SetFormattedText, fs, "%s %.0f", prefix, r.n)
	else
		ok = pcall(fs.SetFormattedText, fs, "%.0f", r.n)
	end
	if not ok then return false end
	if r.col then
		local okA = pcall(fs.SetTextColor, fs, r.col:GetRGBA())
		if not okA then pcall(fs.SetTextColor, fs, r.col:GetRGB()) end
	elseif r.plain then
		local n = r.n
		local warnAt = G("warnAt") or 2
		fs:SetTextColor(Ink(n < 1 and "BAD" or (n <= warnAt and "WARN" or "VALUE")))
		fs:SetAlpha((G("lowOnly") and n > (G("lowAt") or 5)) and 0 or 1)
		return true
	end
	fs:SetAlpha(1)
	return true
end

local function PaintOne(s, cache, showing)
	local fs = s.fs
	if not (showing and s.spell) then
		fs:SetText("")
		return
	end
	if not Write(fs, Read(s.spell, cache)) then fs:SetText("") end
end

-- The Main Spell: the rank you know best, asked by name (the game answers for the highest one).
local function Knows(id)
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	if IsSpellKnown and IsSpellKnown(id) then return true end
	local B = C_SpellBook
	if B and B.IsSpellKnown then
		local ok, yes = pcall(B.IsSpellKnown, id)
		if ok and Safe(yes) and yes then return true end
	end
	return false
end

local function MainSpell()
	local key = G("main")
	local ids = key and GROUP_OF[key]
	if not ids then return nil end
	for i = #ids, 1, -1 do
		if Knows(ids[i]) then return ids[i] end
	end
	return nil
end

local function PaintMain(cache, showing)
	if not mainFrame then return end
	local preview = ns.Previewing(KEY)
	local spell = MainSpell()
	if not (showing and spell) and not preview then
		mainFrame:Hide()
		return
	end
	-- (Named by its first rank: every rank has the name.)
	local name = SpellName((GROUP_OF[G("main")] or GROUP_OF.frostbolt)[1]) or L["Main Spell"]
	mainFrame:SetScale(G("mainScale") or 1)
	if spell and Write(mainText, Read(spell, cache), name) then
		mainFrame:Show()
	elseif preview then
		mainText:SetFormattedText("%s %d", name, 14)
		mainText:SetTextColor(Ink("VALUE"))
		mainText:SetAlpha(1)
		mainFrame:Show()
	else
		mainFrame:Hide()
	end
end

local function Paint()
	local cache = {}
	local showing = Showing()
	for _, s in pairs(spots) do PaintOne(s, cache, showing) end
	PaintMain(cache, showing)
end

-- ---------------------------------------------------------------------------------------------
-- Which spell each button holds
-- ---------------------------------------------------------------------------------------------

local function SlotOf(btn)
	local slot = rawget(btn, "action")
	if type(slot) ~= "number" and type(btn.CalculateAction) == "function" then
		local ok, s = pcall(btn.CalculateAction, btn)
		if ok then slot = s end
	end
	if Safe(slot) and type(slot) == "number" and slot > 0 then return slot end
	return nil
end

local function SpellOn(slot)
	local A = C_ActionBar
	if not (A and A.GetSpell) then return nil end
	local ok, id = pcall(A.GetSpell, slot)
	if ok and Safe(id) and type(id) == "number" and TRACKED[id] then return id end
	return nil
end

local pendingMake = false
local function ScanBars()
	local want = On() and G("bars")
	for _, prefix in ipairs(BAR_NAMES) do
		for i = 1, 12 do
			local btn = _G[prefix .. i]
			if type(btn) == "table" and btn.GetObjectType then
				local slot = want and SlotOf(btn)
				local spell = slot and SpellOn(slot)
				local s = spots[btn]
				if spell and not s then
					-- (Text made out of a fight only: these are the game's secure buttons.)
					if InCombatLockdown() then
						pendingMake = true
					else
						s = Spot(btn, rawget(btn, "TextOverlayContainer") or btn, 1, "bar")
					end
				end
				if s then s.spell = spell end
			end
		end
	end
end

-- Halo's icons, as its ring opens (Halo.lua OnShow): tiles[k].action = { kind, id, name }.
local CastsLeft = {}
ns.CastsLeft = CastsLeft
function CastsLeft.Halo(tiles, shown)
	if type(tiles) ~= "table" then return end
	local want = On() and G("halo")
	for k, t in ipairs(tiles) do
		local a = k <= (shown or 0) and t.action or nil
		local spell
		if want and type(a) == "table" and a.kind == "spell" and TRACKED[a.id] then spell = a.name or a.id end
		local s = spots[t]
		if spell and not s then s = Spot(t, t, (t.base or 36) / 36, "halo") end
		if s then s.spell = spell end
	end
	if want then Paint() end
end

-- ---------------------------------------------------------------------------------------------
-- The Main Spell line
-- ---------------------------------------------------------------------------------------------

local function BuildMain()
	if mainFrame then return end
	mainFrame = CreateFrame("Frame", "DaylightEssentialsCastsLeft", UIParent)
	mainFrame:SetSize(MAIN_W, MAIN_H)
	mainFrame:SetFrameStrata("MEDIUM")
	mainFrame:SetClampedToScreen(true)
	mainFrame:Hide()
	mainText = API.Text(mainFrame, "head", "CENTER")
	mainText:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
	mainFrame:SetPoint(unpack(MAIN_DEFAULT))
	ns.me.RegisterMover(mainFrame, KEY, L["Main Spell"], MAIN_DEFAULT)
end

-- ---------------------------------------------------------------------------------------------
-- When to look
-- ---------------------------------------------------------------------------------------------

local scanSoon, costSoon = false, false
local function ScanNow()
	scanSoon = false
	ScanBars()
	Paint()
end
local function ScanSoon()
	if scanSoon then return end
	scanSoon = true
	C_Timer.After(0, ScanNow)
end
local function CostNow()
	costSoon = false
	-- (Every cost read again; the curves stay for any cost already met.)
	wipe(costs)
	Paint()
end
local function CostSoon()
	if costSoon then return end
	costSoon = true
	C_Timer.After(0, CostNow)
end

local function OnEvent(_, event, unit, kind)
	if event == "UNIT_POWER_UPDATE" then
		if unit ~= "player" or (Safe(kind) and kind ~= "MANA") then return end
		Paint()
	elseif event == "UNIT_MAXPOWER" then
		if unit == "player" then Paint() end
	elseif event == "UNIT_AURA" or event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then
		CostSoon()
	elseif event == "PLAYER_REGEN_DISABLED" then
		Paint()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingMake then
			pendingMake = false
			ScanSoon()
		else
			Paint()
		end
	else
		ScanSoon()
	end
end

local EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "PLAYER_ENTERING_WORLD",
	"SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_AURA" }

-- Heard only by a mage with it on.
local listening = false
local function Listen()
	local on = On()
	if not driver or on == listening then return end
	listening = on
	if on then
		for _, e in ipairs(EVENTS) do pcall(driver.RegisterEvent, driver, e) end
		for _, e in ipairs(UNIT_EVENTS) do pcall(driver.RegisterUnitEvent, driver, e, "player") end
	else
		for _, e in ipairs(EVENTS) do pcall(driver.UnregisterEvent, driver, e) end
		for _, e in ipairs(UNIT_EVENTS) do pcall(driver.UnregisterEvent, driver, e) end
	end
end

function P.Login()
	local _, token = UnitClass("player")
	class = Safe(token) and token or nil
	-- (Its Main Spell line can be placed from any character in unlock mode.)
	ns.me.RegisterTestPart(KEY, L["Casts Left"])
	if class ~= "MAGE" then
		if ns.Previewing(KEY) then
			BuildMain()
			PaintMain({}, false)
		end
		return
	end
	BuildMain()
	driver = CreateFrame("Frame")
	driver:SetScript("OnEvent", OnEvent)
	Listen()
	ScanSoon()
end

function P.Setting()
	if not driver then return end
	Listen()
	-- (A look setting: the curves are made again with it.)
	wipe(curves)
	for _, s in pairs(spots) do
		Font(s.fs, s.scale)
		Place(s)
	end
	ScanBars()
	if not (On() and G("halo")) then
		for _, s in pairs(spots) do
			if s.kind == "halo" then s.spell = nil end
		end
	end
	Paint()
end

-- A new look: the fonts, and the curves' colors.
function P.Style()
	if not driver then return end
	wipe(curves)
	for _, s in pairs(spots) do Font(s.fs, s.scale) end
	Paint()
end

function P.Preview()
	if not mainFrame and ns.Previewing(KEY) then BuildMain() end
	if mainFrame then PaintMain({}, Showing()) end
end
