-- WorldBases: the eight bases of the phone world and their stands. Hands a base to each player, puts the
-- brainrot they carry on a stand, sells one back, rebuilds a saved base when its owner
-- returns, and opens more stands as the MORE STANDS upgrade is bought.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local GameConfig = require(ReplicatedStorage.GameConfig)
local BrainrotModels = require(script.Parent.BrainrotModels)
local CarryBrainrot = require(script.Parent.CarryBrainrot)
local PlayerState = require(script.Parent.PlayerState)
local Notify = ReplicatedStorage.Remotes.Notify

local BaseStands = {}

export type StandSlot = { model: Model, brainrot: Model?, id: string?, mutation: string? }
export type Base = {
	index: number,
	model: Model,
	side: number, -- -1 left of the Feed, 1 right of it
	owner: Player?,
	stands: { StandSlot },
	lockedUntil: number,
	lockReadyAt: number,
}

local bases: { Base } = {}

-- StealBrainrot sets this: what happens when someone who is not the owner uses a stand.
BaseStands.onIntruderPrompt = nil :: ((Player, Base, number) -> ())?

local function openStandCount(owner: Player?): number
	local profile = owner and PlayerState.get(owner)
	return GameConfig.standCount(if profile then profile.upgrades.Stands else 0)
end

-- Puts brainrot `id` on stand `standIndex`, facing the Feed, and records it for its owner.
function BaseStands.setStandBrainrot(base: Base, standIndex: number, id: string, mutation: string?)
	local slot = base.stands[standIndex]
	local pedestal = slot.model.PrimaryPart :: BasePart
	local top = pedestal.Position + Vector3.new(0, 1.1, 0)
	local brainrot = BrainrotModels.cloneWithMutation(id, mutation)
	BrainrotModels.setTagMoney(brainrot, nil, BrainrotCatalog.incomeOf(id, mutation))
	brainrot:PivotTo(CFrame.lookAt(top, top + Vector3.new(-base.side, 0, 0)))
	brainrot.Parent = slot.model
	slot.brainrot, slot.id, slot.mutation = brainrot, id, mutation
	local prompt = pedestal:FindFirstChild("StandPrompt") :: ProximityPrompt
	prompt.ActionText = "Steal"
	prompt.ObjectText = brainrot.Name
	prompt.HoldDuration = GameConfig.STEAL_HOLD
	local emptyTag = pedestal:FindFirstChild("StandTag") :: BillboardGui
	emptyTag.Enabled = false
	local profile = base.owner and PlayerState.get(base.owner)
	if profile then
		profile.stands[tostring(standIndex)] = { id = id, mutation = mutation }
	end
end

-- Empties a stand and returns what stood on it. `keepSaved` leaves the owner's save alone.
function BaseStands.clearStand(base: Base, standIndex: number, keepSaved: boolean?): (string?, string?)
	local slot = base.stands[standIndex]
	local id, mutation = slot.id, slot.mutation
	if slot.brainrot then
		slot.brainrot:Destroy()
	end
	slot.brainrot, slot.id, slot.mutation = nil, nil, nil
	local pedestal = slot.model.PrimaryPart :: BasePart
	local prompt = pedestal:FindFirstChild("StandPrompt") :: ProximityPrompt
	prompt.ActionText = "Place"
	prompt.ObjectText = "Empty stand"
	prompt.HoldDuration = 0
	local emptyTag = pedestal:FindFirstChild("StandTag") :: BillboardGui
	emptyTag.Enabled = true
	local profile = base.owner and PlayerState.get(base.owner)
	if profile and not keepSaved then
		profile.stands[tostring(standIndex)] = nil
	end
	return id, mutation
end

function BaseStands.placeCarriedOnStand(player: Player, base: Base, standIndex: number): boolean
	if base.stands[standIndex].id or standIndex > openStandCount(player) then
		return false
	end
	local info = CarryBrainrot.takeCarried(player)
	if not info then
		return false
	end
	BaseStands.setStandBrainrot(base, standIndex, info.id, info.mutation)
	local income = GameConfig.formatCash(BrainrotCatalog.incomeOf(info.id, info.mutation))
	Notify:FireClient(player, (BrainrotCatalog.get(info.id) :: any).name .. " now earns " .. income .. " a second!", "good")
	return true
end

local function sellFromStand(player: Player, base: Base, standIndex: number)
	local id, mutation = BaseStands.clearStand(base, standIndex)
	if id then
		local refund = math.floor(BrainrotCatalog.priceOf(id, mutation) * GameConfig.SELL_REFUND)
		PlayerState.addCash(player, refund)
		Notify:FireClient(player, "Sold for " .. GameConfig.formatCash(refund), "info")
	end
end

local function onStandPrompt(player: Player, base: Base, standIndex: number)
	if base.owner ~= player then
		if base.owner and BaseStands.onIntruderPrompt then
			BaseStands.onIntruderPrompt(player, base, standIndex)
		end
	elseif not base.stands[standIndex].id then
		if not BaseStands.placeCarriedOnStand(player, base, standIndex) then
			Notify:FireClient(player, "Buy a brainrot from THE FEED first", "info")
		end
	elseif CarryBrainrot.get(player) then
		Notify:FireClient(player, "That stand is taken: use an empty one", "info")
	else
		sellFromStand(player, base, standIndex)
	end
end

-- Shows which stands are open: the first four, plus one for each MORE STANDS level.
function BaseStands.refreshStands(base: Base)
	local open = openStandCount(base.owner)
	for standIndex, slot in base.stands do
		local locked = standIndex > open
		local pedestal = slot.model.PrimaryPart :: BasePart
		local glow = slot.model:FindFirstChild("Glow") :: BasePart
		local prompt = pedestal:FindFirstChild("StandPrompt") :: ProximityPrompt
		local tagText = (pedestal:FindFirstChild("StandTag") :: BillboardGui):FindFirstChild("Text") :: TextLabel
		pedestal.Transparency = if locked then 0.8 else 0
		glow.Transparency = if locked then 0.8 else 0
		prompt.Enabled = base.owner ~= nil and not locked
		tagText.Text = if locked then "LOCKED" else "EMPTY"
	end
end

function BaseStands.setSignLine(base: Base, labelName: string, text: string, color: Color3?)
	local profile = (base.model:FindFirstChild("Sign") :: BasePart):FindFirstChild("Profile") :: SurfaceGui
	local label = profile:FindFirstChild(labelName) :: TextLabel
	label.Text = text
	if color then
		label.TextColor3 = color
	end
end

-- Gives the player the first free base and rebuilds what their save says stood there.
function BaseStands.claimFor(player: Player): Base?
	local profile = PlayerState.get(player)
	for _, base in bases do
		if not base.owner and profile then
			base.owner = player
			player:SetAttribute("BaseIndex", base.index)
			BaseStands.setSignLine(base, "OwnerLabel", "@" .. player.DisplayName)
			for key, placed in profile.stands do
				local standIndex = tonumber(key)
				if standIndex and base.stands[standIndex] and BrainrotCatalog.get(placed.id) then
					BaseStands.setStandBrainrot(base, standIndex, placed.id, placed.mutation)
				end
			end
			BaseStands.refreshStands(base)
			return base
		end
	end
	return nil
end

-- The owner left: clear the base for the next player (their save keeps their brainrots).
function BaseStands.release(player: Player)
	local base = BaseStands.baseOf(player)
	if base then
		for standIndex in base.stands do
			BaseStands.clearStand(base, standIndex, true)
		end
		base.owner = nil
		base.lockedUntil, base.lockReadyAt = 0, 0
		BaseStands.setSignLine(base, "OwnerLabel", "FOR RENT")
		BaseStands.setSignLine(base, "IncomeLabel", "+$0/s")
		BaseStands.refreshStands(base)
	end
end

-- Go Viral wipes the base: every stand emptied, in the world and in the save.
function BaseStands.clearAllFor(player: Player)
	local base = BaseStands.baseOf(player)
	if base then
		for standIndex in base.stands do
			BaseStands.clearStand(base, standIndex)
		end
		BaseStands.refreshStands(base)
	end
end

function BaseStands.baseOf(player: Player): Base?
	for _, base in bases do
		if base.owner == player then
			return base
		end
	end
	return nil
end

function BaseStands.all(): { Base }
	return bases
end

-- Money per second of everything on the base's stands, before rebirth and boost multipliers.
function BaseStands.incomePerSecond(base: Base): number
	local total = 0
	for _, slot in base.stands do
		if slot.id then
			total += BrainrotCatalog.incomeOf(slot.id, slot.mutation)
		end
	end
	return total
end

function BaseStands.occupiedStands(base: Base): { number }
	local occupied = {}
	for standIndex, slot in base.stands do
		if slot.id then
			table.insert(occupied, standIndex)
		end
	end
	return occupied
end

function BaseStands.firstFreeStand(base: Base): number?
	for standIndex = 1, openStandCount(base.owner) do
		if not base.stands[standIndex].id then
			return standIndex
		end
	end
	return nil
end

function BaseStands.isInside(base: Base, position: Vector3): boolean
	local floor = base.model.PrimaryPart :: BasePart
	local offset = floor.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) < floor.Size.X / 2 and math.abs(offset.Z) < floor.Size.Z / 2
end

function BaseStands.spawnCFrame(base: Base): CFrame
	local spawn = base.model:FindFirstChild("Spawn") :: BasePart
	return CFrame.lookAt(spawn.Position + Vector3.new(0, 4, 0), spawn.Position + Vector3.new(-base.side * 30, 4, 0))
end

-- For the tour: opens every stand of each owned base and fills the free ones with a
-- showcase (every rarity, each mutation), so a reviewer can reach the late-game screens.
local SHOWCASE = {
	{ "pingu_pingaling" }, { "captcha_capybarra", "Trending" }, { "memelord_mooso" }, { "subwoofer_wolfo" },
	{ "gigabyto_mammotho", "LegendaryMeme" }, { "cookie_crabbo" }, { "glitchy_giraffo" },
	{ "doomscrollo_dolphino", "Viral" }, { "el_gran_feedalotl" }, { "the_final_notificorn" },
}

-- The tour's one entry point: "Showcase" fills the bases, "SwipeNow" brings the Giant
-- Thumb, "RaidNow" sends the Scam Bot, "BoostNow" starts an Algorithm Boost. It fires a
-- signal the running game listens to, so it works from the command bar too.
function BaseStands.tour(signalName: string)
	game:GetService("ServerStorage").TourSignals[signalName]:Fire()
end

local function fillWithShowcase()
	for _, base in bases do
		local profile = base.owner and PlayerState.get(base.owner)
		if base.owner and profile then
			profile.upgrades.Stands = GameConfig.Upgrades.Stands.maxLevel
			profile.cash += 50_000
			for standIndex, pick in SHOWCASE do
				if not base.stands[standIndex].id then
					BaseStands.setStandBrainrot(base, standIndex, pick[1], pick[2])
					PlayerState.markDiscovered(base.owner, pick[1])
				end
			end
			PlayerState.publish(base.owner)
			BaseStands.refreshStands(base)
		end
	end
end

-- Reads the baked bases out of the workspace and wires every stand's prompt.
function BaseStands.init()
	game:GetService("ServerStorage").TourSignals.Showcase.Event:Connect(fillWithShowcase)
	for index = 1, 8 do
		local model = workspace.Bases:FindFirstChild("Base" .. index) :: Model
		local base: Base = { index = index, model = model, side = model:GetAttribute("Side"), owner = nil, stands = {}, lockedUntil = 0, lockReadyAt = 0 }
		for standIndex = 1, GameConfig.MAX_STANDS do
			local stand = (model:FindFirstChild("Stands") :: Folder):FindFirstChild("Stand" .. standIndex) :: Model
			base.stands[standIndex] = { model = stand }
			local prompt = (stand.PrimaryPart :: BasePart):FindFirstChild("StandPrompt") :: ProximityPrompt
			prompt.Triggered:Connect(function(player)
				onStandPrompt(player, base, standIndex)
			end)
		end
		bases[index] = base
		BaseStands.refreshStands(base)
	end
end

return BaseStands
