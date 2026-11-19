-- HudClient: what the player is told, and nothing they can press. Cash and money per
-- second, the next-step hint, what they carry, the Giant Thumb warning, the Algorithm
-- Boost countdown, toasts from the server and the marker over their own base. It only
-- reads attributes the server publishes; MenuClient owns every button.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.GameConfig)

local player = Players.LocalPlayer
local hud = script.Parent

local TOAST_COLORS = {
	good = Color3.fromRGB(22, 163, 74),
	bad = Color3.fromRGB(220, 38, 38),
	swiped = Color3.fromRGB(220, 38, 38),
	cash = Color3.fromRGB(202, 138, 4),
	viral = Color3.fromRGB(219, 39, 119),
	info = Color3.fromRGB(37, 99, 235),
}

local function makePanel(name: string, anchor: Vector2, position: UDim2, size: UDim2, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = frame
	frame.Parent = hud
	return frame
end

local function makeText(parent: Instance, position: UDim2, size: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = parent
	return label
end

-- cash and income, top centre (clear of Roblox's buttons in the top-left corner)
local cashPanel = makePanel("CashPanel", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.015), UDim2.fromScale(0.34, 0.15), Color3.fromRGB(15, 23, 42))
local cashLabel = makeText(cashPanel, UDim2.fromScale(0.04, 0.02), UDim2.fromScale(0.92, 0.6), Color3.fromRGB(74, 222, 128))
local incomeLabel = makeText(cashPanel, UDim2.fromScale(0.04, 0.6), UDim2.fromScale(0.92, 0.36), Color3.fromRGB(250, 204, 21))

local hintLabel = makeText(hud, UDim2.fromScale(0.2, 0.175), UDim2.fromScale(0.6, 0.055), Color3.new(1, 1, 1))

local carryPanel = makePanel("CarryPanel", Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.9), UDim2.fromScale(0.5, 0.075), Color3.fromRGB(190, 24, 93))
local carryLabel = makeText(carryPanel, UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.94, 0.8), Color3.new(1, 1, 1))

local thumbPanel = makePanel("ThumbWarning", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.74, 0.15), Color3.fromRGB(185, 28, 28))
local thumbLabel = makeText(thumbPanel, UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.84), Color3.new(1, 1, 1))

local boostPanel = makePanel("BoostBanner", Vector2.new(0, 0.5), UDim2.fromScale(0.012, 0.42), UDim2.fromScale(0.2, 0.13), Color3.fromRGB(161, 98, 7))
local boostLabel = makeText(boostPanel, UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.84), Color3.fromRGB(254, 240, 138))

local toastList = Instance.new("Frame")
toastList.Name = "Toasts"
toastList.AnchorPoint = Vector2.new(0.5, 1)
toastList.Position = UDim2.fromScale(0.5, 0.8)
toastList.Size = UDim2.fromScale(0.56, 0.3)
toastList.BackgroundTransparency = 1
toastList.Parent = hud
local toastLayout = Instance.new("UIListLayout")
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.Padding = UDim.new(0.03, 0)
toastLayout.Parent = toastList

local function showToast(text: string, kind: string)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.fromScale(1, 0.22)
	toast.BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info
	toast.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = toast
	local label = makeText(toast, UDim2.fromScale(0.03, 0.12), UDim2.fromScale(0.94, 0.76), Color3.new(1, 1, 1))
	label.Text = text
	toast.Parent = toastList
	task.delay(3.6, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.45)
		toast:Destroy()
	end)
end

-- The Giant Thumb hit this player: throw their own character off the lane.
local function flingOffTheFeed()
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		local away = if rootPart.Position.X >= 0 then 1 else -1
		rootPart.AssemblyLinearVelocity = Vector3.new(away * 85, 75, -25)
	end
end

local function showCash()
	cashLabel.Text = GameConfig.formatCash(player:GetAttribute("Cash") or 0)
	local multiplier = GameConfig.rebirthMultiplier(player:GetAttribute("Rebirths") or 0)
	local income = "+" .. GameConfig.formatCash(player:GetAttribute("Income") or 0) .. "/s"
	incomeLabel.Text = if multiplier > 1 then income .. "   VIRAL x" .. multiplier else income
end

local function showCarrying()
	local carrying = player:GetAttribute("Carrying")
	carryPanel.Visible = carrying ~= nil
	carryLabel.Text = if carrying then "CARRYING " .. string.upper(carrying) .. ": TAKE IT HOME!" else ""
end

-- One line that always says what to do next, so a new player earns within a minute.
local function nextStepHint(): string
	if player:GetAttribute("Carrying") then
		return "Walk to YOUR BASE and PLACE it on a stand"
	elseif (player:GetAttribute("Income") or 0) == 0 then
		return "Go to THE FEED and BUY a brainrot you can afford"
	elseif (player:GetAttribute("Pending") or 0) >= math.max(50, (player:GetAttribute("Cash") or 0) * 0.5) then
		return "Step on your green COLLECT pad to bank your money"
	end
	return ""
end

-- A stand's prompt reads Sell on your own base and Steal on anyone else's.
local function nameStandPrompt(prompt: ProximityPrompt)
	local base = prompt:FindFirstAncestorWhichIsA("Folder") and prompt:FindFirstAncestorWhichIsA("Folder").Parent
	if prompt.Name == "StandPrompt" and base and prompt.ObjectText ~= "Empty stand" then
		local mine = base:GetAttribute("BaseIndex") == player:GetAttribute("BaseIndex")
		prompt.ActionText = if mine then "Sell (half price)" else "Steal"
	end
end

local function markMyBase()
	local index = player:GetAttribute("BaseIndex")
	local base = index and workspace:WaitForChild("Bases"):WaitForChild("Base" .. index)
	if not base or player.PlayerGui:FindFirstChild("MyBaseMarker") then
		return
	end
	local marker = Instance.new("BillboardGui")
	marker.Name = "MyBaseMarker"
	marker.Adornee = base:WaitForChild("Sign")
	marker.Size = UDim2.fromScale(46, 9)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 21, 0)
	marker.LightInfluence = 0
	marker.MaxDistance = 600
	marker.ResetOnSpawn = false
	marker.Parent = player.PlayerGui
	makeText(marker, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(134, 239, 172)).Text = "YOUR BASE"
end

ReplicatedStorage.Remotes.Notify.OnClientEvent:Connect(function(text: string, kind: string)
	showToast(text, kind)
	if kind == "swiped" then
		flingOffTheFeed()
	end
end)
ProximityPromptService.PromptShown:Connect(nameStandPrompt)
for _, attribute in { "Cash", "Income", "Rebirths" } do
	player:GetAttributeChangedSignal(attribute):Connect(showCash)
end
player:GetAttributeChangedSignal("Carrying"):Connect(showCarrying)
player:GetAttributeChangedSignal("BaseIndex"):Connect(markMyBase)
showCash()
showCarrying()
task.spawn(markMyBase)

-- banners that count down against the server's clock
while true do
	local now = workspace:GetServerTimeNow()
	local thumbIn = (workspace:GetAttribute("ThumbWarningUntil") or 0) - now
	local swiping = workspace:GetAttribute("ThumbSwiping") == true
	thumbPanel.Visible = thumbIn > 0 or swiping
	thumbLabel.Text = if swiping then "THE THUMB IS SWIPING! STAY OFF THE FEED!" else string.format("GIANT THUMB IN %d! GET OFF THE FEED!", math.ceil(thumbIn))
	thumbPanel.BackgroundColor3 = if now % 0.5 < 0.25 then Color3.fromRGB(185, 28, 28) else Color3.fromRGB(127, 29, 29)
	local boostLeft = (workspace:GetAttribute("BoostUntil") or 0) - now
	boostPanel.Visible = boostLeft > 0
	boostLabel.Text = string.format("ALGORITHM BOOST x%d  %ds", GameConfig.BOOST.MULTIPLIER, math.ceil(boostLeft))
	hintLabel.Text = nextStepHint()
	task.wait(0.1)
end
