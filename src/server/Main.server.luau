-- Main: the server's only Script. It starts each system once and routes players and the
-- three client requests (buy upgrade, go viral, go private) to the module that owns them.
-- No game rule lives here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local AlgorithmBoostEvent = require(script.Parent.AlgorithmBoostEvent)
local BaseLock = require(script.Parent.BaseLock)
local BaseStands = require(script.Parent.BaseStands)
local CarryBrainrot = require(script.Parent.CarryBrainrot)
local FeedConveyor = require(script.Parent.FeedConveyor)
local GiantThumbHazard = require(script.Parent.GiantThumbHazard)
local GoViralRebirth = require(script.Parent.GoViralRebirth)
local IncomeTicker = require(script.Parent.IncomeTicker)
local PlayerState = require(script.Parent.PlayerState)
local StealBrainrot = require(script.Parent.StealBrainrot)
local ThiefNpc = require(script.Parent.ThiefNpc)
local UpgradeShop = require(script.Parent.UpgradeShop)

local Remotes = ReplicatedStorage.Remotes

local function sendCharacterHome(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	humanoid.WalkSpeed = GameConfig.WALK_SPEED
	local base = BaseStands.baseOf(player)
	if base then
		task.wait(0.1)
		character:PivotTo(BaseStands.spawnCFrame(base))
	end
end

local function onPlayerAdded(player: Player)
	PlayerState.loadProfile(player)
	local base = BaseStands.claimFor(player)
	if not base then
		player:Kick("All eight bases on this phone are taken. Please join another server.")
		return
	end
	player.RespawnLocation = base.model:FindFirstChild("Spawn") :: SpawnLocation
	UpgradeShop.applyUpgrades(player)
	player.CharacterAdded:Connect(function(character)
		sendCharacterHome(player, character)
	end)
	if player.Character then
		sendCharacterHome(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	CarryBrainrot.drop(player, "gone")
	BaseStands.release(player)
	PlayerState.release(player)
end

BaseStands.init()
StealBrainrot.init()
FeedConveyor.start()
IncomeTicker.start()
BaseLock.start()
ThiefNpc.start()
GiantThumbHazard.start()
AlgorithmBoostEvent.start()

Remotes.BuyUpgrade.OnServerEvent:Connect(UpgradeShop.buyNextLevel)
Remotes.GoViral.OnServerEvent:Connect(GoViralRebirth.resetForMultiplier)
Remotes.GoPrivate.OnServerEvent:Connect(BaseLock.goPrivate)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(90)
		for _, player in Players:GetPlayers() do
			PlayerState.saveProfile(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerState.saveProfile(player)
	end
end)
