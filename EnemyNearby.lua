-- Enemy Nearby: a small list of the enemy players seen near you lately, in the DaylightUI look:
-- their level, their name in their class colour and their guild, the newest at the top. A name
-- fades as time passes without seeing them again, and leaves the list after a while (a choice).
-- Click a name to target that player; right-click it to put them on (or take them off) your Kill
-- on Sight list, which is shared by all your characters. A line in the middle of the screen (and,
-- if you like, a sound) tells you when someone on that list shows up, and, by your choice, when
-- any new enemy does. Move the list and the line with /dui unlock.
--
-- How enemies are seen: the game tells addons nothing of other players through the combat log
-- here, so only the players it names to addons count: the nameplates on screen, your target, your
-- focus and the player under the mouse. Enemy nameplates have to be shown for the list to fill
-- (the switch on its page, or the game's own key, V by default).
--
-- Secret values: in a fight the game may keep what it says about a unit secret from addons. Every
-- read is wrapped (pcall) and checked (ns.Safe) before it's compared or used; a player whose name
-- can't be read is left out quietly.
--
-- Click to target: targeting a player by name is a protected action, so each listed name is
-- covered by a secure button (SecureActionButtonTemplate, "/targetexact Name"). Those buttons can't
-- be made, moved, shown, hidden or given a new name while you're in a fight. So they sit apart from
-- the list (on UIParent, laid over its rows out of a fight), and in a fight the list keeps its
-- order: the players already listed stay in their places (clickable, dimmed once gone) and players
-- seen during the fight are added below them, clickable once it ends. Then it sorts itself again.
--
-- What it costs: nothing while it's off. On, a look at each nameplate as it appears and at your
-- target, focus and mouseover as they change; once a second while anyone is listed or a nameplate
-- is up, a look at the players on screen and the list's fading. No timers otherwise.

local _, ns = ...
if ns.off then return end

local API = ns.API
local KEY = "enemyNearby"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = "Enemy Nearby" })

P.defaults = {
	enabled = true,
	inInstances = false,
	keep = 60,
	maxRows = 8,
	alwaysShow = false,
	alertNew = false,
	soundNew = false,
	alertKos = true,
	soundKos = true,
	throttle = 120,
	width = 210,
	scale = 1,
	alertScale = 1,
}

-- ---------------------------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------------------------

local floor, min, max = math.floor, math.min, math.max

local function Say(msg)
	if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff73a0ffEssentials|r: " .. msg) end
end

-- One read from the game, never an error (nil when it fails).
local function Read(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return a, b
end

-- A yes from the game that can be trusted: readable and true.
local function Yes(v)
	if not Safe(v) then return false end
	return v and true or false
end

-- The enemy nameplates switch (the game's own setting).
local function PlatesShown()
	if C_CVar and C_CVar.GetCVarBool then
		local ok, on = pcall(C_CVar.GetCVarBool, "nameplateShowEnemies")
		return ok and on == true
	end
	return false
end

local function ShowPlates(on)
	if InCombatLockdown() then
		Say("enemy nameplates can be switched after the fight.")
		return false
	end
	if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, "nameplateShowEnemies", on and "1" or "0") end
end

-- ---------------------------------------------------------------------------------------------
-- Kill on Sight: account-wide, in DaylightEssentialsDB.kos (lowercased name -> { name, added })
-- ---------------------------------------------------------------------------------------------

local function KosDB()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if type(db.kos) ~= "table" then db.kos = {} end
	return db.kos
end

-- A typed name tidied: no spaces around it, its first letter capital.
local function Clean(name)
	if type(name) ~= "string" then return nil end
	name = name:match("^%s*(.-)%s*$")
	if name == "" then return nil end
	return (name:gsub("^%l", string.upper))
end

local function IsKos(name)
	return type(name) == "string" and KosDB()[string.lower(name)] ~= nil
end

local PaintSoon -- below

local function KosAdd(name)
	name = Clean(name)
	if not name then return false end
	local db = KosDB()
	local k = string.lower(name)
	if db[k] then
		Say(db[k].name .. " is already on your Kill on Sight list.")
		return false
	end
	db[k] = { name = name, added = time() }
	Say(name .. " is on your Kill on Sight list.")
	PaintSoon()
	return true
end

local function KosRemove(name)
	name = Clean(name)
	if not name then return false end
	local db = KosDB()
	local k = string.lower(name)
	if not db[k] then
		Say(name .. " isn't on your Kill on Sight list.")
		return false
	end
	Say(db[k].name .. " is off your Kill on Sight list.")
	db[k] = nil
	PaintSoon()
	return true
end

local function KosNames()
	local names = {}
	for _, v in pairs(KosDB()) do
		if type(v) == "table" and type(v.name) == "string" then names[#names + 1] = v.name end
	end
	table.sort(names)
	return names
end

-- Your target's name, when it's a player whose name can be read.
local function TargetName()
	if not Yes(Read(UnitIsPlayer, "target")) then return nil end
	local name, realm = Read(UnitName, "target")
	if not Safe(name) or not Safe(realm) or type(name) ~= "string" or name == "" then return nil end
	if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
	return name
end

-- ---------------------------------------------------------------------------------------------
-- The options page
-- ---------------------------------------------------------------------------------------------

local function Off(get) return get(KEY .. ".enabled") == false end

P.page = { id = KEY, label = "Enemy Nearby",
	desc = "Enemy players seen near you lately; click a name to target them.",
	groups = {
		{ label = "Enemy Nearby", items = {
			{ type = "toggle", key = KEY .. ".enabled", label = "On" },
			{ type = "toggle", label = "Show enemy nameplates",
			  desc = "The game's own setting (V by default). The list sees players through their nameplates, your target, focus and mouseover, so enemy nameplates have to be shown. It can't be switched in a fight. Move the list with /dui unlock.",
			  get = PlatesShown, set = ShowPlates },
			{ type = "toggle", key = KEY .. ".inInstances", label = "Also in battlegrounds and dungeons",
			  desc = "Off: the list rests while you're inside an instance.", disabled = Off },
		} },
		{ label = "The list", items = {
			{ type = "slider", key = KEY .. ".keep", label = "Seconds a name stays once unseen", min = 15, max = 300, step = 15,
			  desc = "A name fades as the time passes, and leaves the list at the end. In a fight names stay until it ends.",
			  disabled = Off },
			{ type = "slider", key = KEY .. ".maxRows", label = "Names listed", min = 3, max = 15, step = 1, disabled = Off },
			{ type = "toggle", key = KEY .. ".alwaysShow", label = "Show it when nobody's listed", disabled = Off },
			{ type = "slider", key = KEY .. ".width", label = "Width", min = 160, max = 320, step = 5, unit = "px", disabled = Off },
			{ type = "slider", key = KEY .. ".scale", label = "Size", min = 0.7, max = 1.6, step = 0.05, unit = "%", disabled = Off },
		} },
		{ label = "Alerts", items = {
			{ type = "toggle", key = KEY .. ".alertKos", label = "When someone on my Kill on Sight list shows up", disabled = Off },
			{ type = "toggle", key = KEY .. ".soundKos", label = "Kill on Sight sound",
			  disabled = function(get) return Off(get) or get(KEY .. ".alertKos") == false end },
			{ type = "toggle", key = KEY .. ".alertNew", label = "When any new enemy shows up", disabled = Off },
			{ type = "toggle", key = KEY .. ".soundNew", label = "New enemy sound",
			  disabled = function(get) return Off(get) or get(KEY .. ".alertNew") == false end },
			{ type = "slider", key = KEY .. ".throttle", label = "Seconds before the same player alerts again", min = 30, max = 600, step = 30,
			  disabled = Off },
			{ type = "slider", key = KEY .. ".alertScale", label = "Alert size", min = 0.7, max = 2, step = 0.05, unit = "%", disabled = Off },
		} },
		{ label = "Kill on Sight", items = {
			{ type = "text", label = "Right-click a name in the list to add or remove it, or type /dui kos add Name, /dui kos remove Name or /dui kos list. The list is shared by all your characters; its names show in red, with a mark." },
			{ type = "text", label = function()
				local names = KosNames()
				if #names == 0 then return "On the list: nobody yet." end
				return "On the list: " .. table.concat(names, ", ") .. "."
			end },
			{ type = "button", label = "Add my target", func = function()
				local name = TargetName()
				if name then KosAdd(name) else Say("target a player first.") end
			end },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- Looking at a unit
-- ---------------------------------------------------------------------------------------------

-- An enemy player's key (lowercased full name), name, class, level and guild; nil for anyone
-- else, and for anyone the game won't name to addons right now.
local function Look(unit)
	if not Yes(Read(UnitExists, unit)) then return nil end
	if not Yes(Read(UnitIsPlayer, unit)) then return nil end
	if Yes(Read(UnitIsUnit, unit, "player")) then return nil end
	if not (Yes(Read(UnitCanAttack, "player", unit)) or Yes(Read(UnitIsEnemy, "player", unit))) then return nil end
	local name, realm = Read(UnitName, unit)
	if not Safe(name) or not Safe(realm) or type(name) ~= "string" or name == "" then return nil end
	if UNKNOWNOBJECT and name == UNKNOWNOBJECT then return nil end
	if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
	local _, class = Read(UnitClass, unit)
	if not Safe(class) or type(class) ~= "string" then class = nil end
	local level = Read(UnitLevel, unit)
	if not Safe(level) or type(level) ~= "number" then level = nil end
	local guild = Read(GetGuildInfo, unit)
	if not Safe(guild) or type(guild) ~= "string" or guild == "" then guild = nil end
	return string.lower(name), name, class, level, guild
end

-- ---------------------------------------------------------------------------------------------
-- The alert line
-- ---------------------------------------------------------------------------------------------

local alertFrame, alertBody, alertText
local alertToken = 0
local alertSample = false
local AW, AH = 340, 40
local ALERT_HOME = { "CENTER", UIParent, "CENTER", 0, 220 }
local lastAlert = {}   -- key -> GetTime() of its last alert

local function AlertLook()
	local scale = G("alertScale") or 1
	alertBody:SetScale(scale)
	alertFrame:SetSize(AW * scale, AH * scale)
end

local function AlertGone(t)
	if t == alertToken then alertFrame:Hide() end
end

local function AlertFade(t)
	if t ~= alertToken then return end
	API.Fade(alertFrame, 0, "SLOW")
	C_Timer.After(API.Speed and API.Speed.SLOW or 0.4, function() AlertGone(t) end)
end

-- hold nil: stays (the sample).
local function ShowAlert(msg, role, hold)
	alertToken = alertToken + 1
	local t = alertToken
	alertSample = hold == nil
	alertText:SetText(msg)
	ns.Ink(alertText, role)
	alertFrame:SetAlpha(0)
	alertFrame:Show()
	API.Fade(alertFrame, 1, "FAST")
	if hold then C_Timer.After(hold, function() AlertFade(t) end) end
end

local function ClassName(class)
	local names = LOCALIZED_CLASS_NAMES_MALE
	return class and type(names) == "table" and names[class] or nil
end

local function Sound(kit)
	if kit and PlaySound then pcall(PlaySound, kit, "SFX") end
end

-- A player came into the list: an alert, if they call for one and haven't had one lately.
local function Alert(key, name, class, level)
	local kos = IsKos(name)
	local wantKos = kos and G("alertKos")
	if not wantKos and not G("alertNew") then return end
	local now = GetTime()
	local last = lastAlert[key]
	if last and now - last < (G("throttle") or 120) then return end
	lastAlert[key] = now
	if wantKos then
		ShowAlert("Kill on sight: " .. name, "BAD", 3)
		if G("soundKos") and SOUNDKIT then Sound(SOUNDKIT.RAID_WARNING) end
	else
		local what = ClassName(class)
		local lvl = level and level > 0 and tostring(level) or "??"
		ShowAlert("Enemy: " .. name .. (what and (" (" .. lvl .. " " .. what .. ")") or ""), "WARN", 2.5)
		if G("soundNew") and SOUNDKIT then Sound(SOUNDKIT.ALARM_CLOCK_WARNING_2 or SOUNDKIT.RAID_WARNING) end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------------

local ROW_H, PAD, GAP, LVL_W, TITLE_H = 18, 6, 5, 22, 18

local frame, body, title, empty   -- frame: what /dui unlock moves; body: the list, sized by its setting
local rows = {}
local list, byKey = {}, {}        -- the players listed, in order; key -> entry
local plates = {}                 -- the nameplate units up now
local previewing = false
local awake = false               -- listening for enemies (on, and not resting in an instance)
local ticker

local PREVIEW = {
	{ name = "Shadowstep", class = "ROGUE", level = 60, guild = "Night Watch", kos = true, age = 1 },
	{ name = "Frostweaver", class = "MAGE", level = 58, age = 6 },
	{ name = "Ironhide", class = "WARRIOR", level = -1, guild = "Red Ridge Riders", age = 25 },
	{ name = "Thornpaw", class = "DRUID", level = 44, age = 48 },
}

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, body)
	row:SetHeight(ROW_H)
	row:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -(PAD + TITLE_H + (i - 1) * ROW_H))
	row:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, -(PAD + TITLE_H + (i - 1) * ROW_H))
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetWidth(2)
	row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
	row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
	row.mark:SetColorTexture(1, 1, 1, 1)
	row.level = API.Text(row, "small", "CENTER")
	row.level:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.level:SetWidth(LVL_W)
	row.guild = API.Text(row, "small", "RIGHT")
	row.guild:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.guild:SetWordWrap(false)
	row.name = API.Text(row, "body", "LEFT")
	row.name:SetPoint("LEFT", row.level, "RIGHT", GAP, 0)
	row.name:SetPoint("RIGHT", row.guild, "LEFT", -GAP, 0)
	row.name:SetWordWrap(false)
	-- Right-click works on every row (a plain frame); the left click lives on the secure buttons.
	row:EnableMouse(true)
	row:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" and self.key then P.Menu(self, self.key) end
	end)
	rows[i] = row
	return row
end

local function LevelColor(level)
	if not level or level <= 0 then
		local c = ns.Colors().BAD
		if c then return c[1], c[2], c[3] end
		return 1, 0.3, 0.3
	end
	local fn = GetCreatureDifficultyColor or GetQuestDifficultyColor
	local c = Read(fn, level)
	if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
	c = ns.Colors().VALUE
	if c then return c[1], c[2], c[3] end
	return 1, 1, 1
end

local function FillRow(row, name, class, level, guild, kos, age)
	row.name:SetText(name)
	local r, g, b = 1, 1, 1
	if class then r, g, b = API.ClassColor(class) end
	row.name:SetTextColor(r or 1, g or 1, b or 1)
	row.level:SetText(level and level > 0 and tostring(level) or "??")
	row.level:SetTextColor(LevelColor(level))
	row.guild:SetText(guild and ("<" .. guild .. ">") or "")
	ns.Ink(row.guild, "LABEL")
	row.guild:SetWidth(guild and min(row.guild:GetStringWidth() + 2, (G("width") or 210) * 0.45) or 1)
	if kos then
		local c = ns.Colors().BAD or { 1, 0.3, 0.3 }
		row.mark:SetVertexColor(c[1], c[2], c[3])
		row.mark:Show()
	else
		row.mark:Hide()
	end
	-- Bright while seen, fading over the time a name stays; dim once gone (in a fight it stays).
	local keep = max(15, G("keep") or 60)
	local a = 1
	if age > keep then
		a = 0.35
	elseif age > 5 then
		a = 1 - 0.5 * min(1, (age - 5) / max(1, keep - 5))
	end
	row:SetAlpha(a)
end

-- Where it starts (until it's moved): the right of the screen, above the middle.
local function Home()
	return { "RIGHT", UIParent, "RIGHT", -60, 160 }
end

-- The list's size and its own scale go on the body; the moved frame only takes the size it covers
-- on screen. In a fight only the body grows (downward from the frame's top left), so the rows
-- already listed, and the secure buttons over them, stay where they are.
local sizedAs
local function Size(n, force)
	local h = PAD * 2 + TITLE_H + max(n, 1) * ROW_H
	local fight = InCombatLockdown()
	local sig = h .. ":" .. (G("width") or 210) .. ":" .. (G("scale") or 1) .. (fight and ":f" or "")
	if sig == sizedAs and not force then return false end
	sizedAs = sig
	if fight then
		body:SetHeight(h)
	else
		local w, scale = floor(G("width") or 210), G("scale") or 1
		body:SetSize(w, h)
		body:SetScale(scale)
		frame:SetSize(w * scale, h * scale)
	end
	API.Skin(body, { window = true })
	return true
end

-- ---------------------------------------------------------------------------------------------
-- The secure buttons (click to target)
-- ---------------------------------------------------------------------------------------------

local overlays = {}
local placePending = false
local version, placedVersion = 0, -1   -- version: bumped whenever the list's names or order change

-- The secure buttons wait for the fight's end (heard even with the part switched off meanwhile).
local function Pending()
	placePending = true
	if frame then pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED") end
end

local function Overlay(i)
	local o = overlays[i]
	if o then return o end
	o = CreateFrame("Button", "DaylightEssentialsEnemyNearbyButton" .. i, UIParent, "SecureActionButtonTemplate")
	-- Both: the template itself acts on the one the game's "cast on key down" choice says.
	o:RegisterForClicks("AnyUp", "AnyDown")
	o:SetAttribute("type1", "macro")
	local hl = o:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.08)
	o:HookScript("OnClick", function(self, button, down)
		if button == "RightButton" and not down and self.key then P.Menu(self, self.key) end
	end)
	o:Hide()
	overlays[i] = o
	return o
end

-- Lays the secure buttons over the rows listed now. Out of a fight only; in one, it waits.
local function PlaceOverlays()
	if InCombatLockdown() then
		Pending()
		return
	end
	placePending = false
	placedVersion = version
	if frame and not G("enabled") then pcall(frame.UnregisterEvent, frame, "PLAYER_REGEN_ENABLED") end
	local n = (frame and frame:IsShown() and not previewing) and #list or 0
	local ui = UIParent:GetEffectiveScale()
	for i = 1, n do
		local row, e = rows[i], list[i]
		local l, t = row and row:GetLeft(), row and row:GetTop()
		if not l or not t or not e then
			n = i - 1
			break
		end
		local s = row:GetEffectiveScale() / ui
		local o = Overlay(i)
		o:SetFrameStrata(frame:GetFrameStrata())
		o:SetFrameLevel(frame:GetFrameLevel() + 20)
		o:ClearAllPoints()
		o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
		o:SetSize(row:GetWidth() * s, row:GetHeight() * s)
		o:SetAttribute("macrotext1", "/targetexact " .. e.name)
		o.key = e.key
		o:Show()
	end
	for i = n + 1, #overlays do
		overlays[i]:Hide()
		overlays[i].key = nil
	end
end

local placeQueued = false
local function PlaceNow()
	placeQueued = false
	PlaceOverlays()
end
local function PlaceSoon()
	if placeQueued then return end
	placeQueued = true
	C_Timer.After(0.1, PlaceNow)
end

-- ---------------------------------------------------------------------------------------------
-- Drawing the list
-- ---------------------------------------------------------------------------------------------

local function Paint(force)
	if not frame then return end
	local now = GetTime()
	local n
	if previewing then
		n = #PREVIEW
		for i, p in ipairs(PREVIEW) do
			local row = Row(i)
			row.key = nil
			FillRow(row, p.name, p.class, p.level, p.guild, p.kos, p.age)
			row:Show()
		end
	else
		n = #list
		for i, e in ipairs(list) do
			local row = Row(i)
			row.key = e.key
			FillRow(row, e.name, e.class, e.level, e.guild, IsKos(e.name), now - e.seen)
			row:Show()
		end
	end
	for i = n + 1, #rows do
		rows[i]:Hide()
		rows[i].key = nil
	end
	local moved = force or version ~= placedVersion
	if n == 0 and not (awake and G("alwaysShow")) then
		if frame:IsShown() then moved = true end
		frame:Hide()
	else
		empty:SetShown(n == 0)
		if Size(n, force) then moved = true end
		if not frame:IsShown() then moved = true end
		frame:Show()
	end
	if moved then
		if InCombatLockdown() then Pending() else PlaceSoon() end
	end
end

local paintQueued = false
local function PaintNow()
	paintQueued = false
	Paint()
end
function PaintSoon()
	if paintQueued then return end
	paintQueued = true
	C_Timer.After(0.1, PaintNow)
end

-- Out of a fight: the gone leave, the newest first, no more than fit.
local function Tidy()
	if InCombatLockdown() then return end
	local now, keep = GetTime(), max(15, G("keep") or 60)
	for i = #list, 1, -1 do
		local e = list[i]
		if now - e.seen > keep then
			table.remove(list, i)
			byKey[e.key] = nil
			version = version + 1
		end
	end
	table.sort(list, function(a, b) return a.added > b.added end)
	local cap = max(1, floor(G("maxRows") or 8))
	for i = #list, cap + 1, -1 do
		byKey[list[i].key] = nil
		list[i] = nil
		version = version + 1
	end
end

-- ---------------------------------------------------------------------------------------------
-- Seeing players
-- ---------------------------------------------------------------------------------------------

local Tick -- below

local function StartTicker()
	if not ticker then ticker = C_Timer.NewTicker(1, function() Tick() end) end
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function Spot(unit)
	local key, name, class, level, guild = Look(unit)
	if not key then return end
	local now = GetTime()
	local e = byKey[key]
	if e then
		e.seen = now
		e.name = name
		if class then e.class = class end
		if level then e.level = level end
		if guild then e.guild = guild end
	else
		local cap = max(1, floor(G("maxRows") or 8))
		e = { key = key, name = name, class = class, level = level, guild = guild, seen = now, added = now }
		if InCombatLockdown() then
			-- In a fight the order holds (the secure buttons can't follow): below the others.
			if #list < cap then
				list[#list + 1] = e
				byKey[key] = e
			end
		else
			table.insert(list, 1, e)
			byKey[key] = e
			for i = #list, cap + 1, -1 do
				byKey[list[i].key] = nil
				list[i] = nil
			end
		end
		version = version + 1
		Alert(key, name, class, level)
		PaintSoon()
		StartTicker()
	end
	-- A Kill on Sight name typed in lower case takes the game's spelling.
	local kos = KosDB()[key]
	if kos and kos.name ~= name then kos.name = name end
	return key
end

-- Nameplates are followed only for players (their names may be secret for now, readable later).
local function Plate(unit)
	if Yes(Read(UnitIsPlayer, unit)) then
		plates[unit] = true
		Spot(unit)
		StartTicker()
	else
		plates[unit] = nil
	end
end

function Tick()
	if not awake then
		StopTicker()
		return
	end
	for unit in pairs(plates) do Spot(unit) end
	Spot("target")
	Spot("focus")
	Tidy()
	Paint()
	if #list == 0 and next(plates) == nil then StopTicker() end
end

-- Everyone in sight now (as it wakes).
local function Sweep()
	wipe(plates)
	for i = 1, 40 do
		local unit = "nameplate" .. i
		if Yes(Read(UnitExists, unit)) then Plate(unit) end
	end
	Spot("target")
	Spot("focus")
end

local function Clear()
	wipe(list)
	wipe(byKey)
	wipe(plates)
	version = version + 1
	StopTicker()
end

-- ---------------------------------------------------------------------------------------------
-- Waking and resting
-- ---------------------------------------------------------------------------------------------

local BASE = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }
local DETECT = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
	"UPDATE_MOUSEOVER_UNIT", "PLAYER_FOCUS_CHANGED" }

local function Listen(events, on)
	for _, e in ipairs(events) do
		if on then pcall(frame.RegisterEvent, frame, e) else pcall(frame.UnregisterEvent, frame, e) end
	end
end

local function ShouldWake()
	if not G("enabled") then return false end
	if G("inInstances") then return true end
	local inside = Read(IsInInstance)
	return not Yes(inside)
end

local function Update()
	if not frame then return end
	Listen(BASE, G("enabled") == true)
	local on = ShouldWake()
	if on ~= awake then
		awake = on
		Listen(DETECT, on)
		if on then Sweep() else Clear() end
	end
	Paint()
end

local function OnEvent(_, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		if type(unit) == "string" then Plate(unit) end
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		if type(unit) == "string" then plates[unit] = nil end
	elseif event == "PLAYER_TARGET_CHANGED" then
		Spot("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		Spot("mouseover")
	elseif event == "PLAYER_FOCUS_CHANGED" then
		Spot("focus")
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- The fight's names join the order; the list and its buttons are laid out again.
		version = version + 1
		Tidy()
		Paint(true)
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Nothing to do: the list holds its order from here on.
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		PlaceSoon()
	else
		Update()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Right-click menu
-- ---------------------------------------------------------------------------------------------

function P.Menu(owner, key)
	local e = byKey[key]
	if not e then return end
	local name = e.name
	local kos = IsKos(name)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle(name)
			if kos then
				root:CreateButton("Take off Kill on Sight", function() KosRemove(name) end)
			else
				root:CreateButton("Add to Kill on Sight", function() KosAdd(name) end)
			end
			if not InCombatLockdown() then
				root:CreateButton("Take off this list", function()
					if InCombatLockdown() or not byKey[key] then return end
					for i, x in ipairs(list) do
						if x.key == key then
							table.remove(list, i)
							break
						end
					end
					byKey[key] = nil
					version = version + 1
					Paint()
				end)
			end
		end)
	elseif kos then
		KosRemove(name)
	else
		KosAdd(name)
	end
end

-- ---------------------------------------------------------------------------------------------
-- /dui kos
-- ---------------------------------------------------------------------------------------------

local function Command(rest)
	rest = type(rest) == "string" and rest or ""
	local word, arg = rest:match("^%s*(%S*)%s*(.-)%s*$")
	word = string.lower(word or "")
	if word == "add" then
		local name = (arg ~= "" and arg) or TargetName()
		if name then KosAdd(name) else Say("/dui kos add Name (or target a player).") end
	elseif word == "remove" or word == "del" or word == "rm" then
		local name = (arg ~= "" and arg) or TargetName()
		if name then KosRemove(name) else Say("/dui kos remove Name (or target a player).") end
	elseif word == "" or word == "list" then
		local names = KosNames()
		if #names == 0 then
			Say("your Kill on Sight list is empty. /dui kos add Name to add someone.")
		else
			Say("Kill on Sight (" .. #names .. "): " .. table.concat(names, ", "))
		end
	else
		Say("/dui kos add Name, /dui kos remove Name, /dui kos list.")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Building, settings, samples
-- ---------------------------------------------------------------------------------------------

local function ShowSamples()
	previewing = G("enabled") and ns.Previewing(KEY) or false
	if previewing then
		ShowAlert("Kill on sight: " .. PREVIEW[1].name, "BAD", nil)
	elseif alertSample then
		alertSample = false
		alertToken = alertToken + 1
		alertFrame:Hide()
	end
end

local function Build()
	if frame then return end
	frame = CreateFrame("Frame", "DaylightEssentialsEnemyNearby", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:Hide()
	body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	title = API.Text(body, "small", "LEFT")
	title:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + 1, -PAD)
	title:SetText("Enemies nearby")
	ns.Ink(title, "LABEL")
	empty = API.Text(body, "small", "LEFT")
	empty:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + 1, -(PAD + TITLE_H + 3))
	empty:SetText("Nobody seen lately")
	ns.Ink(empty, "OFF")
	empty:Hide()
	frame:SetScript("OnEvent", OnEvent)
	Size(1)
	-- Placed now: after a /reload in a fight, the mover only places it once the fight ends.
	frame:SetPoint(unpack(Home()))
	ns.me.RegisterMover(frame, KEY, "Enemies nearby", Home)
	-- When the list is moved (a profile, the mover), the secure buttons follow it.
	hooksecurefunc(frame, "SetPoint", function() PlaceSoon() end)

	alertFrame = CreateFrame("Frame", "DaylightEssentialsEnemyAlert", UIParent)
	alertFrame:SetSize(AW, AH)
	alertFrame:SetFrameStrata("HIGH")
	alertFrame:SetClampedToScreen(true)
	alertFrame:Hide()
	alertBody = CreateFrame("Frame", nil, alertFrame)
	alertBody:SetSize(AW, AH)
	alertBody:SetPoint("TOPLEFT", alertFrame, "TOPLEFT", 0, 0)
	alertText = API.Text(alertBody, "title", "CENTER")
	alertText:SetPoint("CENTER", alertBody, "CENTER", 0, 0)
	AlertLook()
	alertFrame:SetPoint(unpack(ALERT_HOME))
	ns.me.RegisterMover(alertFrame, KEY .. "Alert", "Enemy alert", ALERT_HOME)

	ns.me.RegisterTestPart(KEY, "Enemies nearby")
	ns.me.RegisterCommand("kos", Command, "kos add|remove|list Name: your Kill on Sight list")
end

function P.Login()
	Build()
	ShowSamples()
	Update()
end

function P.Setting()
	if not frame then return end
	AlertLook()
	ShowSamples()
	Update()
	Tidy()
	PaintSoon()
end

function P.Style()
	if not frame then return end
	ns.Ink(title, "LABEL")
	ns.Ink(empty, "OFF")
	PaintSoon()
end

function P.Preview()
	if not frame then return end
	ShowSamples()
	Paint(true)
end
