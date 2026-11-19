--// repo hub: adds a menu button to the roblox top bar, click it to list and run your repo scripts (client side)

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
	ButtonGap = 12,            -- space between the last top bar button and ours
	PanelWidth = 300,
	PanelMaxHeight = 360,
}

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local StarterGui = cloneref(game:GetService("StarterGui"))

local alive = true
local connections = {}
local function track(conn)
	table.insert(connections, conn)
	return conn
end

local gui
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
	bar = Color3.fromRGB(32, 32, 38),
	item = Color3.fromRGB(40, 40, 48),
	itemHover = Color3.fromRGB(52, 52, 62),
	text = Color3.fromRGB(235, 235, 240),
	sub = Color3.fromRGB(150, 150, 162),
	ok = Color3.fromRGB(90, 200, 120),
	bad = Color3.fromRGB(220, 90, 90),
	topbar = Color3.fromRGB(24, 25, 29),
}

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

local function mountGui(sg: ScreenGui)
	local ok = pcall(function()
		if gethui then
			sg.Parent = gethui()
		else
			sg.Parent = CoreGui
		end
	end)
	if not ok or not sg.Parent then
		sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

gui = Instance.new("ScreenGui")
gui.Name = "RepoHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mountGui(gui)

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

-- top bar button (three horizontal bars)
local menuBtn = Instance.new("TextButton")
menuBtn.Name = "RepoHubButton"
menuBtn.Text = ""
menuBtn.AutoButtonColor = false
menuBtn.Size = UDim2.fromOffset(44, 44)
menuBtn.Position = UDim2.fromOffset(250, 18)
menuBtn.BackgroundColor3 = COLORS.topbar
menuBtn.BackgroundTransparency = 0.15
menuBtn.BorderSizePixel = 0
menuBtn.ZIndex = 3
menuBtn.Parent = gui

do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = menuBtn

	for _, off in ipairs({ -6, 0, 6 }) do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.new(0.5, 0, 0.5, off)
		line.Size = UDim2.new(0.4, 0, 0, 2)
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BorderSizePixel = 0
		line.ZIndex = 4
		line.Parent = menuBtn
		corner(line, 1)
	end
end

-- dropdown panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(CONFIG.PanelWidth, CONFIG.PanelMaxHeight)
panel.BackgroundColor3 = COLORS.bg
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 5
panel.Parent = gui
corner(panel, 10)

local header = Instance.new("TextLabel")
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(14, 0)
header.Size = UDim2.new(1, -70, 0, 38)
header.Font = Enum.Font.GothamMedium
header.TextSize = 14
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextColor3 = COLORS.text
header.Text = CONFIG.Repo
header.ZIndex = 6
header.Parent = panel

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.fromOffset(52, 24)
refreshBtn.Position = UDim2.new(1, -62, 0, 7)
refreshBtn.BackgroundColor3 = COLORS.item
refreshBtn.BorderSizePixel = 0
refreshBtn.Font = Enum.Font.GothamMedium
refreshBtn.TextSize = 12
refreshBtn.TextColor3 = COLORS.text
refreshBtn.Text = "refresh"
refreshBtn.ZIndex = 6
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
status.ZIndex = 6
status.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(8, 42)
list.Size = UDim2.new(1, -16, 1, -74)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = 6
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function setStatus(text: string, color: Color3?)
	status.Text = text
	status.TextColor3 = color or COLORS.sub
end

--// top bar placement: sit to the right of the last button already there

local function findTopbarRightEdge()
	local rightEdge, centerY, height
	local roots = {}
	table.insert(roots, CoreGui)
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
					local cy = pos.Y + size.Y / 2
					local looksReal = obj.BackgroundTransparency < 1 or obj:IsA("GuiButton")
					if looksReal
						and size.X >= 30 and size.X <= 340
						and size.Y >= 30 and size.Y <= 70
						and cy >= 20 and cy <= 75 then
						local edge = pos.X + size.X
						if not rightEdge or edge > rightEdge then
							rightEdge = edge
							centerY = cy
							height = size.Y
						end
					end
				end
			end
		end
	end
	return rightEdge, centerY, height
end

local function placePanel()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
	local bp = menuBtn.AbsolutePosition
	local bs = menuBtn.AbsoluteSize
	local pw = CONFIG.PanelWidth
	local y = bp.Y + bs.Y + 8
	local ph = math.max(140, math.min(CONFIG.PanelMaxHeight, vp.Y - y - 8))
	local x = math.clamp(bp.X, 8, math.max(8, vp.X - pw - 8))
	panel.Size = UDim2.fromOffset(pw, ph)
	panel.Position = UDim2.fromOffset(x, y)
end

local function reposition()
	local edge, cy, h = findTopbarRightEdge()
	local size = 44
	if h then
		size = math.clamp(math.floor(h), 36, 64)
	end
	menuBtn.Size = UDim2.fromOffset(size, size)
	if edge then
		menuBtn.Position = UDim2.fromOffset(edge + CONFIG.ButtonGap, cy - size / 2)
	else
		menuBtn.Position = UDim2.fromOffset(250, 18)
	end
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

--// build list

local loaded = false
local scanning = false

local function setPanelOpen(open: boolean)
	panel.Visible = open
	backdrop.Visible = open
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
		btn.ZIndex = 7
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

track(menuBtn.MouseButton1Click:Connect(function()
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

task.spawn(function()
	while alive and gui do
		pcall(reposition)
		task.wait(2)
	end
end)

task.spawn(populate)
