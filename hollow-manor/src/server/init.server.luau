--!strict
-- Hollow Manor game director. Runs the three acts:
--   Explore: find the five notes while the thing stalks you.
--   Reveal:  the mirror shows who you really are.
--   Hunt:    you are the thing. The search party must not leave.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)
local Hiding = require(script.Hiding)
local MapBuilder = require(script.MapBuilder)
local Rig = require(script.Rig)
local SearchParty = require(script.SearchParty)
local Stalker = require(script.Stalker)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FlashlightRemote = Remotes:WaitForChild("Flashlight") :: RemoteEvent
local RestartRemote = Remotes:WaitForChild("Restart") :: RemoteEvent
local NoteRemote = Remotes:WaitForChild("Note") :: RemoteEvent
local MessageRemote = Remotes:WaitForChild("Message") :: RemoteEvent
local JumpscareRemote = Remotes:WaitForChild("Jumpscare") :: RemoteEvent
local RevealRemote = Remotes:WaitForChild("Reveal") :: RemoteEvent
local TakenRemote = Remotes:WaitForChild("Taken") :: RemoteEvent
local EndingRemote = Remotes:WaitForChild("Ending") :: RemoteEvent
local GameState = ReplicatedStorage:WaitForChild("GameState") :: Configuration

local map: MapBuilder.Map
local act: string = "Explore"
local notesFound: { [number]: boolean } = {}
local mapConnections: { RBXScriptConnection } = {}
local round = 0
local lastCaught: { [Player]: number } = {}

local function setState(key: string, value: any)
	GameState:SetAttribute(key, value)
end

local function getNumber(key: string): number
	local value = GameState:GetAttribute(key)
	return if type(value) == "number" then value else 0
end

local function message(target: Player?, text: string)
	if target then
		MessageRemote:FireClient(target, text)
	else
		MessageRemote:FireAllClients(text)
	end
end

local function noteCount(): number
	local n = 0
	for _ in notesFound do
		n += 1
	end
	return n
end

local function characterOf(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	return character, character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

--------------------------------------------------------------------------------
-- Lighting

local function lightingForAct(currentAct: string)
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.Ambient = Color3.fromRGB(6, 6, 10)
	Lighting.OutdoorAmbient = Color3.fromRGB(14, 14, 22)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.45
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(18, 18, 26)
	atmosphere.Decay = Color3.fromRGB(8, 8, 12)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting

	local tint = Lighting:FindFirstChild("ActTint") :: ColorCorrectionEffect? or Instance.new("ColorCorrectionEffect")
	tint.Name = "ActTint"
	tint.Parent = Lighting
	local hunting = currentAct == "Hunt" or currentAct == "Ending"
	TweenService:Create(tint, TweenInfo.new(3), {
		TintColor = if hunting then Color3.fromRGB(255, 175, 170) else Color3.fromRGB(215, 225, 255),
		Saturation = if hunting then -0.25 else -0.45,
		Contrast = 0.15,
	}):Play()

	for _, light in map.lamps do
		light.Color = if hunting then Color3.fromRGB(255, 40, 30) else Color3.fromRGB(255, 185, 120)
		local bulb = light.Parent
		if bulb and bulb:IsA("BasePart") then
			bulb.Color = if hunting then Color3.fromRGB(255, 50, 40) else Color3.fromRGB(255, 200, 140)
		end
	end
end

--------------------------------------------------------------------------------
-- Characters

local function giveFlashlight(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or head:FindFirstChild("Flashlight") then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Range = 45
	light.Angle = 50
	light.Brightness = 3
	light.Shadows = true
	light.Color = Color3.fromRGB(255, 244, 214)
	light.Enabled = false
	light.Parent = head
	character:SetAttribute("FlashlightOn", false)
end

local function becomeMonster(player: Player)
	local character, root, humanoid = characterOf(player)
	if not character or not humanoid then
		return
	end
	local head = character:FindFirstChild("Head")
	local flashlight = head and head:FindFirstChild("Flashlight")
	if flashlight then
		flashlight:Destroy()
	end
	character:SetAttribute("FlashlightOn", nil)
	-- Grow a little taller before going dark.
	pcall(function()
		local desc = humanoid:GetAppliedDescription()
		desc.HeightScale = 1.2
		humanoid:ApplyDescriptionAsync(desc)
	end)
	Rig.monsterize(character)
	humanoid.WalkSpeed = Config.MONSTER_WALK
	if root then
		root.Anchored = false
	end
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 6
	player.CameraMaxZoomDistance = 14
end

local function spawnCFrame(player: Player): CFrame
	local offset = (player.UserId % 5 - 2) * 2.5
	return map.spawn * CFrame.new(offset, 0, 0)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or player.Character ~= character then
		return
	end
	humanoid.Died:Connect(function()
		Hiding.Forget(player)
	end)
	task.defer(function()
		if player.Character ~= character then
			return
		end
		character:PivotTo(spawnCFrame(player))
		if act == "Hunt" or act == "Ending" then
			becomeMonster(player)
		else
			humanoid.WalkSpeed = Config.PLAYER_WALK
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 0.5
			giveFlashlight(character)
		end
	end)
end

local function onCatch(player: Player)
	local now = os.clock()
	if now - (lastCaught[player] or 0) < 3 then
		return
	end
	lastCaught[player] = now
	Hiding.Release(player)
	JumpscareRemote:FireClient(player)
	local myRound = round
	task.delay(1.4, function()
		if round ~= myRound or act ~= "Explore" then
			return
		end
		local character, root = characterOf(player)
		if character and root then
			root.Anchored = false
			character:PivotTo(spawnCFrame(player))
			message(player, "You wake up in the entrance hall again. It let you go. This time.")
		end
	end)
end

--------------------------------------------------------------------------------
-- Act 3

local function finishGame()
	if act ~= "Hunt" then
		return
	end
	act = "Ending"
	local escaped = getNumber("Escaped")
	local ending = if escaped == 0 then "Perfect" elseif escaped <= 2 then "Legend" else "Exposed"
	setState("Act", act)
	setState("Ending", ending)
	setState("Objective", Story.Objectives.Ending)
	lightingForAct(act)
	local myRound = round
	task.delay(2, function()
		if round == myRound then
			EndingRemote:FireAllClients(ending)
		end
	end)
end

local function checkHuntOver()
	if getNumber("Remaining") <= 0 then
		finishGame()
	end
end

local function startHunt()
	act = "Hunt"
	setState("Act", act)
	setState("Objective", Story.Objectives.Hunt)
	setState("Remaining", #Config.SEARCH_PARTY)
	setState("Taken", 0)
	setState("Escaped", 0)
	setState("HuntEndsAt", workspace:GetServerTimeNow() + Config.HUNT_TIME)
	lightingForAct(act)

	-- The front door swings open for the search party.
	local door = map.frontDoor
	door.CanCollide = false
	local prompt = door:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	TweenService:Create(door, TweenInfo.new(1.5), { Transparency = 1 }):Play()

	message(nil, Story.HuntStart)
	SearchParty.Start(map, {
		onTaken = function(name, position, by)
			setState("Taken", getNumber("Taken") + 1)
			setState("Remaining", getNumber("Remaining") - 1)
			TakenRemote:FireAllClients(name, position, by.Name)
			checkHuntOver()
		end,
		onEscaped = function(name)
			setState("Escaped", getNumber("Escaped") + 1)
			setState("Remaining", getNumber("Remaining") - 1)
			message(nil, `{name} made it to the car...`)
			checkHuntOver()
		end,
	})

	local myRound = round
	task.delay(Config.HUNT_TIME, function()
		if round == myRound and act == "Hunt" then
			local remaining = getNumber("Remaining")
			setState("Escaped", getNumber("Escaped") + remaining)
			setState("Remaining", 0)
			message(nil, "Sirens in the distance. The rest of them got out.")
			SearchParty.Stop()
			finishGame()
		end
	end)
end

--------------------------------------------------------------------------------
-- Act 2

local function startReveal()
	if act ~= "Explore" then
		return
	end
	act = "Reveal"
	setState("Act", act)
	setState("Objective", Story.Objectives.Reveal)
	Stalker.Stop()
	Hiding.SetEnabled(false)
	Hiding.SetPromptsEnabled(map, false)

	for i, player in Players:GetPlayers() do
		local character, root = characterOf(player)
		if character and root then
			local spot = map.mirrorStandSpots[((i - 1) % #map.mirrorStandSpots) + 1]
			character:PivotTo(spot)
			root.Anchored = true
		end
	end
	RevealRemote:FireAllClients(map.mirrorPlaneZ, Config.REVEAL_DURATION)

	local myRound = round
	task.delay(Config.REVEAL_DURATION, function()
		-- A new round (restart) is the only thing that can interrupt the reveal.
		if round ~= myRound then
			return
		end
		for _, player in Players:GetPlayers() do
			becomeMonster(player)
		end
		startHunt()
	end)
end

--------------------------------------------------------------------------------
-- Act 1

local function onNote(player: Player, index: number)
	if act ~= "Explore" or notesFound[index] then
		return
	end
	notesFound[index] = true
	local count = noteCount()
	setState("Notes", count)
	Stalker.SetNotes(count)
	NoteRemote:FireAllClients(index, player.DisplayName)

	local paper = map.notes[index]
	local prompt = paper:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	local glow = paper:FindFirstChildOfClass("PointLight")
	if glow then
		glow:Destroy()
	end
	paper.Transparency = 1

	if count >= #Story.Notes then
		setState("Objective", Story.Objectives.MirrorOpen)
		local door = map.mirrorDoor
		door.CanCollide = false
		local doorPrompt = door:FindFirstChildOfClass("ProximityPrompt")
		if doorPrompt then
			doorPrompt.Enabled = false
		end
		for _, d in door:GetDescendants() do
			if d:IsA("BasePart") then
				d:Destroy()
			end
		end
		TweenService:Create(door, TweenInfo.new(2), { Transparency = 1 }):Play()
		task.delay(3, function()
			message(nil, "Somewhere in the house, chains hit the floor.")
		end)
	end
end

local function connectMap()
	for _, c in mapConnections do
		c:Disconnect()
	end
	table.clear(mapConnections)

	for index, paper in map.notes do
		local prompt = paper:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			table.insert(
				mapConnections,
				prompt.Triggered:Connect(function(player)
					onNote(player, index)
				end)
			)
		end
	end

	local mirrorPrompt = map.mirrorDoor:FindFirstChildOfClass("ProximityPrompt")
	if mirrorPrompt then
		table.insert(
			mapConnections,
			mirrorPrompt.Triggered:Connect(function(player)
				message(player, `Chained shut. Something behind it is breathing. ({noteCount()}/{#Story.Notes} notes)`)
			end)
		)
	end
	local frontPrompt = map.frontDoor:FindFirstChildOfClass("ProximityPrompt")
	if frontPrompt then
		table.insert(
			mapConnections,
			frontPrompt.Triggered:Connect(function(player)
				message(player, "Locked. From the outside.")
			end)
		)
	end

	table.insert(
		mapConnections,
		map.revealTrigger.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if player and act == "Explore" and noteCount() >= #Story.Notes then
				startReveal()
			end
		end)
	)
end

local function startRound()
	round += 1
	SearchParty.Stop()
	Stalker.Stop()
	map = MapBuilder.Build()
	Hiding.Setup(map)
	connectMap()
	table.clear(notesFound)

	act = "Explore"
	setState("Act", act)
	setState("Round", round)
	setState("Notes", 0)
	setState("NotesTotal", #Story.Notes)
	setState("Objective", Story.Objectives.Explore)
	setState("Ending", nil)
	setState("Remaining", nil)
	setState("HuntEndsAt", nil)
	lightingForAct(act)

	Stalker.Start(map, { onCatch = onCatch })
end

--------------------------------------------------------------------------------
-- Boot

-- This place is the whole game: clear out the default template pieces.
for _, name in { "Baseplate", "SpawnLocation" } do
	local default = workspace:FindFirstChild(name)
	if default then
		default:Destroy()
	end
end

startRound()

FlashlightRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight") :: SpotLight?
	if character and light then
		light.Enabled = not light.Enabled
		character:SetAttribute("FlashlightOn", light.Enabled)
	end
end)

RestartRemote.OnServerEvent:Connect(function()
	if act ~= "Ending" then
		return
	end
	startRound()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
	end
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.RespawnTime = 2
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	Hiding.Forget(player)
	lastCaught[player] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
