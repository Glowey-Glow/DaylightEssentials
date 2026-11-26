-- Halo: hold a key and a ring of your own actions opens around the mouse (or in the middle of the
-- screen). Point toward one, or scroll to it, and let go of the key: it fires. Let go with the
-- mouse still in the middle and nothing happens. Spells, items, macros, mounts, companion pets and
-- your pet's abilities and commands each take a slot: open "Edit the slots" (its page, or /halo
-- edit) and drag them in from your spellbook, bags, macros, the mount or pet journal or your
-- pet's bar; right-click a slot to empty it. The slots are kept per character. The ring's shape,
-- size, icon size, where it opens and how it shows what isn't ready are set on its page.
-- (A ring menu like EllesmereUI's Quickdraw. Its way of working, a button per ring and the mouse
-- read on the whole screen, was described to us; written from scratch, none of its code read or
-- used.)
--
-- Up to four rings: the base one, and a Shift, an Alt and a Ctrl ring, each switched on on the
-- page and filled in the editor on its own tab. Hold the modifier with the key and that ring opens
-- instead. Each ring has its own color (the highlight and the rim around its icons) and can have
-- a label of up to 16 letters, shown over it, so you always know which one is open.
--
-- Secure: the game only lets a key press or a click cast, and nothing protected can be changed in
-- a fight. So each Halo has its own secure button (SecureActionButtonTemplate), and its key is
-- bound to that button: the key on its own to the base Halo's, Shift-, Alt- and Ctrl- with it to
-- theirs. Nothing in a fight has to work out which Halo is meant: the button pressed is the Halo.
-- The buttons share one pre-click snippet (SecureHandlerWrapScript) that runs in the game's secure
-- sandbox: on the key going down it notes its button as the ring's "owner" and where the mouse is,
-- shows the ring (a protected frame, so it can be shown in a fight) and cancels the click; on the
-- key coming up it works out which slot you point at (or scrolled to), measured on the whole
-- screen from where it opened, and hands the click on to that slot's action ("typerelease-hN" /
-- "spell-hN" attributes on that Halo's button, written out of a fight only). What you see (which
-- Halo's icons, the highlight, the name, the dimming) is drawn by plain code, which only reads.
--
-- The key: Halo's own, set on its page (override bindings, so the player's saved bindings never
-- change), or the game's Key Bindings entries (one per Halo), or both. Halo's own also binds every
-- other modifier set of the key to a Halo's button where nothing else has it, so a key coming up
-- with a modifier pressed or let go mid-hold still reaches the button that opened.
--
-- Layout: Ring (the slots around the middle) or Bar (the slots in a row, over where it opens). On
-- a controller (the game's controller mode on, or a Halo's key a controller button) it opens as a
-- bar in the middle of the screen with nothing picked, whatever the layout ("Bar With a
-- Controller", on by default), and the mouse doesn't pick there. With the mouse, a bar picks the
-- icon over or under the mouse once it's moved up past the middle.
--
-- Stepping, in a fight too: while a Halo is held open, D-pad Left / Right and LB / RB step its
-- highlight, B closes it without using anything. The secure snippet binds those keys when it
-- opens (override bindings owned by a secure "step" button, set from the snippet: the restricted
-- SetBindingClick) and clears them when it closes; the step button's own snippet moves the
-- owning button's "pick" just as the mouse wheel does. A key that is a Halo's key, or a
-- controller button standing in for Shift, Ctrl or Alt, is left alone. The key list (every
-- modifier set of each, so a controller's Shift held still steps) is written out of a fight.
--
-- Choosing without dragging: clicking a slot in the editor (A on a controller) opens a list of
-- your spells, usable items, macros, mounts, pets and pet actions to pick from; Y on a controller empties the slot. The
-- editor and the list tell the game's controller mode about themselves (Daylight UI's Pad), so
-- the D-pad moves through them and LB / RB step their tabs.
--
-- What it costs: nothing until you press the key; while the ring is open, a light update each
-- frame for the highlight and five times a second for the dimming. No timers otherwise.

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "halo"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = L["Halo"] })

local MAX = 12
local LABEL_MAX = 16
local BUTTON = "DaylightEssentialsHaloButton"

-- The rings: 1 the base one, then the modifier ones. key: its on/off setting and where its slots
-- are kept; mod: the binding's modifier; color: its color setting.
local RINGS = {
	{ label = L["Base"], name = L["Base Halo"], color = "colorBase" },
	{ label = L["Shift"], name = L["Shift Halo"], key = "shift", mod = "SHIFT", color = "colorShift" },
	{ label = L["Alt"], name = L["Alt Halo"], key = "alt", mod = "ALT", color = "colorAlt" },
	{ label = L["Ctrl"], name = L["Ctrl Halo"], key = "ctrl", mod = "CTRL", color = "colorCtrl" },
}

P.defaults = {
	enabled = true,
	key = "",
	count = 8,
	shift = false,
	alt = false,
	ctrl = false,
	baseAccent = true,
	colorBase = { 0.45, 0.6, 1 },
	colorShift = { 0.3, 0.75, 1 },
	colorAlt = { 0.4, 0.85, 0.45 },
	colorCtrl = { 1, 0.55, 0.25 },
	layout = "ring",
	padBar = true,
	shape = "ring",
	opens = "cursor",
	radius = 90,
	iconSize = 36,
	names = true,
	dim = true,
	cdTime = true,
}

P.page = { id = KEY, label = L["Halo"],
	desc = L["Hold a key for a Halo of your actions; point, let go, and it fires."],
	groups = {
		{ label = L["Halo"],
		  desc = L["Set its key here (Set Key), or bind it under Key Bindings, AddOns, Glowey's Essentials (Halo). Hold it, point toward an action or scroll to it, and let go to use it. Let go in the middle to close it without using anything."],
		  items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "button", label = L["Set Key"],
			  desc = L["Opens a small box: press the key you want (a mouse's middle or side button works too), Escape to cancel, or Clear to take it off. Shift, Alt and Ctrl are added by themselves for the Halos below."],
			  func = function() P.KeyBox(true) end },
			{ type = "button", label = L["Edit Halos"],
			  desc = L["Drag spells, items or macros onto the slots; right-click one to empty it. Each Halo has its tab, and a label you can type there. Kept for this character. Also /halo edit. (A macro on a Shift, Alt or Ctrl Halo sees that key held: [mod:shift] and the like always match there.)"],
			  func = function() P.Edit(true) end },
			{ type = "slider", key = KEY .. ".count", label = L["Slots"], min = 2, max = MAX, step = 1,
			  desc = L["How many slots each Halo has to fill. Empty ones aren't shown in the Halo."] },
			{ type = "button", label = L["Clear Base Halo"],
			  desc = L["Takes everything off the base Halo, for this character."],
			  func = function() P.Clear(1) end },
			-- (Each modifier's own; dimmed while that Halo is off.)
			{ type = "button", label = L["Clear Shift Halo"], func = function() P.Clear(2) end,
			  disabled = function(get) return get(KEY .. ".shift") ~= true end },
			{ type = "button", label = L["Clear Alt Halo"], func = function() P.Clear(3) end,
			  disabled = function(get) return get(KEY .. ".alt") ~= true end },
			{ type = "button", label = L["Clear Ctrl Halo"], func = function() P.Clear(4) end,
			  disabled = function(get) return get(KEY .. ".ctrl") ~= true end },
		} },
		{ label = L["More Halos"],
		  desc = L["Hold Shift, Alt or Ctrl with Halo's key to open that Halo instead; works in a fight. One that's off or has nothing in it leaves its modifier to the base Halo. Fill each on its tab in Edit Halos. Binding under Key Bindings instead? Each Halo has its own entry there."],
		  items = {
			{ type = "toggle", key = KEY .. ".shift", label = L["Shift Halo"] },
			{ type = "toggle", key = KEY .. ".alt", label = L["Alt Halo"] },
			{ type = "toggle", key = KEY .. ".ctrl", label = L["Ctrl Halo"] },
		} },
		{ label = L["Colors"],
		  desc = L["Each Halo's color, on the rim around its icons, the one you point at and its label, so you can tell which Halo is open."],
		  items = {
			{ type = "toggle", key = KEY .. ".baseAccent", label = L["Base Halo in My Accent"],
			  desc = L["The base Halo follows your Daylight UI accent color."] },
			{ type = "color", key = KEY .. ".colorBase", label = L["Base Halo"],
			  disabled = function(get) return get(KEY .. ".baseAccent") ~= false end },
			{ type = "color", key = KEY .. ".colorShift", label = L["Shift Halo"] },
			{ type = "color", key = KEY .. ".colorAlt", label = L["Alt Halo"] },
			{ type = "color", key = KEY .. ".colorCtrl", label = L["Ctrl Halo"] },
		} },
		{ label = L["Look"], items = {
			{ type = "dropdown", key = KEY .. ".layout", label = L["Layout"],
			  values = { ring = L["Ring"], bar = L["Bar"] },
			  desc = L["Ring: the slots around the middle. Bar: the slots in a row; move the mouse up onto one, scroll, or step with the D-pad."] },
			{ type = "toggle", key = KEY .. ".padBar", label = L["Bar With a Controller"],
			  desc = L["With the game's controller mode on, or a Halo's key on a controller, it opens as a bar in the middle of the screen. Step with the D-pad or LB / RB, let go to use it, B closes it."] },
			{ type = "dropdown", key = KEY .. ".shape", label = L["Shape"],
			  values = { ring = L["Circle"], arc = L["Arc"] },
			  desc = L["Circle: all the way around, the first slot at the top. Arc: a half circle over the middle, left to right."],
			  disabled = function(get) return get(KEY .. ".layout") == "bar" end },
			{ type = "dropdown", key = KEY .. ".opens", label = L["Opens"],
			  values = { cursor = L["Around Cursor"], center = L["Screen Center"] } },
			{ type = "slider", key = KEY .. ".radius", label = L["Halo Size"], min = 50, max = 220, step = 5, unit = "px",
			  desc = L["From the middle of the Halo to the middle of each icon."] },
			{ type = "slider", key = KEY .. ".iconSize", label = L["Icon Size"], min = 20, max = 72, step = 1, unit = "px" },
			{ type = "toggle", key = KEY .. ".names", label = L["Text in Middle"],
			  desc = L["The name of the action you point at, in the middle of the Halo."] },
			{ type = "toggle", key = KEY .. ".dim", label = L["Dim Icon on Cooldown"],
			  desc = L["Spells cooling down or out of reach (no mana, no rage) and items you have none of."] },
			{ type = "toggle", key = KEY .. ".cdTime", label = L["Cooldown Time on Icon"],
			  desc = L["The time left on a spell or item that is cooling down, on its icon."] },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- The slots: per character, in DaylightEssentialsDB.halo[key] (CharKey below: "Name-Realm", the
-- "Name-" the game gives since it stopped naming realms, or the character's GUID;
-- DaylightEssentialsDB.haloOwners says which, GUID -> key):
--   [i] = action            the base ring (where every slot was kept before there were more rings,
--                           so those stay as they are)
--   shift / alt / ctrl      = { [i] = action }, the modifier rings
--   labels                  = { [ring] = "text" }, each ring's label
-- An action: { kind = "spell", id, name } | { kind = "item", id } | { kind = "macro", name }
--   | { kind = "mount", id, name }      a mount by its journal ID (0: a random favorite)
--   | { kind = "pet", id, name }        a companion pet by its journal GUID
--   | { kind = "petspell", id, name }   an ability of your hunter pet or demon, by spell
--   | { kind = "petcmd", token, slot }  a pet command (Attack, Follow, Passive...), by its token
-- ---------------------------------------------------------------------------------------------

local function Say(msg) print("|cff73a0ffHalo|r: " .. msg) end

-- ---------------------------------------------------------------------------------------------
-- This character's record in a table kept by "Name-Realm". On 2026-11-20 the game stopped giving
-- realm names on this client (GetRealmName() is ""; Daylight UI 2.1.2 DB.lua:226-238), so every
-- character's key turned into "Name-" and what it had saved looked gone. Now:
--   1. The key this character was given before (owners: GUID -> key) is its key: the GUID stays the
--      same whatever the game says the realm is, so this can't happen again.
--   2. Else the key the game gives now, "Name-Realm" or "Name-"; a key another character holds
--      (two characters share a first name) is left to it, and this one is kept by its GUID.
--   3. A record that is new or empty, with no realm name to go by, takes a copy of what the
--      character had before: the "Name-Realm" record Daylight UI finds for it (DB.ShortKey gives
--      the same key from its own saved characters, DB.lua:181-249), else the only "Name-<realm>"
--      record there is, else the record it shared until now. Two to choose from: none is taken.
-- Nothing is deleted and no record is written over: the old ones stay where they were.
-- nil while the game doesn't know the character yet (the caller then waits, or uses nothing).
-- ---------------------------------------------------------------------------------------------
local function EmptyRecord(t)
	for _, v in pairs(t) do
		if type(v) ~= "table" or not EmptyRecord(v) then return false end
	end
	return true
end

local function CopyRecord(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = CopyRecord(x) end
	return out
end

local function CharKey(records, owners)
	local guid, name = UnitGUID("player"), UnitName("player")
	if type(guid) ~= "string" or guid == "" or type(name) ~= "string" or name == "" or name == (UNKNOWNOBJECT or "Unknown") then
		return nil
	end
	local kept = owners[guid]
	if type(kept) == "string" and type(records[kept]) == "table" then return kept end
	local realm = GetRealmName()
	if type(realm) ~= "string" then realm = "" end
	local bare = name .. "-"
	local key = bare .. realm
	local taken = {}
	for g, k in pairs(owners) do
		if g ~= guid then taken[k] = true end
	end
	local shared
	if taken[key] then key, shared = guid, key end
	if type(records[key]) ~= "table" then records[key] = {} end
	owners[guid] = key
	if realm ~= "" or not EmptyRecord(records[key]) then return key end
	-- (What it had before.)
	local old
	local D = _G.DaylightUI
	local short = type(D) == "table" and type(D.DB) == "table" and D.DB.ShortKey
	if type(short) == "function" then
		local ok, k = pcall(short)
		if ok and type(k) == "string" and #k > #bare and k:sub(1, #bare) == bare and type(records[k]) == "table" then old = k end
	end
	if not old then
		local n = 0
		for k, v in pairs(records) do
			if type(k) == "string" and type(v) == "table" and #k > #bare and k:sub(1, #bare) == bare and owners[k] == nil
				and k ~= key then
				n = n + 1
				old = k
			end
		end
		if n ~= 1 then old = nil end
	end
	old = old or shared
	if old and old ~= key and type(records[old]) == "table" then
		for k, v in pairs(records[old]) do records[key][k] = CopyRecord(v) end
	end
	return key
end

local recordKey       -- this character's key in DaylightEssentialsDB.halo, once known
local function Record()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if type(db.halo) ~= "table" then db.halo = {} end
	if not recordKey then
		if type(db.haloOwners) ~= "table" then db.haloOwners = {} end
		recordKey = CharKey(db.halo, db.haloOwners)
	end
	local me = recordKey or ((UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"))
	if type(db.halo[me]) ~= "table" then db.halo[me] = {} end
	return db.halo[me]
end

-- Ring r's slots: { [i] = action }.
local function Slots(r)
	local rec = Record()
	local key = RINGS[r or 1].key
	if not key then return rec end
	if type(rec[key]) ~= "table" then rec[key] = {} end
	return rec[key]
end

-- Ring r's label, or nil.
local function RingLabel(r)
	local labels = Record().labels
	local text = type(labels) == "table" and labels[r]
	if type(text) == "string" and text ~= "" then return text end
	return nil
end

local function SetRingLabel(r, text)
	local rec = Record()
	text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
	-- (The box stops at 16 letters; no byte cut here, which could split an accented letter.)
	if text == "" then
		if type(rec.labels) == "table" then rec.labels[r] = nil end
	else
		if type(rec.labels) ~= "table" then rec.labels = {} end
		rec.labels[r] = text
	end
end

-- Whether ring r is switched on (the base ring always is, while Halo is).
local function RingOn(r)
	if G("enabled") ~= true then return false end
	local key = RINGS[r].key
	return not key or G(key) == true
end

local function Accent()
	local r, g, b = API.Accent()
	return r or 1, g or 1, b or 1
end

-- Ring r's color: the base ring takes the accent unless the player picked its own.
local function RingColor(r)
	if r == 1 and G("baseAccent") ~= false then return Accent() end
	local c = G(RINGS[r].color)
	if type(c) == "table" and type(c[1]) == "number" then return c[1], c[2] or 1, c[3] or 1 end
	return Accent()
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and type(name) == "string" then return name end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, id)
		if ok and type(name) == "string" then return name end
	end
	return nil
end

local function ItemName(id)
	if C_Item and C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, id)
		if ok and type(name) == "string" then return name end
	end
	if GetItemInfo then
		local ok, name = pcall(GetItemInfo, id)
		if ok and type(name) == "string" then return name end
	end
	return nil
end

-- ---------------------------------------------------------------------------------------------
-- Mounts, companion pets and your combat pet's actions.
-- The game puts a mount on the mouse as "mount" (its journal ID) and a companion pet as "battlepet"
-- (its journal GUID): GetCursorInfo, read the way the game's own icon picker does
-- (SharedUIPanelTemplates.lua, SetIconFromMouse). Neither is a spell, item or macro, so they fire
-- the way the journals' own buttons do: C_MountJournal.SummonByID / Dismiss
-- (Blizzard_MountCollection.lua, MountJournalMountButton_UseMount) and
-- C_PetJournal.SummonPetByGUID (Blizzard_PetCollection.lua; the same call sends the pet away).
-- Neither call is protected, so the secure snippet hands them to plain code (CallMethod).
-- An ability or command of your pet is on the mouse as "petaction" (its spell, its place on the
-- pet bar): an ability fires as a spell by name, a command (no spell) through the pet bar slot
-- holding it (the secure "pet" action: CastPetAction).
-- ---------------------------------------------------------------------------------------------
local RANDOM_MOUNT_SPELL = 150544   -- Summon Random Favorite Mount (Blizzard_MountCollection.lua)

-- A mount: its name, icon, whether you're on it, whether it can be used now, its spell.
-- id 0: a random favorite.
local function MountInfo(id)
	if id == 0 then
		local name = _G.MOUNT_JOURNAL_SUMMON_RANDOM_FAVORITE_MOUNT
		if type(name) ~= "string" or name == "" then name = L["Random Favorite Mount"] end
		local icon
		if C_Spell and C_Spell.GetSpellTexture then
			local ok, t = pcall(C_Spell.GetSpellTexture, RANDOM_MOUNT_SPELL)
			if ok and t then icon = t end
		end
		return name, icon or 132261, false, not InCombatLockdown(), RANDOM_MOUNT_SPELL
	end
	local MJ = C_MountJournal
	if type(MJ) ~= "table" or not MJ.GetMountInfoByID or type(id) ~= "number" then return nil end
	local ok, name, spellID, icon, active, usable = pcall(MJ.GetMountInfoByID, id)
	if not ok or type(name) ~= "string" or not Safe(name) then return nil end
	return name, icon, Safe(active) and active == true, not Safe(usable) or usable ~= false, spellID
end

-- A companion pet: its name (the one you gave it first) and icon.
local function PetInfo(guid)
	local PJ = C_PetJournal
	if type(PJ) ~= "table" or not PJ.GetPetInfoByPetID or type(guid) ~= "string" then return nil end
	local ok, _, custom, _, _, _, _, _, name, icon = pcall(PJ.GetPetInfoByPetID, guid)
	if not ok then return nil end
	if type(custom) == "string" and custom ~= "" then name = custom end
	if type(name) ~= "string" then return nil end
	return name, icon
end

-- A pet command's pet bar slot now: the slot holding its token, else nil (no pet out).
local function PetCommandSlot(token)
	if not GetPetActionInfo then return nil end
	for i = 1, NUM_PET_ACTION_SLOTS or 10 do
		local name = GetPetActionInfo(i)
		if Safe(name) and name == token then return i end
	end
	return nil
end

-- A pet command's name and icon: the game's own words for its token ("PET_ACTION_ATTACK").
local function PetCommandInfo(a)
	local word = type(a.token) == "string" and _G[a.token]
	if type(word) ~= "string" or word == "" then word = a.name end
	-- (The pet bar names a command's icon by a token too: "PET_ATTACK_TEXTURE".)
	local icon = a.icon
	if type(icon) == "string" and _G[icon] then icon = _G[icon] end
	return word, icon
end

-- A mount or companion pet let go on: what the secure snippet hands over (never in its own path).
local function Summon(a)
	if type(a) ~= "table" then return end
	if a.kind == "mount" and C_MountJournal and C_MountJournal.SummonByID then
		local _, _, active = MountInfo(a.id)
		if active and a.id ~= 0 and C_MountJournal.Dismiss then
			pcall(C_MountJournal.Dismiss)
		else
			pcall(C_MountJournal.SummonByID, a.id)
		end
	elseif a.kind == "pet" and C_PetJournal and C_PetJournal.SummonPetByGUID then
		pcall(C_PetJournal.SummonPetByGUID, a.id)
	end
end

local function Texture(a)
	if type(a) ~= "table" then return nil end
	if a.kind == "mount" then
		local _, icon = MountInfo(a.id)
		if icon then return icon end
	elseif a.kind == "pet" then
		local _, icon = PetInfo(a.id)
		if icon then return icon end
	elseif a.kind == "petcmd" then
		local _, icon = PetCommandInfo(a)
		if icon then return icon end
	elseif a.kind == "petspell" then
		if C_Spell and C_Spell.GetSpellTexture then
			local ok, t = pcall(C_Spell.GetSpellTexture, a.id)
			if ok and t then return t end
		end
	elseif a.kind == "spell" then
		if C_Spell and C_Spell.GetSpellTexture then
			local ok, t = pcall(C_Spell.GetSpellTexture, a.name or a.id)
			if ok and t then return t end
			ok, t = pcall(C_Spell.GetSpellTexture, a.id)
			if ok and t then return t end
		end
	elseif a.kind == "item" then
		if C_Item and C_Item.GetItemIconByID then
			local ok, t = pcall(C_Item.GetItemIconByID, a.id)
			if ok and t then return t end
		end
		if GetItemIcon then
			local ok, t = pcall(GetItemIcon, a.id)
			if ok and t then return t end
		end
	elseif a.kind == "macro" and GetMacroInfo then
		local ok, _, t = pcall(GetMacroInfo, a.name)
		if ok and t then return t end
	end
	return 134400   -- the question mark
end

local function Label(a)
	if type(a) ~= "table" then return "" end
	if a.kind == "spell" then return SpellName(a.id) or a.name or L["Spell"] end
	if a.kind == "item" then return ItemName(a.id) or L["Item"] end
	if a.kind == "macro" then return a.name or L["Macro"] end
	if a.kind == "mount" then return MountInfo(a.id) or a.name or L["Mount"] end
	if a.kind == "pet" then return PetInfo(a.id) or a.name or L["Pet"] end
	if a.kind == "petspell" then return SpellName(a.id) or a.name or L["Pet Ability"] end
	if a.kind == "petcmd" then return PetCommandInfo(a) or L["Pet Command"] end
	return ""
end

-- What's on the mouse now (picked up from the spellbook, bags, macros, the mount or pet journal,
-- or your pet's bar or spellbook), as an action, or nil.
local function FromCursor()
	if not GetCursorInfo then return nil end
	local kind, a, b, c = GetCursorInfo()
	if kind == "spell" then
		local id = (type(c) == "number" and c) or (type(b) == "number" and b > 100 and b) or nil
		if not id and type(a) == "number" and GetSpellBookItemInfo then
			local ok, _, sid = pcall(GetSpellBookItemInfo, a, b)
			if ok and type(sid) == "number" then id = sid end
		end
		if id then return { kind = "spell", id = id, name = SpellName(id) } end
	elseif kind == "item" and type(a) == "number" then
		return { kind = "item", id = a }
	elseif kind == "macro" and a and GetMacroInfo then
		local name = GetMacroInfo(a)
		if type(name) == "string" then return { kind = "macro", name = name } end
	elseif kind == "mount" and type(a) == "number" then
		-- (The journal's Random Favorite Mount comes with an ID the journal has no mount for.)
		local name = MountInfo(a)
		if a ~= 0 and name then return { kind = "mount", id = a, name = name } end
		return { kind = "mount", id = 0 }
	elseif kind == "battlepet" and type(a) == "string" then
		return { kind = "pet", id = a, name = PetInfo(a) }
	elseif kind == "petaction" then
		-- An ability: its spell. A command (Attack, Follow, Passive...): no spell, so the token of
		-- the pet bar slot it was picked up from.
		if type(a) == "number" and a > 0 and SpellName(a) then
			return { kind = "petspell", id = a, name = SpellName(a) }
		end
		if type(b) == "number" and b > 0 and GetPetActionInfo then
			local token, icon, isToken = GetPetActionInfo(b)
			if Safe(token) and type(token) == "string" and Safe(isToken) and isToken then
				return { kind = "petcmd", token = token, slot = b, name = _G[token], icon = Safe(icon) and icon or nil }
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------------------------
-- The ring
-- ---------------------------------------------------------------------------------------------

local ring, center, title     -- ring: the protected frame the snippets show, one for every Halo
local screen                  -- a protected, invisible frame over the whole screen: the snippets
                              -- read the mouse on it (it never says "nowhere" the way a smaller
                              -- frame does once the mouse is past its edge)
local buttons = {}            -- buttons[r]: Halo r's own secure button, the one its key clicks
local binder                  -- owns Halo's own key bindings (a plain frame)
local holders = {}            -- holders[r]: a plain frame holding Halo r's icons
local tiles = {}              -- tiles[r][k]: Halo r's icons, one per filled slot shown
local shownBy = {}            -- shownBy[r][k] = the slot number (1..MAX) of Halo r's k-th icon
local anglesBy = {}           -- anglesBy[r][k] = its direction in degrees (0 = right, 90 = up)
local xBy = {}                -- xBy[r][k] = on a bar, its sideways offset from the middle
for r = 1, #RINGS do
	tiles[r], shownBy[r], anglesBy[r], xBy[r] = {}, {}, {}, {}
end
local step                    -- the secure button the D-pad steps through while a Halo is open
local open = 1                -- the Halo open now (read from the ring's "owner" on show)
local pending = false         -- a change waiting for the end of a fight

-- Halo r's button. The base one keeps the name it always had, so a key set for it under Key
-- Bindings stays; the others are "...Button2" to "...Button4".
local function ButtonName(r)
	return r == 1 and BUTTON or (BUTTON .. r)
end

local function Tile(r, k)
	local t = tiles[r][k]
	if t then return t end
	t = CreateFrame("Frame", nil, holders[r])
	t.art = t:CreateTexture(nil, "ARTWORK")
	t.art:SetPoint("TOPLEFT", t, "TOPLEFT", 2, -2)
	t.art:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2)
	t.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t.lit = t:CreateTexture(nil, "OVERLAY")
	t.lit:SetPoint("TOPLEFT", t, "TOPLEFT", -2, 2)
	t.lit:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 2, -2)
	t.lit:SetColorTexture(1, 1, 1, 0)
	t.lit:SetDrawLayer("BACKGROUND", -1)
	tiles[r][k] = t
	return t
end

-- Each icon's direction for n icons: Ring from the top, clockwise; Arc from the left over the top.
local function Angles(list, n)
	wipe(list)
	local arc = G("shape") == "arc"
	for k = 1, n do
		if arc then
			list[k] = n == 1 and 90 or (180 - (k - 1) * 180 / (n - 1))
		else
			list[k] = 90 - (k - 1) * 360 / n
		end
	end
end

-- The ring's frame is bigger than the ring itself (room for the label and the lit icon).
local function RingSize()
	local r, s = G("radius") or 90, G("iconSize") or 36
	return math.floor((r + s) * 2 + r)
end

-- Which icon of the open Halo a direction points at (k), or nil in the middle. dx, dy in pixels
-- from where it opened. However far past the ring the mouse goes, the direction still counts (the
-- secure side measures on the whole screen the same way). Settings read every frame while it's
-- open: kept from the last Apply (which every setting change runs).
local cIcon, cNames, cDim = 36, true, true
local cCool = true
local cBar, cPad, cHint = false, false, nil   -- a bar; on a controller (no mouse picking); its hint

local function Pointed(dx, dy)
	local shown, angles = shownBy[open], anglesBy[open]
	local n = #shown
	if n == 0 or cPad then return nil end
	local dead = math.max(14, cIcon * 0.6)
	if cBar then
		-- A bar: once the mouse is moved up past the middle, the icon nearest it sideways.
		if dy < dead then return nil end
		local xs, best, bestD = xBy[open], nil, nil
		for k = 1, n do
			local d = math.abs(xs[k] - dx)
			if not bestD or d < bestD then best, bestD = k, d end
		end
		return best
	end
	if dx * dx + dy * dy < dead * dead then return nil end
	local a = math.deg(math.atan2(dy, dx))
	local best, bestD
	for k = 1, n do
		local d = math.abs(((angles[k] - a + 540) % 360) - 180)
		if not bestD or d < bestD then best, bestD = k, d end
	end
	return best
end

-- The secure snippet, the same on every Halo's button. Which Halo it is never depends on the
-- modifiers held or the button's name: each button has its own fixed "halo", and each modifier's
-- key clicks its own button. The key going down: unless another Halo is held open, note this
-- button as the ring's "owner", note where the mouse is (the middle every direction is read from;
-- the screen's middle when it opens there), open the ring and cancel the click. Coming up (only
-- the owner's): close it, and the slot pointed at, or scrolled to, gets the click ("h<slot>"), or
-- nothing does. What's picked this hold ("pick", "wheel") is kept on the button itself.
local DOWN_UP = [=[
	local ring = self:GetFrameRef("ring")
	local me = self:GetAttribute("halo")
	local holder = ring:GetAttribute("owner") or 0
	if down then
		if ring:IsShown() and holder ~= 0 and holder ~= me then return false end
		local screen = self:GetFrameRef("screen")
		local w, h = screen:GetWidth(), screen:GetHeight()
		local px, py = 0.5, 0.5
		if self:GetAttribute("atcursor") then
			local x, y = screen:GetMousePosition()
			if x and y then px, py = x, y end
			ring:ClearAllPoints()
			ring:SetPoint("CENTER", "$cursor")
		end
		self:SetAttribute("px", px * w)
		self:SetAttribute("py", py * h)
		self:SetAttribute("pick", 0)
		self:SetAttribute("wheel", 0)
		if ring:IsShown() then ring:Hide() end
		ring:SetAttribute("owner", me)
		ring:Show()
		-- The D-pad (and LB / RB, B) for as long as it's held: bound to the step button.
		local step = self:GetFrameRef("step")
		step:ClearBindings()
		for i = 1, step:GetAttribute("nb") or 0 do
			step:SetBindingClick(true, step:GetAttribute("bk" .. i), step, step:GetAttribute("bv" .. i))
		end
		return false
	end
	if holder ~= me then return false end
	ring:SetAttribute("owner", 0)
	self:GetFrameRef("step"):ClearBindings()
	if not ring:IsShown() then return false end
	ring:Hide()
	local n = self:GetAttribute("n") or 0
	if n == 0 then return false end
	local k = 0
	if (self:GetAttribute("wheel") or 0) == 1 then
		k = self:GetAttribute("pick") or 0
	elseif not self:GetAttribute("nomouse") then
		local screen = self:GetFrameRef("screen")
		local x, y = screen:GetMousePosition()
		if x and y then
			local dx = x * screen:GetWidth() - (self:GetAttribute("px") or 0)
			local dy = y * screen:GetHeight() - (self:GetAttribute("py") or 0)
			local dead = self:GetAttribute("dead") or 14
			if self:GetAttribute("bar") then
				-- A bar: moved up past the middle, the icon nearest the mouse sideways.
				if dy >= dead then
					local bestD
					for i = 1, n do
						local d = math.abs((self:GetAttribute("x" .. i) or 0) - dx)
						if not bestD or d < bestD then k, bestD = i, d end
					end
				end
			elseif dx * dx + dy * dy >= dead * dead then
				local a = math.deg(math.atan2(dy, dx))
				local bestD
				for i = 1, n do
					local d = math.abs(((self:GetAttribute("a" .. i) - a + 540) % 360) - 180)
					if not bestD or d < bestD then k, bestD = i, d end
				end
			end
		end
	end
	local slot = k > 0 and self:GetAttribute("s" .. k)
	if not slot then return false end
	-- A mount or companion pet: no secure action, plain code summons it.
	if self:GetAttribute("call" .. slot) then
		self:CallMethod("HaloSummon", slot)
		return false
	end
	return "h" .. slot
]=]

-- The mouse wheel over the open ring: steps the owning button's pick.
local WHEEL = [=[
	local b = self:GetFrameRef("b" .. (self:GetAttribute("owner") or 0))
	if not b then return end
	local n = b:GetAttribute("n") or 0
	if n == 0 then return end
	local k = (b:GetAttribute("pick") or 0) - (offset > 0 and 1 or -1)
	if k < 1 then k = n elseif k > n then k = 1 end
	b:SetAttribute("pick", k)
	b:SetAttribute("wheel", 1)
]=]

-- A stepping key while a Halo is held open (the step button's own snippet; "LEFT" / "RIGHT" /
-- "CANCEL" are the virtual mouse buttons its bindings click with). Left and right step the
-- owning button's pick the way the wheel does (from nothing picked, Right goes to the first and
-- Left to the last); Cancel closes the Halo with nothing used: the owner is let go, so the key
-- coming up finds nothing to do.
local STEP = [=[
	local ring = self:GetFrameRef("ring")
	local b = ring:GetFrameRef("b" .. (ring:GetAttribute("owner") or 0))
	if not b or not ring:IsShown() then
		self:ClearBindings()
		return
	end
	if button == "CANCEL" then
		ring:SetAttribute("owner", 0)
		ring:Hide()
		self:ClearBindings()
		return
	end
	local n = b:GetAttribute("n") or 0
	if n == 0 then return end
	local k = (b:GetAttribute("pick") or 0) + (button == "LEFT" and -1 or 1)
	if k < 1 then k = n elseif k > n then k = 1 end
	b:SetAttribute("pick", k)
	b:SetAttribute("wheel", 1)
]=]

local FIELDS = { "spell", "item", "macro", "action" }   -- the secure button's action fields
local reskin = false                           -- a style change: every tile skinned again

-- Every modifier set a key can carry, in the order the game writes them ("ALT-CTRL-SHIFT-").
local CHORDS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-", "ALT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }

-- A key without its modifiers ("SHIFT-PAD1" -> "PAD1").
local MOD_PREFIX = { "ALT-", "CTRL-", "SHIFT-", "META-" }
local function Bare(key)
	if type(key) ~= "string" then return nil end
	local again = true
	while again do
		again = false
		for _, m in ipairs(MOD_PREFIX) do
			if #key > #m and key:sub(1, #m) == m then
				key = key:sub(#m + 1)
				again = true
			end
		end
	end
	return key
end

-- Every key that opens a Halo: Halo's own and the game's Key Bindings entries, without modifiers.
local function HaloKeys()
	local out = {}
	local own = G("key")
	if type(own) == "string" and own ~= "" then out[Bare(own)] = true end
	if GetBindingKey then
		for r = 1, #RINGS do
			for _, k in ipairs({ GetBindingKey("CLICK " .. ButtonName(r) .. ":LeftButton") }) do
				if type(k) == "string" and k ~= "" then out[Bare(k)] = true end
			end
		end
	end
	return out
end

-- Whether Halo is played with a controller: the game's controller mode is on (as Daylight UI's
-- Pad.On() reads it), or a Halo's key is a controller button.
local function PadUI()
	local IU = _G.InputUtil
	if type(IU) == "table" and type(IU.IsGamepadUIEnabled) == "function" then
		local ok, on = pcall(IU.IsGamepadUIEnabled)
		if ok and on == true then return true end
	end
	-- (Guide.lua's ns.Pad: Daylight UI's kit, checked and pcall'd.)
	if ns.Pad and ns.Pad.On() then return true end
	return false
end

local function Controller(keys)
	if PadUI() then return true end
	for k in pairs(keys or HaloKeys()) do
		if k:sub(1, 3) == "PAD" then return true end
	end
	return false
end

-- The keys that step an open Halo: { game's key global, its usual name, what it does }.
local STEPS = {
	{ "GAMEPAD_DPAD_LEFT", "PADDLEFT", "LEFT" },
	{ "GAMEPAD_DPAD_RIGHT", "PADDRIGHT", "RIGHT" },
	{ "GAMEPAD_SHOULDER_LEFT", "PADLSHOULDER", "LEFT" },
	{ "GAMEPAD_SHOULDER_RIGHT", "PADRSHOULDER", "RIGHT" },
	{ "GAMEPAD_FACE_RIGHT", "PAD2", "CANCEL" },
}
local EMULATE = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }

local function StepKey(def)
	local k = _G[def[1]]
	return type(k) == "string" and k ~= "" and k or def[2]
end

-- A controller button's picture for text (the game's own glyph), or its name.
local function Glyph(key)
	local g = _G["KEY_ABBR_" .. key]
	if type(g) == "string" and g ~= "" then return g end
	if GetBindingText then
		local ok, text = pcall(GetBindingText, key)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	return key
end

-- The stepping keys Halo may take while open: none that opens a Halo or stands in for Shift,
-- Ctrl or Alt. Returns { { key, what } ... } and a signature of what decides the layout.
local function StepList(keys)
	local skip = {}
	for k in pairs(keys) do skip[k] = true end
	if _G.GetCVar then
		for _, cvar in ipairs(EMULATE) do
			local ok, v = pcall(_G.GetCVar, cvar)
			if ok and type(v) == "string" and v ~= "" and v ~= "NONE" then skip[v] = true end
		end
	end
	local list, sig = {}, {}
	for _, def in ipairs(STEPS) do
		local k = StepKey(def)
		if not skip[k] then
			list[#list + 1] = { k, def[3] }
			sig[#sig + 1] = k
		end
	end
	return list, table.concat(sig, ",")
end

-- What decides the layout and the stepping keys, as one string (checked when bindings or
-- settings change, so Halo is only laid out again when it matters).
local function PadSig()
	local keys = HaloKeys()
	local _, sig = StepList(keys)
	return tostring(Controller(keys)) .. ";" .. sig
end
local lastSig

-- Writes every Halo's layout and every slot's action onto its own button. Out of a fight only.
local function Apply()
	if not ring then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local count = math.min(MAX, G("count") or 8)
	local size, icon, radius = RingSize(), G("iconSize") or 36, G("radius") or 90
	cIcon, cNames, cDim = icon, G("names") and true or false, G("dim") and true or false
	cCool = G("cdTime") ~= false
	-- Ring or bar, and whether a controller drives it (then it opens in the middle, the mouse
	-- doesn't pick, and the D-pad does).
	local keys = HaloKeys()
	local pad = Controller(keys)
	local steps, sig = StepList(keys)
	lastSig = tostring(pad) .. ";" .. sig
	cPad = pad
	cBar = G("layout") == "bar" or (pad and G("padBar") ~= false)
	local atCursor = G("opens") == "cursor" and not pad
	local dead = math.max(14, icon * 0.6)
	local stepPx = icon + math.max(6, math.floor(icon * 0.2))
	local rise = math.floor(dead + icon / 2 + 4)   -- a bar's icons sit this far over the middle
	if cBar then
		ring:SetSize(count * stepPx + icon * 2, (rise + icon) * 2 + 40)
	else
		ring:SetSize(size, size)
	end
	if not atCursor then
		ring:ClearAllPoints()
		ring:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	-- The label sits just over the top of the ring (or bar), its own width (never cut short).
	title:ClearAllPoints()
	title:SetPoint("BOTTOM", ring, "CENTER", 0, (cBar and rise or radius) + icon / 2 + 8)
	-- On a controller, what to press, in the middle while nothing is picked.
	cHint = nil
	if pad then
		local left, right, cancel
		for _, s in ipairs(steps) do
			if s[2] == "LEFT" then left = left or s[1]
			elseif s[2] == "RIGHT" then right = right or s[1]
			else cancel = cancel or s[1] end
		end
		if left and right and cancel then
			cHint = L["%s or %s to choose, %s to cancel"]:format(Glyph(left), Glyph(right), Glyph(cancel))
		elseif left and right then
			cHint = L["%s or %s to choose"]:format(Glyph(left), Glyph(right))
		end
	end
	-- The stepping keys, every modifier set of each, for the snippet to bind while it's open.
	if step then
		local nb = 0
		for _, s in ipairs(steps) do
			for _, chord in ipairs(CHORDS) do
				nb = nb + 1
				step:SetAttribute("bk" .. nb, chord .. s[1])
				step:SetAttribute("bv" .. nb, s[2])
			end
		end
		step:SetAttribute("nb", nb)
	end
	for r = 1, #RINGS do
		local b = buttons[r]
		local slots, shown, angles, xs, list = Slots(r), shownBy[r], anglesBy[r], xBy[r], tiles[r]
		local on = RingOn(r)
		wipe(shown)
		for i = 1, count do
			if on and type(slots[i]) == "table" then shown[#shown + 1] = i end
		end
		local n = #shown
		Angles(angles, n)
		wipe(xs)
		for k = 1, n do xs[k] = (k - (n + 1) / 2) * stepPx end
		for k = 1, math.max(n, #list) do
			local t = k <= n and Tile(r, k) or list[k]
			if k <= n then
				local a = slots[shown[k]]
				t.base = icon
				t:SetSize(icon, icon)
				t:ClearAllPoints()
				if cBar then
					t:SetPoint("CENTER", ring, "CENTER", xs[k], rise)
				else
					local rad = math.rad(angles[k])
					t:SetPoint("CENTER", ring, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
				end
				t.art:SetTexture(Texture(a))
				t.action = a
				if reskin or t.skinnedAt ~= icon then
					t.skinnedAt = icon
					API.Skin(t, { noBevel = true, borderPx = 2, bgAlpha = 0.85 })
				end
				t:Show()
			elseif t then
				t:Hide()
				t.action = nil
			end
		end
		-- The secure side, on this Halo's button: how many, their directions, which slot each is,
		-- and each slot's action.
		b:SetAttribute("size", size)
		b:SetAttribute("dead", dead)
		b:SetAttribute("atcursor", atCursor)
		b:SetAttribute("bar", cBar)
		b:SetAttribute("nomouse", pad)
		b:SetAttribute("n", n)
		for k = 1, MAX do
			b:SetAttribute("a" .. k, angles[k])
			b:SetAttribute("x" .. k, xs[k])
			b:SetAttribute("s" .. k, shown[k])
		end
		for i = 1, MAX do
			local a = on and i <= count and slots[i] or nil
			local suffix = "-h" .. i
			local kind, field, value
			if type(a) == "table" then
				if a.kind == "spell" then
					kind, field, value = "spell", "spell", SpellName(a.id) or a.name or a.id
				elseif a.kind == "item" then
					kind, field, value = "item", "item", "item:" .. a.id
				elseif a.kind == "macro" then
					kind, field, value = "macro", "macro", a.name
				elseif a.kind == "petspell" then
					kind, field, value = "spell", "spell", SpellName(a.id) or a.name or a.id
				elseif a.kind == "petcmd" then
					-- (Where the command is on the pet bar now; with no pet out, where it was.)
					local at = PetCommandSlot(a.token)
					if at then a.slot = at end
					if type(a.slot) == "number" then kind, field, value = "pet", "action", a.slot end
				end
			end
			-- (A mount or companion pet: summoned by plain code, see the snippet.)
			b:SetAttribute("call" .. i, type(a) == "table" and (a.kind == "mount" or a.kind == "pet") or nil)
			b:SetAttribute("type" .. suffix, kind)
			b:SetAttribute("typerelease" .. suffix, kind)
			for _, f in ipairs(FIELDS) do
				b:SetAttribute(f .. suffix, f == field and value or nil)
			end
		end
	end
	reskin = false
end

-- Halo's own key, as override bindings (the player's saved bindings stay as they are). Out of a
-- fight only; asked in one, it waits for the fight to end.
--   * The key on its own clicks the base Halo's button; Shift-, Alt- and Ctrl- with it click
--     their Halo's button, only while that Halo is on and has something in it.
--   * Then every other modifier set of the same key that holds a Halo's modifier (Shift: Alt-Shift,
--     Ctrl-Shift, Alt-Ctrl-Shift) clicks that Halo's button too, and what's still left the base
--     one, where nothing else has the chord (no binding, or one of ours) and no Halo has claimed
--     it already. A key comes up through the chord held at that moment, so pressing or letting go
--     of a modifier mid-hold still reaches the button that opened.
local keysPending = false
local function Ours(action)
	return type(action) == "string" and action:sub(1, #BUTTON + 6) == "CLICK " .. BUTTON
end

local function ApplyKeys()
	if not binder then return end
	if InCombatLockdown() then
		keysPending = true
		return
	end
	keysPending = false
	ClearOverrideBindings(binder)
	local key = G("key")
	if G("enabled") ~= true or type(key) ~= "string" or key == "" then return end
	local claimed = {}
	local function Bind(chord, r)
		SetOverrideBindingClick(binder, true, chord .. key, ButtonName(r), "LeftButton")
		claimed[chord] = r
	end
	local function Free(chord)
		if claimed[chord] then return false end
		local action = GetBindingAction(chord .. key, true)
		return action == nil or action == "" or Ours(action)
	end
	Bind("", 1)
	local live = {}
	for r = 2, #RINGS do
		if RingOn(r) and #shownBy[r] > 0 then
			live[r] = true
			Bind(RINGS[r].mod .. "-", r)
		end
	end
	for r = 2, #RINGS do
		if live[r] then
			for _, chord in ipairs(CHORDS) do
				if chord:find(RINGS[r].mod .. "-", 1, true) and Free(chord) then Bind(chord, r) end
			end
		end
	end
	for _, chord in ipairs(CHORDS) do
		if Free(chord) then Bind(chord, 1) end
	end
end

-- What isn't ready (dimmed), read five times a second while the ring is open.
local function Ready(a)
	if a.kind == "mount" then
		local name, _, _, usable = MountInfo(a.id)
		return name ~= nil and usable
	elseif a.kind == "pet" then
		if C_PetJournal and C_PetJournal.PetIsSummonable then
			local ok, can = pcall(C_PetJournal.PetIsSummonable, a.id)
			if ok and Safe(can) and can == false then return false end
		end
		return true
	elseif a.kind == "petcmd" then
		return UnitExists("pet") and PetCommandSlot(a.token) ~= nil
	elseif a.kind == "petspell" and not UnitExists("pet") then
		return false
	elseif a.kind == "spell" or a.kind == "petspell" then
		local id = a.name or a.id
		if C_Spell and C_Spell.GetSpellCooldown then
			local ok, info = pcall(C_Spell.GetSpellCooldown, id)
			if ok and type(info) == "table" and type(info.isActive) == "boolean"
				and info.isActive and info.isOnGCD ~= true then
				return false
			end
		end
		if C_Spell and C_Spell.IsSpellUsable then
			local ok, usable = pcall(C_Spell.IsSpellUsable, id)
			if ok and Safe(usable) and usable == false then return false end
		end
		return true
	elseif a.kind == "item" then
		local count
		if C_Item and C_Item.GetItemCount then
			local ok, c = pcall(C_Item.GetItemCount, a.id)
			if ok and Safe(c) then count = c end
		end
		if type(count) == "number" and count == 0 then return false end
		if C_Container and C_Container.GetItemCooldown then
			local ok, start, duration = pcall(C_Container.GetItemCooldown, a.id)
			if ok and Safe(start) and Safe(duration) and type(start) == "number" and type(duration) == "number"
				and start > 0 and duration > 1.5 then
				return false
			end
		end
	end
	return true
end

-- The time left on an icon that's cooling down: the game's own countdown, on a cooldown frame over
-- the icon with nothing else drawn (no sweep, no edge, no flash: the icon is dimmed already).
-- A spell's is drawn from its duration object, which the game reads as it is, hidden or not, in a
-- fight too (C_Spell.GetSpellCooldownDuration with ignoreGCD, SpellDocumentation.lua:327-341;
-- Cooldown:SetCooldownFromDurationObject, FrameAPICooldownDocumentation.lua:308). An item's from
-- its start and length (C_Container.GetItemCooldown, ContainerDocumentation.lua:337-351, whose
-- returns carry no secret marker; left alone if they ever come hidden).
-- Set once per cooldown (t.cool names the one drawn), not five times a second.
local function CoolFrame(t)
	local cd = t.cd
	if cd then return cd end
	cd = CreateFrame("Cooldown", nil, t, "CooldownFrameTemplate")
	cd:SetPoint("TOPLEFT", t.art, "TOPLEFT", 0, 0)
	cd:SetPoint("BOTTOMRIGHT", t.art, "BOTTOMRIGHT", 0, 0)
	if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
	if cd.SetDrawEdge then cd:SetDrawEdge(false) end
	if cd.SetDrawBling then cd:SetDrawBling(false) end
	if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
	t.cd = cd
	return cd
end

local function CoolOff(t)
	if t.cool == nil then return end
	t.cool = nil
	if t.cd then
		pcall(t.cd.Clear, t.cd)
		t.cd:Hide()
	end
end

local function Cool(t, a)
	if a.kind == "spell" or a.kind == "petspell" then
		local id = a.name or a.id
		local active = false
		if C_Spell and C_Spell.GetSpellCooldown then
			local ok, info = pcall(C_Spell.GetSpellCooldown, id)
			active = ok and type(info) == "table" and type(info.isActive) == "boolean"
				and info.isActive and info.isOnGCD ~= true
		end
		if not active then CoolOff(t) return end
		if t.cool == "spell" then return end
		local cd = CoolFrame(t)
		if C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
			local ok, d = pcall(C_Spell.GetSpellCooldownDuration, id, true)
			if ok and type(d) ~= "nil" and pcall(cd.SetCooldownFromDurationObject, cd, d, true) then
				cd:Show()
				t.cool = "spell"
				return
			end
		end
		CoolOff(t)
	elseif a.kind == "item" then
		local start, duration
		if C_Container and C_Container.GetItemCooldown then
			local ok, s, d = pcall(C_Container.GetItemCooldown, a.id)
			if ok and Safe(s) and Safe(d) and type(s) == "number" and type(d) == "number" then start, duration = s, d end
		end
		if not start or start <= 0 or duration <= 1.5 then CoolOff(t) return end
		local key = start .. ":" .. duration
		if t.cool == key then return end
		local cd = CoolFrame(t)
		if pcall(cd.SetCooldown, cd, start, duration) then
			cd:Show()
			t.cool = key
		else
			CoolOff(t)
		end
	else
		CoolOff(t)
	end
end

-- The rim every icon of the open Halo has in its color; the one pointed at is lit fully.
local REST_ALPHA = 0.35

local lastLit, dimAt = nil, 0
local function OnUpdate()
	local shown, list, b = shownBy[open], tiles[open], buttons[open]
	if #shown == 0 then return end
	-- Which icon is pointed at (or scrolled to): the same rule the secure snippet uses, from the
	-- point it opened at (on the button), in the screen frame's units.
	local k
	if b:GetAttribute("wheel") == 1 then
		k = b:GetAttribute("pick")
		if k == 0 then k = nil end
	elseif not cPad then
		local x, y = GetCursorPosition()
		local s = screen:GetEffectiveScale()
		k = Pointed(x / s - (b:GetAttribute("px") or 0), y / s - (b:GetAttribute("py") or 0))
	end
	if k ~= lastLit then
		local r, g, bl = RingColor(open)
		for i, t in ipairs(list) do
			if i == k then
				t.lit:SetColorTexture(r, g, bl, 0.9)
				t:SetSize(t.base * 1.12, t.base * 1.12)
			else
				t.lit:SetColorTexture(r, g, bl, REST_ALPHA)
				t:SetSize(t.base, t.base)
			end
		end
		lastLit = k
		if cNames and k and list[k] and list[k].action then
			center:SetText(Label(list[k].action))
		elseif not k and cHint then
			center:SetText(cHint)
		else
			center:SetText("")
		end
	end
	local now = GetTime()
	if (cDim or cCool) and now >= dimAt then
		dimAt = now + 0.2
		for i = 1, #shown do
			local t = list[i]
			if t and t.action then
				if cDim then
					local ready = Ready(t.action)
					t.art:SetDesaturated(not ready)
					t.art:SetAlpha(ready and 1 or 0.45)
				end
				if cCool then Cool(t, t.action) end
			end
		end
	end
end

-- The ring just opened: show the icons of the Halo whose button opened it, in its color, its
-- label over it.
local function OnShow()
	local r = ring:GetAttribute("owner")
	open = (type(r) == "number" and RINGS[r]) and r or 1
	for i = 1, #RINGS do holders[i]:SetShown(i == open) end
	lastLit, dimAt = false, 0
	local cr, cg, cb = RingColor(open)
	for _, t in ipairs(tiles[open]) do t.lit:SetColorTexture(cr, cg, cb, REST_ALPHA) end
	title:SetText(RingLabel(open) or "")
	title:SetTextColor(cr, cg, cb)
	center:SetText(#shownBy[open] == 0 and L["No actions yet: Edit Halos on Halo's page"] or "")
	if not cDim then
		for _, t in ipairs(tiles[open]) do
			t.art:SetDesaturated(false)
			t.art:SetAlpha(1)
		end
	end
	-- (Each opening draws its countdowns anew: a slot may hold another action by now.)
	for _, t in ipairs(tiles[open]) do CoolOff(t) end
	-- (Casts Left's numbers on the mage's spells: CastsLeft.lua.)
	if ns.CastsLeft then ns.CastsLeft.Halo(tiles[open], #shownBy[open]) end
end

local function Build()
	-- The ring: protected (SecureFrameTemplate), so the snippet can show and hide it in a fight.
	ring = CreateFrame("Frame", "DaylightEssentialsHalo", UIParent, "SecureFrameTemplate")
	ring:SetFrameStrata("DIALOG")
	ring:SetSize(RingSize(), RingSize())
	ring:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	ring:EnableMouseWheel(true)
	ring:Hide()
	ring:SetAttribute("owner", 0)
	-- One plain holder per Halo for its icons: opening one only shows its holder, so nothing is
	-- laid out in a fight.
	for r = 1, #RINGS do
		local h = CreateFrame("Frame", nil, ring)
		h:SetAllPoints(ring)
		h:Hide()
		holders[r] = h
	end
	center = API.Text(ring, "body", "CENTER")
	center:SetPoint("CENTER", ring, "CENTER", 0, 0)
	ns.Ink(center, "TITLE")
	-- The Halo's label: no width of its own, so 16 letters are never cut short whatever the size.
	title = API.Text(ring, "body", "CENTER")
	title:SetWordWrap(false)
	title:SetPoint("BOTTOM", ring, "CENTER", 0, 60)
	ring:SetScript("OnUpdate", OnUpdate)
	ring:SetScript("OnShow", OnShow)

	-- The whole screen, protected and invisible, taking no clicks: the snippets may read the mouse
	-- on a protected frame in a fight, and on this one it's always somewhere.
	screen = CreateFrame("Frame", nil, UIParent, "SecureFrameTemplate")
	screen:SetAllPoints(UIParent)
	screen:EnableMouse(false)

	-- Each Halo's button. Its click never acts by itself: the snippet cancels the key going down,
	-- and on the key coming up hands the click to a slot ("h3": typerelease-h3, spell-h3...). With
	-- press-and-hold on, the game always fires the release through "typerelease" ("type" is set
	-- too, unused). The modifiers still held then don't matter: the action attributes have no
	-- modifier prefix, and the game falls back to the plain ones. (A macro run from a Shift, Alt or
	-- Ctrl Halo sees that modifier held, and its button as "h3": [mod] and [btn] read that way.)
	ring:SetScript("OnMouseWheel", function() end)
	for r = 1, #RINGS do
		local b = CreateFrame("Button", ButtonName(r), UIParent,
			"SecureActionButtonTemplate,SecureHandlerBaseTemplate")
		b:RegisterForClicks("AnyDown", "AnyUp")
		b:SetAttribute("pressAndHoldAction", true)
		b:SetAttribute("useOnKeyDown", false)
		b:SetAttribute("type", nil)
		b:SetAttribute("halo", r)
		-- (What the snippet calls for a slot holding a mount or a companion pet.)
		b.HaloSummon = function(_, slot)
			if type(slot) == "number" then Summon(Slots(r)[slot]) end
		end
		b:Hide()   -- (a click binding still reaches a hidden button)
		SecureHandlerSetFrameRef(b, "ring", ring)
		SecureHandlerSetFrameRef(b, "screen", screen)
		SecureHandlerWrapScript(b, "OnClick", b, DOWN_UP)
		SecureHandlerSetFrameRef(ring, "b" .. r, b)
		buttons[r] = b
	end
	-- (The handler first, then wrapped: setting it after would replace the wrapper.)
	SecureHandlerWrapScript(ring, "OnMouseWheel", buttons[1], WHEEL)

	-- The step button: what the D-pad, LB / RB and B click while a Halo is held open (the
	-- snippet above binds them to it, and owns those bindings through it). A key's press is
	-- enough; hidden, as a click binding still reaches it.
	step = CreateFrame("Button", "DaylightEssentialsHaloStep", UIParent, "SecureHandlerClickTemplate")
	step:RegisterForClicks("AnyDown")
	step:Hide()
	step:SetAttribute("nb", 0)
	step:SetAttribute("_onclick", STEP)
	SecureHandlerSetFrameRef(step, "ring", ring)
	for r = 1, #RINGS do SecureHandlerSetFrameRef(buttons[r], "step", step) end

	binder = CreateFrame("Frame")
end

-- ---------------------------------------------------------------------------------------------
-- Halo's own key: a small box that takes the next key pressed (out of a fight)
-- ---------------------------------------------------------------------------------------------

-- Shift, Alt and Ctrl on their own can't be the key: they pick the rings.
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, SHIFT = true, CTRL = true, ALT = true, META = true }
-- The mouse buttons the box takes (left and right stay for its own buttons).
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function KeyText(key)
	if type(key) ~= "string" or key == "" then return nil end
	if GetBindingText then
		local ok, text = pcall(GetBindingText, key)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	return key
end

local box

local function SaveKey(key)
	local ok, done = pcall(ns.DUI.Set, ns.DUI, ns.ADDON, KEY .. ".key", key)
	if not ok or done == false then
		Say(L["the key couldn't be saved."])
		return false
	end
	ns.Forget()
	return true
end

local function BoxLayout()
	local now = KeyText(G("key"))
	box.now:SetText(L["Now: %s"]:format(now or L["none"]))
	local game = GetBindingKey and GetBindingKey("CLICK " .. BUTTON .. ":LeftButton")
	box.game:SetText(game and L["Also in Key Bindings: %s"]:format(KeyText(game) or game) or "")
	box.clear:SetShown(now ~= nil)
	-- Tall enough for every line at its width: nothing is cut short.
	local w = box:GetWidth() - 24
	local h = 40
	for _, fs in ipairs({ box.now, box.game, box.help, box.msg }) do
		fs:SetWidth(w)
		local text = fs:GetText()
		if text and text ~= "" then h = h + math.ceil(fs:GetStringHeight() or 14) + 6 end
	end
	box:SetHeight(h + 40)
	ns.SkinWindow(box, nil, KEY)
end

local function Take(key)
	if InCombatLockdown() then return end
	if MODIFIERS[key] then
		box.msg:SetText(L["Shift, Alt and Ctrl can't be the key on their own: held with it, they open the other Halos."])
		ns.Host.Ink(box.msg, "WARN")
		BoxLayout()
		return
	end
	local was = GetBindingAction and GetBindingAction(key)
	if SaveKey(key) then
		local note = L["the key is now %s."]
		if type(was) == "string" and was ~= "" and not Ours(was) then
			note = L["the key is now %s. (it was bound to something else, which comes back if you clear Halo's key)"]
		end
		Say(note:format(KeyText(key) or key))
		P.KeyBox(false)
	end
end

local function BuildBox()
	box = CreateFrame("Frame", "DaylightEssentialsHaloKeyBox", UIParent)
	box:SetFrameStrata("FULLSCREEN_DIALOG")
	box:SetToplevel(true)
	box:SetSize(320, 150)
	box:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	local head = API.Text(box, "head", "LEFT")
	head:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -12)
	head:SetText(L["Halo's Key"])
	-- (The box's inks follow the look: Host.Ink paints them again on every look change.)
	ns.Host.Ink(head, "TITLE")
	box.now = API.Text(box, "body", "LEFT")
	box.now:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -40)
	ns.Host.Ink(box.now, "VALUE")
	box.game = API.Text(box, "small", "LEFT")
	box.game:SetPoint("TOPLEFT", box.now, "BOTTOMLEFT", 0, -6)
	ns.Host.Ink(box.game, "LABEL")
	box.help = API.Text(box, "small", "LEFT")
	box.help:SetPoint("TOPLEFT", box.game, "BOTTOMLEFT", 0, -6)
	box.help:SetText(L["Press the key you want, or click here with the mouse's middle or a side button. Escape cancels."])
	ns.Host.Ink(box.help, "TEXT")
	box.msg = API.Text(box, "small", "LEFT")
	box.msg:SetPoint("TOPLEFT", box.help, "BOTTOMLEFT", 0, -6)
	for _, fs in ipairs({ box.now, box.game, box.help, box.msg }) do fs:SetWordWrap(true) end
	local close = API.Close(box, function() P.KeyBox(false) end)
	if close then close:SetPoint("TOPRIGHT", box, "TOPRIGHT", -6, -6) end
	box.clear = API.Button(box, L["Clear"], 24)
	box.clear:SetWidth(90)
	box.clear:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -12, 12)
	box.clear:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		if SaveKey("") then
			Say(L["Halo's own key is cleared (a key set under Key Bindings still works)."])
			P.KeyBox(false)
		end
	end)
	box:SetScript("OnKeyDown", function(_, key)
		if key == "ESCAPE" then
			P.KeyBox(false)
		else
			Take(key)
		end
	end)
	-- A controller button is taken as the key; the one that opens the game menu (Start, by
	-- default) closes the box, as Escape does.
	box:SetScript("OnGamePadButtonDown", function(_, key)
		if GetBindingAction and GetBindingAction(key) == "TOGGLEGAMEMENU" then
			P.KeyBox(false)
		else
			Take(key)
		end
	end)
	box:SetScript("OnMouseDown", function(_, which)
		if MOUSE[which] then Take(MOUSE[which]) end
	end)
	-- (At Daylight UI's scale, as its own boxes; its keys, Escape included, stay its own.)
	ns.Host.Scaled(box, { own = 1 })
	box:Hide()
end

function P.KeyBox(show)
	if show and InCombatLockdown() then
		Say(L["the key can be set out of a fight."])
		return
	end
	if show then
		if not box then BuildBox() end
		box.msg:SetText("")
		BoxLayout()
		-- Takes every key while it's open (Escape included), so none of them does anything else.
		box:EnableKeyboard(true)
		box:SetPropagateKeyboardInput(false)
		-- A controller's buttons too (the game's own key picker takes them the same way).
		if box.EnableGamePadButton then box:EnableGamePadButton(true) end
		box:Show()
	elseif box and box:IsShown() then
		box:Hide()
		if not InCombatLockdown() then
			box:EnableKeyboard(false)
			if box.EnableGamePadButton then box:EnableGamePadButton(false) end
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Editing the slots (out of a fight)
-- ---------------------------------------------------------------------------------------------

local editor, editTiles = nil, {}
local editRing = 1                  -- the ring the editor shows (and "Empty every slot" empties)
local TAB_W, TAB_H, TAB_GAP = 58, 22, 6
local TOP = 112                     -- the title, the tabs with their labels and the label box

-- ---------------------------------------------------------------------------------------------
-- Choosing a slot's action from a list: the way in without dragging (a controller can't drag
-- from the spellbook). Your spells, the items in your bags and on you that can be used, and your
-- macros, a page at a time.
-- ---------------------------------------------------------------------------------------------

-- Daylight UI's controller support through Guide.lua's guarded wrapper (each call does nothing on a
-- Daylight UI without it, or with no Daylight UI).
local Pad = ns.Pad
local picker
local pickSlot, pickKind, pickPage = 1, 1, 1
local PICK_ROWS, PICK_ROW_H, PICK_ICON = 8, 26, 20
local KINDS = { L["Spells"], L["Items"], L["Macros"], L["Mounts"], L["Pets"], L["Pet Actions"] }

local function SpellList()
	local out, seen = {}, {}
	local SB = C_SpellBook
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
	local SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
	if type(SB) ~= "table" or not (SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo
		and SB.GetSpellBookItemType) or not bank then
		return out
	end
	local okN, lines = pcall(SB.GetNumSpellBookSkillLines)
	for line = 1, okN and type(lines) == "number" and lines or 0 do
		local ok, info = pcall(SB.GetSpellBookSkillLineInfo, line)
		if ok and type(info) == "table" and not info.shouldHide then
			for i = 1, info.numSpellBookItems or 0 do
				local index = (info.itemIndexOffset or 0) + i
				local okT, kind, id = pcall(SB.GetSpellBookItemType, index, bank)
				local passive = false
				if SB.IsSpellBookItemPassive then
					local okP, p = pcall(SB.IsSpellBookItemPassive, index, bank)
					passive = okP and p == true
				end
				if okT and (kind == SPELL or kind == "SPELL") and type(id) == "number" and not passive then
					local name = SpellName(id)
					if name and not seen[name] then
						seen[name] = true
						out[#out + 1] = { action = { kind = "spell", id = id, name = name }, label = name }
					end
				end
			end
		end
	end
	return out
end

-- An item with a use: in the bags, or worn (trinkets and the like).
local function ItemList()
	local out, seen = {}, {}
	local function Add(id, link)
		if type(id) ~= "number" or seen[id] then return end
		local usable = false
		if C_Item and C_Item.GetItemSpell then
			local ok, spell = pcall(C_Item.GetItemSpell, id)
			usable = ok and spell ~= nil
		elseif _G.GetItemSpell then
			local ok, spell = pcall(_G.GetItemSpell, id)
			usable = ok and spell ~= nil
		end
		if not usable then return end
		seen[id] = true
		local name = ItemName(id) or (type(link) == "string" and link:match("%[(.-)%]")) or L["Item"]
		out[#out + 1] = { action = { kind = "item", id = id }, label = name }
	end
	if _G.GetInventoryItemID then
		for slot = 1, 19 do
			local ok, id = pcall(_G.GetInventoryItemID, "player", slot)
			if ok and id then
				local link
				if _G.GetInventoryItemLink then
					local okL, l = pcall(_G.GetInventoryItemLink, "player", slot)
					if okL then link = l end
				end
				Add(id, link)
			end
		end
	end
	if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
		for bag = 0, _G.NUM_BAG_SLOTS or 4 do
			local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
			for slot = 1, okN and type(n) == "number" and n or 0 do
				local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
				if ok and type(info) == "table" then Add(info.itemID, info.hyperlink) end
			end
		end
	end
	return out
end

local function MacroList()
	local out = {}
	if not (_G.GetNumMacros and GetMacroInfo) then return out end
	local okN, account, mine = pcall(_G.GetNumMacros)
	if not okN then return out end
	local first = (type(_G.MAX_ACCOUNT_MACROS) == "number" and _G.MAX_ACCOUNT_MACROS or 120) + 1
	local function Add(i)
		local ok, name = pcall(GetMacroInfo, i)
		if ok and type(name) == "string" and name ~= "" then
			out[#out + 1] = { action = { kind = "macro", name = name }, label = name }
		end
	end
	for i = 1, type(account) == "number" and account or 0 do Add(i) end
	for i = first, first + (type(mine) == "number" and mine or 0) - 1 do Add(i) end
	return out
end

local function ByLabel(a, b) return a.label < b.label end

-- Your mounts (the ones this character can have), a random favorite first.
local function MountList()
	local out = {}
	local MJ = C_MountJournal
	if type(MJ) ~= "table" or not (MJ.GetMountIDs and MJ.GetMountInfoByID) then return out end
	local ok, ids = pcall(MJ.GetMountIDs)
	if ok and type(ids) == "table" then
		for _, id in ipairs(ids) do
			local got, name, _, _, _, _, _, _, _, _, hidden, collected = pcall(MJ.GetMountInfoByID, id)
			if got and type(name) == "string" and collected == true and hidden ~= true then
				out[#out + 1] = { action = { kind = "mount", id = id, name = name }, label = name }
			end
		end
	end
	table.sort(out, ByLabel)
	if #out > 0 then
		table.insert(out, 1, { action = { kind = "mount", id = 0 }, label = (MountInfo(0)) })
	end
	return out
end

-- Your companion pets.
local function PetList()
	local out = {}
	local PJ = C_PetJournal
	if type(PJ) ~= "table" or not PJ.GetOwnedPetIDs then return out end
	local ok, ids = pcall(PJ.GetOwnedPetIDs)
	if ok and type(ids) == "table" then
		for _, guid in ipairs(ids) do
			local name = PetInfo(guid)
			if name then out[#out + 1] = { action = { kind = "pet", id = guid, name = name }, label = name } end
		end
	end
	table.sort(out, ByLabel)
	return out
end

-- Your hunter pet's or demon's commands and abilities: what's on its bar, then the rest of its
-- spellbook. Only while it's out.
local function PetActionList()
	local out, seen = {}, {}
	if not UnitExists("pet") then return out end
	if GetPetActionInfo then
		for i = 1, NUM_PET_ACTION_SLOTS or 10 do
			local name, icon, isToken, _, _, _, spellID = GetPetActionInfo(i)
			if Safe(name) and type(name) == "string" and name ~= "" then
				if Safe(isToken) and isToken then
					local word = _G[name]
					if type(word) == "string" then
						out[#out + 1] = { action = { kind = "petcmd", token = name, slot = i, name = word,
							icon = Safe(icon) and icon or nil }, label = word }
					end
				elseif Safe(spellID) and type(spellID) == "number" and not seen[name] then
					seen[name] = true
					out[#out + 1] = { action = { kind = "petspell", id = spellID, name = name }, label = name }
				end
			end
		end
	end
	local SB = C_SpellBook
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
	if type(SB) == "table" and bank and SB.HasPetSpells and SB.GetSpellBookItemType then
		local ok, n = pcall(SB.HasPetSpells)
		for i = 1, ok and type(n) == "number" and n or 0 do
			local okT, _, id, spellID = pcall(SB.GetSpellBookItemType, i, bank)
			local passive = false
			if SB.IsSpellBookItemPassive then
				local okP, p = pcall(SB.IsSpellBookItemPassive, i, bank)
				passive = okP and p == true
			end
			-- (A pet's spell IDs carry a flag in their high bits: the plain ID is what's below it.)
			if okT and type(id) == "number" and not passive then
				id = type(spellID) == "number" and spellID or id % 0x1000000
				local name = SpellName(id)
				if name and not seen[name] then
					seen[name] = true
					out[#out + 1] = { action = { kind = "petspell", id = id, name = name }, label = name }
				end
			end
		end
	end
	return out
end

local LISTS = { SpellList, ItemList, MacroList, MountList, PetList, PetActionList }

local function PickLayout()
	local list = picker.list or {}
	local pages = math.max(1, math.ceil(#list / PICK_ROWS))
	pickPage = math.max(1, math.min(pickPage, pages))
	picker.head:SetText(L["Choose for Slot %d"]:format(pickSlot))
	-- The tabs, as wide as their words, the one shown lit in the accent.
	local ar, ag, ab = Accent()
	local x = 10
	for i, tab in ipairs(picker.tabs) do
		local w = math.max(TAB_W, math.ceil(ns.TextWidth(tab.word) or 0) + 20)
		tab:SetSize(w, TAB_H)
		tab:ClearAllPoints()
		tab:SetPoint("TOPLEFT", picker, "TOPLEFT", x, -38)
		tab.line:SetColorTexture(ar, ag, ab, i == pickKind and 1 or 0.45)
		tab.line:SetHeight(i == pickKind and 3 or 1)
		ns.Ink(tab.word, i == pickKind and "VALUE" or "LABEL")
		x = x + w + TAB_GAP
	end
	local width = math.max(280, x - TAB_GAP + 10, math.ceil(ns.TextWidth(picker.head) or 0) + 60)
	-- The rows: as wide as the longest name on the page (nothing cut short).
	for i, row in ipairs(picker.rows) do
		local entry = list[(pickPage - 1) * PICK_ROWS + i]
		row.entry = entry
		if entry then
			row.icon:SetTexture(Texture(entry.action))
			row.text:SetText(entry.label)
			width = math.max(width, math.ceil(ns.TextWidth(row.text) or 0) + PICK_ICON + 36)
			row:Show()
		else
			row:Hide()
		end
	end
	picker.empty:SetShown(#list == 0)
	picker.page:SetText(L["Page %d of %d"]:format(pickPage, pages))
	picker.prev:SetShown(pickPage > 1)
	picker.next:SetShown(pickPage < pages)
	width = math.max(width, (picker.prev:GetWidth() or 0) + (picker.next:GetWidth() or 0)
		+ math.ceil(ns.TextWidth(picker.page) or 0) + 48)
	picker:SetSize(width, 38 + TAB_H + 12 + PICK_ROWS * PICK_ROW_H + 12 + 24 + 12)
	ns.SkinWindow(picker, nil, KEY)
	if Pad then
		pcall(Pad.Rescan, picker)
		pcall(Pad.Settle, picker.rows[1]:IsShown() and picker.rows[1] or picker.tabs[pickKind])
	end
end

local function PickKind(k)
	pickKind, pickPage = k, 1
	picker.list = LISTS[k]()
	PickLayout()
end

local function BuildPicker()
	picker = CreateFrame("Frame", "DaylightEssentialsHaloPicker", UIParent)
	picker:SetFrameStrata("FULLSCREEN_DIALOG")
	picker:SetToplevel(true)
	picker:SetClampedToScreen(true)
	picker:EnableMouse(true)
	picker.head = API.Text(picker, "head", "LEFT")
	picker.head:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -10)
	-- (Its inks follow the look: Host.Ink paints them again on every look change.)
	ns.Host.Ink(picker.head, "TITLE")
	local close = API.Close(picker, function() P.Pick(false) end)
	if close then close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -6, -6) end
	picker.tabs = {}
	for i, word in ipairs(KINDS) do
		local tab = CreateFrame("Button", nil, picker)
		tab.word = API.Text(tab, "body", "CENTER")
		tab.word:SetPoint("CENTER", tab, "CENTER", 0, 1)
		tab.word:SetText(word)
		tab.line = tab:CreateTexture(nil, "ARTWORK")
		tab.line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
		tab.line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
		tab:SetScript("OnClick", function() PickKind(i) end)
		picker.tabs[i] = tab
	end
	picker.rows = {}
	local top = 38 + TAB_H + 12
	for i = 1, PICK_ROWS do
		local row = CreateFrame("Button", nil, picker)
		row:SetHeight(PICK_ROW_H)
		row:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -(top + (i - 1) * PICK_ROW_H))
		row:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -10, -(top + (i - 1) * PICK_ROW_H))
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(PICK_ICON, PICK_ICON)
		row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.text = API.Text(row, "body", "LEFT")
		row.text:SetWordWrap(false)
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
		ns.Host.Ink(row.text, "VALUE")
		row.lit = row:CreateTexture(nil, "BACKGROUND")
		row.lit:SetAllPoints(row)
		row.lit:SetColorTexture(1, 1, 1, 0)
		row:SetScript("OnEnter", function(self)
			local r, g, b = Accent()
			self.lit:SetColorTexture(r, g, b, 0.18)
			local a = self.entry and self.entry.action
			if not a then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			-- (A mount's or a companion pet's own tooltip, where the game has one; else its name.)
			local own = false
			if (a.kind == "spell" or a.kind == "petspell") and GameTooltip.SetSpellByID then
				GameTooltip:SetSpellByID(a.id)
				own = true
			elseif a.kind == "item" and GameTooltip.SetItemByID then
				GameTooltip:SetItemByID(a.id)
				own = true
			elseif a.kind == "mount" and GameTooltip.SetMountBySpellID then
				local spell = select(5, MountInfo(a.id))
				own = spell ~= nil and pcall(GameTooltip.SetMountBySpellID, GameTooltip, spell)
			elseif a.kind == "pet" and GameTooltip.SetCompanionPet then
				own = pcall(GameTooltip.SetCompanionPet, GameTooltip, a.id)
			end
			if not own then GameTooltip:SetText(self.entry.label) end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function(self)
			self.lit:SetColorTexture(1, 1, 1, 0)
			GameTooltip:Hide()
		end)
		row:SetScript("OnClick", function(self)
			if not self.entry or InCombatLockdown() then return end
			Slots(editRing)[pickSlot] = self.entry.action
			P.Pick(false)
			P.Changed()
			if Pad then pcall(Pad.Settle, editTiles[pickSlot]) end
		end)
		picker.rows[i] = row
	end
	picker.empty = API.Text(picker, "body", "CENTER")
	picker.empty:SetPoint("TOP", picker, "TOP", 0, -(top + PICK_ROW_H))
	picker.empty:SetText(L["Nothing to choose here yet."])
	ns.Host.Ink(picker.empty, "OFF")
	picker.prev = API.Button(picker, L["Previous Page"], 24)
	picker.next = API.Button(picker, L["Next Page"], 24)
	for _, b in ipairs({ picker.prev, picker.next }) do
		local fs = b.text or (b.GetFontString and b:GetFontString())
		b:SetWidth(math.max(90, math.ceil(ns.TextWidth(fs) or 60) + 28))
	end
	picker.prev:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 10, 12)
	picker.next:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -10, 12)
	picker.prev:SetScript("OnClick", function()
		pickPage = pickPage - 1
		PickLayout()
	end)
	picker.next:SetScript("OnClick", function()
		pickPage = pickPage + 1
		PickLayout()
	end)
	picker.page = API.Text(picker, "small", "CENTER")
	picker.page:SetPoint("BOTTOM", picker, "BOTTOM", 0, 18)
	ns.Host.Ink(picker.page, "LABEL")
	picker:Hide()
	-- On a controller: the D-pad moves through it, LB / RB step its tabs, B closes it.
	if Pad and type(Pad.Follow) == "function" then
		picker.padTabs = function() return picker.tabs, pickKind end
		picker.padFirst = function()
			return picker.rows[1]:IsShown() and picker.rows[1] or picker.tabs[pickKind]
		end
	end
	-- Escape, B on a controller (the fields above), the open / close sounds and fade (Host.Window:
	-- Daylight UI's window feel with it), and Daylight UI's scale, as the editor it sits beside.
	ns.Host.Window(picker, { close = function() P.Pick(false) end })
	ns.Host.Scaled(picker, { own = 1 })
end

-- Opens the list for one slot of the Halo the editor shows (out of a fight), or closes it.
function P.Pick(show, slot)
	if show then
		if InCombatLockdown() or not editor then return end
		if not picker then BuildPicker() end
		pickSlot = slot or 1
		picker:ClearAllPoints()
		picker:SetPoint("TOPLEFT", editor, "TOPRIGHT", 8, 0)
		PickKind(pickKind)
		picker:Show()
		picker:Raise()
	elseif picker and picker:IsShown() then
		picker:Hide()
	end
end

-- The tabs: each ring's name with its color under it, the one shown lit, the ones that are off
-- dimmed; each ring's label under its tab. As wide as their words: nothing is cut short.
local function LayoutTabs()
	local x = 10
	for r, tab in ipairs(editor.tabs) do
		local cr, cg, cb = RingColor(r)
		tab.lab:SetText(RingLabel(r) or "")
		tab.lab:SetTextColor(cr, cg, cb)
		local w = math.max(TAB_W, math.ceil(ns.TextWidth(tab.lab) or 0) + 8,
			math.ceil(ns.TextWidth(tab.word) or 0) + 20)
		tab:SetSize(w, TAB_H)
		tab:ClearAllPoints()
		tab:SetPoint("TOPLEFT", editor, "TOPLEFT", x, -38)
		tab.line:SetColorTexture(cr, cg, cb, r == editRing and 1 or 0.45)
		tab.line:SetHeight(r == editRing and 3 or 1)
		ns.Ink(tab.word, r == editRing and "VALUE" or "LABEL")
		tab:SetAlpha((r == 1 or G(RINGS[r].key) == true) and 1 or 0.45)
		x = x + w + TAB_GAP
	end
	return x - TAB_GAP + 10
end

local function EditLayout()
	if not editor then return end
	local slots, count = Slots(editRing), math.min(MAX, G("count") or 8)
	local icon, radius = math.max(36, G("iconSize") or 36), math.max(90, G("radius") or 90)
	local size = (radius + icon) * 2 + 20
	local tabsW = LayoutTabs()
	if editRing == 1 or G(RINGS[editRing].key) == true then
		if PadUI() then
			-- A controller can't drag: A chooses from the list, Y empties.
			editor.hint:SetText(L["%s on a slot chooses its action, %s empties it."]:format(
				Glyph(StepKey({ "GAMEPAD_FACE_BOTTOM", "PAD1" })), Glyph(StepKey({ "GAMEPAD_FACE_TOP", "PAD4" }))))
		else
			editor.hint:SetText(L["Drag in spells, items, macros, mounts or pets. Right-click to empty."])
		end
	else
		editor.hint:SetText(L["%s is off: turn it on on Halo's page to use it."]:format(RINGS[editRing].name))
	end
	local need = math.ceil(ns.TextWidth(editor.hint) or 0) + 24
	editor:SetSize(math.max(size, tabsW, need), size + TOP - 8 + 10)
	ns.SkinWindow(editor, nil, KEY)
	editor.title:SetText(RINGS[editRing].name)
	if not editor.label:HasFocus() then editor.label:SetText(RingLabel(editRing) or "") end
	local cy = (-TOP + 10) / 2
	for i = 1, MAX do
		local t = editTiles[i]
		if i <= count then
			if not t then
				t = CreateFrame("Button", nil, editor)
				t.art = t:CreateTexture(nil, "ARTWORK")
				t.art:SetPoint("TOPLEFT", t, "TOPLEFT", 2, -2)
				t.art:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2)
				t.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				t.num = API.Text(t, "small", "CENTER")
				t.num:SetPoint("CENTER", t, "CENTER", 0, 0)
				t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				t.slot = i
				local function Drop(self)
					local a = FromCursor()
					if not a then return end
					Slots(editRing)[self.slot] = a
					ClearCursor()
					P.Changed()
				end
				t:SetScript("OnReceiveDrag", Drop)
				t:SetScript("OnClick", function(self, which)
					if which == "RightButton" then
						Slots(editRing)[self.slot] = nil
						P.Changed()
					elseif FromCursor() then
						Drop(self)
					else
						-- Nothing on the mouse (or a controller's A): choose from a list.
						P.Pick(true, self.slot)
					end
				end)
				t:SetScript("OnEnter", function(self)
					local a = Slots(editRing)[self.slot]
					ns.Host.Tip(self, a and Label(a) or L["Slot %d"]:format(self.slot),
						a and L["Right-click to empty it. Drop something else to swap it."]
						or L["Drag a spell, item, macro, mount or pet here."], L["Click to choose from a list."])
				end)
				t:SetScript("OnLeave", function() GameTooltip:Hide() end)
				editTiles[i] = t
			end
			local a = slots[i]
			t:SetSize(icon, icon)
			local rad = math.rad(90 - (i - 1) * 360 / count)
			t:ClearAllPoints()
			t:SetPoint("CENTER", editor, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius + cy)
			API.Skin(t, { noBevel = true, borderPx = 2, bgAlpha = 0.85 })
			if a then
				t.art:SetTexture(Texture(a))
				t.art:Show()
				t.num:SetText("")
			else
				t.art:Hide()
				t.num:SetText(i)
				ns.Ink(t.num, "OFF")
			end
			t:Show()
		elseif t then
			t:Hide()
		end
	end
	-- (On a controller: the D-pad finds the slots shown now.)
	if Pad then pcall(Pad.Rescan, editor) end
end

local function BuildEditor()
	editor = CreateFrame("Frame", "DaylightEssentialsHaloEditor", UIParent)
	-- (Above DaylightUI's options window, where it's opened from.)
	editor:SetFrameStrata("FULLSCREEN_DIALOG")
	editor:SetToplevel(true)
	editor:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	editor:SetClampedToScreen(true)
	editor:EnableMouse(true)
	editor:SetMovable(true)
	editor:RegisterForDrag("LeftButton")
	editor:SetScript("OnDragStart", editor.StartMoving)
	editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
	local head = API.Text(editor, "head", "LEFT")
	head:SetPoint("TOPLEFT", editor, "TOPLEFT", 10, -10)
	ns.Ink(head, "TITLE")
	editor.title = head
	-- A tab per ring: our own plain buttons (the words and color line are ours to paint).
	editor.tabs = {}
	for r, def in ipairs(RINGS) do
		local tab = CreateFrame("Button", nil, editor)
		tab.ring = r
		tab.word = API.Text(tab, "body", "CENTER")
		tab.word:SetPoint("CENTER", tab, "CENTER", 0, 1)
		tab.word:SetText(def.label)
		tab.line = tab:CreateTexture(nil, "ARTWORK")
		tab.line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
		tab.line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
		tab.lab = API.Text(tab, "small", "CENTER")
		tab.lab:SetWordWrap(false)
		tab.lab:SetPoint("TOP", tab, "BOTTOM", 0, -3)
		tab:SetScript("OnClick", function(self)
			editRing = self.ring
			P.Pick(false)
			if editor.label:HasFocus() then editor.label:ClearFocus() end
			editor.label:SetText(RingLabel(editRing) or "")
			EditLayout()
		end)
		tab:SetScript("OnEnter", function(self)
			local text
			if r == 1 then
				text = L["Opens with Halo's key on its own."]
			elseif G(def.key) == true then
				text = L["Opens with %s held with Halo's key."]:format(def.label)
			else
				text = L["Off: turn on %s on Halo's page to use it. You can fill it now."]:format(def.name)
			end
			ns.Host.Tip(self, def.name, text, nil, "ANCHOR_TOP")
		end)
		tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
		editor.tabs[r] = tab
	end
	-- The label of the ring shown: up to 16 letters, saved as you type (empty: no label).
	editor.label = API.Input(editor, { hint = L["This Halo's label (up to 16 letters)"], maxLetters = LABEL_MAX,
		onChange = function(text, user)
			if not user then return end
			SetRingLabel(editRing, text)
			-- (The whole editor: a longer label widens its tab, and the window with it.)
			EditLayout()
		end })
	editor.label:SetMaxLetters(LABEL_MAX)
	editor.label:SetPoint("TOPLEFT", editor, "TOPLEFT", 10, -(38 + TAB_H + 22))
	editor.label:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -10, -(38 + TAB_H + 22))
	local hint = API.Text(editor, "small", "CENTER")
	hint:SetPoint("BOTTOM", editor, "BOTTOM", 0, 10)
	ns.Ink(hint, "LABEL")
	editor.hint = hint
	local close = API.Close(editor, function() P.Edit(false) end)
	if close then close:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -6, -6) end
	editor:Hide()
	-- On a controller (Daylight UI's Pad): the D-pad moves through the tabs and slots, A on a
	-- slot chooses from the list, Y empties it, LB / RB step the Halos, B closes.
	if Pad and type(Pad.Follow) == "function" then
		local function IsSlot(stop)
			return type(stop) == "table" and stop.slot ~= nil and editTiles[stop.slot] == stop
		end
		editor.padTabs = function() return editor.tabs, editRing end
		editor.padFirst = function() return editTiles[1] end
		editor.padSelect = function(stop)
			if IsSlot(stop) then return L["Choose"] end
		end
		editor.padKeys = {
			{ key = "Y", follow = true, label = L["Empty Slot"],
			  when = function(stop) return IsSlot(stop) and Slots(editRing)[stop.slot] ~= nil end,
			  run = function(stop)
				if InCombatLockdown() or not IsSlot(stop) then return end
				Slots(editRing)[stop.slot] = nil
				P.Changed()
			  end },
		}
	end
	-- Escape and B close it, with the open / close sounds and fade (Host.Window: Daylight UI's window
	-- feel with it), at Daylight UI's scale (it floats free).
	ns.Host.Window(editor, { close = function() P.Edit(false) end })
	ns.Host.Scaled(editor, { own = 1 })
end

function P.Edit(show)
	if show and InCombatLockdown() then
		Say(L["the slots can be edited out of a fight."])
		return
	end
	if show then
		if not editor then BuildEditor() end
		EditLayout()
		editor:Show()
		editor:Raise()
	elseif editor then
		P.Pick(false)
		if editor.label:HasFocus() then editor.label:ClearFocus() end
		editor:Hide()
	end
end

-- Slots changed: written onto the buttons, and the keys bound again (a modifier's key is only
-- bound while its Halo has something in it).
function P.Changed()
	if editor and editor:IsShown() then EditLayout() end
	Apply()
	ApplyKeys()
end

-- Empties one ring (the one the editor shows unless another is named); the other rings and the
-- labels stay.
function P.Clear(r)
	if InCombatLockdown() then
		Say(L["the slots can be emptied out of a fight."])
		return
	end
	r = r or editRing
	local slots = Slots(r)
	for i = 1, MAX do slots[i] = nil end
	P.Changed()
	Say(L["the %s is empty."]:format(RINGS[r].name))
end

-- /halo check: what reaches Halo now, said in chat and kept in DaylightEssentialsDB.haloCheck
-- (read after a /reload): Halo's own key and each modifier's variant (what the game would do with
-- it), whether each Halo is on, its slots and what the secure button knows of it.
function P.Check()
	local lines = {}
	local function add(t) lines[#lines + 1] = t Say(t) end
	local key = G("key")
	add(("on=%s key=%s"):format(tostring(G("enabled")), tostring(key)))
	for r = 1, #RINGS do
		local game = { GetBindingKey and GetBindingKey("CLICK " .. ButtonName(r) .. ":LeftButton") }
		local filled = 0
		for i = 1, MAX do if type(Slots(r)[i]) == "table" then filled = filled + 1 end end
		add(("%s: setting=%s on=%s filled=%d button n=%s, Key Bindings: %s"):format(RINGS[r].label,
			tostring(RINGS[r].key and G(RINGS[r].key)), tostring(RingOn(r)), filled,
			tostring(buttons[r] and buttons[r]:GetAttribute("n")), #game > 0 and table.concat(game, ", ") or "none"))
	end
	if type(key) == "string" and key ~= "" then
		for _, chord in ipairs(CHORDS) do
			local action = GetBindingAction and GetBindingAction(chord .. key, true)
			add(("%s%s -> %s"):format(chord, key, (action and action ~= "") and action or "(nothing)"))
		end
	end
	add(("combat=%s pending=%s keysPending=%s owner=%s"):format(tostring(InCombatLockdown()), tostring(pending),
		tostring(keysPending), tostring(ring and ring:GetAttribute("owner"))))
	local db = _G.DaylightEssentialsDB
	if type(db) == "table" then db.haloCheck = lines end
end

local function Command(rest)
	local word, what = (type(rest) == "string" and rest or ""):lower():match("^%s*(%S*)%s*(%S*)")
	word = word or ""
	if word == "" or word == "edit" then
		P.Edit(true)
	elseif word == "key" then
		P.KeyBox(true)
	elseif word == "check" then
		P.Check()
	elseif word == "clear" then
		local r = 1
		for i = 2, #RINGS do
			if what == RINGS[i].key then r = i end
		end
		P.Clear(r)
	else
		Say(L["/halo edit: drag your actions onto its slots. /halo key: set its key. /halo clear [shift|alt|ctrl]: empty a Halo. /halo check: what reaches Halo now."])
	end
end

-- ---------------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------------

-- The key binding's words (Key Bindings, AddOns).
_G.BINDING_HEADER_DAYLIGHTESSENTIALS = _G.BINDING_HEADER_DAYLIGHTESSENTIALS or "Glowey's Essentials"
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton:LeftButton"] = L["Halo: Hold to Open It"]
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton2:LeftButton"] = L["Halo: Shift Halo"]
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton3:LeftButton"] = L["Halo: Alt Halo"]
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton4:LeftButton"] = L["Halo: Ctrl Halo"]

local events
local applyQueued = false
local PAD_EVENTS = { INPUT_DEVICE_INTERFACE_TRANSITION = true, UPDATE_BINDINGS = true, CVAR_UPDATE = true,
	GAME_PAD_CONNECTED = true, GAME_PAD_DISCONNECTED = true }
function P.Login()
	Build()
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", function(_, event)
		if PAD_EVENTS[event] then
			-- Controller mode, the bindings or the controller's Shift / Ctrl / Alt buttons changed:
			-- laid out again only if that changes the layout or the stepping keys (Halo's own
			-- bindings fire this too, every time one opens).
			if PadSig() == lastSig then return end
			lastSig = nil
		end
		if event == "PLAYER_REGEN_DISABLED" then
			if editor and editor:IsShown() then P.Edit(false) end
			P.KeyBox(false)
		elseif event == "PLAYER_REGEN_ENABLED" then
			if pending then Apply() end
			if keysPending then ApplyKeys() end
			if box and not box:IsShown() then
				box:EnableKeyboard(false)
				if box.EnableGamePadButton then box:EnableGamePadButton(false) end
			end
		elseif not applyQueued then
			-- Spells learned (a new rank's name and icon), macros changed: once, after the burst.
			applyQueued = true
			C_Timer.After(0.2, function()
				applyQueued = false
				Apply()
			end)
		end
	end)
	for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "UPDATE_MACROS" }) do
		pcall(events.RegisterEvent, events, e)
	end
	for e in pairs(PAD_EVENTS) do pcall(events.RegisterEvent, events, e) end
	ns.me.RegisterCommand("halo", Command, L["halo edit|key|clear|check: your Halos of actions"])
	-- Its own command too, with no "/dui" in front (the /dui one stays for macros made before).
	_G.SLASH_GLOWEYHALO1 = "/halo"
	_G.SlashCmdList.GLOWEYHALO = function(msg) Command(msg or "") end
	Apply()
	ApplyKeys()
end

function P.Setting()
	if not ring then return end
	Apply()
	ApplyKeys()
	if editor and editor:IsShown() then EditLayout() end
	if box and box:IsShown() then BoxLayout() end
end

function P.Style()
	if not ring then return end
	lastLit = false
	reskin = true
	ns.Ink(center, "TITLE")
	Apply()
	if editor and editor:IsShown() then EditLayout() end
	if picker and picker:IsShown() then PickLayout() end   -- (its tab lines in the new accent)
end
