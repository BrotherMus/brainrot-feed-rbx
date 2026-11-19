-- The Giant Thumb: every few minutes a huge thumb swipes the Feed after a warning; anyone hit drops their cargo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Carry = require(script.Parent.BrainrotCarry)
local Feed = require(script.Parent.FeedConveyor)

local LANE_HALF_WIDTH = 14
local SWIPE_FROM_Z, SWIPE_TO_Z = 168, -138
local SWIPE_SECONDS = 4

local swiping = false

local Thumb = {}

-- Throws a player clear of the Feed; whatever they carried is left lying where they stood.
function Thumb.flickPlayer(player: Player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local side = rootPart.Position.X >= 0 and 1 or -1
	local hadCargo = PlayerState.get(player) and PlayerState.get(player).carrying
	Carry.drop(player, rootPart.Position + Vector3.new(side * 6, 0, 0))
	character:PivotTo(rootPart.CFrame + Vector3.new(side * 24, 9, -12))
	local text = hadCargo and "👍 SWIPED! You dropped your brainrot. Grab it back!" or "👍 SWIPED by the Giant Thumb!"
	PlayerState.notify(player, text, "alert")
end

local function moveThumb(pad: BasePart, goal: CFrame, seconds: number, style: Enum.EasingStyle)
	local tween = TweenService:Create(pad, TweenInfo.new(seconds, style), { CFrame = goal })
	tween:Play()
	tween.Completed:Wait()
end

-- Warning first (the HUD counts down to ThumbAt), then the thumb presses down and swipes up the Feed.
function Thumb.swipe()
	if swiping then
		return
	end
	swiping = true
	workspace:SetAttribute("ThumbAt", workspace:GetServerTimeNow() + Rules.THUMB_WARNING)
	task.wait(Rules.THUMB_WARNING)

	local thumb = ServerStorage.GiantThumb:Clone()
	local pad = thumb.PrimaryPart
	thumb:PivotTo(CFrame.new(0, 70, SWIPE_FROM_Z))
	thumb.Parent = workspace
	moveThumb(pad, CFrame.new(0, 1, SWIPE_FROM_Z), 0.45, Enum.EasingStyle.Quad)

	local alreadyHit = {}
	local watcher = RunService.Heartbeat:Connect(function()
		local z = pad.Position.Z
		Feed.sweepBeyond(z - 12)
		for _, player in Players:GetPlayers() do
			local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local position = rootPart and rootPart.Position
			if position and not alreadyHit[player] and math.abs(position.X) < LANE_HALF_WIDTH and math.abs(position.Z - z) < 18 then
				alreadyHit[player] = true
				Thumb.flickPlayer(player)
			end
		end
	end)
	moveThumb(pad, CFrame.new(0, 1, SWIPE_TO_Z), SWIPE_SECONDS, Enum.EasingStyle.Linear)
	watcher:Disconnect()
	moveThumb(pad, CFrame.new(0, 90, SWIPE_TO_Z - 30), 0.7, Enum.EasingStyle.Quad)
	thumb:Destroy()
	workspace:SetAttribute("ThumbAt", 0)
	swiping = false
end

function Thumb.start()
	task.spawn(function()
		while task.wait(Rules.THUMB_INTERVAL) do
			Thumb.swipe()
		end
	end)
end

return Thumb
