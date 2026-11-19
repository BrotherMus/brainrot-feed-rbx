-- BrainrotModels: hands out the cast. Each of the 48 brainrots is a Model built from Roblox
-- parts in ServerStorage.BrainrotModels. This module clones one, dresses it in its
-- mutation's look and writes price and money per second on its name tag.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BrainrotCatalog = require(ReplicatedStorage.BrainrotCatalog)
local GameConfig = require(ReplicatedStorage.GameConfig)

local BrainrotModels = {}

-- Trending glows cyan and sparkles, Viral burns hot pink, a Legendary Meme is solid gold.
local function applyMutationLook(model: Model, mutation: string)
	local look = BrainrotCatalog.Mutations[mutation]
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Eye" and part.Name ~= "Pupil" and part.Name ~= "Sign" and part.Transparency < 1 then
			if mutation == "Trending" then
				part.Color = part.Color:Lerp(look.color, 0.45)
			elseif mutation == "Viral" then
				part.Color = part.Color:Lerp(look.color, 0.7)
				part.Material = Enum.Material.Neon
			else
				part.Color = look.color:Lerp(part.Color, 0.15)
				part.Material = Enum.Material.Foil
				part.Reflectance = 0.25
			end
		end
	end
	local body = model:FindFirstChild("Body")
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = look.color
	sparkles.Parent = body
	if mutation ~= "Trending" then
		local fire = Instance.new("Fire")
		fire.Color = look.color
		fire.SecondaryColor = Color3.new(1, 1, 1)
		fire.Size = 7
		fire.Heat = 12
		fire.Parent = body
		local light = Instance.new("PointLight")
		light.Color = look.color
		light.Range = 16
		light.Brightness = 2
		light.Parent = body
	end
	local line = model.PrimaryPart.NameTag.Mutation
	line.Text = look.label
	line.TextColor3 = look.color
end

-- Rewrites the last line of the tag: "$250   +$4/s" on the Feed, "+$8/s" once it is owned.
function BrainrotModels.setTagMoney(model: Model, price: number?, incomePerSecond: number)
	local line = model.PrimaryPart.NameTag.Price
	local income = "+" .. GameConfig.formatCash(incomePerSecond) .. "/s"
	line.Text = if price then GameConfig.formatCash(price) .. "   " .. income else income
	line.TextColor3 = if price then Color3.fromRGB(74, 222, 128) else Color3.fromRGB(250, 204, 21)
end

-- A fresh copy of brainrot `id`, standing on the origin and facing -Z, priced for the Feed.
function BrainrotModels.cloneWithMutation(id: string, mutation: string?): Model
	local entry = BrainrotCatalog.get(id) :: BrainrotCatalog.Entry
	local model = ServerStorage.BrainrotModels[entry.name]:Clone()
	if mutation then
		applyMutationLook(model, mutation)
	end
	BrainrotModels.setTagMoney(model, BrainrotCatalog.priceOf(id, mutation), BrainrotCatalog.incomeOf(id, mutation))
	model:SetAttribute("Mutation", mutation)
	return model
end

return BrainrotModels
