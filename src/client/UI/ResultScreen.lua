local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local ResultScreen = {}
ResultScreen.__index = ResultScreen

local function waitForDescendantOfClass(parent: Instance, className: string)
    local descendant = parent:FindFirstChildWhichIsA(className, true)
    if descendant then
        return descendant
    end

    while parent.Parent do
        task.wait()
        descendant = parent:FindFirstChildWhichIsA(className, true)
        if descendant then
            return descendant
        end
    end

    return nil
end

function ResultScreen.new(playerGui: PlayerGui)
    local self = setmetatable({}, ResultScreen)

    local screen = playerGui:WaitForChild("ResultScreen")
    if not screen:IsA("ScreenGui") then
        local descendant = waitForDescendantOfClass(screen, "ScreenGui")
        if not descendant then
            error(
                string.format(
                    "ResultScreen must be a ScreenGui (found %s)",
                    typeof(screen) == "Instance" and screen.ClassName or typeof(screen)
                )
            )
        end

        screen = descendant
    end

    local container = screen:WaitForChild("Container")
    assert(container:IsA("Frame"), "ResultScreen.Container must be a Frame")

    local summaryText = container:WaitForChild("SummaryText") :: TextLabel
    local statusLabel = container:WaitForChild("StatusLabel") :: TextLabel
    local retryButton = container:WaitForChild("RetryButton") :: TextButton
    local lobbyButton = container:WaitForChild("LobbyButton") :: TextButton

    retryButton.MouseButton1Click:Connect(function()
        self:OnRetry(statusLabel)
    end)

    lobbyButton.MouseButton1Click:Connect(function()
        self:OnLobby(statusLabel)
    end)

    self.Screen = screen
    self.SummaryText = summaryText
    self.StatusLabel = statusLabel

    return self
end

function ResultScreen:OnRetry(statusLabel: TextLabel)
    statusLabel.Text = ""
    local success, result = pcall(function()
        return Net:GetFunction("RestartMatch"):InvokeServer()
    end)

    if success and result then
        statusLabel.Text = "Restarting..."
        task.wait(0.5)
        self:Hide()
    else
        statusLabel.Text = "Unable to restart right now."
    end
end

function ResultScreen:OnLobby(statusLabel: TextLabel)
    statusLabel.Text = "Teleporting..."
    Net:GetEvent("LobbyTeleport"):FireServer()
end

function ResultScreen:Show(summary)
    self.Screen.Enabled = true
    self.SummaryText.Text = string.format(
        "Result: %s\nWave Reached: %d\nKills: %d\nGold: %d\nXP: %d\nDamage Dealt: %d\nAssists: %d\nTime Survived: %ds",
        tostring(summary.Reason or "Unknown"),
        summary.Wave or 0,
        summary.Kills or 0,
        summary.Gold or 0,
        summary.XP or 0,
        summary.DamageDealt or 0,
        summary.Assists or 0,
        summary.TimeSurvived or 0
    )
    self.StatusLabel.Text = ""
end

function ResultScreen:Hide()
    self.Screen.Enabled = false
end

return ResultScreen
