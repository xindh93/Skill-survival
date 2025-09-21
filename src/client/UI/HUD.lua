local Workspace = game:GetService("Workspace")

local HUD = {}
HUD.__index = HUD

local function createLabel(parent, text, size, alignment)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Size = size
    label.TextXAlignment = alignment or Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

function HUD.new(playerGui: PlayerGui)
    local self = setmetatable({}, HUD)

    local screen = Instance.new("ScreenGui")
    screen.Name = "SkillSurvivalHUD"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.Parent = playerGui

    local topFrame = Instance.new("Frame")
    topFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    topFrame.BackgroundTransparency = 0.35
    topFrame.BorderSizePixel = 0
    topFrame.Size = UDim2.new(1, 0, 0, 50)
    topFrame.Parent = screen

    local waveLabel = createLabel(topFrame, "Wave 0", UDim2.new(0, 200, 1, 0), Enum.TextXAlignment.Left)
    waveLabel.Position = UDim2.new(0, 16, 0, 0)

    local enemyLabel = createLabel(topFrame, "Enemies: 0", UDim2.new(0, 200, 1, 0), Enum.TextXAlignment.Left)
    enemyLabel.Position = UDim2.new(0, 220, 0, 0)

    local timerLabel = createLabel(topFrame, "Time: ∞", UDim2.new(0, 200, 1, 0), Enum.TextXAlignment.Left)
    timerLabel.Position = UDim2.new(0, 420, 0, 0)

    local rightFrame = Instance.new("Frame")
    rightFrame.BackgroundTransparency = 1
    rightFrame.Size = UDim2.new(0, 200, 0, 100)
    rightFrame.Position = UDim2.new(1, -210, 0, 60)
    rightFrame.Parent = screen

    local goldLabel = createLabel(rightFrame, "Gold: 0", UDim2.new(1, 0, 0.5, -5), Enum.TextXAlignment.Right)
    goldLabel.Position = UDim2.new(0, 0, 0, 0)

    local xpLabel = createLabel(rightFrame, "XP: 0", UDim2.new(1, 0, 0.5, -5), Enum.TextXAlignment.Right)
    xpLabel.Position = UDim2.new(0, 0, 0.5, 0)

    local bottomFrame = Instance.new("Frame")
    bottomFrame.BackgroundTransparency = 1
    bottomFrame.Size = UDim2.new(0, 200, 0, 60)
    bottomFrame.Position = UDim2.new(0, 20, 1, -80)
    bottomFrame.Parent = screen

    local skillLabel = createLabel(bottomFrame, "Q: Ready", UDim2.new(1, 0, 1, 0), Enum.TextXAlignment.Left)

    local messageLabel = createLabel(screen, "", UDim2.new(0, 400, 0, 40), Enum.TextXAlignment.Center)
    messageLabel.Position = UDim2.new(0.5, -200, 0, 60)
    messageLabel.TextTransparency = 1

    local waveAnnouncement = createLabel(screen, "", UDim2.new(0, 350, 0, 60), Enum.TextXAlignment.Center)
    waveAnnouncement.Position = UDim2.new(0.5, -175, 0.5, -100)
    waveAnnouncement.TextTransparency = 1

    self.Screen = screen
    self.WaveLabel = waveLabel
    self.EnemyLabel = enemyLabel
    self.TimerLabel = timerLabel
    self.GoldLabel = goldLabel
    self.XPLabel = xpLabel
    self.SkillLabel = skillLabel
    self.MessageLabel = messageLabel
    self.WaveAnnouncement = waveAnnouncement
    self.LastMessageTask = nil

    return self
end

function HUD:FormatTime(seconds: number)
    seconds = math.max(0, math.floor(seconds + 0.5))
    local minutes = math.floor(seconds / 60)
    local remaining = seconds % 60
    return string.format("%02d:%02d", minutes, remaining)
end

function HUD:Update(state)
    self.WaveLabel.Text = string.format("Wave %d", state.Wave or 0)
    self.EnemyLabel.Text = string.format("Enemies: %d", state.RemainingEnemies or 0)

    if state.Countdown and state.Countdown > 0 then
        self.TimerLabel.Text = string.format("Start In: %ds", math.ceil(state.Countdown))
    elseif state.TimeRemaining and state.TimeRemaining >= 0 then
        self.TimerLabel.Text = "Time Left: " .. self:FormatTime(state.TimeRemaining)
    else
        self.TimerLabel.Text = "Time: ∞"
    end

    self.GoldLabel.Text = string.format("Gold: %d", state.Gold or 0)
    self.XPLabel.Text = string.format("XP: %d", state.XP or 0)

    local info = state.SkillCooldowns and state.SkillCooldowns.AOE_Blast
    if info then
        local elapsed = Workspace:GetServerTimeNow() - info.Timestamp
        local remaining = math.max(0, (info.Cooldown or 0) - elapsed)
        if remaining > 0 then
            self.SkillLabel.Text = string.format("Q: %.1fs", remaining)
        else
            self.SkillLabel.Text = "Q: Ready"
        end
    else
        self.SkillLabel.Text = "Q: Ready"
    end
end

function HUD:ShowMessage(text: string)
    if self.LastMessageTask then
        self.LastMessageTask:Cancel()
        self.LastMessageTask = nil
    end

    self.MessageLabel.TextTransparency = 0
    self.MessageLabel.Text = text

    local thread = task.spawn(function()
        task.wait(3)
        self.MessageLabel.TextTransparency = 1
    end)

    self.LastMessageTask = {
        Cancel = function()
            task.cancel(thread)
            self.MessageLabel.TextTransparency = 1
        end,
    }
end

function HUD:PlayWaveAnnouncement(wave: number)
    self.WaveAnnouncement.Text = string.format("Wave %d", wave)
    self.WaveAnnouncement.TextTransparency = 0
    task.spawn(function()
        task.wait(1.2)
        self.WaveAnnouncement.TextTransparency = 1
    end)
end

function HUD:ShowAOE(position: Vector3, radius: number)
    if typeof(position) ~= "Vector3" then
        return
    end

    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(120, 200, 255)
    ring.Transparency = 0.4
    ring.Anchored = true
    ring.CanCollide = false
    ring.Size = Vector3.new(radius * 2, 0.25, radius * 2)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
    ring.Parent = Workspace

    task.spawn(function()
        for _ = 1, 10 do
            ring.Transparency = ring.Transparency + 0.06
            task.wait(0.05)
        end
        ring:Destroy()
    end)
end

return HUD
