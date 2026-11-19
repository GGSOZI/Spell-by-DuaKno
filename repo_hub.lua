--// repo hub: scans your github repo, lists every other script, click to run (client side)

local CONFIG = {
	Owner = "YOUR_GITHUB_USERNAME",
	Repo = "YOUR_REPO_NAME",
	Branch = "main",
	StartPath = "",            -- "" = repo root, or a folder like "scripts"
	SelfFile = "repo_hub.lua", -- this file's name in the repo, it gets skipped
	MaxDepth = 3,              -- how many folders deep to scan
	Token = nil,               -- optional github token string, avoids rate limit
	Extensions = { lua = true, luau = true, txt = true },
}

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))

local connections = {}
local function track(conn)
	table.insert(connections, conn)
	return conn
end

local gui
local function cleanup()
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

--// http

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local function httpGet(url: string, withAuth: boolean?): string?
	local headers = { ["User-Agent"] = "repo-hub" }
	if withAuth and CONFIG.Token then
		headers["Authorization"] = "Bearer " .. CONFIG.Token
	end
	if httpRequest then
		local ok, res = pcall(httpRequest, { Url = url, Method = "GET", Headers = headers })
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
	return ext ~= nil and CONFIG.Extensions[string.lower(ext)] == true
end

local function scan(path: string, depth: number, out: { any })
	local url = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(
		CONFIG.Owner, CONFIG.Repo, path, CONFIG.Branch
	)
	local body, err = httpGet(url, true)
	if not body then
		return err or "fetch failed"
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
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mountGui(gui)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(320, 400)
main.Position = UDim2.new(0.5, -160, 0.5, -200)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 10)

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 38)
bar.BackgroundColor3 = COLORS.bar
bar.BorderSizePixel = 0
bar.Parent = main
corner(bar, 10)

local barFix = Instance.new("Frame")
barFix.Size = UDim2.new(1, 0, 0, 10)
barFix.Position = UDim2.new(0, 0, 1, -10)
barFix.BackgroundColor3 = COLORS.bar
barFix.BorderSizePixel = 0
barFix.Parent = bar

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -90, 1, 0)
title.Font = Enum.Font.GothamMedium
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = COLORS.text
title.Text = CONFIG.Repo
title.Parent = bar

local function barButton(text: string, xOffset: number)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(28, 24)
	b.Position = UDim2.new(1, xOffset, 0, 7)
	b.BackgroundColor3 = COLORS.item
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = COLORS.text
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = bar
	corner(b, 6)
	return b
end

local refreshBtn = barButton("R", -70)
local closeBtn = barButton("X", -36)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 12, 1, -26)
status.Size = UDim2.new(1, -24, 0, 20)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = COLORS.sub
status.Text = "ready"
status.Parent = main

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(10, 48)
list.Size = UDim2.new(1, -20, 1, -80)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function setStatus(text: string, color: Color3?)
	status.Text = text
	status.TextColor3 = color or COLORS.sub
end

--// drag

do
	local dragging = false
	local dragStart: Vector3
	local startPos: UDim2

	track(bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end))

	track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))

	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

--// run a file from the repo

local running = false

local function runEntry(entry, button: TextButton)
	if running then return end
	running = true
	setStatus("fetching " .. entry.name .. "...")

	local src = httpGet(entry.url, false)
	if not src then
		setStatus("failed to fetch " .. entry.name, COLORS.bad)
		running = false
		return
	end

	local fn, compileErr = loadstring(src)
	if not fn then
		setStatus("compile error in " .. entry.name, COLORS.bad)
		warn("[repo hub] " .. tostring(compileErr))
		running = false
		return
	end

	task.spawn(function()
		local ok, runErr = pcall(fn)
		if ok then
			setStatus("executed " .. entry.name, COLORS.ok)
			button.TextColor3 = COLORS.ok
		else
			setStatus("runtime error in " .. entry.name, COLORS.bad)
			warn("[repo hub] " .. tostring(runErr))
		end
		running = false
	end)
end

--// build list

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function populate()
	clearList()
	setStatus("scanning repo...")
	local entries = {}
	local err = scan(CONFIG.StartPath, 0, entries)

	if err and #entries == 0 then
		setStatus("scan failed: " .. err, COLORS.bad)
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
			runEntry(entry, btn)
		end))
	end

	if #entries == 0 then
		setStatus("no scripts found in repo", COLORS.bad)
	else
		setStatus(#entries .. " script(s) found", COLORS.ok)
	end
end

track(refreshBtn.MouseButton1Click:Connect(function()
	task.spawn(populate)
end))

track(closeBtn.MouseButton1Click:Connect(cleanup))

task.spawn(populate)
