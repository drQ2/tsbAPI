local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local teleportPosition = Vector3.new(1061, 406, 23005)

task.spawn(function() -- break velocity (ripped from IY)
	local BeenASecond, V3 = false, Vector3.new(0, 0, 0)
	delay(1, function()
		BeenASecond = true
	end)
	while not BeenASecond do
		for _, v in ipairs(player.Character:GetDescendants()) do
			if v:IsA("BasePart") then
				v.Velocity, v.RotVelocity = V3, V3
			end
		end
		wait()
	end
end)

local bb=game:service'VirtualUser'
player.Idled:connect(function()bb:CaptureController()bb:ClickButton2(Vector2.new())end) -- anti idle (?)

RunService:Set3dRenderingEnabled(false) -- Disable 3D rendering

RunService.RenderStepped:Connect(function()
	game:GetService("GuiService").ErrorMessageChanged:Connect(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceId, JobId, player)
	end)
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

        if rootPart then
            rootPart.CFrame = CFrame.new(teleportPosition)
        end

        if humanoid and humanoid.Health < 100 then
            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        end
    end
end)

