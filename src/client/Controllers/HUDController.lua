local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local HUDController = Knit.CreateController({
    Name = "HUDController",
})

local function createTextLabel(
    parent: Instance,
    text: string,
    font: Enum.Font,
    textSize: number,
    alignment: Enum.TextXAlignment,
    name: string?
)
    local label = Instance.new("TextLabel")
    label.Name = name or "TextLabel"
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = font
    label.TextScaled = false
    label.TextSize = textSize
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = alignment or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextStrokeTransparency = 0.6
    label.Parent = parent
    return label
end

function HUDController:KnitInit()
    self.Elements = {}
    self.LastMessageTask = nil
    self.AlertTasks = {}
    self.InterfaceSignal = Instance.new("BindableEvent")
    self.InterfaceSignal.Name = "HUDInterfaceReady"
end

function HUDController:KnitStart()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    local playerGui = player:WaitForChild("PlayerGui")
    local function tryAttach(screen)
        if screen and screen:IsA("ScreenGui") and screen.Name == "SkillSurvivalHUD" then
            self:UseExistingInterface(screen)
        end
    end

    local existing = playerGui:FindFirstChild("SkillSurvivalHUD")
    if existing then
        tryAttach(existing)

    end

    playerGui.ChildAdded:Connect(function(child)
        if child.Name == "SkillSurvivalHUD" then
            task.defer(tryAttach, child)
        end
    end)
end

function HUDController:EnsureInterface(playerGui: PlayerGui?)
    if self.Screen and self.Screen.Parent then
        return self.Screen
    end

    playerGui = playerGui or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    if not playerGui then
        local player = Players.LocalPlayer
        if player then
            playerGui = player:FindFirstChild("PlayerGui")
        end
    end

    if not playerGui then
        return nil
    end

    local screen = playerGui:FindFirstChild("SkillSurvivalHUD")
    if not screen then
        screen = playerGui:WaitForChild("SkillSurvivalHUD", 5)
    end

    if not screen then
        warn("HUDController: SkillSurvivalHUD missing from PlayerGui")
        return nil
    end

    self:UseExistingInterface(screen)
    return self.Screen
end

function HUDController:KnitShutdown()
    if self.InterfaceSignal then
        self.InterfaceSignal:Destroy()
        self.InterfaceSignal = nil
    end
    self.Screen = nil
    self.Elements = {}
end

function HUDController:OnInterfaceReady(callback)
    if typeof(callback) ~= "function" then
        return nil
    end

    if self.Screen then
        task.defer(callback, self.Screen)
    end

    if not self.InterfaceSignal then
        local signal = Instance.new("BindableEvent")
        signal.Name = "HUDInterfaceReady"
        self.InterfaceSignal = signal
    end

    return self.InterfaceSignal.Event:Connect(callback)
end

local function resolveCooldownSlot(root: Instance?)
    if not root then
        return nil
    end

    local slot = root:FindFirstChild("Slot")
    local gauge = slot and slot:FindFirstChild("Gauge")
    local cooldownLabel = gauge and gauge:FindFirstChild("CooldownLabel")
    local keyLabel = gauge and gauge:FindFirstChild("KeyLabel")

    if not (slot and gauge and cooldownLabel and keyLabel) then
        return nil
    end

    return {
        Container = root,
        Gauge = gauge,
        CooldownLabel = cooldownLabel,
        KeyLabel = keyLabel,
    }
end

function HUDController:CaptureInterfaceElements(screen: ScreenGui, abilityConfig, dashConfig, uiConfig)
    uiConfig = uiConfig or {}
    abilityConfig = abilityConfig or {}
    dashConfig = dashConfig or {}

    local safeFrame = screen:FindFirstChild("SafeFrame")
    if not safeFrame then
        warn("HUDController: SafeFrame missing from HUD")
        self.Screen = screen
        self.Elements = {}
        if self.InterfaceSignal then
            self.InterfaceSignal:Fire(screen)
        end
        return
    end

    local leftColumn = safeFrame:FindFirstChild("LeftColumn")
    local statusPanel = leftColumn and leftColumn:FindFirstChild("StatusPanel")
    local xpPanel = leftColumn and leftColumn:FindFirstChild("XPPanel")
    local waveLabel = statusPanel and statusPanel:FindFirstChild("WaveLabel")
    local enemyLabel = statusPanel and statusPanel:FindFirstChild("EnemyLabel")
    local timerLabel = statusPanel and statusPanel:FindFirstChild("TimerLabel")
    local goldLabel = statusPanel and statusPanel:FindFirstChild("GoldLabel")

    local xpHeader = xpPanel and xpPanel:FindFirstChild("XPHeader")
    local xpLabel = xpHeader and xpHeader:FindFirstChild("XPText")
    local levelLabel = xpHeader and xpHeader:FindFirstChild("LevelLabel")
    local xpBar = xpPanel and xpPanel:FindFirstChild("XPBar")
    local xpFill = xpBar and xpBar:FindFirstChild("Fill")

    local alertArea = safeFrame:FindFirstChild("AlertArea")
    local waveAnnouncement = alertArea and alertArea:FindFirstChild("WaveAnnouncement")
    local messageLabel = alertArea and alertArea:FindFirstChild("MessageLabel")
    local reservedAlert = alertArea and alertArea:FindFirstChild("ReservedAlerts")
    local reservedLabel = reservedAlert and reservedAlert:FindFirstChild("ReservedLabel")

    local abilityFrame = safeFrame:FindFirstChild("AbilityFrame")
    local skillSlot = abilityFrame and abilityFrame:FindFirstChild("SkillSlot")
    local dashSlot = abilityFrame and abilityFrame:FindFirstChild("DashSlot")

    local skill = resolveCooldownSlot(skillSlot)
    local dash = resolveCooldownSlot(dashSlot)

    if not (skill and dash) then
        warn("HUDController: Ability slots missing or malformed")
        self.Screen = screen
        self.Elements = {}
        if self.InterfaceSignal then
            self.InterfaceSignal:Fire(screen)
        end
        return
    end

    local safeMargin = uiConfig.SafeMargin or 24
    local infoTextSize = uiConfig.InfoTextSize or 18
    local smallTextSize = uiConfig.SmallTextSize or 16
    local alertTextSize = uiConfig.AlertTextSize or 20
    local sidePanelWidth = uiConfig.SidePanelWidth or uiConfig.TopInfoWidth or 260
    local sectionSpacing = uiConfig.SectionSpacing or 12
    local panelBackground = uiConfig.PanelBackgroundColor or uiConfig.TopBarBackgroundColor or Color3.fromRGB(18, 24, 32)
    local panelTransparency = uiConfig.PanelBackgroundTransparency or uiConfig.TopBarTransparency or 0.35
    local panelCornerRadius = uiConfig.PanelCornerRadius or 12
    local panelStrokeColor = uiConfig.PanelStrokeColor or Color3.fromRGB(80, 120, 160)
    local panelStrokeThickness = uiConfig.PanelStrokeThickness or 1.5
    local panelStrokeTransparency = uiConfig.PanelStrokeTransparency or 0.45
    local panelPadding = uiConfig.PanelPadding or 12

    local dashSize = dashConfig.Size or 72
    local abilityWidth = abilityConfig.Width or 260
    local abilityHeight = abilityConfig.Height or 90
    local abilitySpacing = abilityConfig.Spacing or 12
    local abilityBottomOffset = abilityConfig.BottomOffset or 0
    local skillSlotSize = abilityConfig.SkillSize or dashSize

    abilityWidth = math.max(abilityWidth, skillSlotSize + abilitySpacing + dashSize)
    abilityHeight = math.max(abilityHeight, math.max(skillSlotSize, dashSize))

    local reservedBottom = math.max(0, abilityHeight + abilityBottomOffset + sectionSpacing)

    safeFrame.Size = UDim2.new(1, -safeMargin * 2, 1, -safeMargin * 2)
    safeFrame.Position = UDim2.new(0, safeMargin, 0, safeMargin)

    if leftColumn then
        leftColumn.Size = UDim2.new(0, sidePanelWidth, 1, -reservedBottom)
        local leftLayout = leftColumn:FindFirstChildWhichIsA("UIListLayout")
        if leftLayout then
            leftLayout.Padding = UDim.new(0, sectionSpacing)
        end
    end

    if statusPanel then
        statusPanel.BackgroundColor3 = panelBackground
        statusPanel.BackgroundTransparency = panelTransparency
        local statusCorner = statusPanel:FindFirstChildWhichIsA("UICorner")
        if statusCorner then
            statusCorner.CornerRadius = UDim.new(0, panelCornerRadius)
        end
        local statusStroke = statusPanel:FindFirstChildWhichIsA("UIStroke")
        if statusStroke then
            statusStroke.Color = panelStrokeColor
            statusStroke.Thickness = panelStrokeThickness
            statusStroke.Transparency = panelStrokeTransparency
            statusStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        end
        local statusPadding = statusPanel:FindFirstChildWhichIsA("UIPadding")
        if statusPadding then
            statusPadding.PaddingTop = UDim.new(0, panelPadding)
            statusPadding.PaddingBottom = UDim.new(0, panelPadding)
            statusPadding.PaddingLeft = UDim.new(0, panelPadding)
            statusPadding.PaddingRight = UDim.new(0, panelPadding)
        end
        if waveLabel then
            waveLabel.TextSize = uiConfig.TopLabelTextSize or 20
        end
        if enemyLabel then
            enemyLabel.TextSize = infoTextSize
        end
        if timerLabel then
            timerLabel.TextSize = infoTextSize
        end
        if goldLabel then
            goldLabel.TextSize = infoTextSize
        end
    end

    if xpPanel then
        xpPanel.BackgroundColor3 = panelBackground
        xpPanel.BackgroundTransparency = panelTransparency
        local xpCorner = xpPanel:FindFirstChildWhichIsA("UICorner")
        if xpCorner then
            xpCorner.CornerRadius = UDim.new(0, panelCornerRadius)
        end
        local xpStroke = xpPanel:FindFirstChildWhichIsA("UIStroke")
        if xpStroke then
            xpStroke.Color = panelStrokeColor
            xpStroke.Thickness = panelStrokeThickness
            xpStroke.Transparency = panelStrokeTransparency
            xpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        end
        local xpPadding = xpPanel:FindFirstChildWhichIsA("UIPadding")
        if xpPadding then
            xpPadding.PaddingTop = UDim.new(0, panelPadding)
            xpPadding.PaddingBottom = UDim.new(0, panelPadding)
            xpPadding.PaddingLeft = UDim.new(0, panelPadding)
            xpPadding.PaddingRight = UDim.new(0, panelPadding)
        end
        local xpHeader = xpPanel:FindFirstChild("XPHeader")
        if xpHeader then
            xpHeader.Size = UDim2.new(1, 0, 0, uiConfig.XP and uiConfig.XP.LabelHeight or 24)
        end
        if xpLabel then
            xpLabel.TextSize = uiConfig.XP and uiConfig.XP.LabelTextSize or infoTextSize
        end
        if levelLabel then
            levelLabel.TextSize = uiConfig.XP and uiConfig.XP.LevelTextSize or alertTextSize
            levelLabel.Size = UDim2.new(0, (uiConfig.XP and uiConfig.XP.LevelWidth) or 60, 1, 0)
        end
        if xpBar then
            xpBar.BackgroundColor3 = uiConfig.XP and uiConfig.XP.BackgroundColor or panelBackground
            xpBar.BackgroundTransparency = uiConfig.XP and uiConfig.XP.BackgroundTransparency or 0.45
            xpBar.Size = UDim2.new(1, 0, 0, (uiConfig.XP and uiConfig.XP.BarHeight) or 18)
            local barCorner = xpBar:FindFirstChildWhichIsA("UICorner")
            if barCorner then
                barCorner.CornerRadius = UDim.new(0, (uiConfig.XP and uiConfig.XP.CornerRadius) or 9)
            end
        end
        if xpFill then
            xpFill.BackgroundColor3 = uiConfig.XP and uiConfig.XP.FillColor or Color3.fromRGB(88, 182, 255)
            xpFill.BackgroundTransparency = uiConfig.XP and uiConfig.XP.FillTransparency or 0.05
            local fillCorner = xpFill:FindFirstChildWhichIsA("UICorner")
            if fillCorner then
                fillCorner.CornerRadius = UDim.new(0, (uiConfig.XP and uiConfig.XP.CornerRadius) or 9)
            end
        end
    end

    if alertArea then
        local alertOffset = sidePanelWidth + sectionSpacing
        local totalPadding = alertOffset * 2
        local alertHeight = uiConfig.AlertAreaHeight or 160
        alertArea.AnchorPoint = Vector2.new(0.5, 0)
        alertArea.Position = UDim2.new(0.5, 0, 0, uiConfig.AlertAreaOffset or 12)
        if safeFrame.AbsoluteSize.X > 0 and safeFrame.AbsoluteSize.X - totalPadding < (uiConfig.AlertAreaMinWidth or 240) then
            alertArea.Size = UDim2.new(0, math.max(uiConfig.AlertAreaMinWidth or 240, safeFrame.AbsoluteSize.X - totalPadding), 0, alertHeight)
        else
            alertArea.Size = UDim2.new(1, -totalPadding, 0, alertHeight)
        end
        local alertLayout = alertArea:FindFirstChildWhichIsA("UIListLayout")
        if alertLayout then
            alertLayout.Padding = UDim.new(0, uiConfig.AlertPadding or 8)
        end
        if waveAnnouncement then
            waveAnnouncement.TextSize = alertTextSize
            waveAnnouncement.Size = UDim2.new(1, 0, 0, uiConfig.WaveAnnouncementHeight or 48)
        end
        if messageLabel then
            messageLabel.TextSize = alertTextSize
            messageLabel.Size = UDim2.new(1, 0, 0, uiConfig.MessageHeight or 40)
        end
        if reservedAlert then
            reservedAlert.BackgroundTransparency = 1
            reservedAlert.Size = UDim2.new(1, 0, 0, uiConfig.ReservedAlertHeight or 52)
            local reservedCorner = reservedAlert:FindFirstChildWhichIsA("UICorner")
            if reservedCorner then
                reservedCorner.CornerRadius = UDim.new(0, uiConfig.ReservedAlertCornerRadius or 10)
            end
        end
        if reservedLabel then
            reservedLabel.TextSize = alertTextSize
        end
    end

    if abilityFrame then
        abilityFrame.AnchorPoint = Vector2.new(0, 1)
        abilityFrame.Position = UDim2.new(0, 0, 1, -abilityBottomOffset)
        abilityFrame.Size = UDim2.new(0, abilityWidth, 0, abilityHeight)
        local abilityLayout = abilityFrame:FindFirstChildWhichIsA("UIListLayout")
        if abilityLayout then
            abilityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            abilityLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
            abilityLayout.Padding = UDim.new(0, abilitySpacing)
        end
    end

    skill.Container.Size = UDim2.new(0, skillSlotSize, 0, skillSlotSize)
    dash.Container.Size = UDim2.new(0, dashSize, 0, dashSize)

    skill.Gauge.BackgroundColor3 = abilityConfig.SkillBackgroundColor or Color3.fromRGB(18, 24, 32)
    skill.Gauge.BackgroundTransparency = abilityConfig.SkillBackgroundTransparency or 0.25
    local skillStroke = skill.Gauge:FindFirstChildWhichIsA("UIStroke")
    if skillStroke then
        skillStroke.Color = abilityConfig.SkillStrokeColor or Color3.fromRGB(255, 196, 110)
        skillStroke.Thickness = abilityConfig.SkillStrokeThickness or 2
        skillStroke.Transparency = abilityConfig.SkillStrokeTransparency or 0.2
        skillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    end
    dash.Gauge.BackgroundColor3 = dashConfig.BackgroundColor or Color3.fromRGB(18, 24, 32)
    dash.Gauge.BackgroundTransparency = dashConfig.BackgroundTransparency or 0.25
    local dashStroke = dash.Gauge:FindFirstChildWhichIsA("UIStroke")
    if dashStroke then
        dashStroke.Color = dashConfig.StrokeColor or Color3.fromRGB(120, 200, 255)
        dashStroke.Thickness = dashConfig.StrokeThickness or 2
        dashStroke.Transparency = dashConfig.StrokeTransparency or 0.2
        dashStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    end

    self.Screen = screen
    self.SkillDisplayKey = abilityConfig.SkillKey or "Q"
    local skillReadyText = abilityConfig.SkillReadyText
    if skillReadyText == nil then
        skillReadyText = "0.0"
    else
        skillReadyText = tostring(skillReadyText)
    end
    self.SkillReadyText = skillReadyText
    self.SkillReadyColor = abilityConfig.SkillReadyColor or Color3.fromRGB(255, 235, 200)
    self.PrimarySkillId = abilityConfig.PrimarySkillId or "AOE_Blast"
    local dashReadyText = dashConfig.ReadyText
    if dashReadyText == nil then
        dashReadyText = "0.0"
    else
        dashReadyText = tostring(dashReadyText)
    end
    self.DashReadyText = dashReadyText
    self.DashReadyColor = dashConfig.ReadyColor or Color3.fromRGB(180, 255, 205)

    skill.KeyLabel.Text = self.SkillDisplayKey
    skill.CooldownLabel.Text = self.SkillReadyText
    skill.CooldownLabel.TextColor3 = self.SkillReadyColor
    dash.KeyLabel.Text = dashConfig.KeyText or "E"
    dash.CooldownLabel.Text = self.DashReadyText
    dash.CooldownLabel.TextColor3 = self.DashReadyColor

    self.Elements = {
        WaveLabel = waveLabel,
        EnemyLabel = enemyLabel,
        TimerLabel = timerLabel,
        GoldLabel = goldLabel,
        SkillCooldownLabel = skill.CooldownLabel,
        SkillKeyLabel = skill.KeyLabel,
        DashCooldownLabel = dash.CooldownLabel,
        MessageLabel = messageLabel,
        WaveAnnouncement = waveAnnouncement,
        ReservedAlert = reservedAlert,
        ReservedAlertLabel = reservedLabel,
        XPFill = xpFill,
        XPTextLabel = xpLabel,
        LevelLabel = levelLabel,
        XPBar = xpBar,
    }

    if self.InterfaceSignal then
        self.InterfaceSignal:Fire(screen)
    end
end

function HUDController:UseExistingInterface(screen: ScreenGui)
    local uiConfig = Config.UI or {}
    local abilityConfig = uiConfig.Abilities or {}
    local dashConfig = uiConfig.Dash or {}

    if self.Screen == screen then
        return
    end


    screen.Enabled = true

    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = false
    screen.DisplayOrder = (uiConfig.DisplayOrder and uiConfig.DisplayOrder.HUD) or 0

    self:CaptureInterfaceElements(screen, abilityConfig, dashConfig, uiConfig)
end

local function formatTime(seconds: number): string
    seconds = math.max(0, math.floor(seconds + 0.5))
    local minutes = math.floor(seconds / 60)
    local remaining = seconds % 60
    return string.format("%02d:%02d", minutes, remaining)
end

function HUDController:Update(state)
    if not self.Elements.WaveLabel then
        return
    end

    local wave = state.Wave or 0
    self.Elements.WaveLabel.Text = string.format("Wave %d", wave)

    local enemies = state.RemainingEnemies or 0
    if typeof(enemies) == "number" then
        enemies = math.max(0, math.floor(enemies + 0.5))
    else
        enemies = 0
    end
    self.Elements.EnemyLabel.Text = string.format("Enemies: %d", enemies)

    if state.Countdown and state.Countdown > 0 then
        local countdown = math.max(0, state.Countdown)
        local rounded = math.floor((countdown * 10) + 0.5) / 10
        self.Elements.TimerLabel.Text = string.format("Time: %.1fs", rounded)
    elseif state.TimeRemaining and state.TimeRemaining >= 0 then
        self.Elements.TimerLabel.Text = "Time: " .. formatTime(state.TimeRemaining)
    else
        self.Elements.TimerLabel.Text = "Time: ∞"
    end

    local gold = state.Gold or 0
    if typeof(gold) == "number" then
        gold = math.floor(gold + 0.5)
    else
        gold = 0
    end
    self.Elements.GoldLabel.Text = string.format("Gold: %d", gold)

    self:UpdateXP(state)
    self:UpdateSkillCooldowns(state.SkillCooldowns)
    self:UpdateDashCooldown(state.DashCooldown)
end

function HUDController:UpdateXP(state)
    local xpFill = self.Elements.XPFill
    local xpLabel = self.Elements.XPTextLabel
    local levelLabel = self.Elements.LevelLabel

    if not xpFill or not xpLabel or not levelLabel then
        return
    end

    local xpConfig = Config.UI and Config.UI.XP or {}
    local prefix = xpConfig.LabelPrefix or "XP"
    prefix = string.gsub(prefix, "^%s+", "")
    prefix = string.gsub(prefix, "%s+$", "")
    local function composeXPText(valueText: string): string
        if prefix ~= "" then
            return prefix .. valueText
        end
        return valueText
    end

    local levelValue = tonumber(state.Level)
    if levelValue then
        levelLabel.Text = string.format("Lv%d", math.max(1, math.floor(levelValue + 0.5)))
    else
        levelLabel.Text = "Lv1"
    end

    local progress = state.XPProgress
    local current = 0
    local required = 0
    local ratio = 0

    if typeof(progress) == "table" then
        if typeof(progress.Ratio) == "number" then
            ratio = math.clamp(progress.Ratio, 0, 1)
        end
        local currentValue = progress.Current or progress.XP or progress.Value or progress.Amount
        if typeof(currentValue) == "number" then
            current = currentValue
        end
        local requiredValue = progress.Required or progress.Max or progress.Goal or progress.ToNext
        if typeof(requiredValue) == "number" then
            required = requiredValue
        end
    end

    if ratio <= 0 then
        local fallbackCurrent = state.XP or current
        local fallbackRequired = state.NextLevelXP or state.XPGoal or required
        if typeof(fallbackCurrent) == "number" then
            current = fallbackCurrent
        end
        if typeof(fallbackRequired) == "number" then
            required = fallbackRequired
        end
        if required > 0 then
            ratio = math.clamp(current / required, 0, 1)
        elseif typeof(progress) == "table" and typeof(progress.Total) == "number" and progress.Total > 0 then
            current = progress.Total
            ratio = 1
        else
            ratio = 0
        end
    end

    local totalXP = state.XP or current

    xpFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)

    if required > 0 then
        xpLabel.Text = composeXPText(string.format("%d/%d", math.floor(current + 0.5), math.floor(required + 0.5)))
    elseif ratio > 0 then
        xpLabel.Text = composeXPText(string.format("%d%%", math.floor(ratio * 100 + 0.5)))
    elseif typeof(totalXP) == "number" then
        xpLabel.Text = composeXPText(string.format("%d", math.floor(totalXP + 0.5)))
    else
        xpLabel.Text = composeXPText("0")
    end
end

function HUDController:UpdateSkillCooldowns(skillTable)
    local cooldownLabel = self.Elements.SkillCooldownLabel
    local keyLabel = self.Elements.SkillKeyLabel
    if not cooldownLabel then
        return
    end

    if keyLabel then
        keyLabel.Text = self.SkillDisplayKey or "Q"
    end

    local primaryId = self.PrimarySkillId
    if not primaryId then
        local abilityConfig = Config.UI and Config.UI.Abilities
        if abilityConfig then
            primaryId = abilityConfig.PrimarySkillId
        end
        primaryId = primaryId or "AOE_Blast"
    end

    local info
    if typeof(skillTable) == "table" then
        if primaryId and typeof(skillTable[primaryId]) == "table" then
            info = skillTable[primaryId]
        elseif typeof(skillTable.Primary) == "table" then
            info = skillTable.Primary
        else
            for _, entry in pairs(skillTable) do
                if typeof(entry) == "table" then
                    info = entry
                    break
                end
            end
        end
    end

    local readyText = self.SkillReadyText or "Ready"
    local readyColor = self.SkillReadyColor or Color3.fromRGB(255, 235, 200)

    local cooldown = 0
    local remaining = 0

    if info and typeof(info) == "table" then
        if typeof(info.Cooldown) == "number" then
            cooldown = math.max(0, info.Cooldown)
        end

        if typeof(info.ReadyTime) == "number" then
            local now = Workspace:GetServerTimeNow()
            remaining = math.max(0, info.ReadyTime - now)
        elseif typeof(info.Remaining) == "number" then
            remaining = math.max(0, info.Remaining)
        elseif typeof(info.Timestamp) == "number" then
            local now = Workspace:GetServerTimeNow()
            local endTime = info.EndTime
            if typeof(endTime) == "number" then
                remaining = math.max(0, endTime - now)
            else
                local elapsed = now - info.Timestamp
                remaining = math.max(0, cooldown - elapsed)
            end
        end
    end

    if remaining > 0.05 then
        local displayValue = math.floor((remaining * 10) + 0.5) / 10
        cooldownLabel.Text = string.format("%.1f", displayValue)
        cooldownLabel.TextColor3 = Color3.new(1, 1, 1)
        cooldownLabel.TextStrokeTransparency = 0.6
        cooldownLabel.Visible = true
    else
        cooldownLabel.Text = readyText
        cooldownLabel.TextColor3 = readyColor
        cooldownLabel.TextStrokeTransparency = 0.6
        cooldownLabel.Visible = true
    end
end

function HUDController:UpdateDashCooldown(dashData)
    local dashCooldownLabel = self.Elements.DashCooldownLabel
    if not dashCooldownLabel then
        return
    end

    local remaining = 0

    if typeof(dashData) == "table" then
        if typeof(dashData.ReadyTime) == "number" then
            local now = Workspace:GetServerTimeNow()
            remaining = math.max(0, dashData.ReadyTime - now)
        elseif typeof(dashData.Remaining) == "number" then
            remaining = math.max(0, dashData.Remaining)
        end
    end

    local readyText = self.DashReadyText or "Ready"
    local readyColor = self.DashReadyColor or Color3.fromRGB(180, 255, 205)

    if remaining <= 0.05 then
        dashCooldownLabel.Text = readyText
        dashCooldownLabel.TextColor3 = readyColor
        dashCooldownLabel.TextStrokeTransparency = 0.6
        dashCooldownLabel.Visible = true
    else
        local displayValue = math.floor((remaining * 10) + 0.5) / 10
        dashCooldownLabel.Text = string.format("%.1f", displayValue)
        dashCooldownLabel.TextColor3 = Color3.new(1, 1, 1)
        dashCooldownLabel.TextStrokeTransparency = 0.6
        dashCooldownLabel.Visible = true
    end
end

function HUDController:ShowMessage(text: string)
    if not self.Elements.MessageLabel then
        return
    end

    if self.LastMessageTask then
        self.LastMessageTask:Cancel()
        self.LastMessageTask = nil
    end

    local messageLabel = self.Elements.MessageLabel
    messageLabel.Text = text
    messageLabel.TextTransparency = 0

    local duration = (Config.UI and Config.UI.MessageDuration) or 3
    local thread = task.spawn(function()
        task.wait(duration)
        messageLabel.TextTransparency = 1
    end)

    self.LastMessageTask = {
        Cancel = function()
            task.cancel(thread)
            messageLabel.TextTransparency = 1
        end,
    }
end

function HUDController:PlayWaveAnnouncement(wave: number)
    local label = self.Elements.WaveAnnouncement
    if not label then
        return
    end

    label.Text = string.format("Wave %d", wave)
    label.TextTransparency = 0

    task.spawn(function()
        task.wait(1.2)
        label.TextTransparency = 1
    end)
end


function HUDController:ShowAOE(position: Vector3, radius: number)
    if typeof(position) ~= "Vector3" then
        return
    end

    radius = typeof(radius) == "number" and radius or 0
    if radius <= 0 then
        return
    end

    local ignore = {}
    local player = Players.LocalPlayer
    if player and player.Character then
        table.insert(ignore, player.Character)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    if #ignore > 0 then
        params.FilterDescendantsInstances = ignore
    end

    local origin = position + Vector3.new(0, 40, 0)
    local rayResult = Workspace:Raycast(origin, Vector3.new(0, -160, 0), params)
    local groundPosition
    if rayResult then
        groundPosition = Vector3.new(position.X, rayResult.Position.Y + 0.1, position.Z)
    else
        groundPosition = Vector3.new(position.X, position.Y, position.Z)
    end

    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(120, 200, 255)
    ring.Transparency = 0.2
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.CanTouch = false
    ring.TopSurface = Enum.SurfaceType.Smooth
    ring.BottomSurface = Enum.SurfaceType.Smooth
    local height = math.max(0.35, radius * 0.08)
    ring.Size = Vector3.new(radius * 2, height, radius * 2)
    ring.CFrame = CFrame.new(groundPosition) * CFrame.Angles(math.rad(90), 0, 0)
    ring.Parent = Workspace

    local tween = TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(radius * 2.4, height * 0.6, radius * 2.4),
    })

    tween.Completed:Connect(function()
        ring:Destroy()
    end)

    tween:Play()
end

return HUDController
