-- Daylight Essentials' place in DaylightUI's options: one section under Plugins, a page per part,
-- each part's settings under its own key. Loaded last, once every part has said what it has.

local ADDON, ns = ...
if ns.off then return end

local pages = {}
for _, part in ipairs(ns.parts) do
	ns.defaults[part.key] = part.defaults or {}
	if part.page then pages[#pages + 1] = part.page end
end

local ok, err = pcall(function()
	ns.DUI:RegisterPlugin(ADDON, {
		needs = { 1, 1 },
		short = "Essentials",
		color = { 0.45, 0.6, 1 },
		blurb = "Healer mana, a combat timer and alert, a pet reminder, cursor cooldowns, enemies nearby, your secondary stats, Buff Manners and Halo.",
	})
	ns.DUI:RegisterModule(ADDON, { plugin = ADDON, label = "Essentials", defaults = ns.defaults,
		options = { pages = pages } })
end)
if not ok then geterrorhandler()(err) end
