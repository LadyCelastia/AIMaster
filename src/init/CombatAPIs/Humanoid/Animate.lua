-- humanoidAnimatePlayEmote.lua

repeat task.wait(.2)
until script.Parent:IsA("Model")
local Figure = script.Parent
local Torso = Figure:WaitForChild("Torso")
local RightShoulder = Torso:WaitForChild("Right Shoulder")
local LeftShoulder = Torso:WaitForChild("Left Shoulder")
local RightHip = Torso:WaitForChild("Right Hip")
local LeftHip = Torso:WaitForChild("Left Hip")
local Neck = Torso:WaitForChild("Neck")
local Humanoid = Figure:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")
local CharacterStats : Folder = Figure:WaitForChild("CharacterStats")
local Sprinting = CharacterStats:WaitForChild("Sprinting")
local pose = "Standing"

local EMOTE_TRANSITION_TIME = 0.1

local userAnimateScaleRunSuccess, userAnimateScaleRunValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserAnimateScaleRun") end)
local userAnimateScaleRun = userAnimateScaleRunSuccess and userAnimateScaleRunValue

local function getRigScale()
	if userAnimateScaleRun then
		return Figure:GetScale()
	else
		return 1
	end
end

local currentAnim = ""
local currentAnimInstance: Animation = nil
local currentAnimTrack: AnimationTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0
local currentRunningSpeed = 16
local animTable = {}
local animNames = { 
	idle = 	{	
		{ id = "rbxassetid://14882355340", weight = 9 },
		{ id = "rbxassetid://14882355340", weight = 1 }
	},
	walk = 	{ 	
		{ id = "rbxassetid://14882346559", weight = 10 } 
	}, 
	run = 	{
		{ id = "rbxassetid://14882336965", weight = 10 } 
	}, 
	jump = 	{
		{ id = "http://www.roblox.com/asset/?id=125750702", weight = 10 } 
	}, 
	fall = 	{
		{ id = "http://www.roblox.com/asset/?id=180436148", weight = 10 } 
	}, 
	climb = {
		{ id = "http://www.roblox.com/asset/?id=180436334", weight = 10 } 
	}, 
	sit = 	{
		{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 } 
	},	
	wave = {
		{ id = "http://www.roblox.com/asset/?id=128777973", weight = 10 } 
	},
	point = {
		{ id = "http://www.roblox.com/asset/?id=128853357", weight = 10 } 
	},
	dance1 = {
		{ id = "http://www.roblox.com/asset/?id=182435998", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=182491037", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=182491065", weight = 10 } 
	},
	dance2 = {
		{ id = "http://www.roblox.com/asset/?id=182436842", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=182491248", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=182491277", weight = 10 } 
	},
	dance3 = {
		{ id = "http://www.roblox.com/asset/?id=182436935", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=182491368", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=182491423", weight = 10 } 
	},
	laugh = {
		{ id = "http://www.roblox.com/asset/?id=129423131", weight = 10 } 
	},
	cheer = {
		{ id = "http://www.roblox.com/asset/?id=129423030", weight = 10 } 
	},
}
local dances = {"dance1", "dance2", "dance3"}

-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
local emoteNames = { wave = false, point = false, dance1 = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

local function configureAnimationSet(name, fileList)
	if (animTable[name] ~= nil) then
		for _, connection in pairs(animTable[name].connections) do
			if typeof(connection) == "RBXScriptConnection" then
				connection:Disconnect()
			end
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0	
	animTable[name].connections = {}

	-- check for config values
	local config = script:FindFirstChild(name)
	if (config ~= nil) then
		--		print("Loading anims " .. name)
		table.insert(animTable[name].connections, config.ChildAdded:Connect(function(child) configureAnimationSet(name, fileList) end))
		table.insert(animTable[name].connections, config.ChildRemoved:Connect(function(child) configureAnimationSet(name, fileList) end))
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			if (childPart:IsA("Animation")) then
				table.insert(animTable[name].connections, childPart.Changed:Connect(function(property) configureAnimationSet(name, fileList) end))
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				local weightObject = childPart:FindFirstChild("Weight")
				if (weightObject == nil) then
					animTable[name][idx].weight = 1
				else
					animTable[name][idx].weight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
				--			print(name .. " [" .. idx .. "] " .. animTable[name][idx].anim.AnimationId .. " (" .. animTable[name][idx].weight .. ")")
				idx = idx + 1
			end
		end
	end

	-- fallback to defaults
	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
			--			print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")
		end
	end
end

-- Setup animation objects
local function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end	
end

script.ChildAdded:Connect(scriptChildModified)
script.ChildRemoved:Connect(scriptChildModified)

-- Clear any existing animation tracks
-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
if animator then
	local animTracks = animator:GetPlayingAnimationTracks()
	for i,track in ipairs(animTracks) do
		track:Stop(0)
		track:Destroy()
	end
end


for name, fileList in pairs(animNames) do 
	configureAnimationSet(name, fileList)
end	

-- ANIMATION

-- declarations
local toolAnim = "None"
local toolAnimTime = 0

local jumpAnimTime = 0
local jumpAnimDuration = 0.3

local toolTransitionTime = 0.1
local fallTransitionTime = 0.3
local jumpMaxLimbVelocity = 0.75

-- functions

local function stopAllAnimations()
	local oldAnim = currentAnim

	-- return to idle if finishing an emote
	if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
		oldAnim = "idle"
	end

	currentAnim = ""
	currentAnimInstance = nil
	if (currentAnimKeyframeHandler ~= nil) then
		currentAnimKeyframeHandler:Disconnect()
	end

	if (currentAnimTrack ~= nil) then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end

	for _,v in ipairs(Animator:GetPlayingAnimationTracks()) do
		v:Stop()
	end

	return oldAnim
end

local function stopSpecificAnimation(name)
	if currentAnimInstance == nil or currentAnimInstance.Name == name then
		currentAnim = ""
		currentAnimInstance = nil
		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:Disconnect()
		end
		if (currentAnimTrack ~= nil) then
			currentAnimTrack:Stop()
			currentAnimTrack:Destroy()
			currentAnimTrack = nil
		end
	end

	for _,v in ipairs(Animator:GetPlayingAnimationTracks()) do
		if v.Animation == nil or v.Animation.Name == name then
			v:Stop()
		end
	end
end

local function setAnimationSpeed(speed)
	if speed ~= currentAnimSpeed then
		currentAnimSpeed = speed
		currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		--[[
		if currentAnimTrack.Animation.Name == "RunAnim" then
			task.spawn(function()
				error(currentAnimTrack.Animation.Name .. " " .. currentAnimTrack.Speed, 0)
			end)
		end
		--]]
	end
end

local keyFrameReachedFunc

-- Preload animations
local function playAnimation(animName, transitionTime, humanoid) 
	local roll = math.random(1, animTable[animName].totalWeight) 
	local origRoll = roll
	local idx = 1
	while (roll > animTable[animName][idx].weight) do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
	--		print(animName .. " " .. idx .. " [" .. origRoll .. "]")
	local anim = animTable[animName][idx].anim

	-- switch animation		
	if (anim ~= currentAnimInstance) and (currentAnimInstance == nil or not (anim.Parent.Name == "jump" and (currentAnimInstance.Parent.Name == "walk" or currentAnimInstance.Parent.Name == "run"))) then
		--[[
		if currentAnimInstance ~= nil then
			print(currentAnimInstance.Parent.Name .. " " .. anim.Parent.Name)
		end
		--]]
		--((anim.Parent.Name ~= "jump" or (currentAnimInstance.Parent.Name ~= "walk" and currentAnimInstance.Parent.Name ~= "run")) or (anim.Parent.Name == "run" and currentAnimInstance.Parent.Name == "walk") or (anim.Parent.Name == "walk" and currentAnimInstance.Parent.Name == "run"))
		if (currentAnimTrack ~= nil) then
			--print("stopping track")
			currentAnimTrack:Stop(transitionTime)
			currentAnimTrack:Destroy()
		end

		currentAnimSpeed = 1.0

		-- load it to the humanoid; get AnimationTrack
		currentAnimTrack = humanoid.Animator:LoadAnimation(anim)

		-- play the animation
		currentAnim = animName
		currentAnimInstance = anim
		if currentAnimInstance.Parent.Name == "run" or currentAnimInstance.Parent.Name == "walk" then
			currentAnimTrack.Priority = Enum.AnimationPriority.Movement
		elseif currentAnimInstance.Parent.Name == "idle" then
			currentAnimTrack.Priority = Enum.AnimationPriority.Idle
		else
			currentAnimTrack.Priority = Enum.AnimationPriority.Core
		end
		--print("playing " .. currentAnimInstance.Parent.Name .. " priority " .. tostring(currentAnimTrack.Priority))
		currentAnimTrack:Play(transitionTime)

		-- set up keyframe name triggers
		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:Disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:Connect(keyFrameReachedFunc)

		--print(currentAnimTrack.Animation.Name, currentAnimTrack.Speed)
	end

end

keyFrameReachedFunc = function(frameName)
	if (frameName == "End") then

		local repeatAnim = currentAnim
		-- return to idle if finishing an emote
		if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
			repeatAnim = "idle"
		end

		local animSpeed = currentAnimSpeed
		playAnimation(repeatAnim, 0.0, Humanoid)
		setAnimationSpeed(animSpeed)
	end
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

local toolAnimName = ""
local toolAnimTrack = nil
local toolAnimInstance = nil
local currentToolAnimKeyframeHandler = nil

local toolKeyFrameReachedFunc


local function playToolAnimation(animName, transitionTime, humanoid, priority)	 
		--[[
		local roll = math.random(1, animTable[animName].totalWeight) 
		local origRoll = roll
		local idx = 1
		while (roll > animTable[animName][idx].weight) do
			roll = roll - animTable[animName][idx].weight
			idx = idx + 1
		end
--		print(animName .. " * " .. idx .. " [" .. origRoll .. "]")
		local anim = animTable[animName][idx].anim

		if (toolAnimInstance ~= anim) then
			
			if (toolAnimTrack ~= nil) then
				toolAnimTrack:Stop()
				toolAnimTrack:Destroy()
				transitionTime = 0
			end
					
			-- load it to the humanoid; get AnimationTrack
			toolAnimTrack = humanoid:LoadAnimation(anim)
			if priority then
				toolAnimTrack.Priority = priority
			end
			 
			-- play the animation
			toolAnimTrack:Play(transitionTime)
			toolAnimName = animName
			toolAnimInstance = anim

			currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:Connect(toolKeyFrameReachedFunc)
		end
		--]]
end


toolKeyFrameReachedFunc = function(frameName)
	if (frameName == "End") then
		--		print("Keyframe : ".. frameName)	
		--playToolAnimation(toolAnimName, 0.0, Humanoid)
	end
end

local function stopToolAnimations()
	local oldAnim = toolAnimName

	if (currentToolAnimKeyframeHandler ~= nil) then
		currentToolAnimKeyframeHandler:Disconnect()
	end

	toolAnimName = ""
	toolAnimInstance = nil
	if (toolAnimTrack ~= nil) then
		toolAnimTrack:Stop()
		toolAnimTrack:Destroy()
		toolAnimTrack = nil
	end


	return oldAnim
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------


local function onRunning(speed)
	speed /= getRigScale()
	currentRunningSpeed = speed

	if speed > 0.01 then
		if Sprinting.Value == true then
			stopSpecificAnimation("Walk")
			stopSpecificAnimation("WalkAnim")
			stopSpecificAnimation("Run")
			stopSpecificAnimation("RunAnim")
			stopSpecificAnimation("Idle")
			stopSpecificAnimation("Idle1")
			stopSpecificAnimation("Idle2")
			playAnimation("run", 0.1, Humanoid)
			if currentAnimInstance and currentAnimInstance.Name ~= "Run" then
				if currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
					setAnimationSpeed(speed / 14.5)
				elseif currentAnimInstance.AnimationId == "rbxassetid://14789825228" then
					setAnimationSpeed((speed - 8) / 14.5)
				end
			end
			pose = "Sprinting"
		else
			stopSpecificAnimation("Walk")
			stopSpecificAnimation("WalkAnim")
			stopSpecificAnimation("Run")
			stopSpecificAnimation("RunAnim")
			stopSpecificAnimation("Idle")
			stopSpecificAnimation("Idle1")
			stopSpecificAnimation("Idle2")
			playAnimation("walk", 0.1, Humanoid)
			if currentAnimInstance and currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
				setAnimationSpeed(speed / 14.5)
			end
			pose = "Running"
		end
	else
		if emoteNames[currentAnim] == nil then
			stopSpecificAnimation("Walk")
			stopSpecificAnimation("WalkAnim")
			stopSpecificAnimation("Run")
			stopSpecificAnimation("RunAnim")
			stopSpecificAnimation("Idle")
			stopSpecificAnimation("Idle1")
			stopSpecificAnimation("Idle2")
			playAnimation("idle", 0.1, Humanoid)
			pose = "Standing"
		end
	end
end

local function onDied()
	pose = "Dead"
end

local function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

local function onClimbing(speed)
	speed /= getRigScale()

	playAnimation("climb", 0.1, Humanoid)
	setAnimationSpeed(speed / 12.0)
	pose = "Climbing"
end

local function onGettingUp()
	pose = "GettingUp"
end

local function onFreeFall()
	if (jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	end
	pose = "FreeFall"
end

local function onFallingDown()
	pose = "FallingDown"
end

local function onSeated()
	pose = "Seated"
end

local function onPlatformStanding()
	pose = "PlatformStanding"
end

local function onSwimming(speed)
	if speed > 0 then
		pose = "Running"
	else
		pose = "Standing"
	end
end

local function getTool()	
	for _, kid in ipairs(Figure:GetChildren()) do
		if kid.className == "Tool" then return kid end
	end
	return nil
end

local function getToolAnim(tool)
	for _, c in ipairs(tool:GetChildren()) do
		if c.Name == "toolanim" and c.className == "StringValue" then
			return c
		end
	end
	return nil
end

local function animateTool()
	--[[
	if (toolAnim == "None") then
		playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
		return
	end

	if (toolAnim == "Slash") then
		playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end

	if (toolAnim == "Lunge") then
		playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end
	--]]
end

local function moveSit()
	RightShoulder.MaxVelocity = 0.15
	LeftShoulder.MaxVelocity = 0.15
	RightShoulder:SetDesiredAngle(3.14 /2)
	LeftShoulder:SetDesiredAngle(-3.14 /2)
	RightHip:SetDesiredAngle(3.14 /2)
	LeftHip:SetDesiredAngle(-3.14 /2)
end

local lastTick = 0

local function move(time)
	local amplitude = 1
	local frequency = 1
	local deltaTime = time - lastTick
	lastTick = time

	local climbFudge = 0
	local setAngles = false

	if (jumpAnimTime > 0) then
		jumpAnimTime = jumpAnimTime - deltaTime
	end

	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Seated") then
		playAnimation("sit", 0.5, Humanoid)
		return
	elseif (pose == "Running") then
		stopSpecificAnimation("Run")
		stopSpecificAnimation("RunAnim")
		stopSpecificAnimation("Idle")
		stopSpecificAnimation("Idle1")
		stopSpecificAnimation("Idle2")
		playAnimation("walk", 0.1, Humanoid)
	elseif (pose == "Sprinting") then
		stopSpecificAnimation("Walk")
		stopSpecificAnimation("WalkAnim")
		stopSpecificAnimation("Idle")
		stopSpecificAnimation("Idle1")
		stopSpecificAnimation("Idle2")
		playAnimation("run", 0.1, Humanoid)
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
		--		print("Wha " .. pose)
		stopAllAnimations()
		amplitude = 0.1
		frequency = 1
		setAngles = true
	end

	if (setAngles) then
		local desiredAngle = amplitude * math.sin(time * frequency)

		RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
		LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
		RightHip:SetDesiredAngle(-desiredAngle)
		LeftHip:SetDesiredAngle(-desiredAngle)
	end

	-- Tool Animation handling
	local tool = getTool()
	if tool and tool:FindFirstChild("Handle") then

		local animStringValueObject = getToolAnim(tool)

		if animStringValueObject then
			toolAnim = animStringValueObject.Value
			-- message recieved, delete StringValue
			animStringValueObject.Parent = nil
			toolAnimTime = time + .3
		end

		if time > toolAnimTime then
			toolAnimTime = 0
			toolAnim = "None"
		end

		animateTool()		
	else
		stopToolAnimations()
		toolAnim = "None"
		toolAnimInstance = nil
		toolAnimTime = 0
	end
end

-- connect events
Humanoid.Died:Connect(onDied)
Humanoid.Running:Connect(onRunning)
Humanoid.Jumping:Connect(onJumping)
Humanoid.Climbing:Connect(onClimbing)
Humanoid.GettingUp:Connect(onGettingUp)
Humanoid.FreeFalling:Connect(onFreeFall)
Humanoid.FallingDown:Connect(onFallingDown)
Humanoid.Seated:Connect(onSeated)
Humanoid.PlatformStanding:Connect(onPlatformStanding)
Humanoid.Swimming:Connect(onSwimming)

Sprinting:GetPropertyChangedSignal("Value"):Connect(function()
	if Sprinting.Value == true and pose == "Running" then
		stopSpecificAnimation("Walk")
		stopSpecificAnimation("WalkAnim")
		stopSpecificAnimation("Run")
		stopSpecificAnimation("RunAnim")
		stopSpecificAnimation("Idle")
		stopSpecificAnimation("Idle1")
		stopSpecificAnimation("Idle2")
		playAnimation("run", 0.1, Humanoid)
		if currentAnimInstance then
			if currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
				setAnimationSpeed(currentRunningSpeed / 14.5)
			elseif currentAnimInstance.AnimationId == "rbxassetid://14789825228" then
				setAnimationSpeed((currentRunningSpeed - 8) / 14.5)
			end
		end
		pose = "Sprinting"
	elseif Sprinting.Value == false and pose == "Sprinting" then
		stopSpecificAnimation("Walk")
		stopSpecificAnimation("WalkAnim")
		stopSpecificAnimation("Run")
		stopSpecificAnimation("RunAnim")
		stopSpecificAnimation("Idle")
		stopSpecificAnimation("Idle1")
		stopSpecificAnimation("Idle2")
		playAnimation("walk", 0.1, Humanoid)
		if currentAnimInstance and currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
			setAnimationSpeed(currentRunningSpeed / 14.5)
		end
		pose = "Running"
	end
end)

---- setup emote chat hook
--[[
game:GetService("Players").LocalPlayer.Chatted:Connect(function(msg)
	local emote = ""
	if msg == "/e dance" then
		emote = dances[math.random(1, #dances)]
	elseif (string.sub(msg, 1, 3) == "/e ") then
		emote = string.sub(msg, 4)
	elseif (string.sub(msg, 1, 7) == "/emote ") then
		emote = string.sub(msg, 8)
	end

	if (pose == "Standing" and emoteNames[emote] ~= nil) then
		playAnimation(emote, 0.1, Humanoid)
	end

end)
--]]

-- emote bindable hook
script:WaitForChild("PlayEmote").OnInvoke = function(emote)
	-- Only play emotes when idling
	if pose ~= "Standing" then
		return
	end
	if emoteNames[emote] ~= nil then
		-- Default emotes
		playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)

		return true, currentAnimTrack
	end

	-- Return false to indicate that the emote could not be played
	return false
end
-- main program
for _,v in ipairs(script:GetDescendants()) do
	if v:IsA("Animation") then
		v:GetPropertyChangedSignal("AnimationId"):Connect(function()
			if currentAnimInstance == v then
				for i,v2 in pairs(animNames[v.Parent.Name]) do
					if script:FindFirstChild(i) then
						v2.id = script[i]:FindFirstChildOfClass("Animation").AnimationId
					end
				end
				for i,v in pairs(animNames) do
					configureAnimationSet(i, v)
				end
				stopAllAnimations()
				playAnimation(v.Parent.Name, 0.1, Humanoid)
			end
		end)
	end
end

-- initialize to idle
playAnimation("idle", 0.1, Humanoid)
pose = "Standing"
--[[
task.spawn(function()
	while task.wait(2.5) do
		print(os.time(), Animator:GetPlayingAnimationTracks())
	end
end)
--]]
while Figure.Parent ~= nil do
	local time = task.wait(0.1)
	move(time)
end