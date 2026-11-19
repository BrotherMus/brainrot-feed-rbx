-- PlayerState: the one place a player's progress lives. Cash, rebirths, upgrade levels,
-- the index of brainrots found and what stands on which stand. The client only sees the
-- attributes publish() copies onto the Player. Saved to a DataStore in the live game.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)

local PlayerState = {}

export type Placed = { id: string, mutation: string? }
export type Profile = {
	cash: number,
	rebirths: number,
	pending: number, -- income waiting on the collect pad
	upgrades: { [string]: number },
	index: { [string]: boolean },
	stands: { [string]: Placed }, -- keyed by the stand's number as a string
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function newProfile(): Profile
	return {
		cash = GameConfig.STARTING_CASH,
		rebirths = 0,
		pending = 0,
		upgrades = { CarrySpeed = 0, LockTime = 0, Stands = 0 },
		index = {},
		stands = {},
	}
end

-- Loads the saved profile, or starts a new one when there is none or no DataStore (Studio).
function PlayerState.loadProfile(player: Player): Profile
	local profile = newProfile()
	local ok, saved = pcall(function()
		store = store or DataStoreService:GetDataStore("DoomscrollDashV1")
		return (store :: DataStore):GetAsync("player_" .. player.UserId)
	end)
	if ok and type(saved) == "table" then
		for key, value in saved do
			if type(value) == type(profile[key]) then
				profile[key] = value
			end
		end
	end
	profiles[player] = profile
	PlayerState.publish(player)
	return profile
end

function PlayerState.saveProfile(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	pcall(function()
		(store :: DataStore):SetAsync("player_" .. player.UserId, profile)
	end)
end

function PlayerState.get(player: Player): Profile?
	return profiles[player]
end

function PlayerState.release(player: Player)
	PlayerState.saveProfile(player)
	profiles[player] = nil
end

function PlayerState.addCash(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.cash += amount
		PlayerState.publish(player)
	end
end

-- Takes `cost` from the player's cash; false (and nothing taken) when they cannot afford it.
function PlayerState.trySpend(player: Player, cost: number): boolean
	local profile = profiles[player]
	if not profile or profile.cash < cost then
		return false
	end
	profile.cash -= cost
	PlayerState.publish(player)
	return true
end

function PlayerState.markDiscovered(player: Player, brainrotId: string)
	local profile = profiles[player]
	if profile and not profile.index[brainrotId] then
		profile.index[brainrotId] = true
		PlayerState.publish(player)
	end
end

-- Copies what the HUD shows onto Player attributes: the only state the client is sent.
function PlayerState.publish(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local found = {}
	for id in profile.index do
		table.insert(found, id)
	end
	player:SetAttribute("Cash", profile.cash)
	player:SetAttribute("Pending", profile.pending)
	player:SetAttribute("Rebirths", profile.rebirths)
	player:SetAttribute("Index", table.concat(found, ","))
	for key, level in profile.upgrades do
		player:SetAttribute(key .. "Level", level)
	end
end

return PlayerState
