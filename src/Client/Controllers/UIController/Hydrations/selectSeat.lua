local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local PlaySoundEffect = require(ReplicatedStorage.BookingCommon.PlaySoundEffect)
local Producer = require(script.Parent.Parent.Parent.Parent.Producers)
local UIControllerD = require(script.Parent.Parent.types)

local function TemplateDot()
	return Fusion.New("ImageButton")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.02, 0.02),
		ZIndex = 5,

		[Fusion.Children] = {
			Fusion.New("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(1, 0),
			}),

			Fusion.New("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.05,
			}),

			Fusion.New("UISizeConstraint")({
				Name = "UISizeConstraint",
				MinSize = Vector2.new(15, 15),
			}),

			Fusion.New("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(248, 214, 121),
				Thickness = 2,
				Transparency = 0.5,
			}),
		},
	})
end

return function(payload: UIControllerD.UIPayload)
	local selectSeat = payload.BookingGui.SelectSeat
	local currentRoute = payload.CurrentRoute
	local currentParams = payload.CurrentParams
	local currentCamera = workspace.CurrentCamera

	local seatHoldingService = Knit.GetService("SeatHoldingService")

	local shouldDisplay = Fusion.Computed(function()
		return currentRoute:get() == "/select-seat/" and currentParams:get().section ~= nil
	end)

	--// note: originally it's made with fusion's forvalue, but it's way too slow
	local previousDot = {}
	local previousConnections = {}
	local function updateDots()
		for _, dot in ipairs(previousDot) do
			dot:Destroy()
		end
		for _, connection in ipairs(previousConnections) do
			connection:Disconnect()
		end
		previousDot = {}
		if shouldDisplay:get() then
			local targetSeats = CollectionService:GetTagged("Section" .. currentParams:get().section)
			for _, seat in ipairs(targetSeats) do
				local isAvailable = true
				local dot = TemplateDot()
				table.insert(
					previousConnections,
					seat:GetPropertyChangedSignal("CFrame"):Connect(function()
						local seatIn2DSpace = currentCamera:WorldToViewportPoint(seat.Position)
						dot.Position = UDim2.fromOffset(seatIn2DSpace.X, seatIn2DSpace.Y)
					end)
				)
				table.insert(
					previousConnections,
					dot.MouseButton1Click:Connect(function()
						if not isAvailable then
							return
						end
						PlaySoundEffect("click")
						Producer.navigateTo("/select-seat/", {
							section = currentParams:get().section,
							seat = seat,
						})
					end)
				)
				local function updateDotColor()
					local primaryColor
					local key = `{seat:GetAttribute("SeatAisle")}{seat:GetAttribute("SeatRow")}`
					isAvailable = true
					if
						seatHoldingService.SeatsOnHold:Get()[key]
						and seatHoldingService.SeatsOnHold:Get()[key].userId ~= Players.LocalPlayer.UserId
					then
						isAvailable = false
					end
					if
						seatHoldingService.PurchasedSeats:Get()[key]
						and seatHoldingService.PurchasedSeats:Get()[key].userId
					then
						isAvailable = false
					end

					if not isAvailable then
						primaryColor = Color3.fromRGB(127, 125, 117)
					else
						primaryColor = Color3.fromRGB(248, 214, 121)
					end

					dot.BackgroundColor3 = primaryColor
				end

				updateDotColor()
				table.insert(previousConnections, seatHoldingService.SeatsOnHold:Observe(updateDotColor))
				table.insert(previousConnections, seatHoldingService.PurchasedSeats:Observe(updateDotColor))
				dot.Parent = selectSeat
				table.insert(previousDot, dot)
			end
		end
	end

	updateDots()
	Fusion.Observer(shouldDisplay):onChange(updateDots)
end
