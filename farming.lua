local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local teleportPosition = Vector3.new(1061, 406, 23005)

PlaceId, JobId = game.PlaceId, game.JobId
queueteleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)

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

local TeleportCheck = false
Players.LocalPlayer.OnTeleport:Connect(function(State)
	if not TeleportCheck and queueteleport then
		TeleportCheck = true
		queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/drQ2/tsbAPI/refs/heads/main/farming.lua'))()")
	end
end)
