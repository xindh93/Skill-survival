local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)

local RewardService = Knit.CreateService({
    Name = "RewardService",
    Client = {},
})

function RewardService:KnitInit()
    self.PlayerStats = {} :: {[Player]: Types.PlayerStats}
    self.ResultReasons = {} :: {[Player]: string}
    self.DataStore = nil

    local success, store = pcall(function()
        return DataStoreService:GetDataStore("SS_Session")
    end)

    if success then
        self.DataStore = store
    end

    Players.PlayerAdded:Connect(function(player)
        self:SetupPlayer(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self.PlayerStats[player] = nil
        self.ResultReasons[player] = nil
    end)
end

function RewardService:SetupPlayer(player: Player)
    self.PlayerStats[player] = {
        Gold = 0,
        XP = 0,
        Kills = 0,
        WavesCleared = 0,
        DamageDealt = 0,
        Assists = 0,
    }
    self:PushStats(player)
end

function RewardService:ResetPlayer(player: Player)
    local stats = self.PlayerStats[player]
    if not stats then
        return
    end

    stats.Gold = 0
    stats.XP = 0
    stats.Kills = 0
    stats.WavesCleared = 0
    stats.DamageDealt = 0
    stats.Assists = 0
    self:PushStats(player)
end

function RewardService:ResetAll()
    for player in pairs(self.PlayerStats) do
        self:ResetPlayer(player)
    end
end

function RewardService:PushStats(player: Player)
    local stats = self.PlayerStats[player]
    if not stats then
        return
    end

    Net:FireClient(player, "HUD", {
        Gold = stats.Gold,
        XP = stats.XP,
    })
end

function RewardService:AddGold(player: Player, amount: number)
    local stats = self.PlayerStats[player]
    if not stats then
        return
    end

    stats.Gold = stats.Gold + math.floor(amount)
    self:PushStats(player)
end

function RewardService:AddXP(player: Player, amount: number)
    local stats = self.PlayerStats[player]
    if not stats then
        return
    end

    stats.XP = stats.XP + math.floor(amount)
    self:PushStats(player)
end

function RewardService:RecordKill(player: Player)
    local stats = self.PlayerStats[player]
    if not stats then
        return
    end

    stats.Kills = stats.Kills + 1
    self:PushStats(player)
end

function RewardService:RecordAssist(player: Player)
    local stats = self.PlayerStats[player]
    if not stats then
        return
    end

    stats.Assists = stats.Assists + 1
end

function RewardService:RecordDamage(player: Player, amount: number)
    local stats = self.PlayerStats[player]
    if not stats then
        return
    end

    stats.DamageDealt = stats.DamageDealt + amount
end

function RewardService:AddWaveClearRewards(wave: number)
    for player, stats in pairs(self.PlayerStats) do
        stats.WavesCleared = math.max(stats.WavesCleared, wave)
        stats.Gold = stats.Gold + Config.Rewards.WaveClearGold
        stats.XP = stats.XP + Config.Rewards.WaveClearXP
        self:PushStats(player)
    end
end

function RewardService:FinalizeMatch(reason: string)
    for player, stats in pairs(self.PlayerStats) do
        stats.XP = stats.XP + Config.Rewards.ResultXPBonus
        self.ResultReasons[player] = reason
        self:PushStats(player)
        if self.DataStore then
            pcall(function()
                self.DataStore:SetAsync("player_" .. player.UserId, {
                    Gold = stats.Gold,
                    XP = stats.XP,
                    Timestamp = os.time(),
                })
            end)
        end
    end
end

function RewardService:GetSummary(player: Player): Types.RewardSummary
    local stats = self.PlayerStats[player]
    if not stats then
        error("No stats for player")
    end

    local reason = self.ResultReasons[player] or "Unknown"
    return {
        Gold = stats.Gold,
        XP = stats.XP,
        Kills = stats.Kills,
        WavesCleared = stats.WavesCleared,
        DamageDealt = stats.DamageDealt,
        Assists = stats.Assists,
        Reason = reason,
    }
end

return RewardService
