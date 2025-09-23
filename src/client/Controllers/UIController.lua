local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

local ResultScreen = require(script.Parent.Parent.UI.ResultScreen)

local function deepClone(value)
    if typeof(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, item in pairs(value) do
        copy[key] = deepClone(item)
    end

    return copy
end

local UIController = Knit.CreateController({
    Name = "UIController",
})

function UIController:KnitInit()
    self.State = {
        State = "Prepare",
        Wave = 0,
        RemainingEnemies = 0,
        TimeRemaining = -1,
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

    self.Options = {
        ShowNameplates = false,
    }

    self.NameplatePlayerAddedConn = nil
    self.NameplatePlayerRemovingConn = nil
    self.NameplateTrackedPlayers = {}
end

function UIController:KnitStart()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    local playerGui = player:WaitForChild("PlayerGui")
    self.HUD = Knit.GetController("HUDController")
    if self.HUD and self.HUD.CreateInterface and not self.HUD.Screen then
        self.HUD:CreateInterface(playerGui)
    end

    self.ResultScreen = ResultScreen.new(playerGui)

    Net:GetEvent("HUD").OnClientEvent:Connect(function(payload)
        self:ApplyHUDUpdate(payload)
    end)

    Net:GetEvent("GameState").OnClientEvent:Connect(function(data)
        local hud = self.HUD
        if data.Type == "WaveStart" then
            if hud and hud.PlayWaveAnnouncement then
                hud:PlayWaveAnnouncement(data.Wave)
            end
        elseif data.Type == "TeleportFailed" then
            if hud and hud.ShowMessage then
                hud:ShowMessage("Teleport failed: " .. tostring(data.Message))
            end
        end
    end)

    Net:GetEvent("Result").OnClientEvent:Connect(function(summary)
        local hud = self.HUD
        if hud and hud.ShowMessage then
            hud:ShowMessage("Session ended: " .. tostring(summary.Reason))
        end
        self.ResultScreen:Show(summary)
    end)

    Net:GetEvent("Combat").OnClientEvent:Connect(function(event)
        local hud = self.HUD
        if hud and hud.ShowAOE and event.Type == "AOE" then
            hud:ShowAOE(event.Position, event.Radius)
        end
    end)

    Net:GetEvent("DashCooldown").OnClientEvent:Connect(function(data)
        self:OnDashCooldown(data)
    end)

    Net:GetEvent("PartyUpdate").OnClientEvent:Connect(function(partyData)
        self:OnPartyUpdate(partyData)
    end)

    Net:GetEvent("HUDOptions").OnClientEvent:Connect(function(options)
        self:ApplyOptions(options)
    end)

    RunService.RenderStepped:Connect(function()
        local hud = self.HUD
        if not hud or not hud.Update then
            return
        end

        local now = Workspace:GetServerTimeNow()
        local hasActive = false
        local toClear = nil
        local needsUpdate = false

        local dash = self.State.DashCooldown
        if dash and dash.ReadyTime and dash.ReadyTime > 0 then
            local newRemaining = math.max(0, dash.ReadyTime - now)
            if dash.Remaining == nil or math.abs(newRemaining - dash.Remaining) > 0.01 then
                dash.Remaining = newRemaining
                needsUpdate = true
            else
                dash.Remaining = newRemaining
            end
        end

        for skillId, info in pairs(self.State.SkillCooldowns) do
            local cooldown = info.Cooldown or 0
            local timestamp = info.Timestamp

            if not timestamp or cooldown <= 0 then
                toClear = toClear or {}
                table.insert(toClear, skillId)
            else
                local elapsed = now - timestamp
                if elapsed >= cooldown then
                    toClear = toClear or {}
                    table.insert(toClear, skillId)
                else
                    hasActive = true
                end
            end
        end

        if toClear then
            for _, skillId in ipairs(toClear) do
                self.State.SkillCooldowns[skillId] = nil
            end
        end

        if needsUpdate or hasActive or toClear then
            hud:Update(self.State)
        end
    end)

    if self.HUD and self.HUD.Update then
        self.HUD:Update(self.State)
    end

    self:SetNameplatesEnabled(self.Options.ShowNameplates, true)
end

function UIController:ApplyHUDUpdate(payload)
    for key, value in pairs(payload) do
        if key == "SkillCooldowns" then
            if typeof(value) == "table" then
                for skillId, info in pairs(value) do
                    self.State.SkillCooldowns[skillId] = deepClone(info)
                end
            end
        elseif key == "DashCooldown" then
            self:OnDashCooldown(value)
        elseif key == "Party" then
            self.State.Party = deepClone(value)
        elseif key == "XPProgress" then
            self.State.XPProgress = deepClone(value)
        elseif key == "Level" then
            self.State.Level = value
        elseif key == "Options" then
            self:ApplyOptions(value)
        else
            self.State[key] = value
        end
    end

    if self.HUD and self.HUD.Update then
        self.HUD:Update(self.State)
    end
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
        else
            if typeof(data.ReadyTime) == "number" then
                remaining = math.max(0, data.ReadyTime - now)
            elseif typeof(data.EndTime) == "number" then
                remaining = math.max(0, data.EndTime - now)
            elseif typeof(data.Timestamp) == "number" and typeof(data.Cooldown) == "number" then
                remaining = math.max(0, data.Cooldown - (now - data.Timestamp))
            end
        end
    end

    dashState.Cooldown = cooldown
    dashState.Remaining = remaining
    dashState.ReadyTime = now + remaining
    dashState.LastUpdate = now

    if self.HUD and self.HUD.Update then
        self.HUD:Update(self.State)
    end
end

function UIController:OnPartyUpdate(partyData)
    if typeof(partyData) ~= "table" then
        self.State.Party = {}
    else
        self.State.Party = deepClone(partyData)
    end

    if self.HUD and self.HUD.Update then
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
    local character = player and player.Character
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
