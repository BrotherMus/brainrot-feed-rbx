-- The cast of Doomscroll Dash: 42 original brainrots on a ladder of 6 rarities, and the 3 mutations.
local Catalog = {}

Catalog.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(205, 205, 215), weight = 50 },
	{ name = "Rare", color = Color3.fromRGB(80, 170, 255), weight = 25 },
	{ name = "Epic", color = Color3.fromRGB(195, 110, 255), weight = 13 },
	{ name = "Legendary", color = Color3.fromRGB(255, 205, 60), weight = 7 },
	{ name = "Mythic", color = Color3.fromRGB(255, 80, 100), weight = 3.5 },
	{ name = "Unscrollable", color = Color3.fromRGB(90, 255, 225), weight = 1.5 },
}

-- A mutation multiplies what a brainrot earns and gives it a look of its own (BrainrotSpawner.applyMutationLook).
Catalog.MUTATIONS = {
	Trending = { label = "🔥 TRENDING x2", multiplier = 2, chance = 0.08, color = Color3.fromRGB(255, 140, 40) },
	Viral = { label = "🧪 VIRAL x5", multiplier = 5, chance = 0.03, color = Color3.fromRGB(80, 255, 130) },
	LegendaryMeme = { label = "👑 LEGENDARY MEME x10", multiplier = 10, chance = 0.01, color = Color3.fromRGB(255, 215, 70) },
}
local MUTATION_ORDER = { "LegendaryMeme", "Viral", "Trending" }

-- model name in ReplicatedStorage.Brainrots, display name, rarity tier, price, money per second
local CAST = {
	{ "PinguNotifichino", "Pingu Pingu Notifichino", 1, 25, 1 },
	{ "RanellaScrollarella", "Ranella Scrollarella", 1, 40, 2 },
	{ "QuackoHashtacko", "Quacko Hashtacko", 1, 60, 3 },
	{ "LumachinoBufferino", "Lumachino Bufferino", 1, 90, 4 },
	{ "CricetoWifetto", "Criceto Wifetto", 1, 130, 6 },
	{ "PiccioEmojiccio", "Piccio Emojiccio", 1, 180, 8 },
	{ "MuccarellaSelfiestella", "Muccarella Selfiestella", 1, 250, 11 },
	{ "GattinoAlgoritmino", "Gattino Algoritmino", 2, 500, 18 },
	{ "KoalinoCaricatorino", "Koalino Caricatorino", 2, 750, 26 },
	{ "PolpettoPodcastetto", "Polpetto Podcastetto", 2, 1100, 37 },
	{ "TartarelloRouterello", "Tartarello Routerello", 2, 1600, 52 },
	{ "LamaStreamalama", "Lama Lama Streamalama", 2, 2300, 72 },
	{ "FenicottoRinglightotto", "Fenicotto Ringlightotto", 2, 3200, 98 },
	{ "ConiglioCuffiglio", "Coniglio Cuffiglio", 2, 4500, 135 },
	{ "CapibarroSubwooferro", "Capibarro Subwooferro", 3, 8000, 220 },
	{ "SqualottoClickbaitotto", "Squalotto Clickbaitotto", 3, 12000, 320 },
	{ "GufoLivestreamufo", "Gufo Gufo Livestreamufo", 3, 18000, 460 },
	{ "GranchioCaptchio", "Granchio Captchio", 3, 26000, 650 },
	{ "BradipoLagghipo", "Bradipo Lagghipo", 3, 38000, 920 },
	{ "PandarelloPaywallello", "Pandarello Paywallello", 3, 55000, 1300 },
	{ "VolpinaVlogghina", "Volpina Vlogghina", 3, 80000, 1850 },
	{ "ElefantoneInfluencerone", "Elefantone Influencerone", 4, 150000, 3200 },
	{ "LeoneSubscribone", "Leone Subscribone", 4, 220000, 4600 },
	{ "UnicornoUnboxorno", "Unicorno Unboxorno", 4, 330000, 6600 },
	{ "DragonelloDramanello", "Dragonello Dramanello", 4, 480000, 9400 },
	{ "TigrottoTrendotto", "Tigrotto Trendotto", 4, 700000, 13500 },
	{ "GorilloneGreenscreenone", "Gorillone Greenscreenone", 4, 1000000, 19000 },
	{ "OrsacchioRagebaitacchio", "Orsacchio Ragebaitacchio", 4, 1500000, 28000 },
	{ "KrakeninoCookiebannerino", "Krakenino Cookiebannerino", 5, 3000000, 50000 },
	{ "FeniceRefreshenice", "Fenice Refreshenice", 5, 4500000, 73000 },
	{ "MammuttoMegabytto", "Mammutto Megabytto", 5, 6500000, 105000 },
	{ "NarvaloFirewallo", "Narvalo Firewallo", 5, 9500000, 150000 },
	{ "YetinoRepostino", "Yetino Repostino", 5, 14000000, 215000 },
	{ "CerberoServerero", "Cerbero Serverero", 5, 20000000, 300000 },
	{ "PegasoneParazzone", "Pegasone Paparazzone", 5, 30000000, 440000 },
	{ "ThumbosauroScrollosauro", "Thumbosauro Scrollosauro", 6, 60000000, 800000 },
	{ "BalenonaBandalargona", "Balenona Bandalargona", 6, 90000000, 1200000 },
	{ "DodoDoomscrollodo", "Dodo Doomscrollodo", 6, 140000000, 1800000 },
	{ "AxolottoAlgoritmotto", "Axolotto Algoritmotto", 6, 210000000, 2600000 },
	{ "GalloGalatticoViralico", "Gallo Galattico Viralico", 6, 320000000, 3900000 },
	{ "CapraSupremaCinquegi", "Capra Suprema Cinquegi", 6, 480000000, 5700000 },
	{ "CanguroInfinitoScrollaro", "Canguro Infinito Scrollaro", 6, 750000000, 8800000 },
}

Catalog.list = {}
Catalog.byId = {}
for order, row in ipairs(CAST) do
	local entry = { id = row[1], name = row[2], tier = row[3], rarity = Catalog.RARITIES[row[3]], price = row[4], income = row[5], order = order }
	Catalog.list[order] = entry
	Catalog.byId[entry.id] = entry
end

-- Picks what the Feed shows next: a rarity by weight, then any brainrot of that rarity.
function Catalog.rollRandomBrainrot(rng: Random)
	local total = 0
	for _, rarity in Catalog.RARITIES do
		total += rarity.weight
	end
	local pick = rng:NextNumber() * total
	local tier = 1
	for i, rarity in Catalog.RARITIES do
		pick -= rarity.weight
		if pick <= 0 then
			tier = i
			break
		end
	end
	local pool = {}
	for _, entry in Catalog.list do
		if entry.tier == tier then
			table.insert(pool, entry)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

function Catalog.rollMutation(rng: Random): string?
	local roll = rng:NextNumber()
	for _, key in MUTATION_ORDER do
		local chance = Catalog.MUTATIONS[key].chance
		if roll < chance then
			return key
		end
		roll -= chance
	end
	return nil
end

function Catalog.mutationMultiplier(mutation: string?): number
	return mutation and Catalog.MUTATIONS[mutation].multiplier or 1
end

function Catalog.priceOf(id: string, mutation: string?): number
	return math.floor(Catalog.byId[id].price * (1 + (Catalog.mutationMultiplier(mutation) - 1) * 0.5))
end

function Catalog.incomeOf(id: string, mutation: string?): number
	return Catalog.byId[id].income * Catalog.mutationMultiplier(mutation)
end

return Catalog
