local Config = {}

Config.LOBBY_PLACE_ID = 0

Config.Session = {
    PrepareDuration = 5,
    WaveInterval = 8,
    ResultDuration = 12,
    TimeLimit = 600,
    Infinite = false,
}

Config.Enemy = {
    BaseCount = 4,
    CountGrowth = 2,
    BaseHealth = 70,
    HealthGrowthRate = 0.25,
    BaseSpeed = 12,
    SpeedGrowthRate = 0.45,
    MaxSpeedDelta = 8,
    BaseDamage = 10,
    DamageGrowth = 1.5,
    SpawnInterval = 5,
    MaxActive = 80,
    PathRefresh = 0.25,
}

Config.Combat = {
    BasicAttackRange = 10,
    BasicAttackAngle = 120,
    BasicAttackDamage = 28,
    BasicAttackCooldown = 0.75,
    SkillAOEClampRadius = 35,
}

Config.Rewards = {
    KillGold = 6,
    KillXP = 8,
    WaveClearGold = 15,
    WaveClearXP = 25,
    ResultXPBonus = 100,
}

Config.Map = {
    FloorSize = Vector3.new(220, 2, 220),
    FloorMaterial = Enum.Material.Slate,
    LightingColor = Color3.fromRGB(70, 70, 70),
    FloorTransparency = 1,
}

Config.Skill = Config.Skill or {}

Config.Skill.Dash = Config.Skill.Dash or {
    Cooldown = 6.0,
    Distance = 12.0,
    Duration = 0.18,
    IFrame = 0.2,
}

-- =========================
-- Stage / Boss / Enrage
-- =========================
Config.Stage = Config.Stage or {}
Config.Stage.Timings = Config.Stage.Timings or {
    -- 기본 프로덕션 값: 8분 보스, 10분 광폭화
    BossSpawnAtSeconds = 480,

    -- 광폭화 계산 방식
    -- true: 보스 등장 후 EnrageAfterBossSeconds 뒤에 광폭화
    -- false: 절대 시각 EnrageAtSeconds에 광폭화
    UseRelativeEnrage = true,
    EnrageAfterBossSeconds = 120, -- UseRelativeEnrage=true일 때 사용
    EnrageAtSeconds = 600,        -- UseRelativeEnrage=false일 때 사용
}

-- =========================================
-- 테스트용 오버라이드 (끝나면 false로)
-- 보스 60초, 보스 후 30초(=90초)에 광폭화
-- =========================================
do
    local TESTING = true -- 테스트 종료 시 false
    if TESTING then
        Config.Stage.Timings.BossSpawnAtSeconds = 60
        Config.Stage.Timings.UseRelativeEnrage = true
        Config.Stage.Timings.EnrageAfterBossSeconds = 30
        -- 절대 시간으로 테스트하려면 아래처럼:
        -- Config.Stage.Timings.UseRelativeEnrage = false
        -- Config.Stage.Timings.EnrageAtSeconds = 90
    end
end

Config.UI = Config.UI or {}

local ui = Config.UI
ui.SafeMargin = ui.SafeMargin or 24
ui.Font = ui.Font or Enum.Font.Gotham
ui.BoldFont = ui.BoldFont or Enum.Font.GothamBold
ui.TopBarHeight = ui.TopBarHeight or 52
ui.TopBarBackgroundColor = ui.TopBarBackgroundColor or Color3.fromRGB(18, 24, 32)
ui.TopBarTransparency = ui.TopBarTransparency or 0.32
ui.TopLabelTextSize = ui.TopLabelTextSize or 20
ui.InfoTextSize = ui.InfoTextSize or 18
ui.SmallTextSize = ui.SmallTextSize or 16
ui.TopInfoWidth = ui.TopInfoWidth or 240
ui.ResourceHeight = ui.ResourceHeight or 60
ui.ResourcePadding = ui.ResourcePadding or 6
ui.SectionSpacing = ui.SectionSpacing or 14
ui.AlertAreaOffset = ui.AlertAreaOffset or 14
ui.AlertAreaWidth = ui.AlertAreaWidth or 440
ui.AlertAreaHeight = ui.AlertAreaHeight or 140
ui.AlertPadding = ui.AlertPadding or 8
ui.AlertTextSize = ui.AlertTextSize or 20
ui.ReservedAlertHeight = ui.ReservedAlertHeight or 56
ui.ReservedAlertCornerRadius = ui.ReservedAlertCornerRadius or 10
ui.AlertBackgroundColor = ui.AlertBackgroundColor or Color3.fromRGB(18, 24, 32)
ui.AlertBackgroundTransparency = ui.AlertBackgroundTransparency or 0.35
ui.MessageHeight = ui.MessageHeight or 40
ui.WaveAnnouncementHeight = ui.WaveAnnouncementHeight or 48
ui.MessageDuration = ui.MessageDuration or 3
ui.DisplayOrder = ui.DisplayOrder or { HUD = 0 }

ui.XP = ui.XP or {}
local xp = ui.XP
xp.BarWidth = xp.BarWidth or 380
xp.BarHeight = xp.BarHeight or 18
xp.LevelWidth = xp.LevelWidth or 60
xp.LevelSpacing = xp.LevelSpacing or 12
xp.LabelHeight = xp.LabelHeight or 20
xp.LabelTextSize = xp.LabelTextSize or 18
xp.LevelTextSize = xp.LevelTextSize or 24
xp.BackgroundColor = xp.BackgroundColor or Color3.fromRGB(18, 24, 32)
xp.BackgroundTransparency = xp.BackgroundTransparency or 0.45
xp.FillColor = xp.FillColor or Color3.fromRGB(88, 182, 255)
xp.FillTransparency = xp.FillTransparency or 0.05
xp.CornerRadius = xp.CornerRadius or 10

ui.Dash = ui.Dash or {}
local dash = ui.Dash
dash.Size = dash.Size or 72
dash.BackgroundColor = dash.BackgroundColor or Color3.fromRGB(18, 24, 32)
dash.BackgroundTransparency = dash.BackgroundTransparency or 0.25
dash.FillColor = dash.FillColor or Color3.fromRGB(120, 200, 255)
dash.FillTransparency = dash.FillTransparency or 0.15
dash.StrokeColor = dash.StrokeColor or Color3.fromRGB(120, 200, 255)
dash.StrokeThickness = dash.StrokeThickness or 2
dash.StrokeTransparency = dash.StrokeTransparency or 0.2
dash.ReadyColor = dash.ReadyColor or Color3.fromRGB(180, 255, 205)

ui.Party = ui.Party or {}
local party = ui.Party
party.Width = party.Width or 240
party.Padding = party.Padding or 8
party.EntryHeight = party.EntryHeight or 42
party.BackgroundColor = party.BackgroundColor or Color3.fromRGB(18, 24, 32)
party.BackgroundTransparency = party.BackgroundTransparency or 0.25
party.LocalPlayerTransparency = party.LocalPlayerTransparency or 0.18
party.CornerRadius = party.CornerRadius or 10
party.StrokeColor = party.StrokeColor or Color3.fromRGB(80, 120, 160)
party.StrokeThickness = party.StrokeThickness or 1.5
party.StrokeTransparency = party.StrokeTransparency or 0.35
party.HealthFillColor = party.HealthFillColor or Color3.fromRGB(88, 255, 120)
party.HealthFillTransparency = party.HealthFillTransparency or 0.25
party.NameTextSize = party.NameTextSize or 16
party.HealthTextSize = party.HealthTextSize or 15
party.EmptyText = party.EmptyText or "No party members"

ui.Abilities = ui.Abilities or {}
local abilities = ui.Abilities
abilities.Width = abilities.Width or 260
abilities.Height = abilities.Height or 90
abilities.SkillWidth = abilities.SkillWidth or 150
abilities.SkillHeight = abilities.SkillHeight or 36
abilities.Spacing = abilities.Spacing or 12

return Config
