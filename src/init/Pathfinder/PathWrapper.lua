--[[
	LadyCelestia 20/10/2023
	Wrapper for Path object
--]]

local PathfindingService = game:GetService("PathfindingService")

local PathWrapper = {}
PathWrapper.__index = PathWrapper

PathWrapper.new = function(start: Vector3, finish: Vector3, paras: {any}?)
	local self = setmetatable({}, PathWrapper)
	self.Path = PathfindingService:CreatePath(paras)
	self.Next = 2
	self.Start = start
	self.Finish = finish
	self.Active = true
	self.Destroyed = false
	--self._ThisColor = BrickColor.Random()
	self.Waypoints = {}
	self:Compute()
	if self.Path.Status == Enum.PathStatus.Success then
		self.Waypoints = self.Path:GetWaypoints()
	end
	--print("returning path")
	return self, self.Path.Status
end

function PathWrapper:Update()
	if self.Path.Status == Enum.PathStatus.Success then
		self.Waypoints = self.Path:GetWaypoints()
		if self.Walker ~= nil then
			self.Walker:Update()
		end
		-- waypoint visualization for testing
		--[[
		for _,v: BasePart in ipairs(workspace.Waypoints:GetChildren()) do
			if v.BrickColor == self._ThisColor then
				v:Destroy()
			end
		end
		for _,v: PathWaypoint in ipairs(self.Waypoints) do
			local newWaypoint = Instance.new("Part")
			newWaypoint.Shape = Enum.PartType.Ball
			newWaypoint.Material = Enum.Material.Neon
			newWaypoint.Size = Vector3.new(1, 1, 1)
			newWaypoint.BrickColor = self._ThisColor
			newWaypoint.Position = v.Position
			newWaypoint.CanCollide = false
			newWaypoint.Anchored = true
			newWaypoint.Parent = workspace.Waypoints
		end
		--]]
	else
		self.Waypoints = {}
	end
end

function PathWrapper:Compute()
	--game.ReplicatedStorage.Total.Value += 1
	if self.Destroyed ~= true then
		--[[
		self.Blocked = self.Path.Blocked:Connect(function(index)
			if index >= self.Next then
				self.Blocked:Disconnect()
				self:Compute()
			end
		end)
		--]]
		self.Path:ComputeAsync(self.Start, self.Finish)
		if self.Path.Status == Enum.PathStatus.NoPath or self.Path.Status == Enum.PathStatus.FailStartNotEmpty or self.Path.Status == Enum.PathStatus.FailFinishNotEmpty then
			--print("path not success!! ", self.Path.Status)
			self:Destroy()
		else
			--print("updating path")
			self:Update()
			self.Next = 2
		end
	else
		if typeof(self.Blocked) == "RBXScriptConnection" then
			self.Blocked:Disconnect()
			self.Blocked = nil
		end
		pcall(function()
			self.Chaser.PathWrapper = nil
			self.Chaser:Destroy()
			self.Chaser = nil
		end)
		pcall(function()
			self.Walker.PathWrapper = nil
			self.Walker:Destroy()
			self.Walker = nil
		end)
		setmetatable(self, nil)
		self.Active = false
		self.Destroyed = true
	end
end

function PathWrapper:Destroy()
	--[[
	if typeof(self.Blocked) == "RBXScriptConnection" then
		self.Blocked:Disconnect()
		self.Blocked = nil
	end
	--]]
	pcall(function()
		self.Chaser.PathWrapper = nil
		self.Chaser:Destroy()
		self.Chaser = nil
	end)
	pcall(function()
		self.Walker.PathWrapper = nil
		self.Walker:Destroy()
		self.Walker = nil
	end)
	-- waypoint visualization for testing
	--[[
	for _,v: BasePart in ipairs(workspace.Waypoints:GetChildren()) do
		if v.BrickColor == self._ThisColor then
			v:Destroy()
		end
	end
	--]]
	setmetatable(self, nil)
	self.Start = nil
	self.Finish = nil
	self.Active = false
	self.Destroyed = true
end

return PathWrapper