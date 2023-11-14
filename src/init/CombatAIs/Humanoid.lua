local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local HumanoidAI = {}
HumanoidAI.__index = HumanoidAI

HumanoidAI.new = function(Character: Model)
	local self = setmetatable({}, HumanoidAI)
	
	self.StateMachine = nil
	self.Active = false
	self.Frames = 12 -- how many frames per update
	self.CurrentFrame = 0
	self.Aggression = {}
	self.AggressionConnections = {}
	self.CurrentAggression = 0
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
							self.CurrentAggression = totalAggression
							self.StateMachine.Target = object.Value
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
				local newTarget = false
				if self.StateMachine.Target == nil then
					newTarget = true
				else
					local root = self.StateMachine.Target:FindFirstChild("HumanoidRootPart")
					if root == nil then
						newTarget = true
					elseif (self.StateMachine.Character.HumanoidRootPart.Position - root.Position).magnitude >= self.StateMachine.AggroRange * 2 then
						newTarget = true
					end
				end
				if newTarget == true then
					local closest, dist = nil, math.huge
					for _,v in ipairs(Players:GetPlayers()) do
						if v.Character ~= nil then
							local root = v.Character:FindFirstChild("HumanoidRootPart")
							if root ~= nil then
								if closest ~= nil then
									local newDist = (root.Position - self.StateMachine.Character.HumanoidRootPart).magnitude
									if newDist < dist then
										dist = newDist
									end
								else
									closest = root.Parent
									dist = (root.Position - self.StateMachine.Character.HumanoidRootPart).magnitude
								end
							end
						end
					end
					self.StateMachine.Target = closest
				end
			elseif self.StateMachine ~= nil and self.StateMachine.Character == nil then
				self.StateMachine:Destroy()
				return
			end
			if self.StateMachine.Target ~= nil then
				local targetRoot = self.StateMachine.Target:FindFirstChild("HumanoidRootPart")
				
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