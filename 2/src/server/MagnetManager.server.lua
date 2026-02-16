-- MagnetManager.server.lua
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local cupcakeTemplate = ServerStorage:WaitForChild("Cupcake")
local magnetTemplate = ServerStorage:WaitForChild("Magnet")

local LANE_X = { -10, 0, 10 }
local MAGNET_DURATION = 10 -- seconds
local MAGNET_CHANCE = 0.5 -- chance per segment to spawn a magnet

-- Keep track of active magnets for each player
local playerMagnets = {}

-- Helper to place model at world position
local function placeModel(model, pos)
	if not model.PrimaryPart then
		local pp = model:FindFirstChildWhichIsA("BasePart", true)
		if pp then model.PrimaryPart = pp end
	end
	if not model.PrimaryPart then return end

	-- Anchor and disable collisions
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = true
		end
	end

	local yLift = (model.PrimaryPart.Size.Y / 2) + 1.5
	model:PivotTo(CFrame.new(pos + Vector3.new(0, yLift, 0)))
	model.Parent = Workspace
end

-- Spawn magnet randomly on a segment
local function maybeSpawnMagnet(segmentFloor, laneX)
	if math.random() < MAGNET_CHANCE then
		local magnet = magnetTemplate:Clone()
		-- pick a Z somewhere in the segment
		local zPos = segmentFloor.Position.Z + math.random(-25, 25)
		local worldPos = Vector3.new(laneX, segmentFloor.Position.Y, zPos)
		placeModel(magnet, worldPos)
        print("Spawning magnet at", worldPos)

		-- Handle pickup
		local collected = false
		if magnet.PrimaryPart then
			magnet.PrimaryPart.Touched:Connect(function(hit)
				if collected then return end
				local char = hit:FindFirstAncestorOfClass("Model")
				if not char then return end
				local player = Players:GetPlayerFromCharacter(char)
				if not player then return end
				collected = true

				-- Activate magnet for player
				playerMagnets[player] = true
				magnet:Destroy()

				-- Remove magnet after duration
				task.delay(MAGNET_DURATION, function()
					playerMagnets[player] = nil
				end)
			end)
		end
	end
end

-- Expose a function to call from runner when spawning a segment
local MagnetManager = {}

-- segment: floor part of the segment model
function MagnetManager.SpawnOnSegment(segment)
	if not segment:FindFirstChild("Floor") then return end
	local floor = segment.Floor
	for i, laneX in ipairs(LANE_X) do
		maybeSpawnMagnet(floor, laneX)
	end
end

-- Optional: check if player has active magnet
function MagnetManager.PlayerHasMagnet(player)
	return playerMagnets[player] or false
end

return MagnetManager
