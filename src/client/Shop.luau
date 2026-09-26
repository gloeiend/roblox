--!strict
-- Shop window with two tabs: stat upgrades and cosmetic trails.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseRemote = Remotes:WaitForChild("Purchase") :: RemoteFunction
local EquipTrailRemote = Remotes:WaitForChild("EquipTrail") :: RemoteEvent

local Shop = {}

local window: Frame
local pages: { [string]: ScrollingFrame } = {}
local tabs: { [string]: TextButton } = {}
local refreshers: { () -> () } = {}
local notify: (string, string?) -> () = function() end

local function coins(): number
	return player:GetAttribute("Coins") or 0
end

local function ownedTrails(): { [string]: boolean }
	local owned = {}
	local raw = player:GetAttribute("OwnedTrails")
	if type(raw) == "string" then
		for id in raw:gmatch("[^,]+") do
			owned[id] = true
		end
	end
	return owned
end

local function purchase(kind: string, id: string)
	local ok, result, message = pcall(function()
		return PurchaseRemote:InvokeServer(kind, id)
	end)
	if not ok then
		notify("Purchase failed, try again.", "warn")
	else
		notify(message or "", if result then "success" else "warn")
	end
end

local function row(parent: Instance, order: number): Frame
	return UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, 78),
		BackgroundColor3 = UI.Colors.PanelLight,
		LayoutOrder = order,
		Parent = parent,
	}, { UI.corner(12) })
end

local function buildUpgrades(page: ScrollingFrame)
	for order, def in Config.Upgrades do
		local frame = row(page, order)
		UI.label({
			Size = UDim2.new(0.6, 0, 0, 28),
			Position = UDim2.fromOffset(14, 8),
			Text = def.name,
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local detail = UI.label({
			Size = UDim2.new(0.6, 0, 0, 20),
			Position = UDim2.fromOffset(14, 40),
			TextColor3 = UI.Colors.Muted,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local button = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(150, 50),
			Position = UDim2.new(1, -14, 0.5, 0),
			BackgroundColor3 = UI.Colors.Green,
			Parent = frame,
		}, function()
			purchase("Upgrade", def.id)
		end)

		table.insert(refreshers, function()
			local level = player:GetAttribute("Upgrade_" .. def.id) or 0
			local current = Config.upgradeValue(def, level)
			if level >= def.maxLevel then
				detail.Text = `{def.description}  Lv {level}/{def.maxLevel}  •  {current} {def.unit}`
				button.Text = "MAXED"
				button.BackgroundColor3 = UI.Colors.Disabled
			else
				local cost = Config.upgradeCost(def, level)
				detail.Text =
					`{def.description}  Lv {level}/{def.maxLevel}  •  {current} → {Config.upgradeValue(def, level + 1)} {def.unit}`
				button.Text = `$ {Config.formatNumber(cost)}`
				button.BackgroundColor3 = if coins() >= cost then UI.Colors.Green else UI.Colors.Disabled
			end
		end)
		player:GetAttributeChangedSignal("Upgrade_" .. def.id):Connect(Shop.refresh)
	end
end

local function buildTrails(page: ScrollingFrame)
	for order, def in Config.Trails do
		local frame = row(page, order)

		local swatch: Frame = UI.new("Frame", {
			Size = UDim2.fromOffset(56, 56),
			Position = UDim2.fromOffset(11, 11),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = frame,
		}, { UI.corner(10) })
		local keypoints = {}
		for i, color in def.colors do
			table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #def.colors - 1), color))
		end
		if #keypoints == 1 then
			table.insert(keypoints, ColorSequenceKeypoint.new(1, def.colors[1]))
		end
		UI.new("UIGradient", { Color = ColorSequence.new(keypoints), Rotation = 45, Parent = swatch })

		UI.label({
			Size = UDim2.new(0.5, 0, 0, 30),
			Position = UDim2.fromOffset(80, 10),
			Text = def.name,
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local status = UI.label({
			Size = UDim2.new(0.5, 0, 0, 20),
			Position = UDim2.fromOffset(80, 44),
			Font = Enum.Font.Gotham,
			TextColor3 = UI.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local button = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(150, 50),
			Position = UDim2.new(1, -14, 0.5, 0),
			Parent = frame,
		}, function()
			if ownedTrails()[def.id] then
				EquipTrailRemote:FireServer(def.id)
			else
				purchase("Trail", def.id)
			end
		end)

		table.insert(refreshers, function()
			local owned = ownedTrails()[def.id]
			local equipped = player:GetAttribute("EquippedTrail") == def.id
			if equipped then
				status.Text = "Equipped"
				button.Text = "Unequip"
				button.BackgroundColor3 = UI.Colors.Purple
			elseif owned then
				status.Text = "Owned"
				button.Text = "Equip"
				button.BackgroundColor3 = UI.Colors.Blue
			else
				status.Text = "Leaves a glowing streak behind you"
				button.Text = `$ {Config.formatNumber(def.cost)}`
				button.BackgroundColor3 = if coins() >= def.cost then UI.Colors.Green else UI.Colors.Disabled
			end
		end)
	end
end

local function selectTab(name: string)
	for tabName, page in pages do
		page.Visible = tabName == name
		tabs[tabName].BackgroundColor3 = if tabName == name then UI.Colors.Blue else UI.Colors.PanelLight
	end
end

function Shop.refresh()
	if not window.Visible then
		return
	end
	for _, fn in refreshers do
		fn()
	end
end

function Shop.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		Shop.refresh()
		UI.pop(window)
	end
end

function Shop.Init(toast: (string, string?) -> ())
	notify = toast

	local screen = UI.new("ScreenGui", {
		Name = "SkyClimbShop",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})

	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Gold, 3, 0.2),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(620, 480) }),
	})

	UI.label({
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(20, 14),
		Text = "SHOP",
		Font = Enum.Font.FredokaOne,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -14, 0, 12),
		Text = "X",
		BackgroundColor3 = UI.Colors.Red,
		Parent = window,
	}, Shop.toggle)

	local tabBar: Frame = UI.new("Frame", {
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(20, 64),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for order, name in { "Upgrades", "Trails" } do
		tabs[name] = UI.button({
			Size = UDim2.fromOffset(140, 40),
			Text = name,
			LayoutOrder = order,
			Parent = tabBar,
		}, function()
			selectTab(name)
		end)
		pages[name] = UI.new("ScrollingFrame", {
			Name = name,
			Size = UDim2.new(1, -40, 1, -130),
			Position = UDim2.fromOffset(20, 116),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = window,
		}, {
			UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end

	buildUpgrades(pages.Upgrades)
	buildTrails(pages.Trails)
	selectTab("Upgrades")

	for _, attribute in { "Coins", "OwnedTrails", "EquippedTrail" } do
		player:GetAttributeChangedSignal(attribute):Connect(Shop.refresh)
	end

	-- Also open with the B key for keyboard players.
	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			Shop.toggle()
		end
	end)

	-- Fade-in the backdrop feel by slightly dimming the window stroke on open.
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			local stroke = window:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Transparency = 0.8
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 0.2 }):Play()
		end
	end)
end

return Shop
