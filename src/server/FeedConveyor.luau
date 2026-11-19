-- The Feed: a conveyor down the middle of the phone that scrolls random brainrots past for players to buy.
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.BrainrotCatalog)
local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Spawner = require(script.Parent.BrainrotSpawner)
local Carry = require(script.Parent.BrainrotCarry)

local SCROLL_SPEED = 8 -- studs per second
local SPAWN_SECONDS = 2.2
local START_Z, END_Z = -146, 147

local feed = workspace.Feed
local rng = Random.new()

local Feed = {}

function Feed.buyBrainrot(player: Player, model: Model)
	local state = PlayerState.get(player)
	if not state or not model.Parent then
		return
	end
	local id, mutation = model:GetAttribute("Id"), model:GetAttribute("Mutation")
	local price = Catalog.priceOf(id, mutation)
	if state.carrying then
		PlayerState.notify(player, "Hands full! Carry this one home first.", "warn")
	elseif not PlayerState.trySpend(player, price) then
		PlayerState.notify(player, "Not enough money: it costs " .. Rules.formatMoney(price), "warn")
	else
		model:Destroy()
		Carry.give(player, id, mutation)
		PlayerState.notify(player, "Bought " .. Catalog.byId[id].name .. "! Carry it to your base.", "good")
	end
end

-- Rolls a brainrot (and maybe a mutation) and sets it riding the belt from z.
function Feed.spawnOnBelt(z: number?, forcedId: string?, forcedMutation: string?)
	local entry = forcedId and Catalog.byId[forcedId] or Catalog.rollRandomBrainrot(rng)
	local mutation = forcedMutation or (not forcedId and Catalog.rollMutation(rng) or nil)
	local model = Spawner.spawn(entry.id, mutation, true)
	local root = model.PrimaryPart
	root.Anchored = false
	root.CanCollide = true
	root.CollisionGroup = "FeedItem"
	root.CustomPhysicalProperties = PhysicalProperties.new(2, 2, 0, 100, 1)
	model:PivotTo(CFrame.new(0, 0.45, z or START_Z) * CFrame.Angles(0, math.pi, 0))
	local price = Rules.formatMoney(Catalog.priceOf(entry.id, mutation))
	local prompt = Spawner.addPrompt(root, "BuyPrompt", "Buy " .. price, entry.name, 0)
	prompt.Triggered:Connect(function(player)
		Feed.buyBrainrot(player, model)
	end)
	model.Parent = feed.Items
	root:SetNetworkOwner(nil)
	if not z and (mutation == "LegendaryMeme" or entry.tier >= 5) then
		local kind = mutation == "LegendaryMeme" and "LEGENDARY MEME" or entry.rarity.name
		PlayerState.notifyAll("👀 " .. kind .. " " .. entry.name .. " just hit the Feed!", "info")
	end
	return model
end

-- Removes everything on the belt beyond z: scrolled off the end, or wiped away by the Giant Thumb.
function Feed.sweepBeyond(z: number)
	for _, model in feed.Items:GetChildren() do
		local position = model:GetPivot().Position
		if position.Z > z or position.Y < -4 then
			model:Destroy()
		end
	end
end

function Feed.start()
	PhysicsService:RegisterCollisionGroup("FeedItem")
	PhysicsService:RegisterCollisionGroup("FeedBelt")
	PhysicsService:CollisionGroupSetCollidable("FeedItem", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("FeedItem", "FeedItem", false)
	PhysicsService:CollisionGroupSetCollidable("FeedItem", "FeedBelt", true)
	feed.Belt.CollisionGroup = "FeedBelt"
	feed.Belt.AssemblyLinearVelocity = Vector3.new(0, 0, SCROLL_SPEED)
	for z = END_Z - 12, START_Z + 16, -SCROLL_SPEED * SPAWN_SECONDS do
		Feed.spawnOnBelt(z)
	end
	task.spawn(function()
		while true do
			Feed.spawnOnBelt()
			task.wait(SPAWN_SECONDS)
			Feed.sweepBeyond(END_Z)
		end
	end)
end

return Feed
