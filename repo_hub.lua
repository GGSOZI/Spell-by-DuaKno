--// spells hub: a < tab in the top right corner opens a window listing every script in your repo (client side)
--// tap a row to run it. running a new one removes the previous one's tools, guis, threads and connections

local cloneref = cloneref or function(x) return x end

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local StarterGui = cloneref(game:GetService("StarterGui"))
local TweenService = cloneref(game:GetService("TweenService"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local CONFIG = {
	Owner = "GGSOZI",
	Repo = "Spell-by-DuaKno",
	Branch = "main",
	StartPath = "",            -- "" = repo root, or a folder like "scripts"
	SelfFile = "repo_hub.lua", -- this file's name in the repo, it gets skipped
	MaxDepth = 3,              -- how many folders deep to scan
	Token = nil,               -- optional github token string, avoids rate limit
	Extensions = { lua = true, luau = true, txt = true },
	AllowNoExtension = true,   -- files with no extension, like "1 Snowgrave and Iceshock by DuaKNo"

	TabY = 12,                 -- height of the < tab from the top of the screen
	TabHeight = 52,
	WindowWidth = 292,
	WindowHeight = 372,
	SlideSpeed = 0.28,
	SettleTime = 1.5,          -- seconds after a run that new tools/guis count as that script's
}

local COLOR = {
	window = Color3.fromRGB(12, 13, 17),
	header = Color3.fromRGB(17, 19, 25),
	line = Color3.fromRGB(30, 34, 44),
	edge = Color3.fromRGB(40, 46, 60),
	row = Color3.fromRGB(12, 13, 17),
	rowHover = Color3.fromRGB(22, 25, 33),
	rowActive = Color3.fromRGB(18, 30, 42),
	accent = Color3.fromRGB(110, 200, 255),
	text = Color3.fromRGB(214, 222, 235),
	dim = Color3.fromRGB(122, 132, 148),
	good = Color3.fromRGB(120, 230, 170),
	bad = Color3.fromRGB(255, 96, 110),
	badSoft = Color3.fromRGB(58, 24, 30),
}

local alive = true
local connections = {}
local gui

local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function cleanup()
	alive = false
	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	connections = {}
	if gui then
		pcall(function() gui:Destroy() end)
		gui = nil
	end
end

if getgenv then
	if getgenv().RepoHubCleanup then
		pcall(getgenv().RepoHubCleanup)
	end
	getgenv().RepoHubCleanup = cleanup
end

local function notify(title: string, text: string)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 4 })
	end)
end

local function main()
	--// http

	local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
	local lastStatus = nil

	local function httpGet(url: string, withAuth: boolean?): string?
		lastStatus = nil
		local headers = { ["User-Agent"] = "repo-hub" }
		if withAuth and CONFIG.Token then
			headers["Authorization"] = "Bearer " .. CONFIG.Token
		end
		if httpRequest then
			local ok, res = pcall(httpRequest, { Url = url, Method = "GET", Headers = headers })
			if ok and res then
				lastStatus = res.StatusCode
			end
			if ok and res and res.StatusCode == 200 then
				return res.Body
			end
			if ok and res and res.StatusCode == 403 then
				return nil, "rate limited"
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

	--// repo scan

	local function hasValidExt(name: string): boolean
		local ext = string.match(name, "%.([%w_]+)$")
		if ext == nil then
			return CONFIG.AllowNoExtension
		end
		return CONFIG.Extensions[string.lower(ext)] == true
	end

	local function scan(path: string, depth: number, out: { any })
		local url = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(
			CONFIG.Owner, CONFIG.Repo, path, CONFIG.Branch
		)
		local body, err = httpGet(url, true)
		if not body then
			return err or ("http " .. tostring(lastStatus or "no response") .. " (check Owner/Repo/Branch)")
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
				if not isSelf and hasValidExt(item.name) and item.download_url then
					table.insert(out, { name = item.name, path = item.path, url = item.download_url })
				end
			elseif item.type == "dir" and depth < CONFIG.MaxDepth then
				scan(item.path, depth + 1, out)
			end
		end
		return nil
	end

	--// gui base

	gui = Instance.new("ScreenGui")
	gui.Name = "RepoHub"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local mounted = pcall(function()
		if gethui then
			gui.Parent = gethui()
		else
			gui.Parent = CoreGui
		end
	end)
	if not mounted or not gui.Parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	local HEADER = 36
	local TOOLBAR = 28
	local FOOTER = 24

	local function viewport(): Vector2
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize or Vector2.new(800, 400)
	end

	local function tweenTo(obj: Instance, props, t: number?, style: Enum.EasingStyle?)
		local tw = TweenService:Create(
			obj,
			TweenInfo.new(t or CONFIG.SlideSpeed, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			props
		)
		tw:Play()
		return tw
	end

	local function round(parent: Instance, r: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = parent
	end

	local function edge(parent: Instance)
		local s = Instance.new("UIStroke")
		s.Color = COLOR.edge
		s.Thickness = 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = parent
		return s
	end

	local function solid(parent: Instance, color: Color3, size: UDim2, pos: UDim2)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Size = size
		f.Position = pos
		f.Parent = parent
		return f
	end

	-- the < tab in the top right corner
	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AutoButtonColor = false
	tab.AnchorPoint = Vector2.new(1, 0)
	tab.Position = UDim2.new(1, 0, 0, CONFIG.TabY)
	tab.Size = UDim2.fromOffset(24, CONFIG.TabHeight)
	tab.BackgroundColor3 = COLOR.header
	tab.BorderSizePixel = 0
	tab.Font = Enum.Font.Code
	tab.TextSize = 18
	tab.TextColor3 = COLOR.dim
	tab.Text = "<"
	tab.ZIndex = 30
	tab.Parent = gui
	round(tab, 6)
	edge(tab)

	local tabMark = solid(tab, COLOR.accent, UDim2.fromOffset(2, 22), UDim2.new(0, 0, 0.5, -11))
	tabMark.ZIndex = 31

	track(tab.MouseEnter:Connect(function()
		tab.TextColor3 = COLOR.accent
		tab.BackgroundColor3 = COLOR.rowHover
	end))
	track(tab.MouseLeave:Connect(function()
		tab.TextColor3 = COLOR.dim
		tab.BackgroundColor3 = COLOR.header
	end))

	-- window
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(1, 0)
	window.BackgroundColor3 = COLOR.window
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Size = UDim2.fromOffset(CONFIG.WindowWidth, CONFIG.WindowHeight)
	window.Position = UDim2.new(1, CONFIG.WindowWidth + 16, 0, CONFIG.TabY + CONFIG.TabHeight + 8)
	window.Visible = false
	window.ZIndex = 10
	window.Parent = gui
	round(window, 6)
	edge(window)

	local header = solid(window, COLOR.header, UDim2.new(1, 0, 0, HEADER), UDim2.new())
	header.Name = "Header"
	header.ZIndex = 11

	local accentLine = solid(header, COLOR.accent, UDim2.new(1, 0, 0, 2), UDim2.new())
	accentLine.ZIndex = 12

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 2)
	title.Size = UDim2.new(1, -90, 1, -2)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.RichText = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = COLOR.text
	title.Text = 'SPELLS <font color="#6EC8FF">/</font> <font size="11" color="#7A8494">DUAKNO</font>'
	title.ZIndex = 12
	title.Parent = header

	-- header buttons with drawn icons, no glyphs
	local function headerButton(kind: string, indexFromRight: number)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = COLOR.rowHover
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.Text = ""
		b.Size = UDim2.new(0, 32, 1, -2)
		b.Position = UDim2.new(1, -32 * indexFromRight, 0, 2)
		b.ZIndex = 12
		b.Parent = header

		local marks = {}
		if kind == "min" then
			local m = solid(b, COLOR.dim, UDim2.fromOffset(10, 2), UDim2.new(0.5, -5, 0.5, -1))
			m.ZIndex = 13
			table.insert(marks, m)
		else
			for _, rot in ipairs({ 45, -45 }) do
				local m = solid(b, COLOR.dim, UDim2.fromOffset(14, 2), UDim2.new(0.5, -7, 0.5, -1))
				m.Rotation = rot
				m.ZIndex = 13
				table.insert(marks, m)
			end
		end

		local hoverBg = (kind == "close") and COLOR.badSoft or COLOR.rowHover
		local hoverFg = (kind == "close") and COLOR.bad or COLOR.accent

		track(b.MouseEnter:Connect(function()
			b.BackgroundColor3 = hoverBg
			b.BackgroundTransparency = 0
			for _, m in ipairs(marks) do
				m.BackgroundColor3 = hoverFg
			end
		end))
		track(b.MouseLeave:Connect(function()
			b.BackgroundTransparency = 1
			for _, m in ipairs(marks) do
				m.BackgroundColor3 = COLOR.dim
			end
		end))
		return b, marks
	end

	local closeBtn = headerButton("close", 1)
	local minBtn, minMarks = headerButton("min", 2)

	-- toolbar: plain text actions split by thin dividers
	local toolbar = solid(window, COLOR.window, UDim2.new(1, 0, 0, TOOLBAR), UDim2.fromOffset(0, HEADER))
	toolbar.Name = "Toolbar"
	toolbar.ZIndex = 9
	solid(toolbar, COLOR.line, UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 1, -1)).ZIndex = 12

	local function toolButton(text: string, index: number, danger: boolean?)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1 / 3, 0, 1, -1)
		b.Position = UDim2.new((index - 1) / 3, 0, 0, 0)
		b.Font = Enum.Font.Code
		b.TextSize = 12
		b.TextColor3 = COLOR.dim
		b.Text = text
		b.ZIndex = 12
		b.Parent = toolbar

		local hot = danger and COLOR.bad or COLOR.accent
		track(b.MouseEnter:Connect(function()
			b.TextColor3 = hot
		end))
		track(b.MouseLeave:Connect(function()
			b.TextColor3 = COLOR.dim
		end))
		track(b.MouseButton1Down:Connect(function()
			b.TextTransparency = 0.5
		end))
		track(b.MouseButton1Up:Connect(function()
			b.TextTransparency = 0
		end))

		if index > 1 then
			solid(toolbar, COLOR.line, UDim2.new(0, 1, 0, 14), UDim2.new((index - 1) / 3, 0, 0.5, -7)).ZIndex = 12
		end
		return b
	end

	local refreshBtn = toolButton("RELOAD", 1)
	local clearBtn = toolButton("DISPEL", 2)
	local unloadBtn = toolButton("UNLOAD", 3, true)

	-- footer status line
	local footer = solid(window, COLOR.header, UDim2.new(1, 0, 0, FOOTER), UDim2.new(0, 0, 1, -FOOTER))
	footer.Name = "Footer"
	footer.ZIndex = 9
	solid(footer, COLOR.line, UDim2.new(1, 0, 0, 1), UDim2.new()).ZIndex = 12

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(12, 1)
	statusLabel.Size = UDim2.new(1, -24, 1, -1)
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 12
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.TextColor3 = COLOR.dim
	statusLabel.Text = "> idle"
	statusLabel.ZIndex = 12
	statusLabel.Parent = footer

	local function setStatus(text: string, color: Color3?)
		statusLabel.Text = "> " .. text
		statusLabel.TextColor3 = color or COLOR.dim
	end

	-- the list
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, HEADER + TOOLBAR)
	list.Size = UDim2.new(1, 0, 1, -(HEADER + TOOLBAR + FOOTER))
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 2
	list.ScrollBarImageColor3 = COLOR.accent
	list.ElasticBehavior = Enum.ElasticBehavior.Never
	list.ZIndex = 9
	list.Parent = window

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 0)
	listLayout.Parent = list

	--// rows

	local activeBtn = nil
	local rows = {}

	local function paintRow(btn: TextButton)
		local r = rows[btn]
		if not r then return end
		local active = (btn == activeBtn)
		r.bar.BackgroundTransparency = active and 0 or 1
		r.name.TextColor3 = active and COLOR.accent or COLOR.text
		r.index.TextColor3 = active and COLOR.accent or COLOR.dim
		if active then
			r.tag.Text = "ACTIVE"
			r.tag.TextColor3 = COLOR.accent
		else
			r.tag.Text = r.hover and "RUN" or ""
			r.tag.TextColor3 = COLOR.dim
		end
		btn.BackgroundColor3 = active and COLOR.rowActive or COLOR.rowHover
		btn.BackgroundTransparency = (active or r.hover) and 0 or 1
	end

	local function setActive(btn: TextButton?)
		local old = activeBtn
		activeBtn = btn
		if old and old.Parent then
			paintRow(old)
		end
		if btn then
			paintRow(btn)
		end
	end

	local function flashRow(btn: TextButton)
		local r = rows[btn]
		if not r then return end
		r.flash.BackgroundTransparency = 0.65
		tweenTo(r.flash, { BackgroundTransparency = 1 }, 0.6)
	end

	local function makeRow(index: number, label: string)
		local btn = Instance.new("TextButton")
		btn.Name = "Row"
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = COLOR.rowHover
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.Size = UDim2.new(1, 0, 0, 36)
		btn.LayoutOrder = index
		btn.ZIndex = 12
		btn:SetAttribute("Entry", true)
		btn.Parent = list

		local flash = solid(btn, COLOR.accent, UDim2.fromScale(1, 1), UDim2.new())
		flash.BackgroundTransparency = 1
		flash.ZIndex = 12

		local bar = solid(btn, COLOR.accent, UDim2.fromOffset(3, 20), UDim2.new(0, 0, 0.5, -10))
		bar.BackgroundTransparency = 1
		bar.ZIndex = 14

		local idx = Instance.new("TextLabel")
		idx.BackgroundTransparency = 1
		idx.Position = UDim2.fromOffset(14, 0)
		idx.Size = UDim2.fromOffset(22, 36)
		idx.Font = Enum.Font.Code
		idx.TextSize = 12
		idx.TextXAlignment = Enum.TextXAlignment.Left
		idx.TextColor3 = COLOR.dim
		idx.Text = string.format("%02d", index)
		idx.ZIndex = 14
		idx.Parent = btn

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(44, 0)
		name.Size = UDim2.new(1, -44 - 64, 1, 0)
		name.Font = Enum.Font.GothamMedium
		name.TextSize = 13
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = COLOR.text
		name.Text = label
		name.ZIndex = 14
		name.Parent = btn

		local tag = Instance.new("TextLabel")
		tag.BackgroundTransparency = 1
		tag.Position = UDim2.new(1, -64, 0, 0)
		tag.Size = UDim2.fromOffset(52, 36)
		tag.Font = Enum.Font.Code
		tag.TextSize = 10
		tag.TextXAlignment = Enum.TextXAlignment.Right
		tag.TextColor3 = COLOR.dim
		tag.Text = ""
		tag.ZIndex = 14
		tag.Parent = btn

		solid(btn, COLOR.line, UDim2.new(1, -24, 0, 1), UDim2.new(0, 12, 1, -1)).ZIndex = 13

		rows[btn] = { bar = bar, name = name, index = idx, tag = tag, flash = flash, hover = false }

		track(btn.MouseEnter:Connect(function()
			rows[btn].hover = true
			paintRow(btn)
		end))
		track(btn.MouseLeave:Connect(function()
			rows[btn].hover = false
			paintRow(btn)
		end))
		return btn
	end

	--// window state: open / close, minimize

	local isOpen = false
	local minimized = false

	local function metrics()
		local vp = viewport()
		local w = math.min(CONFIG.WindowWidth, vp.X - 56)
		local y = CONFIG.TabY + CONFIG.TabHeight + 8
		local h = math.max(160, math.min(CONFIG.WindowHeight, vp.Y - y - 8))
		return w, y, h
	end

	local function openGoal()
		local w, y, h = metrics()
		return UDim2.new(1, -8, 0, y), UDim2.fromOffset(w, minimized and HEADER or h)
	end

	local function closedPos()
		local w, y = metrics()
		return UDim2.new(1, w + 16, 0, y)
	end

	local function setOpen(open: boolean)
		isOpen = open
		tab.Text = open and ">" or "<"
		if open then
			local pos, sz = openGoal()
			if not window.Visible then
				window.Size = sz
				window.Position = closedPos()
				window.Visible = true
			end
			tweenTo(window, { Position = pos, Size = sz })
		else
			tweenTo(window, { Position = closedPos() })
			task.delay(CONFIG.SlideSpeed + 0.05, function()
				if not isOpen and window then
					window.Visible = false
				end
			end)
		end
	end

	local function setMinimized(state: boolean)
		minimized = state
		if state then
			task.delay(CONFIG.SlideSpeed + 0.05, function()
				if minimized then
					toolbar.Visible = false
					footer.Visible = false
					list.Visible = false
				end
			end)
		else
			toolbar.Visible = true
			footer.Visible = true
			list.Visible = true
		end
		-- the minimize mark becomes a box edge when collapsed
		for _, m in ipairs(minMarks) do
			m.Size = state and UDim2.fromOffset(10, 8) or UDim2.fromOffset(10, 2)
			m.Position = state and UDim2.new(0.5, -5, 0.5, -4) or UDim2.new(0.5, -5, 0.5, -1)
		end
		if isOpen then
			local pos, sz = openGoal()
			tweenTo(window, { Position = pos, Size = sz })
		end
	end

	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then
			track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if isOpen then
					local pos, sz = openGoal()
					window.Position = pos
					window.Size = sz
				end
			end))
		end
	end)

	--// remove the previous script: tools, guis, threads, connections
	--// nothing here touches the script's environment

	local function snapshot()
		local set = {}
		local lp = Players.LocalPlayer
		local function take(root: Instance?, tools: boolean, guis: boolean)
			if not root then return end
			for _, c in ipairs(root:GetChildren()) do
				if tools and (c:IsA("Tool") or c:IsA("HopperBin")) then
					set[c] = true
				elseif guis and c:IsA("ScreenGui") and c ~= gui then
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
		pcall(function()
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
			add(mouse.Move)
			local ch = lp.Character
			if ch then
				local hum = ch:FindFirstChildOfClass("Humanoid")
				if hum then
					add(hum.Died)
					add(hum.StateChanged)
					add(hum.Running)
					add(hum.Jumping)
				end
				add(ch.DescendantAdded)
			end
		end)
		return sigs
	end

	local function killConnections(src: string?)
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

	local function killThreads(src: string?)
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

	local currentRun = nil

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

	local function stopCurrent(): boolean
		local run = currentRun
		if not run then
			return false
		end
		currentRun = nil
		finalizeRun(run)
		for _, th in ipairs(run.threads) do
			pcall(task.cancel, th)
		end
		killThreads(run.source)
		killConnections(run.source)
		for inst in pairs(run.created) do
			pcall(function() inst:Destroy() end)
		end
		setActive(nil)
		return true
	end

	--// run a repo file

	local busy = false

	local function runEntry(entry, btn: TextButton)
		if busy then return end
		busy = true
		setStatus("fetching " .. entry.name .. "...")

		local src = httpGet(entry.url, false)
		if not src then
			setStatus("fetch failed: " .. entry.name, COLOR.bad)
			notify("spells", "failed to fetch " .. entry.name)
			busy = false
			return
		end

		local fn, compileErr = loadstring(src, "=repohub_" .. entry.name)
		if not fn then
			setStatus("compile error: " .. entry.name, COLOR.bad)
			notify("spells", "compile error in " .. entry.name)
			warn("[spells] " .. tostring(compileErr))
			busy = false
			return
		end

		stopCurrent()

		local run = {
			name = entry.name,
			path = entry.path,
			threads = {},
			created = {},
			before = snapshot(),
			source = chunkSource(fn),
			finalized = false,
		}
		currentRun = run
		setActive(btn)
		flashRow(btn)

		local th = task.spawn(function()
			local ok, runErr = pcall(fn)
			if ok then
				setStatus("running " .. entry.name, COLOR.good)
				notify("spells", "running " .. entry.name)
			else
				setStatus("runtime error: " .. entry.name, COLOR.bad)
				notify("spells", "runtime error in " .. entry.name)
				warn("[spells] " .. tostring(runErr))
			end
		end)
		table.insert(run.threads, th)

		task.delay(CONFIG.SettleTime, function()
			if currentRun == run then
				finalizeRun(run)
			end
		end)

		busy = false
	end

	--// list

	local loaded = false
	local scanning = false

	local function clearEntries()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") and child:GetAttribute("Entry") then
				if child == activeBtn then
					activeBtn = nil
				end
				rows[child] = nil
				child:Destroy()
			end
		end
	end

	local function populate()
		if scanning then return end
		scanning = true
		clearEntries()
		setStatus("scanning repo...")
		local entries = {}
		local err = scan(CONFIG.StartPath, 0, entries)

		if err and #entries == 0 then
			setStatus("scan failed: " .. err, COLOR.bad)
			loaded = false
			scanning = false
			return
		end

		table.sort(entries, function(a, b)
			return string.lower(a.path) < string.lower(b.path)
		end)

		for i, entry in ipairs(entries) do
			local label = string.gsub(entry.path, "%.%w+$", "")
			local btn = makeRow(i, label)

			if currentRun and currentRun.path == entry.path then
				setActive(btn)
			end

			track(btn.MouseButton1Click:Connect(function()
				runEntry(entry, btn)
			end))
		end

		loaded = #entries > 0
		if #entries == 0 then
			setStatus("no scripts found", COLOR.bad)
		else
			setStatus(#entries .. " script(s) loaded")
		end
		scanning = false
	end

	--// wiring

	track(tab.MouseButton1Click:Connect(function()
		local willOpen = not isOpen
		setOpen(willOpen)
		if willOpen and not loaded then
			task.spawn(populate)
		end
	end))

	track(closeBtn.MouseButton1Click:Connect(function()
		setOpen(false)
	end))

	track(minBtn.MouseButton1Click:Connect(function()
		setMinimized(not minimized)
	end))

	track(refreshBtn.MouseButton1Click:Connect(function()
		task.spawn(populate)
	end))

	track(clearBtn.MouseButton1Click:Connect(function()
		if stopCurrent() then
			setStatus("removed the active script")
			notify("spells", "removed the active script")
		else
			setStatus("nothing active")
		end
	end))

	track(unloadBtn.MouseButton1Click:Connect(function()
		cleanup()
	end))

	task.spawn(populate)
end

local ok, err = pcall(main)
if not ok then
	warn("[spells] " .. tostring(err))
	notify("spells error", tostring(err))
end
