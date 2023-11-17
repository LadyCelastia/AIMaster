--[[
	LadyCelestia 20/10/2023
	Wrapper for Path object
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ScriptSignal = require(Modules:WaitForChild("ScriptSignal"))
local PathfindingService = game:GetService("PathfindingService")

local PathWrapper = {}
PathWrapper.__index = PathWrapper

PathWrapper.new = function(start: Vector3, finish: Vector3, paras: {any}?)
	local self = setmetatable({}, PathWrapper)
	self.Path = PathfindingService:CreatePath(paras)
	self.Next = 2
	self.Start = start
	self.Finish = finish
	self.Waypoints = {}
	self.Changed = ScriptSignal.new()
	self:Compute()
	if self.Path.Status == Enum.PathStatus.Success then
		self.Waypoints = self.Path:GetWaypoints()
	end
	return self, self.Path.Status
end

function PathWrapper:Update()
	if self.Path.Status == Enum.PathStatus.Success then
		self.Waypoints = self.Path:GetWaypoints()
	else
		self.Waypoints = {}
	end
	self.Changed:Fire()
end

function PathWrapper:Compute()
	self.Blocked = self.Path.Blocked:Connect(function(index)
		if index >= self.Next then
			self.Blocked:Disconnect()
			self.Compute()
		end
	end)
	self.Path:ComputeAsync(self.Start, self.Finish)
	self:Update()
	self.Next = 2
end

function PathWrapper:Destroy()
	if typeof(self.Blocked) == "RBXScriptConnection" then
		self.Blocked:Disconnect()
	end
	if self.Chaser ~= nil then
		self.Chaser:Destroy()
	end
	if self.Walker ~= nil then
		self.Walker:Destroy()
	end
	self = {}
end

return PathWrapper