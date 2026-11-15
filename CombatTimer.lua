-- Combat Timer: how long you've been fighting, in a small box in the DaylightUI look. It shows as
-- a fight starts, counts up in the bright ink, and when the fight ends holds the fight's length
-- in the label ink for a few seconds before it fades. Move it with /dui unlock.
-- What it costs: nothing out of a fight; in one, a look ten times a second, and the text is only
-- set again when what it shows changes.

local _, ns = ...
if ns.off then return end

local L = ns.L

local API = ns.API
local KEY = "combatTimer"
local G = ns.Reader(KEY)

local P = ns.Part({ key = KEY, label = L["Combat Timer"] })

P.defaults = {
	enabled = true,
	hold = 4,
	tenths = false,
	ground = true,
	scale = 1,
}

P.page = { id = KEY, label = L["Combat Timer"],
	desc = L["How long you've been fighting. Move it with /dui unlock."],
	groups = {
		{ label = L["Combat Timer"], items = {
			{ type = "toggle", key = KEY .. ".enabled", label = L["On"] },
			{ type = "slider", key = KEY .. ".hold", label = L["Keep the last fight's time (seconds)"], min = 0, max = 15, step = 1,
			  desc = L["Seconds the fight's length stays after it ends. 0 hides it at once."] },
			{ type = "toggle", key = KEY .. ".tenths", label = L["Tenths of a second"],
			  desc = L["1:23.4 instead of 1:23."] },
		} },
		{ label = L["Look"], items = {
			{ type = "toggle", key = KEY .. ".ground", label = L["Window ground"],
			  desc = L["The timer on a small DaylightUI window. Off: the time alone."] },
			{ type = "slider", key = KEY .. ".scale", label = L["Size"], min = 0.7, max = 2, step = 0.05, unit = "%" },
		} },
	} }

local W, H = 76, 26
local TICK = 0.1

-- Where it starts (until it's moved), edge to edge as /dui unlock's magnet snaps: on top of the
-- damage meter's own window at its left corner while the meter is detached; with the meter in the
-- minimap's panel, against the player frame's left side; else below the screen's middle.
local function Home()
	local detached = API.GetSetting("InfoPanel", "meter.detached") == true
	local meter = _G.DaylightUIDamageMeter
	if detached and type(meter) == "table" and meter.GetObjectType then
		return { "BOTTOMLEFT", meter, "TOPLEFT", 0, 0 }
	end
	local player = ns.MoverFrame("unitframes.player")
	if player then return { "RIGHT", player, "LEFT", 0, 0 } end
	return { "CENTER", UIParent, "CENTER", 0, -240 }
end

local frame, body, text, shell   -- frame: what /dui unlock moves; body: the box, sized by its setting
local started            -- GetTime() the fight started, while in one
local hideToken = 0
local since = 0
local shownStep          -- the last tenth or second written, so the text is set only on a change
local previewShown = false

-- The time in whole tenths (tenths on) or seconds: a 59.96 shows 0:59.9, never 0:60.0.
local function Format(seconds, tenths)
	if seconds < 0 then seconds = 0 end
	if tenths then
		local t = math.floor(seconds * 10)
		local m = math.floor(t / 600)
		local rest = t - m * 600
		return string.format("%d:%02d.%d", m, math.floor(rest / 10), rest % 10)
	end
	local s = math.floor(seconds)
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function Write(seconds)
	local tenths = G("tenths") and true or false
	local step = tenths and math.floor(seconds * 10) or math.floor(seconds)
	if step == shownStep then return end
	shownStep = step
	text:SetText(Format(seconds, tenths))
end

-- Its size goes on the body; the moved frame only takes the size it covers on screen
-- (DaylightUI's mover keeps the moved frame's scale its own).
local function Look()
	local scale = G("scale") or 1
	body:SetScale(scale)
	frame:SetSize(W * scale, H * scale)
	if G("ground") then
		shell = ns.SkinWindow(body)
		if shell then shell:Show() end
	elseif shell then
		ns.ForgetWindow(body)
		shell:Hide()
	end
end

-- Shown at full strength at once (a fade still running from the last fight is replaced).
local function Appear()
	frame:Show()
	API.Fade(frame, 1, 0)
end

local function Tick(_, elapsed)
	since = since + elapsed
	if since < TICK then return end
	since = 0
	if started then Write(GetTime() - started) end
end

local ShowPreview   -- below

local function HideNow(token)
	if token ~= hideToken or started then return end
	frame:SetScript("OnUpdate", nil)
	if ns.Previewing(KEY) then
		ShowPreview()
	else
		frame:Hide()
	end
end

local function FadeOut(token)
	if token ~= hideToken or started then return end
	if ns.Previewing(KEY) then return HideNow(token) end
	API.Fade(frame, 0, "NORMAL")
	C_Timer.After(API.Speed and API.Speed.NORMAL or 0.2, function() HideNow(token) end)
end

local function Start()
	if not G("enabled") then return end
	hideToken = hideToken + 1
	previewShown = false
	started = GetTime()
	since = TICK
	shownStep = nil
	ns.Ink(text, "VALUE")
	Write(0)
	Appear()
	frame:SetScript("OnUpdate", Tick)
end

local function Stop()
	if not started then return end
	local length = GetTime() - started
	started = nil
	frame:SetScript("OnUpdate", nil)
	shownStep = nil
	Write(length)
	ns.Ink(text, "LABEL")
	hideToken = hideToken + 1
	local token = hideToken
	local hold = G("hold") or 4
	if hold <= 0 then
		HideNow(token)
	else
		C_Timer.After(hold, function() FadeOut(token) end)
	end
end

ShowPreview = function()
	if started then return end
	hideToken = hideToken + 1
	if G("enabled") and ns.Previewing(KEY) then
		previewShown = true
		shownStep = nil
		Write(83.4)
		ns.Ink(text, "VALUE")
		Appear()
	elseif previewShown then
		-- Only the sample goes: a last fight's time still held stays.
		previewShown = false
		frame:Hide()
	end
end

local function OnEvent(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		Start()
	elseif event == "PLAYER_REGEN_ENABLED" then
		Stop()
	end
end

function P.Login()
	frame = CreateFrame("Frame", "DaylightEssentialsCombatTimer", UIParent)
	frame:SetSize(W, H)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:Hide()
	body = CreateFrame("Frame", nil, frame)
	body:SetSize(W, H)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	text = API.Text(body, "head", "CENTER")
	text:SetPoint("CENTER", body, "CENTER", 0, 0)
	Look()
	frame:SetScript("OnEvent", OnEvent)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	-- Placed now: after a /reload in a fight, the mover only places it once the fight ends.
	frame:SetPoint(unpack(Home()))
	ns.me.RegisterMover(frame, KEY, L["Combat timer"], Home)
	-- Comes up with DaylightUI's fade-in on login and /reload (the inner box: the frame's own alpha is its own fade).
	ns.FadeIn(KEY, function() return { body } end)
	ns.me.RegisterTestPart(KEY, L["Combat timer"])
	-- A /reload in a fight: the count starts from the reload.
	if InCombatLockdown() then Start() end
end

function P.Setting()
	if not frame then return end
	Look()
	if not G("enabled") and started then
		started = nil
		frame:SetScript("OnUpdate", nil)
		frame:Hide()
	end
	ShowPreview()
end

function P.Style()
	if not frame then return end
	Look()
end

function P.Preview()
	if frame then ShowPreview() end
end
