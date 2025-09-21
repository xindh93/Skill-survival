-- playerCollisionGroup Script
-- 위치: StarterPlayer/StarterCharacterScripts

local character = script.Parent -- 이 스크립트가 실행될 캐릭터 (플레이어)
local PhysicsService = game:GetService("PhysicsService") 

local PLAYER_GROUP_NAME = "player" -- 스튜디오에서 만든 소문자 'player' 충돌 그룹 이름

-- 캐릭터의 모든 파트를 'player' 충돌 그룹에 할당하는 함수
local function SetPlayerCollisionGroup(playerChar)
	for _, part in pairs(playerChar:GetDescendants()) do
		if part:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(part, PLAYER_GROUP_NAME)
		end
	end
end

-- 스크립트가 로드될 때 (플레이어 캐릭터가 생성될 때) 충돌 그룹 설정 함수 호출
SetPlayerCollisionGroup(character)

-- (선택 사항: 플레이어 캐릭터에 파트가 동적으로 추가될 경우를 대비)
-- 캐릭터에 새로운 파트가 추가될 때마다 해당 파트의 충돌 그룹도 설정
character.DescendantAdded:Connect(function(newPart)
	if newPart:IsA("BasePart") then
		PhysicsService:SetPartCollisionGroup(newPart, PLAYER_GROUP_NAME)
	end
end)