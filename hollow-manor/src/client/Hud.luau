--!strict
-- On-screen text: objective, subtitles, the note reader, stamina, hunt stats,
-- the wardrobe view and the ending screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local GameState = ReplicatedStorage:WaitForChild("GameState") :: Configuration
local RestartRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Restart") :: RemoteEvent

local Hud = {}

local screen: ScreenGui
local objectiveLabel: TextLabel
local notesLabel: TextLabel
local subtitle: TextLabel
local subtitleToken = 0
local staminaBar: Frame
local staminaFill: Frame
local huntPanel: Frame
local huntStats: TextLabel
local huntTimer: TextLabel
local senseLabel: TextLabel
local hintLabel: TextLabel
local reader: Frame
local readerTitle: TextLabel
local readerBody: TextLabel
local hideOverlay: Frame

function Hud.message(text: string, duration: number?)
	subtitleToken += 1
	local token = subtitleToken
	subtitle.TextTransparency = 0
	subtitle.TextStrokeTransparency = 0.4
	task.spawn(UI.typewrite, subtitle, text, 55)
	task.delay(duration or math.max(3.5, #text / 14), function()
		if token == subtitleToken then
			UI.fade(subtitle, "TextTransparency", 1, 1)
			UI.fade(subtitle, "TextStrokeTransparency", 1, 1)
		end
	end)
end

function Hud.setStamina(fraction: number, visible: boolean)
	staminaBar.Visible = visible and fraction < 0.999
	staminaFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	staminaFill.BackgroundColor3 = if fraction < 0.25 then UI.Colors.Blood else UI.Colors.Text
end

function Hud.setSense(text: string)
	senseLabel.Text = text
end

function Hud.showNote(index: number, finder: string?)
	local note = Story.Notes[index]
	if not note then
		return
	end
	UI.sound(Config.Sounds.Page, 0.6, 0.8)
	readerTitle.Text = note.title
	readerBody.Text = note.body
	reader.Visible = true
	if finder and finder ~= player.DisplayName then
		Hud.message(`{finder} found something in the {note.room:lower()}.`)
	end
end

function Hud.closeNote()
	reader.Visible = false
end

function Hud.isReading(): boolean
	return reader.Visible
end

function Hud.setHidden(hidden: boolean)
	hideOverlay.Visible = hidden
end

function Hud.showEnding(endingId: string)
	local ending = Story.Endings[endingId]
	if not ending then
		return
	end
	local overlay: Frame = UI.new("Frame", {
		Name = "Ending",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = screen,
	})
	UI.fade(overlay, "BackgroundTransparency", 0, 2.5)
	task.wait(2.5)
	local title = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0.8, 0, 0, 70),
		Position = UDim2.fromScale(0.5, 0.18),
		Font = UI.Fonts.Title,
		TextColor3 = UI.Colors.Blood,
		Text = ending.title,
		ZIndex = 51,
		Parent = overlay,
	})
	title.TextTransparency = 1
	UI.fade(title, "TextTransparency", 0, 1.5)
	task.wait(1.5)
	for i, line in ending.lines do
		local label = UI.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0.7, 0, 0, 30),
			Position = UDim2.new(0.5, 0, 0.32, (i - 1) * 42),
			Text = line,
			ZIndex = 51,
			Parent = overlay,
		})
		UI.typewrite(label, line, 35)
		task.wait(0.8)
	end
	local taken = GameState:GetAttribute("Taken") or 0
	local escaped = GameState:GetAttribute("Escaped") or 0
	UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0.6, 0, 0, 24),
		Position = UDim2.fromScale(0.5, 0.66),
		Text = `Taken: {taken}    Escaped: {escaped}`,
		TextColor3 = UI.Colors.Muted,
		ZIndex = 51,
		Parent = overlay,
	})
	local button: TextButton = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(240, 54),
		Position = UDim2.fromScale(0.5, 0.75),
		BackgroundColor3 = Color3.fromRGB(40, 10, 12),
		Font = UI.Fonts.Story,
		Text = "Wake up again",
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		ZIndex = 51,
		Parent = overlay,
	}, {
		UI.corner(6),
		UI.new("UIStroke", { Color = UI.Colors.Blood, Thickness = 2 }),
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	})
	button.Activated:Connect(function()
		RestartRemote:FireServer()
	end)
	-- The screen clears itself when the next round begins.
	local connection: RBXScriptConnection
	connection = GameState:GetAttributeChangedSignal("Round"):Connect(function()
		connection:Disconnect()
		overlay:Destroy()
	end)
end

function Hud.intro()
	local overlay: Frame = UI.new("Frame", {
		Name = "Intro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 40,
		Parent = screen,
	})
	local line = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.75, 0, 0, 36),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 41,
		Parent = overlay,
	})
	UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0.5, 0, 0, 18),
		Position = UDim2.new(0.5, 0, 1, -30),
		Text = "click to skip",
		TextColor3 = UI.Colors.Muted,
		ZIndex = 41,
		Parent = overlay,
	})
	local skipped = false
	local connection = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			skipped = true
		end
	end)
	for _, text in Story.Intro do
		if skipped then
			break
		end
		line.TextTransparency = 0
		UI.typewrite(line, text, 30)
		local t = 0
		while t < 1.6 and not skipped do
			t += task.wait()
		end
	end
	connection:Disconnect()
	UI.fade(line, "TextTransparency", 1, 1)
	UI.fade(overlay, "BackgroundTransparency", 1, 2.5).Completed:Wait()
	overlay:Destroy()
end

local function refresh()
	local act = GameState:GetAttribute("Act")
	objectiveLabel.Text = tostring(GameState:GetAttribute("Objective") or "")
	local notes = GameState:GetAttribute("Notes") or 0
	local total = GameState:GetAttribute("NotesTotal") or #Story.Notes
	notesLabel.Text = `Notes  {notes}/{total}`
	notesLabel.Visible = act == "Explore"
	huntPanel.Visible = act == "Hunt"
	hintLabel.Text = if act == "Hunt"
		then "Shift: stalk faster    Q: sense them"
		elseif act == "Explore" then "F: flashlight    Shift: run    E: interact / hide"
		else ""
	local remaining = GameState:GetAttribute("Remaining") or 0
	local taken = GameState:GetAttribute("Taken") or 0
	local escaped = GameState:GetAttribute("Escaped") or 0
	huntStats.Text = `Remaining {remaining}    Taken {taken}    Escaped {escaped}`
end

function Hud.Init()
	screen = UI.new("ScreenGui", {
		Name = "HollowHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	objectiveLabel = UI.label({
		Size = UDim2.new(0.5, 0, 0, 26),
		Position = UDim2.fromOffset(24, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Text,
		Parent = screen,
	})
	notesLabel = UI.label({
		Size = UDim2.new(0.3, 0, 0, 20),
		Position = UDim2.fromOffset(24, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		Parent = screen,
	})
	hintLabel = UI.label({
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(0.5, 0, 0, 16),
		Position = UDim2.new(0, 24, 1, -20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		TextTransparency = 0.3,
		Font = UI.Fonts.Body,
		Parent = screen,
	})
	subtitle = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0.8, 0, 0, 30),
		Position = UDim2.new(0.5, 0, 1, -90),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 30,
		Parent = screen,
	})
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(900, 30), Parent = subtitle })

	staminaBar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(220, 4),
		Position = UDim2.new(0.5, 0, 1, -50),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screen,
	})
	staminaFill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Text,
		BorderSizePixel = 0,
		Parent = staminaBar,
	})

	huntPanel = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(360, 90),
		Position = UDim2.new(1, -24, 0, 56),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	huntTimer = UI.label({
		Size = UDim2.new(1, 0, 0, 36),
		Font = UI.Fonts.Title,
		TextColor3 = UI.Colors.Bright,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = huntPanel,
	})
	huntStats = UI.label({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = huntPanel,
	})
	senseLabel = UI.label({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 66),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Muted,
		Parent = huntPanel,
	})

	-- Note reader
	reader = UI.new("Frame", {
		Name = "Reader",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = UI.Colors.Paper,
		Rotation = -1.5,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	}, {
		UI.new("UISizeConstraint", { MinSize = Vector2.new(320, 360), MaxSize = Vector2.new(560, 620) }),
		UI.new("UIStroke", { Color = Color3.fromRGB(120, 100, 70), Thickness = 2 }),
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0, 28),
			PaddingBottom = UDim.new(0, 28),
			PaddingLeft = UDim.new(0, 32),
			PaddingRight = UDim.new(0, 32),
		}),
	})
	readerTitle = UI.label({
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = UI.Colors.PaperInk,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = reader,
	})
	readerBody = UI.label({
		Size = UDim2.new(1, 0, 1, -80),
		Position = UDim2.fromOffset(0, 48),
		TextColor3 = UI.Colors.PaperInk,
		TextStrokeTransparency = 1,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 21,
		Parent = reader,
	})
	local closeButton: TextButton = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Font = UI.Fonts.Body,
		Text = "click or press E to put it down",
		TextColor3 = Color3.fromRGB(110, 90, 70),
		TextScaled = true,
		ZIndex = 21,
		Parent = reader,
	})
	closeButton.Activated:Connect(Hud.closeNote)

	-- Wardrobe slats
	hideOverlay = UI.new("Frame", {
		Name = "Hiding",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	})
	for i = 0, 9 do
		UI.new("Frame", {
			Size = UDim2.new(1, 0, 0.1, if i % 3 == 1 then -26 else -6),
			Position = UDim2.fromScale(0, i * 0.1),
			BackgroundColor3 = Color3.fromRGB(12, 8, 6),
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = hideOverlay,
		})
	end
	UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0.5, 0, 0, 20),
		Position = UDim2.new(0.5, 0, 1, -30),
		Text = "Hold your breath. Press E to leave.",
		TextColor3 = UI.Colors.Muted,
		ZIndex = 11,
		Parent = hideOverlay,
	})

	for _, attribute in { "Act", "Objective", "Notes", "Remaining", "Taken", "Escaped" } do
		GameState:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()

	RunService.Heartbeat:Connect(function()
		local endsAt = GameState:GetAttribute("HuntEndsAt")
		if huntPanel.Visible and type(endsAt) == "number" then
			local left = math.max(0, endsAt - workspace:GetServerTimeNow())
			huntTimer.Text = string.format("%d:%02d", left // 60, math.floor(left % 60))
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.E and reader.Visible and not processed then
			Hud.closeNote()
		end
	end)
end

return Hud
