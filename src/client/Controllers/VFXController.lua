--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)

local VFXController = Knit.CreateController({
    Name = "VFXController",
})

function VFXController:KnitStart()
    Net:GetEvent("DashReplicate").OnClientEvent:Connect(function(player, startPos, endPos, duration)
        self:PlayDashTrail(player, startPos, endPos, duration)
    end)

    Net:GetEvent("Combat").OnClientEvent:Connect(function(event)
        if typeof(event) ~= "table" then
            return
        end

        if event.Type == "AOE" then
            self:PlayAOEIndicator(event.Position, event.Radius)
        end
    end)
end

function VFXController:PlayDashTrail(_player: Player, startPos: Vector3?, endPos: Vector3?, duration: number?)
    if typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then
        return
    end

    local distance = (endPos - startPos).Magnitude
    if distance <= 0.25 then
        return
    end

    local trailPart = Instance.new("Part")
    trailPart.Anchored = true
    trailPart.CanCollide = false
    trailPart.CanQuery = false
    trailPart.CanTouch = false
    trailPart.Material = Enum.Material.Neon
    trailPart.Color = Color3.fromRGB(90, 185, 255)
    trailPart.Transparency = 0.35
    trailPart.Size = Vector3.new(0.45, 0.45, distance)
    trailPart.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance * 0.5)
    trailPart.Parent = Workspace

    local fadeTime = math.max(duration or 0.18, 0.12)
    local tween = TweenService:Create(trailPart, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.25, 0.25, distance * 0.2),
    })

    tween.Completed:Connect(function()
        trailPart:Destroy()
    end)
    tween:Play()
end

function VFXController:PlayAOEIndicator(position: Vector3?, radius: number?)
    if typeof(position) ~= "Vector3" then
        return
    end

    local actualRadius = 0
    if typeof(radius) == "number" then
        actualRadius = math.max(0, radius)
    end

    if actualRadius <= 0 then
        return
    end

    local ignore = {}
    local localPlayer = Players.LocalPlayer
    if localPlayer then
        local character = localPlayer.Character
        if character then
            table.insert(ignore, character)
        end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    if #ignore > 0 then
        params.FilterDescendantsInstances = ignore
    end

    local origin = position + Vector3.new(0, 60, 0)
    local ray = Workspace:Raycast(origin, Vector3.new(0, -160, 0), params)
    local groundPosition
    if ray then
        groundPosition = Vector3.new(position.X, ray.Position.Y + 0.05, position.Z)
    else
        groundPosition = Vector3.new(position.X, position.Y, position.Z)
    end

    local indicator = Instance.new("Part")
    indicator.Name = "AOEIndicator"
    indicator.Anchored = true
    indicator.CanCollide = false
    indicator.CanTouch = false
    indicator.CanQuery = false
    indicator.Material = Enum.Material.Neon
    indicator.Color = Color3.fromRGB(255, 196, 110)
    indicator.Transparency = 0.25
    indicator.TopSurface = Enum.SurfaceType.Smooth
    indicator.BottomSurface = Enum.SurfaceType.Smooth

    local thickness = math.clamp(actualRadius * 0.12, 0.25, 2)
    indicator.Size = Vector3.new(thickness, actualRadius * 2, actualRadius * 2)
    indicator.CFrame = CFrame.new(groundPosition) * CFrame.Angles(0, 0, math.rad(90))
    indicator.Parent = Workspace

    local fadeTime = math.clamp(0.25 + actualRadius * 0.025, 0.35, 0.8)
    local tween = TweenService:Create(indicator, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(math.max(thickness * 0.25, 0.08), actualRadius * 2.6, actualRadius * 2.6),
    })

    tween.Completed:Connect(function()
        indicator:Destroy()
    end)

    tween:Play()

    task.delay(fadeTime + 0.2, function()
        if indicator and indicator.Parent then
            indicator:Destroy()
        end
    end)
end

return VFXController
