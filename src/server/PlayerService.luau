--!strict
-- Owns everything a player does in the game: joining/leaving, respawning at
-- checkpoints, coin pickup, the shop, trails and rebirths. All state changes
-- are validated here; the client only ever asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CourseBuilder = require(script.Parent.CourseBuilder)
local DataService = require(script.Parent.DataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseRemote = Remotes:WaitForChild("Purchase") :: RemoteFunction
local EquipTrailRemote = Remotes:WaitForChild("EquipTrail") :: RemoteEvent
local RebirthRemote = Remotes:WaitForChild("Rebirth") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local CoinCollectedRemote = Remotes:WaitForChild("CoinCollected") :: RemoteEvent

local SCAN_INTERVAL = 0.1
local REQUEST_COOLDOWN = 0.15

local PlayerService = {}

local course: CourseBuilder.Course
local collected: { [Player]: { [number]: number } } = {}
local lastRequest: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

-- Mirror saved data onto leaderstats + attributes so the client UI can react.
local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Stage") :: IntValue).Value = data.Stage;
		(stats:FindFirstChild("Coins") :: IntValue).Value = data.Coins;
		(stats:FindFirstChild("Rebirths") :: IntValue).Value = data.Rebirths
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Stage", data.Stage)
	player:SetAttribute("BestStage", data.BestStage)
	player:SetAttribute("Rebirths", data.Rebirths)
	for _, def in Config.Upgrades do
		player:SetAttribute("Upgrade_" .. def.id, data.Upgrades[def.id])
	end
	local owned = {}
	for id in data.Trails do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("OwnedTrails", table.concat(owned, ","))
	player:SetAttribute("EquippedTrail", data.EquippedTrail)
end

local function addCoins(player: Player, base: number): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local amount = math.floor(base * Config.coinMultiplier(data.Rebirths) + 0.5)
	data.Coins += amount
	sync(player)
	return amount
end

local function getRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function applyStats(player: Player)
	local data = DataService.Get(player)
	local _, humanoid = getRoot(player)
	if not data or not humanoid then
		return
	end
	local speed = Config.getUpgrade("Speed")
	local jump = Config.getUpgrade("Jump")
	if speed then
		humanoid.WalkSpeed = Config.upgradeValue(speed, data.Upgrades.Speed)
	end
	if jump then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Config.upgradeValue(jump, data.Upgrades.Jump)
	end
end

local function applyTrail(player: Player)
	local data = DataService.Get(player)
	local root = getRoot(player)
	if not data or not root then
		return
	end
	local old = root:FindFirstChild("SkyTrail")
	if old then
		old:Destroy()
	end
	for _, name in { "TrailTop", "TrailBottom" } do
		local attachment = root:FindFirstChild(name)
		if attachment then
			attachment:Destroy()
		end
	end

	local def = Config.getTrail(data.EquippedTrail)
	if not def then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.9, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.9, 0)
	bottom.Parent = root

	local keypoints = {}
	for i, color in def.colors do
		local t = if #def.colors == 1 then 0 else (i - 1) / (#def.colors - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(t, color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, def.colors[1]))
	end

	local trail = Instance.new("Trail")
	trail.Name = "SkyTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = root
end

local function teleportToCheckpoint(player: Player)
	local data = DataService.Get(player)
	local root = getRoot(player)
	if not data or not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero;
	(player.Character :: Model):PivotTo(CourseBuilder.SpawnCFrame(course, data.Stage))
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	-- Let the default spawn positioning finish before we move the character.
	task.defer(function()
		if player.Character ~= character then
			return
		end
		teleportToCheckpoint(player)
		applyStats(player)
		applyTrail(player)
	end)
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Stage", "Coins", "Rebirths" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	collected[player] = {}
	DataService.Load(player)
	if player.Parent == nil then
		DataService.Release(player)
		return
	end
	sync(player)
	player:SetAttribute("DataLoaded", true)
	if not DataService.CanSave(player) then
		notify(player, "Progress saving is unavailable in this server.", "warn")
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	collected[player] = nil
	lastRequest[player] = nil
	DataService.Release(player)
end

function PlayerService.OnCheckpoint(player: Player, stage: number)
	local data = DataService.Get(player)
	if not data or stage ~= data.Stage + 1 then
		return
	end
	local _, humanoid = getRoot(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	data.Stage = stage
	local firstTime = stage > data.BestStage
	data.BestStage = math.max(data.BestStage, stage)

	if stage == Config.STAGE_COUNT then
		local amount = addCoins(player, Config.FINISH_REWARD)
		notify(player, `You conquered Sky Climb! +{amount} coins. Rebirth for a permanent coin boost!`, "finish")
	else
		local amount = addCoins(player, Config.CHECKPOINT_REWARD_BASE + stage)
		local zone = Config.zoneForStage(stage + 1)
		if stage % Config.STAGES_PER_ZONE == 0 then
			notify(player, `Entering {zone.name}! +{amount} coins`, "zone")
		else
			notify(player, `Stage {stage}{if firstTime then " (new best!)" else ""}  +{amount} coins`, "stage")
		end
	end
	sync(player)
end

local function collectCoin(player: Player, coin: CourseBuilder.Coin, now: number)
	collected[player][coin.id] = now + Config.COIN_RESPAWN
	local amount = addCoins(player, coin.value)
	CoinCollectedRemote:FireClient(player, coin.id, amount, Config.COIN_RESPAWN)
end

local function scanPlayers()
	local now = os.clock()
	local magnetDef = Config.getUpgrade("Magnet")
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local playerCollected = collected[player]
		local root, humanoid = getRoot(player)
		if not data or not playerCollected or not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local position = root.Position

		-- Rescue players who fell into the void instead of making them wait on a respawn.
		local voidY = course.voidY[data.Stage]
		if voidY and position.Y < voidY then
			teleportToCheckpoint(player)
			continue
		end

		local radius = if magnetDef then Config.upgradeValue(magnetDef, data.Upgrades.Magnet) else 4
		for stage = math.max(1, data.Stage), math.min(Config.STAGE_COUNT, data.Stage + 2) do
			for _, coin in course.coinsByStage[stage] do
				local expires = playerCollected[coin.id]
				if expires and expires > now then
					continue
				end
				if (coin.part.Position - position).Magnitude <= radius then
					collectCoin(player, coin, now)
				end
			end
		end
	end
end

local function onPurchase(player: Player, kind: unknown, id: unknown): (boolean, string)
	if throttled(player) or type(kind) ~= "string" or type(id) ~= "string" then
		return false, "Slow down!"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Still loading your data..."
	end

	if kind == "Upgrade" then
		local def = Config.getUpgrade(id)
		if not def then
			return false, "Unknown upgrade."
		end
		local level = data.Upgrades[def.id]
		if level >= def.maxLevel then
			return false, "Already maxed out!"
		end
		local cost = Config.upgradeCost(def, level)
		if data.Coins < cost then
			return false, `You need {Config.formatNumber(cost - data.Coins)} more coins.`
		end
		data.Coins -= cost
		data.Upgrades[def.id] = level + 1
		sync(player)
		applyStats(player)
		return true, `{def.name} upgraded to level {level + 1}!`
	elseif kind == "Trail" then
		local def = Config.getTrail(id)
		if not def then
			return false, "Unknown trail."
		end
		if data.Trails[def.id] then
			return false, "You already own this trail."
		end
		if data.Coins < def.cost then
			return false, `You need {Config.formatNumber(def.cost - data.Coins)} more coins.`
		end
		data.Coins -= def.cost
		data.Trails[def.id] = true
		data.EquippedTrail = def.id
		sync(player)
		applyTrail(player)
		return true, `Unlocked the {def.name} trail!`
	end
	return false, "Unknown item."
end

local function onEquipTrail(player: Player, id: unknown)
	if throttled(player) or type(id) ~= "string" then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if id == "" or data.Trails[id] then
		data.EquippedTrail = if data.EquippedTrail == id then "" else id
		sync(player)
		applyTrail(player)
	end
end

local function onRebirth(player: Player)
	if throttled(player) then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if data.Stage < Config.STAGE_COUNT then
		notify(player, "Reach the finish to rebirth!", "warn")
		return
	end
	data.Rebirths += 1
	data.Stage = 0
	collected[player] = {}
	sync(player)
	notify(
		player,
		`Rebirth #{data.Rebirths}! Coin multiplier is now x{Config.coinMultiplier(data.Rebirths)}`,
		"finish"
	)
	player:LoadCharacterAsync()
end

function PlayerService.Init(builtCourse: CourseBuilder.Course)
	course = builtCourse

	Players.RespawnTime = 1.5
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	PurchaseRemote.OnServerInvoke = onPurchase
	EquipTrailRemote.OnServerEvent:Connect(onEquipTrail)
	RebirthRemote.OnServerEvent:Connect(onRebirth)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= SCAN_INTERVAL then
			accumulator = 0
			scanPlayers()
		end
	end)
end

return PlayerService
