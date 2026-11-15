-- Daylight Essentials' place in DaylightUI's options: one section under Plugins, a page per part,
-- each part's settings under its own key. Loaded last, once every part has said what it has.

local ADDON, ns = ...
if ns.off then return end

local L = ns.L

-- Window opacity, on the page of each part that shows a box (ns.SkinWindow): "Use DaylightUI's
-- opacity" and its own opacity, in the page's Look group (or a Window group of their own).
local WINDOWED = { combatTimer = true, healerMana = true, enemyNearby = true, stats = true,
	buffManners = true, halo = true }

local function OpacityItems(key)
	return {
		{ type = "toggle", key = key .. ".duiOpacity", label = L["Use DaylightUI's opacity"],
		  desc = L["Its background follows DaylightUI's window opacity."] },
		{ type = "slider", key = key .. ".opacity", label = L["Window opacity"], min = 0.1, max = 1, step = 0.05, unit = "%",
		  desc = L["How solid its background is, with DaylightUI's opacity off."],
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

local pages = {}
for _, part in ipairs(ns.parts) do
	ns.defaults[part.key] = part.defaults or {}
	if part.page then pages[#pages + 1] = part.page end
end

local ok, err = pcall(function()
	ns.DUI:RegisterPlugin(ADDON, {
		needs = { 1, 1 },
		short = L["Essentials"],
		color = { 0.45, 0.6, 1 },
		blurb = L["Healer mana, a combat timer and alert, a pet reminder, cursor cooldowns, enemies nearby, your secondary stats, Buff Manners, Halo and Nameplate Dmg Text."],
	})
	ns.DUI:RegisterModule(ADDON, { plugin = ADDON, label = L["Essentials"], defaults = ns.defaults,
		options = { pages = pages } })
end)
if not ok then geterrorhandler()(err) end
