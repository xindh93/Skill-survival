local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local HUDController = Knit.CreateController({
    Name = "HUDController",
})

local function createTextLabel(parent: Instance, text: string, font: Enum.Font, textSize: number, alignment: Enum.TextXAlignment)
    local label = Instance.new("TextLabel")
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
    self.PartyEntries = {}
    self.LastMessageTask = nil
    self.AlertTasks = {}
end

function HUDController:KnitStart()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    local playerGui = player:WaitForChild("PlayerGui")
    self:CreateInterface(playerGui)
end

function HUDController:CreateInterface(playerGui: PlayerGui)
    local uiConfig = Config.UI or {}
    local font = uiConfig.Font or Enum.Font.Gotham
    local boldFont = uiConfig.BoldFont or Enum.Font.GothamBold
    local safeMargin = uiConfig.SafeMargin or 24
    local topBarHeight = uiConfig.TopBarHeight or 48
    local topBarBackground = uiConfig.TopBarBackgroundColor or Color3.fromRGB(18, 24, 32)
    local topLabelSize = uiConfig.TopLabelTextSize or 18
    local infoTextSize = uiConfig.InfoTextSize or 18
    local smallTextSize = uiConfig.SmallTextSize or 16
    local alertTextSize = uiConfig.AlertTextSize or 20

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

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.BackgroundColor3 = topBarBackground
    topBar.BackgroundTransparency = uiConfig.TopBarTransparency or 0.35
    topBar.BorderSizePixel = 0
    topBar.Size = UDim2.new(1, 0, 0, topBarHeight)
    topBar.Parent = safeFrame

    local waveLabel = createTextLabel(topBar, "Wave 0", boldFont, topLabelSize, Enum.TextXAlignment.Left)
    waveLabel.Size = UDim2.new(0, 220, 1, 0)
    waveLabel.Position = UDim2.new(0, 16, 0, 0)

    local enemyLabel = createTextLabel(topBar, "Enemies: 0", boldFont, topLabelSize, Enum.TextXAlignment.Center)
    enemyLabel.AnchorPoint = Vector2.new(0.5, 0)
    enemyLabel.Position = UDim2.new(0.5, 0, 0, 0)
    enemyLabel.Size = UDim2.new(0, 260, 1, 0)

    local timerLabel = createTextLabel(topBar, "Time: ∞", boldFont, topLabelSize, Enum.TextXAlignment.Right)
    timerLabel.AnchorPoint = Vector2.new(1, 0)
    timerLabel.Position = UDim2.new(1, -16, 0, 0)
    timerLabel.Size = UDim2.new(0, 220, 1, 0)

    local resourceFrame = Instance.new("Frame")
    resourceFrame.Name = "ResourceFrame"
    resourceFrame.BackgroundTransparency = 1
    resourceFrame.Size = UDim2.new(0, uiConfig.TopInfoWidth or 240, 0, 0)
    resourceFrame.AutomaticSize = Enum.AutomaticSize.Y
    resourceFrame.Position = UDim2.new(0, 0, 0, topBarHeight + (uiConfig.SectionSpacing or 12))
    resourceFrame.Parent = safeFrame

    local resourceLayout = Instance.new("UIListLayout")
    resourceLayout.FillDirection = Enum.FillDirection.Vertical
    resourceLayout.SortOrder = Enum.SortOrder.LayoutOrder
    resourceLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    resourceLayout.Padding = UDim.new(0, 6)
    resourceLayout.Parent = resourceFrame

    local goldLabel = createTextLabel(resourceFrame, "Gold: 0", font, infoTextSize, Enum.TextXAlignment.Left)
    goldLabel.LayoutOrder = 1

    local abilityConfig = uiConfig.Abilities or {}
    local dashSize = (uiConfig.Dash and uiConfig.Dash.Size) or 72
    local abilityWidth = abilityConfig.Width or 260
    local abilityHeight = abilityConfig.Height or 90
    local abilitySpacing = abilityConfig.Spacing or 12
    local abilitySkillWidth = abilityConfig.SkillWidth or 150
    local abilitySkillHeight = abilityConfig.SkillHeight or 36

    abilityWidth = math.max(abilityWidth, abilitySkillWidth + abilitySpacing + dashSize)
    abilityHeight = math.max(abilityHeight, dashSize)
    local skillY = math.max(0, math.floor((abilityHeight - abilitySkillHeight) / 2))
    local dashY = math.max(0, math.floor((abilityHeight - dashSize) / 2))

    local abilityFrame = Instance.new("Frame")
    abilityFrame.Name = "AbilityFrame"
    abilityFrame.BackgroundTransparency = 1
    abilityFrame.AnchorPoint = Vector2.new(0, 1)
    abilityFrame.Position = UDim2.new(0, 0, 1, 0)
    abilityFrame.Size = UDim2.new(0, abilityWidth, 0, abilityHeight)
    abilityFrame.Parent = safeFrame

    local skillLabel = createTextLabel(abilityFrame, "Q: Ready", boldFont, infoTextSize, Enum.TextXAlignment.Left)
    skillLabel.Size = UDim2.new(0, abilitySkillWidth, 0, abilitySkillHeight)
    skillLabel.Position = UDim2.new(0, 0, 0, skillY)
    skillLabel.TextScaled = true

    local dashContainer = Instance.new("Frame")
    dashContainer.Name = "DashContainer"
    dashContainer.BackgroundTransparency = 1
    dashContainer.Size = UDim2.new(0, dashSize, 0, dashSize)
    dashContainer.Position = UDim2.new(0, abilitySkillWidth + abilitySpacing, 0, dashY)
    dashContainer.Parent = abilityFrame

    local dashSlot = Instance.new("Frame")
    dashSlot.Name = "DashSlot"
    dashSlot.BackgroundTransparency = 1
    dashSlot.Size = UDim2.fromScale(1, 1)
    dashSlot.Parent = dashContainer

    local dashGauge = Instance.new("Frame")
    dashGauge.Name = "Gauge"
    dashGauge.Size = UDim2.fromScale(1, 1)
    dashGauge.BackgroundColor3 = uiConfig.Dash and uiConfig.Dash.BackgroundColor or Color3.fromRGB(18, 24, 32)
    dashGauge.BackgroundTransparency = uiConfig.Dash and uiConfig.Dash.BackgroundTransparency or 0.25
    dashGauge.BorderSizePixel = 0
    dashGauge.Parent = dashSlot

    local dashCorner = Instance.new("UICorner")
    dashCorner.CornerRadius = UDim.new(1, 0)
    dashCorner.Parent = dashGauge

    local dashStroke = Instance.new("UIStroke")
    dashStroke.Thickness = uiConfig.Dash and uiConfig.Dash.StrokeThickness or 2
    dashStroke.Color = uiConfig.Dash and uiConfig.Dash.StrokeColor or Color3.fromRGB(120, 200, 255)
    dashStroke.Transparency = uiConfig.Dash and uiConfig.Dash.StrokeTransparency or 0.2
    dashStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    dashStroke.Parent = dashGauge

    local dashMask = Instance.new("Frame")
    dashMask.Name = "Mask"
    dashMask.BackgroundTransparency = 1
    dashMask.Size = UDim2.fromScale(1, 1)
    dashMask.ClipsDescendants = true
    dashMask.Parent = dashGauge

    local dashMaskCorner = Instance.new("UICorner")
    dashMaskCorner.CornerRadius = UDim.new(1, 0)
    dashMaskCorner.Parent = dashMask

    local dashFill = Instance.new("Frame")
    dashFill.Name = "Fill"
    dashFill.BorderSizePixel = 0
    dashFill.BackgroundColor3 = uiConfig.Dash and uiConfig.Dash.FillColor or Color3.fromRGB(120, 200, 255)
    dashFill.BackgroundTransparency = uiConfig.Dash and uiConfig.Dash.FillTransparency or 0.15
    dashFill.AnchorPoint = Vector2.new(0, 1)
    dashFill.Position = UDim2.new(0, 0, 1, 0)
    dashFill.Size = UDim2.new(1, 0, 0, 0)
    dashFill.Parent = dashMask

    local dashFillCorner = Instance.new("UICorner")
    dashFillCorner.CornerRadius = UDim.new(1, 0)
    dashFillCorner.Parent = dashFill

    local dashKeyLabel = createTextLabel(dashGauge, "E", boldFont, smallTextSize, Enum.TextXAlignment.Center)
    dashKeyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    dashKeyLabel.Position = UDim2.new(0.5, 0, 0.3, 0)
    dashKeyLabel.TextScaled = true

    local dashCooldownLabel = createTextLabel(dashGauge, "Ready", boldFont, smallTextSize, Enum.TextXAlignment.Center)
    dashCooldownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    dashCooldownLabel.Position = UDim2.new(0.5, 0, 0.72, 0)
    dashCooldownLabel.TextScaled = true

    local alertArea = Instance.new("Frame")
    alertArea.Name = "AlertArea"
    alertArea.BackgroundTransparency = 1
    alertArea.AnchorPoint = Vector2.new(0.5, 0)
    alertArea.Position = UDim2.new(0.5, 0, 0, topBarHeight + (uiConfig.AlertAreaOffset or 12))
    alertArea.Size = UDim2.new(0, uiConfig.AlertAreaWidth or 460, 0, uiConfig.AlertAreaHeight or 160)
    alertArea.Parent = safeFrame

    local alertLayout = Instance.new("UIListLayout")
    alertLayout.FillDirection = Enum.FillDirection.Vertical
    alertLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    alertLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    alertLayout.Padding = UDim.new(0, 8)
    alertLayout.Parent = alertArea

    local waveAnnouncement = createTextLabel(alertArea, "", boldFont, alertTextSize, Enum.TextXAlignment.Center)
    waveAnnouncement.LayoutOrder = 1
    waveAnnouncement.TextTransparency = 1
    waveAnnouncement.Size = UDim2.new(1, 0, 0, uiConfig.WaveAnnouncementHeight or 48)

    local messageLabel = createTextLabel(alertArea, "", boldFont, alertTextSize, Enum.TextXAlignment.Center)
    messageLabel.LayoutOrder = 2
    messageLabel.TextTransparency = 1
    messageLabel.Size = UDim2.new(1, 0, 0, uiConfig.MessageHeight or 40)

    local reservedAlert = Instance.new("Frame")
    reservedAlert.Name = "ReservedAlerts"
    reservedAlert.BackgroundTransparency = uiConfig.AlertBackgroundTransparency or 0.35
    reservedAlert.BackgroundColor3 = uiConfig.AlertBackgroundColor or Color3.fromRGB(18, 24, 32)
    reservedAlert.Size = UDim2.new(1, 0, 0, uiConfig.ReservedAlertHeight or 52)
    reservedAlert.LayoutOrder = 0
    reservedAlert.Parent = alertArea

    local reservedLabel = createTextLabel(reservedAlert, "", font, alertTextSize, Enum.TextXAlignment.Center)
    reservedLabel.Text = ""

    local partyContainer = Instance.new("Frame")
    partyContainer.Name = "PartyContainer"
    partyContainer.BackgroundTransparency = 1
    partyContainer.AnchorPoint = Vector2.new(1, 0.5)
    partyContainer.Position = UDim2.new(1, 0, 0.5, 0)
    partyContainer.Size = UDim2.new(0, uiConfig.Party and uiConfig.Party.Width or 220, 0, 10)
    partyContainer.AutomaticSize = Enum.AutomaticSize.Y
    partyContainer.Parent = safeFrame

    local partyLayout = Instance.new("UIListLayout")
    partyLayout.FillDirection = Enum.FillDirection.Vertical
    partyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    partyLayout.Padding = UDim.new(0, uiConfig.Party and uiConfig.Party.Padding or 6)
    partyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Stretch
    partyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    partyLayout.Parent = partyContainer

    local partyEmptyLabel = createTextLabel(partyContainer, "", font, smallTextSize, Enum.TextXAlignment.Right)
    partyEmptyLabel.LayoutOrder = -1
    partyEmptyLabel.TextTransparency = 0.45
    partyEmptyLabel.Text = ""

    local xpConfig = uiConfig.XP or {}
    local xpBarWidth = xpConfig.BarWidth or 360
    local xpBarHeight = xpConfig.BarHeight or 18
    local xpLevelWidth = xpConfig.LevelWidth or 54
    local xpSpacing = xpConfig.LevelSpacing or 10
    local xpContainerWidth = xpBarWidth + xpSpacing + xpLevelWidth

    local xpContainer = Instance.new("Frame")
    xpContainer.Name = "XPContainer"
    xpContainer.BackgroundTransparency = 1
    xpContainer.AnchorPoint = Vector2.new(0.5, 1)
    xpContainer.Position = UDim2.new(0.5, 0, 1, 0)
    xpContainer.Size = UDim2.new(0, xpContainerWidth, 0, xpBarHeight + (xpConfig.LabelHeight or 18))
    xpContainer.Parent = safeFrame

    local xpBar = Instance.new("Frame")
    xpBar.Name = "XPBar"
    xpBar.BackgroundColor3 = xpConfig.BackgroundColor or Color3.fromRGB(18, 24, 32)
    xpBar.BackgroundTransparency = xpConfig.BackgroundTransparency or 0.45
    xpBar.BorderSizePixel = 0
    xpBar.Size = UDim2.new(0, xpBarWidth, 0, xpBarHeight)
    xpBar.Position = UDim2.new(0, 0, 0, (xpConfig.LabelHeight or 18))
    xpBar.Parent = xpContainer

    local xpBarCorner = Instance.new("UICorner")
    xpBarCorner.CornerRadius = UDim.new(0, xpConfig.CornerRadius or 9)
    xpBarCorner.Parent = xpBar

    local xpFill = Instance.new("Frame")
    xpFill.Name = "Fill"
    xpFill.BackgroundColor3 = xpConfig.FillColor or Color3.fromRGB(88, 182, 255)
    xpFill.BackgroundTransparency = xpConfig.FillTransparency or 0.05
    xpFill.BorderSizePixel = 0
    xpFill.Size = UDim2.new(0, 0, 1, 0)
    xpFill.Parent = xpBar

    local xpFillCorner = Instance.new("UICorner")
    xpFillCorner.CornerRadius = UDim.new(0, xpConfig.CornerRadius or 9)
    xpFillCorner.Parent = xpFill

    local xpLabel = createTextLabel(xpContainer, "XP 0 / 0", font, xpConfig.LabelTextSize or smallTextSize, Enum.TextXAlignment.Left)
    xpLabel.Position = UDim2.new(0, 0, 0, 0)
    xpLabel.Size = UDim2.new(0, xpBarWidth, 0, xpConfig.LabelHeight or 18)

    local levelLabel = createTextLabel(xpContainer, "Lv 1", boldFont, xpConfig.LevelTextSize or alertTextSize, Enum.TextXAlignment.Center)
    levelLabel.AnchorPoint = Vector2.new(0, 0.5)
    levelLabel.Position = UDim2.new(0, xpBarWidth + xpSpacing, 0, (xpConfig.LabelHeight or 18) + xpBarHeight / 2)
    levelLabel.Size = UDim2.new(0, xpLevelWidth, 0, xpBarHeight)

    self.Screen = screen
    self.Elements = {
        WaveLabel = waveLabel,
        EnemyLabel = enemyLabel,
        TimerLabel = timerLabel,
        GoldLabel = goldLabel,
        SkillLabel = skillLabel,
        DashFill = dashFill,
        DashCooldownLabel = dashCooldownLabel,
        MessageLabel = messageLabel,
        WaveAnnouncement = waveAnnouncement,
        ReservedAlert = reservedAlert,
        ReservedAlertLabel = reservedLabel,
        PartyContainer = partyContainer,
        PartyEmptyLabel = partyEmptyLabel,
        XPFill = xpFill,
        XPTextLabel = xpLabel,
        LevelLabel = levelLabel,
        XPBar = xpBar,
    }
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
    self.Elements.EnemyLabel.Text = string.format("Enemies: %d", enemies)

    if state.Countdown and state.Countdown > 0 then
        self.Elements.TimerLabel.Text = string.format("Start In: %ds", math.ceil(state.Countdown))
    elseif state.TimeRemaining and state.TimeRemaining >= 0 then
        self.Elements.TimerLabel.Text = "Time Left: " .. formatTime(state.TimeRemaining)
    else
        self.Elements.TimerLabel.Text = "Time: ∞"
    end

    self.Elements.GoldLabel.Text = string.format("Gold: %d", state.Gold or 0)

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

    local level = state.Level or 1
    levelLabel.Text = string.format("Lv %d", level)

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

    xpFill.Size = UDim2.new(ratio, 0, 1, 0)

    if required > 0 then
        xpLabel.Text = string.format("XP %d / %d", math.floor(current + 0.5), math.floor(required + 0.5))
    elseif ratio > 0 then
        xpLabel.Text = string.format("XP %d%%", math.floor(ratio * 100 + 0.5))
    else
        xpLabel.Text = "XP 0 / ?"
    end
end

function HUDController:UpdateSkillCooldowns(skillTable)
    local skillLabel = self.Elements.SkillLabel
    if not skillLabel then
        return
    end

    local info
    if typeof(skillTable) == "table" then
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

    if info and typeof(info) == "table" then
        local cooldown = 0
        local remaining
        if typeof(info.Cooldown) == "number" then
            cooldown = math.max(0, info.Cooldown)
        end
        if typeof(info.Remaining) == "number" then
            remaining = math.max(0, info.Remaining)
        elseif typeof(info.Timestamp) == "number" then
            local now = Workspace:GetServerTimeNow()
            local elapsed = now - info.Timestamp
            remaining = math.max(0, cooldown - elapsed)
        end

        if remaining and remaining > 0 then
            skillLabel.Text = string.format("Q: %.1fs", remaining)
            return
        end
    end

    skillLabel.Text = "Q: Ready"
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
        if typeof(dashData.Remaining) == "number" then
            remaining = math.max(0, dashData.Remaining)
        end
        if typeof(dashData.Cooldown) == "number" then
            cooldown = math.max(0, dashData.Cooldown)
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

    dashFill.Size = UDim2.new(1, 0, progress, 0)

    if remaining <= 0.05 then
        dashCooldownLabel.Text = "Ready"
        dashCooldownLabel.TextColor3 = Color3.fromRGB(180, 255, 205)
    else
        dashCooldownLabel.Text = string.format("%.1f", remaining)
        dashCooldownLabel.TextColor3 = Color3.new(1, 1, 1)
    end
end

function HUDController:UpdateParty(partyState)
    local container = self.Elements.PartyContainer
    if not container then
        return
    end

    local entries = self.PartyEntries
    local order = 0
    local used = {}

    local list = {}
    if typeof(partyState) == "table" then
        if #partyState > 0 then
            for index, item in ipairs(partyState) do
                table.insert(list, item)
            end
        else
            for _, item in pairs(partyState) do
                table.insert(list, item)
            end
            table.sort(list, function(a, b)
                local aOrder = typeof(a) == "table" and (a.Order or a.Index or 0) or 0
                local bOrder = typeof(b) == "table" and (b.Order or b.Index or 0) or 0
                return aOrder < bOrder
            end)
        end
    end

    for _, data in ipairs(list) do
        local key = nil
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

    if order == 0 and self.Elements.PartyEmptyLabel then
        self.Elements.PartyEmptyLabel.Text = Config.UI.Party and Config.UI.Party.EmptyText or ""
        self.Elements.PartyEmptyLabel.Visible = (self.Elements.PartyEmptyLabel.Text ~= "")
    elseif self.Elements.PartyEmptyLabel then
        self.Elements.PartyEmptyLabel.Visible = false
    end
end

function HUDController:CreatePartyEntry(parent: Instance)
    local partyConfig = Config.UI and Config.UI.Party or {}
    local entryHeight = partyConfig.EntryHeight or 42
    local entry = Instance.new("Frame")
    entry.Name = "PartyEntry"
    entry.BackgroundColor3 = partyConfig.BackgroundColor or Color3.fromRGB(18, 24, 32)
    entry.BackgroundTransparency = partyConfig.BackgroundTransparency or 0.25
    entry.BorderSizePixel = 0
    entry.Size = UDim2.new(1, 0, 0, entryHeight)
    entry.Visible = false
    entry.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, partyConfig.CornerRadius or 8)
    corner.Parent = entry

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = partyConfig.StrokeThickness or 1.5
    stroke.Color = partyConfig.StrokeColor or Color3.fromRGB(90, 120, 150)
    stroke.Transparency = partyConfig.StrokeTransparency or 0.35
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = entry

    local fill = Instance.new("Frame")
    fill.Name = "HealthFill"
    fill.BackgroundColor3 = partyConfig.HealthFillColor or Color3.fromRGB(88, 255, 120)
    fill.BackgroundTransparency = partyConfig.HealthFillTransparency or 0.25
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = entry

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, partyConfig.CornerRadius or 8)
    fillCorner.Parent = fill

    local nameLabel = createTextLabel(entry, "", Config.UI and (Config.UI.Party and Config.UI.Party.Font or Config.UI.Font) or Enum.Font.Gotham, partyConfig.NameTextSize or 16, Enum.TextXAlignment.Left)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.Size = UDim2.new(0.5, -10, 1, 0)

    local healthLabel = createTextLabel(entry, "", Config.UI and (Config.UI.Party and Config.UI.Party.Font or Config.UI.Font) or Enum.Font.Gotham, partyConfig.HealthTextSize or 16, Enum.TextXAlignment.Right)
    healthLabel.AnchorPoint = Vector2.new(1, 0)
    healthLabel.Position = UDim2.new(1, -10, 0, 0)
    healthLabel.Size = UDim2.new(0.5, 0, 1, 0)

    return {
        Frame = entry,
        HealthFill = fill,
        NameLabel = nameLabel,
        HealthLabel = healthLabel,
    }
end

function HUDController:ApplyPartyEntry(entry, data)
    local name = "Player"
    local health = 0
    local maxHealth = 0

    if typeof(data) == "table" then
        name = data.DisplayName or data.Name or name
        health = data.Health or data.Current or data.Value or health
        maxHealth = data.MaxHealth or data.Max or data.Capacity or maxHealth
        if data.UserId == Players.LocalPlayer.UserId or data.IsLocal then
            entry.Frame.BackgroundTransparency = 0.18
        else
            entry.Frame.BackgroundTransparency = Config.UI and Config.UI.Party and Config.UI.Party.BackgroundTransparency or 0.25
        end
    end

    entry.NameLabel.Text = name

    local ratio = 0
    if typeof(health) == "number" then
        health = math.max(0, health)
    else
        health = 0
    end
    if typeof(maxHealth) == "number" and maxHealth > 0 then
        maxHealth = math.max(maxHealth, health, 1)
        ratio = math.clamp(health / maxHealth, 0, 1)
    elseif typeof(data) == "table" and typeof(data.Ratio) == "number" then
        ratio = math.clamp(data.Ratio, 0, 1)
        if maxHealth <= 0 then
            maxHealth = math.floor(health / math.max(ratio, 0.0001))
        end
    end

    entry.HealthFill.Size = UDim2.new(ratio, 0, 1, 0)

    if maxHealth > 0 then
        entry.HealthLabel.Text = string.format("%d / %d", math.floor(health + 0.5), math.floor(maxHealth + 0.5))
    elseif ratio > 0 then
        entry.HealthLabel.Text = string.format("%d%%", math.floor(ratio * 100 + 0.5))
    else
        entry.HealthLabel.Text = "--"
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