local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local ResultScreen = {}
ResultScreen.__index = ResultScreen

function ResultScreen.new(playerGui: PlayerGui)
    local self = setmetatable({}, ResultScreen)

    local screen = Instance.new("ScreenGui")
    screen.Name = "ResultScreen"
    screen.ResetOnSpawn = false
    screen.Enabled = false
    screen.IgnoreGuiInset = true
    screen.Parent = playerGui

    local container = Instance.new("Frame")
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.Size = UDim2.new(0, 420, 0, 320)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.Parent = screen

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Session Summary"
    title.TextSize = 28
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.Parent = container

    local summaryText = Instance.new("TextLabel")
    summaryText.BackgroundTransparency = 1
    summaryText.Font = Enum.Font.Gotham
    summaryText.TextColor3 = Color3.new(1, 1, 1)
    summaryText.TextSize = 18
    summaryText.TextXAlignment = Enum.TextXAlignment.Left
    summaryText.TextYAlignment = Enum.TextYAlignment.Top
    summaryText.TextWrapped = true
    summaryText.Size = UDim2.new(1, -40, 0, 160)
    summaryText.Position = UDim2.new(0, 20, 0, 70)
    summaryText.Parent = container

    local statusLabel = Instance.new("TextLabel")
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 16
    statusLabel.Text = ""
    statusLabel.TextWrapped = true
    statusLabel.Size = UDim2.new(1, -40, 0, 40)
    statusLabel.Position = UDim2.new(0, 20, 0, 235)
    statusLabel.Parent = container

    local retryButton = Instance.new("TextButton")
    retryButton.Text = "Play Again"
    retryButton.Font = Enum.Font.GothamSemibold
    retryButton.TextSize = 18
    retryButton.Size = UDim2.new(0.45, 0, 0, 40)
    retryButton.Position = UDim2.new(0.05, 0, 1, -55)
    retryButton.BackgroundColor3 = Color3.fromRGB(40, 170, 100)
    retryButton.BorderSizePixel = 0
    retryButton.TextColor3 = Color3.new(1, 1, 1)
    retryButton.Parent = container

    local lobbyButton = Instance.new("TextButton")
    lobbyButton.Text = "Return to Lobby"
    lobbyButton.Font = Enum.Font.GothamSemibold
    lobbyButton.TextSize = 18
    lobbyButton.Size = UDim2.new(0.45, 0, 0, 40)
    lobbyButton.Position = UDim2.new(0.5, 0, 1, -55)
    lobbyButton.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
    lobbyButton.BorderSizePixel = 0
    lobbyButton.TextColor3 = Color3.new(1, 1, 1)
    lobbyButton.Parent = container

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
