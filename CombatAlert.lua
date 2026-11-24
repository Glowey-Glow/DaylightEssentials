-- Combat Alert: a short line in the middle of the screen as a fight starts ("+ Combat", in a warm
-- red) and, if you like, as it ends ("- Combat", in green). It pops in, holds a moment and fades.
-- Move it with /dui unlock. What it costs: nothing between fights; an alert is two fades.

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "combatAlert"
local G = ns.Reader(KEY)

local P = ns.Part({ key = KEY, label = L["Combat Alert"] })

P.defaults = {
	enabled = true,
	onLeave = true,
	words = "plus",
	hold = 1,
	sound = false,
	alertSound = ns.Host.DefaultAlert(),   -- (the raid warning, as before it had a choice)
	scale = 1,
}

local WORDS = {
	plus = { L["+ Combat"], L["- Combat"] },
	words = { L["Entering combat"], L["Leaving combat"] },
	short = { L["Combat"], L["Safe"] },
}

P.page = { id = KEY, label = L["Combat Alert"],
	desc = L["A short line mid-screen as a fight starts and ends."],
	groups = {
		{ label = L["Combat Alert"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "toggle", key = KEY .. ".onLeave", label = L["When Combat Ends"] },
			{ type = "dropdown", key = KEY .. ".words", label = L["Alert Style"],
			  values = { plus = L["+/- Combat"], words = L["Entering, Leaving"], short = L["Combat, Safe"] },
			  desc = L["+/- Combat: \"+ Combat\" and \"- Combat\". Entering, Leaving: \"Entering combat\" and \"Leaving combat\". Combat, Safe: \"Combat\" and \"Safe\". Move it with /dui unlock."] },
			{ type = "slider", key = KEY .. ".hold", label = L["Stays for (Seconds)"], min = 0.5, max = 3, step = 0.25 },
			{ type = "toggle", key = KEY .. ".sound", label = L["Sound on Combat Start"] },
			ns.AlertRow({ key = KEY .. ".alertSound", label = L["Alert Sound"],
			  disabled = function(get) return not get(KEY .. ".sound") end }, ns.Host.DefaultAlert(), L["Raid Warning"]),
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
	} }

-- The look's inks for the two lines (its BAD and GOOD), painted again on every look change.
local ENTER, LEAVE = "BAD", "GOOD"

local frame, body, text   -- frame: what /dui unlock moves; body: the line, sized by its setting
local token = 0
local previewShown = false
local W, H = 260, 40
local DEFAULT = { "CENTER", UIParent, "CENTER", 0, 160 }

-- Its size goes on the body; the moved frame only takes the size it covers on screen
-- (DaylightUI's mover keeps the moved frame's scale its own).
local function Look()
	local scale = G("scale") or 1
	body:SetScale(scale)
	frame:SetSize(W * scale, H * scale)
end

local function Words()
	return WORDS[G("words") or "plus"] or WORDS.plus
end

local function Gone(t)
	if t == token then frame:Hide() end
end

local function FadeAway(t)
	if t ~= token then return end
	API.Fade(frame, 0, "SLOW")
	C_Timer.After(API.Speed and API.Speed.SLOW or 0.4, function() Gone(t) end)
end

local function Say(word, role, hold)
	token = token + 1
	local t = token
	previewShown = hold == nil
	text:SetText(word)
	ns.Host.Ink(text, role)
	frame:SetAlpha(0)
	frame:Show()
	API.Fade(frame, 1, "FAST")
	if hold then C_Timer.After(hold, function() FadeAway(t) end) end
end

local function OnEvent(_, event)
	if not G("enabled") then return end
	if event == "PLAYER_REGEN_DISABLED" then
		Say(Words()[1], ENTER, G("hold") or 1)
		if G("sound") then ns.Host.PlayAlert(G("alertSound") or ns.Host.DefaultAlert()) end
	elseif event == "PLAYER_REGEN_ENABLED" and G("onLeave") then
		Say(Words()[2], LEAVE, G("hold") or 1)
	end
end

local function ShowPreview()
	if G("enabled") and ns.Previewing(KEY) then
		Say(Words()[1], ENTER, nil)
	elseif previewShown then
		-- Only the sample goes: an alert showing now is left to fade (test mode and unlock end as a
		-- fight starts, just as its alert shows).
		previewShown = false
		token = token + 1
		frame:Hide()
	end
end

function P.Login()
	frame = CreateFrame("Frame", "DaylightEssentialsCombatAlert", UIParent)
	frame:SetSize(W, H)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:Hide()
	body = CreateFrame("Frame", nil, frame)
	body:SetSize(W, H)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	text = API.Text(body, "title", "CENTER")
	text:SetPoint("CENTER", body, "CENTER", 0, 0)
	Look()
	frame:SetScript("OnEvent", OnEvent)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	-- Placed now: after a /reload in a fight, the mover only places it once the fight ends.
	frame:SetPoint(unpack(DEFAULT))
	ns.me.RegisterMover(frame, KEY, L["Combat Alert"], DEFAULT)
	ns.me.RegisterTestPart(KEY, L["Combat Alert"])
end

function P.Setting()
	if not frame then return end
	Look()
	ShowPreview()
end

function P.Preview()
	if frame then ShowPreview() end
end
