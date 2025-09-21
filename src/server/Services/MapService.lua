local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local MapService = Knit.CreateService({
    Name = "MapService",
    Client = {},
})

function MapService:KnitInit()
    self.EnemySpawnPoints = {}
    self.PlayerSpawn = CFrame.new(0, 5, 0)
end

function MapService:KnitStart()
    self:EnsureArena()
end

function MapService:EnsureArena()
    local floor = Workspace:FindFirstChild("ArenaFloor")
    if not floor then
        floor = Instance.new("Part")
        floor.Name = "ArenaFloor"
        floor.Anchored = true
        floor.Size = Config.Map.FloorSize
        floor.Position = Vector3.new(0, floor.Size.Y / 2 * -1, 0)
        floor.Material = Config.Map.FloorMaterial
        floor.Color = Config.Map.LightingColor
        floor.Parent = Workspace
    end

    Lighting.Ambient = Color3.new(0.35, 0.35, 0.35)
    Lighting.OutdoorAmbient = Color3.new(0.3, 0.3, 0.3)

    local spawnFolder = Workspace:FindFirstChild("ArenaSpawns")
    if spawnFolder then
        spawnFolder:ClearAllChildren()
    else
        spawnFolder = Instance.new("Folder")
        spawnFolder.Name = "ArenaSpawns"
        spawnFolder.Parent = Workspace
    end

    local playerSpawn = Workspace:FindFirstChild("PlayerSpawn")
    if not playerSpawn then
        playerSpawn = Instance.new("SpawnLocation")
        playerSpawn.Name = "PlayerSpawn"
        playerSpawn.Size = Vector3.new(8, 1, 8)
        playerSpawn.Anchored = true
        playerSpawn.Transparency = 1
        playerSpawn.CanCollide = true
        playerSpawn.Neutral = true
        playerSpawn.AllowTeamChangeOnTouch = true
        playerSpawn.Parent = Workspace
    end

    playerSpawn.Position = Vector3.new(0, floor.Position.Y + floor.Size.Y / 2 + 1, 0)
    self.PlayerSpawn = playerSpawn.CFrame + Vector3.new(0, 3, 0)

    table.clear(self.EnemySpawnPoints)
    local radius = math.min(Config.Map.FloorSize.X, Config.Map.FloorSize.Z) / 2 - 12
    for index = 1, 4 do
        local angle = math.rad(45 + (index - 1) * 90)
        local position = Vector3.new(math.cos(angle) * radius, playerSpawn.Position.Y, math.sin(angle) * radius)
        local marker = Instance.new("Part")
        marker.Name = "EnemySpawn" .. index
        marker.Size = Vector3.new(4, 1, 4)
        marker.Anchored = true
        marker.Transparency = 1
        marker.CanCollide = false
        marker.CFrame = CFrame.new(position)
        marker.Parent = spawnFolder
        table.insert(self.EnemySpawnPoints, marker)
    end

    self.EnemySpawnFolder = spawnFolder
end

function MapService:GetEnemySpawns(): {BasePart}
    return self.EnemySpawnPoints
end

function MapService:GetPlayerSpawnCFrame(): CFrame
    return self.PlayerSpawn
end

return MapService
