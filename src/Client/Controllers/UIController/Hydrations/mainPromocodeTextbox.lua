local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local PlaySoundEffect = require(ReplicatedStorage.BookingCommon.PlaySoundEffect)
local Producer = require(script.Parent.Parent.Parent.Parent.Producers)
local UIControllerD = require(script.Parent.Parent.types)

return function(payload: UIControllerD.UIPayload)
	local continueNav: Frame = payload.BookingGui.Main.Slot.TimelineContainer.ContinueNav
	local seatPurchasingService = Knit.GetService("SeatPurchasingService")

	local shouldDisplay = Fusion.Computed(function()
		return payload.CurrentRoute:get() == "/order-overview/"
	end)

	local isRedeemingPromocodeVal = Fusion.Value(false)
	local isPromocodeInvalidVal = Fusion.Value(false)
	local hasRedeemedPromocodeVal = Fusion.Value(false)

	Fusion.Hydrate(continueNav.Promocode)({
		Visible = shouldDisplay,
	})

	local textbox = Fusion.Hydrate(continueNav.Promocode.TextBox)({
		TextEditable = Fusion.Computed(function()
			local isRedeemingPromocode = isRedeemingPromocodeVal:get()
			local hasRedeemedPromocode = hasRedeemedPromocodeVal:get()
			local isPromocodeInvalid = isPromocodeInvalidVal:get()

			return not isRedeemingPromocode and not hasRedeemedPromocode and not isPromocodeInvalid
		end),

		PlaceholderText = Fusion.Computed(function()
			local isRedeemingPromocode = isRedeemingPromocodeVal:get()
			local hasRedeemedPromocode = hasRedeemedPromocodeVal:get()
			local isPromocodeInvalid = isPromocodeInvalidVal:get()

			if isRedeemingPromocode then
				return "Redeeming..."
			end

			if isPromocodeInvalid then
				return "Invalid promocode!"
			end

			if hasRedeemedPromocode then
				return "Promocode redeemed!"
			end

			return "Promocode (optional)"
		end),
	})

	seatPurchasingService.CurrentPromocode:Observe(function(promocode)
		if promocode then
			textbox.Text = ""
			hasRedeemedPromocodeVal:set(true)
		end
	end)

	textbox.FocusLost:Connect(function()
		local promocode = textbox.Text
		if promocode == "" then
			return
		end
		textbox.Text = ""

		isRedeemingPromocodeVal:set(true)
		seatPurchasingService
			:RedeemPromocode(promocode)
			:andThen(function(success, message)
				isRedeemingPromocodeVal:set(false)
				if success then
					hasRedeemedPromocodeVal:set(true)
				else
					warn(message)
					hasRedeemedPromocodeVal:set(false)
					isPromocodeInvalidVal:set(true)
					task.wait(2)
					isPromocodeInvalidVal:set(false)
				end
			end)
			:catch(function(err)
				warn(err)
				hasRedeemedPromocodeVal:set(false)
				isPromocodeInvalidVal:set(true)
				task.wait(2)
				isPromocodeInvalidVal:set(false)
			end)
	end)
end
