--!strict
-- Sprint with stamina, the flashlight and the monster's hunter sense.
-- ContextActionService gives mobile players on-screen buttons for free.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local GameState = ReplicatedStorage:WaitForChild("GameState") :: Configuration
local FlashlightRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Flashlight") :: RemoteEvent

local Controls = {}

local sprintHeld = false
local stamina = 1
local exhausted = false
local senseReadyAt = 0

local function act(): string
	local value = GameState:GetAttribute("Act")
	return if type(value) == "string" then value else "Explore"
end

local function humanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function hunterSense()
	if act() ~= "Hunt" or os.clock() < senseReadyAt then
		return
	end
	senseReadyAt = os.clock() + Config.HUNTER_SENSE_COOLDOWN
	UI.sound(Config.Sounds.Whoosh, 0.7, 0.5)
	local highlights = {}
	for _, survivor in CollectionService:GetTagged("Survivor") do
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 240, 220)
		highlight.FillTransparency = 0.5
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = survivor
		highlight.Parent = workspace.CurrentCamera
		table.insert(highlights, highlight)
	end
	task.delay(Config.HUNTER_SENSE_DURATION, function()
		for _, h in highlights do
			h:Destroy()
		end
	end)
end

function Controls.Init()
	ContextActionService:BindAction("Sprint", function(_, state)
		sprintHeld = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Run")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -90))

	ContextActionService:BindAction("Flashlight", function(_, state)
		if state == Enum.UserInputState.Begin and (act() == "Explore" or act() == "Reveal") then
			UI.sound(Config.Sounds.Click, 0.6, 1.4)
			FlashlightRemote:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("Flashlight", "Light")
	ContextActionService:SetPosition("Flashlight", UDim2.new(1, -170, 1, -150))

	ContextActionService:BindAction("HunterSense", function(_, state)
		if state == Enum.UserInputState.Begin then
			hunterSense()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("HunterSense", "Sense")
	ContextActionService:SetPosition("HunterSense", UDim2.new(1, -230, 1, -120))

	local camera = workspace.CurrentCamera
	RunService.RenderStepped:Connect(function(dt: number)
		local currentAct = act()
		local humanoid, root = humanoidAndRoot()
		local monster = currentAct == "Hunt" or currentAct == "Ending"
		if not humanoid or not root or root.Anchored or player:GetAttribute("Hidden") then
			Hud.setStamina(stamina, false)
			return
		end

		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local sprinting = sprintHeld and moving and not exhausted and stamina > 0
		if sprinting then
			stamina = math.max(0, stamina - dt / Config.STAMINA_SECONDS)
			if stamina <= 0 then
				exhausted = true
			end
		else
			stamina = math.min(1, stamina + dt / Config.STAMINA_REGEN_SECONDS)
			if exhausted and stamina > 0.3 then
				exhausted = false
			end
		end

		local walk = if monster then Config.MONSTER_WALK else Config.PLAYER_WALK
		local run = if monster then Config.MONSTER_SPRINT else Config.PLAYER_SPRINT
		humanoid.WalkSpeed = if sprinting then run else walk
		camera.FieldOfView += ((if sprinting then 78 else 70) - camera.FieldOfView) * math.min(1, dt * 6)
		Hud.setStamina(stamina, true)

		if currentAct == "Hunt" then
			local left = senseReadyAt - os.clock()
			Hud.setSense(if left > 0 then `Sense recharging ({math.ceil(left)}s)` else "Q: sense ready")
		end
	end)
end

return Controls
