-- Healer Mana: a small list of your group's healers with the mana each has left, in the DaylightUI
-- look: their class icon, their name in their class color and their mana as a percent, colored
-- by how much is left. It shows while you're in a group with a healer in it; move it with
-- /dui unlock.
--
-- Who's a healer: the role the group gave them (the group finder, or a leader's role check). WoW:
-- Forever has no specs, and groups often set no roles; then, by your choice, the classes that can
-- heal (priest, druid, shaman, paladin), or nobody.
--
-- The mana: the game can keep other players' mana secret from addons (in a fight, in some places).
-- A secret value can't be compared, added up or turned into text by an addon's own code, but the
-- game's own functions take it: the game is asked for the mana as a percent (UnitPowerPercent),
-- and that percent goes straight into the text's own formatting (SetFormattedText), so the text
-- works in a fight as well as out of one. Its color comes the same way, from a color curve the
-- game reads the secret through. Nothing secret is ever looked at here.
--
-- What it costs: nothing while you're alone or no healer is listed. In a group it listens to the
-- game's mana updates and redraws only the healer whose mana changed; the list itself is made
-- again only when the group changes. No timers.

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "healerMana"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["Healer Mana"] })

P.defaults = {
	enabled = true,
	inParty = true,
	inRaid = true,
	allClasses = true,        -- with no roles set in the group: every healing class counts (off: nobody)
	includeSelf = false,
	maxRaid = 5,
	colorByMana = true,
	drinking = true,
	lowGlow = true,
	scale = 1,
	width = 170,
}

P.page = { id = KEY, label = L["Healer Mana"],
	desc = L["Your group's healers and the mana each has left."],
	groups = {
		{ label = L["Healer Mana"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
		} },
		{ label = L["When It Shows"], items = {
			{ type = "toggle", key = KEY .. ".inParty", label = L["In Party"] },
			{ type = "toggle", key = KEY .. ".inRaid", label = L["In Raid"] },
			{ type = "slider", key = KEY .. ".maxRaid", label = L["Raid Healer List Count"], min = 1, max = 10, step = 1,
			  desc = L["The first healers of the raid, in its order."],
			  disabled = function(get) return get(KEY .. ".inRaid") == false end },
			{ type = "toggle", key = KEY .. ".includeSelf", label = L["Show Self"],
			  desc = L["Your own mana in the list when you're one of the healers."] },
		} },
		{ label = L["Set Healer"], items = {
			{ type = "toggle", key = KEY .. ".allClasses", label = L["Show All Healing Classes"],
			  desc = L["Players the group gave the healer role (the group finder or a role check) are always the healers. When the group has set no roles: on lists every priest, druid, shaman and paladin; off lists only players given the healer role."] },
		} },
		{ label = L["Look"], items = {
			{ type = "toggle", key = KEY .. ".colorByMana", label = L["Color Mana Percent"],
			  desc = L["Red when nearly out, yellow when low, bright above. Works in a fight too."] },
			{ type = "toggle", key = KEY .. ".drinking", label = L["Show Drinking Status"],
			  desc = L["While a healer drinks, their line becomes their mana bar, filling as they drink, with \"Drinking\" on it."] },
			{ type = "toggle", key = KEY .. ".lowGlow", label = L["Glow When Low"],
			  desc = L["Daylight UI's glow runs round a healer's line below 20% mana."] },
			{ type = "slider", key = KEY .. ".width", label = L["Width"], min = 130, max = 260, step = 5, unit = "px",
			  desc = L["At least this wide: it grows to fit a long name."] },
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 1.6, step = 0.05, unit = "%" },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- Who's a healer
-- ---------------------------------------------------------------------------------------------

local HEALING_CLASS = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }

local function RoleOf(unit)
	if not UnitGroupRolesAssigned then return "NONE" end
	local ok, role = pcall(UnitGroupRolesAssigned, unit)
	if not ok or not Safe(role) then return "NONE" end
	return role or "NONE"
end

local function ClassOf(unit)
	local _, class = UnitClass(unit)
	if not Safe(class) then return nil end
	return class
end

-- The group's units, in order (raid1..n, or you then party1..4).
local units = {}
local function GroupUnits()
	wipe(units)
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		for i = 1, 4 do units[#units + 1] = "party" .. i end
	end
	return units
end

-- The healers to list, as units (reused).
local healers = {}
local function FindHealers()
	wipe(healers)
	local raid = IsInRaid()
	if not G("enabled") or not IsInGroup() or (raid and not G("inRaid")) or (not raid and not G("inParty")) then
		return healers
	end
	local max = raid and math.max(1, math.floor(G("maxRaid") or 5)) or 5
	local withSelf = G("includeSelf")
	local any = false
	for _, unit in ipairs(GroupUnits()) do
		if UnitExists(unit) and RoleOf(unit) ~= "NONE" then
			any = true
			break
		end
	end
	local byClass = not any and G("allClasses") ~= false
	for _, unit in ipairs(units) do
		if #healers >= max then break end
		if UnitExists(unit) and (withSelf or not UnitIsUnit(unit, "player")) then
			local healer
			if any then
				healer = RoleOf(unit) == "HEALER"
			elseif byClass then
				healer = HEALING_CLASS[ClassOf(unit) or ""] == true
			end
			if healer then healers[#healers + 1] = unit end
		end
	end
	return healers
end

-- ---------------------------------------------------------------------------------------------
-- The mana, secret or not
-- ---------------------------------------------------------------------------------------------

local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
-- The look's inks for low mana (its BAD and WARN, read again after every look change: P.Style);
-- these only if the look has none.
local FALLBACK = { BAD = { 0.95, 0.35, 0.35 }, WARN = { 1, 0.8, 0.3 } }
local function Ink3(role)
	local c = ns.Colors()[role]
	return type(c) == "table" and c or FALLBACK[role] or ns.Colors().VALUE
end

-- The color the mana text takes: the look's bad ink when nearly out, its warning ink when low, the
-- bright ink above. A curve the game reads the (maybe secret) percent through; built once per style.
local STOPS = { { 0, "BAD" }, { 0.2, "BAD" }, { 0.35, "WARN" }, { 0.5, "WARN" }, { 0.65, "VALUE" }, { 1, "VALUE" } }
local manaCurve
local function ManaCurve()
	if manaCurve ~= nil then return manaCurve or nil end
	manaCurve = false
	if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
	local ok, c = pcall(C_CurveUtil.CreateColorCurve)
	if not ok or not c then return nil end
	if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
		pcall(c.SetType, c, Enum.LuaCurveType.Linear)
	end
	for _, stop in ipairs(STOPS) do
		local rgb = Ink3(stop[2])
		c:AddPoint(stop[1], CreateColor(rgb[1], rgb[2], rgb[3], 1))
	end
	manaCurve = c
	return c
end

local function SetPct(fs, unit)
	fs:SetFormattedText("%.0f%%", UnitPowerPercent(unit, MANA, false, CurveConstants.ScaleTo100))
end

-- Below 20% mana: DaylightUI's glow round the healer's line, in the low red (row.glow, a frame over
-- the line that holds it). Readable mana is compared here. Secret mana (in a fight) never is: it
-- goes through a step curve the game reads it through, whose answer (full below 20%, nothing above)
-- becomes the holder's alpha, so the glow runs all along and only shows below 20%. If the game
-- won't take that answer as an alpha, the line keeps the glow it had when the mana was last read.
-- Not while the healer drinks (their mana is coming back), is dead or offline.
local LOW_AT = 0.2
local LOW_GLOW = {}   -- (the look's bad ink: GlowInk)
local function GlowInk()
	local c = Ink3("BAD")
	LOW_GLOW.r, LOW_GLOW.g, LOW_GLOW.b = c[1], c[2], c[3]
	return LOW_GLOW
end
local lowCurve
local function LowCurve()
	if lowCurve ~= nil then return lowCurve or nil end
	lowCurve = false
	if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
	local ok, c = pcall(C_CurveUtil.CreateColorCurve)
	if not ok or not c then return nil end
	if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
		pcall(c.SetType, c, Enum.LuaCurveType.Step)
	end
	c:AddPoint(0, CreateColor(1, 1, 1, 1))
	c:AddPoint(LOW_AT, CreateColor(1, 1, 1, 0))
	lowCurve = c
	return c
end

local function PaintLow(row, unit)
	local holder = row.glow
	if not holder then return end
	if G("lowGlow") == false or row.dead or row.off or row.drinking or not unit then
		ns.Glow(holder, false)
		holder:SetAlpha(1)
		return
	end
	local cur, max = UnitPower(unit, MANA), UnitPowerMax(unit, MANA)
	if Safe(cur) and Safe(max) and type(cur) == "number" and type(max) == "number" and max > 0 then
		holder:SetAlpha(1)
		ns.Glow(holder, cur / max < LOW_AT, GlowInk())
		return
	end
	local curve = UnitPowerPercent and LowCurve()
	if not curve then return end
	local ok, col = pcall(UnitPowerPercent, unit, MANA, false, curve)
	if not (ok and type(col) == "table" and col.GetRGBA) then return end
	local okA, _, _, _, a = pcall(col.GetRGBA, col)
	if okA and pcall(holder.SetAlpha, holder, a) then ns.Glow(holder, true, GlowInk()) end
end

local function PaintMana(fs, unit)
	if UnitPowerPercent and CurveConstants then
		-- Formatted by the game itself: a secret percent is fine here.
		local ok = pcall(SetPct, fs, unit)
		if not ok then fs:SetText("?") end
	else
		-- An older client: the plain numbers, while they can be read.
		local cur, max = UnitPower(unit, MANA), UnitPowerMax(unit, MANA)
		if Safe(cur) and Safe(max) and type(max) == "number" and max > 0 then
			fs:SetFormattedText("%.0f%%", cur / max * 100)
		else
			fs:SetText("?")
		end
	end
	local curve = G("colorByMana") and UnitPowerPercent and ManaCurve()
	if curve then
		local ok, col = pcall(UnitPowerPercent, unit, MANA, false, curve)
		if ok and type(col) == "table" and col.GetRGB then
			pcall(fs.SetTextColor, fs, col:GetRGB())
			return
		end
	end
	ns.Ink(fs, "VALUE")
end

-- ---------------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------------

local ROW_H, PAD, ICON, GAP, MANA_W = 20, 6, 16, 6, 44
local TITLE_H = 18
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

local frame, body, title   -- frame: what /dui unlock moves; body: the list, sized by its setting
local rows = {}
local rowOf = {}            -- unit -> its row, for the units listed now
local previewing = false

local DRINK_BAR = { 0.25, 0.5, 1 }   -- mana blue

local PREVIEW = {
	{ name = "Lightwell", class = "PRIEST", pct = 82 },
	{ name = "Barkskin", class = "DRUID", pct = 41, drinking = true },
	{ name = "Tidecaller", class = "SHAMAN", pct = 14 },
}

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, body)
	row:SetHeight(ROW_H)
	row:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -(PAD + TITLE_H + (i - 1) * ROW_H))
	row:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, -(PAD + TITLE_H + (i - 1) * ROW_H))
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON, ICON)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexture(CLASS_ICONS)
	-- Drinking: the line becomes their mana bar, filling as they drink, with "Drinking" on it.
	row.bar = API.Bar(row)
	row.bar:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", GAP - 2, 1)
	row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(0)
	if row.bar.SetStatusBarColor then row.bar:SetStatusBarColor(DRINK_BAR[1], DRINK_BAR[2], DRINK_BAR[3]) end
	row.bar:Hide()
	local top = CreateFrame("Frame", nil, row)
	top:SetAllPoints()
	top:SetFrameLevel(row.bar:GetFrameLevel() + 2)
	row.mana = API.Text(top, "body", "RIGHT")
	row.mana:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.mana:SetWidth(MANA_W)
	row.name = API.Text(top, "body", "LEFT")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", GAP, 0)
	row.name:SetPoint("RIGHT", row.mana, "LEFT", -GAP, 0)
	row.name:SetWordWrap(false)
	-- (Holds the low-mana glow: PaintLow.)
	row.glow = CreateFrame("Frame", nil, row)
	row.glow:SetAllPoints()
	row.glow:SetFrameLevel(top:GetFrameLevel() + 1)
	rows[i] = row
	return row
end

-- Drinking: the "Drink" buff (by the game's spell, so in its language), and "Refreshment".
local drinkNames
local function DrinkNames()
	if drinkNames then return drinkNames end
	local t = {}
	for _, id in ipairs({ 430, 43180 }) do   -- Drink, Refreshment
		local ok, n = pcall(C_Spell.GetSpellName, id)
		if ok and Safe(n) and type(n) == "string" then t[#t + 1] = n end
	end
	-- (Kept once the game names Drink; until then asked again, with the English word meanwhile.
	-- Refreshment is only added when this game has it.)
	if #t > 0 then drinkNames = t else t[1] = "Drink" end
	return t
end

-- Whether the healer is drinking now, or nil when it can't be read (a fight: they can't drink then).
local function Drinking(unit)
	if not G("drinking") then return false end
	local find = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if not find then return nil end
	for _, name in ipairs(DrinkNames()) do
		local ok, aura = pcall(find, unit, name, "HELPFUL")
		if not ok or not Safe(aura) then return nil end
		if aura then return true end
	end
	return false
end

local function PaintClass(row, class)
	row.class = class
	row.icon:SetDesaturated(false)
	row.icon:SetAlpha(1)
	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if coords then
		row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		row.icon:Show()
	else
		row.icon:Hide()
	end
	local r, g, b = 1, 1, 1
	if class then r, g, b = API.ClassColor(class) end
	row.name:SetTextColor(r or 1, g or 1, b or 1)
end

-- A dead or offline healer: the whole line grayed (name and class icon), so it reads at a glance.
local function GrayLine(row)
	PaintLow(row, nil)
	row.bar:Hide()
	ns.Ink(row.name, "OFF")
	row.icon:SetDesaturated(true)
	row.icon:SetAlpha(0.6)
end

-- A drinking healer's line: the bar at their mana and "Drinking"; or back to the plain line.
local function PaintDrink(row, unit)
	if row.drinking then
		pcall(row.bar.SetMinMaxValues, row.bar, 0, UnitPowerMax(unit, MANA))
		pcall(row.bar.SetValue, row.bar, UnitPower(unit, MANA))
		row.bar:Show()
		row.mana:SetText(L["Drinking"])
		ns.Ink(row.mana, "VALUE")
	else
		row.bar:Hide()
		PaintMana(row.mana, unit)
	end
	PaintLow(row, unit)
end

-- One healer's line: its name, class and state, then its mana.
local function FillRow(row, unit)
	local name = UnitName(unit)
	if not Safe(name) or not name then name = L["Healer"] end
	row.name:SetText(name)
	-- (Unreadable means a fight, where nobody drinks: a reused row never keeps the last one's.)
	row.drinking = Drinking(unit) == true
	PaintClass(row, ClassOf(unit))
	local connected = UnitIsConnected(unit)
	row.off = Safe(connected) and connected == false
	if row.off or (Safe(UnitIsDeadOrGhost(unit)) and UnitIsDeadOrGhost(unit)) then row.bar:Hide() end
	if row.off then
		row.dead = false
		row.mana:SetText(L["Offline"])
		ns.Ink(row.mana, "OFF")
		GrayLine(row)
		return
	end
	local dead = UnitIsDeadOrGhost(unit)
	row.dead = Safe(dead) and dead == true
	if row.dead then
		row.mana:SetText(L["Dead"])
		ns.Ink(row.mana, "BAD")
		GrayLine(row)
		return
	end
	PaintDrink(row, unit)
end

-- Where it starts (until it's moved): snapped under the party frames, centered on them, edge to edge
-- (as /dui unlock's magnet snaps them); the left of the screen without them.
local function Home()
	local party = ns.MoverFrame("unitframes.party")
	if party then return { "TOP", party, "BOTTOM", 0, 0 } end
	return { "LEFT", UIParent, "LEFT", 40, 120 }
end

-- The list's size and its own scale go on the body; the moved frame only takes the size it covers
-- on screen (DaylightUI's mover keeps the moved frame's scale its own).
-- At least the Width setting, wider when a name or a word ("Offline") needs it: nothing is cut
-- short. Names are plain text (a secret one shows as "Healer"); mana percents are kept to a
-- column wide enough for "100%". Widths that can't be read keep the last ones measured.
local lastNameW, lastManaW = 0, 0
local sizedW, sizedH, sizedScale   -- what Size last set (nil: set it again)
local function Size(n)
	local nameW, manaW = 0, 0
	local nameOk, manaOk = true, true
	for i = 1, n do
		local row = rows[i]
		if row and row:IsShown() then
			local nw = ns.TextWidth(row.name)
			if nw then nameW = math.max(nameW, nw) else nameOk = false end
			if row.off or row.dead or row.drinking then
				local mw = ns.TextWidth(row.mana)
				if mw then manaW = math.max(manaW, mw) else manaOk = false end
			end
		end
	end
	if nameOk then lastNameW = nameW else nameW = math.max(nameW, lastNameW) end
	if manaOk then lastManaW = manaW else manaW = math.max(manaW, lastManaW) end
	local manaCol = math.max(MANA_W, math.ceil(manaW) + 2)
	for i = 1, #rows do rows[i].mana:SetWidth(manaCol) end
	local need = PAD * 2 + ICON + GAP + math.ceil(nameW) + 2 + GAP + manaCol
	local titleW = ns.TextWidth(title) or 0
	local w = math.max(math.floor(G("width") or 170), need, math.ceil(titleW) + PAD * 2 + 2)
	local h = PAD * 2 + TITLE_H + n * ROW_H
	local scale = G("scale") or 1
	if w == sizedW and h == sizedH and scale == sizedScale then return end
	sizedW, sizedH, sizedScale = w, h, scale
	body:SetSize(w, h)
	body:SetScale(scale)
	frame:SetSize(w * scale, h * scale)
	ns.SkinWindow(body, nil, KEY)
end

-- The per-unit events: each listed healer's row hears its own unit only (RegisterUnitEvent), and
-- nothing is heard while nobody is listed. (Every unit if this client lacks RegisterUnitEvent: the
-- handler still looks the unit up.)
local ROW_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_HEALTH", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_AURA" }
local OnEvent   -- below
local function ListenRow(row, unit)
	local ev = row.ev
	if not ev then
		ev = CreateFrame("Frame")
		ev:SetScript("OnEvent", function(...) OnEvent(...) end)
		row.ev = ev
	end
	ev:UnregisterAllEvents()
	-- Your own row in a raid: the game may speak of you as "player" rather than "raidN".
	local okU, me = pcall(UnitIsUnit, unit, "player")
	local alias = (unit ~= "player" and okU and Safe(me) and me == true) and "player" or nil
	for _, e in ipairs(ROW_EVENTS) do
		local ok
		if alias then ok = pcall(ev.RegisterUnitEvent, ev, e, unit, alias)
		else ok = pcall(ev.RegisterUnitEvent, ev, e, unit) end
		if not ok then pcall(ev.RegisterEvent, ev, e) end
	end
end
local function Unlisten(from)
	for i = from or 1, #rows do
		local ev = rows[i].ev
		if ev then ev:UnregisterAllEvents() end
	end
end

-- The list made again from the group.
local function Rebuild()
	if not frame then return end
	wipe(rowOf)
	if previewing then
		for i, p in ipairs(PREVIEW) do
			local row = Row(i)
			row.name:SetText(p.name)
			row.drinking = p.drinking and G("drinking") or false
			PaintClass(row, p.class)
			if row.drinking then
				row.bar:SetMinMaxValues(0, 100)
				row.bar:SetValue(p.pct)
				row.bar:Show()
				row.mana:SetText(L["Drinking"])
				ns.Ink(row.mana, "VALUE")
			else
				row.bar:Hide()
				row.mana:SetFormattedText("%d%%", p.pct)
				local c = Ink3(p.pct <= 20 and "BAD" or p.pct <= 50 and "WARN" or "VALUE")
				row.mana:SetTextColor(c[1], c[2], c[3])
			end
			-- (The sample's low healer glows too.)
			row.glow:SetAlpha(1)
			ns.Glow(row.glow, G("lowGlow") ~= false and not row.drinking and p.pct < LOW_AT * 100, GlowInk())
			row:Show()
		end
		for i = #PREVIEW + 1, #rows do rows[i]:Hide() end
		Size(#PREVIEW)
		Unlisten(1)
		frame:Show()
		return
	end
	local list = FindHealers()
	for i, unit in ipairs(list) do
		local row = Row(i)
		rowOf[unit] = row
		-- Your own row in a raid: the game may speak of you as "player" rather than "raidN".
		if UnitIsUnit(unit, "player") then rowOf.player = row end
		FillRow(row, unit)
		ListenRow(row, unit)
		row:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	Unlisten(#list + 1)
	if #list == 0 then
		frame:Hide()
		return
	end
	Size(#list)
	frame:Show()
end

local rebuildQueued = false
local function RebuildNow()
	rebuildQueued = false
	Rebuild()
end
local function RebuildSoon()
	if rebuildQueued then return end
	rebuildQueued = true
	C_Timer.After(0.2, RebuildNow)
end

-- A healer's line changed its words ("Dead", "Offline"): the box fits them again.
local function Refit()
	local n = 0
	for i = 1, #rows do if rows[i]:IsShown() then n = i end end
	if n > 0 then Size(n) end
end

function OnEvent(_, event, unit, kind)
	if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
		local row = rowOf[unit]
		if row and not row.dead and not row.off and (kind == nil or kind == "MANA") then
			if row.drinking then
				pcall(row.bar.SetMinMaxValues, row.bar, 0, UnitPowerMax(unit, MANA))
				pcall(row.bar.SetValue, row.bar, UnitPower(unit, MANA))
			else
				PaintMana(row.mana, unit)
				PaintLow(row, unit)
			end
		end
	elseif event == "UNIT_HEALTH" then
		-- Health ticks often: the line is only redrawn when the healer dies or comes back.
		local row = rowOf[unit]
		if not row then return end
		local dead = UnitIsDeadOrGhost(unit)
		if Safe(dead) and (dead == true) ~= (row.dead == true) then
			FillRow(row, unit)
			Refit()
		end
	elseif event == "UNIT_AURA" then
		-- Started or stopped drinking: its line only.
		local row = rowOf[unit]
		if not row or row.dead or row.off then return end
		-- Only a buff gained or lost can start or end a drink (not a timer or stack refresh).
		-- (Fields the game hides count as a change.)
		if type(kind) == "table" and Safe(kind) then
			local full, added, removed = kind.isFullUpdate, kind.addedAuras, kind.removedAuraInstanceIDs
			if Safe(full) and Safe(added) and Safe(removed) and not full and not added and not removed then
				return
			end
		end
		local drinking = Drinking(unit)
		-- Buffs unreadable in a fight: nobody drinks in one, so a drink that was showing has ended.
		if drinking == nil and InCombatLockdown() then drinking = false end
		if drinking ~= nil and drinking ~= (row.drinking == true) then
			row.drinking = drinking
			PaintDrink(row, unit)
			Refit()
		end
	elseif event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
		-- Offline (or back): its line only.
		local row = rowOf[unit]
		if row then
			FillRow(row, unit)
			Refit()
		end
	else
		RebuildSoon()
	end
end

local function Build()
	if frame then return end
	frame = CreateFrame("Frame", "DaylightEssentialsHealerMana", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:Hide()
	body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	title = API.Text(body, "small", "LEFT")
	title:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + 1, -PAD)
	title:SetText(L["Healer Mana"])
	ns.Ink(title, "LABEL")
	frame:SetScript("OnEvent", OnEvent)
	-- (A healer's connection, flags, health and mana: heard by its own row, ListenRow.)
	for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD" }) do
		frame:RegisterEvent(e)
	end
	Size(1)
	-- Placed now: after a /reload in a fight, the mover only places it once the fight ends.
	frame:SetPoint(unpack(Home()))
	ns.me.RegisterMover(frame, KEY, L["Healer Mana"], Home)
	-- Comes up with DaylightUI's fade-in on login and /reload (the inner box: the frame's own alpha is left alone).
	ns.FadeIn(KEY, function() return { body } end)
	ns.me.RegisterTestPart(KEY, L["Healer Mana"])
end

-- 1.2.0's "When the group has no roles" (Healing classes / Nobody) is the switch now: Nobody
-- carries over as off, once.
local function MoveNoRoles()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if db.noRolesMoved then return end
	db.noRolesMoved = true
	local ok, old = pcall(API.GetSetting, ns.ADDON, KEY .. ".noRoles")
	if ok and old == "none" then pcall(ns.DUI.Set, ns.DUI, ns.ADDON, KEY .. ".allClasses", false) end
end

function P.Login()
	MoveNoRoles()
	Build()
	previewing = G("enabled") and ns.Previewing(KEY)
	Rebuild()
end

function P.Setting()
	if not frame then return end
	previewing = G("enabled") and ns.Previewing(KEY)
	RebuildSoon()
end

function P.Style()
	manaCurve = nil
	sizedW = nil   -- (skinned again on the next size)
	if not frame then return end
	ns.Ink(title, "LABEL")
	RebuildSoon()
end

function P.Preview()
	if not frame then return end
	previewing = G("enabled") and ns.Previewing(KEY)
	Rebuild()
end
