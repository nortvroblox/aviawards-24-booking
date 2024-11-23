local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.BookingPackages.knit)

local SeatHoldingService = Knit.CreateService({
	Name = "SeatHoldingService",
	Client = {
		SeatsOnHold = Knit.CreateProperty({}),
		PurchasedSeats = Knit.CreateProperty({}),
	},
})

local OnHoldStoreName = "OnHoldStore"
local GeneralOnHoldKey = "SeatsOnHold"
local SeatPurchasedCache = "SeatPurchasedCache2"
local OnHoldStore = MemoryStoreService:GetHashMap(OnHoldStoreName)
local IndividualSeatOnHoldStore = MemoryStoreService:GetHashMap(OnHoldStoreName)
local SeatPurchasedCacheMap = MemoryStoreService:GetHashMap("SeatPurchasedCache2")

--// INDIVIDUAL STORE IS THE SINGLE SOURCE OF TRUTH
--// GENERAL STORE IS A CACHE

local RateLimitStore = {}
local function RateLimit(player, key, timeout)
	local storeKey = player.UserId .. key
	local lastTime = RateLimitStore[storeKey] or 0
	if workspace:GetServerTimeNow() - lastTime < timeout then
		return false
	end

	RateLimitStore[storeKey] = workspace:GetServerTimeNow()
	return true
end

function SeatHoldingService:UpdateSeatHolding()
	local success, seatsOnHold = pcall(function()
		return OnHoldStore:GetAsync(GeneralOnHoldKey)
	end)

	if success then
		print("seatsOnHold:", seatsOnHold)
		self.Client.SeatsOnHold:Set(seatsOnHold)
	else
		warn("Failed to get seats on hold, retrying")
		task.wait(0.5)
		self:UpdateSeatHolding()
	end
end

function SeatHoldingService:UpdatePurchasedSeats()
	local success, purchasedSeats = pcall(function()
		return SeatPurchasedCacheMap:GetAsync(SeatPurchasedCache)
	end)

	if success then
		self.Client.PurchasedSeats:Set(purchasedSeats or {})
	else
		warn("Failed to get purchased seats, retrying")
		task.wait(0.5)
		self:UpdatePurchasedSeats()
	end
end

function SeatHoldingService:UpdateGlobalCache()
	local newData
	local success = pcall(function()
		OnHoldStore:UpdateAsync(GeneralOnHoldKey, function(currentData)
			newData = currentData or {}
			for key, value in pairs(newData) do
				if value.time + 60 * 5 < workspace:GetServerTimeNow() then
					newData[key] = nil
				end
			end
			return newData
		end, 60 * 60 * 24 * 45)
	end)

	if success then
		self.Client.SeatsOnHold:Set(newData)
	else
		warn("Failed to update global cache")
	end
end

function SeatHoldingService:_IsSeatAvailable(player: Player?, seat: { row: number, aisle: number })
	local key = `{seat.aisle}{seat.row}`
	local cachedResult = self.Client.SeatsOnHold:Get()[key]

	if cachedResult then
		local doWeOwnIt = cachedResult.userId == (player and player.UserId)
		if doWeOwnIt then
			return true
		end
	end

	local result = IndividualSeatOnHoldStore:GetAsync(key)
	return result == (player and player.UserId) or result == nil
end

function SeatHoldingService.Client:IsSeatAvailable(player: Player?, seat: { row: number, aisle: number })
	if RateLimit(player, "IsSeatAvailable", 1) then
		return self.Server:_IsSeatAvailable(player, seat)
	else
		warn("Rate limited")
		return false, "You are being rate limited!"
	end
	return self.Server:_IsSeatAvailable(player, seat)
end

function SeatHoldingService:GetPlayerCurrentSeat(player: Player)
	local result = {}
	for key, value in pairs(self.Client.SeatsOnHold:Get()) do
		if value.userId == player.UserId then
			table.insert(result, {
				aisle = string.sub(key, 1, 1),
				row = tonumber(string.sub(key, 2, 3)),
			})
		end
	end
	return result
end

function SeatHoldingService:ConfirmPlayerSeat(player: Player, seat: { row: number, aisle: number })
	local currentSeats = self:GetPlayerCurrentSeat(player)
	for _, currentSeat in ipairs(currentSeats) do
		if currentSeat.row == seat.row and currentSeat.aisle == seat.aisle then
			--// check if we own it in the individual store
			local key = `{seat.aisle}{seat.row}`
			local individualResult = IndividualSeatOnHoldStore:GetAsync(key)
			if individualResult == player.UserId then
				return true
			end
		end
	end
	return false
end

function SeatHoldingService:_HoldSeat(player: Player, seat: { row: number, aisle: number })
	if #self:GetPlayerCurrentSeat(player) > 0 then
		warn("Player already has a seat")
		return false, "Player already has a seat"
	end

	local key = `{seat.aisle}{seat.row}`
	if not self:_IsSeatAvailable(player, seat) then
		warn("Seat is not available")
		return false, "Seat is not available"
	end

	IndividualSeatOnHoldStore:SetAsync(key, player.UserId, 60 * 5 + 20)
	OnHoldStore:UpdateAsync(GeneralOnHoldKey, function(currentData)
		local newData = currentData or {}
		newData[key] = {
			userId = player.UserId,
			time = workspace:GetServerTimeNow(),
		}
		for checkKey, checkValue in pairs(newData) do
			if checkValue.time + 60 * 5 < workspace:GetServerTimeNow() then
				newData[checkKey] = nil
			end
		end
		self.Client.SeatsOnHold:Set(newData)
		return newData
	end, 60 * 60 * 24 * 45)
	MessagingService:PublishAsync("SeatHoldingUpdate")

	return true, "Seat held"
end

function SeatHoldingService.Client:HoldSeat(player: Player, seat: { row: number, aisle: number })
	if RateLimit(player, "HoldSeat", 1) then
		return self.Server:_HoldSeat(player, seat)
	else
		warn("Rate limited")
		return false, "You are being rate limited!"
	end
end

function SeatHoldingService:ReleaseSeat(player: Player, seat: { row: number, aisle: number }?)
	if not seat then
		local currentSeats = self:GetPlayerCurrentSeat(player)
		if #currentSeats == 0 then
			warn("Player does not have a seat")
			return false, "Player does not have a seat"
		end

		seat = currentSeats[1]
	end

	local key = `{seat.aisle}{seat.row}`
	if self:_IsSeatAvailable(nil, seat) then
		warn("Seat is already available", seat)
		return false, "Seat is already available"
	end

	-- do we own it?
	local individualResult = IndividualSeatOnHoldStore:GetAsync(key)
	if individualResult == player.UserId then
		IndividualSeatOnHoldStore:SetAsync(key, individualResult, 0)
		OnHoldStore:UpdateAsync(GeneralOnHoldKey, function(currentData)
			local newData = currentData or {}
			newData[key] = nil
			for checkKey, checkValue in pairs(newData) do
				if checkValue.time + 60 * 5 < workspace:GetServerTimeNow() then
					newData[checkKey] = nil
				end
			end
			task.spawn(function()
				self.Client.SeatsOnHold:Set(newData)
			end)
			return newData
		end, 60 * 60 * 24 * 45)
		MessagingService:PublishAsync("SeatHoldingUpdate")
		print("Seat released")
		return true, "Seat released"
	else
		warn("User does not own this seat")
		OnHoldStore:UpdateAsync(GeneralOnHoldKey, function(currentData)
			local newData = currentData or {}
			if newData[key] and newData[key].userId == player.UserId then
				newData[key] = nil
				warn("Out of sync! Resyncing")
			end
			for checkKey, checkValue in pairs(newData) do
				if checkValue.time + 60 * 5 < workspace:GetServerTimeNow() then
					newData[checkKey] = nil
				end
			end
			task.spawn(function()
				self.Client.SeatsOnHold:Set(newData)
			end)
			return newData
		end, 60 * 60 * 24 * 45)
		print("User does not own this seat")
		return false, "User does not own this seat"
	end
end

function SeatHoldingService.Client:ReleaseSeat(player: Player)
	return self.Server:ReleaseSeat(player)
end

function SeatHoldingService:KnitStart()
	self:UpdateSeatHolding()
end

function SeatHoldingService:KnitInit()
	MessagingService:SubscribeAsync("SeatHoldingUpdate", function()
		print("SeatHoldingUpdate")
		self:UpdateSeatHolding()
		self:UpdatePurchasedSeats()
	end)

	self:UpdateSeatHolding()
	task.spawn(function()
		while true do
			self:UpdateSeatHolding()
			self:UpdatePurchasedSeats()
			task.wait(4)
		end
	end)

	task.spawn(function()
		while true do
			self:UpdateGlobalCache()
			task.wait(10)
		end
	end)

	local totalProcessingThreads = 0
	Players.PlayerRemoving:Connect(function(player)
		totalProcessingThreads = totalProcessingThreads + 1
		local success, err = pcall(function()
			if player then
				local currentSeats = self:GetPlayerCurrentSeat(player)
				for _, seat in ipairs(currentSeats) do
					self:ReleaseSeat(player, seat)
				end
			end
		end)
		if not success then
			warn("Failed to release seat for player", player, err)
		end
		totalProcessingThreads = totalProcessingThreads - 1
	end)

	game:BindToClose(function()
		while totalProcessingThreads > 0 do
			task.wait()
		end
	end)
end

return SeatHoldingService
