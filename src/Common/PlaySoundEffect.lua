local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Click = Instance.new("Sound")
Click.Name = "Click"
Click.RollOffMode = Enum.RollOffMode.InverseTapered
Click.SoundId = "rbxassetid://15675059323"
Click.Parent = LocalPlayer.PlayerGui

local Hover = Instance.new("Sound")
Hover.Name = "Hover"
Hover.RollOffMode = Enum.RollOffMode.InverseTapered
Hover.SoundId = "rbxassetid://10066931761"
Hover.Parent = LocalPlayer.PlayerGui

return function(sound)
	local newSound = sound == "click" and Click or Hover
	newSound = newSound:Clone()
	newSound.Parent = LocalPlayer.PlayerGui
	newSound.PlayOnRemove = true
	newSound:Destroy()
end
