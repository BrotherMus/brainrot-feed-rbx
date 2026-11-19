-- GoViralRebirth: the rebirth. "Go Viral" costs a pile of cash and resets cash, brainrots
-- and upgrades, in exchange for a permanent money multiplier (x2, x3, x4...). The index
-- of brainrots found is kept.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local BaseStands = require(script.Parent.WorldBases)
local CarryBrainrot = require(script.Parent.CarryBrainrot)
local PlayerState = require(script.Parent.PlayerState)
local UpgradeShop = require(script.Parent.UpgradeShop)
local Notify = ReplicatedStorage.Remotes.Notify

local GoViralRebirth = {}

function GoViralRebirth.resetForMultiplier(player: Player)
	local profile = PlayerState.get(player)
	if not profile then
		return
	end
	local cost = GameConfig.rebirthCost(profile.rebirths)
	if profile.cash < cost then
		Notify:FireClient(player, "Going Viral costs " .. GameConfig.formatCash(cost), "bad")
		return
	end
	CarryBrainrot.drop(player, "gone")
	BaseStands.clearAllFor(player)
	profile.rebirths += 1
	profile.cash = GameConfig.STARTING_CASH
	profile.pending = 0
	profile.stands = {}
	profile.upgrades = { CarrySpeed = 0, LockTime = 0, Stands = 0 }
	PlayerState.publish(player)
	UpgradeShop.applyUpgrades(player)
	local multiplier = GameConfig.rebirthMultiplier(profile.rebirths)
	Notify:FireAllClients(player.DisplayName .. " WENT VIRAL! All their money is now x" .. multiplier, "viral")
end

return GoViralRebirth
