local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local HUDController = Knit.CreateController({
    Name = "HUDController",
})

local function trySetAutomaticSize(instance: Instance?, axis: Enum.AutomaticSize)
    if not instance then
        return
    end

    pcall(function()
        (instance :: any).AutomaticSize = axis
    end)
end

local function createTextLabel(
    parent: Instance,
    text: string,
    font: Enum.Font,
    textSize: number,
    xAlignment: Enum.TextXAlignment
)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = font
    label.TextSize = textSize
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = false
    label.TextScaled = false
    label.TextStrokeTransparency = 0.6
    label.Parent = parent
    return label
end

function HUDController:KnitInit()
    self.Elements = {}
    self.PartyEntries = {}
    self.LastMessageTask = nil
    self.LastWaveTask = nil
end

function HUDController:KnitStart()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    local playerGui = player:WaitForChild("PlayerGui")
    if not self.Screen then
        self:CreateInterface(playerGui)
    end
end

function HUDController:CreateInterface(playerGui: PlayerGui)
    if self.LastMessageTask then
        self.LastMessageTask()
        self.LastMessageTask = nil
    end

    if self.LastWaveTask then
        self.LastWaveTask()
        self.LastWaveTask = nil
    end

    if self.Screen then
        self.Screen:Destroy()
        self.Screen = nil
    end

    self.Elements = {}
    self.PartyEntries = {}

    local uiConfig = Config.UI or {}
    local font = uiConfig.Font or Enum.Font.Gotham
    local boldFont = uiConfig.BoldFont or Enum.Font.GothamBold
    local safeMargin = uiConfig.SafeMargin or 24

    local topBarHeight = uiConfig.TopBarHeight or 48
    local topBarBackground = uiConfig.TopBarBackgroundColor or Color3.fromRGB(18, 24, 32)
    local topBarTransparency = uiConfig.TopBarTransparency or 0.35

    local topLabelSize = uiConfig.TopLabelTextSize or 20
    local infoTextSize = uiConfig.InfoTextSize or 18
    local smallTextSize = uiConfig.SmallTextSize or 16

    local screen = Instance.new("ScreenGui")
    screen.Name = "SkillSurvivalHUD"
    screen.IgnoreGuiInset = true
    screen.ResetOnSpawn = false
    screen.DisplayOrder = (uiConfig.DisplayOrder and uiConfig.DisplayOrder.HUD) or 0
    screen.Parent = playerGui

    local safeFrame = Instance.new("Frame")
    safeFrame.Name = "SafeFrame"
    safeFrame.BackgroundTransparency = 1
    safeFrame.Size = UDim2.new(1, -safeMargin * 2, 1, -safeMargin * 2)
    safeFrame.Position = UDim2.new(0, safeMargin, 0, safeMargin)
    safeFrame.Parent = screen

    -- Top information bar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.BackgroundColor3 = topBarBackground
    topBar.BackgroundTransparency = topBarTransparency
    topBar.BorderSizePixel = 0
    topBar.Size = UDim2.new(1, 0, 0, topBarHeight)
    topBar.Parent = safeFrame

    local waveLabel = createTextLabel(topBar, "Wave 0", boldFont, topLabelSize, Enum.TextXAlignment.Left)
    waveLabel.Size = UDim2.new(0, 220, 1, 0)
    waveLabel.Position = UDim2.new(0, 16, 0, 0)

    local enemyLabel = createTextLabel(topBar, "Enemies: 0", boldFont, topLabelSize, Enum.TextXAlignment.Center)
    enemyLabel.AnchorPoint = Vector2.new(0.5, 0)
    enemyLabel.Size = UDim2.new(0, 260, 1, 0)
    enemyLabel.Position = UDim2.new(0.5, 0, 0, 0)

    local timerLabel = createTextLabel(topBar, "Time: ∞", boldFont, topLabelSize, Enum.TextXAlignment.Right)
    timerLabel.AnchorPoint = Vector2.new(1, 0)
    timerLabel.Size = UDim2.new(0, 220, 1, 0)
    timerLabel.Position = UDim2.new(1, -16, 0, 0)

    -- Resource stack on the top-left
    local resourceWidth = uiConfig.TopInfoWidth or 240
    local resourceSpacing = uiConfig.ResourcePadding or 6

    local resourceFrame = Instance.new("Frame")
    resourceFrame.Name = "Resources"
    resourceFrame.BackgroundTransparency = 1
    resourceFrame.Size = UDim2.new(0, resourceWidth, 0, uiConfig.ResourceHeight or 60)
    resourceFrame.Position = UDim2.new(0, 0, 0, topBarHeight + (uiConfig.SectionSpacing or 12))
    resourceFrame.Parent = safeFrame
    trySetAutomaticSize(resourceFrame, Enum.AutomaticSize.Y)

    local resourceLayout = Instance.new("UIListLayout")
    resourceLayout.FillDirection = Enum.FillDirection.Vertical
    resourceLayout.SortOrder = Enum.SortOrder.LayoutOrder
    resourceLayout.Padding = UDim.new(0, resourceSpacing)
    resourceLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    resourceLayout.Parent = resourceFrame

    local goldLabel = createTextLabel(resourceFrame, "Gold: 0", font, infoTextSize, Enum.TextXAlignment.Left)
    goldLabel.LayoutOrder = 1

    -- Reserved alert area (boss warnings / portals etc.)
    local alertWidth = uiConfig.AlertAreaWidth or 440
    local alertHeight = uiConfig.AlertAreaHeight or 140
    local alertOffset = uiConfig.AlertAreaOffset or 12
    local alertPadding = uiConfig.AlertPadding or 8

    local alertArea = Instance.new("Frame")
    alertArea.Name = "AlertArea"
    alertArea.BackgroundTransparency = 1
    alertArea.AnchorPoint = Vector2.new(0.5, 0)
    alertArea.Size = UDim2.new(0, alertWidth, 0, alertHeight)
    alertArea.Position = UDim2.new(0.5, 0, 0, topBarHeight + alertOffset)
    alertArea.Parent = safeFrame

    local alertLayout = Instance.new("UIListLayout")
    alertLayout.FillDirection = Enum.FillDirection.Vertical
    alertLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    alertLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    alertLayout.SortOrder = Enum.SortOrder.LayoutOrder
    alertLayout.Padding = UDim.new(0, alertPadding)
    alertLayout.Parent = alertArea

    local reservedAlert = Instance.new("Frame")
    reservedAlert.Name = "ReservedAlert"
    reservedAlert.BackgroundColor3 = uiConfig.AlertBackgroundColor or Color3.fromRGB(18, 24, 32)
    reservedAlert.BackgroundTransparency = uiConfig.AlertBackgroundTransparency or 0.35
    reservedAlert.BorderSizePixel = 0
    reservedAlert.LayoutOrder = 1
    reservedAlert.Size = UDim2.new(1, 0, 0, uiConfig.ReservedAlertHeight or 52)
    reservedAlert.Parent = alertArea

    local reservedCorner = Instance.new("UICorner")
    reservedCorner.CornerRadius = UDim.new(0, uiConfig.ReservedAlertCornerRadius or 10)
    reservedCorner.Parent = reservedAlert

    local reservedLabel = createTextLabel(reservedAlert, "", font, uiConfig.AlertTextSize or 20, Enum.TextXAlignment.Center)
    reservedLabel.Size = UDim2.new(1, -16, 1, -8)
    reservedLabel.Position = UDim2.new(0, 8, 0, 4)
    reservedLabel.TextWrapped = true

    local messageLabel = createTextLabel(alertArea, "", boldFont, uiConfig.AlertTextSize or 20, Enum.TextXAlignment.Center)
    messageLabel.LayoutOrder = 2
    messageLabel.Size = UDim2.new(1, 0, 0, uiConfig.MessageHeight or 40)
    messageLabel.TextTransparency = 1
    messageLabel.TextWrapped = true

    local waveAnnouncement = createTextLabel(alertArea, "", boldFont, uiConfig.AlertTextSize or 20, Enum.TextXAlignment.Center)
    waveAnnouncement.LayoutOrder = 3
    waveAnnouncement.Size = UDim2.new(1, 0, 0, uiConfig.WaveAnnouncementHeight or 48)
    waveAnnouncement.TextTransparency = 1
    waveAnnouncement.TextWrapped = true

    -- Party list on the right
    local partyConfig = uiConfig.Party or {}
    local partyContainer = Instance.new("Frame")
    partyContainer.Name = "PartyContainer"
    partyContainer.BackgroundTransparency = 1
    partyContainer.AnchorPoint = Vector2.new(1, 0.5)
    partyContainer.Size = UDim2.new(0, partyConfig.Width or 240, 0, partyConfig.EntryHeight or 42)
    partyContainer.Position = UDim2.new(1, 0, 0.5, 0)
    partyContainer.Parent = safeFrame
    trySetAutomaticSize(partyContainer, Enum.AutomaticSize.Y)

    local partyLayout = Instance.new("UIListLayout")
    partyLayout.FillDirection = Enum.FillDirection.Vertical
    partyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Stretch
    partyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    partyLayout.Padding = UDim.new(0, partyConfig.Padding or 8)
    partyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    partyLayout.Parent = partyContainer

    local partyEmptyLabel = createTextLabel(partyContainer, partyConfig.EmptyText or "", font, smallTextSize, Enum.TextXAlignment.Right)
    partyEmptyLabel.LayoutOrder = 0
    partyEmptyLabel.TextTransparency = 0.45
    partyEmptyLabel.Visible = false

    -- Ability area (bottom-left)
    local abilityConfig = uiConfig.Abilities or {}
    local dashConfig = uiConfig.Dash or {}
    local dashSize = dashConfig.Size or 72
    local abilityWidth = abilityConfig.Width or 260
    local abilityHeight = math.max(abilityConfig.Height or dashSize, dashSize)
    local abilitySpacing = abilityConfig.Spacing or 12
    local abilityBottomOffset = abilityConfig.BottomOffset or 0
    local skillKeyText = abilityConfig.SkillKey or "Q"

    self.PrimarySkillId = abilityConfig.PrimarySkillId or "AOE_Blast"
    self.SkillKeyText = skillKeyText
    self.DashReadyText = dashConfig.ReadyText or "Ready"
    self.DashReadyColor = dashConfig.ReadyColor or Color3.fromRGB(180, 255, 205)

    local abilityFrame = Instance.new("Frame")
    abilityFrame.Name = "AbilityFrame"
    abilityFrame.BackgroundTransparency = 1
    abilityFrame.AnchorPoint = Vector2.new(0, 1)
    abilityFrame.Size = UDim2.new(0, abilityWidth, 0, abilityHeight)
    abilityFrame.Position = UDim2.new(0, 0, 1, -abilityBottomOffset)
    abilityFrame.Parent = safeFrame

    local abilityLayout = Instance.new("UIListLayout")
    abilityLayout.FillDirection = Enum.FillDirection.Horizontal
    abilityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    abilityLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    abilityLayout.SortOrder = Enum.SortOrder.LayoutOrder
    abilityLayout.Padding = UDim.new(0, abilitySpacing)
    abilityLayout.Parent = abilityFrame

    local skillLabel = createTextLabel(
        abilityFrame,
        string.format("%s: Ready", skillKeyText),
        boldFont,
        abilityConfig.SkillTextSize or infoTextSize,
        Enum.TextXAlignment.Left
    )
    skillLabel.LayoutOrder = 1
    skillLabel.Size = UDim2.new(0, abilityConfig.SkillWidth or 150, 1, 0)
    skillLabel.TextScaled = false
    skillLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local dashContainer = Instance.new("Frame")
    dashContainer.Name = "DashContainer"
    dashContainer.BackgroundTransparency = 1
    dashContainer.LayoutOrder = 2
    dashContainer.Size = UDim2.new(0, dashSize, 0, dashSize)
    dashContainer.Parent = abilityFrame

    local dashGauge = Instance.new("Frame")
    dashGauge.Name = "Gauge"
    dashGauge.BackgroundColor3 = dashConfig.BackgroundColor or Color3.fromRGB(18, 24, 32)
    dashGauge.BackgroundTransparency = dashConfig.BackgroundTransparency or 0.25
    dashGauge.BorderSizePixel = 0
    dashGauge.Size = UDim2.fromScale(1, 1)
    dashGauge.Parent = dashContainer

    local dashCorner = Instance.new("UICorner")
    dashCorner.CornerRadius = UDim.new(1, 0)
    dashCorner.Parent = dashGauge

    local dashStroke = Instance.new("UIStroke")
    dashStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    dashStroke.Thickness = dashConfig.StrokeThickness or 2
    dashStroke.Color = dashConfig.StrokeColor or Color3.fromRGB(120, 200, 255)
    dashStroke.Transparency = dashConfig.StrokeTransparency or 0.2
    dashStroke.Parent = dashGauge

    local dashMask = Instance.new("Frame")
    dashMask.Name = "Mask"
    dashMask.BackgroundTransparency = 1
    dashMask.ClipsDescendants = true
    dashMask.Size = UDim2.fromScale(1, 1)
    dashMask.Parent = dashGauge

    local dashMaskCorner = Instance.new("UICorner")
    dashMaskCorner.CornerRadius = UDim.new(1, 0)
    dashMaskCorner.Parent = dashMask

    local dashFill = Instance.new("Frame")
    dashFill.Name = "Fill"
    dashFill.AnchorPoint = Vector2.new(0, 1)
    dashFill.BackgroundColor3 = dashConfig.FillColor or Color3.fromRGB(120, 200, 255)
    dashFill.BackgroundTransparency = dashConfig.FillTransparency or 0.15
    dashFill.BorderSizePixel = 0
    dashFill.Position = UDim2.new(0, 0, 1, 0)
    dashFill.Size = UDim2.new(1, 0, 1, 0)
    dashFill.Parent = dashMask

    local dashFillCorner = Instance.new("UICorner")
    dashFillCorner.CornerRadius = UDim.new(1, 0)
    dashFillCorner.Parent = dashFill

    local dashKeyLabel = createTextLabel(dashGauge, dashConfig.KeyText or "E", boldFont, smallTextSize, Enum.TextXAlignment.Center)
    dashKeyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    dashKeyLabel.Position = UDim2.new(0.5, 0, 0.32, 0)
    dashKeyLabel.TextScaled = true

    local dashCooldownLabel = createTextLabel(
        dashGauge,
        dashConfig.ReadyText or "Ready",
        boldFont,
        smallTextSize,
        Enum.TextXAlignment.Center
    )
    dashCooldownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    dashCooldownLabel.Position = UDim2.new(0.5, 0, 0.75, 0)
    dashCooldownLabel.TextScaled = true
    dashCooldownLabel.TextColor3 = self.DashReadyColor or Color3.fromRGB(180, 255, 205)

    -- XP bar bottom-center
    local xpConfig = uiConfig.XP or {}
    local xpBarWidth = xpConfig.BarWidth or 380
    local xpBarHeight = xpConfig.BarHeight or 18
    local xpLabelHeight = xpConfig.LabelHeight or 20
    local xpSpacing = xpConfig.LevelSpacing or 12
    local xpLevelWidth = xpConfig.LevelWidth or 60
    local xpBottomOffset = xpConfig.BottomOffset or 0
    self.XPLabelPrefix = xpConfig.LabelPrefix or "XP"

    local xpContainer = Instance.new("Frame")
    xpContainer.Name = "XPContainer"
    xpContainer.BackgroundTransparency = 1
    xpContainer.AnchorPoint = Vector2.new(0.5, 1)
    xpContainer.Size = UDim2.new(0, xpBarWidth + xpSpacing + xpLevelWidth, 0, xpBarHeight + xpLabelHeight)
    xpContainer.Position = UDim2.new(0.5, 0, 1, -xpBottomOffset)
    xpContainer.Parent = safeFrame

    local xpLabel = createTextLabel(
        xpContainer,
        string.format("%s 0 / ?", self.XPLabelPrefix),
        font,
        xpConfig.LabelTextSize or infoTextSize,
        Enum.TextXAlignment.Left
    )
    xpLabel.Size = UDim2.new(0, xpBarWidth, 0, xpLabelHeight)
    xpLabel.Position = UDim2.new(0, 0, 0, 0)

    local xpBar = Instance.new("Frame")
    xpBar.Name = "XPBar"
    xpBar.BackgroundColor3 = xpConfig.BackgroundColor or Color3.fromRGB(18, 24, 32)
    xpBar.BackgroundTransparency = xpConfig.BackgroundTransparency or 0.45
    xpBar.BorderSizePixel = 0
    xpBar.Size = UDim2.new(0, xpBarWidth, 0, xpBarHeight)
    xpBar.Position = UDim2.new(0, 0, 0, xpLabelHeight)
    xpBar.Parent = xpContainer

    local xpCorner = Instance.new("UICorner")
    xpCorner.CornerRadius = UDim.new(0, xpConfig.CornerRadius or 10)
    xpCorner.Parent = xpBar

    local xpFill = Instance.new("Frame")
    xpFill.Name = "Fill"
    xpFill.BackgroundColor3 = xpConfig.FillColor or Color3.fromRGB(88, 182, 255)
    xpFill.BackgroundTransparency = xpConfig.FillTransparency or 0.05
    xpFill.BorderSizePixel = 0
    xpFill.Size = UDim2.new(0, 0, 1, 0)
    xpFill.Parent = xpBar

    local xpFillCorner = Instance.new("UICorner")
    xpFillCorner.CornerRadius = UDim.new(0, xpConfig.CornerRadius or 10)
    xpFillCorner.Parent = xpFill

    local levelLabel = createTextLabel(xpContainer, "Lv 1", boldFont, xpConfig.LevelTextSize or (infoTextSize + 4), Enum.TextXAlignment.Center)
    levelLabel.AnchorPoint = Vector2.new(0, 0.5)
    levelLabel.Position = UDim2.new(0, xpBarWidth + xpSpacing, 0, xpLabelHeight + xpBarHeight / 2)
    levelLabel.Size = UDim2.new(0, xpLevelWidth, 0, xpBarHeight)

    self.Screen = screen
    self.Elements = {
        WaveLabel = waveLabel,
        EnemyLabel = enemyLabel,
        TimerLabel = timerLabel,
        GoldLabel = goldLabel,
        MessageLabel = messageLabel,
        WaveAnnouncement = waveAnnouncement,
        ReservedAlert = reservedAlert,
        ReservedAlertLabel = reservedLabel,
        XPTextLabel = xpLabel,
        XPFill = xpFill,
        LevelLabel = levelLabel,
        SkillLabel = skillLabel,
        DashFill = dashFill,
        DashCooldownLabel = dashCooldownLabel,
        PartyContainer = partyContainer,
        PartyEmptyLabel = partyEmptyLabel,
    }
end

local function formatTime(seconds: number): string
    seconds = math.max(0, math.floor(seconds + 0.5))
    local minutes = math.floor(seconds / 60)
    local remainder = seconds % 60
    return string.format("%02d:%02d", minutes, remainder)
end

function HUDController:Update(state)
    local elements = self.Elements
    if not elements or not elements.WaveLabel then
        return
    end

    local wave = state.Wave or 0
    elements.WaveLabel.Text = string.format("Wave %d", wave)

    elements.EnemyLabel.Text = string.format("Enemies: %d", state.RemainingEnemies or 0)

    if state.Countdown and state.Countdown > 0 then
        elements.TimerLabel.Text = string.format("Start In: %ds", math.ceil(state.Countdown))
    elseif state.TimeRemaining and state.TimeRemaining >= 0 then
        elements.TimerLabel.Text = "Time Left: " .. formatTime(state.TimeRemaining)
    else
        elements.TimerLabel.Text = "Time: ∞"
    end

    elements.GoldLabel.Text = string.format("Gold: %d", state.Gold or 0)

    self:UpdateXP(state)
    self:UpdateSkillCooldowns(state.SkillCooldowns)
    self:UpdateDashCooldown(state.DashCooldown)
    self:UpdateParty(state.Party)
end

function HUDController:UpdateXP(state)
    local xpFill = self.Elements.XPFill
    local xpLabel = self.Elements.XPTextLabel
    local levelLabel = self.Elements.LevelLabel
    if not xpFill or not xpLabel or not levelLabel then
        return
    end

    local level = tonumber(state.Level) or 1
    levelLabel.Text = string.format("Lv %d", level)

    local progress = state.XPProgress
    local ratio = 0
    local current = 0
    local required = 0

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
        if typeof(state.XP) == "number" then
            current = state.XP
        end
        if typeof(state.NextLevelXP) == "number" then
            required = state.NextLevelXP
        end

        if required > 0 then
            ratio = math.clamp(current / required, 0, 1)
        end
    end

    xpFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)

    local prefix = self.XPLabelPrefix or "XP"
    if required > 0 then
        xpLabel.Text = string.format("%s %d / %d", prefix, math.floor(current + 0.5), math.floor(required + 0.5))
    elseif ratio > 0 then
        xpLabel.Text = string.format("%s %d%%", prefix, math.floor(ratio * 100 + 0.5))
    else
        xpLabel.Text = string.format("%s 0 / ?", prefix)
    end
end

function HUDController:UpdateSkillCooldowns(skillTable)
    local skillLabel = self.Elements.SkillLabel
    if not skillLabel then
        return
    end

    local info
    local trackedId = self.PrimarySkillId
    if typeof(skillTable) == "table" then
        if trackedId and skillTable[trackedId] then
            info = skillTable[trackedId]
        else
            info = skillTable.AOE_Blast or skillTable.Primary
            if not info then
                for _, entry in pairs(skillTable) do
                    if typeof(entry) == "table" then
                        info = entry
                        break
                    end
                end
            end
        end
    end

    local remaining
    if info and typeof(info) == "table" then
        if typeof(info.Remaining) == "number" then
            remaining = math.max(0, info.Remaining)
        else
            local now = Workspace:GetServerTimeNow()
            if typeof(info.ReadyTime) == "number" then
                remaining = math.max(0, info.ReadyTime - now)
            elseif typeof(info.EndTime) == "number" then
                remaining = math.max(0, info.EndTime - now)
            elseif typeof(info.Timestamp) == "number" and typeof(info.Cooldown) == "number" then
                local elapsed = now - info.Timestamp
                remaining = math.max(0, info.Cooldown - elapsed)
            end
        end
    end

    local prefix = self.SkillKeyText or "Q"
    if remaining and remaining > 0.05 then
        local rounded = math.max(0, math.floor(remaining * 10 + 0.5) / 10)
        skillLabel.Text = string.format("%s: %.1fs", prefix, rounded)
    else
        skillLabel.Text = string.format("%s: Ready", prefix)
    end
end

function HUDController:UpdateDashCooldown(dashData)
    local dashFill = self.Elements.DashFill
    local dashCooldownLabel = self.Elements.DashCooldownLabel
    if not dashFill or not dashCooldownLabel then
        return
    end

    local remaining = 0
    local cooldown = 0

    if typeof(dashData) == "table" then
        if typeof(dashData.Cooldown) == "number" then
            cooldown = math.max(0, dashData.Cooldown)
        end

        if typeof(dashData.Remaining) == "number" then
            remaining = math.max(0, dashData.Remaining)
        else
            local now = Workspace:GetServerTimeNow()
            if typeof(dashData.ReadyTime) == "number" then
                remaining = math.max(0, dashData.ReadyTime - now)
            elseif typeof(dashData.EndTime) == "number" then
                remaining = math.max(0, dashData.EndTime - now)
            end
        end
    end

    local progress
    if cooldown > 0 then
        progress = 1 - math.clamp(remaining / cooldown, 0, 1)
    elseif remaining > 0 then
        progress = 0
    else
        progress = 1
    end

    dashFill.Size = UDim2.new(1, 0, math.clamp(progress, 0, 1), 0)

    local readyText = self.DashReadyText or "Ready"
    local readyColor = self.DashReadyColor or Color3.fromRGB(180, 255, 205)

    if remaining <= 0.05 then
        dashCooldownLabel.Text = readyText
        dashCooldownLabel.TextColor3 = readyColor
    else
        local rounded = math.max(0, math.floor(remaining * 10 + 0.5) / 10)
        dashCooldownLabel.Text = string.format("%.1fs", rounded)
        dashCooldownLabel.TextColor3 = Color3.new(1, 1, 1)
    end
end

function HUDController:UpdateParty(partyState)
    local container = self.Elements.PartyContainer
    local emptyLabel = self.Elements.PartyEmptyLabel
    if not container or not emptyLabel then
        return
    end

    local entries = self.PartyEntries
    local order = 0
    local used = {}

    local list = {}
    if typeof(partyState) == "table" then
        if #partyState > 0 then
            for _, member in ipairs(partyState) do
                table.insert(list, member)
            end
        else
            for _, member in pairs(partyState) do
                table.insert(list, member)
            end
            table.sort(list, function(a, b)
                local aOrder = (typeof(a) == "table" and (a.Order or a.Index or 0)) or 0
                local bOrder = (typeof(b) == "table" and (b.Order or b.Index or 0)) or 0
                return aOrder < bOrder
            end)
        end
    end

    for _, data in ipairs(list) do
        local key
        if typeof(data) == "table" then
            if data.Id then
                key = tostring(data.Id)
            elseif data.UserId then
                key = tostring(data.UserId)
            elseif data.Name then
                key = string.lower(data.Name)
            end
        end
        key = key or tostring(order)

        local entry = entries[key]
        if not entry then
            entry = self:CreatePartyEntry(container)
            entries[key] = entry
        end

        order += 1
        entry.Frame.LayoutOrder = order
        self:ApplyPartyEntry(entry, data)
        entry.Frame.Visible = true
        used[key] = true
    end

    for key, entry in pairs(entries) do
        if not used[key] then
            entry.Frame.Visible = false
        end
    end

    if order == 0 then
        emptyLabel.Visible = (emptyLabel.Text ~= "")
    else
        emptyLabel.Visible = false
    end
end

function HUDController:CreatePartyEntry(parent: Instance)
    local uiConfig = Config.UI or {}
    local partyConfig = uiConfig.Party or {}

    local frame = Instance.new("Frame")
    frame.Name = "PartyEntry"
    frame.BackgroundColor3 = partyConfig.BackgroundColor or Color3.fromRGB(18, 24, 32)
    frame.BackgroundTransparency = partyConfig.BackgroundTransparency or 0.25
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, partyConfig.EntryHeight or 42)
    frame.Visible = false
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, partyConfig.CornerRadius or 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = partyConfig.StrokeThickness or 1.5
    stroke.Color = partyConfig.StrokeColor or Color3.fromRGB(80, 120, 160)
    stroke.Transparency = partyConfig.StrokeTransparency or 0.35
    stroke.Parent = frame

    local fill = Instance.new("Frame")
    fill.Name = "HealthFill"
    fill.BackgroundColor3 = partyConfig.HealthFillColor or Color3.fromRGB(88, 255, 120)
    fill.BackgroundTransparency = partyConfig.HealthFillTransparency or 0.25
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = frame

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, partyConfig.CornerRadius or 10)
    fillCorner.Parent = fill

    local nameLabel = createTextLabel(
        frame,
        "",
        partyConfig.Font or uiConfig.Font or Enum.Font.Gotham,
        partyConfig.NameTextSize or 16,
        Enum.TextXAlignment.Left
    )
    nameLabel.Size = UDim2.new(0.5, -12, 1, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local healthLabel = createTextLabel(
        frame,
        "",
        partyConfig.Font or uiConfig.Font or Enum.Font.Gotham,
        partyConfig.HealthTextSize or 16,
        Enum.TextXAlignment.Right
    )
    healthLabel.AnchorPoint = Vector2.new(1, 0)
    healthLabel.Size = UDim2.new(0.5, 0, 1, 0)
    healthLabel.Position = UDim2.new(1, -10, 0, 0)
    healthLabel.TextTruncate = Enum.TextTruncate.AtEnd

    return {
        Frame = frame,
        HealthFill = fill,
        NameLabel = nameLabel,
        HealthLabel = healthLabel,
    }
end

function HUDController:ApplyPartyEntry(entry, data)
    local uiConfig = Config.UI or {}
    local partyConfig = uiConfig.Party or {}
    local localPlayer = Players.LocalPlayer

    local name = "Player"
    local health = 0
    local maxHealth = 0

    if typeof(data) == "table" then
        name = data.DisplayName or data.Name or name
        if typeof(data.Health) == "number" then
            health = data.Health
        elseif typeof(data.Current) == "number" then
            health = data.Current
        elseif typeof(data.Value) == "number" then
            health = data.Value
        end

        if typeof(data.MaxHealth) == "number" then
            maxHealth = data.MaxHealth
        elseif typeof(data.Max) == "number" then
            maxHealth = data.Max
        elseif typeof(data.Capacity) == "number" then
            maxHealth = data.Capacity
        end

        if localPlayer and (data.UserId == localPlayer.UserId or data.IsLocal) then
            entry.Frame.BackgroundTransparency = partyConfig.LocalPlayerTransparency or 0.15
        else
            entry.Frame.BackgroundTransparency = partyConfig.BackgroundTransparency or 0.25
        end
    else
        entry.Frame.BackgroundTransparency = partyConfig.BackgroundTransparency or 0.25
    end

    entry.NameLabel.Text = name

    local ratio = 0
    if typeof(health) == "number" then
        health = math.max(0, health)
    else
        health = 0
    end

    if typeof(maxHealth) == "number" and maxHealth > 0 then
        ratio = math.clamp(health / maxHealth, 0, 1)
    elseif typeof(data) == "table" and typeof(data.Ratio) == "number" then
        ratio = math.clamp(data.Ratio, 0, 1)
        if maxHealth <= 0 and ratio > 0 then
            maxHealth = math.floor(health / math.max(ratio, 0.0001))
        end
    end

    entry.HealthFill.Size = UDim2.new(ratio, 0, 1, 0)

    if maxHealth and maxHealth > 0 then
        entry.HealthLabel.Text = string.format("%d / %d", math.floor(health + 0.5), math.floor(maxHealth + 0.5))
    elseif ratio > 0 then
        entry.HealthLabel.Text = string.format("%d%%", math.floor(ratio * 100 + 0.5))
    else
        entry.HealthLabel.Text = "--"
    end
end

function HUDController:ShowMessage(text: string)
    local messageLabel = self.Elements.MessageLabel
    if not messageLabel then
        return
    end

    if self.LastMessageTask then
        self.LastMessageTask()
        self.LastMessageTask = nil
    end

    messageLabel.Text = text
    messageLabel.TextTransparency = 0

    local duration = (Config.UI and Config.UI.MessageDuration) or 3
    local thread = task.spawn(function()
        task.wait(duration)
        messageLabel.TextTransparency = 1
    end)

    self.LastMessageTask = function()
        task.cancel(thread)
        messageLabel.TextTransparency = 1
    end
end

function HUDController:PlayWaveAnnouncement(wave: number)
    local label = self.Elements.WaveAnnouncement
    if not label then
        return
    end

    if self.LastWaveTask then
        self.LastWaveTask()
        self.LastWaveTask = nil
    end

    label.Text = string.format("Wave %d", wave)
    label.TextTransparency = 0

    local thread = task.spawn(function()
        task.wait(1.2)
        label.TextTransparency = 1
    end)

    self.LastWaveTask = function()
        task.cancel(thread)
        label.TextTransparency = 1
    end
end

function HUDController:ShowAOE(position: Vector3, radius: number)
    if typeof(position) ~= "Vector3" then
        return
    end

    radius = typeof(radius) == "number" and radius or 0
    if radius <= 0 then
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
            ring.Transparency += 0.06
            task.wait(0.05)
        end
        ring:Destroy()
    end)
end

return HUDController
