local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local advanceEvent = ReplicatedStorage:WaitForChild("RunnerAdvance")

-- Create remote for lane switching
local laneEvent = ReplicatedStorage:FindFirstChild("LaneSwitch")
if not laneEvent then
	laneEvent = Instance.new("RemoteEvent")
	laneEvent.Name = "LaneSwitch"
	laneEvent.Parent = ReplicatedStorage
end

local jumpEvent = ReplicatedStorage:FindFirstChild("PlayerJump")
if not jumpEvent then
	jumpEvent = Instance.new("RemoteEvent")
	jumpEvent.Name = "PlayerJump"
	jumpEvent.Parent = ReplicatedStorage
end

local FORWARD_SPEED = 22

-- lanes (must match server)
local LANE_X = { -10, 0, 10 }
local laneIndex = 2

local SEGMENT_LENGTH = 50
local TRIGGER_MULT = 0.7
local nextTriggerZ = -(SEGMENT_LENGTH * TRIGGER_MULT)

local function clampLane(i)
	return math.clamp(i, 1, #LANE_X)
end

-- Block default movement
local function blockMovement()
	local function sink()
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("BlockW", sink, false, Enum.KeyCode.W)
	ContextActionService:BindAction("BlockS", sink, false, Enum.KeyCode.S)
	ContextActionService:BindAction("BlockUp", sink, false, Enum.KeyCode.Up)
	ContextActionService:BindAction("BlockDown", sink, false, Enum.KeyCode.Down)
end

-- Helper to get the root part of the character (works with custom models)
local function getRootPart(char)
	if not char then return nil end
	-- Try HumanoidRootPart first
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp end
	-- Try PrimaryPart
	if char.PrimaryPart then return char.PrimaryPart end
	-- Find any anchored or main part
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.RootPart then return hum.RootPart end
	-- Last resort: find any BasePart
	return char:FindFirstChildWhichIsA("BasePart")
end

player.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	blockMovement()

	local rootPart = getRootPart(char)
	if rootPart then
		nextTriggerZ = rootPart.Position.Z - (SEGMENT_LENGTH * TRIGGER_MULT)
	end

	-- Reset lane
	laneIndex = 2
end)

-- Handle lane switching and jumping (send to server)
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		laneIndex = clampLane(laneIndex - 1)
		laneEvent:FireServer(laneIndex)

	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		laneIndex = clampLane(laneIndex + 1)
		laneEvent:FireServer(laneIndex)

	elseif input.KeyCode == Enum.KeyCode.Space then
		jumpEvent:FireServer()
	end
end)

-- Track segment triggers
RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	if not char then return end
	local rootPart = getRootPart(char)
	if not rootPart then return end

	-- Segment trigger
	if rootPart.Position.Z <= nextTriggerZ then
		advanceEvent:FireServer()
		nextTriggerZ -= SEGMENT_LENGTH
	end
end)
