local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local PlayerProgressService = Knit.CreateService({
    Name = "PlayerProgressService",
    Client = {},
})

local DEFAULT_CHOICES = {
    {
        id = "atk_+10",
        name = "Power Module",
        desc = "+10% Attack",
        kind = "stat",
        value = 0.10,
    },
    {
        id = "hp_+15",
        name = "Vital Core",
        desc = "+15% Max HP",
        kind = "stat",
        value = 0.15,
    },
    {
        id = "dash+1",
        name = "Swift Step",
        desc = "+1 Dash Charge",
        kind = "perk",
        value = 1,
    },
    {
        id = "ult_cd-10",
        name = "Focus Coil",
        desc = "-10% Ultimate Cooldown",
        kind = "perk",
        value = 0.10,
    },
    {
        id = "resurge",
        name = "Resurge",
        desc = "Heal 35% HP instantly",
        kind = "instant",
        value = 0.35,
    },
}

function PlayerProgressService:KnitInit()
    self.Profiles = {} :: {[Player]: {
        level: number,
        xp: number,
        xpToNext: number,
        isFrozen: boolean,
        queue: { {level: number, carriedXP: number, xpToNext: number} },
        activeLevelUp: {
            level: number,
            carriedXP: number,
            xpToNext: number,
            token: string,
            committed: boolean,
            choices: { [number]: { id: string, name: string, desc: string, kind: string, value: any } }?,
        }?,
    }}
    self.ActiveFreezes = 0
    self.WorldFrozen = false
    self.Random = Random.new()
    self.LevelingConfig = Config.Leveling or {}
end

function PlayerProgressService:KnitStart()
    Players.PlayerAdded:Connect(function(player)
        self:CreateProfile(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:RemoveProfile(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:CreateProfile(player)
    end

    Net:GetFunction("GetProgress").OnServerInvoke = function(player)
        local profile = self:CreateProfile(player)
        return {
            Level = profile.level,
            XP = profile.xp,
            XPToNext = profile.xpToNext,
            MaxLevel = self:GetMaxLevel(),
        }
    end

    Net:GetFunction("GetLevelUpChoices").OnServerInvoke = function(player)
        return self:OnGetLevelUpChoices(player)
    end

    Net:GetEvent("CommitLevelUpChoice").OnServerEvent:Connect(function(player, choiceId)
        self:OnCommitLevelUpChoice(player, choiceId)
    end)
end

function PlayerProgressService:GetMaxLevel(): number
    local maxLevel = self.LevelingConfig and self.LevelingConfig.MaxLevel
    if typeof(maxLevel) == "number" and maxLevel > 0 then
        return math.floor(maxLevel)
    end
    return 50
end

function PlayerProgressService:ComputeXPToNext(level: number): number
    local leveling = self.LevelingConfig
    if leveling and typeof(leveling.XPToNext) == "function" then
        local value = leveling.XPToNext(level)
        if typeof(value) == "number" then
            return math.max(0, math.floor(value))
        end
    end
    local baseXP = (leveling and leveling.BaseXP) or 100
    local growth = (leveling and leveling.Growth) or 1.25
    return math.max(0, math.floor(baseXP * (growth ^ (math.max(1, math.floor(level)) - 1))))
end

function PlayerProgressService:CreateProfile(player: Player)
    local existing = self.Profiles[player]
    if existing then
        return existing
    end

    local profile = {
        level = 1,
        xp = 0,
        xpToNext = self:ComputeXPToNext(1),
        isFrozen = false,
        queue = {},
        activeLevelUp = nil,
    }

    self.Profiles[player] = profile
    return profile
end

function PlayerProgressService:RemoveProfile(player: Player)
    local profile = self.Profiles[player]
    if not profile then
        return
    end

    if profile.isFrozen then
        profile.isFrozen = false
        profile.activeLevelUp = nil
        self.ActiveFreezes = math.max(0, self.ActiveFreezes - 1)
        if self.ActiveFreezes == 0 then
            self:SetWorldFreeze(false)
        end
    end

    self.Profiles[player] = nil
end

function PlayerProgressService:IsWorldFrozen(): boolean
    return self.WorldFrozen
end

function PlayerProgressService:SetWorldFreeze(enabled: boolean)
    if enabled then
        if not self.WorldFrozen then
            self.WorldFrozen = true
            Net:FireAll("SetWorldFreeze", true)
        end
    else
        if self.WorldFrozen then
            self.WorldFrozen = false
            Net:FireAll("SetWorldFreeze", false)
        end
    end
end

function PlayerProgressService:GetProfile(player: Player)
    return self.Profiles[player]
end

function PlayerProgressService:AddXP(player: Player, amount: number, reason: string?)
    local profile = self:GetProfile(player)
    if not profile then
        return
    end

    if typeof(amount) ~= "number" or not amount or amount <= 0 or amount ~= amount then
        return
    end

    local maxLevel = self:GetMaxLevel()
    if profile.level >= maxLevel then
        profile.level = maxLevel
        profile.xp = 0
        profile.xpToNext = 0
        self:FireXPChanged(player, profile)
        return
    end

    profile.xp += amount

    local leveled = false
    while profile.level < maxLevel and profile.xpToNext > 0 and profile.xp >= profile.xpToNext do
        local carried = profile.xp - profile.xpToNext
        profile.level += 1
        profile.xp = math.max(0, carried)
        profile.xpToNext = self:ComputeXPToNext(profile.level)

        profile.queue[#profile.queue + 1] = {
            level = profile.level,
            carriedXP = profile.xp,
            xpToNext = profile.xpToNext,
        }

        leveled = true

        if profile.level >= maxLevel then
            profile.level = maxLevel
            profile.xp = 0
            profile.xpToNext = 0
            profile.queue = {}
            break
        end
    end

    if leveled then
        self:ProcessQueue(player, profile)
    elseif not profile.isFrozen then
        self:FireXPChanged(player, profile)
    end
end

function PlayerProgressService:ProcessQueue(player: Player, profile)
    if profile.isFrozen then
        return
    end

    local nextEntry = profile.queue[1]
    if not nextEntry then
        return
    end

    self:BeginLevelUpFreeze(player, profile, nextEntry)
end

function PlayerProgressService:BeginLevelUpFreeze(player: Player, profile, entry)
    profile.isFrozen = true
    self.ActiveFreezes += 1
    if self.ActiveFreezes == 1 then
        self:SetWorldFreeze(true)
    end

    profile.activeLevelUp = {
        level = entry.level,
        carriedXP = entry.carriedXP,
        xpToNext = entry.xpToNext,
        token = HttpService:GenerateGUID(false),
        committed = false,
        choices = nil,
    }

    Net:FireAll("LevelUp", player, entry.level, entry.carriedXP)
end

function PlayerProgressService:GenerateChoices(player: Player, profile)
    local pool = DEFAULT_CHOICES
    local count = math.min(3, #pool)
    local used = {}
    local results = {}
    for _ = 1, count do
        local index
        repeat
            index = self.Random:NextInteger(1, #pool)
        until not used[index]
        used[index] = true
        local entry = pool[index]
        results[#results + 1] = table.clone(entry)
    end
    return results
end

function PlayerProgressService:OnGetLevelUpChoices(player: Player)
    local profile = self:GetProfile(player)
    if not profile or not profile.isFrozen then
        return nil
    end

    local active = profile.activeLevelUp
    if not active or active.committed then
        return nil
    end

    if not active.choices then
        active.choices = self:GenerateChoices(player, profile)
    end

    return {
        Token = active.token,
        Choices = active.choices,
    }
end

function PlayerProgressService:OnCommitLevelUpChoice(player: Player, choiceId: string)
    local profile = self:GetProfile(player)
    if not profile or not profile.isFrozen then
        return
    end

    local active = profile.activeLevelUp
    if not active or active.committed then
        return
    end

    if typeof(choiceId) ~= "string" or choiceId == "" then
        return
    end

    local chosen = nil
    if active.choices then
        for _, option in ipairs(active.choices) do
            if option.id == choiceId then
                chosen = option
                break
            end
        end
    end

    if not chosen then
        return
    end

    active.committed = true
    profile.lastChoice = chosen

    -- TODO: integrate stat and perk application once systems are available.

    self:CompleteLevelUp(player, profile)
end

function PlayerProgressService:CompleteLevelUp(player: Player, profile)
    if profile.queue[1] then
        table.remove(profile.queue, 1)
    end

    profile.activeLevelUp = nil
    profile.isFrozen = false
    self.ActiveFreezes = math.max(0, self.ActiveFreezes - 1)
    if self.ActiveFreezes == 0 then
        self:SetWorldFreeze(false)
    end

    self:FireXPChanged(player, profile)
    self:ProcessQueue(player, profile)
end

function PlayerProgressService:FireXPChanged(player: Player, profile)
    Net:FireAll("XPChanged", player, profile.xp, profile.xpToNext)
end

return PlayerProgressService
