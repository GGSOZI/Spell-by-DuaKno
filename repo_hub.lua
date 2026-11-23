--// POWER/WEAPON TOOLS HUB // powers + weapons // by DuaKNo
--// v3: custom firebase fx layer (SpellsFx) replaces the old ghost replay. powers push softly, nothing kills
--// v2: ability emblems, per-ability accent, owner editor (rename + set ability) with live npoint sync
--// client side executor gui. save as "repo_hub.lua" in the repo root, the scan skips it
--// scans your github repo, sorts every script into POWERS or WEAPONS, preview + activate/equip
--// running a new one removes the previous one's tools, guis, threads and connections (toggle in settings)

local cloneref = cloneref or function(x) return x end

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local StarterGui = cloneref(game:GetService("StarterGui"))
local TweenService = cloneref(game:GetService("TweenService"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

--// ============================== config ==============================

local CONFIG = {
	Owner = "GGSOZI",
	Repo = "Spell-by-DuaKno",
	Branch = "main",
	StartPath = "",             -- "" = repo root, or a folder like "scripts"
	SelfFile = "repo_hub.lua",  -- this file's name in the repo, skipped in the scan
	MaxDepth = 3,
	Token = nil,                -- optional github token string, avoids rate limit
	Extensions = { lua = true, luau = true, txt = true },
	AllowNoExtension = true,
	SettleTime = 1.5,           -- seconds after a run that new tools/guis count as that script's

	WindowWidth = 580,
	WindowHeight = 364,
	TabY = 12,                  -- height of the < tab from the top of the screen
	SettingsFile = "SpellsHub_settings.json",

	Credit = { UserName = "DuaKNo", Instagram = "me_duakno", Discord = "discord.gg/empgqd5qpq" },

	-- only this account can rename scripts / set abilities (name AND real user id are checked)
	OwnerNames = { "DuaKNo" },
	OwnerIds = { 8014469067 }, -- DuaKNo's real user id, checked first so it works even offline
	-- edits are saved to this npoint bin and every player pulls them. make a bin at npoint.io with {} and paste its id
	Npoint = { BinId = "a58c8d3a0629b499d993", PollSeconds = 15 },
	-- custom firebase realtime database (see the setup steps). paste the url, no trailing slash. empty = fx sync off
	Fx = { Url = "https://power-weapon-default-rtdb.firebaseio.com", Auth = nil, PollSeconds = 0.5 },

	-- folders decide the section first: Repo/Weapons/x.lua -> WEAPONS
	WeaponFolders = { weapon = true, weapons = true, guns = true, arms = true, arsenal = true },
	PowerFolders = { power = true, powers = true, moves = true, abilities = true, spells = true },

	-- no folder? the file name decides
	WeaponWords = {
		"sword", "katana", "blade", "saber", "scythe", "axe", "knife", "dagger", "spear", "trident",
		"gun", "rifle", "pistol", "shotgun", "sniper", "launcher", "cannon", "flamethrower",
		"bow", "hammer", "whip", "weapon",
	},

	Categories = {
		{ name = "Ice", color = Color3.fromRGB(120, 205, 255), words = { "snow", "ice", "frost", "freez", "glacier", "blizzard" } },
		{ name = "Fire", color = Color3.fromRGB(255, 122, 66), words = { "fire", "flame", "burn", "ember", "inferno", "blaze" } },
		{ name = "Storm", color = Color3.fromRGB(255, 218, 92), words = { "thunder", "lightning", "shock", "volt", "storm" } },
		{ name = "Wind", color = Color3.fromRGB(170, 235, 220), words = { "wind", "tornado", "gust", "cyclone", "hurricane" } },
		{ name = "Water", color = Color3.fromRGB(84, 160, 255), words = { "water", "wave", "tide", "aqua", "ocean", "flood", "tsunami" } },
		{ name = "Earth", color = Color3.fromRGB(186, 146, 100), words = { "earth", "rock", "stone", "quake", "boulder", "terra", "mud" } },
		{ name = "Nature", color = Color3.fromRGB(112, 214, 98), words = { "plant", "vine", "leaf", "forest", "nature", "flower", "root" } },
		{ name = "Light", color = Color3.fromRGB(255, 244, 170), words = { "light", "holy", "radiant", "divine", "heaven", "sun" } },
		{ name = "Dark", color = Color3.fromRGB(150, 110, 215), words = { "dark", "shadow", "night", "umbra", "abyss" } },
		{ name = "Void", color = Color3.fromRGB(110, 90, 175), words = { "void", "blackhole", "hollow", "null" } },
		{ name = "Blood", color = Color3.fromRGB(205, 40, 70), words = { "blood", "crimson", "vampire", "bleed" } },
		{ name = "Poison", color = Color3.fromRGB(150, 220, 70), words = { "poison", "toxic", "venom", "acid" } },
		{ name = "Gravity", color = Color3.fromRGB(150, 130, 255), words = { "gravity", "graviton", "crush", "pull" } },
		{ name = "Time", color = Color3.fromRGB(240, 200, 120), words = { "time", "clock", "chrono", "rewind" } },
		{ name = "Space", color = Color3.fromRGB(110, 140, 255), words = { "space", "galaxy", "cosmic", "meteor", "comet", "star" } },
		{ name = "Psychic", color = Color3.fromRGB(255, 130, 220), words = { "psychic", "mind", "telekin", "mental", "illusion" } },
		{ name = "Sound", color = Color3.fromRGB(255, 170, 120), words = { "sound", "sonic", "echo", "scream", "music" } },
		{ name = "Metal", color = Color3.fromRGB(190, 200, 215), words = { "metal", "steel", "iron", "chrome" } },
		{ name = "Magma", color = Color3.fromRGB(255, 90, 40), words = { "lava", "magma", "volcano" } },
		{ name = "Sand", color = Color3.fromRGB(225, 195, 130), words = { "sand", "dune", "desert" } },
		{ name = "Magic", color = Color3.fromRGB(200, 120, 255), words = { "magic", "arcane", "spell", "wizard", "rune", "mage" } },
		{ name = "Curse", color = Color3.fromRGB(176, 60, 125), words = { "curse", "hex", "malevolent" } },
		{ name = "Spirit", color = Color3.fromRGB(150, 230, 230), words = { "spirit", "ghost", "soul", "phantom" } },
		{ name = "Energy", color = Color3.fromRGB(120, 255, 240), words = { "energy", "beam", "laser", "plasma", "aura", "blast" } },
		{ name = "Explosion", color = Color3.fromRGB(255, 160, 60), words = { "explosion", "bomb", "boom", "nuke", "explode" } },
		{ name = "Healing", color = Color3.fromRGB(130, 255, 170), words = { "heal", "regen", "restore", "cure" } },
		{ name = "Movement", color = Color3.fromRGB(112, 232, 176), words = { "parkour", "dash", "fly", "speed", "wall", "teleport", "glide" } },
		{ name = "Summon", color = Color3.fromRGB(194, 138, 255), words = { "pet", "guard", "summon", "dog", "cat", "army", "npc" } },
		{ name = "Combat", color = Color3.fromRGB(255, 102, 124), words = { "moveset", "combo", "fight", "punch", "domain" } },
		{ name = "Blade", color = Color3.fromRGB(206, 214, 232), words = { "sword", "katana", "blade", "saber", "scythe", "axe", "knife", "dagger", "spear" } },
		{ name = "Ranged", color = Color3.fromRGB(255, 184, 84), words = { "gun", "rifle", "pistol", "shotgun", "sniper", "launcher", "cannon", "bow" } },
		{ name = "Blunt", color = Color3.fromRGB(190, 170, 150), words = { "hammer", "mace", "club", "staff" } },
	},
	GeneralColor = Color3.fromRGB(150, 160, 184),

	-- per file overrides, key = file name without extension. every field is optional
	-- kind = "Powers" | "Weapons", category = any name, desc = text, color = Color3
	Meta = {
		["Snowgrave_by_DuaKNo"] = {
			kind = "Powers",
			category = "Ice",
			desc = "Snowgrave: pray pose, blizzard, then the freezing beam falls where you aim.",
		},
		["Iceshock_by_DuaKNo"] = {
			kind = "Weapons",
			category = "Ice",
			desc = "Iceshock: an ice ball flies to your click and freezes the target.",
		},
	},
}

local MetaLower = {}
for key, meta in pairs(CONFIG.Meta) do
	MetaLower[string.lower(key)] = meta
end

local THEME = {
	bg = Color3.fromRGB(8, 8, 11),
	panel = Color3.fromRGB(13, 13, 18),
	raised = Color3.fromRGB(21, 21, 29),
	line = Color3.fromRGB(34, 34, 47),
	text = Color3.fromRGB(228, 228, 238),
	soft = Color3.fromRGB(182, 182, 198),
	dim = Color3.fromRGB(118, 118, 140),
	faint = Color3.fromRGB(70, 70, 90),
	ink = Color3.fromRGB(10, 10, 14),
	good = Color3.fromRGB(110, 232, 168),
	bad = Color3.fromRGB(255, 92, 108),
	accents = {
		Powers = Color3.fromRGB(152, 120, 255),
		Weapons = Color3.fromRGB(255, 112, 72),
		Settings = Color3.fromRGB(198, 206, 224),
	},
}

local HEADER, FOOTER, SIDE, ROW_H = 34, 20, 46, 50
local TAB_ORDER = { "Powers", "Weapons", "Settings" }
local TAB_INDEX = { Powers = 1, Weapons = 2, Settings = 3 }

--// ============================== state ==============================

local State = {
	alive = true,
	connections = {},
	gui = nil,
	runs = {},
	cache = {},
	entries = {},
	avatar = nil,
	spin = nil,
	binding = false,
	toggleKey = Enum.KeyCode.RightShift,
	settings = { Scale = 1, Particles = true, Animations = true, Stack = false, Live = true, Impact = true, ImpactPower = 0.5, Quiet = true, Debug = false, SimRadius = 0, NoShare = {}, ToggleKey = "RightShift" },
}

local Fx = (function()
--// SPELLS FX // custom firebase layer // makes any power or weapon visible to other players
--// only small numbers / strings travel through firebase. no code, no script source.
--// every viewer replays the effect with their own copy of the script (viewer mode).
--// pushes are soft and capped, nothing here touches Humanoid.Health.
--//
--// api (everything lives in getgenv().SpellsFx):
--//   Fx.configure({ Url = "https://xxxx-default-rtdb.firebaseio.com", Auth = nil })
--//   Fx.register(id, { play = function(pkt) end, stop = function() end }, FX_PATH)   -- FX_PATH = Fx.currentPath captured at the top of the script. pkt = { id, kind, casterId, caster, target, d }
--//   Fx.emit(id, kind, data, targetUserId)       -- data = plain table of numbers / strings / bools / Fx.vec()
--//   Fx.push(targetUserId, dir, strength, id)    -- soft push on another player (their own client applies it)
--//   Fx.softPush(root, dir, strength)            -- soft push on a local part
--//   Fx.status(targetUserId, name, seconds, data, id)   -- real effect on the target's own client, capped, no damage
--//        names: freeze burn pull spin lift slow glow shock blind shake
--//   Fx.cast(id, pos, { radius, target, freeze, burn, pull, push, spin, lift, slow, glow, shock, blind, shake })   -- emit + effects on every player in range, one call
--//        spin = angular speed (rad/s) + spinRadius + spinUp + spinTime  (tornado) | lift = rise speed + liftTime | slow = seconds + slowFactor
--//        glow = seconds + glowColor = {r,g,b} 0-255 | shock / blind / shake = seconds
--//   Fx.playerAt(mouse) / Fx.playersInRadius(pos, radius)
--//   Fx.vec(v3) / Fx.unvec(tbl)
--//   Fx.viewerOnly / Fx.currentPath               -- read both at the very top of your script (before any yield). viewerOnly is true when a script is loaded only to replay for others

local cloneref = cloneref or function(x) return x end
local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local RunService = cloneref(game:GetService("RunService"))
local Lighting = cloneref(game:GetService("Lighting"))

local genv = (getgenv and getgenv()) or _G
if genv.SpellsFx and genv.SpellsFx.stop then
	pcall(genv.SpellsFx.stop)
end

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local Fx = {
	config = {
		Url = "",             -- firebase realtime database url, no trailing slash
		Auth = nil,           -- optional database secret / token
		Poll = 0.5,           -- seconds between polls
		Ttl = 20,             -- seconds an event lives before its sender deletes it
		MaxPerSec = 30,       -- events accepted per sender per second
		PushMax = 22,         -- hard cap on the horizontal push speed (studs/s)
		PushUp = 10,          -- hard cap on the upward push speed
		PullSpeed = 24,       -- hard cap on the horizontal speed of a pull (studs/s)
		FreezeMax = 6,        -- longest freeze in seconds
		FreezeCooldown = 2,   -- seconds you cannot be frozen again after a freeze ends
		BurnMax = 6,          -- longest burn (visual only) in seconds
		MotionMax = 4,        -- longest spin / lift in seconds
		MotionSpeed = 40,     -- hard cap on the speed of a spin / lift (studs/s)
		MotionCooldown = 2,   -- seconds you cannot be spun / lifted again after one ends
		SpinRadiusMax = 20,   -- widest orbit of a spin
		LiftHeight = 22,      -- highest a spin / lift can raise you above where it started
		SlowMax = 4,          -- longest slow in seconds
		ScreenMax = 3,        -- longest blind / shake in seconds
		PushCooldown = 0.4,   -- seconds between pushes on you
		PushScale = 1,        -- multiplier for pushes that hit you (hub slider)
		AcceptPush = true,    -- false = nobody can push you
		Enabled = true,
	},
	abilities = {},
	pending = {},
	muted = {},
	burning = {},
	cleanups = {},
	freezeLock = 0,
	motionLock = 0,
	temps = {},
	outbox = {},
	sentKeys = {},
	seen = {},
	rate = {},
	logBuf = {},
	seq = 0,
	lastPush = 0,
	alive = true,
	started = false,
	primed = false,
	listen = false,       -- hub sets this so it hears events for scripts it has not loaded yet
	viewerOnly = false,
	currentPath = nil,
	status = "idle",
}

local function myId()
	return Players.LocalPlayer.UserId
end

function Fx.log(text)
	table.insert(Fx.logBuf, tostring(text))
	if #Fx.logBuf > 14 then
		table.remove(Fx.logBuf, 1)
	end
	if Fx.onLog then
		pcall(Fx.onLog, tostring(text))
	end
end

function Fx.configure(cfg)
	for k, v in pairs(cfg or {}) do
		Fx.config[k] = v
	end
	Fx.start()
end

function Fx.ready()
	return Fx.alive
		and Fx.config.Enabled == true
		and type(Fx.config.Url) == "string"
		and Fx.config.Url ~= ""
		and httpRequest ~= nil
end

local function room()
	local id = game.JobId
	if id == nil or id == "" then
		id = "place" .. tostring(game.PlaceId)
	end
	return (string.gsub(id, "[%.%$#%[%]/]", "_"))
end

local function buildUrl(path, query)
	local q = {}
	if Fx.config.Auth then
		table.insert(q, "auth=" .. HttpService:UrlEncode(Fx.config.Auth))
	end
	for _, part in ipairs(query or {}) do
		table.insert(q, part)
	end
	local base = string.gsub(Fx.config.Url, "/+$", "")
	local url = base .. "/spellsfx/" .. room() .. path .. ".json"
	if #q > 0 then
		url = url .. "?" .. table.concat(q, "&")
	end
	return url
end

local function req(method, path, body, rawBody)
	if not httpRequest then
		Fx.status = "executor has no http request"
		return false
	end
	local query = nil
	if method ~= "GET" then
		query = { "print=silent" }
	end
	local opts = { Url = buildUrl(path, query), Method = method, Headers = { ["Content-Type"] = "application/json" } }
	if rawBody then
		opts.Body = rawBody
	elseif body ~= nil then
		local okE, enc = pcall(function()
			return HttpService:JSONEncode(body)
		end)
		if not okE then
			return false
		end
		opts.Body = enc
	end
	local ok, res = pcall(httpRequest, opts)
	if not ok or type(res) ~= "table" then
		Fx.status = "no response (executor blocks the request?)"
		return false
	end
	local code = res.StatusCode
	if code and code >= 200 and code < 300 then
		Fx.status = "connected"
		local data
		if type(res.Body) == "string" and res.Body ~= "" and res.Body ~= "null" then
			local okD, dec = pcall(function()
				return HttpService:JSONDecode(res.Body)
			end)
			if okD then
				data = dec
			end
		end
		return true, data
	end
	Fx.status = "firebase error " .. tostring(code) .. " (check url and rules)"
	return false
end

--// ---------- data helpers ----------

local function clean(v, depth)
	local t = type(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return nil
		end
		return math.clamp(v, -100000, 100000)
	elseif t == "string" then
		return string.sub(v, 1, 40)
	elseif t == "boolean" then
		return v
	elseif t == "table" and depth < 2 then
		local out, n = {}, 0
		for k, x in pairs(v) do
			n += 1
			if n > 24 then
				break
			end
			local cv = clean(x, depth + 1)
			if cv ~= nil then
				out[string.sub(tostring(k), 1, 16)] = cv
			end
		end
		return out
	end
	return nil
end

function Fx.vec(v)
	return { x = v.X, y = v.Y, z = v.Z }
end

function Fx.unvec(t)
	if type(t) ~= "table" then
		return nil
	end
	local x, y, z = t.x, t.y, t.z
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil
	end
	return Vector3.new(x, y, z)
end

--// ---------- players / targeting ----------

function Fx.playerFromInstance(inst)
	local model = inst and inst:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then
			return p
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Fx.playersInRadius(pos, radius, includeSelf)
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if includeSelf or p ~= Players.LocalPlayer then
			local char = p.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - pos).Magnitude <= radius then
				table.insert(out, p)
			end
		end
	end
	return out
end

-- player under the cursor, or the closest one to where the cursor points
function Fx.playerAt(mouse, radius)
	local ok, target = pcall(function()
		return mouse.Target
	end)
	if ok and target then
		local p = Fx.playerFromInstance(target)
		if p and p ~= Players.LocalPlayer then
			return p
		end
	end
	local okH, hit = pcall(function()
		return mouse.Hit.Position
	end)
	if not okH or not hit then
		return nil
	end
	local best, bestD = nil, radius or 10
	for _, p in ipairs(Fx.playersInRadius(hit, radius or 10, false)) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local d = (r.Position - hit).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

--// ---------- soft push (never damage, never kill) ----------

function Fx.softPush(root, dir, strength)
	if not root or not root.Parent or typeof(dir) ~= "Vector3" then
		return false
	end
	local now = os.clock()
	if now - Fx.lastPush < Fx.config.PushCooldown then
		return false
	end
	strength = math.clamp(tonumber(strength) or 0, 0, Fx.config.PushMax)
	if strength <= 0 then
		return false
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.05 then
		flat = -root.CFrame.LookVector
	end
	flat = flat.Unit
	Fx.lastPush = now
	local add = flat * strength + Vector3.new(0, math.min(strength * 0.35, Fx.config.PushUp), 0)
	pcall(function()
		local v = root.AssemblyLinearVelocity + add
		local h = Vector3.new(v.X, 0, v.Z)
		local cap = Fx.config.PushMax * 1.5
		if h.Magnitude > cap then
			h = h.Unit * cap
		end
		root.AssemblyLinearVelocity = Vector3.new(h.X, math.min(v.Y, Fx.config.PushUp * 2), h.Z)
		local hum = root.Parent:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end)
	return true
end

local function receivePush(from, d)
	if not Fx.config.AcceptPush then
		return
	end
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dir = Fx.unvec(d.dir)
	if not dir then
		local caster = Players:GetPlayerByUserId(from)
		local cr = caster and caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
		dir = cr and (root.Position - cr.Position) or -root.CFrame.LookVector
	end
	Fx.softPush(root, dir, (tonumber(d.s) or 0) * (Fx.config.PushScale or 1))
end


--// ---------- status effects: freeze / burn / pull ----------
--// visuals show on every client that gets the event. the hold / pull itself only happens on the TARGET's own client,
--// only when Receive effects is on, always time limited, and never touches Humanoid.Health.

local function visFolder()
	if not Fx.visFolder or not Fx.visFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "SpellsFxVisuals"
		f.Parent = workspace
		Fx.visFolder = f
	end
	return Fx.visFolder
end

local function visualFreeze(char, dur)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local okB, bcf, bsz = pcall(char.GetBoundingBox, char)
	if not okB then
		return
	end
	local offset = bcf.Position - root.Position
	local made = {}
	local function mk(size, transp, mat, color)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = size
		p.Transparency = transp
		p.Material = mat
		p.Color = color
		p.CFrame = CFrame.new(bcf.Position)
		p.Parent = visFolder()
		table.insert(made, p)
	end
	mk(bsz + Vector3.new(1.4, 1.4, 1.4), 0.35, Enum.Material.Glass, Color3.fromRGB(150, 215, 255))
	mk(bsz + Vector3.new(2.4, 2.4, 2.4), 0.88, Enum.Material.Neon, Color3.fromRGB(190, 240, 255))
	local conn
	local function stop()
		Fx.cleanups[stop] = nil
		if conn then
			conn:Disconnect()
			conn = nil
		end
		for _, p in ipairs(made) do
			pcall(function() p:Destroy() end)
		end
	end
	Fx.cleanups[stop] = true
	conn = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			stop()
			return
		end
		local cf = CFrame.new(root.Position + offset)
		for _, p in ipairs(made) do
			p.CFrame = cf
		end
	end)
	task.delay(dur + 0.2, stop)
end

local FIRE_PARTS = { "HumanoidRootPart", "Head", "UpperTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }

local function visualBurn(char, dur)
	local untilT = os.clock() + dur
	local b = Fx.burning[char]
	if b then
		b.untilT = math.max(b.untilT, untilT)
		return
	end
	b = { untilT = untilT, fx = {} }
	Fx.burning[char] = b
	for _, n in ipairs(FIRE_PARTS) do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			local f = Instance.new("Fire")
			f.Size, f.Heat = 6, 10
			f.Color, f.SecondaryColor = Color3.fromRGB(255, 120, 0), Color3.fromRGB(255, 40, 0)
			f.Parent = p
			local sm = Instance.new("Smoke")
			sm.Size, sm.Opacity, sm.RiseVelocity = 3, 0.3, 6
			sm.Color = Color3.fromRGB(40, 40, 40)
			sm.Parent = p
			table.insert(b.fx, f)
			table.insert(b.fx, sm)
		end
	end
	local function stop()
		Fx.cleanups[stop] = nil
		for _, f in ipairs(b.fx) do
			pcall(function() f:Destroy() end)
		end
		if Fx.burning[char] == b then
			Fx.burning[char] = nil
		end
	end
	Fx.cleanups[stop] = true
	task.spawn(function()
		while Fx.alive and char.Parent and os.clock() < b.untilT do
			task.wait(0.2)
		end
		stop()
	end)
end

local function mechFreeze(char, dur)
	if not Fx.config.AcceptPush or Fx.freezeRelease or os.clock() < Fx.freezeLock then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	local cf = root.CFrame
	local saved = { ws = Fx.slowOrig or hum.WalkSpeed, jp = hum.JumpPower, jh = hum.JumpHeight, ar = hum.AutoRotate }
	local t0 = os.clock()
	local conn
	local function release()
		if not conn then
			return
		end
		conn:Disconnect()
		conn = nil
		Fx.freezeRelease = nil
		Fx.freezeLock = os.clock() + Fx.config.FreezeCooldown
		pcall(function()
			hum.WalkSpeed = saved.ws
			hum.JumpPower = saved.jp
			hum.JumpHeight = saved.jh
			hum.AutoRotate = saved.ar
		end)
	end
	Fx.freezeRelease = release
	pcall(function()
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
		hum.AutoRotate = false
	end)
	conn = RunService.Heartbeat:Connect(function()
		if not Fx.alive or not Fx.config.AcceptPush or not root.Parent or hum.Health <= 0 or os.clock() - t0 >= dur then
			release()
			return
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = cf
	end)
end

local function mechPull(dur, pos, speed)
	if not Fx.config.AcceptPush or not pos then
		return
	end
	local now = os.clock()
	local st = Fx.pullState
	if st then
		st.untilT = math.max(st.untilT, now + dur)
		st.pos, st.speed = pos, speed
		return
	end
	st = { untilT = now + dur, pos = pos, speed = speed }
	Fx.pullState = st
	local lastState = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local c = Players.LocalPlayer.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not Fx.alive or not Fx.config.AcceptPush or not root or not hum or hum.Health <= 0 or os.clock() > st.untilT then
			conn:Disconnect()
			Fx.pullState = nil
			return
		end
		if Fx.freezeRelease or Fx.motion then
			return
		end
		local off = st.pos - root.Position
		local flat = Vector3.new(off.X, 0, off.Z)
		if flat.Magnitude < 4 then
			return
		end
		local v = root.AssemblyLinearVelocity
		local cap = math.clamp((st.speed or 16) * (Fx.config.PushScale or 1), 0, Fx.config.PullSpeed)
		local h = Vector3.new(v.X, 0, v.Z) + flat.Unit * cap * 5 * dt
		if h.Magnitude > cap then
			h = h.Unit * cap
		end
		root.AssemblyLinearVelocity = Vector3.new(h.X, v.Y, h.Z)
		if os.clock() - lastState > 0.3 then
			lastState = os.clock()
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end)
		end
	end)
	Fx.pullConn = conn
end

local function visualTemp(char, key, dur, build)
	local per = Fx.temps[char]
	if not per then
		per = {}
		Fx.temps[char] = per
	end
	local e = per[key]
	local untilT = os.clock() + dur
	if e then
		e.untilT = math.max(e.untilT, untilT)
		return
	end
	e = { untilT = untilT, inst = {} }
	per[key] = e
	local ok, list = pcall(build)
	if ok and type(list) == "table" then
		e.inst = list
	end
	local function stop()
		Fx.cleanups[stop] = nil
		for _, i in ipairs(e.inst) do
			pcall(function() i:Destroy() end)
		end
		if per[key] == e then
			per[key] = nil
		end
	end
	Fx.cleanups[stop] = true
	task.spawn(function()
		while Fx.alive and char.Parent and os.clock() < e.untilT do
			task.wait(0.2)
		end
		stop()
	end)
end

local function visualGlow(char, dur, c)
	local col = Color3.fromRGB(255, 255, 255)
	if type(c) == "table" then
		col = Color3.fromRGB(math.clamp(tonumber(c.r) or 255, 0, 255), math.clamp(tonumber(c.g) or 255, 0, 255), math.clamp(tonumber(c.b) or 255, 0, 255))
	end
	visualTemp(char, "glow", dur, function()
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor = col, col
		h.FillTransparency, h.OutlineTransparency = 0.55, 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = char
		return { h }
	end)
end

local function visualShock(char, dur)
	visualTemp(char, "shock", dur, function()
		local list = {}
		local col = Color3.fromRGB(120, 200, 255)
		for _, n in ipairs({ "HumanoidRootPart", "Head", "UpperTorso", "Torso" }) do
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				local pe = Instance.new("ParticleEmitter")
				pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				pe.Color = ColorSequence.new(col)
				pe.LightEmission = 1
				pe.Size = NumberSequence.new(0.5, 0)
				pe.Lifetime = NumberRange.new(0.15, 0.35)
				pe.Rate = 60
				pe.Speed = NumberRange.new(6, 14)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Parent = p
				table.insert(list, pe)
			end
		end
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor = col, Color3.fromRGB(255, 255, 255)
		h.FillTransparency, h.OutlineTransparency = 0.7, 0
		h.Parent = char
		table.insert(list, h)
		task.spawn(function()
			while h.Parent do
				h.FillTransparency = 0.4 + math.random() * 0.5
				task.wait(0.06)
			end
		end)
		return list
	end)
end

local function mechScreen(kind, dur)
	if not Fx.config.AcceptPush or Fx.screenBusy then
		return
	end
	dur = math.clamp(dur, 0.1, Fx.config.ScreenMax)
	Fx.screenBusy = true
	local list = {}
	local conn
	local function stop()
		if not Fx.screenBusy then
			return
		end
		Fx.screenBusy = false
		Fx.cleanups[stop] = nil
		if conn then
			conn:Disconnect()
			conn = nil
		end
		for _, i in ipairs(list) do
			pcall(function() i:Destroy() end)
		end
		pcall(function()
			local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.CameraOffset = Vector3.zero
			end
		end)
	end
	Fx.cleanups[stop] = true
	local t0 = os.clock()
	if kind == "blind" then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness, cc.Contrast, cc.Saturation = 0, 0, 0
		cc.Parent = Lighting
		local bl = Instance.new("BlurEffect")
		bl.Size = 0
		bl.Parent = Lighting
		list = { cc, bl }
		conn = RunService.RenderStepped:Connect(function()
			local a = os.clock() - t0
			local k = math.clamp(math.min(a / 0.25, (dur - a) / 0.6), 0, 1)
			cc.Brightness = 0.9 * k
			bl.Size = 18 * k
			if a >= dur then
				stop()
			end
		end)
	else
		conn = RunService.RenderStepped:Connect(function()
			local a = os.clock() - t0
			local c = Players.LocalPlayer.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if not hum or a >= dur then
				stop()
				return
			end
			local k = math.clamp((dur - a) / 0.5, 0, 1) * 0.35
			hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
		end)
	end
	task.delay(dur + 0.3, stop)
end

local function mechSlow(dur, factor)
	if not Fx.config.AcceptPush or Fx.slowRelease then
		return
	end
	local c = Players.LocalPlayer.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	dur = math.clamp(dur, 0.1, Fx.config.SlowMax)
	factor = math.clamp(tonumber(factor) or 0.4, 0.2, 0.9)
	local orig = hum.WalkSpeed
	local slowed = orig * factor
	Fx.slowOrig = orig
	local t0 = os.clock()
	local conn
	local function release()
		if not conn then
			return
		end
		conn:Disconnect()
		conn = nil
		Fx.slowRelease = nil
		Fx.slowOrig = nil
		if not Fx.freezeRelease then
			pcall(function() hum.WalkSpeed = orig end)
		end
	end
	Fx.slowRelease = release
	conn = RunService.Heartbeat:Connect(function()
		if not Fx.alive or not Fx.config.AcceptPush or hum.Parent == nil or hum.Health <= 0 or os.clock() - t0 >= dur then
			release()
			return
		end
		if not Fx.freezeRelease then
			hum.WalkSpeed = slowed
		end
	end)
end

-- spin = orbit a point (tornado) while rising a bit | lift = float upward and hover. both timed, capped, with a cooldown
local function mechMotion(kind, dur, pos, p)
	if not Fx.config.AcceptPush or not pos then
		return
	end
	local now = os.clock()
	local m = Fx.motion
	if m then
		if m.kind == kind then
			m.untilT = math.min(m.t0 + Fx.config.MotionMax, math.max(m.untilT, now + dur))
			m.pos = pos
		end
		return
	end
	if Fx.freezeRelease or now < Fx.motionLock then
		return
	end
	local c = Players.LocalPlayer.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	local start = root.Position
	local off = Vector3.new(start.X - pos.X, 0, start.Z - pos.Z)
	m = {
		kind = kind,
		t0 = now,
		untilT = now + math.min(dur, Fx.config.MotionMax),
		pos = pos,
		ang = off.Magnitude > 0.1 and math.atan2(off.Z, off.X) or 0,
		h = 0,
		rNow = math.min(off.Magnitude, Fx.config.SpinRadiusMax),
		rGoal = math.clamp(tonumber(p.r) or 10, 3, Fx.config.SpinRadiusMax),
		w = math.clamp(tonumber(p.w) or 3, 0.5, 5),
		up = math.clamp(tonumber(p.up) or (kind == "lift" and 8 or 3), 0, 10),
	}
	m.w = math.min(m.w, Fx.config.MotionSpeed * 0.8 / m.rGoal)
	Fx.motion = m
	local lastState = 0
	local conn
	local function finish()
		if not conn then
			return
		end
		conn:Disconnect()
		conn = nil
		Fx.motion = nil
		Fx.motionLock = os.clock() + Fx.config.MotionCooldown
		if kind == "spin" and root.Parent then
			local tangent = Vector3.new(-math.sin(m.ang), 0, math.cos(m.ang)) * m.w * m.rNow
			if tangent.Magnitude > 14 then
				tangent = tangent.Unit * 14
			end
			root.AssemblyLinearVelocity = Vector3.new(tangent.X, 4, tangent.Z)
		end
	end
	Fx.motionRelease = finish
	conn = RunService.Heartbeat:Connect(function(dt)
		if not Fx.alive or not Fx.config.AcceptPush or not root.Parent or hum.Health <= 0 or os.clock() > m.untilT then
			finish()
			return
		end
		m.h = math.min(m.h + m.up * dt, Fx.config.LiftHeight)
		local v
		if kind == "spin" then
			m.rNow += (m.rGoal - m.rNow) * math.min(1, dt * 3)
			m.ang += m.w * dt
			local tgt = Vector3.new(m.pos.X + math.cos(m.ang) * m.rNow, start.Y + m.h, m.pos.Z + math.sin(m.ang) * m.rNow)
			v = (tgt - root.Position) * 8
		else
			local cur = root.AssemblyLinearVelocity
			v = Vector3.new(cur.X * 0.9, (start.Y + m.h - root.Position.Y) * 6, cur.Z * 0.9)
		end
		if v.Magnitude > Fx.config.MotionSpeed then
			v = v.Unit * Fx.config.MotionSpeed
		end
		root.AssemblyLinearVelocity = v
		if os.clock() - lastState > 0.3 then
			lastState = os.clock()
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end)
		end
	end)
end

function Fx.applyStatus(uid, d, from)
	if type(uid) ~= "number" or type(d) ~= "table" or type(d.n) ~= "string" then
		return
	end
	local plr = Players:GetPlayerByUserId(uid)
	local char = plr and plr.Character
	if not char then
		return
	end
	local mine = uid == myId()
	local dur = tonumber(d.t) or 1
	if d.n == "freeze" then
		dur = math.clamp(dur, 0.1, Fx.config.FreezeMax)
		if d.nv ~= 1 then
			visualFreeze(char, dur)
		end
		if mine then
			mechFreeze(char, dur)
		end
	elseif d.n == "burn" then
		dur = math.clamp(dur, 0.1, Fx.config.BurnMax)
		if d.nv ~= 1 then
			visualBurn(char, dur)
		end
	elseif d.n == "pull" then
		dur = math.clamp(dur, 0.1, 3)
		if mine then
			mechPull(dur, Fx.unvec(d.pos), tonumber(d.s))
		end
	elseif d.n == "spin" or d.n == "lift" then
		if mine then
			local pos = Fx.unvec(d.pos) or (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position)
			mechMotion(d.n, dur, pos, { r = d.r, w = d.s, up = d.up })
		end
	elseif d.n == "slow" then
		if mine then
			mechSlow(dur, d.f)
		end
	elseif d.n == "glow" then
		visualGlow(char, math.clamp(dur, 0.1, 6), d.c)
	elseif d.n == "shock" then
		visualShock(char, math.clamp(dur, 0.1, 6))
	elseif d.n == "blind" or d.n == "shake" then
		if mine then
			mechScreen(d.n, dur)
		end
	end
end

--// ---------- sending ----------

local function nextKey()
	Fx.seq += 1
	local ms = math.floor(DateTime.now().UnixTimestampMillis)
	return string.format("%013d_%d_%05d", ms, myId(), Fx.seq % 100000)
end

function Fx.emit(id, kind, data, targetUserId)
	if not Fx.ready() or type(id) ~= "string" or type(kind) ~= "string" then
		return
	end
	local ab = Fx.abilities[id]
	local path = (ab and ab.path) or Fx.currentPath
	if path and Fx.muted[path] then
		return
	end
	if #Fx.outbox > 40 then
		return
	end
	local ev = { a = string.sub(id, 1, 40), k = string.sub(kind, 1, 16), u = myId(), d = clean(data or {}, 0) or {} }
	if type(path) == "string" and #path <= 200 then
		ev.p = path
	end
	if type(targetUserId) == "number" then
		ev.tu = targetUserId
	end
	table.insert(Fx.outbox, { key = nextKey(), ev = ev })
end

function Fx.push(targetUserId, dir, strength, id)
	if type(targetUserId) ~= "number" or targetUserId == myId() or typeof(dir) ~= "Vector3" then
		return
	end
	strength = math.clamp(tonumber(strength) or 0, 0, Fx.config.PushMax)
	Fx.emit(id or "push", "push", { dir = Fx.vec(dir), s = strength }, targetUserId)
end

-- status on a player. name = freeze burn pull spin lift slow glow shock blind shake. data: { nv = 1 } hides the built-in visuals, pull needs { pos = Fx.vec(p), s = speed }
function Fx.status(targetUserId, name, dur, data, id)
	if type(targetUserId) ~= "number" or type(name) ~= "string" or targetUserId == myId() then
		return
	end
	local d = clean(data or {}, 0) or {}
	d.n = string.sub(name, 1, 12)
	d.t = math.clamp(tonumber(dur) or 1, 0.1, 6)
	Fx.applyStatus(targetUserId, d, myId())
	Fx.emit(id or "status", "status", d, targetUserId)
end

-- one call for a whole cast: tells everyone, then applies the effects to every other player inside opts.radius
-- opts: radius, target (Player), freeze, burn, slow, glow, shock, blind, shake (seconds), pull / lift / spin (speed), pullTime, spinRadius, spinUp, spinTime, liftTime, slowFactor, glowColor, push (speed), novis (bool), data (table)
function Fx.cast(id, pos, opts)
	opts = opts or {}
	local data = { pos = Fx.vec(pos) }
	for k, v in pairs(opts.data or {}) do
		data[k] = v
	end
	Fx.emit(id, "cast", data, opts.target and opts.target.UserId or nil)
	for _, plr in ipairs(Fx.playersInRadius(pos, opts.radius or 20, false)) do
		local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local nv = opts.novis and { nv = 1 } or nil
			if opts.freeze then
				Fx.status(plr.UserId, "freeze", opts.freeze, nv, id)
			end
			if opts.burn then
				Fx.status(plr.UserId, "burn", opts.burn, nv, id)
			end
			if opts.pull then
				Fx.status(plr.UserId, "pull", opts.pullTime or 1, { pos = Fx.vec(pos), s = opts.pull }, id)
			end
			if opts.spin then
				Fx.status(plr.UserId, "spin", opts.spinTime or 3, { pos = Fx.vec(pos), s = opts.spin, r = opts.spinRadius or 10, up = opts.spinUp or 3 }, id)
			end
			if opts.lift then
				Fx.status(plr.UserId, "lift", opts.liftTime or 2, { pos = Fx.vec(pos), up = opts.lift }, id)
			end
			if opts.slow then
				Fx.status(plr.UserId, "slow", opts.slow, { f = opts.slowFactor or 0.4 }, id)
			end
			if opts.glow then
				Fx.status(plr.UserId, "glow", opts.glow, { c = opts.glowColor }, id)
			end
			if opts.shock then
				Fx.status(plr.UserId, "shock", opts.shock, nil, id)
			end
			if opts.blind then
				Fx.status(plr.UserId, "blind", opts.blind, nil, id)
			end
			if opts.shake then
				Fx.status(plr.UserId, "shake", opts.shake, nil, id)
			end
			if opts.push then
				Fx.push(plr.UserId, r.Position - pos, opts.push, id)
			end
		end
	end
end

local function flush()
	local sent = 0
	while #Fx.outbox > 0 and sent < 8 do
		local item = table.remove(Fx.outbox, 1)
		sent += 1
		task.spawn(function()
			if req("PUT", "/" .. item.key, item.ev) then
				Fx.sentKeys[item.key] = os.clock()
			end
		end)
	end
end

local function prune(all)
	local now = os.clock()
	local parts = {}
	for k, t in pairs(Fx.sentKeys) do
		if all or now - t > Fx.config.Ttl then
			table.insert(parts, '"' .. k .. '":null')
			Fx.sentKeys[k] = nil
		end
	end
	if #parts > 0 then
		req("PATCH", "", nil, "{" .. table.concat(parts, ",") .. "}")
	end
end

--// ---------- receiving ----------

local function runPlay(ab, pkt)
	task.spawn(function()
		local ok, err = pcall(ab.play, pkt)
		if not ok then
			Fx.log("play error " .. tostring(pkt.id) .. ": " .. tostring(err))
		end
	end)
end

local function dispatch(ev)
	if type(ev) ~= "table" then
		return
	end
	local me = myId()
	local u, a, k = ev.u, ev.a, ev.k
	if type(u) ~= "number" or u == me or type(a) ~= "string" or type(k) ~= "string" then
		return
	end
	if #a > 40 or #k > 16 then
		return
	end
	local now = os.clock()
	local rl = Fx.rate[u]
	if not rl or now - rl.t >= 1 then
		rl = { t = now, n = 0 }
		Fx.rate[u] = rl
	end
	rl.n += 1
	if rl.n > Fx.config.MaxPerSec then
		return
	end
	local d = clean(ev.d, 0) or {}
	if k == "status" then
		Fx.applyStatus(ev.tu, d, u)
		return
	end
	if k == "push" then
		if ev.tu == me then
			receivePush(u, d)
		end
		return
	end
	local pkt = {
		id = a,
		kind = k,
		casterId = u,
		caster = Players:GetPlayerByUserId(u),
		target = type(ev.tu) == "number" and ev.tu or nil,
		d = d,
	}
	local ab = Fx.abilities[a]
	if ab and ab.play then
		runPlay(ab, pkt)
	elseif type(ev.p) == "string" and Fx.onUnknown then
		local list = Fx.pending[a]
		if not list then
			list = {}
			Fx.pending[a] = list
		end
		if #list < 20 then
			table.insert(list, { pkt = pkt, t = now })
		end
		if not Fx.asked or now - (Fx.asked[a] or -99) > 15 then
			Fx.asked = Fx.asked or {}
			Fx.asked[a] = now
			task.spawn(function()
				local ok, err = pcall(Fx.onUnknown, ev.p, a)
				if not ok then
					Fx.log("load error: " .. tostring(err))
				end
			end)
		end
	end
end

local function poll()
	local ok, data = req("GET", "")
	if not ok then
		return
	end
	if type(data) ~= "table" then
		data = {}
	end
	local keys = {}
	for k in pairs(data) do
		table.insert(keys, k)
	end
	table.sort(keys)
	local first = not Fx.primed
	Fx.primed = true
	local nextSeen = {}
	for _, k in ipairs(keys) do
		nextSeen[k] = true
		if not first and not Fx.seen[k] then
			local okD, errD = pcall(dispatch, data[k])
			if not okD then
				Fx.log("dispatch error: " .. tostring(errD))
			end
		end
	end
	Fx.seen = nextSeen
end

--// ---------- abilities ----------

function Fx.register(id, handlers, path)
	if type(handlers) == "function" then
		handlers = { play = handlers }
	end
	handlers = handlers or {}
	local old = Fx.abilities[id]
	if old and old.stop then
		pcall(old.stop)
	end
	local ab = { play = handlers.play, stop = handlers.stop, path = path or Fx.currentPath, viewer = Fx.viewerOnly }
	Fx.abilities[id] = ab
	local list = Fx.pending[id]
	Fx.pending[id] = nil
	if list and ab.play then
		local now = os.clock()
		for _, item in ipairs(list) do
			if now - item.t < 12 then
				runPlay(ab, item.pkt)
			end
		end
	end
	Fx.start()
	return function()
		if Fx.abilities[id] == ab then
			Fx.unregister(id)
		end
	end
end

function Fx.unregister(id)
	local ab = Fx.abilities[id]
	if not ab then
		return
	end
	Fx.abilities[id] = nil
	if ab.stop then
		pcall(ab.stop)
	end
end

function Fx.unregisterPath(path)
	for id, ab in pairs(Fx.abilities) do
		if ab.path == path then
			Fx.unregister(id)
		end
	end
end

function Fx.hasAbility(id)
	return Fx.abilities[id] ~= nil
end

function Fx.setMuted(path, v)
	Fx.muted[path] = v and true or nil
end

function Fx.isMuted(path)
	return Fx.muted[path] == true
end

--// ---------- loops ----------

function Fx.start()
	if Fx.started or not Fx.alive then
		return
	end
	Fx.started = true
	task.spawn(function()
		while Fx.alive do
			if Fx.ready() and (Fx.listen or next(Fx.abilities) ~= nil) then
				pcall(poll)
			end
			task.wait(math.max(0.25, tonumber(Fx.config.Poll) or 0.5))
		end
	end)
	task.spawn(function()
		local pruneT = os.clock()
		while Fx.alive do
			if Fx.ready() then
				pcall(flush)
				if os.clock() - pruneT >= 5 then
					pruneT = os.clock()
					pcall(prune, false)
				end
			end
			task.wait(0.1)
		end
	end)
end

function Fx.stop()
	if not Fx.alive then
		return
	end
	for id in pairs(table.clone(Fx.abilities)) do
		Fx.unregister(id)
	end
	if Fx.freezeRelease then
		pcall(Fx.freezeRelease)
	end
	if Fx.motionRelease then
		pcall(Fx.motionRelease)
	end
	if Fx.slowRelease then
		pcall(Fx.slowRelease)
	end
	if Fx.pullConn then
		pcall(function() Fx.pullConn:Disconnect() end)
		Fx.pullState = nil
	end
	for stopVis in pairs(table.clone(Fx.cleanups)) do
		pcall(stopVis)
	end
	if Fx.visFolder then
		pcall(function() Fx.visFolder:Destroy() end)
	end
	if Fx.ready() then
		pcall(prune, true)
	end
	Fx.alive = false
	if genv.SpellsFx == Fx then
		genv.SpellsFx = nil
	end
end

genv.SpellsFx = Fx
return Fx
end)()

local Debug = { buf = {}, max = 160, t0 = os.clock() }

function Debug.fmt(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

function Debug.add(text, color)
	local e = { t = os.clock() - Debug.t0, text = tostring(text), color = color }
	table.insert(Debug.buf, e)
	if #Debug.buf > Debug.max then
		table.remove(Debug.buf, 1)
	end
	if Debug.onAdd then
		pcall(Debug.onAdd, e)
	end
end

function Debug.err(text)
	Debug.add(text, THEME.bad)
	if not State.settings.Quiet then
		warn("[spells] " .. tostring(text))
	end
end

-- print / warn handed to power and weapon scripts: quiet = they land in the debug panel instead of the console
function Debug.hooks(name)
	if State.settings.Quiet then
		return function(...)
			Debug.add("[" .. name .. "] " .. Debug.fmt(...))
		end, function(...)
			Debug.add("[" .. name .. "] " .. Debug.fmt(...), THEME.bad)
		end
	end
	return print, warn
end

local function track(conn)
	table.insert(State.connections, conn)
	return conn
end

local function cleanup()
	State.alive = false
	pcall(Fx.stop)
	for _, conn in ipairs(State.connections) do
		pcall(function() conn:Disconnect() end)
	end
	State.connections = {}
	if State.gui then
		pcall(function() State.gui:Destroy() end)
		State.gui = nil
	end
end

if getgenv then
	if getgenv().SpellsHubCleanup then
		pcall(getgenv().SpellsHubCleanup)
	end
	if getgenv().RepoHubCleanup then
		pcall(getgenv().RepoHubCleanup)
	end
	getgenv().SpellsHubCleanup = cleanup
	getgenv().RepoHubCleanup = cleanup
end

local function saveSettings()
	if not writefile then return end
	pcall(function()
		writefile(CONFIG.SettingsFile, HttpService:JSONEncode(State.settings))
	end)
end

local function loadSettings()
	if not (isfile and readfile) then return end
	pcall(function()
		if not isfile(CONFIG.SettingsFile) then return end
		local data = HttpService:JSONDecode(readfile(CONFIG.SettingsFile))
		if type(data) ~= "table" then return end
		for key, default in pairs(State.settings) do
			if type(data[key]) == type(default) then
				State.settings[key] = data[key]
			end
		end
		State.settings.Scale = math.clamp(State.settings.Scale, 0.8, 1.3)
		State.settings.ImpactPower = math.clamp(State.settings.ImpactPower, 0.1, 1)
		if type(State.settings.NoShare) ~= "table" then
			State.settings.NoShare = {}
		end
		local kc = Enum.KeyCode[State.settings.ToggleKey]
		if kc then
			State.toggleKey = kc
		else
			State.settings.ToggleKey = "RightShift"
		end
	end)
end

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 4 })
	end)
end

local function copyText(text)
	local fn = setclipboard or toclipboard
	if fn then
		return pcall(fn, text)
	end
	return false
end

local function hex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function hashString(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 4294967296
	end
	return h
end

--// ============================== net ==============================

local Net = { lastStatus = nil }
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

function Net.get(url, withAuth)
	Net.lastStatus = nil
	local headers = { ["User-Agent"] = "spells-hub" }
	if withAuth and CONFIG.Token then
		headers["Authorization"] = "Bearer " .. CONFIG.Token
	end
	if httpRequest then
		local ok, res = pcall(httpRequest, { Url = url, Method = "GET", Headers = headers })
		if ok and type(res) == "table" then
			Net.lastStatus = res.StatusCode
			if res.StatusCode == 200 and type(res.Body) == "string" then
				return res.Body
			end
			if res.StatusCode == 403 or res.StatusCode == 429 then
				return nil, "rate limited"
			end
		end
	end
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end
	return nil
end

function Net.source(entry)
	local cached = State.cache[entry.url]
	if cached then return cached end
	local body = Net.get(entry.url, false)
	if body then
		State.cache[entry.url] = body
	end
	return body
end

--// ============================== sync (npoint) + owner ==============================
--// DuaKNo edits names / abilities -> saved to an npoint bin -> every player running the hub pulls it on a timer

local Sync = { overrides = {}, last = nil, status = "local only", holdUntil = 0 }
local Owner = { ok = false }

function Sync.url()
	local id = CONFIG.Npoint and CONFIG.Npoint.BinId
	if type(id) == "string" and id ~= "" then
		return "https://api.npoint.io/" .. id
	end
	return nil
end

function Sync.apply(items)
	local clean = {}
	if type(items) == "table" then
		for key, ov in pairs(items) do
			if type(key) == "string" and type(ov) == "table" then
				local entry = {}
				if type(ov.name) == "string" and ov.name ~= "" then
					entry.name = string.sub(ov.name, 1, 40)
				end
				if type(ov.category) == "string" and ov.category ~= "" then
					entry.category = string.sub(ov.category, 1, 20)
				end
				if ov.kind == "Powers" or ov.kind == "Weapons" then
					entry.kind = ov.kind
				end
				if next(entry) then
					clean[string.lower(key)] = entry
				end
			end
		end
	end
	Sync.overrides = clean
end

-- returns true when the data changed
function Sync.pull()
	local url = Sync.url()
	if not url then
		Sync.status = "no npoint bin id set"
		return false
	end
	if os.clock() < Sync.holdUntil then
		return false
	end
	local body = Net.get(url, false)
	if not body then
		Sync.status = "sync offline"
		return false
	end
	if body == Sync.last then
		Sync.status = "synced"
		return false
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(data) ~= "table" then
		Sync.status = "bad sync data"
		return false
	end
	Sync.last = body
	Sync.apply(data.items)
	Sync.status = "synced"
	return true
end

function Sync.push()
	if not Owner.ok then
		return false, "owner only"
	end
	local url = Sync.url()
	if not url then
		Sync.status = "edit kept locally (no bin id)"
		return false, "set CONFIG.Npoint.BinId so edits reach other players"
	end
	if not httpRequest then
		return false, "this executor has no request()"
	end
	local body = HttpService:JSONEncode({ v = 1, updated = os.time(), items = Sync.overrides })
	Sync.holdUntil = os.clock() + 4
	local ok, res = pcall(httpRequest, {
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = body,
	})
	local code = ok and type(res) == "table" and res.StatusCode or nil
	if code and code >= 200 and code < 300 then
		Sync.last = body
		Sync.status = "synced"
		return true
	end
	Sync.status = "sync failed"
	return false, "npoint rejected the save (" .. tostring(code or "no response") .. ")"
end

-- name must match AND the real account behind that name must be this player
function Owner.verify()
	local lp = Players.LocalPlayer
	for _, id in ipairs(CONFIG.OwnerIds or {}) do
		if lp.UserId == id then
			return true
		end
	end
	local matched
	for _, n in ipairs(CONFIG.OwnerNames) do
		if string.lower(lp.Name) == string.lower(n) then
			matched = n
		end
	end
	if not matched then
		return false
	end
	local ok, id = pcall(function()
		return Players:GetUserIdFromNameAsync(matched)
	end)
	return ok and id == lp.UserId
end

--// ============================== repo ==============================

local Repo = {}

function Repo.encode(path)
	return (string.gsub(path, "[^%w%-%._~/]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

function Repo.validExt(name)
	local ext = string.match(name, "%.([%w_]+)$")
	if ext == nil then
		return CONFIG.AllowNoExtension
	end
	return CONFIG.Extensions[string.lower(ext)] == true
end

function Repo.scan(path, depth, out)
	local url = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(
		CONFIG.Owner, CONFIG.Repo, Repo.encode(path), CONFIG.Branch
	)
	local body, err = Net.get(url, true)
	if not body then
		return err or ("http " .. tostring(Net.lastStatus or "no response") .. " (check Owner/Repo/Branch)")
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(data) ~= "table" then
		return "bad response"
	end
	for _, item in ipairs(data) do
		if item.type == "file" then
			local isSelf = string.lower(item.path) == string.lower(CONFIG.SelfFile)
				or string.lower(item.name) == string.lower(CONFIG.SelfFile)
			if not isSelf and Repo.validExt(item.name) and item.download_url then
				table.insert(out, { name = item.name, path = item.path, url = item.download_url })
			end
		elseif item.type == "dir" and depth < CONFIG.MaxDepth then
			Repo.scan(item.path, depth + 1, out)
		end
	end
	return nil
end

function Repo.categoryColor(name)
	for _, cat in ipairs(CONFIG.Categories) do
		if cat.name == name then
			return cat.color
		end
	end
	if name ~= "General" and name ~= nil and name ~= "" then
		return Color3.fromHSV((hashString(string.lower(name)) % 360) / 360, 0.55, 1)
	end
	return CONFIG.GeneralColor
end

function Repo.build(raw)
	local out = {}
	for _, item in ipairs(raw) do
		local base = string.gsub(item.name, "%.%w+$", "")
		local key = string.lower(base)
		local meta = MetaLower[key] or {}

		local top = string.match(item.path, "^([^/]+)/")
		top = top and string.lower(top)

		local ov = Sync.overrides[string.lower(item.path)]
		local kind = (ov and ov.kind) or meta.kind
		if not kind and top then
			if CONFIG.WeaponFolders[top] then
				kind = "Weapons"
			elseif CONFIG.PowerFolders[top] then
				kind = "Powers"
			end
		end
		if not kind then
			for _, w in ipairs(CONFIG.WeaponWords) do
				if string.find(key, w, 1, true) then
					kind = "Weapons"
					break
				end
			end
		end
		kind = kind or "Powers"

		local category = (ov and ov.category) or meta.category
		if not category then
			for _, cat in ipairs(CONFIG.Categories) do
				for _, w in ipairs(cat.words) do
					if string.find(key, w, 1, true) then
						category = cat.name
						break
					end
				end
				if category then break end
			end
		end
		category = category or "General"

		local pretty = string.gsub(base, "^%d+[%s%._%-]+", "")
		pretty = string.gsub(pretty, "_", " ")
		if pretty == "" then pretty = base end
		if ov and ov.name then pretty = ov.name end

		table.insert(out, {
			name = pretty,
			file = item.name,
			path = item.path,
			url = item.url,
			kind = kind,
			category = category,
			color = (not (ov and ov.category) and meta.color) or Repo.categoryColor(category),
			desc = meta.desc,
			seed = hashString(item.path),
			key = string.lower(item.path),
			edited = ov ~= nil,
			info = nil,
		})
	end
	return out
end

local function describeSource(src)
	local parts = {}
	for line in string.gmatch(string.sub(src, 1, 1500), "[^\r\n]+") do
		local c = string.match(line, "^%s*%-%-+%s*/*%s*(.-)%s*$")
		if c == nil then
			if string.match(line, "^%s*$") then
				continue
			end
			break
		end
		if string.sub(c, 1, 1) == "[" then
			break
		end
		if c ~= "" and not string.match(c, "^[=%-_#%*]+$") then
			table.insert(parts, c)
		end
		if #parts >= 2 then break end
	end
	local text = table.concat(parts, " ")
	if #text > 170 then
		text = string.sub(text, 1, 167) .. "..."
	end
	return text
end

--// ============================== ui helpers ==============================

local function new(class, props)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if inst:IsA("GuiButton") then
		inst.AutoButtonColor = false
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		inst.Text = ""
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function tw(obj, props, t, style, dir)
	if not State.settings.Animations then
		t = 0
	end
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

local function apply(inst, props, instant, t)
	if instant then
		for k, v in pairs(props) do
			inst[k] = v
		end
	else
		tw(inst, props, t or 0.16)
	end
end

local function corner(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function newGroup(props)
	local ok, g = pcall(Instance.new, "CanvasGroup")
	if not ok then
		g = Instance.new("Frame")
	end
	g.BorderSizePixel = 0
	local parent
	for k, v in pairs(props) do
		if k == "Parent" then parent = v else g[k] = v end
	end
	g.Parent = parent
	return g
end

local function fadeGroup(g, value, t)
	if g:IsA("CanvasGroup") then
		tw(g, { GroupTransparency = value }, t or 0.25)
	end
end

local function setGroup(g, value)
	if g:IsA("CanvasGroup") then
		g.GroupTransparency = value
	end
end

local function bar(parent, w, h, x, y, rot, color)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, x, 0.5, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rot or 0,
		BackgroundColor3 = color,
		Parent = parent,
	})
end

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(800, 400)
end

-- squish on press, soft white flash on click
local function pressFx(btn)
	local sc = new("UIScale", { Parent = btn })
	track(btn.MouseButton1Down:Connect(function()
		tw(sc, { Scale = 0.965 }, 0.08)
	end))
	local function release()
		tw(sc, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
	end
	track(btn.MouseButton1Up:Connect(release))
	track(btn.MouseLeave:Connect(release))
	return sc
end

local function pulse(btn)
	local f = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		ZIndex = btn.ZIndex + 5,
		Parent = btn,
	})
	local cr = btn:FindFirstChildOfClass("UICorner")
	if cr then
		corner(f, cr.CornerRadius.Offset)
	end
	local t = tw(f, { BackgroundTransparency = 1 }, 0.4)
	t.Completed:Connect(function()
		f:Destroy()
	end)
end

--// ============================== accent ==============================

local Accent = { color = THEME.accents.Powers, fns = {} }
local accentValue = Instance.new("Color3Value")
accentValue.Value = Accent.color

function Accent.bind(fn)
	table.insert(Accent.fns, fn)
	fn(Accent.color)
	return fn
end

track(accentValue.Changed:Connect(function(c)
	Accent.color = c
	for _, fn in ipairs(Accent.fns) do
		fn(c)
	end
end))

function Accent.set(c, instant)
	if instant then
		accentValue.Value = c
	else
		tw(accentValue, { Value = c }, 0.45)
	end
end

--// ============================== runner ==============================

local Runner = { busy = false, busyPath = nil, listeners = {} }
local UI = {}

local function status(text, color)
	if UI.setStatus then
		UI.setStatus(text, color)
	end
end

local function fire()
	for _, fn in ipairs(Runner.listeners) do
		pcall(fn)
	end
end

local function snapshot()
	local set = {}
	local lp = Players.LocalPlayer
	local function take(root, tools, guis)
		if not root then return end
		for _, c in ipairs(root:GetChildren()) do
			if tools and (c:IsA("Tool") or c:IsA("HopperBin")) then
				set[c] = true
			elseif guis and c:IsA("ScreenGui") and c ~= State.gui then
				set[c] = true
			end
		end
	end
	take(lp:FindFirstChildOfClass("Backpack"), true, false)
	take(lp.Character, true, false)
	take(lp:FindFirstChildOfClass("PlayerGui"), false, true)
	take(CoreGui, false, true)
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then
			take(h, false, true)
		end
	end
	return set
end

local function chunkSource(f)
	local ok, s = pcall(function()
		return debug.info(f, "s")
	end)
	if ok and type(s) == "string" then
		return s
	end
	if getinfo then
		local ok2, info = pcall(getinfo, f)
		if ok2 and type(info) == "table" then
			return info.source
		end
	end
	return nil
end

local function signalList()
	local sigs = {}
	local function add(sig)
		if sig then
			table.insert(sigs, sig)
		end
	end
	pcall(function()
		add(RunService.Heartbeat)
		add(RunService.RenderStepped)
		add(RunService.Stepped)
	end)
	pcall(function() add(RunService.PreSimulation) end)
	pcall(function() add(RunService.PostSimulation) end)
	pcall(function() add(RunService.PreRender) end)
	pcall(function() add(RunService.PreAnimation) end)
	pcall(function()
		add(workspace.DescendantAdded)
		add(workspace.ChildAdded)
		add(Players.PlayerAdded)
		add(Players.PlayerRemoving)
	end)
	pcall(function()
		add(UserInputService.TouchStarted)
		add(UserInputService.TouchEnded)
		add(UserInputService.TouchMoved)
		add(UserInputService.TouchTap)
		add(UserInputService.InputBegan)
		add(UserInputService.InputEnded)
		add(UserInputService.InputChanged)
		add(UserInputService.JumpRequest)
	end)
	pcall(function()
		local lp = Players.LocalPlayer
		add(lp.CharacterAdded)
		add(lp.CharacterRemoving)
		add(lp.Chatted)
		local mouse = lp:GetMouse()
		add(mouse.Button1Down)
		add(mouse.Button1Up)
		add(mouse.Button2Down)
		add(mouse.Button2Up)
		add(mouse.Move)
		add(mouse.KeyDown)
		add(mouse.KeyUp)
		local bp = lp:FindFirstChildOfClass("Backpack")
		if bp then
			add(bp.ChildAdded)
			add(bp.ChildRemoved)
		end
		local ch = lp.Character
		if ch then
			local hum = ch:FindFirstChildOfClass("Humanoid")
			if hum then
				add(hum.Died)
				add(hum.StateChanged)
				add(hum.Running)
				add(hum.Jumping)
				add(hum.HealthChanged)
			end
			add(ch.DescendantAdded)
			add(ch.ChildAdded)
		end
	end)
	return sigs
end

local function killConnections(src)
	if not src or not getconnections then return end
	for _, sig in ipairs(signalList()) do
		local ok, conns = pcall(getconnections, sig)
		if ok and type(conns) == "table" then
			for _, conn in ipairs(conns) do
				local f = conn.Function
				if f and chunkSource(f) == src then
					pcall(function() conn:Disconnect() end)
				end
			end
		end
	end
end

local function killThreads(src)
	if not src or not getgc then return end
	local ok, objs = pcall(getgc, true)
	if not ok or type(objs) ~= "table" then return end
	local me = coroutine.running()
	for _, o in ipairs(objs) do
		if type(o) == "thread" and o ~= me then
			for level = 0, 6 do
				local okInfo, s = pcall(function()
					return debug.info(o, level, "s")
				end)
				if not okInfo or s == nil then
					break
				end
				if s == src then
					pcall(task.cancel, o)
					break
				end
			end
		end
	end
end

--// camera + character state, so a stopped script cannot leave you frozen or zoomed
local function captureWorld()
	local w = {}
	local cam = workspace.CurrentCamera
	if cam then
		w.fov, w.camType, w.subject = cam.FieldOfView, cam.CameraType, cam.CameraSubject
	end
	local ch = Players.LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		w.hum = hum
		w.ws, w.jp, w.jh = hum.WalkSpeed, hum.JumpPower, hum.JumpHeight
	end
	return w
end

local function restoreWorld(w)
	if not w then return end
	local cam = workspace.CurrentCamera
	if cam and w.fov then
		pcall(function()
			cam.FieldOfView = w.fov
			cam.CameraType = w.camType
			if w.subject and w.subject.Parent then
				cam.CameraSubject = w.subject
			end
		end)
	end
	local hum = w.hum
	if hum and hum.Parent then
		pcall(function()
			local root = hum.Parent:FindFirstChild("HumanoidRootPart")
			if hum.WalkSpeed == 0 and (w.ws or 0) > 0 then
				hum.WalkSpeed = w.ws
				if (w.jp or 0) > 0 then hum.JumpPower = w.jp end
				if (w.jh or 0) > 0 then hum.JumpHeight = w.jh end
				hum.AutoRotate = true
				if root and root.Anchored then root.Anchored = false end
			end
		end)
	end
end

--// gives the script its own Instance.new and task.* that record what it makes. everything else passes straight through.
local function sandbox(fn, run)
	if not (getfenv and setfenv) then return false end
	local okBase, base = pcall(getfenv, fn)
	if not okBase or type(base) ~= "table" then return false end

	local realTask, realInstance = task, Instance
	local made = 0

	local function keep(th)
		if th then run.threads[th] = true end
		return th
	end

	local taskProxy = setmetatable({
		spawn = function(f, ...) return keep(realTask.spawn(f, ...)) end,
		defer = function(f, ...) return keep(realTask.defer(f, ...)) end,
		delay = function(t, f, ...) return keep(realTask.delay(t, f, ...)) end,
	}, { __index = realTask })

	local function prune()
		local now = os.clock()
		for inst, born in pairs(run.instances) do
			local ok, parent = pcall(function() return inst.Parent end)
			if not ok or (parent == nil and now - born > 5) then
				run.instances[inst] = nil
			end
		end
	end

	local instProxy = setmetatable({
		new = function(class, parent)
			local inst = realInstance.new(class)
			run.instances[inst] = os.clock()
			made += 1
			if made % 1000 == 0 then
				realTask.defer(prune)
			end
			if parent ~= nil then
				inst.Parent = parent
			end
			return inst
		end,
	}, { __index = realInstance })

	local env = setmetatable({ task = taskProxy, Instance = instProxy }, { __index = base, __newindex = base })
	return (pcall(setfenv, fn, env))
end

local function destroyAll(set)
	for inst in pairs(set) do
		pcall(function()
			if inst:IsA("Sound") then inst:Stop() end
			if inst:IsA("ParticleEmitter") then inst.Enabled = false end
		end)
	end
	for inst in pairs(set) do
		pcall(function() inst:Destroy() end)
	end
end

local function finalizeRun(run)
	if run.finalized then return end
	run.finalized = true
	local after = snapshot()
	for inst in pairs(after) do
		if not run.before[inst] then
			run.created[inst] = true
		end
	end
	run.before = nil
end

local function stopRun(run)
	State.runs[run.entry.path] = nil
	pcall(Fx.unregisterPath, run.entry.path)
	finalizeRun(run)
	run.stopped = true
	-- 1. stop every loop the script started
	for th in pairs(run.threads) do
		pcall(task.cancel, th)
	end
	killThreads(run.source)
	-- 2. cut its events so nothing re-triggers
	killConnections(run.source)
	-- 3. remove everything it created
	destroyAll(run.instances)
	destroyAll(run.created)
	run.instances, run.created = {}, {}
	-- 4. put camera + character back, unless another script is still running
	if next(State.runs) == nil then
		restoreWorld(run.world)
	end
end

function Runner.isActive(entry)
	return State.runs[entry.path] ~= nil
end

function Runner.count()
	local n = 0
	for _ in pairs(State.runs) do
		n += 1
	end
	return n
end

function Runner.stop(entry, silent)
	local run = State.runs[entry.path]
	if not run then return false end
	stopRun(run)
	if not silent then
		status("removed " .. entry.name)
		fire()
	end
	return true
end

function Runner.stopAll(silent)
	local list = {}
	for _, run in pairs(State.runs) do
		table.insert(list, run)
	end
	for _, run in ipairs(list) do
		stopRun(run)
	end
	if not silent then
		status(#list > 0 and "dispelled everything" or "nothing active")
		fire()
	end
	return #list > 0
end

function Runner.run(entry)
	if Runner.busy then return end
	Runner.busy, Runner.busyPath = true, entry.path
	fire()
	status("fetching " .. entry.name .. "...")

	local src = Net.source(entry)
	if not src then
		Runner.busy, Runner.busyPath = false, nil
		status("fetch failed: " .. entry.name, THEME.bad)
		notify("Tools Hub", "failed to fetch " .. entry.name)
		fire()
		return
	end

	local fn, compileErr = loadstring("local print, warn = ...; " .. src, "=spellshub_" .. entry.file)
	if not fn then
		Runner.busy, Runner.busyPath = false, nil
		status("compile error: " .. entry.name, THEME.bad)
		notify("Tools Hub", "compile error in " .. entry.name)
		Debug.err("compile " .. entry.name .. ": " .. tostring(compileErr))
		fire()
		return
	end

	if State.settings.Stack then
		Runner.stop(entry, true)
	else
		Runner.stopAll(true)
	end

	local run = {
		entry = entry,
		threads = setmetatable({}, { __mode = "k" }),
		instances = {}, -- strong on purpose: a weak table can lose live instances
		created = {},
		before = snapshot(),
		world = captureWorld(),
		source = chunkSource(fn),
		finalized = false,
	}
	if not sandbox(fn, run) then
		Debug.add("this executor has no setfenv, cleanup uses the basic mode")
	end
	State.runs[entry.path] = run
	Fx.currentPath = entry.path
	Fx.viewerOnly = false

	local th = task.spawn(function()
		local hp, hw = Debug.hooks(entry.name)
		local ok, runErr = pcall(fn, hp, hw)
		if ok then
			status("running " .. entry.name, THEME.good)
		else
			status("runtime error: " .. entry.name, THEME.bad)
			notify("Tools Hub", "runtime error in " .. entry.name)
			Debug.err("runtime " .. entry.name .. ": " .. tostring(runErr))
		end
	end)
	run.threads[th] = true

	task.delay(CONFIG.SettleTime, function()
		if State.runs[entry.path] == run then
			finalizeRun(run)
		end
	end)

	Runner.busy, Runner.busyPath = false, nil
	fire()
end

--// ============================== fx sync (custom firebase) ==============================
--// the hub owns the connection. powers and weapons talk to it through getgenv().SpellsFx (see FxNet header)
--// events carry only numbers and strings. a viewer replays with its own copy of the script from its own repo scan

local FxGlue = { bad = {}, loading = {}, lastStatus = nil }

function FxGlue.apply()
	local c = CONFIG.Fx or {}
	for path in pairs(State.settings.NoShare) do
		Fx.setMuted(path, true)
	end
	Fx.configure({
		Url = c.Url or "",
		Auth = c.Auth,
		Poll = c.PollSeconds or 0.5,
		Enabled = State.settings.Live == true,
		AcceptPush = State.settings.Impact == true,
		PushScale = math.clamp((State.settings.ImpactPower or 0.5) * 2, 0.2, 2),
	})
end

function FxGlue.isShared(entry)
	return not State.settings.NoShare[entry.path]
end

function FxGlue.setShare(entry, v)
	if v then
		State.settings.NoShare[entry.path] = nil
	else
		State.settings.NoShare[entry.path] = true
	end
	Fx.setMuted(entry.path, not v)
	saveSettings()
	Debug.add("share " .. entry.name .. ": " .. (v and "on" or "off"))
end

-- another player used a power this client has not loaded: load the viewer copy from our own repo scan
function FxGlue.load(path)
	if FxGlue.bad[path] or FxGlue.loading[path] or not loadstring then return end
	local entry
	for _, e in ipairs(State.entries or {}) do
		if e.path == path then
			entry = e
			break
		end
	end
	if not entry then
		FxGlue.bad[path] = true
		Fx.log("ignored path not in this repo: " .. tostring(path))
		return
	end
	FxGlue.loading[path] = true
	local src = Net.source(entry)
	FxGlue.loading[path] = nil
	if not src or not string.find(src, "SpellsFx", 1, true) then
		FxGlue.bad[path] = true
		Fx.log(entry.name .. " has no fx support, skipped")
		return
	end
	local fn, err = loadstring("local print, warn = ...; " .. src, "=spellsfx_" .. entry.file)
	if not fn then
		FxGlue.bad[path] = true
		Fx.log("compile error in " .. entry.name .. ": " .. tostring(err))
		return
	end
	Fx.currentPath = path
	Fx.viewerOnly = true
	task.spawn(function()
		local hp, hw = Debug.hooks(entry.name)
		local ok, runErr = pcall(fn, hp, hw)
		if not ok then
			Fx.log("viewer error in " .. entry.name .. ": " .. tostring(runErr))
		end
	end)
	Fx.viewerOnly = false
	Fx.log("viewer copy loaded: " .. entry.name)
end

function FxGlue.start()
	if FxGlue.started then return end
	FxGlue.started = true
	Fx.onLog = function(text)
		Debug.add("fx: " .. text)
	end
	Fx.onUnknown = FxGlue.load
	Fx.listen = true
	FxGlue.apply()
	task.spawn(function()
		while State.alive do
			local st = Fx.status
			if st ~= FxGlue.lastStatus then
				FxGlue.lastStatus = st
				Debug.add("fx: " .. tostring(st), st == "connected" and THEME.good or nil)
				if string.find(st, "error") or string.find(st, "no response") then
					notify("Tools Hub fx", st)
				end
			end
			if not Fx.ready() and not FxGlue.warnedOff then
				FxGlue.warnedOff = true
				Debug.add("fx: off (turn on Live sync in Settings and set CONFIG.Fx.Url)", THEME.bad)
			end
			task.wait(1)
		end
	end)
end


--// ============================== icons ==============================

local function ring(parent, d, x, y, color, thick)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, x, 0.5, y),
		Size = UDim2.fromOffset(d, d),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	corner(f, math.ceil(d / 2))
	stroke(f, color, thick or 1.25)
	return f
end

local function disc(parent, d, x, y, color)
	local f = bar(parent, d, d, x, y, 0, color)
	corner(f, math.ceil(d / 2))
	return f
end

local function sq(parent, d, rot, color, thick)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(d, d),
		Rotation = rot,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	stroke(f, color, thick or 1.25)
	return f
end

local function radial(h, count, r, len, th, color, offsetDeg)
	for i = 0, count - 1 do
		local deg = (i * 360 / count) + (offsetDeg or 0)
		local a = math.rad(deg)
		bar(h, th, len, math.cos(a) * r, math.sin(a) * r, deg - 90, color)
	end
end

--// one little emblem per ability, drawn only with frames. s = icon size, c = colour
local Glyphs = {}

Glyphs.ice = function(h, s, c)
	for _, r in ipairs({ 0, 60, 120 }) do
		bar(h, s * 0.62, 2, 0, 0, r, c)
	end
	for r = 0, 300, 60 do
		local a = math.rad(r)
		bar(h, 3, 3, math.cos(a) * s * 0.31, math.sin(a) * s * 0.31, 45, c)
	end
end

Glyphs.fire = function(h, s, c)
	ring(h, s * 0.34, 0, s * 0.1, c, 1.5)
	bar(h, s * 0.2, s * 0.2, 0, -s * 0.15, 45, c)
	bar(h, 3, 3, 0, s * 0.1, 45, c)
	bar(h, 2, 2, -s * 0.24, -s * 0.1, 45, c)
	bar(h, 2, 2, s * 0.24, -s * 0.02, 45, c)
end

Glyphs.water = function(h, s, c)
	ring(h, s * 0.34, 0, s * 0.08, c, 1.5)
	bar(h, s * 0.2, s * 0.2, 0, -s * 0.15, 45, c)
	bar(h, s * 0.16, 2, 0, s * 0.08, 0, c)
	bar(h, s * 0.1, 2, 0, s * 0.15, 0, c)
end

Glyphs.storm = function(h, s, c)
	bar(h, 3, s * 0.34, s * 0.09, -s * 0.17, 28, c)
	bar(h, s * 0.26, 3, 0, 0, 0, c)
	bar(h, 3, s * 0.34, -s * 0.09, s * 0.17, 28, c)
end

Glyphs.wind = function(h, s, c)
	bar(h, s * 0.5, 2, -s * 0.04, -s * 0.15, 0, c)
	bar(h, s * 0.62, 2, 0, 0, 0, c)
	bar(h, s * 0.4, 2, s * 0.06, s * 0.15, 0, c)
	ring(h, 6, s * 0.25, -s * 0.15, c, 1.25)
	ring(h, 6, -s * 0.28, s * 0.15, c, 1.25)
end

Glyphs.earth = function(h, s, c)
	bar(h, s * 0.58, 3, 0, s * 0.15, 0, c)
	bar(h, s * 0.44, 3, 0, 0, 0, c)
	bar(h, s * 0.3, 3, 0, -s * 0.15, 0, c)
	bar(h, 4, 4, 0, -s * 0.27, 45, c)
end

Glyphs.nature = function(h, s, c)
	local leaf = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(s * 0.3, s * 0.52),
		Rotation = 35,
		BackgroundTransparency = 1,
		Parent = h,
	})
	corner(leaf, s)
	stroke(leaf, c, 1.5)
	bar(h, 2, s * 0.52, 0, 0, 35, c)
end

Glyphs.light = function(h, s, c)
	ring(h, s * 0.22, 0, 0, c, 1.5)
	disc(h, 4, 0, 0, c)
	radial(h, 8, s * 0.3, s * 0.12, 2, c)
end

Glyphs.dark = function(h, s, c)
	ring(h, s * 0.4, -s * 0.04, 0, c, 1.5)
	ring(h, s * 0.32, s * 0.08, 0, c, 1.25)
	disc(h, 3, -s * 0.04, 0, c)
end

Glyphs.void = function(h, s, c)
	ring(h, s * 0.5, 0, 0, c, 1.25)
	ring(h, s * 0.32, 0, 0, c, 1.25)
	ring(h, s * 0.14, 0, 0, c, 1.25)
	disc(h, 3, 0, 0, c)
end

Glyphs.blood = function(h, s, c)
	ring(h, s * 0.3, 0, s * 0.1, c, 1.5)
	bar(h, s * 0.18, s * 0.18, 0, -s * 0.12, 45, c)
	bar(h, 2, 6, 0, s * 0.1, 0, c)
	bar(h, 6, 2, 0, s * 0.1, 0, c)
end

Glyphs.poison = function(h, s, c)
	ring(h, s * 0.42, 0, -s * 0.04, c, 1.5)
	disc(h, 4, -s * 0.07, -s * 0.05, c)
	disc(h, 4, s * 0.07, -s * 0.05, c)
	bar(h, s * 0.16, 2, 0, s * 0.2, 0, c)
	bar(h, 2, 4, -s * 0.04, s * 0.2, 0, c)
	bar(h, 2, 4, s * 0.04, s * 0.2, 0, c)
end

Glyphs.gravity = function(h, s, c)
	ring(h, s * 0.46, 0, 0, c, 1.25)
	ring(h, s * 0.18, 0, 0, c, 1.25)
	for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
		bar(h, 3, 3, d[1] * s * 0.3, d[2] * s * 0.3, 45, c)
	end
end

Glyphs.time = function(h, s, c)
	ring(h, s * 0.46, 0, 0, c, 1.5)
	bar(h, 2, s * 0.18, 0, -s * 0.08, 0, c)
	bar(h, s * 0.14, 2, s * 0.06, 0, 0, c)
	radial(h, 4, s * 0.27, 3, 2, c)
end

Glyphs.space = function(h, s, c)
	ring(h, s * 0.28, 0, 0, c, 1.5)
	bar(h, s * 0.64, 1.5, 0, 0, -25, c)
	disc(h, 3, -s * 0.24, -s * 0.2, c)
	disc(h, 2, s * 0.25, s * 0.22, c)
end

Glyphs.psychic = function(h, s, c)
	local eye = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(s * 0.62, s * 0.32),
		BackgroundTransparency = 1,
		Parent = h,
	})
	corner(eye, s)
	stroke(eye, c, 1.5)
	ring(h, s * 0.14, 0, 0, c, 1.5)
	disc(h, 3, 0, 0, c)
end

Glyphs.sound = function(h, s, c)
	local hs = { 0.18, 0.34, 0.5, 0.34, 0.18 }
	for i, v in ipairs(hs) do
		bar(h, 2.5, s * v, (i - 3) * s * 0.12, 0, 0, c)
	end
end

Glyphs.metal = function(h, s, c)
	sq(h, s * 0.4, 0, c, 1.5)
	sq(h, s * 0.4, 45, c, 1.5)
	disc(h, 3, 0, 0, c)
end

Glyphs.magma = function(h, s, c)
	bar(h, 3, s * 0.4, -s * 0.1, -s * 0.02, 28, c)
	bar(h, 3, s * 0.4, s * 0.1, -s * 0.02, -28, c)
	bar(h, s * 0.5, 2, 0, s * 0.18, 0, c)
	bar(h, 3, 3, 0, -s * 0.24, 45, c)
	bar(h, 2, 2, s * 0.16, -s * 0.22, 45, c)
end

Glyphs.sand = function(h, s, c)
	bar(h, s * 0.5, 2, -s * 0.04, s * 0.1, -8, c)
	bar(h, s * 0.4, 2, s * 0.06, -s * 0.02, 8, c)
	bar(h, s * 0.5, 2, -s * 0.03, -s * 0.14, -8, c)
	disc(h, 2, s * 0.22, s * 0.22, c)
	disc(h, 2, -s * 0.24, -s * 0.24, c)
end

Glyphs.magic = function(h, s, c)
	ring(h, s * 0.5, 0, 0, c, 1.25)
	for _, r in ipairs({ 0, 60, 120 }) do
		bar(h, s * 0.46, 1.5, 0, 0, r, c)
	end
	disc(h, 3, 0, 0, c)
end

Glyphs.curse = function(h, s, c)
	ring(h, s * 0.46, 0, 0, c, 1.25)
	bar(h, s * 0.4, 2, 0, 0, 45, c)
	bar(h, s * 0.4, 2, 0, 0, -45, c)
	disc(h, 3, 0, 0, c)
end

Glyphs.spirit = function(h, s, c)
	ring(h, s * 0.34, 0, -s * 0.07, c, 1.5)
	for _, x in ipairs({ -0.1, 0, 0.1 }) do
		bar(h, 2, s * 0.16, x * s, s * 0.17, 0, c)
	end
	disc(h, 2, -s * 0.06, -s * 0.08, c)
	disc(h, 2, s * 0.06, -s * 0.08, c)
end

Glyphs.energy = function(h, s, c)
	sq(h, s * 0.4, 45, c, 1.5)
	sq(h, s * 0.18, 45, c, 1.25)
	radial(h, 4, s * 0.33, s * 0.1, 2, c)
end

Glyphs.explosion = function(h, s, c)
	bar(h, s * 0.62, 2, 0, 0, 0, c)
	bar(h, s * 0.62, 2, 0, 0, 90, c)
	bar(h, s * 0.4, 2, 0, 0, 45, c)
	bar(h, s * 0.4, 2, 0, 0, -45, c)
	ring(h, s * 0.2, 0, 0, c, 1.5)
end

Glyphs.healing = function(h, s, c)
	ring(h, s * 0.5, 0, 0, c, 1.25)
	bar(h, 3, s * 0.3, 0, 0, 0, c)
	bar(h, s * 0.3, 3, 0, 0, 0, c)
end

Glyphs.summon = function(h, s, c)
	bar(h, 5, 5, 0, -s * 0.17, 45, c)
	bar(h, 5, 5, -s * 0.15, s * 0.1, 45, c)
	bar(h, 5, 5, s * 0.15, s * 0.1, 45, c)
	ring(h, s * 0.12, 0, 0, c, 1.25)
end

Glyphs.movement = function(h, s, c)
	for _, x in ipairs({ -0.1, 0.1 }) do
		bar(h, s * 0.2, 2.5, x * s - s * 0.03, -s * 0.07, 45, c)
		bar(h, s * 0.2, 2.5, x * s - s * 0.03, s * 0.07, -45, c)
	end
end

Glyphs.combat = function(h, s, c)
	bar(h, 2.5, s * 0.62, 0, 0, 45, c)
	bar(h, 2.5, s * 0.62, 0, 0, -45, c)
	disc(h, 4, 0, 0, c)
end

Glyphs.blade = function(h, s, c)
	bar(h, math.max(2, s * 0.09), s * 0.58, 0, 0, 45, c)
	bar(h, s * 0.3, math.max(2, s * 0.07), -s * 0.1, s * 0.1, 45, c)
	bar(h, math.max(3, s * 0.1), math.max(3, s * 0.1), -s * 0.21, s * 0.21, 45, c)
end

Glyphs.ranged = function(h, s, c)
	ring(h, s * 0.4, 0, 0, c, 1.5)
	for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
		bar(h, d[1] == 0 and 2 or s * 0.16, d[2] == 0 and 2 or s * 0.16, d[1] * s * 0.3, d[2] * s * 0.3, 0, c)
	end
	disc(h, 3, 0, 0, c)
end

Glyphs.blunt = function(h, s, c)
	bar(h, 3, s * 0.52, -s * 0.03, s * 0.03, 45, c)
	bar(h, s * 0.3, s * 0.14, s * 0.13, -s * 0.13, 45, c)
end

Glyphs.general = function(h, s, c)
	local inner = sq(h, s * 0.3, 0, c, 1)
	bar(h, math.max(3, s * 0.1), math.max(3, s * 0.1), 0, 0, 45, c)
	return { inner = inner }
end

local function buildSigil(parent, size, seed, color, kind, category)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local parts = {}
	local outer = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.74, size * 0.74),
		Rotation = 45,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	stroke(outer, color, size > 40 and 1.5 or 1.25)
	parts.outer = outer

	local g = Glyphs[string.lower(category or "")]
	if not g then
		g = kind == "Weapons" and Glyphs.blade or Glyphs.general
	end
	local content = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local gp = g(content, size, color)
	if gp and gp.inner then
		parts.inner = gp.inner
	end

	local ticks = 2 + (seed % 3)
	for i = 1, ticks do
		local ang = math.rad((seed * (i * 53 + 7)) % 360)
		local r = size * 0.55
		bar(holder, 2, 2, math.cos(ang) * r, math.sin(ang) * r, 45, color)
	end

	if size >= 40 then
		local orbit = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * 1.02, size * 1.02),
			BackgroundTransparency = 1,
			Parent = holder,
		})
		bar(orbit, 4, 4, 0, -size * 0.51, 45, color)
		parts.orbit = orbit
	end
	return holder, parts
end

local function makeIcon(parent, kind)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -6),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local icon = { strokes = {}, fills = {} }
	if kind == "Powers" then
		local d = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Rotation = 45,
			BackgroundTransparency = 1,
			Parent = holder,
		})
		table.insert(icon.strokes, stroke(d, THEME.dim, 1.5))
		table.insert(icon.fills, bar(holder, 4, 4, 0, 0, 45, THEME.dim))
		for _, p in ipairs({ { 0, -10 }, { 0, 10 }, { -10, 0 }, { 10, 0 } }) do
			table.insert(icon.fills, bar(holder, 2, 2, p[1], p[2], 45, THEME.dim))
		end
	elseif kind == "Weapons" then
		-- sword: blade, pointed tip, crossguard, grip, pommel
		table.insert(icon.fills, bar(holder, 3, 15, 2.5, -2.5, 45, THEME.dim))
		table.insert(icon.fills, bar(holder, 4, 4, 8.4, -8.4, 45, THEME.dim))
		table.insert(icon.fills, bar(holder, 13, 2.5, -3, 3, 45, THEME.dim))
		table.insert(icon.fills, bar(holder, 2.5, 5, -5.6, 5.6, 45, THEME.dim))
		table.insert(icon.fills, bar(holder, 4, 4, -8.2, 8.2, 45, THEME.dim))
	else
		for i, kx in ipairs({ -4, 3, -1 }) do
			local y = (i - 2) * 6
			table.insert(icon.fills, bar(holder, 18, 2, 0, y, 0, THEME.dim))
			table.insert(icon.fills, bar(holder, 4, 6, kx, y, 0, THEME.dim))
		end
	end
	function icon.paint(c)
		for _, s in ipairs(icon.strokes) do s.Color = c end
		for _, f in ipairs(icon.fills) do f.BackgroundColor3 = c end
	end
	return icon
end

local function brackets(parent, inset, len, zindex)
	local list = {}
	local function mark(ax, ay)
		local px = ax == 0 and inset or -inset
		local py = ay == 0 and inset or -inset
		local h = new("Frame", {
			AnchorPoint = Vector2.new(ax, ay),
			Position = UDim2.new(ax, px, ay, py),
			Size = UDim2.fromOffset(len, 1),
			BackgroundColor3 = Accent.color,
			ZIndex = zindex or 3,
			Parent = parent,
		})
		local v = new("Frame", {
			AnchorPoint = Vector2.new(ax, ay),
			Position = UDim2.new(ax, px, ay, py),
			Size = UDim2.fromOffset(1, len),
			BackgroundColor3 = Accent.color,
			ZIndex = zindex or 3,
			Parent = parent,
		})
		table.insert(list, h)
		table.insert(list, v)
	end
	mark(0, 0)
	mark(1, 0)
	mark(0, 1)
	mark(1, 1)
	Accent.bind(function(c)
		for _, f in ipairs(list) do
			f.BackgroundColor3 = c
		end
	end)
end

--// ============================== small controls ==============================

local function ghostButton(parent, text, danger)
	local b = new("TextButton", {
		BackgroundColor3 = THEME.raised,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = THEME.dim,
		Text = text,
		Parent = parent,
	})
	corner(b, 3)
	local st = stroke(b, THEME.line, 1)
	pressFx(b)
	track(b.MouseEnter:Connect(function()
		local c = danger and THEME.bad or Accent.color
		tw(b, { TextColor3 = c }, 0.12)
		tw(st, { Color = c }, 0.12)
	end))
	track(b.MouseLeave:Connect(function()
		tw(b, { TextColor3 = THEME.dim }, 0.15)
		tw(st, { Color = THEME.line }, 0.15)
	end))
	track(b.Activated:Connect(function()
		pulse(b)
	end))
	return b
end


--// ============================== live debug panel ==============================

function Debug.build()
	if Debug.frame and Debug.frame.Parent then return end
	if not State.gui then return end
	local f = new("Frame", {
		Name = "SpellsDebug",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 56),
		Size = UDim2.fromOffset(300, 190),
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.04,
		ZIndex = 60,
		Visible = false,
		Parent = State.gui,
	})
	corner(f, 4)
	stroke(f, THEME.line, 1)
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = THEME.raised, ZIndex = 61, Parent = f })
	corner(head, 4)
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.soft,
		Text = "LIVE DEBUG",
		ZIndex = 62,
		Parent = head,
	})
	local function headBtn(text, x, w)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, x, 0.5, 0),
			Size = UDim2.fromOffset(w, 16),
			BackgroundColor3 = THEME.bg,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = THEME.soft,
			ZIndex = 62,
			Parent = head,
		})
		b.Text = text
		corner(b, 3)
		return b
	end
	local closeBtn = headBtn("X", -6, 20)
	local clearBtn = headBtn("CLEAR", -30, 44)
	local copyBtn = headBtn("COPY", -78, 40)
	local info = new("TextLabel", {
		Position = UDim2.fromOffset(8, 28),
		Size = UDim2.new(1, -16, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 10,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = THEME.good,
		ZIndex = 61,
		Parent = f,
	})
	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 56),
		Size = UDim2.new(1, -12, 1, -62),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = THEME.dim,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 61,
		Parent = f,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = scroll })
	Debug.frame, Debug.scroll, Debug.info = f, scroll, info
	Debug.order = 0

	local function addRow(e)
		Debug.order += 1
		local l = new("TextLabel", {
			LayoutOrder = Debug.order,
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 10,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = e.color or THEME.soft,
			ZIndex = 62,
			Parent = scroll,
		})
		l.Text = string.format("%5.1f  %s", e.t, e.text)
		local kids = {}
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("TextLabel") then table.insert(kids, c) end
		end
		if #kids > Debug.max then
			table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			kids[1]:Destroy()
		end
		task.defer(function()
			if scroll.Parent then
				scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y))
			end
		end)
	end
	for _, e in ipairs(Debug.buf) do addRow(e) end
	Debug.onAdd = function(e)
		if f.Visible then addRow(e) end
	end

	track(closeBtn.Activated:Connect(function()
		State.settings.Debug = false
		saveSettings()
		Debug.setVisible(false)
	end))
	track(clearBtn.Activated:Connect(function()
		Debug.buf = {}
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("TextLabel") then c:Destroy() end
		end
	end))
	track(copyBtn.Activated:Connect(function()
		local lines = {}
		for _, e in ipairs(Debug.buf) do
			table.insert(lines, string.format("%.1f %s", e.t, e.text))
		end
		copyText(table.concat(lines, "\n"))
	end))

	local drag
	track(head.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			drag = { start = input.Position, pos = f.Position }
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - drag.start
			f.Position = UDim2.new(drag.pos.X.Scale, drag.pos.X.Offset + d.X, drag.pos.Y.Scale, drag.pos.Y.Offset + d.Y)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			drag = nil
		end
	end))

	task.spawn(function()
		while State.alive and f.Parent do
			if f.Visible then
				local count = 0
				for _ in pairs(Fx.abilities) do
					count += 1
				end
				info.Text = string.format("fx:%s abilities:%d\n%s", Fx.ready() and "on" or "off", count, tostring(Fx.status))
			end
			task.wait(0.5)
		end
	end)
end

function Debug.setVisible(v)
	if v then
		Debug.build()
	end
	if Debug.frame and Debug.frame.Parent then
		Debug.frame.Visible = v and true or false
		if v then
			for _, c in ipairs(Debug.scroll:GetChildren()) do
				if c:IsA("TextLabel") then c:Destroy() end
			end
			Debug.order = 0
			local old = Debug.onAdd
			Debug.onAdd = nil
			for _, e in ipairs(Debug.buf) do
				Debug.order += 1
				local l = new("TextLabel", {
					LayoutOrder = Debug.order,
					Size = UDim2.new(1, -4, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Font = Enum.Font.Code,
					TextSize = 10,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = e.color or THEME.soft,
					ZIndex = 62,
					Parent = Debug.scroll,
				})
				l.Text = string.format("%5.1f  %s", e.t, e.text)
			end
			Debug.onAdd = old
		end
	end
end

local function makeToggle(parent, initial, onChange)
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(36, 18),
		BackgroundColor3 = THEME.raised,
		Parent = parent,
	})
	corner(btn, 3)
	local st = stroke(btn, THEME.line, 1)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(0, 3, 0.5, -6),
		BackgroundColor3 = THEME.dim,
		Parent = btn,
	})
	corner(knob, 2)
	local value = initial
	local function paint(animated)
		local pos = value and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
		local kc = value and Accent.color or THEME.dim
		local sc = value and Accent.color or THEME.line
		if animated then
			tw(knob, { Position = pos, BackgroundColor3 = kc }, 0.18)
			tw(st, { Color = sc }, 0.18)
		else
			knob.Position = pos
			knob.BackgroundColor3 = kc
			st.Color = sc
		end
	end
	paint(false)
	Accent.bind(function()
		paint(false)
	end)
	track(btn.Activated:Connect(function()
		value = not value
		paint(true)
		onChange(value)
	end))
	return btn
end

local function makeSlider(parent, min, max, initial, step, format, onCommit)
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(36, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = THEME.soft,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = parent,
	})
	local trackBar = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -56, 0.5, 0),
		Size = UDim2.fromOffset(96, 4),
		BackgroundColor3 = THEME.raised,
		Parent = parent,
	})
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Accent.color, Parent = trackBar })
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 14),
		BackgroundColor3 = THEME.text,
		Parent = trackBar,
	})
	corner(knob, 2)
	Accent.bind(function(c)
		fill.BackgroundColor3 = c
	end)
	local hit = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 0, 26),
		BackgroundTransparency = 1,
		Parent = trackBar,
	})

	local value = initial
	local function visual(v)
		local ratio = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(ratio, 1)
		knob.Position = UDim2.new(ratio, 0, 0.5, 0)
		label.Text = format(v)
	end
	visual(value)

	local dragging = false
	local function fromX(x)
		local ratio = math.clamp((x - trackBar.AbsolutePosition.X) / math.max(1, trackBar.AbsoluteSize.X), 0, 1)
		local raw = min + (max - min) * ratio
		value = math.clamp(math.floor(raw / step + 0.5) * step, min, max)
		visual(value)
	end
	track(hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			onCommit(value)
		end
	end))
	return trackBar
end

--// ============================== browser (powers / weapons) ==============================

local function createBrowser(kind)
	local B = { kind = kind, rows = {}, category = "ALL", selected = nil, current = nil, chips = {}, fetchToken = 0 }
	local singular = kind == "Weapons" and "weapon" or "power"
	local page = newGroup({
		Name = kind .. "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = UI.content,
	})
	B.page = page

	-- search
	local searchWrap = new("Frame", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 24),
		BackgroundColor3 = THEME.panel,
		Parent = page,
	})
	corner(searchWrap, 3)
	local searchStroke = stroke(searchWrap, THEME.line, 1)
	local lens = new("Frame", {
		Position = UDim2.fromOffset(9, 6),
		Size = UDim2.fromOffset(9, 9),
		BackgroundTransparency = 1,
		Parent = searchWrap,
	})
	corner(lens, 5)
	stroke(lens, THEME.dim, 1.5)
	new("Frame", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(5, 2),
		Rotation = 45,
		BackgroundColor3 = THEME.dim,
		Parent = searchWrap,
	})
	local searchBox = new("TextBox", {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -90, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextColor3 = THEME.text,
		PlaceholderColor3 = THEME.faint,
		PlaceholderText = "search " .. singular .. "s...",
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = searchWrap,
	})
	local countLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(52, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = THEME.faint,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = searchWrap,
	})
	track(searchBox.Focused:Connect(function()
		tw(searchStroke, { Color = Accent.color }, 0.15)
	end))
	track(searchBox.FocusLost:Connect(function()
		tw(searchStroke, { Color = THEME.line }, 0.2)
	end))

	-- filter chips
	local chipBar = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = page,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = chipBar,
	})
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chipBar })

	-- list
	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, -170, 1, -66),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Accent.color,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = page,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local emptyLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(1, -40, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = THEME.faint,
		Text = "nothing here",
		Visible = false,
		ZIndex = 3,
		Parent = page,
	})

	-- preview
	local pv = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 66),
		Size = UDim2.new(0, 170, 1, -66),
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.12,
		Parent = page,
	})
	new("Frame", { Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = THEME.line, Parent = pv })
	brackets(pv, 7, 8, 4)

	local sigilGlow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 42),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = Accent.color,
		BackgroundTransparency = 0.9,
		Parent = pv,
	})
	corner(sigilGlow, 40)
	B.glow = sigilGlow
	local sigilBox = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Parent = pv,
	})
	local nameLabel = new("TextLabel", {
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = THEME.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = pv,
	})
	local tagsLabel = new("TextLabel", {
		Position = UDim2.fromOffset(12, 95),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 10,
		RichText = true,
		TextColor3 = THEME.dim,
		Text = "",
		Parent = pv,
	})
	local infoLabel = new("TextLabel", {
		Position = UDim2.fromOffset(12, 108),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 9,
		TextColor3 = THEME.faint,
		Text = "",
		Parent = pv,
	})
	local divider = new("Frame", {
		Position = UDim2.fromOffset(12, 126),
		Size = UDim2.new(1, -24, 0, 1),
		BackgroundColor3 = THEME.line,
		Parent = pv,
	})
	local descLabel = new("TextLabel", {
		Position = UDim2.fromOffset(12, 132),
		Size = UDim2.new(1, -24, 1, -178),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = THEME.dim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = pv,
	})

	local primary = new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -106, 0, 30),
		BackgroundColor3 = Accent.color,
		Parent = pv,
	})
	corner(primary, 3)
	local primaryStroke = stroke(primary, Accent.color, 1)
	local primaryLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = THEME.ink,
		Text = "SELECT",
		Parent = primary,
	})
	pressFx(primary)

	local copyBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(32, 30),
		BackgroundColor3 = THEME.raised,
		Parent = pv,
	})
	corner(copyBtn, 3)
	local copyStroke = stroke(copyBtn, THEME.line, 1)
	local copyParts = {}
	do
		local back = new("Frame", {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(9, 9),
			BackgroundTransparency = 1,
			Parent = copyBtn,
		})
		table.insert(copyParts, stroke(back, THEME.dim, 1))
		local front = new("Frame", {
			Position = UDim2.fromOffset(14, 12),
			Size = UDim2.fromOffset(9, 9),
			BackgroundColor3 = THEME.raised,
			Parent = copyBtn,
		})
		table.insert(copyParts, stroke(front, THEME.dim, 1))
	end
	pressFx(copyBtn)
	track(copyBtn.MouseEnter:Connect(function()
		tw(copyStroke, { Color = Accent.color }, 0.12)
		for _, s in ipairs(copyParts) do tw(s, { Color = Accent.color }, 0.12) end
	end))
	track(copyBtn.MouseLeave:Connect(function()
		tw(copyStroke, { Color = THEME.line }, 0.15)
		for _, s in ipairs(copyParts) do tw(s, { Color = THEME.dim }, 0.15) end
	end))

	local shareBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -46, 1, -10),
		Size = UDim2.fromOffset(46, 30),
		BackgroundColor3 = THEME.raised,
		Parent = pv,
	})
	corner(shareBtn, 3)
	local shareStroke = stroke(shareBtn, THEME.line, 1)
	local shareLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = THEME.dim,
		Text = "SHARE",
		Parent = shareBtn,
	})
	pressFx(shareBtn)
	function B.paintShare()
		local e = B.current
		local on = e == nil or FxGlue.isShared(e)
		shareLabel.Text = on and "SHARE" or "HIDDEN"
		shareLabel.TextColor3 = (e and on) and Accent.color or THEME.dim
		shareStroke.Color = (e and on) and Accent.color or THEME.line
	end
	track(shareBtn.Activated:Connect(function()
		if not B.current then return end
		FxGlue.setShare(B.current, not FxGlue.isShared(B.current))
		B.paintShare()
	end))

	local editBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -98, 1, -10),
		Size = UDim2.fromOffset(32, 30),
		BackgroundColor3 = THEME.raised,
		Visible = false,
		Parent = pv,
	})
	corner(editBtn, 3)
	local editStroke = stroke(editBtn, THEME.line, 1)
	local editParts = {
		bar(editBtn, 3, 13, 2, -1, 45, THEME.dim),
		bar(editBtn, 3, 3, -5, 6, 45, THEME.dim),
	}
	pressFx(editBtn)
	track(editBtn.MouseEnter:Connect(function()
		tw(editStroke, { Color = Accent.color }, 0.12)
		for _, p in ipairs(editParts) do tw(p, { BackgroundColor3 = Accent.color }, 0.12) end
	end))
	track(editBtn.MouseLeave:Connect(function()
		tw(editStroke, { Color = THEME.line }, 0.15)
		for _, p in ipairs(editParts) do tw(p, { BackgroundColor3 = THEME.dim }, 0.15) end
	end))
	track(editBtn.Activated:Connect(function()
		if B.current and Owner.ok then
			pulse(editBtn)
			UI.openEditor(B.current)
		end
	end))
	function B.refreshOwner()
		editBtn.Visible = Owner.ok
		primary.Size = UDim2.new(1, Owner.ok and -142 or -106, 0, 30)
	end

	--// painting

	local function paintPrimary(instant)
		local e = B.current
		local bg, fg, st, label
		if not e then
			bg, fg, st, label = THEME.raised, THEME.faint, THEME.line, "SELECT"
		elseif Runner.busy and Runner.busyPath == e.path then
			bg, fg, st, label = THEME.raised, THEME.dim, THEME.line, "LOADING..."
		elseif Runner.isActive(e) then
			bg, fg, st = THEME.raised, Accent.color, Accent.color
			label = kind == "Weapons" and "UNEQUIP" or "DISMISS"
		else
			bg, fg, st = Accent.color, THEME.ink, Accent.color
			label = kind == "Weapons" and "EQUIP" or "ACTIVATE"
		end
		primaryLabel.Text = label
		apply(primary, { BackgroundColor3 = bg }, instant)
		apply(primaryLabel, { TextColor3 = fg }, instant)
		apply(primaryStroke, { Color = st }, instant)
		if B.paintShare then B.paintShare() end
	end
	B.paintPrimary = paintPrimary

	local function paintRow(r, instant)
		local selected = B.selected == r
		local active = Runner.isActive(r.entry)
		apply(r.body, {
			BackgroundColor3 = selected and Accent.color or Color3.new(1, 1, 1),
			BackgroundTransparency = selected and 0.9 or (r.hover and 0.95 or 1),
		}, instant)
		apply(r.bar, {
			Size = selected and UDim2.fromOffset(3, 30) or UDim2.fromOffset(2, 16),
			BackgroundColor3 = selected and Accent.color or r.entry.color,
		}, instant)
		apply(r.name, { TextColor3 = (selected or r.hover) and THEME.text or THEME.soft }, instant)
		r.tag.Visible = active
		r.dot.Visible = active
		if active and not r.pulse then
			r.pulse = TweenService:Create(
				r.dot,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.75 }
			)
			r.pulse:Play()
		elseif not active and r.pulse then
			r.pulse:Cancel()
			r.pulse = nil
			r.dot.BackgroundTransparency = 0
		end
	end

	function B.repaint()
		for _, r in ipairs(B.rows) do
			paintRow(r, false)
		end
		paintPrimary(false)
	end

	function B.onAccent(c)
		list.ScrollBarImageColor3 = c
		if B.selected and B.selected.body.Parent then
			paintRow(B.selected, true)
		end
		local all = B.chips["ALL"]
		if all and B.category == "ALL" then
			all.btn.BackgroundColor3 = c
		end
		paintPrimary(true)
	end
	Accent.bind(B.onAccent)

	--// preview content

	local function showInfo(entry)
		local info = entry.info
		if not info then return end
		descLabel.Text = entry.desc or info.desc
		infoLabel.Text = string.format("%d LINES  %.1f KB", info.lines, info.kb)
	end

	function B.showEntry(entry)
		B.current = entry
		B.fetchToken += 1
		local token = B.fetchToken
		for _, c in ipairs(sigilBox:GetChildren()) do
			c:Destroy()
		end
		local _, parts = buildSigil(sigilBox, 56, entry.seed, entry.color, kind, entry.category)
		B.spin = parts
		sigilGlow.BackgroundColor3 = entry.color
		if UI.current == kind then
			State.spin = parts
			State.glow = sigilGlow
			Accent.set(entry.color)
		end
		nameLabel.Text = entry.name
		nameLabel.TextTransparency = 1
		tw(nameLabel, { TextTransparency = 0 }, 0.3)
		tagsLabel.Text = string.format(
			'<font color="#%s">%s</font>  <font color="#%s">%s</font>',
			hex(entry.color), string.upper(entry.category), hex(THEME.dim), string.upper(singular)
		)
		descLabel.Text = entry.desc or "reading source..."
		infoLabel.Text = ""
		showInfo(entry)
		paintPrimary(false)

		if not entry.info then
			task.spawn(function()
				local src = Net.source(entry)
				if not src then
					if B.fetchToken == token then
						descLabel.Text = entry.desc or "could not read the source"
					end
					return
				end
				local _, n = string.gsub(src, "\n", "\n")
				entry.info = {
					desc = describeSource(src) ~= "" and describeSource(src) or ("custom " .. singular .. " by DuaKNo."),
					lines = n + 1,
					kb = #src / 1024,
				}
				if B.fetchToken == token then
					showInfo(entry)
				end
			end)
		end
	end

	function B.select(r)
		local old = B.selected
		B.selected = r
		if old and old.body.Parent then
			paintRow(old, false)
		end
		if r then
			paintRow(r, false)
			B.showEntry(r.entry)
		end
	end

	function B.selectPath(path)
		for _, r in ipairs(B.rows) do
			if r.entry.path == path then
				B.select(r)
				return
			end
		end
	end

	--// filtering

	function B.applyFilter()
		local q = string.lower(searchBox.Text)
		local shown = 0
		for _, r in ipairs(B.rows) do
			local e = r.entry
			local okCat = B.category == "ALL" or e.category == B.category
			local okQ = q == ""
				or string.find(string.lower(e.name), q, 1, true) ~= nil
				or string.find(string.lower(e.category), q, 1, true) ~= nil
				or string.find(string.lower(e.desc or ""), q, 1, true) ~= nil
			local visible = okCat and okQ
			r.container.Visible = visible
			if visible then
				shown += 1
				r.container.LayoutOrder = shown
			end
		end
		countLabel.Text = shown .. "/" .. #B.rows
		emptyLabel.Visible = shown == 0 and #B.rows > 0
		list.CanvasPosition = Vector2.new(0, 0)
	end
	track(searchBox:GetPropertyChangedSignal("Text"):Connect(B.applyFilter))

	function B.animateIn()
		local n = 0
		for _, r in ipairs(B.rows) do
			if r.container.Visible then
				n += 1
				if n <= 12 then
					r.body.Position = UDim2.fromOffset(-40, 0)
					task.delay((n - 1) * 0.03, function()
						if r.body.Parent then
							tw(r.body, { Position = UDim2.new() }, 0.3)
						end
					end)
				else
					r.body.Position = UDim2.new()
				end
			end
		end
	end

	function B.paintChips(instant)
		for name, chip in pairs(B.chips) do
			local active = B.category == name
			local color = chip.color or Accent.color
			apply(chip.btn, {
				BackgroundColor3 = active and color or THEME.raised,
				TextColor3 = active and THEME.ink or THEME.dim,
			}, instant)
		end
	end

	function B.setCategory(name)
		B.category = name
		B.paintChips(false)
		B.applyFilter()
		B.animateIn()
	end

	function B.buildChips()
		for _, c in ipairs(chipBar:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		B.chips = {}
		local seen, names = {}, {}
		for _, r in ipairs(B.rows) do
			if not seen[r.entry.category] then
				seen[r.entry.category] = r.entry.color
				table.insert(names, r.entry.category)
			end
		end
		table.sort(names)
		table.insert(names, 1, "ALL")
		if not (B.category == "ALL" or seen[B.category]) then
			B.category = "ALL"
		end
		for i, name in ipairs(names) do
			local color = seen[name]
			local btn = new("TextButton", {
				LayoutOrder = i,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 20),
				BackgroundColor3 = THEME.raised,
				Font = Enum.Font.Code,
				TextSize = 10,
				TextColor3 = THEME.dim,
				Text = string.upper(name),
				Parent = chipBar,
			})
			new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = btn })
			corner(btn, 3)
			pressFx(btn)
			B.chips[name] = { btn = btn, color = color }
			track(btn.MouseEnter:Connect(function()
				if B.category ~= name then
					tw(btn, { TextColor3 = color or Accent.color }, 0.12)
				end
			end))
			track(btn.MouseLeave:Connect(function()
				if B.category ~= name then
					tw(btn, { TextColor3 = THEME.dim }, 0.15)
				end
			end))
			track(btn.Activated:Connect(function()
				if B.category ~= name then
					B.setCategory(name)
				end
			end))
		end
		B.paintChips(true)
	end

	--// rows

	function B.makeRow(entry, index)
		local container = new("Frame", {
			Name = "Row",
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = list,
		})
		local body = new("TextButton", {
			Name = "Body",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Parent = container,
		})
		local barF = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(2, 16),
			BackgroundColor3 = entry.color,
			Parent = body,
		})
		local sigilHold = new("Frame", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			Parent = body,
		})
		buildSigil(sigilHold, 34, entry.seed, entry.color, kind, entry.category)
		local nameL = new("TextLabel", {
			Position = UDim2.fromOffset(56, 6),
			Size = UDim2.new(1, -56 - 76, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = THEME.soft,
			Text = entry.name,
			Parent = body,
		})
		new("TextLabel", {
			Position = UDim2.fromOffset(56, 22),
			Size = UDim2.new(1, -66, 0, 12),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = entry.color,
			Text = string.upper(entry.category),
			Parent = body,
		})
		new("TextLabel", {
			Position = UDim2.fromOffset(56, 34),
			Size = UDim2.new(1, -66, 0, 12),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = THEME.faint,
			Text = entry.desc or ("custom " .. singular .. " by DuaKNo"),
			Parent = body,
		})
		local tag = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, 8),
			Size = UDim2.fromOffset(50, 12),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = THEME.good,
			Text = "ACTIVE",
			Visible = false,
			Parent = body,
		})
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 11),
			Size = UDim2.fromOffset(5, 5),
			Rotation = 45,
			BackgroundColor3 = THEME.good,
			Visible = false,
			Parent = body,
		})
		new("Frame", {
			Position = UDim2.new(0, 12, 1, -1),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = THEME.line,
			Parent = container,
		})

		local r = { entry = entry, container = container, body = body, bar = barF, name = nameL, tag = tag, dot = dot, hover = false }
		pressFx(body)
		track(body.MouseEnter:Connect(function()
			r.hover = true
			paintRow(r, false)
		end))
		track(body.MouseLeave:Connect(function()
			r.hover = false
			paintRow(r, false)
		end))
		track(body.Activated:Connect(function()
			B.select(r)
		end))
		return r
	end

	function B.load(entries)
		local keepPath = B.current and B.current.path
		for _, r in ipairs(B.rows) do
			if r.pulse then r.pulse:Cancel() end
			r.container:Destroy()
		end
		B.rows, B.selected, B.current = {}, nil, nil
		for i, entry in ipairs(entries) do
			table.insert(B.rows, B.makeRow(entry, i))
		end
		B.buildChips()
		B.applyFilter()
		local pick = B.rows[1]
		for _, r in ipairs(B.rows) do
			if r.entry.path == keepPath then
				pick = r
			end
		end
		if pick then
			B.select(pick)
		else
			for _, c in ipairs(sigilBox:GetChildren()) do c:Destroy() end
			nameLabel.Text = "no " .. singular .. "s yet"
			tagsLabel.Text = ""
			infoLabel.Text = ""
			descLabel.Text = "nothing in the repo matched this section"
			B.spin = nil
			paintPrimary(true)
		end
		B.repaint()
		B.animateIn()
	end

	function B.onShow()
		State.spin = B.spin
		State.glow = B.glow
		if B.current then
			Accent.set(B.current.color)
		end
		B.animateIn()
	end

	function B.layout(contentW, contentH)
		local pw = math.clamp(math.floor(contentW * 0.38), 150, 210)
		list.Size = UDim2.new(1, -pw, 1, -66)
		pv.Size = UDim2.new(0, pw, 1, -66)
		local panelH = contentH - 66
		descLabel.Visible = panelH >= 190
		divider.Visible = panelH >= 190
		infoLabel.Visible = panelH >= 170
	end

	track(primary.Activated:Connect(function()
		local e = B.current
		if not e or Runner.busy then return end
		pulse(primary)
		if Runner.isActive(e) then
			Runner.stop(e)
		else
			task.spawn(Runner.run, e)
		end
	end))
	track(copyBtn.Activated:Connect(function()
		local e = B.current
		if not e then return end
		pulse(copyBtn)
		local ok = copyText(string.format('loadstring(game:HttpGet("%s"))()', e.url))
		status(ok and ("copied loadstring: " .. e.name) or "clipboard not supported here", ok and THEME.good or THEME.bad)
	end))

	return B
end

--// ============================== simulation radius ==============================
--// SimRadius setting: 0 = off (your original radius is put back), otherwise your real simulation radius is set to it
local SimR = { orig = nil }
do
	pcall(function() SimR.orig = gethiddenproperty(Players.LocalPlayer, "SimulationRadius") end)
end
function SimR.set(v)
	local plr = Players.LocalPlayer
	pcall(function() sethiddenproperty(plr, "SimulationRadius", v) end)
	pcall(function() sethiddenproperty(plr, "MaximumSimulationRadius", v) end)
	pcall(function() plr.MaximumSimulationRadius = v end)
	pcall(function() if setsimulationradius then setsimulationradius(v, v) end end)
end
function SimR.apply()
	local v = State.settings.SimRadius
	if type(v) == "number" and v > 0 then
		SimR.set(v)
	elseif SimR.orig then
		SimR.set(SimR.orig)
		SimR.orig = nil
	end
end

--// ============================== settings page ==============================

local function createSettings()
	local page = newGroup({
		Name = "SettingsPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = UI.content,
	})
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Accent.color,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = page,
	})
	Accent.bind(function(c)
		scroll.ScrollBarImageColor3 = c
	end)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	new("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = scroll })

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function heading(text)
		local f = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = scroll })
		local mark = new("Frame", {
			Position = UDim2.fromOffset(14, 13),
			Size = UDim2.fromOffset(6, 6),
			Rotation = 45,
			BackgroundColor3 = Accent.color,
			Parent = f,
		})
		Accent.bind(function(c)
			mark.BackgroundColor3 = c
		end)
		new("TextLabel", {
			Position = UDim2.fromOffset(28, 8),
			Size = UDim2.new(1, -40, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.dim,
			Text = text,
			Parent = f,
		})
	end

	local function row(title, sub, height)
		local f = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, height or 44), BackgroundTransparency = 1, Parent = scroll })
		new("TextLabel", {
			Position = UDim2.fromOffset(14, 7),
			Size = UDim2.new(1, -170, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = THEME.text,
			Text = title,
			Parent = f,
		})
		new("TextLabel", {
			Position = UDim2.fromOffset(14, 24),
			Size = UDim2.new(1, -170, 0, 13),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = THEME.faint,
			Text = sub,
			Parent = f,
		})
		new("Frame", {
			Position = UDim2.new(0, 14, 1, -1),
			Size = UDim2.new(1, -28, 0, 1),
			BackgroundColor3 = THEME.line,
			Parent = f,
		})
		return f
	end

	heading("INTERFACE")
	makeSlider(row("UI scale", "size of the whole window"), 0.8, 1.3, State.settings.Scale, 0.05, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end, function(v)
		State.settings.Scale = v
		saveSettings()
		UI.relayout()
	end)
	makeToggle(row("Particles", "drifting embers in the background"), State.settings.Particles, function(v)
		State.settings.Particles = v
		UI.particleLayer.Visible = v
		saveSettings()
	end)
	makeToggle(row("Animations", "turn off for a flat, instant interface"), State.settings.Animations, function(v)
		State.settings.Animations = v
		saveSettings()
	end)

	heading("BEHAVIOUR")
	makeToggle(row("Stack scripts", "off = running a new one removes the old one"), State.settings.Stack, function(v)
		State.settings.Stack = v
		saveSettings()
	end)
	makeToggle(row("Live sync", "see other players' powers and weapons (custom firebase)"), State.settings.Live, function(v)
		State.settings.Live = v
		saveSettings()
		FxGlue.apply()
	end)
	makeToggle(row("Silence console", "power and weapon print/warn go to the debug panel"), State.settings.Quiet, function(v)
		State.settings.Quiet = v
		saveSettings()
	end)
	makeSlider(row("Push strength", "how hard other players' powers push you (never damage)"), 0.1, 1, State.settings.ImpactPower, 0.05, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end, function(v)
		State.settings.ImpactPower = v
		saveSettings()
		FxGlue.apply()
	end)
	makeToggle(row("Live debug", "floating panel with live sync status and logs"), State.settings.Debug, function(v)
		State.settings.Debug = v
		saveSettings()
		Debug.setVisible(v)
	end)
	makeToggle(row("Receive effects", "other players' powers can freeze, pull, burn or push you (timed, no damage)"), State.settings.Impact, function(v)
		State.settings.Impact = v
		saveSettings()
		FxGlue.apply()
	end)
	do
		local r = row("Simulation radius", "0 = off. type a number (1000) or inf, then SET")
		local box = new("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -112, 0.5, 0),
			Size = UDim2.fromOffset(80, 22),
			BackgroundColor3 = THEME.raised,
			ClearTextOnFocus = false,
			Font = Enum.Font.Code,
			TextSize = 11,
			TextColor3 = THEME.text,
			PlaceholderColor3 = THEME.faint,
			PlaceholderText = "0 = off",
			Text = State.settings.SimRadius > 0 and tostring(State.settings.SimRadius) or "",
			Parent = r,
		})
		corner(box, 3)
		stroke(box, THEME.line, 1)
		local setBtn = ghostButton(r, "SET", false)
		setBtn.AnchorPoint = Vector2.new(1, 0.5)
		setBtn.Position = UDim2.new(1, -14, 0.5, 0)
		setBtn.Size = UDim2.fromOffset(90, 22)
		local function commit()
			local txt = string.lower((box.Text or ""):gsub("%s", ""))
			local v = tonumber(txt)
			if txt == "inf" or txt == "max" or txt == "huge" then v = 1e9 end
			if not v then
				box.Text = State.settings.SimRadius > 0 and tostring(State.settings.SimRadius) or ""
				return
			end
			v = math.clamp(math.floor(v), 0, 1e9)
			State.settings.SimRadius = v
			box.Text = v > 0 and tostring(v) or ""
			saveSettings()
			SimR.apply()
			pcall(notify, "Simulation radius", v > 0 and ("set to " .. tostring(v)) or "off (original restored)")
		end
		track(setBtn.Activated:Connect(commit))
		track(box.FocusLost:Connect(function(enter)
			if enter then commit() end
		end))
	end
	do
		local r = row("Toggle key", "show or hide the hub")
		local keyBtn = ghostButton(r, string.upper(State.toggleKey.Name), false)
		keyBtn.AnchorPoint = Vector2.new(1, 0.5)
		keyBtn.Position = UDim2.new(1, -14, 0.5, 0)
		keyBtn.Size = UDim2.fromOffset(96, 22)
		UI.keyBtn = keyBtn
		track(keyBtn.Activated:Connect(function()
			State.binding = true
			keyBtn.Text = "PRESS A KEY"
		end))
	end

	heading("LIVE SYNC")
	do
		local r = row("Live sync", "names + abilities set by DuaKNo update for everyone", 44)
		local b = ghostButton(r, "SYNC NOW", false)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -14, 0.5, 0)
		b.Size = UDim2.fromOffset(96, 22)
		track(b.Activated:Connect(function()
			task.spawn(function()
				status("syncing...")
				if Sync.pull() then
					UI.rebuild()
				end
				status(Sync.status, THEME.dim)
			end)
		end))
		UI.ownerRow = row("Owner mode", "select a script, press the pencil: rename it, set its ability", 44)
		UI.ownerRow.Visible = Owner.ok
	end

	heading("ACTIONS")
	do
		local f = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = scroll })
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			Parent = f,
		})
		new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = f })
		local function actionButton(text, idx, danger, fn)
			local b = ghostButton(f, text, danger)
			b.LayoutOrder = idx
			b.Size = UDim2.new(1 / 3, -4, 0, 26)
			track(b.Activated:Connect(fn))
		end
		actionButton("RELOAD REPO", 1, false, function()
			task.spawn(UI.populate)
		end)
		actionButton("DISPEL ALL", 2, false, function()
			Runner.stopAll(false)
		end)
		actionButton("UNLOAD HUB", 3, true, function()
			cleanup()
		end)
	end

	heading("CREDITS")
	do
		local f = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1, Parent = scroll })
		local av = new("ImageLabel", {
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = THEME.raised,
			Image = State.avatar or "",
			Parent = f,
		})
		corner(av, 3)
		stroke(av, THEME.line, 1)
		UI.avatarImage = av
		new("TextLabel", {
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(1, -80, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.text,
			Text = CONFIG.Credit.UserName,
			Parent = f,
		})
		new("TextLabel", {
			Position = UDim2.fromOffset(68, 28),
			Size = UDim2.new(1, -80, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.dim,
			Text = "made every power and weapon in here",
			Parent = f,
		})
		local links = new("Frame", { Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 0, 26), BackgroundTransparency = 1, Parent = f })
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			Parent = links,
		})
		local function linkButton(text, idx, value)
			local b = ghostButton(links, text, false)
			b.LayoutOrder = idx
			b.Size = UDim2.new(0.5, -3, 1, 0)
			track(b.Activated:Connect(function()
				local ok = copyText(value)
				status(ok and ("copied " .. value) or value, ok and THEME.good or THEME.dim)
			end))
		end
		linkButton("INSTAGRAM  " .. CONFIG.Credit.Instagram, 1, CONFIG.Credit.Instagram)
		linkButton("DISCORD  COPY LINK", 2, CONFIG.Credit.Discord)
	end

	return { page = page }
end

--// ============================== owner editor ==============================

local function createEditor()
	local E = { entry = nil, kind = "Powers", category = "General", chips = {}, kindChips = {} }

	local overlay = new("TextButton", {
		Name = "Editor",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = UI.window,
	})
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -28, 1, -28),
		BackgroundColor3 = THEME.panel,
		ZIndex = 41,
		Parent = overlay,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(400, 330), Parent = card })
	corner(card, 4)
	stroke(card, THEME.line, 1)
	brackets(card, 7, 8, 44)

	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Accent.color,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ZIndex = 42,
		Parent = card,
	})
	Accent.bind(function(c)
		scroll.ScrollBarImageColor3 = c
	end)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = scroll })
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
		Parent = scroll,
	})

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function label(text)
		return new("TextLabel", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 10,
			TextColor3 = THEME.dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
			ZIndex = 43,
			Parent = scroll,
		})
	end

	local title = label("")
	title.TextSize = 11
	title.TextColor3 = THEME.text
	title.Size = UDim2.new(1, 0, 0, 18)

	local function inputBox(placeholder)
		local wrap = new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = THEME.raised,
			ZIndex = 43,
			Parent = scroll,
		})
		corner(wrap, 3)
		local st = stroke(wrap, THEME.line, 1)
		local box = new("TextBox", {
			Position = UDim2.fromOffset(9, 0),
			Size = UDim2.new(1, -18, 1, 0),
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = THEME.text,
			PlaceholderColor3 = THEME.faint,
			PlaceholderText = placeholder,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 44,
			Parent = wrap,
		})
		track(box.Focused:Connect(function()
			tw(st, { Color = Accent.color }, 0.15)
		end))
		track(box.FocusLost:Connect(function()
			tw(st, { Color = THEME.line }, 0.2)
		end))
		return box
	end

	label("NAME")
	local nameBox = inputBox("script name")

	label("TYPE")
	local kindRow = new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		ZIndex = 43,
		Parent = scroll,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = kindRow,
	})

	local function paintChip(chip, active)
		tw(chip.btn, {
			BackgroundColor3 = active and chip.color or THEME.raised,
			TextColor3 = active and THEME.ink or THEME.dim,
		}, 0.12)
	end

	local function makeChip(parent, text, color, onClick)
		local btn = new("TextButton", {
			BackgroundColor3 = THEME.raised,
			Font = Enum.Font.Code,
			TextSize = 10,
			TextColor3 = THEME.dim,
			Text = text,
			ZIndex = 44,
			Parent = parent,
		})
		corner(btn, 3)
		pressFx(btn)
		local chip = { btn = btn, color = color }
		track(btn.Activated:Connect(onClick))
		return chip
	end

	local function paintKinds()
		for k, chip in pairs(E.kindChips) do
			paintChip(chip, E.kind == k)
		end
	end
	for i, k in ipairs({ "Powers", "Weapons" }) do
		local chip = makeChip(kindRow, k == "Powers" and "POWER" or "WEAPON", THEME.accents[k], function()
			E.kind = k
			paintKinds()
		end)
		chip.btn.LayoutOrder = i
		chip.btn.Size = UDim2.new(0.5, -3, 1, 0)
		E.kindChips[k] = chip
	end

	label("ABILITY")
	local grid = new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 43,
		Parent = scroll,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(78, 22),
		CellPadding = UDim2.fromOffset(4, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	label("OR TYPE YOUR OWN ABILITY")
	local customBox = inputBox("custom ability name")

	local function paintCats()
		local typed = string.gsub(customBox.Text, "%s", "") ~= ""
		for name, chip in pairs(E.chips) do
			paintChip(chip, (not typed) and E.category == name)
		end
	end

	local names = {}
	for _, cat in ipairs(CONFIG.Categories) do
		table.insert(names, cat.name)
	end
	table.sort(names)
	table.insert(names, "General")
	for i, name in ipairs(names) do
		local chip = makeChip(grid, string.upper(name), Repo.categoryColor(name), function()
			E.category = name
			customBox.Text = ""
			paintCats()
		end)
		chip.btn.LayoutOrder = i
		E.chips[name] = chip
	end
	track(customBox:GetPropertyChangedSignal("Text"):Connect(paintCats))

	local statusLine = label("")
	statusLine.TextColor3 = THEME.faint

	local btnRow = new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 43,
		Parent = scroll,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = btnRow,
	})

	local saveBtn = new("TextButton", {
		LayoutOrder = 1,
		Size = UDim2.new(0.4, -4, 1, 0),
		BackgroundColor3 = Accent.color,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = THEME.ink,
		Text = "SAVE + SYNC",
		ZIndex = 44,
		Parent = btnRow,
	})
	corner(saveBtn, 3)
	pressFx(saveBtn)
	Accent.bind(function(c)
		saveBtn.BackgroundColor3 = c
	end)
	local resetBtn = ghostButton(btnRow, "RESET", false)
	resetBtn.LayoutOrder = 2
	resetBtn.Size = UDim2.new(0.3, -4, 1, 0)
	resetBtn.ZIndex = 44
	local cancelBtn = ghostButton(btnRow, "CANCEL", true)
	cancelBtn.LayoutOrder = 3
	cancelBtn.Size = UDim2.new(0.3, -4, 1, 0)
	cancelBtn.ZIndex = 44

	local function close()
		E.entry = nil
		tw(overlay, { BackgroundTransparency = 1 }, 0.15)
		task.delay(State.settings.Animations and 0.16 or 0.01, function()
			if not E.entry then
				overlay.Visible = false
			end
		end)
	end

	local function trim(s)
		return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
	end

	local function commit(entry, ov, text)
		if not Owner.ok then return end
		Sync.overrides[entry.key] = ov
		local path, kind = entry.path, ov and ov.kind or entry.kind
		close()
		UI.rebuild(path, kind)
		status("saving " .. text .. "...")
		task.spawn(function()
			local ok, err = Sync.push()
			status(ok and ("saved + synced: " .. text) or tostring(err), ok and THEME.good or THEME.bad)
		end)
	end

	track(saveBtn.Activated:Connect(function()
		local e = E.entry
		if not e then return end
		pulse(saveBtn)
		local name = trim(nameBox.Text)
		if name == "" then name = e.name end
		local cat = trim(customBox.Text)
		if cat == "" then cat = E.category end
		commit(e, { name = string.sub(name, 1, 40), category = string.sub(cat, 1, 20), kind = E.kind }, name)
	end))
	track(resetBtn.Activated:Connect(function()
		local e = E.entry
		if not e then return end
		commit(e, nil, e.name)
	end))
	track(cancelBtn.Activated:Connect(close))

	function UI.openEditor(entry)
		if not Owner.ok or not entry then return end
		E.entry = entry
		E.kind = entry.kind
		E.category = entry.category
		title.Text = "EDIT  //  " .. string.upper(entry.file)
		nameBox.Text = entry.name
		if E.chips[entry.category] then
			customBox.Text = ""
		else
			customBox.Text = entry.category
		end
		statusLine.Text = Sync.url() and "changes sync to every player in seconds" or "no npoint bin id set: only you will see changes"
		paintKinds()
		paintCats()
		overlay.Visible = true
		tw(overlay, { BackgroundTransparency = 0.35 }, 0.2)
	end
end

--// ============================== build the window ==============================

local function buildUI()
	local gui = new("ScreenGui", {
		Name = "SpellsHub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	State.gui = gui
	local mounted = pcall(function()
		gui.Parent = gethui and gethui() or CoreGui
	end)
	if not mounted or not gui.Parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	-- shell holds position/size and the open animation scale
	local shell = new("Frame", {
		Name = "Shell",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CONFIG.WindowWidth, CONFIG.WindowHeight),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	UI.shell = shell
	UI.scaler = new("UIScale", { Parent = shell })

	local halo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
		BackgroundColor3 = Accent.color,
		BackgroundTransparency = 0.95,
		Parent = shell,
	})
	corner(halo, 8)
	local haloStroke = stroke(halo, Accent.color, 1, 0.85)
	Accent.bind(function(c)
		halo.BackgroundColor3 = c
		haloStroke.Color = c
	end)
	UI.halo, UI.haloStroke = halo, haloStroke

	local window = newGroup({
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.bg,
		Parent = shell,
	})
	UI.window = window
	corner(window, 4)
	local wStroke = new("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = window,
	})
	local wGrad = new("UIGradient", { Parent = wStroke })
	UI.strokeGrad = wGrad
	Accent.bind(function(c)
		wGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(0.5, THEME.line),
			ColorSequenceKeypoint.new(1, c),
		})
	end)

	-- content area (particles behind pages)
	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(SIDE, HEADER),
		Size = UDim2.new(1, -SIDE, 1, -HEADER - FOOTER),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = window,
	})
	UI.content = content

	local pLayer = new("Frame", {
		Name = "Particles",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Visible = State.settings.Particles,
		Parent = content,
	})
	UI.particleLayer = pLayer
	UI.particles = {}
	for i = 1, 16 do
		local s = ({ 2, 2, 3 })[i % 3 + 1]
		local f = new("Frame", {
			Size = UDim2.fromOffset(s, s),
			Rotation = 45,
			BackgroundColor3 = Accent.color,
			BackgroundTransparency = 0.85,
			Parent = pLayer,
		})
		UI.particles[i] = {
			f = f,
			x = math.random(),
			y = math.random(),
			speed = 0.018 + math.random() * 0.04,
			phase = math.random() * 6.28,
			sway = 0.006 + math.random() * 0.014,
		}
	end
	Accent.bind(function(c)
		for _, p in ipairs(UI.particles) do
			p.f.BackgroundColor3 = c
		end
	end)

	-- header
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, HEADER), BackgroundColor3 = THEME.panel, ZIndex = 5, Parent = window })
	local mark = new("Frame", {
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.fromOffset(12, 12),
		Rotation = 45,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = header,
	})
	local markStroke = stroke(mark, Accent.color, 1.5)
	local markDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Accent.color,
		ZIndex = 6,
		Parent = mark,
	})
	local title = new("TextLabel", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -120, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Michroma,
		TextSize = 12,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text,
		ZIndex = 6,
		Parent = header,
	})
	local function paintTitle()
		local w = UI.uw or CONFIG.WindowWidth
		local name = w >= 470 and "POWER/WEAPON TOOLS HUB" or (w >= 380 and "TOOLS HUB" or "TOOLS")
		title.Text = string.format(
			'%s <font color="#%s">//</font> <font size="9" color="#%s">DUAKNO</font>',
			name, hex(Accent.color), hex(THEME.dim)
		)
	end
	UI.paintTitle = paintTitle
	Accent.bind(function(c)
		markStroke.Color = c
		markDot.BackgroundColor3 = c
		paintTitle()
	end)

	new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.line, ZIndex = 6, Parent = header })
	local sweep = new("Frame", {
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Accent.color,
		ZIndex = 7,
		Parent = header,
	})
	local sweepGrad = new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = sweep,
	})
	UI.sweepGrad = sweepGrad
	Accent.bind(function(c)
		sweep.BackgroundColor3 = c
	end)

	local function headerButton(kind, idx)
		local b = new("TextButton", {
			Position = UDim2.new(1, -32 * idx, 0, 0),
			Size = UDim2.fromOffset(32, HEADER - 2),
			BackgroundColor3 = THEME.raised,
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = header,
		})
		local marks = {}
		if kind == "min" then
			table.insert(marks, bar(b, 10, 2, 0, 0, 0, THEME.dim))
		else
			table.insert(marks, bar(b, 13, 2, 0, 0, 45, THEME.dim))
			table.insert(marks, bar(b, 13, 2, 0, 0, -45, THEME.dim))
		end
		for _, m in ipairs(marks) do m.ZIndex = 7 end
		track(b.MouseEnter:Connect(function()
			local c = kind == "close" and THEME.bad or Accent.color
			tw(b, { BackgroundTransparency = 0.5 }, 0.12)
			for _, m in ipairs(marks) do tw(m, { BackgroundColor3 = c }, 0.12) end
		end))
		track(b.MouseLeave:Connect(function()
			tw(b, { BackgroundTransparency = 1 }, 0.15)
			for _, m in ipairs(marks) do tw(m, { BackgroundColor3 = THEME.dim }, 0.15) end
		end))
		return b, marks
	end
	local closeBtn = headerButton("close", 1)
	local minBtn, minMarks = headerButton("min", 2)
	UI.minMarks = minMarks

	-- drag
	local dragging, dragStart, startPos = false, nil, nil
	track(header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = shell.Position
			local c
			c = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					c:Disconnect()
				end
			end)
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			shell.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))

	-- sidebar
	local sidebar = new("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(0, SIDE, 1, -HEADER - FOOTER),
		BackgroundColor3 = THEME.panel,
		ZIndex = 4,
		Parent = window,
	})
	new("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = THEME.line, ZIndex = 5, Parent = sidebar })

	local glow = new("Frame", {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Accent.color,
		ZIndex = 5,
		Parent = sidebar,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(1, 1) }),
		Parent = glow,
	})
	local indicator = new("Frame", {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.fromOffset(3, 30),
		BackgroundColor3 = Accent.color,
		ZIndex = 6,
		Parent = sidebar,
	})
	Accent.bind(function(c)
		glow.BackgroundColor3 = c
		indicator.BackgroundColor3 = c
	end)
	UI.indicator, UI.glow = indicator, glow

	local labels = { Powers = "POWER", Weapons = "WEAPON", Settings = "SET" }
	local function tabY(idx)
		return 8 + (idx - 1) * 54
	end
	UI.tabs = {}
	UI.badges = {}
	for idx, name in ipairs(TAB_ORDER) do
		local b = new("TextButton", {
			Position = UDim2.fromOffset(0, tabY(idx)),
			Size = UDim2.new(1, -1, 0, 50),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = sidebar,
		})
		local icon = makeIcon(b, name)
		local lbl = new("TextLabel", {
			Position = UDim2.new(0, 0, 1, -16),
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 8,
			TextColor3 = THEME.dim,
			Text = labels[name],
			ZIndex = 7,
			Parent = b,
		})
		local badge = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 4),
			Size = UDim2.fromOffset(16, 10),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = THEME.faint,
			Text = "",
			ZIndex = 7,
			Parent = b,
		})
		UI.badges[name] = badge
		local tab = { btn = b, active = false }
		function tab.paint(active)
			tab.active = active
			local c = active and THEME.accents[name] or THEME.dim
			icon.paint(c)
			lbl.TextColor3 = c
		end
		pressFx(b)
		track(b.MouseEnter:Connect(function()
			if not tab.active then
				icon.paint(THEME.text)
				lbl.TextColor3 = THEME.text
			end
		end))
		track(b.MouseLeave:Connect(function()
			if not tab.active then
				icon.paint(THEME.dim)
				lbl.TextColor3 = THEME.dim
			end
		end))
		track(b.Activated:Connect(function()
			UI.switchTo(name)
		end))
		UI.tabs[name] = tab
	end

	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -36),
		Size = UDim2.fromOffset(60, 12),
		Rotation = -90,
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 9,
		TextColor3 = THEME.faint,
		Text = "DUAKNO",
		ZIndex = 5,
		Parent = sidebar,
	})

	-- footer
	local footer = new("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOTER),
		BackgroundColor3 = THEME.panel,
		ZIndex = 5,
		Parent = window,
	})
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.line, ZIndex = 6, Parent = footer })
	local statusLabel = new("TextLabel", {
		Position = UDim2.fromOffset(12, 1),
		Size = UDim2.new(1, -190, 1, -1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = THEME.dim,
		Text = "> idle",
		ZIndex = 6,
		Parent = footer,
	})
	local footRight = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 1),
		Size = UDim2.fromOffset(170, FOOTER - 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = THEME.faint,
		ZIndex = 6,
		Parent = footer,
	})
	function UI.setStatus(text, color)
		statusLabel.Text = "> " .. text
		statusLabel.TextColor3 = color or THEME.dim
	end
	function UI.refreshFooter()
		footRight.Text = string.format("%d ACTIVE   [%s]", Runner.count(), string.upper(State.toggleKey.Name))
	end

	-- pages
	UI.browsers = {
		Powers = createBrowser("Powers"),
		Weapons = createBrowser("Weapons"),
	}
	UI.pages = {
		Powers = UI.browsers.Powers.page,
		Weapons = UI.browsers.Weapons.page,
		Settings = createSettings().page,
	}

	createEditor()

	-- launcher tab on the right edge
	local tab = new("TextButton", {
		Name = "Tab",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, CONFIG.TabY),
		Size = UDim2.fromOffset(26, 60),
		BackgroundColor3 = THEME.panel,
		ZIndex = 30,
		Parent = gui,
	})
	corner(tab, 4)
	local tabStroke = stroke(tab, THEME.line, 1)
	local tabMark = new("Frame", {
		Position = UDim2.new(0, 0, 0.5, -11),
		Size = UDim2.fromOffset(2, 22),
		BackgroundColor3 = Accent.color,
		ZIndex = 31,
		Parent = tab,
	})
	local chevron = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 1, 0.5, 13),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = tab,
	})
	local chevParts = { bar(chevron, 9, 2, 0, -3, -45, THEME.dim), bar(chevron, 9, 2, 0, 3, 45, THEME.dim) }
	for _, p in ipairs(chevParts) do p.ZIndex = 31 end
	local emblem = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 1, 0.5, -12),
		Size = UDim2.fromOffset(13, 13),
		Rotation = 45,
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = tab,
	})
	local emblemStroke = stroke(emblem, Accent.color, 1.5)
	local emblemDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Accent.color,
		ZIndex = 31,
		Parent = emblem,
	})
	Accent.bind(function(c)
		emblemStroke.Color = c
		emblemDot.BackgroundColor3 = c
	end)
	State.emblem = emblem
	Accent.bind(function(c)
		tabMark.BackgroundColor3 = c
	end)
	UI.chevron = chevron
	track(tab.MouseEnter:Connect(function()
		tw(tabStroke, { Color = Accent.color }, 0.12)
		for _, p in ipairs(chevParts) do tw(p, { BackgroundColor3 = Accent.color }, 0.12) end
	end))
	track(tab.MouseLeave:Connect(function()
		tw(tabStroke, { Color = THEME.line }, 0.15)
		for _, p in ipairs(chevParts) do tw(p, { BackgroundColor3 = THEME.dim }, 0.15) end
	end))
	track(tab.Activated:Connect(function()
		UI.setOpen(not UI.isOpen)
	end))
	pressFx(tab)

	-- window controls wiring
	track(closeBtn.Activated:Connect(function()
		UI.setOpen(false)
	end))
	track(minBtn.Activated:Connect(function()
		UI.setMinimized(not UI.minimized)
	end))

	function UI.tabY(idx)
		return tabY(idx)
	end
end

--// ============================== window logic ==============================

UI.isOpen = false
UI.minimized = false
UI.current = nil
UI.scanning = false

function UI.relayout()
	if not State.gui then return end
	local vp = viewport()
	local us = State.settings.Scale
	local uw = math.max(300, math.min(CONFIG.WindowWidth, (vp.X - 16) / us))
	local uh = math.max(220, math.min(CONFIG.WindowHeight, (vp.Y - 16) / us))
	UI.uw, UI.uh = uw, uh
	UI.shell.Size = UDim2.fromOffset(uw, UI.minimized and HEADER or uh)
	UI.scaler.Scale = UI.isOpen and us or us * 0.94
	for _, b in pairs(UI.browsers) do
		b.layout(uw - SIDE, uh - HEADER - FOOTER)
	end
	if UI.paintTitle then UI.paintTitle() end
end

function UI.setOpen(open)
	UI.isOpen = open
	local us = State.settings.Scale
	tw(UI.chevron, { Rotation = open and 180 or 0 }, 0.3)
	if open then
		UI.shell.Visible = true
		UI.relayout()
		UI.scaler.Scale = us * 0.94
		setGroup(UI.window, 1)
		UI.halo.BackgroundTransparency = 1
		UI.haloStroke.Transparency = 1
		tw(UI.scaler, { Scale = us }, 0.4, Enum.EasingStyle.Back)
		fadeGroup(UI.window, 0, 0.3)
		tw(UI.halo, { BackgroundTransparency = 0.95 }, 0.4)
		tw(UI.haloStroke, { Transparency = 0.85 }, 0.4)
		local b = UI.browsers[UI.current]
		if b then b.onShow() end
	else
		tw(UI.scaler, { Scale = us * 0.94 }, 0.25)
		fadeGroup(UI.window, 1, 0.22)
		tw(UI.halo, { BackgroundTransparency = 1 }, 0.22)
		tw(UI.haloStroke, { Transparency = 1 }, 0.22)
		task.delay(State.settings.Animations and 0.28 or 0.02, function()
			if not UI.isOpen and UI.shell then
				UI.shell.Visible = false
			end
		end)
	end
end

function UI.setMinimized(state)
	UI.minimized = state
	for _, m in ipairs(UI.minMarks) do
		tw(m, {
			Size = state and UDim2.fromOffset(10, 8) or UDim2.fromOffset(10, 2),
		}, 0.2)
	end
	tw(UI.shell, { Size = UDim2.fromOffset(UI.uw, state and HEADER or UI.uh) }, 0.3)
end

function UI.switchTo(name, instant)
	if UI.current == name then return end
	local old = UI.current
	UI.current = name
	Accent.set(THEME.accents[name], instant)
	local idx = TAB_INDEX[name]
	tw(UI.indicator, { Position = UDim2.fromOffset(0, UI.tabY(idx) + 10) }, 0.35, Enum.EasingStyle.Back)
	tw(UI.glow, { Position = UDim2.fromOffset(0, UI.tabY(idx) + 10) }, 0.35, Enum.EasingStyle.Back)
	for tabName, t in pairs(UI.tabs) do
		t.paint(tabName == name)
	end

	local newPage = UI.pages[name]
	local dir = (old and TAB_INDEX[name] > TAB_INDEX[old]) and 1 or -1
	if old then
		local oldPage = UI.pages[old]
		tw(oldPage, { Position = UDim2.fromOffset(-dir * 22, 0) }, 0.22)
		fadeGroup(oldPage, 1, 0.18)
		task.delay(State.settings.Animations and 0.24 or 0.02, function()
			if UI.current ~= old then
				oldPage.Visible = false
			end
		end)
	end
	newPage.Position = UDim2.fromOffset(dir * 22, 0)
	setGroup(newPage, 1)
	newPage.Visible = true
	tw(newPage, { Position = UDim2.new() }, 0.32)
	fadeGroup(newPage, 0, 0.26)

	local b = UI.browsers[name]
	if b then
		b.onShow()
	else
		State.spin, State.glow = nil, nil
	end
end

function UI.rebuild(selectPath, selectKind)
	if not State.raw then return end
	State.entries = Repo.build(State.raw)
	for kind, b in pairs(UI.browsers) do
		local list = {}
		for _, e in ipairs(State.entries) do
			if e.kind == kind then
				table.insert(list, e)
			end
		end
		b.load(list)
	end
	UI.updateCounts()
	if selectPath and selectKind and UI.browsers[selectKind] then
		if UI.current ~= selectKind then
			UI.switchTo(selectKind)
		end
		UI.browsers[selectKind].selectPath(selectPath)
	end
end

function UI.refreshOwner()
	for _, b in pairs(UI.browsers) do
		b.refreshOwner()
	end
	if UI.ownerRow then
		UI.ownerRow.Visible = Owner.ok
	end
end

function UI.updateCounts()
	for kind, badge in pairs(UI.badges) do
		local b = UI.browsers[kind]
		badge.Text = b and tostring(#b.rows) or ""
	end
end

function UI.populate()
	if UI.scanning or not State.alive then return end
	UI.scanning = true
	status("scanning repo...")
	local raw = {}
	local err = Repo.scan(CONFIG.StartPath, 0, raw)
	if not State.alive then return end
	if err and #raw == 0 then
		status("scan failed: " .. err, THEME.bad)
		UI.scanning = false
		return
	end
	table.sort(raw, function(a, b)
		return string.lower(a.path) < string.lower(b.path)
	end)
	State.raw = raw
	Sync.pull()
	State.entries = Repo.build(raw)
	for kind, b in pairs(UI.browsers) do
		local list = {}
		for _, e in ipairs(State.entries) do
			if e.kind == kind then
				table.insert(list, e)
			end
		end
		b.load(list)
	end
	UI.updateCounts()
	UI.refreshFooter()
	if #State.entries == 0 then
		status("no scripts found", THEME.bad)
	else
		status(#State.entries .. " scripts loaded")
	end
	UI.scanning = false
end

local function creditNotifications()
	task.spawn(function()
		local icon
		pcall(function()
			local uid = Players:GetUserIdFromNameAsync(CONFIG.Credit.UserName)
			icon = Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if icon then
			State.avatar = icon
			if UI.avatarImage then
				UI.avatarImage.Image = icon
			end
		end
		local function send(title, text, withIcon)
			for _ = 1, 3 do
				local ok = pcall(function()
					StarterGui:SetCore("SendNotification", {
						Title = title,
						Text = text,
						Duration = 6,
						Icon = withIcon and icon or nil,
					})
				end)
				if ok then return end
				task.wait(0.5)
			end
		end
		send("Powers and weapons hub", "By DuaKNo", true)
		task.wait(0.4)
		send("Follow on Instagram", CONFIG.Credit.Instagram, false)
		task.wait(0.4)
		send("Join Discord server for more", CONFIG.Credit.Discord, false)
	end)
end

--// ============================== boot ==============================

local function main()
	loadSettings()
	buildUI()
	task.spawn(function()
		while State.alive do
			if State.settings.SimRadius > 0 then SimR.apply() end
			task.wait(1)
		end
	end)

	table.insert(Runner.listeners, function()
		for _, b in pairs(UI.browsers) do
			b.repaint()
		end
		UI.refreshFooter()
	end)

	-- animated bits: one heartbeat, only while the window is visible
	local clock = 0
	track(RunService.Heartbeat:Connect(function(dt)
		if not State.alive then return end
		if State.emblem and State.emblem.Parent and State.settings.Animations then
			State.emblemT = (State.emblemT or 0) + dt
			State.emblem.Rotation = 45 + State.emblemT * 40
		end
		if not UI.shell.Visible or UI.minimized then return end
		if not State.settings.Animations then return end
		clock += dt
		UI.strokeGrad.Rotation = (clock * 36) % 360
		UI.sweepGrad.Offset = Vector2.new(((clock * 0.45) % 2) - 1, 0)
		local spin = State.spin
		if spin and spin.outer and spin.outer.Parent then
			spin.outer.Rotation = 45 + clock * 18
			if spin.inner then
				spin.inner.Rotation = -clock * 28
			end
		end
		if spin and spin.orbit and spin.orbit.Parent then
				spin.orbit.Rotation = clock * 55
			end
			local glow = State.glow
			if glow and glow.Parent then
				glow.BackgroundTransparency = 0.89 + 0.05 * math.sin(clock * 2)
			end
			if State.settings.Particles then
			for _, p in ipairs(UI.particles) do
				p.y -= p.speed * dt
				if p.y < -0.05 then
					p.y = 1.05
					p.x = math.random()
				end
				p.f.Position = UDim2.fromScale(p.x + math.sin(clock * 0.6 + p.phase) * p.sway, p.y)
				p.f.BackgroundTransparency = 0.8 + 0.15 * math.sin(clock * 1.3 + p.phase)
			end
		end
	end))

	track(UserInputService.InputBegan:Connect(function(input, processed)
		if State.binding then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				State.binding = false
				if input.KeyCode ~= Enum.KeyCode.Escape then
					State.toggleKey = input.KeyCode
					State.settings.ToggleKey = input.KeyCode.Name
					saveSettings()
				end
				UI.keyBtn.Text = string.upper(State.toggleKey.Name)
				UI.refreshFooter()
			end
			return
		end
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == State.toggleKey then
			UI.setOpen(not UI.isOpen)
		end
	end))

	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then
			track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				UI.relayout()
			end))
		end
	end)

	UI.relayout()
	UI.switchTo("Powers", true)
	UI.refreshFooter()
	UI.setOpen(true)
	if State.settings.Debug then
		Debug.setVisible(true)
	end
	creditNotifications()
	task.spawn(UI.populate)
	local okFx, errFx = pcall(FxGlue.start)
	if not okFx then
		notify("Tools Hub fx", "start error: " .. tostring(errFx))
	end

	task.spawn(function()
		Owner.ok = Owner.verify()
		if Owner.ok and State.alive then
			UI.refreshOwner()
			status("owner mode on")
		end
	end)
	task.spawn(function()
		while State.alive do
			task.wait(math.max(5, CONFIG.Npoint.PollSeconds or 15))
			if State.alive and State.raw and Sync.url() then
				if Sync.pull() then
					UI.rebuild()
				end
			end
		end
	end)
end

local ok, err = pcall(main)
if not ok then
	Debug.err("boot: " .. tostring(err))
	notify("Tools Hub error", tostring(err))
end
