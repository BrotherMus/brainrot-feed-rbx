-- ThiefNpc: the Scam Bot, a flying pop-up ad that steals from unlocked bases so there is
-- a thief even when you play alone. Go Private turns it away; BLOCK it to get the loot back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local GameConfig = require(ReplicatedStorage.GameConfig)
local BaseLock = require(script.Parent.BaseLock)
local BaseStands = require(script.Parent.WorldBases)
local BrainrotModels = require(script.Parent.BrainrotModels)
local PlayerState = require(script.Parent.PlayerState)
local Notify = ReplicatedStorage.Remotes.Notify

local THIEF = GameConfig.THIEF
local ESCAPE_POINT = Vector3.new(0, 9, 226) -- over the charging port

local ThiefNpc = {}

type Raid = { bot: Model, blockedBy: Player? }

local rng = Random.new()
local raidRunning = false

-- An unlocked base with enough brainrots to be worth robbing, or nil.
function ThiefNpc.pickUnlockedBase(minimumBrainrots: number): BaseStands.Base?
	local candidates = {}
	for _, base in BaseStands.all() do
		if base.owner and not BaseLock.isLocked(base) and #BaseStands.occupiedStands(base) >= minimumBrainrots then
			table.insert(candidates, base)
		end
	end
	return if #candidates > 0 then candidates[rng:NextInteger(1, #candidates)] else nil
end

local function setStatus(raid: Raid, text: string)
	local tag = (raid.bot.PrimaryPart :: BasePart):FindFirstChild("BotTag") :: BillboardGui
	local status = tag:FindFirstChild("Status") :: TextLabel
	status.Text = text
end

-- Flies the bot to `target`. False when it was blocked on the way or ran out of time.
local function flyTo(raid: Raid, target: Vector3, speed: number, timeout: number): boolean
	local body = raid.bot.PrimaryPart :: BasePart
	local fly = body:FindFirstChild("Fly") :: AlignPosition
	local face = body:FindFirstChild("Face") :: AlignOrientation
	local flat = Vector3.new(target.X - body.Position.X, 0, target.Z - body.Position.Z)
	if flat.Magnitude > 1 then
		face.CFrame = CFrame.lookAt(Vector3.zero, flat)
	end
	fly.MaxVelocity = speed
	fly.Position = target
	local deadline = os.clock() + timeout
	while os.clock() < deadline and not raid.blockedBy do
		if (body.Position - target).Magnitude < 3 then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local function rewardBlocker(raid: Raid, reward: number, what: string)
	local blocker = raid.blockedBy :: Player
	PlayerState.addCash(blocker, reward)
	Notify:FireClient(blocker, "BLOCKED the Scam Bot! " .. what .. " +" .. GameConfig.formatCash(reward), "cash")
end

-- One whole robbery of `base`, from the bot flying in to it leaving (with or without loot).
function ThiefNpc.raidBase(base: BaseStands.Base)
	local owner = base.owner
	local occupied = BaseStands.occupiedStands(base)
	if raidRunning or not owner or #occupied == 0 then
		return
	end
	raidRunning = true
	local standIndex = occupied[rng:NextInteger(1, #occupied)]
	local pedestal = base.stands[standIndex].model.PrimaryPart :: BasePart
	local bot = ServerStorage.ScamBot:Clone()
	local body = bot.PrimaryPart :: BasePart
	local raid: Raid = { bot = bot }
	bot:PivotTo(CFrame.new(base.side * 150, 50, pedestal.Position.Z))
	bot.Parent = workspace
	body:SetNetworkOwner(nil);
	(body:FindFirstChild("BlockPrompt") :: ProximityPrompt).Triggered:Connect(function(player)
		raid.blockedBy = raid.blockedBy or player
	end)
	Notify:FireClient(owner, "SCAM BOT is coming for your base! GO PRIVATE or BLOCK it!", "bad")
	setStatus(raid, "heading for @" .. owner.DisplayName)

	local stolenId: string?, stolenMutation: string? = nil, nil
	if flyTo(raid, pedestal.Position + Vector3.new(0, 11, 0), THIEF.SPEED, 25) then
		local grabAt = os.clock() + THIEF.GRAB_SECONDS
		while os.clock() < grabAt and not raid.blockedBy and not BaseLock.isLocked(base) do
			setStatus(raid, string.format("stealing... %.1f", grabAt - os.clock()))
			task.wait(0.1)
		end
		if not raid.blockedBy and not BaseLock.isLocked(base) and base.owner == owner and base.stands[standIndex].id then
			stolenId, stolenMutation = BaseStands.clearStand(base, standIndex)
		end
	end

	if stolenId then
		local name = (BrainrotCatalog.get(stolenId) :: BrainrotCatalog.Entry).name
		local loot = BrainrotModels.cloneWithMutation(stolenId, stolenMutation)
		local lootRoot = loot.PrimaryPart :: BasePart
		loot:PivotTo(body.CFrame * CFrame.new(0, -9.5, 0))
		lootRoot.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = lootRoot
		weld.Parent = lootRoot
		loot.Parent = bot
		setStatus(raid, "GOT " .. string.upper(name) .. "! BLOCK ME")
		Notify:FireClient(owner, "The Scam Bot grabbed " .. name .. "! BLOCK it before it escapes!", "bad")
		local escaped = flyTo(raid, ESCAPE_POINT, THIEF.SPEED * 0.6, 60)
		if raid.blockedBy or not escaped then
			if base.owner == owner then
				local home = if base.stands[standIndex].id then BaseStands.firstFreeStand(base) else standIndex
				if home then
					BaseStands.setStandBrainrot(base, home, stolenId, stolenMutation)
				end
				Notify:FireClient(owner, name .. " is back on your stand", "good")
			end
			if raid.blockedBy then
				rewardBlocker(raid, math.max(50, BrainrotCatalog.incomeOf(stolenId, stolenMutation) * 20), name .. " saved.")
			end
		else
			Notify:FireClient(owner, "The Scam Bot escaped with " .. name .. ". Go Private next time!", "bad")
		end
		loot:Destroy()
	elseif raid.blockedBy then
		rewardBlocker(raid, 50, "It never got near.")
	elseif BaseLock.isLocked(base) then
		Notify:FireClient(owner, "ACCESS DENIED: the Scam Bot bounced off your private base", "good")
	end

	setStatus(raid, if raid.blockedBy then "BLOCKED!" elseif stolenId then "thanks for the brainrot" else "ACCESS DENIED")
	raid.blockedBy = nil
	flyTo(raid, body.Position + Vector3.new(0, 90, 60), 60, 3)
	bot:Destroy()
	raidRunning = false
end

function ThiefNpc.start()
	ServerStorage.TourSignals.RaidNow.Event:Connect(function()
		local base = ThiefNpc.pickUnlockedBase(1)
		if base then
			ThiefNpc.raidBase(base)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(THIEF.EVERY_MIN, THIEF.EVERY_MAX))
			local base = ThiefNpc.pickUnlockedBase(THIEF.MIN_BRAINROTS)
			if base then
				ThiefNpc.raidBase(base)
			end
		end
	end)
end

return ThiefNpc
