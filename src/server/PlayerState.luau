-- The one place every player's state lives: money, rebirths, upgrades, index, stands, base and cargo.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.EconomyRules)
local notifyRemote = ReplicatedStorage.Remotes.Notify

local PlayerState = {}
local states = {}

local store
pcall(function()
	store = DataStoreService:GetDataStore("DoomscrollDashV1")
end)

function PlayerState.create(player: Player)
	local state = {
		money = Rules.START_MONEY,
		rebirths = 0,
		upgrades = { CarrySpeed = 0, LockTime = 0, Stands = 0 },
		index = {}, -- [brainrot id] = true once found
		indexCount = 0,
		stands = {}, -- [slot] = { id, mutation, pending, model, prompt }
		carrying = nil, -- { id, mutation, model, stolenFrom }
		base = nil,
		income = 0,
		lockedUntil = 0,
		lockReadyAt = 0,
		savedStands = nil,
	}
	local ok, saved = pcall(function()
		return store and store:GetAsync("p" .. player.UserId)
	end)
	if ok and type(saved) == "table" then
		state.money = saved.money or state.money
		state.rebirths = saved.rebirths or 0
		for key in state.upgrades do
			state.upgrades[key] = saved.upgrades and saved.upgrades[key] or 0
		end
		for _, id in saved.index or {} do
			state.index[id] = true
			state.indexCount += 1
		end
		state.savedStands = saved.stands
	end
	states[player] = state
	PlayerState.publish(player)
	return state
end

function PlayerState.get(player: Player)
	return states[player]
end

function PlayerState.all()
	return states
end

function PlayerState.save(player: Player)
	local state = states[player]
	if not state or not store then
		return
	end
	local index, stands = {}, {}
	for id in state.index do
		table.insert(index, id)
	end
	for slot, stand in state.stands do
		stands[tostring(slot)] = { id = stand.id, mutation = stand.mutation }
	end
	local data = { money = state.money, rebirths = state.rebirths, upgrades = state.upgrades, index = index, stands = stands }
	pcall(function()
		store:SetAsync("p" .. player.UserId, data)
	end)
end

function PlayerState.remove(player: Player)
	states[player] = nil
end

function PlayerState.addMoney(player: Player, amount: number)
	local state = states[player]
	if state then
		state.money += amount
		player:SetAttribute("Money", state.money)
	end
end

function PlayerState.trySpend(player: Player, cost: number): boolean
	local state = states[player]
	if not state or state.money < cost then
		return false
	end
	PlayerState.addMoney(player, -cost)
	return true
end

-- Adds a brainrot to the player's index; true when it is a new find.
function PlayerState.discover(player: Player, id: string): boolean
	local state = states[player]
	if not state or state.index[id] then
		return false
	end
	state.index[id] = true
	state.indexCount += 1
	PlayerState.publish(player)
	return true
end

function PlayerState.isBoosted(): boolean
	return (workspace:GetAttribute("BoostUntil") or 0) > workspace:GetServerTimeNow()
end

function PlayerState.incomeMultiplier(player: Player): number
	local state = states[player]
	return Rules.incomeMultiplier(state.rebirths, state.indexCount, PlayerState.isBoosted())
end

-- Copies the state the HUD shows onto the player's attributes.
function PlayerState.publish(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local found = {}
	for id in state.index do
		table.insert(found, id)
	end
	player:SetAttribute("Money", state.money)
	player:SetAttribute("Income", state.income)
	player:SetAttribute("Rebirths", state.rebirths)
	player:SetAttribute("Index", table.concat(found, ","))
	player:SetAttribute("LockedUntil", state.lockedUntil)
	player:SetAttribute("LockReadyAt", state.lockReadyAt)
	player:SetAttribute("Carrying", state.carrying and state.carrying.id or "")
	for key, level in state.upgrades do
		player:SetAttribute(key, level)
	end
end

function PlayerState.notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, text, kind or "info")
end

function PlayerState.notifyAll(text: string, kind: string?)
	notifyRemote:FireAllClients(text, kind or "info")
end

return PlayerState
