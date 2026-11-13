-- Gone Camping: every camp object you can put down (campfires and each profession's camp pieces,
-- spells or items) behind one small tent button in the DaylightUI look. Click the tent and they
-- fan out; click one to place it. Beside the tent, a short note of what has run out or is about
-- to: Well Fed, your weapon's oil or stone, and the camp buffs you choose to watch, plus when the
-- camp objects' shared cooldown is up. A Sit button rests you at the fire (camp buffs need a
-- minute of rest). Hidden in a fight. Move it with /dui unlock.
-- (The idea is from Camping Kit by Shuklock, All Rights Reserved: only the idea is used; this is
-- written from scratch, from the game's public camping rules.)
--
-- Finding your camp objects: by name (the campfires and every profession's camp pieces, as the
-- game names them in English; a "... Kit" item too), in your spellbook, your bags and your toy box. Anything it
-- misses: drag it onto the tent. Anything you don't want: right-click it in the fan (/dui camp
-- reset brings everything back).
--
-- Secure buttons: placing an object is a protected action, so each one in the fan is a secure
-- button, made, filled and laid out out of a fight only. A state driver hides them in a fight.
--
-- What it costs: nothing while it's off. On, a look when your buffs, bags, spells or weapon
-- change (gathered to one look a moment later); while a countdown shows beside the tent, one
-- look every 10 seconds. No timers otherwise.

local _, ns = ...
if ns.off then return end

local API = ns.API
local KEY = "goneCamping"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = "Gone Camping" })

P.defaults = {
	enabled = true,
	direction = "up",
	slotSize = 32,
	closeAfter = true,
	sit = true,
	fadeIdle = false,
	scale = 1,
	remind = "always",
	fed = true,
	weapon = true,
	warn = 3,
}

local NONE = "-"

-- ---------------------------------------------------------------------------------------------
-- Saved: account-wide, in DaylightEssentialsDB.camping
--   extra = { "spell:123" | "item:456", ... } added by drag; hidden = { [key] = true };
--   buffs = { "Buff name", ... } (up to three) watched camp buffs
-- ---------------------------------------------------------------------------------------------

local function DB()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if type(db.camping) ~= "table" then db.camping = {} end
	local c = db.camping
	if type(c.extra) ~= "table" then c.extra = {} end
	if type(c.hidden) ~= "table" then c.hidden = {} end
	if type(c.buffs) ~= "table" then c.buffs = {} end
	if type(c.toys) ~= "table" then c.toys = {} end   -- camp toys found once (item id -> true)
	return c
end

-- ---------------------------------------------------------------------------------------------
-- Camp objects by name (English, as the game names them)
-- ---------------------------------------------------------------------------------------------

local CAMP = {
	"Basic Campfire", "Journeyman Campfire", "Expert Campfire", "Cookie's Feast", "Iron Oven",
	"Mana Well", "Fermenter", "Alchemy Laboratory",
	"Sharpening Wheel", "Anvil", "Master Forge",
	"Enchanted Lute", "Arcane Salvager", "Arcane Forge",
	"Reagent Bot", "Repair Bot", "Anarchist's Workbench",
	"First Aid Kit",
	"Fishing Bowl", "Fish Bowl", "Fishing Rack", "Fishing Hut",
	"Incense Candle", "Greenhouse", "Seed Hybridizer",
	"Camp Tent", "Tanning Rack", "Sewing Machine",
	"Camp Chair", "Field Guide", "Trapper's Workbench",
	"Faction Banner", "Spinning Wheel", "Loom",
	"Cozy Sleeping Bag", "Pouch of Violet Dust",
}
local CAMP_SET = {}
for _, n in ipairs(CAMP) do CAMP_SET[string.lower(n)] = true end

local function IsCampName(name)
	if type(name) ~= "string" then return false end
	local n = string.lower(name)
	if n:find("^blueprint") or n:find("^recipe") or n:find("^plans") or n:find("^schematic") then return false end
	if CAMP_SET[n] then return true end
	local base = n:match("^(.-) kit$")
	return base ~= nil and CAMP_SET[base] == true
end

local function IsFire(name)
	local n = string.lower(name or "")
	return n:find("campfire") ~= nil or n:find("feast") ~= nil or n:find("oven") ~= nil
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, n = pcall(C_Spell.GetSpellName, id)
		if ok and type(n) == "string" then return n end
	end
	return nil
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, t = pcall(C_Spell.GetSpellTexture, id)
		if ok and t then return t end
	end
	return 134400
end

local function ItemName(id)
	if C_Item and C_Item.GetItemNameByID then
		local ok, n = pcall(C_Item.GetItemNameByID, id)
		if ok and type(n) == "string" then return n end
	end
	return nil
end

local function ItemIcon(id)
	if C_Item and C_Item.GetItemIconByID then
		local ok, t = pcall(C_Item.GetItemIconByID, id)
		if ok and t then return t end
	end
	return 134400
end

local function ItemCount(id)
	local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
	if not fn then return 0 end
	local ok, n = pcall(fn, id)
	return (ok and type(n) == "number") and n or 0
end

-- A toy you own: its name and icon, or nil.
local function ToyInfo(id)
	if not (C_ToyBox and C_ToyBox.GetToyInfo) then return nil end
	if PlayerHasToy then
		local ok, has = pcall(PlayerHasToy, id)
		if not ok or not has then return nil end
	end
	local ok, _, name, icon = pcall(C_ToyBox.GetToyInfo, id)
	if ok and type(name) == "string" and name ~= "" then return name, icon end
	return nil
end

-- The toys in the toy box (Pouch of Violet Dust and such live there, not in your bags): the ones
-- its list shows now, plus every camp toy found before (the list follows the Toys tab's filters,
-- so one hidden there later is still known).
local function ToyIds()
	local ids, seen = {}, {}
	local box = C_ToyBox
	if box and box.GetNumFilteredToys and box.GetToyFromIndex then
		local okN, n = pcall(box.GetNumFilteredToys)
		for i = 1, (okN and type(n) == "number") and n or 0 do
			local ok, id = pcall(box.GetToyFromIndex, i)
			if ok and type(id) == "number" and id > 0 and not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
	end
	for id in pairs(DB().toys) do
		if type(id) == "number" and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end
	return ids
end

-- Every known spell, name -> highest spell id (the spellbook, out of a fight).
local lastBook = {}   -- your spellbook as last read (name -> id), for what an object does
local function Spellbook()
	local out = {}
	local book = C_SpellBook
	if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo) then
		return out
	end
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
	local okN, lines = pcall(book.GetNumSpellBookSkillLines)
	for i = 1, (okN and type(lines) == "number") and lines or 0 do
		local okL, line = pcall(book.GetSpellBookSkillLineInfo, i)
		if okL and type(line) == "table" then
			local first = (line.itemIndexOffset or 0) + 1
			for slot = first, first + (line.numSpellBookItems or 0) - 1 do
				local okI, info = pcall(book.GetSpellBookItemInfo, slot, bank)
				if okI and type(info) == "table" and info.itemType == spellType and not info.isPassive
					and type(info.name) == "string" and type(info.spellID) == "number" then
					local have = out[info.name]
					if not have or info.spellID > have then out[info.name] = info.spellID end
				end
			end
		end
	end
	return out
end

-- The objects you have now: { key, kind, id, name, icon, fire } in fan order (campfires first).
local objects = {}
local waitingNames = false   -- an item's name wasn't cached yet: looked at again when it is

local function Gather()
	wipe(objects)
	waitingNames = false
	local db = DB()
	local seen = {}
	local function Add(kind, id, name, icon)
		local key = kind .. ":" .. id
		if seen[key] or db.hidden[key] then return end
		seen[key] = true
		objects[#objects + 1] = { key = key, kind = kind, id = id, name = name, icon = icon, fire = IsFire(name) }
	end
	lastBook = Spellbook()
	for name, id in pairs(lastBook) do
		if IsCampName(name) then Add("spell", id, name, SpellIcon(id)) end
	end
	local bags = NUM_BAG_SLOTS or 4
	if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
		for bag = 0, bags do
			local okS, slots = pcall(C_Container.GetContainerNumSlots, bag)
			for slot = 1, (okS and type(slots) == "number") and slots or 0 do
				local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
				if okI and type(info) == "table" and type(info.itemID) == "number" then
					local name = ItemName(info.itemID)
					if not name then waitingNames = true
					elseif IsCampName(name) then Add("item", info.itemID, name, info.iconFileID or ItemIcon(info.itemID)) end
				end
			end
		end
	end
	for _, id in ipairs(ToyIds()) do
		local name, icon = ToyInfo(id)
		if name and IsCampName(name) then
			db.toys[id] = true
			Add("toy", id, name, icon or ItemIcon(id))
		end
	end
	-- Added by hand (drag onto the tent), while you still have it.
	for _, key in ipairs(db.extra) do
		local kind, id = key:match("^(%a+):(%d+)$")
		id = tonumber(id)
		if kind == "spell" and id and ((IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))) then
			Add("spell", id, SpellName(id) or ("Spell " .. id), SpellIcon(id))
		elseif kind == "item" and id and ItemCount(id) > 0 then
			Add("item", id, ItemName(id) or ("Item " .. id), ItemIcon(id))
		elseif kind == "toy" and id then
			local name, icon = ToyInfo(id)
			if name then Add("toy", id, name, icon or ItemIcon(id)) end
		end
	end
	table.sort(objects, function(a, b)
		if a.fire ~= b.fire then return a.fire end
		return a.name < b.name
	end)
end

-- The time left on a spell's or item's cooldown (seconds; 0 when ready). Out of a fight only.
local function CooldownLeft(o)
	local start, duration
	if o.kind == "spell" and C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, o.id)
		if ok and type(info) == "table" then start, duration = info.startTime, info.duration end
	elseif (o.kind == "item" or o.kind == "toy") and C_Container and C_Container.GetItemCooldown then
		local ok, s, d = pcall(C_Container.GetItemCooldown, o.id)
		if ok then start, duration = s, d end
	end
	if not (Safe(start) and Safe(duration)) or type(start) ~= "number" or type(duration) ~= "number" then return 0, 0, 0 end
	if duration <= 1.5 then return 0, start, duration end   -- (the global cooldown)
	return math.max(0, start + duration - GetTime()), start, duration
end

-- ---------------------------------------------------------------------------------------------
-- What has run out
-- ---------------------------------------------------------------------------------------------

local WELL_FED = 19705   -- the "Well Fed" buff (any food's: they share the name)

-- The player's buffs: name -> seconds left (math.huge for none), or nil if unreadable.
local auraIds = {}   -- name -> auraInstanceID, from the last MyBuffs (to read a buff's tooltip)
local function MyBuffs()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local out = {}
	wipe(auraIds)
	local now = GetTime()
	for i = 1, 40 do
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok or not Safe(data) then return nil end
		if data == nil then break end
		local name, exp = data.name, data.expirationTime
		if not (Safe(name) and Safe(exp)) then return nil end
		if type(name) == "string" then
			local left = (type(exp) == "number" and exp > 0) and (exp - now) or math.huge
			if not out[name] or left > out[name] then
				out[name] = left
				local id = data.auraInstanceID
				if Safe(id) then auraIds[name] = id end
			end
		end
	end
	return out
end

-- The camp's buffs, as the game names them: sitting by a lit fire puts "Welcoming Campfire" on
-- you with a countdown; when it ends, "Camp Benefits" holds the effects of every camp object at
-- that fire. The objects on the ground can't be read by an addon, only these two buffs.
-- The camp's buffs by the game's ids (their names then come from the game, in its language):
-- Campfire Nearby while you're inside a camp, Welcoming Campfire while you sit (the countdown),
-- Camp Benefits after, Violet Flames by a fire turned purple (Pouch of Violet Dust: camp buffs last
-- two hours). English names until the game has the spells' data (ResolveNames at login).
local AURA = { nearby = 1283391, sitting = 1289723, benefits = 1229741, violet = 1328375 }
local CAMP_BUFF, SITTING, NEARBY, VIOLET = "Camp Benefits", "Welcoming Campfire", "Campfire Nearby", "Violet Flames"
local function ResolveNames()
	CAMP_BUFF = SpellName(AURA.benefits) or CAMP_BUFF
	SITTING = SpellName(AURA.sitting) or SITTING
	NEARBY = SpellName(AURA.nearby) or NEARBY
	VIOLET = SpellName(AURA.violet) or VIOLET
end

-- ---------------------------------------------------------------------------------------------
-- What's at this camp
-- ---------------------------------------------------------------------------------------------
-- The game doesn't list a camp's objects for addons, so it's pieced together while you're inside
-- one (Campfire Nearby on you): each campfire and camp object you mouse over in the world (its
-- tooltip names it, and its lines say what it gives), and each one you or your group put down.
-- The fire's tier says how many objects the camp takes (Basic 3, Journeyman 5, Expert 10); the
-- game's "no room" error says it's full. Walking away (or to another fire) starts over.

local FIRES = { ["basic campfire"] = 3, ["journeyman campfire"] = 5, ["expert campfire"] = 10 }
local WORLD_NAMES = { ["chair"] = "Camp Chair" }   -- objects named differently in the world
local camp = { list = {}, byName = {}, fire = nil, slots = nil, full = false, aura = nil }

local function NearbyAura()
	if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
	local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, AURA.nearby)
	if not ok or not Safe(a) or type(a) ~= "table" then return nil end
	local id = a.auraInstanceID
	return Safe(id) and id or true
end
local function AtCamp() return NearbyAura() ~= nil end

local function ResetCamp()
	wipe(camp.list)
	wipe(camp.byName)
	camp.fire, camp.slots, camp.full = nil, nil, false
end

-- A world object or a cast seen at the camp. True if the camp's picture changed.
local function NoteObject(name, lines, spellID)
	if type(name) ~= "string" or name == "" then return false end
	name = WORLD_NAMES[name:lower()] or name
	local low = name:lower()
	if FIRES[low] then
		if camp.fire == name then return false end
		camp.fire, camp.slots = name, FIRES[low]
		return true
	end
	if not IsCampName(name) or IsFire(name) then return false end
	local e, changed = camp.byName[low], false
	if not e then
		e = { name = name, spell = spellID }
		camp.byName[low] = e
		camp.list[#camp.list + 1] = e
		changed = true
	end
	if lines and #lines > 0 then
		e.lines, changed = lines, true
	elseif not e.lines then
		-- Not moused over yet: what the spell says it does, if it's one you know (or was cast).
		local id = spellID or lastBook[name]
		if id and C_Spell and C_Spell.GetSpellDescription then
			local ok, d = pcall(C_Spell.GetSpellDescription, id)
			if ok and Safe(d) and type(d) == "string" and d ~= "" then e.lines, changed = { d }, true end
		end
	end
	return changed
end

-- A buff's tooltip lines under its name (what it gives), or nil.
local function BuffLines(name)
	local id = auraIds[name]
	if not id or not (C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID) then return nil end
	local ok, info = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", id)
	if not ok or type(info) ~= "table" or type(info.lines) ~= "table" then return nil end
	local out = {}
	for i = 2, #info.lines do
		local t = info.lines[i] and info.lines[i].leftText
		if Safe(t) and type(t) == "string" and t ~= "" and not t:lower():find("remaining$") then out[#out + 1] = t end
	end
	return out
end

local function Seconds(sec)
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function Minutes(sec)
	if sec >= 3600 then return string.format("%dh %dm", math.floor(sec / 3600), math.floor(sec % 3600 / 60)) end
	if sec >= 60 then return string.format("%dm", math.ceil(sec / 60)) end
	return "<1m"
end

local function RemindHere()
	local where = G("remind") or "always"
	if where == "off" then return false end
	if where == "group" then return IsInGroup() end
	if where == "instance" then
		local inside, kind = IsInInstance()
		return inside and (kind == "party" or kind == "raid")
	end
	return true
end

local function IsWeapon(slot)
	local id = GetInventoryItemID("player", slot)
	if not id then return false end
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
		if ok and Safe(classID) then return classID == 2 end   -- (2: weapons)
	end
	return slot == 16
end

-- The notes to show: { text, warn } each, and whether any is a countdown (needs a look later).
local fast = false   -- sitting by the fire: a look every second
local function Notes()
	local notes, counting = {}, false
	fast = false
	if not RemindHere() then return notes, false end
	local warn = (G("warn") or 3) * 60
	local buffs = MyBuffs()
	if buffs then
		-- (Well Fed, Camp Benefits, the sitting countdown and the camp have their own icons.)
		if buffs[SITTING] and buffs[SITTING] < math.huge then fast = true end
		for _, name in ipairs(DB().buffs) do
			local left = buffs[name]
			if name == CAMP_BUFF then
				-- (the tent's border says it)
			elseif not left then
				notes[#notes + 1] = { "Gone: " .. name, true }
			elseif left < math.huge and left <= warn then
				notes[#notes + 1] = { name .. ": " .. Minutes(left), true }
				counting = true
			elseif left < math.huge then counting = counting or left - warn < 600 end
		end
	end
	if G("weapon") and GetWeaponEnchantInfo then
		local ok, hasMain, mainExp, _, _, hasOff, offExp = pcall(GetWeaponEnchantInfo)
		if ok and Safe(hasMain) and Safe(hasOff) and Safe(mainExp) and Safe(offExp) then
			local function Check(slot, has, exp, word)
				if not IsWeapon(slot) then return end
				if not has then
					notes[#notes + 1] = { "No oil or stone" .. word, true }
				elseif type(exp) == "number" and exp / 1000 <= warn then
					notes[#notes + 1] = { "Oil or stone" .. word .. ": " .. Minutes(exp / 1000), true }
					counting = true
				end
			end
			Check(16, hasMain, mainExp, "")
			Check(17, hasOff, offExp, " (off hand)")
		end
	end
	-- The camp pieces' shared cooldown: shown while every one of them is cooling down.
	local soonest
	for _, o in ipairs(objects) do
		if not o.fire and o.kind ~= "toy" then
			local left = CooldownLeft(o)
			if left <= 0 then soonest = nil break end
			soonest = soonest and math.min(soonest, left) or left
		end
	end
	if soonest then
		notes[#notes + 1] = { "Camp pieces ready in " .. Minutes(soonest), false }
		counting = true
	end
	return notes, counting
end

-- ---------------------------------------------------------------------------------------------
-- Settings page
-- ---------------------------------------------------------------------------------------------

local function Off(get) return get(KEY .. ".enabled") == false end
local function NoRemind(get) return Off(get) or get(KEY .. ".remind") == "off" end

local function BuffRow(i)
	return { type = "dropdown", label = "Camp buff " .. i,
		desc = i == 1 and "A buff to watch: you're told when it's gone or about to be. Lists the buffs on you now, so pick them while you're at the camp. Kept for all your characters." or nil,
		default = function() return NONE end,
		get = function()
			local v = DB().buffs[i]
			return type(v) == "string" and v or NONE
		end,
		set = function(v)
			local list = DB().buffs
			list[i] = (v ~= NONE and type(v) == "string") and v or nil
			-- Kept in order, no gaps.
			local packed = {}
			for j = 1, 3 do if type(list[j]) == "string" then packed[#packed + 1] = list[j] end end
			DB().buffs = packed
			if P.Look then P.Look() end
			return true
		end,
		shownAs = function(v)
			if v == NONE then return "None" end
			if #v > 15 then return v:sub(1, 13) .. ".." end
			return v
		end,
		choices = function()
			local values, keys = { [NONE] = "None" }, {}
			for name in pairs(MyBuffs() or {}) do values[name] = name end
			local cur = DB().buffs[i]
			if type(cur) == "string" then values[cur] = cur end
			for k in pairs(values) do if k ~= NONE then keys[#keys + 1] = k end end
			table.sort(keys)
			table.insert(keys, 1, NONE)
			return values, keys
		end,
		disabled = NoRemind }
end

P.page = { id = KEY, label = "Gone Camping",
	desc = "Your camp objects in one tent button, and what has run out.",
	groups = {
		{ label = "Gone Camping",
		  desc = "Click the tent to fan out every camp object you can put down; click one to place it. Missing one? Drag it onto the tent. Right-click one in the fan to leave it out (/dui camp reset brings them back). Hidden in a fight.",
		  items = {
			{ type = "toggle", key = KEY .. ".enabled", label = "On" },
			{ type = "dropdown", key = KEY .. ".direction", label = "Fan out", disabled = Off,
			  values = { up = "Up", down = "Down", left = "Left", right = "Right" },
			  order = { "up", "down", "left", "right" } },
			{ type = "toggle", key = KEY .. ".closeAfter", label = "Close after placing one", disabled = Off },
			{ type = "toggle", key = KEY .. ".sit", label = "A Sit button", disabled = Off,
			  desc = "Sit down at the camp: its buffs come after a minute of rest." },
			{ type = "toggle", key = KEY .. ".fadeIdle", label = "Fade when idle", disabled = Off,
			  desc = "The tent fades while nothing needs you and the mouse is away." },
			{ type = "slider", key = KEY .. ".slotSize", label = "Icon size", min = 24, max = 48, step = 1, unit = "px", disabled = Off },
			{ type = "slider", key = KEY .. ".scale", label = "Size", min = 0.7, max = 2, step = 0.05, unit = "%", disabled = Off },
		} },
		{ label = "Reminders",
		  desc = "Short notes beside the tent while something has run out or is about to: Well Fed, your weapon's oil or stone, and up to three camp buffs you pick. Also when the camp pieces' shared cooldown is up. Never in a fight.",
		  items = {
			{ type = "dropdown", key = KEY .. ".remind", label = "Remind me", disabled = Off,
			  values = { always = "Always", group = "In a group", instance = "In instances", off = "Off" },
			  order = { "always", "group", "instance", "off" },
			  desc = "In instances: dungeons and raids only." },
			{ type = "toggle", key = KEY .. ".fed", label = "Well Fed", disabled = NoRemind },
			{ type = "toggle", key = KEY .. ".weapon", label = "Weapon oil or stone", disabled = NoRemind,
			  desc = "For each hand holding a weapon." },
			{ type = "slider", key = KEY .. ".warn", label = "Minutes of warning", min = 0, max = 10, step = 1, disabled = NoRemind,
			  desc = "How long before a buff runs out the note shows. 0: only once it's gone." },
			BuffRow(1), BuffRow(2), BuffRow(3),
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- The tent, the fan and the notes
-- ---------------------------------------------------------------------------------------------

local TENT, GAP, PAD = 34, 4, 6
local DEFAULT = { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 380, 260 }
local TENT_ICON = "Interface\\Icons\\Spell_Fire_Fire"   -- a campfire

local frame, tent, tentIcon   -- frame: what /dui unlock moves
local fedBox                  -- the smaller box to the tent's left: Well Fed
local campIcons = {}          -- small icons beside the tent: the objects at this camp
local FED, CAMP_ICON = 24, 18
local GREEN, YELLOW, RED = { 0.35, 0.85, 0.4 }, { 1, 0.82, 0.2 }, { 0.9, 0.25, 0.25 }
local SOON = 300   -- under 5 minutes left: yellow

-- A colored edge round a box (four thin lines over its own), recolored by SetEdge.
local function Edge(f, px)
	f.edges = {}
	for i = 1, 4 do
		local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
		t:SetColorTexture(1, 1, 1, 1)
		f.edges[i] = t
	end
	local e = f.edges
	e[1]:SetPoint("TOPLEFT") e[1]:SetPoint("TOPRIGHT") e[1]:SetHeight(px)
	e[2]:SetPoint("BOTTOMLEFT") e[2]:SetPoint("BOTTOMRIGHT") e[2]:SetHeight(px)
	e[3]:SetPoint("TOPLEFT") e[3]:SetPoint("BOTTOMLEFT") e[3]:SetWidth(px)
	e[4]:SetPoint("TOPRIGHT") e[4]:SetPoint("BOTTOMRIGHT") e[4]:SetWidth(px)
end
local function SetEdge(f, c)
	for _, t in ipairs(f.edges) do
		if c then t:SetVertexColor(c[1], c[2], c[3], 1) t:Show() else t:Hide() end
	end
end
-- Green with time to spare, yellow under 5 minutes, red when it's gone.
local function StateColor(left)
	if not left then return RED end
	if left < math.huge and left <= SOON then return YELLOW end
	return GREEN
end
local function Short(sec)
	if not sec or sec == math.huge then return "" end
	if sec >= 3600 then return string.format("%dh", math.floor(sec / 3600)) end
	if sec >= 60 then return string.format("%dm", math.ceil(sec / 60)) end
	return string.format("%ds", math.ceil(sec))
end
local holder                                       -- the secure fan, laid over the frame
local slots = {}
local open = false
local previewing = false
local pendingBuild = false

local function Say(msg) print("|cff73a0ffGone Camping|r: " .. msg) end

local function Slot(i)
	local b = slots[i]
	if b then return b end
	b = CreateFrame("Button", "DaylightEssentialsGoneCampingSlot" .. i, holder, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	b.edge = b:CreateTexture(nil, "BACKGROUND")
	b.edge:SetAllPoints()
	b.edge:SetColorTexture(0, 0, 0, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints(b.icon)
	b.count = API.Text(b, "tiny", "RIGHT")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(b.icon)
	hl:SetColorTexture(1, 1, 1, 0.15)
	b:HookScript("OnClick", function(self, which, down)
		if which == "RightButton" then
			if not down and self.obj and self.obj.key and not InCombatLockdown() then
				DB().hidden[self.obj.key] = true
				Say(self.obj.name .. " is left out of the tent (/dui camp reset brings it back).")
				P.Build()
			end
			return
		end
		if not down and G("closeAfter") and self.obj then
			C_Timer.After(0.2, function() if not InCombatLockdown() then P.Close() end end)
		end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		local o = self.obj
		if o and o.kind == "spell" and GameTooltip.SetSpellByID then
			GameTooltip:SetSpellByID(o.id)
		elseif o and o.kind == "item" and GameTooltip.SetItemByID then
			GameTooltip:SetItemByID(o.id)
		elseif o and o.kind == "toy" and GameTooltip.SetToyByItemID then
			GameTooltip:SetToyByItemID(o.id)
		else
			GameTooltip:SetText(o and o.name or "Sit")
		end
		GameTooltip:AddLine("Right-click: leave it out of the tent.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:Hide()
	slots[i] = b
	return b
end

local SIT = { key = "sit", kind = "sit", name = "Sit", icon = "Interface\\Icons\\Spell_Nature_Sleep" }

-- Lays the fan out (out of a fight only): its secure buttons, their actions, and where they sit.
function P.Build()
	if not frame then return end
	if InCombatLockdown() then
		pendingBuild = true
		return
	end
	pendingBuild = false
	Gather()
	local list = {}
	for _, o in ipairs(objects) do list[#list + 1] = o end
	if G("sit") then list[#list + 1] = SIT end
	local size = G("slotSize") or 32
	local dir = G("direction") or "up"
	local scale = G("scale") or 1
	-- The holder over the tent, on UIParent (the secure part never hangs off a frame DaylightUI moves).
	local l, b = frame:GetLeft(), frame:GetBottom()
	holder:ClearAllPoints()
	if l and b then
		local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
	end
	holder:SetSize(TENT * scale, TENT * scale)
	holder:SetScale(1)
	for i, o in ipairs(list) do
		local btn = Slot(i)
		btn.obj = o
		btn:SetSize(size * scale, size * scale)
		btn:ClearAllPoints()
		local step = (i - 1) * (size * scale + GAP) + GAP
		if dir == "up" then btn:SetPoint("BOTTOM", holder, "TOP", 0, step)
		elseif dir == "down" then btn:SetPoint("TOP", holder, "BOTTOM", 0, -step)
		elseif dir == "left" then btn:SetPoint("RIGHT", holder, "LEFT", -step, 0)
		else btn:SetPoint("LEFT", holder, "RIGHT", step, 0) end
		btn.icon:SetTexture(o.icon or 134400)
		if o.kind == "spell" then
			btn:SetAttribute("type1", "spell")
			btn:SetAttribute("spell1", o.id)
		elseif o.kind == "item" then
			btn:SetAttribute("type1", "item")
			btn:SetAttribute("item1", "item:" .. o.id)
		elseif o.kind == "toy" then
			btn:SetAttribute("type1", "toy")
			btn:SetAttribute("toy1", o.id)
		else
			btn:SetAttribute("type1", "macro")
			btn:SetAttribute("macrotext1", "/sit")
		end
		btn.count:SetText(o.kind == "item" and ItemCount(o.id) > 1 and ItemCount(o.id) or "")
		btn:SetShown(open)
	end
	for i = #list + 1, #slots do
		slots[i]:Hide()
		slots[i].obj = nil
	end
	P.count = #list
	P.Cooldowns()
end

-- Each object's cooldown sweep (a cast or an item's cooldown changed: no new look for objects).
function P.Cooldowns()
	if InCombatLockdown() then return end
	for i = 1, P.count or 0 do
		local btn, o = slots[i], slots[i].obj
		local _, start, duration = 0, nil, nil
		if o and o.kind ~= "sit" then _, start, duration = CooldownLeft(o) end
		if duration and duration > 1.5 then btn.cd:SetCooldown(start, duration) else btn.cd:Clear() end
	end
end

function P.Open()
	if InCombatLockdown() or not holder then return end
	open = true
	for i = 1, P.count or 0 do slots[i]:Show() end
	P.Look()
end

function P.Close()
	if InCombatLockdown() or not holder then return end
	open = false
	for _, b in ipairs(slots) do b:Hide() end
	P.Look()
end

-- Something dragged onto the tent: kept as yours.
local function Drop()
	if InCombatLockdown() or not GetCursorInfo then return end
	local kind, a, b, c = GetCursorInfo()
	local key, name
	if kind == "spell" then
		local id = (type(c) == "number" and c) or (type(b) == "number" and b > 100 and b) or nil
		if id then key, name = "spell:" .. id, SpellName(id) end
	elseif kind == "item" and type(a) == "number" then
		-- (an item that's a toy you own goes in as the toy: it's used from the toy box)
		local toyName = ToyInfo(a)
		if toyName then key, name = "toy:" .. a, toyName else key, name = "item:" .. a, ItemName(a) end
	elseif kind == "toy" and type(a) == "number" then
		key, name = "toy:" .. a, ToyInfo(a)
	end
	if not key then return end
	ClearCursor()
	local db = DB()
	db.hidden[key] = nil
	for _, k in ipairs(db.extra) do if k == key then key = nil break end end
	if key then db.extra[#db.extra + 1] = key end
	Say((name or "It") .. " is in the tent now.")
	P.Build()
end

-- ---------------------------------------------------------------------------------------------
-- The look: the notes, the tent's edge, the fade
-- ---------------------------------------------------------------------------------------------

local ticker, tickEvery
local function Tick(on)
	local every = fast and 1 or 10
	if ticker and (not on or every ~= tickEvery) then
		ticker:Cancel()
		ticker = nil
	end
	if on and not ticker then
		tickEvery = every
		ticker = C_Timer.NewTicker(every, function() P.Look() end)
	end
end

-- An object at this camp: its icon (from your spellbook, a cast, or your own kit), or a question mark.
local function CampIcon(e)
	if e.icon then return e.icon end
	local id = e.spell or lastBook[e.name]
	if id then e.icon = SpellIcon(id) return e.icon end
	for _, o in ipairs(objects) do
		if o.name == e.name then e.icon = o.icon return e.icon end
	end
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, t = pcall(C_Spell.GetSpellTexture, e.name)
		if ok and t then e.icon = t return t end
	end
	return 134400
end

local function CampIconFrame(i)
	local f = campIcons[i]
	if f then return f end
	f = CreateFrame("Frame", nil, frame)
	f:SetSize(CAMP_ICON, CAMP_ICON)
	f.back = f:CreateTexture(nil, "BACKGROUND")
	f.back:SetAllPoints()
	f.back:SetColorTexture(0, 0, 0, 1)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self)
		local e = self.entry
		if not e then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(e.name)
		for _, line in ipairs(e.lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
		if not e.lines then GameTooltip:AddLine("Mouse over it at the camp to see what it gives.", 0.6, 0.6, 0.6, true) end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	campIcons[i] = f
	return f
end

-- The camp's objects in a row beside the tent (to its right; above it when the fan opens right).
local function ShowCamp(list)
	local dir = G("direction") or "up"
	for i, e in ipairs(list) do
		local f = CampIconFrame(i)
		f.entry = e
		f.icon:SetTexture(CampIcon(e))
		f:ClearAllPoints()
		if dir == "right" then
			f:SetPoint("BOTTOMLEFT", tent, "TOPLEFT", (i - 1) * (CAMP_ICON + 2), GAP)
		else
			f:SetPoint("BOTTOMLEFT", tent, "BOTTOMRIGHT", GAP + (i - 1) * (CAMP_ICON + 2), 0)
		end
		f:SetScale(G("scale") or 1)
		f:Show()
	end
	for i = #list + 1, #campIcons do campIcons[i]:Hide() end
end

-- What the tent's left click does now: "/sit" at a camp, else your best campfire (Expert, then
-- Journeyman, then Basic), or nothing if you have none. Also its words for the tooltip.
local function TentAction()
	if AtCamp() then return "/sit", "Left-click: sit by the fire" end
	local best, rank
	for _, o in ipairs(objects) do
		local r = FIRES[string.lower(o.name or "")]
		if r and (not rank or r > rank) then best, rank = o, r end
	end
	if not best then return "", "Left-click: no campfire to put down (learn one, or drag it here)" end
	local m = best.kind == "spell" and ("/cast " .. best.name) or ("/use item:" .. best.id)
	return m, "Left-click: put down your " .. best.name
end

function P.Look()
	if not frame then return end
	local fight = InCombatLockdown()
	-- In a fight nothing here changes: the tent is a secure button now (hidden as the fight starts).
	if fight then
		Tick(false)
		return
	end
	previewing = G("enabled") and ns.Previewing(KEY) or false
	if not G("enabled") or (fight and not previewing) then
		frame:Hide()
		Tick(false)
		return
	end
	local action = TentAction()
	if tent.action ~= action then
		tent:SetAttribute("macrotext1", action)
		tent.action = action
	end
	local scale = G("scale") or 1
	tent:SetScale(scale)
	fedBox:SetScale(scale)
	frame:SetSize(TENT * scale, TENT * scale)
	frame:Show()
	local campLeft, sitting, fedLeft, list, counting
	if previewing then
		campLeft, fedLeft = 52 * 60, 4 * 60
		list = { { name = "Fish Bowl", icon = 132830, lines = { "+8% to all stats." } }, { name = "Camp Chair", icon = 134400 } }
		counting = false
	else
		local notes
		notes, counting = Notes()
		local buffs = MyBuffs() or {}
		campLeft, sitting = buffs[CAMP_BUFF], buffs[SITTING]
		fedLeft = buffs[SpellName(WELL_FED) or "Well Fed"]
		list = buffs[NEARBY] and camp.list or {}
		counting = counting or campLeft ~= nil or fedLeft ~= nil
	end
	-- The tent: its edge says Camp Benefits (green, yellow under 5 minutes, red without), with its
	-- time left on it, or the countdown while you sit by the fire.
	SetEdge(tent, StateColor(campLeft))
	if sitting and sitting < math.huge and not campLeft then
		tent.time:SetText(Seconds(sitting))
	else
		tent.time:SetText(Short(campLeft))
	end
	-- Well Fed, the same way, in the smaller box to its left.
	if G("fed") and (RemindHere() or previewing) then
		SetEdge(fedBox, StateColor(fedLeft))
		fedBox.time:SetText(Short(fedLeft))
		fedBox:Show()
	else
		fedBox:Hide()
	end
	ShowCamp(list)
	Tick((counting or fast) and not fight)
	-- Fades while idle: all green, the fan shut, the mouse away.
	local fine = campLeft ~= nil and (fedLeft ~= nil or not G("fed"))
	local idle = G("fadeIdle") and fine and not open and not frame:IsMouseOver()
		and not (holder and holder:IsMouseOver()) and not previewing
	API.Fade(frame, idle and 0.35 or 1, "NORMAL")
end

local looking = false
local function LookSoon()
	if looking then return end
	looking = true
	C_Timer.After(0.2, function()
		looking = false
		P.Look()
	end)
end

local building = false
local function BuildSoon()
	if building then return end
	building = true
	C_Timer.After(0.3, function()
		building = false
		P.Build()
		P.Look()
	end)
end

-- ---------------------------------------------------------------------------------------------
-- Events, commands, building
-- ---------------------------------------------------------------------------------------------

local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED",
	"SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED",
	"ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "TOYS_UPDATED", "NEW_TOY_ADDED",
	"UNIT_SPELLCAST_SUCCEEDED", "UI_ERROR_MESSAGE" }

-- Mousing over something in the world while at a camp: a campfire or a camp object?
local function OnObjectTooltip(_, data)
	if not (frame and G("enabled")) or type(data) ~= "table" or type(data.lines) ~= "table" then return end
	local first = data.lines[1] and data.lines[1].leftText
	if not Safe(first) or type(first) ~= "string" or not AtCamp() then return end
	local lines = {}
	for i = 2, #data.lines do
		local t = data.lines[i] and data.lines[i].leftText
		if Safe(t) and type(t) == "string" and t ~= "" then lines[#lines + 1] = t end
	end
	if NoteObject(first, lines) then LookSoon() end
end

local function OnEvent(_, event, unit, b, c)
	if event == "UNIT_AURA" then
		if unit ~= "player" then return end
		-- Out of the camp, or at another fire (a new Campfire Nearby): starts over.
		local inst = NearbyAura()
		if not inst or (camp.aura and inst ~= true and camp.aura ~= true and inst ~= camp.aura) then ResetCamp() end
		camp.aura = inst
		LookSoon()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- Something put down by you or your group: one more object at the camp (or a new fire).
		if not (Safe(unit) and type(unit) == "string" and Safe(c) and type(c) == "number") then return end
		if not (unit == "player" or unit:match("^party%d$") or unit:match("^raid%d+$")) then return end
		local name = SpellName(c)
		if not name then return end
		local low = name:lower()
		if FIRES[low] and unit == "player" and not AtCamp() then ResetCamp() end
		if (FIRES[low] or IsCampName(name)) and NoteObject(name, nil, c) then
			if not FIRES[low] then camp.full = false end
			LookSoon()
		end
	elseif event == "UI_ERROR_MESSAGE" then
		local full = _G.SPELL_FAILED_CUSTOM_ERROR_6004   -- the game's "no room for more features" error
		if full and Safe(b) and b == full and AtCamp() and not camp.full then
			camp.full = true
			LookSoon()
		end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if unit == "player" then LookSoon() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if open then open = false end   -- (the state driver hides the fan; it stays shut after)
		frame:Hide()
		Tick(false)
	elseif event == "PLAYER_REGEN_ENABLED" then
		for _, b in ipairs(slots) do b:Hide() end
		if pendingBuild then BuildSoon() else LookSoon() end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if waitingNames then BuildSoon() end
	elseif event == "BAG_UPDATE_DELAYED" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD"
		or event == "TOYS_UPDATED" or event == "NEW_TOY_ADDED" then
		BuildSoon()
	elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
		if not InCombatLockdown() then
			P.Cooldowns()
			LookSoon()
		end
	else
		LookSoon()
	end
end

local function Command(rest)
	rest = type(rest) == "string" and rest or ""
	local word = string.lower(rest:match("^%s*(%S*)") or "")
	if word == "reset" then
		local db = DB()
		wipe(db.hidden)
		wipe(db.extra)
		Say("every camp object is back in the tent, and the ones you added are gone.")
		P.Build()
		P.Look()
	elseif word == "list" then
		Gather()
		local names = {}
		for _, o in ipairs(objects) do names[#names + 1] = o.name end
		Say(#names == 0 and "no camp objects found. Drag one onto the tent to add it."
			or ("in the tent: " .. table.concat(names, ", ")))
	else
		Say("/dui camp list: what's in the tent. /dui camp reset: everything back, your added ones gone.")
	end
end

local function Build()
	frame = CreateFrame("Frame", "DaylightEssentialsGoneCamping", UIParent)
	frame:SetSize(TENT, TENT)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:Hide()

	-- A secure button: its left click sits you down at a camp, or puts down your best campfire
	-- away from one (a macro set out of a fight, Look); the right click opens the fan.
	tent = CreateFrame("Button", "DaylightEssentialsGoneCampingTent", frame, "SecureActionButtonTemplate")
	tent:SetSize(TENT, TENT)
	tent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	API.Skin(tent, { window = true })
	tentIcon = tent:CreateTexture(nil, "ARTWORK")
	tentIcon:SetPoint("TOPLEFT", 4, -4)
	tentIcon:SetPoint("BOTTOMRIGHT", -4, 4)
	tentIcon:SetTexture(TENT_ICON)
	tentIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	Edge(tent, 2)
	tent.time = API.Text(tent, "small", "CENTER")
	tent.time:SetPoint("BOTTOM", tent, "BOTTOM", 0, 3)
	-- Both: the template itself acts on the one the game's "cast on key down" choice says.
	tent:RegisterForClicks("AnyUp", "AnyDown")
	tent:SetAttribute("type1", "macro")
	tent:SetAttribute("macrotext1", "")
	tent:HookScript("OnClick", function(_, which, down)
		if down or InCombatLockdown() then return end
		if GetCursorInfo and GetCursorInfo() then Drop() return end
		if which == "RightButton" then
			if open then P.Close() else P.Open() end
		end
	end)
	tent:SetScript("OnReceiveDrag", Drop)
	tent:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Gone Camping")
		local buffs = MyBuffs() or {}
		local left = buffs[CAMP_BUFF]
		if left then
			local c = StateColor(left)
			GameTooltip:AddLine(CAMP_BUFF .. (left < math.huge and (": " .. Minutes(left) .. " left") or ""), c[1], c[2], c[3])
			for _, line in ipairs(BuffLines(CAMP_BUFF) or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
		elseif buffs[SITTING] then
			GameTooltip:AddLine("Stay seated: " .. CAMP_BUFF .. " in " .. Seconds(buffs[SITTING]), YELLOW[1], YELLOW[2], YELLOW[3])
		else
			GameTooltip:AddLine("No " .. CAMP_BUFF, RED[1], RED[2], RED[3])
			GameTooltip:AddLine("Sit by a lit campfire for about a minute.", 0.8, 0.8, 0.8, true)
		end
		if buffs[NEARBY] then
			local head = camp.fire or "A campfire"
			if camp.full then head = head .. ", full"
			elseif camp.slots then head = head .. ", " .. #camp.list .. " of " .. camp.slots end
			GameTooltip:AddLine(head, 0.8, 0.8, 0.8)
		end
		if buffs[VIOLET] then GameTooltip:AddLine(VIOLET .. ": camp buffs last 2 hours", 0.75, 0.55, 1) end
		local notes = Notes()
		if #notes > 0 then
			GameTooltip:AddLine(" ")
			for _, n in ipairs(notes) do
				if n[2] then GameTooltip:AddLine(n[1], 1, 0.75, 0.3) else GameTooltip:AddLine(n[1], 0.7, 0.7, 0.7) end
			end
		end
		GameTooltip:AddLine(" ")
		local _, words = TentAction()
		GameTooltip:AddLine(words, 0.6, 0.6, 0.6, true)
		GameTooltip:AddLine("Right-click: your camp objects. Drag a spell or item here to add it.", 0.6, 0.6, 0.6, true)
		GameTooltip:Show()
		if G("fadeIdle") then API.Fade(frame, 1, "FAST") end
	end)
	tent:SetScript("OnLeave", function()
		GameTooltip:Hide()
		LookSoon()
	end)

	-- Well Fed: a smaller box to the tent's left, its edge colored the same way.
	fedBox = CreateFrame("Frame", nil, frame)
	fedBox:SetSize(FED, FED)
	fedBox:SetPoint("BOTTOMRIGHT", tent, "BOTTOMLEFT", -GAP, 0)
	API.Skin(fedBox, { window = true })
	fedBox.icon = fedBox:CreateTexture(nil, "ARTWORK")
	fedBox.icon:SetPoint("TOPLEFT", 3, -3)
	fedBox.icon:SetPoint("BOTTOMRIGHT", -3, 3)
	fedBox.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	fedBox.icon:SetTexture(SpellIcon(WELL_FED))
	Edge(fedBox, 2)
	fedBox.time = API.Text(fedBox, "tiny", "CENTER")
	fedBox.time:SetPoint("BOTTOM", fedBox, "BOTTOM", 0, 2)
	fedBox:EnableMouse(true)
	fedBox:SetScript("OnEnter", function(self)
		local buffs = MyBuffs() or {}
		local name = SpellName(WELL_FED) or "Well Fed"
		local left = buffs[name]
		local c = StateColor(left)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if left then
			GameTooltip:SetText(name .. (left < math.huge and (": " .. Minutes(left) .. " left") or ""), c[1], c[2], c[3])
		else
			GameTooltip:SetText("Not " .. name, c[1], c[2], c[3])
		end
		GameTooltip:Show()
	end)
	fedBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	fedBox:Hide()

	-- The secure fan: hidden in every fight by its state driver; filled and laid out out of one.
	holder = CreateFrame("Frame", "DaylightEssentialsGoneCampingFan", UIParent, "SecureHandlerStateTemplate")
	holder:SetSize(TENT, TENT)
	holder:SetFrameStrata("MEDIUM")
	RegisterStateDriver(holder, "visibility", "[combat] hide; show")

	frame:SetPoint(unpack(DEFAULT))
	ns.me.RegisterMover(frame, KEY, "Gone Camping", DEFAULT)
	ns.me.RegisterTestPart(KEY, "Gone Camping")
	-- When the tent is moved (a profile, the mover), the fan follows it.
	hooksecurefunc(frame, "SetPoint", function() BuildSoon() end)
	ns.me.RegisterCommand("camp", Command, "camp list|reset: Gone Camping's tent")
	frame:SetScript("OnEvent", OnEvent)
end

local listening = false
local function Listen(on)
	if on == listening then return end
	listening = on
	for _, e in ipairs(EVENTS) do
		if on then pcall(frame.RegisterEvent, frame, e) else pcall(frame.UnregisterEvent, frame, e) end
	end
	if on then
		frame:RegisterUnitEvent("UNIT_AURA", "player")
		frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
	else
		pcall(frame.UnregisterEvent, frame, "UNIT_AURA")
		pcall(frame.UnregisterEvent, frame, "UNIT_INVENTORY_CHANGED")
	end
end

-- The key binding's words (Key Bindings, AddOns).
_G.BINDING_HEADER_DAYLIGHTESSENTIALS = _G.BINDING_HEADER_DAYLIGHTESSENTIALS or "Daylight Essentials"
_G["BINDING_NAME_CLICK DaylightEssentialsGoneCampingTent:LeftButton"] = "Gone Camping: sit by the fire, or put down a campfire"

function P.Login()
	ResolveNames()
	Build()
	-- The world's tooltips: a campfire or camp object moused over while at a camp.
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
		and Enum.TooltipDataType.Object then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, OnObjectTooltip)
	end
	Listen(G("enabled"))
	BuildSoon()
end

function P.Setting()
	if not frame then return end
	Listen(G("enabled"))
	if not G("enabled") and not InCombatLockdown() then P.Close() end
	BuildSoon()
end

function P.Style()
	if frame then
		API.Skin(tent, { window = true })
		LookSoon()
	end
end

function P.Preview()
	if frame then LookSoon() end
end
