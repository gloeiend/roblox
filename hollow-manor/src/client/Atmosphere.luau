--!strict
-- Everything that makes the house feel alive: flickering lamps (worse when the
-- thing is near), a heartbeat and vignette that track its distance, your own
-- flashlight, police sirens, and the red "monster vision" of the final act.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local GameState = ReplicatedStorage:WaitForChild("GameState") :: Configuration

local Atmosphere = {}

type Lamp = { light: PointLight, bulb: BasePart, base: number, dimUntil: number }
local lamps: { [BasePart]: Lamp } = {}
local vignette: { Frame } = {}
local cameraShake = 0

local function trackLamp(bulb: Instance)
	if not bulb:IsA("BasePart") then
		return
	end
	local light = bulb:FindFirstChildOfClass("PointLight")
	if light then
		lamps[bulb] = { light = light, bulb = bulb, base = light.Brightness, dimUntil = 0 }
	end
end

local function stalkerModel(): Model?
	local manor = workspace:FindFirstChild("HollowManor")
	local thing = manor and manor:FindFirstChild("TheThing")
	return if thing and thing:IsA("Model") then thing else nil
end

local function loopSound(id: string, volume: number): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	return sound
end

function Atmosphere.shake(amount: number)
	cameraShake = math.max(cameraShake, amount)
end

local function buildVignette()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Dread"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	-- Four gradient edges that close in as fear rises.
	local edges = {
		{ size = UDim2.fromScale(1, 0.35), pos = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.35), pos = UDim2.fromScale(0, 0.65), rotation = -90 },
		{ size = UDim2.fromScale(0.3, 1), pos = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.3, 1), pos = UDim2.fromScale(0.7, 0), rotation = 180 },
	}
	for _, edge in edges do
		local frame = UI.new("Frame", {
			Size = edge.size,
			Position = edge.pos,
			BackgroundColor3 = Color3.fromRGB(20, 0, 0),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Parent = gui,
		}, {
			UI.new("UIGradient", {
				Rotation = edge.rotation,
				Transparency = NumberSequence.new(0, 1),
			}),
		})
		table.insert(vignette, frame)
	end
end

function Atmosphere.Init()
	workspace:WaitForChild("HollowManor", 30)
	for _, bulb in CollectionService:GetTagged("FlickerLamp") do
		trackLamp(bulb)
	end
	CollectionService:GetInstanceAddedSignal("FlickerLamp"):Connect(trackLamp)
	CollectionService:GetInstanceRemovedSignal("FlickerLamp"):Connect(function(bulb)
		lamps[bulb :: BasePart] = nil
	end)
	buildVignette()

	loopSound(Config.Sounds.Ambience, 0.35)
	local chase = loopSound(Config.Sounds.Chase, 0)

	-- Local flashlight that follows the camera exactly (the server light on
	-- your head is what other players see, so we hide it for you).
	local camera = workspace.CurrentCamera
	local beamPart = Instance.new("Part")
	beamPart.Name = "MyFlashlight"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CanQuery = false
	beamPart.CanTouch = false
	beamPart.Transparency = 1
	beamPart.Size = Vector3.new(0.2, 0.2, 0.2)
	beamPart.Parent = camera
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 50
	beam.Angle = 48
	beam.Brightness = 3.2
	beam.Shadows = true
	beam.Color = Color3.fromRGB(255, 244, 214)
	beam.Enabled = false
	beam.Parent = beamPart

	-- Monster vision (act 3): you see in the dark now.
	local vision = Instance.new("ColorCorrectionEffect")
	vision.Name = "MonsterVision"
	vision.Enabled = false
	vision.TintColor = Color3.fromRGB(255, 150, 150)
	vision.Brightness = 0.12
	vision.Contrast = 0.3
	vision.Parent = Lighting

	local darkAmbient, darkOutdoor = Lighting.Ambient, Lighting.OutdoorAmbient
	local function applyAct()
		local act = GameState:GetAttribute("Act")
		local monster = act == "Hunt" or act == "Ending"
		vision.Enabled = monster
		-- Local-only brighten: you see in the dark, the house stays black for everyone else.
		Lighting.Ambient = if monster then Color3.fromRGB(70, 30, 30) else darkAmbient
		Lighting.OutdoorAmbient = if monster then Color3.fromRGB(80, 40, 40) else darkOutdoor
	end
	GameState:GetAttributeChangedSignal("Act"):Connect(applyAct)
	applyAct()

	local nextBeat = 0
	RunService:BindToRenderStep("HollowAtmosphere", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local now = os.clock()
		local act = GameState:GetAttribute("Act")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- Flashlight
		local head = character and character:FindFirstChild("Head")
		local serverLight = head and head:FindFirstChild("Flashlight") :: SpotLight?
		if serverLight then
			serverLight.Enabled = false
		end
		beam.Enabled = character ~= nil and character:GetAttribute("FlashlightOn") == true
		beamPart.CFrame = camera.CFrame * CFrame.new(0.4, -0.4, 0)

		-- Fear
		local fear = 0
		local thing = stalkerModel()
		local thingRoot = thing and thing:FindFirstChild("HumanoidRootPart") :: BasePart?
		local chasing = thing ~= nil and thing:GetAttribute("Chasing") == true
		if act == "Explore" and root and thingRoot then
			local distance = (thingRoot.Position - root.Position).Magnitude
			fear = math.clamp(1 - distance / 50, 0, 1)
			if chasing then
				fear = math.max(fear, 0.45)
				if distance < 22 then
					Atmosphere.shake(0.25 * (1 - distance / 22))
				end
			end
		end
		for _, frame in vignette do
			frame.BackgroundTransparency = 1 - fear * 0.9
		end
		if chase then
			chase.Volume += ((if chasing and act == "Explore" then 0.6 else 0) - chase.Volume) * math.min(1, dt * 2)
		end
		if fear > 0.12 and now >= nextBeat then
			nextBeat = now + (1.15 - fear * 0.8)
			UI.sound(Config.Sounds.Heartbeat, 0.4 + fear * 1.2, 0.35)
			task.delay(0.18, function()
				UI.sound(Config.Sounds.Heartbeat, 0.3 + fear, 0.3)
			end)
		end

		-- Lamps: random flicker, violent near the thing.
		for _, lamp in lamps do
			if not lamp.bulb.Parent then
				continue
			end
			local nearThing = thingRoot and (lamp.bulb.Position - thingRoot.Position).Magnitude < 24
			local chance = if nearThing then 0.25 else 0.004
			if now >= lamp.dimUntil and math.random() < chance then
				lamp.dimUntil = now + math.random(4, 20) / 100
			end
			lamp.light.Brightness = if now < lamp.dimUntil then lamp.base * 0.08 else lamp.base
		end

		-- Police sirens alternate red/blue.
		local phase = math.floor(now * 3) % 2 + 1
		for _, siren in CollectionService:GetTagged("Siren") do
			local light = siren:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = siren:GetAttribute("SirenPhase") == phase
			end
		end

		-- Camera shake is applied on top of the default camera each frame.
		if cameraShake > 0.001 and camera.CameraType ~= Enum.CameraType.Scriptable then
			local s = cameraShake
			camera.CFrame *= CFrame.Angles(
				math.rad((math.random() - 0.5) * 4 * s),
				math.rad((math.random() - 0.5) * 4 * s),
				math.rad((math.random() - 0.5) * 2 * s)
			)
			cameraShake *= math.exp(-dt * 6)
		end
	end)
end

return Atmosphere
