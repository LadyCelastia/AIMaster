--[[
    LadyCelestia 7/12/2023
    An always updating list of valid player characters
--]]

local players = game:GetService("Players")
local list = {}

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

return function()
    return list
end