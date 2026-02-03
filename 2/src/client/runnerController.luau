local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local advanceEvent = ReplicatedStorage:WaitForChild("RunnerAdvance")

-- speeds
local FORWARD_SPEED = 19      -- studs/sec for Humanoid:Move
local STRAFE_SPEED = 19       -- studs/sec
local MAX_X = 12

local SEGMENT_LENGTH = 50
local TRIGGER_MULT = 0.7
local nextTriggerZ = -(SEGMENT_LENGTH * TRIGGER_MULT)

local moveLeft = false
local moveRight = false

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		moveLeft = true
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		moveRight = true
	elseif input.KeyCode == Enum.KeyCode.Space then
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Jump = true end
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		moveLeft = false
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		moveRight = false
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	-- we want to run forward toward -Z
	local moveVec = Vector3.new(0, 0, -FORWARD_SPEED)

	-- add left/right
	if moveLeft then
		moveVec += Vector3.new(-STRAFE_SPEED, 0, 0)
	end
	if moveRight then
		moveVec += Vector3.new(STRAFE_SPEED, 0, 0)
	end

	-- clamp X so we don't fall
	--local pos = hrp.Position
	--if math.abs(pos.X) > MAX_X then
		-- if too far, snap back a bit (optional)
		--hrp.CFrame = CFrame.new(Vector3.new(math.clamp(pos.X, -MAX_X, MAX_X), pos.Y, pos.Z), hrp.CFrame.LookVector + hrp.Position)
	--end

	-- tell the humanoid to move in that direction (world space)
	hum:Move(moveVec, true)

	-- trigger server for next segment
	if hrp.Position.Z <= nextTriggerZ then
		advanceEvent:FireServer()
		nextTriggerZ = nextTriggerZ - SEGMENT_LENGTH
	end
end)
