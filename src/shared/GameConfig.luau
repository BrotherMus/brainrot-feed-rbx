-- GameConfig: every tunable number of Doomscroll Dash in one place, with the
-- formulas (rebirth, upgrades) and the cash formatter that server and client share.
local GameConfig = {}

function GameConfig.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths
end

function GameConfig.rebirthCost(rebirths: number): number
	return 1_000_000 * 8 ^ rebirths
end

GameConfig.STARTING_CASH = 100
GameConfig.WALK_SPEED = 22
GameConfig.START_STANDS = 4
GameConfig.MAX_STANDS = 10
GameConfig.SELL_REFUND = 0.5
GameConfig.LOCK_COOLDOWN = 40 -- seconds after a lock ends before Go Private works again
GameConfig.DROPPED_LIFETIME = 25 -- seconds a dropped brainrot waits on the floor

GameConfig.FEED = { SPEED = 8, SPAWN_EVERY = 2.4, HALF_WIDTH = 14, START_Z = -196, END_Z = 196 }
GameConfig.THUMB = { EVERY_MIN = 140, EVERY_MAX = 200, WARNING = 6, SWIPE_SECONDS = 3.2, HIT_HALF_WIDTH = 20 }
GameConfig.BOOST = { EVERY = 210, LASTS = 45, MULTIPLIER = 2 }
GameConfig.THIEF = { EVERY_MIN = 75, EVERY_MAX = 120, GRAB_SECONDS = 3.5, SPEED = 26, MIN_BRAINROTS = 2 }
GameConfig.STEAL_HOLD = 1.6 -- seconds a player holds the prompt to steal

-- level 0 is the start; cost of the next level is baseCost * growth ^ level
GameConfig.Upgrades = {
	CarrySpeed = { title = "CARRY SPEED", blurb = "Run faster while carrying", maxLevel = 5, baseCost = 200, growth = 5 },
	LockTime = { title = "LOCK TIME", blurb = "+15s of Go Private", maxLevel = 5, baseCost = 500, growth = 5 },
	Stands = { title = "MORE STANDS", blurb = "+1 stand in your base", maxLevel = 6, baseCost = 300, growth = 6 },
}
GameConfig.UpgradeOrder = { "CarrySpeed", "LockTime", "Stands" }

function GameConfig.upgradeCost(key: string, level: number): number?
	local def = GameConfig.Upgrades[key]
	if not def or level >= def.maxLevel then
		return nil
	end
	return math.floor(def.baseCost * def.growth ^ level)
end

function GameConfig.carrySpeed(level: number): number
	return 13 + 2.5 * level
end

function GameConfig.lockSeconds(level: number): number
	return 60 + 15 * level
end

function GameConfig.standCount(level: number): number
	return math.min(GameConfig.MAX_STANDS, GameConfig.START_STANDS + level)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }

-- 950 -> "$950", 12500 -> "$12.5K", 3400000 -> "$3.4M"
function GameConfig.formatCash(amount: number): string
	local value = math.max(0, math.floor(amount))
	local tier = 1
	while value >= 1000 and tier < #SUFFIXES do
		value /= 1000
		tier += 1
	end
	if tier == 1 then
		return "$" .. tostring(value)
	end
	local text = string.format(value >= 100 and "%.0f" or value >= 10 and "%.1f" or "%.2f", value)
	return "$" .. text .. SUFFIXES[tier]
end

return GameConfig
