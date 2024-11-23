local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reflex = require(ReplicatedStorage.BookingPackages.reflex)

local RouterProducer = require(script.routerProducer)
local holdProducer = require(script.holdProducer)

export type RootProducer = Reflex.Producer<RootState, RootActions>

export type RootState = {
	router: RouterProducer.RouterState,
	hold: holdProducer.RouterState,
}

type RootActions = {
	router: RouterProducer.RouterActions,
	hold: holdProducer.RouterActions,
}

return Reflex.combineProducers({
	router = RouterProducer,
	hold = holdProducer,
}) :: RootProducer
