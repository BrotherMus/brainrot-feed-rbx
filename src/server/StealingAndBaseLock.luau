-- Stealing and defence: thieves lift brainrots off unlocked stands; "Go Private" locks a base for a while.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.BrainrotCatalog)
local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Spawner = require(script.Parent.BrainrotSpawner)
local Carry = require(script.Parent.BrainrotCarry)
local Stands = require(script.Parent.BaseStandsIncome)

local TAG_DISTANCE = 7

local Stealing = {}

function Stealing.isLocked(owner: Player): boolean
	local state = PlayerState.get(owner)
	return state ~= nil and state.lockedUntil > workspace:GetServerTimeNow()
end

local function showBarrier(base: Model, locked: boolean)
	for _, wall in base.Barrier:GetChildren() do
		wall.Transparency = locked and 0.2 or 1
	end
	base.OwnerSign.Gui.LockStatus.Text = locked and "🔒 PRIVATE" or "🔓 OPEN"
end

-- Locks the player's base against every thief for the Lock Time upgrade's duration, then recharges.
function Stealing.goPrivate(player: Player)
	local state = PlayerState.get(player)
	local now = workspace:GetServerTimeNow()
	if not state or not state.base then
		return
	end
	if now < state.lockReadyAt then
		PlayerState.notify(player, "Lock is recharging: " .. math.ceil(state.lockReadyAt - now) .. "s", "warn")
		return
	end
	local seconds = Rules.lockSeconds(state.upgrades.LockTime)
	local base = state.base
	state.lockedUntil = now + seconds
	state.lockReadyAt = state.lockedUntil + Rules.LOCK_COOLDOWN
	PlayerState.publish(player)
	showBarrier(base, true)
	PlayerState.notify(player, "🔒 Your base is PRIVATE for " .. seconds .. "s. Nobody can steal.", "good")
	task.delay(seconds, function()
		if state.base == base and not Stealing.isLocked(player) then
			showBarrier(base, false)
		end
	end)
end

-- A player lifts a brainrot off someone else's stand and has to carry it home.
function Stealing.trySteal(thief: Player, owner: Player, slot: number)
	local thiefState = PlayerState.get(thief)
	if Stealing.isLocked(owner) then
		PlayerState.notify(thief, "🔒 That base is PRIVATE. Come back when the lock runs out.", "warn")
	elseif not thiefState or thiefState.carrying then
		PlayerState.notify(thief, "Hands full! Carry this one home first.", "warn")
	else
		local stand = Stands.remove(owner, slot)
		if stand and Carry.give(thief, stand.id, stand.mutation, owner) then
			local name = Catalog.byId[stand.id].name
			PlayerState.notify(owner, "🚨 " .. thief.DisplayName .. " is stealing your " .. name .. "! Tag them!", "alert")
			PlayerState.notify(thief, "You stole " .. name .. "! RUN to your base!", "good")
		end
	end
end

-- Stolen goods that were dropped or recovered go back to a free stand of their owner.
function Stealing.returnToOwner(cargo)
	local owner = cargo.stolenFrom
	if owner and PlayerState.get(owner) and Stands.place(owner, cargo.id, cargo.mutation) then
		PlayerState.notify(owner, "✅ " .. Catalog.byId[cargo.id].name .. " is back on its stand.", "good")
	end
end

-- An owner who touches the thief gets the brainrot straight back.
local function catchTaggedThieves()
	for thief, state in PlayerState.all() do
		local victim = state.carrying and state.carrying.stolenFrom
		local thiefRoot = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
		local victimRoot = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
		if thiefRoot and victimRoot and (thiefRoot.Position - victimRoot.Position).Magnitude < TAG_DISTANCE then
			Stealing.returnToOwner(Carry.take(thief))
			PlayerState.notify(thief, "Caught! " .. victim.DisplayName .. " took it back.", "alert")
		end
	end
end

function Stealing.start()
	Stands.onStealAttempt = Stealing.trySteal
	Carry.onPickupExpired = Stealing.returnToOwner
	for _, base in workspace.Bases:GetChildren() do
		local prompt = Spawner.addPrompt(base.LockButton, "LockPrompt", "Go Private", "Lock your base", 0)
		prompt.Triggered:Connect(function(player)
			if Stands.ownerOf(base) == player then
				Stealing.goPrivate(player)
			else
				PlayerState.notify(player, "Only the owner can lock this base.", "warn")
			end
		end)
	end
	task.spawn(function()
		while task.wait(0.2) do
			catchTaggedThieves()
		end
	end)
end

return Stealing
