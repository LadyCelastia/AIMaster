--[[
	LadyCelestia 20/10/2023
	Manages different methods of instantiating a PathWrapper
--]]

local Chaser = require(script:WaitForChild("Chaser"))
local Walker = require(script:WaitForChild("Walker"))
local PathWrapper = require(script:WaitForChild("PathWrapper"))

local Pathfinder = {}

Pathfinder.AttachChaser = function(Target, Root, Path)
	if Path.Destroyed ~= true then
		if Path.Chaser ~= nil then
			Path.Chaser:Destroy()
		end
		Path.Chaser = Chaser.new(Target, Root, Path)
	end
	return Path
end

Pathfinder.AttachWalker = function(Humanoid, Path)
	if Path.Destroyed ~= true then
		if Path.Walker ~= nil then
			Path.Walker:Destroy()
		end
		Path.Walker = Walker.new(Humanoid, Path)
	end
	return Path
end

Pathfinder.PartToPoint = function(Part: BasePart, Point: Vector3, Paras: {any}?)
	return PathWrapper.new(Part.Position, Point, Paras or {WaypointSpacing = 10})
end

Pathfinder.PointToPoint = function(Start: Vector3, Finish: Vector3, Paras: {any}?)
	return PathWrapper.new(Start, Finish, Paras or {WaypointSpacing = 10})
end

Pathfinder.PartToPart = function(Start: BasePart, Finish: BasePart, Paras: {any}?)
	return PathWrapper.new(Start.Position, Finish.Position, Paras or {WaypointSpacing = 10})
end

Pathfinder.PointToPart = function(Start: Vector3, Finish: BasePart, Paras: {any}?)
	return PathWrapper.new(Start, Finish.Position, Paras or {WaypointSpacing = 10})
end

Pathfinder.CharacterToPoint = function(Char: Model, Point: Vector3, Paras: {any}?)
	local root = Char:FindFirstChild("HumanoidRootPart")
	if root ~= nil then
		return PathWrapper.new(root.Position, Point, Paras or {WaypointSpacing = 10})
	end
end

Pathfinder.CharacterToPart = function(Char: Model, Part: BasePart, Chase: boolean, Paras: {any}?)
	local root = Char:FindFirstChild("HumanoidRootPart")
	if root ~= nil then
		local path = PathWrapper.new(root.Position, Part.Position, Paras or {WaypointSpacing = 10})
		if Chase == true then
			path = Pathfinder.AttachChaser(Part, root, path)
		end
		return path
	end
end

Pathfinder.CharacterToCharacter = function(Char: Model, Target: Model, Chase: boolean, Paras: {any}?)
	local root = Char:FindFirstChild("HumanoidRootPart")
	local targetRoot = Target:FindFirstChild("HumanoidRootPart")
	if root ~= nil and targetRoot ~= nil then
		local path = PathWrapper.new(root.Position, targetRoot.Position, Paras or {WaypointSpacing = 10})
		if Chase == true then
			path = Pathfinder.AttachChaser(targetRoot, root, path)
		end
		return path
	end
end

return Pathfinder