-- The Repost Bandit: an NPC thief that robs unlocked bases, so stealing matters even when playing alone.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(ReplicatedStorage.BrainrotCatalog)
local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Spawner = require(script.Parent.BrainrotSpawner)
local Stands = require(script.Parent.BaseStandsIncome)
local Stealing = require(script.Parent.StealingAndBaseLock)

local PORTAL = workspace.RepostPortal.Exit.Position - Vector3.new(0, 0, 6)
local TAG_DISTANCE = 7
local ESCAPE_SPEED = 17

local rng = Random.new()
local heistRunning = false

local Thief = {}

-- Any player who reaches the bandit scares him off.
local function isTagged(npc: Model): boolean
	for _, player in Players:GetPlayers() do
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and (rootPart.Position - npc.PrimaryPart.Position).Magnitude < TAG_DISTANCE then
			return true
		end
	end
	return false
end

-- Walks the bandit to goal; false when a player tagged him on the way.
local function walkTo(npc: Model, goal: Vector3): boolean
	local deadline = os.clock() + 30
	while os.clock() < deadline do
		if isTagged(npc) then
			return false
		end
		local offset = (npc.PrimaryPart.Position - goal) * Vector3.new(1, 0, 1)
		if offset.Magnitude < 4 then
			return true
		end
		npc.Humanoid:MoveTo(goal)
		task.wait(0.2)
	end
	npc:PivotTo(CFrame.new(goal + Vector3.new(0, 3, 0)))
	return true
end

-- A random occupied stand of a base that is not private. Beginners with under 3 brainrots are left alone.
function Thief.pickTarget()
	local options = {}
	for player, state in PlayerState.all() do
		local mine = {}
		for slot in state.stands do
			table.insert(mine, { owner = player, slot = slot })
		end
		if state.base and #mine >= 3 and not Stealing.isLocked(player) then
			table.move(mine, 1, #mine, #options + 1, options)
		end
	end
	return options[rng:NextInteger(1, math.max(#options, 1))]
end

-- One robbery: walk in, grab a brainrot, run for the Repost Portal. Tag him to get it back.
function Thief.runHeist()
	local target = not heistRunning and Thief.pickTarget()
	if not target then
		return
	end
	heistRunning = true
	local owner = target.owner
	local plate = PlayerState.get(owner).base.Stands["Stand" .. target.slot].CashPlate.Position
	local lane = Vector3.new(math.sign(plate.X) * 24, 0, plate.Z)
	local npc = ServerStorage.RepostBandit:Clone()
	npc:PivotTo(CFrame.new(PORTAL + Vector3.new(0, 3, 0)))
	npc.Parent = workspace
	npc.PrimaryPart:SetNetworkOwner(nil)
	PlayerState.notify(owner, "🚨 The Repost Bandit is coming for your base! Go Private or tag him!", "alert")

	local arrived = walkTo(npc, lane) and walkTo(npc, plate)
	task.wait(arrived and 1.5 or 0)
	local canSteal = arrived and not isTagged(npc) and PlayerState.get(owner) and not Stealing.isLocked(owner)
	local stand = canSteal and Stands.remove(owner, target.slot)
	if stand then
		local name = Catalog.byId[stand.id].name
		local loot = Spawner.spawn(stand.id, stand.mutation, false)
		loot.PrimaryPart.Anchored = false
		loot.PrimaryPart.CanCollide = false
		loot.PrimaryPart.Massless = true
		loot:PivotTo(npc.PrimaryPart.CFrame * CFrame.new(0, 4.6, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = npc.PrimaryPart
		weld.Part1 = loot.PrimaryPart
		weld.Parent = loot.PrimaryPart
		loot.Parent = npc
		npc.Humanoid.WalkSpeed = ESCAPE_SPEED
		PlayerState.notify(owner, "🚨 The Repost Bandit grabbed your " .. name .. "! Tag him before the portal!", "alert")
		if walkTo(npc, lane) and walkTo(npc, PORTAL) then
			PlayerState.notify(owner, "💀 Your " .. name .. " got reposted. It is gone.", "alert")
		else
			Stealing.returnToOwner({ id = stand.id, mutation = stand.mutation, stolenFrom = owner })
		end
	elseif PlayerState.get(owner) then
		PlayerState.notify(owner, "The Repost Bandit gave up. Your base is safe.", "good")
	end
	npc:Destroy()
	heistRunning = false
end

function Thief.start()
	-- the bandit walks through stands and walls instead of getting stuck on them
	PhysicsService:RegisterCollisionGroup("Thief")
	PhysicsService:RegisterCollisionGroup("BaseProps")
	PhysicsService:CollisionGroupSetCollidable("Thief", "BaseProps", false)
	for _, part in workspace.Bases:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Floor" then
			part.CollisionGroup = "BaseProps"
		end
	end
	task.spawn(function()
		while task.wait(Rules.THIEF_INTERVAL) do
			Thief.runHeist()
		end
	end)
end

return Thief
