local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("BookingPackages"):WaitForChild("knit"))

-- Add controllers & components:
Knit.AddControllers(script.Controllers)

-- Start Knit:
Knit.Start()
	:andThen(function()
		print("Knit Client has started")
	end)
	:catch(function(err)
		warn("Knit framework failure: " .. tostring(err))
	end)
