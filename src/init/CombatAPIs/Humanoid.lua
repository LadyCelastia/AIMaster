--[[
	LadyCelestia 27/10/2023
	API for handling humanoid combat
--]]

local debris = game:GetService("Debris")
local serverStorage = game:GetService("ServerStorage")
local serverValues = serverStorage:WaitForChild("Values")
local rollValues = serverValues:WaitForChild("Rolling")
local rollForce = rollValues:WaitForChild("RollForce")
local rollDuration = rollValues:WaitForChild("RollDuration")
local rollYVelocity = rollValues:WaitForChild("RollYVelocity")
local rollYDurationDivider = rollValues:WaitForChild("RollYDurationDivider")
local bindablesFolder = serverStorage:WaitForChild("Bindables")
local statusEffectBindable = bindablesFolder:WaitForChild("StatusEffect")

local HumanoidCombat = {}
HumanoidCombat.__index = HumanoidCombat

HumanoidCombat.new = function(Character)
	local self = setmetatable({}, HumanoidCombat)

	self.IsHumanoid = true
	self.Weapon = nil
	self.Character = Character
	for _,v in ipairs(script:GetChildren()) do
		v:Clone().Parent = Character
	end

	return self
end

function HumanoidCombat:Roll(Direction)
	if self.Character ~= nil then
		local character = self.Character
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local canRoll : BoolValue = character.CharacterStats.CanRoll
		local stamina : NumberValue = character.CharacterStats.Stamina
		if stamina.Value < 16 then
			return nil
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		task.delay(.9, function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end)
		if canRoll.Value == true then
			canRoll.Value = false
			stamina.Value -= 16
			task.delay(3.3, function()
				canRoll.Value = true
			end)
			local iframe = Instance.new("BoolValue")
			debris:AddItem(iframe, .69)
			iframe.Name = "IFrame"
			iframe.Value = true
			iframe.Parent = character
			local rollDirection = nil
			if Direction == "Left" then
				rollDirection = {"Right", -1}
			elseif Direction == "Right" then
				rollDirection = {"Right", 1}
			elseif Direction == "Back" then
				rollDirection = {"Front", -1}
			else
				rollDirection = {"Front", 1}
			end
			statusEffectBindable:Invoke("Stun", character, {
				["Duration"] = rollDuration.Value + .11,
				["SlowFactor"] = 1,
				["PlayNow"] = true
			})
			local YVelocity = rollYVelocity.Value
			local YDurationDivider = rollYDurationDivider.Value
			if humanoid.FloorMaterial == Enum.Material.Air then
				YVelocity = nil
				YDurationDivider = 500
			end
			statusEffectBindable:Invoke("Knockback", character, {
				["Force"] = rollForce.Value,
				["Duration"] = rollDuration.Value,
				["Direction"] = rollDirection,
				["YVelocity"] = YVelocity,
				["YDurationDivider"] = YDurationDivider,
				["PlayNow"] = true
			})
			task.delay(rollDuration.Value, function()
				statusEffectBindable:Invoke("Knockback", character, {
					["Force"] = 13.3,
					["Duration"] = .19,
					["Direction"] = rollDirection,
					["PlayNow"] = true
				})
			end)
		end
	end
end

function HumanoidCombat:StartSprint()
	if self.Character ~= nil then
		local Sprinting = self.Character.CharacterStats.Sprinting
		local humanoid = self.Character:FindFirstChildOfClass("Humanoid")
		if Sprinting.Value == false then
			Sprinting.Value = true
			humanoid.WalkSpeed += 10
		end
	end
end

function HumanoidCombat:StopSprint()
	if self.Character ~= nil then
		local Sprinting = self.Character.CharacterStats.Sprinting
		local humanoid = self.Character:FindFirstChildOfClass("Humanoid")
		if Sprinting.Value == true then
			Sprinting.Value = false
			humanoid.WalkSpeed -= 10
		end
	end
end

function HumanoidCombat:Block()
	if self.Character ~= nil and self.Weapon ~= nil then
		self.Weapon:Block(self.Weapon)
	end
end

function HumanoidCombat:Unblock()
	if self.Character ~= nil and self.Weapon ~= nil then
		self.Weapon:Unblock(self.Weapon)
	end
end

function HumanoidCombat:LightAttack()
	if self.Character ~= nil and self.Weapon ~= nil then
		self.Weapon:LightAttack(self.Weapon)
	end
end

function HumanoidCombat:HeavyAttack()
	if self.Character ~= nil and self.Weapon ~= nil then
		self.Weapon:HeavyAttack(self.Weapon)
	end
end

return HumanoidCombat