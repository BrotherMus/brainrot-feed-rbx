-- Draws every ProximityPrompt as a big tappable button that fits a phone screen.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rules = require(ReplicatedStorage.EconomyRules)

local player = Players.LocalPlayer
local template = ReplicatedStorage.Assets.PromptButton

local BUTTON_COLORS = {
	BuyPrompt = Color3.fromRGB(50, 200, 100),
	GrabPrompt = Color3.fromRGB(255, 150, 40),
	StandPrompt = Color3.fromRGB(235, 55, 65),
	LockPrompt = Color3.fromRGB(235, 55, 65),
}

local BigPrompts = {}

local function ownsBaseOf(prompt: ProximityPrompt): boolean
	local node: Instance? = prompt
	while node and node.Parent ~= workspace.Bases do
		node = node.Parent
	end
	return node ~= nil and node:GetAttribute("OwnerId") == player.UserId
end

-- A stand reads "Sell" to its owner and "Steal" to everyone else; only the owner sees the lock button.
function BigPrompts.buttonTextFor(prompt: ProximityPrompt): string?
	if prompt.Name == "StandPrompt" then
		if ownsBaseOf(prompt) then
			return "Sell +" .. Rules.formatMoney(prompt:GetAttribute("SellValue") or 0)
		end
		return "STEAL!"
	elseif prompt.Name == "LockPrompt" and not ownsBaseOf(prompt) then
		return nil
	end
	return prompt.ActionText
end

function BigPrompts.showButton(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local text = BigPrompts.buttonTextFor(prompt)
	if not text then
		return
	end
	local gui = template:Clone()
	local button = gui.Button
	button.ActionText.Text = text
	button.ObjectText.Text = prompt.ObjectText
	button.KeyText.Text = inputType == Enum.ProximityPromptInputType.Touch and "👆" or "E"
	button.BackgroundColor3 = BUTTON_COLORS[prompt.Name] or BUTTON_COLORS.BuyPrompt
	gui.Adornee = prompt.Parent
	gui.Parent = player.PlayerGui

	local holdTween: Tween? = nil
	local connections = {
		button.MouseButton1Down:Connect(function()
			prompt:InputHoldBegin()
		end),
		button.MouseButton1Up:Connect(function()
			prompt:InputHoldEnd()
		end),
		prompt.PromptButtonHoldBegan:Connect(function()
			holdTween = TweenService:Create(button.HoldFill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			holdTween:Play()
		end),
		prompt.PromptButtonHoldEnded:Connect(function()
			if holdTween then
				holdTween:Cancel()
			end
			button.HoldFill.Size = UDim2.fromScale(0, 1)
		end),
	}
	prompt.PromptHidden:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		gui:Destroy()
	end)
end

function BigPrompts.start()
	ProximityPromptService.PromptShown:Connect(BigPrompts.showButton)
end

return BigPrompts
