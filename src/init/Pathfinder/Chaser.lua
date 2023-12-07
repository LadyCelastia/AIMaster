--[[
	LadyCelestia 20/10/2023
	Add-on to PathWrapper for updating finish position based on a constantly moving BasePart
--]]

local RunService = game:GetService("RunService")

local Chaser = {}
Chaser.__index = Chaser

Chaser.new = function(Target: BasePart, Start: BasePart, PathWrapper)
	local self = setmetatable({}, Chaser)
	self.PathWrapper = PathWrapper
	self.Target = Target
	self.Start = Start
	self.Active = true
	self.AutoUpdate = true
	self.AutoUpdateFrames = 60
	self.CurrentFrame = 0
	if RunService:IsServer() == true then
		self.Connection = RunService.Heartbeat:Connect(function()
			self:FrameFunction()
		end)
	else
		self.Connection = RunService.RenderStepped:Connect(function()
			self:FrameFunction()
		end)
	end
	PathWrapper.Chaser = self
	return self
end

function Chaser:FrameFunction()
	self.CurrentFrame += 1
	if self.CurrentFrame >= self.AutoUpdateFrames then
		self.CurrentFrame = 0
		if self.AutoUpdate == true then
			self:Update()
		end
	end
end

function Chaser:Update()
	if typeof(self.Target) == "Instance" and self.Target:IsA("BasePart") and self.PathWrapper.Finish ~= self.Target.Position and self.Active == true then
		if self.Start.Parent == nil or self.Target.Parent == nil then
			-- Garbage collect safety net
			local success, _ = pcall(function()
				self.PathWrapper:Destroy()
			end)
			if success ~= true then
				pcall(function()
					self:Destroy()
				end)
			end
		else
			self.PathWrapper.Finish = self.Target.Position
			self.PathWrapper.Start = self.Start.Position
			if self.PathWrapper.Destroyed ~= true then
				local success, _ = pcall(function()
					self.PathWrapper:Compute()
				end)
				if success ~= true then
					local success, _ = pcall(function()
						self.PathWrapper:Destroy()
					end)
					if success ~= true then
						pcall(function()
							self:Destroy()
						end)
					end
				end
			else
				self:Destroy()
			end
			--game.ReplicatedStorage.Chaser.Value += 1
		end

	end
end

function Chaser:Destroy()
	pcall(function()
		self.Connection:Disconnect()
	end)
	self.Start = nil
	self.Target = nil
	self.AutoUpdate = false
	self.Active = false
	self.Destroyed = true
	self.FrameFunction = nil
	setmetatable(self, nil)
	self.PathWrapper = nil
end

return Chaser