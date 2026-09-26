--!strict
-- Server entry point: sets the mood, builds the course and starts services.

local Lighting = game:GetService("Lighting")

local CourseBuilder = require(script.CourseBuilder)
local DataService = require(script.DataService)
local PlayerService = require(script.PlayerService)

local function setupLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(110, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 180)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	local function ensure<T>(className: string, name: string): T
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local effect = Instance.new(className :: any)
		effect.Name = name
		effect.Parent = Lighting
		return effect :: any
	end

	local atmosphere = ensure("Atmosphere", "SkyAtmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(120, 150, 200)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2

	local bloom = ensure("BloomEffect", "SkyBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.4

	local color = ensure("ColorCorrectionEffect", "SkyColor") :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.05

	local rays = ensure("SunRaysEffect", "SkyRays") :: SunRaysEffect
	rays.Intensity = 0.08
end

setupLighting()

local course = CourseBuilder.Build({
	onCheckpoint = PlayerService.OnCheckpoint,
})

PlayerService.Init(course)
DataService.StartAutosave()

game:BindToClose(function()
	DataService.SaveAll()
end)
