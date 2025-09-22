local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)

local EnemyBillboard = Knit.CreateController({
    Name = "EnemyBillboard",
})

function EnemyBillboard:KnitInit()
    self.Billboards = {}
end

function EnemyBillboard:KnitStart()
    local enemiesFolder = Workspace:WaitForChild("Enemies")

    local function onSpawned(model)
        self:AttachBillboard(model)
    end

    local function onRemoved(model)
        self:DetachBillboard(model)
    end

    enemiesFolder.ChildAdded:Connect(onSpawned)
    enemiesFolder.ChildRemoved:Connect(onRemoved)

    for _, child in ipairs(enemiesFolder:GetChildren()) do
        self:AttachBillboard(child)
    end

    Net:GetEvent("EnemySpawned").OnClientEvent:Connect(onSpawned)
    Net:GetEvent("EnemyRemoved").OnClientEvent:Connect(onRemoved)
end

function EnemyBillboard:AttachBillboard(model: Model)
    if not model or self.Billboards[model] then
        return
    end

    task.defer(function()
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local primary = model.PrimaryPart
        if not humanoid or not primary then
            return
        end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "EnemyBillboard"
        billboard.Size = UDim2.new(0, 120, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 4, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = primary

        local frame = Instance.new("Frame")
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.4
        frame.Size = UDim2.fromScale(1, 1)
        frame.Parent = billboard

        local bar = Instance.new("Frame")
        bar.Name = "HealthBar"
        bar.BackgroundColor3 = Color3.fromRGB(88, 255, 88)
        bar.BorderSizePixel = 0
        bar.Size = UDim2.fromScale(1, 1)
        bar.Parent = frame

        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.Size = UDim2.fromScale(1, 1)
        text.Font = Enum.Font.GothamSemibold
        text.TextScaled = true
        text.TextColor3 = Color3.new(1, 1, 1)
        text.TextStrokeTransparency = 0.6
        text.Text = model.Name
        text.Parent = frame

        local connections = {}
        local function update()
            bar.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
        end

        table.insert(connections, humanoid:GetPropertyChangedSignal("Health"):Connect(update))
        update()

        self.Billboards[model] = {
            Billboard = billboard,
            Connections = connections,
        }
    end)
end

function EnemyBillboard:DetachBillboard(model: Model)
    if not model then
        return
    end

    local record = self.Billboards[model]
    if not record then
        return
    end

    for _, connection in ipairs(record.Connections) do
        connection:Disconnect()
    end

    if record.Billboard then
        record.Billboard:Destroy()
    end

    self.Billboards[model] = nil
end

return EnemyBillboard
