--[[
	LadyCelestia 20/10/2023
	Add-on to PathWrapper which allows a Character to automatically walk to the next waypoints
--]]

local function findNearestWaypoint(Point, Waypoints)
	local nearest, dist, index = nil, math.huge, nil
	for i,v in ipairs(Waypoints) do
		local newDist = (v - Point).magnitude
		if newDist < dist then
			nearest, dist, index = v, newDist, i
		end
	end
	return nearest, dist, index
end

local Walker = {}
Walker.__index = Walker

Walker.new = function(Hum: Humanoid, PathWrapper)
	local self = setmetatable({}, Walker)
	
	self.Humanoid = Hum
	if Hum.Parent:FindFirstChild("HumanoidRootPart") ~= nil then
		self.Root = Hum.Parent.HumanoidRootPart
	end
	self.PathWrapper = PathWrapper
	self.ScriptConnection = self.PathWrapper.Changed:Connect(function()
		if self.Root ~= nil then
			local nearest, dist, index = findNearestWaypoint(self.Root.Position, self.PathWrapper.Waypoints)
			if nearest ~= nil and index ~= nil then
				self.Humanoid:MoveTo(self.PathWrapper.Waypoints[index])
				self.PathWrapper.Next = index + 1
			end
		end
	end)
	self.Connection = self.Humanoid.MoveToFinished:Connect(function()
		if #self.PathWrapper.Waypoints >= self.PathWrapper.Next then
			self.Humanoid:MoveTo(self.PathWrapper.Waypoints[self.PathWrapper.Next])
			self.PathWrapper.Next += 1
		else
			self.PathWrapper:Destroy()
		end
	end)
	
	PathWrapper.Walker = self
	return self
end

function Walker:Update(Hum: Humanoid?)
	if typeof(Hum) == "Instance" and Hum:IsA("Humanoid") then
		self.Humanoid = Hum
	end
	if typeof(self.Humanoid) == "Instance" then
		if self.Humanoid.Parent:FindFirstChild("HumanoidRootPart") ~= nil then
			self.Root = self.Humanoid.Parent.HumanoidRootPart
		end
		if self.Humanoid:IsA("Humanoid") then
			self.Humanoid:MoveTo(self.PathWrapper.Waypoints[self.PathWrapper.Next - 1])
		end
	end
end

function Walker:Destroy()
	self.ScriptConnection:Disconnect()
	self.Connection:Disconnect()
	self = {}
end
	
return Walker