-- 중앙 몹 AI 제어 스크립트
-- 위치: ServerScriptService

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MOB_TAG = "mob" -- 몹 모델에 사용된 태그
local MOB_TRACKING_DIST_SQ = 200 * 200 -- 몹 추적 거리의 제곱 (예: 100스터드)

-- 주기적으로 몹들의 AI를 업데이트
RunService.Heartbeat:Connect(function(dt)
	-- 약 0.2초마다 몹 AI를 처리 (서버 부하 분산)
	if os.clock() % 0.2 < dt then
		local mobsToProcess = CollectionService:GetTagged(MOB_TAG) -- 'mob' 태그가 붙은 모든 몹 가져오기

		for _, currentMobModel in pairs(mobsToProcess) do
			local mobHumanoid = currentMobModel:FindFirstChildOfClass("Humanoid")
			local mobRootPart = currentMobModel:FindFirstChild("HumanoidRootPart")

			-- 몹이 유효하지 않거나 죽었다면 건너뛰기
			if not (mobHumanoid and mobHumanoid.Health > 0 and mobRootPart) then continue end

			local targetPlayerChar = nil -- 가장 가까운 플레이어 캐릭터 저장 변수
			local minDistSqToTarget = MOB_TRACKING_DIST_SQ -- 현재까지 발견된 최소 거리 제곱

			-- 모든 플레이어를 순회하며 가장 가까운 유효한 대상 찾기
			for _, playerObj in pairs(game.Players:GetPlayers()) do
				local playerChar = playerObj.Character
				-- 플레이어 캐릭터가 유효하지 않거나, 죽었거나, RootPart가 없으면 건너뛰기
				if not (playerChar and playerChar:FindFirstChildOfClass("Humanoid") and playerChar:FindFirstChildOfClass("Humanoid").Health > 0 and playerChar:FindFirstChild("HumanoidRootPart")) then continue end

				local playerRootPart = playerChar.HumanoidRootPart

				-- ⭐⭐ 여기 한 줄이 수정된 부분! MagnitudeSquared 대신 직접 제곱을 계산해! ⭐⭐
				local distVec = mobRootPart.Position - playerRootPart.Position
				local currentDistSq = distVec.X^2 + distVec.Y^2 + distVec.Z^2 
				-- 또는 currentDistSq = distVec.Magnitude * distVec.Magnitude 이렇게 해도 돼!

				-- 현재 플레이어가 더 가깝다면 가장 가까운 대상으로 업데이트
				if currentDistSq < minDistSqToTarget then
					minDistSqToTarget = currentDistSq
					targetPlayerChar = playerChar
				end
			end

			-- 대상 플레이어가 있으면 해당 방향으로 몹 이동, 없으면 제자리 멈춤
			if targetPlayerChar then
				mobHumanoid:MoveTo(targetPlayerChar.HumanoidRootPart.Position)
			else
				mobHumanoid:MoveTo(mobRootPart.Position) -- 몹 제자리에 멈춤
			end
		end
	end
end)