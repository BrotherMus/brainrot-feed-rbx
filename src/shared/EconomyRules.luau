-- The numbers of the economy: upgrades, the Go Viral rebirth, event timers and money formatting.
local Rules = {}

Rules.START_MONEY = 50
Rules.WALK_SPEED = 20
Rules.SELL_REFUND = 0.5
Rules.LOCK_COOLDOWN = 20
Rules.THUMB_INTERVAL = 150
Rules.THUMB_WARNING = 6
Rules.BOOST_INTERVAL = 240
Rules.BOOST_SECONDS = 45
Rules.THIEF_INTERVAL = 75

Rules.UPGRADES = {
	CarrySpeed = { title = "Carry Speed", maxLevel = 5, baseCost = 200, growth = 4 },
	LockTime = { title = "Lock Time", maxLevel = 5, baseCost = 500, growth = 4 },
	Stands = { title = "More Stands", maxLevel = 6, baseCost = 1000, growth = 5 },
}

function Rules.upgradeCost(key: string, level: number): number
	local upgrade = Rules.UPGRADES[key]
	return upgrade.baseCost * upgrade.growth ^ level
end

function Rules.carrySpeed(level: number): number
	return 14 + 2 * level
end

function Rules.lockSeconds(level: number): number
	return 60 + 15 * level
end

function Rules.standCount(level: number): number
	return 4 + level
end

-- Go Viral: reset for a permanent money multiplier.
function Rules.rebirthCost(rebirths: number): number
	return 500000 * 5 ^ rebirths
end

function Rules.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths
end

-- Every brainrot found in the index adds 1%; an Algorithm Boost doubles it all.
function Rules.incomeMultiplier(rebirths: number, indexCount: number, boosted: boolean): number
	return Rules.rebirthMultiplier(rebirths) * (1 + 0.01 * indexCount) * (boosted and 2 or 1)
end

local SUFFIXES = { "", "K", "M", "B", "T" }

function Rules.formatMoney(amount: number): string
	local whole = math.floor(amount)
	local value, tier = whole, 1
	while value >= 1000 and tier < #SUFFIXES do
		value /= 1000
		tier += 1
	end
	if tier == 1 then
		return "$" .. whole
	end
	local text = string.format("$%.2f", value):gsub("%.?0+$", "")
	return text .. SUFFIXES[tier]
end

return Rules
