local executeFunction = "DecodeAntiMultiFunction"

if _G[executeFunction] then
    warn("Decode: Function already running.")
    return
end

_G[executeFunction] = true

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Env = getfenv()
local getconnections = Env["getconnections"]
local queueTeleport = Env["queue_on_teleport"]
local syn = Env["syn"]
local http_request = Env["http_request"]
local request = Env["request"]
_G.DecodeAPI = _G.DecodeAPI or {}
_G.DecodeAPI.Configs = _G.DecodeAPI.Configs or {}

task.spawn(function()
    local Player = game:GetService("Players").LocalPlayer
    local RunService = game:GetService("RunService")
    
    RunService.Heartbeat:Connect(function()
        local Configs = _G.DecodeAPI.Configs
        if not Configs then return end
        
        local Character = Player.Character
        if not Character then return end
        
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        if not Humanoid then return end
        
        if Configs.SpeedEnabled then
            if Humanoid.WalkSpeed ~= (Configs.Speed or 16) then
                Humanoid.WalkSpeed = Configs.Speed or 16
            end
        else
            if Humanoid.WalkSpeed ~= 16 then
                Humanoid.WalkSpeed = 16
            end
        end
    end)
end)

task.spawn(function()
    RunService.Stepped:Connect(function()
        local Configs = _G.DecodeAPI.Configs
        if not Configs or not Configs.NoClipEnabled then return end

        local Character = LocalPlayer.Character
        if not Character then return end

        for _, Part in ipairs(Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                if Part.Name == "HumanoidRootPart" then
                    Part.CanCollide = false
                else
                    local Connection = Part:GetTouchingParts()
                    local IsOnBaseplate = false
                    
                    for _, TouchPart in ipairs(Connection) do
                        if TouchPart == Workspace.Baseplate or TouchPart.Name == "Baseplate" or TouchPart.Name == "TopLayer" then
                            IsOnBaseplate = true
                            break
                        end
                    end

                    if IsOnBaseplate then
                        Part.CanCollide = true
                    else
                        Part.CanCollide = false
                    end
                end
            end
        end
    end)
end)

do
    local moduleInstance = ReplicatedStorage:FindFirstChild("SharedModules")
    moduleInstance = moduleInstance and moduleInstance:FindFirstChild("Networking")

    if moduleInstance then
        local ok, result = pcall(require, moduleInstance)
        if ok and type(result) == "table" then
            Networking = result
        else
            warn("[AntiAfk] Failed to require Networking:", result)
        end
    else
        warn("[AntiAfk] Could not find ReplicatedStorage.SharedModules.Networking")
    end
end

local function getRequestHop()
    if type(Networking) ~= "table" then return nil end
    local antiAfk = rawget(Networking, "AntiAfk") or Networking.AntiAfk
    if type(antiAfk) ~= "table" then return nil end
    return antiAfk.RequestHop
end

local function disableIdledConnections()
    if not getconnections then
        warn("[AntiAfk] getconnections not supported by executor")
        return
    end

    for _, connection in ipairs(getconnections(LocalPlayer.Idled)) do
        pcall(function()
            connection:Disable()
        end)
    end
end

local function enableRequestHopBlock()
    local requestHop = getRequestHop()
    if not requestHop then
        warn("[AntiAfk] RequestHop packet not found - skipping hop block")
        return
    end

    if rawget(requestHop, "_OldFire") then return end

    local ok = pcall(function()
        requestHop._OldFire = requestHop.Fire
        requestHop.Fire = function()
            return
        end
    end)

    if ok then
        if _G.PostMailboxTerminalAlert then
            _G.PostMailboxTerminalAlert("AntiAFK", "RequestHop blocked successfully", false)
        end
    else
        warn("[AntiAfk] Failed to patch RequestHop (locked table?)")
    end
end

local function disableRequestHopBlock()
    local requestHop = getRequestHop()
    if not requestHop then return end

    pcall(function()
        if requestHop._OldFire then
            requestHop.Fire = requestHop._OldFire
            requestHop._OldFire = nil
        end
    end)
end

_G.DecodeAPI.StartAntiAfk = function()
    if _G.DecodeAPI.AntiAfkLoopActive then return end
    _G.DecodeAPI.AntiAfkLoopActive = true

    disableIdledConnections()
    enableRequestHopBlock()

    task.spawn(function()
        while _G.DecodeAPI.AntiAfkLoopActive do
            local configs = _G.DecodeAPI.Configs

            if configs and configs.AntiAfkToggleState then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.zero)
                end)
            end

            task.wait(60)
        end

        disableRequestHopBlock()
        _G.DecodeAPI.AntiAfkLoopActive = false
    end)
end

_G.DecodeAPI.StopAntiAfk = function()
    _G.DecodeAPI.AntiAfkLoopActive = false
    disableRequestHopBlock()
end

_G.DecodeAPI.StartAntiAfk()

_G.DecodeAPI.StartNetworkAutoReconnect = function()
    if _G.DecodeAPI.AutoReconnectConnection then
        return
    end

    local Rejoining = false
    local LogService = game:GetService("LogService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    _G.DecodeAPI.AutoReconnectConnection = LogService.MessageOut:Connect(function(text, messageType)
        local configs = _G.DecodeAPI.Configs

        if Rejoining then 
            return 
        end
        if not configs or not configs.RejoinToggleState then 
            return 
        end
        
        local isDisconnect = text:find("Lost connection") or text:find("Disconnected") or text:find("277") or text:find("279")

        if not isDisconnect then 
            return 
        end

        Rejoining = true

        local placeId = game.PlaceId
        local jobId = game.JobId
        local attempts = 0

        task.spawn(function()
            while true do
                pcall(function()
                    attempts = attempts + 1
                    
                    if attempts <= 5 and jobId ~= "" then
                        local options = Instance.new("TeleportOptions")
                        options.ServerInstanceId = jobId
                        TeleportService:TeleportAsync(placeId, {LocalPlayer}, options)
                    else
                        TeleportService:TeleportAsync(placeId, {LocalPlayer})
                    end
                end)
                task.wait(5)
            end
        end)
    end)
end

_G.DecodeAPI.StartNetworkAutoReconnect()

_G.DecodeAPI.StartAutoExecute = function()
    if _G.DecodeAPI.AutoExecuteActive then return end
    _G.DecodeAPI.AutoExecuteActive = true
    
    local scriptToExecute = [[
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ItzYumi/Decode/refs/heads/main/DE%3ACODE.lua", true))()
    ]]

    local teleportConnection
    local hasQueued = false

    teleportConnection = game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(teleportState)
        local configs = _G.DecodeAPI.Configs
        
        if configs and configs.ExecuteToggleState and not hasQueued then
            local queueFunction = queueTeleport or (syn and syn.queue_on_teleport)
            
            if queueFunction then
                hasQueued = true
                pcall(function()
                    queueFunction(scriptToExecute)
                end)
            end
        end
    end)

    task.spawn(function()
        while _G.DecodeAPI.AutoExecuteActive do
            task.wait(1)
        end
        if teleportConnection then
            teleportConnection:Disconnect()
        end
    end)
end

_G.DecodeAPI.StartAutoExecute()

local blacklistedServers = {}
local teleporting = false
local teleportStartedAt = 0
local autoLoopStarted = false
local autoTargetFound = false
local lastAutoTarget

local function getConfig()
    local api = _G.DecodeAPI

    if type(api) == "table" and type(api.Configs) == "table" then
        return api.Configs
    end

    return nil
end

local function isEnabled(value)
    if type(value) == "boolean" then
        return value
    end

    if type(value) == "number" then
        return value ~= 0
    end

    if type(value) == "string" then
        return value == "true" or value == "1"
    end

    return false
end

local function getTargetVersion(configs)
    local value = tonumber(configs and configs.HopTargetVersion)

    if not value or value <= 0 then
        return 0
    end

    return math.floor(value)
end

local function getHopDelay(configs)
    local value = tonumber(configs and configs.HopDelayValue)

    if not value then
        return 1
    end

    return math.max(0, value)
end

local function getSelection(configs)
    local selection = configs and configs.HopSelection

    if selection == "Low" or selection == "High" or selection == "Random" then
        return selection
    end

    return "Random"
end

local function safeRequest(url)
    local requestFunc

    if type(syn) == "table" and type(syn.request) == "function" then
        requestFunc = syn.request
    elseif type(http_request) == "function" then
        requestFunc = http_request
    elseif type(request) == "function" then
        requestFunc = request
    end

    if type(requestFunc) ~= "function" then
        warn("No executor HTTP request function found!")
        return ""
    end

    local success, response = pcall(function()
        return requestFunc({
            Url = url,
            Method = "GET"
        })
    end)

    if success and response and type(response.Body) == "string" then
        return response.Body
    end

    return ""
end

local function getCurrentServerVersion()
    return game.PlaceVersion
end

local function isCurrentServerTarget(targetVersion)
    return targetVersion > 0 and getCurrentServerVersion() == targetVersion
end

local function getAvailablePublicServer(findTarget)
    local configs = getConfig()
    local selection = getSelection(configs)
    local targetVersion = getTargetVersion(configs)

    local sortOrder = "Asc"

    if selection == "High" then
        sortOrder = "Desc"
    elseif selection == "Random" then
        sortOrder = math.random(1, 2) == 1 and "Asc" or "Desc"
    end

    local servers = {}
    local targetServers = {}
    local cursor = ""

    for pageCount = 1, 3 do
        local encodedCursor = cursor

        if encodedCursor ~= "" then
            encodedCursor = HttpService:UrlEncode(encodedCursor)
        end

        local url = string.format(
            "https://games.roblox.com/v1/games/%s/servers/Public?cursor=%s&sortOrder=%s&excludeFullGames=true&limit=10",
            tostring(game.PlaceId),
            encodedCursor,
            sortOrder
        )

        local response = safeRequest(url)

        if response == "" then
            break
        end

        local decodeSuccess, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)

        if not decodeSuccess or type(data) ~= "table" or type(data.data) ~= "table" then
            break
        end

        for _, server in ipairs(data.data) do
            if type(server) == "table" then
                local id = server.id and tostring(server.id) or ""
                local playing = tonumber(server.playing)
                local maxPlayers = tonumber(server.maxPlayers)

                if id ~= ""
                    and id ~= tostring(game.JobId)
                    and not blacklistedServers[id]
                    and playing
                    and maxPlayers
                    and playing < maxPlayers then

                    if selection == "Low" or playing > 0 then
                        local serverInfo = {
                            Id = id,
                            Playing = playing,
                            MaxPlayers = maxPlayers
                        }

                        table.insert(servers, serverInfo)

                        if findTarget
                            and targetVersion > 0
                            and playing == targetVersion then
                            table.insert(targetServers, serverInfo)
                        end
                    end
                end
            end
        end

        local nextCursor = data.nextPageCursor

        if type(nextCursor) == "string" then
            cursor = nextCursor
        else
            cursor = ""
        end

        if cursor == "" then
            break
        end
    end

    if findTarget and #targetServers > 0 then
        local targetServer = targetServers[math.random(1, #targetServers)]
        return targetServer.Id
    end

    if #servers == 0 then
        return nil
    end

    if selection == "Low" then
        table.sort(servers, function(a, b)
            if a.Playing == b.Playing then
                return a.Id < b.Id
            end

            return a.Playing < b.Playing
        end)

        return servers[1].Id
    end

    if selection == "High" then
        table.sort(servers, function(a, b)
            if a.Playing == b.Playing then
                return a.Id < b.Id
            end

            return a.Playing < b.Playing
        end)

        return servers[#servers].Id
    end

    return servers[math.random(1, #servers)].Id
end

failureConnection = TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    if player ~= LocalPlayer then
        return
    end

    teleporting = false
    teleportStartedAt = 0

    warn("Teleport failed: " .. tostring(errorMessage))
end)

local function hopPublicServer(findTarget)
    findTarget = findTarget == true

    if teleporting then
        return false
    end

    local configs = getConfig()

    if findTarget then
        local targetVersion = getTargetVersion(configs)
        local hopDelay = getHopDelay(configs)

        if not configs
            or not isEnabled(configs.HopEnabled)
            or targetVersion <= 0
            or hopDelay <= 0 then
            return false
        end
    end

    local serverId = getAvailablePublicServer(findTarget)

    if not serverId or serverId == tostring(game.JobId) then
        warn("No valid servers found to hop to.")
        return false
    end

    if findTarget then
        configs = getConfig()

        if not configs
            or not isEnabled(configs.HopEnabled)
            or getTargetVersion(configs) <= 0
            or getHopDelay(configs) <= 0 then
            return false
        end
    end

    blacklistedServers[serverId] = true
    teleporting = true
    teleportStartedAt = os.clock()

    local success, errorMessage = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            serverId,
            LocalPlayer
        )
    end)

    if not success then
        teleporting = false
        teleportStartedAt = 0

        warn("Failed to initiate teleport: " .. tostring(errorMessage))
        return false
    end

    return true
end

local function startAutoHop()
    if autoLoopStarted then
        return
    end

    autoLoopStarted = true

    task.spawn(function()
        while true do
            local configs = getConfig()
            local enabled = isEnabled(configs and configs.HopEnabled)
            local targetVersion = getTargetVersion(configs)
            local hopDelay = getHopDelay(configs)

            if not enabled then
                autoTargetFound = false
                lastAutoTarget = nil
                task.wait(0.25)
            else
                if lastAutoTarget ~= targetVersion then
                    autoTargetFound = false
                    lastAutoTarget = targetVersion
                end

                if targetVersion <= 0 then
                    autoTargetFound = false
                    task.wait(0.25)
                elseif hopDelay <= 0 then
                    task.wait(0.25)
                elseif autoTargetFound then
                    task.wait(0.25)
                elseif isCurrentServerTarget(targetVersion) then
                    autoTargetFound = true
                    task.wait(0.25)
                elseif teleporting then
                    if teleportStartedAt > 0 and os.clock() - teleportStartedAt >= 30 then
                        teleporting = false
                        teleportStartedAt = 0
                    end

                    task.wait(0.25)
                else
                    task.wait(hopDelay)

                    local latestConfigs = getConfig()
                    local latestEnabled = isEnabled(latestConfigs and latestConfigs.HopEnabled)
                    local latestTarget = getTargetVersion(latestConfigs)
                    local latestDelay = getHopDelay(latestConfigs)

                    if latestEnabled
                        and latestTarget > 0
                        and latestDelay > 0
                        and not autoTargetFound
                        and not teleporting
                        and not isCurrentServerTarget(latestTarget) then

                        hopPublicServer(true)
                    end
                end
            end
        end
    end)
end

local decodeAPI = _G.DecodeAPI

if type(decodeAPI) ~= "table" then
    decodeAPI = {}
    _G.DecodeAPI = decodeAPI
end

decodeAPI.HopOnce = function()
    autoTargetFound = false
    return hopPublicServer(false)
end

decodeAPI.HopPublicServer = hopPublicServer

startAutoHop()