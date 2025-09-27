local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local PLAYER_COLLISION_GROUP = "SkillSurvivalPlayers"
local ENEMY_COLLISION_GROUP = "SkillSurvivalEnemies"

local GameStateService = Knit.CreateService({
    Name = "GameStateService",
    Client = {},
})

function GameStateService:KnitInit()
    self.State = "Idle"
    self.MatchStartTime = 0
    self.RestartSignal = Knit.Util.Signal.new()
    self.ResultReason = "Unknown"
    self.BossSpawned = false
    self.EnrageTriggered = false
    self.AwardedMilestones = {}
    self.CharacterConnections = {}
end

function GameStateService:KnitStart()
    self.EnemyService = Knit.GetService("EnemyService")
    self.RewardService = Knit.GetService("RewardService")
    self.MapService = Knit.GetService("MapService")
    self.BossService = Knit.GetService("BossService")

    if self.EnemyService then
        self.PlayerCollisionGroup = self.EnemyService:GetPlayerCollisionGroup()
        self.EnemyCollisionGroup = self.EnemyService:GetEnemyCollisionGroup()
        if self.EnemyService.EnsureCollisionGroups then
            self.EnemyService:EnsureCollisionGroups()
        end
    end

    self.PlayerCollisionGroup = self.PlayerCollisionGroup or PLAYER_COLLISION_GROUP
    self.EnemyCollisionGroup = self.EnemyCollisionGroup or ENEMY_COLLISION_GROUP
    self:EnsureCollisionGroups()

    if self.EnemyService.EnemyCountChanged then
        self.EnemyService.EnemyCountChanged:Connect(function()
            if self.State == "Active" then
                Net:FireAll("HUD", self:GetHUDPayload())
            end
        end)
    end

    if self.BossService then
        if self.BossService.BossSpawned then
            self.BossService.BossSpawned:Connect(function()
                if self.State == "Active" and not self.BossSpawned then
                    self.BossSpawned = true
                    if self.EnemyService and self.EnemyService.SetBossPhaseActiveCap then
                        self.EnemyService:SetBossPhaseActiveCap()
                    end
                end
            end)
        end

        if self.BossService.EnrageTriggered then
            self.BossService.EnrageTriggered:Connect(function()
                if self.State == "Active" and not self.EnrageTriggered then
                    self.EnrageTriggered = true
                    self.ResultReason = "Boss enraged"
                end
            end)
        end
    end

    Net:GetFunction("RestartMatch").OnServerInvoke = function(player)
        return self:RestartMatch(player)
    end

    Net:GetFunction("RequestSummary").OnServerInvoke = function(player)
        return self.RewardService:GetSummary(player)
    end

    Net:GetEvent("LobbyTeleport").OnServerEvent:Connect(function(player)
        self:TeleportToLobby(player)
    end)

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            self:OnCharacterAdded(player, character)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:DisconnectCharacterSignals(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            self:OnCharacterAdded(player, player.Character)
        end
    end
end

function GameStateService:EnsureCollisionGroups()
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

    local playerGroup = self.PlayerCollisionGroup or PLAYER_COLLISION_GROUP
    local enemyGroup = self.EnemyCollisionGroup or ENEMY_COLLISION_GROUP

    ensure(playerGroup)
    ensure(enemyGroup)

    if playerGroup and enemyGroup then
        PhysicsService:CollisionGroupSetCollidable(playerGroup, enemyGroup, false)
    end
end

function GameStateService:ApplyCharacterCollisionGroup(character: Model)
    if not character then
        return
    end

    local groupName = self.PlayerCollisionGroup or PLAYER_COLLISION_GROUP
    if typeof(groupName) ~= "string" or groupName == "" then
        return
    end

    local function setCollisionGroup(part: BasePart)
        if part.CollisionGroup ~= groupName then
            part.CollisionGroup = groupName
        end
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            setCollisionGroup(descendant)
        end
    end

    character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            setCollisionGroup(descendant)
        end
    end)
end

function GameStateService:DisconnectCharacterSignals(player: Player)
    local connections = self.CharacterConnections[player]
    if not connections then
        return
    end

    for _, connection in ipairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end

    self.CharacterConnections[player] = nil
end

function GameStateService:BindTeammateSignals(player: Player, character: Model)
    if not player or not character then
        return
    end

    self:DisconnectCharacterSignals(player)

    local connections = {}
    self.CharacterConnections[player] = connections

    local function connectHumanoid(humanoid: Humanoid)
        if not humanoid then
            return
        end

        table.insert(connections, humanoid.Died:Connect(function()
            local name = player.DisplayName or player.Name
            Net:FireAll("TeammateDown", name)
        end))
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        connectHumanoid(humanoid)
    end

    table.insert(connections, character.ChildAdded:Connect(function(child)
        if child:IsA("Humanoid") then
            connectHumanoid(child)
        end
    end))

    table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:DisconnectCharacterSignals(player)
        end
    end))
end

function GameStateService:OnCharacterAdded(_player: Player, character: Model)
    if not character then
        return
    end

    self:ApplyCharacterCollisionGroup(character)

    task.defer(function()
        self:TeleportCharacterToSpawn(character)
    end)

    self:BindTeammateSignals(_player, character)
end

function GameStateService:TeleportCharacterToSpawn(character: Model)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local spawnCFrame = self.MapService:GetPlayerSpawnCFrame()
    root.CFrame = spawnCFrame
end

function GameStateService:Start()
    if self.MainLoop then
        return
    end

    self.MainLoop = task.spawn(function()
        while true do
            self:RunSession()
            self.State = "Results"

            task.delay(Config.Session.ResultDuration, function()
                if self.State == "Results" then
                    self.RestartSignal:Fire()
                end
            end)

            self.RestartSignal:Wait()
        end
    end)
end

function GameStateService:RestartMatch(player: Player)
    if self.State ~= "Results" then
        return false
    end

    if player and not Players:GetPlayerByUserId(player.UserId) then
        return false
    end

    self.RestartSignal:Fire()
    return true
end

function GameStateService:RunSession()
    self.State = "Active"
    self.ResultReason = "Unknown"
    self.MatchStartTime = time()
    self.BossSpawned = false
    self.EnrageTriggered = false
    self.AwardedMilestones = {}

    self.RewardService:ResetAll()
    self.EnemyService:StartMatch(self.MatchStartTime)

    if self.BossService and self.BossService.StartSession then
        self.BossService:StartSession(self.MatchStartTime)
    end

    local milestoneTimes = {}
    for threshold in pairs(Config.Rewards.MilestoneGold or {}) do
        table.insert(milestoneTimes, threshold)
    end
    table.sort(milestoneTimes)

    Net:FireAll("HUD", self:GetHUDPayload(0))

    local nextHudUpdate = 0

    while self.State == "Active" do
        local now = time()
        local elapsed = math.max(0, now - self.MatchStartTime)

        for _, threshold in ipairs(milestoneTimes) do
            if elapsed >= threshold and not self.AwardedMilestones[threshold] then
                self.AwardedMilestones[threshold] = true
                self.RewardService:GrantMilestoneRewards(threshold)
            end
        end

        if self.EnrageTriggered then
            if self.ResultReason == "Unknown" then
                self.ResultReason = "Boss enraged"
            end
            self.State = "Ended"
            break
        end

        if self:CheckForSessionEnd(elapsed) then
            break
        end

        if now >= nextHudUpdate then
            Net:FireAll("HUD", self:GetHUDPayload(elapsed))
            nextHudUpdate = now + 1
        end

        task.wait(0.1)
    end

    self:FinalizeSession(self.ResultReason)
end

function GameStateService:GetHUDPayload(elapsed: number?)
    elapsed = elapsed or math.max(0, time() - (self.MatchStartTime or time()))
    return {
        State = self.State,
        RemainingEnemies = self.EnemyService and self.EnemyService:GetRemainingEnemies() or 0,
        TimeRemaining = self:GetTimeRemaining(elapsed),
        Elapsed = elapsed,
        Countdown = 0,
    }
end

function GameStateService:GetTimeRemaining(elapsed: number?)
    if Config.Session.Infinite then
        return -1
    end

    elapsed = elapsed or (time() - self.MatchStartTime)
    return math.max(0, Config.Session.TimeLimit - (elapsed or 0))
end

function GameStateService:CheckForSessionEnd(elapsed: number?)
    local alivePlayers = self:GetAlivePlayerCount()
    if alivePlayers <= 0 then
        self.ResultReason = "All players down"
        self.State = "Ended"
        return true
    end

    if not Config.Session.Infinite then
        elapsed = elapsed or (time() - self.MatchStartTime)
        if elapsed >= Config.Session.TimeLimit then
            self.ResultReason = "Time limit"
            self.State = "Ended"
            return true
        end
    end

    return false
end

function GameStateService:GetAlivePlayerCount()
    local alive = 0
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            alive = alive + 1
        end
    end
    return alive
end

function GameStateService:FinalizeSession(reason: string)
    if reason == "Unknown" then
        reason = "Session Complete"
    end

    self.ResultReason = reason
    self.State = "Results"
    self.EnemyService:StopAll()
    if self.BossService and self.BossService.StopSession then
        self.BossService:StopSession()
    end
    self.RewardService:FinalizeMatch(reason)

    Net:FireAll("HUD", {
        State = self.State,
        RemainingEnemies = 0,
        TimeRemaining = 0,
        Elapsed = math.max(0, time() - (self.MatchStartTime or time())),
        Countdown = 0,
    })

    for _, player in ipairs(Players:GetPlayers()) do
        local summary = self.RewardService:GetSummary(player)
        summary.TimeSurvived = math.floor(time() - self.MatchStartTime)
        Net:FireClient(player, "Result", summary)
    end
end

function GameStateService:TeleportToLobby(player: Player)
    local placeId = Config.LOBBY_PLACE_ID
    if placeId <= 0 then
        return
    end

    local success, err = pcall(function()
        TeleportService:Teleport(placeId, player)
    end)

    if not success then
        Net:FireClient(player, "GameState", {
            Type = "TeleportFailed",
            Message = err,
        })
    end
end

return GameStateService
