local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local PLAYER_COLLISION_GROUP = "SkillSurvivalPlayers"
local ENEMY_COLLISION_GROUP = "SkillSurvivalEnemies"

local function applyCollisionGroup(instance: Instance, groupName: string)
    if typeof(groupName) ~= "string" or groupName == "" then
        return
    end

    local function setCollisionGroup(part: BasePart)
        if part.CollisionGroup ~= groupName then
            part.CollisionGroup = groupName
        end
    end

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("BasePart") then
            setCollisionGroup(descendant)
        end
    end

    if instance:IsA("Model") then
        instance.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("BasePart") then
                setCollisionGroup(descendant)
            end
        end)
    end
end

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
    self.EnemyCountChanged = Knit.Util.Signal.new()
    self.CollisionGroups = {
        Player = PLAYER_COLLISION_GROUP,
        Enemy = ENEMY_COLLISION_GROUP,
    }
    self:EnsureCollisionGroups()
end

function EnemyService:EnsureCollisionGroups()
    local function ensure(name: string)
        if typeof(name) ~= "string" or name == "" then
            return
        end

        local success, exists = pcall(function()
            if PhysicsService.CollisionGroupExists then
                return PhysicsService:CollisionGroupExists(name)
            end

            PhysicsService:GetCollisionGroupId(name)
            return true
        end)

        if not success or not exists then
            if PhysicsService.RegisterCollisionGroup then
                PhysicsService:RegisterCollisionGroup(name)
            else
                PhysicsService:CreateCollisionGroup(name)
            end
        end
    end

    local playerGroup = self:GetPlayerCollisionGroup()
    local enemyGroup = self:GetEnemyCollisionGroup()

    ensure(playerGroup)
    ensure(enemyGroup)

    if playerGroup and enemyGroup then
        PhysicsService:CollisionGroupSetCollidable(playerGroup, enemyGroup, false)
    end
end

function EnemyService:GetPlayerCollisionGroup(): string
    local groups = self.CollisionGroups
    if groups and typeof(groups.Player) == "string" and groups.Player ~= "" then
        return groups.Player
    end
    return PLAYER_COLLISION_GROUP
end

function EnemyService:GetEnemyCollisionGroup(): string
    local groups = self.CollisionGroups
    if groups and typeof(groups.Enemy) == "string" and groups.Enemy ~= "" then
        return groups.Enemy
    end
    return ENEMY_COLLISION_GROUP
end

function EnemyService:ApplyEnemyCollisionGroup(model: Model)
    if not model then
        return
    end

    applyCollisionGroup(model, self:GetEnemyCollisionGroup())
end

function EnemyService:KnitStart()
    self.RewardService = Knit.GetService("RewardService")
    self.MapService = Knit.GetService("MapService")
    self.CombatService = Knit.GetService("CombatService")

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
    self.EnemyCountChanged:Fire(self.ActiveEnemies)
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
    self.EnemyCountChanged:Fire(self.ActiveEnemies)
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
        self.WaveCleared:Fire()
        return
    end

    local spawnInterval = Config.Enemy.SpawnInterval or 0
    if spawnInterval < 0 then
        spawnInterval = 0
    end

    local maxActive = Config.Enemy.MaxActive
    if type(maxActive) ~= "number" or maxActive <= 0 then
        maxActive = math.huge
    end

    task.spawn(function()
        local index = 1
        while index <= spawnCount do
            if not self.MatchActive then
                break
            end

            while self.MatchActive and self.ActiveEnemies >= maxActive do
                task.wait(math.max(0.1, spawnInterval * 0.25))
            end

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

            index += 1

            if index <= spawnCount then
                task.wait(spawnInterval)
            end
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

    model.PrimaryPart = root
    return model
end

function EnemyService:SpawnEnemy(spawnCFrame: CFrame, stats)
    local model = self:CreateEnemyModel(stats)
    model:SetPrimaryPartCFrame(spawnCFrame)
    model.Parent = self.EnemyFolder
    self:ApplyEnemyCollisionGroup(model)

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
    self.EnemyCountChanged:Fire(self.ActiveEnemies)

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

    local refresh = math.max(0.05, Config.Enemy.PathRefresh)

    while self.MatchActive and humanoid.Health > 0 and model.Parent do
        local targetRoot = self:GetClosestTarget(model)
        local root = model.PrimaryPart

        if targetRoot and targetRoot.Parent and root then
            local reached = false
            local connection
            connection = humanoid.MoveToFinished:Connect(function()
                reached = true
            end)

            humanoid:MoveTo(targetRoot.Position)

            local elapsed = 0
            while self.MatchActive and humanoid.Health > 0 and model.Parent and elapsed < refresh do
                task.wait(0.05)
                elapsed += 0.05

                root = model.PrimaryPart
                if not root then
                    break
                end

                if reached then
                    break
                end

                if not targetRoot.Parent then
                    break
                end

                local distance = (targetRoot.Position - root.Position).Magnitude
                if distance <= 3 then
                    break
                end
            end

            if connection then
                connection:Disconnect()
            end
        else
            local rootPart = model.PrimaryPart
            if rootPart then
                humanoid:MoveTo(rootPart.Position)
            end
            task.wait(refresh)
        end
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
    local now = time()
    local last = cooldowns[player]
    if last and now - last < 1.5 then
        return
    end

    cooldowns[player] = now
    if self.CombatService then
        self.CombatService:ApplyDamageToPlayer(player, enemyData.Stats.Damage, enemyData)
    else
        humanoid:TakeDamage(enemyData.Stats.Damage)
    end
end

function EnemyService:OnEnemyDied(enemyData)
    local model = enemyData.Model
    if not self.Enemies[model] then
        return
    end

    self.Enemies[model] = nil
    self.TouchCooldowns[model] = nil
    self.ActiveEnemies = math.max(0, self.ActiveEnemies - 1)
    self.EnemyCountChanged:Fire(self.ActiveEnemies)

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

function EnemyService:IsSpawning(): boolean
    return self.Spawning
end

function EnemyService:ForceNextWave()
    self.Spawning = false
    for model in pairs(self.Enemies) do
        model:Destroy()
    end
    self.Enemies = {}
    self.TouchCooldowns = {}
    self.ActiveEnemies = 0
    self.EnemyCountChanged:Fire(self.ActiveEnemies)
    self.WaveCleared:Fire()
end

return EnemyService
