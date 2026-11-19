-- Doomscroll Dash, client entry: binds the HUD to the player's replicated state and sends button presses.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage:WaitForChild("BrainrotCatalog"))
local Rules = require(ReplicatedStorage:WaitForChild("EconomyRules"))
local BigPrompts = require(script.Parent:WaitForChild("BigPrompts"))
local IndexPanel = require(script.Parent:WaitForChild("IndexPanel"))

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud", 60)
local feed = workspace:WaitForChild("Feed")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local panels = { hud.UpgradesPanel, hud.RebirthPanel, hud.IndexPanel }

local GREEN = Color3.fromRGB(50, 200, 100)
local GREY = Color3.fromRGB(110, 110, 125)
local RED = Color3.fromRGB(235, 55, 65)
local TOAST_COLORS = { good = GREEN, warn = Color3.fromRGB(255, 150, 40), alert = RED, info = Color3.fromRGB(50, 140, 255) }
local UPGRADE_EFFECTS = {
	CarrySpeed = function(level)
		return Rules.carrySpeed(level) .. " speed"
	end,
	LockTime = function(level)
		return Rules.lockSeconds(level) .. "s lock"
	end,
	Stands = function(level)
		return Rules.standCount(level) .. " stands"
	end,
}

local lastMoney: number? = nil
local indexBuilt = false
local toastCount = 0

local function attribute(name: string): number
	return player:GetAttribute(name) or 0
end

local function togglePanel(panel: Frame)
	for _, other in panels do
		other.Visible = other == panel and not panel.Visible
	end
end

-- "+$120" floats up from the money counter whenever money comes in.
local function popCash(amount: number)
	local pop = hud.CashPopup:Clone()
	pop.Text = "+" .. Rules.formatMoney(amount)
	pop.Visible = true
	pop.Parent = hud
	hud.CashSound:Play()
	local tween = TweenService:Create(pop, TweenInfo.new(0.9), { Position = pop.Position - UDim2.fromScale(0, 0.07), TextTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		pop:Destroy()
	end)
end

local function showToast(text: string, kind: string)
	toastCount += 1
	local oldest = hud.Toasts:FindFirstChild(tostring(toastCount - 3))
	if oldest then
		oldest:Destroy()
	end
	local toast = hud.ToastTemplate:Clone()
	toast.Name = tostring(toastCount)
	toast.Text = text
	toast.BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info
	toast.LayoutOrder = toastCount
	toast.Visible = true
	toast.Parent = hud.Toasts
	if kind == "alert" then
		hud.AlertSound:Play()
	end
	task.delay(4.5, function()
		toast:Destroy()
	end)
end

-- Upgrade rows and the Go Viral panel: level, effect, price, and green only when affordable.
local function refreshShop(money: number)
	for key, upgrade in Rules.UPGRADES do
		local row = hud.UpgradesPanel.Rows[key]
		local level = attribute(key)
		local maxed = level >= upgrade.maxLevel
		local cost = Rules.upgradeCost(key, level)
		row.LevelText.Text = `Level {level}/{upgrade.maxLevel}: {UPGRADE_EFFECTS[key](level)}`
		row.BuyButton.Text = maxed and "MAX" or Rules.formatMoney(cost)
		row.BuyButton.BackgroundColor3 = (maxed or money < cost) and GREY or GREEN
	end
	local rebirths = attribute("Rebirths")
	local multiplier = Rules.rebirthMultiplier(rebirths)
	local rebirthCost = Rules.rebirthCost(rebirths)
	hud.MultiplierBadge.Text = `x{multiplier} MONEY`
	hud.RebirthPanel.MultiplierText.Text = `x{multiplier}  ➜  x{multiplier + 1} MONEY`
	hud.RebirthPanel.ConfirmButton.Text = "GO VIRAL  " .. Rules.formatMoney(rebirthCost)
	hud.RebirthPanel.ConfirmButton.BackgroundColor3 = money < rebirthCost and GREY or Color3.fromRGB(255, 60, 140)
end

local function refreshHud()
	local money = attribute("Money")
	if lastMoney and money > lastMoney then
		popCash(money - lastMoney)
	end
	lastMoney = money
	hud.MoneyPanel.MoneyText.Text = Rules.formatMoney(money)
	hud.MoneyPanel.IncomeText.Text = "+" .. Rules.formatMoney(attribute("Income")) .. "/s"
	refreshShop(money)

	local found = player:GetAttribute("Index") or ""
	local _, foundCount = string.gsub(found, "[^,]+", "")
	hud.Buttons.IndexButton.Text = `📖 INDEX {foundCount}/{#Catalog.list}`
	if indexBuilt then
		IndexPanel.showFound(hud.IndexPanel, found)
	end

	local carrying = player:GetAttribute("Carrying") or ""
	hud.HintText.Visible = carrying ~= "" or attribute("Income") == 0
	if carrying ~= "" then
		hud.HintText.Text = "🏃 Carry " .. Catalog.byId[carrying].name .. " to your base!"
	else
		hud.HintText.Text = "Buy a brainrot from the Feed and carry it to your base!"
	end
end

-- Countdowns: the base lock, the Giant Thumb warning and the Algorithm Boost.
local function refreshTimers()
	local now = workspace:GetServerTimeNow()
	local lockButton = hud.Buttons.LockButton
	local lockedFor = attribute("LockedUntil") - now
	local readyIn = attribute("LockReadyAt") - now
	if lockedFor > 0 then
		lockButton.Text = `🔒 PRIVATE {math.ceil(lockedFor)}s`
		lockButton.BackgroundColor3 = GREEN
	elseif readyIn > 0 then
		lockButton.Text = `⏳ LOCK IN {math.ceil(readyIn)}s`
		lockButton.BackgroundColor3 = GREY
	else
		lockButton.Text = "🔒 GO PRIVATE"
		lockButton.BackgroundColor3 = RED
	end

	local thumbAt = workspace:GetAttribute("ThumbAt") or 0
	local thumbIn = thumbAt - now
	hud.ThumbBanner.Visible = thumbAt > 0
	feed.RailLeft.Color = thumbAt > 0 and RED or Color3.fromRGB(255, 60, 140)
	feed.RailRight.Color = thumbAt > 0 and RED or Color3.fromRGB(60, 220, 255)
	hud.DangerFlash.BackgroundTransparency = thumbAt > 0 and 0.9 + 0.06 * math.sin(now * 12) or 1
	if thumbIn > 0 then
		hud.ThumbBanner.Text = `⚠ GIANT THUMB IN {math.ceil(thumbIn)}s - GET OFF THE FEED!`
	else
		hud.ThumbBanner.Text = "👍 SWIPE!!! STAY OFF THE FEED!"
	end

	local boostLeft = (workspace:GetAttribute("BoostUntil") or 0) - now
	hud.BoostBanner.Visible = boostLeft > 0
	hud.BoostBanner.Position = UDim2.fromScale(0.25, thumbAt > 0 and 0.305 or 0.19)
	hud.BoostBanner.Text = `📈 ALGORITHM BOOST: x2 MONEY - {math.ceil(boostLeft)}s`
	Lighting.Grade.TintColor = boostLeft > 0 and Color3.fromRGB(255, 240, 190) or Color3.new(1, 1, 1)
end

local function connectButtons()
	hud.Buttons.UpgradesButton.Activated:Connect(function()
		togglePanel(hud.UpgradesPanel)
	end)
	hud.Buttons.RebirthButton.Activated:Connect(function()
		togglePanel(hud.RebirthPanel)
	end)
	hud.Buttons.IndexButton.Activated:Connect(function()
		if not indexBuilt then
			indexBuilt = true
			IndexPanel.buildGrid(hud.IndexPanel)
			IndexPanel.showFound(hud.IndexPanel, player:GetAttribute("Index") or "")
		end
		togglePanel(hud.IndexPanel)
	end)
	hud.Buttons.LockButton.Activated:Connect(function()
		remotes.PlayerAction:FireServer("Lock")
	end)
	hud.RebirthPanel.ConfirmButton.Activated:Connect(function()
		remotes.PlayerAction:FireServer("Rebirth")
		hud.RebirthPanel.Visible = false
	end)
	for _, row in hud.UpgradesPanel.Rows:GetChildren() do
		if row:IsA("Frame") then
			row.BuyButton.Activated:Connect(function()
				remotes.PlayerAction:FireServer("Upgrade", row.Name)
			end)
		end
	end
	for _, panel in panels do
		panel.Close.Activated:Connect(function()
			panel.Visible = false
		end)
	end
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)
BigPrompts.start()
connectButtons()
remotes.Notify.OnClientEvent:Connect(showToast)
player.AttributeChanged:Connect(refreshHud)
refreshHud()
while true do
	refreshTimers()
	task.wait(0.1)
end
