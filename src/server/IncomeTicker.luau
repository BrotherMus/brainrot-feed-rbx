-- IncomeTicker: money per second. Once a second every base earns what its brainrots pay,
-- times the owner's rebirth multiplier and any Algorithm Boost. The money piles up on the
-- base's collect pad until the owner steps on it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local BaseStands = require(script.Parent.BaseStands)
local PlayerState = require(script.Parent.PlayerState)
local Notify = ReplicatedStorage.Remotes.Notify

local IncomeTicker = {}

local boostMultiplier = 1

-- What the base earns each second right now, with every multiplier applied.
function IncomeTicker.moneyPerSecond(base: BaseStands.Base): number
	local profile = base.owner and PlayerState.get(base.owner)
	if not profile then
		return 0
	end
	return BaseStands.incomePerSecond(base) * GameConfig.rebirthMultiplier(profile.rebirths) * boostMultiplier
end

local function showPending(base: BaseStands.Base, pending: number)
	local pad = base.model:FindFirstChild("CollectPad") :: BasePart
	local amount = (pad:FindFirstChild("CollectGui") :: BillboardGui):FindFirstChild("Amount") :: TextLabel
	amount.Text = GameConfig.formatCash(pending)
end

local function payEveryBaseOnce()
	for _, base in BaseStands.all() do
		local owner = base.owner
		local profile = owner and PlayerState.get(owner)
		if owner and profile then
			local rate = IncomeTicker.moneyPerSecond(base)
			profile.pending += rate
			owner:SetAttribute("Income", rate)
			owner:SetAttribute("Pending", profile.pending)
			showPending(base, profile.pending)
			BaseStands.setSignLine(base, "IncomeLabel", "+" .. GameConfig.formatCash(rate) .. "/s")
		end
	end
end

-- The owner stepped on their collect pad: everything waiting there becomes cash.
function IncomeTicker.collect(player: Player)
	local base = BaseStands.baseOf(player)
	local profile = PlayerState.get(player)
	if base and profile and profile.pending >= 1 then
		local amount = math.floor(profile.pending)
		profile.pending = 0
		PlayerState.addCash(player, amount)
		showPending(base, 0)
		Notify:FireClient(player, "Collected " .. GameConfig.formatCash(amount), "cash")
	end
end

-- AlgorithmBoostEvent calls this: 2 while the boost runs, 1 when it ends.
function IncomeTicker.setBoostMultiplier(multiplier: number)
	boostMultiplier = multiplier
end

function IncomeTicker.start()
	for _, base in BaseStands.all() do
		local pad = base.model:FindFirstChild("CollectPad") :: BasePart
		pad.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)
			if player and player == base.owner then
				IncomeTicker.collect(player)
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			payEveryBaseOnce()
		end
	end)
end

return IncomeTicker
