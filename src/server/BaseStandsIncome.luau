-- Bases: each player owns a profile with stands; a placed brainrot earns money every second until collected.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.BrainrotCatalog)
local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)
local Spawner = require(script.Parent.BrainrotSpawner)
local Carry = require(script.Parent.BrainrotCarry)

local bases = workspace.Bases
local owners = {} -- [base model] = player

local Stands = {}
Stands.onStealAttempt = nil -- StealingAndBaseLock sets this: (thief, owner, slot)

-- Once a second every placed brainrot pays its rate into its stand's cash plate.
local function earnIncomeEverySecond(player: Player, state)
	local multiplier = PlayerState.incomeMultiplier(player)
	local total = 0
	for slot, stand in state.stands do
		local rate = Catalog.incomeOf(stand.id, stand.mutation) * multiplier
		stand.pending += rate
		total += rate
		state.base.Stands["Stand" .. slot].CashPlate.CashGui.Amount.Text = Rules.formatMoney(stand.pending)
		Spawner.writeLabel(stand.model, nil, rate)
	end
	state.income = total
	player:SetAttribute("Income", total)
	-- nobody gets stuck: a player robbed of everything and too poor for the cheapest brainrot is topped up
	if total == 0 and not state.carrying and state.money < Catalog.list[1].price then
		PlayerState.addMoney(player, Rules.START_MONEY - state.money)
		PlayerState.notify(player, "The algorithm pities you: back to " .. Rules.formatMoney(Rules.START_MONEY), "info")
	end
end

-- Walking over a stand's cash plate collects what it has earned.
local function collectNearbyCash(player: Player, state, position: Vector3)
	for slot, stand in state.stands do
		local plate = state.base.Stands["Stand" .. slot].CashPlate
		if stand.pending > 0 and (plate.Position - position).Magnitude < 5.5 then
			PlayerState.addMoney(player, stand.pending)
			stand.pending = 0
			plate.CashGui.Amount.Text = "$0"
		end
	end
end

function Stands.ownerOf(base: Model): Player?
	return owners[base]
end

function Stands.isInsideBase(base: Model, position: Vector3): boolean
	local offset = base.Floor.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) < 28 and math.abs(offset.Z) < 32
end

-- Shows as many stands as the More Stands upgrade has unlocked.
function Stands.refreshStands(player: Player)
	local state = PlayerState.get(player)
	local count = Rules.standCount(state.upgrades.Stands)
	for _, stand in state.base.Stands:GetChildren() do
		local open = stand:GetAttribute("Slot") <= count
		stand.Pedestal.Transparency = open and 0 or 0.85
		stand.CashPlate.Transparency = open and 0 or 1
		stand.CashPlate.CashGui.Enabled = open
	end
end

function Stands.freeSlot(player: Player): number?
	local state = PlayerState.get(player)
	for slot = 1, Rules.standCount(state.upgrades.Stands) do
		if not state.stands[slot] then
			return slot
		end
	end
	return nil
end

-- Puts a brainrot on a stand of the player's base, facing down the phone like everything on the Feed.
function Stands.place(player: Player, id: string, mutation: string?, slot: number?): boolean
	local state = PlayerState.get(player)
	slot = slot or Stands.freeSlot(player)
	if not state or not state.base or not slot or state.stands[slot] then
		return false
	end
	local pedestal = state.base.Stands["Stand" .. slot].Pedestal
	local top = pedestal.Position + Vector3.new(0, pedestal.Size.X / 2, 0)
	local model = Spawner.spawn(id, mutation, false)
	model.PrimaryPart.Anchored = true
	model.PrimaryPart.CanCollide = false
	model:PivotTo(CFrame.lookAt(top, top + Vector3.zAxis))
	model.Parent = pedestal.Parent
	local prompt = Spawner.addPrompt(pedestal, "StandPrompt", "Steal", Catalog.byId[id].name, 1.2)
	prompt:SetAttribute("SellValue", math.floor(Catalog.priceOf(id, mutation) * Rules.SELL_REFUND))
	prompt.Triggered:Connect(function(who)
		if who == player then
			Stands.sell(player, slot)
		elseif Stands.onStealAttempt then
			Stands.onStealAttempt(who, player, slot)
		end
	end)
	state.stands[slot] = { id = id, mutation = mutation, pending = 0, model = model, prompt = prompt }
	if PlayerState.discover(player, id) then
		PlayerState.notify(player, "📖 New in your Index: " .. Catalog.byId[id].name .. " (+1% money)", "good")
	end
	return true
end

-- Empties a stand and returns what stood on it; uncollected money on it is lost.
function Stands.remove(player: Player, slot: number)
	local state = PlayerState.get(player)
	local stand = state and state.stands[slot]
	if not stand then
		return nil
	end
	state.stands[slot] = nil
	stand.model:Destroy()
	stand.prompt:Destroy()
	state.base.Stands["Stand" .. slot].CashPlate.CashGui.Amount.Text = "$0"
	return stand
end

function Stands.sell(player: Player, slot: number)
	local stand = Stands.remove(player, slot)
	if stand then
		local value = stand.pending + math.floor(Catalog.priceOf(stand.id, stand.mutation) * Rules.SELL_REFUND)
		PlayerState.addMoney(player, value)
		PlayerState.notify(player, "Sold " .. Catalog.byId[stand.id].name .. " for " .. Rules.formatMoney(value), "info")
	end
end

function Stands.clear(player: Player)
	local state = PlayerState.get(player)
	for slot in pairs(table.clone(state.stands)) do
		Stands.remove(player, slot)
	end
end

function Stands.assignBase(player: Player)
	local state = PlayerState.get(player)
	for number = 1, #bases:GetChildren() do
		local base = bases["Base" .. number]
		if not owners[base] then
			owners[base] = player
			state.base = base
			base:SetAttribute("OwnerId", player.UserId)
			base.OwnerSign.Gui.OwnerName.Text = "@" .. player.DisplayName
			base.OwnerSign.Gui.LockStatus.Text = "🔓 OPEN"
			Stands.refreshStands(player)
			for slot, saved in state.savedStands or {} do
				Stands.place(player, saved.id, saved.mutation, tonumber(slot))
			end
			return base
		end
	end
	return nil
end

function Stands.releaseBase(player: Player)
	local state = PlayerState.get(player)
	if state and state.base then
		Stands.clear(player)
		owners[state.base] = nil
		state.base:SetAttribute("OwnerId", nil)
		state.base.OwnerSign.Gui.OwnerName.Text = "FREE PROFILE"
		state.base.OwnerSign.Gui.LockStatus.Text = "waiting for a player"
		state.base = nil
	end
end

-- Carrying a brainrot into your own base puts it on the first free stand.
local function placeCargoAtHome(player: Player, state)
	if not Stands.freeSlot(player) then
		if os.clock() - (state.fullWarnedAt or 0) > 4 then
			state.fullWarnedAt = os.clock()
			PlayerState.notify(player, "All stands are full! Sell one or buy More Stands.", "warn")
		end
		return
	end
	local cargo = Carry.take(player)
	Stands.place(player, cargo.id, cargo.mutation)
	PlayerState.notify(player, Catalog.byId[cargo.id].name .. " is on its stand and earning!", "good")
end

function Stands.start()
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(0.2)
			ticks += 1
			for player, state in PlayerState.all() do
				local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if state.base and ticks % 5 == 0 then
					earnIncomeEverySecond(player, state)
				end
				if state.base and rootPart then
					collectNearbyCash(player, state, rootPart.Position)
					if state.carrying and Stands.isInsideBase(state.base, rootPart.Position) then
						placeCargoAtHome(player, state)
					end
				end
			end
		end
	end)
end

return Stands
