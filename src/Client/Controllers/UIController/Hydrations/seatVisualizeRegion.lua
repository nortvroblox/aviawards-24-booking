local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Module3D = require(ReplicatedStorage.BookingCommon.Module3D)
local Producer = require(script.Parent.Parent.Parent.Parent.Producers)
local UIControllerD = require(script.Parent.Parent.types)

local CurrentCamera = workspace.CurrentCamera
local Seats = workspace.Seats

local PossibleFocus = {
	All = Seats.SeatCamera,
	L = Seats.SeatCamera.L,
	R = Seats.SeatCamera.R,
	M = Seats.SeatCamera.M,
}

local FocusZooom = {
	All = 1.4,
	L = 1.2,
	R = 1.2,
	M = 1.4,
}

local FocusAngle = {
	All = CFrame.Angles(0, 0, 0),
	L = CFrame.Angles(0.6, 0, 0),
	R = CFrame.Angles(0.6, 0, 0),
	M = CFrame.Angles(0.6, 0, 0),
}

return function(payload: UIControllerD.UIPayload)
	local seatVisualizeRegion: Frame = payload.BookingGui.Main.Slot.SeatVisualizeRegion
	local timelineContainer: Frame = payload.BookingGui.Main.Slot.TimelineContainer

	CurrentCamera.FieldOfView = 15
	CurrentCamera.CameraType = Enum.CameraType.Scriptable
	CurrentCamera.CFrame = CFrame.new(0, 0, 0)

	local currentFocus = "All"
	local handlers = {}

	--// If local space's center -> global space, this will be the global space's center
	local glboalCenter = Seats.SeatCamera.M:GetPivot() --// this is 0,0,0 of the local space
	for key, value in pairs(PossibleFocus) do
		local handler = Module3D:Attach3D(seatVisualizeRegion, value, nil, FocusZooom[key])
		handler:SetActive(false)
		--// find offset from value:GetPivot() to global center
		handler:SetCFrame(
			CFrame.new(0, 0, 0)
				* CFrame.new(glboalCenter.Position - value:GetPivot().Position)
				* CFrame.Angles(1, math.pi, 0)
				* FocusAngle[key]
		)
		handlers[key] = handler
	end

	local previousFocus = currentFocus
	RunService.Heartbeat:Connect(function(dt: number)
		for key, _ in pairs(PossibleFocus) do
			handlers[key]:SetActive(key == currentFocus)
			task.wait()
		end
		local seatCurrentPivot = Seats:GetPivot()
		local handler = handlers[currentFocus]
		local targetPivot = handler.Object3D.MODEL_CENTER.CFrame

		if previousFocus ~= currentFocus then
			previousFocus = currentFocus
			Seats:PivotTo(seatCurrentPivot:Lerp(targetPivot, 0.3))
		end

		if (seatCurrentPivot.Position - targetPivot.Position).Magnitude > 0.5 then
			Seats:PivotTo(seatCurrentPivot:Lerp(targetPivot, 10 * dt))
		end

		if Producer.getState().router.currentRoute == "/select-seat/" then
			local section = Producer.getState().router.params.section
			currentFocus = section or "All"
		end
	end)

	Fusion.Hydrate(timelineContainer.CurrentState)({
		Text = Fusion.Computed(function()
			return payload.CurrentParams:get().section and "SELECT A SEAT" or "SELECT A SECTION"
		end),
		Visible = Fusion.Computed(function()
			return payload.CurrentRoute:get() == "/select-seat/"
		end),
	})
end
