-- MenuClient: every button the player can press and the three panels they open. GO
-- PRIVATE (the base lock and its timer), UPGRADES, GO VIRAL (the rebirth) and the INDEX of
-- brainrots found. A press only sends a request: the server checks and decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local GameConfig = require(ReplicatedStorage.GameConfig)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer
local hud = script.Parent

local NAVY = Color3.fromRGB(15, 23, 42)
local openPanelName: string? = nil

local function style(gui: GuiObject, color: Color3, radius: number)
	gui.BackgroundColor3 = color
	gui.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function makeText(parent: Instance, position: UDim2, size: UDim2, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, position: UDim2, size: UDim2, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = string.gsub(text, "%A", "") .. "Button"
	button.Position = position
	button.Size = size
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0
	button.Text = text
	button.AutoButtonColor = true
	style(button, color, 0.25)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	padding.Parent = button
	button.Parent = parent
	return button
end

-- the column of four big buttons on the right edge, above the mobile jump button
local column = Instance.new("Frame")
column.Name = "Buttons"
column.AnchorPoint = Vector2.new(1, 0.5)
column.Position = UDim2.new(1, -10, 0.4, 0)
column.Size = UDim2.fromScale(0.17, 0.52)
column.BackgroundTransparency = 1
column.Parent = hud
local privateButton = makeButton(column, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), "GO PRIVATE", Color3.fromRGB(220, 38, 38))
local upgradesButton = makeButton(column, UDim2.fromScale(0, 0.26), UDim2.fromScale(1, 0.22), "UPGRADES", Color3.fromRGB(37, 99, 235))
local viralButton = makeButton(column, UDim2.fromScale(0, 0.52), UDim2.fromScale(1, 0.22), "GO VIRAL", Color3.fromRGB(219, 39, 119))
local indexButton = makeButton(column, UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), "INDEX", Color3.fromRGB(124, 58, 237))

-- one modal panel, refilled for whichever menu is open
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.45, 0.54)
panel.Size = UDim2.fromScale(0.62, 0.74)
panel.Visible = false
style(panel, NAVY, 0.06)
panel.Parent = hud
local panelTitle = makeText(panel, UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.76, 0.14), "", Color3.new(1, 1, 1))
local closeButton = makeButton(panel, UDim2.fromScale(0.86, 0.025), UDim2.fromScale(0.11, 0.13), "X", Color3.fromRGB(220, 38, 38))
local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromScale(0.04, 0.18)
content.Size = UDim2.fromScale(0.92, 0.78)
content.BackgroundTransparency = 1
content.Parent = panel

local function cash(): number
	return player:GetAttribute("Cash") or 0
end

local function fillUpgrades()
	panelTitle.Text = "UPGRADES"
	for row, key in GameConfig.UpgradeOrder do
		local definition = GameConfig.Upgrades[key]
		local level = player:GetAttribute(key .. "Level") or 0
		local cost = GameConfig.upgradeCost(key, level)
		local line = Instance.new("Frame")
		line.Position = UDim2.fromScale(0, (row - 1) * 0.34)
		line.Size = UDim2.fromScale(1, 0.3)
		style(line, Color3.fromRGB(30, 41, 59), 0.18)
		line.Parent = content
		makeText(line, UDim2.fromScale(0.03, 0.06), UDim2.fromScale(0.62, 0.48), definition.title .. "  " .. level .. "/" .. definition.maxLevel, Color3.new(1, 1, 1)).TextXAlignment = Enum.TextXAlignment.Left
		makeText(line, UDim2.fromScale(0.03, 0.56), UDim2.fromScale(0.62, 0.36), definition.blurb, Color3.fromRGB(148, 163, 184)).TextXAlignment = Enum.TextXAlignment.Left
		local affordable = cost ~= nil and cash() >= cost
		local buy = makeButton(line, UDim2.fromScale(0.68, 0.12), UDim2.fromScale(0.29, 0.76), if cost then "BUY " .. GameConfig.formatCash(cost) else "MAX", if affordable then Color3.fromRGB(22, 163, 74) else Color3.fromRGB(71, 85, 105))
		buy.Activated:Connect(function()
			Remotes.BuyUpgrade:FireServer(key)
		end)
	end
end

local function fillGoViral()
	panelTitle.Text = "GO VIRAL (REBIRTH)"
	local rebirths = player:GetAttribute("Rebirths") or 0
	local cost = GameConfig.rebirthCost(rebirths)
	makeText(content, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), string.format("ALL MONEY x%d  ->  x%d FOREVER", GameConfig.rebirthMultiplier(rebirths), GameConfig.rebirthMultiplier(rebirths + 1)), Color3.fromRGB(250, 204, 21))
	makeText(content, UDim2.fromScale(0, 0.23), UDim2.fromScale(1, 0.13), "Resets your cash, brainrots and upgrades. Your index stays.", Color3.fromRGB(203, 213, 225))
	makeText(content, UDim2.fromScale(0, 0.4), UDim2.fromScale(1, 0.16), "COST " .. GameConfig.formatCash(cost) .. "   YOU HAVE " .. GameConfig.formatCash(cash()), Color3.new(1, 1, 1))
	local go = makeButton(content, UDim2.fromScale(0.2, 0.62), UDim2.fromScale(0.6, 0.32), "GO VIRAL!", if cash() >= cost then Color3.fromRGB(219, 39, 119) else Color3.fromRGB(71, 85, 105))
	go.Activated:Connect(function()
		Remotes.GoViral:FireServer()
	end)
end

local function foundSet(): ({ [string]: boolean }, number)
	local found, count = {}, 0
	for id in string.gmatch(player:GetAttribute("Index") or "", "[^,]+") do
		found[id] = true
		count += 1
	end
	return found, count
end

-- The index: all 48 brainrots in rarity order; the ones not found yet show as ???.
local function fillIndex()
	local found, count = foundSet()
	local all = BrainrotCatalog.getAll48()
	panelTitle.Text = string.format("INDEX  %d / %d FOUND", count, #all)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 10
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.235, 0, 0, 78)
	grid.CellPadding = UDim2.new(0.015, 0, 0, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroller
	for _, entry in all do
		local cell = Instance.new("Frame")
		cell.LayoutOrder = entry.order
		style(cell, if found[entry.id] then entry.color:Lerp(NAVY, 0.72) else Color3.fromRGB(30, 41, 59), 0.16)
		cell.Parent = scroller
		makeText(cell, UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.52), if found[entry.id] then entry.name else "???", Color3.new(1, 1, 1))
		makeText(cell, UDim2.fromScale(0.04, 0.6), UDim2.fromScale(0.92, 0.34), string.upper(entry.rarityName), entry.color)
	end
end

local FILLERS = { Upgrades = fillUpgrades, GoViral = fillGoViral, Index = fillIndex }

local function refreshPanel()
	content:ClearAllChildren()
	panel.Visible = openPanelName ~= nil
	if openPanelName then
		FILLERS[openPanelName]()
	end
end

local function togglePanel(name: string)
	openPanelName = if openPanelName == name then nil else name
	refreshPanel()
end

upgradesButton.Activated:Connect(function()
	togglePanel("Upgrades")
end)
viralButton.Activated:Connect(function()
	togglePanel("GoViral")
end)
indexButton.Activated:Connect(function()
	togglePanel("Index")
end)
closeButton.Activated:Connect(function()
	openPanelName = nil
	refreshPanel()
end)
privateButton.Activated:Connect(function()
	Remotes.GoPrivate:FireServer()
end)
for _, attribute in { "Cash", "Rebirths", "Index", "CarrySpeedLevel", "LockTimeLevel", "StandsLevel" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if openPanelName and (attribute ~= "Cash" or openPanelName ~= "Index") then
			refreshPanel()
		end
	end)
end

-- the lock button counts down its own timer and cooldown
while true do
	local now = workspace:GetServerTimeNow()
	local lockedFor = (player:GetAttribute("LockedUntil") or 0) - now
	local readyIn = (player:GetAttribute("LockReadyAt") or 0) - now
	if lockedFor > 0 then
		privateButton.Text = string.format("PRIVATE %ds", math.ceil(lockedFor))
		privateButton.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
	elseif readyIn > 0 then
		privateButton.Text = string.format("READY IN %ds", math.ceil(readyIn))
		privateButton.BackgroundColor3 = Color3.fromRGB(71, 85, 105)
	else
		privateButton.Text = "GO PRIVATE"
		privateButton.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	end
	local _, count = foundSet()
	indexButton.Text = string.format("INDEX %d/48", count)
	task.wait(0.2)
end
