local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local eatingSoundEvent = ReplicatedStorage:WaitForChild("EatCupcakeSound")
eatingSoundEvent.OnClientEvent:Connect(function()
	local cupcakeSound = Instance.new("Sound")
	cupcakeSound.SoundId = "rbxassetid://140669721576021" -- TODO: Replace with your cupcake sound asset ID
	cupcakeSound.Volume = 0.9
	cupcakeSound.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	cupcakeSound:Play()
	cupcakeSound.Ended:Connect(function()
		cupcakeSound:Destroy()
	end)
end)
