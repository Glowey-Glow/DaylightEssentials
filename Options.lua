-- Glowey's Essentials' place in DaylightUI's options: one section under Plugins, a page per part,
-- each part's settings under its own key. Loaded last, once every part has said what it has.

local ADDON, ns = ...
if ns.off then return end

local L = ns.L

-- Window opacity, on the page of each part that shows a box (ns.SkinWindow): "Use DaylightUI's
-- opacity" and its own opacity, in the page's Look group (or a Window group of their own).
local WINDOWED = { combatTimer = true, healerMana = true, enemyNearby = true, stats = true,
	buffManners = true, halo = true }

-- (Without Daylight UI, Host.lua, both are left out: the boxes take the Glowey window opacity.)
local function NoDaylight() return ns.standalone == true end
local function OpacityItems(key)
	return {
		{ type = "toggle", key = key .. ".duiOpacity", label = L["Use Daylight UI's Opacity"], hidden = NoDaylight,
		  desc = L["Its background follows Daylight UI's window opacity."] },
		{ type = "slider", key = key .. ".opacity", label = L["Window Opacity"], min = 0.1, max = 1, step = 0.05, unit = "%",
		  desc = L["How solid its background is, with Daylight UI's opacity off."], hidden = NoDaylight,
		  disabled = function(get) return get(key .. ".duiOpacity") ~= false end },
	}
end

for _, part in ipairs(ns.parts) do
	if WINDOWED[part.key] and part.page and part.page.groups then
		part.defaults = part.defaults or {}
		if part.defaults.duiOpacity == nil then part.defaults.duiOpacity = true end
		if part.defaults.opacity == nil then part.defaults.opacity = 0.85 end
		local group
		for _, g in ipairs(part.page.groups) do
			if g.label == L["Look"] and type(g.items) == "table" then group = g end
		end
		if not group then
			group = { label = L["Window"], items = {} }
			part.page.groups[#part.page.groups + 1] = group
		end
		for _, item in ipairs(OpacityItems(part.key)) do group.items[#group.items + 1] = item end
	end
end

-- 1.2.0 had one opacity for every box (a Look page): a player who set their own has it moved to
-- each part, once.
ns.me.On("Login", function()
	local db = _G.DaylightEssentialsDB
	if type(db) ~= "table" then
		db = {}
		_G.DaylightEssentialsDB = db
	end
	if db.opacityMoved then return end
	db.opacityMoved = true
	local ok, old = pcall(ns.API.GetSetting, ADDON, "look.duiOpacity")
	if not ok or old ~= false then return end
	local _, value = pcall(ns.API.GetSetting, ADDON, "look.opacity")
	for key in pairs(WINDOWED) do
		pcall(ns.DUI.Set, ns.DUI, ADDON, key .. ".duiOpacity", false)
		if type(value) == "number" then pcall(ns.DUI.Set, ns.DUI, ADDON, key .. ".opacity", value) end
	end
end)

-- "Move Window" on the page of each part with a frame of its own to place (its mover): frames
-- unlocked to drag, from the page itself (Host.SetUnlocked: Daylight UI's /dui unlock with it, the
-- Glowey unlock without). A second press locks them again. In the page's first group, after its
-- On switch.
local MOVABLE = { combatTimer = true, healerMana = true, enemyNearby = true, stats = true,
	buffManners = true, combatAlert = true, petReminder = true, sealReminder = true }

local function Unlocked()
	local H = ns.Host
	return H and H.Unlocked and H.Unlocked() == true or false
end

local function MoveItem()
	return { type = "button", label = L["Move Window"],
		textFn = function() return Unlocked() and L["Lock Windows"] or L["Move Window"] end,
		desc = L["Shows a handle on each window you can move: drag it, or right-click it to put it back. Press again (or use the lock button) when done."],
		func = function()
			local H = ns.Host
			if H and H.SetUnlocked then H.SetUnlocked(not Unlocked()) end
		end }
end

for _, part in ipairs(ns.parts) do
	local g = MOVABLE[part.key] and part.page and part.page.groups and part.page.groups[1]
	if g and type(g.items) == "table" then
		local at = #g.items + 1
		for i, item in ipairs(g.items) do
			if item.type == "toggle" and item.key == part.key .. ".enabled" then at = i + 1 break end
		end
		table.insert(g.items, at, MoveItem())
	end
end

local pages = {}
for _, part in ipairs(ns.parts) do
	ns.defaults[part.key] = part.defaults or {}
	-- (A part that lives on Daylight UI's own frames has no page without it.)
	if part.page and not (part.daylightOnly and ns.standalone) then pages[#pages + 1] = part.page end
end
-- (The page the welcome's Open Options shows: EssentialsGuide.lua.)
ns.firstPage = pages[1] and pages[1].id

-- The "Tell Me When a Newer Version Is Out" switch (Update.lua), on the first page.
if ns.UpdateGroup and pages[1] then table.insert(pages[1].groups, ns.UpdateGroup()) end

local ok, err = pcall(function()
	-- (With Daylight UI and another of Glowey's plugins on, its pages go under one "Glowey's" entry
	-- on the options rail: Hub.lua.)
	local spec = { addon = ADDON, dui = ns.DUI,
		plugin = {
			title = "Glowey's Essentials",
			icon = "Interface\\AddOns\\" .. ADDON .. "\\Media\\icon-glyph.png",
			needs = { 1, 1 },
			short = L["Essentials"],
			color = { 0.45, 0.6, 1 },
			blurb = L["Healer mana, a combat timer and alert, a pet reminder, cursor cooldowns, enemies nearby, your secondary stats, Buff Manners, Halo and Nameplate Dmg Text."],
		},
		module = { plugin = ADDON, label = L["Essentials"], defaults = ns.defaults, options = { pages = pages } },
		words = { open = L["Open"], pages = L["Its settings, a page each."] },
		hubIcon = "Interface\\AddOns\\" .. ADDON .. "\\Media\\glowey-hub.png",
		hubBlurb = L["Glowey's plugins, in one place."],
		hubDesc = L["Glowey's plugins, in one place."],
	}
	if ns.Hub then ns.Hub.Join(spec) else
		ns.DUI:RegisterPlugin(ADDON, spec.plugin)
		ns.DUI:RegisterModule(ADDON, spec.module)
	end
end)
if not ok then geterrorhandler()(err) end
