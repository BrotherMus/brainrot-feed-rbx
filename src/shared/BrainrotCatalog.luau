-- BrainrotCatalog: the cast of Doomscroll Dash. 48 original brainrots (absurd animal +
-- phone-world object) on a ladder of 6 rarities, the 3 mutations, and the dice that pick
-- what scrolls down the Feed next. Pure data and maths: the models themselves are built
-- from parts in ServerStorage.BrainrotModels, one per name below.
local BrainrotCatalog = {}

export type Entry = {
	id: string, name: string, order: number, rarity: number, rarityName: string,
	color: Color3, price: number, income: number,
}

BrainrotCatalog.Rarities = {
	{ name = "Common", color = Color3.fromRGB(203, 213, 225), weight = 54, basePrice = 25, payback = 12 },
	{ name = "Uncommon", color = Color3.fromRGB(74, 222, 128), weight = 25, basePrice = 600, payback = 28 },
	{ name = "Rare", color = Color3.fromRGB(56, 189, 248), weight = 12, basePrice = 12_000, payback = 55 },
	{ name = "Epic", color = Color3.fromRGB(192, 132, 252), weight = 6, basePrice = 250_000, payback = 90 },
	{ name = "Legendary", color = Color3.fromRGB(250, 204, 21), weight = 2.4, basePrice = 5_000_000, payback = 130 },
	{ name = "Mythic", color = Color3.fromRGB(251, 73, 96), weight = 0.6, basePrice = 100_000_000, payback = 180 },
}

BrainrotCatalog.Mutations = {
	Trending = { label = "TRENDING x2", incomeMult = 2, priceMult = 1.5, chance = 0.06, color = Color3.fromRGB(34, 211, 238) },
	Viral = { label = "VIRAL x5", incomeMult = 5, priceMult = 3, chance = 0.02, color = Color3.fromRGB(255, 64, 160) },
	LegendaryMeme = { label = "LEGENDARY MEME x10", incomeMult = 10, priceMult = 5, chance = 0.005, color = Color3.fromRGB(255, 200, 40) },
}
BrainrotCatalog.MutationOrder = { "LegendaryMeme", "Viral", "Trending" } -- rarest is rolled first

-- Eight per rarity, cheapest first.
local NAMES = {
	-- Common
	"Scrollino Snailino", "Likey Lizardo", "Buffero Hamstero", "Pingu Pingaling",
	"Selfie Shrimpo", "Lagga Froggo", "Emoji Molo", "Wifi Wormi",
	-- Uncommon
	"Hashtaggo Doggo", "Charger Chameleono", "Captcha Capybarra", "Podcasto Pandaro",
	"Filtero Flamingo", "Bluetootho Beavero", "Spammy Salmoni", "Cookie Crabbo",
	-- Rare
	"Streamer Stingrayo", "Vloggo Hippo", "Memelord Mooso", "Notifico Narwhalo",
	"Algoritmo Alpaco", "Influenco Iguano", "Glitchy Giraffo", "Popup Porcupino",
	-- Epic
	"Clickbaito Catfisho", "Doomscrollo Dolphino", "Ratio Raccoono", "Livestreamo Llamo",
	"Firewallo Walruso", "Subwoofer Wolfo", "Thumbnailo Tapiro", "Darkmode Batto",
	-- Legendary
	"Viralissimo Vulturo", "Algorhythmo Octobeato", "Gigabyto Mammotho", "Trendsetta Tigretta",
	"Cloudstorago Storko", "Overclocko Ostricho", "Megapixelo Peacocko", "Fiberoptico Foxo",
	-- Mythic
	"Supremo Scrollosaurus", "El Gran Feedalotl", "Omega Wifiwhalo", "Doomscrollius Maximus",
	"Infinito Loopalope", "Lord Laggington Krakeno", "Quantum Quokkabyte", "The Final Notificorn",
}

local PER_RARITY = 8
local cast: { Entry } = {}
local byId: { [string]: Entry } = {}

function BrainrotCatalog.getAll48(): { Entry }
	return cast
end

function BrainrotCatalog.get(id: string): Entry?
	return byId[id]
end

-- 337.4 -> 340, 12431 -> 12000: prices a player can read at a glance
local function roundToTwoDigits(value: number): number
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(value)) - 1)
	return math.floor(value / magnitude + 0.5) * magnitude
end

function BrainrotCatalog.priceOf(id: string, mutation: string?): number
	local mult = if mutation then BrainrotCatalog.Mutations[mutation].priceMult else 1
	return math.floor(byId[id].price * mult)
end

-- money per second of one brainrot on a stand, before rebirth and Algorithm Boost
function BrainrotCatalog.incomeOf(id: string, mutation: string?): number
	local mult = if mutation then BrainrotCatalog.Mutations[mutation].incomeMult else 1
	return byId[id].income * mult
end

function BrainrotCatalog.rollMutation(rng: Random, luck: number): string?
	for _, key in BrainrotCatalog.MutationOrder do
		if rng:NextNumber() < BrainrotCatalog.Mutations[key].chance * luck then
			return key
		end
	end
	return nil
end

-- Picks the next post of the Feed: a rarity by weight (luck tilts it toward the rare end),
-- then one of that rarity's eight, then maybe a mutation.
function BrainrotCatalog.rollForFeed(rng: Random, luck: number): (string, string?)
	local total = 0
	local weights = {}
	for index, rarity in BrainrotCatalog.Rarities do
		weights[index] = rarity.weight * luck ^ (index - 1)
		total += weights[index]
	end
	local pick = rng:NextNumber() * total
	local rarityIndex = 1
	for index, weight in weights do
		pick -= weight
		if pick <= 0 then
			rarityIndex = index
			break
		end
	end
	local entry = cast[(rarityIndex - 1) * PER_RARITY + rng:NextInteger(1, PER_RARITY)]
	return entry.id, BrainrotCatalog.rollMutation(rng, luck)
end

for order, name in NAMES do
	local rarityIndex = math.ceil(order / PER_RARITY)
	local rarity = BrainrotCatalog.Rarities[rarityIndex]
	local price = roundToTwoDigits(rarity.basePrice * 1.45 ^ ((order - 1) % PER_RARITY))
	local entry: Entry = {
		id = string.gsub(string.lower(name), "%A+", "_"),
		name = name,
		order = order,
		rarity = rarityIndex,
		rarityName = rarity.name,
		color = rarity.color,
		price = price,
		income = math.max(1, roundToTwoDigits(price / rarity.payback)),
	}
	cast[order] = entry
	byId[entry.id] = entry
end

return BrainrotCatalog
