local API = {}

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

API.Camera = function()
    return workspace.CurrentCamera
end

API.chr = function()
    return Player and Player.Character
end

API.Humanoid = function()
    return API.chr() and API.chr():FindFirstChildWhichIsA("Humanoid")
end

API.RootPart = function()
    return API.chr() and API.chr():FindFirstChild("HumanoidRootPart")
end

API.Bind = function(k,c)
    game:GetService("UserInputService").InputBegan:Connect(function(i,g)
        if not g and i.KeyCode == k then
            c()
        end
    end)
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
        game:GetService("RunService").RenderStepped:Connect(c)
    end)()
end

API.OnSpawn = function(c)
    Player.CharacterAdded:Connect(c)
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
            game:GetService("StarterGui"):SetCore("SendNotification", {
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

API.setTransparency = function(isInvisible)
    for _, part in pairs(API.chr():GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency ~= 1 then
            part.Transparency = isInvisible and 0.5 or 0
        end
    end
end

return API
