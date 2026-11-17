local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local hitboxEnabled, hitboxSize, hitboxTransparency = false, 20, 0.5
local hitboxColorName, hitboxColor = "Blue", Color3.fromRGB(173, 216, 230)
local silentAimEnabled, silentAimKeyHeld = false, false
local silentAimPart, silentAimFOV = "Head", 300
local camlockEnabled, camlockTarget, camlockSmoothness = false, nil, 0.25
local espEnabled, espColorName, espColor, espMode = false, "Blue", Color3.fromRGB(173, 216, 230), "Name"
local whitelist, speedEnabled, speedValue = {}, false, 16
local espDrawings = {}
local hasDrawing = pcall(function() local d = Drawing.new("Text"); d:Remove() end)

local keys = { uiToggle = Enum.KeyCode.RightShift, silentAim = Enum.KeyCode.V, camlock = Enum.KeyCode.C, speed = Enum.KeyCode.X }
local colorPresets = {
    ["Red"] = Color3.fromRGB(255, 70, 70), ["Pink"] = Color3.fromRGB(255, 105, 180), ["Blue"] = Color3.fromRGB(173, 216, 230),
    ["Cyan"] = Color3.fromRGB(0, 255, 255), ["Green"] = Color3.fromRGB(50, 255, 50), ["Purple"] = Color3.fromRGB(138, 43, 226),
    ["Orange"] = Color3.fromRGB(255, 140, 0), ["White"] = Color3.fromRGB(255, 255, 255)
}
local FogPresets = {
    ["Neon Red"] = {Color = Color3.fromRGB(255,70,70), Density = 0.45}, ["Deep Pink"] = {Color = Color3.fromRGB(255,20,147), Density = 0.48},
    ["Electric Blue"] = {Color = Color3.fromRGB(0,255,255), Density = 0.51}, ["Toxic Green"] = {Color = Color3.fromRGB(50,255,50), Density = 0.49},
    ["Void Purple"] = {Color = Color3.fromRGB(138,43,226), Density = 0.56}, ["Hell Orange"] = {Color = Color3.fromRGB(255,140,0), Density = 0.43},
}
local function isWhitelisted(p) return whitelist[p.UserId] or whitelist[p.Name] end

local function applyHitbox(p)
    if not hitboxEnabled or p == LocalPlayer or not p.Character or isWhitelisted(p) then return end
    local part = p.Character:FindFirstChild("HumanoidRootPart")
    if part and part:IsA("BasePart") then
        part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        part.Transparency = hitboxTransparency
        part.Color = hitboxColor
        part.CanCollide = false
        part.Material = Enum.Material.Neon
    end
end
local function clearHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local part = p.Character:FindFirstChild("HumanoidRootPart")
            if part then
                part.Size = Vector3.new(2,2,1); part.Transparency = 0; part.Color = Color3.new(1,1,1)
                part.CanCollide = true; part.Material = Enum.Material.Plastic
            end
        end
    end
end
RunService.RenderStepped:Connect(function() if hitboxEnabled then for _, p in ipairs(Players:GetPlayers()) do applyHitbox(p) end end end)

local Camera = Workspace.CurrentCamera
local function getAimTarget()
    if not silentAimEnabled or not silentAimKeyHeld then return nil end
    local closest, shortest = nil, silentAimFOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not isWhitelisted(p) then
            local part = p.Character:FindFirstChild(silentAimPart)
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < shortest then shortest = d; closest = part end
                end
            end
        end
    end
    return closest
end
pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__index
    setreadonly(mt, false)
    mt.__index = newcclosure(function(self, k)
        if k == "Hit" and silentAimEnabled and silentAimKeyHeld then
            local t = getAimTarget()
            if t then return CFrame.new(t.Position) end
        end
        return old(self, k)
    end)
    setreadonly(mt, true)
end)

local function findCamTarget()
    local mp = UserInputService:GetMouseLocation()
    local closest, shortest = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not isWhitelisted(p) then
            local h = p.Character:FindFirstChild("Head")
            if h then
                local sp, on = Camera:WorldToViewportPoint(h.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
                    if d < shortest then shortest = d; closest = p end
                end
            end
        end
    end
    return closest
end
RunService.RenderStepped:Connect(function()
    if not camlockEnabled then return end
    if not camlockTarget or not camlockTarget.Character or isWhitelisted(camlockTarget) then
        camlockTarget = findCamTarget(); return
    end
    local h = camlockTarget.Character:FindFirstChild("Head")
    if not h then camlockTarget = findCamTarget(); return end
    local cp = Camera.CFrame.Position
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(cp, cp + (h.Position - cp).Unit), camlockSmoothness)
end)

RunService.RenderStepped:Connect(function()
    if speedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speedValue end
    end
end)

local function clearESP()
    for _, d in pairs(espDrawings) do for _, v in pairs(d) do if v.Remove then v:Remove() end end end
    espDrawings = {}
end
RunService.RenderStepped:Connect(function()
    if not espEnabled or not hasDrawing then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h, hrp = p.Character:FindFirstChild("Head"), p.Character:FindFirstChild("HumanoidRootPart")
            if h and hrp then
                if not espDrawings[p.UserId] then espDrawings[p.UserId] = {name = Drawing.new("Text"), box = Drawing.new("Square")} end
                local d = espDrawings[p.UserId]
                local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                if on and sp.Z > 0 then
                    local col = isWhitelisted(p) and Color3.fromRGB(200,255,200) or espColor
                    d.name.Visible = (espMode == "Name" or espMode == "Both"); d.name.Text = p.Name; d.name.Color = col
                    d.name.Position = Vector2.new(sp.X, sp.Y - 30); d.name.Size = 14; d.name.Center = true
                    d.box.Visible = (espMode == "Box" or espMode == "Both"); d.box.Color = col
                    d.box.Thickness = 1; d.box.Position = Vector2.new(sp.X - 20, sp.Y - 30); d.box.Size = Vector2.new(40, 60)
                else d.name.Visible = false; d.box.Visible = false end
            end
        end
    end
end)

local function setFog(n)
    local p = FogPresets[n]; if not p then return end
    Lighting.FogColor = p.Color; Lighting.FogStart = 0; Lighting.FogEnd = 1000 * (1 - p.Density)
end
local function resetFog()
    Lighting.FogColor = Color3.fromRGB(192, 192, 192); Lighting.FogStart = 0; Lighting.FogEnd = 100000
end

pcall(function() if game.CoreGui:FindFirstChild("LucasEXE") then game.CoreGui.LucasEXE:Destroy() end end)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LucasEXE"; ScreenGui.ResetOnSpawn = false; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local BG_MAIN, BG_SIDEBAR, BG_HEADER = Color3.fromRGB(220, 240, 255), Color3.fromRGB(235, 245, 255), Color3.fromRGB(190, 225, 255)
local ACCENT, TEXT_DARK, LINE_CLR = Color3.fromRGB(160, 210, 255), Color3.fromRGB(40, 60, 80), Color3.fromRGB(180, 210, 240)
local FONT = Enum.Font.SourceSans

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 660, 0, 520); Main.Position = UDim2.new(0.5, -330, 0.5, -260)
Main.BackgroundColor3 = BG_MAIN; Main.BorderSizePixel = 0; Main.Active = true; Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)
local mstr = Instance.new("UIStroke", Main); mstr.Color = LINE_CLR; mstr.Thickness = 1

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 44); Header.BackgroundColor3 = BG_HEADER; Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 300, 1, 0); Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1; Title.Text = "LUCAS.EXE"; Title.TextColor3 = TEXT_DARK; Title.Font = FONT
Title.TextSize = 20; Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 30, 0, 30); CloseBtn.Position = UDim2.new(1, -40, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 150); CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"; CloseBtn.TextColor3 = Color3.new(1,1,1); CloseBtn.Font = FONT; CloseBtn.TextSize = 14
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 10)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 170, 1, -44); Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.BackgroundColor3 = BG_SIDEBAR; Sidebar.BorderSizePixel = 0
local sl = Instance.new("UIListLayout", Sidebar); sl.Padding = UDim.new(0, 6); sl.SortOrder = Enum.SortOrder.LayoutOrder
local sp = Instance.new("UIPadding", Sidebar); sp.PaddingTop = UDim.new(0,12); sp.PaddingLeft = UDim.new(0,10); sp.PaddingRight = UDim.new(0,10)
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 16)

local Content = Instance.new("Frame", Main)
Content.Size = UDim2.new(1, -170, 1, -44); Content.Position = UDim2.new(0, 170, 0, 44)
Content.BackgroundTransparency = 1

local pages = {}
local function makePage(n)
    local p = Instance.new("Frame"); p.Name = n; p.Size = UDim2.new(1,0,1,0); p.BackgroundTransparency = 1
    p.Visible = false; p.Parent = Content; pages[n] = p; return p
end
local HitboxPage, FogPage, SilentAimPage = makePage("Hitbox"), makePage("Fog"), makePage("SilentAim")
local CamlockPage, ESPPage, WhitelistPage = makePage("Camlock"), makePage("ESP"), makePage("Whitelist")
local SpeedPage, KeybindPage, ConfigPage = makePage("Speed"), makePage("Keybind"), makePage("Config")

local sidebarButtons = {}
local function selectTab(btn, page)
    for _, b in ipairs(sidebarButtons) do b.BackgroundColor3 = BG_SIDEBAR end
    btn.BackgroundColor3 = BG_MAIN
    for _, p in ipairs(Content:GetChildren()) do if p:IsA("Frame") then p.Visible = (p == page) end end
end
local function makeSidebarButton(n, o, page)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(1,0,0,34); btn.BackgroundColor3 = BG_SIDEBAR; btn.BorderSizePixel = 0
    btn.Text = "  "..n; btn.TextColor3 = TEXT_DARK; btn.Font = FONT; btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left; btn.LayoutOrder = o
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)
    btn.MouseButton1Click:Connect(function() selectTab(btn, page) end)
    table.insert(sidebarButtons, btn); return btn
end

local hitboxTab = makeSidebarButton("Hitbox", 1, HitboxPage)
makeSidebarButton("Fog Changer", 2, FogPage)
makeSidebarButton("Silent Aim", 3, SilentAimPage)
makeSidebarButton("Camlock", 4, CamlockPage)
makeSidebarButton("ESP", 5, ESPPage)
makeSidebarButton("Whitelist", 6, WhitelistPage)
makeSidebarButton("Speed Master", 7, SpeedPage)
makeSidebarButton("Keybinds", 8, KeybindPage)
makeSidebarButton("Config", 9, ConfigPage)

local function makeRow(parent, labelText, yPos)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,-30,0,44); row.Position = UDim2.new(0,15,0,yPos)
    row.BackgroundColor3 = BG_SIDEBAR; row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-140,1,0); lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = TEXT_DARK
    lbl.Font = FONT; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left
    return row
end

local function makeToggle(row, init, cb)
    local state = init
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0,50,0,26); btn.Position = UDim2.new(1,-62,0.5,-13)
    btn.BackgroundColor3 = state and ACCENT or Color3.fromRGB(210,220,230); btn.BorderSizePixel = 0; btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame", btn)
    knob.Size = UDim2.new(0,20,0,20); knob.Position = state and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)
    knob.BackgroundColor3 = Color3.new(1,1,1); knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and ACCENT or Color3.fromRGB(210,220,230)
        knob:TweenPosition(state and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        cb(state)
    end)
end

local function makeSlider(row, min, max, init, step, cb)
    local holder = Instance.new("Frame", row)
    holder.Size = UDim2.new(0,140,0,24); holder.Position = UDim2.new(1,-160,0.5,-12)
    holder.BackgroundColor3 = Color3.fromRGB(210,220,230); holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", holder)
    fill.Size = UDim2.new((init-min)/(max-min),0,1,0); fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame", holder)
    knob.Size = UDim2.new(0,14,0,14); knob.Position = UDim2.new((init-min)/(max-min),-7,0.5,-7)
    knob.BackgroundColor3 = Color3.new(1,1,1); knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local val = Instance.new("TextLabel", row)
    val.Size = UDim2.new(0,50,0,20); val.Position = UDim2.new(1,-62,0.5,-10)
    val.BackgroundTransparency = 1; val.Text = tostring(init); val.TextColor3 = TEXT_DARK
    val.Font = FONT; val.TextSize = 14
    local drag = false
    local function update(x)
        local rel = math.clamp((x - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + (max-min)*rel)/step + 0.5)*step
        fill.Size = UDim2.new((v-min)/(max-min),0,1,0); knob.Position = UDim2.new((v-min)/(max-min),-7,0.5,-7)
        val.Text = tostring(v); cb(v)
    end
    knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then update(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    holder.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; update(i.Position.X) end end)
end

local function makeDropdown(row, opts, init, cb)
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0,110,0,28); btn.Position = UDim2.new(1,-122,0.5,-14)
    btn.BackgroundColor3 = Color3.fromRGB(240,250,255); btn.BorderSizePixel = 0
    btn.Text = init; btn.TextColor3 = TEXT_DARK; btn.Font = FONT; btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    local idx = 1
    for i,o in ipairs(opts) do if o == init then idx = i; break end end
    btn.MouseButton1Click:Connect(function()
        idx = idx + 1; if idx > #opts then idx = 1 end
        btn.Text = opts[idx]; cb(opts[idx])
    end)
end

local function makeKeybindRow(page, labelText, keyName, yPos)
    local row = makeRow(page, labelText, yPos)
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0,100,0,28); btn.Position = UDim2.new(1,-112,0.5,-14)
    btn.BackgroundColor3 = Color3.fromRGB(240,250,255); btn.BorderSizePixel = 0
    btn.Text = keys[keyName].Name; btn.TextColor3 = TEXT_DARK; btn.Font = FONT; btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    btn.MouseButton1Click:Connect(function()
        btn.Text = "[Press Key]"
        local conn; conn = UserInputService.InputBegan:Connect(function(input, proc)
            if proc or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            keys[keyName] = input.KeyCode; btn.Text = input.KeyCode.Name; conn:Disconnect()
        end)
    end)
end
makeToggle(makeRow(HitboxPage, "Enable Hitbox Expander", 15), false, function(s) hitboxEnabled = s; if not s then clearHitboxes() end end)
makeSlider(makeRow(HitboxPage, "Hitbox Size", 70), 2, 100, hitboxSize, 1, function(v) hitboxSize = v end)
makeSlider(makeRow(HitboxPage, "Hitbox Transparency", 125), 0, 1, hitboxTransparency, 0.05, function(v) hitboxTransparency = v end)
makeDropdown(makeRow(HitboxPage, "Hitbox Color", 180), {"Red", "Pink", "Blue", "Cyan", "Green", "Purple", "Orange", "White"}, hitboxColorName, function(v) hitboxColorName = v; hitboxColor = colorPresets[v] end)

local fogScroll = Instance.new("ScrollingFrame", FogPage)
fogScroll.Size = UDim2.new(1,-30,1,-30); fogScroll.Position = UDim2.new(0,15,0,15)
fogScroll.BackgroundTransparency = 1; fogScroll.BorderSizePixel = 0; fogScroll.ScrollBarThickness = 6
fogScroll.CanvasSize = UDim2.new(0,0,0,0); fogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local fl = Instance.new("UIListLayout", fogScroll); fl.Padding = UDim.new(0,8); fl.SortOrder = Enum.SortOrder.LayoutOrder
local o = 0
for name, p in pairs(FogPresets) do
    o = o + 1
    local btn = Instance.new("TextButton", fogScroll)
    btn.Size = UDim2.new(1,-10,0,36); btn.BackgroundColor3 = p.Color; btn.BorderSizePixel = 0
    btn.Text = name; btn.TextColor3 = Color3.new(1,1,1); btn.Font = FONT; btn.TextSize = 14; btn.LayoutOrder = o
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)
    btn.MouseButton1Click:Connect(function() setFog(name) end)
end
local clearBtn = Instance.new("TextButton", fogScroll)
clearBtn.Size = UDim2.new(1,-10,0,36); clearBtn.BackgroundColor3 = Color3.fromRGB(210,220,230); clearBtn.BorderSizePixel = 0
clearBtn.Text = "Reset Fog"; clearBtn.TextColor3 = TEXT_DARK; clearBtn.Font = FONT; clearBtn.TextSize = 14; clearBtn.LayoutOrder = 999
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0,10)
clearBtn.MouseButton1Click:Connect(function() resetFog() end)

makeToggle(makeRow(SilentAimPage, "Enable Silent Aim", 15), false, function(s) silentAimEnabled = s end)
makeSlider(makeRow(SilentAimPage, "FOV (px)", 70), 50, 1000, silentAimFOV, 10, function(v) silentAimFOV = v end)
makeDropdown(makeRow(SilentAimPage, "Target Part", 125), {"Head","HumanoidRootPart","UpperTorso","LowerTorso"}, silentAimPart, function(v) silentAimPart = v end)

makeToggle(makeRow(CamlockPage, "Enable Camlock", 15), false, function(s) camlockEnabled = s; if not s then camlockTarget = nil end end)
makeSlider(makeRow(CamlockPage, "Camlock Smoothness", 70), 0.05, 1.0, camlockSmoothness, 0.05, function(v) camlockSmoothness = v end)

makeToggle(makeRow(ESPPage, "Enable ESP", 15), false, function(s) espEnabled = s; if not s then clearESP() end end)
makeDropdown(makeRow(ESPPage, "ESP Color", 70), {"Red", "Pink", "Blue", "Cyan", "Green", "Purple", "Orange", "White"}, espColorName, function(v) espColorName = v; espColor = colorPresets[v] end)
makeDropdown(makeRow(ESPPage, "ESP Mode", 125), {"Name","Box","Skeleton","Both"}, espMode, function(v) espMode = v end)

local wlScroll = Instance.new("ScrollingFrame", WhitelistPage)
wlScroll.Size = UDim2.new(1,-30,1,-30); wlScroll.Position = UDim2.new(0,15,0,15)
wlScroll.BackgroundTransparency = 1; wlScroll.BorderSizePixel = 0; wlScroll.ScrollBarThickness = 6
wlScroll.CanvasSize = UDim2.new(0,0,0,0); wlScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local wll = Instance.new("UIListLayout", wlScroll); wll.Padding = UDim.new(0,6); wll.SortOrder = Enum.SortOrder.LayoutOrder
local function refreshWhitelist()
    for _, c in ipairs(wlScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            n = n + 1
            local row = Instance.new("Frame", wlScroll)
            row.Size = UDim2.new(1,-10,0,32); row.BackgroundColor3 = BG_SIDEBAR; row.BorderSizePixel = 0; row.LayoutOrder = n
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)
            local lbl = Instance.new("TextLabel", row)
            lbl.Size = UDim2.new(1,-80,1,0); lbl.Position = UDim2.new(0,10,0,0)
            lbl.BackgroundTransparency = 1; lbl.Text = p.Name.." ("..p.UserId..")"
            lbl.TextColor3 = TEXT_DARK; lbl.Font = FONT; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left
            local t = Instance.new("TextButton", row)
            t.Size = UDim2.new(0,60,0,24); t.Position = UDim2.new(1,-70,0.5,-12)
            t.BackgroundColor3 = whitelist[p.UserId] and Color3.fromRGB(200,255,200) or Color3.fromRGB(255,200,200)
            t.BorderSizePixel = 0; t.Text = whitelist[p.UserId] and "ON" or "OFF"
            t.TextColor3 = TEXT_DARK; t.Font = FONT; t.TextSize = 14
            Instance.new("UICorner", t).CornerRadius = UDim.new(0,6)
            t.MouseButton1Click:Connect(function()
                if whitelist[p.UserId] then whitelist[p.UserId] = nil else whitelist[p.UserId] = true end
                refreshWhitelist()
            end)
        end
    end
end
refreshWhitelist()
Players.PlayerAdded:Connect(function() task.wait(1); refreshWhitelist() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshWhitelist() end)

makeToggle(makeRow(SpeedPage, "Enable Speed Master", 15), false, function(s)
    speedEnabled = s
    if not s and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end)
makeSlider(makeRow(SpeedPage, "Speed Value", 70), 16, 200, speedValue, 1, function(v) speedValue = v end)

makeKeybindRow(KeybindPage, "UI Toggle", "uiToggle", 15)
makeKeybindRow(KeybindPage, "Silent Aim", "silentAim", 70)
makeKeybindRow(KeybindPage, "Camlock", "camlock", 125)
makeKeybindRow(KeybindPage, "Speed Master", "speed", 180)

local configList, activeConfig = {"Default"}, "Default"
pcall(function() for _, f in ipairs(listfiles(".")) do if f:match("LucasEXE_") and f:match("%.json$") then table.insert(configList, f:gsub("LucasEXE_", ""):gsub("%.json", "")) end end end)

local nameBox = Instance.new("TextBox", ConfigPage)
nameBox.Size = UDim2.new(0, 200, 0, 30); nameBox.Position = UDim2.new(0.5, -100, 0, 15)
nameBox.BackgroundColor3 = Color3.fromRGB(240, 250, 255); nameBox.BorderSizePixel = 0
nameBox.Text = "Default"; nameBox.PlaceholderText = "Config Name"
nameBox.TextColor3 = TEXT_DARK; nameBox.Font = FONT; nameBox.TextSize = 14
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0,8)

local saveBtn = Instance.new("TextButton", ConfigPage)
saveBtn.Size = UDim2.new(0, 200, 0, 35); saveBtn.Position = UDim2.new(0.5, -100, 0, 55)
saveBtn.BackgroundColor3 = ACCENT; saveBtn.BorderSizePixel = 0
saveBtn.Text = "Save Config"; saveBtn.TextColor3 = TEXT_DARK; saveBtn.Font = FONT; saveBtn.TextSize = 14
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0,8)

local loadDropdown = Instance.new("TextButton", ConfigPage)
loadDropdown.Size = UDim2.new(0, 200, 0, 35); loadDropdown.Position = UDim2.new(0.5, -100, 0, 110)
loadDropdown.BackgroundColor3 = Color3.fromRGB(240, 250, 255); loadDropdown.BorderSizePixel = 0
loadDropdown.Text = "Load: Default"; loadDropdown.TextColor3 = TEXT_DARK; loadDropdown.Font = FONT; loadDropdown.TextSize = 14
Instance.new("UICorner", loadDropdown).CornerRadius = UDim.new(0,8)

local loadBtn = Instance.new("TextButton", ConfigPage)
loadBtn.Size = UDim2.new(0, 200, 0, 35); loadBtn.Position = UDim2.new(0.5, -100, 0, 155)
loadBtn.BackgroundColor3 = ACCENT; loadBtn.BorderSizePixel = 0
loadBtn.Text = "Apply Loaded Config"; loadBtn.TextColor3 = TEXT_DARK; loadBtn.Font = FONT; loadBtn.TextSize = 14
Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0,8)

local dropIdx = 1
loadDropdown.MouseButton1Click:Connect(function()
    dropIdx = dropIdx + 1; if dropIdx > #configList then dropIdx = 1 end
    activeConfig = configList[dropIdx]; loadDropdown.Text = "Load: " .. activeConfig
end)

saveBtn.MouseButton1Click:Connect(function()
    local cName = nameBox.Text ~= "" and nameBox.Text or "Default"
    local data = {hitbox = {size = hitboxSize, trans = hitboxTransparency, col = hitboxColorName}, esp = {col = espColorName, mode = espMode}, silent = {fov = silentAimFOV, part = silentAimPart}, cam = {smooth = camlockSmoothness}, speed = {val = speedValue}, binds = {ui = keys.uiToggle.Name, aim = keys.silentAim.Name, cam = keys.camlock.Name, spd = keys.speed.Name}}
    if writefile then writefile("LucasEXE_" .. cName .. ".json", HttpService:JSONEncode(data)); saveBtn.Text = "Saved!"; task.wait(1); saveBtn.Text = "Save Config"
        if not table.find(configList, cName) then table.insert(configList, cName) end
    end
end)
