local NEW_WALK_ANIMATION_ID = "108526943269716"
local NEW_RUN_ANIMATION_ID = "108526943269716"




local npcModel = script.Parent
local animateScript = npcModel:WaitForChild("Animate")
local walkAnimContainer = animateScript:FindFirstChild("walk")
if walkAnimContainer and NEW_WALK_ANIMATION_ID ~= "0" then
	local walkAnim = walkAnimContainer:FindFirstChildOfClass("Animation") or (walkAnimContainer:IsA("Animation") and walkAnimContainer)
	if walkAnim then
		walkAnim.AnimationId = "rbxassetid://" .. NEW_WALK_ANIMATION_ID
	end
end
local runAnimContainer = animateScript:FindFirstChild("run")
if runAnimContainer and NEW_RUN_ANIMATION_ID ~= "0" then
	local runAnim = runAnimContainer:FindFirstChildOfClass("Animation") or (runAnimContainer:IsA("Animation") and runAnimContainer)
	if runAnim then
		runAnim.AnimationId = "rbxassetid://" .. NEW_RUN_ANIMATION_ID
	end
end