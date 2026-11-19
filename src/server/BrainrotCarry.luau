-- Carrying: a bought or stolen brainrot rides above its carrier until it is placed at home, dropped or lost.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.BrainrotCatalog)
local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Spawner = require(script.Parent.BrainrotSpawner)

local PICKUP_SECONDS = 20

local Carry = {}
Carry.onPickupExpired = nil -- StealingAndBaseLock sets this to send unclaimed stolen goods home

-- A carrier walks at the Carry Speed upgrade's pace, everyone else at full speed.
function Carry.applyCarrySpeedUpgrade(player: Player)
	local state = PlayerState.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if state and humanoid then
		humanoid.WalkSpeed = state.carrying and Rules.carrySpeed(state.upgrades.CarrySpeed) or Rules.WALK_SPEED
	end
end

function Carry.give(player: Player, id: string, mutation: string?, stolenFrom: Player?): boolean
	local state = PlayerState.get(player)
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not state or state.carrying or not rootPart then
		return false
	end
	local model = Spawner.spawn(id, mutation, false)
	local root = model.PrimaryPart
	root.Anchored = false
	root.CanCollide = false
	root.Massless = true
	model:PivotTo(rootPart.CFrame * CFrame.new(0, 2.7, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = root
	weld.Parent = root
	model.Parent = player.Character
	state.carrying = { id = id, mutation = mutation, model = model, stolenFrom = stolenFrom }
	Carry.applyCarrySpeedUpgrade(player)
	PlayerState.publish(player)
	return true
end

-- Removes and returns what the player carries.
function Carry.take(player: Player)
	local state = PlayerState.get(player)
	local cargo = state and state.carrying
	if not cargo then
		return nil
	end
	state.carrying = nil
	cargo.model:Destroy()
	Carry.applyCarrySpeedUpgrade(player)
	PlayerState.publish(player)
	return cargo
end

-- The carrier loses the brainrot: it lies on the screen for anyone to grab, then expires.
function Carry.drop(player: Player, where: Vector3?)
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local cargo = Carry.take(player)
	if not cargo then
		return
	end
	local spot = where or (rootPart and rootPart.Position) or Vector3.zero
	local pickup = Spawner.spawn(cargo.id, cargo.mutation, false)
	pickup.PrimaryPart.Anchored = true
	pickup.PrimaryPart.CanCollide = false
	pickup:PivotTo(CFrame.new(math.clamp(spot.X, -88, 88), 0.3, math.clamp(spot.Z, -176, 176)))
	local prompt = Spawner.addPrompt(pickup.PrimaryPart, "GrabPrompt", "Grab", Catalog.byId[cargo.id].name, 0)
	pickup.Parent = workspace.Dropped
	prompt.Triggered:Connect(function(grabber)
		local victim = cargo.stolenFrom ~= grabber and cargo.stolenFrom or nil
		if pickup.Parent and Carry.give(grabber, cargo.id, cargo.mutation, victim) then
			pickup:Destroy()
		end
	end)
	task.delay(PICKUP_SECONDS, function()
		if pickup.Parent then
			pickup:Destroy()
			if Carry.onPickupExpired then
				Carry.onPickupExpired(cargo)
			end
		end
	end)
end

return Carry
