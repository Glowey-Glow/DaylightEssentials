-- Daylight Essentials' place in DaylightUI's options: one section under Plugins, a page per part,
-- each part's settings under its own key. Loaded last, once every part has said what it has.

local ADDON, ns = ...
if ns.off then return end

local L = ns.L

-- Look: the window opacity every box of ours shares (ns.SkinWindow). Last on the page list.
local KEY = "look"
local look = ns.Part({ key = KEY, label = L["Look"] })
look.defaults = {
	duiOpacity = true,
	opacity = 0.85,
}
look.page = { id = KEY, label = L["Look"],
	desc = L["How the boxes and windows of Daylight Essentials look."],
	groups = {
		{ label = L["Window"], items = {
			{ type = "toggle", key = KEY .. ".duiOpacity", label = L["Use DaylightUI's opacity"],
			  desc = L["Every box follows DaylightUI's window opacity."] },
			{ type = "slider", key = KEY .. ".opacity", label = L["Window opacity"], min = 0.1, max = 1, step = 0.05, unit = "%",
			  desc = L["How solid the boxes' backgrounds are, with DaylightUI's opacity off."],
			  disabled = function(get) return get(KEY .. ".duiOpacity") ~= false end },
		} },
	} }
function look.Setting() ns.ReskinWindows() end
function look.Style() ns.ReskinWindows() end

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
		blurb = L["Healer mana, a combat timer and alert, a pet reminder, cursor cooldowns, enemies nearby, your secondary stats, Buff Manners and Halo."],
	})
	ns.DUI:RegisterModule(ADDON, { plugin = ADDON, label = L["Essentials"], defaults = ns.defaults,
		options = { pages = pages } })
end)
if not ok then geterrorhandler()(err) end
