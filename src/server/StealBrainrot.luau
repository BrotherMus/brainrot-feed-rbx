-- StealBrainrot: players steal from each other. Hold the prompt on a brainrot in a base
-- that is not private and it jumps onto your head; get it onto one of your own stands and
-- it is yours. Until then its owner can take it back by reaching you, and the Giant Thumb
-- sends it home too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local BaseLock = require(script.Parent.BaseLock)
local BaseStands = require(script.Parent.WorldBases)
local CarryBrainrot = require(script.Parent.CarryBrainrot)
local Notify = ReplicatedStorage.Remotes.Notify

local StealBrainrot = {}

-- `thief` finished holding the Steal prompt on stand `standIndex` of someone else's base.
function StealBrainrot.stealFromUnlockedBase(thief: Player, base: BaseStands.Base, standIndex: number)
	local owner = base.owner
	local thiefBase = BaseStands.baseOf(thief)
	if not owner or not base.stands[standIndex].id then
		return
	elseif BaseLock.isLocked(base) then
		Notify:FireClient(thief, "This base is PRIVATE: you cannot steal here", "bad")
		return
	elseif CarryBrainrot.get(thief) then
		Notify:FireClient(thief, "Hands full: you can only carry one", "info")
		return
	elseif not thiefBase or not BaseStands.firstFreeStand(thiefBase) then
		Notify:FireClient(thief, "No free stand in your base to put it on", "info")
		return
	end
	local id, mutation = BaseStands.clearStand(base, standIndex)
	local name = (BrainrotCatalog.get(id :: string) :: BrainrotCatalog.Entry).name

	-- dropped or caught before it reaches the thief's stand: back to where it stood
	local function returnHome()
		if base.owner == owner then
			local home = if base.stands[standIndex].id then BaseStands.firstFreeStand(base) else standIndex
			if home then
				BaseStands.setStandBrainrot(base, home, id :: string, mutation)
			end
			Notify:FireClient(owner, name .. " is back on your stand", "good")
		end
	end

	local info = CarryBrainrot.pickUp(thief, id :: string, mutation, returnHome)
	if not info then
		returnHome()
		return
	end
	local takeBack = Instance.new("ProximityPrompt")
	takeBack.Name = "TakeBackPrompt"
	takeBack.Style = Enum.ProximityPromptStyle.Custom
	takeBack.ActionText = "Take back"
	takeBack.ObjectText = "STOLEN " .. name
	takeBack.MaxActivationDistance = 13
	takeBack.RequiresLineOfSight = false
	takeBack.Parent = info.model.PrimaryPart
	takeBack.Triggered:Connect(function(player)
		if player == owner and CarryBrainrot.get(thief) == info then
			CarryBrainrot.drop(thief, "caught")
			Notify:FireClient(thief, owner.DisplayName .. " took " .. name .. " back", "bad")
		end
	end)
	Notify:FireClient(owner, thief.DisplayName .. " is STEALING your " .. name .. "! Catch them!", "bad")
	Notify:FireClient(thief, "You stole " .. name .. "! Run it to a stand in your base", "good")
end

function StealBrainrot.init()
	BaseStands.onIntruderPrompt = StealBrainrot.stealFromUnlockedBase
end

return StealBrainrot
