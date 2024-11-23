local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.BookingPackages.knit)

local BGMController = Knit.CreateController({ Name = "BGMController" })

local Music = {
	-- "rbxassetid://1842241530",
	-- "rbxassetid://1845756489",
	-- "rbxassetid://1845458027",
	-- "rbxassetid://1846457890",
	-- "rbxassetid://1846458016",
	-- "rbxassetid://1838857104",
	"rbxassetid://1842092578",
}

function BGMController:KnitStart()
	local audioInstances = {}
	for _, music in ipairs(Music) do
		local audio = Instance.new("Sound")
		audio.SoundId = music
		audio.Parent = workspace
		table.insert(audioInstances, audio)
	end

	local random = Random.new()
	local currentMusic = 1
	while true do
		audioInstances[currentMusic]:Play()
		audioInstances[currentMusic].Ended:Wait()
		audioInstances[currentMusic]:Stop()
		local nextMusic = currentMusic
		local attempts = 0
		repeat
			nextMusic = random:NextInteger(1, #Music)
			attempts += 1
			task.wait()
		until nextMusic ~= currentMusic or attempts > 3
		currentMusic = nextMusic

		task.wait()
	end
end

function BGMController:KnitInit() end

return BGMController
