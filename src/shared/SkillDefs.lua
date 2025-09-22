local Types = require(script.Parent.Types)

local function clampLevel(level: number, maxLevel: number): number
    level = math.floor(level)
    if level < 1 then
        level = 1
    end
    if level > maxLevel then
        level = maxLevel
    end
    return level
end

local SkillDefs: {[string]: Types.SkillDefinition} = {}

SkillDefs.AOE_Blast = {
    Id = "AOE_Blast",
    Name = "Arc Shock",
    Slot = "Q",
    Rarity = "Rare",
    Cooldown = 8,
    MaxLevel = 20,
    Description = "Detonates a radial shockwave that damages nearby enemies.",
    LevelCurve = function(level: number)
        level = clampLevel(level, 20)
        local damage = 45 + (level - 1) * 3.5
        local radius = 12 + (level - 1) * 0.35
        return {
            Damage = damage,
            Radius = radius,
        }
    end,
}

SkillDefs.Dash = {
    Id = "Dash",
    Name = "Blink Step",
    Slot = "Passive",
    Rarity = "Uncommon",
    Cooldown = 6,
    MaxLevel = 20,
    Description = "Quickly dash forward, gaining a burst of speed.",
    LevelCurve = function(level: number)
        level = clampLevel(level, 20)
        local speedBoost = 12 + (level - 1) * 0.6
        local duration = 0.35 + (level - 1) * 0.01
        return {
            SpeedBoost = speedBoost,
            Duration = duration,
        }
    end,
}

SkillDefs.Shield = {
    Id = "Shield",
    Name = "Bulwark Field",
    Slot = "Passive",
    Rarity = "Epic",
    Cooldown = 18,
    MaxLevel = 20,
    Description = "Project an energy barrier that mitigates incoming damage.",
    LevelCurve = function(level: number)
        level = clampLevel(level, 20)
        local duration = 3 + (level - 1) * 0.1
        local shield = 35 + (level - 1) * 4
        return {
            Duration = duration,
            Shield = shield,
        }
    end,
}

return SkillDefs
