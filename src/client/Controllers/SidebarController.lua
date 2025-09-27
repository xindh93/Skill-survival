local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)

local SidebarController = Knit.CreateController({
    Name = "SidebarController",
})

function SidebarController:KnitInit()
    self.Screen = nil
    self.PlayerGui = nil
    self.Rows = {}
    self.DownCount = 0
    self.RushResetToken = 0
    self.ActiveTweens = {}
    self.LastSessionResetClock = 0
end

local function isSidebar(screen: Instance): boolean
    return screen and screen:IsA("ScreenGui") and screen.Name == "Sidebar"
end

function SidebarController:AttachInterface(screen: ScreenGui)
    if not isSidebar(screen) then
        return
    end

    if self.Screen == screen then
        return
    end

    self.Screen = screen
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true

    local container = screen:FindFirstChild("Container")
    local bossRow = container and container:FindFirstChild("BossRow")
    local downRow = container and container:FindFirstChild("DownRow")
    local rushRow = container and container:FindFirstChild("RushRow")

    local function capture(rowInstance)
        if not rowInstance or not rowInstance:IsA("Frame") then
            return nil
        end

        local label = rowInstance:FindFirstChild("Label")
        if not label or not label:IsA("TextLabel") then
            label = rowInstance:FindFirstChildWhichIsA("TextLabel", true)
        end

        return {
            Frame = rowInstance,
            Label = label,
        }
    end

    self.Rows = {
        Boss = capture(bossRow),
        Down = capture(downRow),
        Rush = capture(rushRow),
    }

    for _, row in pairs(self.Rows) do
        if row and row.Frame and not row.Frame:FindFirstChildOfClass("UIScale") then
            local scale = Instance.new("UIScale")
            scale.Scale = 1
            scale.Parent = row.Frame
        end
    end

    self:ResetState()
end

function SidebarController:ResetState()
    self.DownCount = 0
    self.RushResetToken = self.RushResetToken + 1
    self.LastSessionResetClock = os.clock()

    if self.Rows.Boss and self.Rows.Boss.Label then
        self.Rows.Boss.Label.Text = "보스: 대기중"
    end

    if self.Rows.Down and self.Rows.Down.Label then
        self.Rows.Down.Label.Text = "팀원 사망: 0"
    end

    if self.Rows.Rush and self.Rows.Rush.Label then
        self.Rows.Rush.Label.Text = "러쉬: -"
    end
end

function SidebarController:PlayPulse(row)
    if not row or not row.Frame then
        return
    end

    local scale = row.Frame:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Scale = 1
        scale.Parent = row.Frame
    end

    local tweens = self.ActiveTweens[row.Frame]
    if tweens then
        for _, tween in ipairs(tweens) do
            tween:Cancel()
        end
    end

    local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local downInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

    local upTween = TweenService:Create(scale, tweenInfo, {Scale = 1.05})
    local downTween = TweenService:Create(scale, downInfo, {Scale = 1})
    local tweenPair = {upTween, downTween}
    self.ActiveTweens[row.Frame] = tweenPair

    upTween.Completed:Connect(function()
        if self.ActiveTweens[row.Frame] == tweenPair then
            downTween:Play()
        end
    end)

    downTween.Completed:Connect(function()
        if self.ActiveTweens[row.Frame] == tweenPair then
            self.ActiveTweens[row.Frame] = nil
        end
        scale.Scale = 1
    end)

    upTween:Play()
end

function SidebarController:SetBossState(text)
    if self.Rows.Boss and self.Rows.Boss.Label then
        self.Rows.Boss.Label.Text = text
        self:PlayPulse(self.Rows.Boss)
    end
end

function SidebarController:SetDownCount(count)
    self.DownCount = count
    if self.Rows.Down and self.Rows.Down.Label then
        self.Rows.Down.Label.Text = string.format("팀원 사망: %d", count)
        self:PlayPulse(self.Rows.Down)
    end
end

function SidebarController:SetRushState(text)
    if self.Rows.Rush and self.Rows.Rush.Label then
        self.Rows.Rush.Label.Text = text
        self:PlayPulse(self.Rows.Rush)
    end
end

function SidebarController:ScheduleRushReset()
    local token = self.RushResetToken + 1
    self.RushResetToken = token
    task.delay(3, function()
        if self.RushResetToken == token then
            if self.Rows.Rush and self.Rows.Rush.Label then
                self.Rows.Rush.Label.Text = "러쉬: -"
            end
        end
    end)
end

function SidebarController:BindRemotes()
    Net:GetEvent("BossSpawned").OnClientEvent:Connect(function(spawned)
        if spawned then
            self:SetBossState("보스: 등장!")
        end
    end)

    Net:GetEvent("BossEnraged").OnClientEvent:Connect(function()
        self:SetBossState("보스: 분노!")
    end)

    Net:GetEvent("TeammateDown").OnClientEvent:Connect(function(playerName)
        self:SetDownCount(self.DownCount + 1)
    end)

    Net:GetEvent("RushWarning").OnClientEvent:Connect(function(kind)
        if kind == "pulse" then
            self:SetRushState("러쉬: 잠깐")
        elseif kind == "surge" then
            self:SetRushState("러쉬: 대규모")
        else
            self:SetRushState("러쉬: -")
        end
        self:ScheduleRushReset()
    end)

    Net:GetEvent("HUD").OnClientEvent:Connect(function(payload)
        if typeof(payload) ~= "table" then
            return
        end

        local state = payload.State
        local elapsed = payload.Elapsed

        if state == "Active" and typeof(elapsed) == "number" and elapsed <= 0.5 then
            local now = os.clock()
            if now - (self.LastSessionResetClock or 0) > 1 then
                self:ResetState()
                self.LastSessionResetClock = now
            end
        end
    end)
end

function SidebarController:KnitStart()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    self.PlayerGui = player:WaitForChild("PlayerGui")

    local function tryAttach(screen)
        if isSidebar(screen) then
            self:AttachInterface(screen)
        end
    end

    local existing = self.PlayerGui:FindFirstChild("Sidebar")
    if existing then
        tryAttach(existing)
    end

    self.PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "Sidebar" then
            task.defer(tryAttach, child)
        end
    end)

    self:BindRemotes()
end

return SidebarController
