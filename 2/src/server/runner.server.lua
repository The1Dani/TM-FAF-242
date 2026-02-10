local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local cupcakeTemplate = ServerStorage:WaitForChild("Cupcake")

local LANE_X = { -10, 0, 10 }
local OBSTACLE_PER_LANE_CHANCE = 0.55 -- chance each lane gets an obstacle on a segment
local COIN_PER_LANE_CHANCE = 0.25     -- optional: coins per lane

-- create / get remote
local advanceEvent = ReplicatedStorage:FindFirstChild("RunnerAdvance")
if not advanceEvent then
	advanceEvent = Instance.new("RemoteEvent")
	advanceEvent.Name = "RunnerAdvance"
	advanceEvent.Parent = ReplicatedStorage
end

-- SETTINGS
local SEGMENT_LENGTH = 50
local SEGMENT_WIDTH = 30
local START_Y = 50
local SEGMENTS_AHEAD = 8       -- how many we keep in front
local COIN_CHANCE = 0.4
local OBSTACLE_CHANCE = 0.3

-- this runner will have ONE track for now
local segments = {}  -- array of segment models
local lastIndexSpawned = -1

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
		Color3.fromRGB(60, 60, 60),
		true,
		true
	)
	floor.CFrame = CFrame.new(0, START_Y, -index * SEGMENT_LENGTH)
	floor.Name = "Floor"
	floor.Parent = model
	model.PrimaryPart = floor

	for _, laneX in ipairs(LANE_X) do
		-- choose a Z offset inside the segment (avoid edges)

		-- random obstacle in this lane
		if math.random() < OBSTACLE_PER_LANE_CHANCE then
			local obstacle = makePart(Vector3.new(4, 6, 4), Color3.fromRGB(180, 20, 20), true, true)
			obstacle.Name = "Obstacle"
			local zOffset = math.random(-SEGMENT_LENGTH/2 + 8, SEGMENT_LENGTH/2 - 8)

			obstacle.CFrame = floor.CFrame * CFrame.new(laneX, 4, zOffset)
			obstacle.Parent = model

			local hitOnce = false
			obstacle.Touched:Connect(function(hit)
				if hitOnce then return end
				local plr = Players:GetPlayerFromCharacter(hit.Parent)
				if plr and plr.Character then
					local hum = plr.Character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						hitOnce = true
						hum.Health = 0
					end
				end
			end)
		end

		-- optional: random coin in this lane
		if math.random() < COIN_PER_LANE_CHANCE then
			-- clone cupcake model
			local cupcake = cupcakeTemplate:Clone()
			cupcake.Name = "Cupcake"

			-- pick spawn position on this lane
			local zOffset = math.random(-SEGMENT_LENGTH/2 + 10, SEGMENT_LENGTH/2 - 10)

			-- ensure PrimaryPart exists (needed for PivotTo)
			if not cupcake.PrimaryPart then
				local pp = cupcake:FindFirstChildWhichIsA("BasePart", true)
				if pp then cupcake.PrimaryPart = pp end
			end
			if not cupcake.PrimaryPart then
				warn("CupcakePickup has no BasePart inside it, can't place it.")
				return
			end

			-- make all parts behave like a pickup
			for _, d in ipairs(cupcake:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = true
					d.CanQuery = false
				end
			end

			-- place it above the floor (lift by half its height)
			local floorTopY = floor.Position.Y+3 + (floor.Size.Y / 2) 
			local yLift = (cupcake.PrimaryPart.Size.Y / 2) + 0.5

			local worldPos = Vector3.new(floor.Position.X + laneX, floorTopY + yLift, floor.Position.Z + zOffset)
			cupcake:PivotTo(CFrame.new(worldPos))

			cupcake.Parent = model

			-- IMPORTANT: Models don't have Touched, so use a BasePart inside the model
			local touchPart = cupcake.PrimaryPart

			local collected = false
			touchPart.Touched:Connect(function(hit)
				if collected then return end

				local character = hit:FindFirstAncestorOfClass("Model")
				if not character then return end

				local plr = Players:GetPlayerFromCharacter(character)
				if not plr then return end

				local ls = plr:FindFirstChild("leaderstats")
				local coins = ls and ls:FindFirstChild("Coins")
				if not coins then return end

				collected = true
				coins.Value += 1
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

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local pos = firstSeg.PrimaryPart.Position
		-- stand on it and look forward (toward -Z)
		hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 5), pos + Vector3.new(0, 5, -200))
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		if #segments == 0 then
			buildInitialTrack()
		end
		placeOnTrack(player, char)
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
	local player = Players:GetPlayers()[1]
	if not player then return end
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hrp.Position.Y < (START_Y - 10) then
		hum.Health = 0
	end
end)
