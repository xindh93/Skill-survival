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
        floor.CanCollide = true
        floor.Parent = Workspace
    end

    local floorSize = Config.Map.FloorSize
    floor.Size = floorSize
    floor.Position = Vector3.new(0, -floorSize.Y / 2, 0)
    floor.Material = Config.Map.FloorMaterial
    floor.Color = Config.Map.LightingColor
    floor.Transparency = Config.Map.FloorTransparency or 0
    floor.Reflectance = 0

    Lighting.Ambient = Color3.new(0.35, 0.35, 0.35)
    Lighting.OutdoorAmbient = Color3.new(0.3, 0.3, 0.3)

    local spawnFolder = Workspace:FindFirstChild("ArenaSpawns")
    if not spawnFolder then
        spawnFolder = Instance.new("Folder")
        spawnFolder.Name = "ArenaSpawns"
        spawnFolder.Parent = Workspace
    end

    local playerSpawn = Workspace:FindFirstChild("PlayerSpawn")
    local playerSpawnPart: BasePart? = nil
    local createdSpawn = false

    if playerSpawn then
        if playerSpawn:IsA("BasePart") then
            playerSpawnPart = playerSpawn
        elseif playerSpawn:IsA("Model") then
            playerSpawnPart = playerSpawn:FindFirstChildWhichIsA("BasePart", true)
        end
    end

    if not playerSpawnPart then
        playerSpawnPart = Instance.new("SpawnLocation")
        playerSpawnPart.Name = "PlayerSpawn"
        playerSpawnPart.Size = Vector3.new(8, 1, 8)
        playerSpawnPart.Anchored = true
        playerSpawnPart.Transparency = 1
        playerSpawnPart.CanCollide = true
        playerSpawnPart.Neutral = true
        playerSpawnPart.AllowTeamChangeOnTouch = true
        playerSpawnPart.Parent = Workspace
        createdSpawn = true
    end

    if createdSpawn then
        playerSpawnPart.Position = Vector3.new(0, floor.Position.Y + floor.Size.Y / 2 + 1, 0)
    end

    self.PlayerSpawn = playerSpawnPart.CFrame * CFrame.new(0, playerSpawnPart.Size.Y / 2 + 3, 0)

    table.clear(self.EnemySpawnPoints)

    for _, child in ipairs(spawnFolder:GetDescendants()) do
        if child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
            table.insert(self.EnemySpawnPoints, child)
        end
    end

    if #self.EnemySpawnPoints == 0 then
        local radius = math.min(Config.Map.FloorSize.X, Config.Map.FloorSize.Z) / 2 - 12
        for index = 1, 4 do
            local angle = math.rad(45 + (index - 1) * 90)
            local position = Vector3.new(math.cos(angle) * radius, playerSpawnPart.Position.Y, math.sin(angle) * radius)
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
