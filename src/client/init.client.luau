--!strict
-- Client entry point: wires up the HUD, shop and effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(script.Effects)
local HUD = require(script.HUD)
local Shop = require(script.Shop)

local player = Players.LocalPlayer
local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

-- Wait for the server to finish loading our save so the UI never flashes zeros.
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end

HUD.Init(Shop.toggle)
Shop.Init(HUD.toast)
Effects.Init(HUD.coinBurst)

NotifyRemote.OnClientEvent:Connect(function(text: string, kind: string?)
	HUD.toast(text, kind)
end)

HUD.toast("Welcome to Sky Climb! Reach the finish, collect coins and press B for the shop.", "info")
