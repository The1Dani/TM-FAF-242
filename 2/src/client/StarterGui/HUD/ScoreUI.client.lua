local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = script.Parent
local label = gui:WaitForChild("ScoreLabel")

local function hook()
	local stats = player:WaitForChild("leaderstats")
	local score = stats:WaitForChild("Score")

	label.Text = "Score: " .. score.Value
	score.Changed:Connect(function()
		label.Text = "Score " .. score.Value
	end)
end

hook()
