--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

local DEFAULT_DASH_CONFIG = {
    Cooldown = 6.0,
    Distance = 12.0,
    Duration = 0.18,
    IFrame = 0.2,
}

type DashState = {
    Character: Model,
    Humanoid: Humanoid,
    Root: BasePart,
    Direction: Vector3,
    StartPos: Vector3,
    TargetPos: Vector3,
    StartTime: number,
    EndTime: number,
    Duration: number,
    Distance: number,
    OriginalAutoRotate: boolean,
    OriginalFriction: PhysicalProperties?,
}

local DashService = Knit.CreateService({
    Name = "DashService",
    Client = {},
})

function DashService:KnitInit()
    self.LastDash = {} :: {[Player]: number}
    self.ActiveDashes = {} :: {[Player]: DashState}
    self.CooldownThreads = {} :: {[Player]: thread}
    self.IFrameTokens = {} :: {[Model]: {}?}
    self.EnemyService = nil
end

local function getDashConfig()
    local skillConfig = Config.Skill and Config.Skill.Dash
    if not skillConfig then
        return DEFAULT_DASH_CONFIG
    end
    return {
        Cooldown = skillConfig.Cooldown or DEFAULT_DASH_CONFIG.Cooldown,
        Distance = skillConfig.Distance or DEFAULT_DASH_CONFIG.Distance,
        Duration = skillConfig.Duration or DEFAULT_DASH_CONFIG.Duration,
        IFrame = skillConfig.IFrame or DEFAULT_DASH_CONFIG.IFrame,
    }
end

function DashService:KnitStart()
    for _, player in ipairs(Players:GetPlayers()) do
        self:_bindCharacter(player)
    end

    Players.PlayerAdded:Connect(function(player)
        self:_bindCharacter(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayer(player)
    end)

    self.EnemyService = Knit.GetService("EnemyService")

    Net:GetEvent("DashRequest").OnServerEvent:Connect(function(player, direction)
        self:HandleDashRequest(player, direction)
    end)

    RunService.Heartbeat:Connect(function()
        self:UpdateDashes()
    end)
end

function DashService:_bindCharacter(player: Player)
    local function onCharacter(character: Model)
        character:SetAttribute("IFrame", false)
        character:GetPropertyChangedSignal("Parent"):Connect(function()
            if not character.Parent then
                self.IFrameTokens[character] = nil
            end
        end)
    end

    player.CharacterAdded:Connect(onCharacter)
    player.CharacterRemoving:Connect(function(character)
        self.IFrameTokens[character] = nil
        self:FinishDash(player, false)
    end)
    if player.Character then
        onCharacter(player.Character)
    end
end

function DashService:CleanupPlayer(player: Player)
    self.LastDash[player] = nil
    self:StopCooldownBroadcast(player)
    local dash = self.ActiveDashes[player]
    if dash then
        self:FinishDash(player, false)
    end
end

function DashService:HandleDashRequest(player: Player, rawDirection)
    if not Net:CheckRate(player, "DashRequest", 8) then
        return
    end

    local dashConfig = getDashConfig()
    local now = os.clock()
    local last = self.LastDash[player]
    if last then
        local remaining = dashConfig.Cooldown - (now - last)
        if remaining > 0 then
            self:SendCooldownUpdate(player, dashConfig.Cooldown, math.max(0, remaining))
            return
        end
    end

    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then
        return
    end

    local blockedAttributes = {"Stunned", "Knocked", "Knockback", "Groggy", "Disabled", "NoMove"}
    for _, attributeName in ipairs(blockedAttributes) do
        local value = character:GetAttribute(attributeName)
        if typeof(value) == "boolean" and value then
            return
        end
    end

    if self.ActiveDashes[player] then
        return
    end

    local direction = self:ResolveDirection(rawDirection, humanoid, root)
    if not direction then
        return
    end

    direction = Vector3.new(direction.X, 0, direction.Z)
    if direction.Magnitude <= 0.001 then
        return
    end
    direction = direction.Unit

    local dashDistance = math.max(0, dashConfig.Distance)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local ignore = {character}
    local enemyService = self.EnemyService
    if enemyService and enemyService.EnemyFolder then
        table.insert(ignore, enemyService.EnemyFolder)
    else
        local enemiesFolder = Workspace:FindFirstChild("Enemies")
        if enemiesFolder then
            table.insert(ignore, enemiesFolder)
        end
    end
    params.FilterDescendantsInstances = ignore

    local raycast = Workspace:Raycast(root.Position, direction * dashDistance, params)
    if raycast then
        dashDistance = math.min(dashDistance, math.max(0, raycast.Distance - 1))
    end

    if dashDistance <= 0.5 then
        self:SendCooldownUpdate(player, dashConfig.Cooldown, 0)
        return
    end

    local startPos = root.Position
    local targetPos = startPos + direction * dashDistance
    targetPos = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)

    local startTime = os.clock()
    local duration = math.max(0.05, dashConfig.Duration)

    local dash: DashState = {
        Character = character,
        Humanoid = humanoid,
        Root = root,
        Direction = direction,
        StartPos = startPos,
        TargetPos = targetPos,
        StartTime = startTime,
        EndTime = startTime + duration,
        Duration = duration,
        Distance = dashDistance,
        OriginalAutoRotate = humanoid.AutoRotate,
        OriginalFriction = root.CustomPhysicalProperties,
    }

    self.ActiveDashes[player] = dash
    self.LastDash[player] = startTime

    humanoid.AutoRotate = false
    root.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
    character:SetAttribute("IFrame", true)
    self:ScheduleIFrameClear(character, dashConfig.IFrame)

    Net:FireAll("DashReplicate", player, startPos, targetPos, duration)
    self:StartCooldownBroadcast(player, dashConfig.Cooldown)
end

function DashService:ResolveDirection(rawDirection, humanoid: Humanoid, root: BasePart): Vector3?
    if typeof(rawDirection) == "Vector3" then
        local flat = Vector3.new(rawDirection.X, 0, rawDirection.Z)
        if flat.Magnitude > 0.001 then
            return flat.Unit
        end
    end

    local move = humanoid.MoveDirection
    if move.Magnitude > 0.001 then
        local flat = Vector3.new(move.X, 0, move.Z)
        if flat.Magnitude > 0.001 then
            return flat.Unit
        end
    end

    local look = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude > 0.001 then
        return flatLook.Unit
    end

    return nil
end


function DashService:ScheduleIFrameClear(character: Model, duration: number)
    if duration <= 0 then
        character:SetAttribute("IFrame", false)
        self.IFrameTokens[character] = nil
        return
    end

    local token = {}
    self.IFrameTokens[character] = token
    task.delay(duration, function()
        if self.IFrameTokens[character] == token then
            self.IFrameTokens[character] = nil
            if character.Parent then
                character:SetAttribute("IFrame", false)
            end
        end
    end)
end

function DashService:UpdateDashes()
    if next(self.ActiveDashes) == nil then
        return
    end

    local now = os.clock()
    local toFinish: {[Player]: boolean} = {}

    for player, dash in pairs(self.ActiveDashes) do
        local character = dash.Character
        local humanoid = dash.Humanoid
        local root = dash.Root

        if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not root or not root.Parent then
            toFinish[player] = false
            continue
        end

        local alpha = dash.Duration > 0 and math.clamp((now - dash.StartTime) / dash.Duration, 0, 1) or 1
        local newPos = dash.StartPos:Lerp(dash.TargetPos, alpha)
        local newCFrame = CFrame.lookAt(newPos, newPos + dash.Direction)
        character:PivotTo(newCFrame)

        if now >= dash.EndTime then
            toFinish[player] = true
        end
    end

    for player, snap in pairs(toFinish) do
        self:FinishDash(player, snap)
    end
end

function DashService:FinishDash(player: Player, snapToEnd: boolean)
    local dash = self.ActiveDashes[player]
    if not dash then
        return
    end

    self.ActiveDashes[player] = nil

    local character = dash.Character
    local humanoid = dash.Humanoid
    local root = dash.Root

    if root and root.Parent then
        if snapToEnd then
            local finalCFrame = CFrame.lookAt(dash.TargetPos, dash.TargetPos + dash.Direction)
            if character and character.Parent then
                character:PivotTo(finalCFrame)
            else
                root.CFrame = finalCFrame
            end
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.CustomPhysicalProperties = dash.OriginalFriction
    end

    if humanoid and humanoid.Parent then
        humanoid.AutoRotate = dash.OriginalAutoRotate
    end

    if character and character.Parent and not self.IFrameTokens[character] then
        character:SetAttribute("IFrame", false)
    end
end

function DashService:StartCooldownBroadcast(player: Player, cooldown: number)
    self:StopCooldownBroadcast(player)

    if cooldown <= 0 then
        self:SendCooldownUpdate(player, 0, 0)
        return
    end

    local startTime = os.clock()
    local thread: thread
    thread = task.spawn(function()
        while self.CooldownThreads[player] == thread do
            local elapsed = os.clock() - startTime
            local remaining = math.max(0, cooldown - elapsed)
            self:SendCooldownUpdate(player, cooldown, remaining)
            if remaining <= 0 then
                break
            end
            task.wait(math.clamp(remaining / 6, 0.1, 0.3))
        end
        if self.CooldownThreads[player] == thread then
            self.CooldownThreads[player] = nil
        end
    end)

    self.CooldownThreads[player] = thread
end

function DashService:StopCooldownBroadcast(player: Player)
    local thread = self.CooldownThreads[player]
    if thread then
        self.CooldownThreads[player] = nil
        task.cancel(thread)
    end
end

function DashService:SendCooldownUpdate(player: Player, cooldown: number, remaining: number)
    Net:FireClient(player, "DashCooldown", {
        Cooldown = cooldown,
        Remaining = math.max(0, remaining),
    })
end

return DashService
