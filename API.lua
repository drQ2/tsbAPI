local API = {}

local Players = cloneref(game:GetService("Players"))
local Player = Players.LocalPlayer
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local StarterGui = cloneref(game:GetService("StarterGui"))

-- Global Connection Management
if not getgenv().TSB_Connections then getgenv().TSB_Connections = {} end

function API.Cleanup()
	for _, conn in ipairs(getgenv().TSB_Connections) do
		if conn then
			if conn.Disconnect then conn:Disconnect()
			elseif conn.disconnect then conn:disconnect()
			end
		end
	end
	table.clear(getgenv().TSB_Connections)
end

function API.add(conn)
	if conn then
		table.insert(getgenv().TSB_Connections, conn)
	end
	return conn
end

API.Camera = function()
	return workspace.CurrentCamera
end

API.chr = function()
	return Player.Character
end

API.Humanoid = function()
	return API.chr() and API.chr():FindFirstChildWhichIsA("Humanoid")
end

API.RootPart = function()
	return API.chr() and API.chr():FindFirstChild("HumanoidRootPart")
end

API.Animator = function()
	return API.Humanoid().Animator
end

API.Bind = function(k,c)
	API.add(UserInputService.InputBegan:Connect(function(i,g)
		if not g and i.KeyCode == k then
			c()
		end
	end))
end

API.TP = function(KEY, POS, DUNK)
	API.Bind(KEY, function()
		if API.RootPart() then
			API.RootPart().CFrame = DUNK and API.RootPart().CFrame + Vector3.new(0, POS, 0) or CFrame.new(POS)
		end
	end)
end

API.loop = function(c)
	coroutine.wrap(function()
		API.add(RunService.RenderStepped:Connect(c))
	end)()
end

API.OnSpawn = function(c)
	API.add(Player.CharacterAdded:Connect(c))
end

API.flip = function(a, b, c)
	local _, ry, _ = API.Camera().CFrame:ToOrientation()
	if API.RootPart() then
		API.RootPart().CFrame = CFrame.new(API.RootPart().CFrame.p) * CFrame.fromOrientation(0, ry, 0)
		API.RootPart().CFrame *= CFrame.Angles(a, b, c)
	end
end

API.trackedPlayers = {}

function API.Detect(v, isAccessory, itemName, highlightColor, alertTitle, alertText)
	local item = isAccessory and v:FindFirstChild(itemName) or v:GetAttribute(itemName)
	local highlightName = itemName .. "Highlight"

	if item and not API.trackedPlayers[v] then
		local playerInstance = Players:GetPlayerFromCharacter(v)
		if playerInstance then
			StarterGui:SetCore("SendNotification", {
				Title = alertTitle,
				Text = playerInstance.DisplayName .. alertText,
				Icon = "rbxthumb://type=AvatarHeadShot&id=" .. playerInstance.UserId .. "&w=150&h=150",
				Button1 = "Got it"
			})
		end

		local highlight = v:FindFirstChild(highlightName) or Instance.new("Highlight")
		highlight.Name = highlightName
		highlight.Adornee = v
		highlight.FillColor = highlightColor
		highlight.FillTransparency = 0.5
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.OutlineTransparency = 0
		highlight.Parent = v

		API.trackedPlayers[v] = itemName
	elseif not item and API.trackedPlayers[v] == itemName then
		API.trackedPlayers[v] = nil
		local highlight = v:FindFirstChild(highlightName)
		if highlight then
			highlight:Destroy()
		end
	end
end

local cachedParts = {}
local lastChar = nil
local lastTransState = nil

API.setTransparency = function(isInvisible)
	local char = API.chr()
	if not char then return end
	
	if char ~= lastChar then
		cachedParts = {}
		lastChar = char
		lastTransState = nil
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency ~= 1 then
				table.insert(cachedParts, {p = part, o = part.Transparency})
			end
		end
		-- Listen for new parts (optional, but good for tools/accessories)
		char.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") and part.Transparency ~= 1 then
				table.insert(cachedParts, {p = part, o = part.Transparency})
			end
		end)
	end

	-- Only apply changes if the state toggled
	if lastTransState == isInvisible then return end
	lastTransState = isInvisible

	for _, data in ipairs(cachedParts) do
		if data.p and data.p.Parent then -- check validity
			data.p.Transparency = isInvisible and 0.5 or data.o
		end
	end
end



API.PlayAnim = function(ID,timePos)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://"..tostring(ID)
	local loadedAnim = API.Humanoid().Animator:LoadAnimation(anim)
	if timePos then
		loadedAnim.Priority = Enum.AnimationPriority.Action4
		loadedAnim:Play()
		loadedAnim.TimePosition = timePos
		loadedAnim:AdjustSpeed(0)
		RunService.RenderStepped:Wait()
		loadedAnim:Stop()
	else
		loadedAnim:Play()
	end
end

API.AnimPlayed = function(AnimationIds,stop,callback)
	local function hookAnimator(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then return end
		local animator = hum:WaitForChild("Animator", 5)
		if not animator then return end

		API.add(animator.AnimationPlayed:Connect(function(animationTrack)
			local trackId = string.match(animationTrack.Animation.AnimationId, "%d+")
			for _, v in ipairs(AnimationIds) do
				if trackId == tostring(v) then
					if stop then animationTrack:Stop()
					elseif callback then callback()
					end
				end
			end
		end))
		
		-- Check already playing tracks
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local trackId = string.match(track.Animation.AnimationId, "%d+")
			for _, v in ipairs(AnimationIds) do
				if trackId == tostring(v) then
					if stop then track:Stop()
					elseif callback then callback()
					end
				end
			end
		end
	end

	if Player.Character then task.spawn(hookAnimator, Player.Character) end
	API.add(Player.CharacterAdded:Connect(hookAnimator))
end

API.Nearest = function()
	local closestPlayer = nil
	local shortestDistance = math.huge
	local myRoot = API.RootPart()
	if not myRoot then return nil end
	local myPos = myRoot.Position

	for _, otherPlayer in ipairs(workspace.Live:GetChildren()) do
		if otherPlayer ~= Player.Character then
			local root = otherPlayer:FindFirstChild("HumanoidRootPart")
			if root then
				local distance = (myPos - root.Position).Magnitude
				if distance < shortestDistance then
					closestPlayer = otherPlayer
					shortestDistance = distance
				end
			end
		end
	end
	return closestPlayer
end

local VIP = false

API.DashCD = function(state)
	if not VIP then
		workspace:SetAttribute("VIPServer",Player.UserId)
		workspace:SetAttribute("VIPServerOwner",Player.Name)
		VIP = true
	end
	workspace:SetAttribute("NoDashCooldown",state)
end

return API
