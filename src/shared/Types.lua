local Types = {}

export type PlayerStats = {
    Gold: number,
    XP: number,
    Kills: number,
    WavesCleared: number,
    DamageDealt: number,
    Assists: number,
}

export type EnemyStats = {
    MaxHealth: number,
    Damage: number,
    Speed: number,
    RewardGold: number,
}

export type WaveConfig = {
    Count: number,
    HealthMultiplier: number,
    SpeedBonus: number,
}

export type SkillLevelInfo = {
    Damage: number?,
    Radius: number?,
    Duration: number?,
    Shield: number?,
    SpeedBoost: number?,
    CooldownReduction: number?,
}

export type SkillDefinition = {
    Id: string,
    Name: string,
    Slot: string?,
    Rarity: string,
    Cooldown: number,
    MaxLevel: number,
    Description: string,
    LevelCurve: (number) -> SkillLevelInfo,
}

export type RewardSummary = PlayerStats & {
    Reason: string,
}

Types.PlayerStats = {} :: PlayerStats
Types.EnemyStats = {} :: EnemyStats
Types.WaveConfig = {} :: WaveConfig
Types.SkillDefinition = {} :: SkillDefinition
Types.SkillLevelInfo = {} :: SkillLevelInfo
Types.RewardSummary = {} :: RewardSummary

return Types
