local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)

local InputController = Knit.CreateController({
    Name = "InputController",
})

function InputController:KnitInit()
    self.MoveVector = Vector3.zero
    self.Mouse = Players.LocalPlayer:GetMouse()
end

function InputController:KnitStart()
    self:BindMovement()

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:PerformBasicAttack()
        elseif input.KeyCode == Enum.KeyCode.Q then
            self:ActivateSkill("AOE_Blast")
        end
    end)
end

function InputController:BindMovement()
    local function handle(actionName, inputState, inputObject)
        if inputState == Enum.UserInputState.End then
            self.MoveVector = Vector3.zero
            local character = Players.LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:Move(Vector3.zero, true)
            end
            return Enum.ContextActionResult.Pass
        end

        local move = Vector3.zero
        if inputObject.KeyCode == Enum.KeyCode.W then
            move = move + Vector3.new(0, 0, -1)
        elseif inputObject.KeyCode == Enum.KeyCode.S then
            move = move + Vector3.new(0, 0, 1)
        elseif inputObject.KeyCode == Enum.KeyCode.A then
            move = move + Vector3.new(-1, 0, 0)
        elseif inputObject.KeyCode == Enum.KeyCode.D then
            move = move + Vector3.new(1, 0, 0)
        end

        if move.Magnitude > 0 then
            local character = Players.LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local camera = Workspace.CurrentCamera
                local lookVector = camera.CFrame.LookVector
                local rightVector = camera.CFrame.RightVector
                local forward = Vector3.new(lookVector.X, 0, lookVector.Z)
                if forward.Magnitude < 0.01 then
                    forward = Vector3.new(0, 0, -1)
                else
                    forward = forward.Unit
                end
                local moveDirection = rightVector * move.X + forward * move.Z
                if moveDirection.Magnitude > 0 then
                    humanoid:Move(moveDirection.Unit, false)
                end
            end
        end

        return Enum.ContextActionResult.Sink
    end

    ContextActionService:BindAction("SS_Move", handle, false, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D)
end

function InputController:PerformBasicAttack()
    local event = Net:GetEvent("Attack")
    event:FireServer()
end

function InputController:ActivateSkill(skillId: string)
    local event = Net:GetEvent("Skill")
    local targetPosition
    if self.Mouse and self.Mouse.Hit then
        targetPosition = self.Mouse.Hit.Position
    end
    event:FireServer(skillId, {
        TargetPosition = targetPosition,
    })
end

return InputController
