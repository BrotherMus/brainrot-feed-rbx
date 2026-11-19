-- HudClient: what the player is told, and nothing they can press. Cash, money per second,
-- the next-step hint, the Giant Thumb warning, the boost countdown and toasts. It only
-- reads what the server publishes and fills in StarterGui.Hud; MenuClient owns the buttons.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.GameConfig)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud")
local cashPanel, hintPanel, carryPanel = hud.CashPanel, hud.HintPanel, hud.CarryPanel
local thumbPanel, boostPanel = hud.ThumbWarning, hud.BoostBanner

local TOAST_COLORS = {
	good = Color3.fromRGB(22, 163, 74),
	bad = Color3.fromRGB(220, 38, 38),
	swiped = Color3.fromRGB(220, 38, 38),
	cash = Color3.fromRGB(202, 138, 4),
	viral = Color3.fromRGB(219, 39, 119),
	info = Color3.fromRGB(37, 99, 235),
}

local function showToast(text: string, kind: string)
	local toast = hud.ToastTemplate:Clone()
	toast.BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info
	toast.Text.Text = text
	toast.Visible = true
	toast.Parent = hud.Toasts
	task.delay(3.6, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toast.Text, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.45)
		toast:Destroy()
	end)
end

-- The Giant Thumb hit this player: throw their own character off the lane.
local function flingOffTheFeed()
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local away = if rootPart.Position.X >= 0 then 1 else -1
		rootPart.AssemblyLinearVelocity = Vector3.new(away * 85, 75, -25)
	end
end

local function showCash()
	cashPanel.Cash.Text = GameConfig.formatCash(player:GetAttribute("Cash") or 0)
	local multiplier = GameConfig.rebirthMultiplier(player:GetAttribute("Rebirths") or 0)
	local income = "+" .. GameConfig.formatCash(player:GetAttribute("Income") or 0) .. "/s"
	cashPanel.Income.Text = if multiplier > 1 then income .. "   VIRAL x" .. multiplier else income
end

local function showCarrying()
	local carrying = player:GetAttribute("Carrying")
	carryPanel.Visible = carrying ~= nil
	carryPanel.Text.Text = if carrying then "CARRYING " .. string.upper(carrying) .. ": TAKE IT HOME!" else ""
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
	local stands = prompt:FindFirstAncestorWhichIsA("Folder")
	if prompt.Name == "StandPrompt" and stands and prompt.ObjectText ~= "Empty stand" then
		local mine = stands.Parent:GetAttribute("BaseIndex") == player:GetAttribute("BaseIndex")
		prompt.ActionText = if mine then "Sell (half price)" else "Steal"
	end
end

local function markMyBase()
	local index = player:GetAttribute("BaseIndex")
	local base = index and workspace:WaitForChild("Bases"):WaitForChild("Base" .. index)
	if base then
		local marker = hud.Parent:FindFirstChild("MyBaseMarker") or hud.MyBaseMarker:Clone()
		marker.Adornee = base:WaitForChild("Sign")
		marker.Enabled = true
		marker.Parent = hud.Parent
	end
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
	thumbPanel.Text.Text = if swiping then "THE THUMB IS SWIPING! STAY OFF THE FEED!" else string.format("GIANT THUMB IN %d! GET OFF THE FEED!", math.ceil(thumbIn))
	thumbPanel.BackgroundColor3 = if now % 0.5 < 0.25 then Color3.fromRGB(185, 28, 28) else Color3.fromRGB(127, 29, 29)
	local boostLeft = (workspace:GetAttribute("BoostUntil") or 0) - now
	boostPanel.Visible = boostLeft > 0
	boostPanel.Text.Text = string.format("ALGORITHM BOOST x%d  %ds", GameConfig.BOOST.MULTIPLIER, math.ceil(boostLeft))
	local hint = nextStepHint()
	hintPanel.Visible = hint ~= ""
	hintPanel.Text.Text = hint
	task.wait(0.1)
end
