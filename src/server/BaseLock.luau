-- BaseLock: "Go Private". Raises a shield over the owner's base for 60 seconds (longer
-- with the LOCK TIME upgrade). While it is up nobody can steal there, the Scam Bot is
-- turned away and intruders are pushed back out. Then it needs a cooldown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local BaseStands = require(script.Parent.BaseStands)
local PlayerState = require(script.Parent.PlayerState)
local Notify = ReplicatedStorage.Remotes.Notify

local BaseLock = {}

function BaseLock.isLocked(base: BaseStands.Base): boolean
	return workspace:GetServerTimeNow() < base.lockedUntil
end

local function showShield(base: BaseStands.Base, locked: boolean)
	for _, name in { "Barrier", "BarrierRoof" } do
		local shield = base.model:FindFirstChild(name) :: BasePart
		shield.Transparency = if locked then 0 else 1
	end
end

-- The owner pressed GO PRIVATE.
function BaseLock.goPrivate(player: Player)
	local base = BaseStands.baseOf(player)
	local profile = PlayerState.get(player)
	local now = workspace:GetServerTimeNow()
	if not base or not profile then
		return
	elseif now < base.lockReadyAt then
		Notify:FireClient(player, "Go Private is recharging", "info")
		return
	end
	local seconds = GameConfig.lockSeconds(profile.upgrades.LockTime)
	base.lockedUntil = now + seconds
	base.lockReadyAt = base.lockedUntil + GameConfig.LOCK_COOLDOWN
	player:SetAttribute("LockedUntil", base.lockedUntil)
	player:SetAttribute("LockReadyAt", base.lockReadyAt)
	showShield(base, true)
	Notify:FireClient(player, "Your base is PRIVATE for " .. seconds .. " seconds", "good")
end

-- Anyone but the owner standing inside a locked base is put back out at its front.
local function pushIntrudersOut(base: BaseStands.Base)
	for _, player in Players:GetPlayers() do
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player ~= base.owner and rootPart and BaseStands.isInside(base, rootPart.Position) then
			local floor = base.model.PrimaryPart :: BasePart
			rootPart.CFrame = CFrame.new(floor.Position.X - base.side * 46, 4, rootPart.Position.Z)
			Notify:FireClient(player, "This base is PRIVATE", "bad")
		end
	end
end

function BaseLock.start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = workspace:GetServerTimeNow()
			for _, base in BaseStands.all() do
				if now < base.lockedUntil then
					BaseStands.setSignLine(base, "LockLabel", "PRIVATE " .. math.ceil(base.lockedUntil - now) .. "s", Color3.fromRGB(248, 113, 113))
					pushIntrudersOut(base)
				elseif (base.model:FindFirstChild("Barrier") :: BasePart).Transparency == 0 or base.lockedUntil ~= 0 then
					base.lockedUntil = 0
					showShield(base, false)
					BaseStands.setSignLine(base, "LockLabel", "UNLOCKED", Color3.fromRGB(134, 239, 172))
				end
			end
		end
	end)
end

return BaseLock
