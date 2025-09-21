local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)

local HUD = require(script.Parent.Parent.UI.HUD)
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
        SkillCooldowns = {},
    }
end

function UIController:KnitStart()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.HUD = HUD.new(playerGui)
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

    RunService.RenderStepped:Connect(function()
        if not self.HUD then
            return
        end

        local now = Workspace:GetServerTimeNow()
        local hasActive = false
        local toClear = nil

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

        if hasActive or toClear then
            self.HUD:Update(self.State)
        end
    end)

    self.HUD:Update(self.State)
end

function UIController:ApplyHUDUpdate(payload)
    for key, value in pairs(payload) do
        if key == "SkillCooldowns" then
            for skillId, info in pairs(value) do
                self.State.SkillCooldowns[skillId] = info
            end
        else
            self.State[key] = value
        end
    end

    self.HUD:Update(self.State)
end

return UIController
