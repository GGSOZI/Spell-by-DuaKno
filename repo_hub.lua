--// spellbook hub: a < tab in the top right corner opens an arcane Dex++ styled window (client side)
--// lists every script in your repo as a spell, tap one to cast it
--// casting a new spell removes the previous one's tools, guis, threads and connections

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
	TabHeight = 46,
	WindowWidth = 300,
	WindowHeight = 380,
	SlideSpeed = 0.22,
	SettleTime = 1.5,          -- seconds after a cast that new tools/guis count as that spell's
}

-- arcane palette on the Dex++ layout
local DEX = {
	Main1 = Color3.fromRGB(40, 26, 82),
	Main2 = Color3.fromRGB(24, 17, 44),
	Outline1 = Color3.fromRGB(70, 50, 130),
	Outline2 = Color3.fromRGB(90, 64, 170),
	Button = Color3.fromRGB(48, 36, 84),
	ButtonHover = Color3.fromRGB(68, 52, 118),
	ButtonPress = Color3.fromRGB(34, 26, 60),
	Selection = Color3.fromRGB(122, 64, 255),
	Glow = Color3.fromRGB(150, 100, 255),
	Text = Color3.fromRGB(240, 235, 255),
	Sub = Color3.fromRGB(170, 160, 205),
	Good = Color3.fromRGB(160, 255, 210),
	Important = Color3.fromRGB(255, 90, 120),
	CloseHover = Color3.fromRGB(196, 43, 70),
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

	local TOP = 30 -- title bar height

	local function pad(parent: Instance, left: number, right: number)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, left)
		p.PaddingRight = UDim.new(0, right)
		p.Parent = parent
	end

	local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness
		s.Transparency = transparency
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = parent
		return s
	end

	local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(a, b)
		g.Rotation = rotation
		g.Parent = parent
		return g
	end

	local function viewport(): Vector2
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize or Vector2.new(800, 400)
	end

	local function tweenTo(obj: Instance, props, t: number?)
		local tw = TweenService:Create(
			obj,
			TweenInfo.new(t or CONFIG.SlideSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			props
		)
		tw:Play()
		return tw
	end

	-- the < tab in the top right corner
	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AutoButtonColor = false
	tab.AnchorPoint = Vector2.new(1, 0)
	tab.Position = UDim2.new(1, 0, 0, CONFIG.TabY)
	tab.Size = UDim2.fromOffset(30, CONFIG.TabHeight)
	tab.BackgroundColor3 = DEX.Main1
	tab.BackgroundTransparency = 0.05
	tab.BorderSizePixel = 0
	tab.Font = Enum.Font.SourceSansBold
	tab.TextSize = 24
	tab.TextColor3 = DEX.Text
	tab.Text = "<"
	tab.ZIndex = 30
	tab.Parent = gui

	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = tab
	end
	gradient(tab, Color3.fromRGB(96, 56, 190), Color3.fromRGB(40, 26, 82), 90)
	local tabStroke = stroke(tab, DEX.Glow, 1.5, 0.3)

	-- window: Dex++ layout, Main1 title bar, Main2 body, outlined
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(1, 0)
	window.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	window.BackgroundTransparency = 0.04
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Size = UDim2.fromOffset(CONFIG.WindowWidth, CONFIG.WindowHeight)
	window.Position = UDim2.new(1, CONFIG.WindowWidth + 16, 0, CONFIG.TabY + CONFIG.TabHeight + 8)
	window.Visible = false
	window.ZIndex = 10
	window.Parent = gui
	gradient(window, Color3.fromRGB(32, 22, 58), Color3.fromRGB(16, 12, 30), 90)
	stroke(window, DEX.Glow, 1.5, 0.35)

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.new(1, 0, 0, TOP)
	topBar.ZIndex = 11
	topBar.Parent = window
	gradient(topBar, Color3.fromRGB(96, 56, 190), Color3.fromRGB(40, 26, 82), 0)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 0)
	title.Size = UDim2.new(1, -10 - 28 * 2, 1, 0)
	title.Font = Enum.Font.Fantasy
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextColor3 = DEX.Text
	title.Text = "🔮 Spellbook"
	title.ZIndex = 12
	title.Parent = topBar

	local function titleButton(text: string, indexFromRight: number, hoverColor: Color3?)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = DEX.ButtonHover
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.Size = UDim2.new(0, 28, 1, 0)
		b.Position = UDim2.new(1, -28 * indexFromRight, 0, 0)
		b.Font = Enum.Font.SourceSansBold
		b.TextSize = 18
		b.TextColor3 = DEX.Text
		b.Text = text
		b.ZIndex = 12
		b.Parent = topBar

		track(b.MouseEnter:Connect(function()
			b.BackgroundColor3 = hoverColor or DEX.ButtonHover
			b.BackgroundTransparency = 0
		end))
		track(b.MouseLeave:Connect(function()
			b.BackgroundTransparency = 1
		end))
		track(b.MouseButton1Down:Connect(function()
			b.BackgroundColor3 = DEX.ButtonPress
			b.BackgroundTransparency = 0
		end))
		track(b.MouseButton1Up:Connect(function()
			b.BackgroundColor3 = hoverColor or DEX.ButtonHover
		end))
		return b
	end

	local closeBtn = titleButton("X", 1, DEX.CloseHover)
	local minBtn = titleButton("-", 2)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, TOP)
	body.Size = UDim2.new(1, 0, 1, -TOP)
	body.ZIndex = 11
	body.Parent = window

	--// dex styled buttons

	local activeBtn = nil

	local function baseColor(btn: TextButton)
		return btn == activeBtn and DEX.Selection or DEX.Button
	end

	local function makeButton(parent: Instance, text: string, order: number, height: number, left: boolean?)
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.Size = UDim2.new(1, -6, 0, height)
		btn.BackgroundColor3 = DEX.Button
		btn.BorderColor3 = DEX.Outline2
		btn.BorderSizePixel = 1
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 15
		btn.TextColor3 = DEX.Text
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.Text = text
		btn.LayoutOrder = order
		btn.ZIndex = 12
		btn.Parent = parent
		if left then
			btn.TextXAlignment = Enum.TextXAlignment.Left
			pad(btn, 10, 10)
		end

		track(btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = btn == activeBtn and DEX.Selection or DEX.ButtonHover
		end))
		track(btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = baseColor(btn)
		end))
		track(btn.MouseButton1Down:Connect(function()
			btn.BackgroundColor3 = btn == activeBtn and DEX.Selection or DEX.ButtonPress
		end))
		track(btn.MouseButton1Up:Connect(function()
			btn.BackgroundColor3 = baseColor(btn)
		end))
		return btn
	end

	local function entryText(btn: TextButton, active: boolean)
		local label = btn:GetAttribute("Label") or ""
		btn.Text = (active and "⚡  " or "✨  ") .. label
	end

	local function setActive(btn: TextButton?)
		local old = activeBtn
		activeBtn = btn
		if old and old.Parent then
			old.BackgroundColor3 = DEX.Button
			entryText(old, false)
		end
		if btn then
			btn.BackgroundColor3 = DEX.Selection
			entryText(btn, true)
		end
	end

	-- controls row
	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.BackgroundTransparency = 1
	controls.Position = UDim2.fromOffset(4, 4)
	controls.Size = UDim2.new(1, -8, 0, 28)
	controls.ZIndex = 11
	controls.Parent = body

	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Padding = UDim.new(0, 4)
	controlsLayout.Parent = controls

	local refreshBtn = makeButton(controls, "reload", 1, 28)
	local clearBtn = makeButton(controls, "dispel", 2, 28)
	local unloadBtn = makeButton(controls, "unload", 3, 28)
	for _, b in ipairs({ refreshBtn, clearBtn, unloadBtn }) do
		b.Size = UDim2.new(1 / 3, -3, 1, 0)
	end

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(8, 36)
	statusLabel.Size = UDim2.new(1, -16, 0, 18)
	statusLabel.Font = Enum.Font.SourceSans
	statusLabel.TextSize = 14
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.TextColor3 = DEX.Sub
	statusLabel.Text = "the book is closed"
	statusLabel.ZIndex = 11
	statusLabel.Parent = body

	local function setStatus(text: string, color: Color3?)
		statusLabel.Text = text
		statusLabel.TextColor3 = color or DEX.Sub
	end

	-- vertical spell list
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundColor3 = Color3.fromRGB(16, 11, 30)
	list.BackgroundTransparency = 0.1
	list.BorderColor3 = DEX.Outline1
	list.BorderSizePixel = 1
	list.Position = UDim2.fromOffset(4, 58)
	list.Size = UDim2.new(1, -8, 1, -62)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = DEX.Glow
	list.ElasticBehavior = Enum.ElasticBehavior.Never
	list.ZIndex = 11
	list.Parent = body

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = list

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 3)
	listPadding.PaddingLeft = UDim.new(0, 3)
	listPadding.PaddingBottom = UDim.new(0, 3)
	listPadding.Parent = list

	--// window state: open / close, minimize

	local isOpen = false
	local minimized = false

	local function metrics()
		local vp = viewport()
		local w = math.min(CONFIG.WindowWidth, vp.X - 56)
		local y = CONFIG.TabY + CONFIG.TabHeight + 8
		local h = math.max(140, math.min(CONFIG.WindowHeight, vp.Y - y - 8))
		return w, y, h
	end

	local function openGoal()
		local w, y, h = metrics()
		return UDim2.new(1, -8, 0, y), UDim2.fromOffset(w, minimized and TOP or h)
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
			task.delay(CONFIG.SlideSpeed + 0.03, function()
				if not isOpen and window then
					window.Visible = false
				end
			end)
		end
	end

	local function setMinimized(state: boolean)
		minimized = state
		minBtn.Text = state and "+" or "-"
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

	-- the tab glows slowly
	task.spawn(function()
		local dim = false
		while alive and gui do
			tweenTo(tabStroke, { Transparency = dim and 0.15 or 0.75 }, 1.1)
			dim = not dim
			task.wait(1.1)
		end
	end)

	--// remove the previous spell: tools, guis, threads, connections
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

	--// cast a repo file

	local busy = false

	local function runEntry(entry, btn: TextButton)
		if busy then return end
		busy = true
		setStatus("summoning " .. entry.name .. "...")

		local src = httpGet(entry.url, false)
		if not src then
			setStatus("failed to fetch " .. entry.name, DEX.Important)
			notify("spellbook", "failed to fetch " .. entry.name)
			busy = false
			return
		end

		local fn, compileErr = loadstring(src, "=repohub_" .. entry.name)
		if not fn then
			setStatus("compile error in " .. entry.name, DEX.Important)
			notify("spellbook", "compile error in " .. entry.name)
			warn("[spellbook] " .. tostring(compileErr))
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

		local th = task.spawn(function()
			local ok, runErr = pcall(fn)
			if ok then
				setStatus("casting " .. entry.name, DEX.Good)
				notify("spellbook", "cast " .. entry.name)
			else
				setStatus("the spell failed: " .. entry.name, DEX.Important)
				notify("spellbook", "runtime error in " .. entry.name)
				warn("[spellbook] " .. tostring(runErr))
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
				child:Destroy()
			end
		end
	end

	local function populate()
		if scanning then return end
		scanning = true
		clearEntries()
		setStatus("searching the library...")
		local entries = {}
		local err = scan(CONFIG.StartPath, 0, entries)

		if err and #entries == 0 then
			setStatus("scan failed: " .. err, DEX.Important)
			loaded = false
			scanning = false
			return
		end

		table.sort(entries, function(a, b)
			return string.lower(a.path) < string.lower(b.path)
		end)

		for i, entry in ipairs(entries) do
			local label = string.gsub(entry.path, "%.%w+$", "")
			local btn = makeButton(list, "", i, 32, true)
			btn:SetAttribute("Entry", true)
			btn:SetAttribute("Label", label)
			entryText(btn, false)

			if currentRun and currentRun.path == entry.path then
				setActive(btn)
			end

			track(btn.MouseButton1Click:Connect(function()
				runEntry(entry, btn)
			end))
		end

		loaded = #entries > 0
		if #entries == 0 then
			setStatus("no spells found in the repo", DEX.Important)
		else
			setStatus(#entries .. " spell(s) ready", DEX.Sub)
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
			setStatus("dispelled", DEX.Sub)
			notify("spellbook", "removed the active spell")
		else
			setStatus("no active spell", DEX.Sub)
		end
	end))

	track(unloadBtn.MouseButton1Click:Connect(function()
		cleanup()
	end))

	task.spawn(populate)
end

local ok, err = pcall(main)
if not ok then
	warn("[spellbook] " .. tostring(err))
	notify("spellbook error", tostring(err))
end
