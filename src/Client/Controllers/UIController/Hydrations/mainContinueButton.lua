local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local PlaySoundEffect = require(ReplicatedStorage.BookingCommon.PlaySoundEffect)
local Producer = require(script.Parent.Parent.Parent.Parent.Producers)
local UIControllerD = require(script.Parent.Parent.types)

return function(payload: UIControllerD.UIPayload)
	local continueNav: Frame = payload.BookingGui.Main.Slot.TimelineContainer.ContinueNav
	local seatPurchasingService = Knit.GetService("SeatPurchasingService")

	local isCheckingInitialHoldVal = Fusion.Value(Producer.getState().hold.isCheckingInitialHold)
	Producer:subscribe(function(state)
		return state.hold.isCheckingInitialHold
	end, function(route)
		isCheckingInitialHoldVal:set(route)
	end)

	local isHoldUpdatingVal = Fusion.Value(Producer.getState().hold.isHoldUpdating)
	Producer:subscribe(function(state)
		return state.hold.isHoldUpdating
	end, function(route)
		isHoldUpdatingVal:set(route)
	end)

	local playerOwnSeatVal = Fusion.Value(false)
	seatPurchasingService.PlayerOwnSeat:Observe(function(seatData)
		playerOwnSeatVal:set(seatData and seatData.row and seatData.aisle and seatData)
	end)

	local isDisabled = Fusion.Computed(function()
		local currentRoute = payload.CurrentRoute:get()
		local currentParams = payload.CurrentParams:get()
		local isCheckingInitialHold = isCheckingInitialHoldVal:get()
		local isHoldUpdating = isHoldUpdatingVal:get()
		local playerOwnSeat = playerOwnSeatVal:get()

		if isCheckingInitialHold or isHoldUpdating or playerOwnSeat then
			return true
		end
		if currentRoute == "/select-seat/" then
			return currentParams.seat == nil
		end
		if currentRoute == "/order-overview/" then
			return currentParams.holdStatus ~= true
		end
	end)

	local buttonColor = Fusion.Computed(function()
		return isDisabled:get() and Color3.fromRGB(224, 224, 224) or Color3.fromRGB(224, 224, 224)
	end)

	local buttonTransparency = Fusion.Computed(function()
		return isDisabled:get() and 1 or 0
	end)

	local textColor = Fusion.Computed(function()
		return isDisabled:get() and Color3.fromRGB(234, 234, 234) or Color3.fromRGB(10, 15, 30)
	end)

	Fusion.Hydrate(continueNav.Continue)({
		[Fusion.OnEvent("MouseButton1Click")] = function()
			local currentRoute = payload.CurrentRoute:get()
			local currentParams = payload.CurrentParams:get()

			if isDisabled:get() then
				return
			end

			PlaySoundEffect("click")

			if currentRoute == "/select-seat/" then
				if currentParams.seat then
					Producer.navigateTo("/order-overview/", {
						seat = currentParams.seat,
					})
				end
			end

			if currentRoute == "/order-overview/" then
				-- PurchaseSeat
				seatPurchasingService:PurchaseSeat({
					row = currentParams.seat:GetAttribute("SeatRow"),
					aisle = currentParams.seat:GetAttribute("SeatAisle"),
				})
			end
		end,

		[Fusion.OnEvent("MouseEnter")] = function()
			if isDisabled:get() then
				return
			end
			PlaySoundEffect("hover")
		end,

		BackgroundTransparency = Fusion.Spring(buttonTransparency, 25, 1),
		BackgroundColor3 = Fusion.Spring(buttonColor, 25, 1),
	})

	Fusion.Hydrate(continueNav.Continue.TextLabel)({
		TextColor3 = Fusion.Spring(textColor, 25, 1),
	})
end
