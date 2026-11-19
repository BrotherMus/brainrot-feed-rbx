-- CarryBrainrot: one brainrot rides above a player's head, from the Feed (or a rival's
-- stand) to a stand of their own. Carrying slows the player down. Dropping it (the Giant
-- Thumb, dying) leaves it on the glass for anyone to grab, unless it was stolen: then it
-- runs home to its owner.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotBuilder = require(ReplicatedStorage.BrainrotBuilder)
local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local GameConfig = require(ReplicatedStorage.GameConfig)
local PlayerState = require(script.Parent.PlayerState)

local CarryBrainrot = {}

export type Carried = {
	id: string,
	mutation: string?,
	model: Model,
	returnHome: (() -> ())?, -- set for a stolen brainrot: puts it back on its owner's stand
	diedConnection: RBXScriptConnection?,
}

local carried: { [Player]: Carried } = {}

local function applyWalkSpeed(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local profile = PlayerState.get(player)
		local level = if profile then profile.upgrades.CarrySpeed else 0
		humanoid.WalkSpeed = if carried[player] then GameConfig.carrySpeed(level) else GameConfig.WALK_SPEED
	end
end

-- A brainrot lying on the glass: the first player to reach it with empty hands takes it.
local function leaveOnTheGlass(id: string, mutation: string?, position: Vector3)
	local folder = workspace:FindFirstChild("Dropped") or Instance.new("Folder")
	folder.Name = "Dropped"
	folder.Parent = workspace
	local model = BrainrotBuilder.buildFromParts(id, mutation)
	BrainrotBuilder.setTagMoney(model, nil, BrainrotCatalog.incomeOf(id, mutation))
	local x = math.clamp(position.X, -125, 125)
	local z = math.clamp(position.Z, -210, 210)
	model:PivotTo(CFrame.new(x, 0.45, z))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = model.Name
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		if model.Parent and CarryBrainrot.pickUp(player, id, mutation) then
			model:Destroy()
		end
	end)
	model.Parent = folder
	Debris:AddItem(model, GameConfig.DROPPED_LIFETIME)
end

function CarryBrainrot.get(player: Player): Carried?
	return carried[player]
end

function CarryBrainrot.refreshSpeed(player: Player)
	applyWalkSpeed(player)
end

-- Builds the brainrot on the player's head. Nil when their hands are full or they are down.
function CarryBrainrot.pickUp(player: Player, id: string, mutation: string?, returnHome: (() -> ())?): Carried?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if carried[player] or not rootPart or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local model = BrainrotBuilder.buildFromParts(id, mutation)
	BrainrotBuilder.setTagMoney(model, nil, BrainrotCatalog.incomeOf(id, mutation))
	model:PivotTo(rootPart.CFrame * CFrame.new(0, 2.8, 0))
	local modelRoot = model.PrimaryPart :: BasePart
	modelRoot.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = modelRoot
	weld.Parent = modelRoot
	model.Parent = character
	local info: Carried = { id = id, mutation = mutation, model = model, returnHome = returnHome }
	info.diedConnection = humanoid.Died:Once(function()
		CarryBrainrot.drop(player, "died")
	end)
	carried[player] = info
	player:SetAttribute("Carrying", model.Name)
	PlayerState.markDiscovered(player, id)
	applyWalkSpeed(player)
	return info
end

-- Empties the player's hands and returns what they held (to place it on a stand).
function CarryBrainrot.takeCarried(player: Player): Carried?
	local info = carried[player]
	if not info then
		return nil
	end
	carried[player] = nil
	if info.diedConnection then
		info.diedConnection:Disconnect()
	end
	info.model:Destroy()
	player:SetAttribute("Carrying", nil)
	applyWalkSpeed(player)
	return info
end

-- Knocks the brainrot out of the player's hands. reason "gone" removes it for good.
function CarryBrainrot.drop(player: Player, reason: string)
	local held = carried[player]
	local position = if held then held.model:GetPivot().Position else Vector3.zero
	local info = CarryBrainrot.takeCarried(player)
	if not info then
		return
	end
	if info.returnHome then
		info.returnHome()
	elseif reason ~= "gone" then
		leaveOnTheGlass(info.id, info.mutation, position)
	end
end

return CarryBrainrot
