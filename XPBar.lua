-- XP Bar: an experience bar with the numbers a leveling player asks about, under the quest tracker
-- (or free, anywhere you move it), with its window or without (Windowless).
--   * The bar: this level's XP, the XP your finished quests will give you (green, right after the
--     fill) and your rested XP (purple, after that), as the game's and Daylight UI's bars show them.
--   * Under it, each on its own switch: the time to level at your rate, XP per hour, XP per kill
--     over the last hour, kills to level, the quests ready to turn in and where they take the bar,
--     the XP of your whole quest log, your rested XP and this session's totals.
-- Docked, it hangs under the quest tracker at its width and follows it as the list grows, shrinks
-- or moves: Daylight UI's tracker, else the game's. When RestedXP's guide is docked under or in
-- place of the tracker (Addon Skins), it hangs under the guide instead. No room under it (a tall
-- list near the bottom of the screen): just above the tracker. Free, it's moved with /dui unlock
-- (/glowey unlock without Daylight UI) or the page's Move Window.
-- "Replace Other XP Bars": while this shows, Daylight UI's XP bar is switched off through its plugin
-- API (me.Override, never saved: turning this off, logging out or changing it yourself gives it
-- back), or without Daylight UI the game's own bar is kept hidden. At the level cap this hides and
-- they come back (Daylight UI's bar shows your reputation there).
--
-- Where the numbers come from:
--   * XP gained: the change in UnitXP at each PLAYER_XP_UPDATE (across a level-up too).
--   * Which kind: a quest turned in says how much XP it gave (QUEST_TURNED_IN's xpReward); that part
--     of a gain is the quest's. Each kill's XP line in chat (CHAT_MSG_COMBAT_XP_GAIN) marks a kill:
--     its text is read when the game lets it be ("Kobold dies, you gain 120 experience"), else any
--     such line in a fight or just after one counts as a kill. What's left is "other" (exploring,
--     gathering). The three are put together a moment after the gain, since the game sends them in
--     no set order.
--   * Rate: the XP of the last hour (or of this session, when it's younger), per hour. Time to
--     level: what's left of the level at that rate.
--   * Quests: the reward XP of each quest in the log (GetQuestLogRewardXP), finished ones apart.
-- Nothing runs on a clock: the numbers are worked out again at each gain, quest log change, fight's
-- end, and when the box is shown or hovered (a time-to-level read then is the rate of that moment).
-- The last hour's gains and the session are kept per character (DaylightEssentialsDB.xpBar, by
-- GUID), so a /reload keeps them; a new login starts a new session.

-- luacheck: read globals UnitXP UnitXPMax UnitLevel UnitGUID GetXPExhaustion IsPlayerAtEffectiveMaxLevel
-- luacheck: read globals GetMaxPlayerLevel GetQuestLogRewardXP C_QuestLog C_Timer BreakUpLargeNumbers
-- luacheck: read globals InCombatLockdown GetTime time wipe COMBATLOG_XPGAIN_FIRSTPERSON ObjectiveTrackerFrame
-- luacheck: read globals GameTooltip LibStub UIParent

local _, ns = ...
if ns.off then return end

local L = ns.L
local API = ns.API
local KEY = "xpBar"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["XP Bar"] })

local HOUR = 3600
local RESOLVE = 0.4        -- s after a gain before its kind is decided (the quest and kill lines arrive)
local AFTER_FIGHT = 3      -- s after a fight in which a kill line still counts as a kill
local MIN_RATE_TIME = 120  -- s of data before a rate (and time to level) is shown

local RESTED = { 0.58, 0.32, 0.88 }   -- the purple Daylight UI's bar uses for rested XP

-- ---------------------------------------------------------------------------------------------
-- Settings and page
-- ---------------------------------------------------------------------------------------------

P.defaults = {
	enabled = false,
	replace = true,
	shows = "always",
	dock = "tracker",
	width = 240,
	windowless = false,
	barText = "percent",
	barHeight = 14,
	scale = 1,
	timeToLevel = true,
	perHour = true,
	perKill = true,
	killsToLevel = true,
	questsReady = true,
	questLog = true,
	rested = true,
	session = false,
}

local function Off(get) return get(KEY .. ".enabled") == false end
local function Docked(get) return Off(get) or get(KEY .. ".dock") ~= "free" end

local function DB()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	return db
end

local NewSession   -- (below)

P.page = { id = KEY, label = L["XP Bar"],
	desc = L["Your XP with time to level, XP per kill and your quests' XP."],
	groups = {
		{ label = L["XP Bar"],
		  desc = L["An experience bar with the numbers you level by: your rate, kills and quests. It hides at the level cap."],
		  items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "toggle", key = KEY .. ".replace", label = L["Replace Other XP Bars"], disabled = Off,
			  desc = ns.standalone and L["While this shows, the game's own XP bar is kept hidden. Turned off, or at the level cap, it comes back."]
				or L["While this shows, Daylight UI's XP bar is switched off for the session (never saved). Turned off, or at the level cap, it comes back."] },
			{ type = "dropdown", key = KEY .. ".shows", label = L["Shows"], disabled = Off,
			  values = { always = L["Always"], calm = L["Out of a Fight"] }, order = { "always", "calm" } },
			{ type = "button", label = L["Start a New Session"], disabled = Off,
			  desc = L["Forgets this session's totals and the last hour's gains: the rate starts again from now."],
			  func = function() if NewSession then NewSession() end end },
		} },
		{ label = L["Where"], items = {
			{ type = "dropdown", key = KEY .. ".dock", label = L["Dock To"], disabled = Off,
			  values = { tracker = L["Quest Tracker"], free = L["Free"] }, order = { "tracker", "free" },
			  desc = ns.standalone and L["Quest Tracker: under the quest list, as wide as it, following it as it grows and moves (above it when there's no room below). Free: move it anywhere with /glowey unlock or Move Window."]
				or L["Quest Tracker: under the quest list (or RestedXP's guide docked there), as wide as the minimap's panel when the tracker hangs under it, following it as it grows and moves (above it when there's no room below). Free: move it anywhere with /dui unlock or Move Window."] },
			{ type = "slider", key = KEY .. ".width", label = L["Width"], min = 160, max = 420, step = 5, unit = "px",
			  disabled = Docked, desc = L["Free only. Docked, it takes the tracker's width and fits its text to it; free, it's never narrower than its text."] },
			{ type = "toggle", key = KEY .. ".windowless", label = L["Windowless"], disabled = Off,
			  desc = L["Just the bar and the text, with no window behind them, docked or free."] },
		} },
		{ label = L["Details"], desc = L["The lines under the bar. Rates count the last hour, or this session while it's younger."],
		  items = {
			{ type = "toggle", key = KEY .. ".timeToLevel", label = L["Time to Level"], disabled = Off,
			  desc = L["What's left of the level at your XP per hour."] },
			{ type = "toggle", key = KEY .. ".perHour", label = L["XP per Hour"], disabled = Off },
			{ type = "toggle", key = KEY .. ".perKill", label = L["XP per Kill"], disabled = Off,
			  desc = L["The average XP of your kills over the last hour."] },
			{ type = "toggle", key = KEY .. ".killsToLevel", label = L["Kills to Level"], disabled = Off,
			  desc = L["What's left of the level at your average XP per kill."] },
			{ type = "toggle", key = KEY .. ".questsReady", label = L["Quests Ready"], disabled = Off,
			  desc = L["The quests you can turn in now, their XP, and where the bar goes when you do."] },
			{ type = "toggle", key = KEY .. ".questLog", label = L["Quest Log XP"], disabled = Off,
			  desc = L["The XP of every quest in your log, finished or not."] },
			{ type = "toggle", key = KEY .. ".rested", label = L["Rested XP"], disabled = Off },
			{ type = "toggle", key = KEY .. ".session", label = L["This Session"], disabled = Off,
			  desc = L["XP, kills and quests since you logged in (a /reload keeps them)."] },
		} },
		{ label = L["Look"], items = {
			{ type = "dropdown", key = KEY .. ".barText", label = L["Bar Text"], disabled = Off,
			  values = { percent = L["Percent"], numbers = L["Numbers"], both = L["Both"], off = L["Off"] },
			  order = { "percent", "numbers", "both", "off" },
			  desc = L["What the bar shows on it, after your level."] },
			{ type = "slider", key = KEY .. ".barHeight", label = L["Bar Height"], min = 8, max = 26, step = 1, unit = "px",
			  disabled = Off },
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 1.6, step = 0.05, unit = "%", disabled = Off },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- Reading the game
-- ---------------------------------------------------------------------------------------------

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
end

-- A plain number, or nil (missing or secret).
local function Num(v)
	if type(v) == "number" and Safe(v) then return v end
	return nil
end

local function AtCap()
	local capped = Call(IsPlayerAtEffectiveMaxLevel)
	if capped ~= nil and Safe(capped) then return capped == true end
	local max, level = Num(Call(GetMaxPlayerLevel)), Num(UnitLevel("player"))
	return max ~= nil and level ~= nil and level >= max
end

local function ReadXP()
	return Num(Call(UnitXP, "player")), Num(Call(UnitXPMax, "player")), Num(UnitLevel("player"))
end

-- The quest log's reward XP: { ready, readyCount, all, allCount }. Recounted on quest log events
-- (once per burst), including entries under collapsed headers.
local quests = { ready = 0, readyCount = 0, all = 0, allCount = 0 }
local function CountQuests()
	local QL = C_QuestLog
	local ready, readyCount, all, allCount = 0, 0, 0, 0
	if type(QL) == "table" and type(QL.GetInfo) == "function" and type(GetQuestLogRewardXP) == "function" then
		local shown, total = Call(QL.GetNumQuestLogEntries)
		local n = (Num(shown) or 0) + (Num(total) or 0)
		for i = 1, n do
			local info = Call(QL.GetInfo, i)
			local id = type(info) == "table" and not info.isHeader and info.questID
			if type(id) == "number" and not Call(QL.IsFailed, id) then
				local r = Num(Call(GetQuestLogRewardXP, id))
				if r and r > 0 then
					all, allCount = all + r, allCount + 1
					if Call(QL.IsComplete, id) or Call(QL.ReadyForTurnIn, id) then
						ready, readyCount = ready + r, readyCount + 1
					end
				end
			end
		end
	end
	quests.ready, quests.readyCount, quests.all, quests.allCount = ready, readyCount, all, allCount
end

-- ---------------------------------------------------------------------------------------------
-- Gains: what they were, kept per character
-- ---------------------------------------------------------------------------------------------

local store   -- DaylightEssentialsDB.xpBar[guid]: { gains = { { t, xp, kind } }, session = { ... } }

local function Store()
	if store then return store end
	local guid = UnitGUID("player")
	if type(guid) ~= "string" or not Safe(guid) then return nil end
	local db = DB()
	db.xpBar = type(db.xpBar) == "table" and db.xpBar or {}
	local s = db.xpBar[guid]
	if type(s) ~= "table" then
		s = {}
		db.xpBar[guid] = s
	end
	s.gains = type(s.gains) == "table" and s.gains or {}
	if type(s.session) ~= "table" then s.session = { start = time(), xp = 0, kills = 0, quests = 0 } end
	store = s
	return s
end

-- Gains older than an hour go.
local function Prune(now)
	local s = Store()
	if not s then return end
	local gains, keep = s.gains, 0
	for i = 1, #gains do
		local g = gains[i]
		if type(g) == "table" and type(g[1]) == "number" and now - g[1] <= HOUR then
			keep = keep + 1
			gains[keep] = g
		end
	end
	for i = #gains, keep + 1, -1 do gains[i] = nil end
end

local Paint, PaintSoon, LayParts, WatchTracker

local function Record(xp, kind, count)
	local s = Store()
	if not s or xp <= 0 then return end
	local now = time()
	Prune(now)
	count = math.max(1, count or 1)
	local each = xp / count
	for _ = 1, count do s.gains[#s.gains + 1] = { now, each, kind } end
	local ses = s.session
	ses.xp = (ses.xp or 0) + xp
	if kind == "kill" then ses.kills = (ses.kills or 0) + count end
	if kind == "quest" then ses.quests = (ses.quests or 0) + count end
end

-- (The last hour's gains go too: the rate counts play time, and the time logged out isn't.)
NewSession = function()
	local s = Store()
	if not s then return end
	s.session = { start = time(), xp = 0, kills = 0, quests = 0 }
	wipe(s.gains)
	if PaintSoon then PaintSoon() end
end

-- The numbers: { rate (XP/h or nil), perKill, kills (last hour), perQuest }.
local function Rates()
	local s = Store()
	local out = {}
	if not s then return out end
	local now = time()
	Prune(now)
	local xp, killXP, kills, questXP, questsDone = 0, 0, 0, 0, 0
	for _, g in ipairs(s.gains) do
		xp = xp + g[2]
		if g[3] == "kill" then killXP, kills = killXP + g[2], kills + 1 end
		if g[3] == "quest" then questXP, questsDone = questXP + g[2], questsDone + 1 end
	end
	-- Over the last hour, or the session while it's younger (its gains from before a /reload count).
	local span = math.min(HOUR, now - (s.session.start or now))
	if span >= MIN_RATE_TIME and xp > 0 then out.rate = xp / span * HOUR end
	if kills > 0 then out.perKill = killXP / kills end
	out.kills = kills
	if questsDone > 0 then out.perQuest = questXP / questsDone end
	return out
end

-- ---------------------------------------------------------------------------------------------
-- Telling gains apart
-- ---------------------------------------------------------------------------------------------

-- The start of a kill's XP line ("%s dies, you gain %d experience."), as a Lua pattern, made from
-- the game's own string so it reads in every language: what comes before the number, the name a
-- wildcard. Group and rested variants start the same way.
local KILL_PATTERN
do
	local fmt = type(COMBATLOG_XPGAIN_FIRSTPERSON) == "string" and COMBATLOG_XPGAIN_FIRSTPERSON
		or "%s dies, you gain %d experience."
	local head = fmt:match("^(.-)%%%d*%$?d")
	if head and head:find("%%%d*%$?s") then
		head = head:gsub("%%%d*%$?s", "\001")
		head = head:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
		KILL_PATTERN = "^" .. head:gsub("\001", ".+")
	end
end

local lastXP, lastMax, lastLevel
local pending = { xp = 0, questXP = 0, quests = 0, kills = 0 }
local resolveQueued = false
local fightEnded = 0

local function Resolve()
	resolveQueued = false
	local p = pending
	local delta = p.xp
	if delta > 0 then
		local q = math.min(delta, p.questXP)
		if q > 0 then Record(q, "quest", math.max(1, p.quests)) end
		local rest = delta - q
		if rest > 0 then
			if p.kills > 0 then Record(rest, "kill", p.kills) else Record(rest, "other") end
		end
	end
	p.xp, p.questXP, p.quests, p.kills = 0, 0, 0, 0
	PaintSoon()
end

local function ResolveSoon()
	if resolveQueued then return end
	resolveQueued = true
	C_Timer.After(RESOLVE, Resolve)
end

local function OnXP()
	local cur, max, level = ReadXP()
	if not (cur and max and level) then return end
	if lastXP and lastMax and lastLevel then
		local delta
		if level == lastLevel then delta = cur - lastXP
		elseif level == lastLevel + 1 then delta = (lastMax - lastXP) + cur
		end
		if delta and delta > 0 then
			pending.xp = pending.xp + delta
			ResolveSoon()
		end
	end
	lastXP, lastMax, lastLevel = cur, max, level
end

local function OnKillLine(text)
	if type(text) == "string" and Safe(text) then
		if KILL_PATTERN and text:find(KILL_PATTERN) then pending.kills = pending.kills + 1 end
	elseif InCombatLockdown() or GetTime() - fightEnded < AFTER_FIGHT then
		pending.kills = pending.kills + 1
	end
	ResolveSoon()
end

local function OnQuestTurnedIn(xp)
	xp = Num(xp)
	if xp and xp > 0 then
		pending.questXP = pending.questXP + xp
		pending.quests = pending.quests + 1
		ResolveSoon()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------------------------

local function Big(n)
	n = math.floor(n + 0.5)
	if type(BreakUpLargeNumbers) == "function" then return BreakUpLargeNumbers(n) end
	return tostring(n)
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	if seconds < 60 then return L["< 1m"] end
	local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
	if h >= 100 then return L["%dh"]:format(h) end
	if h > 0 then return L["%dh %dm"]:format(h, m) end
	return L["%dm"]:format(m)
end

local function Pct(v, max) return math.floor(v / max * 1000 + 0.5) / 10 end

-- ---------------------------------------------------------------------------------------------
-- The box
-- ---------------------------------------------------------------------------------------------

local ROW_H, PAD, GAP, SLACK, BAR_GAP = 17, 6, 14, 6, 5

local frame, body, shell, content
local barHolder, xpBar, overlay, bankTex, restTex, barText
local barParts = { cur = 0, max = 1, ahead = 0, rested = 0 }
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
	row.label:SetWordWrap(false)
	ns.Ink(row.label, "LABEL")
	rows[i] = row
	return row
end

-- The lines to show now: { label, value, role } (reused).
local lines, nLines = {}, 0
local function Add(label, value, role)
	nLines = nLines + 1
	local l = lines[nLines]
	if not l then l = {} lines[nLines] = l end
	l[1], l[2], l[3] = label, value, role or "VALUE"
end

-- The sample shown while unlocked or in test mode.
local SAMPLE = { cur = 41250, max = 68000, level = 27, rested = 9800, ready = 6400, readyCount = 3, all = 15900,
	allCount = 11, rate = 31200, perKill = 284, kills = 88 }

local function Collect(d)
	nLines = 0
	local left = d.max - d.cur
	if G("timeToLevel") then
		Add(L["Time to Level"], d.rate and Clock(left / d.rate * HOUR) or L["Gathering Data"], d.rate and "VALUE" or "OFF")
	end
	if G("perHour") then
		Add(L["XP per Hour"], d.rate and Big(d.rate) or L["Gathering Data"], d.rate and "VALUE" or "OFF")
	end
	if G("perKill") then
		Add(L["XP per Kill"], d.perKill and Big(d.perKill) or L["No Kills Yet"], d.perKill and "VALUE" or "OFF")
	end
	if G("killsToLevel") and d.perKill and d.perKill > 0 then
		Add(L["Kills to Level"], Big(math.ceil(left / d.perKill)))
	end
	if G("questsReady") then
		if d.readyCount > 0 then
			local where
			if d.ready >= left then where = L["Levels Up"]
			else where = L["%s%%"]:format(Pct(d.cur + d.ready, d.max)) end
			Add(ns.Plural(d.readyCount, L["%d Quest Ready"], L["%d Quests Ready"], L["%d Quests Ready#few"]):format(d.readyCount),
				L["%s XP, to %s"]:format(Big(d.ready), where), "GOOD")
		else
			Add(L["Quests Ready"], L["None"], "OFF")
		end
	end
	if G("questLog") and d.allCount > 0 then
		Add(L["Quest Log XP"], L["%s (%d)"]:format(Big(d.all), d.allCount))
	end
	if G("rested") and d.rested > 0 then
		Add(L["Rested XP"], L["%s (%s%%)"]:format(Big(d.rested), Pct(d.rested, d.max)))
	end
	if G("session") then
		Add(L["This Session"], L["%s XP, %d kills, %d quests"]:format(Big(d.sesXP), d.sesKills, d.sesQuests))
	end
end

-- Everything the box shows now, or nil (nothing to show: at the cap, or no XP to read).
local function Data()
	if previewing then
		local s = SAMPLE
		return { cur = s.cur, max = s.max, level = s.level, rested = s.rested, ready = s.ready, readyCount = s.readyCount,
			all = s.all, allCount = s.allCount, rate = s.rate, perKill = s.perKill,
			sesXP = 48200, sesKills = s.kills, sesQuests = 7 }
	end
	if AtCap() then return nil end
	local cur, max, level = ReadXP()
	if not (cur and max and level and max > 0) then return nil end
	local r = Rates()
	local ses = Store() and Store().session or {}
	return { cur = cur, max = max, level = level, rested = Num(Call(GetXPExhaustion)) or 0,
		ready = quests.ready, readyCount = quests.readyCount, all = quests.all, allCount = quests.allCount,
		rate = r.rate, perKill = r.perKill, sesXP = ses.xp or 0, sesKills = ses.kills or 0, sesQuests = ses.quests or 0 }
end

local function BarString(d)
	local mode = G("barText") or "percent"
	if mode == "off" then return nil end
	local lvl = L["Level %d"]:format(d.level)
	if mode == "numbers" then return L["%s  ·  %s / %s"]:format(lvl, Big(d.cur), Big(d.max)) end
	if mode == "both" then
		return L["%s  ·  %s / %s (%s%%)"]:format(lvl, Big(d.cur), Big(d.max), Pct(d.cur, d.max))
	end
	return L["%s  ·  %s%%"]:format(lvl, Pct(d.cur, d.max))
end

-- ---------------------------------------------------------------------------------------------
-- Docking under the quest tracker
-- ---------------------------------------------------------------------------------------------

local DOCK_GAP = 4

local function Usable(f) return type(f) == "table" and type(f.GetObjectType) == "function" end

-- Daylight UI's tracker (through its API's GetFrame, as Addon Skins' RestedXP dock reads it) as
-- { holder, list }: the list's frame (or its box round it), else the holder when it grows up from
-- its bottom; else the game's tracker, its lowest section showing.
local function Tracker()
	local get = API.GetFrame
	if type(get) == "function" then
		local ok, holder = pcall(get, "questtracker")
		if ok and Usable(holder) then
			local list, up
			local kids = { holder:GetChildren() }
			for _, kid in ipairs(kids) do
				if kid:IsObjectType("ScrollFrame") then
					list = kid
					up = kid:GetPoint(1) == "BOTTOMRIGHT"
					for _, box in ipairs(kids) do
						if box ~= kid and box:IsShown() and select(2, box:GetPoint(1)) == kid then list = box end
					end
					break
				end
			end
			return { holder = holder, list = (up or not list) and holder or list, own = true }
		end
	end
	local f = _G.ObjectiveTrackerFrame
	if not Usable(f) then return nil end
	-- (Its frame is as tall as the room it may take: the bottom of what shows is its lowest section,
	-- or its header while it's folded up.)
	local low, lowB = nil, nil
	if type(f.modules) == "table" and not (f.IsCollapsed and f:IsCollapsed()) then
		for _, m in ipairs(f.modules) do
			if Usable(m) and m:IsShown() then
				local b = m:GetBottom()
				if b and (not lowB or b < lowB) then low, lowB = m, b end
			end
		end
	end
	if not low and Usable(f.Header) and f.Header:IsShown() then low = f.Header end
	return { holder = f, list = low or f, game = true }
end

-- RestedXP's guide, when it hangs off the tracker (Addon Skins docks it under or in its place):
-- the box goes under it instead. Read from its public AceAddon and windows only.
local function DockedGuide(t)
	local ace = _G.LibStub and _G.LibStub("AceAddon-3.0", true)
	local okA, rxp = pcall(function() return ace and ace:GetAddon("RXPGuides", true) end)
	if not (okA and type(rxp) == "table") then return nil end
	local f
	local v2 = rxp.v2
	if type(v2) == "table" and type(v2.IsEnabled) == "function" and v2:IsEnabled()
		and type(v2.GetGuideWindowAnchorFrame) == "function" then
		local ok, w = pcall(v2.GetGuideWindowAnchorFrame, v2)
		if ok then f = w end
	else
		f = rxp.RXPFrame or _G.RXPFrame
	end
	if not (Usable(f) and f:IsShown() and f:GetNumPoints() > 0) then return nil end
	local rel = select(2, f:GetPoint(1))
	if rel == t.holder or rel == t.list then return f end
	-- (Its rel may be a frame inside the holder: the list's view.)
	if Usable(rel) and rel.GetParent and rel:GetParent() == t.holder then return f end
	return nil
end

-- What the box hangs from now: { frame, at = "under" or "top", tracker, guide }, or nil (free).
local function DockTarget()
	if G("dock") == "free" then return nil end
	local t = Tracker()
	if not t then return nil end
	local guide = DockedGuide(t)
	local anchor = guide or t.list
	if not (anchor.GetLeft and anchor:GetLeft() and anchor:GetBottom()) then
		-- (The tracker put away with nothing in it: in its place.)
		anchor = t.holder
		if not (anchor.GetLeft and anchor:GetLeft() and anchor:GetTop()) then return nil end
		return { frame = anchor, at = "top", tracker = t, guide = guide }
	end
	return { frame = anchor, at = "under", tracker = t, guide = guide }
end

-- ---------------------------------------------------------------------------------------------
-- Painting and placing
-- ---------------------------------------------------------------------------------------------

-- Daylight UI's fade: the box fades out and back with the rest of the UI, by the choices of what it
-- belongs with. Docked, the quest tracker's (Daylight UI's own tracker, Quests > fade; the game's
-- tracker under the minimap, InfoPanel > tracker.fade), so the two fade, wait and come back on
-- mouseover together. Free, those of Daylight UI's XP bar it stands in for: the minimap panel's,
-- or the XP bar's own when it has its own fade. The engine also hushes it with everything else (a
-- flight path, a campfire). Registered again only when that source changes (the same key replaces
-- the old one). Nothing without Daylight UI.
local fadeList = {}
local fadeFrom
local function FadeSource(docked)
	if docked then
		local get = API.GetFrame
		local ok, own = false, nil
		if type(get) == "function" then ok, own = pcall(get, "questtracker") end
		if ok and Usable(own) then return "Quests", "fade" end
		return "InfoPanel", "tracker.fade"
	end
	local okS, ownFade = pcall(API.GetSetting, "InfoPanel", "xp.ownFade")
	if okS and ownFade == true then return "InfoPanel", "xp.fade" end
	return "InfoPanel", "fade"
end
local function FollowFade(docked)
	if ns.standalone or type(ns.me.RegisterFade) ~= "function" or not frame then return end
	local scope, path = FadeSource(docked)
	local from = scope .. ">" .. path
	if from == fadeFrom then return end
	fadeFrom = from
	fadeList[1] = frame
	pcall(ns.me.RegisterFade, { key = KEY, frames = function() return fadeList end, scope = scope, path = path })
end

local suspended = nil
local function Home() return { "RIGHT", UIParent, "RIGHT", -40, -120 } end
local function Suspend(on)
	if suspended == on then return end
	suspended = on
	if not ns.SuspendMover(KEY, on) and not on and frame then
		frame:ClearAllPoints()
		frame:SetPoint(unpack(Home()))
	end
end

local function Anchored(f, want)
	if f:GetNumPoints() ~= #want then return false end
	for i, w in ipairs(want) do
		local p, rel, rp, x, y = f:GetPoint(i)
		if p ~= w[1] or rel ~= w[2] or rp ~= w[3] or math.abs((x or 0) - w[4]) > 0.01 or math.abs((y or 0) - w[5]) > 0.01 then
			return false
		end
	end
	return true
end

-- How wide the text needs the box (body units). The numbers change width as they change (9,812 to
-- 12,386, "Gathering Data" to 12m), and docked the box's inside is scaled to fit the tracker: fitted
-- to each new width, everything would resize at every gain. So the widest it has needed is kept and
-- only grows (measuredW), and is let go only when the layout should change: a setting or the look
-- (ForgetWidth), or the tracker's or the minimap's width (Place).
local measuredW = 0   -- the width the box is laid out for: the widest needed since the last forget
local needNow = 0     -- what the text needs this paint
local lastAcross      -- the docked width the box was last fitted to
local function ForgetWidth() measuredW, lastAcross = 0, nil end
local boxH = 1

-- Docked: hung from the target's right edge at exactly its width, so it widens and narrows with the
-- tracker or the RestedXP guide docked there; under the minimap's panel, flush with the panel's
-- outer edges (PanelSpan). When its
-- text needs more room than that, what's inside is scaled down to fit (to 40% of its Size at the
-- least), never cut and never wider than the tracker. Under it; with no room under it, over the
-- tracker's top instead; in its place when it holds nothing.
local FIT_FLOOR = 0.4

-- The minimap's panel (Daylight UI's, border and data texts included: API.GetFrame "infopanel"),
-- left and right edges in screen pixels, when what the box hangs from is under it: then the box is
-- flush with the panel's outer edges, as wide as the minimap you see, not the map picture the
-- tracker's list lines up with. nil otherwise (no panel, the tracker elsewhere, no Daylight UI).
local function PanelSpan(anchor)
	local get = API.GetFrame
	if type(get) ~= "function" then return nil end
	local ok, panel = pcall(get, "infopanel")
	if not (ok and Usable(panel) and panel:IsVisible()) then return nil end
	local ps, as = panel:GetEffectiveScale(), anchor:GetEffectiveScale()
	local pl, pr, pb = panel:GetLeft(), panel:GetRight(), panel:GetBottom()
	local al, ar, at = anchor:GetLeft(), anchor:GetRight(), anchor:GetTop()
	if not (pl and pr and pb and al and ar and at and pr > pl) then return nil end
	pl, pr, pb, al, ar, at = pl * ps, pr * ps, pb * ps, al * as, ar * as, at * as
	local mid = (al + ar) / 2
	if mid < pl or mid > pr or at > pb + 2 then return nil end
	return pl, pr
end
local function Place()
	local target = DockTarget()
	local scale = G("scale") or 1
	FollowFade(target ~= nil)
	if not target then
		Suspend(false)
		local w = math.max(G("width") or 240, measuredW)
		body:SetSize(w, boxH)
		frame:SetSize(w * scale, boxH * scale)
		return
	end
	Suspend(true)
	WatchTracker()   -- (a guide or box that came since: its size changes followed too)
	local a = target.frame
	local l, r = a:GetLeft(), a:GetRight()
	local fs = frame:GetEffectiveScale()
	local across = (l and r and r > l) and (r - l) * a:GetEffectiveScale() / fs or 0
	-- Under the minimap's panel: its width, and its right edge's distance from the anchor's.
	local padR = 0
	local spanL, spanR = PanelSpan(a)
	if spanL and r then
		across = (spanR - spanL) / fs
		padR = (spanR - r * a:GetEffectiveScale()) / fs
	end
	-- (Another width to fit: what's needed now, not the widest of the old one.)
	if not lastAcross or math.abs(across - lastAcross) > 0.5 then
		measuredW, lastAcross = needNow, across
	end
	local fit, w = scale, measuredW
	if across > 0 then
		if measuredW * fit > across then fit = math.max(scale * FIT_FLOOR, across / measuredW) end
		w = across / fit
	end
	body:SetScale(fit)
	body:SetSize(w, boxH)
	frame:SetSize(w * fit, boxH * fit)
	local want
	if target.at == "top" then
		want = { { "TOPRIGHT", a, "TOPRIGHT", 0, 0 } }
	else
		-- Room under it? (Screen pixels; positions are plain numbers.)
		local bottom = a:GetBottom() * a:GetEffectiveScale()
		local need = (boxH * fit + DOCK_GAP) * frame:GetEffectiveScale()
		local ground = (UIParent:GetBottom() or 0) * UIParent:GetEffectiveScale()
		if bottom - need >= ground then
			want = { { "TOPRIGHT", a, "BOTTOMRIGHT", padR, -DOCK_GAP } }
		else
			-- Over the tracker's top (the holder's, the list's own when it's the game's).
			local top = target.tracker.holder
			want = { { "BOTTOMRIGHT", top, "TOPRIGHT", 0, DOCK_GAP } }
		end
	end
	if not Anchored(frame, want) then
		frame:ClearAllPoints()
		for _, p in ipairs(want) do frame:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
	end
end

-- Whether the box shows now (outside unlock and test mode).
local function Wanted()
	if not G("enabled") then return false end
	if G("shows") == "calm" and inFight then return false end
	return true
end

-- The other XP bars, out of the way while this shows (Replace Other XP Bars).
local override   -- the me.Override handle while Daylight UI's bar is off for us
local gameHidden = false
local GAME_BARS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local hookedBars = setmetatable({}, { __mode = "k" })

local function HideGameBars(on)
	for _, name in ipairs(GAME_BARS) do
		local f = _G[name]
		if Usable(f) then
			-- (Edit Mode frames: kept hidden from their own OnShow, never by hooking Show itself,
			-- as Daylight UI's bar does it.)
			if on and not hookedBars[f] and f.HookScript then
				hookedBars[f] = true
				f:HookScript("OnShow", function(self) if gameHidden then self:Hide() end end)
			end
			if on then f:Hide() elseif gameHidden then f:Show() end
		end
	end
	gameHidden = on
end

local function Replace(showing)
	local want = showing and G("enabled") == true and G("replace") == true
	if ns.standalone then
		if want ~= gameHidden then HideGameBars(want) end
		return
	end
	if want and not override and type(ns.me.Override) == "function" then
		local ok, h = pcall(ns.me.Override, "InfoPanel", "xp.enabled", false)
		override = ok and h or nil
	elseif not want and override then
		local h = override
		override = nil
		pcall(API.Off, h)
	end
end

-- The finished quests' XP (green) right after the fill and the rested XP (purple) after that,
-- laid on the bar's track as two strips (Daylight UI's bar draws its own fill and track, so the
-- strips go over the track, never under the fill). Laid again when the bar changes width.
function LayParts()
	if not overlay then return end
	local w = overlay:GetWidth() or 0
	local p = barParts
	if w <= 0 or p.max <= 0 then
		bankTex:Hide()
		restTex:Hide()
		return
	end
	local x0, x1, x2 = w * p.cur / p.max, w * p.ahead / p.max, w * p.rested / p.max
	bankTex:ClearAllPoints()
	bankTex:SetPoint("TOPLEFT", overlay, "TOPLEFT", x0, 0)
	bankTex:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", x0, 0)
	bankTex:SetWidth(math.max(0.01, x1 - x0))
	bankTex:SetShown(x1 - x0 >= 0.5)
	restTex:ClearAllPoints()
	restTex:SetPoint("TOPLEFT", overlay, "TOPLEFT", x1, 0)
	restTex:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", x1, 0)
	restTex:SetWidth(math.max(0.01, x2 - x1))
	restTex:SetShown(x2 - x1 >= 0.5)
end

local lastString
Paint = function()
	if not frame then return end
	local on = G("enabled") == true
	previewing = on and ns.Previewing(KEY)
	local d = on and (previewing or Wanted()) and Data() or nil
	Replace(on and not AtCap())
	if not d then
		frame:Hide()
		return
	end
	-- The bar: the XP itself, then the finished quests' XP and the rested XP as strips after it.
	local barH = G("barHeight") or 14
	barHolder:SetHeight(barH)
	local ahead = math.min(d.max, d.cur + (G("questsReady") ~= false and d.ready or 0))
	xpBar:SetMinMaxValues(0, d.max)
	xpBar:SetValue(d.cur)
	barParts.cur, barParts.max, barParts.ahead = d.cur, d.max, ahead
	barParts.rested = d.rested > 0 and math.min(d.max, ahead + d.rested) or ahead
	LayParts()
	local str = BarString(d)
	barText:SetShown(str ~= nil)
	if str and str ~= lastString then barText:SetText(str) end
	lastString = str
	-- The lines.
	Collect(d)
	local labelW, valueW = 0, 0
	for i = 1, nLines do
		local row, l = Row(i), lines[i]
		row.label:SetText(l[1])
		row.value:SetText(l[2])
		ns.Ink(row.value, l[3])
		labelW = math.max(labelW, ns.TextWidth(row.label) or 0)
		valueW = math.max(valueW, ns.TextWidth(row.value) or 0)
		local y = -(PAD + barH + BAR_GAP + (i - 1) * ROW_H)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, y)
		row:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, y)
		row:Show()
	end
	for i = nLines + 1, #rows do rows[i]:Hide() end
	needNow = math.ceil(labelW + GAP + valueW + SLACK) + PAD * 2
	if barText:IsShown() then needNow = math.max(needNow, math.ceil((ns.TextWidth(barText) or 0) + SLACK) + PAD * 2 + 8) end
	if needNow > measuredW then measuredW = needNow end
	boxH = PAD * 2 + barH + (nLines > 0 and (BAR_GAP + nLines * ROW_H) or 0)
	body:SetScale(G("scale") or 1)
	shell:SetShown(G("windowless") ~= true)
	Place()
	ns.SkinWindow(shell, nil, KEY)
	frame:Show()
end

local paintQueued = false
PaintSoon = function()
	if paintQueued then return end
	paintQueued = true
	C_Timer.After(0, function()
		paintQueued = false
		Paint()
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The hover: everything at once
-- ---------------------------------------------------------------------------------------------

local function ShowTip(self)
	local d = Data()
	if not d then return end
	local right = (self:GetCenter() or 0) * self:GetEffectiveScale() > (UIParent:GetCenter() or 0) * UIParent:GetEffectiveScale()
	ns.Host.TipLines(self, function(t)
		t.Line(L["Level %d"]:format(d.level), "TITLE")
		t.Double(L["This Level"], L["%s / %s (%s%%)"]:format(Big(d.cur), Big(d.max), Pct(d.cur, d.max)))
		t.Double(L["To Level"], Big(d.max - d.cur))
		if d.rested > 0 then t.Double(L["Rested XP"], Big(d.rested)) end
		t.Blank()
		t.Double(L["XP per Hour"], d.rate and Big(d.rate) or L["Gathering Data"])
		if d.rate then
			t.Double(L["Time to Level"], Clock((d.max - d.cur) / d.rate * HOUR))
			if d.ready > 0 and d.ready < d.max - d.cur then
				t.Double(L["After Turning In"], Clock((d.max - d.cur - d.ready) / d.rate * HOUR))
			end
		end
		t.Double(L["XP per Kill"], d.perKill and Big(d.perKill) or L["No Kills Yet"])
		if d.perKill and d.perKill > 0 then t.Double(L["Kills to Level"], Big(math.ceil((d.max - d.cur) / d.perKill))) end
		t.Blank()
		t.Double(L["Quests Ready"], L["%s XP (%d)"]:format(Big(d.ready), d.readyCount), "LABEL", "GOOD")
		t.Double(L["Quest Log XP"], L["%s XP (%d)"]:format(Big(d.all), d.allCount))
		t.Blank()
		t.Double(L["This Session"], L["%s XP"]:format(Big(d.sesXP)))
		t.Double(L["Kills"], tostring(d.sesKills))
		t.Double(L["Quests"], tostring(d.sesQuests))
	end, right and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
end

-- ---------------------------------------------------------------------------------------------
-- Following the tracker
-- ---------------------------------------------------------------------------------------------

local hooked = setmetatable({}, { __mode = "k" })
local function Watch(f)
	if not Usable(f) or hooked[f] or not f.HookScript then return end
	hooked[f] = true
	f:HookScript("OnShow", PaintSoon)
	f:HookScript("OnHide", PaintSoon)
	f:HookScript("OnSizeChanged", PaintSoon)
end

-- The tracker's frames (and RestedXP's guide when it hangs there), hooked once each: their own
-- show, hide and size say when to place the box again. The game's tracker also redraws itself
-- through its Update, which moves its sections without resizing the frame.
local gameHooked = false
WatchTracker = function()
	if G("dock") == "free" or not G("enabled") then return end
	local t = Tracker()
	if not t then return end
	Watch(t.holder)
	Watch(t.list)
	if t.own then
		for _, kid in ipairs({ t.holder:GetChildren() }) do Watch(kid) end
	end
	if t.game and not gameHooked and type(t.holder.Update) == "function" then
		gameHooked = true
		hooksecurefunc(t.holder, "Update", PaintSoon)
	end
	Watch(DockedGuide(t))
	-- (The minimap's panel resized: the box takes its new width.)
	if type(API.GetFrame) == "function" then
		local ok, panel = pcall(API.GetFrame, "infopanel")
		if ok then Watch(panel) end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------------

local questQueued = false
local function QuestsSoon()
	if questQueued then return end
	questQueued = true
	C_Timer.After(0.2, function()
		questQueued = false
		CountQuests()
		PaintSoon()
	end)
end

local EVENTS = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
	"CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED",
	"DISPLAY_SIZE_CHANGED" }

local function OnEvent(_, event, a, b)
	if event == "PLAYER_XP_UPDATE" then
		if a == nil or a == "player" then OnXP() end
		PaintSoon()
	elseif event == "PLAYER_LEVEL_UP" then
		OnXP()
		QuestsSoon()
	elseif event == "QUEST_TURNED_IN" then
		OnQuestTurnedIn(b)
		QuestsSoon()
	elseif event == "QUEST_LOG_UPDATE" then
		QuestsSoon()
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		OnKillLine(a)
	elseif event == "PLAYER_REGEN_DISABLED" then
		inFight = true
		PaintSoon()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inFight = false
		fightEnded = GetTime()
		WatchTracker()
		PaintSoon()
	else
		PaintSoon()
	end
end

local listening = false
local function Listen(on)
	if on == listening or not frame then return end
	listening = on
	for _, e in ipairs(EVENTS) do
		if on then frame:RegisterEvent(e) else frame:UnregisterEvent(e) end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------------------------------

local function Build()
	if frame then return end
	frame = CreateFrame("Frame", "DaylightEssentialsXPBar", UIParent)
	frame:SetFrameStrata("LOW")
	frame:SetClampedToScreen(true)
	frame:SetSize(240, 60)
	frame:Hide()
	frame:SetScript("OnEvent", OnEvent)
	body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	body:SetSize(240, 60)
	shell = CreateFrame("Frame", nil, body)
	shell:SetAllPoints()
	shell:SetFrameLevel(body:GetFrameLevel())
	content = CreateFrame("Frame", nil, body)
	content:SetAllPoints()
	content:SetFrameLevel(body:GetFrameLevel() + 5)
	-- The bar: three stacked, the rested one carrying the dark track.
	barHolder = CreateFrame("Frame", nil, content)
	barHolder:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -PAD)
	barHolder:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, -PAD)
	barHolder:SetHeight(14)
	xpBar = API.Bar(barHolder)
	xpBar:SetAllPoints(barHolder)
	overlay = CreateFrame("Frame", nil, barHolder)
	overlay:SetAllPoints(xpBar)
	overlay:SetFrameLevel(xpBar:GetFrameLevel() + 1)
	bankTex = overlay:CreateTexture(nil, "ARTWORK")
	restTex = overlay:CreateTexture(nil, "ARTWORK")
	overlay:SetScript("OnSizeChanged", function() LayParts() end)
	local textLayer = CreateFrame("Frame", nil, barHolder)
	textLayer:SetAllPoints(barHolder)
	textLayer:SetFrameLevel(overlay:GetFrameLevel() + 1)
	barText = API.Text(textLayer, "small", "CENTER")
	barText:SetPoint("CENTER", textLayer, "CENTER", 0, 0)
	barText:SetWordWrap(false)
	-- The hover: the details, nothing to click.
	body:EnableMouse(true)
	body:SetMouseClickEnabled(false)
	body:SetScript("OnEnter", ShowTip)
	body:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame:HookScript("OnShow", function() WatchTracker() end)
	frame:SetPoint(unpack(Home()))
	ns.me.RegisterMover(frame, KEY, L["XP Bar"], Home)
	ns.FadeIn(KEY, function() return { shell, content } end)
	ns.me.RegisterTestPart(KEY, L["XP Bar"])
end

-- The strips' colors: the finished quests' in the look's "good" green, rested in purple. (The fill
-- is Daylight UI's own, in its accent.)
local function Recolor()
	if not bankTex then return end
	local good = ns.Colors().GOOD or { 0.42, 0.86, 0.45 }
	bankTex:SetColorTexture(good[1], good[2], good[3], 0.85)
	restTex:SetColorTexture(RESTED[1], RESTED[2], RESTED[3], 0.7)
end

local function Refresh()
	if not frame then return end
	local on = G("enabled") == true
	Listen(on)
	if not on then
		Replace(false)
		frame:Hide()
		return
	end
	WatchTracker()
	Paint()
end

function P.Login()
	Build()
	inFight = InCombatLockdown() == true
	lastXP, lastMax, lastLevel = ReadXP()
	CountQuests()
	Recolor()
	Refresh()
end

-- A new login starts a new session; a /reload keeps it. The game says which on its first
-- PLAYER_ENTERING_WORLD, listened for from the moment this file loads (Daylight UI's Login can
-- come after it).
do
	local boot = CreateFrame("Frame")
	boot:RegisterEvent("PLAYER_ENTERING_WORLD")
	boot:SetScript("OnEvent", function(self, _, initial, reload)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:SetScript("OnEvent", nil)
		if initial and not reload then NewSession() end
		lastXP, lastMax, lastLevel = ReadXP()
		CountQuests()
		if frame then Refresh() end
	end)
end

function P.Setting()
	lastString = nil
	ForgetWidth()
	Refresh()
end

function P.Style()
	if not frame then return end
	lastString = nil
	ForgetWidth()
	Recolor()
	Paint()
end

function P.Preview()
	Refresh()
end
