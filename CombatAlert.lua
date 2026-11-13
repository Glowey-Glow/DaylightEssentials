-- Combat Alert: a short line in the middle of the screen as a fight starts ("+ Combat", in a warm
-- red) and, if you like, as it ends ("- Combat", in green). It pops in, holds a moment and fades.
-- Move it with /dui unlock. What it costs: nothing between fights; an alert is two fades.

local _, ns = ...
if ns.off then return end

local API = ns.API
local KEY = "combatAlert"
local G = ns.Reader(KEY)

local P = ns.Part({ key = KEY, label = "Combat Alert" })

P.defaults = {
	enabled = true,
	onLeave = true,
	words = "plus",
	hold = 1,
	sound = false,
	scale = 1,
}

local WORDS = {
	plus = { "+ Combat", "- Combat" },
	words = { "Entering combat", "Leaving combat" },
	short = { "Combat", "Safe" },
}

P.page = { id = KEY, label = "Combat Alert",
	desc = "A short line mid-screen as a fight starts and ends.",
	groups = {
		{ label = "Combat Alert", items = {
			{ type = "toggle", key = KEY .. ".enabled", label = "On" },
			{ type = "toggle", key = KEY .. ".onLeave", label = "Also when a fight ends" },
			{ type = "dropdown", key = KEY .. ".words", label = "Words",
			  values = { plus = "+/- Combat", words = "Entering, leaving", short = "Combat, Safe" },
			  desc = "+/- Combat: \"+ Combat\" and \"- Combat\". Entering, leaving: \"Entering combat\" and \"Leaving combat\". Combat, Safe: \"Combat\" and \"Safe\". Move it with /dui unlock." },
			{ type = "slider", key = KEY .. ".hold", label = "Stays for (seconds)", min = 0.5, max = 3, step = 0.25 },
			{ type = "toggle", key = KEY .. ".sound", label = "A sound as a fight starts" },
			{ type = "slider", key = KEY .. ".scale", label = "Size", min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
	} }

local ENTER = { 0.95, 0.4, 0.35 }
local LEAVE = { 0.45, 0.85, 0.5 }

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

local function Say(word, color, hold)
	token = token + 1
	local t = token
	previewShown = hold == nil
	text:SetText(word)
	text:SetTextColor(color[1], color[2], color[3])
	frame:SetAlpha(0)
	frame:Show()
	API.Fade(frame, 1, "FAST")
	if hold then C_Timer.After(hold, function() FadeAway(t) end) end
end

local function OnEvent(_, event)
	if not G("enabled") then return end
	if event == "PLAYER_REGEN_DISABLED" then
		Say(Words()[1], ENTER, G("hold") or 1)
		if G("sound") and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING, "SFX") end
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
	ns.me.RegisterMover(frame, KEY, "Combat alert", DEFAULT)
	ns.me.RegisterTestPart(KEY, "Combat alert")
end

function P.Setting()
	if not frame then return end
	Look()
	ShowPreview()
end

function P.Preview()
	if frame then ShowPreview() end
end
