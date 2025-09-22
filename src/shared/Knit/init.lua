local RunService = game:GetService("RunService")

local Knit = {}
Knit.Services = {}
Knit.Controllers = {}
Knit.Util = {
    Signal = require(script.Util.Signal),
}

local isServer = RunService:IsServer()

local StartPromise = {}
StartPromise.__index = StartPromise

function StartPromise:andThen(callback)
    if typeof(callback) == "function" then
        callback()
    end
    return self
end

function StartPromise:catch(callback)
    return self
end

local function registerModules(container: Instance, loader: (ModuleScript) -> ())
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("ModuleScript") then
            loader(child)
        end
    end
end

function Knit.CreateService(serviceDef)
    assert(isServer, "Knit.CreateService can only be used on the server")
    assert(serviceDef and serviceDef.Name, "Service definition requires a Name")
    serviceDef.KnitInit = serviceDef.KnitInit or function() end
    serviceDef.KnitStart = serviceDef.KnitStart or function() end
    serviceDef.Client = serviceDef.Client or {}
    Knit.Services[serviceDef.Name] = serviceDef
    return serviceDef
end

function Knit.AddServices(container: Instance)
    assert(isServer, "Knit.AddServices can only run on the server")
    registerModules(container, require)
end

function Knit.GetService(name: string)
    local service = Knit.Services[name]
    if not service then
        error("[Knit] Service not found: " .. tostring(name))
    end
    return service
end

function Knit.CreateController(controllerDef)
    assert(not isServer, "Knit.CreateController can only be used on the client")
    assert(controllerDef and controllerDef.Name, "Controller definition requires a Name")
    controllerDef.KnitInit = controllerDef.KnitInit or function() end
    controllerDef.KnitStart = controllerDef.KnitStart or function() end
    Knit.Controllers[controllerDef.Name] = controllerDef
    return controllerDef
end

function Knit.AddControllers(container: Instance)
    assert(not isServer, "Knit.AddControllers can only run on the client")
    registerModules(container, require)
end

local function runLifecycle(collection)
    for _, object in pairs(collection) do
        if type(object.KnitInit) == "function" then
            object:KnitInit()
        end
    end

    for _, object in pairs(collection) do
        if type(object.KnitStart) == "function" then
            task.spawn(function()
                object:KnitStart()
            end)
        end
    end
end

local startCompleted = false

function Knit.Start()
    if startCompleted then
        return setmetatable({}, StartPromise)
    end

    startCompleted = true
    if isServer then
        runLifecycle(Knit.Services)
    else
        runLifecycle(Knit.Controllers)
    end

    return setmetatable({}, StartPromise)
end

return Knit
