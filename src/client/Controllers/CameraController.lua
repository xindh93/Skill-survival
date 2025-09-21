local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)

local CameraController = Knit.CreateController({
    Name = "CameraController",
})

function CameraController:KnitInit()
    self.BaseYaw = math.rad(45)
    self.MinYaw = math.rad(30)
    self.MaxYaw = math.rad(60)
    self.BasePitch = math.rad(35)
    self.MinPitch = math.rad(25)
    self.MaxPitch = math.rad(45)
    self.TargetYaw = self.BaseYaw
    self.CurrentYaw = self.BaseYaw
    self.TargetPitch = self.BasePitch
    self.CurrentPitch = self.BasePitch
    self.Distance = 28
    self.RotationActive = false
    self.LastInputPosition = Vector2.new()
end

function CameraController:KnitStart()
    self.Camera = Workspace.CurrentCamera
    self.Camera.CameraType = Enum.CameraType.Scriptable

    Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait()
        if self.Camera then
            self.Camera.CameraType = Enum.CameraType.Scriptable
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.RotationActive = true
            self.LastInputPosition = UserInputService:GetMouseLocation()
        elseif input.KeyCode == Enum.KeyCode.R then
            self.TargetYaw = self.BaseYaw
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.RotationActive = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if self.RotationActive and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Delta
            self.TargetYaw = math.clamp(self.TargetYaw - delta.X * 0.003, self.MinYaw, self.MaxYaw)
            self.TargetPitch = math.clamp(self.TargetPitch - delta.Y * 0.002, self.MinPitch, self.MaxPitch)
        end
    end)

    RunService:BindToRenderStep("SS_Camera", Enum.RenderPriority.Camera.Value, function(dt)
        self:UpdateCamera(dt)
    end)
end

function CameraController:GetFocus(): (Vector3?, Humanoid?)
    local player = Players.LocalPlayer
    if not player then
        return nil
    end

    local character = player.Character
    if not character then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then
        return nil
    end

    if humanoid.Health <= 0 then
        return nil
    end

    return root.Position + Vector3.new(0, 3.5, 0), humanoid
end

function CameraController:UpdateCamera(dt: number)
    if not self.Camera then
        self.Camera = Workspace.CurrentCamera
        if not self.Camera then
            return
        end
    end

    local focusPosition = self:GetFocus()
    if not focusPosition then
        return
    end

    self.CurrentYaw = self.CurrentYaw + (self.TargetYaw - self.CurrentYaw) * math.clamp(dt * 6, 0, 1)
    self.CurrentPitch = self.CurrentPitch + (self.TargetPitch - self.CurrentPitch) * math.clamp(dt * 6, 0, 1)

    local rotation = CFrame.fromEulerAnglesYXZ(-self.CurrentPitch, self.CurrentYaw, 0)
    local lookVector = rotation.LookVector
    local cameraPosition = focusPosition - lookVector * self.Distance

    self.Camera.CameraType = Enum.CameraType.Scriptable
    self.Camera.CFrame = CFrame.new(cameraPosition, focusPosition)
    self.Camera.Focus = CFrame.new(focusPosition)
end

return CameraController
