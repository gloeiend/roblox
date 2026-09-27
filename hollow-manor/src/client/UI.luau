--!strict
-- Tiny helpers for building UI in code.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Ink = Color3.fromRGB(10, 8, 10),
	Paper = Color3.fromRGB(226, 214, 186),
	PaperInk = Color3.fromRGB(45, 30, 25),
	Text = Color3.fromRGB(225, 220, 215),
	Muted = Color3.fromRGB(140, 130, 128),
	Blood = Color3.fromRGB(170, 20, 25),
	Bright = Color3.fromRGB(255, 60, 60),
}

UI.Fonts = {
	Story = Enum.Font.SpecialElite,
	Title = Enum.Font.Creepster,
	Body = Enum.Font.Gotham,
}

function UI.new(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className :: any)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = UI.Fonts.Story,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		TextStrokeTransparency = 0.6,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextLabel", defaults)
end

function UI.corner(radius: number): any
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UI.fade(object: GuiObject, property: string, to: number, time: number): Tween
	local tween = TweenService:Create(object, TweenInfo.new(time), { [property] = to })
	tween:Play()
	return tween
end

-- Reveal text one character at a time.
function UI.typewrite(label: TextLabel, text: string, charsPerSecond: number?)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local total = utf8.len(text) or #text
	local rate = charsPerSecond or 40
	local shown = 0
	while shown < total and label.Parent do
		shown += 1
		label.MaxVisibleGraphemes = shown
		task.wait(1 / rate)
	end
	label.MaxVisibleGraphemes = -1
end

function UI.sound(id: string, volume: number?, pitch: number?): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	game:GetService("SoundService"):PlayLocalSound(sound)
	task.delay(4, function()
		sound:Destroy()
	end)
	return sound
end

return UI
