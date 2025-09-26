local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local ResultScreen = {}
ResultScreen.__index = ResultScreen

local function resolveScreenGui(container: Instance): ScreenGui?
    if container:IsA("ScreenGui") then
        return container
    end

    local descendant = container:FindFirstChildWhichIsA("ScreenGui", true)
    if descendant then
        return descendant
    end

    local found: ScreenGui? = nil
    local connection: RBXScriptConnection? = nil

    connection = container.DescendantAdded:Connect(function(child)
        if child:IsA("ScreenGui") then
            found = child
            if connection then
                connection:Disconnect()
            end
        end
    end)

    while container.Parent and not found do
        task.wait()
    end

    if connection then
        connection:Disconnect()
    end

    return found
end

local function formatSummary(summary)
    return string.format(
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
end

function ResultScreen.new(playerGui: PlayerGui)
    local container = playerGui:WaitForChild("ResultScreen")
    local screen = resolveScreenGui(container)

    if not screen then
        error(
            string.format(
                "ResultScreen must be a ScreenGui (found %s)",
                typeof(container) == "Instance" and container.ClassName or typeof(container)
            )
        )
    end

    local self = setmetatable({}, ResultScreen)

    local frame = screen:WaitForChild("Container")
    assert(frame:IsA("Frame"), "ResultScreen.Container must be a Frame")

    local summaryText = frame:WaitForChild("SummaryText")
    local statusLabel = frame:WaitForChild("StatusLabel")
    local retryButton = frame:WaitForChild("RetryButton")
    local lobbyButton = frame:WaitForChild("LobbyButton")

    self.Screen = screen
    self.SummaryText = summaryText :: TextLabel
    self.StatusLabel = statusLabel :: TextLabel

    retryButton.MouseButton1Click:Connect(function()
        self:HandleRetry()
    end)

    lobbyButton.MouseButton1Click:Connect(function()
        self:HandleLobby()
    end)

    return self
end

function ResultScreen:HandleRetry()
    local statusLabel = self.StatusLabel
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

function ResultScreen:HandleLobby()
    self.StatusLabel.Text = "Teleporting..."
    Net:GetEvent("LobbyTeleport"):FireServer()
end

function ResultScreen:Show(summary)
    self.Screen.Enabled = true
    self.SummaryText.Text = formatSummary(summary)
    self.StatusLabel.Text = ""
end

function ResultScreen:Hide()
    self.Screen.Enabled = false
end

return ResultScreen
