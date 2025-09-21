local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local EnemyService = Knit.CreateService({
    Name = "EnemyService",
    Client = {},
})

function EnemyService:KnitInit()
    self.Enemies = {} :: {[Model]: {Model: Model, Humanoid: Humanoid, Stats: any, LastHit: Player?}}
    self.TouchCooldowns = {} :: {[Model]: {[Player]: number}}
    self.ActiveEnemies = 0
    self.Spawning = false
    self.MatchActive = false
    self.WaveCleared = Knit.Util.Signal.new()
end

function EnemyService:KnitStart()
    self.RewardService = Knit.GetService("RewardService")
    self.MapService = Knit.GetService("MapService")

    self.EnemyFolder = Workspace:FindFirstChild("Enemies")
    if not self.EnemyFolder then
        self.EnemyFolder = Instance.new("Folder")
        self.EnemyFolder.Name = "Enemies"
        self.EnemyFolder.Parent = Workspace
    end
end

function EnemyService:StartMatch()
    self.MatchActive = true
    self.Spawning = false
    self.ActiveEnemies = 0
    self.Enemies = {}
    self.TouchCooldowns = {}
    self.EnemyFolder:ClearAllChildren()
end

function EnemyService:StopAll()
    self.MatchActive = false
    self.Spawning = false
    for model in pairs(self.Enemies) do
        model:Destroy()
    end
    self.Enemies = {}
    self.TouchCooldowns = {}
    self.ActiveEnemies = 0
end

function EnemyService:BeginWave(waveNumber: number)
    if not self.MatchActive then
        return
    end

    self.Spawning = true
    local spawnCount = math.max(1, Config.Enemy.BaseCount + Config.Enemy.CountGrowth * (waveNumber - 1))
    local healthMultiplier = 1 + Config.Enemy.HealthGrowthRate * (waveNumber - 1)
    local speedBonus = math.min(Config.Enemy.MaxSpeedDelta, Config.Enemy.SpeedGrowthRate * (waveNumber - 1))
    local damage = Config.Enemy.BaseDamage + Config.Enemy.DamageGrowth * (waveNumber - 1)

    local spawns = self.MapService:GetEnemySpawns()
    if #spawns == 0 then
        warn("[EnemyService] No spawn points available")
        self.Spawning = false
        return
    end

    task.spawn(function()
        for index = 1, spawnCount do
            if not self.MatchActive then
                break
            end
            local spawnPart = spawns[((index - 1) % #spawns) + 1]
            local spawnCFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
            self:SpawnEnemy(spawnCFrame, {
                MaxHealth = Config.Enemy.BaseHealth * healthMultiplier,
                Damage = damage,
                Speed = Config.Enemy.BaseSpeed + speedBonus,
                RewardGold = Config.Rewards.KillGold,
            })
            task.wait(Config.Enemy.SpawnInterval)
        end

        self.Spawning = false
        self:CheckWaveCleared()
    end)
end

function EnemyService:CreateEnemyModel(stats)
    local model = Instance.new("Model")
    model.Name = "Zombie"

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 2, 1)
    root.Material = Enum.Material.Fabric
    root.Color = Color3.fromRGB(86, 107, 70)
    root.CanCollide = true
    root.Anchored = false
    root.Parent = model

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Material = Enum.Material.Fabric
    torso.Color = Color3.fromRGB(64, 82, 51)
    torso.CanCollide = false
    torso.Anchored = false
    torso.Parent = model

    local weld = Instance.new("Weld")
    weld.Part0 = root
    weld.Part1 = torso
    weld.C0 = CFrame.new(0, 1, 0)
    weld.Parent = root

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.6, 1.6, 1.6)
    head.Material = Enum.Material.Fabric
    head.Color = Color3.fromRGB(103, 132, 71)
    head.CanCollide = false
    head.Parent = model

    local neck = Instance.new("Weld")
    neck.Part0 = torso
    neck.Part1 = head
    neck.C0 = CFrame.new(0, 1.3, 0)
    neck.Parent = torso

    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "EnemyHumanoid"
    humanoid.WalkSpeed = stats.Speed
    humanoid.MaxHealth = stats.MaxHealth
    humanoid.Health = stats.MaxHealth
    humanoid.Parent = model

    local animator = Instance.new("Animator")
    animator.Parent = humanoid

    model.PrimaryPart = root
    return model
end

function EnemyService:SpawnEnemy(spawnCFrame: CFrame, stats)
    local model = self:CreateEnemyModel(stats)
    model:SetPrimaryPartCFrame(spawnCFrame)
    model.Parent = self.EnemyFolder

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end

    local data = {
        Model = model,
        Humanoid = humanoid,
        Stats = stats,
        LastHit = nil :: Player?,
    }

    self.Enemies[model] = data
    self.ActiveEnemies = self.ActiveEnemies + 1
    self.TouchCooldowns[model] = {}

    if model.PrimaryPart then
        model.PrimaryPart:SetNetworkOwner(nil)
        model.PrimaryPart.Touched:Connect(function(part)
            self:OnEnemyTouched(data, part)
        end)
    end

    if humanoid then
        humanoid.Died:Connect(function()
            self:OnEnemyDied(data)
        end)
    end

    Net:FireAll("EnemySpawned", model)

    task.spawn(function()
        self:RunEnemyBehavior(data)
    end)
end

function EnemyService:RunEnemyBehavior(enemyData)
    local humanoid = enemyData.Humanoid
    local model = enemyData.Model
    if not humanoid then
        return
    end

    while self.MatchActive and humanoid.Health > 0 and model.Parent do
        local target = self:GetClosestTarget(model)
        if target then
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = false,
            })
            local root = model.PrimaryPart
            if root then
                path:ComputeAsync(root.Position, target.Position)
                local waypoints = path:GetWaypoints()
                for _, waypoint in ipairs(waypoints) do
                    if not self.MatchActive or humanoid.Health <= 0 or not model.Parent then
                        break
                    end
                    humanoid:MoveTo(waypoint.Position)
                    humanoid.MoveToFinished:Wait()
                end
            end
        end
        task.wait(Config.Enemy.PathRefresh)
    end
end

function EnemyService:GetClosestTarget(model: Model)
    local root = model.PrimaryPart
    if not root then
        return nil
    end

    local closest
    local closestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if hrp and humanoid and humanoid.Health > 0 then
            local distance = (hrp.Position - root.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closest = hrp
            end
        end
    end

    return closest, closestDistance
end

function EnemyService:OnEnemyTouched(enemyData, part: BasePart)
    if not self.MatchActive then
        return
    end

    local character = part.Parent
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local player = Players:GetPlayerFromCharacter(character)
    if not humanoid or not player then
        return
    end

    if humanoid.Health <= 0 then
        return
    end

    local cooldowns = self.TouchCooldowns[enemyData.Model]
    local now = os.clock()
    local last = cooldowns[player]
    if last and now - last < 1.5 then
        return
    end

    cooldowns[player] = now
    humanoid:TakeDamage(enemyData.Stats.Damage)
end

function EnemyService:OnEnemyDied(enemyData)
    local model = enemyData.Model
    if not self.Enemies[model] then
        return
    end

    self.Enemies[model] = nil
    self.TouchCooldowns[model] = nil
    self.ActiveEnemies = math.max(0, self.ActiveEnemies - 1)

    Net:FireAll("EnemyRemoved", model)

    local killer = enemyData.LastHit
    if killer then
        self.RewardService:RecordKill(killer)
        self.RewardService:AddGold(killer, enemyData.Stats.RewardGold)
        self.RewardService:AddXP(killer, Config.Rewards.KillXP)
    end

    model:Destroy()
    self:CheckWaveCleared()
end

function EnemyService:ApplyDamage(model: Model, amount: number, player: Player?)
    local data = self.Enemies[model]
    if not data then
        return
    end

    local humanoid = data.Humanoid
    if not humanoid or humanoid.Health <= 0 then
        return
    end

    humanoid:TakeDamage(amount)
    if player then
        data.LastHit = player
    end
end

function EnemyService:CheckWaveCleared()
    if not self.Spawning and self.ActiveEnemies <= 0 then
        self.WaveCleared:Fire()
    end
end

function EnemyService:GetActiveEnemies()
    return self.Enemies
end

function EnemyService:GetRemainingEnemies(): number
    return self.ActiveEnemies
end

function EnemyService:ForceNextWave()
    self.Spawning = false
    for model in pairs(self.Enemies) do
        model:Destroy()
    end
    self.Enemies = {}
    self.TouchCooldowns = {}
    self.ActiveEnemies = 0
    self.WaveCleared:Fire()
end

return EnemyService
