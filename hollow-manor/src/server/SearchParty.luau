--!strict
-- Act 3: the search party. Five people with flashlights sweep the manor
-- looking for the missing family. If they see you, they run for the car.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)
local MapBuilder = require(script.Parent.MapBuilder)
local Rig = require(script.Parent.Rig)

export type Callbacks = {
	onTaken: (name: string, position: Vector3, by: Player) -> (),
	onEscaped: (name: string) -> (),
}

local TICK = 0.2
local FOV_DOT = math.cos(math.rad(70))
local CLOSE_SENSE = 10

local SearchParty = {}

local running = false
local generation = 0
local spawned: { Instance } = {}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function say(head: BasePart, text: string, color: Color3?)
	local existing = head:FindFirstChild("Speech")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(235, 235, 235)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = head
	task.delay(2.8, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function monsters(): { { player: Player, root: BasePart, character: Model } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and root and humanoid and humanoid.Health > 0 and character:GetAttribute("IsMonster") then
			table.insert(list, { player = player, root = root, character = character })
		end
	end
	return list
end

local function buildCar(parent: Instance, spot: CFrame)
	local car = Instance.new("Model")
	car.Name = "PoliceCar"
	local function body(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = spot * CFrame.new(offset)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = car
		return p
	end
	body(Vector3.new(6, 2.2, 12), Vector3.new(0, 1.9, 0), Color3.fromRGB(230, 230, 235))
	body(Vector3.new(5.6, 1.8, 6), Vector3.new(0, 3.9, 0.5), Color3.fromRGB(20, 20, 25), Enum.Material.Glass)
	for _, x in { -3, 3 } do
		for _, z in { -3.8, 3.8 } do
			local wheel = body(Vector3.new(1, 2.2, 2.2), Vector3.new(x, 1.1, z), Color3.fromRGB(15, 15, 15))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	for i, color in { Color3.fromRGB(255, 30, 30), Color3.fromRGB(40, 90, 255) } do
		local siren = body(Vector3.new(1.4, 0.6, 0.8), Vector3.new(if i == 1 then -0.8 else 0.8, 5.1, 0.5), color, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 3
		light.Parent = siren
		siren:SetAttribute("SirenPhase", i)
		CollectionService:AddTag(siren, "Siren")
	end
	for _, x in { -2, 2 } do
		local headlight = body(Vector3.new(1, 0.6, 0.2), Vector3.new(x, 2.1, -6.05), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Front
		beam.Range = 45
		beam.Angle = 50
		beam.Brightness = 3
		beam.Parent = headlight
	end
	car.Parent = parent
	table.insert(spawned, car)
end

local function takeEffect(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			TweenService:Create(d, TweenInfo.new(1.1), { Transparency = 1, Color = Color3.new(0, 0, 0) }):Play()
		elseif d:IsA("Light") then
			d.Enabled = false
		elseif d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(1.1), { Transparency = 1 }):Play()
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.new(0, 0, 0))
		smoke.Size = NumberSequence.new(2, 5)
		smoke.Transparency = NumberSequence.new(0.2, 1)
		smoke.Lifetime = NumberRange.new(0.8, 1.2)
		smoke.Speed = NumberRange.new(2, 5)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Enabled = false
		smoke.Parent = root
		smoke:Emit(40)
	end
	task.delay(1.5, function()
		model:Destroy()
	end)
end

local function runSurvivor(map: MapBuilder.Map, index: number, callbacks: Callbacks, myGeneration: number)
	local def = Config.SEARCH_PARTY[index]
	local model = Rig.create(def.name, { skin = def.skin, shirt = def.shirt, pants = def.pants })
	model:PivotTo(CFrame.lookAt(map.yardSpawns[index], map.insidePoint))
	model.Parent = map.model
	table.insert(spawned, model)
	CollectionService:AddTag(model, "Survivor")

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = (model:FindFirstChild("Head") or root) :: BasePart
	root:SetNetworkOwner(nil)
	Rig.animate(model)
	local nav = Rig.navigator(model)

	local flashlight = Instance.new("SpotLight")
	flashlight.Name = "Flashlight"
	flashlight.Face = Enum.NormalId.Front
	flashlight.Range = 40
	flashlight.Angle = 45
	flashlight.Brightness = 3.5
	flashlight.Shadows = true
	flashlight.Color = Color3.fromRGB(255, 245, 220)
	flashlight.Parent = head

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(160, 20)
	tag.StudsOffset = Vector3.new(0, 1.8, 0)
	tag.MaxDistance = 25
	tag.LightInfluence = 0
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	nameLabel.TextTransparency = 0.3
	nameLabel.Text = def.name
	nameLabel.Parent = tag
	tag.Parent = head

	local state = "Enter"
	local lastSaw = 0
	local waitUntil = 0
	local target: Vector3 = map.insidePoint
	humanoid.WalkSpeed = Config.PARTY_WALK
	nav:moveTo(target)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }

	while running and generation == myGeneration and model.Parent do
		task.wait(TICK)
		local now = os.clock()
		local position = root.Position

		-- Taken?
		local taker: Player? = nil
		local seen = false
		for _, monster in monsters() do
			local offset = monster.root.Position - head.Position
			local distance = offset.Magnitude
			if distance <= Config.TAKE_RANGE then
				taker = monster.player
				break
			end
			if distance <= Config.PARTY_SIGHT and (distance < CLOSE_SENSE or head.CFrame.LookVector:Dot(offset.Unit) > FOV_DOT) then
				local hit = workspace:Raycast(head.Position, offset, params)
				if not hit or hit.Instance:IsDescendantOf(monster.character) then
					seen = true
				end
			end
		end
		if taker then
			CollectionService:RemoveTag(model, "Survivor")
			callbacks.onTaken(def.name, position, taker)
			takeEffect(model)
			return
		end

		if seen then
			lastSaw = now
			if state ~= "Flee" then
				state = "Flee"
				say(head, pick(Story.PartyLines.Spotted), Color3.fromRGB(255, 120, 120))
				humanoid.WalkSpeed = Config.PARTY_FLEE
			end
		end

		if state == "Enter" then
			if nav:arrived(4) then
				state = "Search"
				waitUntil = now + 1
				say(head, pick(Story.PartyLines.Search))
			end
		elseif state == "Search" then
			if nav:arrived(3) and now >= waitUntil then
				if waitUntil == 0 then
					waitUntil = now + math.random(10, 30) / 10
				else
					waitUntil = 0
					target = pick(map.waypoints)
					nav:moveTo(target, 5)
					if math.random() < 0.3 then
						say(head, pick(Story.PartyLines.Search))
					end
				end
			end
		elseif state == "Flee" then
			nav:moveTo(map.escapePoint, 1.5)
			local flat = Vector3.new(map.escapePoint.X - position.X, 0, map.escapePoint.Z - position.Z)
			if flat.Magnitude < 5 then
				CollectionService:RemoveTag(model, "Survivor")
				callbacks.onEscaped(def.name)
				say(head, "GO GO GO! DRIVE!", Color3.fromRGB(255, 220, 120))
				task.delay(1.5, function()
					model:Destroy()
				end)
				return
			elseif now - lastSaw > Config.PARTY_CALM_DOWN then
				state = "Search"
				humanoid.WalkSpeed = Config.PARTY_WALK
				waitUntil = 0
				target = pick(map.waypoints)
				nav:moveTo(target, 5)
				say(head, "I... I think we lost it.")
			end
		end
		nav:step()
	end
end

function SearchParty.Start(map: MapBuilder.Map, callbacks: Callbacks)
	SearchParty.Stop()
	running = true
	generation += 1
	local myGeneration = generation
	buildCar(map.model, map.carSpot)
	for index = 1, #Config.SEARCH_PARTY do
		task.delay((index - 1) * 2.5, function()
			if running and generation == myGeneration then
				runSurvivor(map, index, callbacks, myGeneration)
			end
		end)
	end
end

function SearchParty.Stop()
	running = false
	generation += 1
	for _, instance in spawned do
		instance:Destroy()
	end
	table.clear(spawned)
end

return SearchParty
