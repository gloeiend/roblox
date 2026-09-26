--!strict
-- Loads, caches and saves per-player data. Falls back to an in-memory profile
-- (that is never written back) when DataStores are unavailable, e.g. in an
-- unpublished Studio place, so the game stays playable offline.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type PlayerData = {
	Coins: number,
	Stage: number,
	BestStage: number,
	Rebirths: number,
	Upgrades: { [string]: number },
	Trails: { [string]: boolean },
	EquippedTrail: string,
}

type Profile = {
	data: PlayerData,
	canSave: boolean,
}

local DataService = {}

local profiles: { [Player]: Profile } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, progress will not save:", result)
	end
end

local function defaultData(): PlayerData
	local upgrades = {}
	for _, def in Config.Upgrades do
		upgrades[def.id] = 0
	end
	return {
		Coins = 0,
		Stage = 0,
		BestStage = 0,
		Rebirths = 0,
		Upgrades = upgrades,
		Trails = {},
		EquippedTrail = "",
	}
end

-- Fill in any fields added since the player last saved and clamp bad values.
local function reconcile(raw: any): PlayerData
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	for _, key in { "Coins", "Stage", "BestStage", "Rebirths" } do
		if type(raw[key]) == "number" then
			(data :: any)[key] = math.max(0, math.floor(raw[key]))
		end
	end
	data.Stage = math.min(data.Stage, Config.STAGE_COUNT)
	if type(raw.Upgrades) == "table" then
		for _, def in Config.Upgrades do
			local level = raw.Upgrades[def.id]
			if type(level) == "number" then
				data.Upgrades[def.id] = math.clamp(math.floor(level), 0, def.maxLevel)
			end
		end
	end
	if type(raw.Trails) == "table" then
		for id, owned in raw.Trails do
			if owned == true and Config.getTrail(id) then
				data.Trails[id] = true
			end
		end
	end
	if type(raw.EquippedTrail) == "string" and data.Trails[raw.EquippedTrail] then
		data.EquippedTrail = raw.EquippedTrail
	end
	return data
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function withRetries<T>(attempts: number, fn: () -> T): (boolean, T | string)
	local lastErr: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt * 1.5)
	end
	return false, tostring(lastErr)
end

function DataService.Load(player: Player): PlayerData
	local activeStore = store
	if not activeStore then
		local profile = { data = defaultData(), canSave = false }
		profiles[player] = profile
		return profile.data
	end

	local ok, result = withRetries(3, function()
		return activeStore:GetAsync(keyFor(player))
	end)

	local profile: Profile
	if ok then
		profile = { data = reconcile(result), canSave = true }
	else
		-- Never overwrite a real save with defaults if the read failed.
		warn("[DataService] Failed to load data for", player.Name, result)
		profile = { data = defaultData(), canSave = false }
	end
	profiles[player] = profile
	return profile.data
end

function DataService.Get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

function DataService.CanSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.canSave
end

function DataService.Save(player: Player)
	local profile = profiles[player]
	local activeStore = store
	if not profile or not profile.canSave or not activeStore then
		return
	end
	local snapshot = table.clone(profile.data)
	snapshot.Upgrades = table.clone(profile.data.Upgrades)
	snapshot.Trails = table.clone(profile.data.Trails)
	local ok, err = withRetries(3, function()
		activeStore:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
		return true
	end)
	if not ok then
		warn("[DataService] Failed to save data for", player.Name, err)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
end

function DataService.SaveAll()
	local threads = {}
	for player in profiles do
		table.insert(
			threads,
			task.spawn(function()
				DataService.Save(player)
			end)
		)
	end
	-- Give pending saves time to finish (BindToClose allows ~30s).
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local running = false
		for _, thread in threads do
			if coroutine.status(thread) ~= "dead" then
				running = true
				break
			end
		end
		if not running then
			break
		end
		task.wait(0.25)
	end
end

function DataService.StartAutosave()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

return DataService
