local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reflex = require(ReplicatedStorage.BookingPackages.reflex)

-- Define types (optional in Luau, but helpful for clarity)
export type RouterState = {
	currentRoute: string,
	params: { [string]: string }, -- Optional: For route parameters
}

export type RouterActions = {
	navigateTo: (route: string, params: { [string]: string }) -> (),
}

export type RouterProducer = Reflex.Producer<RouterState, RouterActions>

-- Initial state: Start at a default route
local initialState: RouterState = {
	currentRoute = "/select-seat/",
	params = {},
}

-- Create the producer
local routerProducer = Reflex.createProducer(initialState, {
	navigateTo = function(state: RouterState, route: string, params: { [string]: string }): RouterState
		local nextState = table.clone(state)
		nextState.currentRoute = route
		nextState.params = params
		return nextState
	end,
}) :: RouterProducer

return routerProducer
