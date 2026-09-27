--!strict
-- Act 1 antagonist: a shadow that patrols the manor, hunts by sight and sound,
-- and drags you out of your hiding spot if it saw you climb in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local Rig = require(script.Parent.Rig)

export type Callbacks = {
	onCatch: (player: Player) -> (),
}

local TICK = 0.15
local FOV_DOT = math.cos(math.rad(65)) -- 130 degree cone
local CLOSE_SENSE = 12 -- always notices you this close, even from behind

local Stalker = {}

local model: Model? = nil
local running = false
local generation = 0
local notesFound = 0
local lastSeen: { [Player]: number } = {}

local function characterParts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root, humanoid
end

local function canSee(self: Model, head: BasePart, character: Model, targetRoot: BasePart, range: number): boolean
	local offset = targetRoot.Position - head.Position
	local distance = offset.Magnitude
	if distance > range then
		return false
	end
	if distance > CLOSE_SENSE then
		local facing = head.CFrame.LookVector
		if facing:Dot(offset.Unit) < FOV_DOT then
			return false
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self }
	local result = workspace:Raycast(head.Position, offset, params)
	return result == nil or result.Instance:IsDescendantOf(character)
end

-- Returns the best visible or audible target, if any.
local function findTarget(self: Model, head: BasePart): (Player?, Vector3?)
	local best: Player? = nil
	local bestPos: Vector3? = nil
	local bestDistance = math.huge
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character, root = characterParts(player)
		if not character or not root or player:GetAttribute("Hidden") or character:GetAttribute("IsMonster") then
			continue
		end
		local distance = (root.Position - head.Position).Magnitude
		local range = Config.STALKER_SIGHT
		if character:GetAttribute("FlashlightOn") then
			range *= Config.STALKER_FLASHLIGHT_SIGHT_BONUS
		end
		local sprinting = root.AssemblyLinearVelocity.Magnitude > Config.PLAYER_WALK + 3
		local noticed = canSee(self, head, character, root, range)
			or (sprinting and distance < Config.STALKER_HEAR_RANGE)
		if noticed then
			lastSeen[player] = now
			if distance < bestDistance then
				best, bestPos, bestDistance = player, root.Position, distance
			end
		end
	end
	return best, bestPos
end

local function farthestWaypoint(map: MapBuilder.Map): Vector3
	local best = map.waypoints[1]
	local bestScore = -1
	for _, point in map.waypoints do
		local closest = math.huge
		for _, player in Players:GetPlayers() do
			local _, root = characterParts(player)
			if root then
				closest = math.min(closest, (root.Position - point).Magnitude)
			end
		end
		if closest > bestScore then
			best, bestScore = point, closest
		end
	end
	return best
end

function Stalker.SetNotes(count: number)
	notesFound = count
end

-- True if the stalker had eyes on this player within the last `seconds`.
function Stalker.SawRecently(player: Player, seconds: number): boolean
	local t = lastSeen[player]
	return t ~= nil and os.clock() - t <= seconds
end

function Stalker.GetModel(): Model?
	return model
end

function Stalker.Stop()
	running = false
	generation += 1
	if model then
		model:Destroy()
		model = nil
	end
	table.clear(lastSeen)
end

function Stalker.Start(map: MapBuilder.Map, callbacks: Callbacks)
	Stalker.Stop()
	running = true
	generation += 1
	local myGeneration = generation

	local stalker = Rig.create("TheThing", {
		skin = Color3.new(0, 0, 0),
		shirt = Color3.new(0, 0, 0),
		pants = Color3.new(0, 0, 0),
	}, 1.25)
	Rig.monsterize(stalker)
	local start = farthestWaypoint(map)
	stalker:PivotTo(CFrame.new(start + Vector3.new(0, 2, 0)))
	stalker.Parent = map.model
	model = stalker

	local humanoid = stalker:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = stalker:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = (stalker:FindFirstChild("Head") or root) :: BasePart
	root:SetNetworkOwner(nil)
	Rig.animate(stalker)
	local nav = Rig.navigator(stalker)

	local activeAt = os.clock() + Config.STALKER_GRACE
	local chasing: Player? = nil
	local lastKnown: Vector3? = nil
	local lastKnownAt = 0
	local patrolTarget: Vector3? = nil
	local patrolWaitUntil = 0
	local restingUntil = 0

	task.spawn(function()
		while running and generation == myGeneration and stalker.Parent do
			task.wait(TICK)
			local now = os.clock()
			if now < activeAt or now < restingUntil then
				stalker:SetAttribute("Chasing", false)
				continue
			end

			local target, targetPos = findTarget(stalker, head)
			local chaseSpeed = Config.STALKER_CHASE_SPEED + notesFound * Config.STALKER_SPEED_PER_NOTE

			-- A player we watched climb into a wardrobe is still fair game.
			if not target and chasing and chasing:GetAttribute("Hidden") and Stalker.SawRecently(chasing, 2) then
				local hideSpot = chasing:GetAttribute("HiddenAt")
				if typeof(hideSpot) == "Vector3" then
					target, targetPos = chasing, hideSpot
					lastSeen[chasing] = now
				end
			end

			if target and targetPos then
				chasing = target
				lastKnown = targetPos
				lastKnownAt = now
				humanoid.WalkSpeed = chaseSpeed
				stalker:SetAttribute("Chasing", true)
				nav:moveTo(targetPos, 0.4)
			elseif lastKnown and now - lastKnownAt < Config.STALKER_LOSE_TIME then
				humanoid.WalkSpeed = chaseSpeed * 0.9
				nav:moveTo(lastKnown, 1)
			else
				chasing = nil
				lastKnown = nil
				stalker:SetAttribute("Chasing", false)
				humanoid.WalkSpeed = Config.STALKER_PATROL_SPEED
				if not patrolTarget or nav:arrived(3) then
					if patrolTarget and patrolWaitUntil == 0 then
						patrolWaitUntil = now + math.random(10, 30) / 10
					end
					if now >= patrolWaitUntil then
						patrolWaitUntil = 0
						patrolTarget = map.waypoints[math.random(1, #map.waypoints)]
						nav:moveTo(patrolTarget :: Vector3, 5)
					end
				end
			end
			nav:step()

			-- Catch anyone in reach (hidden players only if it knows where they are).
			for _, player in Players:GetPlayers() do
				local character, playerRoot = characterParts(player)
				if not character or not playerRoot or character:GetAttribute("IsMonster") then
					continue
				end
				local hidden = player:GetAttribute("Hidden")
				if hidden and not (player == chasing and Stalker.SawRecently(player, 2.5)) then
					continue
				end
				if (playerRoot.Position - root.Position).Magnitude <= Config.STALKER_CATCH_RANGE + (if hidden then 3 else 0) then
					callbacks.onCatch(player)
					chasing = nil
					lastKnown = nil
					lastSeen[player] = nil
					nav:stop()
					restingUntil = now + Config.STALKER_REST_AFTER_CATCH
					stalker:SetAttribute("Chasing", false)
					stalker:PivotTo(CFrame.new(farthestWaypoint(map) + Vector3.new(0, 2, 0)))
					break
				end
			end
		end
	end)
end

return Stalker
