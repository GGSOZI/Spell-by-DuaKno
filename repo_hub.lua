--// repo hub: top bar style button, click it to list and run your repo scripts (client side)

local cloneref = cloneref or function(x) return x end

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local StarterGui = cloneref(game:GetService("StarterGui"))

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

	StartX = 8,                -- first spot checked, same as the widget you copied
	StartY = 12,               -- used when no top bar is found to line up with
	ButtonSize = 44,           -- used when no top bar is found to copy the size from
	ButtonGap = 8,             -- space between buttons
	MaxRows = 3,               -- rows it can drop down to when the row is full
	PanelWidth = 300,
	PanelMaxHeight = 360,
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
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 5 })
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

	--// gui

	local COLORS = {
		bg = Color3.fromRGB(24, 24, 28),
		item = Color3.fromRGB(40, 40, 48),
		itemHover = Color3.fromRGB(52, 52, 62),
		text = Color3.fromRGB(235, 235, 240),
		sub = Color3.fromRGB(150, 150, 162),
		ok = Color3.fromRGB(90, 200, 120),
		bad = Color3.fromRGB(220, 90, 90),
		topbar = Color3.fromRGB(18, 18, 21),
	}

	local function corner(parent: Instance, r: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = parent
		return c
	end

	local function circle(parent: Instance)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = parent
		return c
	end

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

	-- invisible layer behind the panel, click it to close
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundTransparency = 1
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	-- widget, same structure as the one you copied
	local widget = Instance.new("Frame")
	widget.Name = "Widget"
	widget.BackgroundTransparency = 1
	widget.Size = UDim2.fromOffset(CONFIG.ButtonSize, CONFIG.ButtonSize)
	widget.Position = UDim2.fromOffset(CONFIG.StartX, CONFIG.StartY)
	widget.ZIndex = 20
	widget.Parent = gui

	local iconButton = Instance.new("Frame")
	iconButton.Name = "IconButton"
	iconButton.BackgroundColor3 = COLORS.topbar
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

	-- dropdown panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(CONFIG.PanelWidth, CONFIG.PanelMaxHeight)
	panel.BackgroundColor3 = COLORS.bg
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 30
	panel.Parent = gui
	corner(panel, 10)

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(14, 0)
	header.Size = UDim2.new(1, -90, 0, 38)
	header.Font = Enum.Font.GothamMedium
	header.TextSize = 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = COLORS.text
	header.Text = CONFIG.Repo
	header.Parent = panel

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.fromOffset(60, 24)
	refreshBtn.Position = UDim2.new(1, -70, 0, 7)
	refreshBtn.BackgroundColor3 = COLORS.item
	refreshBtn.BorderSizePixel = 0
	refreshBtn.Font = Enum.Font.GothamMedium
	refreshBtn.TextSize = 12
	refreshBtn.TextColor3 = COLORS.text
	refreshBtn.Text = "refresh"
	refreshBtn.Parent = panel
	corner(refreshBtn, 6)

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0, 14, 1, -26)
	status.Size = UDim2.new(1, -28, 0, 20)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = COLORS.sub
	status.Text = "ready"
	status.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 42)
	list.Size = UDim2.new(1, -16, 1, -74)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 3
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function setStatus(text: string, color: Color3?)
		status.Text = text
		status.TextColor3 = color or COLORS.sub
	end

	--// slot finder: checks what already sits in the top area, takes the first free spot,
	--// shifts right past anything in the way, drops to the next row when the row is full

	local function collectItems(vp: Vector2)
		local items = {}
		local rowH, rowCY = nil, nil
		local roots = { CoreGui }
		if gethui then
			local ok, h = pcall(gethui)
			if ok and h and h ~= CoreGui then
				table.insert(roots, h)
			end
		end
		local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
		if pg then
			table.insert(roots, pg)
		end

		for _, root in ipairs(roots) do
			local ok, desc = pcall(function()
				return root:GetDescendants()
			end)
			if ok then
				for _, obj in ipairs(desc) do
					if obj:IsA("GuiObject") and obj.Visible and not obj:IsDescendantOf(gui) then
						local size = obj.AbsoluteSize
						local pos = obj.AbsolutePosition
						local looksReal = obj.BackgroundTransparency < 1 or obj:IsA("GuiButton")
							or obj:IsA("ImageLabel") or obj:IsA("TextLabel")
						if looksReal
							and size.X >= 20 and size.X <= 340
							and size.Y >= 20 and size.Y <= 90
							and pos.X >= -2 and pos.X + size.X <= vp.X + 2
							and pos.Y >= -2 and pos.Y <= 220 then
							table.insert(items, {
								l = pos.X, t = pos.Y, r = pos.X + size.X, b = pos.Y + size.Y,
							})
							local cy = pos.Y + size.Y / 2
							if size.Y >= 30 and size.Y <= 70 and cy >= 20 and cy <= 75 then
								if not rowH or size.Y > rowH then
									rowH = size.Y
									rowCY = cy
								end
							end
						end
					end
				end
			end
		end
		return items, rowH, rowCY
	end

	local function blocker(l: number, t: number, r: number, b: number, items)
		for _, it in ipairs(items) do
			if l < it.r and r > it.l and t < it.b and b > it.t then
				return it
			end
		end
		return nil
	end

	local function findSlot(size: number, startY: number, items, vp: Vector2)
		local gap = CONFIG.ButtonGap
		local y = startY
		for _ = 1, CONFIG.MaxRows do
			local x = CONFIG.StartX
			local guard = 0
			while x + size <= vp.X - 8 and guard < 80 do
				guard += 1
				local hit = blocker(x, y, x + size, y + size, items)
				if not hit then
					return x, y
				end
				x = hit.r + gap
			end
			y = y + size + gap
		end
		return CONFIG.StartX, startY
	end

	local function placePanel()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
		local bp = widget.AbsolutePosition
		local bs = widget.AbsoluteSize
		local pw = CONFIG.PanelWidth
		local y = bp.Y + bs.Y + 8
		local ph = math.max(140, math.min(CONFIG.PanelMaxHeight, vp.Y - y - 8))
		local x = math.clamp(bp.X, 8, math.max(8, vp.X - pw - 8))
		panel.Size = UDim2.fromOffset(pw, ph)
		panel.Position = UDim2.fromOffset(x, y)
	end

	local function reposition()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
		local items, rowH, rowCY = collectItems(vp)
		local size = rowH and math.clamp(math.floor(rowH + 0.5), 36, 64) or CONFIG.ButtonSize
		local startY = rowCY and (rowCY - size / 2) or CONFIG.StartY
		local x, y = findSlot(size, startY, items, vp)
		widget.Size = UDim2.fromOffset(size, size)
		widget.Position = UDim2.fromOffset(x, y)
		if panel.Visible then
			placePanel()
		end
	end

	--// run a file from the repo

	local running = false

	local function runEntry(entry)
		if running then return end
		running = true
		setStatus("fetching " .. entry.name .. "...")

		local src = httpGet(entry.url, false)
		if not src then
			setStatus("failed to fetch " .. entry.name, COLORS.bad)
			notify("repo hub", "failed to fetch " .. entry.name)
			running = false
			return
		end

		local fn, compileErr = loadstring(src)
		if not fn then
			setStatus("compile error in " .. entry.name, COLORS.bad)
			notify("repo hub", "compile error in " .. entry.name)
			warn("[repo hub] " .. tostring(compileErr))
			running = false
			return
		end

		task.spawn(function()
			local ok, runErr = pcall(fn)
			if ok then
				setStatus("executed " .. entry.name, COLORS.ok)
				notify("repo hub", "executed " .. entry.name)
			else
				setStatus("runtime error in " .. entry.name, COLORS.bad)
				notify("repo hub", "runtime error in " .. entry.name)
				warn("[repo hub] " .. tostring(runErr))
			end
			running = false
		end)
	end

	--// list

	local loaded = false
	local scanning = false

	local function setPanelOpen(open: boolean)
		panel.Visible = open
		backdrop.Visible = open
		overlay.Visible = open
		if open then
			placePanel()
		end
	end

	local function clearList()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

	local function populate()
		if scanning then return end
		scanning = true
		clearList()
		setStatus("scanning repo...")
		local entries = {}
		local err = scan(CONFIG.StartPath, 0, entries)

		if err and #entries == 0 then
			setStatus("scan failed: " .. err, COLORS.bad)
			loaded = false
			scanning = false
			return
		end

		table.sort(entries, function(a, b)
			return string.lower(a.path) < string.lower(b.path)
		end)

		for i, entry in ipairs(entries) do
			local btn = Instance.new("TextButton")
			btn.Name = entry.name
			btn.LayoutOrder = i
			btn.Size = UDim2.new(1, -6, 0, 36)
			btn.BackgroundColor3 = COLORS.item
			btn.BorderSizePixel = 0
			btn.AutoButtonColor = false
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 13
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.TextColor3 = COLORS.text
			btn.TextTruncate = Enum.TextTruncate.AtEnd
			btn.Text = "   " .. (string.gsub(entry.path, "%.%w+$", ""))
			btn.Parent = list
			corner(btn, 8)

			track(btn.MouseEnter:Connect(function()
				btn.BackgroundColor3 = COLORS.itemHover
			end))
			track(btn.MouseLeave:Connect(function()
				btn.BackgroundColor3 = COLORS.item
			end))
			track(btn.MouseButton1Click:Connect(function()
				setPanelOpen(false)
				runEntry(entry)
			end))
		end

		loaded = #entries > 0
		if #entries == 0 then
			setStatus("no scripts found in repo", COLORS.bad)
		else
			setStatus(#entries .. " script(s) found", COLORS.ok)
		end
		scanning = false
	end

	--// wiring

	track(clickRegion.MouseEnter:Connect(function()
		overlay.Visible = true
	end))
	track(clickRegion.MouseLeave:Connect(function()
		overlay.Visible = panel.Visible
	end))

	track(clickRegion.MouseButton1Click:Connect(function()
		local willOpen = not panel.Visible
		setPanelOpen(willOpen)
		if willOpen and not loaded then
			task.spawn(populate)
		end
	end))

	track(backdrop.MouseButton1Click:Connect(function()
		setPanelOpen(false)
	end))

	track(refreshBtn.MouseButton1Click:Connect(function()
		task.spawn(populate)
	end))

	pcall(reposition)

	task.spawn(function()
		while alive and gui do
			task.wait(2)
			pcall(reposition)
		end
	end)

	task.spawn(populate)
end

local ok, err = pcall(main)
if not ok then
	warn("[repo hub] " .. tostring(err))
	notify("repo hub error", tostring(err))
end
