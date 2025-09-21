-- PassiveKnifeSystem Script (최종 최적화 버전!)
-- 위치: ServerScriptService (이 스크립트를 이곳에 넣어주세요!)

-- ⭐ 서비스 참조
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local DebrisService = game:GetService("Debris")

-- ✨ 설정 변수 ✨ (여기 값들을 조절해서 쿨타임, 속도, 데미지 등을 변경할 수 있습니다)
local KNIFE_MODEL_NAME = "ThrowingKnife" -- ReplicatedStorage에 있는 단검 모델 이름 (정확히 일치해야 함!)
local THROW_COOLDOWN = 1.0 -- 단검 발사 간격 (초) - 조금 빠르게 (1.5초 -> 1.0초)
local KNIFE_SPEED = 200 -- 단검이 날아가는 속도 (스터드/초) - 더 빠르게 (50 -> 80)
local KNIFE_DAMAGE = 20 -- 단검이 주는 피해량 - 더 강력하게 (10 -> 20)
local MAX_RANGE = 400 -- 몹을 찾을 최대 거리 (스터드) - 범위 넓게 (200 -> 400)

-- ✨ 몹 태그 정보 ✨
local MOB_TAG = "mob" -- 몹 모델에 붙인 태그 이름 (소문자 'mob' 확인!)

-- ✨ 플레이어별 마지막 발사 시간을 저장할 테이블 (쿨타임 관리용) ✨
local playerLastThrowTimes = {}

-- ✨ 함수: 단검 모델 복제 및 설정 ✨
local function getThrowingKnife()
	local knifeTemplate = ReplicatedStorage:FindFirstChild(KNIFE_MODEL_NAME)
	if not knifeTemplate then
		warn("단검 템플릿 '" .. KNIFE_MODEL_NAME .. "'을 ReplicatedStorage에서 찾을 수 없습니다!")
		return nil
	end

	local knifeClone = knifeTemplate:Clone()
	knifeClone.Parent = workspace
	knifeClone.Name = "ThrownKnife_" .. math.random(1, 1000)

	if not knifeClone.PrimaryPart then
		local firstBasePartFound = nil
		for _, obj in pairs(knifeClone:GetDescendants()) do
			if obj:IsA("BasePart") then
				firstBasePartFound = obj
				break
			end
		end
		if firstBasePartFound then
			knifeClone.PrimaryPart = firstBasePartFound
			warn("단검의 PrimaryPart가 Studio에서 설정되지 않았습니다. 자동으로 '" .. firstBasePartFound.Name .. "'으로 설정합니다.")
		else
			warn("단검 모델 '" .. knifeClone.Name .. "'에 BasePart가 없습니다! PrimaryPart 설정 불가능. 단검 파괴.")
			knifeClone:Destroy()
			return nil
		end
	end

	local mainPart = knifeClone.PrimaryPart
	if mainPart.Anchored then mainPart.Anchored = false end
	if mainPart.CanCollide then mainPart.CanCollide = false end

	for _, part in pairs(knifeClone:GetDescendants()) do
		if part:IsA("BasePart") and part ~= mainPart then 
			if part.Anchored then part.Anchored = false end
			if part.CanCollide then part.CanCollide = false end
			part.CanTouch = true
			part.Transparency = 0 
		end
	end

	return knifeClone
end

-- ✨ 함수: 단검 발사 로직 ✨
local function throwKnifeAtMob(playerChar, targetRootPart)
	local playerRootPart = playerChar:FindFirstChild("HumanoidRootPart")
	if not playerRootPart then return end
	if not targetRootPart or not targetRootPart.Parent then return end

	local knife = getThrowingKnife()
	if not knife then return end 

	local knifeMainPart = knife.PrimaryPart
	if not knifeMainPart then 
		knife:Destroy()
		return 
	end

	-- 180도 회전해서 세로 방향 유지하며 목표 바라보게 CFrame 설정
	local lookVector = (targetRootPart.Position - playerRootPart.Position).Unit
	local upVector = Vector3.new(0, 1, 0)
	local rightVector = lookVector:Cross(upVector).Unit
	local correctedUp = rightVector:Cross(lookVector).Unit

	local rotation180 = CFrame.Angles(0, math.rad(180), 0)

	local spawnOffset = lookVector * (playerRootPart.Size.Z / 2 + 1)
	knifeMainPart.CFrame = CFrame.fromMatrix(playerRootPart.Position + spawnOffset, lookVector, correctedUp) * rotation180

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge) 
	bodyVelocity.Velocity = lookVector * KNIFE_SPEED 
	bodyVelocity.Parent = knifeMainPart 

	DebrisService:AddItem(bodyVelocity, 0.1) 

	local hitConnection
	hitConnection = knifeMainPart.Touched:Connect(function(hitPart) 
		if not hitConnection then return end 

		hitConnection:Disconnect() 
		hitConnection = nil 

		local hitCharacter = hitPart.Parent

		if hitCharacter == playerChar then 
			return 
		end

		local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")

		if hitHumanoid and hitHumanoid.Health > 0 and CollectionService:HasTag(hitCharacter, MOB_TAG) then
			hitHumanoid:TakeDamage(KNIFE_DAMAGE)
			DebrisService:AddItem(knife, 0.01) 
		else
			DebrisService:AddItem(knife, 0.01) 
		end
	end)

	DebrisService:AddItem(knife, 5.0) 
end

-- ✨ 메인 게임 루프: Heartbeat 이벤트로 쿨타임마다 몹 감지 및 단검 발사 ✨
RunService.Heartbeat:Connect(function()
	local currentTime = tick() 

	for _, playerObj in pairs(Players:GetPlayers()) do 
		local character = playerObj.Character
		if not character then continue end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		local playerRootPart = character:FindFirstChild("HumanoidRootPart")
		if not playerRootPart then continue end

		local lastPlayerThrowTime = playerLastThrowTimes[playerObj.UserId] or 0 

		if currentTime - lastPlayerThrowTime < THROW_COOLDOWN then 
			continue 
		end

		local closestMob = nil
		local minDistSq = MAX_RANGE * MAX_RANGE

		local mobs = CollectionService:GetTagged(MOB_TAG)

		for _, mobModel in pairs(mobs) do
			local mobHumanoid = mobModel:FindFirstChildOfClass("Humanoid")
			local mobRootPart = mobModel:FindFirstChild("HumanoidRootPart")

			if mobHumanoid and mobHumanoid.Health > 0 and mobRootPart then
				local distVec = playerRootPart.Position - mobRootPart.Position
				local distSq = distVec.X^2 + distVec.Y^2 + distVec.Z^2 

				if distSq < minDistSq then
					minDistSq = distSq
					closestMob = mobRootPart
				end
			end
		end

		if closestMob then
			throwKnifeAtMob(character, closestMob)
			playerLastThrowTimes[playerObj.UserId] = currentTime
		end
	end
end)

-- ✨ 플레이어가 게임을 떠날 때, 해당 플레이어의 쿨타임 기록을 제거 ✨
Players.PlayerRemoving:Connect(function(playerObj)
	playerLastThrowTimes[playerObj.UserId] = nil 
end)