local actionCosts = {
    Humanoid = {},
}

return function(command, args)
    if command == "GetActionCosts" then
        return actionCosts[args] or {}
    end
end