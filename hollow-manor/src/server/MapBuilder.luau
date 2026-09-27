--!strict
-- Builds Hollow Manor from the ASCII floor plan in Config.MAP: walls, floors,
-- furniture, lamps, hiding wardrobes, notes, the mirror (with a mirrored room
-- behind the glass) and the front yard.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)

export type Closet = {
	part: BasePart,
	prompt: ProximityPrompt,
	inside: CFrame,
	front: CFrame,
}

export type Map = {
	model: Model,
	spawn: CFrame,
	waypoints: { Vector3 },
	notes: { [number]: BasePart },
	closets: { Closet },
	lamps: { PointLight },
	mirrorDoor: BasePart,
	frontDoor: BasePart,
	revealTrigger: BasePart,
	mirrorPlaneZ: number,
	mirrorStandSpots: { CFrame },
	yardSpawns: { Vector3 },
	insidePoint: Vector3, -- just inside the front door
	escapePoint: Vector3,
	carSpot: CFrame,
}

local CELL = Config.CELL
local HEIGHT = Config.WALL_HEIGHT
local ORIGIN = Config.ORIGIN

local WALL_COLOR = Color3.fromRGB(58, 48, 44)
local WOOD_COLOR = Color3.fromRGB(62, 40, 28)
local DARK_WOOD = Color3.fromRGB(38, 25, 18)

local MapBuilder = {}

local rows: { string } = {}
for line in Config.MAP:gmatch("[^\n]+") do
	table.insert(rows, line)
end
local ROW_COUNT = #rows
local COL_COUNT = #rows[1]
for i, line in rows do
	assert(#line == COL_COUNT, `Config.MAP row {i} is {#line} wide, expected {COL_COUNT}`)
end

-- Rows and columns are 0-based to match the map comments.
local function cellAt(r: number, c: number): string
	local line = rows[r + 1]
	if not line or c < 0 or c >= COL_COUNT then
		return "#"
	end
	return line:sub(c + 1, c + 1)
end

local function cellCenter(r: number, c: number): Vector3
	return ORIGIN + Vector3.new((c + 0.5) * CELL, 0, (r + 0.5) * CELL)
end

local function inMirrorRoom(r: number, c: number): boolean
	local room = Config.MIRROR_ROOM
	return r >= room.rowMin and r <= room.rowMax and c >= room.colMin and c <= room.colMax
end

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function decor(parent: Instance, props: { [string]: any }): BasePart
	props.CanCollide = if props.CanCollide == nil then false else props.CanCollide
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	return part(parent, props)
end

-- Direction (unit vector on XZ) toward the closest wall within two cells.
local function wallDirection(r: number, c: number): Vector3
	local dirs = {
		{ dr = -1, dc = 0, v = Vector3.new(0, 0, -1) },
		{ dr = 1, dc = 0, v = Vector3.new(0, 0, 1) },
		{ dr = 0, dc = -1, v = Vector3.new(-1, 0, 0) },
		{ dr = 0, dc = 1, v = Vector3.new(1, 0, 0) },
	}
	for distance = 1, 2 do
		for _, d in dirs do
			if cellAt(r + d.dr * distance, c + d.dc * distance) == "#" then
				return d.v
			end
		end
	end
	return Vector3.new(0, 0, -1)
end

-- Horizontal runs of `kind` in one row become a single wall part.
local function buildWallRuns(parent: Instance, rowText: string, r: number, zOverride: number?)
	local c = 0
	while c < COL_COUNT do
		if rowText:sub(c + 1, c + 1) == "#" then
			local start = c
			while c < COL_COUNT and rowText:sub(c + 1, c + 1) == "#" do
				c += 1
			end
			local length = (c - start) * CELL
			local z = zOverride or (ORIGIN.Z + (r + 0.5) * CELL)
			part(parent, {
				Name = "Wall",
				Size = Vector3.new(length, HEIGHT, CELL),
				CFrame = CFrame.new(ORIGIN.X + start * CELL + length / 2, ORIGIN.Y + HEIGHT / 2, z),
				Color = WALL_COLOR,
				Material = Enum.Material.Plaster,
			})
		else
			c += 1
		end
	end
end

local function buildLamp(parent: Instance, position: Vector3, lamps: { PointLight })
	local bulb = decor(parent, {
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, HEIGHT - 2.5, 0)),
		Color = Color3.fromRGB(255, 200, 140),
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	decor(parent, {
		Name = "Cord",
		Size = Vector3.new(0.1, 1.9, 0.1),
		CFrame = CFrame.new(position + Vector3.new(0, HEIGHT - 0.95, 0)),
		Color = Color3.fromRGB(20, 20, 20),
	})
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 0.9
	light.Color = Color3.fromRGB(255, 185, 120)
	light.Shadows = true
	light.Parent = bulb
	CollectionService:AddTag(bulb, "FlickerLamp")
	table.insert(lamps, light)

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 230, 200))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new(0.08)
	dust.Rate = 3
	dust.Lifetime = NumberRange.new(5, 8)
	dust.Speed = NumberRange.new(0.2, 0.6)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.LightEmission = 0.3
	dust.Parent = bulb
end

local function buildTable(parent: Instance, position: Vector3)
	local top = position + Vector3.new(0, 3, 0)
	part(parent, {
		Name = "Table",
		Size = Vector3.new(4, 0.4, 3),
		CFrame = CFrame.new(top),
		Color = WOOD_COLOR,
		Material = Enum.Material.Wood,
	})
	for _, offset in { Vector3.new(1.7, 0, 1.2), Vector3.new(-1.7, 0, 1.2), Vector3.new(1.7, 0, -1.2), Vector3.new(-1.7, 0, -1.2) } do
		part(parent, {
			Name = "Leg",
			Size = Vector3.new(0.3, 2.8, 0.3),
			CFrame = CFrame.new(position + offset + Vector3.new(0, 1.4, 0)),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		})
	end
	-- A candle that barely helps.
	local candle = decor(parent, {
		Name = "Candle",
		Size = Vector3.new(0.3, 0.8, 0.3),
		CFrame = CFrame.new(top + Vector3.new(0.8, 0.6, 0)),
		Color = Color3.fromRGB(235, 225, 200),
	})
	local flame = Instance.new("PointLight")
	flame.Range = 7
	flame.Brightness = 0.6
	flame.Color = Color3.fromRGB(255, 150, 60)
	flame.Parent = candle
	local fire = Instance.new("Fire")
	fire.Size = 1
	fire.Heat = 1
	fire.Parent = candle
end

local function buildBookshelf(parent: Instance, position: Vector3, back: Vector3)
	local cf = CFrame.lookAt(position + back * (CELL / 2 - 0.9) + Vector3.new(0, 5, 0), position - back * 10 + Vector3.new(0, 5, 0))
	part(parent, {
		Name = "Bookshelf",
		Size = Vector3.new(4.4, 10, 1.6),
		CFrame = cf,
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	})
	local rng = Random.new(math.floor(position.X * 7 + position.Z * 13))
	for shelf = 0, 3 do
		local x = -1.9
		while x < 1.7 do
			local w = rng:NextNumber(0.25, 0.45)
			local h = rng:NextNumber(1.2, 1.9)
			decor(parent, {
				Name = "Book",
				Size = Vector3.new(w, h, 1.2),
				CFrame = cf * CFrame.new(x + w / 2, -3.8 + shelf * 2.4 + h / 2, -0.25),
				Color = Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0.3, 0.7), rng:NextNumber(0.15, 0.4)),
				CastShadow = false,
			})
			x += w + 0.05
		end
	end
end

local function buildBed(parent: Instance, position: Vector3)
	part(parent, {
		Name = "Bed",
		Size = Vector3.new(4.5, 1.6, 7),
		CFrame = CFrame.new(position + Vector3.new(0, 0.8, 0)),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	})
	decor(parent, {
		Name = "Sheets",
		Size = Vector3.new(4.3, 0.6, 5.6),
		CFrame = CFrame.new(position + Vector3.new(0, 1.9, 0.6)),
		Color = Color3.fromRGB(150, 140, 130),
		Material = Enum.Material.Fabric,
	})
	decor(parent, {
		Name = "Pillow",
		Size = Vector3.new(3, 0.6, 1.1),
		CFrame = CFrame.new(position + Vector3.new(0, 1.9, -2.8)),
		Color = Color3.fromRGB(200, 195, 185),
		Material = Enum.Material.Fabric,
	})
end

local function buildCloset(parent: Instance, position: Vector3, back: Vector3, closets: { Closet })
	local depth = 3.5
	local center = position + back * (CELL / 2 - depth / 2) + Vector3.new(0, 4.5, 0)
	local cf = CFrame.lookAt(center, center - back)
	local wardrobe = part(parent, {
		Name = "Wardrobe",
		Size = Vector3.new(4.2, 9, depth),
		CFrame = cf,
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	})
	-- Door seam + handles, purely visual.
	decor(parent, {
		Name = "Seam",
		Size = Vector3.new(0.08, 8.4, 0.1),
		CFrame = cf * CFrame.new(0, 0, -depth / 2 - 0.02),
		Color = Color3.fromRGB(15, 10, 8),
	})
	for _, x in { -0.35, 0.35 } do
		decor(parent, {
			Name = "Handle",
			Size = Vector3.new(0.15, 0.6, 0.15),
			CFrame = cf * CFrame.new(x, 0, -depth / 2 - 0.1),
			Color = Color3.fromRGB(150, 120, 60),
			Material = Enum.Material.Metal,
		})
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hide"
	prompt.ObjectText = "Wardrobe"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = wardrobe

	local groundFront = Vector3.new(center.X, ORIGIN.Y + 3, center.Z) - back * (depth / 2 + 2.5)
	table.insert(closets, {
		part = wardrobe,
		prompt = prompt,
		inside = CFrame.lookAt(Vector3.new(center.X, ORIGIN.Y + 3, center.Z), groundFront),
		front = CFrame.lookAt(groundFront, groundFront - back),
	})
end

local function buildNote(parent: Instance, position: Vector3, index: number): BasePart
	local note = Story.Notes[index]
	decor(parent, {
		Name = "NoteStand",
		Size = Vector3.new(1.6, 3, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
		CanCollide = true,
	})
	local paper = part(parent, {
		Name = "Note" .. index,
		Size = Vector3.new(1.1, 0.05, 1.5),
		CFrame = CFrame.new(position + Vector3.new(0, 3.05, 0)) * CFrame.Angles(0, math.rad(15 * index), 0),
		Color = Color3.fromRGB(230, 220, 190),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	paper:SetAttribute("NoteIndex", index)
	local glow = Instance.new("PointLight")
	glow.Range = 6
	glow.Brightness = 0.7
	glow.Color = Color3.fromRGB(255, 230, 170)
	glow.Parent = paper

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read"
	prompt.ObjectText = note.title
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = paper
	return paper
end

local function buildDoor(parent: Instance, cells: { Vector3 }, name: string, color: Color3): BasePart
	local sum = Vector3.zero
	for _, p in cells do
		sum += p
	end
	local center = sum / #cells
	local door = part(parent, {
		Name = name,
		Size = Vector3.new(CELL * #cells, HEIGHT, 1),
		CFrame = CFrame.new(center + Vector3.new(0, HEIGHT / 2, 0)),
		Color = color,
		Material = Enum.Material.Wood,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = name
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = door
	return door
end

local function buildYard(parent: Instance, doorCells: { Vector3 }): (Vector3, Vector3, { Vector3 }, CFrame)
	local doorCenter = (doorCells[1] + doorCells[#doorCells]) / 2
	local yardTop = ORIGIN.Z + ROW_COUNT * CELL
	local yardDepth = 9 * CELL
	local minX = ORIGIN.X + 11 * CELL
	local maxX = ORIGIN.X + 25 * CELL

	-- Fence around the yard (the east side is the reflection room's wall).
	local fenceHeight = 7
	local function fence(from: Vector3, to: Vector3)
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		part(parent, {
			Name = "Fence",
			Size = Vector3.new(0.6, fenceHeight, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, fenceHeight / 2, 0), to + Vector3.new(0, fenceHeight / 2, 0)),
			Color = Color3.fromRGB(25, 25, 28),
			Material = Enum.Material.Metal,
		})
		-- Invisible barrier so nobody climbs out.
		part(parent, {
			Name = "Barrier",
			Size = Vector3.new(0.6, 60, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 30, 0), to + Vector3.new(0, 30, 0)),
			Transparency = 1,
			CanQuery = false,
		})
	end
	local y = ORIGIN.Y
	local south = yardTop + yardDepth
	fence(Vector3.new(minX, y, yardTop), Vector3.new(minX, y, south))
	fence(Vector3.new(minX, y, south), Vector3.new(maxX, y, south))
	fence(Vector3.new(maxX, y, south), Vector3.new(maxX, y, yardTop))

	-- Stone path from the door to the road.
	part(parent, {
		Name = "Path",
		Size = Vector3.new(CELL * 2, 0.2, yardDepth),
		CFrame = CFrame.new(doorCenter.X, y + 0.05, yardTop + yardDepth / 2),
		Color = Color3.fromRGB(70, 70, 75),
		Material = Enum.Material.Cobblestone,
	})

	-- Dead trees.
	local rng = Random.new(1014)
	for _ = 1, 5 do
		local x = rng:NextNumber(minX + 4, maxX - 4)
		if math.abs(x - doorCenter.X) < CELL * 1.5 then
			x = doorCenter.X + (if x < doorCenter.X then -1 else 1) * CELL * 2
		end
		local base = Vector3.new(x, y, rng:NextNumber(yardTop + 8, south - 10))
		local trunkHeight = rng:NextNumber(12, 18)
		part(parent, {
			Name = "DeadTree",
			Size = Vector3.new(1.4, trunkHeight, 1.4),
			CFrame = CFrame.new(base + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))),
			Color = Color3.fromRGB(35, 28, 24),
			Material = Enum.Material.Wood,
		})
		for _ = 1, 3 do
			local h = rng:NextNumber(trunkHeight * 0.5, trunkHeight * 0.9)
			decor(parent, {
				Name = "Branch",
				Size = Vector3.new(0.5, 6, 0.5),
				CFrame = CFrame.new(base + Vector3.new(0, h, 0))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					* CFrame.Angles(math.rad(rng:NextNumber(35, 60)), 0, 0)
					* CFrame.new(0, 3, 0),
				Color = Color3.fromRGB(35, 28, 24),
				Material = Enum.Material.Wood,
			})
		end
	end

	local insidePoint = doorCenter - Vector3.new(0, 0, CELL * 2)
	local escapePoint = Vector3.new(doorCenter.X, y, south - 6)
	local spawns = {}
	for i = 1, #Config.SEARCH_PARTY do
		table.insert(spawns, Vector3.new(doorCenter.X + (i - 3) * 3, y + 3, south - 12))
	end
	local carSpot = CFrame.new(minX + 9, y, south - 9)
	return insidePoint, escapePoint, spawns, carSpot
end

function MapBuilder.Build(): Map
	local old = workspace:FindFirstChild("HollowManor")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "HollowManor"
	-- Always fully streamed so AI paths and teleports never hit unloaded parts.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = workspace

	local structure = Instance.new("Folder")
	structure.Name = "Structure"
	structure.Parent = model
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = model

	local width = COL_COUNT * CELL
	local depth = ROW_COUNT * CELL

	-- Ground, manor floor, ceiling (the ceiling also covers the reflection room).
	part(structure, {
		Name = "Ground",
		Size = Vector3.new(800, 2, 800),
		CFrame = CFrame.new(ORIGIN + Vector3.new(width / 2, -1.1, depth / 2)),
		Color = Color3.fromRGB(28, 34, 24),
		Material = Enum.Material.Grass,
	})
	part(structure, {
		Name = "Floor",
		Size = Vector3.new(width, 1, depth),
		CFrame = CFrame.new(ORIGIN + Vector3.new(width / 2, -0.5, depth / 2)),
		Color = Color3.fromRGB(60, 42, 30),
		Material = Enum.Material.WoodPlanks,
	})
	part(structure, {
		Name = "Ceiling",
		Size = Vector3.new(width, 1, depth),
		CFrame = CFrame.new(ORIGIN + Vector3.new(width / 2, HEIGHT + 0.5, depth / 2)),
		Color = Color3.fromRGB(30, 26, 24),
		Material = Enum.Material.Wood,
	})

	local map = {
		model = model,
		waypoints = {},
		notes = {},
		closets = {},
		lamps = {},
		mirrorStandSpots = {},
	} :: any

	local lockedCells, doorCells, glassCells = {}, {}, {}

	for r = 0, ROW_COUNT - 1 do
		buildWallRuns(structure, rows[r + 1], r)
		for c = 0, COL_COUNT - 1 do
			local kind = cellAt(r, c)
			local pos = cellCenter(r, c)
			local mirrorRoom = inMirrorRoom(r, c)
			if kind == "S" then
				local p = pos + Vector3.new(0, 3, 0)
				map.spawn = CFrame.lookAt(p, p + Vector3.new(0, 0, -1))
			elseif kind == "K" then
				buildLamp(props, pos, map.lamps)
				if not mirrorRoom then
					table.insert(map.waypoints, pos + Vector3.new(0, 3, 0))
				end
			elseif kind == "P" then
				table.insert(map.waypoints, pos + Vector3.new(0, 3, 0))
			elseif kind == "T" then
				buildTable(props, pos)
			elseif kind == "B" then
				buildBookshelf(props, pos, wallDirection(r, c))
			elseif kind == "R" then
				buildBed(props, pos)
			elseif kind == "C" then
				buildCloset(props, pos, wallDirection(r, c), map.closets)
			elseif kind == "L" then
				table.insert(lockedCells, pos)
			elseif kind == "E" then
				table.insert(doorCells, pos)
			elseif kind == "G" then
				table.insert(glassCells, pos)
			elseif kind == "X" then
				map.revealTrigger = part(structure, {
					Name = "RevealTrigger",
					Size = Vector3.new(CELL * 3, 8, CELL * 3),
					CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)),
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
				})
			elseif tonumber(kind) then
				local index = tonumber(kind) :: number
				map.notes[index] = buildNote(props, pos, index)
				table.insert(map.waypoints, pos + Vector3.new(0, 3, 0))
			end
		end
	end

	map.mirrorDoor = buildDoor(structure, lockedCells, "Mirror Room", Color3.fromRGB(45, 20, 20))
	map.frontDoor = buildDoor(structure, doorCells, "Front Door", Color3.fromRGB(50, 34, 24))
	-- Chains on the mirror room door sell that it's locked.
	for _, angle in { 25, -25 } do
		decor(map.mirrorDoor, {
			Name = "Chain",
			Size = Vector3.new(CELL * 2.2, 0.4, 0.3),
			CFrame = map.mirrorDoor.CFrame * CFrame.new(0, 0, -0.7) * CFrame.Angles(0, 0, math.rad(angle)),
			Color = Color3.fromRGB(90, 90, 95),
			Material = Enum.Material.DiamondPlate,
		})
	end

	-- The mirror sits on the centre line of its wall row; everything in the
	-- mirror room is copied to the far side so the glass has depth.
	local glassRow = ROW_COUNT - 1
	local planeZ = ORIGIN.Z + (glassRow + 0.5) * CELL
	map.mirrorPlaneZ = planeZ
	local glassMin, glassMax = math.huge, -math.huge
	for _, p in glassCells do
		glassMin = math.min(glassMin, p.X - CELL / 2)
		glassMax = math.max(glassMax, p.X + CELL / 2)
	end
	local glassCenterX = (glassMin + glassMax) / 2
	part(structure, {
		Name = "Mirror",
		Size = Vector3.new(glassMax - glassMin, HEIGHT - 2, 0.2),
		CFrame = CFrame.new(glassCenterX, ORIGIN.Y + HEIGHT / 2, planeZ),
		Color = Color3.fromRGB(160, 175, 190),
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Reflectance = 0.25,
		CastShadow = false,
	})
	for _, x in { glassMin, glassMax } do
		part(structure, {
			Name = "MirrorFrame",
			Size = Vector3.new(0.8, HEIGHT, CELL),
			CFrame = CFrame.new(x, ORIGIN.Y + HEIGHT / 2, planeZ),
			Color = Color3.fromRGB(110, 85, 40),
			Material = Enum.Material.Metal,
		})
	end
	local reflection = Instance.new("Folder")
	reflection.Name = "Reflection"
	reflection.Parent = model
	local room = Config.MIRROR_ROOM
	local reflectionFloorDepth = (room.rowMax - room.rowMin + 1) * CELL
	part(reflection, {
		Name = "ReflectionFloor",
		Size = Vector3.new((room.colMax - room.colMin + 1) * CELL, 1, reflectionFloorDepth + CELL / 2),
		CFrame = CFrame.new(
			ORIGIN.X + (room.colMin + room.colMax + 1) / 2 * CELL,
			ORIGIN.Y - 0.5,
			planeZ + (reflectionFloorDepth + CELL / 2) / 2
		),
		Color = Color3.fromRGB(60, 42, 30),
		Material = Enum.Material.WoodPlanks,
	})
	part(reflection, {
		Name = "ReflectionCeiling",
		Size = Vector3.new((room.colMax - room.colMin + 1) * CELL, 1, reflectionFloorDepth + CELL / 2),
		CFrame = CFrame.new(
			ORIGIN.X + (room.colMin + room.colMax + 1) / 2 * CELL,
			ORIGIN.Y + HEIGHT + 0.5,
			planeZ + (reflectionFloorDepth + CELL / 2) / 2
		),
		Color = Color3.fromRGB(30, 26, 24),
		Material = Enum.Material.Wood,
	})
	for r = room.rowMin, room.rowMax do
		local mirroredZ = 2 * planeZ - (ORIGIN.Z + (r + 0.5) * CELL)
		local text = {}
		for c = 0, COL_COUNT - 1 do
			local kind = cellAt(r, c)
			local inside = c >= room.colMin and c <= room.colMax
			table.insert(text, if inside and (kind == "#" or kind == "L") then "#" else ".")
			if inside and kind == "K" then
				buildLamp(reflection, Vector3.new(ORIGIN.X + (c + 0.5) * CELL, ORIGIN.Y, mirroredZ), map.lamps)
			end
		end
		buildWallRuns(reflection, table.concat(text), r, mirroredZ)
	end

	local revealPos = map.revealTrigger.Position
	for i = 1, 4 do
		local spot = Vector3.new(glassCenterX + (i - 2.5) * 3.5, ORIGIN.Y + 3, planeZ - 9)
		table.insert(map.mirrorStandSpots, CFrame.lookAt(spot, Vector3.new(spot.X, spot.Y, planeZ)))
	end
	assert(revealPos, "map needs an X cell")

	local yard = Instance.new("Folder")
	yard.Name = "Yard"
	yard.Parent = model
	map.insidePoint, map.escapePoint, map.yardSpawns, map.carSpot = buildYard(yard, doorCells)

	assert(map.spawn, "map needs an S cell")
	for i = 1, #Story.Notes do
		assert(map.notes[i], `map is missing note {i}`)
	end
	return map :: Map
end

return MapBuilder
