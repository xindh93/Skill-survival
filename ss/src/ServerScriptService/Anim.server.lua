local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://108526943269716" 

		local track = humanoid:LoadAnimation(animation)
		track:Play()
	end)
end)