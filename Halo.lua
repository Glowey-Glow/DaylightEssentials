-- Halo: hold a key and a ring of your own actions opens around the mouse (or in the middle of the
-- screen). Point toward one, or scroll to it, and let go of the key: it fires. Let go with the
-- mouse still in the middle and nothing happens. Spells, items and macros each take a slot: open
-- "Edit the slots" (its page, or /dui halo edit) and drag them in from your spellbook, bags or
-- macros; right-click a slot to empty it. The slots are kept per character. The ring's shape,
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
	shape = "ring",
	opens = "cursor",
	radius = 90,
	iconSize = 36,
	names = true,
	dim = true,
}

P.page = { id = KEY, label = L["Halo"],
	desc = L["Hold a key for a Halo of your actions; point, let go, and it fires."],
	groups = {
		{ label = L["Halo"],
		  desc = L["Set its key here (Set Key), or bind it under Key Bindings, AddOns, Daylight Essentials (Halo). Hold it, point toward an action or scroll to it, and let go to use it. Let go in the middle to close it without using anything."],
		  items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "button", label = L["Set Key"],
			  desc = L["Opens a small box: press the key you want (a mouse's middle or side button works too), Escape to cancel, or Clear to take it off. Shift, Alt and Ctrl are added by themselves for the Halos below."],
			  func = function() P.KeyBox(true) end },
			{ type = "button", label = L["Edit Halos"],
			  desc = L["Drag spells, items or macros onto the slots; right-click one to empty it. Each Halo has its tab, and a label you can type there. Kept for this character. Also /dui halo edit. (A macro on a Shift, Alt or Ctrl Halo sees that key held: [mod:shift] and the like always match there.)"],
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
			{ type = "toggle", key = KEY .. ".baseAccent", label = L["Base Halo in my accent"],
			  desc = L["The base Halo follows your DaylightUI accent color."] },
			{ type = "color", key = KEY .. ".colorBase", label = L["Base Halo"],
			  disabled = function(get) return get(KEY .. ".baseAccent") ~= false end },
			{ type = "color", key = KEY .. ".colorShift", label = L["Shift Halo"] },
			{ type = "color", key = KEY .. ".colorAlt", label = L["Alt Halo"] },
			{ type = "color", key = KEY .. ".colorCtrl", label = L["Ctrl Halo"] },
		} },
		{ label = L["Look"], items = {
			{ type = "dropdown", key = KEY .. ".shape", label = L["Shape"],
			  values = { ring = L["Circle"], arc = L["Arc"] },
			  desc = L["Circle: all the way around, the first slot at the top. Arc: a half circle over the middle, left to right."] },
			{ type = "dropdown", key = KEY .. ".opens", label = L["Opens"],
			  values = { cursor = L["Around Cursor"], center = L["Screen center"] } },
			{ type = "slider", key = KEY .. ".radius", label = L["Halo size"], min = 50, max = 220, step = 5, unit = "px",
			  desc = L["From the middle of the Halo to the middle of each icon."] },
			{ type = "slider", key = KEY .. ".iconSize", label = L["Icon size"], min = 20, max = 72, step = 1, unit = "px" },
			{ type = "toggle", key = KEY .. ".names", label = L["Name in the middle"],
			  desc = L["The name of the action you point at, in the middle of the Halo."] },
			{ type = "toggle", key = KEY .. ".dim", label = L["Dim what isn't ready"],
			  desc = L["Spells cooling down or out of reach (no mana, no rage) and items you have none of."] },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- The slots: per character, in DaylightEssentialsDB.halo["Name-Realm"]:
--   [i] = action            the base ring (where every slot was kept before there were more rings,
--                           so those stay as they are)
--   shift / alt / ctrl      = { [i] = action }, the modifier rings
--   labels                  = { [ring] = "text" }, each ring's label
-- An action: { kind = "spell", id, name } | { kind = "item", id } | { kind = "macro", name }
-- ---------------------------------------------------------------------------------------------

local function Say(msg) print("|cff73a0ffHalo|r: " .. msg) end

local function Record()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if type(db.halo) ~= "table" then db.halo = {} end
	local me = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
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

local function Texture(a)
	if type(a) ~= "table" then return nil end
	if a.kind == "spell" then
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
	return ""
end

-- What's on the mouse now (picked up from the spellbook, bags or macros), as an action, or nil.
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
for r = 1, #RINGS do
	tiles[r], shownBy[r], anglesBy[r] = {}, {}, {}
end
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

local function Pointed(dx, dy)
	local shown, angles = shownBy[open], anglesBy[open]
	local n = #shown
	if n == 0 then return nil end
	local dead = math.max(14, cIcon * 0.6)
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
		return false
	end
	if holder ~= me then return false end
	ring:SetAttribute("owner", 0)
	if not ring:IsShown() then return false end
	ring:Hide()
	local n = self:GetAttribute("n") or 0
	if n == 0 then return false end
	local k = 0
	if (self:GetAttribute("wheel") or 0) == 1 then
		k = self:GetAttribute("pick") or 0
	else
		local screen = self:GetFrameRef("screen")
		local x, y = screen:GetMousePosition()
		if x and y then
			local dx = x * screen:GetWidth() - (self:GetAttribute("px") or 0)
			local dy = y * screen:GetHeight() - (self:GetAttribute("py") or 0)
			local dead = self:GetAttribute("dead") or 14
			if dx * dx + dy * dy >= dead * dead then
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

local FIELDS = { "spell", "item", "macro" }   -- the secure button's action fields
local reskin = false                           -- a style change: every tile skinned again

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
	ring:SetSize(size, size)
	if G("opens") ~= "cursor" then
		ring:ClearAllPoints()
		ring:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	-- The label sits just over the top of the ring, its own width (never cut short).
	title:ClearAllPoints()
	title:SetPoint("BOTTOM", ring, "CENTER", 0, radius + icon / 2 + 8)
	for r = 1, #RINGS do
		local b = buttons[r]
		local slots, shown, angles, list = Slots(r), shownBy[r], anglesBy[r], tiles[r]
		local on = RingOn(r)
		wipe(shown)
		for i = 1, count do
			if on and type(slots[i]) == "table" then shown[#shown + 1] = i end
		end
		local n = #shown
		Angles(angles, n)
		for k = 1, math.max(n, #list) do
			local t = k <= n and Tile(r, k) or list[k]
			if k <= n then
				local a = slots[shown[k]]
				t.base = icon
				t:SetSize(icon, icon)
				t:ClearAllPoints()
				local rad = math.rad(angles[k])
				t:SetPoint("CENTER", ring, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
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
		b:SetAttribute("dead", math.max(14, icon * 0.6))
		b:SetAttribute("atcursor", G("opens") == "cursor")
		b:SetAttribute("n", n)
		for k = 1, MAX do
			b:SetAttribute("a" .. k, angles[k])
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
				end
			end
			b:SetAttribute("type" .. suffix, kind)
			b:SetAttribute("typerelease" .. suffix, kind)
			for _, f in ipairs(FIELDS) do
				b:SetAttribute(f .. suffix, f == field and value or nil)
			end
		end
	end
	reskin = false
end

-- Every modifier set a key can carry, in the order the game writes them ("ALT-CTRL-SHIFT-").
local CHORDS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-", "ALT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }

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
	if a.kind == "spell" then
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
	else
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
		else
			center:SetText("")
		end
	end
	local now = GetTime()
	if cDim and now >= dimAt then
		dimAt = now + 0.2
		for i = 1, #shown do
			local t = list[i]
			if t and t.action then
				local ready = Ready(t.action)
				t.art:SetDesaturated(not ready)
				t.art:SetAlpha(ready and 1 or 0.45)
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
		b:Hide()   -- (a click binding still reaches a hidden button)
		SecureHandlerSetFrameRef(b, "ring", ring)
		SecureHandlerSetFrameRef(b, "screen", screen)
		SecureHandlerWrapScript(b, "OnClick", b, DOWN_UP)
		SecureHandlerSetFrameRef(ring, "b" .. r, b)
		buttons[r] = b
	end
	-- (The handler first, then wrapped: setting it after would replace the wrapper.)
	SecureHandlerWrapScript(ring, "OnMouseWheel", buttons[1], WHEEL)

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
	ns.SkinWindow(box)
end

local function Take(key)
	if InCombatLockdown() then return end
	if MODIFIERS[key] then
		box.msg:SetText(L["Shift, Alt and Ctrl can't be the key on their own: held with it, they open the other Halos."])
		ns.Ink(box.msg, "WARN")
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
	head:SetText(L["Halo's key"])
	ns.Ink(head, "TITLE")
	box.now = API.Text(box, "body", "LEFT")
	box.now:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -40)
	ns.Ink(box.now, "VALUE")
	box.game = API.Text(box, "small", "LEFT")
	box.game:SetPoint("TOPLEFT", box.now, "BOTTOMLEFT", 0, -6)
	ns.Ink(box.game, "LABEL")
	box.help = API.Text(box, "small", "LEFT")
	box.help:SetPoint("TOPLEFT", box.game, "BOTTOMLEFT", 0, -6)
	box.help:SetText(L["Press the key you want, or click here with the mouse's middle or a side button. Escape cancels."])
	ns.Ink(box.help, "TEXT")
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
	box:SetScript("OnMouseDown", function(_, which)
		if MOUSE[which] then Take(MOUSE[which]) end
	end)
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
		box:Show()
	elseif box and box:IsShown() then
		box:Hide()
		if not InCombatLockdown() then box:EnableKeyboard(false) end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Editing the slots (out of a fight)
-- ---------------------------------------------------------------------------------------------

local editor, editTiles = nil, {}
local editRing = 1                  -- the ring the editor shows (and "Empty every slot" empties)
local TAB_W, TAB_H, TAB_GAP = 58, 22, 6
local TOP = 112                     -- the title, the tabs with their labels and the label box

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
		editor.hint:SetText(L["Drag in spells, items or macros. Right-click to empty."])
	else
		editor.hint:SetText(L["%s is off: turn it on on Halo's page to use it."]:format(RINGS[editRing].name))
	end
	local need = math.ceil(ns.TextWidth(editor.hint) or 0) + 24
	editor:SetSize(math.max(size, tabsW, need), size + TOP - 8 + 10)
	ns.SkinWindow(editor)
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
					else
						Drop(self)
					end
				end)
				t:SetScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					local a = Slots(editRing)[self.slot]
					GameTooltip:SetText(a and Label(a) or L["Slot %d"]:format(self.slot))
					GameTooltip:AddLine(a and L["Right-click to empty it. Drop something else to swap it."]
						or L["Drag a spell, item or macro here."], 1, 1, 1, true)
					GameTooltip:Show()
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
			if editor.label:HasFocus() then editor.label:ClearFocus() end
			editor.label:SetText(RingLabel(editRing) or "")
			EditLayout()
		end)
		tab:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(def.name)
			if r == 1 then
				GameTooltip:AddLine(L["Opens with Halo's key on its own."], 1, 1, 1, true)
			elseif G(def.key) == true then
				GameTooltip:AddLine(L["Opens with %s held with Halo's key."]:format(def.label), 1, 1, 1, true)
			else
				GameTooltip:AddLine(L["Off: turn on %s on Halo's page to use it. You can fill it now."]:format(def.name),
					1, 1, 1, true)
			end
			GameTooltip:Show()
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

-- /dui halo check: what reaches Halo now, said in chat and kept in DaylightEssentialsDB.haloCheck
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
		Say(L["/dui halo edit: drag your actions onto its slots. /dui halo key: set its key. /dui halo clear [shift|alt|ctrl]: empty a Halo. /dui halo check: what reaches Halo now."])
	end
end

-- ---------------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------------

-- The key binding's words (Key Bindings, AddOns).
_G.BINDING_HEADER_DAYLIGHTESSENTIALS = _G.BINDING_HEADER_DAYLIGHTESSENTIALS or "Daylight Essentials"
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton:LeftButton"] = L["Halo: hold to open it"]
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton2:LeftButton"] = L["Halo: Shift Halo"]
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton3:LeftButton"] = L["Halo: Alt Halo"]
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton4:LeftButton"] = L["Halo: Ctrl Halo"]

local events
local applyQueued = false
function P.Login()
	Build()
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			if editor and editor:IsShown() then P.Edit(false) end
			P.KeyBox(false)
		elseif event == "PLAYER_REGEN_ENABLED" then
			if pending then Apply() end
			if keysPending then ApplyKeys() end
			if box and not box:IsShown() then box:EnableKeyboard(false) end
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
	ns.me.RegisterCommand("halo", Command, L["halo edit|key|clear|check: your Halos of actions"])
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
end
