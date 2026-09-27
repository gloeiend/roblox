--!strict
-- Tuning for Hollow Manor. Change numbers here, not in the scripts.

local Config = {}

-- Map
Config.CELL = 5 -- studs per map character
Config.WALL_HEIGHT = 14
Config.ORIGIN = Vector3.new(0, 0, 0)

-- Floor plan, one character per cell. North is the top row (-Z).
--   #  wall            .  floor           S  player spawn
--   1-5 memory notes    C  wardrobe (hide) K  ceiling lamp
--   P  patrol point     T  table           B  bookshelf
--   R  bed              L  mirror-room door (locked until all notes are found)
--   X  reveal trigger   G  the mirror      E  front door (to the yard)
Config.MAP = [[
##############################################
#B.B.B.B.B.#...........#.......#.............#
#..........#.T.......T.#.R...C.#.B..........C#
#....K.....#...........#.......#.............#
#..........#....K......#...K...#......K......#
#.1........#.T.......T.#...3...#..T.....2....#
#..........#...........#.......#.............#
#..C.................................P.......#
#............................................#
#.P........#.......P...#.......#.........T...#
#####..#######..###########..##########..#####
#............................................#
#...K...P..........K..........P.........K....#
#............................................#
#####..###########..########LL#########..#####
#.........#..............#..........#........#
#..T...C..#..............#....K.....#.R......#
#....K....#.......K......#..........#........#
#.........#..............#......X...#....K...#
#....4....#......S.......#..........#......5.#
#.P.......#..............#..........#.C......#
#.........#..............#..........#.......P#
#######################EE######GGGG###########
]]

-- The mirror room, in cell coordinates (inclusive), is copied behind the glass
-- so the reflection has a room to live in.
Config.MIRROR_ROOM = { rowMin = 14, rowMax = 21, colMin = 25, colMax = 36 }

-- Movement
Config.PLAYER_WALK = 12
Config.PLAYER_SPRINT = 20
Config.MONSTER_WALK = 18
Config.MONSTER_SPRINT = 27
Config.STAMINA_SECONDS = 5 -- sprint time from full
Config.STAMINA_REGEN_SECONDS = 7 -- time to refill from empty

-- Act 1: the stalker
Config.STALKER_GRACE = 25 -- seconds before it starts hunting
Config.STALKER_PATROL_SPEED = 8
Config.STALKER_CHASE_SPEED = 16.5
Config.STALKER_SPEED_PER_NOTE = 0.6
Config.STALKER_SIGHT = 50
Config.STALKER_FLASHLIGHT_SIGHT_BONUS = 1.4 -- your light makes you easier to spot
Config.STALKER_HEAR_RANGE = 22 -- sprinting players are heard through walls
Config.STALKER_CATCH_RANGE = 4
Config.STALKER_LOSE_TIME = 4
Config.STALKER_REST_AFTER_CATCH = 8

-- Act 2
Config.REVEAL_DURATION = 16

-- Act 3: the hunt
Config.HUNT_TIME = 300
Config.PARTY_WALK = 9
Config.PARTY_FLEE = 16
Config.PARTY_SIGHT = 42
Config.PARTY_CALM_DOWN = 10 -- seconds without seeing you before a survivor stops fleeing
Config.TAKE_RANGE = 5
Config.HUNTER_SENSE_DURATION = 4
Config.HUNTER_SENSE_COOLDOWN = 15

Config.SEARCH_PARTY = {
	{ name = "Deputy Ruiz", shirt = Color3.fromRGB(40, 60, 110), pants = Color3.fromRGB(30, 30, 40), skin = Color3.fromRGB(198, 140, 100) },
	{ name = "Sheriff Hale", shirt = Color3.fromRGB(120, 90, 50), pants = Color3.fromRGB(50, 40, 30), skin = Color3.fromRGB(234, 184, 146) },
	{ name = "Nora (reporter)", shirt = Color3.fromRGB(150, 40, 50), pants = Color3.fromRGB(40, 40, 60), skin = Color3.fromRGB(120, 80, 60) },
	{ name = "Uncle Walt", shirt = Color3.fromRGB(70, 100, 60), pants = Color3.fromRGB(60, 50, 40), skin = Color3.fromRGB(230, 190, 160) },
	{ name = "Dr. Imani", shirt = Color3.fromRGB(220, 220, 230), pants = Color3.fromRGB(40, 40, 50), skin = Color3.fromRGB(90, 60, 45) },
}

-- Sounds. The rbxasset:// ones ship with every Roblox client. Paste your own
-- Creator Store audio ids (e.g. "rbxassetid://123") into the empty slots for
-- ambience, chase music and screams. Empty strings are skipped.
Config.Sounds = {
	Ambience = "",
	Chase = "",
	Scream = "",
	Heartbeat = "rbxasset://sounds/action_jump_land.mp3",
	Jumpscare = "rbxasset://sounds/glassbreak.wav",
	Shatter = "rbxasset://sounds/glassbreak.wav",
	Whoosh = "rbxasset://sounds/swoosh.wav",
	Click = "rbxasset://sounds/clickfast.wav",
	Page = "rbxasset://sounds/swoosh.wav",
}

-- Default Roblox R15 animations used by the NPCs.
Config.Animations = {
	Walk = "rbxassetid://507777826",
	Idle = "rbxassetid://507766388",
}

return Config
