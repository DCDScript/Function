local executeUI = "DecodeAntiMultiUi"

if _G[executeUI] then
    warn("Decode: UI already running.")
    return
end

_G[executeUI] = true

local Decode = {}

local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local env = getfenv()
local listfiles = env["listfiles"]
local setclipboard =  env["setclipboard"] or env["toclipboard"]
local getcustomasset = env.getcustomasset or function() return "" end
local isfile = env.isfile or function() return false end
local isfolder = env.isfolder or function() return false end
local makefolder = env.makefolder or function() end
local readfile = env.readfile or function() return "" end
local writefile = env.writefile or function() end
local folderPath = "Decode by ItzYumi"
local assetFolder = "Decode by ItzYumi/Assets"
local assetPath = assetFolder .. "/icon.png"
local filePath = folderPath .. "/Save System/Steal an Egg/config.json"

local Configurations = { 
    SpeedEnabled = false,
    Speed = 0,
    NoClipEnabled = false,
    InfiniteJumpEnabled = false,
    AntiAfkToggleState = true,
    RejoinToggleState = true,
    ExecuteToggleState = false,
    InputConfig = "",
    InputConfigFile = "",
    SelectedCopyConfig = {},
    HopDelayValue = 0,
    HopSelection = "Low",
    HopEnabled = false,
    HopTargetVersion = 0,
    StealEgg = false,
    
    MainHue = {10, 18, 30},
    SidebarHue = {15, 27, 44},
    AccentHue = {14, 165, 233},
    ElementHue = {22, 38, 62},
    TextMainHue = {255, 255, 255},
    TextMutedHue = {140, 160, 185}
}

local UI = {
    Tabs = {},
    FirstTab = nil,
    PageList = {"Home", "Main", "Assist", "Shop", "Misc", "Settings"},
    CreatedPages = {},
    PlayerTracker = { OriginalSpeed = 16 }
}

Decode.Theme = {
    MainBackground = Color3.fromRGB(unpack(Configurations.MainHue)),
    SidebarBackground = Color3.fromRGB(unpack(Configurations.SidebarHue)),
    AccentColor = Color3.fromRGB(unpack(Configurations.AccentHue)),
    ElementBackground = Color3.fromRGB(unpack(Configurations.ElementHue)),
    TextMain = Color3.fromRGB(unpack(Configurations.TextMainHue)),
    TextMuted = Color3.fromRGB(unpack(Configurations.TextMutedHue))
}

local function saveConfig()
    local success, str = pcall(function()
        return HttpService:JSONEncode(Configurations)
    end)
    if success and str then
        local split = string.split(filePath, "/")
        local currentPath = ""
        for i = 1, #split - 1 do
            currentPath = currentPath == "" and split[i] or currentPath .. "/" .. split[i]
            if not isfolder(currentPath) then
                makefolder(currentPath)
            end
        end
        writefile(filePath, str)
    end
end

local function loadConfig()
    if isfile(filePath) then
        local success, content = pcall(function()
            return readfile(filePath)
        end)
        if success and content then
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if decodeSuccess and type(data) == "table" then
                for k, v in pairs(data) do
                    if Configurations[k] ~= nil then
                        Configurations[k] = v
                    end
                end
            end
        end
    end
end

loadConfig()
_G.DecodeAPI = { Configs = Configurations }

if not isfolder(folderPath) then makefolder(folderPath) end
if not isfolder(assetFolder) then makefolder(assetFolder) end

if not isfile(assetPath) then
    pcall(function()
        local g = game
        local content = g["HttpGet"](g, "https://raw.githubusercontent.com/ItzYumi/Decode/refs/heads/main/de_code_logo.png")
        if content then
            writefile(assetPath, content)
        end
    end)
end

local function getEggsDescendants()
    local eggsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models"):WaitForChild("Eggs")
    local children = eggsFolder:GetChildren()
    
    local eggsList = {}
    
    for _, egg in ipairs(children) do
        if egg:IsA("Model") or egg:IsA("Folder") then
            table.insert(eggsList, egg.Name)
        end
    end
    
    return eggsList
end

UI.ScreenGui = Instance.new("ScreenGui")
UI.ScreenGui.Name = "Decode_UI"
UI.ScreenGui.ResetOnSpawn = false
UI.ScreenGui.Parent = CoreGui

UI.FrameMain = Instance.new("Frame")
UI.FrameMain.Name = "MainContainer"
UI.FrameMain.Size = UDim2.new(0, 520, 0, 340)
UI.FrameMain.Position = UDim2.new(0.5, -260, 0.5, -170)
UI.FrameMain.BackgroundColor3 = Decode.Theme.MainBackground
UI.FrameMain.BackgroundTransparency = 0.15
UI.FrameMain.BorderSizePixel = 0
UI.FrameMain.Active = true
UI.FrameMain.Draggable = true
UI.FrameMain.Parent = UI.ScreenGui

UI.CornerMain = Instance.new("UICorner")
UI.CornerMain.CornerRadius = UDim.new(0, 10)
UI.CornerMain.Parent = UI.FrameMain

UI.TopHeader = Instance.new("Frame")
UI.TopHeader.Name = "TopHeader"
UI.TopHeader.Size = UDim2.new(1, 0, 0, 35)
UI.TopHeader.BackgroundTransparency = 1
UI.TopHeader.Parent = UI.FrameMain

UI.TitleLabel = Instance.new("TextLabel")
UI.TitleLabel.Size = UDim2.new(0, 200, 1, 0)
UI.TitleLabel.Position = UDim2.new(0, 14, 0, 0)
UI.TitleLabel.BackgroundTransparency = 1
UI.TitleLabel.Text = "DECODE | v1.0.0 Beta"
UI.TitleLabel.TextColor3 = Decode.Theme.TextMuted
UI.TitleLabel.TextSize = 16
UI.TitleLabel.Font = Enum.Font.SourceSansBold
UI.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.TitleLabel.Parent = UI.TopHeader

UI.CloseButton = Instance.new("TextButton")
UI.CloseButton.Size = UDim2.new(0, 35, 0, 35)
UI.CloseButton.Position = UDim2.new(1, -40, 0, 0)
UI.CloseButton.BackgroundTransparency = 1
UI.CloseButton.Text = "X"
UI.CloseButton.TextColor3 = Decode.Theme.TextMuted
UI.CloseButton.TextSize = 14
UI.CloseButton.Font = Enum.Font.SourceSansBold
UI.CloseButton.Parent = UI.TopHeader

UI.MinimizeButton = Instance.new("TextButton")
UI.MinimizeButton.Size = UDim2.new(0, 35, 0, 35)
UI.MinimizeButton.Position = UDim2.new(1, -75, 0, 0)
UI.MinimizeButton.BackgroundTransparency = 1
UI.MinimizeButton.Text = "-"
UI.MinimizeButton.TextColor3 = Decode.Theme.TextMuted
UI.MinimizeButton.TextSize = 18
UI.MinimizeButton.Font = Enum.Font.SourceSansBold
UI.MinimizeButton.Parent = UI.TopHeader

UI.MinimizeLogo = Instance.new("ImageButton")
UI.MinimizeLogo.Name = "MinimizeLogo"
UI.MinimizeLogo.Size = UDim2.new(0, 40, 0, 40)
UI.MinimizeLogo.Position = UDim2.new(0.05, 0, 0.05, 0)
UI.MinimizeLogo.BackgroundColor3 = Decode.Theme.SidebarBackground
UI.MinimizeLogo.BackgroundTransparency = 0.2
UI.MinimizeLogo.Image = isfile(assetPath) and getcustomasset(assetPath) or ""
UI.MinimizeLogo.Visible = false
UI.MinimizeLogo.Active = true
UI.MinimizeLogo.Draggable = true
UI.MinimizeLogo.Parent = UI.ScreenGui

UI.LogoCorner = Instance.new("UICorner")
UI.LogoCorner.CornerRadius = UDim.new(1, 0)
UI.LogoCorner.Parent = UI.MinimizeLogo

UI.LogoStroke = Instance.new("UIStroke")
UI.LogoStroke.Color = Decode.Theme.MainBackground
UI.LogoStroke.Thickness = 2
UI.LogoStroke.Parent = UI.MinimizeLogo

UI.MinimizeButton.MouseButton1Click:Connect(function()
    UI.FrameMain.Visible = false
    UI.MinimizeLogo.Visible = true
end)

UI.MinimizeLogo.MouseButton1Click:Connect(function()
    UI.MinimizeLogo.Visible = false
    UI.FrameMain.Visible = true
end)

UI.Sidebar = Instance.new("Frame")
UI.Sidebar.Name = "Sidebar"
UI.Sidebar.Size = UDim2.new(0, 160, 1, -35)
UI.Sidebar.Position = UDim2.new(0, 0, 0, 35)
UI.Sidebar.BackgroundColor3 = Decode.Theme.SidebarBackground
UI.Sidebar.BackgroundTransparency = 0.2
UI.Sidebar.BorderSizePixel = 0
UI.Sidebar.Parent = UI.FrameMain

UI.CornerSidebar = Instance.new("UICorner")
UI.CornerSidebar.CornerRadius = UDim.new(0, 10)
UI.CornerSidebar.Parent = UI.Sidebar

UI.NavScroll = Instance.new("ScrollingFrame")
UI.NavScroll.Size = UDim2.new(1, -12, 1, -20)
UI.NavScroll.Position = UDim2.new(0, 12, 0, 10)
UI.NavScroll.BackgroundTransparency = 1
UI.NavScroll.BorderSizePixel = 0
UI.NavScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.NavScroll.ScrollBarThickness = 0
UI.NavScroll.Parent = UI.Sidebar

UI.NavLayout = Instance.new("UIListLayout")
UI.NavLayout.Parent = UI.NavScroll
UI.NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.NavLayout.Padding = UDim.new(0, 4)

UI.NavLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UI.NavScroll.CanvasSize = UDim2.new(0, 0, 0, UI.NavLayout.AbsoluteContentSize.Y)
end)

UI.ContentContainer = Instance.new("Frame")
UI.ContentContainer.Name = "ContentContainer"
UI.ContentContainer.Size = UDim2.new(1, -185, 1, -50)
UI.ContentContainer.Position = UDim2.new(0, 175, 0, 40)
UI.ContentContainer.BackgroundTransparency = 1
UI.ContentContainer.Parent = UI.FrameMain

UI.PageHeaderLabel = Instance.new("TextLabel")
UI.PageHeaderLabel.Name = "PageHeaderLabel"
UI.PageHeaderLabel.Size = UDim2.new(1, 0, 0, 30)
UI.PageHeaderLabel.Position = UDim2.new(0, 0, 0, -5)
UI.PageHeaderLabel.BackgroundTransparency = 1
UI.PageHeaderLabel.Text = "Home"
UI.PageHeaderLabel.TextColor3 = Decode.Theme.TextMain
UI.PageHeaderLabel.TextSize = 22
UI.PageHeaderLabel.Font = Enum.Font.SourceSansBold
UI.PageHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.PageHeaderLabel.Parent = UI.ContentContainer

UI.NotifyContainer = Instance.new("Frame")
UI.NotifyContainer.Name = "NotificationContainer"
UI.NotifyContainer.Size = UDim2.new(0, 280, 0, 400)
UI.NotifyContainer.Position = UDim2.new(1, -290, 0, 20)
UI.NotifyContainer.BackgroundTransparency = 1
UI.NotifyContainer.ZIndex = 9999
UI.NotifyContainer.Parent = UI.ScreenGui

local activeCards = {}
local maxCards = 3

function Decode:Notify(titleText, bodyText, isAlert)
    for idx = #activeCards, 1, -1 do
        local oldCard = activeCards[idx]
        if idx >= maxCards then
            table.remove(activeCards, idx)
            local dropTween = TweenService:Create(oldCard, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1.5, 0, 0, oldCard.Position.Y.Offset),
                BackgroundTransparency = 1
            })
            dropTween:Play()
            dropTween.Completed:Connect(function() oldCard:Destroy() end)
        else
            activeCards[idx + 1] = oldCard
            local targetY = idx * 68
            TweenService:Create(oldCard, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, targetY)
            }):Play()
        end
    end

    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(1, 0, 0, 56)
    Card.Position = UDim2.new(1.4, 0, 0, 0)
    Card.BackgroundColor3 = Decode.Theme.SidebarBackground
    Card.BackgroundTransparency = 0.1
    Card.BorderSizePixel = 0
    Card.ZIndex = 10000
    Card.Parent = UI.NotifyContainer

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 6)
    CardCorner.Parent = Card

    local GlowBar = Instance.new("Frame")
    GlowBar.Size = UDim2.new(0, 4, 1, 0)
    GlowBar.Position = UDim2.new(0, 0, 0, 0)
    GlowBar.BackgroundColor3 = isAlert and Color3.fromRGB(239, 68, 68) or Decode.Theme.AccentColor
    GlowBar.BorderSizePixel = 0
    GlowBar.ZIndex = 10001
    GlowBar.Parent = Card

    local GlowCorner = Instance.new("UICorner")
    GlowCorner.CornerRadius = UDim.new(0, 4)
    GlowCorner.Parent = GlowBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -20, 0, 20)
    TitleLabel.Position = UDim2.new(0, 14, 0, 8)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = tostring(titleText):upper()
    TitleLabel.TextColor3 = isAlert and Color3.fromRGB(252, 165, 165) or Decode.Theme.TextMain
    TitleLabel.TextSize = 11
    TitleLabel.Font = Enum.Font.SourceSansBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 10002
    TitleLabel.Parent = Card

    local BodyLabel = Instance.new("TextLabel")
    BodyLabel.Size = UDim2.new(1, -20, 0, 24)
    BodyLabel.Position = UDim2.new(0, 14, 0, 24)
    BodyLabel.BackgroundTransparency = 1
    BodyLabel.Text = bodyText
    BodyLabel.TextColor3 = Decode.Theme.TextMuted
    BodyLabel.TextSize = 13
    BodyLabel.Font = Enum.Font.SourceSans
    BodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    BodyLabel.TextWrapped = true
    BodyLabel.ZIndex = 10002
    BodyLabel.Parent = Card

    table.insert(activeCards, 1, Card)

    TweenService:Create(Card, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()

    task.delay(3.0, function()
        if Card and Card.Parent then
            local cardIndex = table.find(activeCards, Card)
            if cardIndex then table.remove(activeCards, cardIndex) end
            
            local exitTween = TweenService:Create(Card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1.4, 0, 0, Card.Position.Y.Offset),
                BackgroundTransparency = 1
            })
            exitTween:Play()
            exitTween.Completed:Connect(function() Card:Destroy() end)
        end
    end)
end

_G.PostMailboxTerminalAlert = function(title, body, isErr)
    Decode:Notify(title, body, isErr)
end

function Decode:CreateTab(tabName)
    local Temp = {}
    Temp.Page = Instance.new("ScrollingFrame")
    Temp.Page.Name = tabName .. "_Page"
    Temp.Page.Size = UDim2.new(1, 0, 1, -30)
    Temp.Page.Position = UDim2.new(0, 0, 0, 30)
    Temp.Page.BackgroundTransparency = 1
    Temp.Page.BorderSizePixel = 0
    Temp.Page.Visible = false
    Temp.Page.ScrollBarThickness = 0
    Temp.Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Temp.Page.Parent = UI.ContentContainer

    Temp.Layout = Instance.new("UIListLayout")
    Temp.Layout.Parent = Temp.Page
    Temp.Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Temp.Layout.Padding = UDim.new(0, 6)
    
    Temp.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Temp.Page.CanvasSize = UDim2.new(0, 0, 0, Temp.Layout.AbsoluteContentSize.Y + 10)
    end)

    Temp.Button = Instance.new("TextButton")
    Temp.Button.Name = tabName .. "_Btn"
    Temp.Button.Size = UDim2.new(1, 0, 0, 34)
    Temp.Button.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Button.BackgroundTransparency = 1
    Temp.Button.Text = "  " .. tabName
    Temp.Button.TextColor3 = Decode.Theme.TextMuted
    Temp.Button.TextSize = 14
    Temp.Button.Font = Enum.Font.SourceSansBold
    Temp.Button.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Button.Parent = UI.NavScroll

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Button

    UI.Tabs[tabName] = Temp

    Temp.Button.MouseButton1Click:Connect(function()
        for _, tab in pairs(UI.Tabs) do
            tab.Page.Visible = false
            tab.Button.BackgroundTransparency = 1
            tab.Button.TextColor3 = Decode.Theme.TextMuted
        end
        Temp.Page.Visible = true
        Temp.Button.BackgroundTransparency = 0.8
        Temp.Button.TextColor3 = Decode.Theme.TextMain
        UI.PageHeaderLabel.Text = tabName
    end)

    if not UI.FirstTab then
        UI.FirstTab = Temp
    end

    return Temp.Page
end

function Decode:CreateDropdown(parentPage, dropdownText)
    local Temp = {}
    Temp.Container = Instance.new("Frame")
    Temp.Container.Name = dropdownText .. "_DropdownContainer"
    Temp.Container.Size = UDim2.new(1, 0, 0, 36)
    Temp.Container.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Container.BackgroundTransparency = 0.4
    Temp.Container.ClipsDescendants = true
    Temp.Container.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Container

    Temp.Header = Instance.new("TextButton")
    Temp.Header.Name = "Header"
    Temp.Header.Size = UDim2.new(1, 0, 0, 36)
    Temp.Header.BackgroundTransparency = 1
    Temp.Header.Text = "  " .. dropdownText
    Temp.Header.TextColor3 = Decode.Theme.TextMain
    Temp.Header.TextSize = 14
    Temp.Header.Font = Enum.Font.SourceSansSemibold
    Temp.Header.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Header.Parent = Temp.Container

    Temp.Arrow = Instance.new("TextLabel")
    Temp.Arrow.Name = "Arrow"
    Temp.Arrow.Size = UDim2.new(0, 36, 0, 36)
    Temp.Arrow.Position = UDim2.new(1, -36, 0, 0)
    Temp.Arrow.BackgroundTransparency = 1
    Temp.Arrow.Text = ">"
    Temp.Arrow.TextColor3 = Decode.Theme.TextMuted
    Temp.Arrow.TextSize = 13
    Temp.Arrow.Font = Enum.Font.SourceSansBold
    Temp.Arrow.Parent = Temp.Header

    Temp.ItemsFrame = Instance.new("Frame")
    Temp.ItemsFrame.Name = "Items"
    Temp.ItemsFrame.Size = UDim2.new(1, -12, 1, -40)
    Temp.ItemsFrame.Position = UDim2.new(0, 6, 0, 40)
    Temp.ItemsFrame.BackgroundTransparency = 1
    Temp.ItemsFrame.Parent = Temp.Container

    Temp.Layout = Instance.new("UIListLayout")
    Temp.Layout.Parent = Temp.ItemsFrame
    Temp.Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Temp.Layout.Padding = UDim.new(0, 5)

    Temp.Open = false
    Temp.Header.MouseButton1Click:Connect(function()
        Temp.Open = not Temp.Open
        local targetHeight = Temp.Open and (Temp.Layout.AbsoluteContentSize.Y + 45) or 36
        local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(Temp.Container, info, {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(Temp.Arrow, info, {Rotation = Temp.Open and 90 or 0}):Play()
        
        task.wait(0.2)
        if Temp.Open and parentPage:IsA("ScrollingFrame") then
            parentPage.CanvasSize = UDim2.new(0, 0, 0, parentPage.UIListLayout.AbsoluteContentSize.Y + 10)
        end
    end)

    return Temp.ItemsFrame
end

function Decode:AddInput(parentPage, inputText, defaultValue, callback, subtext, placeholderText)
    local Temp = {}

    Temp.Frame = Instance.new("Frame")
    Temp.Frame.Size = UDim2.new(1, 0, 0, 36)
    Temp.Frame.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Frame.BackgroundTransparency = 0.6
    Temp.Frame.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Frame

    Temp.Label = Instance.new("TextLabel")
    Temp.Label.Size = UDim2.new(0, 180, subtext and 0.5 or 1, 0)
    Temp.Label.Position = UDim2.new(0, 10, 0, subtext and 2 or 0)
    Temp.Label.BackgroundTransparency = 1
    Temp.Label.Text = inputText
    Temp.Label.TextColor3 = Decode.Theme.TextMain
    Temp.Label.TextSize = 13
    Temp.Label.Font = Enum.Font.SourceSansBold
    Temp.Label.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Label.Parent = Temp.Frame

    if subtext then
        Temp.SubLabel = Instance.new("TextLabel")
        Temp.SubLabel.Size = UDim2.new(0, 220, 0.5, 0)
        Temp.SubLabel.Position = UDim2.new(0, 10, 0.5, -2)
        Temp.SubLabel.BackgroundTransparency = 1
        Temp.SubLabel.Text = subtext
        Temp.SubLabel.TextColor3 = Decode.Theme.TextMuted
        Temp.SubLabel.TextSize = 11
        Temp.SubLabel.Font = Enum.Font.SourceSans
        Temp.SubLabel.TextXAlignment = Enum.TextXAlignment.Left
        Temp.SubLabel.Parent = Temp.Frame
    end

    Temp.ValueBox = Instance.new("TextBox")
    Temp.ValueBox.Size = UDim2.new(0, 120, 0, 24)
    Temp.ValueBox.Position = UDim2.new(1, -130, 0.5, -12)
    Temp.ValueBox.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.ValueBox.Text = tostring(defaultValue or "")
    Temp.ValueBox.TextColor3 = Decode.Theme.TextMain
    Temp.ValueBox.TextSize = 12
    Temp.ValueBox.Font = Enum.Font.SourceSans
    Temp.ValueBox.ClearTextOnFocus = true
    Temp.ValueBox.PlaceholderText = placeholderText or ""
    Temp.ValueBox.PlaceholderColor3 = Decode.Theme.TextMuted
    Temp.ValueBox.TextWrapped = true
    Temp.ValueBox.Parent = Temp.Frame

    Temp.CornerBox = Instance.new("UICorner")
    Temp.CornerBox.CornerRadius = UDim.new(0, 4)
    Temp.CornerBox.Parent = Temp.ValueBox

    Temp.ValueBox.FocusLost:Connect(function()
        local currentText = Temp.ValueBox.Text
        if currentText == "" and defaultValue and defaultValue ~= "" then
            Temp.ValueBox.Text = tostring(defaultValue)
            currentText = defaultValue
        end
        if callback then
            callback(currentText)
        end
    end)

    return Temp
end

function Decode:AddNumInput(parentPage, sliderText, defaultValue, callback, subtext)
    local Temp = {}
    Temp.Frame = Instance.new("Frame")
    Temp.Frame.Size = UDim2.new(1, 0, 0, 36)
    Temp.Frame.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Frame.BackgroundTransparency = 0.6
    Temp.Frame.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Frame

    Temp.Label = Instance.new("TextLabel")
    Temp.Label.Size = UDim2.new(0, 180, subtext and 0.5 or 1, 0)
    Temp.Label.Position = UDim2.new(0, 10, 0, subtext and 2 or 0)
    Temp.Label.BackgroundTransparency = 1
    Temp.Label.Text = sliderText
    Temp.Label.TextColor3 = Decode.Theme.TextMain
    Temp.Label.TextSize = 13
    Temp.Label.Font = Enum.Font.SourceSansBold
    Temp.Label.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Label.Parent = Temp.Frame

    if subtext then
        Temp.SubLabel = Instance.new("TextLabel")
        Temp.SubLabel.Size = UDim2.new(0, 220, 0.5, 0)
        Temp.SubLabel.Position = UDim2.new(0, 10, 0.5, -2)
        Temp.SubLabel.BackgroundTransparency = 1
        Temp.SubLabel.Text = subtext
        Temp.SubLabel.TextColor3 = Decode.Theme.TextMuted
        Temp.SubLabel.TextSize = 11
        Temp.SubLabel.Font = Enum.Font.SourceSans
        Temp.SubLabel.TextXAlignment = Enum.TextXAlignment.Left
        Temp.SubLabel.Parent = Temp.Frame
    end

    Temp.ValueBox = Instance.new("TextBox")
    Temp.ValueBox.Size = UDim2.new(0, 55, 0, 24)
    Temp.ValueBox.Position = UDim2.new(1, -65, 0.5, -12)
    Temp.ValueBox.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.ValueBox.Text = tostring(defaultValue)
    Temp.ValueBox.TextColor3 = Decode.Theme.TextMain
    Temp.ValueBox.TextSize = 12
    Temp.ValueBox.Font = Enum.Font.SourceSansBold
    Temp.ValueBox.Parent = Temp.Frame

    Temp.CornerBox = Instance.new("UICorner")
    Temp.CornerBox.CornerRadius = UDim.new(0, 4)
    Temp.CornerBox.Parent = Temp.ValueBox
    
    Temp.ValueBox.FocusLost:Connect(function()
        local cleanText = Temp.ValueBox.Text:gsub("[^%d%.%-]", "")
        local num = tonumber(cleanText)
        if num and callback then
            Temp.ValueBox.Text = tostring(num)
            callback(num)
        elseif callback then
            Temp.ValueBox.Text = tostring(defaultValue)
            callback(defaultValue)
        end
    end)
    return Temp
end

function Decode:AddToggle(parentPage, toggleText, callback)
    local Temp = {}
    Temp.Frame = Instance.new("Frame")
    Temp.Frame.Name = toggleText .. "_ToggleFrame"
    Temp.Frame.Size = UDim2.new(1, 0, 0, 36)
    Temp.Frame.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Frame.BackgroundTransparency = 0.6
    Temp.Frame.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Frame

    Temp.Label = Instance.new("TextLabel")
    Temp.Label.Size = UDim2.new(1, -60, 1, 0)
    Temp.Label.Position = UDim2.new(0, 10, 0, 0)
    Temp.Label.BackgroundTransparency = 1
    Temp.Label.Text = toggleText
    Temp.Label.TextColor3 = Decode.Theme.TextMain
    Temp.Label.TextSize = 13
    Temp.Label.Font = Enum.Font.SourceSans
    Temp.Label.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Label.Parent = Temp.Frame

    Temp.SwitchBg = Instance.new("Frame")
    Temp.SwitchBg.Name = "ToggleSwitchBg"
    Temp.SwitchBg.Size = UDim2.new(0, 32, 0, 16)
    Temp.SwitchBg.Position = UDim2.new(1, -45, 0.5, -8)
    Temp.SwitchBg.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.SwitchBg.Parent = Temp.Frame

    Temp.SwitchCorner = Instance.new("UICorner")
    Temp.SwitchCorner.CornerRadius = UDim.new(1, 0)
    Temp.SwitchCorner.Parent = Temp.SwitchBg

    Temp.SliderNode = Instance.new("Frame")
    Temp.SliderNode.Name = "ToggleSliderNode"
    Temp.SliderNode.Size = UDim2.new(0, 12, 0, 12)
    Temp.SliderNode.Position = UDim2.new(0, 2, 0.5, -6)
    Temp.SliderNode.BackgroundColor3 = Decode.Theme.TextMuted
    Temp.SliderNode.Parent = Temp.SwitchBg

    Temp.NodeCorner = Instance.new("UICorner")
    Temp.NodeCorner.CornerRadius = UDim.new(1, 0)
    Temp.NodeCorner.Parent = Temp.SliderNode

    Temp.ClickBtn = Instance.new("TextButton")
    Temp.ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    Temp.ClickBtn.BackgroundTransparency = 1
    Temp.ClickBtn.Text = ""
    Temp.ClickBtn.Parent = Temp.Frame

    Temp.IsToggled = false

    function Temp:UpdateVisualState()
        if Temp.IsToggled then
            Temp.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
            Temp.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
        else
            Temp.SwitchBg.BackgroundColor3 = Decode.Theme.MainBackground
            Temp.SliderNode.BackgroundColor3 = Decode.Theme.TextMuted
        end
    end

    Temp.ClickBtn.MouseButton1Click:Connect(function()
        Temp.IsToggled = not Temp.IsToggled
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if Temp.IsToggled then
            game:GetService("TweenService"):Create(Temp.SwitchBg, info, {BackgroundColor3 = Decode.Theme.AccentColor}):Play()
            game:GetService("TweenService"):Create(Temp.SliderNode, info, {Position = UDim2.new(1, -14, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMain}):Play()
        else
            game:GetService("TweenService"):Create(Temp.SwitchBg, info, {BackgroundColor3 = Decode.Theme.MainBackground}):Play()
            game:GetService("TweenService"):Create(Temp.SliderNode, info, {Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMuted}):Play()
        end
        if callback then callback(Temp.IsToggled) end
    end)

    return Temp
end

function Decode:AddLabel(parentPage, text)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 24)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Decode.Theme.TextMuted
    Label.TextSize = 13
    Label.Font = Enum.Font.SourceSansBold
    Label.TextXAlignment = Enum.TextXAlignment.Center
    Label.Parent = parentPage
end

function Decode:AddSelector(parentPage, text, options, onSelect, showAll, showNormal)
    local Temp = {}
    Temp.Frame = Instance.new("Frame")
    Temp.Frame.Size = UDim2.new(1, 0, 0, 36)
    Temp.Frame.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Frame.BackgroundTransparency = 0.6
    Temp.Frame.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Frame

    Temp.Label = Instance.new("TextLabel")
    Temp.Label.Size = UDim2.new(0, 150, 1, 0)
    Temp.Label.Position = UDim2.new(0, 10, 0, 0)
    Temp.Label.BackgroundTransparency = 1
    Temp.Label.Text = text
    Temp.Label.TextColor3 = Decode.Theme.TextMain
    Temp.Label.TextSize = 13
    Temp.Label.Font = Enum.Font.SourceSansBold
    Temp.Label.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Label.Parent = Temp.Frame

    Temp.SelectBtn = Instance.new("TextButton")
    Temp.SelectBtn.Size = UDim2.new(0, 120, 0, 26)
    Temp.SelectBtn.Position = UDim2.new(1, -130, 0.5, -13)
    Temp.SelectBtn.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.SelectBtn.Text = "Select Options"
    Temp.SelectBtn.TextColor3 = Decode.Theme.TextMuted
    Temp.SelectBtn.TextSize = 12
    Temp.SelectBtn.Font = Enum.Font.SourceSans
    Temp.SelectBtn.Parent = Temp.Frame

    Temp.SelectCorner = Instance.new("UICorner")
    Temp.SelectCorner.CornerRadius = UDim.new(0, 6)
    Temp.SelectCorner.Parent = Temp.SelectBtn

    Temp.Popup = Instance.new("Frame")
    Temp.Popup.Size = UDim2.new(0, 160, 0, 240)
    Temp.Popup.Position = UDim2.new(1, -175, 0, 45)
    Temp.Popup.BackgroundColor3 = Decode.Theme.SidebarBackground
    Temp.Popup.BorderSizePixel = 0
    Temp.Popup.Visible = false
    Temp.Popup.ZIndex = 50
    Temp.Popup.Parent = UI.FrameMain

    Temp.PopupCorner = Instance.new("UICorner")
    Temp.PopupCorner.CornerRadius = UDim.new(0, 8)
    Temp.PopupCorner.Parent = Temp.Popup

    Temp.PopupStroke = Instance.new("UIStroke")
    Temp.PopupStroke.Color = Decode.Theme.MainBackground
    Temp.PopupStroke.Thickness = 1
    Temp.PopupStroke.Parent = Temp.Popup

    Temp.SearchBox = Instance.new("TextBox")
    Temp.SearchBox.Size = UDim2.new(1, -20, 0, 24)
    Temp.SearchBox.Position = UDim2.new(0, 10, 0, 10)
    Temp.SearchBox.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.SearchBox.Text = ""
    Temp.SearchBox.PlaceholderText = "Search"
    Temp.SearchBox.PlaceholderColor3 = Decode.Theme.TextMuted
    Temp.SearchBox.TextColor3 = Decode.Theme.TextMain
    Temp.SearchBox.TextSize = 12
    Temp.SearchBox.Font = Enum.Font.SourceSans
    Temp.SearchBox.ZIndex = 51
    Temp.SearchBox.Parent = Temp.Popup

    Temp.SearchCorner = Instance.new("UICorner")
    Temp.SearchCorner.CornerRadius = UDim.new(0, 4)
    Temp.SearchCorner.Parent = Temp.SearchBox

    Temp.Scroll = Instance.new("ScrollingFrame")
    Temp.Scroll.Size = UDim2.new(1, -10, 1, -50)
    Temp.Scroll.Position = UDim2.new(0, 5, 0, 45)
    Temp.Scroll.BackgroundTransparency = 1
    Temp.Scroll.BorderSizePixel = 0
    Temp.Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Temp.Scroll.ScrollBarThickness = 2
    Temp.Scroll.ScrollBarImageColor3 = Decode.Theme.AccentColor
    Temp.Scroll.ZIndex = 51
    Temp.Scroll.Parent = Temp.Popup

    Temp.Layout = Instance.new("UIListLayout")
    Temp.Layout.Padding = UDim.new(0, 4)
    Temp.Layout.Parent = Temp.Scroll

    Temp.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Temp.Scroll.CanvasSize = UDim2.new(0, 0, 0, Temp.Layout.AbsoluteContentSize.Y)
    end)

    function Temp:UpdateSelectionText(val)
        Temp.SelectBtn.TextWrapped = true
        if type(val) == "table" then
            if #val > 0 then
                local sortedTable = {}
                for _, item in ipairs(val) do table.insert(sortedTable, item) end
                table.sort(sortedTable)

                local textStr = ""
                for i, option in ipairs(sortedTable) do
                    textStr = textStr .. (i == 1 and "" or ", ") .. option
                end
                Temp.SelectBtn.Text = textStr
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMain
                Temp.SelectBtn.TextSize = #textStr > 22 and 10 or 12
            else
                Temp.SelectBtn.Text = "Select Options"
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMuted
                Temp.SelectBtn.TextSize = 12
            end
        else
            if val and val ~= "" then
                Temp.SelectBtn.Text = tostring(val)
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMain
                Temp.SelectBtn.TextSize = string.len(tostring(val)) > 22 and 10 or 12
            else
                Temp.SelectBtn.Text = "Select Options"
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMuted
                Temp.SelectBtn.TextSize = 12
            end
        end
        
        for _, btn in pairs(Temp.Scroll:GetChildren()) do
            if btn:IsA("TextButton") then
                local btnText = string.gsub(btn.Text, "^%s+", "")
                local currentSelected = Temp.SelectBtn.Text
                local isMatch = false
                
                if currentSelected == btnText then
                    isMatch = true
                else
                    for item in string.gmatch(currentSelected, "([^,]+)") do
                        if string.gsub(item, "^%s+", "") == btnText then
                            isMatch = true
                            break
                        end
                    end
                end

                if isMatch then
                    btn.BackgroundTransparency = 0.4
                else
                    btn.BackgroundTransparency = 1
                end
            end
        end
    end

    function Temp:Populate(list)
        for _, obj in pairs(Temp.Scroll:GetChildren()) do
            if obj:IsA("TextButton") then obj:Destroy() end
        end

        local fullList = {}
        if showAll == true then table.insert(fullList, "All") end
        if showNormal == true then table.insert(fullList, "Normal") end
        for _, optName in ipairs(list) do table.insert(fullList, optName) end

        for _, optName in ipairs(fullList) do
            local OptBtn = Instance.new("TextButton")
            OptBtn.Size = UDim2.new(1, -5, 0, 28)
            OptBtn.BackgroundColor3 = Decode.Theme.AccentColor
            OptBtn.BackgroundTransparency = 1
            OptBtn.Text = "  " .. optName
            OptBtn.TextColor3 = Decode.Theme.TextMain
            OptBtn.TextSize = 13
            OptBtn.Font = Enum.Font.SourceSans
            OptBtn.TextXAlignment = Enum.TextXAlignment.Left
            OptBtn.ZIndex = 52
            OptBtn.Parent = Temp.Scroll

            local OptCorner = Instance.new("UICorner")
            OptCorner.CornerRadius = UDim.new(0, 4)
            OptCorner.Parent = OptBtn

            local currentText = Temp.SelectBtn.Text
            local isInitiallyMatch = false
            if currentText == optName then
                isInitiallyMatch = true
            else
                for item in string.gmatch(currentText, "([^,]+)") do
                    if string.gsub(item, "^%s+", "") == optName then
                        isInitiallyMatch = true
                        break
                    end
                end
            end

            if isInitiallyMatch then
                OptBtn.BackgroundTransparency = 0.4
            end

            OptBtn.MouseButton1Click:Connect(function()
                if onSelect then
                    onSelect(optName, Temp)
                else
                    if Temp.SelectBtn.Text == optName then
                        Temp:UpdateSelectionText("")
                    else
                        Temp:UpdateSelectionText(optName)
                    end
                end
            end)
        end
    end

    if options then Temp:Populate(options) end

    Temp.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(Temp.SearchBox.Text)
        for _, btn in pairs(Temp.Scroll:GetChildren()) do
            if btn:IsA("TextButton") then
                if query == "" or string.find(string.lower(btn.Text), query) then
                    btn.Visible = true
                else
                    btn.Visible = false
                end
            end
        end
    end)

    local UserInputService = game:GetService("UserInputService")
    
    Temp.SelectBtn.MouseButton1Click:Connect(function()
        Temp.Popup.Visible = not Temp.Popup.Visible
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if Temp.Popup.Visible then
                local pos = input.Position
                local popupPos = Temp.Popup.AbsolutePosition
                local popupSize = Temp.Popup.AbsoluteSize
                local btnPos = Temp.SelectBtn.AbsolutePosition
                local btnSize = Temp.SelectBtn.AbsoluteSize

                local inPopup = pos.X >= popupPos.X and pos.X <= (popupPos.X + popupSize.X) and pos.Y >= popupPos.Y and pos.Y <= (popupPos.Y + popupSize.Y)
                local inBtn = pos.X >= btnPos.X and pos.X <= (btnPos.X + btnSize.X) and pos.Y >= btnPos.Y and pos.Y <= (btnPos.Y + btnSize.Y)

                if not inPopup and not inBtn then
                    Temp.Popup.Visible = false
                end
            end
        end
    end)
    
    return Temp
end

function Decode:AddButton(parentPage, buttonText)
    local Temp = {}
    
    Temp.Button = Instance.new("TextButton")
    Temp.Button.Size = UDim2.new(1, 0, 0, 36)
    Temp.Button.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Button.BackgroundTransparency = 0.6
    Temp.Button.Text = buttonText
    Temp.Button.TextColor3 = Decode.Theme.TextMain
    Temp.Button.TextSize = 13
    Temp.Button.Font = Enum.Font.SourceSansBold
    Temp.Button.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Button

    return Temp.Button
end

for _, name in ipairs(UI.PageList) do
    UI.CreatedPages[name] = Decode:CreateTab(name)
end

UI.DiscordDrop = Decode:CreateDropdown(UI.CreatedPages["Home"], "Discord")

UI.DiscordRow = Instance.new("Frame")
UI.DiscordRow.Name = "DiscordInviteRow"
UI.DiscordRow.Size = UDim2.new(1, 0, 0, 36)
UI.DiscordRow.BackgroundColor3 = Decode.Theme.ElementBackground
UI.DiscordRow.BackgroundTransparency = 0.6
UI.DiscordRow.Parent = UI.DiscordDrop

UI.DiscordRowCorner = Instance.new("UICorner")
UI.DiscordRowCorner.CornerRadius = UDim.new(0, 6)
UI.DiscordRowCorner.Parent = UI.DiscordRow

UI.DiscordLabel = Instance.new("TextLabel")
UI.DiscordLabel.Size = UDim2.new(0, 150, 1, 0)
UI.DiscordLabel.Position = UDim2.new(0, 10, 0, 0)
UI.DiscordLabel.BackgroundTransparency = 1
UI.DiscordLabel.Text = "Discord Invite"
UI.DiscordLabel.TextColor3 = Decode.Theme.TextMain
UI.DiscordLabel.TextSize = 13
UI.DiscordLabel.Font = Enum.Font.SourceSans
UI.DiscordLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.DiscordLabel.Parent = UI.DiscordRow

UI.CopyButton = Instance.new("TextButton")
UI.CopyButton.Name = "CopyBtn"
UI.CopyButton.Size = UDim2.new(0, 55, 0, 24)
UI.CopyButton.Position = UDim2.new(1, -65, 0.5, -12)
UI.CopyButton.BackgroundColor3 = Decode.Theme.MainBackground
UI.CopyButton.Text = "COPY"
UI.CopyButton.TextColor3 = Decode.Theme.TextMain
UI.CopyButton.TextSize = 12
UI.CopyButton.Font = Enum.Font.SourceSansBold
UI.CopyButton.Parent = UI.DiscordRow

UI.CopyCorner = Instance.new("UICorner")
UI.CopyCorner.CornerRadius = UDim.new(0, 4)
UI.CopyCorner.Parent = UI.CopyButton

UI.CopyButton.MouseButton1Click:Connect(function()
    local invite = "https://discord.gg/Q6SqhpEKGZ"
    local clipboard = env["setclipboard"] or env["toclipboard"]
    if clipboard then
        pcall(clipboard, invite)
    elseif env["request"] then
        pcall(env["request"], {
            Url = "http://localhost:24892/copy",
            Method = "POST",
            Body = invite
        })
    end
end)

UI.LocalPlayerDrop = Decode:CreateDropdown(UI.CreatedPages["Home"], "LocalPlayer")

UI.SpeedSlider = Decode:AddNumInput(UI.LocalPlayerDrop, "Set Speed", Configurations.Speed, function(value)
    Configurations.Speed = value
    saveConfig()
end)

UI.WalkspeedToggle = Decode:AddToggle(UI.LocalPlayerDrop, "Enable Walkspeed", function(state)
    Configurations.SpeedEnabled = state
    saveConfig()
end)

UI.NoClipToggle = Decode:AddToggle(UI.LocalPlayerDrop, "No Clip", function(state)
    Configurations.NoClipEnabled = state
    saveConfig()
end)

UserInputService.JumpRequest:Connect(function()
    if Configurations.InfiniteJumpEnabled and LocalPlayer.Character then
        local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

UI.InfJumpToggle = Decode:AddToggle(UI.LocalPlayerDrop, "Infinite Jump", function(state)
    Configurations.InfiniteJumpEnabled = state
    saveConfig()
    if not state and LocalPlayer.Character then
        local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            Humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end)

UI.StealDrop = Decode:CreateDropdown(UI.CreatedPages["Main"], "Steal")

Decode:AddLabel(UI.StealDrop, "- [ Options ] -")

UI.EggsStealSelector = Decode:AddSelector(UI.StealDrop, "Select Eggs", {}, function(chosen, selectorObj)
    Configurations.SelectedEggsFilter = Configurations.SelectedEggsFilter or {}
    local idx = table.find(Configurations.SelectedEggsFilter, chosen)
    if idx then 
        table.remove(Configurations.SelectedEggsFilter, idx) 
    else 
        table.insert(Configurations.SelectedEggsFilter, chosen) 
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.SelectedEggsFilter)
end)

Decode:AddLabel(UI.StealDrop, "- [ Functions ] -")

UI.StealEggsToggle = Decode:AddToggle(UI.StealDrop, "Steal Eggs", function(state)
    Configurations.StealEgg = state
    saveConfig()
end)

UI.ServerDrop = Decode:CreateDropdown(UI.CreatedPages["Misc"], "Server")

Decode:AddLabel(UI.ServerDrop, "- [ Functions ] -")

UI.AntiAfkToggle = Decode:AddToggle(UI.ServerDrop, "Anti-AFK", function(state)
    Configurations.AntiAfkToggleState = state
    saveConfig()
end)

UI.RejoinToggle = Decode:AddToggle(UI.ServerDrop, "Auto-Connect", function(state)
    Configurations.RejoinToggleState = state
    saveConfig()
end)

UI.ExecuteToggle = Decode:AddToggle(UI.ServerDrop, "Auto-Execute", function(state)
    Configurations.ExecuteToggleState = state
    saveConfig()
end)

Decode:AddLabel(UI.ServerDrop, "- [ Find Server Version ] -")
Decode:AddLabel(UI.ServerDrop, "\n- [ Configs ] -")

UI.Hop = Decode:AddNumInput(UI.ServerDrop, "Delay Hop", Configurations.HopDelayValue or 1, function(value)
    Configurations.HopDelayValue = value
    saveConfig()
end, "Should be > 0")

UI.HopTarget = Decode:AddNumInput(UI.ServerDrop, "Target Version", Configurations.HopTargetVersion or 0, function(value)
    Configurations.HopTargetVersion = value
    saveConfig()
end, "Should be > 0")

Decode:AddLabel(UI.ServerDrop, "- [ Options ] -")

UI.HopSelector = Decode:AddSelector(UI.ServerDrop, "Select Hop", {"Low", "High", "Random"}, function(chosen, selectorObj)
    if selectorObj.SelectBtn.Text == chosen then
        Configurations.HopSelection = ""
    else
        Configurations.HopSelection = chosen
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.HopSelection)
end)

Decode:AddLabel(UI.ServerDrop, "- [ Functions ] -")

UI.HopToggle = Decode:AddToggle(UI.ServerDrop, "Auto Hop", function(state)
    Configurations.HopEnabled = state
    saveConfig()
end)

UI.OneHop = Decode:AddButton(UI.ServerDrop, "Hop Once")
UI.OneHop.MouseButton1Click:Connect(function()
    local api = _G.DecodeAPI
    local hopOnce = api and api.HopOnce

    if type(hopOnce) == "function" then
        task.spawn(function()
            hopOnce()
        end)
    end
end)

UI.ConfigDrop = Decode:CreateDropdown(UI.CreatedPages["Settings"], "Config")

Decode:AddLabel(UI.ConfigDrop, "- [ Main Configuration ] -")

UI.CopyMyConfigBtn = Decode:AddButton(UI.ConfigDrop, "Copy My Config")
UI.CopyMyConfigBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local filePathToMain = folderPath .. "/Save System/Steal an Egg/config.json"
        
        local isfile = env["isfile"]
        local readfile = env["readfile"]
        
        if isfile and readfile and isfile(filePathToMain) then
            local contentToCopy = readfile(filePathToMain)
            
            if contentToCopy and contentToCopy ~= "" then
                if setclipboard then
                    setclipboard(tostring(contentToCopy))
                    if _G.PostMailboxTerminalAlert then
                        _G.PostMailboxTerminalAlert("Config", "Main config text copied to clipboard!", false)
                    end
                else
                    if _G.PostMailboxTerminalAlert then
                        _G.PostMailboxTerminalAlert("Config", "Clipboard unsupported! Output sent to F9.", true)
                    end
                end
            else
                if _G.PostMailboxTerminalAlert then
                    _G.PostMailboxTerminalAlert("Config Error", "Main config file is completely empty!", true)
                end
            end
        else
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "Main config.json file does not exist yet!", true)
            end
        end
    end)
end)

UI.DeleteMyConfigBtn = Decode:AddButton(UI.ConfigDrop, "Delete My Config")
UI.DeleteMyConfigBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local filePathToMain = folderPath .. "/Save System/Steal an Egg/config.json"
        
        local isfile = env["isfile"]
        local delfile = env["delfile"]
        
        if isfile and isfile(filePathToMain) then
            if delfile then
                delfile(filePathToMain)
                if _G.PostMailboxTerminalAlert then
                    _G.PostMailboxTerminalAlert("Config", "Successfully deleted!\nRestart the game to apply changes.", false)
                end
            else
                if _G.PostMailboxTerminalAlert then
                    _G.PostMailboxTerminalAlert("Config", "Your executor doesn't support file deletion (delfile)!", true)
                end
            end
        else
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config", "Main config.json file does not exist!", true)
            end
        end
    end)
end)

Decode:AddLabel(UI.ConfigDrop, "- [ Setup Configuration ] -")

local function getSavedConfigsList()
    local configs = {}
    local folderToScan = folderPath .. "/Save System/Steal an Egg/Saved Configs/"
    
    if makefolder and not isfolder(folderToScan) then
        makefolder(folderToScan)
    end
    
    pcall(function()
        local files = listfiles(folderToScan)
        for _, fullPath in ipairs(files) do
            local cleanName = fullPath:match("([^/\\]+)%.json$")
            if cleanName then
                table.insert(configs, cleanName)
            end
        end
    end)
    
    return configs
end

UI.CopySelector = Decode:AddSelector(UI.ConfigDrop, "Select Config", getSavedConfigsList(), function(chosen, selectorObj)
    if Configurations.SelectedCopyConfig[1] == chosen then
        Configurations.SelectedCopyConfig = {}
    else
        Configurations.SelectedCopyConfig = {chosen}
    end
    
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.SelectedCopyConfig)
end)

UI.CopyConfigBtn = Decode:AddButton(UI.ConfigDrop, "Copy Selected Config")
UI.CopyConfigBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local selectedFile = Configurations.SelectedCopyConfig[1]
        
        if not selectedFile or selectedFile == "" then
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "No configuration file selected!", true)
            end
            return
        end
        
        local filePathToRead = folderPath .. "/Save System/Steal an Egg/Saved Configs/" .. selectedFile .. ".json"
        
        local isfile = env["isfile"]
        local readfile = env["readfile"]
        
        if isfile and readfile and isfile(filePathToRead) then
            local contentToCopy = readfile(filePathToRead)
            
            if contentToCopy and contentToCopy ~= "" then
                if setclipboard then
                    setclipboard(tostring(contentToCopy))
                    if _G.PostMailboxTerminalAlert then
                        _G.PostMailboxTerminalAlert("Config", "Copied file contents to clipboard!", false)
                    end
                else
                    if _G.PostMailboxTerminalAlert then
                        _G.PostMailboxTerminalAlert("Config", "Clipboard unsupported! Content printed to F9.", true)
                    end
                end
            else
                if _G.PostMailboxTerminalAlert then
                    _G.PostMailboxTerminalAlert("Config Error", "Selected file is empty inside!", true)
                end
            end
        else
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "File could not be found on device!", true)
            end
        end
    end)
end)

UI.DelConfigBtn = Decode:AddButton(UI.ConfigDrop, "Delete Selected Config")
UI.DelConfigBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local selectedFile = Configurations.SelectedCopyConfig[1]
        
        if not selectedFile or selectedFile == "" then
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "No configuration file selected!", true)
            end
            return
        end
        
        local filePathToDelete = folderPath .. "/Save System/Steal an Egg/Saved Configs/" .. selectedFile .. ".json"
        
        local isfile = env["isfile"]
        local delfile = env["delfile"]
        
        if isfile and delfile and isfile(filePathToDelete) then
            delfile(filePathToDelete)
            
            Configurations.SelectedCopyConfig = {}
            saveConfig()
            
            if UI.CopySelector and UI.CopySelector.Populate then
                UI.CopySelector:Populate(getSavedConfigsList())
                UI.CopySelector:UpdateSelectionText(Configurations.SelectedCopyConfig)
            end
            
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config", "Deleted file: " .. selectedFile .. ".json successfully!", false)
            end
        else
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "File could not be found or deleted!", true)
            end
        end
    end)
end)

UI.UseConfigBtn = Decode:AddButton(UI.ConfigDrop, "Use Selected Config")
UI.UseConfigBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local selectedFile = Configurations.SelectedCopyConfig[1]
        
        if not selectedFile or selectedFile == "" then
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "No configuration file selected!", true)
            end
            return
        end
        
        local filePathToRead = folderPath .. "/Save System/Steal an Egg/Saved Configs/" .. selectedFile .. ".json"
        local filePathToMain = folderPath .. "/Save System/Steal an Egg/config.json"
        
        local isfile = env["isfile"]
        local readfile = env["readfile"]
        local writefile = env["writefile"]
        
        if isfile and readfile and writefile and isfile(filePathToRead) then
            local chosenConfigValue = readfile(filePathToRead)
            
            writefile(filePathToMain, chosenConfigValue)
            
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config", "Config Applied! Restart the game to apply changes.", false)
            end
        else
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "Selected file could not be found!", true)
            end
        end
    end)
end)

Decode:AddLabel(UI.ConfigDrop, "- [ Save Configuration ] -")

UI.SaveFile = Decode:AddInput(UI.ConfigDrop, "Input File Name", Configurations.InputConfigFile, function(value)
    Configurations.InputConfigFile = value
    saveConfig()
end, nil, "File Name")

UI.SaveInput = Decode:AddInput(UI.ConfigDrop, "Input Configuration", Configurations.InputConfig, function(value)
    Configurations.InputConfig = value
    saveConfig()
end, nil, "Paste Config")

UI.SaveConfigBtn = Decode:AddButton(UI.ConfigDrop, "Save Input Config")
UI.SaveConfigBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local fileName = UI.SaveFile.ValueBox.Text
        local configValue = UI.SaveInput.ValueBox.Text

        if fileName == "" or configValue == "" then
            if _G.PostMailboxTerminalAlert then
                _G.PostMailboxTerminalAlert("Config Error", "File Name and Value cannot be empty!", true)
            end
            return
        end

        local filePathSave = folderPath .. "/Save System/Steal an Egg/Saved Configs/" .. fileName .. ".json"

        writefile(filePathSave, tostring(configValue))

        Configurations.InputConfig = ""
        Configurations.InputConfigFile = ""
        UI.SaveInput.ValueBox.Text = ""
        UI.SaveFile.ValueBox.Text = ""
        saveConfig()

        if UI.CopySelector and UI.CopySelector.Populate then
            UI.CopySelector:Populate(getSavedConfigsList())
        end

        if _G.PostMailboxTerminalAlert then
            _G.PostMailboxTerminalAlert("Config", "Saved file: " .. fileName .. ".json successfully!", false)
        end
    end)
end)

task.spawn(function()
    task.wait(0.1)
    if Configurations.SpeedEnabled and UI.WalkspeedToggle then
        UI.WalkspeedToggle.IsToggled = true
        UI.WalkspeedToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.WalkspeedToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.WalkspeedToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.NoClipEnabled and UI.NoClipToggle then
        UI.NoClipToggle.IsToggled = true
        UI.NoClipToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.NoClipToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.NoClipToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.InfiniteJumpEnabled and UI.InfJumpToggle then
        UI.InfJumpToggle.IsToggled = true
        UI.InfJumpToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.InfJumpToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.InfJumpToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.StealEgg and UI.StealEggsToggle then
        UI.StealEggsToggle.IsToggled = true
        UI.StealEggsToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.StealEggsToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.StealEggsToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end
end)

task.spawn(function()
    local EggsList = getEggsDescendants()

    if UI.EggsStealSelector and UI.EggsStealSelector.Populate then pcall(function() UI.EggsStealSelector:Populate(EggsList) end) end
end)

UI.CloseTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
UI.ExitModal = Instance.new("Frame")
UI.ExitModal.Name = "ExitConfirmation"
UI.ExitModal.Size = UDim2.new(0, 320, 0, 200)
UI.ExitModal.Position = UDim2.new(0.5, -160, 0.5, -100)
UI.ExitModal.BackgroundColor3 = Decode.Theme.SidebarBackground
UI.ExitModal.BackgroundTransparency = 0.05
UI.ExitModal.BorderSizePixel = 0
UI.ExitModal.Visible = false
UI.ExitModal.ZIndex = 10
UI.ExitModal.Parent = UI.FrameMain

UI.ModalCorner = Instance.new("UICorner")
UI.ModalCorner.CornerRadius = UDim.new(0, 12)
UI.ModalCorner.Parent = UI.ExitModal

UI.ModalStroke = Instance.new("UIStroke")
UI.ModalStroke.Color = Decode.Theme.AccentColor
UI.ModalStroke.Thickness = 1
UI.ModalStroke.Parent = UI.ExitModal

UI.WarnIcon = Instance.new("TextLabel")
UI.WarnIcon.Size = UDim2.new(1, 0, 0, 40)
UI.WarnIcon.Position = UDim2.new(0, 0, 0, 15)
UI.WarnIcon.BackgroundTransparency = 1
UI.WarnIcon.Text = "⚠️"
UI.WarnIcon.TextSize = 28
UI.WarnIcon.ZIndex = 11
UI.WarnIcon.Parent = UI.ExitModal

UI.ConfirmHeader = Instance.new("TextLabel")
UI.ConfirmHeader.Size = UDim2.new(1, 0, 0, 25)
UI.ConfirmHeader.Position = UDim2.new(0, 0, 0, 60)
UI.ConfirmHeader.BackgroundTransparency = 1
UI.ConfirmHeader.Text = "Exit Confirmation"
UI.ConfirmHeader.TextColor3 = Decode.Theme.TextMain
UI.ConfirmHeader.TextSize = 16
UI.ConfirmHeader.Font = Enum.Font.SourceSansBold
UI.ConfirmHeader.ZIndex = 11
UI.ConfirmHeader.Parent = UI.ExitModal

UI.ConfirmDesc = Instance.new("TextLabel")
UI.ConfirmDesc.Size = UDim2.new(1, -40, 0, 35)
UI.ConfirmDesc.Position = UDim2.new(0, 20, 0, 85)
UI.ConfirmDesc.BackgroundTransparency = 1
UI.ConfirmDesc.Text = "Are you sure you want to close the UI?\nYou won't be able to re-open in this session."
UI.ConfirmDesc.TextColor3 = Decode.Theme.TextMuted
UI.ConfirmDesc.TextSize = 13
UI.ConfirmDesc.Font = Enum.Font.SourceSans
UI.ConfirmDesc.TextWrapped = true
UI.ConfirmDesc.ZIndex = 11
UI.ConfirmDesc.Parent = UI.ExitModal

UI.YesBtn = Instance.new("TextButton")
UI.YesBtn.Name = "YesButton"
UI.YesBtn.Size = UDim2.new(0, 125, 0, 35)
UI.YesBtn.Position = UDim2.new(0, 25, 1, -50)
UI.YesBtn.BackgroundColor3 = Decode.Theme.ElementBackground
UI.YesBtn.Text = "Yes"
UI.YesBtn.TextColor3 = Decode.Theme.TextMain
UI.YesBtn.TextSize = 14
UI.YesBtn.Font = Enum.Font.SourceSansBold
UI.YesBtn.ZIndex = 11
UI.YesBtn.Parent = UI.ExitModal

UI.YesCorner = Instance.new("UICorner")
UI.YesCorner.CornerRadius = UDim.new(0, 6)
UI.YesCorner.Parent = UI.YesBtn

UI.NoBtn = Instance.new("TextButton")
UI.NoBtn.Name = "NoButton"
UI.NoBtn.Size = UDim2.new(0, 125, 0, 35)
UI.NoBtn.Position = UDim2.new(1, -150, 1, -50)
UI.NoBtn.BackgroundColor3 = Decode.Theme.ElementBackground
UI.NoBtn.Text = "No"
UI.NoBtn.TextColor3 = Decode.Theme.TextMain
UI.NoBtn.TextSize = 14
UI.NoBtn.Font = Enum.Font.SourceSansBold
UI.NoBtn.ZIndex = 11
UI.NoBtn.Parent = UI.ExitModal

UI.NoCorner = Instance.new("UICorner")
UI.NoCorner.CornerRadius = UDim.new(0, 6)
UI.NoCorner.Parent = UI.NoBtn

UI.CloseButton.MouseButton1Click:Connect(function()
    UI.ExitModal.Size = UDim2.new(0, 0, 0, 0)
    UI.ExitModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    UI.ExitModal.Visible = true
    local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(UI.ExitModal, OpenTweenInfo, {
        Size = UDim2.new(0, 320, 0, 200),
        Position = UDim2.new(0.5, -160, 0.5, -100)
    }):Play()
end)

local function closePopup()
    local tween = TweenService:Create(UI.ExitModal, UI.CloseTweenInfo, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    })
    tween:Play()
    tween.Completed:Connect(function()
        UI.ExitModal.Visible = false
    end)
end

UI.NoBtn.MouseButton1Click:Connect(closePopup)

UI.YesBtn.MouseButton1Click:Connect(function()
    UI.ScreenGui:Destroy()
end)

function Decode:Init()
    if UI.FirstTab then
        UI.FirstTab.Page.Visible = true
        UI.FirstTab.Button.BackgroundTransparency = 0.8
        UI.FirstTab.Button.TextColor3 = Decode.Theme.TextMain
    end
end

if _G.PostMailboxTerminalAlert then
    _G.PostMailboxTerminalAlert("Decode", "UI Loaded", false)
end
print("Decode: UI Loaded")
Decode:Init()
return Decode