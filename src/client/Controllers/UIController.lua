local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

local ResultScreen = require(script.Parent.Parent.UI.ResultScreen)

local UIController = Knit.CreateController({
    Name = "UIController",
})

function UIController:KnitInit()
    self.State = {
        State = "Prepare",
        Wave = 0,
        RemainingEnemies = 0,
        TimeRemaining = -1,
        Countdown = 0,
        Gold = 0,
        XP = 0,
        Level = 1,
        XPProgress = nil,
        SkillCooldowns = {},
        DashCooldown = {
            Remaining = 0,
            Cooldown = (Config.Skill and Config.Skill.Dash and Config.Skill.Dash.Cooldown) or 6,
            ReadyTime = 0,
        },
        Party = {},
    }
    self.Options = {ShowNameplates = false}
    self.MatchEndTime = nil
    self.CountdownEndTime = nil
    self.EstimatedEnemyCount = 0
end

function UIController:KnitStart()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.HUD = Knit.GetController("HUDController")
    if self.HUD and self.HUD.CreateInterface and not self.HUD.Screen then
        self.HUD:CreateInterface(playerGui)
    end
    self.ResultScreen = ResultScreen.new(playerGui)

    Net:GetEvent("HUD").OnClientEvent:Connect(function(payload)
        self:ApplyHUDUpdate(payload)
    end)

    Net:GetEvent("GameState").OnClientEvent:Connect(function(data)
        if data.Type == "WaveStart" then
            self.HUD:PlayWaveAnnouncement(data.Wave)
        elseif data.Type == "TeleportFailed" then
            self.HUD:ShowMessage("Teleport failed: " .. tostring(data.Message))
        end
    end)

    Net:GetEvent("Result").OnClientEvent:Connect(function(summary)
        self.HUD:ShowMessage("Session ended: " .. tostring(summary.Reason))
        self.ResultScreen:Show(summary)
    end)

    Net:GetEvent("Combat").OnClientEvent:Connect(function(event)
        if event.Type == "AOE" then
            self.HUD:ShowAOE(event.Position, event.Radius)
        end
    end)

    Net:GetEvent("DashCooldown").OnClientEvent:Connect(function(data)
        self:OnDashCooldown(data)
    end)

    Net:GetEvent("PartyUpdate").OnClientEvent:Connect(function(partyData)
        self:OnPartyUpdate(partyData)
    end)

    Net:GetEvent("EnemySpawned").OnClientEvent:Connect(function()
        self:OnEnemyCountDelta(1)
    end)

    Net:GetEvent("EnemyRemoved").OnClientEvent:Connect(function()
        self:OnEnemyCountDelta(-1)
    end)

    RunService.RenderStepped:Connect(function()
        if not self.HUD then
            return
        end

        local now = Workspace:GetServerTimeNow()
        local needsUpdate = false
        local hasActiveSkill = false
        local toClear = nil

        local dash = self.State.DashCooldown
        if dash and dash.ReadyTime and dash.ReadyTime > 0 then
            local newRemaining = math.max(0, dash.ReadyTime - now)
            if dash.Remaining == nil or math.abs(newRemaining - dash.Remaining) > 0.01 or newRemaining <= 0.05 then
                dash.Remaining = newRemaining
                needsUpdate = true
            else
                dash.Remaining = newRemaining
            end
        end

        for skillId, info in pairs(self.State.SkillCooldowns) do
            local cooldown = info and info.Cooldown or 0
            local timestamp = info and info.Timestamp

            if typeof(timestamp) ~= "number" or cooldown <= 0 then
                toClear = toClear or {}
                table.insert(toClear, skillId)
            else
                local endTime = info.EndTime
                if typeof(endTime) ~= "number" then
                    endTime = timestamp + cooldown
                    info.EndTime = endTime
                end

                local remaining = endTime - now
                if remaining <= 0 then
                    toClear = toClear or {}
                    table.insert(toClear, skillId)
                    needsUpdate = true
                else
                    hasActiveSkill = true
                    if info.Remaining == nil or math.abs(remaining - info.Remaining) > 0.05 then
                        info.Remaining = remaining
                        needsUpdate = true
                    else
                        info.Remaining = remaining
                    end
                end
            end
        end

        if self.CountdownEndTime and self.State.State == "Prepare" then
            local newCountdown = math.max(0, self.CountdownEndTime - now)
            if math.abs(newCountdown - (self.State.Countdown or 0)) > 0.05 then
                self.State.Countdown = newCountdown
                needsUpdate = true
            else
                self.State.Countdown = newCountdown
            end
            if newCountdown <= 0 then
                self.CountdownEndTime = nil
            end
        end

        if self.MatchEndTime and (self.State.TimeRemaining == nil or self.State.TimeRemaining >= 0) then
            local newRemaining = math.max(0, self.MatchEndTime - now)
            if math.abs(newRemaining - (self.State.TimeRemaining or 0)) > 0.05 then
                self.State.TimeRemaining = newRemaining
                needsUpdate = true
            else
                self.State.TimeRemaining = newRemaining
            end
            if newRemaining <= 0 then
                self.MatchEndTime = nil
            end
        end

        if toClear then
            for _, skillId in ipairs(toClear) do
                self.State.SkillCooldowns[skillId] = nil
            end
            needsUpdate = true
        end

        if needsUpdate or hasActiveSkill then
            self.HUD:Update(self.State)
        end
    end)

    self.HUD:Update(self.State)
end

function UIController:ApplyHUDUpdate(payload)
    local now = Workspace:GetServerTimeNow()
    local newState

    for key, value in pairs(payload) do
        if key == "SkillCooldowns" then
            for skillId, info in pairs(value) do
                if typeof(info) == "table" then
                    if typeof(info.Remaining) == "number" and info.Remaining > 0 then
                        info.EndTime = now + info.Remaining
                    else
                        info.EndTime = nil
                    end
                    self.State.SkillCooldowns[skillId] = info
                else
                    self.State.SkillCooldowns[skillId] = nil
                end
            end
        elseif key == "DashCooldown" then
            self:OnDashCooldown(value)
        elseif key == "Party" then
            self.State.Party = value
        elseif key == "XPProgress" then
            self.State.XPProgress = value
        elseif key == "Level" then
            self.State.Level = value
        elseif key == "TimeRemaining" then
            if typeof(value) == "number" then
                if value >= 0 then
                    local remainingValue = math.max(0, value)
                    self.State.TimeRemaining = remainingValue
                    self.MatchEndTime = now + remainingValue
                else
                    self.State.TimeRemaining = value
                    self.MatchEndTime = nil
                end
            else
                self.State.TimeRemaining = -1
                self.MatchEndTime = nil
            end
        elseif key == "Countdown" then
            if typeof(value) == "number" then
                local countdownValue = math.max(0, value)
                self.State.Countdown = countdownValue
                if countdownValue > 0 then
                    self.CountdownEndTime = now + countdownValue
                else
                    self.CountdownEndTime = nil
                end
            else
                self.State.Countdown = 0
                self.CountdownEndTime = nil
            end
        elseif key == "RemainingEnemies" then
            self.State.RemainingEnemies = value
            if typeof(value) == "number" then
                self.EstimatedEnemyCount = math.max(0, value)
            else
                self.EstimatedEnemyCount = 0
            end
        elseif key == "State" then
            newState = value
        else
            self.State[key] = value
        end
    end

    if newState ~= nil then
        self.State.State = newState
        if newState == "Prepare" then
            self.EstimatedEnemyCount = self.State.RemainingEnemies or 0
        elseif newState == "Active" then
            if typeof(self.State.RemainingEnemies) == "number" then
                self.EstimatedEnemyCount = math.max(0, self.State.RemainingEnemies)
            end
        elseif newState == "Results" or newState == "Ended" or newState == "Idle" then
            self.EstimatedEnemyCount = 0
            self.MatchEndTime = nil
        end

        if newState ~= "Prepare" then
            self.CountdownEndTime = nil
            self.State.Countdown = 0
        end
    end

    self.HUD:Update(self.State)
end

function UIController:OnDashCooldown(data)
    local dashState = self.State.DashCooldown
    if not dashState then
        dashState = {}
        self.State.DashCooldown = dashState
    end

    local now = Workspace:GetServerTimeNow()
    local cooldown = dashState.Cooldown or 0
    local remaining = dashState.Remaining or 0

    if typeof(data) == "table" then
        if typeof(data.Cooldown) == "number" then
            cooldown = math.max(0, data.Cooldown)
        end
        if typeof(data.Remaining) == "number" then
            remaining = math.max(0, data.Remaining)
        end
    end

    dashState.Cooldown = cooldown
    dashState.Remaining = remaining
    dashState.ReadyTime = now + remaining
    dashState.LastUpdate = now

    if self.HUD then
        self.HUD:Update(self.State)
    end
end

function UIController:OnPartyUpdate(partyData)
    if typeof(partyData) ~= "table" then
        self.State.Party = {}
    else
        self.State.Party = partyData
    end

    if self.HUD then
        self.HUD:Update(self.State)
    end
end

function UIController:OnPartyUpdate(partyData)
    if typeof(partyData) ~= "table" then
        self.State.Party = {}
    else
        self.State.Party = partyData
    end

    if self.HUD then
        self.HUD:Update(self.State)
    end
end

function UIController:OnEnemyCountDelta(delta)
    if typeof(delta) ~= "number" or delta == 0 then
        return
    end

    if self.State.State == "Results" or self.State.State == "Idle" then
        self.EstimatedEnemyCount = 0
        self.State.RemainingEnemies = 0
        if self.HUD then
            self.HUD:Update(self.State)
        end
        return
    end

    local count = self.EstimatedEnemyCount
    if typeof(count) ~= "number" then
        count = self.State.RemainingEnemies or 0
    end

    count = count + delta
    if count < 0 then
        count = 0
    end

    self.EstimatedEnemyCount = count
    self.State.RemainingEnemies = count

    if self.HUD then
        self.HUD:Update(self.State)
    end
end

function UIController:ApplyOptions(options)
    if typeof(options) ~= "table" then
        return
    end

    if options.ShowNameplates ~= nil then
        self:SetNameplatesEnabled(not not options.ShowNameplates)
    end
end

function UIController:SetNameplatesEnabled(enabled, force)
    enabled = not not enabled

    if not force and self.Options.ShowNameplates == enabled then
        return
    end

    self.Options.ShowNameplates = enabled

    if enabled then
        self:DisconnectNameplateTracking()
        self:ApplyNameplateMode(Enum.HumanoidDisplayDistanceType.Viewer)
    else
        self:ConnectNameplateTracking()
        self:ApplyNameplateMode(Enum.HumanoidDisplayDistanceType.None)
    end
end

function UIController:ApplyNameplateMode(displayType)
    for _, player in ipairs(Players:GetPlayers()) do
        self:ApplyNameplateToPlayer(player, displayType)
    end
end

function UIController:ApplyNameplateToPlayer(player, displayType)
    local character = player.Character
    if character then
        self:ApplyNameplateToCharacter(character, displayType)
    end
end

function UIController:ApplyNameplateToCharacter(character, displayType)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = displayType
    end
end

function UIController:ConnectNameplateTracking()
    self:DisconnectNameplateTracking()

    self.NameplateTrackedPlayers = {}

    local function track(player)
        self:TrackPlayerNameplate(player)
    end

    self.NameplatePlayerAddedConn = Players.PlayerAdded:Connect(track)
    self.NameplatePlayerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        self:UntrackPlayerNameplate(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        track(player)
    end
end

function UIController:DisconnectNameplateTracking()
    if self.NameplatePlayerAddedConn then
        self.NameplatePlayerAddedConn:Disconnect()
        self.NameplatePlayerAddedConn = nil
    end
    if self.NameplatePlayerRemovingConn then
        self.NameplatePlayerRemovingConn:Disconnect()
        self.NameplatePlayerRemovingConn = nil
    end

    for player, connections in pairs(self.NameplateTrackedPlayers) do
        if connections.CharacterAdded then
            connections.CharacterAdded:Disconnect()
        end
        if connections.CharacterRemoving then
            connections.CharacterRemoving:Disconnect()
        end
        if connections.ChildAdded then
            connections.ChildAdded:Disconnect()
        end
        self.NameplateTrackedPlayers[player] = nil
    end
end

function UIController:TrackPlayerNameplate(player)
    self:UntrackPlayerNameplate(player)

    local connections = {}
    self.NameplateTrackedPlayers[player] = connections

    local function apply(character)
        self:ApplyNameplateToCharacter(character, Enum.HumanoidDisplayDistanceType.None)
        if connections.ChildAdded then
            connections.ChildAdded:Disconnect()
        end
        connections.ChildAdded = character.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then
                self:ApplyNameplateToCharacter(character, Enum.HumanoidDisplayDistanceType.None)
            end
        end)
    end

    if player.Character then
        apply(player.Character)
    end

    connections.CharacterAdded = player.CharacterAdded:Connect(function(character)
        apply(character)
    end)

    connections.CharacterRemoving = player.CharacterRemoving:Connect(function(character)
        if connections.ChildAdded then
            connections.ChildAdded:Disconnect()
            connections.ChildAdded = nil
        end
        self:ApplyNameplateToCharacter(character, Enum.HumanoidDisplayDistanceType.Viewer)
    end)
end

function UIController:UntrackPlayerNameplate(player)
    local connections = self.NameplateTrackedPlayers[player]
    if not connections then
        return
    end

    if connections.CharacterAdded then
        connections.CharacterAdded:Disconnect()
    end
    if connections.CharacterRemoving then
        connections.CharacterRemoving:Disconnect()
    end
    if connections.ChildAdded then
        connections.ChildAdded:Disconnect()
    end

    self.NameplateTrackedPlayers[player] = nil
end

return UIController
