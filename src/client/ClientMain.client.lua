local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Shared.Knit)

Knit.AddControllers(script.Parent.Controllers)
Knit.Start()
