--[[
	LadyCelestia 20/10/2023
	Add-on to PathWrapper for updating finish position based on a constantly moving BasePart
--]]

local RunService = game:GetService("RunService")

local Chaser = {}
Chaser.__index = Chaser

Chaser.new = function(Target: BasePart, PathWrapper)
	local self = setmetatable({}, Chaser)
	
	self.PathWrapper = PathWrapper
	self.Target = Target
	self.AutoUpdate = false
	self.AutoUpdateFrames = 10
	self.CurrentFrame = 0
	self.FrameFunction = function()
		self.CurrentFrame += 1
		if self.CurrentFrame >= self.AutoUpdateFrames then
			self.CurrentFrame = 0
			if self.AutoUpdate == true then
				self:Update()
			end
		end
	end
	if RunService:IsServer() == true then
		self.Connection = RunService.Stepped:Connect(self.FrameFunction)
	else
		self.Connection = RunService.RenderStepped:Connect(self.FrameFunction)
	end
	
	PathWrapper.Chaser = self
	return self
end

function Chaser:Update()
	if typeof(self.Target) == "Instance" and self.Target:IsA("BasePart") then
		self.PathWrapper.Finish = self.Target.Position
		self.PathWrapper:Compute()
	end
end

function Chaser:Destroy()
	if typeof(self.Connection) == "RBXScriptConnection" then
		self.Connection:Disconnect()
	end
	self.FrameFunction = nil
	self = {}
end

return Chaser