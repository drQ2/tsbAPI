local Misc = {}

local CT = loadstring(game:HttpGet('https://raw.githubusercontent.com/ShizukuFuru/TSB-Folder/refs/heads/main/Custom-TEST.lua'))()

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

 
local cfNew = CFrame.new
local cfFromOrientation = CFrame.fromOrientation
local v3New = Vector3.new
local tick = tick

local CAMERA_OFFSET_SHIFTLOCK = v3New(1.75, 0, 0)
local CAMERA_OFFSET_DEFAULT   = v3New(0, 0, 0)
local CF_IDENTITY = cfNew()

 
if not getgenv().MiscGlueState then
	getgenv().MiscGlueState = {
		glueConnection     = nil,
		glueCamConnection  = nil,
		glueInputConnection = nil,
		glueShiftLock      = false,
		glueClone          = nil,
		glueActive         = false,
		lastClientCFrame   = nil,
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

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------

local function DisconnectState(key)
	local conn = state[key]
	if conn then
		conn:Disconnect()
		state[key] = nil
	end
end

local function CreateWeld(Part0, Part1, C0, C1, parent)
	local w = Instance.new("Weld")
	w.Part0 = Part0
	w.Part1 = Part1
	w.C0 = C0
	w.C1 = C1
	w.Parent = parent
	return w
end

local function FindAttachment(Model, AttachmentName)
	for _, Child in ipairs(Model:GetChildren()) do
		if Child:IsA("Attachment") and Child.Name == AttachmentName then
			return Child
		elseif not Child:IsA("Accoutrement") and not Child:IsA("Tool") then
			local found = FindAttachment(Child, AttachmentName)
			if found then return found end
		end
	end
end

----------------------------------------------------------------
-- Accessory
----------------------------------------------------------------

local function AddAccessoryInternal(Accessory, AttachmentPoint)
	local character = CT.Character()
	if not character then return end
	local Handle = Accessory:FindFirstChild("Handle")

	if Handle then
		local Attachment = Handle:FindFirstChildOfClass("Attachment")
		Accessory.Parent = character
		if Attachment then
			local CharAttach = FindAttachment(character, Attachment.Name)
			if CharAttach then
				CreateWeld(CharAttach.Parent, Attachment.Parent, CharAttach.CFrame, Attachment.CFrame, CharAttach.Parent)
			end
		else
			local Target = character:FindFirstChild(AttachmentPoint)
			if Target then
				CreateWeld(Target, Handle, cfNew(), Accessory.AttachmentPoint, Target)
			end
		end
	elseif Accessory:IsA("Shirt") or Accessory:IsA("Pants") then
		local isShirt = Accessory:IsA("Shirt")
		for _, obj in ipairs(character:GetChildren()) do
			if (isShirt and obj:IsA("Shirt")) or (not isShirt and obj:IsA("Pants")) then
				obj:Destroy()
			end
		end
		task.wait()
		Accessory.Parent = character
	end
end

function Misc.AddAccessory(id, AttachmentPoint)
	local ok, result = pcall(game.GetObjects, game, "rbxassetid://" .. id)
	if ok and result and result[1] then
		AddAccessoryInternal(result[1], AttachmentPoint)
	else
		warn("Failed to add accessory, invalid assetId or other")
	end
end

----------------------------------------------------------------
-- Hitbox
----------------------------------------------------------------

function Misc.Hitbox(originCFrame, size, filterList, mode, duration, onHit)
	local self = { _running = true }

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType[mode]
	params.FilterDescendantsInstances = filterList or {}

	local hitCooldown = {}
	local endTime = duration and (tick() + duration) or nil
	local isDynamic = type(originCFrame) == "function"

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not self._running then
			connection:Disconnect()
			return
		end

		if endTime and tick() > endTime then
			self:Stop()
			return
		end

		local cframe = isDynamic and originCFrame() or originCFrame
		if not cframe then return end

		local parts = workspace:GetPartBoundsInBox(cframe, size, params)
		local found -- lazy-allocated only when needed

		for i = 1, #parts do
			local part = parts[i]
			local model = part:FindFirstAncestorOfClass("Model")
			if model and not hitCooldown[model] then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hitCooldown[model] = true
					if not found then found = {} end
					found[#found + 1] = {
						plr = Players:GetPlayerFromCharacter(model),
						model = model,
						humanoid = hum,
						part = part,
					}
				end
			end
		end

		if found and onHit then
			task.defer(onHit, found)
		end
	end)

	function self:Stop()
		self._running = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	return self
end

----------------------------------------------------------------
-- Glue Clone
----------------------------------------------------------------
local function CreateGlueClone()
	local char = CT.Character()
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

	clone:SetAttribute("_collisionConn", nil) 
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

----------------------------------------------------------------
-- Glue
----------------------------------------------------------------

function Misc.Glue(Root, Offset, Toggle, UseDesync)
	state.glueActive = false

	DisconnectState("glueConnection")
	DisconnectState("glueCamConnection")
	DisconnectState("glueInputConnection")
	state.glueShiftLock = false

	if state.lastClientCFrame then
		local c = CT.Character()
		if c and c.PrimaryPart then
			c.PrimaryPart.CFrame = state.lastClientCFrame
		end
		state.lastClientCFrame = nil
	end

	DestroyGlueClone()

	MW_Camera.CameraSubject = nil
	local hum = CT.Humanoid()
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
		local c = CT.Character()
		if not c then return false end
		local pr = c.PrimaryPart
		local hum = c:FindFirstChildOfClass("Humanoid")
		if not pr or not hum or hum.Health <= 0 or pr.Position.Y < workspace.FallenPartsDestroyHeight then
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
			if not ok then Misc.StopGlue() return end
			
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
		if not ok then Misc.StopGlue() return end

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
		if not ok then Misc.StopGlue() return end

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

function Misc.StopGlue()
	Misc.Glue(nil, nil, false)
end

function Misc.Fling(root, targetPos, options)
	--[[
		root:       BasePart or Model to fling (should be anchored or network-owned)
		targetPos:  Vector3 final resting position
		options:    optional config table
		
		Returns handle with :Stop()
	]]
	options = options or {}

	local arcHeight   = options.arcHeight   or 15     -- peak height above start/end
	local maxBounces  = options.bounces     or 2      -- ground bounces before settling
	local restitution = options.restitution or 0.3    -- vertical energy kept per bounce (0-1)
	local friction    = options.friction    or 0.5    -- horizontal speed kept per bounce (0-1)
	local drag        = options.drag        or 0      -- air resistance per frame (0 = none)
	local tumbleRate  = options.tumbleSpeed or 12     -- radians/sec at full speed
	local snapTime    = options.snapDuration or 0.35  -- seconds to ease into final position
	local groundY     = options.groundY     or targetPos.Y
	local onComplete  = options.onComplete            -- callback when done

	local isModel = root:IsA("Model")
	local startPos = isModel and root:GetPivot().Position or root.Position

	local function setCF(cf)
		if isModel then root:PivotTo(cf) else root.CFrame = cf end
	end

	local g = workspace.Gravity

	-- ── Solve initial velocity for parabolic arc ──
	-- Peak is arcHeight above whichever endpoint is higher
	local peakY = math.max(startPos.Y, groundY) + math.max(arcHeight, 1)

	-- V0y to reach peak:  peakY = startY + vy²/(2g)
	local vy0 = math.sqrt(math.max(0.01, 2 * g * (peakY - startPos.Y)))

	-- Flight time = time rising + time falling from peak to groundY
	local tUp   = vy0 / g
	local tDown = math.sqrt(math.max(0.01, 2 * (peakY - groundY) / g))
	local T     = math.max(tUp + tDown, 0.1)

	-- Horizontal velocity so we arrive at target.X/Z at time T
	local vx0 = (targetPos.X - startPos.X) / T
	local vz0 = (targetPos.Z - startPos.Z) / T

	-- ── State ──
	local vel  = v3New(vx0, vy0, vz0)
	local pos  = startPos
	local bouncesUsed = 0
	local tumbleAngle = 0
	local phase       = "flight"   -- "flight" | "snap"
	local snapStartT  = 0
	local snapFromPos, snapFromRot
	local elapsed = 0

	-- Tumble axis: perpendicular to horizontal flight direction
	-- (0,1,0) × flightDir gives the "cartwheel" axis
	local tumbleAxis = v3New(1, 0, 0) -- fallback
	do
		local hDir = v3New(vx0, 0, vz0)
		if hDir.Magnitude > 0.01 then
			local cross = v3New(0, 1, 0):Cross(hDir.Unit)
			if cross.Magnitude > 0.001 then
				tumbleAxis = cross.Unit
			end
		end
	end

	-- ── Simulation loop ──
	local self = { _running = true }
	local conn

	conn = RunService.Heartbeat:Connect(function(dt)
		if not self._running then conn:Disconnect() return end
		elapsed += dt

		if phase == "flight" then
			-- Euler integration
			vel = v3New(vel.X, vel.Y - g * dt, vel.Z)
			if drag > 0 then vel = vel * (1 - drag) end
			pos = pos + vel * dt

			-- Ground collision
			if pos.Y <= groundY then
				pos = v3New(pos.X, groundY, pos.Z)

				if bouncesUsed < maxBounces and math.abs(vel.Y) > 2 then
					-- Bounce: reflect vertical, dampen both axes
					bouncesUsed += 1
					vel = v3New(
						vel.X * friction,
						math.abs(vel.Y) * restitution,
						vel.Z * friction
					)
				else
					-- All bounces spent → transition to snap phase
					phase = "snap"
					snapStartT  = elapsed
					snapFromPos = pos
					snapFromRot = CFrame.fromAxisAngle(tumbleAxis, tumbleAngle)
				end
			end

			-- Tumble: fast when moving, fades as speed drops
			local speed = vel.Magnitude
			tumbleAngle += tumbleRate * dt * math.clamp(speed / 40, 0, 1)

			setCF(cfNew(pos) * CFrame.fromAxisAngle(tumbleAxis, tumbleAngle))

		elseif phase == "snap" then
			-- Ease-out quad into exact target + upright rotation
			local alpha = math.clamp((elapsed - snapStartT) / snapTime, 0, 1)
			local ease  = 1 - (1 - alpha) ^ 2

			local p   = snapFromPos:Lerp(targetPos, ease)
			local rot = snapFromRot:Lerp(cfNew(), ease) -- → identity (upright)

			setCF(cfNew(p) * rot)

			if alpha >= 1 then
				setCF(cfNew(targetPos))
				self._running = false
				conn:Disconnect()
				if onComplete then task.defer(onComplete) end
				return
			end
		end

		-- Safety timeout
		if elapsed > 15 then
			setCF(cfNew(targetPos))
			self._running = false
			conn:Disconnect()
			if onComplete then task.defer(onComplete) end
		end
	end)

	function self:Stop()
		self._running = false
		if conn then conn:Disconnect() conn = nil end
	end

	return self
end

return Misc
