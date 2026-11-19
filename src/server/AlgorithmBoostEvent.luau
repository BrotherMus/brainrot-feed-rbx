-- Algorithm Boost: a timed event during which every base pays double.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.EconomyRules)
local PlayerState = require(script.Parent.PlayerState)

local Boost = {}

-- PlayerState.isBoosted reads BoostUntil for the income multiplier; the HUD counts it down.
function Boost.startDoubleMoneyEvent()
	workspace:SetAttribute("BoostUntil", workspace:GetServerTimeNow() + Rules.BOOST_SECONDS)
	PlayerState.notifyAll("📈 ALGORITHM BOOST! Every base pays x2 for " .. Rules.BOOST_SECONDS .. "s!", "good")
end

function Boost.start()
	task.spawn(function()
		while task.wait(Rules.BOOST_INTERVAL) do
			Boost.startDoubleMoneyEvent()
		end
	end)
end

return Boost
