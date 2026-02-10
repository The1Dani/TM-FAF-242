local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local advanceEvent = ReplicatedStorage:WaitForChild("RunnerAdvance")

local FORWARD_SPEED =  	22

-- lanes (must match server)
local LANE_X = { -10, 0, 10 }
local laneIndex = 2

local SEGMENT_LENGTH = 50
local TRIGGER_MULT = 0.7
local nextTriggerZ = -(SEGMENT_LENGTH * TRIGGER_MULT)

local function clampLane(i)
	return math.clamp(i, 1, #LANE_X)
end

local function snapToLane()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local pos = hrp.Position
	local targetX = LANE_X[laneIndex]

	-- snap ONLY X, keep current Y/Z and rotation
	hrp.CFrame = CFrame.new(targetX, pos.Y, pos.Z) * CFrame.Angles(0, hrp.Orientation.Y * math.pi/180, 0)
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		laneIndex = clampLane(laneIndex - 1)
		snapToLane()

	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		laneIndex = clampLane(laneIndex + 1)
		snapToLane()

	elseif input.KeyCode == Enum.KeyCode.Space then
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Jump = true end
		end
	end
end)

-- also snap on spawn (so you start perfectly centered)
player.CharacterAdded:Connect(function()
	task.wait(0.1)
	snapToLane()
end)

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	-- only forward movement
	hum:Move(Vector3.new(0, 0, -FORWARD_SPEED), true)

	-- segment trigger
	if hrp.Position.Z <= nextTriggerZ then
		advanceEvent:FireServer()
		nextTriggerZ -= SEGMENT_LENGTH
	end
end)
