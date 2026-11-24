-- Glowey's Essentials' welcome on first launch (the engine: Guide.lua). No tour: its parts show up
-- in their own moments (a fight, a group, a missing pet, a key held), and each one's options page
-- has a live preview. The welcome says what it adds and what it can stand in for, and its main
-- button opens Essentials' options.
local _, ns = ...
local Guide = ns.Guide
if not Guide then return end
local L = ns.L

-- What changed, newest first: shown once after an update ("What's New" in the options shows them
-- again).
local NEWS = {
	{ version = "1.11.0", lines = {
		L["Works without Daylight UI: every page is in Glowey's settings (/glowey), in Glowey's look or Blizzard Style. With Daylight UI it follows its language, colors and scale."],
		L["Buff Manners lists several players at once (Players Listed, 3 to start), offers to rebuff you before yours run out, and Disable When Busy keeps it quiet in a crowd."],
		L["Move Window on each page with a window of its own unlocks them to drag, and locks them again."],
		L["Quick Loot (off to start): everything taken the moment the loot window opens."],
	} },
}

Guide.Setup({
	name = "Glowey's Essentials",
	db = function() return _G.DaylightEssentialsDB end,
	-- (A player from before the welcome: anything saved besides the guide's own.)
	existing = function()
		local db = _G.DaylightEssentialsDB
		if type(db) ~= "table" then return false end
		for k in pairs(db) do
			if k ~= "guide" and k ~= "updateCheck" then return true end
		end
		return false
	end,
	intro = ns.standalone and L["Small extras for your screen, each with its own page in Glowey's settings (/glowey): a live preview, its settings and a switch to turn it off."]
		or L["Small extras for your screen, each with its own page in Daylight UI's options (Plugins > Essentials): a live preview, its settings and a switch to turn it off."],
	heading = L["What It Adds:"],
	takes = function()
		return {
			L["On your screen from the start: Healer Mana, Combat Timer, Combat Alert, Pet Reminder (hunters and warlocks), Cursor Cooldowns, Enemy Nearby and Secondary Stats. Move any of them with Move Window on its page."],
			L["Buff Manners: one click to buff players who buffed you and others near you, several at a time, and to rebuff yourself before yours run out."],
			L["Halo: hold a key for a ring of your actions, point at one and let go to use it. Pick its key on the Halo page first."],
			L["Nameplate Dmg Text (off to start): damage numbers that pop off enemy nameplates. Turned on, it stands in for Daylight UI's combat text and the game's floating numbers, so nothing shows twice."],
		}
	end,
	-- (2026-11-16: everyone gets the welcome once more with this release.)
	reset = "2026-11-16",
	news = NEWS,
	main = { label = L["Open Options"], fn = function() Guide.OpenOptions(ns.firstPage) end },
	decline = { label = L["Okay"], fn = function() end },
})
