local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	-- maybe coin
	if math.random() < COIN_CHANCE then
		local coin = makePart(Vector3.new(2,2,2), Color3.fromRGB(255, 220, 0), false, false)
		coin.Shape = Enum.PartType.Ball
		coin.Name = "Coin"
		coin.Position = floor.Position + Vector3.new(
			math.random(-SEGMENT_WIDTH/2 + 3, SEGMENT_WIDTH/2 - 3),
			5,
			math.random(-SEGMENT_LENGTH/2 + 5, SEGMENT_LENGTH/2 - 5)
		)
		coin.Parent = model

		coin.Touched:Connect(function(hit)
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			if plr then
				local ls = plr:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Coins") then
					ls.Coins.Value += 1
				end
				coin:Destroy()
			end
		end)
	end

	-- maybe obstacle
	if math.random() < OBSTACLE_CHANCE then
		local obstacle = makePart(Vector3.new(4, 6, 4), Color3.fromRGB(180, 20, 20), true, true)
		obstacle.Name = "Obstacle"
		obstacle.CFrame = floor.CFrame * CFrame.new(
			math.random(-SEGMENT_WIDTH/2 + 5, SEGMENT_WIDTH/2 - 5),
			4,
			math.random(-SEGMENT_LENGTH/2 + 5, SEGMENT_LENGTH/2 - 5)
		)
		obstacle.Parent = model

		obstacle.Touched:Connect(function(hit)
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			if plr and plr.Character then
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if hum then hum.Health = 0 end
			end
		end)
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
