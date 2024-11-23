local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reflex = require(ReplicatedStorage.BookingPackages.reflex)

-- Define types (optional in Luau, but helpful for clarity)
export type RouterState = {
	isCheckingInitialHold: boolean,
	isHoldUpdating: boolean,
	currentHoldData: { [string]: string },
}

export type RouterActions = {
	checkInitialHold: () -> (),
	setInitialHold: (isCheckingInitialHold: boolean) -> (),
	setHoldUpdating: (isHoldUpdating: boolean) -> (),
	setHoldData: (currentHoldData: { [string]: string }) -> (),
}

export type RouterProducer = Reflex.Producer<RouterState, RouterActions>

-- Initial state: Start at a default route
local initialState: RouterState = {
	isCheckingInitialHold = true,
	isHoldUpdating = false,
	currentHoldData = {},
}

-- Create the producer
local routerProducer = Reflex.createProducer(initialState, {
	checkInitialHold = function(state: RouterState): RouterState
		local nextState = table.clone(state)
		nextState.isCheckingInitialHold = true
		return nextState
	end,
	setInitialHold = function(state: RouterState, isCheckingInitialHold: boolean): RouterState
		local nextState = table.clone(state)
		nextState.isCheckingInitialHold = isCheckingInitialHold
		return nextState
	end,
	setHoldUpdating = function(state: RouterState, isHoldUpdating: boolean): RouterState
		local nextState = table.clone(state)
		nextState.isHoldUpdating = isHoldUpdating
		return nextState
	end,
	setHoldData = function(state: RouterState, currentHoldData: { [string]: string }): RouterState
		local nextState = table.clone(state)
		nextState.currentHoldData = currentHoldData
		return nextState
	end,
}) :: RouterProducer

return routerProducer
