--!strict
-- Scripted moments: the mirror reveal, the jumpscare and the "taken" flash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)
local Atmosphere = require(script.Parent.Atmosphere)
local Hud = require(script.Parent.Hud)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Cutscene = {}

local screen: ScreenGui

local function overlay(color: Color3, transparency: number, z: number?): Frame
	return UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z or 60,
		Parent = screen,
	})
end

-- Reflect a CFrame across the plane z = planeZ, keeping it a valid rotation.
local function mirror(cf: CFrame, planeZ: number): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(x, y, 2 * planeZ - z, r00, r01, -r02, r10, r11, -r12, -r20, -r21, r22)
end

local function darken(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(4, 2, 4)
	highlight.FillTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(90, 0, 0)
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local eyes = Instance.new("BillboardGui")
		eyes.Size = UDim2.fromScale(1.2, 0.5)
		eyes.StudsOffset = Vector3.new(0, 0.15, 0)
		eyes.LightInfluence = 0
		eyes.Parent = head
		for _, x in { 0.12, 0.62 } do
			UI.new("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 30, 30),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0.26, 0.45),
				Position = UDim2.fromScale(x, 0.25),
				Parent = eyes,
			}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 40, 40)
		glow.Range = 10
		glow.Brightness = 2
		glow.Parent = head
	end
end

-- Builds a local copy of the character whose parts can be driven each frame.
local function makeReflection(character: Model): (Model, { { source: BasePart, copy: BasePart } })
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = false
	clone.Name = "Reflection"
	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Light") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local pairsList = {}
	local sources = character:GetDescendants()
	local copies = clone:GetDescendants()
	-- Match parts by their path inside the model.
	local byPath: { [string]: BasePart } = {}
	for _, d in copies do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			byPath[d:GetFullName():gsub("^.-Reflection", "")] = d
		end
	end
	for _, d in sources do
		if d:IsA("BasePart") then
			local path = d:GetFullName():gsub("^.-" .. character.Name, "")
			local copy = byPath[path]
			if copy then
				table.insert(pairsList, { source = d, copy = copy })
			end
		end
	end
	clone.Parent = workspace.CurrentCamera
	return clone, pairsList
end

function Cutscene.reveal(planeZ: number, duration: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	-- Wait a beat so the server's teleport to the mirror has replicated.
	task.wait(0.2)
	Hud.closeNote()

	local camera = workspace.CurrentCamera
	local black = overlay(Color3.new(0, 0, 0), 0)
	TweenService:Create(black, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()

	camera.CameraType = Enum.CameraType.Scriptable
	local rootPos = root.Position
	local camPos = rootPos + Vector3.new(1.2, 1.9, -3.4)
	camera.CFrame = CFrame.lookAt(camPos, Vector3.new(rootPos.X, rootPos.Y + 1.2, planeZ))

	local reflection, parts = makeReflection(character)
	local frozen: { [BasePart]: CFrame } = {}
	local approach = 0
	local started = os.clock()

	RunService:BindToRenderStep("MirrorReveal", Enum.RenderPriority.Camera.Value + 2, function()
		-- Keep your own body visible even though you're in first person.
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
		for _, pair in parts do
			local target = frozen[pair.copy] or mirror(pair.source.CFrame, planeZ)
			pair.copy.CFrame = target - Vector3.new(0, 0, approach)
			pair.copy.LocalTransparencyModifier = 0
		end
		-- Slow push-in on the glass.
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		camera.CFrame = CFrame.lookAt(camPos:Lerp(camPos + Vector3.new(-0.6, -0.2, 2.2), t), Vector3.new(rootPos.X, rootPos.Y + 1.2, planeZ))
	end)

	local lines = Story.Reveal
	local function at(seconds: number, fn: () -> ())
		task.delay(seconds, fn)
	end

	at(1, function()
		Hud.message(lines[1], 2)
	end)
	at(3, function()
		Hud.message(lines[2], 2)
	end)
	for i, t in { 4.8, 5.3, 5.6, 6.0 } do
		at(t, function()
			local flick = overlay(Color3.new(0, 0, 0), 0)
			task.delay(if i % 2 == 0 then 0.12 else 0.07, function()
				flick:Destroy()
			end)
		end)
	end
	at(6.5, function()
		local blackout = overlay(Color3.new(0, 0, 0), 0)
		UI.sound(Config.Sounds.Whoosh, 1, 0.4)
		-- Swap the reflection while nobody can see.
		for _, d in reflection:GetDescendants() do
			if d:IsA("Accessory") or d:IsA("Clothing") or (d:IsA("Decal") and d.Name == "face") then
				d:Destroy()
			end
		end
		darken(reflection)
		for _, pair in parts do
			frozen[pair.copy] = mirror(pair.source.CFrame, planeZ)
		end
		task.delay(0.9, function()
			blackout:Destroy()
			Atmosphere.shake(0.4)
		end)
	end)
	-- It stops copying you... and steps toward the glass.
	at(7.5, function()
		local distance = 0
		for _, pair in parts do
			if pair.source.Name == "HumanoidRootPart" then
				distance = (frozen[pair.copy].Position.Z - planeZ) - 1.2
			end
		end
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(v)
			approach = v
		end)
		TweenService:Create(value, TweenInfo.new(6.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = distance }):Play()
	end)
	for i, t in { 8, 9.4, 10.8, 12.2, 13.4 } do
		at(t, function()
			Hud.message(lines[i + 2], 1.6)
		end)
	end
	at(14.2, function()
		UI.sound(Config.Sounds.Shatter, 1.5, 0.7)
		UI.sound(Config.Sounds.Jumpscare, 1, 0.5)
		Atmosphere.shake(1.5)
		local manor = workspace:FindFirstChild("HollowManor")
		local glass = manor and manor:FindFirstChild("Mirror", true)
		if glass and glass:IsA("BasePart") then
			glass.Transparency = 1
		end
		local flash = overlay(Color3.new(1, 1, 1), 0)
		TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		task.delay(0.8, function()
			flash:Destroy()
		end)
		reflection:Destroy()
	end)
	at(15, function()
		black.BackgroundTransparency = 1
		TweenService:Create(black, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play()
	end)
	at(duration + 0.3, function()
		RunService:UnbindFromRenderStep("MirrorReveal")
		if reflection.Parent then
			reflection:Destroy()
		end
		camera.CameraType = Enum.CameraType.Custom
		local character2 = player.Character
		local humanoid = character2 and character2:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		TweenService:Create(black, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
		task.delay(2, function()
			black:Destroy()
		end)
	end)
end

-- The thing's face, built from frames so it needs no image uploads.
function Cutscene.jumpscare()
	local root = overlay(Color3.new(0, 0, 0), 0, 70)
	local face: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 71,
		Parent = root,
	}, {
		UI.new("UIAspectRatioConstraint", { AspectRatio = 1.2 }),
	})
	for _, x in { 0.2, 0.62 } do
		UI.new("Frame", {
			Size = UDim2.fromScale(0.18, 0.14),
			Position = UDim2.fromScale(x, 0.22),
			BackgroundColor3 = Color3.fromRGB(255, 20, 20),
			BorderSizePixel = 0,
			ZIndex = 72,
			Parent = face,
		}, {
			UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UI.new("UIStroke", { Color = Color3.fromRGB(255, 120, 80), Thickness = 6, Transparency = 0.3 }),
		})
	end
	local mouth: Frame = UI.new("Frame", {
		Size = UDim2.fromScale(0.6, 0.3),
		Position = UDim2.fromScale(0.2, 0.55),
		BackgroundColor3 = Color3.fromRGB(60, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 72,
		Parent = face,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	for i = 0, 8 do
		for _, top in { true, false } do
			UI.new("Frame", {
				Size = UDim2.fromScale(0.07, 0.3),
				Position = UDim2.fromScale(0.07 + i * 0.1, if top then 0 else 0.7),
				Rotation = if top then 45 else -45,
				BackgroundColor3 = Color3.fromRGB(230, 225, 200),
				BorderSizePixel = 0,
				ZIndex = 73,
				Parent = mouth,
			})
		end
	end
	UI.sound(Config.Sounds.Jumpscare, 2, 0.55)
	UI.sound(Config.Sounds.Whoosh, 2, 0.3)
	UI.sound(Config.Sounds.Scream, 1.5, 1)
	Atmosphere.shake(2)
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = face })
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	local start = os.clock()
	while os.clock() - start < 0.9 do
		face.Position = UDim2.new(0.5, math.random(-18, 18), 0.5, math.random(-18, 18))
		root.BackgroundColor3 = if math.random() < 0.3 then Color3.fromRGB(80, 0, 0) else Color3.new(0, 0, 0)
		task.wait(0.03)
	end
	face:Destroy()
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	task.wait(0.6)
	TweenService:Create(root, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	task.delay(1.2, function()
		root:Destroy()
	end)
end

function Cutscene.taken(name: string, position: Vector3, byName: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if byName == player.Name then
		local pulse = overlay(Color3.fromRGB(120, 0, 0), 0.4, 55)
		TweenService:Create(pulse, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
		task.delay(0.9, function()
			pulse:Destroy()
		end)
		Atmosphere.shake(0.6)
		Hud.message(`You took {name}. The house is pleased.`)
	else
		Hud.message(`{name} vanished into the dark.`)
	end
	if root and (root.Position - position).Magnitude < 60 then
		UI.sound(Config.Sounds.Scream, 1, 1)
		UI.sound(Config.Sounds.Whoosh, 0.8, 0.6)
	end
end

function Cutscene.Init()
	screen = UI.new("ScreenGui", {
		Name = "HollowCutscene",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

return Cutscene
