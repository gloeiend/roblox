--!strict
-- Character helpers shared by the stalker, the search party and the player's
-- transformation: building NPC rigs, animating them, turning any character
-- into "the thing", and following paths.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Colors = { skin: Color3, shirt: Color3, pants: Color3 }

local Rig = {}

-- Minimal hand-built rig used if the avatar service is unavailable.
local function fallbackRig(name: string, colors: Colors, height: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local function limb(partName: string, size: Vector3, offset: Vector3, color: Color3): BasePart
		local p = Instance.new("Part")
		p.Name = partName
		p.Size = size * height
		p.Color = color
		p.CFrame = root.CFrame * CFrame.new(offset * height)
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	limb("UpperTorso", Vector3.new(2, 2, 1), Vector3.zero, colors.shirt)
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), colors.skin)
	limb("LeftLeg", Vector3.new(0.9, 2, 0.9), Vector3.new(-0.5, -2, 0), colors.pants)
	limb("RightLeg", Vector3.new(0.9, 2, 0.9), Vector3.new(0.5, -2, 0), colors.pants)
	limb("LeftArm", Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 0, 0), colors.shirt)
	limb("RightArm", Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 0, 0), colors.shirt)
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2 * height
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

function Rig.create(name: string, colors: Colors, height: number?): Model
	local scale = height or 1
	local ok, result = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = colors.skin
		desc.LeftArmColor = colors.shirt
		desc.RightArmColor = colors.shirt
		desc.TorsoColor = colors.shirt
		desc.LeftLegColor = colors.pants
		desc.RightLegColor = colors.pants
		desc.HeightScale = scale
		desc.DepthScale = 1
		desc.WidthScale = if scale > 1 then 0.85 else 1
		desc.HeadScale = 1
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	local model: Model = if ok then result else fallbackRig(name, colors, scale)
	if not ok then
		warn("[Rig] Using fallback rig:", result)
	end
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	return model
end

-- Plays walk/idle animations driven by the humanoid's running speed.
function Rig.animate(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local ok, tracks = pcall(function()
		local walk = Instance.new("Animation")
		walk.AnimationId = Config.Animations.Walk
		local idle = Instance.new("Animation")
		idle.AnimationId = Config.Animations.Idle
		return { walk = animator:LoadAnimation(walk), idle = animator:LoadAnimation(idle) }
	end)
	if not ok then
		return
	end
	tracks.idle.Looped = true
	tracks.walk.Looped = true
	tracks.idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not tracks.walk.IsPlaying then
				tracks.idle:Stop(0.2)
				tracks.walk:Play(0.2)
			end
			tracks.walk:AdjustSpeed(math.clamp(speed / 12, 0.5, 2.2))
		elseif tracks.walk.IsPlaying then
			tracks.walk:Stop(0.2)
			tracks.idle:Play(0.2)
		end
	end)
end

-- Two glowing eyes that ignore lighting, so they read in total darkness.
local function addEyes(head: BasePart)
	if head:FindFirstChild("Eyes") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Eyes"
	gui.Size = UDim2.fromScale(1.2, 0.5)
	gui.StudsOffset = Vector3.new(0, 0.15, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = head
	for _, x in { 0.12, 0.62 } do
		local eye = Instance.new("Frame")
		eye.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
		eye.BorderSizePixel = 0
		eye.Size = UDim2.fromScale(0.26, 0.45)
		eye.Position = UDim2.fromScale(x, 0.25)
		eye.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = eye
	end
	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = Color3.fromRGB(255, 40, 40)
	glow.Range = 8
	glow.Brightness = 1.2
	glow.Parent = head
end

-- Turn any character into the shadow thing: a black silhouette with red eyes.
function Rig.monsterize(model: Model)
	for _, child in model:GetDescendants() do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Decal") and child.Name == "face" then
			child:Destroy()
		end
	end
	local highlight = model:FindFirstChild("Shadow") :: Highlight? or Instance.new("Highlight")
	highlight.Name = "Shadow"
	highlight.FillColor = Color3.fromRGB(4, 2, 4)
	highlight.FillTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(90, 0, 0)
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		addEyes(head)
	end
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if torso and not torso:FindFirstChild("Smoke") then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Smoke"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.new(0, 0, 0))
		smoke.Transparency = NumberSequence.new(0.6, 1)
		smoke.Size = NumberSequence.new(1.5, 3)
		smoke.Rate = 12
		smoke.Lifetime = NumberRange.new(1, 1.6)
		smoke.Speed = NumberRange.new(0.5, 1.5)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Parent = torso
	end
	model:SetAttribute("IsMonster", true)
end

--------------------------------------------------------------------------------
-- Navigator: follows PathfindingService paths toward a moving target.

export type Navigator = {
	humanoid: Humanoid,
	root: BasePart,
	path: Path,
	waypoints: { PathWaypoint },
	index: number,
	target: Vector3?,
	computedAt: number,
	lastProgress: number,
	lastPosition: Vector3,
	moveTo: (self: Navigator, target: Vector3, repathInterval: number?) -> (),
	step: (self: Navigator) -> (),
	stop: (self: Navigator) -> (),
	arrived: (self: Navigator, radius: number) -> boolean,
}

local Navigator = {}
Navigator.__index = Navigator

function Rig.navigator(model: Model): Navigator
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local self = setmetatable({
		humanoid = humanoid,
		root = root,
		path = PathfindingService:CreatePath({
			AgentRadius = 1.8,
			AgentHeight = 6,
			AgentCanJump = false,
			WaypointSpacing = 6,
		}),
		waypoints = {},
		index = 0,
		target = nil,
		computedAt = 0,
		lastProgress = os.clock(),
		lastPosition = root.Position,
	}, Navigator)
	return (self :: any) :: Navigator
end

function Navigator.moveTo(self: Navigator, target: Vector3, repathInterval: number?)
	local now = os.clock()
	local interval = repathInterval or 1.5
	local moved = self.target == nil or ((self.target :: Vector3) - target).Magnitude > 4
	if not moved and now - self.computedAt < interval and self.index > 0 then
		return
	end
	self.target = target
	self.computedAt = now
	local ok = pcall(function()
		self.path:ComputeAsync(self.root.Position, target)
	end)
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.index = math.min(2, #self.waypoints)
	else
		-- No path: head straight for it and hope.
		self.waypoints = {}
		self.index = 0
		self.humanoid:MoveTo(target)
		return
	end
	local waypoint = self.waypoints[self.index]
	if waypoint then
		self.humanoid:MoveTo(waypoint.Position)
	end
end

function Navigator.step(self: Navigator)
	local now = os.clock()
	local position = self.root.Position
	if (position - self.lastPosition).Magnitude > 1 then
		self.lastPosition = position
		self.lastProgress = now
	elseif self.target and now - self.lastProgress > 1.5 then
		-- Stuck on furniture or another NPC: force a fresh path.
		self.lastProgress = now
		self.computedAt = 0
		self.index = 0
		self:moveTo(self.target :: Vector3)
		return
	end

	local waypoint = self.waypoints[self.index]
	if not waypoint then
		return
	end
	local flat = Vector3.new(waypoint.Position.X - position.X, 0, waypoint.Position.Z - position.Z)
	if flat.Magnitude < 3 then
		self.index += 1
		local nextPoint = self.waypoints[self.index]
		if nextPoint then
			self.humanoid:MoveTo(nextPoint.Position)
		end
	else
		-- Humanoid:MoveTo times out after 8s; keep re-issuing it.
		self.humanoid:MoveTo(waypoint.Position)
	end
end

function Navigator.stop(self: Navigator)
	self.target = nil
	self.waypoints = {}
	self.index = 0
	self.humanoid:MoveTo(self.root.Position)
end

function Navigator.arrived(self: Navigator, radius: number): boolean
	local target = self.target
	if not target then
		return true
	end
	local flat = Vector3.new(target.X - self.root.Position.X, 0, target.Z - self.root.Position.Z)
	return flat.Magnitude <= radius
end

return Rig
