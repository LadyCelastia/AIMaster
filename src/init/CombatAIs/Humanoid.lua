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
local Params = RaycastParams.new()
Params.IgnoreWater = true
Params.FilterType = Enum.RaycastFilterType.Exclude
Params:AddToFilter(GetPlayerCharacters())
Params:AddToFilter(CollectionService:GetTagged("AIControlled"))

local function isInList(value, list)
	for _,v in pairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

local function findClosestTarget(origin: Vector3, excludeList: {Model})
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
	return closest, dist
end

local function hasLOS(pos1: Vector3, pos2: Vector3): boolean & RaycastResult
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
				if selfRoot == nil or selfHum == nil or selfHum.Health <= 0 then
					-- Invalid!
					self.StateMachine:Destroy()
				elseif self.StateMachine.State == "Idle" then
					-- Search for a target
					local searchState, excludeList = 0, {}
					-- Search states: 0 = searching, 1 = found successfully, 2 = epsilon transition, 3 = no target
					repeat
						local closest, dist = findClosestTarget(selfRoot.Position, excludeList)
						if closest ~= nil then
							-- There is a valid next closest!
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
									self.StateMachine.State = "Chasing"
									self.StateMachine.Target = closest
									Pathfinder.AttachWalker(selfHum, newPath)
									self.StateMachine.Path = newPath
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
				end
				if self.StateMachine.State == "Idle" then
					-- Search for a target
				    local closest, _ = findClosestTarget(self.StateMachine.Character.HumanoidRootPart.Position)
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