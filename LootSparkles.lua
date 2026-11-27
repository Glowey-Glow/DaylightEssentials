-- Loot Sparkles: things worth walking over to sparkle.
--   * Quest items: the game's own loot sparkle stays on. Graphics presets switch it off
--     (outlineModeShowLootEffectWhenDisabled), so it is set again a moment after any graphics
--     change. Your outline mode is left as you set it unless "Outline Off Too" is on: the game draws
--     either its outline or the sparkle on a quest item, never both.
--   * Herbs, ore veins, quest objects, corpses with loot, corpses to skin and lockboxes you can pick:
--     a cluster of glints, in a color per kind, on the thing the interact key would use (the game's
--     "softinteract" unit). Grey when you can't use it yet (skill too low, locked).
--
-- How the glints find their object: the game's soft targeting picks the nearest thing you can
-- interact with, and with the interact key's world-object icons on it gives that thing a nameplate.
-- The glints hang under that nameplate. The nameplate itself is opened only for a thing that gets
-- glints (SoftTargetNameplateInteract), and what's on it (its name, the empty bar of a corpse) is
-- made see-through, so the world looks as it does without this, plus the sparkle. The kind comes
-- from the cursor the game would show over it (a pickaxe, a herb leaf, a lock), whether it belongs to
-- an unfinished quest objective, and for corpses whether loot is left or the tooltip says Skinnable.
--
-- Safe self-cast: with soft targeting on, a spell cast without a target could land on a living unit
-- it had picked beside you. Soft targeting (the interact key) is paused in a fight, and with
-- "Near Units Too" also while it picks a player or other living unit that offers no
-- service, until you move or a few seconds pass. Vendors, trainers, quest givers and the like are
-- left alone. No game setting is written in a fight, nor while an NPC, mail or bank window is open
-- (a setting changed there runs the game's handlers in our name, which addons in those windows trip
-- over).
--
-- No watcher: everything here follows the game's events (a new soft target, a nameplate shown or
-- taken back, loot opened or closed, the quest log, a fight) and one-shot timers. The glints move
-- by the game's own animations, which run only while they show.
--
-- The game settings changed are kept as they were (DaylightEssentialsDB.sparkles) and put back when
-- the part or its last kind is switched off. SoftTargetIconInteract (the icons over NPCs) is never
-- written: the game's nameplates keep a copy of it, and one written by an addon stays tainted there.
--
-- Daylight UI: its Quality of Life page has "Show quest item sparkles", the same job as Quest
-- Items here. While that is on, Daylight UI keeps them, unless "Essentials Keeps Quest Sparkles" is
-- on: then Daylight UI's switch is turned off for the session through its plugin API (me.Override,
-- never saved; logging out or changing it yourself gives it back) and this part keeps them, with the
-- outline off as Daylight UI had it.
-- Forever Loot Sparkles - Herbs & Ores: with it on, the glints here start off (both would hang on
-- the same nameplate and fight over the same settings); turn them on here and off in it if you'd
-- rather this did it.

-- luacheck: read globals C_AddOns C_CVar C_NamePlate C_QuestLog C_TooltipInfo C_Timer
-- luacheck: read globals SetUnitCursorTexture UnitIsGameObject UnitIsUnit UnitIsDead UnitExists
-- luacheck: read globals UnitIsPlayer UnitPlayerControlled UnitCanAttack UnitGUID UnitName UnitPosition
-- luacheck: read globals CanLootUnit GetNumLootItems GetLootSourceInfo IsPlayerSpell IsSpellKnown
-- luacheck: read globals GetFileIDFromPath InCombatLockdown issecretvalue Enum UNIT_SKINNABLE_LEATHER
-- luacheck: read globals UNIT_SKINNABLE_HERB UNIT_SKINNABLE_ROCK UNIT_SKINNABLE_BOLTS GetTime wipe

local ADDON, ns = ...
if ns.off then return end

local L = ns.L

local KEY = "lootSparkles"
local G = ns.Reader(KEY)
local SOFT = "softinteract"
local GLINT = "Interface\\AddOns\\" .. ADDON .. "\\Media\\sparkle-glint.png"

-- The kinds, their setting and their color to start.
local KINDS = {
	{ id = "herb", key = "herbs", label = L["Herbs"], color = { 0.38, 1, 0.42 }, prof = "herb" },
	{ id = "ore", key = "ore", label = L["Ore Veins"], color = { 1, 0.6, 0.25 }, prof = "ore" },
	{ id = "quest", key = "questObjects", label = L["Quest Objects"], color = { 1, 0.86, 0.45 } },
	{ id = "corpse", key = "corpses", label = L["Corpses With Loot"], color = { 0.78, 0.55, 1 } },
	{ id = "skin", key = "skinning", label = L["Corpses to Skin"], color = { 0.72, 0.52, 0.32 }, prof = "skin" },
	{ id = "lock", key = "lockboxes", label = L["Lockboxes to Pick"], color = { 1, 0.95, 0.45 } },
}
local KIND = {}
for _, k in ipairs(KINDS) do KIND[k.id] = k end
local GREY = { 0.6, 0.6, 0.6 }

-- Gathering professions by their rank spells (Apprentice to Artisan).
local PROFESSION = {
	herb = { 2366, 2368, 3570, 11993 },
	ore = { 2575, 2576, 3564, 10248 },
	skin = { 8613, 8617, 8618, 10768 },
}

-- Soft targeting as the glints need it, and what each was is kept (once, until given back).
local SOFT_CVARS = {
	SoftTargetInteract = "3",          -- the interact key's target, with mouse and controller
	SoftTargetIconGameObject = "1",    -- world objects get a nameplate
	SoftTargetInteractArc = "2",       -- all around you
	SoftTargetInteractRange = "30",
	SoftTargetInteractOnlyInRange = "0",
}
local GATE = "SoftTargetNameplateInteract"   -- the nameplate on the soft target, opened per thing
local QUEST_CVAR = "outlineModeShowLootEffectWhenDisabled"
local OUTLINE_CVARS = { "graphicsOutlineMode", "OutlineEngineMode", "raidGraphicsOutlineMode", "RAIDOutlineEngineMode" }
-- A graphics change that may have reset the quest sparkle: set again a second later.
local WATCHED = { graphicsquality = true, raidgraphicsquality = true, [QUEST_CVAR:lower()] = true }
for _, n in ipairs(OUTLINE_CVARS) do WATCHED[n:lower()] = true end

local GLINTS = 7
local SIZE = 32          -- a glint at its biggest (px, the nameplate's scale)
local SPREAD = 42        -- the disc they appear in
local DROP = -44         -- from the nameplate down to the thing
local LOOTED_HOLD = 3    -- s a corpse just looted counts as empty (the game still says loot for a moment)
local RESUME_AFTER = 4   -- s a "near a unit" pause lasts at least, then ends once you move
local RESUME_MOVE = 5    -- yards
local START_DELAY = 6    -- s after login: Forever Loot Sparkles puts its old settings back until 5 s

-- ---------------------------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------------------------

local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- A call that may error or answer with a secret: nil then.
local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok or Secret(v) then return nil end
	return v
end

local function DB()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if type(db.sparkles) ~= "table" then db.sparkles = {} end
	return db.sparkles
end

local function GetCV(name)
	if not (C_CVar and C_CVar.GetCVar) then return nil end
	local ok, v = pcall(C_CVar.GetCVar, name)
	if ok and v ~= nil and not Secret(v) then return tostring(v) end
	return nil
end

-- Written only when it differs (each write runs the game's handlers at once).
local function SetCV(name, value)
	value = tostring(value)
	local now = GetCV(name)
	if now == nil or now == value then return end
	pcall(C_CVar.SetCVar, name, value)
end

-- Daylight UI's own windows and the game's that an NPC, mailbox or bank opens.
local WINDOWS = { "AuctionFrame", "AuctionHouseFrame", "MerchantFrame", "MailFrame", "BankFrame",
	"GossipFrame", "QuestFrame", "TaxiFrame", "ClassTrainerFrame", "TradeFrame", "GuildRegistrarFrame",
	"PetStableFrame", "TabardFrame" }
local talking = {}   -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW types open now

local function WindowOpen()
	if next(talking) then return true end
	for _, name in ipairs(WINDOWS) do
		local f = _G[name]
		if type(f) == "table" and f.IsShown and Ask(f.IsShown, f) == true then return true end
	end
	return false
end

-- ---------------------------------------------------------------------------------------------
-- The part and its page
-- ---------------------------------------------------------------------------------------------

local P = ns.Part({ key = KEY, label = L["Loot Sparkles"] })

-- Forever Loot Sparkles' Herbs & Ores companion sparkles the same things.
local companion = (function()
	local A = C_AddOns
	if type(A) ~= "table" or type(A.DoesAddOnExist) ~= "function" or type(A.GetAddOnEnableState) ~= "function" then
		return false
	end
	local okE, exists = pcall(A.DoesAddOnExist, "ForeverLootSparkles_Coloring")
	if not (okE and exists) then return false end
	local okS, state = pcall(A.GetAddOnEnableState, "ForeverLootSparkles_Coloring", UnitGUID and UnitGUID("player") or nil)
	return okS and type(state) == "number" and state > 0
end)()

local defaults = {
	enabled = false,
	quest = true,
	outlineOff = false,
	takeQuest = false,
	glints = not companion,
	ownProfessions = true,
	safeCast = "units",
	hidePlate = true,
	hideIcon = false,
	tint = 0.3,
}
for _, k in ipairs(KINDS) do
	defaults[k.key] = k.id ~= "quest"   -- (quest objects mostly have the game's own sparkle)
	defaults[k.key .. "Color"] = { k.color[1], k.color[2], k.color[3] }
end
P.defaults = defaults

-- Daylight UI's Show quest item sparkles: its value, nil without that page (no QoL module).
local function DaylightQuestOn()
	if ns.standalone then return nil end
	local ok, v = pcall(ns.API.GetSetting, "QoL", "lootSparkles")
	if not ok or v == nil then return nil end
	return v == true
end

local function On() return G("enabled") == true end
local function GlintsOff(get) return get(KEY .. ".enabled") ~= true or get(KEY .. ".glints") ~= true end
local function QuestOff(get) return get(KEY .. ".enabled") ~= true or get(KEY .. ".quest") ~= true end

local function KnowsProfession(prof)
	local spells = PROFESSION[prof]
	if not spells then return true end
	local known = IsPlayerSpell or IsSpellKnown
	if type(known) ~= "function" then return true end
	for _, id in ipairs(spells) do
		if Ask(known, id) == true then return true end
	end
	return false
end

local function KindItems()
	local items = {}
	for _, k in ipairs(KINDS) do
		local prof = k.prof
		items[#items + 1] = { type = "toggle", key = KEY .. "." .. k.key, label = k.label,
			disabled = function(get)
				if GlintsOff(get) then return true end
				return prof ~= nil and get(KEY .. ".ownProfessions") ~= false and not KnowsProfession(prof)
			end,
			desc = prof and L["Only for a character who knows the profession, while Only Your Professions is on."] or nil }
		items[#items + 1] = { type = "color", key = KEY .. "." .. k.key .. "Color", label = k.label,
			disabled = function(get) return GlintsOff(get) or get(KEY .. "." .. k.key) ~= true end }
	end
	return items
end

P.page = { id = KEY, label = L["Loot Sparkles"],
	desc = L["Quest items, herbs, ore and corpses with loot sparkle as you near them."],
	groups = {
		{ label = L["Loot Sparkles"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"],
			  desc = L["Changes some of the game's settings while on (its loot sparkle and the interact key's soft targeting) and puts them back as they were when off."] },
		} },
		{ label = L["Quest Items"], items = {
			{ type = "toggle", key = KEY .. ".quest", label = L["Keep Quest Items Sparkling"],
			  disabled = function(get) return get(KEY .. ".enabled") ~= true end,
			  desc = L["The game's own sparkle on quest items you can loot, set again whenever a graphics preset turns it off. Quest givers sparkle too: the game has one setting for both. Turning it off may only show after you restart the game."] },
			{ type = "toggle", key = KEY .. ".outlineOff", label = L["Outline Off Too"], disabled = QuestOff,
			  desc = L["The game draws either its outline round what you point at or the sparkle on a quest item, never both. On: the outline is off, so the sparkle always shows. Off: your outline setting stays."] },
			{ type = "toggle", key = KEY .. ".takeQuest", label = L["Essentials Keeps Quest Sparkles"],
			  hidden = function() return DaylightQuestOn() == nil and not G("takeQuest") end,
			  disabled = QuestOff,
			  desc = L["Daylight UI's Show Quest Item Sparkles (Quality of Life) does this too. Off: while that is on, Daylight UI keeps them. On: it is turned off while Essentials does it (given back when you log out or turn this off)."] },
		} },
		{ label = L["Herbs, Ore and More"], items = {
			{ type = "toggle", key = KEY .. ".glints", label = L["Sparkle What's Near"],
			  disabled = function(get) return get(KEY .. ".enabled") ~= true end,
			  desc = L["Glints on the herb, vein, corpse or chest the interact key would use, in a color per kind, grey while you can't use it yet. Turns the game's interact key on."] },
			{ type = "text", hidden = function() return not companion end,
			  label = L["Forever Loot Sparkles - Herbs & Ores sparkles these too. While it's on, these wait: the two would hide each other's glints. Turn it off in your addon list to use these."] },
			{ type = "toggle", key = KEY .. ".ownProfessions", label = L["Only Your Professions"], disabled = GlintsOff,
			  desc = L["Herbs, ore and corpses to skin sparkle only for a character who knows Herbalism, Mining or Skinning."] },
		} },
		{ label = L["Kinds"], items = KindItems() },
		{ label = L["Look"], items = {
			{ type = "slider", key = KEY .. ".tint", label = L["Color Strength"], min = 0, max = 1, step = 0.05, unit = "%",
			  disabled = GlintsOff, desc = L["How strongly the glints show their color, so they stay seen on snow and sand. 0 is a plain glow."] },
			{ type = "toggle", key = KEY .. ".hidePlate", label = L["Hide the Name Under It"], disabled = GlintsOff,
			  desc = L["The nameplate the glints hang on (its name, a corpse's empty bar) is see-through, so only the sparkle shows."] },
			{ type = "toggle", key = KEY .. ".hideIcon", label = L["Hide the Interact Icon"], disabled = GlintsOff,
			  desc = L["The game's small icon over a sparkling thing (a pickaxe, a leaf, a hand) is hidden too."] },
		} },
		{ label = L["Safe Self-Cast"], items = {
			{ type = "dropdown", key = KEY .. ".safeCast", label = L["Pause the Interact Key"], disabled = GlintsOff,
			  values = { off = L["Never"], combat = L["In a Fight"], units = L["Near Units Too"] },
			  order = { "off", "combat", "units" },
			  desc = L["A spell cast with no target can land on a unit the interact key picked beside you. In a Fight: paused while you fight. Near Units Too: also while it picks a player or other unit that offers no service, until you move. Vendors, trainers and quest givers are left alone."] },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- What a thing is
-- ---------------------------------------------------------------------------------------------

local probe = UIParent:CreateTexture(nil, "BACKGROUND")
probe:Hide()

-- The cursor the game would show over a unit: its file (id or path) and atlas, as strings in small
-- letters, nil where unreadable.
local function Cursor(unit)
	if Ask(SetUnitCursorTexture, probe, unit, nil, true) ~= true then return nil end
	local file, atlas = Ask(probe.GetTexture, probe), probe.GetAtlas and Ask(probe.GetAtlas, probe)
	return file, atlas
end

-- Cursor files by id where the client knows the paths: kind and whether it's the "Unable" one.
local CURSOR_FILES = { Mine = "ore", GatherHerbs = "herb", PickLock = "lock", Quest = "quest",
	QuestRepeatable = "quest", QuestTurnIn = "quest", Interact = "other", LootAll = "other", Pickup = "other" }
local cursorById = {}
if type(GetFileIDFromPath) == "function" then
	for name, kind in pairs(CURSOR_FILES) do
		for _, unable in ipairs({ false, true }) do
			local path = "Interface\\Cursor\\" .. (unable and "Unable" or "") .. name
			local id = Ask(GetFileIDFromPath, path) or Ask(GetFileIDFromPath, path .. ".blp")
			if id then cursorById[id] = { kind, unable } end
		end
	end
end
local CURSOR_WORDS = { { "herb", "herb" }, { "gather", "herb" }, { "mine", "ore" }, { "picklock", "lock" },
	{ "quest", "quest" }, { "skin", "skin" }, { "lootall", "other" }, { "pickup", "other" }, { "interact", "other" } }

local function CursorWord(s)
	if type(s) ~= "string" then return nil, false end
	s = s:lower()
	local unable = s:find("unable", 1, true) ~= nil
	for _, w in ipairs(CURSOR_WORDS) do
		if s:find(w[1], 1, true) then return w[2], unable end
	end
	return nil, unable
end

local function CursorKind(unit)
	local file, atlas = Cursor(unit)
	local hit = type(file) == "number" and cursorById[file]
	if hit then return hit[1], hit[2] end
	local kind, unable = CursorWord(file)
	if kind then return kind, unable end
	local k2, u2 = CursorWord(atlas)
	return k2, unable or u2
end

-- Quest objectives not done yet, in small letters, read again after the quest log changes.
local objectives, objectivesStale = {}, true
local questByGuid = {}   -- GUID -> part of an unfinished objective (cleared with the log)

local function Clean(s)
	s = s:lower():gsub("\194\160", " "):gsub("%d+%s*/%s*%d+", "")
	return (s:gsub("^[%s:%-]+", ""):gsub("[%s:%-]+$", ""))
end

local function ReadObjectives()
	objectivesStale = false
	wipe(objectives)
	local Q = C_QuestLog
	if not (Q and Q.GetNumQuestLogEntries and Q.GetQuestIDForLogIndex and Q.GetQuestObjectives) then return end
	for i = 1, Ask(Q.GetNumQuestLogEntries) or 0 do
		local id = Ask(Q.GetQuestIDForLogIndex, i)
		local list = type(id) == "number" and id > 0 and Ask(Q.GetQuestObjectives, id)
		if type(list) == "table" then
			for _, o in ipairs(list) do
				if not o.finished and type(o.text) == "string" and not Secret(o.text) then
					local t = Clean(o.text)
					if #t >= 4 then objectives[#objectives + 1] = t end
				end
			end
		end
	end
end

local QUEST_LINE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective

local function ForQuest(unit, name)
	local guid = Ask(UnitGUID, unit)
	if guid and questByGuid[guid] ~= nil then return questByGuid[guid] end
	local yes = false
	if C_QuestLog and Ask(C_QuestLog.UnitIsRelatedToActiveQuest, unit) == true then
		yes = true
	elseif QUEST_LINE and C_TooltipInfo then
		local data = Ask(C_TooltipInfo.GetUnit, unit)
		for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
			if line.type == QUEST_LINE then yes = true break end
		end
	end
	if not yes and type(name) == "string" and #name >= 4 then
		if objectivesStale then ReadObjectives() end
		local n = Clean(name)
		for _, t in ipairs(objectives) do
			if t:find(n, 1, true) or (#t >= 5 and n:find(t, 1, true)) then yes = true break end
		end
	end
	if guid then questByGuid[guid] = yes end
	return yes
end

-- Corpses: the ones just looted count as empty for a moment (LOOTED_HOLD).
local looted = {}   -- GUID -> when its loot window closed (math.huge while open)

local function LootLeft(unit)
	local guid = Ask(UnitGUID, unit)
	if not guid or type(CanLootUnit) ~= "function" then return false end
	local at = looted[guid]
	if at and (at == math.huge or GetTime() - at < LOOTED_HOLD) then return false end
	looted[guid] = nil
	local ok, has, can = pcall(CanLootUnit, guid)
	if not ok or Secret(has) or Secret(can) then return false end
	return has == true and can ~= false
end

-- The "Skinnable" line on a corpse's tooltip (red: skill too low).
local SKINNABLE = {}
for _, t in ipairs({ UNIT_SKINNABLE_LEATHER, UNIT_SKINNABLE_HERB, UNIT_SKINNABLE_ROCK, UNIT_SKINNABLE_BOLTS }) do
	if type(t) == "string" and t ~= "" then SKINNABLE[t] = true end
end
local skinSeen = {}   -- GUID -> { skinnable, tooLow }

local function Skinnable(unit)
	local guid = Ask(UnitGUID, unit)
	local seen = guid and skinSeen[guid]
	if seen then return seen[1], seen[2] end
	local yes, low = false, false
	local kind, unable = CursorKind(unit)
	if kind == "skin" then yes, low = true, unable end
	if not yes and C_TooltipInfo then
		local data = Ask(C_TooltipInfo.GetUnit, unit)
		for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
			local text = line.leftText
			if type(text) == "string" and not Secret(text) and SKINNABLE[text] then
				local c = line.leftColor
				yes = true
				low = type(c) == "table" and type(c.r) == "number" and not Secret(c.r) and c.r > 0.9 and c.g < 0.3 or false
				break
			end
		end
	end
	if guid then skinSeen[guid] = { yes, low } end
	return yes, low
end

local function Allowed(kind)
	local k = KIND[kind]
	if not k or G(k.key) ~= true then return false end
	if k.prof and G("ownProfessions") ~= false and not KnowsProfession(k.prof) then return false end
	return true
end

-- What the unit is, as a kind that may sparkle now, and whether it's greyed (can't use it yet).
local function KindOf(unit)
	if Ask(UnitIsGameObject, unit) == true then
		local kind, unable = CursorKind(unit)
		if kind ~= "herb" and kind ~= "ore" and kind ~= "lock" and ForQuest(unit, Ask(UnitName, unit)) then
			kind = "quest"
		end
		if kind and Allowed(kind) then return kind, unable == true end
		return nil
	end
	if Ask(UnitIsDead, unit) == true and Ask(UnitIsPlayer, unit) ~= true then
		if Allowed("corpse") and LootLeft(unit) then return "corpse", false end
		if Allowed("skin") then
			local yes, low = Skinnable(unit)
			if yes then return "skin", low end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------------------------
-- The glints
-- ---------------------------------------------------------------------------------------------
-- One frame of seven glints, moved onto the plate of whatever sparkles. Each glint is a glow (added
-- light) over the same shape in the kind's color (plain blend: on snow the glow alone washes white),
-- grown, turned and faded by an animation of the game's; each time round it starts somewhere new.

local sparkle   -- { frame, glints, plate, kind, grey }

local function Place(g)
	local a, r = math.random() * 2 * math.pi, math.sqrt(math.random())
	g.holder:ClearAllPoints()
	g.holder:SetPoint("CENTER", sparkle.frame, "CENTER", math.cos(a) * r * SPREAD, math.sin(a) * r * SPREAD * 0.7)
	local s = 0.55 + 0.6 * math.random()
	g.holder:SetSize(SIZE * s, SIZE * s)
end

local function Anim(tex, g)
	local ag = tex:CreateAnimationGroup()
	ag:SetLooping("REPEAT")
	local fadeIn = ag:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.45)
	fadeIn:SetOrder(2)
	fadeIn:SetSmoothing("OUT")
	local grow = ag:CreateAnimation("Scale")
	grow:SetScaleFrom(0.35, 0.35)
	grow:SetScaleTo(1, 1)
	grow:SetDuration(0.45)
	grow:SetOrder(2)
	local spin = ag:CreateAnimation("Rotation")
	spin:SetDegrees(70)
	spin:SetDuration(0.9)
	spin:SetOrder(2)
	local rise = ag:CreateAnimation("Translation")
	rise:SetOffset(0, 9)
	rise:SetDuration(0.9)
	rise:SetOrder(2)
	local fadeOut = ag:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(0.45)
	fadeOut:SetStartDelay(0.45)
	fadeOut:SetOrder(2)
	fadeOut:SetSmoothing("IN")
	-- First a short dark pause (its length set each time round), then the shine somewhere new.
	local rest = ag:CreateAnimation("Alpha")
	rest:SetFromAlpha(0)
	rest:SetToAlpha(0)
	rest:SetDuration(0.1)
	rest:SetOrder(1)
	g.rest = g.rest or {}
	g.rest[#g.rest + 1] = rest
	return ag
end

local function Build()
	if sparkle then return sparkle end
	local f = CreateFrame("Frame")
	f:SetSize(1, 1)
	f:Hide()
	sparkle = { frame = f, glints = {} }
	for i = 1, GLINTS do
		local g = {}
		g.holder = CreateFrame("Frame", nil, f)
		g.tint = g.holder:CreateTexture(nil, "ARTWORK")
		g.tint:SetAllPoints()
		g.tint:SetTexture(GLINT)
		g.tint:SetBlendMode("BLEND")
		g.tint:SetAlpha(0)
		g.glow = g.holder:CreateTexture(nil, "OVERLAY")
		g.glow:SetAllPoints()
		g.glow:SetTexture(GLINT)
		g.glow:SetBlendMode("ADD")
		g.glow:SetAlpha(0)
		g.glowAnim = Anim(g.glow, g)
		g.tintAnim = Anim(g.tint, g)
		-- Each time round: a new spot and pause (the tint's group follows the glow's).
		g.glowAnim:SetScript("OnLoop", function()
			local pause = 0.1 + 0.8 * math.random()
			for _, r in ipairs(g.rest) do r:SetDuration(pause) end
			Place(g)
		end)
		sparkle.glints[i] = g
	end
	-- A corpse's grey name, as the game shows it without this (its own plate is out of reach).
	sparkle.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sparkle.name:SetTextColor(0.62, 0.62, 0.62)
	sparkle.name:Hide()
	return sparkle
end

local function Paint()
	if not sparkle or not sparkle.kind then return end
	local k = KIND[sparkle.kind]
	local c = G(k.key .. "Color")
	if type(c) ~= "table" or type(c[1]) ~= "number" then c = k.color end
	if sparkle.grey then c = GREY end
	local tint = tonumber(G("tint")) or 0.3
	for _, g in ipairs(sparkle.glints) do
		g.glow:SetVertexColor(c[1], c[2], c[3], sparkle.grey and 0.55 or 1)
		g.tint:SetVertexColor(c[1], c[2], c[3], tint)
		g.tint:SetShown(tint > 0)
	end
end

local function Start()
	for i, g in ipairs(sparkle.glints) do
		Place(g)
		-- Staggered, so they don't all flash at once.
		local delay = (i - 1) * 0.13
		for _, r in ipairs(g.rest) do r:SetDuration(delay + 0.05) end
		g.glowAnim:Stop()
		g.tintAnim:Stop()
		g.glowAnim:Play()
		g.tintAnim:Play()
	end
end

local function StopAll()
	for _, g in ipairs(sparkle.glints) do
		g.glowAnim:Stop()
		g.tintAnim:Stop()
	end
end

-- ---------------------------------------------------------------------------------------------
-- The plate under the glints: see-through while they show
-- ---------------------------------------------------------------------------------------------

local veiled = {}        -- frame -> alpha it had
local veilHooked = setmetatable({}, { __mode = "k" })
local veiling = false
local iconHidden         -- { icon, alpha }
local shownThrough       -- { holder, ignored before }: the interact icon shows through the veil

local function Hold(frame, alpha)
	if veiling or veiled[frame] == nil then return end
	if type(alpha) == "number" and not Secret(alpha) then veiled[frame] = alpha end
	if alpha ~= 0 then
		veiling = true
		pcall(frame.SetAlpha, frame, 0)
		veiling = false
	end
end

local function Veil(frame)
	if type(frame) ~= "table" or veiled[frame] ~= nil or frame == sparkle.frame or not frame.SetAlpha then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	local a = Ask(frame.GetAlpha, frame)
	veiled[frame] = type(a) == "number" and a or 1
	if not veilHooked[frame] then
		veilHooked[frame] = true
		pcall(hooksecurefunc, frame, "SetAlpha", Hold)
	end
	veiling = true
	pcall(frame.SetAlpha, frame, 0)
	veiling = false
end

local function IconHolder(plate)
	local uf = plate.UnitFrame
	local h = (type(uf) == "table" and uf.SoftTargetFrame) or plate.SoftTargetFrame
	return type(h) == "table" and h or nil
end

local function Unveil()
	veiling = true
	for frame, a in pairs(veiled) do pcall(frame.SetAlpha, frame, a) end
	veiling = false
	wipe(veiled)
	if iconHidden then
		pcall(iconHidden[1].SetAlpha, iconHidden[1], iconHidden[2])
		iconHidden = nil
	end
	if shownThrough then
		pcall(shownThrough[1].SetIgnoreParentAlpha, shownThrough[1], shownThrough[2])
		shownThrough = nil
	end
	if sparkle then sparkle.name:Hide() end
end

local function Children(f)
	local ok, list = pcall(function() return { f:GetChildren() } end)
	return ok and list or {}
end

-- Everything on the plate but the interact icon (it shows through, or is hidden on its own).
local function VeilPlate(plate)
	local holder = IconHolder(plate)
	local uf = plate.UnitFrame
	if G("hidePlate") ~= false then
		Veil(uf)
		for _, c in ipairs(Children(plate)) do
			if c ~= holder and c ~= sparkle.frame then Veil(c) end
		end
		if holder and holder.SetIgnoreParentAlpha and not shownThrough then
			shownThrough = { holder, Ask(holder.IsIgnoringParentAlpha, holder) == true }
			pcall(holder.SetIgnoreParentAlpha, holder, true)
		end
	end
	if holder and G("hideIcon") == true and not iconHidden then
		local icon = holder.Icon or holder
		local a = Ask(icon.GetAlpha, icon)
		iconHidden = { icon, type(a) == "number" and a or 1 }
		pcall(icon.SetAlpha, icon, 0)
	end
end

local function Release()
	if not sparkle or not sparkle.plate then return end
	Unveil()
	StopAll()
	sparkle.frame:Hide()
	sparkle.frame:ClearAllPoints()
	sparkle.frame:SetParent(UIParent)
	sparkle.plate, sparkle.kind = nil, nil
end

local function Attach(plate, unit, kind, grey)
	Build()
	if sparkle.plate == plate and sparkle.kind == kind then
		if sparkle.grey ~= grey then
			sparkle.grey = grey
			Paint()
		end
		return
	end
	Release()
	local f = sparkle.frame
	sparkle.plate, sparkle.kind, sparkle.grey = plate, kind, grey
	f:SetParent(plate)
	local lvl = Ask(plate.GetFrameLevel, plate)
	if type(lvl) == "number" then f:SetFrameLevel(math.max(lvl - 1, 0)) end
	f:SetPoint("CENTER", plate, "CENTER", 0, DROP)
	f:SetIgnoreParentAlpha(true)
	VeilPlate(plate)
	if (kind == "corpse" or kind == "skin") and G("hidePlate") ~= false then
		local name = Ask(UnitName, unit)
		if type(name) == "string" and name ~= "" then
			local holder = IconHolder(plate)
			sparkle.name:SetText(name)
			sparkle.name:ClearAllPoints()
			if holder then sparkle.name:SetPoint("TOP", holder, "BOTTOM", 0, -2)
			else sparkle.name:SetPoint("CENTER", plate, "CENTER", 0, 0) end
			sparkle.name:Show()
		end
	end
	Paint()
	f:Show()
	Start()
end

-- ---------------------------------------------------------------------------------------------
-- Soft targeting
-- ---------------------------------------------------------------------------------------------

local ready = false      -- after START_DELAY: Forever Loot Sparkles has put its old settings back
local gate               -- the soft target's nameplate: true / false as last written, nil unknown
local paused             -- nil, "combat" or "unit"
local pausedAt, pausedY, pausedX
local pending            -- a game setting to write once the fight or the NPC window is over
local plates = {}        -- nameplate tokens shown now

-- Forever Loot Sparkles - Herbs & Ores loaded now: its glints and these would hang on the same
-- nameplate, and each hides everything else there (the other's glints too), so neither would
-- show. These wait while it's loaded.
local function CompanionLoaded()
	local A = C_AddOns
	return type(A) == "table" and type(A.IsAddOnLoaded) == "function"
		and A.IsAddOnLoaded("ForeverLootSparkles_Coloring") == true
end

local function GlintsWanted()
	if not (On() and G("glints") == true) or CompanionLoaded() then return false end
	for _, k in ipairs(KINDS) do
		if Allowed(k.id) then return true end
	end
	return false
end

local function CanWrite()
	if InCombatLockdown() or WindowOpen() then
		pending = true
		return false
	end
	return true
end

local function SetGate(open)
	if gate == open or not CanWrite() then return end
	gate = open
	SetCV(GATE, open and "1" or "0")
end

local function SoftOn()
	if not CanWrite() then return end
	local s = DB()
	s.soft = s.soft or {}
	for name, v in pairs(SOFT_CVARS) do
		if s.soft[name] == nil then s.soft[name] = GetCV(name) or false end
		if not (name == "SoftTargetInteract" and paused) then SetCV(name, v) end
	end
	if s.soft[GATE] == nil then s.soft[GATE] = GetCV(GATE) or false end
	gate = nil
end

local function SoftBack()
	local s = DB()
	if not s.soft then return end
	if not CanWrite() then return end
	for name, v in pairs(s.soft) do
		if v ~= false then SetCV(name, v) end
	end
	s.soft, s.pausedInteract, paused, gate = nil, nil, nil, nil
end

local function Pos()
	local ok, y, x = pcall(UnitPosition, "player")
	if ok and type(y) == "number" and type(x) == "number" and not Secret(y) and not Secret(x) then return y, x end
	return nil
end

local Evaluate

local function Resume()
	if not paused or InCombatLockdown() or WindowOpen() then return end
	paused = nil
	local s = DB()
	if s.pausedInteract ~= nil then
		if GetCV("SoftTargetInteract") == "0" then SetCV("SoftTargetInteract", s.pausedInteract) end
		s.pausedInteract = nil
	end
	gate = nil
	Evaluate()
end

-- Ends a "near a unit" pause once you've moved a few yards (or, where the game won't say where you
-- are, once the wait is over). Asked when you stop moving and once when the wait is up.
local function MaybeResume()
	if paused ~= "unit" or GetTime() - pausedAt < RESUME_AFTER then return end
	local y, x = Pos()
	if y and pausedY then
		local dy, dx = y - pausedY, x - pausedX
		if dy * dy + dx * dx < RESUME_MOVE * RESUME_MOVE then return end
	end
	Resume()
end

local function Pause(why)
	if paused then
		if why == "combat" then paused = "combat" end
		return
	end
	if InCombatLockdown() or WindowOpen() then return end
	local now = GetCV("SoftTargetInteract")
	if now == nil or now == "0" then return end
	DB().pausedInteract = now
	paused, pausedAt = why, GetTime()
	pausedY, pausedX = Pos()
	SetCV("SoftTargetInteract", "0")
	if why == "unit" then C_Timer.After(RESUME_AFTER + 0.1, MaybeResume) end
end

-- A unit you talk to, not cast on: a vendor, trainer, flight master, quest giver...
local SERVICE = { "speak", "buy", "repair", "taxi", "trainer", "innkeeper", "mail", "directions", "quest",
	"interact", "bank", "auction", "transmog" }
local function Service(unit)
	if Ask(UnitIsPlayer, unit) ~= false or Ask(UnitPlayerControlled, unit) == true
		or Ask(UnitCanAttack, "player", unit) == true then
		return false
	end
	local file, atlas = Cursor(unit)
	for _, s in ipairs({ file, atlas }) do
		if type(s) == "string" then
			s = s:lower()
			for _, w in ipairs(SERVICE) do
				if s:find(w, 1, true) then return true end
			end
		elseif type(s) == "number" then
			local hit = cursorById[s]
			if hit and (hit[1] == "quest" or hit[1] == "other") then return true end
		end
	end
	return false
end

-- The soft target's plate: by its own token, else among the plates shown.
local function TargetPlate()
	local NP = C_NamePlate
	if not NP then return nil end
	local plate = Ask(NP.GetNamePlateForUnit, SOFT)
	if plate then return SOFT, plate end
	for token in pairs(plates) do
		if Ask(UnitIsUnit, token, SOFT) == true then
			plate = Ask(NP.GetNamePlateForUnit, token)
			if plate then return token, plate end
		end
	end
	return SOFT, nil
end

local function SoftExists()
	return Ask(UnitExists, SOFT) == true or Ask(UnitIsGameObject, SOFT) == true
end

function Evaluate()
	if not ready or WindowOpen() then return end
	if not GlintsWanted() then
		Release()
		return
	end
	if not SoftExists() then
		Release()
		return
	end
	local unit, plate = TargetPlate()
	local kind, grey = KindOf(unit)
	if not kind then
		SetGate(false)
		Release()
		-- A living unit picked: in "near units" mode the interact key rests a moment.
		if G("safeCast") == "units" and Ask(UnitIsDead, unit) == false and Ask(UnitIsGameObject, unit) ~= true
			and not Service(unit) then
			Pause("unit")
		end
		return
	end
	SetGate(true)
	if not plate then return end   -- (asked for just now: it comes with NAME_PLATE_UNIT_ADDED)
	Attach(plate, unit, kind, grey)
end

-- ---------------------------------------------------------------------------------------------
-- Quest items (the game's own sparkle), and Daylight UI's copy of it
-- ---------------------------------------------------------------------------------------------

local override   -- the me.Override handle while Daylight UI's switch is off for us

local function QuestMine()
	if not (On() and G("quest") == true) then return false end
	local dui = DaylightQuestOn()
	if dui == nil or override then return true end
	if dui then return G("takeQuest") == true end
	return true
end

local function Handover()
	local want = On() and G("quest") == true and G("takeQuest") == true and not ns.standalone
	if want and not override and DaylightQuestOn() == true and type(ns.me.Override) == "function" then
		local ok, h = pcall(ns.me.Override, "QoL", "lootSparkles", false)
		override = ok and h or nil
	elseif not want and override then
		-- (Forgotten first: giving it back fires SettingChanged, which mustn't read as the player's.)
		local h = override
		override = nil
		pcall(ns.API.Off, h)
	end
end

local function QuestApply()
	if not CanWrite() then return end
	local s = DB()
	if QuestMine() then
		if s.quest == nil then s.quest = GetCV(QUEST_CVAR) or false end
		SetCV(QUEST_CVAR, "1")
		-- (Taken from Daylight UI, the outline goes as it had it.)
		if G("outlineOff") == true or override then
			s.outline = s.outline or {}
			for _, n in ipairs(OUTLINE_CVARS) do
				if s.outline[n] == nil then s.outline[n] = GetCV(n) or false end
				SetCV(n, "0")
			end
		elseif s.outline then
			for n, v in pairs(s.outline) do if v ~= false then SetCV(n, v) end end
			s.outline = nil
		end
	else
		-- Given back only while Daylight UI isn't keeping it itself.
		if s.quest ~= nil and DaylightQuestOn() ~= true then
			if s.quest ~= false then SetCV(QUEST_CVAR, s.quest) end
		end
		s.quest = nil
		if s.outline and DaylightQuestOn() ~= true then
			for n, v in pairs(s.outline) do if v ~= false then SetCV(n, v) end end
		end
		s.outline = nil
	end
end

-- ---------------------------------------------------------------------------------------------
-- Putting it together
-- ---------------------------------------------------------------------------------------------

local function Sync()
	Handover()
	QuestApply()
	if not ready then return end
	if GlintsWanted() then
		SoftOn()
		if paused and G("safeCast") == "off" then Resume() end
		if paused == "unit" and G("safeCast") ~= "units" then Resume() end
	else
		Release()
		SoftBack()
	end
	skinSeen = {}
	Evaluate()
end

local events = CreateFrame("Frame")
local H = {}

function H.PLAYER_SOFT_INTERACT_CHANGED() Evaluate() end

function H.NAME_PLATE_UNIT_ADDED(token)
	if type(token) == "string" then plates[token] = true end
	Evaluate()
end

function H.NAME_PLATE_UNIT_REMOVED(token)
	if type(token) == "string" then plates[token] = nil end
	local plate = C_NamePlate and Ask(C_NamePlate.GetNamePlateForUnit, token)
	if sparkle and plate and plate == sparkle.plate then Release() end
end

function H.QUEST_LOG_UPDATE()
	objectivesStale = true
	wipe(questByGuid)
end

function H.LOOT_OPENED()
	local function Mark(guid) if type(guid) == "string" and not Secret(guid) then looted[guid] = math.huge end end
	if type(GetLootSourceInfo) == "function" then
		for slot = 1, Ask(GetNumLootItems) or 0 do Mark(Ask(GetLootSourceInfo, slot)) end
	end
	Mark(Ask(UnitGUID, SOFT))
	Mark(Ask(UnitGUID, "target"))
	if sparkle and sparkle.kind == "corpse" then Release() end
end

function H.LOOT_CLOSED()
	local now = GetTime()
	for guid, at in pairs(looted) do
		if at == math.huge then looted[guid] = now elseif now - at >= LOOTED_HOLD then looted[guid] = nil end
	end
	wipe(skinSeen)
	Evaluate()
	-- Once the hold is over, what's left in a corpse (or its skin) sparkles.
	C_Timer.After(LOOTED_HOLD + 0.1, Evaluate)
end

-- In a fight no game setting can change: the nameplate is closed just before (else a corpse would
-- keep an empty one all fight; the price is no glints in a fight) and the interact key paused.
function H.PLAYER_REGEN_DISABLED()
	if not (ready and GlintsWanted()) then return end
	gate = nil
	SetCV(GATE, "0")
	Release()
	if G("safeCast") ~= "off" then Pause("combat") end
end

function H.PLAYER_REGEN_ENABLED()
	if paused == "combat" then Resume() end
	if pending then
		pending = false
		Sync()
	else
		Evaluate()
	end
end

function H.PLAYER_STOPPED_MOVING() MaybeResume() end

function H.PLAYER_INTERACTION_MANAGER_FRAME_SHOW(t) talking[t or "?"] = true end

function H.PLAYER_INTERACTION_MANAGER_FRAME_HIDE(t)
	if t ~= nil and talking[t] then talking[t] = nil else wipe(talking) end
	if pending and not WindowOpen() and not InCombatLockdown() then
		pending = false
		Sync()
	end
end

function H.PLAYER_ENTERING_WORLD()
	wipe(talking)   -- a loading screen closes every NPC window
	if ready then Sync() end
end

-- A graphics change (the player's or a preset's) may have reset the quest sparkle or the outline:
-- set again once it settles.
local again
function H.CVAR_UPDATE(name)
	if type(name) ~= "string" or Secret(name) or not WATCHED[name:lower()] or again then return end
	if not QuestMine() then return end
	again = true
	C_Timer.After(1, function()
		again = false
		QuestApply()
	end)
end

-- Learning or forgetting a profession.
function H.SKILL_LINES_CHANGED() if ready then Sync() end end

events:SetScript("OnEvent", function(_, event, ...)
	local fn = H[event]
	if fn then
		local ok, err = pcall(fn, ...)
		if not ok then geterrorhandler()(err) end
	end
end)

local listening = false
local function Listen(on)
	if on == listening then return end
	listening = on
	for event in pairs(H) do
		if on then pcall(events.RegisterEvent, events, event) else pcall(events.UnregisterEvent, events, event) end
	end
end

function P.Login()
	-- What was paused when the game last closed comes back (a logout mid-pause).
	local s = DB()
	if s.pausedInteract ~= nil and not On() then
		SetCV("SoftTargetInteract", s.pausedInteract)
		s.pausedInteract = nil
	end
	Listen(true)
	Handover()
	QuestApply()
	C_Timer.After(START_DELAY, function()
		ready = true
		if s.pausedInteract ~= nil and not InCombatLockdown() then
			paused = "unit"
			pausedAt = -math.huge
			Resume()
		end
		Sync()
	end)
end

function P.Setting() Sync() end

-- Daylight UI's own switch changed (by the player, or by the end of our override).
if ns.me and ns.me.On then
	ns.me.On("SettingChanged", function(scope, path)
		if scope ~= "QoL" or path ~= "lootSparkles" then return end
		if override and DaylightQuestOn() == true then
			-- Turned back on in Daylight UI: the player's pick. Ours stands down.
			override = nil
			pcall(ns.DUI.Set, ns.DUI, ADDON, KEY .. ".takeQuest", false)
		end
		QuestApply()
	end)
end
