--[[
    LadyCelestia 8/28/2023
    Character Handler
--]]

local ServerStorage = game:GetService("ServerStorage")
local Bindables = ServerStorage:WaitForChild("Bindables")
local RagdollEvent = Bindables:WaitForChild("RagdollEvent")

local Character = script.Parent
local Humanoid : Humanoid = Character:WaitForChild("Humanoid")
local CharacterStats : Folder = Character:WaitForChild("CharacterStats")

local Stamina : NumberValue = CharacterStats:WaitForChild("Stamina")
local MaxStamina : IntValue = CharacterStats:WaitForChild("MaxStamina")
local StaminaRegen : NumberValue = CharacterStats:WaitForChild("StaminaRegen")
local Sprinting : BoolValue = CharacterStats:WaitForChild("Sprinting")
local CanRegenStamina = true
local StaminaValue = Stamina.Value
local StaminaCoroutine = nil

local Mana : NumberValue = CharacterStats:WaitForChild("Mana")
local MaxMana : IntValue = CharacterStats:WaitForChild("MaxMana")
local ManaRegen : NumberValue = CharacterStats:WaitForChild("ManaRegen")
local CanRegenMana = true
local ManaValue = Mana.Value
local ManaCoroutine = nil

local HealthRegen : NumberValue = CharacterStats:WaitForChild("HealthRegen")

local KnockedSerial = nil

Stamina:GetPropertyChangedSignal("Value"):Connect(function()
	if Stamina.Value < StaminaValue then
		CanRegenStamina = false
		if StaminaCoroutine ~= nil then
			pcall(task.cancel, StaminaCoroutine)
		end
		StaminaCoroutine = task.delay(3.8, function()
			CanRegenStamina = true
		end)
	end
	StaminaValue = Stamina.Value
end)

Mana:GetPropertyChangedSignal("Value"):Connect(function()
	if Mana.Value < ManaValue then
		CanRegenMana = false
		if ManaCoroutine ~= nil then
			pcall(task.cancel, ManaCoroutine)
		end
		ManaCoroutine = task.delay(3.8, function()
			CanRegenMana = true
		end)
	end
	ManaValue = Mana.Value
end)

Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
	if Humanoid.Health <= 0 then
		for i,v in pairs(Character:GetDescendants()) do
			if v:IsA("Motor6D") or v:IsA("BallSocketConstraint") then
				v:Destroy()
			end
		end
		script:Destroy()
	elseif Humanoid.Health <= 1 and KnockedSerial == nil then
		KnockedSerial = RagdollEvent:Invoke("Ragdoll", Character)
	elseif Humanoid.Health >= 18 and KnockedSerial ~= nil then
		RagdollEvent:Invoke("Unragdoll", Character, KnockedSerial)
		KnockedSerial = nil
	end
end)

local RunService = game:GetService("RunService")
local frame = 0
local delta = 0
RunService.Stepped:Connect(function(_, deltaTime)
	frame += 1
	delta += deltaTime
	if frame >= 5 then
		if CanRegenStamina == true and Sprinting.Value == false then
			if (Stamina.Value + (StaminaRegen.Value * delta)) <= MaxStamina.Value then
				Stamina.Value += (StaminaRegen.Value * delta)
			elseif Stamina.Value < MaxStamina.Value then
				Stamina.Value = MaxStamina.Value
			end
		end
		if CanRegenMana == true and Sprinting.Value == false then
			if (Mana.Value + (ManaRegen.Value * delta)) <= MaxMana.Value then
				Mana.Value += (ManaRegen.Value * delta)
			elseif Mana.Value < MaxMana.Value then
				Mana.Value = MaxMana.Value
			end
		end
		if Humanoid.Health < Humanoid.MaxHealth then
			if (Humanoid.Health + HealthRegen.Value * delta) <= Humanoid.MaxHealth then
				Humanoid.Health += HealthRegen.Value * delta
			else
				Humanoid.Health = Humanoid.MaxHealth
			end
		end
		frame = 0
		delta = 0
	end
end)