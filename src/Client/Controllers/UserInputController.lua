local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.BookingPackages.knit)
local UserInputController = Knit.CreateController({ Name = "UserInputController" })

function UserInputController:KnitStart()
	--// disable all gui, core
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	UserInputService.ModalEnabled = false
	GuiService.TouchControlsEnabled = false
end

function UserInputController:KnitInit() end

return UserInputController
