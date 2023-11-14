--[[
	LadyCelestia 20/10/2023
	Manages different methods of instantiating a PathWrapper
--]]

local Chaser = require(script:WaitForChild("Chaser"))
local Walker = require(script:WaitForChild("Walker"))
local PathWrapper = require(script:WaitForChild("PathWrapper"))

local Pathfinder = {}

Pathfinder.AttachChaser = function(Target, Path)
	if Path.Chaser ~= nil then
		Path.Chaser:Destroy()
	end
	Path.Chaser = Chaser.new(Target, Path)
end

Pathfinder.AttachWalker = function(Humanoid, Path)
	if Path.Walker ~= nil then
		Path.Walker:Destroy()
	end
	Path.Walker = Walker.new(Humanoid, Path)
end

Pathfinder.PartToPoint = function(Part: BasePart, Point: Vector3, Paras: {any}?)
	return PathWrapper.new(Part.Position, Point, Paras)
end

Pathfinder.PointToPoint = function(Start: Vector3, Finish: Vector3, Paras: {any}?)
	return PathWrapper.new(Start, Finish, Paras)
end

Pathfinder.PartToPart = function(Start: BasePart, Finish: BasePart, Paras: {any}?)
	return PathWrapper.new(Start.Position, Finish.Position, Paras)
end

Pathfinder.PointToPart = function(Start: Vector3, Finish: BasePart, Paras: {any}?)
	return PathWrapper.new(Start, Finish.Position, Paras)
end

Pathfinder.CharacterToPoint = function(Char: Model, Point: Vector3, Paras: {any}?)
	local root = Char:FindFirstChild("HumanoidRootPart")
	if root ~= nil then
		return PathWrapper.new(root.Position, Point, Paras)
	end
end

Pathfinder.CharacterToPart = function(Char: Model, Part: BasePart, Chase: boolean, Paras: {any}?)
	local root = Char:FindFirstChild("HumanoidRootPart")
	if root ~= nil then
		local path = PathWrapper.new(root.Position, Part.Position, Paras)
		if Chase == true then
			Pathfinder.AttachChaser(Part, path)
		end
		return path
	end
end

Pathfinder.CharacterToCharacter = function(Char: Model, Target: Model, Chase: boolean, Paras: {any}?)
	local root = Char:FindFirstChild("HumanoidRootPart")
	local targetRoot = Target:FindFirstChild("HumanoidRootPart")
	if root ~= nil and targetRoot ~= nil then
		local path = PathWrapper.new(root.Position, targetRoot.Position, Paras)
		if Chase == true then
			Pathfinder.AttachChaser(targetRoot, path)
		end
		return path
	end
end

return Pathfinder