--!strict
-- Obstacle generators. Each generator receives the build context and the
-- point (top surface, near edge) where the section starts, builds its parts
-- heading toward +Z, and returns the point where the next checkpoint pad
-- should begin.

local TweenService = game:GetService("TweenService")

export type Context = {
	rng: Random,
	difficulty: number, -- 0 at the first stage, 1 at the last
	platform: (size: Vector3, cframe: CFrame) -> BasePart,
	hazard: (size: Vector3, cframe: CFrame) -> BasePart,
	coin: (position: Vector3) -> (),
	folder: Instance,
}

export type Generator = (ctx: Context, start: Vector3) -> Vector3

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Center a part of `size` so its top surface sits at `topCenter`.
local function topAt(topCenter: Vector3, size: Vector3): CFrame
	return CFrame.new(topCenter - Vector3.new(0, size.Y / 2, 0))
end

local Obstacles: { [string]: Generator } = {}

-- Classic hops between floating platforms that shrink as difficulty rises.
Obstacles.Jumps = function(ctx, start)
	local d = ctx.difficulty
	local count = 4 + math.floor(d * 3)
	local pos = start
	for i = 1, count do
		-- Base jump covers ~8 studs flat, so keep the hardest gaps just under that.
		local gap = lerp(3, 6, d) + ctx.rng:NextNumber(0, 1)
		local width = lerp(8, 4, d)
		local rise = ctx.rng:NextInteger(-1, 1)
		local sideways = ctx.rng:NextNumber(-4, 4)
		local size = Vector3.new(width, 1, width)
		local top = Vector3.new(start.X + sideways, pos.Y + rise, pos.Z + gap + width / 2)
		ctx.platform(size, topAt(top, size))
		if i % 2 == 0 then
			ctx.coin(top + Vector3.new(0, 3, 0))
		end
		pos = Vector3.new(top.X, top.Y, top.Z + width / 2)
	end
	return pos + Vector3.new(0, 0, lerp(3, 6, d))
end

-- A walkway crossed by glowing kill strips you have to hop over.
Obstacles.LavaStrips = function(ctx, start)
	local d = ctx.difficulty
	local length = 44
	local width = 10
	local floorSize = Vector3.new(width, 1, length)
	ctx.platform(floorSize, topAt(start + Vector3.new(0, 0, length / 2), floorSize))

	local z = 6
	while z < length - 5 do
		local depth = lerp(2, 4.5, d) + ctx.rng:NextNumber(0, 1)
		local stripSize = Vector3.new(width, 1, depth)
		ctx.hazard(stripSize, CFrame.new(start + Vector3.new(0, 0.5, z + depth / 2)))
		ctx.coin(start + Vector3.new(ctx.rng:NextNumber(-3, 3), 5, z + depth / 2))
		z += depth + lerp(7, 4.5, d) + ctx.rng:NextNumber(0, 1.5)
	end
	return start + Vector3.new(0, 0, length)
end

-- Narrow zig-zagging beams.
Obstacles.Tightrope = function(ctx, start)
	local d = ctx.difficulty
	local beamWidth = lerp(3, 1.2, d)
	local segments = 3 + math.floor(d * 2)
	local pos = start
	local direction = if ctx.rng:NextNumber() < 0.5 then -1 else 1
	for i = 1, segments do
		local length = ctx.rng:NextNumber(12, 18)
		local sideways = direction * ctx.rng:NextNumber(4, 7)
		local from = pos
		local to = Vector3.new(start.X + sideways, pos.Y, pos.Z + length)
		local mid = (from + to) / 2
		local span = (to - from).Magnitude
		local size = Vector3.new(beamWidth, 1, span + beamWidth)
		local cframe = CFrame.lookAt(mid, to) * CFrame.new(0, -0.5, 0)
		ctx.platform(size, cframe)
		-- A small pad at every corner so turns are fair.
		local padSize = Vector3.new(beamWidth + 1.5, 1, beamWidth + 1.5)
		ctx.platform(padSize, topAt(to, padSize))
		if i % 2 == 1 then
			ctx.coin(mid + Vector3.new(0, 3, 0))
		end
		pos = to
		direction = -direction
	end
	return Vector3.new(pos.X, pos.Y, pos.Z + 4)
end

-- Platforms that slide side to side over the void. Physics-driven via a
-- PrismaticConstraint servo so players are carried along naturally.
Obstacles.MovingPlatforms = function(ctx, start)
	local d = ctx.difficulty
	local count = 3 + math.floor(d * 2)
	local range = lerp(8, 14, d)
	local speed = lerp(5, 11, d)
	local gap = lerp(3, 5.5, d)
	local size = Vector3.new(7, 1, 7)

	local z = start.Z - size.Z / 2
	for i = 1, count do
		z += size.Z + gap
		local center = Vector3.new(start.X, start.Y - 0.5, z)

		local anchor = Instance.new("Part")
		anchor.Name = "SliderAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.new(center)
		anchor.Parent = ctx.folder

		local platform = ctx.platform(size, CFrame.new(center))
		platform.Name = "MovingPlatform"
		platform.Anchored = false

		local a0 = Instance.new("Attachment")
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Parent = platform

		local slider = Instance.new("PrismaticConstraint")
		slider.Attachment0 = a0
		slider.Attachment1 = a1
		slider.ActuatorType = Enum.ActuatorType.Servo
		slider.ServoMaxForce = 1e8
		slider.Speed = speed
		slider.LinearResponsiveness = 60
		slider.Parent = platform

		platform:SetNetworkOwner(nil)

		-- Offset phase so neighbouring platforms don't line up perfectly.
		local side = if i % 2 == 0 then 1 else -1
		task.spawn(function()
			local travelTime = range / speed
			while platform.Parent do
				slider.TargetPosition = side * range / 2
				task.wait(travelTime + 0.6)
				side = -side
			end
		end)

		ctx.coin(center + Vector3.new(0, 3.5, 0))
	end
	return Vector3.new(start.X, start.Y, z + size.Z / 2 + gap)
end

-- Spinning neon bars sweeping across a walkway.
Obstacles.Spinners = function(ctx, start)
	local d = ctx.difficulty
	local width = 12
	local spinnerCount = if d > 0.45 then 3 else 2
	local gap = 14
	local length = gap * (spinnerCount + 1)
	local floorSize = Vector3.new(width, 1, length)
	ctx.platform(floorSize, topAt(start + Vector3.new(0, 0, length / 2), floorSize))

	for i = 1, spinnerCount do
		local center = start + Vector3.new(0, 1.5, gap * i)

		local hub = Instance.new("Part")
		hub.Name = "SpinnerHub"
		hub.Anchored = true
		hub.CanCollide = false
		hub.CanTouch = false
		hub.Shape = Enum.PartType.Cylinder
		hub.Material = Enum.Material.Metal
		hub.Color = Color3.fromRGB(60, 60, 70)
		hub.Size = Vector3.new(3, 2, 2)
		hub.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
		hub.Parent = ctx.folder

		local bar = ctx.hazard(Vector3.new(width - 1, 1, 1), CFrame.new(center))
		bar.Name = "SpinnerBar"
		bar.Anchored = false
		bar.CanCollide = false
		bar.Massless = true

		-- Attachments rotated so their primary (X) axis points up.
		local upright = CFrame.Angles(0, 0, math.rad(90))
		local a0 = Instance.new("Attachment")
		a0.CFrame = hub.CFrame:ToObjectSpace(CFrame.new(center) * upright)
		a0.Parent = hub
		local a1 = Instance.new("Attachment")
		a1.CFrame = upright
		a1.Parent = bar

		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment0 = a0
		hinge.Attachment1 = a1
		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.MotorMaxTorque = 1e9
		hinge.MotorMaxAcceleration = math.huge
		hinge.AngularVelocity = lerp(1.6, 3.6, d) * (if i % 2 == 0 then -1 else 1)
		hinge.Parent = bar

		bar:SetNetworkOwner(nil)

		ctx.coin(center + Vector3.new(0, 5, 0))
	end
	return start + Vector3.new(0, 0, length)
end

-- Platforms that crumble a moment after you step on them.
Obstacles.Crumbling = function(ctx, start)
	local d = ctx.difficulty
	local count = 5 + math.floor(d * 3)
	local fadeTime = lerp(1.2, 0.45, d)
	local size = Vector3.new(6, 1, 6)
	local pos = start
	for i = 1, count do
		local gap = lerp(3, 6, d)
		local top = Vector3.new(start.X + ctx.rng:NextNumber(-3, 3), pos.Y, pos.Z + gap + size.Z / 2)
		local platform = ctx.platform(size, topAt(top, size))
		platform.Name = "CrumblingPlatform"
		platform.Material = Enum.Material.Slate
		local baseColor = platform.Color

		local crumbling = false
		platform.Touched:Connect(function(hit)
			if crumbling then
				return
			end
			local model = hit:FindFirstAncestorOfClass("Model")
			if not model or not model:FindFirstChildOfClass("Humanoid") then
				return
			end
			crumbling = true
			platform.Color = Color3.fromRGB(255, 170, 90)
			local fade = TweenService:Create(platform, TweenInfo.new(fadeTime), { Transparency = 0.85 })
			fade:Play()
			fade.Completed:Wait()
			platform.CanCollide = false
			platform.Transparency = 1
			task.wait(3)
			platform.CanCollide = true
			platform.Transparency = 0
			platform.Color = baseColor
			crumbling = false
		end)

		if i % 3 == 0 then
			ctx.coin(top + Vector3.new(0, 3, 0))
		end
		pos = Vector3.new(top.X, top.Y, top.Z + size.Z / 2)
	end
	return Vector3.new(pos.X, pos.Y, pos.Z + 4)
end

-- Climb truss towers, hopping between ledges on the way up.
Obstacles.Tower = function(ctx, start)
	local d = ctx.difficulty
	local levels = 2 + math.floor(d * 2)
	local pos = start
	for level = 1, levels do
		local height = 2 * math.floor(lerp(6, 9, d) + ctx.rng:NextNumber(0, 2))
		local truss = Instance.new("TrussPart")
		truss.Name = "Truss"
		truss.Anchored = true
		truss.Size = Vector3.new(2, height, 2)
		truss.Color = Color3.fromRGB(200, 200, 210)
		truss.CFrame = CFrame.new(pos.X, pos.Y + height / 2, pos.Z + 1)
		truss.Parent = ctx.folder

		local ledgeTop = Vector3.new(pos.X, pos.Y + height, pos.Z + 2)
		local ledgeSize = Vector3.new(8, 1, 7)
		ctx.platform(ledgeSize, topAt(ledgeTop + Vector3.new(0, 0, ledgeSize.Z / 2), ledgeSize))
		ctx.coin(ledgeTop + Vector3.new(0, 3, ledgeSize.Z / 2))

		pos = ledgeTop + Vector3.new(0, 0, ledgeSize.Z)
		if level < levels then
			-- Short hop over to the next tower's base.
			local hop = lerp(3, 6, d)
			local baseSize = Vector3.new(6, 1, 4)
			local baseTop = pos + Vector3.new(ctx.rng:NextNumber(-3, 3), 0, hop + baseSize.Z / 2)
			ctx.platform(baseSize, topAt(baseTop, baseSize))
			pos = baseTop + Vector3.new(0, 0, baseSize.Z / 2 - 2)
		end
	end
	return pos + Vector3.new(0, 0, 4)
end

return Obstacles
