--[[
	LadyCelestia 30/10/2023
	Team relations for NPC infighting
--]]

local Teams = {}
Teams.Relations = {
	["Test1"] = {
		["Allies"] = {"Test2"},
		["Enemies"] = {"Test3", "Test4"},
	},
	["Test2"] = {
		["Allies"] = {"Test1"},
		["Enemies"] = {"Test3", "Test4"},
	},
	["Test3"] = {
		["Allies"] = {"Test4"},
		["Enemies"] = {"Test1", "Test2"},
	},
	["Test4"] = {
		["Allies"] = {"Test3"},
		["Enemies"] = {"Test1", "Test2"},
	},
	["Test5"] = {
		["Allies"] = {},
		["Enemies"] = {"Test1", "Test2", "Test3", "Test4"},
	},
}

Teams.GetRelationStatus = function(Team1, Team2) -- 0 = enemies, 1 = neutral, 2 = friendly
	for i,v in pairs(Teams.Relations) do
		if i == Team1 then
			for _,v2 in ipairs(v.Allies) do
				if v2 == Team2 then
					return 2
				end
			end
			for _,v2 in pairs(v.Enemies) do
				if v2 == Team2 then
					return 0
				end
			end
		end
	end
	return 1
end

Teams.GetRelations = function(Team)
	for i,v in pairs(Teams.Relations) do
		if i == Team then
			return v
		end
	end
end

return Teams