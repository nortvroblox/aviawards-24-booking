local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local Producer = require(script.Parent.Parent.Parent.Parent.Producers)
local UIControllerD = require(script.Parent.Parent.types)

return function(payload: UIControllerD.UIPayload)
	local seatPurchasingService = Knit.GetService("SeatPurchasingService")
	local receiptContainer: Frame = payload.BookingGui.Main.Slot.SeatVisualizeRegion.ReceiptWrapper.ReceiptContainer
	local receipt: Frame = receiptContainer.Receipt
	local infoCol: Frame = receipt.ReceiptTicket.TicketInfoWrapper.Info.InfoCol

	local row: Frame = infoCol.Row
	local aisle: Frame = infoCol.Aisle
	local seat: Frame = infoCol.Seat
	seatPurchasingService.PlayerOwnSeat:Observe(function(seatData)
		receiptContainer.Visible = not not seatData
		if not (seatData and seatData.row and seatData.aisle) then
			Producer.navigateTo("/select-seat/", {})
			return
		end
		Producer.navigateTo("/confirmation/", {})

		seat.TextLabel.Text = `SEAT {seatData.aisle}{seatData.row}`
		row.TextLabel.Text = `ROW {seatData.row}`
		aisle.TextLabel.Text = `AISLE {seatData.aisle}`
	end)
end
