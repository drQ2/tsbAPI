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

API.GetHumanoid = function(c)
	return c and c:FindFirstChildWhichIsA("Humanoid")
end

API.GetRoot = function(c)
	return c and c:FindFirstChild("HumanoidRootPart")
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

	if item then
		if API.trackedPlayers[v] and API.trackedPlayers[v] ~= itemName then
			local oldHighlight = v:FindFirstChild(API.trackedPlayers[v] .. "Highlight")
			if oldHighlight then oldHighlight:Destroy() end
			API.trackedPlayers[v] = nil
		end
		
		if not API.trackedPlayers[v] then
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
		end
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

API.LoadAnim = function(ID)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://"..tostring(ID)
	local hum = API.Humanoid()
	return hum and hum.Animator and hum.Animator:LoadAnimation(anim)
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
					elseif callback then callback(animationTrack)
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
					elseif callback then callback(track)
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

-- Resolve a player by username or display name (exact match first, then partial)
API.resolvePlayer = function(nameQuery)
	nameQuery = string.lower(nameQuery)
	if nameQuery == "me" then return Player end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Player then
			if string.lower(p.Name) == nameQuery or string.lower(p.DisplayName) == nameQuery then
				return p
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Player then
			if string.find(string.lower(p.Name), nameQuery, 1, true) or string.find(string.lower(p.DisplayName), nameQuery, 1, true) then
				return p
			end
		end
	end
	return nil
end

-- Check if a player is alive (has character, humanoid, health > 0)
API.isPlayerAlive = function(player)
	if not player or not player.Parent then return false end
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	return true
end

-- Send a chat message using the correct chat system
API.chatMessage = function(text)
	pcall(function()
		local TCS = game:GetService("TextChatService")
		if TCS.ChatVersion == Enum.ChatVersion.TextChatService then
			TCS.TextChannels.RBXGeneral:SendAsync(text)
		else
			game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
		end
	end)
end

----------------------------------------------------------------
-- Glue / Desync System (merged from Misc.lua)
----------------------------------------------------------------

local cfNew = CFrame.new
local cfFromOrientation = CFrame.fromOrientation
local v3New = Vector3.new
local CF_IDENTITY = cfNew()

if not getgenv().MiscGlueState then
	getgenv().MiscGlueState = {
		glueConnection      = nil,
		glueCamConnection   = nil,
		glueInputConnection = nil,
		glueShiftLock       = false,
		glueClone           = nil,
		glueActive          = false,
		lastClientCFrame    = nil,
	}
end
local state = getgenv().MiscGlueState

if not getgenv().MW_Camera then
	getgenv().MW_Camera = { CameraSubject = nil }
end
local MW_Camera = getgenv().MW_Camera

if not getgenv().MW_CameraHooked then
	getgenv().MW_CameraHooked = true
	local IsA = game.IsA

	local __index
	__index = hookmetamethod(game, "__index", newcclosure(function(self, key)
		if not checkcaller() and MW_Camera.CameraSubject then
			if typeof(self) == "Instance" and IsA(self, "Camera") then
				if key == "CameraSubject" or key == "cameraSubject" then
					return MW_Camera.CameraSubject
				end
			end
		end
		return __index(self, key)
	end))

	local __newindex
	__newindex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
		if not checkcaller() and MW_Camera.CameraSubject then
			if typeof(self) == "Instance" and IsA(self, "Camera") then
				if key == "CameraSubject" or key == "cameraSubject" then
					return
				end
			end
		end
		return __newindex(self, key, value)
	end))
end

local function DisconnectState(key)
	local conn = state[key]
	if conn then
		conn:Disconnect()
		state[key] = nil
	end
end

local function CreateGlueClone()
	local char = API.chr()
	if not char then return nil end

	local clone = char:Clone()
	clone.Name = "GlueClone"

	local cloneParts = {}

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BaseScript") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Transparency = 1
			desc.CanCollide = false
			desc.Anchored = false
			cloneParts[#cloneParts + 1] = desc
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		end
	end

	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.NameDisplayDistance = 0
		hum.HealthDisplayDistance = 0
	end

	clone.Parent = workspace

	local conn
	conn = RunService.Stepped:Connect(function()
		if not clone or not clone.Parent then
			conn:Disconnect()
			return
		end
		for i = 1, #cloneParts do
			local p = cloneParts[i]
			if p and p.Parent then
				p.CanCollide = false
			end
		end
	end)

	state._glueCollisionConn = conn
	return clone
end

local function DestroyGlueClone()
	if state._glueCollisionConn then
		state._glueCollisionConn:Disconnect()
		state._glueCollisionConn = nil
	end
	local c = state.glueClone
	if c then
		if c.Parent then c:Destroy() end
		state.glueClone = nil
	end
end

function API.Glue(Root, Offset, Toggle, UseDesync)
	state.glueActive = false

	DisconnectState("glueConnection")
	DisconnectState("glueCamConnection")
	DisconnectState("glueInputConnection")
	state.glueShiftLock = false

	if state.lastClientCFrame then
		local c = API.chr()
		if c and c.PrimaryPart then
			c.PrimaryPart.CFrame = state.lastClientCFrame
		end
		state.lastClientCFrame = nil
	end

	DestroyGlueClone()

	MW_Camera.CameraSubject = nil
	local hum = API.Humanoid()
	if hum then
		workspace.CurrentCamera.CameraSubject = hum
	end

	if not Toggle then return end

	local offsetCF
	local offsetFunc
	local offsetType

	if type(Offset) == "function" then
		offsetFunc = Offset
		offsetType = "function"
	elseif typeof(Offset) == "CFrame" then
		offsetCF = Offset
		offsetType = "cframe"
	elseif typeof(Offset) == "Vector3" then
		offsetCF = cfNew(Offset)
		offsetType = "cframe"
	elseif type(Offset) == "table" then
		offsetCF = cfNew(Offset[1] or 0, Offset[2] or 0, Offset[3] or 0)
		offsetType = "cframe"
	else
		offsetCF = CF_IDENTITY
		offsetType = "cframe"
	end

	state.glueActive = true

	local function checkAlive()
		local c = API.chr()
		if not c then return false end
		local pr = c.PrimaryPart
		local h = c:FindFirstChildOfClass("Humanoid")
		if not pr or not h or h.Health <= 0 or pr.Position.Y < workspace.FallenPartsDestroyHeight then
			return false
		end

		if not Root or not Root.Parent then return false end
		local rootPos = Root:IsA("Model") and Root:GetPivot().Position or Root.Position
		if rootPos.Y < workspace.FallenPartsDestroyHeight then
			return false
		end
		local tHum = Root.Parent:FindFirstChildOfClass("Humanoid")
		if tHum and tHum.Health <= 0 then return false end

		return true, pr
	end

	if not UseDesync then
		state.glueConnection = RunService.Heartbeat:Connect(function()
			if not state.glueActive then return end
			local ok, pr = checkAlive()
			if not ok then API.StopGlue() return end

			sethiddenproperty(pr, "PhysicsRepRootPart", Root)

			if offsetType == "function" then
				local result = offsetFunc()
				if typeof(result) == "CFrame" then
					pr.CFrame = result
				else
					local ox, oy, oz = offsetFunc()
					pr.CFrame = (Root:IsA("Model") and Root:GetPivot() or Root.CFrame) * cfNew(ox, oy, oz)
				end
			else
				pr.CFrame = (Root:IsA("Model") and Root:GetPivot() or Root.CFrame) * offsetCF
			end
		end)
		return
	end

	state.glueClone = CreateGlueClone()
	if not state.glueClone then return end

	local cloneHum = state.glueClone:FindFirstChildOfClass("Humanoid")
	workspace.Camera.CameraSubject = cloneHum
	MW_Camera.CameraSubject = cloneHum

	state.glueInputConnection = UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
		state.glueShiftLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	end)

	state.glueCamConnection = RunService.RenderStepped:Connect(function()
		if not state.glueActive then return end
		local ok, pr = checkAlive()
		if not ok then API.StopGlue() return end

		if state.lastClientCFrame then
			pr.CFrame = state.lastClientCFrame
		end

		if state.glueShiftLock then
			local _, ry = workspace.CurrentCamera.CFrame:ToOrientation()
			pr.CFrame = cfNew(pr.Position) * cfFromOrientation(0, ry, 0)
		end
	end)

	state.glueConnection = RunService.Heartbeat:Connect(function()
		if not state.glueActive then return end
		local ok, pr = checkAlive()
		if not ok then API.StopGlue() return end

		state.lastClientCFrame = pr.CFrame

		sethiddenproperty(pr, "PhysicsRepRootPart", Root)

		if offsetType == "function" then
			local result = offsetFunc()
			if typeof(result) == "CFrame" then
				pr.CFrame = result
			else
				local ox, oy, oz = offsetFunc()
				pr.CFrame = (Root:IsA("Model") and Root:GetPivot() or Root.CFrame) * cfNew(ox, oy, oz)
			end
		else
			pr.CFrame = (Root:IsA("Model") and Root:GetPivot() or Root.CFrame) * offsetCF
		end

		local gc = state.glueClone
		if gc and gc.PrimaryPart then
			gc.PrimaryPart.CFrame = state.lastClientCFrame
		end
	end)
end

function API.StopGlue()
	API.Glue(nil, nil, false)
end

return API
