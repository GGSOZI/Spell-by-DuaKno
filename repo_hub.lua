--// repo hub: fixed widget opens a Dex++ styled window with a vertical script list (client side)
--// title bar: < > dock left/right, - minimize, X close
--// running a new script stops and removes the previous one's tools, guis, threads and connections

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

	PositionX = 8,             -- fixed spot of the widget
	PositionY = 12,
	ButtonSize = 44,
	WindowWidth = 300,
	WindowHeight = 380,
	DefaultDock = "right",     -- "right" or "left"
	SlideSpeed = 0.22,
	SettleTime = 1.5,          -- seconds after a run that new tools/guis count as that script's
}

-- Dex++ palette
local DEX = {
	Main1 = Color3.fromRGB(52, 52, 52),
	Main2 = Color3.fromRGB(45, 45, 45),
	Outline1 = Color3.fromRGB(33, 33, 33),
	Outline2 = Color3.fromRGB(55, 55, 55),
	Button = Color3.fromRGB(60, 60, 60),
	ButtonHover = Color3.fromRGB(68, 68, 68),
	ButtonPress = Color3.fromRGB(40, 40, 40),
	Selection = Color3.fromRGB(11, 90, 175),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(170, 170, 170),
	Good = Color3.fromRGB(173, 241, 149),
	Important = Color3.fromRGB(255, 0, 0),
	CloseHover = Color3.fromRGB(196, 43, 28),
	Icon = Color3.fromRGB(18, 18, 21),
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

	local size = CONFIG.ButtonSize
	local TOP = 28 -- title bar height

	local function circle(parent: Instance)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = parent
	end

	local function pad(parent: Instance, left: number, right: number)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, left)
		p.PaddingRight = UDim.new(0, right)
		p.Parent = parent
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

	-- widget, same structure as the one you copied
	local widget = Instance.new("Frame")
	widget.Name = "Widget"
	widget.BackgroundTransparency = 1
	widget.Size = UDim2.fromOffset(size, size)
	widget.Position = UDim2.fromOffset(CONFIG.PositionX, CONFIG.PositionY)
	widget.ZIndex = 20
	widget.Parent = gui

	local iconButton = Instance.new("Frame")
	iconButton.Name = "IconButton"
	iconButton.BackgroundColor3 = DEX.Icon
	iconButton.BackgroundTransparency = 0.08
	iconButton.BorderSizePixel = 0
	iconButton.ClipsDescendants = true
	iconButton.Size = UDim2.fromScale(1, 1)
	iconButton.ZIndex = 2
	iconButton.Parent = widget
	circle(iconButton)

	local overlay = Instance.new("Frame")
	overlay.Name = "IconOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.BackgroundTransparency = 0.85
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 6
	overlay.Parent = iconButton
	circle(overlay)

	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.BackgroundTransparency = 1
	iconImage.Position = UDim2.fromScale(0.5, 0.5)
	iconImage.Size = UDim2.fromScale(0.5, 0.5)
	iconImage.Image = "http://www.roblox.com/asset/?id=6031280882"
	iconImage.ZIndex = 15
	iconImage.Parent = widget

	local clickRegion = Instance.new("TextButton")
	clickRegion.Name = "ClickRegion"
	clickRegion.BackgroundTransparency = 1
	clickRegion.Size = UDim2.fromScale(1, 1)
	clickRegion.Text = ""
	clickRegion.ZIndex = 20
	clickRegion.Parent = widget

	-- window, Dex++ look: Main1 title bar, Main2 body, Outline1 border
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundColor3 = DEX.Main2
	window.BackgroundTransparency = 0.1
	window.BorderColor3 = DEX.Outline1
	window.BorderSizePixel = 1
	window.ClipsDescendants = true
	window.Size = UDim2.fromOffset(CONFIG.WindowWidth, CONFIG.WindowHeight)
	window.Position = UDim2.fromOffset(0, 0)
	window.Visible = false
	window.ZIndex = 10
	window.Parent = gui

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = DEX.Main1
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.new(1, 0, 0, TOP)
	topBar.ZIndex = 11
	topBar.Parent = window

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(8, 0)
	title.Size = UDim2.new(1, -8 - 28 * 4, 1, 0)
	title.Font = Enum.Font.SourceSans
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextColor3 = DEX.Text
	title.Text = CONFIG.Repo
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
		b.TextSize = 16
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
	local dockRightBtn = titleButton(">", 3)
	local dockLeftBtn = titleButton("<", 4)

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
		btn.TextSize = 14
		btn.TextColor3 = DEX.Text
		btn.TextTransparency = 0.1
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

	local function setActive(btn: TextButton?)
		local old = activeBtn
		activeBtn = btn
		if old and old.Parent then
			old.BackgroundColor3 = DEX.Button
		end
		if btn then
			btn.BackgroundColor3 = DEX.Selection
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

	local refreshBtn = makeButton(controls, "refresh", 1, 28)
	local clearBtn = makeButton(controls, "clear", 2, 28)
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
	statusLabel.Text = "ready"
	statusLabel.ZIndex = 11
	statusLabel.Parent = body

	local function setStatus(text: string, color: Color3?)
		statusLabel.Text = text
		statusLabel.TextColor3 = color or DEX.Sub
	end

	-- vertical script list
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundColor3 = DEX.Main2
	list.BackgroundTransparency = 0
	list.BorderColor3 = DEX.Outline1
	list.BorderSizePixel = 1
	list.Position = UDim2.fromOffset(4, 58)
	list.Size = UDim2.new(1, -8, 1, -62)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = Color3.fromRGB(57, 57, 57)
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

	--// window state: open / close, dock, minimize

	local isOpen = false
	local minimized = false
	local dock = (CONFIG.DefaultDock == "left") and "left" or "right"

	local function windowRect()
		local vp = viewport()
		local w = math.min(CONFIG.WindowWidth, vp.X - 16)
		local y = CONFIG.PositionY + size + 8
		local h = math.max(140, math.min(CONFIG.WindowHeight, vp.Y - y - 8))
		local x = (dock == "right") and (vp.X - w - 8) or CONFIG.PositionX
		return x, y, w, h
	end

	local function goalProps()
		local x, y, w, h = windowRect()
		return UDim2.fromOffset(x, y), UDim2.fromOffset(w, minimized and TOP or h)
	end

	local function paintDock()
		dockRightBtn.TextColor3 = (dock == "right") and DEX.Sub or DEX.Text
		dockLeftBtn.TextColor3 = (dock == "left") and DEX.Sub or DEX.Text
	end
	paintDock()

	local function offscreenX(): number
		local _, _, w = windowRect()
		return (dock == "right") and viewport().X or -w - 8
	end

	local function setOpen(open: boolean)
		isOpen = open
		overlay.Visible = open
		if open then
			local pos, sz = goalProps()
			if not window.Visible then
				window.Size = sz
				window.Position = UDim2.fromOffset(offscreenX(), pos.Y.Offset)
				window.Visible = true
			end
			tweenTo(window, { Position = pos, Size = sz })
		else
			local _, y = windowRect()
			tweenTo(window, { Position = UDim2.fromOffset(offscreenX(), y) })
			task.delay(CONFIG.SlideSpeed + 0.03, function()
				if not isOpen and window then
					window.Visible = false
				end
			end)
		end
	end

	local function setDock(side: string)
		if dock == side then return end
		dock = side
		paintDock()
		if isOpen then
			local pos, sz = goalProps()
			tweenTo(window, { Position = pos, Size = sz })
		end
	end

	local function setMinimized(state: boolean)
		minimized = state
		minBtn.Text = state and "+" or "-"
		if isOpen then
			local pos, sz = goalProps()
			tweenTo(window, { Position = pos, Size = sz })
		end
	end

	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then
			track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if isOpen then
					local pos, sz = goalProps()
					window.Position = pos
					window.Size = sz
				end
			end))
		end
	end)

	--// remove the previous script: tools, guis, threads, connections

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

	local function buildEnv(fn, bucket)
		local okBase, base = pcall(getfenv, fn)
		if not okBase or type(base) ~= "table" then
			return nil
		end
		local function keep(th)
			table.insert(bucket, th)
			return th
		end
		local taskProxy = setmetatable({
			spawn = function(f, ...) return keep(task.spawn(f, ...)) end,
			defer = function(f, ...) return keep(task.defer(f, ...)) end,
			delay = function(t, f, ...) return keep(task.delay(t, f, ...)) end,
		}, { __index = task })
		local coProxy = setmetatable({
			create = function(f) return keep(coroutine.create(f)) end,
			wrap = function(f)
				local co = keep(coroutine.create(f))
				return function(...)
					local res = table.pack(coroutine.resume(co, ...))
					if not res[1] then
						error(res[2], 0)
					end
					return table.unpack(res, 2, res.n)
				end
			end,
		}, { __index = coroutine })
		return setmetatable({
			task = taskProxy,
			coroutine = coProxy,
			spawn = taskProxy.spawn,
			delay = taskProxy.delay,
		}, { __index = base, __newindex = base })
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
			setStatus("failed to fetch " .. entry.name, DEX.Important)
			notify("repo hub", "failed to fetch " .. entry.name)
			busy = false
			return
		end

		local fn, compileErr = loadstring(src, "=repohub_" .. entry.name)
		if not fn then
			setStatus("compile error in " .. entry.name, DEX.Important)
			notify("repo hub", "compile error in " .. entry.name)
			warn("[repo hub] " .. tostring(compileErr))
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

		local env = buildEnv(fn, run.threads)
		if env then
			pcall(setfenv, fn, env)
		end

		local th = task.spawn(function()
			local ok, runErr = pcall(fn)
			if ok then
				setStatus("running " .. entry.name, DEX.Good)
				notify("repo hub", "executed " .. entry.name)
			else
				setStatus("runtime error in " .. entry.name, DEX.Important)
				notify("repo hub", "runtime error in " .. entry.name)
				warn("[repo hub] " .. tostring(runErr))
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
		setStatus("scanning repo...")
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
			local btn = makeButton(list, label, i, 30, true)
			btn:SetAttribute("Entry", true)

			if currentRun and currentRun.path == entry.path then
				setActive(btn)
			end

			track(btn.MouseButton1Click:Connect(function()
				runEntry(entry, btn)
			end))
		end

		loaded = #entries > 0
		if #entries == 0 then
			setStatus("no scripts found in repo", DEX.Important)
		else
			setStatus(#entries .. " script(s)", DEX.Sub)
		end
		scanning = false
	end

	--// wiring

	track(clickRegion.MouseEnter:Connect(function()
		overlay.Visible = true
	end))
	track(clickRegion.MouseLeave:Connect(function()
		overlay.Visible = isOpen
	end))

	track(clickRegion.MouseButton1Click:Connect(function()
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

	track(dockRightBtn.MouseButton1Click:Connect(function()
		setDock("right")
	end))

	track(dockLeftBtn.MouseButton1Click:Connect(function()
		setDock("left")
	end))

	track(refreshBtn.MouseButton1Click:Connect(function()
		task.spawn(populate)
	end))

	track(clearBtn.MouseButton1Click:Connect(function()
		if stopCurrent() then
			setStatus("cleared", DEX.Sub)
			notify("repo hub", "removed the running script")
		else
			setStatus("nothing running", DEX.Sub)
		end
	end))

	track(unloadBtn.MouseButton1Click:Connect(function()
		cleanup()
	end))

	task.spawn(populate)
end

local ok, err = pcall(main)
if not ok then
	warn("[repo hub] " .. tostring(err))
	notify("repo hub error", tostring(err))
end
