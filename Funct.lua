local executeFunction = "DecodeAntiMultiFunction"

if _G[executeFunction] then
    warn("Decode: Function already running.")
    return
end

_G[executeFunction] = true

local Env = getfenv()
local syn = Env["syn"]
local http_request = Env["http_request"]
local request = Env["request"]
local require = Env["require"]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Network = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local askFieldEggSnapshotRF = Network:WaitForChild("RF/EggWorld/AskFieldEggSnapshot")
local askFieldEggCarry = Network:WaitForChild("RF/EggWorld/AskFieldEggCarry")
local askState = Network:WaitForChild("RF/Homestead/AskState")
local askRenderSnapshot = Network:WaitForChild("RF/Treadmill/AskRenderSnapshot")
local askDoff = Network:WaitForChild("RF/Treadmill/AskDoff")
local askWearStill = Network:WaitForChild("RF/Treadmill/AskWearStill")
local askLiveSnapshot = Network:WaitForChild("RF/EggWorld/AskLiveSnapshot")
local askWearTool = Network:WaitForChild("RF/EggWorld/AskWearTool")
local _askPlaceEgg = Network:WaitForChild("RF/EggWorld/AskPlaceEgg")
local _askHatch = Network:WaitForChild("RF/EggWorld/AskHatch")
local _askFinishHatch = Network:WaitForChild("RF/EggWorld/AskFinishHatch")
local AreaEggCycle = require(ReplicatedStorage.Shared.Util.AreaEggCycle)
local AreaEggResetCycle = require(ReplicatedStorage.Data.AreaEggResetCycle)
local LocalPlayer = Players.LocalPlayer
_G.DecodeAPI.Configs = _G.DecodeAPI.Configs or {}
local Configurations = _G.DecodeAPI.Configs

task.spawn(function()
    local Player = game:GetService("Players").LocalPlayer
    local RunService = game:GetService("RunService")
    
    RunService.Heartbeat:Connect(function()
        if not _G.DecodeAPI or not _G.DecodeAPI.Configs then return end
        
        local Configs = _G.DecodeAPI.Configs
        
        if Configs.SpeedEnabled == true then
            local Character = Player.Character
            if not Character then return end
            
            local Humanoid = Character:FindFirstChildOfClass("Humanoid")
            if not Humanoid then return end
            
            local targetSpeed = Configs.Speed or 16
            if Humanoid.WalkSpeed ~= targetSpeed then
                Humanoid.WalkSpeed = targetSpeed
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
                    Part.CanCollide = true
                else
                    Part.CanCollide = false
                end
            end
        end
    end)
end)

local abs = math.abs
local max = math.max
local min = math.min
local huge = math.huge
local round = math.round
local clock = os.clock
local v3new = Vector3.new
local cfnew = CFrame.new

local State = {
    SavedHumanoid = nil,
    SavedGroundOffset = 3.8,
    SavedJumpPower = 50,
    SavedJumpHeight = 7.2,
    SavedUseJumpPower = true,
    CachedControls = nil,
    CurrentCarryingUid = nil,
    hasActiveTargets = false,
    RestoredCharacter = nil,
    SafeZoneStagingDone = false,
    LastSnapshotCycleTime = 0,
    LastSnapshotRawRecords = nil,
    NewCycleGracePending = false,
    LastConfigEnabledState = false,
    SnapshotRetryTime = 0,
    CycleStartClock = 0,
    WasNight = false
}

local Caches = {
    EggInstance = {},
    EggNotFound = {},
    CarryCheck = { uid = nil, time = 0, value = false },
    Snapshot = { time = 0, ok = false, result = nil },
    Treadmill = { time = 0, value = false },
    Plot = { time = 0, value = nil },
    SafeZone = { time = 0, value = nil },
    GuardArea = { time = 0, parts = {} },
    WallCollision = { time = 0, active = false },
    Trap = { time = 0, positions = {} },
    DeliveredEgg = {},
    AreaEggIndex = { time = 0, folder = nil, entries = {} },
    AssetRarities = {},
    AssetEarnings = {},
    BlacklistedEggs = {},
    CarriedEggRecords = {},
    AssetsIndex = { time = 0, value = nil }
}

local MAX_CLIMB_PER_STEP = 5
local MAX_DROP_PER_STEP = 8
local MAX_CARRY_ATTEMPTS = 15
local SLOT_WAIT_TIMEOUT = 20
local TRAP_AVOID_RADIUS = 15
local NEW_CYCLE_GRACE_SECONDS = 25

local AreaEggEntries = {}
local activeConnections = {}

local function indexSingle(instance)
    if not instance then return end
    local nameStr = instance.Name
    if nameStr and nameStr ~= "" then
        AreaEggEntries[nameStr] = instance
    end
    local uidAttr = instance:GetAttribute("Uid")
    if uidAttr and uidAttr ~= "" then
        AreaEggEntries[tostring(uidAttr)] = instance
    end
    local idAttr = instance:GetAttribute("ID")
    if idAttr and idAttr ~= "" then
        AreaEggEntries[tostring(idAttr)] = instance
    end
    if instance:IsA("StringValue") then
        local val = instance.Value
        if val and val ~= "" then
            AreaEggEntries[tostring(val)] = instance.Parent or instance
        end
    end
end

local function deindexSingle(instance)
    if not instance then return end
    local nameStr = instance.Name
    if nameStr and nameStr ~= "" and AreaEggEntries[nameStr] == instance then
        AreaEggEntries[nameStr] = nil
    end
    local uidAttr = instance:GetAttribute("Uid")
    if uidAttr and uidAttr ~= "" then
        local k = tostring(uidAttr)
        if AreaEggEntries[k] == instance then
            AreaEggEntries[k] = nil
        end
    end
    local idAttr = instance:GetAttribute("ID")
    if idAttr and idAttr ~= "" then
        local k = tostring(idAttr)
        if AreaEggEntries[k] == instance then
            AreaEggEntries[k] = nil
        end
    end
    if instance:IsA("StringValue") then
        local val = instance.Value
        if val and val ~= "" then
            local k = tostring(val)
            local target = instance.Parent or instance
            if AreaEggEntries[k] == target then
                AreaEggEntries[k] = nil
            end
        end
    end
end

local function clearConnections()
    for i = 1, #activeConnections do
        if activeConnections[i] then
            activeConnections[i]:Disconnect()
        end
    end
    table.clear(activeConnections)
end

local function setupIncrementalIndexing(folder)
    clearConnections()
    table.clear(AreaEggEntries)
    if not folder then return end
    for _, desc in ipairs(folder:GetDescendants()) do
        indexSingle(desc)
    end
    table.insert(activeConnections, folder.DescendantAdded:Connect(indexSingle))
    table.insert(activeConnections, folder.DescendantRemoving:Connect(deindexSingle))
end

task.spawn(function()
    local folder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if folder then
        setupIncrementalIndexing(folder)
    end
    Workspace.ChildAdded:Connect(function(child)
        if child.Name == "AreaEggSlotsClient" then
            setupIncrementalIndexing(child)
        end
    end)
    Workspace.ChildRemoved:Connect(function(child)
        if child.Name == "AreaEggSlotsClient" then
            clearConnections()
            table.clear(AreaEggEntries)
        end
    end)
end)

UserInputService.JumpRequest:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum and hum.Parent and not hum.PlatformStand and not hum.Sit then
        hum.Jump = true
    end
end)

local function requireRarityModule()
    local dataFolder = ReplicatedStorage:FindFirstChild("Data")
    if dataFolder then
        local mod = dataFolder:FindFirstChild("Rarity")
        if mod then return require(mod) end
    end
    return nil
end

local okRarity, rarityModule = pcall(requireRarityModule)

if not okRarity or not rarityModule then
    okRarity, rarityModule = pcall(function()
        local dataFolder = ReplicatedStorage:WaitForChild("Data", 15)
        return dataFolder and require(dataFolder:WaitForChild("Rarity", 15))
    end)
end

if not okRarity or not rarityModule then
    rarityModule = { Rarities = {} }
end

local rarityWeights = {
    Admin = 23, Exclusive = 22, Limited = 21, Divine = 20, Eternal = 19,
    Secret = 18, Cosmic = 17, Mythic = 16, Epic = 15, Uncommon = 14,
    Common = 13, BrainrotGod = 12, Superior = 11, Transcendent = 11,
    Exotic = 10, Celestial = 9, Basic = 8, Rainbow = 7, Prismatic = 7,
    Legendary = 6, Mythical = 5, SuperRare = 4, Rare = 3
}
local function isNightTime()
    if Workspace:GetAttribute("Event_AdminAbuse") == true then
        return false
    end
    local now = Workspace:GetServerTimeNow()
    local isNight = AreaEggCycle.IsNightPhase(now)
    local isNightTrans = AreaEggCycle.IsWithinNightTransition(
        now, 
        AreaEggResetCycle.NightLightingTransitionSeconds, 
        AreaEggResetCycle.NightLightingStartDelaySeconds
    )
    return isNight or isNightTrans
end

local function isStillAllowed()
    if isNightTime() then return false end
    return Configurations.StealEgg or Configurations.StealEggRarity or Configurations.StealEarnRate
end

local function buildGroundIgnoreList()
    local excludeList = {}
    local character = LocalPlayer.Character

    if character then
        table.insert(excludeList, character)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(excludeList, player.Character)
        end
    end

    local debrisFolder = Workspace:FindFirstChild("__DEBRIS")
    if debrisFolder then
        table.insert(excludeList, debrisFolder)
    end

    for _, eggInstance in pairs(Caches.EggInstance) do
        if eggInstance and eggInstance.Parent then
            table.insert(excludeList, eggInstance)
        end
    end

    if State.CurrentCarryingUid then
        local carriedUidKey = tostring(State.CurrentCarryingUid)
        local carriedEgg = Caches.EggInstance[carriedUidKey]
        if carriedEgg and carriedEgg.Parent then
            table.insert(excludeList, carriedEgg)
        end
    end

    return excludeList
end

local function findSolidGround(x, startY, z, ignoreList)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList
    params.IgnoreWater = true

    local origin = v3new(x, startY + 30, z)
    local direction = v3new(0, -200, 0)
    local currentIgnore = {}
    for _, item in ipairs(ignoreList) do
        table.insert(currentIgnore, item)
    end

    for _ = 1, 5 do
        local result = Workspace:Raycast(origin, direction, params)
        if not result then break end
        local hit = result.Instance
        if hit:IsA("Terrain") or hit.CanCollide then
            return result.Position.Y
        else
            table.insert(currentIgnore, hit)
            params.FilterDescendantsInstances = currentIgnore
        end
    end
    return nil
end

local function alignToGround(pos)
    if not pos then return pos end

    local groundY = findSolidGround(pos.X, pos.Y, pos.Z, buildGroundIgnoreList())
    if groundY then
        return v3new(pos.X, groundY + State.SavedGroundOffset, pos.Z)
    end

    local objectsFolder = Workspace:FindFirstChild("__OBJECTS")
    local areasFolder = objectsFolder and objectsFolder:FindFirstChild("Areas")
    local guardAreas = areasFolder and areasFolder:FindFirstChild("GuardAreas")
    local forestArea = guardAreas and guardAreas:FindFirstChild("Forest")

    if forestArea then
        local forestParts = {}
        if forestArea:IsA("BasePart") then
            table.insert(forestParts, forestArea)
        else
            for _, part in ipairs(forestArea:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    table.insert(forestParts, part)
                end
            end
        end

        local closestPart = nil
        local closestDistance = huge

        for _, part in ipairs(forestParts) do
            local partPos = part.Position
            local partSize = part.Size
            local halfX = partSize.X * 0.5
            local halfZ = partSize.Z * 0.5

            if pos.X >= partPos.X - halfX and pos.X <= partPos.X + halfX and pos.Z >= partPos.Z - halfZ and pos.Z <= partPos.Z + halfZ then
                local topY = partPos.Y + partSize.Y * 0.5
                local distance = abs(pos.Y - topY)

                if distance < closestDistance then
                    closestDistance = distance
                    closestPart = part
                end
            end
        end

        if closestPart then
            return v3new(pos.X, closestPart.Position.Y + closestPart.Size.Y * 0.5 + State.SavedGroundOffset, pos.Z)
        end
    end

    return v3new(pos.X, pos.Y, pos.Z)
end

local function clampVerticalStep(currentPos, candidatePos)
    local y = candidatePos.Y
    if y > currentPos.Y + MAX_CLIMB_PER_STEP then
        y = currentPos.Y + MAX_CLIMB_PER_STEP
    elseif y < currentPos.Y - MAX_DROP_PER_STEP then
        y = currentPos.Y - MAX_DROP_PER_STEP
    end
    return v3new(candidatePos.X, y, candidatePos.Z)
end

local function getPlayerControls()
    if State.CachedControls then return State.CachedControls end
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
    if not playerModule then return nil end
    local ok, module = pcall(require, playerModule)
    if not ok or not module or type(module.GetControls) ~= "function" then return nil end
    local ok2, controls = pcall(function() return module:GetControls() end)
    if ok2 then State.CachedControls = controls end
    return State.CachedControls
end

local function isHumanoidRecovering(humanoid)
    if not humanoid then return false end
    if humanoid.Health <= 0 then return true end
    if humanoid.PlatformStand then return true end
    local okState, currentState = pcall(function() return humanoid:GetState() end)
    if okState and currentState then
        if currentState == Enum.HumanoidStateType.Dead
            or currentState == Enum.HumanoidStateType.Physics
            or currentState == Enum.HumanoidStateType.FallingDown
            or currentState == Enum.HumanoidStateType.Ragdoll then
            return true
        end
    end
    return false
end

local function waitForCharacterReady(timeout)
    local deadline = clock() + (tonumber(timeout) or 10)
    while clock() < deadline do
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if character and character.Parent and rootPart and rootPart.Parent then
            local humanoid = character:FindFirstChildWhichIsA("Humanoid")
            if not humanoid then
                return true
            end
            if not isHumanoidRecovering(humanoid) then
                return true
            end
        end
        task.wait(0.08)
    end
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    return character ~= nil and character.Parent ~= nil and rootPart ~= nil and rootPart.Parent ~= nil
end

local function setCharacterControlsEnabled(enabled)
    local controls = getPlayerControls()
    if controls then
        pcall(function()
            if enabled then controls:Enable() else controls:Disable() end
        end)
    end
end

local function ensureFreeCamera(subject)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    if camera.CameraType ~= Enum.CameraType.Custom then
        camera.CameraType = Enum.CameraType.Custom
    end
    if subject and camera.CameraSubject ~= subject then
        camera.CameraSubject = subject
    end
end

local function cloneHumanoidWithDescendants(humanoid)
    local archivableStates = {}
    archivableStates[humanoid] = humanoid.Archivable
    humanoid.Archivable = true
    for _, desc in ipairs(humanoid:GetDescendants()) do
        archivableStates[desc] = desc.Archivable
        desc.Archivable = true
    end
    local clone = humanoid:Clone()
    for inst, state in pairs(archivableStates) do
        pcall(function() inst.Archivable = state end)
    end
    return clone
end

local function getEggPosition(eggInstance)
    if not eggInstance or not eggInstance.Parent then return nil end
    if eggInstance:IsA("Model") then
        if eggInstance.PrimaryPart then return eggInstance.PrimaryPart.Position end
        local nextPart = eggInstance:FindFirstChildWhichIsA("BasePart", true)
        if nextPart then return nextPart.Position end
    elseif eggInstance:IsA("BasePart") then
        return eggInstance.Position
    end
    return nil
end

local function getEggPositionFromSnapshot(record)
    if not record then return nil end
    local bottomCFrame = record.BottomCFrame
    if typeof(bottomCFrame) == "CFrame" then return bottomCFrame.Position end
    if typeof(bottomCFrame) == "Instance" and bottomCFrame:IsA("CFrameValue") then return bottomCFrame.Value.Position end
    return nil
end

local function getEggApproachRadius(eggInstance)
    if not eggInstance then return 0 end
    local part = nil
    if eggInstance:IsA("BasePart") then
        part = eggInstance
    elseif eggInstance:IsA("Model") then
        part = eggInstance.PrimaryPart or eggInstance:FindFirstChildWhichIsA("BasePart", true)
    end
    if part then return min(max(part.Size.X, part.Size.Z) * 0.5, 4) end
    if eggInstance:IsA("Model") then
        local okExtents, extentsSize = pcall(function() return eggInstance:GetExtentsSize() end)
        if okExtents and extentsSize then return min(max(extentsSize.X, extentsSize.Z) * 0.5, 4) end
    end
    return 0
end

local function getEggTravelPosition(record, eggInstance)
    if eggInstance and eggInstance.Parent then
        local livePos = getEggPosition(eggInstance)
        if livePos then return livePos end
    end
    local snapshotPos = getEggPositionFromSnapshot(record)
    if snapshotPos then return snapshotPos end
    return nil
end

local function getSafeZonePosition()
    local now = clock()
    if Caches.SafeZone.time > 0 and now - Caches.SafeZone.time < 2 and Caches.SafeZone.value then
        return Caches.SafeZone.value
    end
    local value = nil
    local trackStart = Workspace:FindFirstChild("TrackStart", true)
    if not trackStart then
        local objectsFolder = Workspace:FindFirstChild("__OBJECTS")
        local buildFolder = objectsFolder and objectsFolder:FindFirstChild("Build")
        local mainMap = buildFolder and buildFolder:FindFirstChild("MainMap")
        trackStart = mainMap and mainMap:FindFirstChild("TrackStart")
    end
    if not trackStart then
        trackStart = Workspace:FindFirstChild("SafeZone", true)
    end
    if not trackStart then
        local objectsFolder = Workspace:FindFirstChild("__OBJECTS")
        local areasFolder = objectsFolder and objectsFolder:FindFirstChild("Areas")
        local wall = areasFolder and areasFolder:FindFirstChild("WallStartCollision")
        if wall then
            if wall:IsA("BasePart") then
                value = wall.Position + v3new(0, 0, 10)
            else
                local p = wall:FindFirstChildWhichIsA("BasePart", true)
                if p then value = p.Position + v3new(0, 0, 10) end
            end
        end
    end
    if trackStart then
        if trackStart:IsA("BasePart") then
            value = trackStart.Position
        else
            local part = trackStart:FindFirstChildWhichIsA("BasePart", true)
            if part then
                value = part.Position
            else
                local okPivot, pivot = pcall(function() return trackStart:GetPivot() end)
                if okPivot and pivot then value = pivot.Position end
            end
        end
    end
    if value then
        Caches.SafeZone.time = now
        Caches.SafeZone.value = value
    end
    return value
end

local function getTrapHitboxPositions()
    local now = clock()
    if Caches.Trap.time > 0 and now - Caches.Trap.time < 2 then return Caches.Trap.positions end
    local positions = {}
    local debrisFolder = Workspace:FindFirstChild("__DEBRIS")
    if debrisFolder then
        for _, trap in ipairs(debrisFolder:GetChildren()) do
            local hitbox = trap:FindFirstChild("Hitbox", true)
            if hitbox and hitbox:IsA("BasePart") then table.insert(positions, hitbox.Position) end
        end
    end
    Caches.Trap.time = now
    Caches.Trap.positions = positions
    return positions
end

local function getFlatDistanceXZ(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function isPositionInsideTrapAvoidance(pos, radius)
    local checkRadius = radius or (TRAP_AVOID_RADIUS + 5)
    local checkRadiusSq = checkRadius * checkRadius
    for _, trapPos in ipairs(getTrapHitboxPositions()) do
        local dx = pos.X - trapPos.X
        local dz = pos.Z - trapPos.Z
        if dx * dx + dz * dz <= checkRadiusSq and abs(pos.Y - trapPos.Y) <= 35 then
            return true
        end
    end
    return false
end

local function isSegmentTrapClear(a, b, radius)
    local checkRadius = radius or (TRAP_AVOID_RADIUS + 5)
    local checkRadiusSq = checkRadius * checkRadius
    local abx = b.X - a.X
    local abz = b.Z - a.Z
    local aby = b.Y - a.Y
    local lenSq = abx * abx + abz * abz
    if lenSq < 0.01 then
        return not isPositionInsideTrapAvoidance(b, checkRadius)
    end
    for _, trapPos in ipairs(getTrapHitboxPositions()) do
        local apx = trapPos.X - a.X
        local apz = trapPos.Z - a.Z
        local t = (apx * abx + apz * abz) / lenSq
        if t < 0 then
            t = 0
        elseif t > 1 then
            t = 1
        end
        local closestX = a.X + abx * t
        local closestZ = a.Z + abz * t
        local closestY = a.Y + aby * t
        local dx = closestX - trapPos.X
        local dz = closestZ - trapPos.Z
        if dx * dx + dz * dz <= checkRadiusSq and abs(closestY - trapPos.Y) <= 35 then
            local adx = a.X - trapPos.X
            local adz = a.Z - trapPos.Z
            local bdx = b.X - trapPos.X
            local bdz = b.Z - trapPos.Z
            local distA = math.sqrt(adx * adx + adz * adz)
            local distB = math.sqrt(bdx * bdx + bdz * bdz)
            local startInside = distA <= checkRadius and abs(a.Y - trapPos.Y) <= 35
            local endInside = distB <= checkRadius and abs(b.Y - trapPos.Y) <= 35
            if not (startInside and not endInside and distB > distA + 1) then
                return false
            end
        end
    end
    return true
end

local function getGuardAreaParts()
    local now = clock()
    if Caches.GuardArea.time > 0 and now - Caches.GuardArea.time < 2 then return Caches.GuardArea.parts end
    local parts = {}
    local objectsFolder = Workspace:FindFirstChild("__OBJECTS")
    local areasFolder = objectsFolder and objectsFolder:FindFirstChild("Areas")
    local guardAreas = areasFolder and areasFolder:FindFirstChild("GuardAreas")
    if guardAreas then
        for _, area in ipairs(guardAreas:GetChildren()) do
            if area.Parent then
                if area:IsA("BasePart") then
                    table.insert(parts, area)
                else
                    for _, d in ipairs(area:GetChildren()) do
                        if d:IsA("BasePart") then table.insert(parts, d) end
                    end
                end
            end
        end
    end
    Caches.GuardArea.time = now
    Caches.GuardArea.parts = parts
    return parts
end

local function isInsideGuardArea()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local pos = rootPart.Position
    for _, part in ipairs(getGuardAreaParts()) do
        if part.Parent and part.Size.X < 700 and part.Size.Z < 700 then
            local localPoint = part.CFrame:PointToObjectSpace(pos)
            local halfSize = part.Size * 0.5
            if abs(localPoint.X) <= halfSize.X and abs(localPoint.Y) <= halfSize.Y + 12 and abs(localPoint.Z) <= halfSize.Z then
                return true
            end
        end
    end
    return false
end

local function isStagedInSafeZone()
    local safePos = getSafeZonePosition()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not safePos or not rootPart then return false end
    local sdx = rootPart.Position.X - safePos.X
    local sdz = rootPart.Position.Z - safePos.Z
    return math.sqrt(sdx * sdx + sdz * sdz) <= 20
end

local function isWallCollisionActive()
    local now = clock()
    if Caches.WallCollision.time > 0 and now - Caches.WallCollision.time < 0.25 then return Caches.WallCollision.active end
    local isWallActive = false
    local objectsFolder = Workspace:FindFirstChild("__OBJECTS")
    local areasFolder = objectsFolder and objectsFolder:FindFirstChild("Areas")
    local wallStartCollision = areasFolder and areasFolder:FindFirstChild("WallStartCollision")
    if wallStartCollision then
        if wallStartCollision:IsA("BasePart") then
            isWallActive = wallStartCollision.CanCollide
        else
            for _, part in ipairs(wallStartCollision:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    isWallActive = true
                    break
                end
            end
        end
    end
    Caches.WallCollision.time = now
    Caches.WallCollision.active = isWallActive
    return isWallActive
end

local function getAssetsIndex(force)
    local now = clock()
    if not force and Caches.AssetsIndex.time > 0 and now - Caches.AssetsIndex.time < 5 then return Caches.AssetsIndex.value end

    local assetsIndex = ReplicatedStorage:FindFirstChild("Data")
    assetsIndex = assetsIndex and assetsIndex:FindFirstChild("Assets")
    assetsIndex = assetsIndex and assetsIndex:FindFirstChild("Configs")

    if assetsIndex then
        Caches.AssetsIndex.time = now
        Caches.AssetsIndex.value = assetsIndex
    end

    return assetsIndex
end

local function resolveRarityName(rarityValue, rarityByReference)
    if rarityValue == nil then return nil end

    local byRef = rarityByReference[rarityValue]
    if byRef then return byRef end

    local valueType = type(rarityValue)
    if valueType == "string" then
        if rarityModule.Rarities and rarityModule.Rarities[rarityValue] ~= nil then
            return rarityValue
        end
        if rarityWeights[rarityValue] ~= nil then
            return rarityValue
        end
        return rarityValue
    end

    if valueType == "table" then
        local nameField = rarityValue.Name or rarityValue._id or rarityValue.Id
        if type(nameField) == "string" then
            if rarityModule.Rarities and rarityModule.Rarities[nameField] ~= nil then
                return nameField
            end
            if rarityWeights[nameField] ~= nil then
                return nameField
            end
            return nameField
        end
    end

    return nil
end

local function preloadAssetRarities()
    local assetsIndex = getAssetsIndex(true)
    if not assetsIndex then return false end

    local rarityByReference = {}
    if rarityModule and rarityModule.Rarities then
        for rarityName, rarityData in pairs(rarityModule.Rarities) do
            if type(rarityData) == "table" then
                rarityByReference[rarityData] = rarityName
            end
        end
    end

    local loadedRarities = {}
    for _, assetFile in ipairs(assetsIndex:GetDescendants()) do
        if assetFile:IsA("ModuleScript") then
            local success, data = pcall(require, assetFile)
            if success and type(data) == "table" and data.Rarity ~= nil then
                local rarityName = resolveRarityName(data.Rarity, rarityByReference)
                if rarityName then loadedRarities[assetFile.Name] = rarityName end
            end
        end
    end

    Caches.AssetRarities = loadedRarities
    return true
end

local function getRarityFromName(assetName)
    return Caches.AssetRarities[assetName]
end

if not preloadAssetRarities() then
    task.spawn(function()
        while not preloadAssetRarities() do task.wait(0.5) end
    end)
end

local function preloadAssetEarnings()
    local assetsIndex = getAssetsIndex(true)
    if not assetsIndex then return false end

    local loadedEarnings = {}
    for _, assetFile in ipairs(assetsIndex:GetDescendants()) do
        if assetFile:IsA("ModuleScript") then
            local success, data = pcall(require, assetFile)
            if success and type(data) == "table" then
                local rate = tonumber(data.EarningRate)
                if rate and rate > 0 then
                    loadedEarnings[assetFile.Name] = rate
                else
                    loadedEarnings[assetFile.Name] = false
                end
            end
        end
    end

    Caches.AssetEarnings = loadedEarnings
    return true
end

if not preloadAssetEarnings() then
    task.spawn(function()
        while not preloadAssetEarnings() do task.wait(0.5) end
    end)
end

local MutationRegistry = {}
pcall(function()
    local mod = ReplicatedStorage:FindFirstChild("Shared")
    mod = mod and mod:FindFirstChild("Modules")
    mod = mod and mod:FindFirstChild("Mutations")
    if not mod then return end
    
    local mutationsModule = require(mod)
    local registryTable = nil
    
    if type(mutationsModule.All) == "function" then
        registryTable = mutationsModule.All()
    elseif type(mutationsModule.GetMutations) == "function" then
        registryTable = mutationsModule.GetMutations()
    end
    
    if type(registryTable) == "table" then
        for name, data in pairs(registryTable) do
            if type(data) == "table" then
                local entry = table.clone(data)
                entry.ValueMulti = entry.ValueMulti or entry.EarningsScalar or 1
                MutationRegistry[name] = entry
            end
        end
    end
end)

local function getBaseEarning(assetName)
    if assetName == nil then return 0 end
    local cached = Caches.AssetEarnings[assetName]
    if cached ~= nil then
        return cached and cached or 0
    end
    local rate = false
    local assetsIndex = getAssetsIndex(false)
    if assetsIndex then
        local assetFile = assetsIndex:FindFirstChild(assetName)
        if assetFile and assetFile:IsA("ModuleScript") then
            local success, data = pcall(require, assetFile)
            if success and type(data) == "table" then
                local parsed = tonumber(data.EarningRate)
                if parsed and parsed > 0 then
                    rate = parsed
                end
            end
        end
    end
    Caches.AssetEarnings[assetName] = rate
    return rate and rate or 0
end

local function computeRecordEarning(record)
    if not record then return 0 end
    local baseEarning = getBaseEarning(record.AssetCategory)
    if baseEarning <= 0 then return 0 end
    local scale = tonumber(record.AssetScale) or tonumber(record.NestScale) or 1
    local earning = baseEarning * (scale ^ 1.85)
    local mutations = record.Mutations
    if type(mutations) == "table" then
        for _, mName in pairs(mutations) do
            local entry = MutationRegistry[tostring(mName)]
            local multi = entry and tonumber(entry.ValueMulti) or 1
            if multi ~= 1 then
                earning = earning * multi
            end
        end
    end
    return earning
end

local function getRecordEarning(record)
    local cached = record.CachedEarning
    if cached ~= nil then return cached end
    local earning = computeRecordEarning(record)
    record.CachedEarning = earning
    return earning
end

local function precomputeRecordEarnings(records)
    if not records then return end
    for _, record in ipairs(records) do
        if type(record) == "table" and record.CachedEarning == nil then
            record.CachedEarning = computeRecordEarning(record)
        end
    end
end

local function formatComma(n)
    local s = tostring(round(tonumber(n) or 0))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function sendStolenEggWebhook(uid)
    local configs = _G.DecodeAPI and _G.DecodeAPI.Configs or {}
    if not configs.EggSend or not configs.EggURL or configs.EggURL == "" then return end
    task.spawn(function()
        pcall(function()
            local record = Caches.CarriedEggRecords[tostring(uid)]
            if not record then return end
            local assetName = record.AssetCategory or "Unknown"
            local rarityName = getRarityFromName(assetName) or "Unknown"
            local scale = tonumber(record.AssetScale) or tonumber(record.NestScale) or 1
            local petName = assetName
            local baseEarning = 0
            local baseWeight = 0
            local assetsIndex = getAssetsIndex(false)
            if assetsIndex and assetName ~= "Unknown" then
                local assetFile = assetsIndex:FindFirstChild(assetName)
                if assetFile and assetFile:IsA("ModuleScript") then
                    local okConfig, config = pcall(require, assetFile)
                    if okConfig and type(config) == "table" then
                        petName = config.DisplayName or petName
                        baseEarning = tonumber(config.EarningRate) or 0
                        baseWeight = tonumber(config.ModelWeight) or 0
                    end
                end
            end
            local finalWeight = round(baseWeight * (scale ^ 3))
            local finalEarning = baseEarning * (scale ^ 1.85)
            local foundMutations = {}
            if type(record.Mutations) == "table" then
                for _, mName in pairs(record.Mutations) do
                    local nameStr = tostring(mName)
                    if nameStr ~= "" and nameStr ~= "nil" then
                        table.insert(foundMutations, nameStr)
                        if MutationRegistry[nameStr] and type(MutationRegistry[nameStr].ValueMulti) == "number" then
                            finalEarning = finalEarning * MutationRegistry[nameStr].ValueMulti
                        end
                    end
                end
            end
            finalEarning = round(finalEarning)
            local earningThreshold = tonumber(configs.EarningRate) or 0
            if earningThreshold > 0 and finalEarning < earningThreshold then return end
            local username = LocalPlayer and LocalPlayer.Name or "Unknown"
            if configs.HideUsername then username = "*****" end
            local mutationText = "None"
            if #foundMutations > 0 then mutationText = table.concat(foundMutations, ", ") end
            local embed = {
                title = "Decode Hub | Egg Successfully Stolen",
                color = 1752220,
                fields = {
                    { name = "-> Profile :", value = "Username : `" .. username .. "`", inline = false },
                    { name = "-> Egg Info :", value = table.concat({
                        "Pet Name : `" .. tostring(petName) .. "`",
                        "Rarity : `" .. tostring(rarityName) .. "`",
                        "Weight : `" .. formatComma(finalWeight) .. "Kg`",
                        "Mutation : `" .. mutationText .. "`",
                        "Earning : `$" .. formatComma(finalEarning) .. "/s`"
                    }, "\n"), inline = false }
                },
                footer = { text = "Decode Hub • Steal An Egg" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            local payload = { username = "Decode Hub", embeds = { embed } }
            local body = HttpService:JSONEncode(payload)
            local req = syn and syn.request or http_request or request
            if req then
                req({ Url = configs.EggURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            end
        end)
    end)
end

local function isValidEggInstance(inst)
    if not inst or not inst.Parent then return false end
    if not inst:IsDescendantOf(Workspace) then return false end
    local objectsFolder = Workspace:FindFirstChild("__OBJECTS")
    if objectsFolder and inst:IsDescendantOf(objectsFolder) then return false end
    return inst:IsA("Model") or inst:IsA("BasePart")
end

local function deepScanForUid(root, uid, allowAttributeScan)
    if not root or not root.Parent then return nil end
    local target = root:FindFirstChild(uid, true)
    if target then return target end
    if allowAttributeScan == false then return nil end
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("StringValue") and desc.Value == uid then return desc.Parent end
        if desc:GetAttribute("Uid") == uid or desc:GetAttribute("ID") == uid then return desc end
        if desc.Name == "Uid" and desc:IsA("StringValue") and desc.Value == uid then return desc.Parent and desc.Parent.Parent or desc.Parent end
    end
    return nil
end

local function getAreaEggIndex(force)
    return AreaEggEntries
end

local function isUidInAreaSlots(uid, force)
    local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if not slotsFolder then return false end
    local entry = getAreaEggIndex(force)[tostring(uid)]
    if not entry then return false end
    if not entry.Parent then return false end
    return entry:IsDescendantOf(slotsFolder)
end

local function resolveEggStatus(inst)
    local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if slotsFolder and inst:IsDescendantOf(slotsFolder) then return "Safe in Nest (AreaEggSlotsClient)" end
    return "Stolen / Moved (Direct Workspace Parent)"
end

local function findEggInstance(uid)
    local uidKey = tostring(uid)
    local cached = Caches.EggInstance[uidKey]
    if cached and isValidEggInstance(cached) then
        return cached, resolveEggStatus(cached)
    end
    Caches.EggInstance[uidKey] = nil

    local now = clock()
    local notFoundTime = Caches.EggNotFound[uidKey]
    local notFoundTTL = State.NewCycleGracePending and 2 or 0.75
    if notFoundTime and now - notFoundTime < notFoundTTL then return nil, "Not Found" end

    local areaEntry = getAreaEggIndex(false)[uidKey]
    if areaEntry and isValidEggInstance(areaEntry) then
        Caches.EggInstance[uidKey] = areaEntry
        Caches.EggNotFound[uidKey] = nil
        return areaEntry, "Safe in Nest (AreaEggSlotsClient)"
    end

    local debrisFolder = Workspace:FindFirstChild("__DEBRIS")
    if debrisFolder then
        local allowAttrScan = now - (State.LastDebrisAttrScan or 0) > 0.5
        if allowAttrScan then State.LastDebrisAttrScan = now end
        local target = deepScanForUid(debrisFolder, uidKey, allowAttrScan)
        if target and isValidEggInstance(target) then
            Caches.EggInstance[uidKey] = target
            Caches.EggNotFound[uidKey] = nil
            return target, "Stolen / Moved (Direct Workspace Parent)"
        end
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name ~= "__OBJECTS" and child.Name ~= "__DEBRIS" and child.Name ~= "AreaEggSlotsClient" then
            if child.Name == uidKey or child:GetAttribute("Uid") == uidKey or child:GetAttribute("ID") == uidKey then
                if isValidEggInstance(child) then
                    Caches.EggInstance[uidKey] = child
                    Caches.EggNotFound[uidKey] = nil
                    return child, "Stolen / Moved (Direct Workspace Parent)"
                end
            end
        end
    end

    Caches.EggNotFound[uidKey] = now
    return nil, "Not Found"
end

local function eggExistsForTarget(uid)
    local uidKey = tostring(uid)
    if isUidInAreaSlots(uidKey, false) then return true end
    local eggInstance = findEggInstance(uidKey)
    if eggInstance and isValidEggInstance(eggInstance) then
        return true
    end
    return false
end

local function isEggLooseInWorld(uid)
    local eggInstance = findEggInstance(uid)
    if not eggInstance or not isValidEggInstance(eggInstance) then return false end
    local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if slotsFolder and eggInstance:IsDescendantOf(slotsFolder) then return false end
    return true
end

local function checkIsStillCarrying(uid, originalEggPosition)
    local character = LocalPlayer.Character
    if not character then return false end
    local embeddedCheck = deepScanForUid(character, uid, true)
    if embeddedCheck then return true end
    local eggInstance = findEggInstance(uid)
    if not eggInstance then return false end
    if eggInstance:IsDescendantOf(character) then return true end
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("JointInstance") or desc:IsA("WeldConstraint") then
            local p0 = desc.Part0
            local p1 = desc.Part1
            if (p0 and p0:IsDescendantOf(eggInstance)) or (p1 and p1:IsDescendantOf(eggInstance)) then
                return true
            end
        end
    end
    for _, desc in ipairs(eggInstance:GetDescendants()) do
        if desc:IsA("JointInstance") or desc:IsA("WeldConstraint") then
            local p0 = desc.Part0
            local p1 = desc.Part1
            if (p0 and p0:IsDescendantOf(character)) or (p1 and p1:IsDescendantOf(character)) then
                return true
            end
        end
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local eggPos = getEggPosition(eggInstance)
    if rootPart and eggPos and originalEggPosition then
        local dx = rootPart.Position.X - eggPos.X
        local dz = rootPart.Position.Z - eggPos.Z
        local flat = math.sqrt(dx * dx + dz * dz)
        local moved = (eggPos - originalEggPosition).Magnitude > 2
        local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
        local inSlots = slotsFolder and eggInstance:IsDescendantOf(slotsFolder)
        if moved and flat < 8 and not inSlots then
            return true
        end
    end
    return false
end

local function checkIsStillCarryingFast(uid, originalEggPosition)
    local now = clock()
    if Caches.CarryCheck.uid == uid and now - Caches.CarryCheck.time < 0.05 then return Caches.CarryCheck.value end
    local value = checkIsStillCarrying(uid, originalEggPosition)
    Caches.CarryCheck.uid = uid
    Caches.CarryCheck.time = now
    Caches.CarryCheck.value = value
    return value
end

local function isTargetStillSelected(record)
    if isNightTime() then return false end
    local matchedSelection = false
    if Configurations.StealEgg then
        if Configurations.SelectedEggsFilter and table.find(Configurations.SelectedEggsFilter, record.AssetCategory) ~= nil then matchedSelection = true end
    elseif Configurations.StealEggRarity then
        if Configurations.SelectedRarityFilter then
            local itemRarity = getRarityFromName(record.AssetCategory)
            if itemRarity and table.find(Configurations.SelectedRarityFilter, itemRarity) ~= nil then matchedSelection = true end
        end
    elseif Configurations.StealEarnRate then
        local threshold = tonumber(Configurations.EarnRate) or 0
        if getRecordEarning(record) >= threshold then matchedSelection = true end
    end
    if not matchedSelection then return false end
    return true
end

local function getMyPlotNumber(force)
    local now = clock()
    if not force and Caches.Plot.time > 0 and now - Caches.Plot.time < 5 then return Caches.Plot.value end
    local value = nil
    local success, rawResponse = pcall(function() return askState:InvokeServer() end)
    if success and rawResponse and rawResponse.OwnersBySlot then
        local myUserId = LocalPlayer.UserId
        for slotNumber, ownerId in pairs(rawResponse.OwnersBySlot) do
            if tonumber(ownerId) == myUserId then
                value = tostring(slotNumber)
                break
            end
        end
    end
    Caches.Plot.time = now
    Caches.Plot.value = value
    return value
end

local function getIsOnTreadmill(force)
    local now = clock()
    if not force and Caches.Treadmill.time > 0 and now - Caches.Treadmill.time < 1 then return Caches.Treadmill.value end
    local value = false
    local success, rawResponse = pcall(function() return askRenderSnapshot:InvokeServer() end)
    if success and type(rawResponse) == "table" then
        local myUserId = LocalPlayer.UserId
        for _, userId in ipairs(rawResponse) do
            if tonumber(userId) == myUserId then
                value = true
                break
            end
        end
    end
    Caches.Treadmill.time = now
    Caches.Treadmill.value = value
    return value
end

local function forceUnequipTreadmill()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local deadline = clock() + 3
    while clock() < deadline do
        pcall(function()
            if askDoff then
                askDoff:InvokeServer()
            end
        end)
        if humanoid then
            humanoid.Sit = false
            humanoid.Jump = true
        end
        if character then
            for _, desc in ipairs(character:GetDescendants()) do
                if desc:IsA("Weld") or desc:IsA("WeldConstraint") or desc:IsA("Snap") then
                    local p0 = desc.Part0
                    local p1 = desc.Part1
                    if (p0 and not p0:IsDescendantOf(character)) or (p1 and not p1:IsDescendantOf(character)) then
                        pcall(function() desc:Destroy() end)
                    end
                end
            end
        end
        if rootPart then
            rootPart.AssemblyLinearVelocity = v3new(0, 0, 0)
            rootPart.AssemblyAngularVelocity = v3new(0, 0, 0)
        end
        task.wait(0.1)
        Caches.Treadmill.time = 0
        if not getIsOnTreadmill(true) then
            break
        end
    end
    if humanoid then
        humanoid.Sit = false
        humanoid.Jump = true
    end
    if rootPart then
        rootPart.AssemblyLinearVelocity = v3new(0, 0, 0)
        rootPart.AssemblyAngularVelocity = v3new(0, 0, 0)
    end
    task.wait(0.05)
    Caches.Treadmill.time = clock()
    Caches.Treadmill.value = false
    return true
end

local function destroyHumanoidAndFixCamera()
    State.RestoredCharacter = nil
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoid then
        State.SavedUseJumpPower = humanoid.UseJumpPower
        State.SavedJumpPower = humanoid.JumpPower > 0 and humanoid.JumpPower or 50
        State.SavedJumpHeight = humanoid.JumpHeight > 0 and humanoid.JumpHeight or 7.2
        local offset = 3.8
        if humanoid.HipHeight and humanoid.HipHeight > 0 then
            offset = max(3.8, humanoid.HipHeight + (rootPart and rootPart.Size.Y * 0.5 or 1) + 1.2)
        end
        State.SavedGroundOffset = offset
        if not State.SavedHumanoid then
            State.SavedHumanoid = cloneHumanoidWithDescendants(humanoid)
        end
        setCharacterControlsEnabled(false)
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false
        humanoid:Destroy()
    end
    if rootPart then
        rootPart.AssemblyLinearVelocity = v3new(0, 0, 0)
        rootPart.AssemblyAngularVelocity = v3new(0, 0, 0)
        local alignedPos = alignToGround(rootPart.Position)
        rootPart.CFrame = cfnew(clampVerticalStep(rootPart.Position, alignedPos))
    end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part ~= rootPart then
            part.AssemblyLinearVelocity = v3new(0, 0, 0)
            part.AssemblyAngularVelocity = v3new(0, 0, 0)
        end
    end
    ensureFreeCamera(rootPart or character)
end

local function restoreHumanoid()
    local character = LocalPlayer.Character
    if not character then
        State.SavedHumanoid = nil
        State.RestoredCharacter = nil
        return
    end
    for _, desc in ipairs(character:GetDescendants()) do
        if desc.Name == "AntiGravityForSteal" or desc:IsA("BodyVelocity") or desc:IsA("BodyPosition") or desc:IsA("BodyGyro") then
            pcall(function() desc:Destroy() end)
        end
    end
    local currentHumanoid = character:FindFirstChildWhichIsA("Humanoid")
    if currentHumanoid then
        if State.RestoredCharacter == character then return end
        currentHumanoid.UseJumpPower = State.SavedUseJumpPower
        currentHumanoid.JumpPower = State.SavedJumpPower
        currentHumanoid.JumpHeight = State.SavedJumpHeight
        currentHumanoid.PlatformStand = false
        currentHumanoid.Sit = false
        setCharacterControlsEnabled(true)
        ensureFreeCamera(currentHumanoid)
        State.RestoredCharacter = character
        return
    end
    if not State.SavedHumanoid then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local alignedPos = alignToGround(rootPart.Position)
        rootPart.CFrame = cfnew(clampVerticalStep(rootPart.Position, alignedPos))
        rootPart.AssemblyLinearVelocity = v3new(0,0,0)
        rootPart.AssemblyAngularVelocity = v3new(0,0,0)
    end
    local newHumanoid = State.SavedHumanoid
    State.SavedHumanoid = nil
    for _, child in ipairs(newHumanoid:GetChildren()) do
        if child:IsA("Animator") then child:Destroy() end
    end
    newHumanoid.Parent = character
    Instance.new("Animator", newHumanoid)
    pcall(function()
        newHumanoid.PlatformStand = false
        newHumanoid.Sit = false
        newHumanoid.AutoRotate = true
        newHumanoid.WalkSpeed = newHumanoid.WalkSpeed > 0 and newHumanoid.WalkSpeed or 16
        newHumanoid.UseJumpPower = State.SavedUseJumpPower
        newHumanoid.JumpPower = State.SavedJumpPower
        newHumanoid.JumpHeight = State.SavedJumpHeight
        for _, stateType in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            if stateType ~= Enum.HumanoidStateType.None then
                pcall(function() newHumanoid:SetStateEnabled(stateType, true) end)
            end
        end
        newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        newHumanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        newHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)
    if character.PrimaryPart == nil and rootPart then character.PrimaryPart = rootPart end
    local animate = character:FindFirstChild("Animate")
    if animate then
        animate.Disabled = true
        task.wait()
        animate.Disabled = false
    end
    task.wait(0.05)
    pcall(function()
        newHumanoid:ChangeState(Enum.HumanoidStateType.Landed)
        newHumanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
    ensureFreeCamera(newHumanoid)
    local controls = getPlayerControls()
    if controls then
        pcall(function()
            if type(controls.OnCharacterAdded) == "function" then
                controls:OnCharacterAdded(character)
            end
            if type(controls.OnHumanoidAdded) == "function" then
                controls:OnHumanoidAdded(newHumanoid)
            end
            controls.humanoid = newHumanoid
            if controls.activeController then
                controls.activeController.humanoid = newHumanoid
                if type(controls.activeController.SetHumanoid) == "function" then
                    controls.activeController:SetHumanoid(newHumanoid)
                end
            end
            controls:Enable()
        end)
    else
        setCharacterControlsEnabled(true)
    end
    State.RestoredCharacter = character
end

local function waitForWallCollision(stillWantedFunc, holdPosition)
    local objectsFolder = Workspace:FindFirstChild("__OBJECTS")
    local areasFolder = objectsFolder and objectsFolder:FindFirstChild("Areas")
    if not areasFolder then return end
    while stillWantedFunc() and not isNightTime() do
        if not isWallCollisionActive() then break end
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            if holdPosition then
                local aligned = alignToGround(holdPosition)
                rootPart.CFrame = cfnew(clampVerticalStep(rootPart.Position, aligned))
            end
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
        end
        task.wait(0.1)
    end
end

local function tweenTo(targetPosition, shouldContinue, stopDistance)
    if not targetPosition then return false end

    if not waitForCharacterReady(10) then return false end

    local character = LocalPlayer.Character
    if not character then return false end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local speed = tonumber(Configurations.HopStuds or Configurations.HopStud) or 16
    if speed <= 0 then speed = 16 end

    local arriveDistance = tonumber(stopDistance) or 0.5
    local lastDistance = nil
    local lastProgressTime = clock()
    local lastSetPosition = nil
    local correctionCount = 0
    local wallBumpCount = 0
    local lastWallBumpTime = 0

    ensureFreeCamera(rootPart)

    local wallParams = RaycastParams.new()
    wallParams.FilterType = Enum.RaycastFilterType.Exclude
    wallParams.FilterDescendantsInstances = {character}
    wallParams.IgnoreWater = true

    local function detectWallObstacle(fromPos, toPos)
        local dir = toPos - fromPos
        local dist = dir.Magnitude
        if dist < 1 then return nil end
        local unitDir = dir.Unit
        local rayOrigin = fromPos + v3new(0, 2, 0)
        local rayLength = dist + 3
        local hit = Workspace:Raycast(rayOrigin, unitDir * rayLength, wallParams)
        if hit and hit.Instance.CanCollide then
            return hit
        end
        return nil
    end

    local function tryAvoidWall(currentPos, targetPos, wallHit)
        if not wallHit then return targetPos end
        
        local wallNormal = wallHit.Normal
        local _wallPos = wallHit.Position
        
        local _dirToTarget = (targetPos - currentPos).Unit
        local pushPerp = v3new(-wallNormal.Z, 0, wallNormal.X)
        
        local offsetAmount = 3
        local alt1 = v3new(targetPos.X + pushPerp.X * offsetAmount, targetPos.Y, targetPos.Z + pushPerp.Z * offsetAmount)
        local alt2 = v3new(targetPos.X - pushPerp.X * offsetAmount, targetPos.Y, targetPos.Z - pushPerp.Z * offsetAmount)
        
        local alt1Clear = not detectWallObstacle(currentPos, alt1)
        local alt2Clear = not detectWallObstacle(currentPos, alt2)
        
        if alt1Clear then return alt1 end
        if alt2Clear then return alt2 end
        
        local alt3 = v3new(targetPos.X + pushPerp.X * offsetAmount * 2, targetPos.Y, targetPos.Z + pushPerp.Z * offsetAmount * 2)
        local alt4 = v3new(targetPos.X - pushPerp.X * offsetAmount * 2, targetPos.Y, targetPos.Z - pushPerp.Z * offsetAmount * 2)
        
        if not detectWallObstacle(currentPos, alt3) then return alt3 end
        if not detectWallObstacle(currentPos, alt4) then return alt4 end
        
        return targetPos
    end

    while true do
        if LocalPlayer.Character ~= character then
            return false
        end

        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            return false
        end

        if humanoid and isHumanoidRecovering(humanoid) then
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
            waitForCharacterReady(10)
            return false
        end

        if isNightTime() then
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
            return false
        end

        if shouldContinue and not shouldContinue() then
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
            return false
        end

        if not rootPart.Parent then return false end

        local deltaTime = RunService.Heartbeat:Wait()
        if deltaTime > 0.1 then deltaTime = 0.1 end

        if LocalPlayer.Character ~= character or not rootPart.Parent then
            return false
        end

        local currentPos = rootPart.Position
        local dx = targetPosition.X - currentPos.X
        local dz = targetPosition.Z - currentPos.Z
        local distXZ = math.sqrt(dx * dx + dz * dz)

        if lastSetPosition then
            local correctionDistance = (currentPos - lastSetPosition).Magnitude
            local correctionLimit = max(10, speed * 0.12)
            if correctionDistance > correctionLimit then
                correctionCount = correctionCount + 1
            else
                correctionCount = max(correctionCount - 1, 0)
            end
        end

        if not lastDistance or distXZ < lastDistance - 0.15 then
            lastDistance = distXZ
            lastProgressTime = clock()
        elseif lastDistance and distXZ > lastDistance + 10 then
            correctionCount = correctionCount + 1
        end

        if correctionCount >= 4 or clock() - lastProgressTime > 1.35 then
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
            return false
        end

        if distXZ <= arriveDistance then
            local groundY = findSolidGround(targetPosition.X, max(currentPos.Y, targetPosition.Y), targetPosition.Z, buildGroundIgnoreList())
            local finalY = groundY and (groundY + State.SavedGroundOffset) or max(currentPos.Y, targetPosition.Y)
            local finalPos = v3new(targetPosition.X, finalY, targetPosition.Z)
            rootPart.CFrame = cfnew(finalPos)
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
            break
        end

        local stepXZ = min(speed * deltaTime, distXZ)
        local nextX = currentPos.X + (dx / distXZ) * stepXZ
        local nextZ = currentPos.Z + (dz / distXZ) * stepXZ
        local nextPosGround = alignToGround(v3new(nextX, currentPos.Y, nextZ))
        nextPosGround = clampVerticalStep(currentPos, nextPosGround)

        local wallHit = detectWallObstacle(currentPos, nextPosGround)
        
        if wallHit then
            wallBumpCount = wallBumpCount + 1
            lastWallBumpTime = clock()
            
            if wallBumpCount > 3 and clock() - lastWallBumpTime < 2 then
                local avoidedTarget = tryAvoidWall(currentPos, targetPosition, wallHit)
                if avoidedTarget ~= targetPosition then
                    targetPosition = avoidedTarget
                    wallBumpCount = 0
                else
                    local bumpPos = wallHit.Position - (wallHit.Normal * 2)
                    bumpPos = v3new(bumpPos.X, nextPosGround.Y, bumpPos.Z)
                    rootPart.CFrame = cfnew(bumpPos)
                    rootPart.AssemblyLinearVelocity = v3new(0,0,0)
                    rootPart.AssemblyAngularVelocity = v3new(0,0,0)
                    task.wait(0.05)
                    continue
                end
            else
                local bumpPos = wallHit.Position - (wallHit.Normal * 2)
                bumpPos = v3new(bumpPos.X, nextPosGround.Y, bumpPos.Z)
                rootPart.CFrame = cfnew(bumpPos)
                rootPart.AssemblyLinearVelocity = v3new(0,0,0)
                rootPart.AssemblyAngularVelocity = v3new(0,0,0)
                task.wait(0.05)
                continue
            end
        else
            wallBumpCount = max(wallBumpCount - 1, 0)
        end

        local maxStep = speed * deltaTime + 10
        if (nextPosGround - currentPos).Magnitude > maxStep then
            nextPosGround = v3new(nextX, currentPos.Y, nextZ)
        end

        rootPart.CFrame = cfnew(nextPosGround)
        lastSetPosition = nextPosGround

        rootPart.AssemblyLinearVelocity = v3new(0,0,0)
        rootPart.AssemblyAngularVelocity = v3new(0,0,0)
    end

    ensureFreeCamera(rootPart)
    return true
end

local function followMovingEgg(uid, shouldContinue)
    if not waitForCharacterReady(10) then return false, nil end
    local character = LocalPlayer.Character
    if not character then return false, nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false, nil end
    local speed = tonumber(Configurations.HopStuds or Configurations.HopStud) or 16
    if speed <= 0 then speed = 16 end
    local startedAt = clock()
    local latestEggInstance = nil
    ensureFreeCamera(rootPart)
    
    local wallParams = RaycastParams.new()
    wallParams.FilterType = Enum.RaycastFilterType.Exclude
    wallParams.FilterDescendantsInstances = {character}
    wallParams.IgnoreWater = true
    
    local function detectWallObstacle(fromPos, toPos)
        local dir = toPos - fromPos
        local dist = dir.Magnitude
        if dist < 1 then return nil end
        local unitDir = dir.Unit
        local rayOrigin = fromPos + v3new(0, 2, 0)
        local rayLength = dist + 3
        local hit = Workspace:Raycast(rayOrigin, unitDir * rayLength, wallParams)
        if hit and hit.Instance.CanCollide then
            return hit
        end
        return nil
    end
    
    local wallBumpCount = 0
    local lastWallBumpTime = 0
    
    while clock() - startedAt < 30 do
        if isNightTime() then return false, latestEggInstance end
        if shouldContinue and not shouldContinue() then return false, latestEggInstance end
        if not rootPart.Parent then return false, latestEggInstance end
        if LocalPlayer.Character ~= character then return false, latestEggInstance end
        local humanoidNow = character:FindFirstChildWhichIsA("Humanoid")
        if humanoidNow and isHumanoidRecovering(humanoidNow) then
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
            waitForCharacterReady(10)
            return false, latestEggInstance
        end
        local deltaTime = RunService.Heartbeat:Wait()
        if deltaTime > 0.1 then deltaTime = 0.1 end
        local eggInstance = findEggInstance(uid)
        if not eggInstance then return false, latestEggInstance end
        latestEggInstance = eggInstance
        local eggPosition = getEggPosition(eggInstance)
        if not eggPosition then return false, latestEggInstance end
        local currentPos = rootPart.Position
        local dx = eggPosition.X - currentPos.X
        local dz = eggPosition.Z - currentPos.Z
        local flatDistance = math.sqrt(dx * dx + dz * dz)
        local eggApproachRadius = getEggApproachRadius(eggInstance)
        local arrivalDistance = max(4, eggApproachRadius + 2)
        if flatDistance <= arrivalDistance then
            local groundY = findSolidGround(eggPosition.X, max(currentPos.Y, eggPosition.Y), eggPosition.Z, buildGroundIgnoreList())
            local finalY = groundY and (groundY + State.SavedGroundOffset) or max(currentPos.Y, eggPosition.Y)
            rootPart.CFrame = cfnew(eggPosition.X, finalY, eggPosition.Z)
            rootPart.AssemblyLinearVelocity = v3new(0,0,0)
            rootPart.AssemblyAngularVelocity = v3new(0,0,0)
            return true, latestEggInstance
        end
        local movementTarget = eggPosition
        local movingPart = nil
        if eggInstance:IsA("BasePart") then movingPart = eggInstance
        elseif eggInstance:IsA("Model") then movingPart = eggInstance.PrimaryPart or eggInstance:FindFirstChildWhichIsA("BasePart", true) end
        if movingPart then
            local velocity = movingPart.AssemblyLinearVelocity
            if velocity.Magnitude <= 100 then
                local leadTime = min(flatDistance / speed, 0.2)
                movementTarget = movementTarget + velocity * leadTime
            end
        end
        local mdx = movementTarget.X - currentPos.X
        local mdz = movementTarget.Z - currentPos.Z
        local movementDistanceXZ = math.sqrt(mdx * mdx + mdz * mdz)
        if movementDistanceXZ > 0 then
            local stepDistance = min(speed * deltaTime, movementDistanceXZ)
            local nextX = currentPos.X + (mdx / movementDistanceXZ) * stepDistance
            local nextZ = currentPos.Z + (mdz / movementDistanceXZ) * stepDistance
            local nextPosGround = alignToGround(v3new(nextX, currentPos.Y, nextZ))
            nextPosGround = clampVerticalStep(currentPos, nextPosGround)
            
            local wallHit = detectWallObstacle(currentPos, nextPosGround)
            if wallHit then
                wallBumpCount = wallBumpCount + 1
                lastWallBumpTime = clock()
                if wallBumpCount > 3 and clock() - lastWallBumpTime < 2 then
                    local _dirToTarget = (movementTarget - currentPos).Unit
                    local wallNormal = wallHit.Normal
                    local pushPerp = v3new(-wallNormal.Z, 0, wallNormal.X)
                    local offsetAmount = 4
                    local altTarget = v3new(movementTarget.X + pushPerp.X * offsetAmount, movementTarget.Y, movementTarget.Z + pushPerp.Z * offsetAmount)
                    if not detectWallObstacle(currentPos, altTarget) then
                        movementTarget = altTarget
                        wallBumpCount = 0
                    else
                        local bumpPos = wallHit.Position - (wallHit.Normal * 2)
                        bumpPos = v3new(bumpPos.X, nextPosGround.Y, bumpPos.Z)
                        rootPart.CFrame = cfnew(bumpPos)
                        rootPart.AssemblyLinearVelocity = v3new(0,0,0)
                        rootPart.AssemblyAngularVelocity = v3new(0,0,0)
                        task.wait(0.05)
                        continue
                    end
                else
                    local bumpPos = wallHit.Position - (wallHit.Normal * 2)
                    bumpPos = v3new(bumpPos.X, nextPosGround.Y, bumpPos.Z)
                    rootPart.CFrame = cfnew(bumpPos)
                    rootPart.AssemblyLinearVelocity = v3new(0,0,0)
                    rootPart.AssemblyAngularVelocity = v3new(0,0,0)
                    task.wait(0.05)
                    continue
                end
            else
                wallBumpCount = max(wallBumpCount - 1, 0)
            end
            
            local maxStep = speed * deltaTime + 10
            if (nextPosGround - currentPos).Magnitude > maxStep then
                nextPosGround = v3new(nextX, currentPos.Y, nextZ)
            end
            rootPart.CFrame = cfnew(nextPosGround)
        end
        rootPart.AssemblyLinearVelocity = v3new(0,0,0)
        rootPart.AssemblyAngularVelocity = v3new(0,0,0)
    end
    rootPart.AssemblyLinearVelocity = v3new(0,0,0)
    rootPart.AssemblyAngularVelocity = v3new(0,0,0)
    return false, latestEggInstance
end

local function buildTrapAvoidingWaypoints(startPos, endPos)
    local traps = getTrapHitboxPositions()
    local clearance = TRAP_AVOID_RADIUS + 7

    if #traps == 0 then
        return { endPos }
    end

    local function pointClear(pos)
        local radiusSq = clearance * clearance

        for _, trapPos in ipairs(traps) do
            local dx = pos.X - trapPos.X
            local dz = pos.Z - trapPos.Z

            if dx * dx + dz * dz <= radiusSq and abs(pos.Y - trapPos.Y) <= 35 then
                return false
            end
        end

        return true
    end

    local function segmentClear(a, b)
        local radiusSq = clearance * clearance
        local abx = b.X - a.X
        local abz = b.Z - a.Z
        local aby = b.Y - a.Y
        local lengthSq = abx * abx + abz * abz

        if lengthSq < 0.01 then
            return pointClear(b)
        end

        for _, trapPos in ipairs(traps) do
            local apx = trapPos.X - a.X
            local apz = trapPos.Z - a.Z
            local t = (apx * abx + apz * abz) / lengthSq

            if t < 0 then
                t = 0
            elseif t > 1 then
                t = 1
            end

            local closestX = a.X + abx * t
            local closestZ = a.Z + abz * t
            local closestY = a.Y + aby * t
            local dx = closestX - trapPos.X
            local dz = closestZ - trapPos.Z

            if dx * dx + dz * dz <= radiusSq and abs(closestY - trapPos.Y) <= 35 then
                local adx = a.X - trapPos.X
                local adz = a.Z - trapPos.Z
                local bdx = b.X - trapPos.X
                local bdz = b.Z - trapPos.Z
                local distanceA = math.sqrt(adx * adx + adz * adz)
                local distanceB = math.sqrt(bdx * bdx + bdz * bdz)
                local startInside = distanceA <= clearance and abs(a.Y - trapPos.Y) <= 35
                local endInside = distanceB <= clearance and abs(b.Y - trapPos.Y) <= 35

                if not (startInside and not endInside and distanceB > distanceA + 0.5) then
                    return false
                end
            end
        end

        return true
    end

    if segmentClear(startPos, endPos) then
        return { endPos }
    end

    local function solvePath(radii, sampleCount)
        local nodes = { startPos, endPos }

        for _, trapPos in ipairs(traps) do
            for _, radiusOffset in ipairs(radii) do
                local radius = clearance + radiusOffset

                for index = 1, sampleCount do
                    local angle = (index - 1) * math.pi * 2 / sampleCount
                    local candidate = v3new(
                        trapPos.X + math.cos(angle) * radius,
                        startPos.Y,
                        trapPos.Z + math.sin(angle) * radius
                    )

                    if pointClear(candidate) then
                        table.insert(nodes, candidate)
                    end
                end
            end
        end

        local nodeCount = #nodes
        local distances = table.create(nodeCount, huge)
        local previous = table.create(nodeCount)
        local used = table.create(nodeCount, false)

        distances[1] = 0

        for iteration = 1, nodeCount do
            local bestIndex = nil
            local bestDistance = huge

            for index = 1, nodeCount do
                if not used[index] and distances[index] < bestDistance then
                    bestDistance = distances[index]
                    bestIndex = index
                end
            end

            if not bestIndex then
                break
            end

            if bestIndex == 2 then
                break
            end

            used[bestIndex] = true
            local fromPosition = nodes[bestIndex]

            for index = 2, nodeCount do
                if index ~= bestIndex and not used[index] then
                    local toPosition = nodes[index]

                    if segmentClear(fromPosition, toPosition) then
                        local edgeDistance = getFlatDistanceXZ(fromPosition, toPosition)
                        local candidateDistance = bestDistance + edgeDistance

                        if candidateDistance < distances[index] then
                            distances[index] = candidateDistance
                            previous[index] = bestIndex
                        end
                    end
                end
            end

            if iteration % 10 == 0 then
                task.wait()
            end
        end

        if not previous[2] then
            return nil
        end

        local path = {}
        local cursor = 2

        while cursor and cursor ~= 1 do
            table.insert(path, 1, nodes[cursor])
            cursor = previous[cursor]
        end

        if cursor ~= 1 or #path == 0 then
            return nil
        end

        return path
    end

    local path = solvePath({ 8, 28 }, 16)
    if path then
        return path
    end

    path = solvePath({ 12, 40, 72 }, 20)
    if path then
        return path
    end

    path = solvePath({ 20, 60, 110 }, 24)
    if path then
        return path
    end

    return nil
end

local function returnToSafeZone(shouldContinue)
    local safeZonePos = getSafeZonePosition()
    if not safeZonePos then return false end

    return tweenTo(safeZonePos, shouldContinue, 0.5)
end

local function deliverToSafeZoneAvoidingTraps(targetUid)
    local safeZonePos = getSafeZonePosition()
    if not safeZonePos then return false end

    local clearance = TRAP_AVOID_RADIUS + 7
    local lastTrapRefresh = 0

    local function findAdjustedEnd(fromPos, basePos)
        if isSegmentTrapClear(fromPos, basePos, clearance) then return basePos end
        local dir = basePos - fromPos
        dir = v3new(dir.X, 0, dir.Z)
        local mag = dir.Magnitude
        if mag > 0.01 then
            dir = dir / mag
        else
            dir = v3new(0, 0, 1)
        end
        local perp = v3new(-dir.Z, 0, dir.X)
        for step = 4, 70, 4 do
            for sign = -1, 1, 2 do
                local cand = v3new(
                    basePos.X + perp.X * sign * step,
                    basePos.Y,
                    basePos.Z + perp.Z * sign * step
                )
                if isSegmentTrapClear(fromPos, cand, clearance) then
                    return cand
                end
            end
        end
        return basePos
    end

    while not isNightTime() and isStillAllowed() do
        if not checkIsStillCarryingFast(targetUid, nil) then
            return false
        end

        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            return false
        end

        if getFlatDistanceXZ(rootPart.Position, safeZonePos) <= 0.5 then
            rootPart.AssemblyLinearVelocity = v3new(0, 0, 0)
            rootPart.AssemblyAngularVelocity = v3new(0, 0, 0)
            return true
        end

        Caches.Trap.time = 0

        local function makeContinue(waypoint, replanFlagSetter)
            return function()
                if isNightTime() or not isStillAllowed() then
                    return false
                end

                if not checkIsStillCarryingFast(targetUid, nil) then
                    return false
                end

                local currentCharacter = LocalPlayer.Character
                local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
                if not currentRoot then
                    return false
                end

                local now = clock()
                if now - lastTrapRefresh >= 0.25 then
                    lastTrapRefresh = now
                    Caches.Trap.time = 0
                end

                if not isSegmentTrapClear(currentRoot.Position, waypoint, clearance) then
                    if replanFlagSetter then replanFlagSetter() end
                    return false
                end

                return true
            end
        end

        local currentRootPos = rootPart.Position
        local adjustedEnd = findAdjustedEnd(currentRootPos, safeZonePos)

        if isSegmentTrapClear(currentRootPos, adjustedEnd, clearance) then
            local directContinue = makeContinue(adjustedEnd, function() end)
            local reachedDirect = tweenTo(adjustedEnd, directContinue, 2.0)

            local currentCharacter = LocalPlayer.Character
            local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")

            if reachedDirect then
                if currentRoot then
                    currentRoot.AssemblyLinearVelocity = v3new(0, 0, 0)
                    currentRoot.AssemblyAngularVelocity = v3new(0, 0, 0)
                end
                tweenTo(safeZonePos, function()
                    if isNightTime() or not isStillAllowed() then return false end
                    if not checkIsStillCarryingFast(targetUid, nil) then return false end
                    return true
                end, 0.5)
                if currentRoot and getFlatDistanceXZ(currentRoot.Position, safeZonePos) <= 1 then
                    currentRoot.AssemblyLinearVelocity = v3new(0, 0, 0)
                    currentRoot.AssemblyAngularVelocity = v3new(0, 0, 0)
                    return true
                end
            else
                if currentRoot and getFlatDistanceXZ(currentRoot.Position, safeZonePos) <= 1 then
                    currentRoot.AssemblyLinearVelocity = v3new(0, 0, 0)
                    currentRoot.AssemblyAngularVelocity = v3new(0, 0, 0)
                    return true
                end
            end

            if not checkIsStillCarryingFast(targetUid, nil) then
                return false
            end

            task.wait(0.03)
        else
            local waypoints = buildTrapAvoidingWaypoints(currentRootPos, adjustedEnd)

            if not waypoints or #waypoints == 0 then
                local fallbackContinue = makeContinue(adjustedEnd, function() end)
                local reachedFallback = tweenTo(adjustedEnd, fallbackContinue, 2.0)
                if reachedFallback then
                    tweenTo(safeZonePos, function()
                        if isNightTime() or not isStillAllowed() then return false end
                        if not checkIsStillCarryingFast(targetUid, nil) then return false end
                        return true
                    end, 0.5)
                end
                local currentCharacter = LocalPlayer.Character
                local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
                if currentRoot and getFlatDistanceXZ(currentRoot.Position, safeZonePos) <= 1 then
                    currentRoot.AssemblyLinearVelocity = v3new(0, 0, 0)
                    currentRoot.AssemblyAngularVelocity = v3new(0, 0, 0)
                    return true
                end
                rootPart.AssemblyLinearVelocity = v3new(0, 0, 0)
                rootPart.AssemblyAngularVelocity = v3new(0, 0, 0)
                task.wait(0.1)
            else
                local mustReplan = false

                for index, waypoint in ipairs(waypoints) do
                    local stopDistance = index == #waypoints and 2.0 or 2.5
                    local deliveryContinue = makeContinue(waypoint, function() mustReplan = true end)
                    local reached = tweenTo(waypoint, deliveryContinue, stopDistance)

                    if not reached then
                        if not checkIsStillCarryingFast(targetUid, nil) then
                            return false
                        end
                        mustReplan = true
                        break
                    end
                end

                local currentCharacter = LocalPlayer.Character
                local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")

                if currentRoot then
                    if getFlatDistanceXZ(currentRoot.Position, safeZonePos) <= 1 then
                        currentRoot.AssemblyLinearVelocity = v3new(0, 0, 0)
                        currentRoot.AssemblyAngularVelocity = v3new(0, 0, 0)
                        return true
                    end
                    local dxEnd = currentRoot.Position.X - adjustedEnd.X
                    local dzEnd = currentRoot.Position.Z - adjustedEnd.Z
                    if math.sqrt(dxEnd * dxEnd + dzEnd * dzEnd) <= 3 then
                        tweenTo(safeZonePos, function()
                            if isNightTime() or not isStillAllowed() then return false end
                            if not checkIsStillCarryingFast(targetUid, nil) then return false end
                            return true
                        end, 0.5)
                        if getFlatDistanceXZ(currentRoot.Position, safeZonePos) <= 1 then
                            currentRoot.AssemblyLinearVelocity = v3new(0, 0, 0)
                            currentRoot.AssemblyAngularVelocity = v3new(0, 0, 0)
                            return true
                        end
                    end
                end

                if mustReplan then
                    task.wait(0.03)
                end
            end
        end
    end

    return false
end

local function deliverEggWithReCarry(targetUid, record, alreadyCarrying)
    local uidKey = tostring(targetUid)
    State.CurrentCarryingUid = targetUid
    Caches.CarriedEggRecords[uidKey] = record

    local maxRecoveryLoops = 25
    local recoveryCount = 0
    local skipVerify = alreadyCarrying == true
    local dropCooldown = 0

    while recoveryCount < maxRecoveryLoops do
        if isNightTime() then break end

        if not isStillAllowed() then break end

        if dropCooldown > 0 then
            dropCooldown = dropCooldown - 1
            task.wait(0.1)
            recoveryCount = recoveryCount + 1
            if recoveryCount >= maxRecoveryLoops then break end
            continue
        end

        local currentlyHolding
        if skipVerify then
            skipVerify = false
            currentlyHolding = true
        else
            Caches.CarryCheck.uid = nil
            currentlyHolding = checkIsStillCarrying(targetUid, nil)
        end

        if not currentlyHolding then
            Caches.EggInstance[uidKey] = nil
            local eggInstance = findEggInstance(targetUid)
            if not eggInstance then
                task.wait(0.08)
                eggInstance = findEggInstance(targetUid)
            end

            if not eggInstance then
                recoveryCount = recoveryCount + 1
                task.wait(0.1)
            else
                local eggPos = getEggPosition(eggInstance)
                if eggPos then
                    tweenTo(eggPos, isStillAllowed, 0.5)

                    local reCarried = false
                    for _ = 1, MAX_CARRY_ATTEMPTS do
                        if isNightTime() or not isStillAllowed() then break end
                        local currentInst = findEggInstance(targetUid)
                        if not currentInst then break end
                        local curPos = getEggPosition(currentInst) or eggPos
                        local char = LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if root then
                            root.AssemblyLinearVelocity = v3new(0, 0, 0)
                            if curPos and (root.Position - curPos).Magnitude > 3.5 then
                                tweenTo(curPos, isStillAllowed, 0.5)
                            end
                        end

                        pcall(function()
                            askFieldEggCarry:InvokeServer({ Uid = targetUid })
                        end)

                        task.wait(0.04)

                        Caches.CarryCheck.uid = nil
                        if checkIsStillCarrying(targetUid, nil) then
                            reCarried = true
                            break
                        end
                    end

                    if not reCarried then
                        recoveryCount = recoveryCount + 1
                        dropCooldown = 10
                    else
                        recoveryCount = 0
                        dropCooldown = 0
                    end
                else
                    recoveryCount = recoveryCount + 1
                    task.wait(0.1)
                end
            end
        else
            local safeZonePos = getSafeZonePosition()
            if not safeZonePos then return false end

            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return false end

            deliverToSafeZoneAvoidingTraps(targetUid)

            local curRoot = character and character:FindFirstChild("HumanoidRootPart")
            if curRoot then
                local dx = curRoot.Position.X - safeZonePos.X
                local dz = curRoot.Position.Z - safeZonePos.Z
                local flatDist = math.sqrt(dx * dx + dz * dz)

                Caches.CarryCheck.uid = nil

                if flatDist <= 20 then
                    local waitDeadline = clock() + 2.0
                    while clock() < waitDeadline do
                        Caches.CarryCheck.uid = nil
                        Caches.EggInstance[uidKey] = nil

                        local eggInst = findEggInstance(targetUid)
                        local inSlots = isUidInAreaSlots(uidKey, false)
                        local eggInWorld = (eggInst and isValidEggInstance(eggInst)) or inSlots

                        if not eggInWorld then
                            State.CurrentCarryingUid = nil
                            Caches.DeliveredEgg[uidKey] = true
                            pcall(sendStolenEggWebhook, targetUid)
                            return true
                        end

                        local isHolding = checkIsStillCarrying(targetUid, nil)
                        if eggInst and not eggInst:IsDescendantOf(character) and not isHolding then
                            dropCooldown = 10
                            break
                        end

                        task.wait(0.05)
                    end
                end
            end
        end
    end

    State.CurrentCarryingUid = nil
    return false
end

local function deliverCarriedEgg()
    local uid = State.CurrentCarryingUid
    if not uid then return false end
    local record = Caches.CarriedEggRecords[tostring(uid)] or { Uid = uid }
    return deliverEggWithReCarry(uid, record, false)
end

local function runTreadmillLogic()
    if State.SavedHumanoid or State.hasActiveTargets or State.CurrentCarryingUid or isNightTime() then return end
    local plotNum = getMyPlotNumber(false)
    if not plotNum then return end
    local renders = Workspace:FindFirstChild("__ClientTreadmillRenders")
    if not renders then return end
    local renderFolder = renders:FindFirstChild("TreadmillRender_" .. plotNum)
    if not renderFolder then return end
    local target = renderFolder:FindFirstChildWhichIsA("BasePart", true)
    local character = LocalPlayer.Character
    if not target or not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    if not tweenTo(target.Position + v3new(0,2,0)) then return end
    for _ = 1, 8 do
        if not Configurations.TreadmillToggleState or State.hasActiveTargets or State.CurrentCarryingUid or isNightTime() then return end
        rootPart.CFrame = target.CFrame + v3new(0,2,0)
        rootPart.AssemblyLinearVelocity = v3new(0,0,0)
        rootPart.AssemblyAngularVelocity = v3new(0,0,0)
        pcall(function() askWearStill:InvokeServer() end)
        task.wait(0.2)
    end
end

local function getCurrentCycleStartTime()
    local now = Workspace:GetServerTimeNow()
    local cycleLength = 600
    if AreaEggResetCycle and type(AreaEggResetCycle.CycleLengthSeconds) == "number" and AreaEggResetCycle.CycleLengthSeconds > 0 then
        cycleLength = AreaEggResetCycle.CycleLengthSeconds
    end
    return math.floor(now / cycleLength) * cycleLength
end

local function areRecordsSame(oldRecs, newRecs)
    if not oldRecs or not newRecs then return false end
    if #oldRecs ~= #newRecs then return false end
    for i = 1, #newRecs do
        if not oldRecs[i] or oldRecs[i].Uid ~= newRecs[i].Uid then
            return false
        end
    end
    return true
end

local function getEggSnapshot(force)
    local currentCycle = getCurrentCycleStartTime()
    local configEnabled = Configurations.StealEgg or Configurations.StealEggRarity or Configurations.StealEarnRate
    configEnabled = configEnabled and not State.LastConfigEnabledState
    State.LastConfigEnabledState = configEnabled

    if force or configEnabled then
        State.SnapshotRetryTime = 0
    end

    local cycleChanged = currentCycle ~= State.LastSnapshotCycleTime
    if cycleChanged then
        local wasFirstCall = State.LastSnapshotCycleTime == 0
        State.LastSnapshotCycleTime = currentCycle
        State.LastSnapshotRawRecords = nil
        State.SafeZoneStagingDone = false
        Caches.DeliveredEgg = {}
        Caches.EggInstance = {}
        Caches.EggNotFound = {}
        Caches.CarriedEggRecords = {}
        Caches.BlacklistedEggs = {}
        if not wasFirstCall then
            State.NewCycleGracePending = true
            State.CycleStartClock = clock()
        end
    end

    if configEnabled then
        State.SafeZoneStagingDone = false
        Caches.BlacklistedEggs = {}
    end

    if not force and not configEnabled and not cycleChanged and Caches.Snapshot.result and clock() < State.SnapshotRetryTime then
        return Caches.Snapshot.result
    end

    local success, result = pcall(function() return askFieldEggSnapshotRF:InvokeServer() end)

    if success and type(result) == "table" and result.Records then
        if areRecordsSame(State.LastSnapshotRawRecords, result.Records) then
            State.SnapshotRetryTime = clock() + 2
            return Caches.Snapshot.result
        end

        State.LastSnapshotRawRecords = result.Records
        precomputeRecordEarnings(result.Records)
        Caches.Snapshot.time = clock()
        Caches.Snapshot.ok = true
        Caches.Snapshot.result = result
        State.SnapshotRetryTime = 0
        return result
    else
        State.SnapshotRetryTime = clock() + 2
        return Caches.Snapshot.result
    end
end

local function isCycleGraceActive()
    if not State.NewCycleGracePending then return false end
    if State.CycleStartClock <= 0 then
        State.NewCycleGracePending = false
        return false
    end
    if clock() - State.CycleStartClock > NEW_CYCLE_GRACE_SECONDS then
        State.NewCycleGracePending = false
        return false
    end
    return true
end

local lastPreloadAt = 0
local function forcePreloadBySnapshot(records)
    if not records then return end
    if clock() - lastPreloadAt < 3 then return end
    lastPreloadAt = clock()
    for _, record in ipairs(records) do
        if record.Uid then findEggInstance(record.Uid) end
    end
end

local function waitForEggInSlots(uid, stillWanted, timeout)
    local deadline = clock() + (timeout or SLOT_WAIT_TIMEOUT)
    while clock() < deadline do
        if isNightTime() then return false end
        if stillWanted and not stillWanted() then return false end
        if isUidInAreaSlots(uid, false) then return true end
        if isEggLooseInWorld(uid) then return true end
        task.wait(0.15)
    end
    if isUidInAreaSlots(uid, true) then return true end
    return isEggLooseInWorld(uid)
end

local function processSingleEggSelection(record, allowGrace)
    local targetUid = record.Uid
    local uidKey = tostring(targetUid)
    local stillWanted = function() return isTargetStillSelected(record) end
    if not stillWanted() then return false end

    if not waitForCharacterReady(10) then return false end

    if State.CurrentCarryingUid and State.CurrentCarryingUid ~= targetUid then
        local delivered = deliverCarriedEgg()
        if not delivered then return false end
    end

    local graceActive = allowGrace and isCycleGraceActive()

    Caches.EggInstance[uidKey] = nil
    Caches.EggNotFound[uidKey] = nil
    local eggInstance = findEggInstance(targetUid)
    local inSlots = isUidInAreaSlots(targetUid, true)
    local inWorkspace = eggInstance ~= nil and isValidEggInstance(eggInstance)

    if not inSlots and not inWorkspace and not graceActive then
        Caches.BlacklistedEggs[uidKey] = true
        return false
    end

    local travelPosition = getEggTravelPosition(record, eggInstance)
    if not travelPosition then
        Caches.BlacklistedEggs[uidKey] = true
        return false
    end

    if getIsOnTreadmill(true) then
        forceUnequipTreadmill()
    end

    if not stillWanted() then return false end

    local isWallActive = isWallCollisionActive()

    destroyHumanoidAndFixCamera()

    local inGuardArea = isInsideGuardArea()
    if not inGuardArea then
        local stagedSafe = isStagedInSafeZone()
        if not stagedSafe then
            local returned = returnToSafeZone(stillWanted)
            if not returned then return false end
        end
        State.SafeZoneStagingDone = true
        local wallActiveNow = isWallCollisionActive()
        if wallActiveNow then
            waitForWallCollision(stillWanted, getSafeZonePosition())
        end
    elseif isWallActive then
        local returned = returnToSafeZone(stillWanted)
        if not returned then return false end
        waitForWallCollision(stillWanted, getSafeZonePosition())
    else
        State.SafeZoneStagingDone = true
    end

    if not stillWanted() then return false end

    local maxRetries = 5
    local retryCount = 0
    local deliverySuccess = false

    while stillWanted() and retryCount < maxRetries do
        if isNightTime() then break end
        local attemptFailed = false

        Caches.EggInstance[uidKey] = nil
        local currentEggInstance = findEggInstance(targetUid)
        local inSlotsNow = isUidInAreaSlots(targetUid, false)

        if not currentEggInstance and not inSlotsNow and not graceActive then
            Caches.BlacklistedEggs[uidKey] = true
            break
        end

        local currentTravelPos = nil
        if currentEggInstance then
            currentTravelPos = getEggPosition(currentEggInstance)
        end

        if not currentTravelPos then
            currentTravelPos = getEggPositionFromSnapshot(record) or travelPosition
        end

        local inSlotsCheck = isUidInAreaSlots(targetUid, false)
        if currentEggInstance and not inSlotsCheck then
            local reachedEgg = followMovingEgg(targetUid, stillWanted)
            if not reachedEgg then
                attemptFailed = true
            end
        else
            local reachedTravel = tweenTo(currentTravelPos, stillWanted, 0.5)
            if not reachedTravel then
                attemptFailed = true
            end
        end

        if not attemptFailed and not stillWanted() then break end

        if not attemptFailed then
            local inSlotsAfterArrive = isUidInAreaSlots(targetUid, false)
            local looseAfterArrive = isEggLooseInWorld(targetUid)

            if not inSlotsAfterArrive and not looseAfterArrive then
                if graceActive then
                    local appeared = waitForEggInSlots(targetUid, stillWanted, SLOT_WAIT_TIMEOUT)
                    if not appeared then
                        Caches.BlacklistedEggs[uidKey] = true
                        break
                    end
                else
                    Caches.BlacklistedEggs[uidKey] = true
                    break
                end
            end
        end

        if not attemptFailed then
            Caches.EggInstance[uidKey] = nil
            Caches.EggNotFound[uidKey] = nil
            currentEggInstance = findEggInstance(targetUid)
            if not currentEggInstance then
                Caches.BlacklistedEggs[uidKey] = true
                break
            end
        end

        if not attemptFailed then
            local refreshedTravel = getEggPosition(currentEggInstance) or getEggTravelPosition(record, currentEggInstance)
            if refreshedTravel then
                local character = LocalPlayer.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local dx = rootPart.Position.X - refreshedTravel.X
                    local dz = rootPart.Position.Z - refreshedTravel.Z
                    if math.sqrt(dx * dx + dz * dz) > 3.5 then
                        local reachedRefreshed = tweenTo(refreshedTravel, stillWanted, 0.5)
                        if not reachedRefreshed then
                            attemptFailed = true
                        end
                    end
                end
            end
        end

        if not attemptFailed then
            if State.SavedHumanoid then pcall(function() State.SavedHumanoid.PlatformStand = true end) end

            local carryVerification = false
            local originalEggPosition = getEggPosition(currentEggInstance) or travelPosition

            for _ = 1, MAX_CARRY_ATTEMPTS do
                if isNightTime() or not stillWanted() then break end
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.AssemblyLinearVelocity = v3new(0, 0, 0)
                end

                pcall(function()
                    askFieldEggCarry:InvokeServer({ Uid = targetUid })
                end)

                Caches.CarryCheck.uid = nil
                task.wait(0.04)
                Caches.CarryCheck.uid = nil
                if checkIsStillCarrying(targetUid, originalEggPosition) then
                    carryVerification = true
                    break
                end

                local currentEgg = findEggInstance(targetUid)
                if currentEgg then
                    local eggPos = getEggPosition(currentEgg)
                    if eggPos and root then
                        local dx = root.Position.X - eggPos.X
                        local dz = root.Position.Z - eggPos.Z
                        if math.sqrt(dx * dx + dz * dz) > 3.5 then
                            tweenTo(eggPos, stillWanted, 0.5)
                        end
                    end
                end
            end

            if carryVerification then
                State.CurrentCarryingUid = targetUid
                Caches.CarriedEggRecords[uidKey] = record
                local deliveredOk = deliverEggWithReCarry(targetUid, record, true)
                if deliveredOk then
                    deliverySuccess = true
                    break
                else
                    attemptFailed = true
                end
            else
                attemptFailed = true
            end
        end

        if attemptFailed then
            retryCount = retryCount + 1
            task.wait(0.1)
        end
    end

    return deliverySuccess
end

LocalPlayer.CharacterAdded:Connect(function()
    Caches.EggInstance = {}
    Caches.EggNotFound = {}
    Caches.CarryCheck = { uid = nil, time = 0, value = false }
    Caches.Snapshot = { time = 0, ok = false, result = nil }
    Caches.Treadmill = { time = 0, value = false }
    Caches.Plot = { time = 0, value = nil }
    Caches.SafeZone = { time = 0, value = nil }
    Caches.GuardArea = { time = 0, parts = {} }
    Caches.WallCollision = { time = 0, active = false }
    Caches.Trap = { time = 0, positions = {} }
    Caches.AreaEggIndex = { time = 0, folder = nil, entries = {} }
    Caches.BlacklistedEggs = {}
    State.SavedHumanoid = nil
    State.CurrentCarryingUid = nil
    State.hasActiveTargets = false
    State.RestoredCharacter = nil
    State.SafeZoneStagingDone = false
    State.LastSnapshotCycleTime = 0
    State.LastSnapshotRawRecords = nil
    State.NewCycleGracePending = false
    State.LastConfigEnabledState = false
    State.SnapshotRetryTime = 0
    State.CycleStartClock = 0
    State.WasNight = false
    task.spawn(function()
        waitForCharacterReady(15)
    end)
end)

local function isEggValidTarget(record, priorityUid)
    if not record or not record.Uid then return false end
    local uidKey = tostring(record.Uid)
    if Caches.DeliveredEgg[uidKey] then return false end
    if Caches.BlacklistedEggs[uidKey] then return false end
    local selectedOk, selected = pcall(isTargetStillSelected, record)
    if not selectedOk or not selected then return false end

    local existsOk, exists = pcall(eggExistsForTarget, record.Uid)
    local eggPresent = existsOk and exists
    if eggPresent then return true end

    local cycleGrace = isCycleGraceActive()
    local graceAllowed = cycleGrace and priorityUid ~= nil and uidKey == priorityUid
    if graceAllowed then return true end
    if cycleGrace then return false end

    Caches.BlacklistedEggs[uidKey] = true
    return false
end

task.spawn(function()
    while true do
        local filteringActive = false
        if Configurations.StealEgg and Configurations.SelectedEggsFilter and #Configurations.SelectedEggsFilter > 0 then
            filteringActive = true
        elseif Configurations.StealEggRarity and Configurations.SelectedRarityFilter and #Configurations.SelectedRarityFilter > 0 then
            filteringActive = true
        elseif Configurations.StealEarnRate then
            filteringActive = true
        end

        if filteringActive then
            if isNightTime() then
                State.WasNight = true
                State.CurrentCarryingUid = nil
                State.hasActiveTargets = false
                State.SafeZoneStagingDone = false
                pcall(restoreHumanoid)
                task.wait(0.5)
            else
                if State.WasNight then
                    State.WasNight = false
                    State.NewCycleGracePending = true
                    State.CycleStartClock = clock()
                    Caches.BlacklistedEggs = {}
                    Caches.EggInstance = {}
                    Caches.EggNotFound = {}
                    getEggSnapshot(true)
                end

                if not Caches.Snapshot.result and Caches.Snapshot.time == 0 then getEggSnapshot(true) end
                local result = getEggSnapshot(false)
                if result and type(result) == "table" and result.Records then
                    local matchedRecords = {}
                    for _, record in pairs(result.Records) do
                        if record.Uid and isTargetStillSelected(record) and not Caches.DeliveredEgg[tostring(record.Uid)] then
                            table.insert(matchedRecords, record)
                        end
                    end
                    local earnRateMode = Configurations.StealEarnRate and not Configurations.StealEgg and not Configurations.StealEggRarity
                    table.sort(matchedRecords, function(a, b)
                        if earnRateMode then
                            local earnA = getRecordEarning(a)
                            local earnB = getRecordEarning(b)
                            if earnA ~= earnB then return earnA > earnB end
                        end
                        local rarityA = getRarityFromName(a.AssetCategory) or "Basic"
                        local rarityB = getRarityFromName(b.AssetCategory) or "Basic"
                        local weightA = rarityWeights[rarityA] or 0
                        local weightB = rarityWeights[rarityB] or 0
                        if weightA ~= weightB then return weightA > weightB end
                        local scaleA = tonumber(a.NestScale) or 0
                        local scaleB = tonumber(b.NestScale) or 0
                        return scaleA > scaleB
                    end)

                    local priorityUid = matchedRecords[1] and tostring(matchedRecords[1].Uid) or nil

                    local validTargets = {}
                    for _, record in ipairs(matchedRecords) do
                        if isEggValidTarget(record, priorityUid) then
                            table.insert(validTargets, record)
                        end
                    end

                    State.hasActiveTargets = #validTargets > 0 or State.CurrentCarryingUid ~= nil
                    if #validTargets > 0 or State.CurrentCarryingUid then
                        forcePreloadBySnapshot(matchedRecords)
                        State.hasActiveTargets = true

                        if not State.CurrentCarryingUid then
                            if getIsOnTreadmill(true) then
                                forceUnequipTreadmill()
                            end
                            local inGuardArea = isInsideGuardArea()
                            local stagedSafe = isStagedInSafeZone()
                            if not inGuardArea and not stagedSafe then
                                destroyHumanoidAndFixCamera()
                                returnToSafeZone(function() return not isNightTime() end)
                                local wallActive = isWallCollisionActive()
                                if wallActive then
                                    waitForWallCollision(function() return not isNightTime() end, getSafeZonePosition())
                                end
                                State.SafeZoneStagingDone = true
                            end
                        end

                        local carried = false
                        local failedAttempts = {}
                        while not carried and not isNightTime() do
                            if State.CurrentCarryingUid then
                                State.hasActiveTargets = true
                                local delivered = deliverCarriedEgg()
                                if delivered then
                                    State.hasActiveTargets = false
                                    carried = true
                                    break
                                else
                                    task.wait(0.15)
                                end
                            end
                            if carried then break end

                            local currentValidTargets = {}
                            for _, record in ipairs(validTargets) do
                                if isEggValidTarget(record, priorityUid) then
                                    table.insert(currentValidTargets, record)
                                end
                            end
                            if #currentValidTargets == 0 then break end

                            for _, targetRecord in ipairs(currentValidTargets) do
                                if isNightTime() or (not Configurations.StealEgg and not Configurations.StealEggRarity and not Configurations.StealEarnRate) then break end
                                if State.CurrentCarryingUid then
                                    State.hasActiveTargets = true
                                    local delivered = deliverCarriedEgg()
                                    if delivered then
                                        State.hasActiveTargets = false
                                        carried = true
                                        break
                                    else
                                        task.wait(0.15)
                                    end
                                end
                                if carried then break end

                                local recordUidKey = tostring(targetRecord.Uid)
                                local isPriority = priorityUid ~= nil and recordUidKey == priorityUid
                                local cycleGraceActiveNow = isCycleGraceActive()
                                local graceAllowed = cycleGraceActiveNow and isPriority

                                local selectedOk, selected = pcall(isTargetStillSelected, targetRecord)
                                local existsOk, exists = pcall(eggExistsForTarget, targetRecord.Uid)
                                local canProcess = selectedOk and selected and ((existsOk and exists) or graceAllowed)
                                if canProcess then
                                    State.hasActiveTargets = true
                                    local processOk, processResult = pcall(processSingleEggSelection, targetRecord, graceAllowed)
                                    State.hasActiveTargets = State.CurrentCarryingUid ~= nil
                                    if processOk and processResult then
                                        if isPriority then State.NewCycleGracePending = false end
                                        carried = true
                                        failedAttempts[recordUidKey] = nil
                                        break
                                    else
                                        failedAttempts[recordUidKey] = (failedAttempts[recordUidKey] or 0) + 1
                                        if failedAttempts[recordUidKey] >= MAX_CARRY_ATTEMPTS then
                                            Caches.BlacklistedEggs[recordUidKey] = true
                                            if isPriority then
                                                State.NewCycleGracePending = false
                                            end
                                        end
                                    end
                                end
                            end

                            local changed = false
                            local newTargetedRecordsFound = {}
                            for _, record in ipairs(validTargets) do
                                if (failedAttempts[tostring(record.Uid)] or 0) >= MAX_CARRY_ATTEMPTS or Caches.BlacklistedEggs[tostring(record.Uid)] then
                                    changed = true
                                else
                                    table.insert(newTargetedRecordsFound, record)
                                end
                            end
                            if changed then validTargets = newTargetedRecordsFound end
                            if #validTargets == 0 then break end
                            if not carried and not State.CurrentCarryingUid then task.wait(0.05) end
                        end

                        if not State.CurrentCarryingUid then
                            if #validTargets > 0 and not isNightTime() then
                                State.hasActiveTargets = true
                            else
                                State.hasActiveTargets = false
                                pcall(restoreHumanoid)
                            end
                        end
                    else
                        State.hasActiveTargets = false
                        pcall(restoreHumanoid)
                    end
                else
                    if not State.CurrentCarryingUid then
                        State.hasActiveTargets = false
                        pcall(restoreHumanoid)
                    end
                end
            end
            task.wait(State.hasActiveTargets and 0.03 or 0.2)
        else
            if not State.CurrentCarryingUid then
                State.hasActiveTargets = false
                State.SafeZoneStagingDone = false
                pcall(restoreHumanoid)
            end
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1.5)
        if State.hasActiveTargets and State.CurrentCarryingUid == nil and getIsOnTreadmill(true) then
            if State.SavedHumanoid then forceUnequipTreadmill() end
        end
        if Configurations.TreadmillToggleState and not getIsOnTreadmill(false) and not State.hasActiveTargets and not State.CurrentCarryingUid and not State.SavedHumanoid and not isNightTime() then
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if rootPart and not State.SavedHumanoid then
                local initialPos = rootPart.Position
                task.wait(5)
                if not getIsOnTreadmill(true) and not State.hasActiveTargets and not State.CurrentCarryingUid and not State.SavedHumanoid and not isNightTime() and character and character.Parent and rootPart.Parent then
                    local currentPos = rootPart.Position
                    if (initialPos - currentPos).Magnitude < 0.5 then
                        local plotNum = getMyPlotNumber(false)
                        if plotNum then
                            local renders = Workspace:FindFirstChild("__ClientTreadmillRenders")
                            local renderFolder = renders and renders:FindFirstChild("TreadmillRender_" .. plotNum)
                            local target = renderFolder and renderFolder:FindFirstChildWhichIsA("BasePart", true)
                            if target and (rootPart.Position - target.Position).Magnitude > 2 then
                                runTreadmillLogic()
                            end
                        end
                    end
                end
            end
        end
    end
end)

if _G.PostMailboxTerminalAlert then
    _G.PostMailboxTerminalAlert("Decode", "Function Loaded", false)
end
print("Decode: Function Loaded")
