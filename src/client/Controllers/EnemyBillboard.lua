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

        local existing = primary:FindFirstChild("EnemyBillboard")
        if existing then
            existing:Destroy()
        end

        -- Enemy nameplates and health bars are intentionally disabled.
        -- Retain an empty placeholder so future toggles can re-enable without
        -- leaking connections.
        local placeholder = Instance.new("Folder")
        placeholder.Name = "EnemyBillboard"
        placeholder.Parent = primary

        self.Billboards[model] = {
            Billboard = placeholder,
            Connections = {},
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
