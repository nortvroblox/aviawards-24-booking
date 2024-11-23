local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PlaySoundEffect = require(ReplicatedStorage.BookingCommon.PlaySoundEffect)
local UIControllerD = require(script.Parent.Parent.types)

local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)
local Producer = require(script.Parent.Parent.Parent.Parent.Producers)

local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return function(payload: UIControllerD.UIPayload)
	local seatPurchasingService = Knit.GetService("SeatPurchasingService")
	local seatVisualizeRegion: Frame = payload.BookingGui.Main.Slot.SeatVisualizeRegion
	local selectSection: Frame = seatVisualizeRegion.SelectSection
	local selectSectionDesktop: Frame = payload.BookingGui.SelectSectionDesktop

	local isMobileVal = Fusion.Value(UserInputService.TouchEnabled)
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

	local waitingForSeatOwnershipVal = Fusion.Value(false)
	local ownSeatVal = Fusion.Value(false)
	seatPurchasingService.PlayerOwnSeat:Observe(function(seatData)
		waitingForSeatOwnershipVal:set(seatData == nil)
		ownSeatVal:set(seatData and seatData.row and seatData.aisle and seatData)
	end)

	local shouldShow = Fusion.Computed(function()
		local isCheckingInitialHold = isCheckingInitialHoldVal:get()
		local isHoldUpdating = isHoldUpdatingVal:get()
		local waitingForSeatOwnership = waitingForSeatOwnershipVal:get()
		local ownSeat = ownSeatVal:get()

		if isCheckingInitialHold or isHoldUpdating or waitingForSeatOwnership or ownSeat then
			return false
		end

		return payload.CurrentRoute:get() == "/select-seat/" and payload.CurrentParams:get().section == nil
	end)

	Fusion.Hydrate(require(script.Parent.Parent.Components.LoadSpinner)())({
		Visible = Fusion.Computed(function()
			local isCheckingInitialHold = isCheckingInitialHoldVal:get()
			local isHoldUpdating = isHoldUpdatingVal:get()
			local waitingForSeatOwnership = waitingForSeatOwnershipVal:get()

			return isCheckingInitialHold or isHoldUpdating or waitingForSeatOwnership
		end),
		Parent = seatVisualizeRegion,
	})

	local hoveredVals = {
		L = Fusion.Value(false),
		R = Fusion.Value(false),
		M = Fusion.Value(false),
	}
	local uiPositionVals = {
		L = Fusion.Value(UDim2.new(0, 0, 0, 0)),
		R = Fusion.Value(UDim2.new(0, 0, 0, 0)),
		M = Fusion.Value(UDim2.new(0, 0, 0, 0)),
	}
	local hoverHighlightInstances = {
		L = workspace.Seats.SeatModels.LHighlight,
		R = workspace.Seats.SeatModels.RHighlight,
		M = workspace.Seats.SeatModels.MHighlight,
	}
	RunService.RenderStepped:Connect(function()
		isMobileVal:set(UserInputService.TouchEnabled)

		local currentMousePosition = UserInputService:GetMouseLocation()
		local unitRay = workspace.CurrentCamera:ScreenPointToRay(currentMousePosition.X, currentMousePosition.Y)
		local extendedRay = Ray.new(unitRay.Origin, unitRay.Direction * 15000)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { workspace.Seats.SeatCamera }
		local part = workspace:Raycast(extendedRay.Origin, extendedRay.Direction, raycastParams)

		local newVal = { L = false, R = false, M = false }
		if part then
			if newVal[part.Instance.Name] ~= nil then
				newVal[part.Instance.Name] = true
			end
		end

		for key, value in pairs(hoveredVals) do
			value:set(newVal[key])
		end

		for key, value in pairs(hoverHighlightInstances) do
			value.FillTransparency = Lerp(value.FillTransparency, newVal[key] and shouldShow:get() and 0.4 or 1, 0.2)
		end

		for _, section in pairs(workspace.Seats.SeatCamera:GetChildren()) do
			local positionInScreen = workspace.CurrentCamera:WorldToScreenPoint(section.Position)
			uiPositionVals[section.Name]:set(UDim2.new(0, positionInScreen.X, 0, positionInScreen.Y))
		end
	end)

	for _, section in pairs(selectSection:GetChildren()) do
		if not section:IsA("ImageButton") then
			continue
		end

		local buttonTransparency = Fusion.Value(1)
		local buttonTextTransparency = Fusion.Value(1)
		local buttonOutlineTransparency = Fusion.Value(1)
		local isHovered = Fusion.Value(false)

		local function updateButtonTransparency()
			local isHovering = isHovered:get()
			buttonOutlineTransparency:set(shouldShow:get() and 0 or 1)

			if isHovering and shouldShow:get() then
				buttonTextTransparency:set(0)
				buttonTransparency:set(0.8)
			else
				buttonTextTransparency:set(1)
				buttonTransparency:set(1)
			end
		end

		Fusion.Observer(isHovered):onChange(updateButtonTransparency)
		Fusion.Observer(shouldShow):onChange(updateButtonTransparency)
		updateButtonTransparency()

		Fusion.Hydrate(section)({
			[Fusion.OnEvent("MouseButton1Click")] = function()
				Producer.navigateTo("/select-seat/", {
					section = section.Name,
				})
				PlaySoundEffect("click")
			end,

			[Fusion.OnEvent("MouseEnter")] = function()
				-- buttonTransparency:set(0.8)
				isHovered:set(true)
				PlaySoundEffect("hover")
			end,

			[Fusion.OnEvent("MouseLeave")] = function()
				-- buttonTransparency:set(1)
				isHovered:set(false)
			end,

			BackgroundTransparency = Fusion.Spring(buttonTransparency, 25, 1),
			Active = shouldShow,
		})

		Fusion.Hydrate(section.UIStroke)({
			Transparency = Fusion.Spring(buttonOutlineTransparency, 25, 1),
		})

		Fusion.Hydrate(section.TextLabel)({
			TextTransparency = Fusion.Spring(buttonTextTransparency, 25, 1),
		})
	end

	for _, section in pairs(selectSectionDesktop:GetChildren()) do
		local hoverVal = hoveredVals[section.Name]
		local hoverOffset = Fusion.Spring(
			Fusion.Computed(function()
				return hoverVal:get() and 0 or 0.01
			end),
			25,
			1
		)

		Fusion.Observer(hoverVal):onChange(function()
			if hoverVal:get() then
				PlaySoundEffect("hover")
			end
		end)

		Fusion.Hydrate(section)({
			TextTransparency = Fusion.Spring(
				Fusion.Computed(function()
					local isVis = shouldShow:get()
					local isHover = hoverVal:get()

					return isVis and isHover and 0 or 1
				end),
				25,
				1
			),
			Position = Fusion.Computed(function()
				return uiPositionVals[section.Name]:get() + UDim2.new(0, 0, hoverOffset:get(), 0)
			end),
			ZIndex = Fusion.Computed(function()
				return hoverVal:get() and 2 or 1
			end),
			Active = Fusion.Computed(function()
				local isVis = shouldShow:get()
				local isHover = hoverVal:get()

				return isVis and isHover
			end),

			[Fusion.OnEvent("MouseButton1Click")] = function()
				Producer.navigateTo("/select-seat/", {
					section = section.Name,
				})

				PlaySoundEffect("click")
			end,
		})
	end

	local routeVisibilityValue = Fusion.Value(0)
	local routeVisibilitySpring = Fusion.Spring(routeVisibilityValue, 25, 1)
	local function updateRouteVisibility()
		routeVisibilityValue:set(shouldShow:get() and 0 or 1)
	end
	Fusion.Observer(shouldShow):onChange(updateRouteVisibility)
	updateRouteVisibility()

	Fusion.Hydrate(selectSection)({
		Visible = Fusion.Computed(function()
			local routeVisibility = routeVisibilitySpring:get()
			local isMobile = isMobileVal:get()
			return math.round(routeVisibility * 100) < 99 and isMobile
		end),
	})

	Fusion.Hydrate(selectSectionDesktop)({
		Visible = Fusion.Computed(function()
			local routeVisibility = routeVisibilitySpring:get()
			local isMobile = isMobileVal:get()
			return math.round(routeVisibility * 100) < 99 and not isMobile
		end),
	})
end
