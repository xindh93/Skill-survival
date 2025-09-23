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

Config.UI = {
    SafeMargin = 24,
    Font = Enum.Font.Gotham,
    BoldFont = Enum.Font.GothamBold,
    TopBarHeight = 52,
    TopBarBackgroundColor = Color3.fromRGB(18, 24, 32),
    TopBarTransparency = 0.32,
    TopLabelTextSize = 20,
    InfoTextSize = 18,
    SmallTextSize = 16,
    SectionSpacing = 14,
    AlertAreaOffset = 14,
    AlertAreaWidth = 440,
    AlertAreaHeight = 140,
    AlertTextSize = 20,
    ReservedAlertHeight = 56,
    AlertBackgroundColor = Color3.fromRGB(18, 24, 32),
    AlertBackgroundTransparency = 0.35,
    MessageDuration = 3,
    BottomReservedHeight = 160,
    XP = {
        BarWidth = 380,
        BarHeight = 18,
        LevelWidth = 60,
        LevelSpacing = 12,
        LabelHeight = 20,
        LabelTextSize = 18,
        LevelTextSize = 24,
        BackgroundColor = Color3.fromRGB(18, 24, 32),
        BackgroundTransparency = 0.45,
        FillColor = Color3.fromRGB(88, 182, 255),
        FillTransparency = 0.05,
        CornerRadius = 10,
    },
    Dash = {
        Size = 72,
        BackgroundColor = Color3.fromRGB(18, 24, 32),
        BackgroundTransparency = 0.25,
        FillColor = Color3.fromRGB(120, 200, 255),
        FillTransparency = 0.15,
        StrokeColor = Color3.fromRGB(120, 200, 255),
        StrokeThickness = 2,
        StrokeTransparency = 0.2,
    },
    Party = {
        Width = 240,
        Padding = 8,
        EntryHeight = 42,
        BackgroundColor = Color3.fromRGB(18, 24, 32),
        BackgroundTransparency = 0.25,
        CornerRadius = 10,
        StrokeColor = Color3.fromRGB(80, 120, 160),
        StrokeThickness = 1.5,
        StrokeTransparency = 0.35,
        HealthFillColor = Color3.fromRGB(88, 255, 120),
        HealthFillTransparency = 0.25,
        NameTextSize = 16,
        HealthTextSize = 15,
        EmptyText = "No party members",
    },
}

return Config
