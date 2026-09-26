--!strict
-- Tiny helpers for building styled UI in code.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(24, 28, 44),
	PanelLight = Color3.fromRGB(38, 44, 66),
	Text = Color3.fromRGB(245, 247, 255),
	Muted = Color3.fromRGB(160, 170, 200),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(70, 210, 120),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(170, 100, 255),
	Red = Color3.fromRGB(240, 80, 90),
	Disabled = Color3.fromRGB(80, 86, 110),
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

function UI.corner(radius: number): any
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UI.stroke(color: Color3, thickness: number, transparency: number?): any
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(px: number): any
	local u = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextLabel", defaults)
end

-- A chunky button with hover/press feedback.
function UI.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		AutoButtonColor = false,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		BackgroundColor3 = UI.Colors.Blue,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button: TextButton = UI.new("TextButton", defaults, {
		UI.corner(10),
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		UI.stroke(Color3.fromRGB(0, 0, 0), 2, 0.6),
	})
	local scale = UI.new("UIScale", { Parent = button })

	local function tweenScale(to: number)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = to }):Play()
	end
	button.MouseEnter:Connect(function()
		tweenScale(1.05)
	end)
	button.MouseLeave:Connect(function()
		tweenScale(1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenScale(0.94)
	end)
	button.MouseButton1Up:Connect(function()
		tweenScale(1.05)
	end)
	button.Activated:Connect(onClick)
	return button
end

function UI.pop(guiObject: GuiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = guiObject })
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

return UI
