-- UpgradeShop: the three upgrades bought with cash. CARRY SPEED (run faster with a
-- brainrot on your head), LOCK TIME (Go Private lasts longer) and MORE STANDS (room for
-- one more brainrot). Prices and caps come from GameConfig.Upgrades.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local BaseStands = require(script.Parent.BaseStands)
local CarryBrainrot = require(script.Parent.CarryBrainrot)
local PlayerState = require(script.Parent.PlayerState)
local Notify = ReplicatedStorage.Remotes.Notify

local UpgradeShop = {}

-- The client asked to buy the next level of `key`. Everything is checked again here.
function UpgradeShop.buyNextLevel(player: Player, key: any)
	local profile = PlayerState.get(player)
	local definition = if type(key) == "string" then GameConfig.Upgrades[key] else nil
	if not profile or not definition then
		return
	end
	local level = profile.upgrades[key] or 0
	local cost = GameConfig.upgradeCost(key, level)
	if not cost then
		Notify:FireClient(player, definition.title .. " is maxed out", "info")
	elseif not PlayerState.trySpend(player, cost) then
		Notify:FireClient(player, definition.title .. " costs " .. GameConfig.formatCash(cost), "bad")
	else
		profile.upgrades[key] = level + 1
		PlayerState.publish(player)
		UpgradeShop.applyUpgrades(player)
		Notify:FireClient(player, definition.title .. " is now level " .. (level + 1), "good")
	end
end

-- Makes the world match the player's levels: open stands and carry speed.
function UpgradeShop.applyUpgrades(player: Player)
	local base = BaseStands.baseOf(player)
	if base then
		BaseStands.refreshStands(base)
	end
	CarryBrainrot.refreshSpeed(player)
end

return UpgradeShop
