local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local playerCollisionGroupName = "Players"
PhysicsService:RegisterCollisionGroup(playerCollisionGroupName)
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, playerCollisionGroupName, false)

local previousCollisionGroups = {}

local function setCollisionGroup(part)
	part.CollisionGroup = playerCollisionGroupName
end

local function onCharacterAdded(character)
	character.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") then
			setCollisionGroup(child)
		end
	end)
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("BasePart") then
			setCollisionGroup(child)
		end
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)