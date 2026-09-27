--!strict
-- Client entry point for Hollow Manor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atmosphere = require(script.Atmosphere)
local Controls = require(script.Controls)
local Cutscene = require(script.Cutscene)
local Hud = require(script.Hud)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameState = ReplicatedStorage:WaitForChild("GameState") :: Configuration

Hud.Init()
Cutscene.Init()
Atmosphere.Init()
Controls.Init()

local MessageRemote = Remotes:WaitForChild("Message") :: RemoteEvent
MessageRemote.OnClientEvent:Connect(function(text: string)
	Hud.message(text)
end)

local NoteRemote = Remotes:WaitForChild("Note") :: RemoteEvent
NoteRemote.OnClientEvent:Connect(function(index: number, finder: string)
	Hud.showNote(index, finder)
end)

local JumpscareRemote = Remotes:WaitForChild("Jumpscare") :: RemoteEvent
JumpscareRemote.OnClientEvent:Connect(function()
	Hud.closeNote()
	Cutscene.jumpscare()
end)

local HideRemote = Remotes:WaitForChild("Hide") :: RemoteEvent
HideRemote.OnClientEvent:Connect(function(hidden: boolean, front: CFrame?)
	Hud.setHidden(hidden)
	local camera = workspace.CurrentCamera
	if hidden and front then
		-- Peek out through the wardrobe slats.
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = front * CFrame.new(0, 2.2, 1.2)
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end)

local RevealRemote = Remotes:WaitForChild("Reveal") :: RemoteEvent
RevealRemote.OnClientEvent:Connect(function(planeZ: number, duration: number)
	Hud.setHidden(false)
	Cutscene.reveal(planeZ, duration)
end)

local TakenRemote = Remotes:WaitForChild("Taken") :: RemoteEvent
TakenRemote.OnClientEvent:Connect(function(name: string, position: Vector3, byName: string)
	Cutscene.taken(name, position, byName)
end)

local EndingRemote = Remotes:WaitForChild("Ending") :: RemoteEvent
EndingRemote.OnClientEvent:Connect(function(endingId: string)
	Hud.showEnding(endingId)
end)

-- New round: back to the start of the story.
GameState:GetAttributeChangedSignal("Round"):Connect(function()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	Hud.setHidden(false)
	Hud.closeNote()
	task.spawn(Hud.intro)
end)

if GameState:GetAttribute("Act") == "Explore" then
	Hud.intro()
end
