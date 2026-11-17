-- Da Hood Utility: Full Featured Script
-- UI style: Ria-like light theme, header "LUCAS.EXE"
-- Features: Hitbox, Fog, Silent Aim, Camlock, ESP, Whitelist, Speed, Keybinds
-- Requires a Roblox executor with Level 7 permissions and getrawmetatable support.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ============ CONFIG ============
local hitboxEnabled = false
local hitboxSize = 20
local hitboxTransparency = 0.5
local hitboxColor = Color3.fromRGB(255, 0, 0)
local TARGET_PART = "HumanoidRootPart"

local silentAimEnabled = false
local silentAimPart = "Head"
local silentAimFOV = 300
local silentAimKey = Enum.KeyCode.V
local silentAimKeyHeld = false

local camlockEnabled = false
local camlockTarget = nil
local camlockSmoothness = 0.25

local espEnabled = false
local espColor = Color3.fromRGB(255, 0, 0)
local espMode = "Name" -- Name, Box, Skeleton, Both
local espDrawings = {}

local whitelist = {}

local speedEnabled = false
local speedValue = 16
local defaultWalkSpeed = 16

local FogPresets = {
    ["Neon Red"]      = {Color = Color3.fromRGB(255, 70, 70),  Density = 0.45},
    ["Deep Pink"]     = {Color = Color3.fromRGB(255, 20, 147), Density = 0.48},
    ["Electric Blue"] = {Color = Color3.fromRGB(0, 255, 255),  Density = 0.51},
    ["Toxic Green"]   = {Color = Color3.fromRGB(50, 255, 50),  Density = 0.49},
    ["Void Purple"]   = {Color = Color3.fromRGB(138, 43, 226), Density = 0.56},
    ["Hell Orange"]   = {Color = Color3.fromRGB(255, 140, 0),  Density = 0.43},
}

-- ============ HITBOX LOGIC ============
local function isWhitelisted(player)
    return whitelist[player.UserId] or whitelist[player.Name]
end

local function applyHitbox(player)
    if not hitboxEnabled or player == LocalPlayer or not player.Character or isWhitelisted(player) then return end
    local part = player.Character:FindFirstChild(TARGET_PART)
    if part and part:IsA("BasePart") then
        part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        part.Transparency = hitboxTransparency
        part.Color = hitboxColor
        part.CanCollide = false
        part.Material = Enum.Material.Neon
    end
end

local function applyToAll()
    if not hitboxEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        applyHitbox(player)
    end
end

local function clearHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local part = player.Character:FindFirstChild(TARGET_PART)
            if part and part:IsA("BasePart") then
                part.Size = Vector3.new(2, 2, 1)
                part.Transparency = 0
                part.Color = Color3.fromRGB(255, 255, 255)
                part.CanCollide = true
                part.Material = Enum.Material.Plastic
            end
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        applyHitbox(player)
    end)
end)
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            applyHitbox(player)
        end)
    end
end
RunService.RenderStepped:Connect(function() applyToAll() end)

-- ============ SILENT AIM LOGIC ============
local Camera = Workspace.CurrentCamera
local function getClosestTargetPart(partName, fov)
    local closest = nil
    local shortest = fov or math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not isWhitelisted(player) then
            local part = player.Character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if dist2D < shortest then shortest = dist2D; closest = part end
                end
            end
        end
    end
    return closest
end
local function getAimTarget()
    if not silentAimEnabled or not silentAimKeyHeld then return nil end
    return getClosestTargetPart(silentAimPart, silentAimFOV)
end
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == silentAimKey then silentAimKeyHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == silentAimKey then silentAimKeyHeld = false end
end)
pcall(function()
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    setreadonly(mt, false)
    mt.__index = newcclosure(function(self, key)
        if key == "Hit" and silentAimEnabled and silentAimKeyHeld then
            local target = getAimTarget()
            if target then return CFrame.new(target.Position) end
        end
        return oldIndex(self, key)
    end)
    setreadonly(mt, true)
end)

-- ============ CAMLOCK LOGIC ============
local function findClosestPlayerToCursor()
    local mousePos = UserInputService:GetMouseLocation()
    local closest = nil
    local shortest = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not isWhitelisted(player) then
            local head = player.Character:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < shortest then shortest = dist; closest = player end
                end
            end
        end
    end
    return closest
end
RunService.RenderStepped:Connect(function()
    if not camlockEnabled then return end
    if not camlockTarget or not camlockTarget.Character then
        camlockTarget = findClosestPlayerToCursor(); return
    end
    if isWhitelisted(camlockTarget) then camlockTarget = nil; return end
    local head = camlockTarget.Character:FindFirstChild("Head")
    if not head then camlockTarget = findClosestPlayerToCursor(); return end
    local camPos = Camera.CFrame.Position
    local lookDir = (head.Position - camPos).Unit
    local newCFrame = CFrame.new(camPos, camPos + lookDir)
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, camlockSmoothness)
end)

-- ============ SPEED LOGIC ============
RunService.RenderStepped:Connect(function()
    if speedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speedValue end
    end
end)

-- ============ ESP LOGIC ============
local function clearESP()
    for _, d in pairs(espDrawings) do
        if typeof(d) == "table" then
            for _, v in pairs(d) do if v and v.Remove then v:Remove() end end
        elseif d and d.Remove then
            d:Remove()
        end
    end
    espDrawings = {}
end

local function getBoxFromPart(part)
    local pos, size = part.Position, part.Size
    return pos, size
end

local function drawESP()
    if not espEnabled then clearESP(); return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if head and hrp then
                if not espDrawings[player.UserId] then
                    espDrawings[player.UserId] = {
                        name = Drawing.new("Text"),
                        box = Drawing.new("Square"),
                        line = Drawing.new("Line"),
                    }
                end
                local d = espDrawings[player.UserId]
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen and screenPos.Z > 0 then
                    local wl = isWhitelisted(player)
                    local col = wl and Color3.fromRGB(0, 255, 0) or espColor
                    d.name.Visible = (espMode == "Name" or espMode == "Both")
                    d.name.Text = player.Name
                    d.name.Color = col
                    d.name.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
                    d.name.Size = 14
                    d.name.Center = true
                    d.box.Visible = (espMode == "Box" or espMode == "Both")
                    d.box.Color = col
                    d.box.Thickness = 1
                    d.box.Position = Vector2.new(screenPos.X - 20, screenPos.Y - 30)
                    d.box.Size = Vector2.new(40, 60)
                    d.line.Visible = (espMode == "Skeleton")
                    d.line.Color = col
                    d.line.Thickness = 1
                    d.line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    d.line.To = Vector2.new(screenPos.X, screenPos.Y)
                else
                    for _, v in pairs(d) do v.Visible = false end
                end
            end
        end
    end
end
RunService.RenderStepped:Connect(drawESP)

-- ============ FOG LOGIC ============
local function setFog(name)
    local preset = FogPresets[name]
    if not preset then return end
    Lighting.FogColor = preset.Color
    Lighting.FogStart = 0
    Lighting.FogEnd = 1000 * (1 - preset.Density)
end
local function clearFog()
    Lighting.FogColor = Color3.fromRGB(192, 192, 192)
    Lighting.FogStart = 0
    Lighting.FogEnd = 100000
end

-- ============ GUI ============
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LucasEXE"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local BG_MAIN      = Color3.fromRGB(240, 245, 250)
local BG_SIDEBAR   = Color3.fromRGB(255, 255, 255)
local BG_HEADER    = Color3.fromRGB(230, 240, 250)
local ACCENT       = Color3.fromRGB(130, 200, 250)
local TEXT_DARK    = Color3.fromRGB(30, 40, 50)
local LINE_CLR     = Color3.fromRGB(220, 230, 240)

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 660, 0, 470)
Main.Position = UDim2.new(0.5, -330, 0.5, -235)
Main.BackgroundColor3 = BG_MAIN
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local ms = Instance.new("UIStroke", Main); ms.Color = LINE_CLR; ms.Thickness = 1

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = BG_HEADER
Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 300, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "LUCAS.EXE"
Title.TextColor3 = TEXT_DARK
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 170, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = BG_SIDEBAR
Sidebar.BorderSizePixel = 0
local sl = Instance.new("UIListLayout", Sidebar)
sl.Padding = UDim.new(0, 6); sl.SortOrder = Enum.SortOrder.LayoutOrder
local sp = Instance.new("UIPadding", Sidebar)
sp.PaddingTop = UDim.new(0, 12); sp.PaddingLeft = UDim.new(0, 10); sp.PaddingRight = UDim.new(0, 10)

local Content = Instance.new("Frame", Main)
Content.Size = UDim2.new(1, -170, 1, -40)
Content.Position = UDim2.new(0, 170, 0, 40)
Content.BackgroundTransparency = 1

local function makePage()
    local p = Instance.new("Frame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Parent = Content
    return p
end
local HitboxPage = makePage()
local FogPage = makePage()
local SilentAimPage = makePage()
local CamlockPage = makePage()
local ESPPage = makePage()
local WhitelistPage = makePage()
local SpeedPage = makePage()
local KeybindPage = makePage()

local sidebarButtons = {}
local function selectTab(activeBtn, page)
    for _, b in ipairs(sidebarButtons) do
        b.BackgroundColor3 = BG_SIDEBAR; b.TextColor3 = TEXT_DARK
    end
    activeBtn.BackgroundColor3 = ACCENT; activeBtn.TextColor3 = Color3.new(1,1,1)
    for _, p in ipairs(Content:GetChildren()) do
        if p:IsA("Frame") then p.Visible = (p == page) end
    end
end
local function makeSidebarButton(name, order, page)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = BG_SIDEBAR
    btn.BorderSizePixel = 0
    btn.Text = "  " .. name
    btn.TextColor3 = TEXT_DARK
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.LayoutOrder = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = BG_MAIN end)
    btn.MouseLeave:Connect(function()
        if btn.BackgroundColor3 ~= ACCENT then btn.BackgroundColor3 = BG_SIDEBAR end
    end)
    btn.MouseButton1Click:Connect(function() selectTab(btn, page) end)
    table.insert(sidebarButtons, btn)
    return btn
end

local hitboxTab = makeSidebarButton("Hitbox", 1, HitboxPage)
local fogTab = makeSidebarButton("Fog Changer", 2, FogPage)
local silentTab = makeSidebarButton("Silent Aim", 3, SilentAimPage)
local camlockTab = makeSidebarButton("Camlock", 4, CamlockPage)
local espTab = makeSidebarButton("ESP", 5, ESPPage)
local wlTab = makeSidebarButton("Whitelist", 6, WhitelistPage)
local speedTab = makeSidebarButton("Speed Master", 7, SpeedPage)
local keybindTab = makeSidebarButton("Keybinds", 8, KeybindPage)

-- ============ ROW HELPERS ============
local function makeRow(parent, labelText, yPos, height)
    height = height or 44
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -30, 0, height)
    row.Position = UDim2.new(0, 15, 0, yPos)
    row.BackgroundColor3 = BG_SIDEBAR
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -140, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = TEXT_DARK
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return row, lbl
end

local function makeToggle(parentRow, initial, onChange)
    local state = initial
    local btn = Instance.new("TextButton", parentRow)
    btn.Size = UDim2.new(0, 50, 0, 26)
    btn.Position = UDim2.new(1, -62, 0.5, -13)
    btn.BackgroundColor3 = state and ACCENT or Color3.fromRGB(220, 225, 230)
    btn.BorderSizePixel = 0
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", btn)
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and ACCENT or Color3.fromRGB(220, 225, 230)
        knob:TweenPosition(state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        onChange(state)
    end)
end

local function makeSlider(parentRow, min, max, initial, step, onChange)
    local sliderHolder = Instance.new("Frame", parentRow)
    sliderHolder.Size = UDim2.new(0, 140, 0, 24)
    sliderHolder.Position = UDim2.new(1, -160, 0.5, -12)
    sliderHolder.BackgroundColor3 = Color3.fromRGB(220, 225, 230)
    sliderHolder.BorderSizePixel = 0
    Instance.new("UICorner", sliderHolder).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame", sliderHolder)
    fill.Size = UDim2.new((initial - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = ACCENT
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", sliderHolder)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new((initial - min) / (max - min), -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local valLabel = Instance.new("TextLabel", parentRow)
    valLabel.Size = UDim2.new(0, 50, 0, 20)
    valLabel.Position = UDim2.new(1, -62, 0.5, -10)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(initial)
    valLabel.TextColor3 = TEXT_DARK
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 12
    local dragging = false
    local function updateFromX(mx)
        local rel = math.clamp((mx - sliderHolder.AbsolutePosition.X) / sliderHolder.AbsoluteSize.X, 0, 1)
        local val = min + (max - min) * rel
        val = math.floor(val / step + 0.5) * step
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        knob.Position = UDim2.new((val - min) / (max - min), -7, 0.5, -7)
        valLabel.Text = tostring(val)
        onChange(val)
    end
    knob.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateFromX(input.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    sliderHolder.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; updateFromX(input.Position.X) end end)
end

local function makeColorPicker(parentRow, initial, onChange)
    local btn = Instance.new("TextButton", parentRow)
    btn.Size = UDim2.new(0, 50, 0, 26)
    btn.Position = UDim2.new(1, -62, 0.5, -13)
    btn.BackgroundColor3 = initial
    btn.BorderSizePixel = 0
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        local palette = {
            Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255),
            Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(0, 255, 255),
            Color3.fromRGB(255, 255, 255),
        }
        local current = btn.BackgroundColor3
        local idx = 1
        for i, c in ipairs(palette) do if c == current then idx = i + 1; break end end
        if idx > #palette then idx = 1 end
        btn.BackgroundColor3 = palette[idx]
        onChange(palette[idx])
    end)
end

local function makeDropdown(parentRow, options, initial, onChange)
    local btn = Instance.new("TextButton", parentRow)
    btn.Size = UDim2.new(0, 100, 0, 26)
    btn.Position = UDim2.new(1, -112, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(240, 245, 250)
    btn.BorderSizePixel = 0
    btn.Text = initial
    btn.TextColor3 = TEXT_DARK
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local idx = 1
    for i, opt in ipairs(options) do if opt == initial then idx = i; break end end
    btn.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        btn.Text = options[idx]
        onChange(options[idx])
    end)
end

-- ============ HITBOX PAGE ============
local hitRow = makeRow(HitboxPage, "Enable Hitbox Expander", 15)
makeToggle(hitRow, false, function(s) hitboxEnabled = s; if not s then clearHitboxes() end end)

local sizeRow = makeRow(HitboxPage, "Hitbox Size", 70)
makeSlider(sizeRow, 2, 100, hitboxSize, 1, function(v) hitboxSize = v end)

local transRow = makeRow(HitboxPage, "Hitbox Transparency", 125)
makeSlider(transRow, 0, 1, hitboxTransparency, 0.05, function(v) hitboxTransparency = v end)

local colorRow = makeRow(HitboxPage, "Hitbox Color", 180)
makeColorPicker(colorRow, hitboxColor, function(c) hitboxColor = c end)

makeRow(HitboxPage, "Target Part: " .. TARGET_PART, 235)

-- ============ FOG PAGE ============
local fogScroll = Instance.new("ScrollingFrame", FogPage)
fogScroll.Size = UDim2.new(1, -30, 1, -30)
fogScroll.Position = UDim2.new(0, 15, 0, 15)
fogScroll.BackgroundTransparency = 1
fogScroll.BorderSizePixel = 0
fogScroll.ScrollBarThickness = 6
fogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
fogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local fl = Instance.new("UIListLayout", fogScroll)
fl.Padding = UDim.new(0, 8); fl.SortOrder = Enum.SortOrder.LayoutOrder
local order = 0
for name, preset in pairs(FogPresets) do
    order = order + 1
    local btn = Instance.new("TextButton", fogScroll)
    btn.Size = UDim2.new(1, -10, 0, 36)
    btn.BackgroundColor3 = preset.Color
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.LayoutOrder = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function() setFog(name) end)
end
local clearBtn = Instance.new("TextButton", fogScroll)
clearBtn.Size = UDim2.new(1, -10, 0, 36)
clearBtn.BackgroundColor3 = Color3.fromRGB(200, 205, 215)
clearBtn.BorderSizePixel = 0
clearBtn.Text = "Clear Fog"
clearBtn.TextColor3 = TEXT_DARK
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 14
clearBtn.LayoutOrder = 999
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 8)
clearBtn.MouseButton1Click:Connect(function() clearFog() end)

-- ============ SILENT AIM PAGE ============
local saToggleRow = makeRow(SilentAimPage, "Enable Silent Aim", 15)
makeToggle(saToggleRow, false, function(s) silentAimEnabled = s end)

local fovRow = makeRow(SilentAimPage, "FOV (px)", 70)
makeSlider(fovRow, 50, 1000, silentAimFOV, 10, function(v) silentAimFOV = v end)

local aimPartRow = makeRow(SilentAimPage, "Target Part", 125)
makeDropdown(aimPartRow, {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}, silentAimPart, function(v) silentAimPart = v end)

-- ============ CAMLOCK PAGE ============
local clToggleRow = makeRow(CamlockPage, "Enable Camlock", 15)
makeToggle(clToggleRow, false, function(s)
    camlockEnabled = s
    if not s then camlockTarget = nil end
end)

local smoothRow = makeRow(CamlockPage, "Camlock Smoothness", 70)
makeSlider(smoothRow, 0.05, 1.0, camlockSmoothness, 0.05, function(v) camlockSmoothness = v end)

makeRow(CamlockPage, "Target: Closest to Crosshair", 125)

-- ============ ESP PAGE ============
local espToggleRow = makeRow(ESPPage, "Enable ESP", 15)
makeToggle(espToggleRow, false, function(s) espEnabled = s; if not s then clearESP() end end)

local espColorRow = makeRow(ESPPage, "ESP Color", 70)
makeColorPicker(espColorRow, espColor, function(c) espColor = c end)

local espModeRow = makeRow(ESPPage, "ESP Mode", 125)
makeDropdown(espModeRow, {"Name", "Box", "Skeleton", "Both"}, espMode, function(v) espMode = v end)

-- ============ WHITELIST PAGE ============
local wlScroll = Instance.new("ScrollingFrame", WhitelistPage)
wlScroll.Size = UDim2.new(1, -30, 1, -80)
wlScroll.Position = UDim2.new(0, 15, 0, 15)
wlScroll.BackgroundTransparency = 1
wlScroll.BorderSizePixel = 0
wlScroll.ScrollBarThickness = 6
wlScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
wlScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local wll = Instance.new("UIListLayout", wlScroll)
wll.Padding = UDim.new(0, 6); wll.SortOrder = Enum.SortOrder.LayoutOrder

local function refreshWhitelist()
    for _, c in ipairs(wlScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local o = 0
    for id, _ in pairs(whitelist) do
        o = o + 1
        local row = Instance.new("Frame", wlScroll)
        row.Size = UDim2.new(1, -10, 0, 32)
        row.BackgroundColor3 = BG_SIDEBAR
        row.BorderSizePixel = 0
        row.LayoutOrder = o
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(id)
        lbl.TextColor3 = TEXT_DARK
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        local rm = Instance.new("TextButton", row)
        rm.Size = UDim2.new(0, 24, 0, 24)
        rm.Position = UDim2.new(1, -30, 0.5, -12)
        rm.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
        rm.BorderSizePixel = 0
        rm.Text = "X"
        rm.TextColor3 = Color3.new(1,1,1)
        rm.Font = Enum.Font.GothamBold
        rm.TextSize = 12
        Instance.new("UICorner", rm).CornerRadius = UDim.new(0, 4)
        rm.MouseButton1Click:Connect(function()
            whitelist[id] = nil
            refreshWhitelist()
        end)
    end
end

local wlInput = Instance.new("TextBox", WhitelistPage)
wlInput.Size = UDim2.new(1, -120, 0, 36)
wlInput.Position = UDim2.new(0, 15, 1, -50)
wlInput.BackgroundColor3 = BG_SIDEBAR
wlInput.BorderSizePixel = 0
wlInput.Text = ""
wlInput.PlaceholderText = "Enter Player Name or UserId"
wlInput.TextColor3 = TEXT_DARK
wlInput.Font = Enum.Font.Gotham
wlInput.TextSize = 12
wlInput.ClearTextOnFocus = false
Instance.new("UICorner", wlInput).CornerRadius = UDim.new(0, 6)

local wlAddBtn = Instance.new("TextButton", WhitelistPage)
wlAddBtn.Size = UDim2.new(0, 90, 0, 36)
wlAddBtn.Position = UDim2.new(1, -105, 1, -50)
wlAddBtn.BackgroundColor3 = ACCENT
wlAddBtn.BorderSizePixel = 0
wlAddBtn.Text = "Add"
wlAddBtn.TextColor3 = Color3.new(1,1,1)
wlAddBtn.Font = Enum.Font.G