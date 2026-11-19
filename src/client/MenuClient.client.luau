-- MenuClient: every button the player can press. GO PRIVATE (the base lock), UPGRADES,
-- GO VIRAL (the rebirth), the INDEX of brainrots found and the big world prompts. A press
-- only sends a request: the server decides. The layout is built in StarterGui.Hud.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local GameConfig = require(ReplicatedStorage.GameConfig)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud")
local buttons, panel = hud.Buttons, hud.Panel
local views = { Upgrades = panel.UpgradesView, GoViral = panel.GoViralView, Index = panel.IndexView }

local CAN_AFFORD, CANNOT = Color3.fromRGB(22, 163, 74), Color3.fromRGB(71, 85, 105)
local openView: string? = nil

local function cash(): number
	return player:GetAttribute("Cash") or 0
end

local function showUpgrades()
	panel.Title.Text = "UPGRADES"
	for _, key in GameConfig.UpgradeOrder do
		local definition = GameConfig.Upgrades[key]
		local level = player:GetAttribute(key .. "Level") or 0
		local cost = GameConfig.upgradeCost(key, level)
		local line = views.Upgrades[key]
		line.Title.Text = definition.title .. "  " .. level .. "/" .. definition.maxLevel
		line.Blurb.Text = definition.blurb
		line.Buy.Text = if cost then "BUY " .. GameConfig.formatCash(cost) else "MAX"
		line.Buy.BackgroundColor3 = if cost and cash() >= cost then CAN_AFFORD else CANNOT
	end
end

local function showGoViral()
	panel.Title.Text = "GO VIRAL (REBIRTH)"
	local rebirths = player:GetAttribute("Rebirths") or 0
	local cost = GameConfig.rebirthCost(rebirths)
	local view = views.GoViral
	view.Multiplier.Text = string.format("ALL MONEY x%d  ->  x%d FOREVER", GameConfig.rebirthMultiplier(rebirths), GameConfig.rebirthMultiplier(rebirths + 1))
	view.Cost.Text = "COST " .. GameConfig.formatCash(cost) .. "   YOU HAVE " .. GameConfig.formatCash(cash())
	view.Go.BackgroundColor3 = if cash() >= cost then Color3.fromRGB(219, 39, 119) else CANNOT
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
local function showIndex()
	local found, count = foundSet()
	local all = BrainrotCatalog.getAll48()
	panel.Title.Text = string.format("INDEX  %d / %d FOUND", count, #all)
	for _, entry in all do
		local cell = views.Index:FindFirstChild(entry.id) or hud.IndexCellTemplate:Clone()
		cell.Name = entry.id
		cell.LayoutOrder = entry.order
		cell.BackgroundColor3 = if found[entry.id] then entry.color:Lerp(Color3.fromRGB(15, 23, 42), 0.72) else Color3.fromRGB(30, 41, 59)
		cell.BrainrotName.Text = if found[entry.id] then entry.name else "???"
		cell.Rarity.Text = string.upper(entry.rarityName)
		cell.Rarity.TextColor3 = entry.color
		cell.Visible = true
		cell.Parent = views.Index
	end
end

local SHOW = { Upgrades = showUpgrades, GoViral = showGoViral, Index = showIndex }

-- Every world prompt (Buy, Place, Steal, Sell, Pick up, Block) is one big button over the
-- thing it acts on: tap or click it, or press E. Holding it fills the prompt's hold time.
local function showBigPrompt(prompt: ProximityPrompt)
	local gui = hud.PromptTemplate:Clone()
	local button = gui.Button
	local function label()
		button.Action.Text = if prompt.HoldDuration > 0 then "HOLD: " .. prompt.ActionText else prompt.ActionText
		button.Object.Text = prompt.ObjectText
	end
	label()
	local changed = prompt.Changed:Connect(label)
	button.MouseButton1Down:Connect(function()
		prompt:InputHoldBegin()
	end)
	button.MouseButton1Up:Connect(function()
		prompt:InputHoldEnd()
	end)
	gui.Adornee = prompt.Parent
	gui.Enabled = true
	gui.Parent = hud.Parent
	prompt.PromptHidden:Once(function()
		changed:Disconnect()
		gui:Destroy()
	end)
end

local function refreshPanel()
	panel.Visible = openView ~= nil
	for name, view in views do
		view.Visible = name == openView
	end
	if openView then
		SHOW[openView]()
	end
end

local function togglePanel(name: string?)
	openView = if openView == name then nil else name
	refreshPanel()
end

ProximityPromptService.PromptShown:Connect(showBigPrompt)
for name in views do
	buttons[name].Activated:Connect(function()
		togglePanel(name)
	end)
end
panel.Close.Activated:Connect(function()
	togglePanel(openView)
end)
buttons.GoPrivate.Activated:Connect(function()
	Remotes.GoPrivate:FireServer()
end)
views.GoViral.Go.Activated:Connect(function()
	Remotes.GoViral:FireServer()
end)
for _, key in GameConfig.UpgradeOrder do
	views.Upgrades[key].Buy.Activated:Connect(function()
		Remotes.BuyUpgrade:FireServer(key)
	end)
end
for _, attribute in { "Cash", "Rebirths", "Index", "CarrySpeedLevel", "LockTimeLevel", "StandsLevel" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if openView and (attribute ~= "Cash" or openView ~= "Index") then
			refreshPanel()
		end
	end)
end

-- the lock button counts down its own timer and cooldown
while true do
	local now = workspace:GetServerTimeNow()
	local lockedFor = (player:GetAttribute("LockedUntil") or 0) - now
	local readyIn = (player:GetAttribute("LockReadyAt") or 0) - now
	local lock = buttons.GoPrivate
	if lockedFor > 0 then
		lock.Text = string.format("PRIVATE %ds", math.ceil(lockedFor))
		lock.BackgroundColor3 = CAN_AFFORD
	elseif readyIn > 0 then
		lock.Text = string.format("READY IN %ds", math.ceil(readyIn))
		lock.BackgroundColor3 = CANNOT
	else
		lock.Text = "GO PRIVATE"
		lock.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	end
	local _, count = foundSet()
	buttons.Index.Text = string.format("INDEX %d/48", count)
	task.wait(0.2)
end
