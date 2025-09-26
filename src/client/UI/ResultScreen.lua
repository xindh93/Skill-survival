local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local ResultScreen = {}
ResultScreen.__index = ResultScreen

local function findScreenGui(root)
    if not root then
        return nil
    end

    if root:IsA("ScreenGui") then
        return root
    end

    local existing = root:FindFirstChildWhichIsA("ScreenGui", true)
    if existing then
        return existing
    end

    local found
    local connection
    connection = root.DescendantAdded:Connect(function(descendant)
        if not found and descendant:IsA("ScreenGui") then
            found = descendant
        end
    end)

    task.defer(function()
        if connection then
            connection:Disconnect()
        end
    end)

    task.wait()

    return found
end

local function resolveResultScreen(playerGui)
    local container = playerGui:FindFirstChild("ResultScreen")

    if container then
        local screen = findScreenGui(container)
        if screen then
            return screen
        end

        if container:IsA("ScreenGui") then
            return container
        end
    end

    local descendant = playerGui:FindFirstChild("ResultScreen", true)
    if descendant and descendant:IsA("Instance") then
        local screen = findScreenGui(descendant)
        if screen then
            return screen
        end
        if descendant:IsA("ScreenGui") then
            return descendant
        end
    end

    return nil
end

function ResultScreen.new(playerGui)
    local self = setmetatable({}, ResultScreen)

    local screen = resolveResultScreen(playerGui)
    if not screen then
        warn("ResultScreen: no ScreenGui named ResultScreen was found. The result screen will remain disabled.")
        return self
    end

    local container = screen:FindFirstChild("Container")
    local summaryText = container and container:FindFirstChild("SummaryText")
    local statusLabel = container and container:FindFirstChild("StatusLabel")
    local retryButton = container and container:FindFirstChild("RetryButton")
    local lobbyButton = container and container:FindFirstChild("LobbyButton")

    if retryButton and retryButton:IsA("TextButton") then
        retryButton.MouseButton1Click:Connect(function()
            self:OnRetry()
        end)
    end

    if lobbyButton and lobbyButton:IsA("TextButton") then
        lobbyButton.MouseButton1Click:Connect(function()
            self:OnLobby()
        end)
    end

    self.Screen = screen
    self.Container = container
    self.SummaryText = summaryText
    self.StatusLabel = statusLabel

    return self
end

function ResultScreen:OnRetry()
    if self.StatusLabel and self.StatusLabel:IsA("TextLabel") then
        self.StatusLabel.Text = ""
    end

    local success, result = pcall(function()
        return Net:GetFunction("RestartMatch"):InvokeServer()
    end)

    if success and result then
        if self.StatusLabel and self.StatusLabel:IsA("TextLabel") then
            self.StatusLabel.Text = "Restarting..."
        end
        task.wait(0.5)
        self:Hide()
    else
        if self.StatusLabel and self.StatusLabel:IsA("TextLabel") then
            self.StatusLabel.Text = "Unable to restart right now."
        end
    end
end

function ResultScreen:OnLobby()
    if self.StatusLabel and self.StatusLabel:IsA("TextLabel") then
        self.StatusLabel.Text = "Teleporting..."
    end
    Net:GetEvent("LobbyTeleport"):FireServer()
end

local function formatSummary(summary)
    if typeof(summary) ~= "table" then
        return "Session ended."
    end

    local reason = tostring(summary.Reason or "Unknown")
    local wave = tostring(summary.Wave or 0)
    local kills = tostring(summary.Kills or 0)
    local gold = tostring(summary.Gold or 0)
    local xp = tostring(summary.XP or 0)
    local damage = tostring(summary.DamageDealt or 0)
    local assists = tostring(summary.Assists or 0)
    local timeSurvived = tostring(summary.TimeSurvived or 0)

    return string.format(
        "Result: %s\nWave Reached: %s\nKills: %s\nGold: %s\nXP: %s\nDamage Dealt: %s\nAssists: %s\nTime Survived: %ss",
        reason,
        wave,
        kills,
        gold,
        xp,
        damage,
        assists,
        timeSurvived
    )
end

function ResultScreen:Show(summary)
    if not self.Screen or not self.Screen:IsA("ScreenGui") then
        return
    end

    self.Screen.Enabled = true

    if self.SummaryText and self.SummaryText:IsA("TextLabel") then
        self.SummaryText.Text = formatSummary(summary)
    end

    if self.StatusLabel and self.StatusLabel:IsA("TextLabel") then
        self.StatusLabel.Text = ""
    end
end

function ResultScreen:Hide()
    if self.Screen and self.Screen:IsA("ScreenGui") then
        self.Screen.Enabled = false
    end
end

return ResultScreen
