-- FeedConveyor: the Feed. Posts (a brainrot riding a card) appear under THE FEED arch and
-- scroll down the lane in the middle of the phone. Each shows its name, rarity, price and
-- money per second, and the first player to pay for it carries it away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotBuilder = require(ReplicatedStorage.BrainrotBuilder)
local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local GameConfig = require(ReplicatedStorage.GameConfig)
local CarryBrainrot = require(script.Parent.CarryBrainrot)
local PlayerState = require(script.Parent.PlayerState)
local Notify = ReplicatedStorage.Remotes.Notify

local FEED = GameConfig.FEED
local FeedConveyor = {}

type Post = { model: Model, id: string, mutation: string?, price: number }

local posts: { Post } = {}
local rng = Random.new()
local spawnCount = 0
local luck, luckUntil = 1, 0

local function removePost(post: Post)
	local at = table.find(posts, post)
	if at then
		table.remove(posts, at)
	end
	post.model:Destroy()
end

-- The player pays the post's price and walks off with the brainrot on their head.
function FeedConveyor.buyFromFeed(player: Player, post: Post)
	local name = post.model.Name
	if not post.model.Parent then
		return
	elseif CarryBrainrot.get(player) then
		Notify:FireClient(player, "Hands full: carry this one home first", "info")
	elseif not PlayerState.trySpend(player, post.price) then
		Notify:FireClient(player, name .. " costs " .. GameConfig.formatCash(post.price) .. ": not enough cash", "bad")
	elseif CarryBrainrot.pickUp(player, post.id, post.mutation) then
		removePost(post)
		Notify:FireClient(player, "Bought " .. name .. "! Carry it to a stand in your base", "good")
	else
		PlayerState.addCash(player, post.price) -- could not pick it up: money back
	end
end

local function weldedPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = model.PrimaryPart
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- Rolls a brainrot, stands it on a post card at `z` on the lane and sets it scrolling.
local function spawnPost(z: number)
	spawnCount += 1
	local id, mutation = BrainrotCatalog.rollForFeed(rng, if os.clock() < luckUntil then luck else 1)
	local entry = BrainrotCatalog.get(id) :: BrainrotCatalog.Entry
	local model = BrainrotBuilder.buildFromParts(id, mutation)
	local root = model.PrimaryPart :: BasePart
	local column = if spawnCount % 2 == 0 then -1 else 1 -- two columns, each facing its side's bases
	local at = Vector3.new(column * 6.8, 0.75, z)
	local facing = CFrame.lookAt(at, at + Vector3.new(column, 0, 0))
	model:PivotTo(facing)
	weldedPart(model, "PostCard", Vector3.new(12, 0.3, 12), CFrame.new(at.X, 0.58, z), Color3.fromRGB(241, 245, 249), Enum.Material.SmoothPlastic)
	weldedPart(model, "PostHeader", Vector3.new(12, 0.34, 2.2), CFrame.new(at.X, 0.59, z - 4.9), entry.color, Enum.Material.Neon)

	-- physics carries it down the lane so every client sees it glide, not hop
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = Vector3.new(0, 0, FEED.SPEED)
	velocity.MaxForce = math.huge
	velocity.Parent = root
	local upright = Instance.new("AlignOrientation")
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = attachment
	upright.CFrame = facing.Rotation
	upright.RigidityEnabled = true
	upright.Parent = root

	local post: Post = { model = model, id = id, mutation = mutation, price = BrainrotCatalog.priceOf(id, mutation) }
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. GameConfig.formatCash(post.price)
	prompt.ObjectText = entry.name
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		FeedConveyor.buyFromFeed(player, post)
	end)

	root.Anchored = false
	model.Parent = workspace.Feed.Posts
	root:SetNetworkOwner(nil)
	table.insert(posts, post)
end

-- The Giant Thumb wipes every post it has passed (it swipes from the far end toward -Z).
function FeedConveyor.swipeAwayBeyond(z: number)
	for index = #posts, 1, -1 do
		if posts[index].model:GetPivot().Position.Z >= z then
			removePost(posts[index])
		end
	end
end

-- After a swipe the Feed is "refreshed": for a while it rolls rarer posts.
function FeedConveyor.freshFeed(newLuck: number, seconds: number)
	luck, luckUntil = newLuck, os.clock() + seconds
end

function FeedConveyor.start()
	for z = FEED.START_Z, FEED.END_Z - 30, FEED.SPEED * FEED.SPAWN_EVERY do
		spawnPost(z) -- the lane is already full when the first player arrives
	end
	task.spawn(function()
		while true do
			task.wait(FEED.SPAWN_EVERY)
			spawnPost(FEED.START_Z)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			FeedConveyor.swipeAwayBeyond(FEED.END_Z) -- seen it: off the end of the Feed
		end
	end)
end

return FeedConveyor
