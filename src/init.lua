local collectionService = game:GetService("CollectionService")
local Pathfinder = require(script:WaitForChild("Pathfinder"))
local aiLibrary = require(script:WaitForChild("AILibrary"))
local combatAPIs = script:WaitForChild("CombatAPIs")
local combatAIs = script:WaitForChild("CombatAIs")

local loadedCombatAPIs = {}
local loadedCombatAIs = {}
local existingStateMachines = {}

for _,v in ipairs(combatAPIs:GetChildren()) do
	if v:IsA("ModuleScript") then
		loadedCombatAPIs[v.Name] = require(v)
	end
end
for _,v in ipairs(combatAIs:GetChildren()) do
	if v:IsA("ModuleScript") then
		loadedCombatAIs[v.Name] = require(v)
	end
end

local RagdollJointBlacklist = {"LeftWrist", "RightWrist", "LeftAnkle", "RightAnkle"}
local function BlacklistCheck(name : string)
	for _,v in ipairs(RagdollJointBlacklist) do
		if v == name then
			return false
		end
	end
	return true
end

local function loadCharacter(character : Model, noAnim : boolean)
	local humanoid : Humanoid = character:WaitForChild("Humanoid")
	local animator = Instance.new("Animator", humanoid)
	
	collectionService:AddTag(character, "NPCCharacter")

	local cn; cn = humanoid.Running:Connect(function(speed)
		if speed > 0 then
			cn:Disconnect()
			local ff = character:FindFirstChild("SpawnForceField")
			local ff2 = character:FindFirstChild("ForceField")
			if ff then
				ff:Destroy()
			end
			if ff2 then
				ff2:Destroy()
			end
		end
	end)

	humanoid.WalkSpeed = 12

	local RealSpeed = Instance.new("NumberValue")
	RealSpeed.Name = "RealSpeed"
	RealSpeed.Value = humanoid.WalkSpeed
	RealSpeed.Parent = humanoid

	local Root : BasePart = character:WaitForChild("HumanoidRootPart")

	for _,v in ipairs(character:GetDescendants()) do
		if v:IsA("Motor6D") and BlacklistCheck(v.Name) == true then
			local BallSocketConstraint = Instance.new("BallSocketConstraint", v.Parent)
			BallSocketConstraint.Name = "RagdollConstraint"
			local Attachment0, Attachment1 = Instance.new("Attachment"), Instance.new("Attachment")
			Attachment0.Parent, Attachment1.Parent = v.Part0, v.Part1
			BallSocketConstraint.Attachment0, BallSocketConstraint.Attachment1 = Attachment0, Attachment1
			Attachment0.CFrame, Attachment1.CFrame = v.c0, v.c1
			BallSocketConstraint.LimitsEnabled = true
			BallSocketConstraint.TwistLimitsEnabled = true
			BallSocketConstraint.Enabled = false
		elseif v:IsA("BasePart") then
			v.CollisionGroup = "RagdollA"
			if v.Name == "HumanoidRootPart" then
				v.CollisionGroup = "RagdollB"
			elseif v.Name == "Head" then
				v.CanCollide = true
			end
		end
	end

	if noAnim ~= true then
		local animations = character:FindFirstChild("Animations") or Instance.new("Folder")
		animations.Name = "Animations"
		animations.Parent = character
		local rollFront, rollBack, rollLeft, rollRight = Instance.new("Animation"), Instance.new("Animation"), Instance.new("Animation"), Instance.new("Animation")
		rollFront.Name, rollBack.Name, rollLeft.Name, rollRight.Name = "RollFront", "RollBack", "RollLeft", "RollRight"
		rollFront.AnimationId, rollBack.AnimationId, rollLeft.AnimationId, rollRight.AnimationId = "rbxassetid://14635811987", "rbxassetid://14635819269", "rbxassetid://14635834979", "rbxassetid://14635828633"
		rollFront.Parent, rollBack.Parent, rollLeft.Parent, rollRight.Parent = animations, animations, animations, animations
	end

	local characterStats = Instance.new("Folder")
	characterStats.Name = "CharacterStats"
	local stamina = Instance.new("NumberValue")
	stamina.Name = "Stamina"
	stamina.Value = 100
	stamina.Parent = characterStats
	local maxStamina = Instance.new("IntValue")
	maxStamina.Name = "MaxStamina"
	maxStamina.Value = 100
	maxStamina.Parent = characterStats
	local staminaRegen = Instance.new("NumberValue")
	staminaRegen.Name = "StaminaRegen"
	staminaRegen.Value = 25
	staminaRegen.Parent = characterStats
	local mana = Instance.new("NumberValue")
	mana.Name = "Mana"
	mana.Value = 100
	mana.Parent = characterStats
	local maxMana = Instance.new("IntValue")
	maxMana.Name = "MaxMana"
	maxMana.Value = 100
	maxMana.Parent = characterStats
	local manaRegen = Instance.new("NumberValue")
	manaRegen.Name = "ManaRegen"
	manaRegen.Value = 25
	manaRegen.Parent = characterStats
	local canParry = Instance.new("BoolValue")
	canParry.Name = "CanParry"
	canParry.Value = true
	canParry.Parent = characterStats
	local canRoll = Instance.new("BoolValue")
	canRoll.Name = "CanRoll"
	canRoll.Value = true
	canRoll.Parent = characterStats
	local healthRegen = Instance.new("NumberValue")
	healthRegen.Name = "HealthRegen"
	healthRegen.Value = 0.8
	healthRegen.Parent = characterStats
	local Sprinting = Instance.new("BoolValue")
	Sprinting.Name = "Sprinting"
	Sprinting.Value = false
	Sprinting.Parent = characterStats
	characterStats.Parent = character

	task.spawn(function()
		local Health : Script = character:WaitForChild("Health", 3)
		if Health ~= nil then
			Health:Destroy()
		end
	end)
end

local StateMachine = {}
StateMachine.__index = StateMachine

StateMachine.new = function()
	local self = setmetatable({}, StateMachine)
	
	self.State = "Idle"
	self.Character = nil
	self.Path = nil
	self.Weapon = nil
	self.CombatAI = nil
	self.CombatAPI = nil
	self.Target = nil
	self.AggroRange = 50
	self.Team = nil
	self.Difficulty = 50 -- 1 to 100, determins how proficient the AI is at combat (100 is max)
	
	table.insert(existingStateMachines, self)
	
	return self
end

function StateMachine:Update(doNotCompute)
	if self.CombatAI ~= nil then
		if self.CombatAI.IsHumanoid == true then
			self.CombatAPI.Weapon = self.Weapon
		end
		self.CombatAPI.Character = self.Character
	end
	if doNotCompute ~= true and self.Path ~= nil then
		self.Path:Compute()
	end
end

function StateMachine:Destroy()
	pcall(function()
		self.Path:Destroy()
	end)
	pcall(function()
		self.Weapon:Destroy()
	end)
	pcall(function()
		self.CombatAI:Destroy()
	end)
	self.Character = nil
	self.Target = nil
end

local Module = {}
Module.Pathfinder = Pathfinder
Module.Mount = loadCharacter

Module.newAI = function()
	return StateMachine.new()
end

Module.MountCombat = function(CombatType)	
	if loadedCombatAPIs[CombatType] ~= nil then
		return loadedCombatAPIs[CombatType].new()
	end
end

Module.MountAI = function(AIType)
	if loadedCombatAIs[AIType] ~= nil then
		return loadedCombatAIs[AIType].new()
	end
end

Module.buildAI = function(AIName)
	local newAI = StateMachine.new()
	for i,v in pairs(aiLibrary) do
		if i == AIName then
			newAI["CombatAI"] = (v["CombatAI"] ~= nil and loadedCombatAIs[v["CombatAI"]].new()) or nil
		end
	end
end

return Module