--[[
	LadyCelestia 3/11/2023
	Main AI for humanoid characters
--]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Teams = require(script.Parent.Parent:WaitForChild("Teams"))
local Pathfinder = require(script.Parent.Parent:WaitForChild("Pathfinder"))

local HumanoidAI = {}
HumanoidAI.__index = HumanoidAI

HumanoidAI.new = function(Character: Model)
	local self = setmetatable({}, HumanoidAI)

	self.StateMachine = nil
	self.Active = false
	self.Frames = 60 -- how many frames per update
	self.CurrentFrame = 0
	self.Aggression = {}
	self.AggressionConnections = {}
	self.CurrentAggression = 20
	self.PreviousTarget = nil
	self.CurrentTween = nil
	self.ChildAddedConnection = Character.ChildAdded:Connect(function(object)
		if object:IsA("ObjectValue") then
			self.Aggression[object.Value] = {}
			self.Aggression[object.Value][tick()] = object.Name
			self.AggressionConnections[object] = object:GetPropertyChangedSignal("Name"):Connect(function()
				self.Aggression[object.Value][tick()] = object.Name
				for timestamp, aggression in pairs(self.Aggression[object.Value]) do
					local totalAggression = 0
					if tick() - timestamp < 5 then
						totalAggression += aggression
						if totalAggression > self.CurrentAggression then
							--Retarget
							if self.StateMachine.Path ~= nil then
								self.StateMachine.Path:Destroy()
							end
							self.StateMachine.State = "Chasing"
							self.CurrentAggression = totalAggression
							self.StateMachine.Target = object.Value
							self.StateMachine.Path = Pathfinder.CharacterToCharacter(self.StateMachine.Character, self.StateMachine.Target, true)
							Pathfinder.AttachWalker(self.StateMachine.Character.Humanoid, self.StateMachine.Path)
							self.StateMachine.Character:FindFirstChildOfClass("Humanoid"):MoveTo(self.StateMachine.Path.Waypoints[self.StateMachine.Path.Next].Position)
						end
					else
						self.Aggression[object.Value][timestamp] = nil
					end
				end
			end)
		end
	end)
	self.ChildRemovedConnection = Character.ChildRemoved:Connect(function(object)
		if self.AggressionConnections[object] ~= nil then
			self.AggressionConnections[object]:Disconnect()
		end
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