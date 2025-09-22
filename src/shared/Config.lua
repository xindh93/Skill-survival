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

return Config
