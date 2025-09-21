-- 몹 충돌 그룹 설정 스크립트
-- 위치: 각 몹 모델 내부 (예: Mob 모델 안에 Script로)

local mobModel = script.Parent -- 스크립트의 부모 (몹 모델)
local PhysicsService = game:GetService("PhysicsService") -- PhysicsService 불러오기

local MOB_GROUP_NAME = "mob" -- 스튜디오에서 만든 'mob' 충돌 그룹 이름 (소문자)

-- 몹 모델의 모든 파트를 'mob' 충돌 그룹에 할당하는 함수
local function SetMobCollisionGroup(mobInstance)
	for _, part in pairs(mobInstance:GetDescendants()) do
		if part:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(part, MOB_GROUP_NAME)
		end
	end
end

-- 스크립트가 로드될 때 몹의 충돌 그룹 설정
SetMobCollisionGroup(mobModel)

-- (선택 사항: 몹 모델에 파트가 나중에 동적으로 추가될 경우를 대비)
-- mobModel.DescendantAdded:Connect(function(newPart)
--    if newPart:IsA("BasePart") then
--        PhysicsService:SetPartCollisionGroup(newPart, MOB_GROUP_NAME)
--    end
-- end)

