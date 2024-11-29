local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local Producer = require(script.Parent.Parent.Parent.Parent.Producers)
local UIControllerD = require(script.Parent.Parent.types)

local Remap = function(value, min, max, newMin, newMax)
	return (value - min) / (max - min) * (newMax - newMin) + newMin
end

local function SecondToMinute(inSecond: number)
	local minute = math.floor(inSecond / 60)
	local second = inSecond % 60

	return string.format("%02d:%02d", minute, second)
end

return function(payload: UIControllerD.UIPayload)
	local seatPurchasingService = Knit.GetService("SeatPurchasingService")

	local seatVisualizeRegion: Frame = payload.BookingGui.Main.Slot.SeatVisualizeRegion
	local orderOverviewContainer: Frame = seatVisualizeRegion.OrderOverviewContainer
	local orderOverview: Frame = orderOverviewContainer.OrderOverview
	local seatInfoWrapper: Frame = orderOverview.SeatInfoWrapper

	local currentTimeVal = Fusion.Value(os.clock())
	local currentHoldDataVal = Fusion.Value(Producer.getState().hold.currentHoldData)
	Producer:subscribe(function(state)
		return state.hold.currentHoldData
	end, function(route)
		currentHoldDataVal:set(route)
	end)

	local lastUpdate = os.clock()
	RunService.Heartbeat:Connect(function()
		if os.clock() - lastUpdate < 0.1 then
			return
		end
		lastUpdate = os.clock()
		currentTimeVal:set(workspace:GetServerTimeNow())
	end)

	local shouldDisplay = Fusion.Computed(function()
		return payload.CurrentRoute:get() == "/order-overview/"
	end)

	local transparencyValue = Fusion.Computed(function()
		return shouldDisplay:get() and 0 or 1
	end)

	local transparencySpring = Fusion.Spring(transparencyValue, 25, 1)

	Fusion.Hydrate(require(script.Parent.Parent.Components.LoadSpinner)())({
		Visible = Fusion.Computed(function()
			return payload.CurrentParams:get().holdStatus == nil
		end),
		Parent = orderOverviewContainer,
	})

	Fusion.Hydrate(orderOverviewContainer)({
		Visible = Fusion.Computed(function()
			return math.round(transparencySpring:get() * 100) < 100
		end),
		BackgroundTransparency = 1,
	})

	Fusion.Hydrate(seatInfoWrapper.SeatInfo.SeatLocation)({
		Text = Fusion.Computed(function()
			local currentParams = payload.CurrentParams:get()
			if shouldDisplay:get() and currentParams.seat then
				return currentParams.seat:GetAttribute("SeatAisle") .. currentParams.seat:GetAttribute("SeatRow")
			end

			return ""
		end),
		TextTransparency = transparencySpring,
	})

	local seatPriceVal = Fusion.Value(0)
	seatPurchasingService.SeatPrice:Observe(function(price)
		seatPriceVal:set(price)
	end)
	Fusion.Hydrate(seatInfoWrapper.SeatInfo.Price)({
		Text = Fusion.Computed(function()
			return ` {seatPriceVal:get()}`
		end),
		TextTransparency = transparencySpring,
	})

	Fusion.Hydrate(orderOverview.TimeoutText)({
		TextTransparency = transparencySpring,
		Text = Fusion.Computed(function()
			-- return `00:00 MINUTE BEFORE RETURN`
			local currentHoldData = currentHoldDataVal:get()
			local currentTime = currentTimeVal:get()
			if currentHoldData then
				return `{SecondToMinute((currentHoldData.timeout or currentTime) - currentTime)} MINUTE BEFORE RETURN`
			end

			return "..."
		end),
	})

	Fusion.Hydrate(orderOverview.Title)({
		TextTransparency = transparencySpring,
	})

	Fusion.Hydrate(orderOverview.Description)({
		TextTransparency = transparencySpring,
	})

	Fusion.Hydrate(orderOverviewContainer.SeatVisualize)({
		ImageTransparency = transparencySpring,
		Position = Fusion.Spring(
			Fusion.Computed(function()
				return shouldDisplay:get() and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.3, 0.5)
			end),
			25,
			1
		),
	})

	Fusion.Hydrate(orderOverview)({
		BackgroundTransparency = Fusion.Computed(function()
			return Remap(transparencySpring:get(), 0, 1, 0.95, 1)
		end),
		Position = Fusion.Spring(
			Fusion.Computed(function()
				return shouldDisplay:get() and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.2, 0.5)
			end),
			25,
			1
		),
	})

	Fusion.Hydrate(orderOverview.UIStroke)({
		Transparency = Fusion.Computed(function()
			return Remap(transparencySpring:get(), 0, 1, 0.5, 1)
		end),
	})

	local templateSeat = orderOverviewContainer.SeatVisualize.TemplateSeat
	RunService.RenderStepped:Connect(function(dt)
		templateSeat:PivotTo(templateSeat:GetPivot() * CFrame.Angles(0, dt / 10, 0))
	end)
end
