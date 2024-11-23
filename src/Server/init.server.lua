local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("BookingPackages"):WaitForChild("knit"))

-- Add controllers & components:
Knit.AddServicesDeep(script.Services)

-- Start Knit:
Knit.Start()
	:andThen(function()
		print("Knit Server has started")
	end)
	:catch(function(err)
		warn("Knit framework failure: " .. tostring(err))
	end)
