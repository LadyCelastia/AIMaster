--[[
	LadyCelestia 20/10/2023
	Add-on to PathWrapper which allows a Character to automatically walk to the next waypoints
--]]

local function findNearestWaypoint(Point, Waypoints)
	local nearest, dist, index = nil, math.huge, nil
	for i,v in ipairs(Waypoints) do
		local newDist = (v.Position - Point).magnitude
		if newDist < dist then
			nearest, dist, index = v.Position, newDist, i
		end
	end
	return nearest, dist, index
end

local Walker = {}
Walker.__index = Walker

Walker.new = function(Hum: Humanoid, PathWrapper)
	local self = setmetatable({}, Walker)

	self.Humanoid = Hum
	self.PathWrapper = PathWrapper
	self.Active = true
	self.EpsilonFunction = nil
	self.Connection = self.Humanoid.MoveToFinished:Connect(function(goalReached)
		if goalReached == true then
			if #self.PathWrapper.Waypoints >= self.PathWrapper.Next then
				if self.EpsilonFunction ~= nil and self.EpsilonFunction() == true then
					self.PathWrapper:Destroy()
					return
				end
				self.Humanoid:MoveTo(self.PathWrapper.Waypoints[self.PathWrapper.Next].Position)
				if self.PathWrapper.Waypoints[self.PathWrapper.Next].Action == Enum.PathWaypointAction.Jump then
					self.Humanoid.Jump = true
				end
				self.PathWrapper.Next += 1
			else
				self.PathWrapper:Destroy()
			end
		else
			-- The AI is probably stuck, try to get unstuck
			--game.ReplicatedStorage.Unstuck.Value += 1
			self.PathWrapper:Compute()
			self:Update()
		end
	end)
	PathWrapper.Walker = self
	return self
end

function Walker:Update()
	if typeof(self.Humanoid) == "Instance" and self.Humanoid:IsA("Humanoid") and self.PathWrapper.Waypoints[self.PathWrapper.Next] ~= nil and self.Active == true then
		self.Humanoid:MoveTo(self.PathWrapper.Waypoints[self.PathWrapper.Next - 1].Position)
		local root = self.Humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if root ~= nil and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(self.PathWrapper.Waypoints[self.PathWrapper.Next - 1].Position.X, 0, self.PathWrapper.Waypoints[self.PathWrapper.Next - 1].Position.Z)).Magnitude < 1.5 and math.abs(root.Position.Y - self.PathWrapper.Waypoints[self.PathWrapper.Next - 1].Position.Y) < 5.5 then
			self.Humanoid:MoveTo(root.Position)
		end
	end
end

function Walker:Destroy()
	pcall(function()
		self.Connection:Disconnect()
		self.Connection = nil
	end)
	self.EpsilonFunction = nil
	self.Active = false
	setmetatable(self, nil)
	self.PathWrapper = nil
end

return Walker