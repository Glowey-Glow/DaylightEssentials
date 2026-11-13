-- Pet Reminder: for hunters and warlocks, a warning line while your pet is missing ("No pet") or
-- set to passive ("Pet is passive"), in a gentle pulse. Quiet while you're mounted, on a flight,
-- dead, in a vehicle, resting in a town or inn (a choice), and for a warlock who sacrificed the
-- demon on purpose (Demonic Sacrifice's buff). Only once you can call a pet (a hunter's Call Pet,
-- a warlock's first demon). Move it with /dui unlock.
-- What it costs: nothing for other classes; for these, a look when the pet, its bar, your mount
-- or your resting changes (gathered to one look a moment later). No timers while it's quiet.

local _, ns = ...
if ns.off then return end

local API = ns.API
local KEY = "petReminder"
local G = ns.Reader(KEY)
local Safe = ns.Safe

local P = ns.Part({ key = KEY, label = "Pet Reminder" })

P.defaults = {
	enabled = true,
	missing = true,
	passive = true,
	notResting = true,
	scale = 1,
}

P.page = { id = KEY, label = "Pet Reminder",
	desc = "For hunters and warlocks: a warning while your pet is missing or passive.",
	groups = {
		{ label = "Pet Reminder", items = {
			{ type = "toggle", key = KEY .. ".enabled", label = "On" },
			{ type = "toggle", key = KEY .. ".missing", label = "When I have no pet out",
			  desc = "Not for a warlock under Demonic Sacrifice's buff (the demon given up on purpose)." },
			{ type = "toggle", key = KEY .. ".passive", label = "When my pet is set to passive" },
			{ type = "toggle", key = KEY .. ".notResting", label = "Quiet in towns and inns",
			  desc = "No warning while you're resting." },
			{ type = "slider", key = KEY .. ".scale", label = "Size", min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
	} }

-- The spell that lets a class call a pet, any rank (the warning waits until one is known).
local CALLS = {
	HUNTER = { 883 },                    -- Call Pet
	WARLOCK = { 688, 697, 712, 691 },    -- Summon Imp, Voidwalker, Succubus, Felhunter
}
-- Demonic Sacrifice's buffs (the warlock gave the demon up on purpose).
local SACRIFICE = { 18789, 18790, 18791, 18792, 35701 }

local WARN = { 1, 0.75, 0.3 }

local frame, body, text, pulse   -- frame: what /dui unlock moves; body: the line, sized by its setting
local W, H = 220, 30
local DEFAULT = { "CENTER", UIParent, "CENTER", 0, 110 }
local class
local looking = false

local function Known(list)
	for _, id in ipairs(list or {}) do
		if (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) then return true end
	end
	return false
end

local function Sacrificed()
	if class ~= "WARLOCK" or not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
	for _, id in ipairs(SACRIFICE) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
		if ok and aura ~= nil then return true end
	end
	return false
end

local function Passive()
	if not GetPetActionInfo then return false end
	for i = 1, NUM_PET_ACTION_SLOTS or 10 do
		local name, _, _, active = GetPetActionInfo(i)
		if name == "PET_MODE_PASSIVE" then return Safe(active) and active == true end
	end
	return false
end

local function Quiet()
	if UnitIsDeadOrGhost("player") then return true end
	if IsMounted and IsMounted() then return true end
	if UnitOnTaxi and UnitOnTaxi("player") then return true end
	if UnitInVehicle and UnitInVehicle("player") then return true end
	if G("notResting") and IsResting() then return true end
	return false
end

-- What to warn about now, or nil.
local function Warning()
	if not G("enabled") or not CALLS[class] or not Known(CALLS[class]) or Quiet() then return nil end
	if not UnitExists("pet") then
		if G("missing") and not Sacrificed() then return "No pet" end
		return nil
	end
	if G("passive") and Passive() then return "Pet is passive" end
	return nil
end

local function Show(word)
	if word then
		text:SetText(word)
		local scale = G("scale") or 1
		body:SetScale(scale)
		frame:SetSize(W * scale, H * scale)
		if not frame:IsShown() then
			frame:SetAlpha(1)
			frame:Show()
			pulse:Play()
		end
	elseif frame:IsShown() then
		pulse:Stop()
		frame:Hide()
	end
end

local function Look()
	looking = false
	if ns.Previewing(KEY) and G("enabled") then
		Show("No pet")
		return
	end
	Show(Warning())
end

local function LookSoon()
	if looking then return end
	looking = true
	C_Timer.After(0.1, Look)
end

local EVENTS = { "UNIT_PET", "PET_BAR_UPDATE", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD",
	"PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ALIVE",
	"PLAYER_UNGHOST", "PLAYER_DEAD", "SPELLS_CHANGED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }

local function OnEvent(_, event, unit)
	-- A warlock's buffs change all through a fight; they only matter while no pet is out.
	if event == "UNIT_AURA" and (unit ~= "player" or UnitExists("pet")) then return end
	LookSoon()
end

function P.Login()
	local _, token = UnitClass("player")
	class = token
	-- Only a class with a pet has anything here: no frame, mover or sample for the others.
	if not CALLS[class] then return end
	frame = CreateFrame("Frame", "DaylightEssentialsPetReminder", UIParent)
	frame:SetSize(W, H)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:Hide()
	body = CreateFrame("Frame", nil, frame)
	body:SetSize(W, H)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	text = API.Text(body, "head", "CENTER")
	text:SetPoint("CENTER", body, "CENTER", 0, 0)
	text:SetTextColor(WARN[1], WARN[2], WARN[3])
	pulse = frame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local a = pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.45)
	a:SetDuration(0.9)
	a:SetSmoothing("IN_OUT")
	-- Placed now: after a /reload in a fight, the mover only places it once the fight ends.
	frame:SetPoint(unpack(DEFAULT))
	ns.me.RegisterMover(frame, KEY, "Pet reminder", DEFAULT)
	ns.me.RegisterTestPart(KEY, "Pet reminder")
	frame:SetScript("OnEvent", OnEvent)
	for _, e in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, e) end
	if class == "WARLOCK" then frame:RegisterUnitEvent("UNIT_AURA", "player") end
	LookSoon()
end

function P.Setting()
	if frame then LookSoon() end
end

function P.Preview()
	if frame then Look() end
end
