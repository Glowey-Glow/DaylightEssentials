-- Halo: hold a key and a ring of your own actions opens around the mouse (or in the middle of the
-- screen). Point toward one, or scroll to it, and let go of the key: it fires. Let go with the
-- mouse still in the middle and nothing happens. Spells, items and macros each take a slot: open
-- "Edit the slots" (its page, or /dui halo edit) and drag them in from your spellbook, bags or
-- macros; right-click a slot to empty it. The slots are kept per character. The ring's shape,
-- size, icon size, where it opens and how it shows what isn't ready are set on its page.
-- (A ring menu like EllesmereUI's Quickdraw, an idea only: written from scratch, nothing of it
-- read or used.)
--
-- Secure: the game only lets a key press or a click cast, and nothing protected can be changed in
-- a fight. So the key is bound to one secure button (SecureActionButtonTemplate). Its pre-click
-- snippet (SecureHandlerWrapScript) runs in the game's secure sandbox: on the key going down it
-- shows the ring (a protected frame, so it can be shown in a fight) and cancels the click; on the
-- key coming up it works out which slot you point at (or scrolled to) and hands the click on to
-- that slot's action ("type-hN" / "spell-hN" attributes, written out of a fight only). What you
-- see (the highlight, the name, the dimming) is drawn by plain code, which only reads.
--
-- What it costs: nothing until you press the key; while the ring is open, a light update each
-- frame for the highlight and five times a second for the dimming. No timers otherwise.

local _, ns = ...
if ns.off then return end

local API = ns.API
local KEY = "halo"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = "Halo" })

local MAX = 12

P.defaults = {
	enabled = true,
	count = 8,
	shape = "ring",
	opens = "cursor",
	radius = 90,
	iconSize = 36,
	names = true,
	dim = true,
}

P.page = { id = KEY, label = "Halo",
	desc = "Hold a key for a ring of your actions; point, let go, and it fires.",
	groups = {
		{ label = "Halo",
		  desc = "Bind its key under Key Bindings, AddOns, Daylight Essentials (Halo). Hold it, point toward an action or scroll to it, and let go to use it. Let go in the middle to close it without using anything.",
		  items = {
			{ type = "toggle", key = KEY .. ".enabled", label = "On" },
			{ type = "button", label = "Edit the slots",
			  desc = "Drag spells, items or macros onto the slots; right-click one to empty it. Kept for this character. Also /dui halo edit.",
			  func = function() P.Edit(true) end },
			{ type = "slider", key = KEY .. ".count", label = "Slots", min = 2, max = MAX, step = 1,
			  desc = "How many slots there are to fill. Empty ones aren't shown in the ring." },
			{ type = "button", label = "Empty every slot",
			  desc = "Takes everything off this character's ring.",
			  func = function() P.Clear() end },
		} },
		{ label = "Look", items = {
			{ type = "dropdown", key = KEY .. ".shape", label = "Shape",
			  values = { ring = "Ring", arc = "Arc" },
			  desc = "Ring: all the way around, the first slot at the top. Arc: a half circle over the middle, left to right." },
			{ type = "dropdown", key = KEY .. ".opens", label = "Opens",
			  values = { cursor = "At the mouse", center = "Screen center" } },
			{ type = "slider", key = KEY .. ".radius", label = "Ring size", min = 50, max = 220, step = 5, unit = "px",
			  desc = "From the middle of the ring to the middle of each icon." },
			{ type = "slider", key = KEY .. ".iconSize", label = "Icon size", min = 20, max = 72, step = 1, unit = "px" },
			{ type = "toggle", key = KEY .. ".names", label = "Name in the middle",
			  desc = "The name of the action you point at, in the middle of the ring." },
			{ type = "toggle", key = KEY .. ".dim", label = "Dim what isn't ready",
			  desc = "Spells cooling down or out of reach (no mana, no rage) and items you have none of." },
		} },
	} }

-- ---------------------------------------------------------------------------------------------
-- The slots: per character, in DaylightEssentialsDB.halo["Name-Realm"] = { [i] = action }
-- An action: { kind = "spell", id, name } | { kind = "item", id } | { kind = "macro", name }
-- ---------------------------------------------------------------------------------------------

local function Say(msg) print("|cff73a0ffHalo|r: " .. msg) end

local function Slots()
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
	if a.kind == "spell" then return SpellName(a.id) or a.name or "Spell" end
	if a.kind == "item" then return ItemName(a.id) or "Item" end
	if a.kind == "macro" then return a.name or "Macro" end
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

local ring, center, trigger   -- ring: protected frame the snippet shows; trigger: the bound button
local tiles = {}              -- the icons in the ring, one per filled slot shown
local shown = {}              -- shown[k] = the slot number (1..MAX) of the k-th icon
local angles = {}             -- angles[k] = its direction in degrees (0 = right, 90 = up)
local pending = false         -- a change waiting for the end of a fight

local function Accent()
	local r, g, b = API.Accent()
	return r or 1, g or 1, b or 1
end

local function Tile(k)
	local t = tiles[k]
	if t then return t end
	t = CreateFrame("Frame", nil, ring)
	t.art = t:CreateTexture(nil, "ARTWORK")
	t.art:SetPoint("TOPLEFT", t, "TOPLEFT", 2, -2)
	t.art:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2)
	t.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t.lit = t:CreateTexture(nil, "OVERLAY")
	t.lit:SetPoint("TOPLEFT", t, "TOPLEFT", -2, 2)
	t.lit:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 2, -2)
	t.lit:SetColorTexture(1, 1, 1, 0)
	t.lit:SetDrawLayer("BACKGROUND", -1)
	tiles[k] = t
	return t
end

-- Each icon's direction for n icons: Ring from the top, clockwise; Arc from the left over the top.
local function Angles(n)
	wipe(angles)
	local arc = G("shape") == "arc"
	for k = 1, n do
		if arc then
			angles[k] = n == 1 and 90 or (180 - (k - 1) * 180 / (n - 1))
		else
			angles[k] = 90 - (k - 1) * 360 / n
		end
	end
end

-- The ring's frame is bigger than the ring itself, so pointing well past an icon still counts.
local function RingSize()
	local r, s = G("radius") or 90, G("iconSize") or 36
	return math.floor((r + s) * 2 + r)
end

-- Which icon a direction points at (k), or nil in the middle. dx, dy in pixels from the middle.
-- Settings read every frame while the ring is open: kept from the last Apply (which every setting
-- change runs).
local cIcon, cNames, cDim = 36, true, true

local function Pointed(dx, dy)
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

-- The secure snippets. The key going down: open the ring (and cancel the click); coming up: the
-- slot pointed at, or scrolled to, gets the click ("h<slot>"), or nothing does.
local DOWN_UP = [=[
	local ring = self:GetFrameRef("ring")
	if down then
		if self:GetAttribute("atcursor") then
			ring:ClearAllPoints()
			ring:SetPoint("CENTER", "$cursor")
		end
		ring:SetAttribute("pick", 0)
		ring:SetAttribute("wheel", 0)
		ring:Show()
		return false
	end
	if not ring:IsShown() then return false end
	ring:Hide()
	local n = self:GetAttribute("n") or 0
	if n == 0 then return false end
	local k = 0
	if (ring:GetAttribute("wheel") or 0) == 1 then
		k = ring:GetAttribute("pick") or 0
	else
		local x, y = ring:GetMousePosition()
		if x and y then
			local size = self:GetAttribute("size") or 1
			local dx, dy = (x - 0.5) * size, (y - 0.5) * size
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

local WHEEL = [=[
	local n = owner:GetAttribute("n") or 0
	if n == 0 then return end
	local k = (self:GetAttribute("pick") or 0) - (offset > 0 and 1 or -1)
	if k < 1 then k = n elseif k > n then k = 1 end
	self:SetAttribute("pick", k)
	self:SetAttribute("wheel", 1)
]=]

local FIELDS = { "spell", "item", "macro" }   -- the secure button's action fields
local reskin = false                           -- a style change: every tile skinned again

-- Writes the ring's layout and every slot's action onto the secure button. Out of a fight only.
local function Apply()
	if not ring then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local slots = Slots()
	local count = math.min(MAX, G("count") or 8)
	local on = G("enabled") == true
	wipe(shown)
	for i = 1, count do
		if on and type(slots[i]) == "table" then shown[#shown + 1] = i end
	end
	local n = #shown
	Angles(n)
	local size, icon, radius = RingSize(), G("iconSize") or 36, G("radius") or 90
	cIcon, cNames, cDim = icon, G("names") and true or false, G("dim") and true or false
	ring:SetSize(size, size)
	if G("opens") ~= "cursor" then
		ring:ClearAllPoints()
		ring:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	for k = 1, math.max(n, #tiles) do
		local t = k <= n and Tile(k) or tiles[k]
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
	reskin = false
	-- The secure side: how many, their directions, which slot each is, and each slot's action.
	trigger:SetAttribute("n", n)
	trigger:SetAttribute("size", size)
	trigger:SetAttribute("dead", math.max(14, icon * 0.6))
	trigger:SetAttribute("atcursor", G("opens") == "cursor")
	for k = 1, MAX do
		trigger:SetAttribute("a" .. k, angles[k])
		trigger:SetAttribute("s" .. k, shown[k])
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
		trigger:SetAttribute("type" .. suffix, kind)
		trigger:SetAttribute("typerelease" .. suffix, kind)
		for _, f in ipairs(FIELDS) do
			trigger:SetAttribute(f .. suffix, f == field and value or nil)
		end
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

local lastLit, dimAt = nil, 0
local function OnUpdate()
	if #shown == 0 then return end
	-- Which icon is pointed at (or scrolled to): the same rule the secure snippet uses.
	local k
	if ring:GetAttribute("wheel") == 1 then
		k = ring:GetAttribute("pick")
		if k == 0 then k = nil end
	else
		local cx, cy = ring:GetCenter()
		if cx then
			local x, y = GetCursorPosition()
			local s = ring:GetEffectiveScale()
			k = Pointed(x / s - cx, y / s - cy)
		end
	end
	if k ~= lastLit then
		local r, g, b = Accent()
		for i, t in ipairs(tiles) do
			if i == k then
				t.lit:SetColorTexture(r, g, b, 0.9)
				t:SetSize(t.base * 1.12, t.base * 1.12)
			else
				t.lit:SetColorTexture(1, 1, 1, 0)
				t:SetSize(t.base, t.base)
			end
		end
		lastLit = k
		if cNames and k and tiles[k] and tiles[k].action then
			center:SetText(Label(tiles[k].action))
		else
			center:SetText("")
		end
	end
	local now = GetTime()
	if cDim and now >= dimAt then
		dimAt = now + 0.2
		for i = 1, #shown do
			local t = tiles[i]
			if t and t.action then
				local ready = Ready(t.action)
				t.art:SetDesaturated(not ready)
				t.art:SetAlpha(ready and 1 or 0.45)
			end
		end
	end
end

local function OnShow()
	lastLit, dimAt = false, 0
	center:SetText(#shown == 0 and "No actions yet: Edit the slots on Halo's page" or "")
	if not cDim then
		for _, t in ipairs(tiles) do
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
	center = API.Text(ring, "body", "CENTER")
	center:SetPoint("CENTER", ring, "CENTER", 0, 0)
	ns.Ink(center, "TITLE")
	ring:SetScript("OnUpdate", OnUpdate)
	ring:SetScript("OnShow", OnShow)

	-- The bound button. Its click never acts by itself: the snippet cancels the key going down,
	-- and on the key coming up hands the click to a slot ("h3": type-h3, spell-h3...). Both
	-- "type" and "typerelease" are set, so the action fires on release whichever way the game's
	-- "cast on key down" choice is set.
	trigger = CreateFrame("Button", "DaylightEssentialsHaloButton", UIParent,
		"SecureActionButtonTemplate,SecureHandlerBaseTemplate")
	trigger:RegisterForClicks("AnyDown", "AnyUp")
	trigger:SetAttribute("pressAndHoldAction", true)
	trigger:SetAttribute("useOnKeyDown", false)
	trigger:SetAttribute("type", nil)
	trigger:Hide()   -- (a click binding still reaches a hidden button)
	SecureHandlerSetFrameRef(trigger, "ring", ring)
	SecureHandlerWrapScript(trigger, "OnClick", trigger, DOWN_UP)
	-- (The handler first, then wrapped: setting it after would replace the wrapper.)
	ring:SetScript("OnMouseWheel", function() end)
	SecureHandlerWrapScript(ring, "OnMouseWheel", trigger, WHEEL)
end

-- ---------------------------------------------------------------------------------------------
-- Editing the slots (out of a fight)
-- ---------------------------------------------------------------------------------------------

local editor, editTiles = nil, {}

local function EditLayout()
	if not editor then return end
	local slots, count = Slots(), math.min(MAX, G("count") or 8)
	local icon, radius = math.max(36, G("iconSize") or 36), math.max(90, G("radius") or 90)
	local size = (radius + icon) * 2 + 20
	editor:SetSize(size, size + 40)
	API.Skin(editor, { window = true })
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
					Slots()[self.slot] = a
					ClearCursor()
					P.Changed()
				end
				t:SetScript("OnReceiveDrag", Drop)
				t:SetScript("OnClick", function(self, which)
					if which == "RightButton" then
						Slots()[self.slot] = nil
						P.Changed()
					else
						Drop(self)
					end
				end)
				t:SetScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					local a = Slots()[self.slot]
					GameTooltip:SetText(a and Label(a) or ("Slot " .. self.slot))
					GameTooltip:AddLine(a and "Right-click to empty it. Drop something else to swap it."
						or "Drag a spell, item or macro here.", 1, 1, 1, true)
					GameTooltip:Show()
				end)
				t:SetScript("OnLeave", function() GameTooltip:Hide() end)
				editTiles[i] = t
			end
			local a = slots[i]
			t:SetSize(icon, icon)
			local rad = math.rad(90 - (i - 1) * 360 / count)
			t:ClearAllPoints()
			t:SetPoint("CENTER", editor, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius - 14)
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
	editor:SetFrameStrata("DIALOG")
	editor:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	editor:SetClampedToScreen(true)
	editor:EnableMouse(true)
	editor:SetMovable(true)
	editor:RegisterForDrag("LeftButton")
	editor:SetScript("OnDragStart", editor.StartMoving)
	editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
	local title = API.Text(editor, "head", "LEFT")
	title:SetPoint("TOPLEFT", editor, "TOPLEFT", 10, -10)
	title:SetText("Halo slots")
	ns.Ink(title, "TITLE")
	local hint = API.Text(editor, "small", "CENTER")
	hint:SetPoint("BOTTOM", editor, "BOTTOM", 0, 10)
	hint:SetText("Drag in spells, items or macros. Right-click to empty.")
	ns.Ink(hint, "LABEL")
	editor.hint = hint
	local close = API.Close(editor, function() P.Edit(false) end)
	if close then close:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -6, -6) end
	editor:Hide()
end

function P.Edit(open)
	if open and InCombatLockdown() then
		Say("the slots can be edited out of a fight.")
		return
	end
	if open then
		if not editor then BuildEditor() end
		EditLayout()
		-- Never narrower than its hint: nothing is cut short.
		local need = (ns.TextWidth(editor.hint) or 0) + 24
		if editor:GetWidth() < need then editor:SetWidth(need) end
		editor:Show()
	elseif editor then
		editor:Hide()
	end
end

function P.Changed()
	if editor and editor:IsShown() then EditLayout() end
	Apply()
end

function P.Clear()
	if InCombatLockdown() then
		Say("the slots can be emptied out of a fight.")
		return
	end
	wipe(Slots())
	P.Changed()
	Say("every slot is empty.")
end

local function Command(rest)
	local word = string.lower((type(rest) == "string" and rest:match("^%s*(%S*)")) or "")
	if word == "" or word == "edit" then
		P.Edit(true)
	elseif word == "clear" then
		P.Clear()
	else
		Say("/dui halo edit: drag your actions onto its slots. /dui halo clear: empty them all.")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------------

-- The key binding's words (Key Bindings, AddOns).
_G.BINDING_HEADER_DAYLIGHTESSENTIALS = _G.BINDING_HEADER_DAYLIGHTESSENTIALS or "Daylight Essentials"
_G["BINDING_NAME_CLICK DaylightEssentialsHaloButton:LeftButton"] = "Halo: hold to open the ring"

local events
local applyQueued = false
function P.Login()
	Build()
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			if editor and editor:IsShown() then P.Edit(false) end
		elseif event == "PLAYER_REGEN_ENABLED" then
			if pending then Apply() end
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
	ns.me.RegisterCommand("halo", Command, "halo edit|clear: your ring of actions")
	Apply()
end

function P.Setting()
	if not ring then return end
	Apply()
	if editor and editor:IsShown() then EditLayout() end
end

function P.Style()
	if not ring then return end
	lastLit = false
	reskin = true
	ns.Ink(center, "TITLE")
	Apply()
end
