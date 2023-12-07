--[[
	LadyCelestia 3/11/2023
	Main AI for humanoid characters
--]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Teams = require(script.Parent.Parent:WaitForChild("Teams"))
local Pathfinder = require(script.Parent.Parent:WaitForChild("Pathfinder"))
local GetPlayerCharacters = require(script.Parent.Parent:WaitForChild("PlayerCharacterList"))

local function findClosestTarget()
	
end

local HumanoidAI = {}
HumanoidAI.__index = HumanoidAI

--[[
	States:
	Idle - Search for a target
	Chasing - Chase a found target
	Dash - Aggressive pursue with a line of sight
	CloseCombat - Close enough to target to enter combat

	Aggression: Attacking the AI increases your aggression toward the AI.
	When your aggression exceeds that of the current target's aggression, the AI targets you instead.
--]]

HumanoidAI.new = function(Character: Model)
	local self = setmetatable({}, HumanoidAI)

	self.StateMachine = nil
	self.Active = false
	self.Frames = 60 -- how many frames per update
	self.CurrentFrame = 0
	self.Aggression = {}
	self.CurrentAggression = 20
	self.CurrentTween = nil
	self.PreviousTarget = nil
	self.ChildAddedConnection = Character.ChildAdded:Connect(function(object)
		if object:IsA("ObjectValue") then
			local timestamp = tick()
			self.Aggression[object.Value][timestamp] = object.Name
			task.delay(5, function()
				self.Aggression[object.Value][timestamp] = nil
			end)
			local totalAggression = 0
			for oldTimestamp, aggression in pairs(self.Aggression[object.Value]) do
				if (timestamp - oldTimestamp) < 5 then
					totalAggression += aggression
					if totalAggression > self.CurrentAggression then
						self.CurrentAggression = totalAggression
						self.StateMachine.Target = object.Value
						self.StateMachine.State = "Chasing"
						pcall(function()
							self.StateMachine.Path:Destroy()
						end)
					end
				else
					self.Aggression[object.Value][oldTimestamp] = nil
				end
				
			end
		end
	end)
	self.ChildRemovedConnection = Character.ChildRemoved:Connect(function(object)
		if object:IsA("ObjectValue") and self.Aggression[object.Value] ~= nil then
			self.Aggression[object.Value] = nil
		end
	end)
	self.Connection = RunService.Stepped:Connect(function()
		self.CurrentFrame += 1
		if self.CurrentFrame >= self.Frames then
			self.CurrentFrame = 0
			if self.StateMachine ~= nil and self.StateMachine.Character ~= nil and self.Active == true then
				if self.StateMachine.State == "Idle" then
					-- Search for a target
					local closest = nil
					local dist = math.huge
					for _,v in ipairs(workspace:GetChildren()) do
						if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("CharacterStats") and v.CharacterStats:FindFirstChild("Team") and v:FindFirstChild("HumanoidRootPart") then
							local team = v.CharacterStats:FindFirstChild("Team")
							local hum = v:FindFirstChildOfClass("Humanoid")
							local targetRoot = v:FindFirstChild("HumanoidRootPart")
							if (hum.Health > 0) and (Teams.GetRelationStatus(self.StateMachine.Character.CharacterStats.Team.Value, team.Value) == 0) and ((self.StateMachine.Character.HumanoidRootPart.Position - targetRoot.Position).magnitude < dist) then
								closest = v
								dist = (self.StateMachine.Character.HumanoidRootPart.Position - targetRoot.Position).magnitude
							end
						end
					end
					if closest ~= nil and dist <= self.StateMachine.AggroRange then
						-- Begin chase
						self.StateMachine.State = "Chasing"
						self.CurrentAggression = 20
						self.StateMachine.Target = closest
						self.StateMachine.Path = Pathfinder.CharacterToCharacter(self.StateMachine.Character, self.StateMachine.Target, true)
						Pathfinder.AttachWalker(self.StateMachine.Character.Humanoid, self.StateMachine.Path)
						self.StateMachine.Character:FindFirstChildOfClass("Humanoid"):MoveTo(self.StateMachine.Path.Waypoints[self.StateMachine.Path.Next].Position)
						self.StateMachine.Path.Next += 1
					end
				elseif self.StateMachine.State == "Chasing" then
					local reset = false
					if self.StateMachine.Target == nil then
						-- The target might be despawned? Do a reset
						reset = true
					else
						local targetRoot = self.StateMachine.Target:FindFirstChild("HumanoidRootPart")
						local hum = self.StateMachine.Target:FindFirstChildOfClass("Humanoid")
						if targetRoot and hum and hum.Health > 0 then
							if (targetRoot.Position - self.StateMachine.Character.HumanoidRootPart.Position).magnitude <= 4.5 then
								-- Close enough, enter close combat
								self.StateMachine.State = "CloseCombat"
								self.StateMachine.Path:Destroy()
								self.StateMachine.Character:FindFirstChildOfClass("Humanoid"):MoveTo(self.StateMachine.Character.HumanoidRootPart.Position)
							end
						else
							-- The target is probably dead, do a reset
							reset = true
						end
					end
					if reset == true then
						self.StateMachine.State = "Idle"
						self.CurrentAggression = 0
						self.StateMachine.Path:Destroy()
						self.StateMachine.Character:FindFirstChildOfClass("Humanoid"):MoveTo(self.StateMachine.Character.HumanoidRootPart.Position)
					end
				elseif self.StateMachine.State == "CloseCombat" then
					local reset = false
					if self.StateMachine.Target == nil then
						-- The target might be despawned? Do a reset
						reset = true
					else
						local targetRoot = self.StateMachine.Target:FindFirstChild("HumanoidRootPart")
						local hum = self.StateMachine.Target:FindFirstChildOfClass("Humanoid")
						if targetRoot and hum and hum.Health > 0 then
							if (targetRoot.Position - self.StateMachine.Character.HumanoidRootPart.Position).magnitude <= 4.5 then
								-- Close enough, fight
								if typeof(self.CurrentTween) == "Instance" and self.CurrentTween:IsA("Tween") then
									self.CurrentTween:Cancel()
									self.CurrentTween:Destroy()
								end
								self.CurrentTween = TweenService:Create(self.StateMachine.Character.HumanoidRootPart, TweenInfo.new(), {CFrame = CFrame.lookAt(self.StateMachine.Character.HumanoidRootPart.Position, Vector3.new(targetRoot.Position.X, self.StateMachine.Character.HumanoidRootPart.Position.Y, targetRoot.Position.Z))})
								self.CurrentTween:Play()
								self.StateMachine.CombatAPI:LightAttack()
							else
								-- Target has fled! Chase
								self.StateMachine.State = "Chasing"
								self.StateMachine.Path = Pathfinder.CharacterToCharacter(self.StateMachine.Character, self.StateMachine.Target, true)
								Pathfinder.AttachWalker(self.StateMachine.Character:FindFirstChildOfClass("Humanoid"), self.StateMachine.Path)
								self.StateMachine.Character:FindFirstChildOfClass("Humanoid"):MoveTo(self.StateMachine.Path.Waypoints[self.StateMachine.Path.Next].Position)
							end
						else
							-- The target is probably dead, do a reset
							reset = true
						end
					end
					if reset == true then
						self.StateMachine.State = "Idle"
						self.CurrentAggression = 0
						self.StateMachine.Path:Destroy()
						self.StateMachine.Character:FindFirstChildOfClass("Humanoid"):MoveTo(self.StateMachine.Character.HumanoidRootPart.Position)
					end
				end
			elseif self.StateMachine ~= nil and self.StateMachine.Character == nil then
				-- The npc doesn't exist anymore, do clean up
				self.StateMachine:Destroy()
			end
		end
	end)

	return self
end

function HumanoidAI:Activate()
	self.CurrentFrame = self.Frames - 1
	self.Active = true
end

function HumanoidAI:Deactivate()
	self.Active = false
end

function HumanoidAI:Destroy()

end

return HumanoidAI