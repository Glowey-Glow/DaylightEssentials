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
-- Each full key ("combatTimer.hold") is made once and kept, so a reader called every frame
-- builds no strings.
function ns.Reader(key)
	local prefix = key .. "."
	local paths = {}
	return function(name)
		local path = paths[name]
		if not path then
			path = prefix .. name
			paths[name] = path
		end
		return ns.Get(path)
	end
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

-- A box of ours in DaylightUI's window shell: its background at DaylightUI's window opacity, or at
-- its part's own ("<key>.opacity") with that part's "Use DaylightUI's opacity" off (each part with
-- a box has the two on its page: Options.lua adds them). extra: the shell's other opts
-- (borderPx...). Each box is remembered (weakly) with them, so a change to either setting, or to
-- DaylightUI's look, dresses them all again. A box whose shell is put away (the combat timer without
-- its ground) is let go with ns.ForgetWindow. Returns API.Skin's.
local windows = setmetatable({}, { __mode = "k" })
function ns.SkinWindow(frame, extra, key)
	windows[frame] = { extra = extra, key = key }
	local opts = { window = true }
	if extra then for k, v in pairs(extra) do opts[k] = v end end
	if key and ns.Get(key .. ".duiOpacity") == false and not opts.noBackground then
		opts.bgAlpha = ns.Get(key .. ".opacity")
	end
	return API.Skin(frame, opts)
end

function ns.ForgetWindow(frame) windows[frame] = nil end

function ns.ReskinWindows()
	for frame, w in pairs(windows) do ns.SkinWindow(frame, w.extra, w.key) end
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

-- Text in UTF-8: names and spells in other languages take two to four bytes a letter, so text is
-- cut and counted by whole letters, never by bytes (half a letter shows as a box, or breaks a
-- macro).
local CHAR = "[%z\1-\127\194-\244][\128-\191]*"

-- The first letter (all its bytes), or "".
function ns.FirstChar(s)
	return type(s) == "string" and s:match("^" .. CHAR) or ""
end

-- How many letters (not bytes).
function ns.CharCount(s)
	if type(s) ~= "string" then return 0 end
	local _, n = s:gsub(CHAR, "")
	return n
end

-- s cut to at most maxBytes bytes, at the end of a whole letter.
function ns.CutBytes(s, maxBytes)
	if type(s) ~= "string" or #s <= maxBytes then return s end
	local out = 0
	for ch in s:gmatch(CHAR) do
		if out + #ch > maxBytes then break end
		out = out + #ch
	end
	return s:sub(1, out)
end

-- Capital and small letters beyond A to Z: Latin-1 (À to Þ), Latin Extended-A (Ā to ž) and
-- Cyrillic (Ѐ to Я), all two bytes in UTF-8. string.lower and string.upper only know A to Z.
local function LowerCode(c)
	if c >= 0xC0 and c <= 0xDE and c ~= 0xD7 then return c + 0x20 end
	if c >= 0x100 and c <= 0x17F then
		if c == 0x130 or c == 0x131 or c == 0x138 or c == 0x149 or c == 0x17F then return c end
		if c == 0x178 then return 0xFF end
		-- (Ĺ to ň and Ź to ž put the capital on the odd number; the rest on the even one.)
		if (c >= 0x139 and c <= 0x148) or (c >= 0x179 and c <= 0x17E) then
			return c % 2 == 1 and c + 1 or c
		end
		return c % 2 == 0 and c + 1 or c
	end
	if c >= 0x410 and c <= 0x42F then return c + 0x20 end
	if c >= 0x400 and c <= 0x40F then return c + 0x50 end
	return c
end

local function UpperCode(c)
	if c >= 0xE0 and c <= 0xFE and c ~= 0xF7 then return c - 0x20 end
	if c == 0xFF then return 0x178 end
	if c >= 0x100 and c <= 0x17F then
		if c == 0x130 or c == 0x131 or c == 0x138 or c == 0x149 or c == 0x17F then return c end
		if (c >= 0x139 and c <= 0x148) or (c >= 0x179 and c <= 0x17E) then
			return c % 2 == 0 and c - 1 or c
		end
		return c % 2 == 1 and c - 1 or c
	end
	if c >= 0x430 and c <= 0x44F then return c - 0x20 end
	if c >= 0x450 and c <= 0x45F then return c - 0x50 end
	return c
end

-- A two-byte letter through one of the two above.
local function Recase(ch, fn)
	local a, b = ch:byte(1, 2)
	local c = fn((a - 0xC0) * 64 + (b - 0x80))
	return string.char(0xC0 + math.floor(c / 64), 0x80 + c % 64)
end
local function LowerChar(ch) return Recase(ch, LowerCode) end

-- A name in small letters, to compare names whatever their capitals ("Élise" and "élise" match).
-- For A to Z it's string.lower's own answer.
function ns.Fold(s)
	if type(s) ~= "string" then return s end
	return (string.lower(s):gsub("[\194-\223][\128-\191]", LowerChar))
end

-- A table keyed by ns.Fold whose keys may be string.lower's (A to Z only, as kept before 1.2.0):
-- each such key moves to its folded one (an entry already there wins).
function ns.FoldKeys(t)
	local moves = {}
	for k in pairs(t) do
		if type(k) == "string" and ns.Fold(k) ~= k then moves[#moves + 1] = k end
	end
	for _, k in ipairs(moves) do
		local to = ns.Fold(k)
		if t[to] == nil then t[to] = t[k] end
		t[k] = nil
	end
end

-- s with its first letter a capital.
function ns.UpperFirst(s)
	if type(s) ~= "string" then return s end
	local first = ns.FirstChar(s)
	local rest = s:sub(#first + 1)
	if #first == 1 then
		first = string.upper(first)
	elseif #first == 2 and first:byte(1) <= 223 then
		first = Recase(first, UpperCode)
	end
	return first .. rest
end

-- Joins DaylightUI's login and /reload fade-in:the frames start unseen and come up with the rest
-- of the UI (its timing, after the loading screen, only when the player has "fade in" on and
-- motion allowed). Nothing more: no fade choices of its own, so they stay fully shown after.
-- Frames whose alpha the part sets itself are never handed over (DaylightUI owns these ones').
function ns.FadeIn(partKey, frames)
	local reg = ns.me.RegisterFade
	if type(reg) ~= "function" then return false end
	local ok, done = pcall(reg, { key = partKey .. ".intro", frames = frames })
	return ok and done == true
end

-- Whether the player lets DaylightUI animate (its "motion" choice). True when it can't be asked.
function ns.MotionOn()
	local motion = DUI.Motion
	if type(motion) ~= "table" or type(motion.On) ~= "function" then return true end
	local ok, on = pcall(motion.On)
	return not ok or on ~= false
end

-- DaylightUI's animated glow (API.GlowAround, 1.9) round a frame of ours, in the style the player
-- picked for DaylightUI's main buttons (none at all when that's "None"); on = false takes it away. It
-- eases in and out, and stays away while the player has motion off. Nothing with an older
-- DaylightUI. opts: GlowAround's (inset, thick, size, r, g, b); style is filled in here.
local glowing = setmetatable({}, { __mode = "k" })
function ns.Glow(frame, on, opts)
	if type(API.GlowAround) ~= "function" or type(frame) ~= "table" then return end
	on = on and true or false
	local o = {}
	if type(opts) == "table" then for k, v in pairs(opts) do o[k] = v end end
	if on and o.style == nil then
		local ok, style = pcall(API.GetSetting, "general", "buttonGlow")
		if ok and style == "none" then on = false end
		if ok and type(style) == "string" and style ~= "none" then o.style = style end
	end
	if not on and not glowing[frame] then return end
	glowing[frame] = on or nil
	pcall(API.GlowAround, frame, on, o)
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
	-- (A part's window opacity: its boxes are dressed again.)
	if path:find("%.duiOpacity$") or path:find("%.opacity$") then ns.ReskinWindows() end
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
	ns.ReskinWindows()
	ns.Each("Style")
end)

ns.me.On("UnlockChanged", function(on)
	ns.unlocked = on == true
	ns.Each("Preview")
end)

ns.me.On("TestModeChanged", function() ns.Each("Preview") end)
