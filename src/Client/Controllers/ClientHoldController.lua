local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local Producer = require(script.Parent.Parent.Producers)

local ClientHoldController = Knit.CreateController({ Name = "ClientHoldController" })
local SeatHoldingService

function ClientHoldController:KnitStart()
	SeatHoldingService = Knit.GetService("SeatHoldingService")

	local lastRoute, lastParams = Producer.getState().router.currentRoute, Producer.getState().router.params
	Producer:subscribe(function(state)
		return state.router.params
	end, function(params)
		local currentRoute = Producer.getState().router.currentRoute

		if currentRoute == "/order-overview/" then
			if params.seat and params.holdStatus == nil then
				Producer.setHoldUpdating(true)
				SeatHoldingService:HoldSeat({
					aisle = params.seat:GetAttribute("SeatAisle"),
					row = params.seat:GetAttribute("SeatRow"),
				})
					:andThen(function(newHoldStatus, message)
						if newHoldStatus then
							Producer.navigateTo("/order-overview/", {
								seat = params.seat,
								section = params.seat:GetAttribute("Section"),
								holdStatus = newHoldStatus,
							})
							print("Seat held successfully")
						else
							print("Seat held unsuccessfully", message)
							Producer.navigateTo("/select-seat/", {
								seat = params.seat,
								section = params.seat:GetAttribute("Section"),
							})
						end
					end)
					:catch(function(err)
						warn("Failed to hold seat: " .. tostring(err))
						Producer.navigateTo("/select-seat/", {
							seat = params.seat,
							section = params.seat:GetAttribute("Section"),
						})
					end)
					:finally(function()
						Producer.setHoldUpdating(false)
					end)
			end
		elseif lastRoute == "/order-overview/" and currentRoute ~= "/order-overview/" then
			Producer.setHoldUpdating(true)
			SeatHoldingService:ReleaseSeat():finally(function()
				Producer.setHoldUpdating(false)
			end)
		end

		lastRoute, lastParams = currentRoute, params
	end)

	print("Checking initial hold")
	repeat
		task.wait()
	until SeatHoldingService.SeatsOnHold:Get() ~= nil

	local haveLockedSeat
	for seatKey, seatInfo in pairs(SeatHoldingService.SeatsOnHold:Get()) do
		if seatInfo.userId == Players.LocalPlayer.UserId then
			haveLockedSeat = {
				aisle = string.sub(seatKey, 1, 1),
				row = tonumber(string.sub(seatKey, 2, 3)),
				timeout = seatInfo.time + 60 * 5,
			}
			break
		end
	end

	if haveLockedSeat then
		local actualSeat
		for _, seat in pairs(CollectionService:GetTagged("AASeat")) do
			if
				seat:GetAttribute("SeatAisle") == haveLockedSeat.aisle
				and seat:GetAttribute("SeatRow") == haveLockedSeat.row
			then
				actualSeat = seat
				break
			end
		end
		Producer.navigateTo("/order-overview/", {
			seat = actualSeat,
			section = actualSeat:GetAttribute("Section"),
			holdStatus = true,
		})

		Producer.setHoldData(haveLockedSeat)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local currentSeat
			for seatKey, seatInfo in pairs(SeatHoldingService.SeatsOnHold:Get()) do
				if seatInfo.userId == Players.LocalPlayer.UserId then
					currentSeat = {
						aisle = string.sub(seatKey, 1, 1),
						row = tonumber(string.sub(seatKey, 2, 3)),
						timeout = seatInfo.time + 60 * 5,
					}
					break
				end
			end

			if currentSeat then
				if workspace:GetServerTimeNow() > currentSeat.timeout then
					Producer.navigateTo("/select-seat/", {
						seat = nil,
						section = nil,
					})
					Producer.setHoldUpdating(true)
					SeatHoldingService:ReleaseSeat():finally(function()
						Producer.setHoldUpdating(false)
					end)
				end
			end

			Producer.setHoldData(currentSeat)
		end
	end)

	Producer.setInitialHold(false)
	print("Initial hold checked")
end

function ClientHoldController:KnitInit() end

return ClientHoldController
