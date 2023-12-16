--[[
	LadyCelestia 3/11/2023
	Main AI for humanoid characters
--]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Teams = require(script.Parent.Parent:WaitForChild("Teams"))
local Players = game:GetService("Players")
local Pathfinder = require(script.Parent.Parent:WaitForChild("Pathfinder"))
local GetPlayerCharacters = require(script.Parent.Parent:WaitForChild("PlayerCharacterList"))
local Params = RaycastParams.new()
Params.IgnoreWater = true
Params.FilterType = Enum.RaycastFilterType.Exclude
Params:AddToFilter(GetPlayerCharacters())
Params:AddToFilter(CollectionService:GetTagged("AIControlled"))
local GetConfigs = require(script.Parent.Parent:WaitForChild("Configs"))
local ActionCosts = GetConfigs("GetActionCosts", "NormalZombie")

local function isInList(value, list)
	for _,v in pairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

local function findClosestTarget(origin: Vector3, excludeList: {Model}, Range: number)
	Range = Range or math.huge
	excludeList = excludeList or {}
	local targets = GetPlayerCharacters(excludeList)
	for _,v in ipairs(CollectionService:GetTagged("AIControlled")) do
		local hum = v:FindFirstChildOfClass("Humanoid")
		if hum ~= nil and hum.Health > 0 and v:FindFirstChild("HumanoidRootPart") ~= nil and isInList(v, excludeList) == false then
			table.insert(targets, v)
		end
	end
	local closest, dist = nil, math.huge
	for _,v in ipairs(targets) do
		local newDist = (origin - v.HumanoidRootPart.Position).magnitude
		if newDist < dist then
			closest = v
			dist = newDist
		end
	end
	if dist <= Range then
		return closest, dist
	end
	return nil
end

local function hasLOS(pos1: Vector3, pos2: Vector3): boolean & RaycastResult
	Params.FilterDescendantsInstances = CollectionService:GetTagged("AIControlled")
	Params:AddToFilter(GetPlayerCharacters())
	local result = workspace:Raycast(pos1, (pos2 - pos1).Unit, Params)
	return (result ~= nil), result
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
	self.PersistentFrames = self.Frames
	self.DashAmount = 0
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
			object.Name = timestamp
		end
	end)
	self.ChildRemovedConnection = Character.ChildRemoved:Connect(function(object)
		if object:IsA("ObjectValue") and self.Aggression[object.Value] ~= nil then
			self.Aggression[object.Value][tonumber(object.Name)] = nil
		end
	end)
	self.Connection = RunService.Stepped:Connect(function()
		self.CurrentFrame += 1
		if self.CurrentFrame >= self.Frames then
			self.CurrentFrame = 0
			if self.StateMachine ~= nil and self.StateMachine.Character ~= nil and self.Active == true then
				local selfRoot = self.StateMachine.Character:FindFirstChild("HumanoidRootPart")
				local selfHum = self.StateMachine.Character:FindFirstChildOfClass("Humanoid")
				if selfRoot == nil or selfHum == nil or selfHum.Health <= 0 or self.StateMachine.Character.Parent == nil then
					-- Invalid character! Destroy right now!
					self.StateMachine:Destroy()
				elseif self.StateMachine.State == "Idle" then
					-- Search for a target
					local searchState, excludeList = 0, {}
					-- Search states: 0 = searching, 1 = found successfully, 2 = epsilon transition, 3 = no target
					repeat
						local closest, dist = findClosestTarget(selfRoot.Position, excludeList, self.StateMachine.AggroRange)
						if closest ~= nil then
							-- There is a valid next closest!
							local targetRoot = closest:FindFirstChild("HumanoidRootPart")
							if dist < 4.5 then
								-- Close enough for close combat!
								self.StateMachine.State = "CloseCombat"
								self.StateMachine.Target = closest
								selfHum:MoveTo(selfRoot.Position)
								searchState = 2
							elseif hasLOS(selfRoot.Position, closest.HumanoidRootPart.Position) == true then
								-- Has line of sight! Enter dash
								self.StateMachine.State = "Dash"
								selfHum:MoveTo(closest.HumanoidRootPart.Position)
								searchState = 2
							else
								-- Try to pathfind
								local newPath = Pathfinder.CharacterToCharacter(self.StateMachine.Character, closest, true)
								if newPath.Destroyed == false then
									-- Has a path!
									self.StateMachine.Path = newPath
									self.StateMachine.State = "Chasing"
									self.StateMachine.Target = closest
									Pathfinder.AttachWalker(selfHum, newPath)
									newPath.Walker.EpsilonFunction = function()
										if hasLOS(selfRoot, targetRoot) == true and math.abs(selfRoot.Position.Y - targetRoot.Position.Y) < 5 then
											self.StateMachine.State = "Dash"
											self.Frames = 6
											self.CurrentFrame = 0
											selfHum:MoveTo(targetRoot.Position)
											return true
										end
										return false
									end
									self.StateMachine.Path:Update()
									searchState = 1
								else
									-- Does not have a path!
									table.insert(excludeList, closest)
								end
							end

						else
							-- There is no next closest
							searchState = 3
						end
					until searchState ~= 0
					if searchState == 2 then
						selfHum:MoveTo(selfRoot.Position)
					end
				
				elseif self.StateMachine.State == "Chasing" then
					if self.StateMachine.Target == nil then
						-- The target might have left the game! Reset immediately
						self.StateMachine.State = "Idle"
						if self.StateMachine.Path ~= nil then
							pcall(function()
								self.StateMachine.Path:Destroy()
							end)
							self.StateMachine.Path = nil
						end
						selfHum:MoveTo(selfRoot.Position)
						return
					end
					local reset = false
					local targetRoot: BasePart = self.StateMachine.Target:FindFirstChild("HumanoidRootPart")
					local targetHum = self.StateMachine.Target:FindFirstChildOfClass("Humanoid")
					local closest, dist = findClosestTarget(selfRoot.Position, {}, self.StateMachine.AggroRange)
					if closest ~= self.StateMachine.Target and closest ~= nil then
						-- Target is no longer the closest! Select a new target
						self.StateMachine.Target = closest
						targetRoot = self.StateMachine.Target:FindFirstChild("HumanoidRootPart")
						if self.StateMachine.Path ~= nil then
							pcall(function()
								self.StateMachine.Path:Destroy()
							end)
							self.StateMachine.Path = nil
						end
						self.Path = Pathfinder.CharacterToCharacter(self.StateMachine.Character, closest, true, {
							WaypointSpacing = 100,
							AgentCanClimb = true,
							Costs = ActionCosts
						})
						if self.StateMachine.Path.Waypoints[self.StateMachine.Path.Next] ~= nil then
							self.StateMachine.Path = Pathfinder.AttachWalker(selfHum, self.StateMachine.Path)
							self.StateMachine.Path.Walker.EpsilonFunction = function()
								if hasLOS(selfRoot.Position, targetRoot.Position) == true and math.abs(selfRoot.Position.Y - targetRoot.Position.Y) < 5 then
									return true
								end
								return false
							end
							selfHum:MoveTo(self.StateMachine.Path.Waypoints[self.StateMachine.Path.Next].Position)
							if self.StateMachine.Path.Waypoints[self.StateMachine.Path.Next].Action == Enum.PathWaypointAction.Jump then
								self.Humanoid.Jump = true
							end
							self.StateMachine.Path.Next += 1
						elseif targetRoot ~= nil then
							selfHum:MoveTo(targetRoot.Position)
						end
					elseif closest ~= nil then
						-- Target is still the closest
						Params.FilterDescendantsInstances = GetPlayerCharacters()
						local AIArray = CollectionService:GetTagged("AIControlled")
						if #AIArray > 0 then
							Params:AddToFilter(AIArray)
						end
						Params:AddToFilter(self.StateMachine.Character)
						if targetRoot == nil or targetHum == nil or targetHum.Health <= 0 or self.StateMachine.Path.Waypoints[self.StateMachine.Path.Next - 1] == nil then
							-- Target is dead or invalid path
							reset = true
						elseif (targetRoot.Position - selfRoot.Position).Magnitude <= 3 then
							-- Close enough, enter close combat!
							self.StateMachine.State = "CloseCombat"
							selfHum:MoveTo(selfRoot.Position)
						elseif self.StateMachine.Path == nil or self.StateMachine.Path.Active == false then
							-- Path is dead!
							if hasLOS(selfRoot.Position, targetRoot.Position) == true and math.abs(selfRoot.Position.Y - targetRoot.Position.Y) < 5 then
								-- Has LOS, enter dash
								self.StateMachine.State = "Dash"
								self.Frames = 6
								selfHum:MoveTo(targetRoot.Position + (targetRoot.CFrame.LookVector * 4))
							else
								reset = true
							end
						end
						-- Obstacle avoidance
						local frontRay = workspace:Raycast(selfRoot.Position - Vector3.new(0, 1, 0), selfRoot.CFrame.LookVector * 2.5, Params)
						if frontRay ~= nil and not frontRay.Instance:IsA("TrussPart") then
							selfHum.Jump = true
						end
					end

					if reset ~= true and self.StateMachine.Path ~= nil then
						if hasLOS(selfRoot.Position, targetRoot).Position == true and math.abs(selfRoot.Position.Y - targetRoot.Position.Y) < 5 then
							-- Has LOS, enter dash
							--game.ReplicatedStorage.ToDash.Value += 1
							self.StateMachine.State = "Dash"
							self.Frames = 6
							selfHum:MoveTo(targetRoot.Position + (targetRoot.CFrame.LookVector * 4))
						elseif self.Path.Walker == nil then
							-- The path is dead!
							self.StateMachine.Path = nil
						else
							self.StateMachine.Path.Walker:Update()
						end
					elseif reset == true then
						self.StateMachine.State = "Idle"
						pcall(function()
							self.StateMachine.Path:Destroy()
						end)
						self.StateMachine.Path = nil
						selfHum:MoveTo(selfRoot.Position)
					end
				
				elseif self.StateMachine.State == "Dash" then
					local reset = false
					local targetRoot: BasePart = self.StateMachine.Target:FindFirstChild("HumanoidRootPart")
					local targetHum = self.StateMachine.Target:FindFirstChildOfClass("Humanoid")
					if targetRoot == nil or targetHum == nil or targetHum.Health <= 0 then
						reset = true
					else
						if hasLOS(selfRoot.Position, targetRoot.Position) == true then
							selfHum:MoveTo(targetRoot.Position + (targetRoot.CFrame.LookVector * 4))
							self.DashAmount += 1
							if self.DashAmount >= 10 then
								self.DashAmount = 0
								local frontRay = workspace:Raycast(selfRoot.Position - Vector3.new(0, 1, 0), selfRoot.CFrame.LookVector * 2.5, Params)
								if frontRay ~= nil and not frontRay.Instance:IsA("TrussPart") then
									selfHum.Jump = true
								end
							end
							if (targetRoot.Position - selfRoot.Position).magnitude <= 4.5 and math.abs(selfRoot.Position.Y - targetRoot.Position.Y) <= 3.8 then
								self.StateMachine.State = "CloseCombat"
								self.Frames = self.PersistentFrames
								self.DashAmount = 0
								selfHum:MoveTo(selfRoot.Position)
							end
						else
							reset = true
						end
					end
					if reset == true then
						self.StateMachine.State = "Idle"
						self.Frames = self.PersistentFrames
						self.DashAmount = 0
						selfHum:MoveTo(selfRoot.Position)
					end
				
				elseif self.StateMachine.State == "CloseCombat" then
					print("in close combat")

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