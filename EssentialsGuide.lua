-- Daylight Essentials' welcome on first launch (the engine: Guide.lua). No tour: its parts show up
-- in their own moments (a fight, a group, a missing pet, a key held), and each one's options page
-- has a live preview. The welcome says what it adds and what it can stand in for, and its main
-- button opens Essentials' options.
local _, ns = ...
local Guide = ns.Guide
if not Guide then return end
local L = ns.L

Guide.Setup({
	name = "Daylight Essentials",
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
	intro = L["Small extras for your screen, each with its own page in Daylight UI's options (Plugins > Essentials): a live preview, its settings and a switch to turn it off."],
	heading = L["What It Adds:"],
	takes = function()
		return {
			L["On your screen from the start: Healer Mana, Combat Timer, Combat Alert, Pet Reminder (hunters and warlocks), Cursor Cooldowns, Enemy Nearby and Secondary Stats. Move any of them with /dui unlock."],
			L["Buff Manners: one click to buff players who buffed you, and others near you."],
			L["Halo: hold a key for a ring of your actions, point at one and let go to use it. Pick its key on the Halo page first."],
			L["Nameplate Dmg Text (off to start): damage numbers that pop off enemy nameplates. Turned on, it stands in for Daylight UI's combat text and the game's floating numbers, so nothing shows twice."],
		}
	end,
	-- (2026-11-16: everyone gets the welcome once more with this release.)
	reset = "2026-11-16",
	main = { label = L["Open Options"], fn = function() Guide.OpenOptions(ns.firstPage) end },
	decline = { label = L["Okay"], fn = function() end },
})
