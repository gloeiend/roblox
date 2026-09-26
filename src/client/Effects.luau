--!strict
-- Client-side juice: spinning coins, per-player coin hiding, pickup sparkles,
-- sounds and checkpoint celebrations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CoinCollectedRemote = Remotes:WaitForChild("CoinCollected") :: RemoteEvent

local COIN_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local Effects = {}

type CoinVisual = { part: BasePart, base: CFrame, phase: number }

local coins: { [number]: CoinVisual } = {}
local hiddenUntil: { [number]: number } = {}

local function playSound(id: string, pitch: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	SoundService:PlayLocalSound(sound)
	task.delay(2, function()
		sound:Destroy()
	end)
end

local function setHidden(visual: CoinVisual, hidden: boolean)
	visual.part.Transparency = if hidden then 1 else 0
end

local function track(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("CoinId")
	if type(id) ~= "number" then
		return
	end
	local visual = { part = part, base = part.CFrame, phase = (id * 0.37) % (math.pi * 2) }
	coins[id] = visual
	local expires = hiddenUntil[id]
	setHidden(visual, expires ~= nil and expires > os.clock())
end

local function sparkle(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(18)
	task.delay(1, function()
		anchor:Destroy()
	end)
end

local function celebrate(big: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 90)),
	})
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new(if big then 1 else 0.6, 0)
	emitter.Speed = NumberRange.new(10, if big then 30 else 18)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Enabled = false
	emitter.Parent = root
	emitter:Emit(if big then 120 else 40)
	task.delay(2, function()
		emitter:Destroy()
	end)
	playSound(COIN_SOUND, if big then 0.8 else 1.3, 0.8)
end

function Effects.Init(onCoin: (amount: number) -> ())
	local course = workspace:WaitForChild("Course")
	local coinFolder = course:WaitForChild("Coins")
	for _, child in coinFolder:GetChildren() do
		track(child)
	end
	coinFolder.ChildAdded:Connect(track)
	coinFolder.ChildRemoved:Connect(function(child)
		local id = child:GetAttribute("CoinId")
		if type(id) == "number" then
			coins[id] = nil
		end
	end)

	CoinCollectedRemote.OnClientEvent:Connect(function(id: number, amount: number, respawn: number)
		hiddenUntil[id] = os.clock() + respawn
		local visual = coins[id]
		if visual then
			setHidden(visual, true)
			sparkle(visual.part.Position)
		end
		playSound(COIN_SOUND, 1.6 + math.random() * 0.3, 0.5)
		onCoin(amount)
	end)

	-- Spin + bob coins locally, and bring back coins whose timer ran out.
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local now = os.clock()
		for id, visual in coins do
			local expires = hiddenUntil[id]
			if expires then
				if expires <= now then
					hiddenUntil[id] = nil
					setHidden(visual, false)
				else
					continue
				end
			end
			local t = elapsed + visual.phase
			visual.part.CFrame = visual.base * CFrame.new(0, math.sin(t * 2) * 0.35, 0) * CFrame.Angles(0, t * 2.5, 0)
		end
	end)

	local lastStage = player:GetAttribute("Stage") or 0
	player:GetAttributeChangedSignal("Stage"):Connect(function()
		local stage = player:GetAttribute("Stage") or 0
		if stage > lastStage then
			celebrate(stage >= Config.STAGE_COUNT or stage % Config.STAGES_PER_ZONE == 0)
		end
		lastStage = stage
	end)

	-- Brief flash so checkpoint teleports and rebirths don't feel jarring.
	player.CharacterAdded:Connect(function()
		local gui = player:FindFirstChild("PlayerGui")
		if not gui then
			return
		end
		local flash = Instance.new("ScreenGui")
		flash.IgnoreGuiInset = true
		flash.DisplayOrder = 10
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 0.3
		frame.Parent = flash
		flash.Parent = gui
		local tween = TweenService:Create(frame, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			flash:Destroy()
		end)
	end)
end

return Effects
