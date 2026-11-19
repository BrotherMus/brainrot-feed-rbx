-- Upgrades bought with money: Carry Speed, Lock Time and More Stands.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Carry = require(script.Parent.BrainrotCarry)
local Stands = require(script.Parent.BaseStandsIncome)

local UpgradeShop = {}

function UpgradeShop.buyUpgrade(player: Player, key: string)
	local state = PlayerState.get(player)
	local upgrade = Rules.UPGRADES[key]
	if not state or not upgrade then
		return
	end
	local level = state.upgrades[key]
	if level >= upgrade.maxLevel then
		PlayerState.notify(player, upgrade.title .. " is maxed out.", "info")
	elseif not PlayerState.trySpend(player, Rules.upgradeCost(key, level)) then
		PlayerState.notify(player, "Not enough money for " .. upgrade.title .. ".", "warn")
	else
		state.upgrades[key] = level + 1
		PlayerState.publish(player)
		Stands.refreshStands(player)
		Carry.applyCarrySpeedUpgrade(player)
		PlayerState.notify(player, "⬆ " .. upgrade.title .. " is now level " .. level + 1 .. "!", "good")
	end
end

return UpgradeShop
