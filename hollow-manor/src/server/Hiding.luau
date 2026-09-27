--!strict
-- Wardrobes you can climb into. While hidden you're anchored inside and the
-- stalker can't see you, unless it watched you get in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapBuilder = require(script.Parent.MapBuilder)

local HideRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Hide") :: RemoteEvent

local Hiding = {}

local occupants: { [MapBuilder.Closet]: Player } = {}
local hiddenIn: { [Player]: MapBuilder.Closet } = {}
local connections: { RBXScriptConnection } = {}
local enabled = true

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Hiding.Release(player: Player)
	local closet = hiddenIn[player]
	if not closet then
		return
	end
	hiddenIn[player] = nil
	occupants[closet] = nil
	closet.prompt.ActionText = "Hide"
	player:SetAttribute("Hidden", nil)
	player:SetAttribute("HiddenAt", nil)
	local root = rootOf(player)
	if root and player.Character then
		root.Anchored = false
		player.Character:PivotTo(closet.front)
	end
	HideRemote:FireClient(player, false)
end

function Hiding.ReleaseAll()
	for player in hiddenIn do
		Hiding.Release(player)
	end
end

local function enter(player: Player, closet: MapBuilder.Closet)
	local root = rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	hiddenIn[player] = closet
	occupants[closet] = player
	closet.prompt.ActionText = "Leave"
	player:SetAttribute("Hidden", true)
	player:SetAttribute("HiddenAt", closet.front.Position)
	character:PivotTo(closet.inside)
	root.Anchored = true
	HideRemote:FireClient(player, true, closet.front)
end

function Hiding.SetEnabled(value: boolean)
	enabled = value
	if not value then
		Hiding.ReleaseAll()
	end
end

-- Drop state without moving the character (they died or left).
function Hiding.Forget(player: Player)
	local closet = hiddenIn[player]
	if closet then
		occupants[closet] = nil
		closet.prompt.ActionText = "Hide"
	end
	hiddenIn[player] = nil
	player:SetAttribute("Hidden", nil)
	player:SetAttribute("HiddenAt", nil)
end

function Hiding.Setup(map: MapBuilder.Map)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(occupants)
	for player in hiddenIn do
		player:SetAttribute("Hidden", nil)
		player:SetAttribute("HiddenAt", nil)
	end
	table.clear(hiddenIn)
	enabled = true

	for _, closet in map.closets do
		closet.prompt.Enabled = true
		table.insert(
			connections,
			closet.prompt.Triggered:Connect(function(player)
				if not enabled then
					return
				end
				if hiddenIn[player] == closet then
					Hiding.Release(player)
				elseif not hiddenIn[player] and not occupants[closet] then
					enter(player, closet)
				end
			end)
		)
	end
end

function Hiding.SetPromptsEnabled(map: MapBuilder.Map, value: boolean)
	for _, closet in map.closets do
		closet.prompt.Enabled = value
	end
end

return Hiding
