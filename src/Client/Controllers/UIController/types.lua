local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.BookingPackages.fusion)
local Knit = require(ReplicatedStorage.BookingPackages.knit)

export type UIPayload = {
	BookingGui: ScreenGui,
	UIController: typeof(Knit.CreateController),
	CurrentRoute: Fusion.Value<string>,
	CurrentParams: Fusion.Value<{}>,
}

return {}
