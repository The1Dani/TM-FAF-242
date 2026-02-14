local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local cupcakeTemplate = ServerStorage:WaitForChild("Cupcake")

local LANE_X = { -10, 0, 10 }
local OBSTACLE_PER_LANE_CHANCE = 0.55 -- chance each lane gets an obstacle on a segment
local COIN_PER_LANE_CHANCE = 0.25     -- optional: coins per lane

local FORWARD_SPEED = 22

-- Track each player's lane and movement
local playerData = {}

-- create / get remotes
local advanceEvent = ReplicatedStorage:FindFirstChild("RunnerAdvance")
if not advanceEvent then
	advanceEvent = Instance.new("RemoteEvent")
	advanceEvent.Name = "RunnerAdvance"
	advanceEvent.Parent = ReplicatedStorage
end

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

-- Helper to get root part (works with custom characters without HumanoidRootPart)
local function getRootPart(char)
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp end
	if char.PrimaryPart then return char.PrimaryPart end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.RootPart then return hum.RootPart end
	return char:FindFirstChildWhichIsA("BasePart")
end

-- Setup movement constraints on character
local function setupCharacterMovement(player, char)
	task.wait(0.3)

	local rootPart = getRootPart(char)
	local hum = char:FindFirstChildOfClass("Humanoid")

	if not rootPart or not hum then
		warn("Could not find root part or humanoid for", player.Name)
		return
	end

	-- Initialize player data
	playerData[player] = {
		laneIndex = 2,
		rootPart = rootPart,
		humanoid = hum
	}

	-- Remove any existing movers
	local existingVel = rootPart:FindFirstChild("RunnerVelocity")
	if existingVel then existingVel:Destroy() end
	local existingGyro = rootPart:FindFirstChild("RunnerGyro")
	if existingGyro then existingGyro:Destroy() end
	local existingAttach = rootPart:FindFirstChild("RunnerAttachment")
	if existingAttach then existingAttach:Destroy() end

	-- Create attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "RunnerAttachment"
	attachment.Parent = rootPart

	-- LinearVelocity for forward movement
	local linearVel = Instance.new("LinearVelocity")
	linearVel.Name = "RunnerVelocity"
	linearVel.Attachment0 = attachment
	linearVel.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVel.MaxForce = 100000
	linearVel.VectorVelocity = Vector3.new(0, 0, -FORWARD_SPEED)
	linearVel.Parent = rootPart

	-- AlignOrientation to face forward
	local alignOri = Instance.new("AlignOrientation")
	alignOri.Name = "RunnerGyro"
	alignOri.Attachment0 = attachment
	alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOri.MaxTorque = 200000
	alignOri.Responsiveness = 100
	alignOri.CFrame = CFrame.Angles(0, 0, 0)
	alignOri.Parent = rootPart

	-- Position in center lane
	local pos = rootPart.Position
	rootPart.CFrame = CFrame.new(LANE_X[2], pos.Y, pos.Z)
end

-- Handle lane switch from client
laneEvent.OnServerEvent:Connect(function(player, newLaneIndex)
	local data = playerData[player]
	if not data then return end

	newLaneIndex = math.clamp(newLaneIndex, 1, #LANE_X)
	data.laneIndex = newLaneIndex

	local rootPart = data.rootPart
	if rootPart and rootPart.Parent then
		local pos = rootPart.Position
		local targetX = LANE_X[newLaneIndex]
		rootPart.CFrame = CFrame.new(targetX, pos.Y, pos.Z)
	end
end)

-- Handle jump from client
jumpEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	local hum = data.humanoid
	if hum and hum.Parent then
		hum.Jump = true
	end
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)

-- SETTINGS
local SEGMENT_LENGTH = 50
local SEGMENT_WIDTH = 30
local START_Y = 50
local SEGMENTS_AHEAD = 8       -- how many we keep in front
local COIN_CHANCE = 0.4
local OBSTACLE_CHANCE = 0.3
local SPAWN_START_AHEAD = 8  -- studs; ~2 meters ≈ 2 studs, but use 6–12 for visibility

-- this runner will have ONE track for now
local segments = {}  -- array of segment models
local lastIndexSpawned = -1
local function randomForwardZ(margin)
	-- spawn only in the "front" part of the segment (toward -Z)
	local minZ = -SEGMENT_LENGTH/2 + margin
	local maxZ = -SPAWN_START_AHEAD -- must stay negative to be in front direction
	if maxZ <= minZ then
		maxZ = minZ + 1
	end
	return math.random(minZ, maxZ)
end

local function placeModelAt(model: Model, worldPos: Vector3)
	-- Find a PrimaryPart (or assign one)
	if not model.PrimaryPart then
		local pp = model:FindFirstChildWhichIsA("BasePart", true)
		if pp then model.PrimaryPart = pp end
	end
	if not model.PrimaryPart then
		warn("CupcakePickup has no BasePart inside it.")
		return
	end

	-- Make sure parts behave like a pickup
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = true   -- IMPORTANT if we use touch pickup
			d.CanQuery = true
		end
	end

	-- Lift by half height so it sits on top of floor
	local yLift = (model.PrimaryPart.Size.Y / 2) + 1.5

	model:PivotTo(CFrame.new(worldPos + Vector3.new(0, yLift, 0)))
end


-- make a part helper
local function makePart(size, color, anchored, canCollide)
	local p = Instance.new("Part")
	p.Size = size
	p.Anchored = anchored
	p.CanCollide = canCollide
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- create one platform at index (0,1,2,3...) on NEGATIVE Z
local function createSegment(index)
	local model = Instance.new("Model")
	model.Name = "Segment_" .. index

	local floor = makePart(
		Vector3.new(SEGMENT_WIDTH, 2, SEGMENT_LENGTH),
		Color3.fromRGB(121, 200, 245),
		true,
		true
	)
	floor.CFrame = CFrame.new(0, START_Y, -index * SEGMENT_LENGTH)
	floor.Name = "Floor"
	floor.Parent = model
	model.PrimaryPart = floor
	local spawnLane = {}
	local count = 0

	for i = 1, #LANE_X do
		spawnLane[i] = (math.random() < OBSTACLE_PER_LANE_CHANCE)
		if spawnLane[i] then count += 1 end
	end

	-- prevent 3/3 blocked: force one random lane to be empty
	if count == #LANE_X then
		local open = math.random(1, #LANE_X)
		spawnLane[open] = false
		count -= 1
	end

	for i, laneX in ipairs(LANE_X) do
	-- remember obstacle Z for this lane (if any)
		local obstacleZ = nil

		-- spawn obstacle if pattern says so
		if spawnLane[i] then
			local obstacle = makePart(Vector3.new(4, 6, 4), Color3.fromRGB(180, 20, 20), true, true)
			obstacle.Name = "Obstacle"

			obstacleZ = randomForwardZ(8)
			obstacle.CFrame = floor.CFrame * CFrame.new(laneX, 4, obstacleZ)
			obstacle.Parent = model

			local hitOnce = false
			obstacle.Touched:Connect(function(hit)
				if hitOnce then return end
				local character = hit:FindFirstAncestorOfClass("Model")
				if not character then return end

				local plr = Players:GetPlayerFromCharacter(character)
				if not plr then return end

				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hitOnce = true
					hum.Health = 0
				end
			end)
		end

		-- cupcake spawn
		if math.random() < COIN_PER_LANE_CHANCE then
			local cupcake = cupcakeTemplate:Clone()
			cupcake.Name = "Cupcake"

			-- ensure PrimaryPart exists
			if not cupcake.PrimaryPart then
				local pp = cupcake:FindFirstChildWhichIsA("BasePart", true)
				if pp then cupcake.PrimaryPart = pp end
			end
			if not cupcake.PrimaryPart then
				warn("CupcakePickup has no BasePart inside it, can't place it.")
				return
			end

			-- make pickup parts
			for _, d in ipairs(cupcake:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = true
					d.CanQuery = false
				end
			end

			-- pick a cupcake Z that doesn't overlap the obstacle in same lane
			local cupcakeZ = randomForwardZ(10)
			local MIN_GAP_Z = 10 -- studs between cupcake and obstacle

			if obstacleZ then
				local tries = 0
				while math.abs(cupcakeZ - obstacleZ) < MIN_GAP_Z and tries < 12 do
					cupcakeZ = randomForwardZ(10)
					tries += 1
				end

				-- fallback: if still too close, shove it forward/back
				if math.abs(cupcakeZ - obstacleZ) < MIN_GAP_Z then
					cupcakeZ = obstacleZ + (cupcakeZ >= obstacleZ and MIN_GAP_Z or -MIN_GAP_Z)
					cupcakeZ = math.clamp(cupcakeZ, -SEGMENT_LENGTH/2 + 10, SEGMENT_LENGTH/2 - 10)
				end
			end

			-- place it above the floor
			local floorTopY = floor.Position.Y+2 + (floor.Size.Y / 2)
			local yLift = (cupcake.PrimaryPart.Size.Y / 2) + 0.5

			local worldPos = Vector3.new(floor.Position.X + laneX, floorTopY + yLift, floor.Position.Z + cupcakeZ)
			cupcake:PivotTo(CFrame.new(worldPos))
			cupcake.Parent = model

			-- touch pickup (on PrimaryPart)
			local collected = false
			cupcake.PrimaryPart.Touched:Connect(function(hit)
				if collected then return end

				local character = hit:FindFirstAncestorOfClass("Model")
				if not character then return end

				local plr = Players:GetPlayerFromCharacter(character)
				if not plr then return end

				local ls = plr:FindFirstChild("leaderstats")
				local score = ls and ls:FindFirstChild("Score") -- <- HERE
				if not score then return end

				collected = true
				score.Value += 1
				cupcake:Destroy()
			end)
		end
	end


	model.Parent = Workspace
	return model
end
-- build initial 8 segments
local function buildInitialTrack()
	segments = {}
	for i = 0, SEGMENTS_AHEAD - 1 do
		local seg = createSegment(i)
		table.insert(segments, seg)
	end
	lastIndexSpawned = SEGMENTS_AHEAD - 1
end

buildInitialTrack()

-- place player on first segment when they spawn
local function placeOnTrack(player, character)
	if #segments == 0 then return end
	local firstSeg = segments[1]
	if not firstSeg.PrimaryPart then return end

	local rootPart = getRootPart(character)
	if rootPart then
		local pos = firstSeg.PrimaryPart.Position
		-- stand on it and look forward (toward -Z)
		rootPart.CFrame = CFrame.new(pos + Vector3.new(0, 5, 5), pos + Vector3.new(0, 5, -200))
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		if #segments == 0 then
			buildInitialTrack()
		end
		placeOnTrack(player, char)
		setupCharacterMovement(player, char)
	end)
end)

-- client asks: "I passed a segment, give me a new one"
advanceEvent.OnServerEvent:Connect(function(player)
	-- remove oldest
	local firstSeg = segments[1]
	if firstSeg then
		firstSeg:Destroy()
		table.remove(segments, 1)
	end

	-- create a new one farther
	lastIndexSpawned += 1
	local newSeg = createSegment(lastIndexSpawned)
	table.insert(segments, newSeg)
end)

-- still keep fall-to-death
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end

		local rootPart = getRootPart(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if rootPart and hum and rootPart.Position.Y < (START_Y - 10) then
			hum.Health = 0
		end
	end
end)
