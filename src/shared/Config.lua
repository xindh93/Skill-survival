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

/* PATCH START: Dash skill defaults */
Config.Skill = Config.Skill or {}

Config.Skill.Dash = Config.Skill.Dash or {
    Cooldown = 6.0,
    Distance = 12.0,
    Duration = 0.18,
    IFrame = 0.2,
}
/* PATCH END */

/* PATCH START: Stage timings (boss/enrage) configurable */
Config.Stage = Config.Stage or {}

Config.Stage.Timings = Config.Stage.Timings or {
    -- 기본 프로덕션 값: 8분 보스, 10분 광폭화
    BossSpawnAtSeconds = 480,
    EnrageAtSeconds = 600,

    -- true면 '절대 시각 EnrageAtSeconds' 대신 '보스 후 EnrageAfterBossSeconds' 사용
    UseRelativeEnrage = true,
    EnrageAfterBossSeconds = 120,
}

-- =========================================================
-- ✦ 테스트 중이라면 아래 오버라이드 값을 켜두세요.
-- 보스 = 60초, 광폭화 = 보스 후 30초(= 90초 시점)
-- =========================================================
do
    local TESTING = true -- ← 테스트 종료 시 false로 바꾸세요
    if TESTING then
        Config.Stage.Timings.BossSpawnAtSeconds = 60
        Config.Stage.Timings.UseRelativeEnrage = true
        Config.Stage.Timings.EnrageAfterBossSeconds = 30
        -- 절대시간을 쓰고 싶다면:
        -- Config.Stage.Timings.UseRelativeEnrage = false
        -- Config.Stage.Timings.EnrageAtSeconds = 90
    end
end
/* PATCH END */

return Config
