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
end

function UIController:ApplyHUDUpdate(payload)
    for key, value in pairs(payload) do
        if key == "SkillCooldowns" then
            if typeof(value) == "table" then
                for skillId, info in pairs(value) do
                    if typeof(info) == "table" then
                        self.State.SkillCooldowns[skillId] = table.clone(info)
                    else
                        self.State.SkillCooldowns[skillId] = info
                    end
                end
            end
        elseif key == "DashCooldown" then
            self:OnDashCooldown(value)
        elseif key == "Party" then
            if typeof(value) == "table" then
                self.State.Party = table.clone(value)
            else
                self.State.Party = value
            end
        elseif key == "XPProgress" then
            if typeof(value) == "table" then
                self.State.XPProgress = table.clone(value)
            else
                self.State.XPProgress = value
            end
        elseif key == "Level" then
            self.State.Level = value
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
        self.State.Party = table.clone(partyData)
    end

    if self.HUD and self.HUD.Update then
        self.HUD:Update(self.State)
    end
end

return UIController
