--[[
    LadyCelestia 7/12/2023
    An always updating list of valid player characters
--]]

local players = game:GetService("Players")
local list = {}

local function isInList(value, list)
	for _,v in pairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

for _,v in ipairs(players:GetPlayers()) do
	if v.Character ~= nil then
		table.insert(list, v.Character)
		local hum = v.Character:FindFirstChildOfClass("Humanoid")
		if hum ~= nil then
			hum.Died:Connect(function()
				for i,v in ipairs(list) do
					if v == v.Character then
						table.remove(list, i)
					end
				end
			end)
		end
	end
	v.CharacterAdded:Connect(function(character)
		table.insert(list, v.Character)
		local hum = character:WaitForChild("Humanoid", 10)
		hum.Died:Connect(function()
			for i,v in ipairs(list) do
				if v == character then
					table.remove(list, i)
				end
			end
		end)
	end)
end

players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		table.insert(list, character)
		local hum = character:WaitForChild("Humanoid", 10)
		hum.Died:Connect(function()
			for i,v in ipairs(list) do
				if v == character then
					table.remove(list, i)
				end
			end
		end)
	end)
end)

return function(excludeList: {Model})
	excludeList = excludeList or {}
	local clone = table.clone(list)
	local cullList = {}
	for i,v in ipairs(clone) do
		if isInList(v, excludeList) == true then
			table.insert(cullList, i)
		end
	end
	--print(clone, cullList, excludeList)
	for i,v in ipairs(cullList) do
		table.remove(clone, v)
		for i2,v2 in ipairs(cullList) do
			if i2 > i and v2 > v then
				cullList[i2] = v2 - 1
			end
		end
	end
	--print(clone)
	return clone
end