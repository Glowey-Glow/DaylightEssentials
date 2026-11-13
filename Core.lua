-- Daylight Essentials: a DaylightUI plugin of small combat and play aids, each one switched on and
-- set on its own page in DaylightUI's options (Plugins, Essentials):
--   * Healer Mana: your group's healers and the mana each has left.
--   * Combat Timer: how long you've been fighting, and how long the last fight took.
--   * Combat Alert: a short "+ Combat" / "- Combat" in the middle of the screen.
--   * Pet Reminder: a warning while your pet is missing or set to passive.
--   * Cursor Cooldowns: your taunt's and dispels' cooldowns beside the mouse pointer.
--   * Enemy Nearby: enemy players seen near you lately, and your Kill on Sight list.
--   * Secondary Stats: the stats that matter for your role (or your own pick) in a small box.
--   * Buff Manners: one click to buff players who buffed you, your target, group or passers-by.
--   * Halo: hold a key for a ring of your actions at the mouse; point, let go, and it fires.
--   * Gone Camping: your camp objects behind one tent button, and notes on what has run out.
-- This file is what the parts share: their settings, DaylightUI's look, and the game's and
-- DaylightUI's events handed to each part. Options.lua (loaded last) registers the plugin.
-- Built on DaylightUI.API only.

local ADDON, ns = ...

local DUI = _G.DaylightUI
local API = DUI and DUI.API
if not API or API.major ~= 1 then
	ns.off = true
	return
end

ns.ADDON, ns.DUI, ns.API = ADDON, DUI, API
ns.me = API.For(ADDON)

-- ---------------------------------------------------------------------------------------------
-- The parts
-- ---------------------------------------------------------------------------------------------
-- Each part: { key, label, defaults, page, Login, Setting(path), Style, Preview } (all but key and
-- label optional). Its settings live under its key: "combatTimer.hold".
ns.parts = {}
function ns.Part(def)
	ns.parts[#ns.parts + 1] = def
	return def
end

-- ---------------------------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------------------------
-- Read once and kept until a setting of ours changes.
ns.defaults = {}
local cache, NONE = {}, {}

local function DefaultOf(path)
	local t = ns.defaults
	for word in string.gmatch(path, "[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[word]
	end
	return t
end

function ns.Get(path)
	local v = cache[path]
	if v ~= nil then
		if v == NONE then return nil end
		return v
	end
	local ok, value = pcall(API.GetSetting, ADDON, path)
	if not ok or value == nil then value = DefaultOf(path) end
	cache[path] = value == nil and NONE or value
	return value
end

function ns.Forget() wipe(cache) end

-- A part's own reader: ns.Reader("combatTimer")("hold").
function ns.Reader(key)
	local prefix = key .. "."
	return function(name) return ns.Get(prefix .. name) end
end

-- ---------------------------------------------------------------------------------------------
-- Look and small helpers
-- ---------------------------------------------------------------------------------------------

-- DaylightUI's text inks, kept until the style changes (each read of API.Colors makes tables).
local colors
function ns.Colors()
	if not colors then colors = API.Colors() end
	return colors
end

function ns.Ink(fs, role)
	local c = ns.Colors()[role or "TEXT"]
	if type(c) == "table" then fs:SetTextColor(c[1], c[2], c[3]) end
end

-- Whether a value can be read (the game keeps some values secret from addons in a fight).
function ns.Safe(v)
	return not (issecretvalue and issecretvalue(v))
end

-- Whether a part shows its samples: frames unlocked (/dui unlock), or test mode with this part
-- ticked in its box (TestPartShown only says whether it's ticked).
ns.unlocked = false
function ns.Previewing(key)
	if ns.unlocked then return true end
	if DUI.testMode == true and DUI.TestPartShown then
		local ok, shown = pcall(DUI.TestPartShown, "plugin." .. ADDON .. "." .. key)
		return ok and shown == true
	end
	return false
end

-- The frame DaylightUI moves under a mover key ("unitframes.party"), or nil. Read from DaylightUI's
-- own mover list (not part of its plugin API, so it's asked carefully).
function ns.MoverFrame(key)
	local movers = DUI.Movers
	if type(movers) ~= "table" or type(movers.Get) ~= "function" then return nil end
	local ok, e = pcall(movers.Get, key)
	local f = ok and type(e) == "table" and e.frame
	if type(f) == "table" and f.GetObjectType then return f end
	return nil
end

-- Stops (or restarts) DaylightUI placing one of our part's frames: while suspended its spot stays
-- saved, /dui unlock shows no handle for it, and we place it ourselves (a box docked to another
-- frame). Asked carefully, like ns.MoverFrame.
function ns.SuspendMover(partKey, suspended)
	local movers = DUI.Movers
	if type(movers) ~= "table" or type(movers.Suspend) ~= "function" then return false end
	return (pcall(movers.Suspend, "plugin." .. ADDON .. "." .. partKey, suspended and true or false))
end

-- A text's natural width (not cut to its box), or nil while it can't be read: a text holding a
-- secret value has a secret width. Boxes that fit their text keep the last width they measured.
function ns.TextWidth(fs)
	if type(fs) ~= "table" then return nil end
	local ok, w = pcall(fs.GetUnboundedStringWidth, fs)
	if not ok or not ns.Safe(w) or type(w) ~= "number" then
		ok, w = pcall(fs.GetStringWidth, fs)
		if not ok or not ns.Safe(w) or type(w) ~= "number" then return nil end
	end
	return w
end

-- Whether the player lets DaylightUI animate (its "motion" choice). True when it can't be asked.
function ns.MotionOn()
	local motion = DUI.Motion
	if type(motion) ~= "table" or type(motion.On) ~= "function" then return true end
	local ok, on = pcall(motion.On)
	return not ok or on ~= false
end

-- A file in DaylightUI's media folder (its art, used where it is, never copied), or nil.
function ns.DaylightMedia(file)
	return type(DUI.MEDIA) == "string" and (DUI.MEDIA .. file) or nil
end

-- Runs fn for every part that has it.
function ns.Each(name, ...)
	for _, part in ipairs(ns.parts) do
		local fn = part[name]
		if type(fn) == "function" then
			local ok, err = pcall(fn, ...)
			if not ok then geterrorhandler()(err) end
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- DaylightUI's events, handed to the parts
-- ---------------------------------------------------------------------------------------------

ns.me.On("Login", function() ns.Each("Login") end)

ns.me.On("SettingChanged", function(scope, path)
	if scope ~= ADDON then return end
	ns.Forget()
	path = type(path) == "string" and path or ""
	for _, part in ipairs(ns.parts) do
		if type(part.Setting) == "function"
			and (path == "" or path == part.key or string.sub(path, 1, #part.key + 1) == part.key .. ".") then
			local ok, err = pcall(part.Setting, path)
			if not ok then geterrorhandler()(err) end
		end
	end
end)

ns.me.On("StyleChanged", function()
	colors = nil
	ns.Each("Style")
end)

ns.me.On("UnlockChanged", function(on)
	ns.unlocked = on == true
	ns.Each("Preview")
end)

ns.me.On("TestModeChanged", function() ns.Each("Preview") end)
