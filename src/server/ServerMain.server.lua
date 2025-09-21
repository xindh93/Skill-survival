local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)

Knit.AddServices(script.Parent.Services)
Knit.Start()

local GameStateService = Knit.GetService("GameStateService")
GameStateService:Start()

-- ensure remotes exist on startup
for _, eventName in pairs(Net.Definitions.Events) do
    Net:GetEvent(eventName)
end

for _, functionName in pairs(Net.Definitions.Functions) do
    Net:GetFunction(functionName)
end
