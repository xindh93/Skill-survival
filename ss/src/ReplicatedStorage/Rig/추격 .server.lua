-- 개별 몹 공격 스크립트
-- 위치: 각 몹 모델 내부 (예: Mob 모델 안에 Script로)

local mobModel = script.Parent -- 스크립트의 부모 (몹 모델)
local mobHumanoid = mobModel:FindFirstChildOfClass("Humanoid") -- 몹의 Humanoid

local DEBOUNCE_ACTIVE = false -- 공격 시간 제한 (디바운스) 활성화 여부

-- 몹이 다른 오브젝트와 충돌했을 때 (공격 감지)
mobHumanoid.Touched:Connect(function(hitPart)
	local hitCharacter = hitPart.Parent -- 충돌한 오브젝트의 부모 (캐릭터)
	local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid") -- 충돌한 캐릭터의 Humanoid

	-- 유효한 생명체와 충돌했고 디바운스가 비활성 상태일 경우 처리
	if hitHumanoid and hitHumanoid.Health > 0 and not DEBOUNCE_ACTIVE then
		local playerHit = game.Players:GetPlayerFromCharacter(hitCharacter) -- 충돌한 캐릭터가 플레이어인지 확인

		-- 플레이어와 충돌한 경우 공격 처리
		if playerHit then
			DEBOUNCE_ACTIVE = true -- 디바운스 활성화 (중복 공격 방지)
			hitHumanoid.Health -= 5 -- 플레이어 체력 5 감소
			task.wait(1) -- 1초 대기 (다음 공격까지의 쿨타임)
			DEBOUNCE_ACTIVE = false -- 디바운스 비활성화 (다음 공격 가능)
		end
	end
end)