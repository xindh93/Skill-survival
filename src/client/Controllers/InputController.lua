local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)

local MOVE_KEY_DIRECTIONS = {
    [Enum.KeyCode.W] = Vector3.new(0, 0, -1),
    [Enum.KeyCode.S] = Vector3.new(0, 0, 1),
    [Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
    [Enum.KeyCode.D] = Vector3.new(1, 0, 0),
}

local InputController = Knit.CreateController({
    Name = "InputController",
})

function InputController:KnitInit()
    self.MoveVector = Vector3.zero
    self.ActiveMoveKeys = {}
    self.LastMoveVector = Vector3.zero
    self.Mouse = Players.LocalPlayer:GetMouse()
end

function InputController:KnitStart()
    self:BindMovement()

    RunService.RenderStepped:Connect(function()
        local character = Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            self.LastMoveVector = Vector3.zero
            return
        end

        local moveVector = self.MoveVector
        if moveVector.Magnitude > 0 then
            humanoid:Move(moveVector, true)
            self.LastMoveVector = moveVector
        elseif self.LastMoveVector.Magnitude > 0 then
            humanoid:Move(Vector3.zero, true)
            self.LastMoveVector = Vector3.zero
        end
    end)

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
    local function updateMoveVector()
        local move = Vector3.zero
        for _, direction in pairs(self.ActiveMoveKeys) do
            move += direction
        end

        if move.Magnitude > 0 then
            if move.Magnitude > 1 then
                move = move.Unit
            end
            self.MoveVector = move
        else
            self.MoveVector = Vector3.zero
        end
    end

    local function handle(actionName, inputState, inputObject)
        local direction = MOVE_KEY_DIRECTIONS[inputObject.KeyCode]
        if not direction then
            return Enum.ContextActionResult.Pass
        end

        if inputState == Enum.UserInputState.Begin then
            self.ActiveMoveKeys[inputObject.KeyCode] = direction
        elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
            self.ActiveMoveKeys[inputObject.KeyCode] = nil
        end

        updateMoveVector()

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
