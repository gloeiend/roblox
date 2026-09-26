--!strict
-- Central tuning for Sky Climb. Everything gameplay-related lives here so the
-- game can be rebalanced without touching logic.

export type UpgradeDef = {
	id: string,
	name: string,
	description: string,
	baseCost: number,
	costGrowth: number,
	maxLevel: number,
	perLevel: number,
	base: number,
	unit: string,
}

export type TrailDef = {
	id: string,
	name: string,
	cost: number,
	colors: { Color3 },
}

export type ZoneDef = {
	name: string,
	platform: Color3,
	accent: Color3,
	material: Enum.Material,
}

local Config = {}

Config.DATASTORE_NAME = "SkyClimb_v1"
Config.AUTOSAVE_INTERVAL = 120

-- Course layout
Config.SEED = 20260926
Config.STAGE_COUNT = 40
Config.STAGES_PER_ZONE = 10
Config.COURSE_ORIGIN = Vector3.new(0, 100, 0)
Config.VOID_DROP = 25 -- studs below the current section before we rescue a falling player

-- Economy
Config.COIN_VALUE = 1
Config.COIN_RESPAWN = 40 -- seconds before a collected coin reappears for that player
Config.CHECKPOINT_REWARD_BASE = 5
Config.FINISH_REWARD = 250
Config.REBIRTH_MULTIPLIER = 0.5 -- each rebirth adds +50% to all coin gains

Config.Zones = {
	{
		name = "Meadow",
		platform = Color3.fromRGB(106, 190, 92),
		accent = Color3.fromRGB(255, 214, 102),
		material = Enum.Material.Grass,
	},
	{
		name = "Dunes",
		platform = Color3.fromRGB(226, 190, 128),
		accent = Color3.fromRGB(214, 110, 60),
		material = Enum.Material.Sandstone,
	},
	{
		name = "Frostpeak",
		platform = Color3.fromRGB(190, 230, 255),
		accent = Color3.fromRGB(120, 170, 255),
		material = Enum.Material.Ice,
	},
	{
		name = "Emberforge",
		platform = Color3.fromRGB(70, 60, 64),
		accent = Color3.fromRGB(255, 120, 40),
		material = Enum.Material.Basalt,
	},
} :: { ZoneDef }

Config.Upgrades = {
	{
		id = "Speed",
		name = "Swift Shoes",
		description = "Run faster.",
		baseCost = 25,
		costGrowth = 1.55,
		maxLevel = 10,
		perLevel = 2,
		base = 16,
		unit = "speed",
	},
	{
		id = "Jump",
		name = "Spring Boots",
		description = "Jump higher.",
		baseCost = 35,
		costGrowth = 1.6,
		maxLevel = 8,
		perLevel = 3,
		base = 50,
		unit = "power",
	},
	{
		id = "Magnet",
		name = "Coin Magnet",
		description = "Grab coins from farther away.",
		baseCost = 50,
		costGrowth = 1.7,
		maxLevel = 8,
		perLevel = 3,
		base = 4,
		unit = "studs",
	},
} :: { UpgradeDef }

Config.Trails = {
	{ id = "Sunset", name = "Sunset", cost = 150, colors = { Color3.fromRGB(255, 94, 98), Color3.fromRGB(255, 195, 113) } },
	{ id = "Mint", name = "Mint", cost = 300, colors = { Color3.fromRGB(80, 255, 180), Color3.fromRGB(60, 160, 255) } },
	{ id = "Ember", name = "Ember", cost = 600, colors = { Color3.fromRGB(255, 60, 0), Color3.fromRGB(255, 220, 0) } },
	{ id = "Void", name = "Void", cost = 1200, colors = { Color3.fromRGB(120, 0, 255), Color3.fromRGB(20, 0, 40) } },
	{
		id = "Rainbow",
		name = "Rainbow",
		cost = 3000,
		colors = {
			Color3.fromRGB(255, 0, 0),
			Color3.fromRGB(255, 200, 0),
			Color3.fromRGB(0, 255, 80),
			Color3.fromRGB(0, 160, 255),
			Color3.fromRGB(200, 0, 255),
		},
	},
} :: { TrailDef }

function Config.getUpgrade(id: string): UpgradeDef?
	for _, def in Config.Upgrades do
		if def.id == id then
			return def
		end
	end
	return nil
end

function Config.getTrail(id: string): TrailDef?
	for _, def in Config.Trails do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- Cost of buying the *next* level when currently at `level`.
function Config.upgradeCost(def: UpgradeDef, level: number): number
	return math.floor(def.baseCost * def.costGrowth ^ level)
end

function Config.upgradeValue(def: UpgradeDef, level: number): number
	return def.base + def.perLevel * level
end

function Config.coinMultiplier(rebirths: number): number
	return 1 + rebirths * Config.REBIRTH_MULTIPLIER
end

function Config.zoneForStage(stage: number): ZoneDef
	local index = math.clamp(math.floor((stage - 1) / Config.STAGES_PER_ZONE) + 1, 1, #Config.Zones)
	return Config.Zones[index]
end

function Config.formatNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(math.floor(n))
	-- thousands separators for small numbers
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

return Config
