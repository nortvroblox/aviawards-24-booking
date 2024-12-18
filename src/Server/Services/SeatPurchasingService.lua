local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local ProfileStore = require(ReplicatedStorage.BookingCommon.ProfileStore)

local SeatDeveloperProduct = 2661883212
local SeatPrice = MarketplaceService:GetProductInfo(SeatDeveloperProduct, Enum.InfoType.Product).PriceInRobux

local SeatPurchasedCache = "SeatPurchasedCache2"
local SeatDBKey = "SeatDB"

local PromocodeLockMap = MemoryStoreService:GetHashMap("PromocodeLockMap")

local SeatPurchasedCacheMap = MemoryStoreService:GetHashMap("SeatPurchasedCache2")
local SeatDBTemplate = {}
for _, seat in pairs(CollectionService:GetTagged("AASeat")) do
	SeatDBTemplate[`{seat:GetAttribute("SeatAisle")}{seat:GetAttribute("SeatRow")}`] = {}
end
local SeatDBStore = ProfileStore.New("SeatDBStore1", SeatDBTemplate)

local PurchaseQueue = {}
local TicketGivenOutQueue = {}
local OnSeatPurchasedSignal = Instance.new("BindableEvent")
local SeatHoldingService
local SeatPurchasingService = Knit.CreateService({
	Name = "SeatPurchasingService",
	Client = {
		SeatPrice = Knit.CreateProperty(SeatPrice),
		PlayerOwnSeat = Knit.CreateProperty(nil),
		CurrentPromocode = Knit.CreateProperty(nil),
	},
})

local Secrets = DataStoreService:GetDataStore("Secrets"):GetAsync("Secrets")

local function getPromocode(promocode: string)
	local response = HttpService:RequestAsync({
		Url = `{Secrets.promocodeUrl}/api/v2/tables/{Secrets.promocodeTable}/records?offset=0&limit=25&where=(Code,eq,{promocode})&viewId={Secrets.promocodeViewId}`,
		Method = "GET",
		Headers = {
			["xc-token"] = `{Secrets.promocodeToken}`,
		},
	})

	if response.Success then
		local data = HttpService:JSONDecode(response.Body)
		if data.list and data.list[1] then
			return data.list[1]
		end
	end

	return false, "Failed to get promocode"
end

local function redeemPromocode(promocode: string, player: Player)
	local codeData = getPromocode(promocode)
	if not codeData then
		return false, "Promocode not found"
	end

	if codeData.Redeemed == 1 then
		return false, "Promocode already redeemed"
	end

	local newData = table.clone(codeData)
	newData.Redeemed = 1
	newData.Redeemedby_UserId = player.UserId
	newData.Redeemedby_Username = player.Name

	local response = HttpService:RequestAsync({
		Url = `{Secrets.promocodeUrl}/api/v2/tables/{Secrets.promocodeTable}/records`,
		Method = "PATCH",
		Headers = {
			["xc-token"] = `{Secrets.promocodeToken}`,
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode(newData),
	})

	if response.Success then
		return true, "Promocode redeemed successfully"
	end

	return false, "Failed to redeem promocode"
end

local function hasPlayerRedeemedPromocode(player: Player)
	local response = HttpService:RequestAsync({
		Url = `{Secrets.promocodeUrl}/api/v2/tables/{Secrets.promocodeTable}/records?offset=0&limit=25&where=(Redeemedby_UserId,eq,{player.UserId})&viewId={Secrets.promocodeViewId}`,
		Method = "GET",
		Headers = {
			["xc-token"] = `{Secrets.promocodeToken}`,
		},
	})

	if response.Success then
		local data = HttpService:JSONDecode(response.Body)
		if data.list and data.list[1] then
			return data.list[1]
		end
	end

	return false, "Failed to get promocode"
end

function SeatPurchasingService.Client:PurchaseSeat(player: Player, seat: { row: number, aisle: number })
	if SeatHoldingService:ConfirmPlayerSeat(player, seat) then
		TicketGivenOutQueue[player] = nil
		PurchaseQueue[player] = {
			time = workspace:GetServerTimeNow(),
			seat = seat,
		}
		local hasPromocode = not not self.CurrentPromocode:GetFor(player)

		if not hasPromocode then
			local success, message = pcall(function()
				MarketplaceService:PromptProductPurchase(player, SeatDeveloperProduct)
			end)

			if not success then
				warn("Failed to prompt purchase: " .. message)
			end
		end

		local timeout = workspace:GetServerTimeNow() + 30
		local hasPurchased = hasPromocode
		local hasCanceled = false
		local purchaseConnection
		purchaseConnection = OnSeatPurchasedSignal.Event:Connect(function(purchaser)
			if purchaser == player then
				hasPurchased = true
			end
		end)

		local closeConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(playerId, productId, wasPurchased)
				if playerId == player.UserId and productId == SeatDeveloperProduct then
					if not wasPurchased then
						hasCanceled = true
					end
				end
			end
		)

		while
			not hasPurchased
			and not hasCanceled
			and (workspace:GetServerTimeNow() < timeout)
			and (player.Parent == Players)
		do
			task.wait(0.02)
		end
		purchaseConnection:Disconnect()
		closeConnection:Disconnect()

		if not hasPurchased then
			PurchaseQueue[player] = nil
			TicketGivenOutQueue[player] = nil

			local responseMsg = "Your purchase has timed out, please try again by rejoining the game."
			if hasCanceled then
				responseMsg = "Your purchase has been canceled, please try again by rejoining the game."
			end
			player:Kick(responseMsg)
			return false, responseMsg
		end

		PurchaseQueue[player] = nil

		local seatKey = `{seat.aisle}{seat.row}`
		local newProfile = SeatDBStore:StartSessionAsync(SeatDBKey, {
			Cancel = function()
				return TicketGivenOutQueue[player]
			end,
		})
		if not newProfile then
			TicketGivenOutQueue[player] = nil
			return false, "Failed to start session"
		end
		newProfile:Reconcile()

		local doesPlayerOwnSeat
		for _, value in pairs(newProfile.Data) do
			if value.userId == player.UserId then
				doesPlayerOwnSeat = true
				break
			end
		end

		if doesPlayerOwnSeat then
			print("Seat already purchased")
			TicketGivenOutQueue[player] = false
			newProfile:EndSession()
			return false, "Seat already purchased"
		end

		if newProfile.Data[seatKey].userId then
			print("Seat already purchased")
			TicketGivenOutQueue[player] = false
			newProfile:EndSession()
			return false, "Seat already purchased"
		end

		local newTicketData = {
			userId = player.UserId,
			time = workspace:GetServerTimeNow(),
			seat = {
				row = seat.row,
				aisle = seat.aisle,
			},
		}

		newProfile.Data[seatKey] = newTicketData
		newProfile:EndSession()
		print("newProfile.Data", newProfile.Data)

		SeatPurchasedCacheMap:UpdateAsync(SeatPurchasedCache, function()
			return newProfile.Data
		end, 60 * 60 * 24 * 45)
		SeatHoldingService:ReleaseSeat(player, seat)
		local currentOwned = SeatHoldingService.Client.PurchasedSeats:Get()
		currentOwned[seatKey] = newTicketData
		SeatHoldingService.Client.PurchasedSeats:Set(currentOwned)

		MessagingService:PublishAsync("SeatHoldingUpdate")

		TicketGivenOutQueue[player] = true
		self.PlayerOwnSeat:SetFor(player, seat)
		print("Has purchased!")

		return true, "Seat purchased successfully"
	end

	return false, "You don't have permission to purchase this seat (hold not confirmed)"
end

function SeatPurchasingService.Client:RedeemPromocode(player: Player, promocode: string)
	if self.CurrentPromocode:GetFor(player) then
		return false, "You have already redeemed a promocode"
	end

	local promocodeData = getPromocode(promocode)
	if not promocodeData then
		return false, "Promocode not found"
	end

	if promocodeData.Redeemed == 1 then
		return false, "Promocode already redeemed"
	end

	if PromocodeLockMap:GetAsync(promocode) then
		return false, "Promocode is locked"
	end

	PromocodeLockMap:SetAsync(promocode, true, 60 * 5)
	local success, message = redeemPromocode(promocode, player)
	if not success then
		PromocodeLockMap:SetAsync(promocode, false)
		return false, message
	end

	self.CurrentPromocode:SetFor(player, promocode)
	print("Promocode redeemed successfully")

	return true, "Promocode redeemed successfully"
end

function SeatPurchasingService:PlayerAdded(player)
	local ownSeat = false
	local seatData = SeatPurchasedCacheMap:GetAsync(SeatPurchasedCache)
	if seatData then
		for _, value in pairs(seatData) do
			if value.userId == player.UserId then
				ownSeat = true
				self.Client.PlayerOwnSeat:SetFor(player, value.seat)
				break
			end
		end
	end

	local redeemedPromocode = hasPlayerRedeemedPromocode(player)
	if redeemedPromocode then
		self.Client.CurrentPromocode:SetFor(player, redeemedPromocode)
		self.Client.SeatPrice:SetFor(player, 0)
	end

	if not ownSeat then
		self.Client.PlayerOwnSeat:SetFor(player, false)
	end
end

function SeatPurchasingService:KnitStart()
	SeatHoldingService = Knit.GetService("SeatHoldingService")
	local newProfile = SeatDBStore:StartSessionAsync(SeatDBKey)
	if not newProfile then
		for _, player in pairs(Players:GetPlayers()) do
			player:Kick("Failed to start session")
		end
		return false, "Failed to start session"
	end

	newProfile:Reconcile()
	-- write to cache
	SeatPurchasedCacheMap:UpdateAsync(SeatPurchasedCache, function()
		return newProfile.Data
	end, 60 * 60 * 24 * 45)

	newProfile:EndSession()

	for _, player in pairs(Players:GetPlayers()) do
		self:PlayerAdded(player)
	end
	Players.PlayerAdded:Connect(function(player)
		self:PlayerAdded(player)
	end)
end

function SeatPurchasingService:KnitInit()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local success, message = pcall(function()
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if player then
				if receiptInfo.ProductId == SeatDeveloperProduct then
					if PurchaseQueue[player] then
						OnSeatPurchasedSignal:Fire(player)

						local startAwaitingTime = workspace:GetServerTimeNow()
						repeat
							task.wait()
						until TicketGivenOutQueue[player] ~= nil
							or workspace:GetServerTimeNow() - startAwaitingTime > 60
						if not TicketGivenOutQueue[player] then
							TicketGivenOutQueue[player] = nil
							return false
						end

						print("Seat purchased!")
						TicketGivenOutQueue[player] = nil

						return true
					end
				end
			end
			return false
		end)

		if not success then
			warn("Failed to process receipt: ", message)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return if message == true
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	--// Force the game to wait until all seats are purchased
	game:BindToClose(function()
		local isAllPurchased = false
		while not isAllPurchased do
			isAllPurchased = true
			for _, _ in pairs(PurchaseQueue) do
				isAllPurchased = false
				break
			end

			for _, _ in pairs(TicketGivenOutQueue) do
				isAllPurchased = false
				break
			end
			task.wait(0.1)
		end
	end)
end

return SeatPurchasingService
