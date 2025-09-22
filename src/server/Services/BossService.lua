--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local BossService = Knit.CreateService({
    Name = "BossService",
    Client = {},
})

function BossService:KnitInit()
    self.GameStateService = nil
    self.BossSpawned = Knit.Util.Signal.new()
    self.EnrageTriggered = Knit.Util.Signal.new()
    self._bossTriggered = false
    self._enrageTriggered = false
    self._lastState = nil :: string?
end

local function getTimings()
    local timings = Config.Stage and Config.Stage.Timings
    local bossAt = timings and timings.BossSpawnAtSeconds or 480
    local enrageAt

    if timings then
        if timings.UseRelativeEnrage then
            enrageAt = bossAt + (timings.EnrageAfterBossSeconds or 0)
        else
            enrageAt = timings.EnrageAtSeconds or (bossAt + 120)
        end
    else
        enrageAt = bossAt + 120
    end

    bossAt = math.max(0, bossAt)
    enrageAt = math.max(bossAt, enrageAt)

    return bossAt, enrageAt
end

function BossService:KnitStart()
    self.GameStateService = Knit.GetService("GameStateService")

    RunService.Heartbeat:Connect(function()
        self:_onHeartbeat()
    end)
end

function BossService:_onHeartbeat()
    local gameState = self.GameStateService
    if not gameState then
        return
    end

    if gameState.IsPaused and gameState:IsPaused() then
        return
    end

    local state = gameState.State
    if state ~= "Active" then
        if self._lastState == "Active" then
            self:_resetTriggers()
        end
        self._lastState = state
        return
    end

    if self._lastState ~= "Active" then
        self:_resetTriggers()
    end
    self._lastState = state

    local startTime = gameState.MatchStartTime
    if type(startTime) ~= "number" or startTime <= 0 then
        return
    end

    local elapsed = time() - startTime
    local bossAt, enrageAt = getTimings()

    if not self._bossTriggered and elapsed >= bossAt then
        self._bossTriggered = true
        self:TriggerBossSpawn(elapsed)
    end

    if not self._enrageTriggered and elapsed >= enrageAt then
        self._enrageTriggered = true
        self:TriggerEnrage(elapsed)
    end
end

function BossService:_resetTriggers()
    self._bossTriggered = false
    self._enrageTriggered = false
end

function BossService:GetConfiguredTimings(): (number, number)
    return getTimings()
end

function BossService:TriggerBossSpawn(elapsed: number)
    self.BossSpawned:Fire(elapsed)
end

function BossService:TriggerEnrage(elapsed: number)
    self.EnrageTriggered:Fire(elapsed)
end

return BossService
