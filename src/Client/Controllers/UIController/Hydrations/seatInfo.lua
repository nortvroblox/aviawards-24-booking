local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local UIControllerD = require(script.Parent.Parent.types)

local Remap = function(value, min, max, newMin, newMax)
	return (value - min) / (max - min) * (newMax - newMin) + newMin
end

return function(payload: UIControllerD.UIPayload)
	local seatPurchasingService = Knit.GetService("SeatPurchasingService")

	local seatVisualizeRegion: Frame = payload.BookingGui.Main.Slot.SeatVisualizeRegion
	local seatInfoContainer: Frame = seatVisualizeRegion.SeatInfoContainer
	local SeatInfo = seatInfoContainer.SeatInfo

	local visibility = Fusion.Computed(function()
		local currentRoute = payload.CurrentRoute:get()
		local currentParams = payload.CurrentParams:get()
		return currentRoute == "/select-seat/" and currentParams.seat ~= nil
	end)

	local transparencyValue = Fusion.Computed(function()
		return visibility:get() and 0 or 1
	end)
	local transparencySpring = Fusion.Spring(transparencyValue, 25, 1)

	Fusion.Hydrate(seatInfoContainer)({
		Visible = Fusion.Computed(function()
			return math.round(transparencySpring:get() * 100) < 100
		end),
		Position = Fusion.Spring(
			Fusion.Computed(function()
				return visibility:get() and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.2)
			end),
			25,
			1
		),
	})

	Fusion.Hydrate(SeatInfo)({
		BackgroundTransparency = Fusion.Computed(function()
			return Remap(transparencySpring:get(), 0, 1, 0.25, 1)
		end),
	})

	Fusion.Hydrate(SeatInfo.UIStroke)({
		Transparency = Fusion.Computed(function()
			return Remap(transparencySpring:get(), 0, 1, 0.5, 1)
		end),
	})

	Fusion.Hydrate(SeatInfo.SeatName)({
		Text = Fusion.Computed(function()
			local currentRoute = payload.CurrentRoute:get()
			local currentParams = payload.CurrentParams:get()
			if currentRoute == "/select-seat/" and currentParams.seat then
				local seatAisle = currentParams.seat:GetAttribute("SeatAisle")
				local seatRow = currentParams.seat:GetAttribute("SeatRow")

				return `SEAT {seatAisle}{#tostring(seatRow) == 0 and "0" or ""}{seatRow}`
			end

			return ""
		end),
		TextTransparency = transparencySpring,
	})

	local seatPriceVal = Fusion.Value(0)
	seatPurchasingService.SeatPrice:Observe(function(price)
		seatPriceVal:set(price)
	end)
	Fusion.Hydrate(SeatInfo.Price)({
		Text = Fusion.Computed(function()
			return ` {seatPriceVal:get()}`
		end),
		TextTransparency = transparencySpring,
	})

	Fusion.Hydrate(SeatInfo.Aisle)({
		Text = Fusion.Computed(function()
			local currentRoute = payload.CurrentRoute:get()
			local currentParams = payload.CurrentParams:get()
			if currentRoute == "/select-seat/" and currentParams.seat then
				local seatAisle = currentParams.seat:GetAttribute("SeatAisle")

				return `AISLE {seatAisle}`
			end

			return ""
		end),
		TextTransparency = transparencySpring,
	})

	Fusion.Hydrate(SeatInfo.Row)({
		Text = Fusion.Computed(function()
			local currentRoute = payload.CurrentRoute:get()
			local currentParams = payload.CurrentParams:get()
			if currentRoute == "/select-seat/" and currentParams.seat then
				local seatRow = currentParams.seat:GetAttribute("SeatRow")

				return `ROW {#tostring(seatRow) == 0 and "0" or ""}{seatRow}`
			end

			return ""
		end),
		TextTransparency = transparencySpring,
	})

	Fusion.Hydrate(SeatInfo.Footnote)({
		TextTransparency = transparencySpring,
	})
end
