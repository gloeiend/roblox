--!strict
-- Always-on HUD: coins, stage progress, rebirth multiplier, menu buttons and
-- toast notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RebirthRemote = Remotes:WaitForChild("Rebirth") :: RemoteEvent

local HUD = {}

local TOAST_COLORS: { [string]: Color3 } = {
	info = UI.Colors.Blue,
	stage = UI.Colors.Green,
	zone = UI.Colors.Purple,
	finish = UI.Colors.Gold,
	warn = UI.Colors.Red,
	success = UI.Colors.Green,
}

local screen: ScreenGui
local toastHolder: Frame
local coinLabel: TextLabel
local coinPanel: Frame
local stageLabel: TextLabel
local progressFill: Frame
local multiplierLabel: TextLabel
local rebirthButton: TextButton

function HUD.toast(text: string, kind: string?)
	local color = TOAST_COLORS[kind or "info"] or UI.Colors.Blue
	local toast: Frame = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = toastHolder,
	}, {
		UI.corner(10),
		UI.stroke(color, 2),
		UI.label({
			Size = UDim2.new(1, -24, 1, -12),
			Position = UDim2.fromOffset(12, 6),
			Text = text,
			TextColor3 = UI.Colors.Text,
		}),
	})
	UI.pop(toast)
	task.delay(3.5, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		for _, child in toast:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, fade, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.45)
		toast:Destroy()
	end)
end

-- Floating "+N" that drifts up from the coin counter.
function HUD.coinBurst(amount: number)
	local burst = UI.label({
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.new(0, 60, 1, -10),
		Text = "+" .. amount,
		TextColor3 = UI.Colors.Gold,
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = coinPanel,
	})
	local tween = TweenService:Create(burst, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 60, 1, 30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		burst:Destroy()
	end)
end

local function refresh()
	local coins = player:GetAttribute("Coins") or 0
	local stage = player:GetAttribute("Stage") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0

	coinLabel.Text = Config.formatNumber(coins)

	local zone = Config.zoneForStage(math.max(1, math.min(stage + 1, Config.STAGE_COUNT)))
	if stage >= Config.STAGE_COUNT then
		stageLabel.Text = "FINISHED!  Rebirth to climb again"
	else
		stageLabel.Text = `Stage {stage} / {Config.STAGE_COUNT}  •  {zone.name}`
	end
	TweenService:Create(progressFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(stage / Config.STAGE_COUNT, 1),
		BackgroundColor3 = zone.accent,
	}):Play()

	multiplierLabel.Text = `x{Config.coinMultiplier(rebirths)} coins  •  {rebirths} rebirths`

	local canRebirth = stage >= Config.STAGE_COUNT
	rebirthButton.BackgroundColor3 = if canRebirth then UI.Colors.Purple else UI.Colors.Disabled
	rebirthButton.Text = if canRebirth then "REBIRTH!" else "Rebirth"
end

function HUD.Init(onShop: () -> ())
	screen = UI.new("ScreenGui", {
		Name = "SkyClimbHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Scale the whole HUD to the screen so it works on phones and monitors.
	local root: Frame = UI.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local scale: UIScale = UI.new("UIScale", { Parent = root })
	local camera = workspace.CurrentCamera
	local function rescale()
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.55, 1.25)
		root.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Coins (top-left)
	coinPanel = UI.new("Frame", {
		Name = "Coins",
		Size = UDim2.fromOffset(230, 62),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = root,
	}, {
		UI.corner(14),
		UI.stroke(UI.Colors.Gold, 2, 0.3),
		UI.new("Frame", {
			Name = "Icon",
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.fromOffset(11, 11),
			BackgroundColor3 = UI.Colors.Gold,
		}, {
			UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UI.stroke(Color3.fromRGB(200, 140, 20), 3),
			UI.label({ Size = UDim2.fromScale(1, 1), Text = "$", TextColor3 = Color3.fromRGB(150, 95, 10), Font = Enum.Font.FredokaOne }),
		}),
	})
	coinLabel = UI.label({
		Size = UDim2.new(1, -70, 0, 36),
		Position = UDim2.fromOffset(62, 13),
		Text = "0",
		Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = coinPanel,
	})
	multiplierLabel = UI.label({
		Size = UDim2.fromOffset(230, 20),
		Position = UDim2.fromOffset(16, 82),
		Text = "",
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.6,
		Parent = root,
	})

	-- Stage progress (top-center)
	local progress: Frame = UI.new("Frame", {
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(440, 58),
		Position = UDim2.new(0.5, 0, 0, 16),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = root,
	}, {
		UI.corner(14),
	})
	stageLabel = UI.label({
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 6),
		Text = "",
		Parent = progress,
	})
	local bar: Frame = UI.new("Frame", {
		Size = UDim2.new(1, -20, 0, 14),
		Position = UDim2.fromOffset(10, 36),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = progress,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	progressFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Green,
		Parent = bar,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- Menu buttons (left, below coins)
	local menu: Frame = UI.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.new(0, 16, 0.5, -60),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	UI.button({
		Name = "Shop",
		Size = UDim2.fromOffset(120, 50),
		Text = "Shop",
		BackgroundColor3 = UI.Colors.Gold,
		TextColor3 = Color3.fromRGB(60, 40, 0),
		LayoutOrder = 1,
		Parent = menu,
	}, onShop)
	rebirthButton = UI.button({
		Name = "Rebirth",
		Size = UDim2.fromOffset(120, 50),
		Text = "Rebirth",
		BackgroundColor3 = UI.Colors.Disabled,
		LayoutOrder = 2,
		Parent = menu,
	}, function()
		RebirthRemote:FireServer()
	end)

	-- Toasts (bottom-center)
	toastHolder = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(520, 200),
		Position = UDim2.new(0.5, 0, 1, -110),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for _, attribute in { "Coins", "Stage", "Rebirths" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		UI.pop(coinPanel)
	end)
	refresh()

	-- Gently pulse the rebirth button once it's available.
	task.spawn(function()
		local rebirthScale = rebirthButton:FindFirstChildOfClass("UIScale") :: UIScale
		while screen.Parent do
			if (player:GetAttribute("Stage") or 0) >= Config.STAGE_COUNT then
				TweenService:Create(rebirthScale, TweenInfo.new(0.5), { Scale = 1.1 }):Play()
				task.wait(0.5)
				TweenService:Create(rebirthScale, TweenInfo.new(0.5), { Scale = 1 }):Play()
			end
			task.wait(0.5)
		end
	end)
end

return HUD
