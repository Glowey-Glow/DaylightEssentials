-- Quick Loot: when the game auto-loots (your Auto Loot setting, or the auto loot key held with it
-- off), everything is taken the moment the loot window opens instead of one slot after another as
-- the game's own window does, so a corpse, a chest or a catch empties at once.
--
-- How: the game says the loot is ready (LOOT_READY, its first argument whether auto loot applies)
-- and every slot is taken at once (LootSlot), from the last to the first so the slot numbers don't
-- shift under it. A slot the game won't hand over (bags full, an item that asks to be confirmed,
-- one still being rolled on) stays in the window, as it does with the game's own looting.
-- LOOT_READY can come twice for one corpse: a second within a moment is left alone.
--
-- Off to start when another addon that does the same is installed and enabled for this character
-- (Daylight UI's Quality of Life, Polestar and the other quick-loot addons below), so two of them
-- never take the same loot. Turned on here, it works alongside them. A choice made on its page is
-- kept; the start follows the addons installed until then.

-- luacheck: read globals C_AddOns GetCVarBool IsModifiedClick GetNumLootItems LootSlot

local _, ns = ...
if ns.off then return end

local L = ns.L

local KEY = "quickLoot"
local G = ns.Reader(KEY)

-- Addons with a quick loot of their own: the folder name -> its name for the page.
local OTHERS = {
	{ "DaylightUI_QoL", "Daylight UI" },
	{ "Polestar", "Polestar" },
	{ "Leatrix_Plus", "Leatrix Plus" },
	{ "SpeedyAutoLoot", "Speedy AutoLoot" },
	{ "AutoLootPlus", "AutoLootPlus" },
	{ "FasterLoot", "Faster Loot" },
}

-- The ones installed and enabled for this character (known from the start: the game's addon list).
local function Others()
	local out = {}
	local A = C_AddOns
	if type(A) ~= "table" or type(A.DoesAddOnExist) ~= "function" or type(A.GetAddOnEnableState) ~= "function" then
		return out
	end
	local me = UnitName and UnitName("player") or nil
	for _, o in ipairs(OTHERS) do
		local okE, exists = pcall(A.DoesAddOnExist, o[1])
		if okE and exists then
			local okS, state = pcall(A.GetAddOnEnableState, o[1], me)
			if okS and type(state) == "number" and state > 0 then out[#out + 1] = o[2] end
		end
	end
	return out
end
local others = Others()

local P = ns.Part({ key = KEY, label = L["Quick Loot"] })

P.defaults = {
	enabled = #others == 0,
}

P.page = { id = KEY, label = L["Quick Loot"],
	desc = L["Takes all the loot at once when the game auto-loots."],
	groups = {
		{ label = L["Quick Loot"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"],
			  desc = L["With Auto Loot on (or its key held), everything is taken the moment the loot window opens, instead of one item after another. What the game won't hand over, such as with your bags full, stays in the window."] },
			{ type = "text", label = function()
				if #others == 0 then return L["No other addon here takes loot this way."] end
				return string.format(L["Off to start: %s takes loot this way too. Turn it on here if you'd rather Glowey's Essentials did it, and off in the other."],
					table.concat(others, ", "))
			  end },
		} },
	} }

local last = -1
local frame = CreateFrame("Frame")

local function AutoLootApplies(given)
	if given ~= nil then return given and true or false end
	if type(GetCVarBool) ~= "function" or type(IsModifiedClick) ~= "function" then return false end
	return (GetCVarBool("autoLootDefault") and true or false) ~= (IsModifiedClick("AUTOLOOTTOGGLE") and true or false)
end

frame:SetScript("OnEvent", function(_, _, autoLoot)
	if not G("enabled") or not AutoLootApplies(autoLoot) then return end
	local now = GetTime()
	if now - last < 0.3 then return end
	last = now
	if type(GetNumLootItems) ~= "function" or type(LootSlot) ~= "function" then return end
	for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end)

local function Sync()
	if G("enabled") then frame:RegisterEvent("LOOT_READY") else frame:UnregisterEvent("LOOT_READY") end
end

function P.Login() Sync() end
function P.Setting() Sync() end
