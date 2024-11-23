local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local UIControllerD = require(script.Parent.Parent.types)

local RouteToTimeline = {
	["/select-seat/"] = 1,
	["/order-overview/"] = 2,
	["/confirmation/"] = 3,
}

return function(payload: UIControllerD.UIPayload)
	local bookingGui: Frame = payload.BookingGui
	local timelineContainer: Frame = bookingGui.Main.Slot.TimelineContainer
	local timelineDotsWrapper: Frame = timelineContainer.TimelineWrapper.TimelineDots
	local dotContainer: Frame = timelineDotsWrapper.DotContainer
	local lineContainer: Frame = timelineDotsWrapper.LineContainer

	local currentTimeline = Fusion.Computed(function()
		return RouteToTimeline[payload.CurrentRoute:get()] or 1
	end)

	local timelineDots = {
		[1] = dotContainer["1"].Dot,
		[2] = dotContainer["2"].Dot,
		[3] = dotContainer["3"].Dot,
	}

	local timelineLines = {
		[1] = lineContainer["1"].Line,
		[2] = lineContainer["2"].Line,
		[3] = lineContainer["3"].Line,
	}

	for i = 1, 3 do
		local dot = timelineDots[i]
		local line = timelineLines[i]

		Fusion.Hydrate(dot)({
			BackgroundColor3 = Fusion.Spring(
				Fusion.Computed(function()
					return i <= currentTimeline:get() and Color3.fromRGB(248, 214, 121) or Color3.fromRGB(127, 125, 117)
				end),
				25,
				1
			),
		})

		Fusion.Hydrate(dot.UIStroke)({
			Color = Fusion.Spring(
				Fusion.Computed(function()
					return i <= currentTimeline:get() and Color3.fromRGB(248, 214, 121) or Color3.fromRGB(127, 125, 117)
				end),
				25,
				1
			),
		})

		Fusion.Hydrate(line)({
			BackgroundTransparency = Fusion.Spring(
				Fusion.Computed(function()
					return (i <= currentTimeline:get() or i == 3) and 0 or 1
				end),
				15,
				1
			),
		})
	end

	Fusion.Hydrate(timelineLines[3])({
		BackgroundColor3 = Fusion.Spring(
			Fusion.Computed(function()
				return currentTimeline:get() == 3 and Color3.fromRGB(248, 214, 121) or Color3.fromRGB(127, 125, 117)
			end),
			25,
			1
		),
	})

	Fusion.Hydrate(timelineDotsWrapper.LineActive)({
		Size = Fusion.Spring(
			Fusion.Computed(function()
				return UDim2.new(0, 2, math.max((currentTimeline:get() - 1) * 0.25, 0), 0)
			end),
			25,
			1
		),
	})

	Fusion.Hydrate(timelineDotsWrapper.LineInactive)({
		Size = Fusion.Spring(
			Fusion.Computed(function()
				return UDim2.new(0, 2, math.max((3 - currentTimeline:get()) * 0.25, 0), 0)
			end),
			25,
			1
		),
		--// right below LineActive
		Position = Fusion.Spring(
			Fusion.Computed(function()
				return UDim2.new(0.5, 0, math.max((currentTimeline:get()) * 0.25, 0), 0)
			end),
			25,
			1
		),
	})
end
