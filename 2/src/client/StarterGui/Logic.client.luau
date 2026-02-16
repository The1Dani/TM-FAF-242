local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

print("🔧 [MAGNET UI] Script starting...")
print("🔧 [MAGNET UI] Script location:", script:GetFullName())
print("🔧 [MAGNET UI] Script.Parent:", script.Parent)

-- Wait for PlayerGui
local playerGui = player:WaitForChild("PlayerGui")
print("🔧 [MAGNET UI] Found PlayerGui:", playerGui)

-- Find the HUD ScreenGui (for ScoreLabel)
local hudGui = playerGui:WaitForChild("HUD", 5)
if not hudGui then
	warn("❌ [MAGNET UI] Could not find HUD ScreenGui!")
	return
end
print("🔧 [MAGNET UI] Found HUD ScreenGui:", hudGui)

local label = hudGui:WaitForChild("ScoreLabel", 5)
if not label then
	warn("❌ [MAGNET UI] Could not find ScoreLabel!")
else
	print("🔧 [MAGNET UI] Found ScoreLabel:", label)
end

-- Create a NEW ScreenGui specifically for the magnet indicator
local magnetGui = Instance.new("ScreenGui")
magnetGui.Name = "MagnetIndicatorGui"
magnetGui.ResetOnSpawn = false
magnetGui.IgnoreGuiInset = true
magnetGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
magnetGui.Parent = playerGui
print("🔧 [MAGNET UI] Created MagnetIndicatorGui:", magnetGui)

-- Create Magnet Indicator Frame
local magnetIndicator = Instance.new("Frame")
magnetIndicator.Name = "MagnetIndicator"
magnetIndicator.Size = UDim2.new(0, 200, 0, 60)
magnetIndicator.Position = UDim2.new(0, 20, 0, 100) -- Below score
magnetIndicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
magnetIndicator.BorderSizePixel = 3
magnetIndicator.BorderColor3 = Color3.fromRGB(255, 255, 255)
magnetIndicator.Visible = true  -- ⭐ ALWAYS VISIBLE FOR DEBUG
magnetIndicator.ZIndex = 10
magnetIndicator.Parent = magnetGui
print("✅ [MAGNET UI] Created MagnetIndicator Frame - Visible:", magnetIndicator.Visible)

-- Icon
local magnetIcon = Instance.new("TextLabel")
magnetIcon.Name = "Icon"
magnetIcon.Size = UDim2.new(0, 50, 1, 0)
magnetIcon.Position = UDim2.new(0, 5, 0, 0)
magnetIcon.BackgroundTransparency = 1
magnetIcon.Text = "🧲"
magnetIcon.TextScaled = true
magnetIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
magnetIcon.Font = Enum.Font.GothamBold
magnetIcon.ZIndex = 11
magnetIcon.Parent = magnetIndicator
print("✅ [MAGNET UI] Created Icon")

-- Text Label
local magnetText = Instance.new("TextLabel")
magnetText.Name = "Text"
magnetText.Size = UDim2.new(1, -60, 0.5, 0)
magnetText.Position = UDim2.new(0, 60, 0, 0)
magnetText.BackgroundTransparency = 1
magnetText.Text = "MAGNET [DEBUG]"
magnetText.TextScaled = true
magnetText.TextColor3 = Color3.fromRGB(255, 255, 255)
magnetText.Font = Enum.Font.GothamBold
magnetText.TextXAlignment = Enum.TextXAlignment.Left
magnetText.ZIndex = 11
magnetText.Parent = magnetIndicator
print("✅ [MAGNET UI] Created Text Label")

-- Timer Label
local magnetTimer = Instance.new("TextLabel")
magnetTimer.Name = "Timer"
magnetTimer.Size = UDim2.new(1, -60, 0.5, 0)
magnetTimer.Position = UDim2.new(0, 60, 0.5, 0)
magnetTimer.BackgroundTransparency = 1
magnetTimer.Text = "READY"
magnetTimer.TextScaled = true
magnetTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
magnetTimer.Font = Enum.Font.GothamBold
magnetTimer.TextXAlignment = Enum.TextXAlignment.Left
magnetTimer.ZIndex = 11
magnetTimer.Parent = magnetIndicator
print("✅ [MAGNET UI] Created Timer Label")

-- Glow effect
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 100, 100)
uiStroke.Thickness = 3
uiStroke.Parent = magnetIndicator

-- Rounded corners
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = magnetIndicator

print("✅ [MAGNET UI] All UI elements created and visible!")
print("✅ [MAGNET UI] Indicator should be visible at position (20, 100)")

-- Track magnet time
local magnetEndTime = 0
local magnetActive = false

-- Score hook
if label then
	local function hook()
		local stats = player:WaitForChild("leaderstats")
		local score = stats:WaitForChild("Score")

		label.Text = "Score: " .. score.Value
		score.Changed:Connect(function()
			label.Text = "Score: " .. score.Value
		end)
		print("✅ [MAGNET UI] Score hook connected!")
	end
	hook()
end

-- Listen for magnet status updates
print("🔧 [MAGNET UI] Waiting for MagnetStatus RemoteEvent...")
local magnetStatusEvent = ReplicatedStorage:WaitForChild("MagnetStatus", 10)
if magnetStatusEvent then
	print("✅ [MAGNET UI] Found MagnetStatus RemoteEvent!")
	magnetStatusEvent.OnClientEvent:Connect(function(active, duration)
		print("🧲 [MAGNET UI] Received magnet status - Active:", active, "Duration:", duration)
		if active then
			magnetActive = true
			magnetEndTime = tick() + duration
			magnetIndicator.Visible = true
			magnetText.Text = "MAGNET ACTIVE!"
			magnetIndicator.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green when active
			print("🧲 [MAGNET UI] Magnet NOW ACTIVE - UI should be GREEN!")
		else
			magnetActive = false
			magnetText.Text = "MAGNET [DEBUG]"
			magnetTimer.Text = "READY"
			magnetIndicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Red when inactive
			print("🧲 [MAGNET UI] Magnet deactivated")
		end
	end)
else
	warn("❌ [MAGNET UI] Could not find MagnetStatus RemoteEvent!")
end

-- Update timer
game:GetService("RunService").RenderStepped:Connect(function()
	if magnetActive then
		local remaining = math.max(0, magnetEndTime - tick())
		magnetTimer.Text = string.format("%.1fs", remaining)

		-- Pulse effect when time is low
		if remaining < 3 then
			local scale = 1 + math.sin(tick() * 10) * 0.1
			magnetIndicator.Size = UDim2.new(0, 200 * scale, 0, 60 * scale)
		else
			magnetIndicator.Size = UDim2.new(0, 200, 0, 60)
		end
	else
		-- Show it's ready/waiting
		local pulse = math.abs(math.sin(tick() * 2))
		magnetTimer.Text = "WAITING"
		magnetIndicator.BackgroundTransparency = 0.3 + (pulse * 0.2) -- Subtle pulse
	end
end)

print("✅✅✅ [MAGNET UI] FULLY LOADED AND RUNNING! ✅✅✅")
print("👀 [MAGNET UI] Look at TOP-LEFT of screen for RED BOX!")
