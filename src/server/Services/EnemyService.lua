local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

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
    self.MatchActive = false
    self.EnemyCountChanged = Knit.Util.Signal.new()
    self.CollisionGroups = {
        Player = PLAYER_COLLISION_GROUP,
        Enemy = ENEMY_COLLISION_GROUP,
    }
    self.MatchStartTime = 0
    self.MatchStartWorldTime = 0
    self.LastSpawnTime = 0
    self.NextPulseTime = 0
    self.SurgeActiveUntil = nil
    self.LastSurgeStart = nil
    self.SurgeActive = false
    self.CurrentSurgeIndex = 1
    self.SpawnLoopConnection = nil
    self.ActiveCap = Config.Enemy.MaxActive or 80
    self.MaxActiveCap = Config.Enemy.MaxActive or 80
    self.BossPhaseCap = Config.Enemy.BossPhaseMaxActive or self.ActiveCap
    self.LastPortalUse = {} :: {[Instance]: number}
    self.PortalIndex = 0
    self.Random = Random.new()
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
    self.PlayerProgressService = Knit.GetService("PlayerProgressService")

    self.EnemyFolder = Workspace:FindFirstChild("Enemies")
    if not self.EnemyFolder then
        self.EnemyFolder = Instance.new("Folder")
        self.EnemyFolder.Name = "Enemies"
        self.EnemyFolder.Parent = Workspace
    end
end

function EnemyService:StartMatch(startTime: number?)
    self.MatchActive = true
    self.ActiveEnemies = 0
    self.Enemies = {}
    self.TouchCooldowns = {}
    local serverNow = time()
    self.MatchStartTime = startTime or serverNow
    local worldNow = self:GetWorldTime()
    if typeof(self.MatchStartTime) == "number" then
        local delta = serverNow - self.MatchStartTime
        self.MatchStartWorldTime = worldNow - delta
    else
        self.MatchStartWorldTime = worldNow
    end
    local spawnInterval = Config.Enemy.SpawnInterval or 0
    if spawnInterval < 0 then
        spawnInterval = 0
    end
    self.LastSpawnTime = self.MatchStartWorldTime - spawnInterval
    local pulseInterval = Config.Session.PulseInterval or 0
    if pulseInterval > 0 then
        self.NextPulseTime = self.MatchStartWorldTime + pulseInterval
    else
        self.NextPulseTime = 0
    end
    self.SurgeActiveUntil = nil
    self.LastSurgeStart = nil
    self.SurgeActive = false
    self.CurrentSurgeIndex = 1
    self.ActiveCap = self.MaxActiveCap
    self.LastPortalUse = {}
    self.PortalIndex = 0
    self.EnemyFolder:ClearAllChildren()
    self.EnemyCountChanged:Fire(self.ActiveEnemies)

    if self.SpawnLoopConnection then
        self.SpawnLoopConnection:Disconnect()
    end

    self.SpawnLoopConnection = RunService.Heartbeat:Connect(function()
        self:OnHeartbeat()
    end)
end

function EnemyService:StopAll()
    self.MatchActive = false
    self.MatchStartWorldTime = 0
    if self.SpawnLoopConnection then
        self.SpawnLoopConnection:Disconnect()
        self.SpawnLoopConnection = nil
    end

    for model in pairs(self.Enemies) do
        model:Destroy()
    end

    self.Enemies = {}
    self.TouchCooldowns = {}
    self.ActiveEnemies = 0
    self.LastPortalUse = {}
    self.EnemyCountChanged:Fire(self.ActiveEnemies)
end

function EnemyService:SetBossPhaseActiveCap()
    self.ActiveCap = self.BossPhaseCap
end

function EnemyService:OnHeartbeat()
    if not self.MatchActive then
        return
    end

    if self.PlayerProgressService and self.PlayerProgressService:IsWorldFrozen() then
        -- TODO: Pause other enemy subsystems (AI steering, projectiles) during world freeze.
        return
    end

    local worldNow = self:GetWorldTime()
    local matchStart = self.MatchStartWorldTime or worldNow
    local elapsed = math.max(0, worldNow - matchStart)

    self:ProcessSurge(elapsed)
    self:ProcessPulses(elapsed, worldNow)
    self:ProcessContinuousSpawns(elapsed, worldNow)
end

function EnemyService:ProcessSurge(elapsed: number)
    if self.SurgeActiveUntil and elapsed >= self.SurgeActiveUntil then
        self.SurgeActiveUntil = nil
        self.SurgeActive = false
    end

    local surgeTimes = Config.Session.SurgeTimes or {}
    local surgeDuration = Config.Session.SurgeDuration or 0
    local index = self.CurrentSurgeIndex or 1

    while index <= #surgeTimes do
        local startTime = surgeTimes[index]
        if elapsed >= startTime then
            if self.LastSurgeStart ~= startTime then
                self.LastSurgeStart = startTime
                self.SurgeActiveUntil = startTime + surgeDuration
                self.SurgeActive = surgeDuration > 0
                print(string.format("[EnemyService] Rush surge @t=%.2f", elapsed))
                Net:FireAll("RushWarning", "surge")
            end
            self.CurrentSurgeIndex = index + 1
            break
        else
            break
        end
    end

    if not self.SurgeActiveUntil then
        self.SurgeActive = false
    elseif elapsed < self.SurgeActiveUntil then
        self.SurgeActive = true
    end
end

function EnemyService:ProcessPulses(elapsed: number, worldNow: number)
    local interval = Config.Session.PulseInterval or 0
    if interval <= 0 then
        return
    end

    if self.NextPulseTime <= 0 then
        self.NextPulseTime = (self.MatchStartWorldTime or worldNow) + interval
    end

    while worldNow >= self.NextPulseTime do
        print(string.format("[EnemyService] Rush pulse @t=%.2f", elapsed))
        Net:FireAll("RushWarning", "pulse")
        self:SpawnEnemies(Config.Enemy.PulseBonus or 0, elapsed, "pulse")
        self.NextPulseTime += interval
    end
end

function EnemyService:ProcessContinuousSpawns(elapsed: number, worldNow: number)
    local spawnInterval = Config.Enemy.SpawnInterval or 0
    if spawnInterval <= 0 then
        spawnInterval = 0.1
    end

    if self.SurgeActive then
        local multiplier = Config.Enemy.SurgeIntervalMult or 1
        if multiplier > 0 then
            spawnInterval = spawnInterval * multiplier
        end
    end

    while worldNow - self.LastSpawnTime >= spawnInterval do
        if not self:SpawnEnemies(1, elapsed, "continuous") then
            break
        end
        self.LastSpawnTime += spawnInterval
    end
end

function EnemyService:GetSpawnPortals(): {BasePart}
    local portals = {}

    for _, instance in ipairs(CollectionService:GetTagged("SpawnPortal")) do
        local part = self:ResolvePortalPart(instance)
        if part and part.Parent then
            table.insert(portals, part)
        end
    end

    if #portals == 0 and self.MapService then
        for _, part in ipairs(self.MapService:GetEnemySpawns()) do
            if part and part.Parent and part:IsA("BasePart") then
                table.insert(portals, part)
            end
        end
    end

    if #portals == 0 then
        return portals
    end

    local lookup = {}
    for _, portal in ipairs(portals) do
        lookup[portal] = true
    end

    for portal in pairs(self.LastPortalUse) do
        if not lookup[portal] or not portal.Parent then
            self.LastPortalUse[portal] = nil
        end
    end

    return portals
end

function EnemyService:ResolvePortalPart(instance: Instance?): BasePart?
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        return instance:FindFirstChildWhichIsA("BasePart", true)
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

function EnemyService:GetWorldTime(): number
    local service = self.PlayerProgressService
    if service and typeof(service.GetWorldTime) == "function" then
        local ok, result = pcall(function()
            return service:GetWorldTime()
        end)
        if ok and typeof(result) == "number" then
            return result
        end
    end
    return time()
end

function EnemyService:SelectPortal(portals: {BasePart}): BasePart?
    local count = #portals
    if count == 0 then
        return nil
    end

    for _ = 1, count do
        self.PortalIndex = (self.PortalIndex % count) + 1
        local portal = portals[self.PortalIndex]
        if portal and portal.Parent then
            return portal
        end
    end

    return nil
end

function EnemyService:GetNearestPlayerDistance(position: Vector3): number?
    local nearest: number? = nil
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and humanoid.Health > 0 and root then
            local distance = (root.Position - position).Magnitude
            if not nearest or distance < nearest then
                nearest = distance
            end
        end
    end
    return nearest
end

function EnemyService:ComputeEnemyStats(elapsed: number)
    local minutes = math.max(0, elapsed) / 60
    local healthGrowth = Config.Enemy.HealthGrowthRate or 0
    local baseHealth = Config.Enemy.BaseHealth or 70
    local healthMultiplier = math.pow(1 + healthGrowth, minutes)
    local maxHealth = baseHealth * healthMultiplier

    local speedGrowth = Config.Enemy.SpeedGrowthRate or 0
    local speedBonus = math.min(Config.Enemy.MaxSpeedDelta or 0, speedGrowth * minutes)
    local speed = (Config.Enemy.BaseSpeed or 12) + speedBonus

    local damage = (Config.Enemy.BaseDamage or 10) + (Config.Enemy.DamageGrowth or 0) * minutes

    local eliteChance = 0
    if elapsed >= 360 then
        eliteChance = Config.Enemy.EliteChanceAfter6m or Config.Enemy.EliteChanceStart or 0
    elseif elapsed >= 120 then
        eliteChance = Config.Enemy.EliteChanceStart or 0
    end

    local isElite = eliteChance > 0 and self.Random:NextNumber() < eliteChance
    if isElite then
        maxHealth *= 1.75
        damage *= 1.5
        speed += 2
    end

    local reward = Config.Rewards.KillGold or 0
    if isElite then
        reward = math.floor(reward * 1.5)
    end

    return {
        MaxHealth = maxHealth,
        Damage = damage,
        Speed = speed,
        RewardGold = reward,
        IsElite = isElite,
    }
end

function EnemyService:LogSpawn(portal: Instance?, reason: string, attempt: number, nearest: number?, isElite: boolean?, source: string?)
    local portalName = "unknown"
    if portal and portal.Parent then
        portalName = portal:GetFullName()
    end

    local message = string.format("[EnemyService] Spawn %s @Portal=%s, attempts=%d", tostring(reason), portalName, attempt or 0)
    if nearest then
        message ..= string.format(", nearest=%.1f", nearest)
    end
    if source then
        message ..= string.format(", source=%s", source)
    end
    if isElite then
        message ..= ", elite=true"
    end
    print(message)
end

function EnemyService:AttemptSpawn(portals: {BasePart}, stats, elapsed: number, source: string?): boolean
    if #portals == 0 then
        warn("[EnemyService] No spawn portals available")
        return false
    end

    local spawnConfig = Config.Enemy.Spawn or {}
    local maxAttempts = math.max(1, spawnConfig.MaxSpawnAttempts or 8)

    for attempt = 1, maxAttempts do
        local portal = self:SelectPortal(portals)
        if not portal then
            break
        end

        local spawnCFrame, reason, nearest = self:ValidatePortal(portal, spawnConfig)
        if spawnCFrame then
            self.LastPortalUse[portal] = self:GetWorldTime()
            self:SpawnEnemy(spawnCFrame, stats)
            self:LogSpawn(portal, "OK", attempt, nearest, stats.IsElite, source)
            return true
        else
            self:LogSpawn(portal, reason or "Failed", attempt, nearest, stats.IsElite, source)
        end
    end

    return false
end

function EnemyService:SpawnEnemies(count: number, elapsed: number, source: string?): boolean
    count = math.max(0, math.floor(count or 0))
    if count <= 0 then
        return false
    end

    local portals = self:GetSpawnPortals()
    if #portals == 0 then
        warn("[EnemyService] No spawn portals available")
        return false
    end

    local spawned = 0
    for _ = 1, count do
        if not self.MatchActive then
            break
        end

        if self.ActiveEnemies >= self.ActiveCap then
            print(string.format("[EnemyService] Active cap reached (%d/%d) -> skip", self.MaxActiveCap, self.ActiveCap))
            break
        end

        local stats = self:ComputeEnemyStats(elapsed)
        if not self:AttemptSpawn(portals, stats, elapsed, source) then
            break
        end

        spawned += 1
    end

    return spawned > 0
end

function EnemyService:ValidatePortal(portal: BasePart, spawnConfig)
    local now = self:GetWorldTime()
    local cooldown = spawnConfig.PortalCooldown or 0
    local lastUse = self.LastPortalUse[portal]
    if cooldown > 0 and lastUse and (now - lastUse) < cooldown then
        return nil, "Cooldown"
    end

    local part = self:ResolvePortalPart(portal)
    if not part or not part.Parent then
        return nil, "Invalid"
    end

    local separation = spawnConfig.Separation or 0
    local offset = Vector3.zero
    if separation > 0 then
        local radius = math.sqrt(self.Random:NextNumber()) * separation
        local angle = self.Random:NextNumber() * math.pi * 2
        offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
    end

    local origin = part.Position + offset + Vector3.new(0, 6, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {self.EnemyFolder}
    local result = Workspace:Raycast(origin, Vector3.new(0, -20, 0), params)
    if not result then
        return nil, "NoGround"
    end

    local spawnPosition = result.Position + Vector3.new(0, 3, 0)
    local minDistance = spawnConfig.MinSpawnDistance or 0
    local nearest = self:GetNearestPlayerDistance(spawnPosition)
    if minDistance > 0 and nearest and nearest < minDistance then
        return nil, "TooClose", nearest
    end

    return CFrame.new(spawnPosition), "OK", nearest
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
    if stats.IsElite then
        model.Name = "Elite" .. model.Name
        model:SetAttribute("IsElite", true)
    end
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
        local leveling = Config.Leveling
        local xpConfig = leveling and leveling.XP
        local killXP = xpConfig and xpConfig.Kill or Config.Rewards.KillXP
        if self.PlayerProgressService then
            self.PlayerProgressService:AddXP(killer, killXP, "Kill")
        end
    end

    model:Destroy()
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

function EnemyService:GetActiveEnemies()
    return self.Enemies
end

function EnemyService:GetRemainingEnemies(): number
    return self.ActiveEnemies
end

return EnemyService
