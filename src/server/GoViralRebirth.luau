-- Go Viral: the rebirth. Money, brainrots and upgrades reset; the money multiplier grows for good.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Carry = require(script.Parent.BrainrotCarry)
local Stands = require(script.Parent.BaseStandsIncome)

local Rebirth = {}

function Rebirth.goViral(player: Player)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local cost = Rules.rebirthCost(state.rebirths)
	if state.money < cost then
		PlayerState.notify(player, "Going viral needs " .. Rules.formatMoney(cost) .. ".", "warn")
		return
	end
	Carry.take(player)
	Stands.clear(player)
	state.rebirths += 1
	state.money = Rules.START_MONEY
	for key in state.upgrades do
		state.upgrades[key] = 0
	end
	Stands.refreshStands(player)
	PlayerState.publish(player)
	local multiplier = Rules.rebirthMultiplier(state.rebirths)
	PlayerState.notifyAll("🚀 " .. player.DisplayName .. " WENT VIRAL! Money x" .. multiplier .. " forever.", "good")
end

return Rebirth
