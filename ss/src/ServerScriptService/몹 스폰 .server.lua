-- Optimized Mob Spawner Script
-- 위치: ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DebrisService = game:GetService("Debris") -- 제거 서비스

-- ✨ 설정 부분 ✨ (여기를 바꿔서 원하는 대로 몹 스폰을 조절하세요)
local NPC_TEMPLATE_NAMES = {"Rig", "mob"} -- ReplicatedStorage에 있는 몹 템플릿 모델 이름 리스트 (여러 개 추가 가능)
-- 예: {"MobTemplate1", "MobTemplate2", "Zombie", "Orc"}
local SPAWN_AREA_PART_NAMES = {"SpawnArea"} -- Workspace에 있는 몹 스폰 구역 Part들의 이름 리스트
-- 이 파트들의 위에서 몹이 랜덤하게 스폰됩니다.

--###################################################################################
local MAX_NPC_COUNT = 150 -- 월드에 동시에 존재할 수 있는 최대 NPC (몹) 수
local SPAWN_INTERVAL = 1 -- 새 NPC를 소환 시도하는 간격 (초)
--####################################################################################

-- ✨ 내부 상태 변수 ✨
local activeNpcs = {} -- {npcModel = true} - 현재 월드에 활성화된 NPC 모델들을 저장
local lastSpawnTime = 0 -- 마지막으로 NPC를 소환한 시간
local spawnAreas = {} -- 스폰 구역 파트들의 정보를 저장

-- ✨ 함수: 스폰 구역 파트 정보 가져오기 ✨
-- 스크립트가 시작될 때 Workspace에서 지정된 이름의 스폰 구역 파트들을 찾아 정보를 저장합니다.
local function getSpawnAreas()
	local areas = {}
	for _, name in ipairs(SPAWN_AREA_PART_NAMES) do
		local part = game.Workspace:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(areas, {Position = part.Position, Size = part.Size})
		else
			warn("Mob Spawner: 스폰 구역 파트 '" .. name .. "'을(를) 찾을 수 없거나 BasePart가 아닙니다.")
		end
	end
	return areas
end

-- 스크립트 로드 시 스폰 구역 초기화
spawnAreas = getSpawnAreas()

-- ✨ 함수: 죽었거나 제거된 NPC 정리 ✨
-- activeNpcs 테이블에서 더 이상 유효하지 않은 NPC 모델들을 제거합니다.
local function cleanupDeadNpcs()
	local updatedActiveNpcs = {}
	for npcModel, _ in pairs(activeNpcs) do
		-- NPC 모델이 여전히 존재하고, 부모가 있으며, Humanoid가 살아있을 경우에만 유지
		if npcModel and npcModel.Parent and npcModel:FindFirstChildOfClass("Humanoid") and npcModel:FindFirstChildOfClass("Humanoid").Health > 0 then
			updatedActiveNpcs[npcModel] = true
		else
			-- 몹이 죽었거나 파괴된 경우, 남아있다면 DebrisService로 완전히 제거 예약
			if npcModel and npcModel.Parent then
				DebrisService:AddItem(npcModel, 0) -- 즉시 제거
			end
		end
	end
	activeNpcs = updatedActiveNpcs
end


-- ✨ 메인 스폰 루프 (RunService.Heartbeat 사용) ✨
-- 게임의 매 프레임마다 호출되어 몹 스폰 로직을 실행합니다.
RunService.Heartbeat:Connect(function()
	local currentTime = tick()

	-- 주기적으로 죽었거나 제거된 NPC 참조를 정리
	cleanupDeadNpcs()

	-- 현재 NPC 수가 최대치를 초과하면 더 이상 소환하지 않습니다.
	if #activeNpcs >= MAX_NPC_COUNT then return end

	-- 마지막 소환 시도 시간부터 충분한 간격이 지나지 않았다면 소환하지 않습니다.
	if (currentTime - lastSpawnTime) < SPAWN_INTERVAL then return end

	-- 새 NPC를 소환할 시간입니다.
	lastSpawnTime = currentTime

	-- ✨ 유효성 검사 ✨
	if #NPC_TEMPLATE_NAMES == 0 then warn("Mob Spawner: 설정된 NPC 템플릿이 없습니다."); return end
	if #spawnAreas == 0 then warn("Mob Spawner: 설정된 스폰 구역이 없습니다."); return end

	-- ✨ 1. 랜덤 NPC 템플릿 선택 ✨
	local randomTemplateName = NPC_TEMPLATE_NAMES[math.random(1, #NPC_TEMPLATE_NAMES)]
	local npcTemplate = ReplicatedStorage:FindFirstChild(randomTemplateName)
	if not npcTemplate or not npcTemplate:IsA("Model") then
		warn("Mob Spawner: NPC 템플릿 '" .. randomTemplateName .. "'을 찾을 수 없거나 Model 타입이 아닙니다."); return
	end

	-- ✨ 2. 랜덤 스폰 구역 선택 ✨
	local spawnArea = spawnAreas[math.random(1, #spawnAreas)]

	-- ✨ 3. NPC 복제 및 Workspace에 추가 ✨
	local npcClone = npcTemplate:Clone()
	npcClone.Parent = game.Workspace

	-- ✨ 4. 스폰 위치 계산 (스폰 구역의 표면 위에 정확히 배치) ✨
	local randomX = math.random(spawnArea.Position.X - spawnArea.Size.X/2, spawnArea.Position.X + spawnArea.Size.X/2)
	local randomZ = math.random(spawnArea.Position.Z - spawnArea.Size.Z/2, spawnArea.Position.Z + spawnArea.Size.Z/2)
	local surfaceY = spawnArea.Position.Y + spawnArea.Size.Y / 2 -- 스폰 구역의 윗면 Y 좌표

	local humanoidRootPart = npcClone:FindFirstChild("HumanoidRootPart") -- 몹의 HumanoidRootPart를 찾음
	local npcHeightOffset = 0 
	if humanoidRootPart then
		npcHeightOffset = humanoidRootPart.Size.Y / 2 -- HumanoidRootPart 높이의 절반
		-- 모델의 PrimaryPart가 설정되어 있다면 SetPrimaryPartCFrame 사용 (더 정확)
		if npcClone.PrimaryPart then
			npcClone:SetPrimaryPartCFrame(CFrame.new(randomX, surfaceY + npcHeightOffset, randomZ))
		else -- PrimaryPart가 없다면 MoveTo 사용
			npcClone:MoveTo(Vector3.new(randomX, surfaceY + npcHeightOffset, randomZ))
		end
	else
		-- HumanoidRootPart가 없는 경우, 기본적으로 표면에서 2스터드 위에 스폰 (땅에 박히지 않게)
		warn("Mob Spawner: 소환된 NPC에 HumanoidRootPart가 없습니다. 기본 높이로 소환됩니다.")
		npcClone:MoveTo(Vector3.new(randomX, surfaceY + 2, randomZ))
	end

	-- ✨ 5. 활성화된 NPC 리스트에 추가 ✨
	activeNpcs[npcClone] = true

	-- ✨ 6. NPC Humanoid Died 이벤트 연결 (선택 사항: 좀비 내부 스크립트가 이미 처리한다면 필요 없음) ✨
	local humanoid = npcClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if activeNpcs[npcClone] then
				activeNpcs[npcClone] = nil -- 몹이 죽으면 즉시 리스트에서 제거
				-- (주의: 몹 내부 스크립트에서 Destroy()를 호출하는 경우)
				-- DebrisService:AddItem(npcClone, 2) -- 죽음 애니메이션 등 고려하여 2초 후 최종 제거 예약
			end
		end)
	end
end)