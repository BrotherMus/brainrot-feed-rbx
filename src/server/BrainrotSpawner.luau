-- Builds a labelled brainrot from the baked part models and dresses it in its mutation's look.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.BrainrotCatalog)
local Rules = require(ReplicatedStorage.EconomyRules)

local models = ReplicatedStorage.Brainrots
local labelTemplate = ReplicatedStorage.Assets.BrainrotLabel

local Spawner = {}

-- Trending burns, Viral glows toxic green, a Legendary Meme turns to solid gold.
function Spawner.applyMutationLook(model: Model, mutation: string)
	local info = Catalog.MUTATIONS[mutation]
	local root = model.PrimaryPart
	local light = Instance.new("PointLight")
	light.Color = info.color
	light.Range = 16
	light.Brightness = 2.5
	light.Parent = root
	if mutation == "Trending" then
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 14
		fire.Parent = root
		return
	end
	local golden = mutation == "LegendaryMeme"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "Eye" and part.Name ~= "Pupil" then
			part.Color = part.Color:Lerp(info.color, golden and 0.8 or 0.45)
			part.Material = golden and Enum.Material.Metal or Enum.Material.Neon
			part.Reflectance = golden and 0.35 or 0
		end
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = golden and Color3.new(1, 1, 1) or info.color
	sparkles.Parent = root
end

-- The floating label: mutation, name, rarity, then price and money per second.
function Spawner.writeLabel(model: Model, price: number?, incomePerSecond: number)
	local entry = Catalog.byId[model:GetAttribute("Id")]
	local mutation = model:GetAttribute("Mutation")
	local label = model.PrimaryPart:FindFirstChild("BrainrotLabel")
	if not label then
		label = labelTemplate:Clone()
		label.StudsOffsetWorldSpace = Vector3.new(0, model:GetAttribute("Height") + 3.6, 0)
		label.NameText.Text = entry.name
		label.RarityText.Text = entry.rarity.name:upper()
		label.RarityText.TextColor3 = entry.rarity.color
		label.MutationText.Text = mutation and Catalog.MUTATIONS[mutation].label or ""
		label.MutationText.TextColor3 = mutation and Catalog.MUTATIONS[mutation].color or Color3.new(1, 1, 1)
		label.Parent = model.PrimaryPart
	end
	local income = "+" .. Rules.formatMoney(incomePerSecond) .. "/s"
	if price then
		label.MoneyText.Text = `<font color="#7CFF9A">{Rules.formatMoney(price)}</font>  {income}`
	else
		label.MoneyText.Text = income
	end
end

function Spawner.spawn(id: string, mutation: string?, showPrice: boolean): Model
	local model = models[id]:Clone()
	model:SetAttribute("Id", id)
	model:SetAttribute("Mutation", mutation)
	if mutation then
		Spawner.applyMutationLook(model, mutation)
	end
	Spawner.writeLabel(model, showPrice and Catalog.priceOf(id, mutation) or nil, Catalog.incomeOf(id, mutation))
	return model
end

-- Every interaction in the world is a ProximityPrompt that the client draws as a big button (BigPrompts).
function Spawner.addPrompt(part: BasePart, name: string, action: string, object: string, holdSeconds: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = holdSeconds
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 17
	prompt.Parent = part
	return prompt
end

return Spawner
