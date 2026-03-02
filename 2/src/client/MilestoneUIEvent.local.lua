local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local milestoneEvent = ReplicatedStorage:WaitForChild("MilestoneUIEvent")

-- reference the manually created label
local textLabel = player:WaitForChild("PlayerGui"):WaitForChild("MilestoneGUI"):WaitForChild("MilestoneLabel")

milestoneEvent.OnClientEvent:Connect(function(message)
    textLabel.Text = message
    textLabel.Visible = true
    task.delay(2, function()
        textLabel.Visible = false
    end)
end)