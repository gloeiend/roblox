--!strict
-- Procedurally builds the whole obby from Config.SEED: a lobby, one obstacle
-- section plus checkpoint per stage, decorative clouds and a finish podium.
-- The same seed always produces the same course.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Obstacles = require(script.Parent.Obstacles)

export type Coin = {
	id: number,
	part: BasePart,
	stage: number,
	value: number,
}

export type Course = {
	folder: Model,
	checkpoints: { [number]: BasePart }, -- [0] is the lobby
	voidY: { [number]: number }, -- rescue height for a player whose current stage is the key
	coinsByStage: { [number]: { Coin } },
	coinsById: { [number]: Coin },
}

export type Callbacks = {
	onCheckpoint: (player: Player, stage: number) -> (),
}

local HAZARD_COLOR = Color3.fromRGB(255, 45, 60)
local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local PAD_SIZE = Vector3.new(12, 1, 10)

-- Order of the first few stages is fixed so new players get a gentle ramp.
local INTRO_ORDER = { "Jumps", "LavaStrips", "Tightrope" }
local POOL = { "Jumps", "LavaStrips", "Tightrope", "MovingPlatforms", "Spinners", "Crumbling", "Tower" }

local CourseBuilder = {}

local function newPart(props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function characterFromHit(hit: BasePart): (Model?, Humanoid?)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end
	return model, model:FindFirstChildOfClass("Humanoid")
end

local function bindHazard(part: BasePart)
	part.Touched:Connect(function(hit)
		local _, humanoid = characterFromHit(hit)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end)
end

local function makeLabel(parent: BasePart, text: string, color: Color3, height: number, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(8, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
end

local function buildCheckpoint(folder: Instance, stage: number, topCenter: Vector3, isFinish: boolean): BasePart
	local zone = Config.zoneForStage(stage)
	local size = if isFinish then Vector3.new(30, 1, 30) else PAD_SIZE
	local pad = newPart({
		Name = if isFinish then "Finish" else "Checkpoint" .. stage,
		Size = size,
		CFrame = CFrame.new(topCenter + Vector3.new(0, -0.5, size.Z / 2)),
		Color = if isFinish then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(245, 245, 250),
		Material = if isFinish then Enum.Material.Neon else Enum.Material.SmoothPlastic,
	}, folder)
	pad:SetAttribute("Stage", stage)

	-- Glowing trim so checkpoints read clearly from a distance.
	newPart({
		Name = "Trim",
		Size = Vector3.new(size.X, 0.2, 1),
		CFrame = pad.CFrame * CFrame.new(0, 0.6, -size.Z / 2 + 0.5),
		Color = zone.accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, folder)

	if isFinish then
		makeLabel(pad, "FINISH!", Color3.fromRGB(255, 230, 120), 10, 400)
		for _, offset in { Vector3.new(-12, 0, -12), Vector3.new(12, 0, -12), Vector3.new(-12, 0, 12), Vector3.new(12, 0, 12) } do
			local pillar = newPart({
				Name = "Pillar",
				Size = Vector3.new(2, 14, 2),
				CFrame = pad.CFrame * CFrame.new(offset + Vector3.new(0, 7.5, 0)),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.Marble,
			}, folder)
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 220, 90)
			sparkles.Parent = pillar
		end
	else
		makeLabel(pad, tostring(stage), zone.accent, 4, 90)
	end
	return pad
end

local function buildLobby(folder: Instance, origin: Vector3): BasePart
	local lobby = newPart({
		Name = "Lobby",
		Size = Vector3.new(40, 2, 40),
		CFrame = CFrame.new(origin - Vector3.new(0, 1, 0)),
		Color = Color3.fromRGB(235, 240, 250),
		Material = Enum.Material.SmoothPlastic,
	}, folder)
	lobby:SetAttribute("Stage", 0)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, -8))
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	local sign = newPart({
		Name = "TitleSign",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(origin + Vector3.new(0, 0, 14)),
	}, folder)
	makeLabel(sign, "SKY CLIMB", Color3.fromRGB(255, 255, 255), 12, 300)
	local sub = newPart({
		Name = "SubSign",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(origin + Vector3.new(0, 0, 14)),
	}, folder)
	local subGui = Instance.new("BillboardGui")
	subGui.Size = UDim2.fromScale(16, 1.5)
	subGui.StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0)
	subGui.MaxDistance = 200
	subGui.Parent = sub
	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Size = UDim2.fromScale(1, 1)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextScaled = true
	subLabel.Text = `Climb {Config.STAGE_COUNT} stages • Grab coins • Buy upgrades • Rebirth`
	subLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
	subLabel.TextStrokeTransparency = 0.4
	subLabel.Parent = subGui

	return lobby
end

local function buildClouds(folder: Instance, rng: Random, around: Vector3)
	for _ = 1, 2 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local center = around + Vector3.new(side * rng:NextNumber(35, 80), rng:NextNumber(-40, 10), rng:NextNumber(-20, 20))
		for _ = 1, rng:NextInteger(3, 5) do
			local s = rng:NextNumber(10, 22)
			newPart({
				Name = "Cloud",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(s, s, s),
				CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-3, 3), rng:NextNumber(-8, 8))),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.15,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, folder)
		end
	end
end

function CourseBuilder.Build(callbacks: Callbacks): Course
	local existing = workspace:FindFirstChild("Course")
	if existing then
		existing:Destroy()
	end

	-- A persistent model is always fully streamed to every client, so players
	-- never land on (or teleport to) a platform that hasn't loaded yet.
	local folder = Instance.new("Model")
	folder.Name = "Course"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Parent = workspace -- parented first so physics parts can take network ownership

	local rng = Random.new(Config.SEED)
	local origin = Config.COURSE_ORIGIN

	local course: Course = {
		folder = folder,
		checkpoints = {},
		voidY = {},
		coinsByStage = {},
		coinsById = {},
	}

	course.checkpoints[0] = buildLobby(folder, origin)

	local coinFolder = Instance.new("Folder")
	coinFolder.Name = "Coins"
	coinFolder.Parent = folder

	local nextCoinId = 0
	local edge = origin + Vector3.new(0, 0, 20)
	local previousType = ""

	for stage = 1, Config.STAGE_COUNT do
		local zone = Config.zoneForStage(stage)
		local stageFolder = Instance.new("Folder")
		stageFolder.Name = string.format("Stage%02d", stage)
		stageFolder.Parent = folder

		local lowestTop = edge.Y
		local stageCoins: { Coin } = {}
		course.coinsByStage[stage] = stageCoins

		local ctx: Obstacles.Context = {
			rng = rng,
			difficulty = (stage - 1) / math.max(1, Config.STAGE_COUNT - 1),
			folder = stageFolder,
			platform = function(size, cframe)
				local part = newPart({
					Name = "Platform",
					Size = size,
					CFrame = cframe,
					Color = zone.platform,
					Material = zone.material,
				}, stageFolder)
				lowestTop = math.min(lowestTop, cframe.Position.Y + size.Y / 2)
				return part
			end,
			hazard = function(size, cframe)
				local part = newPart({
					Name = "Hazard",
					Size = size,
					CFrame = cframe,
					Color = HAZARD_COLOR,
					Material = Enum.Material.Neon,
				}, stageFolder)
				bindHazard(part)
				return part
			end,
			coin = function(position)
				nextCoinId += 1
				local part = newPart({
					Name = "Coin",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.4, 2.4, 2.4),
					CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0),
					Color = COIN_COLOR,
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					CastShadow = false,
				}, coinFolder)
				part:SetAttribute("CoinId", nextCoinId)
				local coin: Coin = {
					id = nextCoinId,
					part = part,
					stage = stage,
					value = Config.COIN_VALUE + math.floor(stage / 8),
				}
				table.insert(stageCoins, coin)
				course.coinsById[nextCoinId] = coin
			end,
		}

		local obstacleType = INTRO_ORDER[stage]
		if not obstacleType then
			repeat
				obstacleType = POOL[rng:NextInteger(1, #POOL)]
			until obstacleType ~= previousType
		end
		previousType = obstacleType
		stageFolder:SetAttribute("Obstacle", obstacleType)

		local finishPoint = Obstacles[obstacleType](ctx, edge)
		local isFinish = stage == Config.STAGE_COUNT
		local pad = buildCheckpoint(folder, stage, finishPoint, isFinish)
		course.checkpoints[stage] = pad

		local previousTop = course.checkpoints[stage - 1].Position.Y + course.checkpoints[stage - 1].Size.Y / 2
		course.voidY[stage - 1] = math.min(lowestTop, previousTop) - Config.VOID_DROP

		if stage % Config.STAGES_PER_ZONE == 1 then
			local marker = newPart({
				Name = "ZoneMarker",
				Size = Vector3.new(1, 1, 1),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CFrame = CFrame.new(edge + Vector3.new(0, 0, -6)),
			}, stageFolder)
			makeLabel(marker, zone.name:upper(), zone.accent, 9, 160)
		end

		buildClouds(folder, rng, (edge + finishPoint) / 2)

		pad.Touched:Connect(function(hit)
			local model = characterFromHit(hit)
			local player = model and Players:GetPlayerFromCharacter(model)
			if player then
				callbacks.onCheckpoint(player, stage)
			end
		end)

		edge = finishPoint + Vector3.new(0, 0, pad.Size.Z)
	end

	local finish = course.checkpoints[Config.STAGE_COUNT]
	course.voidY[Config.STAGE_COUNT] = finish.Position.Y - Config.VOID_DROP

	return course
end

-- Where a player standing at `stage` should respawn.
function CourseBuilder.SpawnCFrame(course: Course, stage: number): CFrame
	local pad = course.checkpoints[math.clamp(stage, 0, Config.STAGE_COUNT)]
	local top = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3, 0)
	-- Face down the course (+Z).
	return CFrame.lookAt(top, top + Vector3.new(0, 0, 1))
end

return CourseBuilder
