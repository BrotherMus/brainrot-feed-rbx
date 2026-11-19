-- AlgorithmBoostEvent: the timed event. Every few minutes "the algorithm" favours
-- everyone: for 45 seconds every base pays double, its trim glows gold and each screen
-- shows a countdown.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local BaseStands = require(script.Parent.BaseStands)
local IncomeTicker = require(script.Parent.IncomeTicker)
local Notify = ReplicatedStorage.Remotes.Notify

local BOOST = GameConfig.BOOST
local GOLD = Color3.fromRGB(255, 200, 40)

local AlgorithmBoostEvent = {}

local running = false

local function glowBaseTrims(gold: boolean)
	for _, base in BaseStands.all() do
		for _, part in base.model:GetChildren() do
			if part.Name == "Trim" or part.Name == "WallCap" then
				local trim = part :: BasePart
				if gold then
					trim:SetAttribute("HomeColor", trim.Color)
					trim.Color = GOLD
				else
					trim.Color = trim:GetAttribute("HomeColor") or trim.Color
				end
			end
		end
	end
end

function AlgorithmBoostEvent.payDoubleFor(seconds: number)
	if running then
		return
	end
	running = true
	IncomeTicker.setBoostMultiplier(BOOST.MULTIPLIER)
	workspace:SetAttribute("BoostUntil", workspace:GetServerTimeNow() + seconds)
	glowBaseTrims(true)
	Notify:FireAllClients("ALGORITHM BOOST! Every base pays x" .. BOOST.MULTIPLIER .. " for " .. seconds .. " seconds", "viral")
	task.wait(seconds)
	IncomeTicker.setBoostMultiplier(1)
	workspace:SetAttribute("BoostUntil", 0)
	glowBaseTrims(false)
	running = false
end

-- For the tour: asks the running game to start a boost right now.
function AlgorithmBoostEvent.boostNow()
	game:GetService("ServerStorage").TourSignals.BoostNow:Fire()
end

function AlgorithmBoostEvent.start()
	game:GetService("ServerStorage").TourSignals.BoostNow.Event:Connect(function()
		AlgorithmBoostEvent.payDoubleFor(BOOST.LASTS)
	end)
	task.spawn(function()
		while true do
			task.wait(BOOST.EVERY)
			AlgorithmBoostEvent.payDoubleFor(BOOST.LASTS)
		end
	end)
end

return AlgorithmBoostEvent
