-- BrainrotCatalog: the cast of Doomscroll Dash. 48 original brainrots (absurd animal +
-- phone-world object) on a ladder of 6 rarities, the 3 mutations, and the dice that pick
-- what scrolls down the Feed next. Pure data and maths: it creates no instances.
local BrainrotCatalog = {}

export type Entry = {
	id: string, name: string, order: number, rarity: number, rarityName: string, color: Color3,
	price: number, income: number, body: string, prop: string, main: Color3, accent: Color3,
	traits: { [string]: string },
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

-- name, body plan, prop, main colour, accent colour, traits. Eight per rarity, cheapest first.
local ROWS = {
	-- Common
	{ "Scrollino Snailino", "slug", "phone", "a3e635", "3b82f6", "stalks=1" },
	{ "Likey Lizardo", "quad", "heart", "4ade80", "ef4444", "tail=long snout=short" },
	{ "Buffero Hamstero", "blob", "ring", "f6b26b", "fff7ed", "ears=round belly=1" },
	{ "Pingu Pingaling", "bird", "bell", "1f2937", "fbbf24", "snout=beak belly=1" },
	{ "Selfie Shrimpo", "fish", "camera", "fb7185", "fecdd3", "stalks=1 tail=fan whiskers=1" },
	{ "Lagga Froggo", "blob", "bars", "22c55e", "bbf7d0", "stalks=1 belly=1" },
	{ "Emoji Molo", "biped", "bubble::D", "8b5e3c", "facc15", "snout=long" },
	{ "Wifi Wormi", "slug", "wifi", "f9a8d4", "38bdf8", "stripes=1" },
	-- Uncommon
	{ "Hashtaggo Doggo", "quad", "sign:#", "d4a373", "0ea5e9", "ears=droopy tail=stub snout=short" },
	{ "Charger Chameleono", "quad", "cable", "34d399", "f59e0b", "horn=one snout=short spikes=1" },
	{ "Captcha Capybarra", "quad", "sign:I AM NOT A ROBOT", "b08968", "22c55e", "ears=round snout=short size=1.1" },
	{ "Podcasto Pandaro", "biped", "mic", "f8fafc", "111827", "ears=round mask=1 belly=1" },
	{ "Filtero Flamingo", "bird", "shades", "fb7185", "111827", "neck=2 snout=beak legs=long" },
	{ "Bluetootho Beavero", "biped", "bubble:BT", "92400e", "3b82f6", "ears=round horn=tusks tail=fan" },
	{ "Spammy Salmoni", "fish", "envelope", "fda4af", "e5e7eb", "belly=1" },
	{ "Cookie Crabbo", "blob", "cookie", "ef4444", "d6a15b", "stalks=1 claws=1" },
	-- Rare
	{ "Streamer Stingrayo", "fish", "headset", "64748b", "a855f7", "wings=1 tail=long" },
	{ "Vloggo Hippo", "quad", "camera", "a78bfa", "111827", "ears=round snout=long size=1.2" },
	{ "Memelord Mooso", "quad", "crown", "7c4a2d", "facc15", "horn=antlers snout=long ears=droopy" },
	{ "Notifico Narwhalo", "fish", "bubble:99+", "93c5fd", "ef4444", "horn=one belly=1" },
	{ "Algoritmo Alpaco", "quad", "sign:FOR YOU", "fef3c7", "10b981", "neck=2 ears=pointy fluff=1" },
	{ "Influenco Iguano", "quad", "ring", "84cc16", "fde68a", "spikes=1 tail=long snout=short" },
	{ "Glitchy Giraffo", "quad", "sign:ERR0R", "facc15", "22d3ee", "neck=4 horn=two spots=1 ears=pointy" },
	{ "Popup Porcupino", "blob", "sign:AD  X", "78716c", "f43f5e", "spikes=1 snout=short ears=round" },
	-- Epic
	{ "Clickbaito Catfisho", "fish", "sign:YOU WONT BELIEVE", "6b7280", "ef4444", "whiskers=1 belly=1 size=1.15" },
	{ "Doomscrollo Dolphino", "fish", "phone", "38bdf8", "111827", "snout=long belly=1 size=1.15" },
	{ "Ratio Raccoono", "biped", "bars", "9ca3af", "111827", "ears=pointy mask=1 tail=long stripes=1" },
	{ "Livestreamo Llamo", "quad", "sign:LIVE", "f5e6c8", "ef4444", "neck=3 ears=pointy fluff=1" },
	{ "Firewallo Walruso", "blob", "sign:FIREWALL", "8d6e63", "f97316", "horn=tusks whiskers=1 snout=short size=1.2" },
	{ "Subwoofer Wolfo", "quad", "speaker", "475569", "22d3ee", "ears=pointy tail=long snout=long" },
	{ "Thumbnailo Tapiro", "quad", "sign:> PLAY", "374151", "ef4444", "snout=trunk ears=round belly=1" },
	{ "Darkmode Batto", "bird", "bubble:Zz", "312e81", "fde047", "wings=1 ears=pointy" },
	-- Legendary
	{ "Viralissimo Vulturo", "bird", "sign:GOING VIRAL", "44403c", "f43f5e", "neck=2 snout=beak wings=1 fluff=1 size=1.2" },
	{ "Algorhythmo Octobeato", "blob", "headset", "c084fc", "22d3ee", "tentacles=1 size=1.2" },
	{ "Gigabyto Mammotho", "quad", "sign:1000 GB", "8b5a2b", "22c55e", "snout=trunk horn=tusks fluff=1 ears=round size=1.35" },
	{ "Trendsetta Tigretta", "quad", "shades", "fb923c", "111827", "stripes=1 ears=round tail=long snout=short size=1.2" },
	{ "Cloudstorago Storko", "bird", "cloud", "f8fafc", "38bdf8", "neck=2 snout=beak legs=long size=1.2" },
	{ "Overclocko Ostricho", "bird", "bubble:999%", "57534e", "f59e0b", "neck=3 snout=beak legs=long fluff=1 size=1.2" },
	{ "Megapixelo Peacocko", "bird", "camera", "0d9488", "3b82f6", "tail=fan horn=two snout=beak size=1.2" },
	{ "Fiberoptico Foxo", "quad", "cable", "f97316", "67e8f9", "ears=pointy snout=long belly=1 size=1.2" },
	-- Mythic
	{ "Supremo Scrollosaurus", "biped", "phone", "16a34a", "a3e635", "tail=long spikes=1 snout=long size=1.6" },
	{ "El Gran Feedalotl", "quad", "crown", "f9a8d4", "facc15", "gills=1 tail=long belly=1 size=1.5" },
	{ "Omega Wifiwhalo", "fish", "wifi", "1d4ed8", "e0f2fe", "belly=1 size=1.8" },
	{ "Doomscrollius Maximus", "biped", "crown", "a8a29e", "eab308", "mask=1 ears=round belly=1 size=1.6" },
	{ "Infinito Loopalope", "quad", "ring", "fde68a", "8b5cf6", "horn=antlers ears=long tail=stub size=1.5" },
	{ "Lord Laggington Krakeno", "blob", "sign:LOADING...", "7f1d1d", "fca5a5", "tentacles=1 horn=two size=1.7" },
	{ "Quantum Quokkabyte", "biped", "cloud", "d6a370", "22d3ee", "ears=round belly=1 tail=stub size=1.5" },
	{ "The Final Notificorn", "quad", "bell", "ffffff", "ef4444", "horn=one mane=1 tail=long ears=pointy size=1.6" },
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

for order, row in ROWS do
	local rarityIndex = math.ceil(order / PER_RARITY)
	local rarity = BrainrotCatalog.Rarities[rarityIndex]
	local step = (order - 1) % PER_RARITY
	local price = roundToTwoDigits(rarity.basePrice * 1.45 ^ step)
	local traits = {}
	for key, value in string.gmatch(row[6], "(%w+)=([%w%.]+)") do
		traits[key] = value
	end
	local entry: Entry = {
		id = string.gsub(string.lower(row[1]), "%A+", "_"),
		name = row[1],
		order = order,
		rarity = rarityIndex,
		rarityName = rarity.name,
		color = rarity.color,
		price = price,
		income = math.max(1, roundToTwoDigits(price / rarity.payback)),
		body = row[2],
		prop = row[3],
		main = Color3.fromHex(row[4]),
		accent = Color3.fromHex(row[5]),
		traits = traits,
	}
	cast[order] = entry
	byId[entry.id] = entry
end

return BrainrotCatalog
