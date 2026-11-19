-- Doomscroll Dash, server entry: wires players, the action remote and the game systems together.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Carry = require(script.Parent.BrainrotCarry)
local Stands = require(script.Parent.BaseStandsIncome)
local Feed = require(script.Parent.FeedConveyor)
local Stealing = require(script.Parent.StealingAndBaseLock)
local Thief = require(script.Parent.ThiefNpc)
local Thumb = require(script.Parent.GiantThumbHazard)
local UpgradeShop = require(script.Parent.UpgradeShop)
local Rebirth = require(script.Parent.GoViralRebirth)
local Boost = require(script.Parent.AlgorithmBoostEvent)

local function spawnAtBase(player: Player, character: Model)
	local state = PlayerState.get(player)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = Rules.WALK_SPEED
	humanoid.Died:Connect(function()
		Carry.drop(player)
	end)
	task.wait()
	if state and state.base then
		local spot = state.base.SpawnPad.Position + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.lookAt(spot, spot - Vector3.zAxis))
	end
end

local function onPlayerAdded(player: Player)
	PlayerState.create(player)
	Stands.assignBase(player)
	player.CharacterAdded:Connect(function(character)
		spawnAtBase(player, character)
	end)
	if player.Character then
		spawnAtBase(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local cargo = Carry.take(player)
	if cargo and cargo.stolenFrom then
		Stealing.returnToOwner(cargo)
	end
	PlayerState.save(player)
	Stands.releaseBase(player)
	PlayerState.remove(player)
end

-- Everything the HUD's buttons ask for arrives here and is checked again on the server.
local actions = {
	Upgrade = UpgradeShop.buyUpgrade,
	Rebirth = Rebirth.goViral,
	Lock = Stealing.goPrivate,
}
ReplicatedStorage.Remotes.PlayerAction.OnServerEvent:Connect(function(player, action, argument)
	local handler = actions[action]
	if handler and (argument == nil or type(argument) == "string") then
		handler(player, argument)
	end
end)

-- Server-only hooks for reviewers and screenshots (TOUR.json): start an event or stock a base on demand.
local tour = {
	Thumb = Thumb.swipe,
	Boost = Boost.startDoubleMoneyEvent,
	Thief = Thief.runHeist,
	Feed = function(id, mutation)
		Feed.spawnOnBelt(nil, id, mutation)
	end,
	Money = function(amount)
		for player in PlayerState.all() do
			PlayerState.addMoney(player, amount)
		end
	end,
	Place = function(id, mutation)
		for player in PlayerState.all() do
			Stands.place(player, id, mutation)
		end
	end,
}
ServerStorage.TourEvent.Event:Connect(function(name, ...)
	if tour[name] then
		tour[name](...)
	end
end)

Feed.start()
Stands.start()
Stealing.start()
Thief.start()
Thumb.start()
Boost.start()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerState.save(player)
	end
end)
