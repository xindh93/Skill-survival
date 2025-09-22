--!strict
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

return VFXController
