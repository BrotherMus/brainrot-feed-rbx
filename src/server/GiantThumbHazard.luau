-- GiantThumbHazard: every few minutes a thumb the size of a building swipes up the Feed.
-- The lane flashes red and every screen shows a warning first. Anyone still on the Feed
-- when it passes is knocked flying and drops what they carry; the posts it passes are
-- swiped away and the Feed comes back "refreshed" with rarer brainrots for a while.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local CarryBrainrot = require(script.Parent.CarryBrainrot)
local FeedConveyor = require(script.Parent.FeedConveyor)
local Notify = ReplicatedStorage.Remotes.Notify

local THUMB, FEED = GameConfig.THUMB, GameConfig.FEED
local CALM, DANGER = Color3.fromRGB(34, 211, 238), Color3.fromRGB(255, 40, 40)

local GiantThumbHazard = {}

local swiping = false
local rng = Random.new()

local function colourWarnStrips(color: Color3)
	for _, strip in workspace.Feed:GetChildren() do
		if strip.Name == "WarnStrip" then
			(strip :: BasePart).Color = color
		end
	end
end

-- Everyone on the lane under the thumb's pad is hit once: they drop what they carry.
local function knockPlayersOffFeed(thumbZ: number, alreadyHit: { [Player]: boolean })
	for _, player in Players:GetPlayers() do
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart and not alreadyHit[player] then
			local position = rootPart.Position
			local underPad = math.abs(position.X) <= THUMB.HIT_HALF_WIDTH and math.abs(position.Z - (thumbZ + 8)) <= 27
			if underPad and position.Y < 30 then
				alreadyHit[player] = true
				CarryBrainrot.drop(player, "thumb")
				Notify:FireClient(player, "SWIPED! The Giant Thumb knocked you off the Feed", "swiped")
			end
		end
	end
end

-- The whole hazard: warning, the thumb pressing down, the swipe up the lane, the lift.
function GiantThumbHazard.swipeTheFeed()
	if swiping then
		return
	end
	swiping = true
	workspace:SetAttribute("ThumbWarningUntil", workspace:GetServerTimeNow() + THUMB.WARNING)
	local warningEnds = os.clock() + THUMB.WARNING
	local lit = false
	while os.clock() < warningEnds do
		lit = not lit
		colourWarnStrips(if lit then DANGER else Color3.fromRGB(90, 10, 10))
		task.wait(0.25)
	end
	colourWarnStrips(DANGER)

	local thumb = ServerStorage.GiantThumb:Clone()
	local fromZ, toZ = FEED.END_Z + 50, FEED.START_Z - 70
	thumb:PivotTo(CFrame.new(0, 70, fromZ))
	thumb.Parent = workspace
	workspace:SetAttribute("ThumbSwiping", true)
	local alreadyHit: { [Player]: boolean } = {}
	local startedAt = os.clock()
	local pressTime, liftTime = 0.5, 0.7
	while true do
		RunService.Heartbeat:Wait()
		local t = os.clock() - startedAt
		local y, z = 0.5, fromZ
		if t < pressTime then
			y = 70 - 69.5 * (t / pressTime)
		elseif t < pressTime + THUMB.SWIPE_SECONDS then
			z = fromZ + (toZ - fromZ) * ((t - pressTime) / THUMB.SWIPE_SECONDS)
			knockPlayersOffFeed(z, alreadyHit)
			FeedConveyor.swipeAwayBeyond(z - 12)
		elseif t < pressTime + THUMB.SWIPE_SECONDS + liftTime then
			z = toZ
			y = 0.5 + 90 * ((t - pressTime - THUMB.SWIPE_SECONDS) / liftTime)
		else
			break
		end
		thumb:PivotTo(CFrame.new(0, y, z))
	end
	thumb:Destroy()
	workspace:SetAttribute("ThumbSwiping", false)
	colourWarnStrips(CALM)
	FeedConveyor.freshFeed(2.2, 25)
	Notify:FireAllClients("Feed refreshed! Rarer brainrots for 25 seconds", "good")
	swiping = false
end

-- For the tour: asks the running game for a swipe right now, whoever calls it.
function GiantThumbHazard.swipeNow()
	ServerStorage.TourSignals.SwipeNow:Fire()
end

function GiantThumbHazard.start()
	ServerStorage.TourSignals.SwipeNow.Event:Connect(GiantThumbHazard.swipeTheFeed)
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(THUMB.EVERY_MIN, THUMB.EVERY_MAX))
			GiantThumbHazard.swipeTheFeed()
		end
	end)
end

return GiantThumbHazard
