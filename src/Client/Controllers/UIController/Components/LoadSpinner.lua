local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)

local function LoadSpinner()
	local currentTime = Fusion.Value(0)
	RunService.Heartbeat:Connect(function()
		currentTime:set(os.clock())
	end)

	return Fusion.New("ImageLabel")({
		Name = "LoadSpinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Image = "rbxassetid://137427439145598",
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(100, 100),
		Visible = false,

		Rotation = Fusion.Computed(function()
			return currentTime:get() * 360
		end),
	})
end

return LoadSpinner
