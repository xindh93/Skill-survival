local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

local LEVELING = Config.Leveling or {}
local LEVELING_UI = LEVELING.UI or {}
local MAX_LEVEL = (LEVELING.MaxLevel and math.floor(LEVELING.MaxLevel)) or 50
local LERP_SPEED = LEVELING_UI.LerpSpeed or 6
local FREEZE_FADE = LEVELING_UI.FreezeFade or 0.25

local controllersFolder = script.Parent and script.Parent:FindFirstChild("Controllers")

local function waitForController(name: string)
    while true do
        controllersFolder = controllersFolder or (script.Parent and script.Parent:FindFirstChild("Controllers"))

        local getController = Knit and Knit.GetController
        if typeof(getController) == "function" then
            local ok, controller = pcall(getController, Knit, name)
            if ok and controller then
                return controller
            end
        end

        if controllersFolder then
            local module = controllersFolder:FindFirstChild(name)
            if module and module:IsA("ModuleScript") then
                local ok, controller = pcall(require, module)
                if ok and controller then
                    return controller
                end
            end
        end

        task.wait()
    end
end

local function computeXPToNext(level: number): number
    if level >= MAX_LEVEL then
        return 0
    end
    if typeof(LEVELING.XPToNext) == "function" then
        local ok, value = pcall(LEVELING.XPToNext, level)
        if ok and typeof(value) == "number" then
            return math.max(0, math.floor(value))
        end
    end
    local baseXP = LEVELING.BaseXP or 100
    local growth = LEVELING.Growth or 1.25
    return math.max(0, math.floor(baseXP * (growth ^ (math.max(1, level) - 1))))
end

local uiController: any = nil
local hudReady = false
local pushHUDUpdate
local function markHUDReady()
    if hudReady then
        return
    end
    hudReady = true
    if pushHUDUpdate then
        pushHUDUpdate()
    end
end

local levelUpGui = PLAYER_GUI:WaitForChild("LevelUpModal", 5)
if not levelUpGui then
    levelUpGui = Instance.new("ScreenGui")
    levelUpGui.Name = "LevelUpModal"
    levelUpGui.ResetOnSpawn = false
    levelUpGui.IgnoreGuiInset = true
    levelUpGui.DisplayOrder = 100
    levelUpGui.Enabled = false
    levelUpGui.Parent = PLAYER_GUI
end

local freezeOverlay = levelUpGui:FindFirstChild("FreezeOverlay")
local rootFrame = levelUpGui:FindFirstChild("Root")
local confirmBlocker = levelUpGui:FindFirstChild("ConfirmBlocker")
local optionsFrame = rootFrame and rootFrame:FindFirstChild("Options")

local optionButtons = {}
if optionsFrame then
    for _, child in ipairs(optionsFrame:GetChildren()) do
        if child:IsA("TextButton") then
            table.insert(optionButtons, child)
        end
    end
    table.sort(optionButtons, function(a, b)
        return a.Name < b.Name
    end)
end

local xpState = {
    level = 1,
    xp = 0,
    xpToNext = computeXPToNext(1),
    currentRatio = 0,
    targetRatio = 0,
}

local worldFrozen = false
local modalActive = false
local choiceSubmitted = false
local activeChoices = nil
local overlayTween: Tween? = nil
local freezeBlockBound = false

pushHUDUpdate = function()
    if not uiController or not hudReady then
        return
    end

    local progress = {
        Ratio = math.clamp(xpState.currentRatio, 0, 1),
        Current = xpState.xp,
        Required = xpState.xpToNext,
    }

    uiController.State.Level = xpState.level
    uiController.State.XP = xpState.xp
    uiController.State.XPProgress = progress
    uiController:WithHUD("UpdateXP", {
        Level = xpState.level,
        XP = xpState.xp,
        XPProgress = progress,
    })
end

task.spawn(function()
    uiController = waitForController("UIController")
    local hudController = waitForController("HUDController")

    if hudController and typeof(hudController.OnInterfaceReady) == "function" then
        hudController:OnInterfaceReady(function()
            markHUDReady()
        end)
    end

    if hudController and hudController.Screen then
        markHUDReady()
    elseif not hudController then
        markHUDReady()
    end
end)

local function setTargetFromXP(xp: number, xpToNext: number)
    xpToNext = math.max(0, xpToNext or 0)
    xp = math.max(0, xp or 0)
    xpState.xp = xp
    xpState.xpToNext = xpToNext
    if xpToNext > 0 then
        xpState.targetRatio = math.clamp(xp / xpToNext, 0, 1)
    else
        xpState.targetRatio = 1
    end
end

local function applyLevel(level: number, xp: number, xpToNext: number)
    xpState.level = math.max(1, math.floor(level or 1))
    setTargetFromXP(xp, xpToNext)
end

local function setInputBlocked(enabled: boolean)
    if enabled and not freezeBlockBound then
        local function sink()
            return Enum.ContextActionResult.Sink
        end
        ContextActionService:BindActionAtPriority(
            "SS_LevelUpFreeze",
            sink,
            false,
            Enum.ContextActionPriority.High.Value,
            Enum.KeyCode.W,
            Enum.KeyCode.A,
            Enum.KeyCode.S,
            Enum.KeyCode.D,
            Enum.KeyCode.Q,
            Enum.KeyCode.E,
            Enum.KeyCode.Space,
            Enum.UserInputType.MouseButton1,
            Enum.UserInputType.MouseButton2,
            Enum.UserInputType.Touch
        )
        freezeBlockBound = true
    elseif not enabled and freezeBlockBound then
        ContextActionService:UnbindAction("SS_LevelUpFreeze")
        freezeBlockBound = false
    end
end

local function tweenOverlay(enabled: boolean)
    if not freezeOverlay then
        return
    end

    if overlayTween then
        overlayTween:Cancel()
        overlayTween = nil
    end

    local goal = {BackgroundTransparency = enabled and 0.35 or 1}
    overlayTween = TweenService:Create(
        freezeOverlay,
        TweenInfo.new(FREEZE_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        goal
    )

    overlayTween.Completed:Connect(function()
        if not enabled and not modalActive then
            levelUpGui.Enabled = false
            if rootFrame then
                rootFrame.Visible = false
            end
        end
    end)

    overlayTween:Play()
end

local function resetChoices()
    activeChoices = nil
    choiceSubmitted = false
    if not optionsFrame then
        return
    end

    for _, button in ipairs(optionButtons) do
        button.AutoButtonColor = false
        button.Active = false
        button.Selectable = false
        button.Visible = true
        local stroke = button:FindFirstChildWhichIsA("UIStroke")
        if stroke then
            stroke.Transparency = 0.2
        end
        local choiceId = button:FindFirstChild("ChoiceId")
        if choiceId and choiceId:IsA("StringValue") then
            choiceId.Value = ""
        end
        local nameLabel = button:FindFirstChild("Name")
        if nameLabel and nameLabel:IsA("TextLabel") then
            nameLabel.Text = "Loading..."
        end
        local descLabel = button:FindFirstChild("Desc")
        if descLabel and descLabel:IsA("TextLabel") then
            descLabel.Text = ""
        end
    end
end

local function populateChoices(choices)
    activeChoices = choices
    if not choices then
        for _, button in ipairs(optionButtons) do
            button.AutoButtonColor = false
            button.Active = false
            local nameLabel = button:FindFirstChild("Name")
            if nameLabel and nameLabel:IsA("TextLabel") then
                nameLabel.Text = "No Options"
            end
            local descLabel = button:FindFirstChild("Desc")
            if descLabel and descLabel:IsA("TextLabel") then
                descLabel.Text = "Please wait for the server."
            end
        end
        return
    end

    for index, button in ipairs(optionButtons) do
        local info = choices[index]
        local choiceId = button:FindFirstChild("ChoiceId")
        if info and typeof(info) == "table" then
            button.AutoButtonColor = true
            button.Active = true
            button.Selectable = true
            local nameLabel = button:FindFirstChild("Name")
            local descLabel = button:FindFirstChild("Desc")
            if nameLabel and nameLabel:IsA("TextLabel") then
                nameLabel.Text = tostring(info.name or info.id or "Unknown")
            end
            if descLabel and descLabel:IsA("TextLabel") then
                descLabel.Text = tostring(info.desc or "")
            end
            if choiceId and choiceId:IsA("StringValue") then
                choiceId.Value = tostring(info.id or "")
            end
        else
            button.AutoButtonColor = false
            button.Active = false
            button.Selectable = false
            if choiceId and choiceId:IsA("StringValue") then
                choiceId.Value = ""
            end
            local nameLabel = button:FindFirstChild("Name")
            if nameLabel and nameLabel:IsA("TextLabel") then
                nameLabel.Text = "Unavailable"
            end
            local descLabel = button:FindFirstChild("Desc")
            if descLabel and descLabel:IsA("TextLabel") then
                descLabel.Text = ""
            end
        end
    end
end

local function requestChoices()
    local remote = Net:GetFunction("GetLevelUpChoices")
    local success, payload = pcall(function()
        return remote:InvokeServer()
    end)
    if not success then
        warn("PlayerProgress: failed to fetch level-up choices", payload)
        populateChoices(nil)
        return
    end

    if typeof(payload) ~= "table" then
        populateChoices(nil)
        return
    end

    if not modalActive then
        return
    end

    populateChoices(payload.Choices)
end

local function onOptionClicked(button: TextButton)
    if choiceSubmitted or not modalActive then
        return
    end

    local choiceId = ""
    local choiceValue = button:FindFirstChild("ChoiceId")
    if choiceValue and choiceValue:IsA("StringValue") then
        choiceId = choiceValue.Value
    end
    if choiceId == "" then
        return
    end

    choiceSubmitted = true
    for _, option in ipairs(optionButtons) do
        option.AutoButtonColor = false
        option.Active = false
        option.Selectable = false
        local stroke = option:FindFirstChildWhichIsA("UIStroke")
        if stroke then
            stroke.Transparency = option == button and 0 or 0.6
        end
    end

    Net:GetEvent("CommitLevelUpChoice"):FireServer(choiceId)
end

for _, button in ipairs(optionButtons) do
    button.MouseButton1Click:Connect(function()
        onOptionClicked(button)
    end)
end

if confirmBlocker and confirmBlocker:IsA("GuiButton") then
    confirmBlocker.AutoButtonColor = false
    confirmBlocker.MouseButton1Click:Connect(function()
        -- intentional no-op to block dismiss
    end)
end

local function playLevelUpAnimation(newLevel: number, carriedXP: number)
    carriedXP = carriedXP or 0
    local previousGoal = xpState.xpToNext > 0 and xpState.xpToNext or computeXPToNext(math.max(1, newLevel - 1))
    xpState.targetRatio = 1
    xpState.xp = previousGoal
    xpState.xpToNext = previousGoal

    task.spawn(function()
        while math.abs(xpState.currentRatio - 1) > 0.01 do
            RunService.RenderStepped:Wait()
        end

        local nextGoal = computeXPToNext(newLevel)
        xpState.level = math.clamp(newLevel, 1, MAX_LEVEL)
        xpState.currentRatio = 0
        xpState.xpToNext = nextGoal
        xpState.xp = math.clamp(carriedXP, 0, nextGoal > 0 and nextGoal or carriedXP)
        if nextGoal > 0 then
            xpState.targetRatio = math.clamp(xpState.xp / nextGoal, 0, 1)
        else
            xpState.targetRatio = 1
        end
        pushHUDUpdate()
    end)
end

local progressFunction = Net:GetFunction("GetProgress")
local xpChangedEvent = Net:GetEvent("XPChanged")
local levelUpEvent = Net:GetEvent("LevelUp")
local freezeEvent = Net:GetEvent("SetWorldFreeze")

local success, initial = pcall(function()
    return progressFunction:InvokeServer()
end)
if success and typeof(initial) == "table" then
    local level = initial.Level or initial.level or 1
    local xp = initial.XP or initial.xp or 0
    local xpToNext = initial.XPToNext or initial.xpToNext or computeXPToNext(level)
    xpState.currentRatio = xpToNext > 0 and math.clamp(xp / xpToNext, 0, 1) or 1
    applyLevel(level, xp, xpToNext)
    pushHUDUpdate()
else
    warn("PlayerProgress: failed to load initial progress", initial)
end

xpChangedEvent.OnClientEvent:Connect(function(player, xp, xpToNext)
    if player ~= LOCAL_PLAYER then
        return
    end

    setTargetFromXP(xp, xpToNext)
    pushHUDUpdate()
end)

levelUpEvent.OnClientEvent:Connect(function(player, newLevel, carriedXP)
    if player ~= LOCAL_PLAYER then
        return
    end

    modalActive = true
    levelUpGui.Enabled = true
    if rootFrame then
        rootFrame.Visible = true
    end
    setInputBlocked(true)
    tweenOverlay(true)
    resetChoices()
    task.spawn(requestChoices)
    playLevelUpAnimation(newLevel, carriedXP)
end)

freezeEvent.OnClientEvent:Connect(function(enabled)
    worldFrozen = not not enabled
    setInputBlocked(worldFrozen)
    if worldFrozen then
        levelUpGui.Enabled = true
        tweenOverlay(true)
    else
        tweenOverlay(false)
        modalActive = false
        if rootFrame then
            rootFrame.Visible = false
        end
        resetChoices()
    end
end)

RunService.RenderStepped:Connect(function(dt)
    local diff = xpState.targetRatio - xpState.currentRatio
    if math.abs(diff) > 0.0005 then
        local step = math.clamp(dt * LERP_SPEED, 0, 1)
        xpState.currentRatio += diff * step
    else
        xpState.currentRatio = xpState.targetRatio
    end
    pushHUDUpdate()
end)
