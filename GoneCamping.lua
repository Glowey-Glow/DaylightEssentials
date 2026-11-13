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
-- game names them in English; a "... Kit" item too), in your spellbook and your bags. Anything it
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

-- Every known spell, name -> highest spell id (the spellbook, out of a fight).
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
	for name, id in pairs(Spellbook()) do
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
	-- Added by hand (drag onto the tent), while you still have it.
	for _, key in ipairs(db.extra) do
		local kind, id = key:match("^(%a+):(%d+)$")
		id = tonumber(id)
		if kind == "spell" and id and ((IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))) then
			Add("spell", id, SpellName(id) or ("Spell " .. id), SpellIcon(id))
		elseif kind == "item" and id and ItemCount(id) > 0 then
			Add("item", id, ItemName(id) or ("Item " .. id), ItemIcon(id))
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
	elseif o.kind == "item" and C_Container and C_Container.GetItemCooldown then
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
local function MyBuffs()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local out = {}
	local now = GetTime()
	for i = 1, 40 do
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok or not Safe(data) then return nil end
		if data == nil then break end
		local name, exp = data.name, data.expirationTime
		if not (Safe(name) and Safe(exp)) then return nil end
		if type(name) == "string" then
			local left = (type(exp) == "number" and exp > 0) and (exp - now) or math.huge
			if not out[name] or left > out[name] then out[name] = left end
		end
	end
	return out
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
local function Notes()
	local notes, counting = {}, false
	if not RemindHere() then return notes, false end
	local warn = (G("warn") or 3) * 60
	local buffs = MyBuffs()
	if buffs then
		if G("fed") then
			local fed = SpellName(WELL_FED) or "Well Fed"
			local left = buffs[fed]
			if not left then
				notes[#notes + 1] = { "Not Well Fed", true }
			elseif left < math.huge and left <= warn then
				notes[#notes + 1] = { fed .. ": " .. Minutes(left), true }
				counting = true
			elseif left < math.huge then counting = counting or left - warn < 600 end
		end
		for _, name in ipairs(DB().buffs) do
			local left = buffs[name]
			if not left then
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
		if not o.fire then
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

local frame, tent, tentIcon, notesBox, notesText   -- frame: what /dui unlock moves
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
		key, name = "item:" .. a, ItemName(a)
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

local ticker
local function Tick(on)
	if on and not ticker then
		ticker = C_Timer.NewTicker(10, function() P.Look() end)
	elseif not on and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function SizeNotes()
	local w = ns.TextWidth(notesText) or 0
	local h = notesText:GetStringHeight() or 0
	if not Safe(h) or type(h) ~= "number" then h = 14 end
	notesBox:SetSize(math.ceil(w) + PAD * 2 + 2, math.ceil(h) + PAD * 2)
	API.Skin(notesBox, { window = true })
end

local function PlaceNotes()
	notesBox:ClearAllPoints()
	local dir = G("direction") or "up"
	if dir == "up" or dir == "down" then
		notesBox:SetPoint("LEFT", tent, "RIGHT", GAP, 0)
	else
		notesBox:SetPoint("TOP", tent, "BOTTOM", 0, -GAP)
	end
end

function P.Look()
	if not frame then return end
	local fight = InCombatLockdown()
	previewing = G("enabled") and ns.Previewing(KEY) or false
	if not G("enabled") or (fight and not previewing) then
		frame:Hide()
		Tick(false)
		return
	end
	local scale = G("scale") or 1
	tent:SetScale(scale)
	frame:SetSize(TENT * scale, TENT * scale)
	frame:Show()
	local notes, counting
	if previewing then
		notes, counting = { { "Not Well Fed", true }, { "Camp pieces ready in 42m", false } }, false
	else
		notes, counting = Notes()
	end
	local lines, warn = {}, false
	local warnHex, labelHex = "|cffffbf4d", "|cffa0a0a0"
	for _, n in ipairs(notes) do
		lines[#lines + 1] = (n[2] and warnHex or labelHex) .. n[1] .. "|r"
		warn = warn or n[2]
	end
	if #lines > 0 then
		notesText:SetText(table.concat(lines, "\n"))
		PlaceNotes()
		SizeNotes()
		notesBox:Show()
	else
		notesBox:Hide()
	end
	-- The tent's edge in the warning color while something has run out.
	tent.warn:SetShown(warn)
	Tick(counting and not fight)
	-- Fades while idle: nothing to say, the fan shut, the mouse away.
	local idle = G("fadeIdle") and not warn and not open and not frame:IsMouseOver()
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
	"ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "PLAYER_EQUIPMENT_CHANGED" }

local function OnEvent(_, event, unit)
	if event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
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
	elseif event == "BAG_UPDATE_DELAYED" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
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

	tent = CreateFrame("Button", "DaylightEssentialsGoneCampingTent", frame)
	tent:SetSize(TENT, TENT)
	tent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	API.Skin(tent, { window = true })
	tentIcon = tent:CreateTexture(nil, "ARTWORK")
	tentIcon:SetPoint("TOPLEFT", 4, -4)
	tentIcon:SetPoint("BOTTOMRIGHT", -4, 4)
	tentIcon:SetTexture(TENT_ICON)
	tentIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tent.warn = tent:CreateTexture(nil, "OVERLAY")
	tent.warn:SetPoint("BOTTOMLEFT", tent, "BOTTOMLEFT", 2, 2)
	tent.warn:SetPoint("BOTTOMRIGHT", tent, "BOTTOMRIGHT", -2, 2)
	tent.warn:SetHeight(2)
	tent.warn:SetColorTexture(1, 0.75, 0.3, 1)
	tent.warn:Hide()
	tent:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	tent:SetScript("OnClick", function(_, which)
		if InCombatLockdown() then return end
		if GetCursorInfo and GetCursorInfo() then Drop() return end
		if which == "RightButton" then P.Close() return end
		if open then P.Close() else P.Open() end
	end)
	tent:SetScript("OnReceiveDrag", Drop)
	tent:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Gone Camping")
		GameTooltip:AddLine("Click: your camp objects. Drag a spell or item here to add it.", 1, 1, 1, true)
		GameTooltip:Show()
		if G("fadeIdle") then API.Fade(frame, 1, "FAST") end
	end)
	tent:SetScript("OnLeave", function()
		GameTooltip:Hide()
		LookSoon()
	end)

	notesBox = CreateFrame("Frame", nil, frame)
	notesBox:SetSize(10, 10)
	notesText = API.Text(notesBox, "small", "LEFT")
	notesText:SetPoint("TOPLEFT", notesBox, "TOPLEFT", PAD, -PAD)
	notesBox:Hide()

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
_G["BINDING_NAME_CLICK DaylightEssentialsGoneCampingTent:LeftButton"] = "Gone Camping: open or close the tent"

function P.Login()
	Build()
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
