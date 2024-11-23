local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)

local Producer = require(script.Parent.Parent.Producers)
local UIController = Knit.CreateController({ Name = "UIController" })

function UIController:KnitStart()
	local BookingGui = Players.LocalPlayer.PlayerGui:WaitForChild("BookingGui")
	local currentRoute = Fusion.Value(Producer.getState().router.currentRoute)
	local currentParams = Fusion.Value(Producer.getState().router.params)

	Producer:subscribe(function(state)
		return state.router.currentRoute
	end, function(route)
		currentRoute:set(route)
	end)

	Producer:subscribe(function(state)
		return state.router.params
	end, function(params)
		currentParams:set(params)
	end)

	for _, module in ipairs(script.Hydrations:GetChildren()) do
		if module:IsA("ModuleScript") then
			require(module)({
				BookingGui = BookingGui,
				UIController = self,
				CurrentRoute = currentRoute,
				CurrentParams = currentParams,
			})
		end
	end
end

function UIController:KnitInit() end

return UIController
