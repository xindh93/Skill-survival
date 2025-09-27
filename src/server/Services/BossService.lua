--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local BossService = Knit.CreateService({
    Name = "BossService",
    Client = {},
})

function BossService:KnitInit()
    self.BossSpawned = Knit.Util.Signal.new()
    self.EnrageTriggered = Knit.Util.Signal.new()
    self.SessionActive = false
    self.MatchStartTime = 0
    self._bossTriggered = false
    self._enrageTriggered = false
end

function BossService:KnitStart()
    RunService.Heartbeat:Connect(function()
        self:_onHeartbeat()
    end)
end

function BossService:_reset()
    self._bossTriggered = false
    self._enrageTriggered = false
end

function BossService:_onHeartbeat()
    if not self.SessionActive then
        return
    end

    local startTime = self.MatchStartTime
    if typeof(startTime) ~= "number" or startTime <= 0 then
        return
    end

    local elapsed = time() - startTime
    local bossTime, enrageTime = self:GetConfiguredTimings()

    if not self._bossTriggered and elapsed >= bossTime then
        self._bossTriggered = true
        self:TriggerBossSpawn(elapsed)
    end

    if not self._enrageTriggered and elapsed >= enrageTime then
        self._enrageTriggered = true
        self:TriggerEnrage(elapsed)
    end
end

function BossService:GetConfiguredTimings(): (number, number)
    local session = Config.Session or {}
    local bossTime = session.BossTime or 480
    local enrageTime = session.EnrageTime or (bossTime + 120)
    bossTime = math.max(0, bossTime)
    enrageTime = math.max(bossTime, enrageTime)
    return bossTime, enrageTime
end

function BossService:StartSession(startTime: number?)
    self.SessionActive = true
    self.MatchStartTime = startTime or time()
    self:_reset()
end

function BossService:StopSession()
    self.SessionActive = false
    self.MatchStartTime = 0
    self:_reset()
end

function BossService:TriggerBossSpawn(elapsed: number)
    self.BossSpawned:Fire(elapsed)
    Net:FireAll("BossSpawned", true)
end

function BossService:TriggerEnrage(elapsed: number)
    self.EnrageTriggered:Fire(elapsed)
    Net:FireAll("BossEnraged")
end

return BossService
