--!strict
-- ============================================================
-- Town Complete v9.8.0 (Scryux UI) - Parte 1/3
-- FOV Selectivo + Mejoras de Grok + Rivals + Solara-Adapted
-- ============================================================

local _env = getgenv and getgenv() or _G
local realPrint = print
local realWarn  = warn

-- ============================================================
-- BLOQUE 0: Logger con niveles (mejorado de Grok)
-- ============================================================
local Logger = {
    level = "WARN",
    prefix = "[TownComplete] ",
    levels = {DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4},
}
function Logger.Log(level, ...)
    if Logger.levels[level] < Logger.levels[Logger.level] then return end
    local args = {...}
    local parts = {}
    for i = 1, #args do parts[i] = tostring(args[i]) end
    realPrint(Logger.prefix .. "[" .. level .. "] " .. table.concat(parts, " "))
end
function Logger.Debug(...) Logger.Log("DEBUG", ...) end
function Logger.Info(...)  Logger.Log("INFO", ...) end
function Logger.Warn(...)  Logger.Log("WARN", ...) end
function Logger.Error(...) Logger.Log("ERROR", ...) end

local function _noop() end
_env.print = _noop
_env.warn  = _noop

-- ============================================================
-- BLOQUE 1: Helpers + Carga de Scryux UI
-- ============================================================
local ScryuxUI
do
    local function Has(fn)
        local env = getgenv and getgenv() or _G
        return type(env[fn]) == "function" or type(_G[fn]) == "function"
    end

    if _env.TownComplete_Loaded then
        pcall(function() _env.TownComplete_Cleanup() end)
        _env.TownComplete_Loaded = false
        task.wait(0.3)
    end
    _env.TownComplete_Loaded = true

    local SCRYUX_URLS = {
        "https://cdn.jsdelivr.net/gh/player2dwhite-tech/Scryux-Library@main/Scryux-Library.lua",
        "https://raw.githubusercontent.com/player2dwhite-tech/Scryux-Library/main/Scryux-Library.lua",
    }
    local CACHE_FILE = "scryux_ui_cache.lua"
    local CACHE_VERSION = "v9.8.0"

    local function SafeRequest(url)
        if Has("request") then
            local ok, response = pcall(function()
                return request({
                    Url = url, Method = "GET",
                    Headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
                })
            end)
            if ok and response and response.Success then return response.Body end
        end
        local ok, result = pcall(function() return game:HttpGet(url) end)
        return ok and result or nil
    end

    local function IsValidUI(code)
        if not code or #code < 2000 then return false end
        if not code:find("CreateWindow") then return false end
        if not code:find("CreateTab") then return false end
        return true
    end

    local function LoadFromCache()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
        local ok, exists = pcall(isfile, CACHE_FILE)
        if not ok or not exists then return nil end
        local ok2, cached = pcall(readfile, CACHE_FILE)
        if not ok2 or not cached or #cached < 2000 then return nil end
        if not cached:find(CACHE_VERSION, 1, true) then
            Logger.Info("Caché de Scryux obsoleto, recargando...")
            if type(delfile) == "function" then pcall(delfile, CACHE_FILE) end
            return nil
        end
        if not IsValidUI(cached) then
            if type(delfile) == "function" then pcall(delfile, CACHE_FILE) end
            return nil
        end
        local fn = loadstring(cached)
        if not fn then return nil end
        local ok3, lib = pcall(fn)
        if ok3 and lib then return lib end
        return nil
    end

    local function LoadFromURL(url)
        local code = SafeRequest(url)
        if not code or #code < 2000 then return nil end
        if not IsValidUI(code) then return nil end
        local fn = loadstring(code)
        if not fn then return nil end
        local ok, lib = pcall(fn)
        if ok and lib then
            if type(writefile) == "function" then
                local codeWithVersion = "-- " .. CACHE_VERSION .. "\n" .. code
                pcall(writefile, CACHE_FILE, codeWithVersion)
            end
            return lib
        end
        return nil
    end

    ScryuxUI = LoadFromCache()
    if not ScryuxUI then
        for _, url in ipairs(SCRYUX_URLS) do
            local lib = LoadFromURL(url)
            if lib then ScryuxUI = lib; break end
            task.wait(0.5)
        end
    end
end

if not ScryuxUI then
    _env.print = realPrint
    _env.warn  = realWarn
    Logger.Error("No se pudo cargar Scryux UI")
    return
end

-- ============================================================
-- BLOQUE 2: Servicios + Configuración + Vars (con compactación de Grok)
-- ============================================================
local Vars = {}
local Settings = {}
local BODY_PARTS_ALL = {}

do
    -- ✅ Compactación estilo Grok (1 sola declaración múltiple)
    local Players, RunService, UserInputService, CoreGui, Stats, Lighting =
        game:GetService("Players"),
        game:GetService("RunService"),
        game:GetService("UserInputService"),
        game:GetService("CoreGui"),
        game:GetService("Stats"),
        game:GetService("Lighting")

    local LP = Players.LocalPlayer
    local Workspace = workspace
    local function GetCamera() return Workspace.CurrentCamera end

    Vars.Players = Players
    Vars.RunService = RunService
    Vars.UserInputService = UserInputService
    Vars.CoreGui = CoreGui
    Vars.Stats = Stats
    Vars.Lighting = Lighting
    Vars.LP = LP
    Vars.Workspace = Workspace
    Vars.GetCamera = GetCamera

    Vars.Vector2_new = Vector2.new
    Vars.Vector3_new = Vector3.new
    Vars.CFrame_new = CFrame.new
    Vars.CFrame_Angles = CFrame.Angles
    Vars.math_floor = math.floor
    Vars.math_clamp = math.clamp
    Vars.math_max = math.max
    Vars.math_min = math.min
    Vars.math_rad = math.rad
    Vars.math_tan = math.tan
    Vars.table_insert = table.insert
    Vars.table_remove = table.remove
    Vars.table_clear = table.clear
    Vars.os_clock = os.clock
    Vars.string_find = string.find

    Vars.isScriptUnloaded = false
    Vars.activePlayers = {}
    Vars.uniqueId = tostring(math.random(100000, 999999))

    Vars.aimKeyHeld = false
    Vars.isLocalDead = false
    Vars.aimbotHelperActive = false
    Vars.anti360Active = false
    Vars.anti360Cooldown = 0
    Vars.currentTargetForAnti360 = nil

    Vars.helperMousePosition = Vector2.new(0, 0)

    Vars.noRecoilRunning = false
    Vars.noRecoilConnections = {}

    -- ✅ X-Ray mejorado (Grok)
    Vars.xrayActive = false
    Vars.xrayThread = nil
    Vars.originalTransparency = {}

    Vars.visibilityCache = {}
    Vars.VIS_CACHE_TTL = 0.15

    Vars.SharedRayParams = RaycastParams.new()
    Vars.SharedRayParams.FilterType = Enum.RaycastFilterType.Blacklist
    Vars.SharedIgnoreList = {}
    Vars.SharedIgnoreListOwner = nil

    Vars.highlightCooldowns = {}

    Vars.antiFallRunning = false
    Vars.antiFallConnection = nil
    Vars.antiFallCharConnections = {}

    Vars.SkeletonLinePool = {}
    Vars.SkeletonLinePoolMAX = 500
    Vars.ActiveSkeletons = {}

    Vars.ESPPool = {}
    Vars.ESPObjectPool = { box = {}, health = {}, name = {}, chams = {}, headDot = {}, weapon = {} }
    Vars.ESPObjectPoolMAX = 32

    Vars.ItemESPList = {}

    Vars.targetIndicator = nil
    Vars.Bar = nil

    Vars.strafeConnection = nil
    Vars.strafeOriginalWalkspeed = nil
    Vars.strafeKeyLeftHeld = false
    Vars.strafeKeyRightHeld = false

    Vars.spinbotConnection = nil
    Vars.spinbotActive = false
    Vars.spinbotOriginalCFrame = nil

    Vars.hideBodyConnection = nil

    Vars.TracerPool = {}
    Vars.TracerPoolMAX = 64
    Vars.ActiveTracers = {}
    Vars.tracerConnections = {}
    Vars.tracerLoopConn = nil

    Vars.stickyTarget = nil
    Vars.stickyLastSeen = 0

    Vars.aimAssistActive = false
    Vars.aimAssistConnection = nil
    Vars.aimAssistFOVCircle = nil
    Vars.aimAssistFOVConn = nil
    Vars.aimAssistLastFrame = 0

    Vars.targetTransition = {
        active = false,
        startCFrame = nil,
        targetCFrame = nil,
        progress = 0,
        duration = 0.25,
        previousPlayer = nil,
    }
    Vars.TARGET_TRANSITION_DURATION = 0.25

    Vars.deadBlacklist = {}
    Vars.DEAD_BLACKLIST_DURATION = 3

    Vars.whitelist = {}

    Vars.CrosshairLines = {}
    Vars.CrosshairConn = nil
    Vars.CrosshairRayParams = RaycastParams.new()
    Vars.CrosshairRayParams.FilterType = Enum.RaycastFilterType.Blacklist

    Vars.exploitWalkspeedConn = nil
    Vars.exploitJumpConn = nil
    Vars.exploitNoclipConn = nil
    Vars.exploitFlyConn = nil
    Vars.exploitFlyControl = {F = 0, B = 0, L = 0, R = 0, U = 0, D = 0}
    Vars.exploitFlyKeyConn = nil
    Vars.exploitFlyKeyEndConn = nil
    Vars.exploitTeleportConn = nil

    Vars.positionHistory = {}
    Vars.POS_HISTORY_MAX = 20
    Vars.POS_HISTORY_TTL = 0.2

    Vars.currentSelectivePartName = nil
    Vars.currentHybridPartName = nil

    -- ✅ NUEVO v9.8.0: Un solo loop ESP+Skeleton (Grok)
    Vars.espSkeletonConn = nil

    -- ✅ NUEVO v9.8.0: Lighting guardado (Grok)
    Vars.OriginalLighting = nil
    Vars.lightingChildAddedConn = nil

    -- ✅ NUEVO v9.8.0: Estado del ESP Pool
    Vars.lastESPUpdate = 0
    Vars.lastSkeletonUpdate = 0

    -- ============================================================
    -- CONFIGURACIÓN
    -- ============================================================
    Settings = {
        ESP = {
            Enabled = true, Chams = true, TeamCheck = false,
            ShowHealth = true, ShowName = true, ShowDistance = false,
            Box = true, BoxColor = Color3.fromRGB(170, 0, 255),
            BoxThickness = 1, BoxPadding = 0.5,
            HealthThickness = 2,
            NameColor = Color3.fromRGB(255, 255, 0),
            ChamsColor = Color3.fromRGB(170, 0, 255),
            ChamsFillTransparency = 0.25,
            ChamsOutlineTransparency = 0,
            ChamsOutlineColor = Color3.new(1, 1, 1),
            ChamsDepthMode = "AlwaysOnTop",
            WallcheckChams = false,
            HeadDots = false,
            HeadDotColor = Color3.fromRGB(255, 255, 0),
            HeadDotRadius = 5,
            HeadDotThickness = 2,
            HeadDotTransparency = 1,
            Items = false,
            ItemColor = Color3.fromRGB(255, 165, 0),
            ItemTextSize = 16,
            ItemMaxDistance = 500,
            Weapons = false,
            WeaponColor = Color3.fromRGB(255, 0, 255),
            WeaponTextSize = 16,
            Colors = {
                Visible = Color3.fromRGB(255, 0, 0),
                Partial = Color3.fromRGB(255, 200, 0),
                Invisible = Color3.fromRGB(0, 255, 80),
                Passive = Color3.fromRGB(0, 120, 255),
                Dead = Color3.fromRGB(100, 100, 100),
            }
        },
        Skeleton = {
            Enabled = true, Color = Color3.fromRGB(255, 255, 255),
            Thickness = 1, MaxDistance = 500, RigMode = "Auto", OnlyVisible = false,
        },
        FullBright = { Enabled = false },
        Aimbot = {
            Enabled = false, Method = "Camera",
            WallCheck = false, StrictWallCheck = false,
            IgnoreTransparent = true, IgnoreNonCollidable = true,
            TeamCheck = false, IgnorePassive = true,
            MaxDistance = 500, AimKeyType = "Mouse",
            AimKey = Enum.KeyCode.T,
            AimMouseButton = Enum.UserInputType.MouseButton2,
            FOV = 180, ShowFOV = false,
            FOVColor = Color3.fromRGB(255,255,255), FOVThickness = 2,
            AimPartMode = "Selective FOV",
            Selective = {
                Enabled = true,
                HeadZoneTop = 0.0,
                HeadZoneBottom = 0.35,
                TorsoZoneTop = 0.35,
                TorsoZoneBottom = 0.70,
                LegsZoneTop = 0.70,
                LegsZoneBottom = 1.0,
                LeftArmZoneLeft = 0.0,
                LeftArmZoneRight = 0.35,
                CenterZoneLeft = 0.35,
                CenterZoneRight = 0.65,
                RightArmZoneLeft = 0.65,
                RightArmZoneRight = 1.0,
                TransitionSmoothing = 0.85,
                DeadzoneRadius = 0.05,
            },
            Hybrid = {
                Enabled = false,
                BasePart = "Head",
                VerticalBiasThreshold = 0.15,
                DownwardSmoothness = 0.7,
                AllowReturn = true,
            },
            HelperSmoothness = 0.15, BaseSmoothness = 0.15,
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false,
            Priority = "Distance",
            StickyLock = false, StickyTimeout = 2,
            RequireGun = true,
            BonePriority = {
                Head = 1.0,
                UpperTorso = 0.7,
                LowerTorso = 0.6,
                HumanoidRootPart = 0.5,
                LeftUpperArm = 0.35,
                RightUpperArm = 0.35,
                LeftLowerArm = 0.25,
                RightLowerArm = 0.25,
                LeftUpperLeg = 0.3,
                RightUpperLeg = 0.3,
                LeftLowerLeg = 0.2,
                RightLowerLeg = 0.2,
            },
            Anti360 = { Enabled = false, DetectionDistance = 1.5, Hysteresis = 1.5, ReEnableDelay = 0.25 }
        },
        AimAssist = {
            Enabled = false, FOV = 30, ShowFOV = false,
            FOVColor = Color3.fromRGB(0, 255, 255), FOVThickness = 1,
            MaxDistance = 500, Smoothness = 0.3, AimPart = "Head",
            TeamCheck = false, IgnorePassive = true, WallCheck = false,
            Visible = true, UseMouse = false, Priority = "Distance",
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false,
            Selective = false,
        },
        WeaponMods = { NoRecoil = false },
        Visuals = {
            XRay = false, NoFog = false, NoBloom = false, NoSunRays = false,
            CustomFOV = false, FOVValue = 70, OriginalFOV = nil,
            HideBody = false, HideHands = false, HideTool = false,
            BulletTracers = false, TracerColor = Color3.fromRGB(255, 50, 50),
            TracerLifetime = 2, TracerThickness = 2, TracerMaxDistance = 500,
            -- ✅ NUEVO v9.8.0: Límite de tracers activos (Grok)
            MaxActiveTracers = 40,
            Crosshair = false,
            CrosshairColor = Color3.fromRGB(255, 255, 255),
            CrosshairEnemyColor = Color3.fromRGB(255, 0, 0),
            CrosshairSize = 8,
            CrosshairThickness = 2,
            CrosshairTransparency = 1,
            CrosshairGap = 4,
        },
        Sync = { Enabled = false, TryFFlagFallback = false, AutoDisableOnLowFPS = false },
        HUD = { Enabled = true, ShowFPS = true, ShowPing = true, Position = "TopRight" },
        Performance = { ESPUpdateRate = 0.03, SkeletonUpdateRate = 0.04 },
        UI = { ShowScreenBar = true },
        AntiFall = { Enabled = false },
        Movement = {
            StrafeEnabled = false, StrafeDistance = 0.3, PeekCooldown = 0.08,
            StrafeKeyLeft = Enum.KeyCode.A, StrafeKeyRight = Enum.KeyCode.D,
        },
        Exploit = {
            Spinbot = false, SpinbotSpeed = 720,
            Walkspeed = false, WalkspeedValue = 16,
            JumpPower = false, JumpPowerValue = 50,
            Noclip = false, Fly = false, FlySpeed = 50,
            TeleportToCursor = false,
        },
        Hotkeys = {
            ToggleMenu = Enum.KeyCode.RightShift,
            Helper = Enum.KeyCode.Y,
            Panic = Enum.KeyCode.End,
        },
        Backtrack = { Enabled = false, Delay = 0.1, ShowIndicator = false },
    }

    Vars.Settings = Settings

    BODY_PARTS_ALL = {
        "Auto (Nearest to Crosshair)", "Head", "Torso",
        "Selective FOV", "Hybrid",
        "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
        "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    }
    Vars.BODY_PARTS_ALL = BODY_PARTS_ALL
end

-- ============================================================
-- BLOQUE 3: Funciones Core
-- ============================================================
do
    local LP = Vars.LP
    local Workspace = Vars.Workspace
    local Settings = Vars.Settings
    local V2 = Vars.Vector2_new
    local V3 = Vars.Vector3_new
    local CFrame_new = Vars.CFrame_new
    local table_insert = Vars.table_insert
    local os_clock = Vars.os_clock
    local string_find = Vars.string_find

    local function GetCamera() return Vars.GetCamera() end
    Vars.GetCamera = GetCamera

    local function IsMenuOpen()
        local w = _env.TownUI_Window
        if w and w.IsVisible then
            local ok, visible = pcall(function() return w:IsVisible() end)
            if ok then return visible end
        end
        return false
    end
    Vars.IsMenuOpen = IsMenuOpen

    local function SilentPcall(fn, ...)
        if not fn then return nil end
        local ok, result = pcall(fn, ...)
        if not ok then return nil end
        return result
    end
    Vars.SilentPcall = SilentPcall

    local function hasGunScript(character)
        if not character then return false end
        for _, child in pairs(character:GetChildren()) do
            if child:IsA("Tool") then
                local gunScript = child:FindFirstChild("GunScript")
                if gunScript and gunScript:IsA("LocalScript") then
                    return true
                end
            end
        end
        return false
    end
    Vars.hasGunScript = hasGunScript

    local function IsPassive(playerName)
        local char = Workspace:FindFirstChild(playerName)
        if not char then return false end
        local head = char:FindFirstChild("Head")
        if head then
            if head.Material == Enum.Material.ForceField then return true end
            if head:FindFirstChildOfClass("ForceField") then return true end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum:FindFirstChildOfClass("ForceField") then return true end
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if torso and torso.Material == Enum.Material.ForceField then return true end
        return false
    end
    Vars.IsPassive = IsPassive

    local function IsPartTransparent(part)
        if part.Transparency >= 0.1 then return true end
        if part.CanCollide == false then return true end
        if part.Material == Enum.Material.Glass then return true end
        if part.Material == Enum.Material.ForceField then return true end
        local n = part.Name:lower()
        if string_find(n, "glass") or string_find(n, "window") then return true end
        if part:IsA("SpawnLocation") then return true end
        if part.Parent and part.Parent:IsA("Tool") then return true end
        if part:IsA("MeshPart") and part.Transparency >= 0.3 then return true end
        if part:IsA("Seat") then return true end
        return false
    end

    local function RebuildIgnoreList(targetPlayer)
        local ignore = {}
        if LP.Character then
            for _, p in ipairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") then table_insert(ignore, p) end
            end
        end
        if targetPlayer and targetPlayer.Character then
            for _, p in ipairs(targetPlayer.Character:GetDescendants()) do
                if p:IsA("BasePart") then table_insert(ignore, p) end
            end
        end
        local cam = GetCamera()
        if cam then table_insert(ignore, cam) end
        Vars.SharedIgnoreList = ignore
        Vars.SharedRayParams.FilterDescendantsInstances = ignore
        Vars.SharedIgnoreListOwner = targetPlayer and targetPlayer.Name or nil
    end
    Vars.RebuildIgnoreList = RebuildIgnoreList

    local function CheckPositionVisibility(position, player, ignoreTransparent, ignoreNonCollidable)
        local cam = GetCamera()
        if not cam then return "hidden" end
        local camPos = cam.CFrame.Position
        local dir = (position - camPos).Unit
        local dist = (position - camPos).Magnitude
        local targetName = player and player.Name or nil
        if Vars.SharedIgnoreListOwner ~= targetName then
            RebuildIgnoreList(player)
        end
        local params = Vars.SharedRayParams
        local hits = {}
        local origin = camPos
        local remaining = dist
        while remaining > 0.01 and #hits < 50 do
            local hit = Workspace:Raycast(origin, dir * remaining, params)
            if not hit then break end
            local hp = hit.Instance
            if player and player.Character and hp:IsDescendantOf(player.Character) then break end
            if hp.Parent and hp.Parent:IsA("Tool") then
                local nd = (hit.Position - origin).Magnitude
                origin = hit.Position + dir * 0.01
                remaining = remaining - nd - 0.01
                continue
            end
            if (ignoreTransparent and IsPartTransparent(hp)) or (ignoreNonCollidable and not hp.CanCollide) then
                local nd = (hit.Position - origin).Magnitude
                origin = hit.Position + dir * 0.01
                remaining = remaining - nd - 0.01
            else
                table_insert(hits, hp)
                local nd = (hit.Position - origin).Magnitude
                origin = hit.Position + dir * 0.01
                remaining = remaining - nd - 0.01
            end
        end
        if #hits == 0 then return "visible" end
        for _, p in ipairs(hits) do
            if not IsPartTransparent(p) and p.CanCollide then return "hidden" end
        end
        return "partially_visible"
    end

    local function CheckVisibility(player)
        if not player or not player.Character then return "hidden" end
        local head = player.Character:FindFirstChild("Head")
        if not head then return "hidden" end
        local cached = Vars.visibilityCache[player.Name]
        local now = os_clock()
        if cached and (now - cached.time) < Vars.VIS_CACHE_TTL then
            return cached.vis
        end
        local vis = CheckPositionVisibility(head.Position, player,
            Settings.Aimbot.IgnoreTransparent, Settings.Aimbot.IgnoreNonCollidable)
        Vars.visibilityCache[player.Name] = { vis = vis, time = now }
        return vis
    end
    Vars.CheckVisibility = CheckVisibility

    local function GetBoundingVectors(char)
        if not char then return nil, nil, false end
        local ok, cf, size = pcall(function()
            local c, s = char:GetBoundingBox()
            return c, s
        end)
        if not ok or not cf or not size then return nil, nil, false end
        local padding = Settings.ESP.BoxPadding
        size = size + V3(padding, padding, padding)
        local corners = {
            cf * CFrame_new(-size.X/2,  size.Y/2,  size.Z/2),
            cf * CFrame_new( size.X/2,  size.Y/2,  size.Z/2),
            cf * CFrame_new(-size.X/2, -size.Y/2,  size.Z/2),
            cf * CFrame_new( size.X/2, -size.Y/2,  size.Z/2),
            cf * CFrame_new(-size.X/2,  size.Y/2, -size.Z/2),
            cf * CFrame_new( size.X/2,  size.Y/2, -size.Z/2),
            cf * CFrame_new(-size.X/2, -size.Y/2, -size.Z/2),
            cf * CFrame_new( size.X/2, -size.Y/2, -size.Z/2),
        }
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        local anyOnScreen = false
        local cam = GetCamera()
        for _, corner in ipairs(corners) do
            local sp, onScreen = cam:WorldToViewportPoint(corner.Position)
            if onScreen then
                anyOnScreen = true
                if sp.X < minX then minX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y > maxY then maxY = sp.Y end
            end
        end
        if not anyOnScreen then return nil, nil, false end
        local boxPos = V2(minX, minY)
        local boxSize = V2(maxX - minX, maxY - minY)
        if boxSize.X > 5000 or boxSize.Y > 5000 or boxSize.X < 1 or boxSize.Y < 1 then
            return nil, nil, false
        end
        return boxPos, boxSize, true
    end
    Vars.GetBoundingVectors = GetBoundingVectors

    local function GetRigType(char)
        if not char then return nil end
        if char:FindFirstChild("UpperTorso") and char:FindFirstChild("LowerTorso") then
            return "R15"
        end
        if char:FindFirstChild("Torso") and char:FindFirstChild("Left Arm") then
            return "R6"
        end
        if char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") then
            return "R6"
        end
        return nil
    end
    Vars.GetRigType = GetRigType

    local R15_BONES = {
        {"UpperTorso", "Head"}, {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"}, {"UpperTorso", "LowerTorso"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    }
    local R6_BONES = {
        {"Torso", "Head"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
        {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
    }
    local function GetBonesForRig(rigType)
        if rigType == "R15" then return R15_BONES end
        if rigType == "R6" then return R6_BONES end
        return nil
    end
    Vars.GetBonesForRig = GetBonesForRig

    -- ============================================================
    -- Predicción con aceleración + ping (Rivals)
    -- ============================================================
    local function PredictPosition(part, amount, usePing)
        if not part then return nil end
        local pos = part.Position
        local vel = part.AssemblyLinearVelocity or V3(0,0,0)
        local acc = part.AssemblyLinearAcceleration or V3(0,0,0)
        local totalAmount = amount
        if usePing then
            local ping = 0
            pcall(function()
                ping = Vars.Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            end)
            totalAmount = totalAmount + ping * 0.5
        end
        return pos + vel * totalAmount + 0.5 * acc * totalAmount * totalAmount
    end
    Vars.PredictPosition = PredictPosition

    -- ============================================================
    -- FOV Selectivo
    -- ============================================================
    local function GetSelectiveBodyPart(player, screenPos, fovCenter, fovRadius)
        if not player or not player.Character then return nil end
        local char = player.Character
        local cam = GetCamera()
        if not cam then return nil end
        local cfg = Settings.Aimbot.Selective
        local rigType = GetRigType(char)
        if not rigType then return nil end

        local delta = V2(screenPos.X - fovCenter.X, screenPos.Y - fovCenter.Y)
        local distFromCenter = delta.Magnitude
        if distFromCenter < 0.01 then
            return char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        end

        local normX = math.clamp((delta.X + fovRadius) / (fovRadius * 2), 0, 1)
        local normY = math.clamp((delta.Y + fovRadius) / (fovRadius * 2), 0, 1)

        local verticalZone = "torso"
        if normY <= cfg.HeadZoneBottom then
            verticalZone = "head"
        elseif normY <= cfg.TorsoZoneBottom then
            verticalZone = "torso"
        else
            verticalZone = "legs"
        end

        local horizontalZone = "center"
        if normX <= cfg.LeftArmZoneRight then
            horizontalZone = "left"
        elseif normX >= cfg.RightArmZoneLeft then
            horizontalZone = "right"
        end

        local partName
        if rigType == "R15" then
            if verticalZone == "head" then
                partName = "Head"
            elseif verticalZone == "torso" then
                if horizontalZone == "left" then
                    partName = "LeftUpperArm"
                elseif horizontalZone == "right" then
                    partName = "RightUpperArm"
                else
                    partName = "UpperTorso"
                end
            else
                if horizontalZone == "left" then
                    partName = "LeftUpperLeg"
                elseif horizontalZone == "right" then
                    partName = "RightUpperLeg"
                else
                    partName = "LowerTorso"
                end
            end
        else
            if verticalZone == "head" then
                partName = "Head"
            elseif verticalZone == "torso" then
                if horizontalZone == "left" then
                    partName = "Left Arm"
                elseif horizontalZone == "right" then
                    partName = "Right Arm"
                else
                    partName = "Torso"
                end
            else
                if horizontalZone == "left" then
                    partName = "Left Leg"
                elseif horizontalZone == "right" then
                    partName = "Right Leg"
                else
                    partName = "Torso"
                end
            end
        end

        local part = char:FindFirstChild(partName)
        if not part then
            part = char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        end
        return part
    end
    Vars.GetSelectiveBodyPart = GetSelectiveBodyPart

    -- ============================================================
    -- Modo Híbrido
    -- ============================================================
    local hybridState = {
        currentPart = "Head",
        lastChange = 0,
    }
    local function GetHybridBodyPart(player, screenPos, fovCenter, fovRadius)
        if not player or not player.Character then return nil end
        local char = player.Character
        local cfg = Settings.Aimbot.Hybrid
        local now = os_clock()

        local delta = V2(screenPos.X - fovCenter.X, screenPos.Y - fovCenter.Y)
        local normY = (delta.Y + fovRadius) / (fovRadius * 2)
        normY = math.clamp(normY, 0, 1)

        local targetPart = cfg.BasePart
        if normY > 0.5 + cfg.VerticalBiasThreshold then
            targetPart = "UpperTorso"
        end
        if normY > 0.75 + cfg.VerticalBiasThreshold then
            targetPart = "LowerTorso"
        end
        if not cfg.AllowReturn and normY < 0.5 then
            targetPart = hybridState.currentPart
        end

        if targetPart ~= hybridState.currentPart then
            if (now - hybridState.lastChange) > 0.15 then
                hybridState.currentPart = targetPart
                hybridState.lastChange = now
            else
                targetPart = hybridState.currentPart
            end
        end

        local part = char:FindFirstChild(targetPart)
        if not part then
            local r6Map = { UpperTorso = "Torso", LowerTorso = "Torso" }
            part = char:FindFirstChild(r6Map[targetPart] or targetPart)
        end
        if not part then
            part = char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        end
        return part
    end
    Vars.GetHybridBodyPart = GetHybridBodyPart

    -- ============================================================
    -- Bone Priority
    -- ============================================================
    local function GetBestBodyPartByPriority(player, cam)
        if not player or not player.Character then return nil end
        local char = player.Character
        if not cam then cam = GetCamera() end
        if not cam then return nil end
        local center = V2(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local best, bestScore = nil, math.huge
        local priorities = Settings.Aimbot.BonePriority
        for partName, priority in pairs(priorities) do
            local part = char:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (V2(sp.X, sp.Y) - center).Magnitude
                    local score = dist / math.max(priority, 0.01)
                    if score < bestScore then
                        bestScore = score
                        best = part
                    end
                end
            end
        end
        return best
    end
    Vars.GetBestBodyPartByPriority = GetBestBodyPartByPriority

    -- ============================================================
    -- Backtrack
    -- ============================================================
    local function UpdatePositionHistory()
        local now = os_clock()
        for _, p in ipairs(Vars.activePlayers) do
            if not p.Character then continue end
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            Vars.positionHistory[p.Name] = Vars.positionHistory[p.Name] or {}
            table.insert(Vars.positionHistory[p.Name], 1, {
                pos = root.Position,
                time = now,
                cframe = root.CFrame,
            })
            while #Vars.positionHistory[p.Name] > Vars.POS_HISTORY_MAX do
                table.remove(Vars.positionHistory[p.Name])
            end
            while #Vars.positionHistory[p.Name] > 0
                and (now - Vars.positionHistory[p.Name][#Vars.positionHistory[p.Name]].time) > Vars.POS_HISTORY_TTL do
                table.remove(Vars.positionHistory[p.Name])
            end
        end
    end
    Vars.UpdatePositionHistory = UpdatePositionHistory

    local function GetBacktrackPosition(playerName, delay)
        local hist = Vars.positionHistory[playerName]
        if not hist or #hist == 0 then return nil end
        local targetTime = os_clock() - delay
        for _, entry in ipairs(hist) do
            if entry.time <= targetTime then
                return entry.pos, entry.cframe
            end
        end
        return hist[#hist].pos, hist[#hist].cframe
    end
    Vars.GetBacktrackPosition = GetBacktrackPosition

    -- Loop de historial
    Vars.posHistoryConn = Vars.RunService.Heartbeat:Connect(function()
        if Vars.isScriptUnloaded then return end
        if Settings.Backtrack.Enabled then
            Vars.UpdatePositionHistory()
        end
    end)
end

-- ============================================================
-- BLOQUE 4: ESP / Chams / Skeleton / HeadDots / Items / Weapons
-- (Optimizado con Grok: Pool compacto, Update compacto, Loops unificados)
-- ============================================================
do
    local LP = Vars.LP
    local CoreGui = Vars.CoreGui
    local Settings = Vars.Settings
    local V2 = Vars.Vector2_new
    local V3 = Vars.Vector3_new
    local CFrame_new = Vars.CFrame_new
    local math_floor = Vars.math_floor
    local math_clamp = Vars.math_clamp
    local math_max = Vars.math_max
    local table_insert = Vars.table_insert
    local table_remove = Vars.table_remove
    local table_clear = Vars.table_clear
    local string_find = Vars.string_find
    local os_clock = Vars.os_clock

    local function GetCamera() return Vars.GetCamera() end
    local function IsPassive(name) return Vars.IsPassive(name) end
    local function CheckVisibility(p) return Vars.CheckVisibility(p) end
    local function GetBoundingVectors(c) return Vars.GetBoundingVectors(c) end
    local function GetRigType(c) return Vars.GetRigType(c) end
    local function GetBonesForRig(r) return Vars.GetBonesForRig(r) end

    -- ============================================================
    -- Skeleton line pool
    -- ============================================================
    local function AcquireSkeletonLine()
        local line = table_remove(Vars.SkeletonLinePool)
        if line then line.Visible = false; return line end
        line = Drawing.new("Line")
        line.Thickness = 1
        line.Visible = false
        return line
    end

    local function ReleaseSkeletonLine(line)
        if not line then return end
        line.Visible = false
        if #Vars.SkeletonLinePool < Vars.SkeletonLinePoolMAX then
            table_insert(Vars.SkeletonLinePool, line)
        else
            pcall(function() line:Remove() end)
        end
    end

    local function ClearSkeletonForPlayer(playerName)
        if not playerName then return end
        local data = Vars.ActiveSkeletons[playerName]
        if not data then return end
        for _, line in ipairs(data.lines) do
            ReleaseSkeletonLine(line)
        end
        Vars.ActiveSkeletons[playerName] = nil
    end
    Vars.ClearSkeletonForPlayer = ClearSkeletonForPlayer

    local function ClearAllSkeletons()
        for name in pairs(Vars.ActiveSkeletons) do
            ClearSkeletonForPlayer(name)
        end
    end
    Vars.ClearAllSkeletons = ClearAllSkeletons

    -- ============================================================
    -- ESP Pool (compacto - Grok)
    -- ============================================================
    local function GetOrCreateESP(name)
        local esp = Vars.ESPPool[name]
        if esp then return esp end

        local function take(pool, create)
            local obj = table_remove(Vars.ESPObjectPool[pool])
            if obj then return obj end
            return create()
        end

        local box = take("box", function()
            local b = Drawing.new("Square")
            b.Thickness = 1; b.Filled = false; b.Visible = false
            return b
        end)

        local health = take("health", function()
            local h = Drawing.new("Line")
            h.Thickness = 2; h.Visible = false
            return h
        end)

        local nameLabel = take("name", function()
            local n = Drawing.new("Text")
            n.Size = 16; n.Center = true; n.Outline = true; n.Font = 2; n.Visible = false
            return n
        end)

        local headDot = take("headDot", function()
            local c = Drawing.new("Circle")
            c.Filled = true; c.Visible = false
            return c
        end)

        local weapon = take("weapon", function()
            local w = Drawing.new("Text")
            w.Size = 16; w.Center = true; w.Outline = true; w.Font = 2; w.Visible = false
            return w
        end)

        local chams = take("chams", function()
            local h = Instance.new("Highlight")
            h.FillColor = Settings.ESP.ChamsColor
            h.OutlineColor = Settings.ESP.ChamsOutlineColor
            h.FillTransparency = Settings.ESP.ChamsFillTransparency
            h.OutlineTransparency = Settings.ESP.ChamsOutlineTransparency
            h.DepthMode = Enum.HighlightDepthMode[Settings.ESP.ChamsDepthMode] or Enum.HighlightDepthMode.AlwaysOnTop
            h.Enabled = false
            h.Parent = CoreGui
            return h
        end)
        chams.Parent = CoreGui

        esp = { box = box, health = health, name = nameLabel, chams = chams, headDot = headDot, weapon = weapon }
        Vars.ESPPool[name] = esp
        return esp
    end
    Vars.GetOrCreateESP = GetOrCreateESP

    -- ============================================================
    -- Remove ESP (compacto - Grok)
    -- ============================================================
    local function RemoveESPForPlayer(name)
        local esp = Vars.ESPPool[name]
        if not esp then return end

        local function release(obj, pool, isHighlight)
            if not obj then return end
            if isHighlight then
                obj.Enabled = false
                obj.Adornee = nil
                obj.Parent = nil
            else
                obj.Visible = false
            end
            if #Vars.ESPObjectPool[pool] < Vars.ESPObjectPoolMAX then
                table_insert(Vars.ESPObjectPool[pool], obj)
            else
                pcall(function()
                    if isHighlight then obj:Destroy() else obj:Remove() end
                end)
            end
        end

        release(esp.box, "box")
        release(esp.health, "health")
        release(esp.name, "name")
        release(esp.headDot, "headDot")
        release(esp.weapon, "weapon")
        release(esp.chams, "chams", true)

        Vars.ESPPool[name] = nil
    end
    Vars.RemoveESPForPlayer = RemoveESPForPlayer

    -- ============================================================
    -- Clear All ESP (compacto - Grok)
    -- ============================================================
    local function ClearAllESP()
        for name in pairs(Vars.ESPPool) do
            RemoveESPForPlayer(name)
        end
        for poolName, list in pairs(Vars.ESPObjectPool) do
            for _, obj in ipairs(list) do
                pcall(function()
                    if obj:IsA("Highlight") then obj:Destroy() else obj:Remove() end
                end)
            end
            Vars.ESPObjectPool[poolName] = {}
        end
    end
    Vars.ClearAllESP = ClearAllESP

    local function GetESPColor(player)
        if IsPassive(player.Name) then return Settings.ESP.Colors.Passive end
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then return Settings.ESP.Colors.Dead end
        return Settings.ESP.Colors.Visible
    end

    -- ============================================================
    -- Update ESP (compacto - Grok)
    -- ============================================================
    local function UpdateESPForPlayer(player)
        if not player or player == LP then return end

        local esp = Vars.ESPPool[player.Name]
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        -- Early return si no hay personaje, está muerto o ESP desactivado
        if not char or not hum or hum.Health <= 0 or not Settings.ESP.Enabled then
            if esp then
                esp.box.Visible = false
                esp.health.Visible = false
                esp.name.Visible = false
                esp.chams.Enabled = false
                if esp.headDot then esp.headDot.Visible = false end
                if esp.weapon then esp.weapon.Visible = false end
            end
            ClearSkeletonForPlayer(player.Name)
            return
        end

        esp = GetOrCreateESP(player.Name)
        local boxPos, boxSize, isVisible = GetBoundingVectors(char)
        local color = GetESPColor(player)

        -- Chams
        if Settings.ESP.Chams then
            esp.chams.Adornee = char
            esp.chams.FillColor = color
            esp.chams.OutlineColor = Settings.ESP.ChamsOutlineColor
            esp.chams.OutlineTransparency = Settings.ESP.ChamsOutlineTransparency
            esp.chams.DepthMode = Enum.HighlightDepthMode[Settings.ESP.ChamsDepthMode] or Enum.HighlightDepthMode.AlwaysOnTop
            esp.chams.FillTransparency = (Settings.ESP.WallcheckChams and CheckVisibility(player) == "hidden")
                and 1 or Settings.ESP.ChamsFillTransparency
            esp.chams.Enabled = true
        else
            esp.chams.Enabled = false
        end

        -- Si no está en pantalla, ocultamos todo lo 2D
        if not isVisible or not boxPos or not boxSize then
            esp.box.Visible = false
            esp.health.Visible = false
            esp.name.Visible = false
            if esp.headDot then esp.headDot.Visible = false end
            if esp.weapon then esp.weapon.Visible = false end
            ClearSkeletonForPlayer(player.Name)
            return
        end

        -- Box
        esp.box.Visible = Settings.ESP.Box
        if Settings.ESP.Box then
            esp.box.Position = boxPos
            esp.box.Size = boxSize
            esp.box.Color = Settings.ESP.BoxColor
            esp.box.Thickness = Settings.ESP.BoxThickness
        end

        -- Health
        if Settings.ESP.ShowHealth then
            local hp = math_clamp(hum.Health / math_max(hum.MaxHealth, 1), 0, 1)
            esp.health.From = V2(boxPos.X - 5, boxPos.Y + boxSize.Y)
            esp.health.To = V2(boxPos.X - 5, boxPos.Y + boxSize.Y * (1 - hp))
            esp.health.Color = Color3.fromHSV(hp * 0.3, 1, 1)
            esp.health.Thickness = Settings.ESP.HealthThickness
            esp.health.Visible = true
        else
            esp.health.Visible = false
        end

        -- Name
        if Settings.ESP.ShowName then
            local text = player.Name
            if Settings.ESP.ShowDistance and LP.Character then
                local myRoot = LP.Character:FindFirstChild("HumanoidRootPart")
                local theirRoot = char:FindFirstChild("HumanoidRootPart")
                if myRoot and theirRoot then
                    text = text .. " [" .. math_floor((myRoot.Position - theirRoot.Position).Magnitude) .. "m]"
                end
            end
            esp.name.Text = text
            esp.name.Position = V2(boxPos.X + boxSize.X/2, boxPos.Y - 18)
            esp.name.Color = Settings.ESP.NameColor
            esp.name.Visible = true
        else
            esp.name.Visible = false
        end

        -- Head Dot
        if Settings.ESP.HeadDots and esp.headDot then
            local head = char:FindFirstChild("Head")
            if head then
                local sp, onScreen = GetCamera():WorldToViewportPoint(head.Position)
                if onScreen then
                    esp.headDot.Position = V2(sp.X, sp.Y)
                    esp.headDot.Radius = Settings.ESP.HeadDotRadius
                    esp.headDot.Thickness = Settings.ESP.HeadDotThickness
                    esp.headDot.Color = Settings.ESP.HeadDotColor
                    esp.headDot.Transparency = Settings.ESP.HeadDotTransparency
                    esp.headDot.Visible = true
                else
                    esp.headDot.Visible = false
                end
            else
                esp.headDot.Visible = false
            end
        elseif esp.headDot then
            esp.headDot.Visible = false
        end

        -- Weapon
        if Settings.ESP.Weapons and esp.weapon then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                esp.weapon.Text = tool.Name
                esp.weapon.Position = V2(boxPos.X + boxSize.X/2, boxPos.Y + boxSize.Y + 14)
                esp.weapon.Color = Settings.ESP.WeaponColor
                esp.weapon.Size = Settings.ESP.WeaponTextSize
                esp.weapon.Visible = true
            else
                esp.weapon.Visible = false
            end
        elseif esp.weapon then
            esp.weapon.Visible = false
        end
    end
    Vars.UpdateESPForPlayer = UpdateESPForPlayer

    -- ============================================================
    -- Update Skeleton (compacto - Grok)
    -- ============================================================
    local function UpdateSkeletonForPlayer(player)
        if not player or player == LP or not Settings.Skeleton.Enabled then
            ClearSkeletonForPlayer(player and player.Name)
            return
        end

        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then
            ClearSkeletonForPlayer(player.Name)
            return
        end

        if Settings.Skeleton.OnlyVisible and CheckVisibility(player) == "hidden" then
            ClearSkeletonForPlayer(player.Name)
            return
        end

        if Settings.Skeleton.MaxDistance > 0 and LP.Character then
            local myRoot = LP.Character:FindFirstChild("HumanoidRootPart")
            local theirRoot = char:FindFirstChild("HumanoidRootPart")
            if myRoot and theirRoot and (myRoot.Position - theirRoot.Position).Magnitude > Settings.Skeleton.MaxDistance then
                ClearSkeletonForPlayer(player.Name)
                return
            end
        end

        local rigType = GetRigType(char)
        if not rigType then
            ClearSkeletonForPlayer(player.Name)
            return
        end

        local mode = Settings.Skeleton.RigMode
        if (mode == "R6" and rigType ~= "R6") or (mode == "R15" and rigType ~= "R15") then
            ClearSkeletonForPlayer(player.Name)
            return
        end

        local bones = GetBonesForRig(rigType)
        if not bones then
            ClearSkeletonForPlayer(player.Name)
            return
        end

        local data = Vars.ActiveSkeletons[player.Name]
        if not data or data.rigType ~= rigType then
            ClearSkeletonForPlayer(player.Name)
            data = { lines = {}, rigType = rigType }
            Vars.ActiveSkeletons[player.Name] = data
        end

        local cam = GetCamera()
        for i, bone in ipairs(bones) do
            local line = data.lines[i] or AcquireSkeletonLine()
            data.lines[i] = line

            local a = char:FindFirstChild(bone[1])
            local b = char:FindFirstChild(bone[2])
            if a and b then
                local va, oa = cam:WorldToViewportPoint(a.Position)
                local vb, ob = cam:WorldToViewportPoint(b.Position)
                if oa and ob then
                    line.From = V2(va.X, va.Y)
                    line.To = V2(vb.X, vb.Y)
                    line.Color = Settings.Skeleton.Color
                    line.Thickness = Settings.Skeleton.Thickness
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end

        for i = #bones + 1, #data.lines do
            data.lines[i].Visible = false
        end
    end
    Vars.UpdateSkeletonForPlayer = UpdateSkeletonForPlayer

    -- ============================================================
    -- Items ESP (optimizado - Grok)
    -- ============================================================
    local ItemESPList = Vars.ItemESPList or {}
    Vars.ItemESPList = ItemESPList

    local function IsItemPart(part)
        if not part or not part:IsA("BasePart") then return false end

        -- Evitar partes de personajes (Grok)
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then
            return false
        end

        local name = part.Name:lower()
        if name:find("weapon") or name:find("gun") or name:find("collectible")
            or name:find("pickup") or name:find("item") or name:find("loot") then
            return true
        end

        local parent = part.Parent
        if parent and parent:IsA("Tool") then return true end
        return false
    end
    Vars.IsItemPart = IsItemPart

    local function CreateItemESP(part)
        if not part or not part.Parent then return end
        if ItemESPList[part] then return end
        if not Settings.ESP.Enabled or not Settings.ESP.Items then return end
        if not IsItemPart(part) then return end

        local label = Drawing.new("Text")
        label.Size = Settings.ESP.ItemTextSize or 14
        label.Center = true
        label.Outline = true
        label.OutlineColor = Color3.new(0, 0, 0)
        label.Font = 2
        label.Color = Settings.ESP.ItemColor or Color3.fromRGB(255, 255, 100)
        label.Visible = false
        label.Text = part.Name

        ItemESPList[part] = label
    end
    Vars.CreateItemESP = CreateItemESP

    local function ClearItemESP()
        for part, label in pairs(ItemESPList) do
            pcall(function() label:Remove() end)
        end
        table_clear(ItemESPList)
    end
    Vars.ClearItemESP = ClearItemESP

    local function UpdateItemESP()
        if not Settings.ESP.Enabled or not Settings.ESP.Items then
            for _, label in pairs(ItemESPList) do
                label.Visible = false
            end
            return
        end

        local cam = GetCamera()
        if not cam then return end

        local lpRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local maxDist = Settings.ESP.ItemMaxDistance or 0
        local itemColor = Settings.ESP.ItemColor
        local itemSize = Settings.ESP.ItemTextSize

        for part, label in pairs(ItemESPList) do
            if not part or not part.Parent then
                pcall(function() label:Remove() end)
                ItemESPList[part] = nil
            else
                local show = true
                if lpRoot and maxDist > 0 then
                    local dist = (part.Position - lpRoot.Position).Magnitude
                    if dist > maxDist then
                        show = false
                    end
                end

                if show then
                    local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        label.Position = V2(screenPos.X, screenPos.Y)
                        label.Color = itemColor
                        label.Size = itemSize
                        label.Text = part.Name
                        label.Visible = true
                    else
                        label.Visible = false
                    end
                else
                    label.Visible = false
                end
            end
        end
    end
    Vars.UpdateItemESP = UpdateItemESP

    -- Conexiones (con task.defer - Grok)
    if not Vars.itemAddedConn then
        Vars.itemAddedConn = Vars.Workspace.DescendantAdded:Connect(function(desc)
            if Vars.isScriptUnloaded then return end
            if desc:IsA("BasePart") and IsItemPart(desc) then
                task.defer(CreateItemESP, desc)
            end
        end)
    end

    if not Vars.itemRemovingConn then
        Vars.itemRemovingConn = Vars.Workspace.DescendantRemoving:Connect(function(desc)
            if Vars.isScriptUnloaded then return end
            local label = ItemESPList[desc]
            if label then
                pcall(function() label:Remove() end)
                ItemESPList[desc] = nil
            end
        end)
    end

    -- ============================================================
    -- Rebuild active players
    -- ============================================================
    local function RebuildActivePlayers()
        Vars.activePlayers = {}
        for _, p in ipairs(Vars.Players:GetPlayers()) do
            if p ~= LP then
                table_insert(Vars.activePlayers, p)
            end
        end
    end
    Vars.RebuildActivePlayers = RebuildActivePlayers
    RebuildActivePlayers()

    -- ============================================================
    -- ✅ NUEVO v9.8.0: UN SOLO LOOP ESP + Skeleton (Grok)
    -- ============================================================
    Vars.espSkeletonConn = Vars.RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end

        local now = os_clock()
        local players = Vars.activePlayers
        if not players or #players == 0 then return end

        -- ========== ESP ==========
        if Settings.ESP.Enabled then
            local espRate = Settings.Performance.ESPUpdateRate or 0.03
            if (now - Vars.lastESPUpdate) >= espRate then
                Vars.lastESPUpdate = now

                for i = 1, #players do
                    Vars.SilentPcall(UpdateESPForPlayer, players[i])
                end

                if Settings.ESP.Items then
                    Vars.SilentPcall(UpdateItemESP)
                end
            end
        end

        -- ========== Skeleton ==========
        if Settings.Skeleton.Enabled then
            local skRate = Settings.Performance.SkeletonUpdateRate or 0.04
            if (now - Vars.lastSkeletonUpdate) >= skRate then
                Vars.lastSkeletonUpdate = now

                for i = 1, #players do
                    Vars.SilentPcall(UpdateSkeletonForPlayer, players[i])
                end
            end
        end
    end)
end

-- ============================================================
-- BLOQUE 5: HUD + Eventos + Lighting (mejorado - Grok) + Custom FOV + HideBody + Crosshair
-- ============================================================
do
    local Players = Vars.Players
    local RunService = Vars.RunService
    local UserInputService = Vars.UserInputService
    local Stats = Vars.Stats
    local Lighting = Vars.Lighting
    local LP = Vars.LP
    local Settings = Vars.Settings
    local V2 = Vars.Vector2_new
    local V3 = Vars.Vector3_new
    local CFrame_new = Vars.CFrame_new
    local math_floor = Vars.math_floor
    local table_insert = Vars.table_insert
    local os_clock = Vars.os_clock

    local function GetCamera() return Vars.GetCamera() end

    -- ============================================================
    -- HUD
    -- ============================================================
    local HudLabel = Drawing.new("Text")
    HudLabel.Visible = false
    HudLabel.Size = 18
    HudLabel.Outline = true
    HudLabel.Color = Color3.fromRGB(0, 255, 0)
    HudLabel.Font = 2
    Vars.HudLabel = HudLabel

    local AimModeLabel = Drawing.new("Text")
    AimModeLabel.Visible = false
    AimModeLabel.Size = 16
    AimModeLabel.Outline = true
    AimModeLabel.Color = Color3.fromRGB(255, 255, 0)
    AimModeLabel.Font = 2
    Vars.AimModeLabel = AimModeLabel

    local cachedFPS = 60
    local cachedPing = 0
    local frameCount = 0
    local lastFPSReset = os_clock()

    local function GetPing()
        local ok, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and ping then return math_floor(ping) end
        return 0
    end
    Vars.GetPing = GetPing

    Vars.fpsCounterConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        frameCount = frameCount + 1
        local now = os_clock()
        if (now - lastFPSReset) >= 1 then
            cachedFPS = frameCount
            frameCount = 0
            lastFPSReset = now
        end
    end)

    Vars.pingUpdateConn = RunService.Heartbeat:Connect(function()
        if Vars.isScriptUnloaded then return end
        pcall(function() cachedPing = GetPing() end)
    end)

    Vars.hudConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        if not Settings.HUD.Enabled then
            HudLabel.Visible = false
            AimModeLabel.Visible = false
            return
        end
        HudLabel.Visible = true
        local cam = GetCamera()
        local text = ""
        if Settings.HUD.ShowFPS then text = "FPS: " .. cachedFPS end
        if Settings.HUD.ShowPing then
            if text ~= "" then text = text .. "\n" end
            text = text .. "PING: " .. cachedPing .. "ms"
        end
        HudLabel.Text = text
        if cachedFPS >= 60 then
            HudLabel.Color = Color3.fromRGB(0, 255, 0)
        elseif cachedFPS >= 30 then
            HudLabel.Color = Color3.fromRGB(255, 255, 0)
        else
            HudLabel.Color = Color3.fromRGB(255, 0, 0)
        end
        local pos = Settings.HUD.Position
        if pos == "TopRight" then
            HudLabel.Position = V2(cam.ViewportSize.X - 120, 20)
            AimModeLabel.Position = V2(cam.ViewportSize.X - 220, 60)
        elseif pos == "TopLeft" then
            HudLabel.Position = V2(20, 20)
            AimModeLabel.Position = V2(20, 60)
        elseif pos == "BottomRight" then
            HudLabel.Position = V2(cam.ViewportSize.X - 120, cam.ViewportSize.Y - 80)
            AimModeLabel.Position = V2(cam.ViewportSize.X - 220, cam.ViewportSize.Y - 120)
        elseif pos == "BottomLeft" then
            HudLabel.Position = V2(20, cam.ViewportSize.Y - 80)
            AimModeLabel.Position = V2(20, cam.ViewportSize.Y - 120)
        end

        if Settings.Aimbot.Enabled then
            local mode = Settings.Aimbot.AimPartMode
            if mode == "Selective FOV" then
                AimModeLabel.Text = "AIM: Selective (" .. (Vars.currentSelectivePartName or "?") .. ")"
                AimModeLabel.Visible = true
            elseif mode == "Hybrid" then
                AimModeLabel.Text = "AIM: Hybrid (" .. (Vars.currentHybridPartName or "Head") .. ")"
                AimModeLabel.Visible = true
            else
                AimModeLabel.Text = "AIM: " .. mode
                AimModeLabel.Visible = true
            end
        else
            AimModeLabel.Visible = false
        end
    end)

    -- ============================================================
    -- Eventos de jugadores
    -- ============================================================
    Vars.playerAddedConn = Players.PlayerAdded:Connect(function(p)
        if p ~= LP then Vars.RebuildActivePlayers() end
    end)

    Vars.playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
        Vars.RemoveESPForPlayer(p.Name)
        Vars.ClearSkeletonForPlayer(p.Name)
        Vars.visibilityCache[p.Name] = nil
        Vars.highlightCooldowns[p.Name] = nil
        Vars.positionHistory[p.Name] = nil
        Vars.RebuildActivePlayers()
    end)

    Vars.localCharConn = LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        Vars.ClearAllSkeletons()
        Vars.ClearAllESP()
        Vars.isLocalDead = false
        if Vars.RebuildIgnoreList then
            Vars.RebuildIgnoreList(nil)
        end
    end)

    Vars.localDiedConn = nil
    if LP.Character then
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            Vars.localDiedConn = hum.Died:Connect(function()
                Vars.isLocalDead = true
            end)
        end
    end

    -- ============================================================
    -- ✅ Visuals / Lighting (mejorado - Grok)
    -- ============================================================

    -- Guardar valores originales una sola vez
    local function SaveOriginalLighting()
        if Vars.OriginalLighting then return end
        Vars.OriginalLighting = {
            Brightness = Lighting.Brightness,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            FogColor = Lighting.FogColor,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Ambient = Lighting.Ambient,
            GlobalShadows = Lighting.GlobalShadows,
        }
    end
    Vars.SaveOriginalLighting = SaveOriginalLighting

    local function setFullBright(enabled)
        SaveOriginalLighting()

        if enabled then
            Lighting.Brightness = 2.5
            Lighting.FogEnd = 9e9
            Lighting.FogStart = 0
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Ambient = Color3.fromRGB(180, 180, 180)
            Lighting.GlobalShadows = false
        else
            local orig = Vars.OriginalLighting
            Lighting.Brightness = orig.Brightness
            Lighting.FogEnd = Settings.Visuals.NoFog and 9e9 or orig.FogEnd
            Lighting.FogStart = Settings.Visuals.NoFog and 0 or orig.FogStart
            Lighting.OutdoorAmbient = orig.OutdoorAmbient
            Lighting.Ambient = orig.Ambient
            Lighting.GlobalShadows = orig.GlobalShadows
        end
        Settings.FullBright.Enabled = enabled
    end
    Vars.setFullBright = setFullBright

    local function setNoFog(enabled)
        SaveOriginalLighting()
        if enabled then
            Lighting.FogEnd = 9e9
            Lighting.FogStart = 0
        else
            if not Settings.FullBright.Enabled then
                Lighting.FogEnd = Vars.OriginalLighting.FogEnd
                Lighting.FogStart = Vars.OriginalLighting.FogStart
            end
        end
        Settings.Visuals.NoFog = enabled
    end
    Vars.setNoFog = setNoFog

    local function setNoBloom(enabled)
        pcall(function()
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("BloomEffect") then
                    effect.Enabled = not enabled
                end
            end
        end)
        Settings.Visuals.NoBloom = enabled
    end
    Vars.setNoBloom = setNoBloom

    local function setNoSunRays(enabled)
        pcall(function()
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("SunRaysEffect") then
                    effect.Enabled = not enabled
                end
            end
        end)
        Settings.Visuals.NoSunRays = enabled
    end
    Vars.setNoSunRays = setNoSunRays

    local function setCustomFOV(enabled, value)
        local cam = GetCamera()
        if not cam then return end
        if enabled then
            if Settings.Visuals.OriginalFOV == nil then
                Settings.Visuals.OriginalFOV = cam.FieldOfView
            end
            cam.FieldOfView = value or Settings.Visuals.FOVValue or 70
        else
            if Settings.Visuals.OriginalFOV then
                cam.FieldOfView = Settings.Visuals.OriginalFOV
                Settings.Visuals.OriginalFOV = nil
            end
        end
        Settings.Visuals.CustomFOV = enabled
    end
    Vars.setCustomFOV = setCustomFOV

    -- Reset total de visuales
    local function ResetAllVisuals()
        setFullBright(false)
        setNoFog(false)
        setNoBloom(false)
        setNoSunRays(false)
        setCustomFOV(false)
    end
    Vars.ResetAllVisuals = ResetAllVisuals

    -- Detectar efectos nuevos (Bloom/SunRays) que el juego cree después (Grok)
    Vars.lightingChildAddedConn = Lighting.ChildAdded:Connect(function(child)
        if Vars.isScriptUnloaded then return end
        if Settings.Visuals.NoBloom and child:IsA("BloomEffect") then
            child.Enabled = false
        end
        if Settings.Visuals.NoSunRays and child:IsA("SunRaysEffect") then
            child.Enabled = false
        end
    end)

    -- ============================================================
    -- HideBody
    -- ============================================================
    local HIDE_BODY_PARTS = {
        "UpperTorso", "LowerTorso", "Torso",
        "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    }
    local HIDE_HANDS_PARTS = { "LeftHand", "RightHand" }

    local function ApplyHideBody()
        if not LP.Character then return end
        local char = LP.Character
        for _, partName in ipairs(HIDE_BODY_PARTS) do
            local part = char:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.LocalTransparencyModifier = Settings.Visuals.HideBody and 1 or 0
            end
        end
        for _, partName in ipairs(HIDE_HANDS_PARTS) do
            local part = char:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.LocalTransparencyModifier = Settings.Visuals.HideHands and 1 or 0
            end
        end
        if Settings.Visuals.HideTool then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local tool = hum:FindFirstChildOfClass("Tool") or char:FindFirstChildOfClass("Tool")
                if tool then
                    for _, part in ipairs(tool:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.LocalTransparencyModifier = 1
                        end
                    end
                end
            end
        end
    end

    local function StartHideBody()
        if Vars.hideBodyConnection then return end
        Vars.hideBodyConnection = RunService.RenderStepped:Connect(function()
            if Vars.isScriptUnloaded then return end
            if Settings.Visuals.HideBody or Settings.Visuals.HideHands or Settings.Visuals.HideTool then
                pcall(ApplyHideBody)
            end
        end)
    end
    Vars.StartHideBody = StartHideBody

    local function StopHideBody()
        if Vars.hideBodyConnection then
            pcall(function() Vars.hideBodyConnection:Disconnect() end)
            Vars.hideBodyConnection = nil
        end
    end
    Vars.StopHideBody = StopHideBody

    -- ============================================================
    -- Crosshair (con RaycastParams reutilizado)
    -- ============================================================
    local function CreateCrosshairLines()
        for _, line in ipairs(Vars.CrosshairLines) do
            pcall(function() line:Remove() end)
        end
        Vars.CrosshairLines = {}
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = Settings.Visuals.CrosshairThickness
            table_insert(Vars.CrosshairLines, line)
        end
    end

    local function UpdateCrosshair()
        if not Settings.Visuals.Crosshair then
            for _, line in ipairs(Vars.CrosshairLines) do
                line.Visible = false
            end
            return
        end
        if #Vars.CrosshairLines == 0 then CreateCrosshairLines() end

        local cam = GetCamera()
        if not cam then return end
        local center = V2(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

        local isEnemy = false
        local ignore = {}
        if LP.Character then table_insert(ignore, LP.Character) end
        if cam then table_insert(ignore, cam) end
        Vars.CrosshairRayParams.FilterDescendantsInstances = ignore
        local ray = cam:ViewportPointToRay(center.X, center.Y)
        local result = Vars.Workspace:Raycast(ray.Origin, ray.Direction * 1000, Vars.CrosshairRayParams)
        if result and result.Instance then
            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
            if hitChar and hitChar ~= LP.Character then
                local plr = Vars.Players:GetPlayerFromCharacter(hitChar)
                if plr and plr ~= LP then isEnemy = true end
            end
        end

        local color = isEnemy and Settings.Visuals.CrosshairEnemyColor or Settings.Visuals.CrosshairColor
        local size = Settings.Visuals.CrosshairSize
        local gap = Settings.Visuals.CrosshairGap
        local thickness = Settings.Visuals.CrosshairThickness
        local transparency = Settings.Visuals.CrosshairTransparency

        local positions = {
            {From = V2(center.X + gap, center.Y), To = V2(center.X + gap + size, center.Y)},
            {From = V2(center.X - gap, center.Y), To = V2(center.X - gap - size, center.Y)},
            {From = V2(center.X, center.Y + gap), To = V2(center.X, center.Y + gap + size)},
            {From = V2(center.X, center.Y - gap), To = V2(center.X, center.Y - gap - size)},
        }

        for i, line in ipairs(Vars.CrosshairLines) do
            line.From = positions[i].From
            line.To = positions[i].To
            line.Color = color
            line.Thickness = thickness
            line.Transparency = transparency
            line.Visible = true
        end
    end
    Vars.UpdateCrosshair = UpdateCrosshair

    local function StartCrosshair()
        if Vars.CrosshairConn then return end
        CreateCrosshairLines()
        Vars.CrosshairConn = RunService.RenderStepped:Connect(UpdateCrosshair)
    end
    Vars.StartCrosshair = StartCrosshair

    local function StopCrosshair()
        if Vars.CrosshairConn then
            pcall(function() Vars.CrosshairConn:Disconnect() end)
            Vars.CrosshairConn = nil
        end
        for _, line in ipairs(Vars.CrosshairLines) do
            pcall(function() line:Remove() end)
        end
        Vars.CrosshairLines = {}
    end
    Vars.StopCrosshair = StopCrosshair
end

-- ============================================================
-- BLOQUE 6: Bullet Tracers (mejorado - Grok) + No Recoil + X-Ray
-- ============================================================
do
    local RunService = Vars.RunService
    local LP = Vars.LP
    local Settings = Vars.Settings
    local V2 = Vars.Vector2_new
    local V3 = Vars.Vector3_new
    local table_insert = Vars.table_insert
    local table_remove = Vars.table_remove
    local table_clear = Vars.table_clear
    local os_clock = Vars.os_clock
    local string_find = Vars.string_find

    local function GetCamera() return Vars.GetCamera() end

    -- ============================================================
    -- ✅ Tracers mejorados (Grok)
    -- ============================================================
    local function AcquireTracer()
        local t = table_remove(Vars.TracerPool)
        if t then
            t.Visible = false
            return t
        end
        t = Drawing.new("Line")
        t.Thickness = 2
        t.Visible = false
        return t
    end

    local function ReleaseTracer(t)
        if not t then return end
        t.Visible = false
        if #Vars.TracerPool < Vars.TracerPoolMAX then
            table_insert(Vars.TracerPool, t)
        else
            pcall(function() t:Remove() end)
        end
    end

    local function CreateTracer(fromPos, toPos)
        if not Settings.Visuals.BulletTracers then return end
        if not fromPos or not toPos then return end

        local dist = (fromPos - toPos).Magnitude
        if dist > Settings.Visuals.TracerMaxDistance then return end

        -- Límite de tracers activos (Grok)
        local maxActive = Settings.Visuals.MaxActiveTracers or 40
        if #Vars.ActiveTracers >= maxActive then
            local oldest = table_remove(Vars.ActiveTracers, 1)
            if oldest then ReleaseTracer(oldest.tracer) end
        end

        local tracer = AcquireTracer()
        tracer.Color = Settings.Visuals.TracerColor
        tracer.Thickness = Settings.Visuals.TracerThickness
        tracer.Transparency = 0
        tracer.Visible = true

        table_insert(Vars.ActiveTracers, {
            tracer = tracer,
            fromPos = fromPos,
            toPos = toPos,
            startTime = os_clock(),
            lifetime = Settings.Visuals.TracerLifetime,
        })
    end
    Vars.CreateTracer = CreateTracer

    local function UpdateTracers()
        if Vars.isScriptUnloaded then return end

        local cam = GetCamera()
        if not cam then return end

        local now = os_clock()
        local i = 1

        while i <= #Vars.ActiveTracers do
            local data = Vars.ActiveTracers[i]
            local age = now - data.startTime

            if age >= data.lifetime then
                ReleaseTracer(data.tracer)
                table_remove(Vars.ActiveTracers, i)
            else
                local v1, onScreen1 = cam:WorldToViewportPoint(data.fromPos)
                local v2, onScreen2 = cam:WorldToViewportPoint(data.toPos)

                -- ✅ Mostrar si al menos uno está en pantalla (Grok)
                if onScreen1 or onScreen2 then
                    data.tracer.From = V2(v1.X, v1.Y)
                    data.tracer.To = V2(v2.X, v2.Y)
                    data.tracer.Transparency = age / data.lifetime
                    data.tracer.Visible = true
                else
                    data.tracer.Visible = false
                end
                i = i + 1
            end
        end
    end

    local function StartTracerLoop()
        if Vars.tracerLoopConn then return end
        Vars.tracerLoopConn = RunService.RenderStepped:Connect(UpdateTracers)
    end
    Vars.StartTracerLoop = StartTracerLoop

    local function StopTracerLoop()
        if Vars.tracerLoopConn then
            pcall(function() Vars.tracerLoopConn:Disconnect() end)
            Vars.tracerLoopConn = nil
        end
        for _, data in ipairs(Vars.ActiveTracers) do
            ReleaseTracer(data.tracer)
        end
        table_clear(Vars.ActiveTracers)
    end
    Vars.StopTracerLoop = StopTracerLoop

    local function ClearAllTracers()
        for _, data in ipairs(Vars.ActiveTracers) do
            ReleaseTracer(data.tracer)
        end
        table_clear(Vars.ActiveTracers)

        for _, t in ipairs(Vars.TracerPool) do
            pcall(function() t:Remove() end)
        end
        table_clear(Vars.TracerPool)
    end
    Vars.ClearAllTracers = ClearAllTracers

    StartTracerLoop()

    -- ============================================================
    -- No Recoil (UNIFICADO en un solo Heartbeat)
    -- ============================================================
    local noRecoilCache = {}

    local function RebuildNoRecoilCache()
        noRecoilCache = {}
        local function scan(tool)
            if not tool:IsA("Tool") then return end
            local af = tool:FindFirstChild("AttachmentFolder")
            if not af then return end
            for _, a in ipairs(af:GetChildren()) do
                local ia = a:FindFirstChild("IsAttachment")
                if ia and ia:IsA("StringValue") and ia.Value == "Sights" then
                    local stats = a:FindFirstChild("Stats")
                    if stats then
                        for _, name in ipairs({
                            "GunRecoil","GunRecoilX","GunRecoilAimed",
                            "RecoilAngle","RecoilSpread","RecoilStrength",
                            "AimSway","AimSpeed","AimScatterMultiplyer"
                        }) do
                            local s = stats:FindFirstChild(name)
                            if s and s:IsA("NumberValue") then table_insert(noRecoilCache, s) end
                        end
                    end
                end
            end
        end
        if LP.Character then
            for _, t in ipairs(LP.Character:GetChildren()) do scan(t) end
        end
        if LP.Backpack then
            for _, t in ipairs(LP.Backpack:GetChildren()) do scan(t) end
        end
    end

    local function NoRecoilTick()
        if not Vars.noRecoilRunning then return end
        pcall(function()
            local r = LP:FindFirstChild("Recoil")
            if r then
                for _, c in ipairs(r:GetDescendants()) do
                    if c:IsA("CFrameValue") then c.Value = CFrame.new()
                    elseif c:IsA("NumberValue") then c.Value = 0 end
                end
                local a = r:FindFirstChild("CurrentRecoil")
                local b = r:FindFirstChild("CurrentRecoil2")
                local cc = r:FindFirstChild("CurrentRecoil3")
                if a and a:IsA("CFrameValue") then a.Value = CFrame.new() end
                if b and b:IsA("CFrameValue") then b.Value = CFrame.new() end
                if cc and cc:IsA("NumberValue") then cc.Value = 0 end
            end
            local char = LP.Character
            if char then
                local gav = char:FindFirstChild("GUNAIMVALUE")
                if gav then
                    for _, c in ipairs(gav:GetChildren()) do
                        if c:IsA("NumberValue") then c.Value = 0 end
                    end
                end
            end
            for _, s in ipairs(noRecoilCache) do
                if s and s.Parent then s.Value = 0 end
            end
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
                        if t.Animation then
                            local low = (t.Animation.Name or ""):lower()
                            if low:find("fire") or low:find("recoil") or low:find("aim") then
                                t:AdjustSpeed(999)
                            end
                        end
                    end
                end
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        for n, v in pairs({
                            GunRecoil=0, GunRecoilX=0, RecoilAngle=0,
                            RecoilSpread=0, RecoilStrength=0, AimSway=0
                        }) do
                            local e = tool:FindFirstChild(n)
                            if not e then
                                local nv = Instance.new("NumberValue")
                                nv.Name = n; nv.Value = v; nv.Parent = tool
                            else e.Value = v end
                        end
                    end
                end
                local function scanForSights(parent)
                    if not parent then return end
                    for _, ch in ipairs(parent:GetChildren()) do
                        if ch:IsA("Folder") and ch.Name == "AttachmentFolder" then
                            for _, a in ipairs(ch:GetChildren()) do
                                local ia = a:FindFirstChild("IsAttachment")
                                if ia and ia:IsA("StringValue") and ia.Value == "Sights" then
                                    local stats = a:FindFirstChild("Stats")
                                    if stats then
                                        for _, s in ipairs(stats:GetChildren()) do
                                            if s:IsA("NumberValue") then
                                                local nm = s.Name
                                                if nm:find("Recoil") or nm:find("Sway") or nm:find("Spread") or nm:find("Scatter") then
                                                    s.Value = 0
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        scanForSights(ch)
                    end
                end
                scanForSights(LP.Backpack)
                scanForSights(char)
            end
        end)
    end

    local function StartNoRecoil()
        if Vars.noRecoilRunning then return end
        Vars.noRecoilRunning = true
        RebuildNoRecoilCache()
        table_insert(Vars.noRecoilConnections, LP.CharacterAdded:Connect(RebuildNoRecoilCache))
        if LP.Backpack then
            table_insert(Vars.noRecoilConnections, LP.Backpack.ChildAdded:Connect(RebuildNoRecoilCache))
        end
        local conn = RunService.Heartbeat:Connect(NoRecoilTick)
        table_insert(Vars.noRecoilConnections, conn)
    end
    Vars.StartNoRecoil = StartNoRecoil

    local function StopNoRecoil()
        Vars.noRecoilRunning = false
        for _, c in ipairs(Vars.noRecoilConnections) do
            pcall(function() c:Disconnect() end)
        end
        Vars.noRecoilConnections = {}
    end
    Vars.StopNoRecoil = StopNoRecoil

    -- ============================================================
    -- X-Ray (mejorado - Grok: limpieza cada 30s)
    -- ============================================================
    local function StartXRay()
        if Vars.xrayThread then return end
        Vars.xrayActive = true
        Vars.xrayThread = task.spawn(function()
            local partList, lastRefresh = {}, 0
            local lastPartCleanup = 0
            while Vars.xrayActive do
                pcall(function()
                    local cam = GetCamera()
                    if not cam then return end
                    local camPos = cam.CFrame.Position
                    local camLook = cam.CFrame.LookVector
                    local now = os_clock()
                    if now - lastRefresh > 2 then
                        partList = {}
                        for _, part in ipairs(Vars.Workspace:GetDescendants()) do
                            if part:IsA("BasePart")
                                and part ~= cam
                                and (not LP.Character or not part:IsDescendantOf(LP.Character))
                                and part.Transparency < 0.9 and part.Parent
                            then
                                if Vars.originalTransparency[part] == nil then
                                    Vars.originalTransparency[part] = part.Transparency
                                end
                                table_insert(partList, part)
                            end
                        end
                        lastRefresh = now
                    end
                    for _, part in ipairs(partList) do
                        if not part.Parent then continue end
                        local orig = Vars.originalTransparency[part] or 0
                        local nl = part.Name:lower()
                        if string_find(nl, "floor") or string_find(nl, "ground")
                            or string_find(nl, "terrain")
                            or (part.Parent and part.Parent:IsA("Tool"))
                        then
                            part.Transparency = orig
                            continue
                        end
                        local dir = (part.Position - camPos)
                        if dir.Magnitude > 0.1 then
                            local dot = camLook:Dot(dir.Unit)
                            if dot > 0.3 then
                                part.Transparency = math.max(orig, 0.75)
                            else
                                part.Transparency = orig
                            end
                        end
                    end
                    if now - lastPartCleanup > 30 then
                        lastPartCleanup = now
                        for part in pairs(Vars.originalTransparency) do
                            if not part or not part.Parent then
                                Vars.originalTransparency[part] = nil
                            end
                        end
                    end
                end)
                task.wait(0.15)
            end
        end)
    end
    Vars.StartXRay = StartXRay

    local function StopXRay()
        Vars.xrayActive = false
        if Vars.xrayThread then task.cancel(Vars.xrayThread); Vars.xrayThread = nil end
        pcall(function()
            for part, t in pairs(Vars.originalTransparency) do
                if part and part.Parent then part.Transparency = t end
            end
            Vars.originalTransparency = {}
        end)
    end
    Vars.StopXRay = StopXRay
end

-- ============================================================
-- BLOQUE 7: Target Manager + Aimbot (con FOV Selectivo) + Aim Assist
-- ============================================================
do
    local RunService = Vars.RunService
    local UserInputService = Vars.UserInputService
    local LP = Vars.LP
    local Settings = Vars.Settings
    local V2 = Vars.Vector2_new
    local V3 = Vars.Vector3_new
    local CFrame_new = Vars.CFrame_new
    local math_clamp = Vars.math_clamp
    local math_rad = Vars.math_rad
    local math_tan = Vars.math_tan
    local table_insert = Vars.table_insert
    local os_clock = Vars.os_clock

    local function GetCamera() return Vars.GetCamera() end
    local function IsMenuOpen() return Vars.IsMenuOpen() end
    local function CheckVisibility(p) return Vars.CheckVisibility(p) end
    local function IsPassive(n) return Vars.IsPassive(n) end
    local function GetRigType(c) return Vars.GetRigType(c) end
    local function hasGunScript(c) return Vars.hasGunScript(c) end
    local function PredictPosition(p, a, ping) return Vars.PredictPosition(p, a, ping) end
    local function GetSelectiveBodyPart(p, sp, c, r) return Vars.GetSelectiveBodyPart(p, sp, c, r) end
    local function GetHybridBodyPart(p, sp, c, r) return Vars.GetHybridBodyPart(p, sp, c, r) end
    local function GetBestBodyPartByPriority(p, cam) return Vars.GetBestBodyPartByPriority(p, cam) end
    local function GetBacktrackPosition(name, delay) return Vars.GetBacktrackPosition(name, delay) end

    local BODY_PARTS = {
        "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    }
    local BODY_PARTS_R6 = {
        "Head", "Torso", "HumanoidRootPart",
        "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    }

    local function IsDeadBlacklisted(playerName)
        local expiry = Vars.deadBlacklist[playerName]
        if not expiry then return false end
        if os_clock() > expiry then
            Vars.deadBlacklist[playerName] = nil
            return false
        end
        return true
    end
    Vars.IsDeadBlacklisted = IsDeadBlacklisted

    local function AddToDeadBlacklist(playerName)
        Vars.deadBlacklist[playerName] = os_clock() + Vars.DEAD_BLACKLIST_DURATION
    end
    Vars.AddToDeadBlacklist = AddToDeadBlacklist

    local function IsWhitelisted(player)
        if not player then return false end
        return Vars.whitelist[player.UserId] == true
    end
    Vars.IsWhitelisted = IsWhitelisted

    local function GetNearestBodyPart(player)
        if not player or not player.Character then return nil end
        local char = player.Character
        local cam = GetCamera()
        if not cam then return nil end
        local centerX = cam.ViewportSize.X / 2
        local centerY = cam.ViewportSize.Y / 2
        local centerVec = V2(centerX, centerY)
        local best, bestDist = nil, math.huge
        local rigType = GetRigType(char)
        local partList = rigType == "R15" and BODY_PARTS or BODY_PARTS_R6
        for _, partName in ipairs(partList) do
            local part = char:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local screenPos = V2(pos.X, pos.Y)
                    local dist = (screenPos - centerVec).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = part
                    end
                end
            end
        end
        return best
    end
    Vars.GetNearestBodyPart = GetNearestBodyPart

    -- ============================================================
    -- Target Manager
    -- ============================================================
    local TargetManager = {}
    local currentTarget = nil

    local function ComputeFOVRadius(cam, fovDegrees)
        if not cam then return 100 end
        local gf = cam.FieldOfView or 70
        local half = cam.ViewportSize.X / 2
        return half * math_tan(math_rad(fovDegrees / 2)) / math_tan(math_rad(gf / 2))
    end
    Vars.ComputeFOVRadius = ComputeFOVRadius

    local function ResolveAimPart(player, cam, fovCenter, fovRadius)
        local char = player.Character
        if not char then return nil end
        local mode = Settings.Aimbot.AimPartMode

        if mode == "Auto (Nearest to Crosshair)" then
            return GetNearestBodyPart(player)
        elseif mode == "Selective FOV" then
            local sp = Vars.helperMousePosition
            local part = GetSelectiveBodyPart(player, sp, fovCenter, fovRadius)
            Vars.currentSelectivePartName = part and part.Name or nil
            return part
        elseif mode == "Hybrid" then
            local sp = Vars.helperMousePosition
            local part = GetHybridBodyPart(player, sp, fovCenter, fovRadius)
            Vars.currentHybridPartName = part and part.Name or nil
            return part
        elseif mode == "Head" then
            return char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        elseif mode == "Torso" then
            return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
        else
            local part = char:FindFirstChild(mode)
            if not part then
                part = char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            end
            return part
        end
    end
    Vars.ResolveAimPart = ResolveAimPart

    function TargetManager:GetCandidates()
        local candidates = {}
        if not LP.Character then return candidates end
        local lr = LP.Character:FindFirstChild("HumanoidRootPart")
        if not lr then return candidates end
        local cam = GetCamera()
        if not cam then return candidates end
        local fovCenter = Vars.helperMousePosition
        local fovRadius = ComputeFOVRadius(cam, Settings.Aimbot.FOV)

        for _, player in ipairs(Vars.activePlayers) do
            if IsWhitelisted(player) then continue end
            if IsDeadBlacklisted(player.Name) then continue end
            if not self:ValidateTarget(player) then continue end
            if Settings.Aimbot.TeamCheck and player.Team == LP.Team then continue end
            if Settings.Aimbot.IgnorePassive and IsPassive(player.Name) then continue end
            local tr = player.Character.HumanoidRootPart
            local dist = (lr.Position - tr.Position).Magnitude
            if Settings.Aimbot.MaxDistance > 0 and dist > Settings.Aimbot.MaxDistance then continue end
            if Settings.Aimbot.WallCheck then
                local vis = CheckVisibility(player)
                if Settings.Aimbot.StrictWallCheck and vis ~= "visible" then continue end
                if vis == "hidden" then continue end
            end

            local aimPart = ResolveAimPart(player, cam, fovCenter, fovRadius)
            if not aimPart then continue end

            local tp = aimPart.Position

            if Settings.Backtrack.Enabled then
                local bp = GetBacktrackPosition(player.Name, Settings.Backtrack.Delay)
                if bp then tp = bp end
            end

            if Settings.Aimbot.UsePrediction then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    tp = PredictPosition(root, Settings.Aimbot.PredictionAmount, Settings.Aimbot.UsePingPrediction)
                end
            end

            local sp, onScreen = cam:WorldToViewportPoint(tp)
            if not onScreen then continue end
            local dc = (V2(sp.X, sp.Y) - fovCenter).Magnitude
            if dc > fovRadius then continue end
            if Settings.Aimbot.Anti360.Enabled and Vars.anti360Active and Vars.currentTargetForAnti360 == player then
                continue
            end
            table_insert(candidates, {
                player = player, part = aimPart, targetPos = tp,
                distance = dist, screenDist = dc, screenPos = sp,
                aimPartName = aimPart.Name,
            })
        end
        return candidates
    end

    function TargetManager:ValidateTarget(player)
        if not player or player == LP then return false end
        if IsDeadBlacklisted(player.Name) then return false end
        if not player.Character then return false end
        local char = player.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        if hum.Health <= 0 then
            AddToDeadBlacklist(player.Name)
            return false
        end
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Dead
            or state == Enum.HumanoidStateType.Dying
            or state == Enum.HumanoidStateType.Physics then
            AddToDeadBlacklist(player.Name)
            return false
        end
        if not char.Parent or char.Parent ~= Vars.Workspace then
            AddToDeadBlacklist(player.Name)
            return false
        end
        if not char:FindFirstChild("HumanoidRootPart") then
            AddToDeadBlacklist(player.Name)
            return false
        end
        if not char:FindFirstChild("Head") then
            AddToDeadBlacklist(player.Name)
            return false
        end
        return true
    end

    function TargetManager:GetBestTarget()
        local c = self:GetCandidates()
        if #c == 0 then
            self:ClearTarget()
            Vars.targetTransition.active = false
            Vars.targetTransition.previousPlayer = nil
            return nil
        end
        local pr = Settings.Aimbot.Priority or "Distance"
        local best, bs = nil, math.huge
        for _, x in ipairs(c) do
            local s
            if pr == "Distance" then
                s = x.distance
            elseif pr == "FOV" then
                s = x.screenDist
            elseif pr == "Priority" then
                local prio = Settings.Aimbot.BonePriority[x.aimPartName] or 0.5
                s = x.screenDist / math.max(prio, 0.01)
            else
                s = x.distance
            end
            if s < bs then bs = s; best = x end
        end
        return best
    end

    function TargetManager:LockTarget(t)
        if not t then self:ClearTarget(); return end
        if currentTarget and currentTarget.player == t.player then return end
        if currentTarget and currentTarget.player and currentTarget.part
            and t.part and t.part.Parent then
            local cam = GetCamera()
            Vars.targetTransition.active = true
            Vars.targetTransition.startCFrame = cam.CFrame
            Vars.targetTransition.targetCFrame = CFrame_new(cam.CFrame.Position, t.part.Position)
            Vars.targetTransition.progress = 0
            Vars.targetTransition.previousPlayer = currentTarget.player
        end
        currentTarget = t
    end

    function TargetManager:UpdateTarget()
        if not currentTarget or not currentTarget.player then self:ClearTarget(); return end
        if not self:ValidateTarget(currentTarget.player) then self:ClearTarget(); return end
        if IsWhitelisted(currentTarget.player) then self:ClearTarget(); return end
        local lr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not lr then self:ClearTarget(); return end
        local d = (currentTarget.player.Character.HumanoidRootPart.Position - lr.Position).Magnitude
        if Settings.Aimbot.MaxDistance > 0 and d > Settings.Aimbot.MaxDistance then
            self:ClearTarget(); return
        end
        local cam = GetCamera()
        local fovCenter = Vars.helperMousePosition
        local fovRadius = ComputeFOVRadius(cam, Settings.Aimbot.FOV)
        local aimPart = ResolveAimPart(currentTarget.player, cam, fovCenter, fovRadius)
        if not aimPart then self:ClearTarget(); return end
        currentTarget.part = aimPart
        currentTarget.targetPos = aimPart.Position
        currentTarget.aimPartName = aimPart.Name
    end

    function TargetManager:ClearTarget()
        currentTarget = nil
        Vars.currentSelectivePartName = nil
        Vars.currentHybridPartName = nil
    end
    function TargetManager:GetCurrentTarget() return currentTarget end

    function TargetManager:AddToWhitelist(player)
        if Vars.whitelist[player.UserId] then
            Vars.whitelist[player.UserId] = nil
        else
            Vars.whitelist[player.UserId] = true
        end
        if currentTarget and currentTarget.player == player then self:ClearTarget() end
    end

    function TargetManager:IsWhitelisted(player)
        return IsWhitelisted(player)
    end

    Vars.TargetManager = TargetManager

    -- ============================================================
    -- Anti-360
    -- ============================================================
    local function CheckAnti360()
        if not Settings.Aimbot.Anti360.Enabled then
            Vars.anti360Active = false
            Vars.currentTargetForAnti360 = nil
            Vars.anti360Cooldown = 0
            return false
        end
        local now = os_clock()
        if Vars.anti360Active and now < Vars.anti360Cooldown then
            return true
        end
        local lr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not lr then
            Vars.anti360Active = false
            Vars.currentTargetForAnti360 = nil
            return false
        end
        local closest, cd = nil, Settings.Aimbot.Anti360.DetectionDistance + Settings.Aimbot.Anti360.Hysteresis
        for _, p in ipairs(Vars.activePlayers) do
            if not TargetManager:ValidateTarget(p) then continue end
            if Settings.Aimbot.TeamCheck and p.Team == LP.Team then continue end
            if Settings.Aimbot.IgnorePassive and IsPassive(p.Name) then continue end
            local d = (p.Character.HumanoidRootPart.Position - lr.Position).Magnitude
            if d < cd then cd = d; closest = p end
        end
        if not closest then
            Vars.anti360Active = false
            Vars.currentTargetForAnti360 = nil
            return false
        end
        local vel = closest.Character.HumanoidRootPart.AssemblyLinearVelocity or V3(0,0,0)
        local lat = V3(vel.X, 0, vel.Z)
        if cd <= Settings.Aimbot.Anti360.DetectionDistance and lat.Magnitude > 3 then
            if not Vars.anti360Active then
                Vars.anti360Active = true
                Vars.currentTargetForAnti360 = closest
                Vars.anti360Cooldown = now + Settings.Aimbot.Anti360.ReEnableDelay
            end
            return true
        end
        if Vars.anti360Active then
            if cd > (Settings.Aimbot.Anti360.DetectionDistance + Settings.Aimbot.Anti360.Hysteresis) then
                Vars.anti360Active = false
                Vars.currentTargetForAnti360 = nil
                Vars.anti360Cooldown = now + Settings.Aimbot.Anti360.ReEnableDelay
                return false
            end
            return true
        end
        return false
    end
    Vars.CheckAnti360 = CheckAnti360

    -- ============================================================
    -- Main Aimbot Loop
    -- ============================================================
    local lastFrameTime = 0
    local function MainAimbotLoop()
        if Vars.isScriptUnloaded or not Settings.Aimbot.Enabled then return end
        if Vars.isLocalDead or IsMenuOpen() then return end
        if type(isrbxactive) == "function" and not isrbxactive() then return end
        if Settings.Aimbot.RequireGun then
            if not hasGunScript(LP.Character) then
                TargetManager:ClearTarget()
                Vars.targetTransition.active = false
                return
            end
        end

        Vars.helperMousePosition = UserInputService:GetMouseLocation()

        local now = os_clock()
        local dt = now - lastFrameTime
        lastFrameTime = now
        if dt > 0.5 then dt = 0.5 end

        local held
        if Settings.Aimbot.AimKeyType == "Key" then held = Vars.aimKeyHeld
        else held = UserInputService:IsMouseButtonPressed(Settings.Aimbot.AimMouseButton) end
        if not held then
            Vars.targetTransition.active = false
            return
        end

        if Vars.CheckAnti360() then
            TargetManager:ClearTarget()
            Vars.targetTransition.active = false
            return
        end

        if Settings.Aimbot.StickyLock and TargetManager:GetCurrentTarget() then
            local ct = TargetManager:GetCurrentTarget()
            local stillValid = TargetManager:ValidateTarget(ct.player)
            if stillValid then
                Vars.stickyTarget = ct.player
                Vars.stickyLastSeen = now
            else
                if (now - Vars.stickyLastSeen) > Settings.Aimbot.StickyTimeout then
                    TargetManager:ClearTarget()
                    Vars.stickyTarget = nil
                end
            end
        elseif not Settings.Aimbot.StickyLock then
            Vars.stickyTarget = nil
        end

        TargetManager:UpdateTarget()

        if Settings.Aimbot.StickyLock and Vars.stickyTarget and Vars.stickyTarget.Character then
            local stHum = Vars.stickyTarget.Character:FindFirstChildOfClass("Humanoid")
            if stHum and stHum.Health > 0 then
                local cam = GetCamera()
                local fovCenter = Vars.helperMousePosition
                local fovRadius = ComputeFOVRadius(cam, Settings.Aimbot.FOV)
                local stPart = ResolveAimPart(Vars.stickyTarget, cam, fovCenter, fovRadius)
                if stPart then
                    TargetManager:LockTarget({
                        player = Vars.stickyTarget, part = stPart, targetPos = stPart.Position,
                        distance = 0, screenDist = 0, screenPos = V2(0, 0),
                        aimPartName = stPart.Name,
                    })
                end
            end
        end

        local ct = TargetManager:GetCurrentTarget()
        if ct and ct.player ~= Vars.targetTransition.previousPlayer then
            local aimPos = ct.part and ct.part.Position or nil
            if aimPos then
                local cam = GetCamera()
                Vars.targetTransition.active = true
                Vars.targetTransition.startCFrame = cam.CFrame
                Vars.targetTransition.targetCFrame = CFrame_new(cam.CFrame.Position, aimPos)
                Vars.targetTransition.progress = 0
                Vars.targetTransition.duration = Vars.TARGET_TRANSITION_DURATION
                Vars.targetTransition.previousPlayer = ct.player
            end
        elseif not ct then
            Vars.targetTransition.previousPlayer = nil
        end

        if not TargetManager:GetCurrentTarget() then
            local nt = TargetManager:GetBestTarget()
            if nt then
                TargetManager:LockTarget(nt)
                local cam = GetCamera()
                Vars.targetTransition.active = true
                Vars.targetTransition.startCFrame = cam.CFrame
                Vars.targetTransition.targetCFrame = CFrame_new(cam.CFrame.Position, nt.part.Position)
                Vars.targetTransition.progress = 0
                Vars.targetTransition.duration = Vars.TARGET_TRANSITION_DURATION
                Vars.targetTransition.previousPlayer = nt.player
            end
        end

        local t = TargetManager:GetCurrentTarget()
        if not t then return end
        if Vars.CheckAnti360() then
            TargetManager:ClearTarget()
            Vars.targetTransition.active = false
            return
        end
        local ap = t.part
        if not ap or not ap.Parent then
            TargetManager:ClearTarget()
            return
        end

        if Vars.targetTransition.active then
            Vars.targetTransition.progress = Vars.targetTransition.progress + (dt / Vars.targetTransition.duration)
            if Vars.targetTransition.progress >= 1 then
                Vars.targetTransition.progress = 1
                Vars.targetTransition.active = false
            end
            local cam = GetCamera()
            local eased = 1 - (1 - Vars.targetTransition.progress) ^ 3
            local newTargetCF = CFrame_new(cam.CFrame.Position, ap.Position)
            Vars.targetTransition.targetCFrame = newTargetCF
            pcall(function()
                cam.CFrame = Vars.targetTransition.startCFrame:Lerp(Vars.targetTransition.targetCFrame, eased)
            end)
            return
        end

        local aimPos = ap.Position
        if Settings.Backtrack.Enabled then
            local bp = GetBacktrackPosition(t.player.Name, Settings.Backtrack.Delay)
            if bp then aimPos = bp end
        end
        if Settings.Aimbot.UsePrediction then
            local root = t.player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                aimPos = PredictPosition(root, Settings.Aimbot.PredictionAmount, Settings.Aimbot.UsePingPrediction)
            end
        end

        local sm = Vars.aimbotHelperActive and Settings.Aimbot.HelperSmoothness or Settings.Aimbot.BaseSmoothness
        local lr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if Settings.Aimbot.Anti360.Enabled and lr then
            for _, p in ipairs(Vars.activePlayers) do
                if p ~= LP and p.Character then
                    local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
                    if pRoot then
                        local d = (pRoot.Position - lr.Position).Magnitude
                        if d <= Settings.Aimbot.Anti360.DetectionDistance then
                            sm = 1
                            break
                        end
                    end
                end
            end
        end

        local cam = GetCamera()
        if Settings.Aimbot.Method == "Camera" then
            if sm >= 1 then return
            elseif sm <= 0 then
                pcall(function() cam.CFrame = CFrame_new(cam.CFrame.Position, aimPos) end)
            else
                pcall(function()
                    local tcf = CFrame_new(cam.CFrame.Position, aimPos)
                    local f = math_clamp(1 - sm, 0.01, 1)
                    cam.CFrame = cam.CFrame:Lerp(tcf, f)
                end)
            end
        else
            local sp = cam:WorldToViewportPoint(aimPos)
            local d = V2(sp.X - Vars.helperMousePosition.X, sp.Y - Vars.helperMousePosition.Y)
            if d.Magnitude > 0.5 then
                if sm >= 1 then return
                elseif sm <= 0 then mousemoverel(d.X, d.Y)
                else
                    local f = math_clamp(1 - sm, 0.01, 1)
                    mousemoverel(d.X * f, d.Y * f)
                end
            end
        end
    end

    Vars.aimbotConn = RunService.RenderStepped:Connect(MainAimbotLoop)

    -- ============================================================
    -- FOV Circle del Aimbot
    -- ============================================================
    local fovCircle = nil
    Vars.fovConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
            fovCircle.Filled = false
            fovCircle.Visible = false
        end
        fovCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled and not IsMenuOpen()
        if fovCircle.Visible then
            local cam = GetCamera()
            local r = ComputeFOVRadius(cam, Settings.Aimbot.FOV)
            local mp = UserInputService:GetMouseLocation()
            fovCircle.Position = V2(mp.X, mp.Y)
            fovCircle.Radius = r
            fovCircle.Color = Settings.Aimbot.FOVColor
            fovCircle.Thickness = Settings.Aimbot.FOVThickness
        end
    end)
    Vars.GetFOVCircle = function() return fovCircle end

    -- ============================================================
    -- Indicador de target
    -- ============================================================
    local targetIndicator = nil
    Vars.targetIndicatorConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        if not Settings.Aimbot.Enabled then
            if targetIndicator then targetIndicator.Visible = false end
            return
        end
        if not targetIndicator then
            targetIndicator = Drawing.new("Circle")
            targetIndicator.Filled = false
            targetIndicator.Thickness = 2
            targetIndicator.Color = Color3.fromRGB(255, 0, 0)
            targetIndicator.Visible = false
        end
        local t = TargetManager:GetCurrentTarget()
        if t and t.part and t.part.Parent then
            local sp, onScreen = GetCamera():WorldToViewportPoint(t.part.Position)
            if onScreen then
                targetIndicator.Position = V2(sp.X, sp.Y)
                targetIndicator.Radius = 10
                targetIndicator.Visible = true
            else targetIndicator.Visible = false end
        else targetIndicator.Visible = false end
    end)
    Vars.GetTargetIndicator = function() return targetIndicator end

    -- ============================================================
    -- Hotkeys configurables
    -- ============================================================
    Vars.aimKeyBeganConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Settings.Hotkeys.Helper then
            Vars.aimbotHelperActive = not Vars.aimbotHelperActive
            if _env.TownUI_Window and _env.TownUI_Window.Notify then
                pcall(function()
                    _env.TownUI_Window:Notify("Helper",
                        Vars.aimbotHelperActive and "Aim: Helper mode" or "Aim: Base mode",
                        1.5, "Info")
                end)
            end
        end
        if input.KeyCode == Settings.Aimbot.AimKey then Vars.aimKeyHeld = true end
    end)

    Vars.aimKeyEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Settings.Aimbot.AimKey then Vars.aimKeyHeld = false end
    end)

    -- ============================================================
    -- AIM ASSIST
    -- ============================================================
    local function GetAimAssistTarget()
        if not LP.Character then return nil end
        local lr = LP.Character:FindFirstChild("HumanoidRootPart")
        if not lr then return nil end
        local cam = GetCamera()
        if not cam then return nil end
        local center = Vars.helperMousePosition
        local radius = ComputeFOVRadius(cam, Settings.AimAssist.FOV)
        local best, bestScore = nil, math.huge
        for _, player in ipairs(Vars.activePlayers) do
            if not player or player == LP then continue end
            if IsWhitelisted(player) then continue end
            if IsDeadBlacklisted(player.Name) then continue end
            if not player.Character then continue end
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            if Settings.AimAssist.TeamCheck and player.Team == LP.Team then continue end
            if Settings.AimAssist.IgnorePassive and IsPassive(player.Name) then continue end

            local part
            if Settings.AimAssist.Selective then
                part = ResolveAimPart(player, cam, center, radius)
            else
                part = player.Character:FindFirstChild(Settings.AimAssist.AimPart)
                if not part then
                    part = player.Character:FindFirstChild("Head")
                        or player.Character:FindFirstChild("HumanoidRootPart")
                end
            end
            if not part then continue end

            local tr = player.Character:FindFirstChild("HumanoidRootPart")
            if not tr then continue end
            local dist = (lr.Position - tr.Position).Magnitude
            if Settings.AimAssist.MaxDistance > 0 and dist > Settings.AimAssist.MaxDistance then continue end
            if Settings.AimAssist.WallCheck then
                local vis = CheckVisibility(player)
                if Settings.AimAssist.Visible and vis ~= "visible" then continue end
                if not Settings.AimAssist.Visible and vis == "hidden" then continue end
            end

            local targetPos = part.Position
            if Settings.AimAssist.UsePrediction then
                targetPos = PredictPosition(tr, Settings.AimAssist.PredictionAmount, Settings.AimAssist.UsePingPrediction)
            end
            if Settings.Backtrack.Enabled then
                local bp = GetBacktrackPosition(player.Name, Settings.Backtrack.Delay)
                if bp then targetPos = bp end
            end

            local sp, onScreen = cam:WorldToViewportPoint(targetPos)
            if not onScreen then continue end
            local dc = (V2(sp.X, sp.Y) - center).Magnitude
            if dc > radius then continue end

            local score = (Settings.AimAssist.Priority == "Distance") and dist or dc
            if score < bestScore then
                bestScore = score
                best = { player = player, part = part, targetPos = targetPos,
                         distance = dist, screenDist = dc, screenPos = sp }
            end
        end
        return best
    end

    local function AimAssistLoop()
        if Vars.isScriptUnloaded or not Settings.AimAssist.Enabled then return end
        if Vars.isLocalDead or IsMenuOpen() then return end
        if type(isrbxactive) == "function" and not isrbxactive() then return end

        Vars.helperMousePosition = UserInputService:GetMouseLocation()

        local now = os_clock()
        local dt = now - Vars.aimAssistLastFrame
        Vars.aimAssistLastFrame = now
        if dt > 0.5 then dt = 0.5 end

        local target = GetAimAssistTarget()
        if not target then return end
        local aimPos = target.targetPos
        local sm = Settings.AimAssist.Smoothness
        local cam = GetCamera()

        if Settings.AimAssist.UseMouse then
            local sp = cam:WorldToViewportPoint(aimPos)
            local d = V2(sp.X - Vars.helperMousePosition.X, sp.Y - Vars.helperMousePosition.Y)
            if d.Magnitude > 0.5 then
                if sm <= 0 then mousemoverel(d.X, d.Y)
                else
                    local f = math_clamp(1 - sm, 0.01, 1)
                    mousemoverel(d.X * f, d.Y * f)
                end
            end
        else
            if sm <= 0 then
                pcall(function() cam.CFrame = CFrame_new(cam.CFrame.Position, aimPos) end)
            else
                pcall(function()
                    local tcf = CFrame_new(cam.CFrame.Position, aimPos)
                    local f = math_clamp(1 - sm, 0.01, 1)
                    cam.CFrame = cam.CFrame:Lerp(tcf, f)
                end)
            end
        end
    end

    local function StartAimAssist()
        if Vars.aimAssistConnection then return end
        Vars.aimAssistActive = true
        Vars.aimAssistLastFrame = os_clock()
        Vars.aimAssistConnection = RunService.RenderStepped:Connect(AimAssistLoop)
        if not Vars.aimAssistFOVCircle then
            Vars.aimAssistFOVCircle = Drawing.new("Circle")
            Vars.aimAssistFOVCircle.Filled = false
            Vars.aimAssistFOVCircle.Visible = false
        end
        if not Vars.aimAssistFOVConn then
            Vars.aimAssistFOVConn = RunService.RenderStepped:Connect(function()
                if Vars.isScriptUnloaded then return end
                if not Vars.aimAssistFOVCircle then return end
                Vars.aimAssistFOVCircle.Visible = Settings.AimAssist.ShowFOV
                    and Settings.AimAssist.Enabled and not IsMenuOpen()
                if Vars.aimAssistFOVCircle.Visible then
                    local cam = GetCamera()
                    local r = ComputeFOVRadius(cam, Settings.AimAssist.FOV)
                    local mp = UserInputService:GetMouseLocation()
                    Vars.aimAssistFOVCircle.Position = V2(mp.X, mp.Y)
                    Vars.aimAssistFOVCircle.Radius = r
                    Vars.aimAssistFOVCircle.Color = Settings.AimAssist.FOVColor
                    Vars.aimAssistFOVCircle.Thickness = Settings.AimAssist.FOVThickness
                end
            end)
        end
    end
    Vars.StartAimAssist = StartAimAssist

    local function StopAimAssist()
        Vars.aimAssistActive = false
        if Vars.aimAssistConnection then
            pcall(function() Vars.aimAssistConnection:Disconnect() end)
            Vars.aimAssistConnection = nil
        end
        if Vars.aimAssistFOVConn then
            pcall(function() Vars.aimAssistFOVConn:Disconnect() end)
            Vars.aimAssistFOVConn = nil
        end
        if Vars.aimAssistFOVCircle then
            pcall(function() Vars.aimAssistFOVCircle:Remove() end)
            Vars.aimAssistFOVCircle = nil
        end
    end
    Vars.StopAimAssist = StopAimAssist
end

-- ============================================================
-- BLOQUE 8: Sync Booster + Anti-Fall + Strafe HvH + Exploit
-- ============================================================
do
    local Players = Vars.Players
    local RunService = Vars.RunService
    local UserInputService = Vars.UserInputService
    local LP = Vars.LP
    local Settings = Vars.Settings
    local V2 = Vars.Vector2_new
    local V3 = Vars.Vector3_new
    local CFrame_new = Vars.CFrame_new
    local math_rad = Vars.math_rad
    local table_insert = Vars.table_insert
    local os_clock = Vars.os_clock

    local function SafeSetFPS(cap)
        if type(setfpscap) == "function" then pcall(function() setfpscap(cap) end) end
    end
    local function GetCurrentFPS()
        if type(getfpscap) == "function" then return getfpscap() end
        return 0
    end
    local function GetCurrentSimRadius()
        if type(gethiddenproperty) == "function" then
            local ok, current = pcall(gethiddenproperty, LP, "SimulationRadius")
            if ok then return current end
        end
        return nil
    end
    Vars.GetCurrentFPS = GetCurrentFPS
    Vars.GetCurrentSimRadius = GetCurrentSimRadius

    local SYNC_RADIUS_BOOSTED = 400
    local SYNC_RADIUS_BOOSTED_MAX = 400
    local SYNC_RADIUS_DEFAULT = 100
    local SYNC_RADIUS_DEFAULT_MAX = 100
    local SYNC_FPS_CAP_WHEN_ON = 60
    local SYNC_FPS_CAP_WHEN_OFF = 0
    local SYNC_LOW_FPS_THRESHOLD = 30
    local SYNC_LOW_FPS_TICKS = 60

    local syncData = {
        enabled = false, connection = nil, lastUpdate = 0,
        UPDATE_INTERVAL = 0.05, originalFPSCap = nil,
        radiusResetCount = 0, lowFPSCount = 0, fflagFallbackTried = false,
    }

    local function ApplySimulationRadius(radius, maxRadius, force)
        if not force then
            local current = GetCurrentSimRadius()
            if current and current >= radius then return end
            syncData.radiusResetCount = syncData.radiusResetCount + 1
        end
        if type(setsimulationradius) == "function" then
            pcall(setsimulationradius, radius, maxRadius)
        end
        if type(sethiddenproperty) == "function" then
            pcall(sethiddenproperty, LP, "SimulationRadius", radius)
            pcall(sethiddenproperty, LP, "MaxSimulationRadius", maxRadius)
        end
    end

    local function TryFFlagFallback()
        if syncData.fflagFallbackTried then return end
        syncData.fflagFallbackTried = true
        if not Settings.Sync.TryFFlagFallback then return end
        if type(setfflag) ~= "function" then return end
        pcall(setfflag, "DFIntS2PhysicsSenderRate", 60)
    end

    local function SyncTick()
        if not syncData.enabled then return end
        ApplySimulationRadius(SYNC_RADIUS_BOOSTED, SYNC_RADIUS_BOOSTED_MAX, false)
    end

    local function StartSyncBooster()
        if syncData.enabled then return end
        syncData.enabled = true
        if syncData.originalFPSCap == nil then
            syncData.originalFPSCap = GetCurrentFPS()
        end
        ApplySimulationRadius(SYNC_RADIUS_BOOSTED, SYNC_RADIUS_BOOSTED_MAX, true)
        SafeSetFPS(SYNC_FPS_CAP_WHEN_ON)
        TryFFlagFallback()
        if syncData.connection then
            pcall(function() syncData.connection:Disconnect() end)
            syncData.connection = nil
        end
        syncData.lastUpdate = 0
        syncData.lowFPSCount = 0
        syncData.radiusResetCount = 0
        syncData.connection = RunService.Heartbeat:Connect(function()
            if not syncData.enabled then return end
            local now = os_clock()
            if (now - syncData.lastUpdate) < syncData.UPDATE_INTERVAL then return end
            syncData.lastUpdate = now
            if #Players:GetPlayers() < 2 then return end
            SyncTick()
            if Settings.Sync.AutoDisableOnLowFPS then
                local fps = GetCurrentFPS()
                if fps > 0 and fps < SYNC_LOW_FPS_THRESHOLD then
                    syncData.lowFPSCount = syncData.lowFPSCount + 1
                    if syncData.lowFPSCount >= SYNC_LOW_FPS_TICKS then
                        syncData.lowFPSCount = 0
                        StopSyncBooster()
                    end
                else
                    syncData.lowFPSCount = 0
                end
            end
        end)
    end
    Vars.StartSyncBooster = StartSyncBooster

    local function StopSyncBooster()
        if not syncData.enabled then return end
        syncData.enabled = false
        if syncData.connection then
            pcall(function() syncData.connection:Disconnect() end)
            syncData.connection = nil
        end
        syncData.lastUpdate = 0
        syncData.lowFPSCount = 0
        ApplySimulationRadius(SYNC_RADIUS_DEFAULT, SYNC_RADIUS_DEFAULT_MAX, true)
        if syncData.originalFPSCap ~= nil then
            SafeSetFPS(syncData.originalFPSCap)
            syncData.originalFPSCap = nil
        else
            SafeSetFPS(SYNC_FPS_CAP_WHEN_OFF)
        end
    end
    Vars.StopSyncBooster = StopSyncBooster

    Vars.syncCharConn = LP.CharacterAdded:Connect(function()
        if syncData.enabled then
            task.wait(0.5)
            if syncData.enabled then
                ApplySimulationRadius(SYNC_RADIUS_BOOSTED, SYNC_RADIUS_BOOSTED_MAX, true)
            end
        end
    end)

    -- ============================================================
    -- Anti-Fall
    -- ============================================================
    local function StartAntiFall()
        if Vars.antiFallRunning then return end
        Vars.antiFallRunning = true
        local function setupChar(char)
            local hum = char:WaitForChild("Humanoid", 5)
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            if not hum or not hrp then return end
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            local stateConn = hum.StateChanged:Connect(function(_, newState)
                if newState == Enum.HumanoidStateType.Ragdoll then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {char}
            local startY = nil
            local heartbeatConn = RunService.Heartbeat:Connect(function()
                if not Vars.antiFallRunning then return end
                local r = char:FindFirstChild("HumanoidRootPart")
                local h = char:FindFirstChild("Humanoid")
                if not r or not h then return end
                if h.FloorMaterial ~= Enum.Material.Air then
                    startY = nil
                    return
                end
                if startY == nil then startY = r.Position.Y end
                if startY - r.Position.Y < 6.5 then return end
                local result = Vars.Workspace:Raycast(r.Position, V3(0, -300, 0), rayParams)
                if not result then return end
                r.AssemblyLinearVelocity = V3(0, 0, 0)
                startY = nil
            end)
            table_insert(Vars.antiFallCharConnections, stateConn)
            table_insert(Vars.antiFallCharConnections, heartbeatConn)
        end
        if LP.Character then setupChar(LP.Character) end
        Vars.antiFallConnection = LP.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            if Vars.antiFallRunning then setupChar(char) end
        end)
    end
    Vars.StartAntiFall = StartAntiFall

    local function StopAntiFall()
        Vars.antiFallRunning = false
        if Vars.antiFallConnection then
            Vars.antiFallConnection:Disconnect()
            Vars.antiFallConnection = nil
        end
        for _, conn in ipairs(Vars.antiFallCharConnections) do
            pcall(function() conn:Disconnect() end)
        end
        Vars.antiFallCharConnections = {}
    end
    Vars.StopAntiFall = StopAntiFall

    -- ============================================================
    -- Strafe HvH
    -- ============================================================
    local strafeLeftConn = nil
    local strafeLeftEndConn = nil
    local lastPeek = 0
    Vars.StartStrafeHvH = function()
        if Vars.strafeConnection then return end
        if not LP.Character then return end
        strafeLeftConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Settings.Movement.StrafeKeyLeft then Vars.strafeKeyLeftHeld = true end
            if input.KeyCode == Settings.Movement.StrafeKeyRight then Vars.strafeKeyRightHeld = true end
        end)
        strafeLeftEndConn = UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Settings.Movement.StrafeKeyLeft then Vars.strafeKeyLeftHeld = false end
            if input.KeyCode == Settings.Movement.StrafeKeyRight then Vars.strafeKeyRightHeld = false end
        end)
        Vars.strafeConnection = RunService.Heartbeat:Connect(function()
            if Vars.isScriptUnloaded or not Settings.Movement.StrafeEnabled then return end
            local char = LP.Character
            if not char then return end
            local h = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not h or not root or not root:IsA("BasePart") then return end
            local now = os_clock()
            if (now - lastPeek) < Settings.Movement.PeekCooldown then return end
            local strafeDir = 0
            if Vars.strafeKeyLeftHeld then strafeDir = -1 end
            if Vars.strafeKeyRightHeld then strafeDir = 1 end
            if strafeDir ~= 0 then
                local cam = Vars.GetCamera()
                local camRight = cam.CFrame.RightVector
                local offset = camRight * (strafeDir * Settings.Movement.StrafeDistance)
                local newPos = root.Position + offset
                if h.FloorMaterial == Enum.Material.Air or h.MoveDirection.Magnitude < 0.1 then
                    pcall(function()
                        root.CFrame = CFrame_new(newPos, newPos + cam.CFrame.LookVector)
                    end)
                    lastPeek = now
                end
            end
        end)
    end

    Vars.StopStrafeHvH = function()
        if Vars.strafeConnection then
            pcall(function() Vars.strafeConnection:Disconnect() end)
            Vars.strafeConnection = nil
        end
        if strafeLeftConn then pcall(function() strafeLeftConn:Disconnect() end); strafeLeftConn = nil end
        if strafeLeftEndConn then pcall(function() strafeLeftEndConn:Disconnect() end); strafeLeftEndConn = nil end
    end

    -- ============================================================
    -- EXPLOIT: Spinbot (no se atasca al caminar)
    -- ============================================================
    local lastSpin = 0
    local spinAngle = 0
    Vars.StartExploitSpinbot = function()
        if Vars.spinbotConnection then return end
        Vars.spinbotActive = true
        lastSpin = os_clock()
        Vars.spinbotConnection = RunService.RenderStepped:Connect(function()
            if Vars.isScriptUnloaded or not Settings.Exploit.Spinbot then return end
            local char = LP.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root or not root:IsA("BasePart") then return end
            local now = os_clock()
            local delta = now - lastSpin
            lastSpin = now
            if delta > 0.5 then delta = 0.5 end
            spinAngle = spinAngle + math_rad(Settings.Exploit.SpinbotSpeed) * delta
            if spinAngle > math.pi * 2 then
                spinAngle = spinAngle - math.pi * 2
            end
            pcall(function()
                local currentPos = root.Position
                local currentLook = root.CFrame.LookVector
                local rotatedLook = V3(
                    currentLook.X * math.cos(spinAngle) - currentLook.Z * math.sin(spinAngle),
                    currentLook.Y,
                    currentLook.X * math.sin(spinAngle) + currentLook.Z * math.cos(spinAngle)
                )
                root.CFrame = CFrame.lookAt(currentPos, currentPos + rotatedLook)
            end)
        end)
    end

    Vars.StopExploitSpinbot = function()
        Vars.spinbotActive = false
        if Vars.spinbotConnection then
            pcall(function() Vars.spinbotConnection:Disconnect() end)
            Vars.spinbotConnection = nil
        end
    end

    Vars.StartExploitWalkspeed = function()
        if Vars.exploitWalkspeedConn then return end
        Vars.exploitWalkspeedConn = RunService.Heartbeat:Connect(function()
            if not Settings.Exploit.Walkspeed then return end
            local char = LP.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if hum.WalkSpeed ~= Settings.Exploit.WalkspeedValue then
                hum.WalkSpeed = Settings.Exploit.WalkspeedValue
            end
        end)
    end
    Vars.StopExploitWalkspeed = function()
        if Vars.exploitWalkspeedConn then
            pcall(function() Vars.exploitWalkspeedConn:Disconnect() end)
            Vars.exploitWalkspeedConn = nil
        end
    end

    Vars.StartExploitJumpPower = function()
        if Vars.exploitJumpConn then return end
        Vars.exploitJumpConn = RunService.Heartbeat:Connect(function()
            if not Settings.Exploit.JumpPower then return end
            local char = LP.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if hum.JumpPower ~= Settings.Exploit.JumpPowerValue then
                hum.JumpPower = Settings.Exploit.JumpPowerValue
            end
        end)
    end
    Vars.StopExploitJumpPower = function()
        if Vars.exploitJumpConn then
            pcall(function() Vars.exploitJumpConn:Disconnect() end)
            Vars.exploitJumpConn = nil
        end
    end

    Vars.StartExploitNoclip = function()
        if Vars.exploitNoclipConn then return end
        Vars.exploitNoclipConn = RunService.Stepped:Connect(function()
            if not Settings.Exploit.Noclip then return end
            local char = LP.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
    Vars.StopExploitNoclip = function()
        if Vars.exploitNoclipConn then
            pcall(function() Vars.exploitNoclipConn:Disconnect() end)
            Vars.exploitNoclipConn = nil
        end
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end

    Vars.StartExploitFly = function()
        if Vars.exploitFlyConn then return end
        Vars.exploitFlyConn = RunService.Heartbeat:Connect(function()
            if not Settings.Exploit.Fly then return end
            local char = LP.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then return end
            hum.WalkSpeed = 0
            local cam = Vars.GetCamera()
            if not cam then return end
            local ctrl = Vars.exploitFlyControl
            local direction = (cam.CFrame.LookVector * (ctrl.F + ctrl.B)
                + cam.CFrame.RightVector * (ctrl.R + ctrl.L)).Unit
            local vertical = V3(0, (ctrl.U + ctrl.D), 0)
            root.AssemblyLinearVelocity = direction * Settings.Exploit.FlySpeed + vertical * Settings.Exploit.FlySpeed
        end)
    end
    Vars.StopExploitFly = function()
        if Vars.exploitFlyConn then
            pcall(function() Vars.exploitFlyConn:Disconnect() end)
            Vars.exploitFlyConn = nil
        end
        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end

    Vars.exploitFlyKeyConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local c = Vars.exploitFlyControl
        if input.KeyCode == Enum.KeyCode.W then c.F = 1
        elseif input.KeyCode == Enum.KeyCode.S then c.B = -1
        elseif input.KeyCode == Enum.KeyCode.A then c.L = -1
        elseif input.KeyCode == Enum.KeyCode.D then c.R = 1
        elseif input.KeyCode == Enum.KeyCode.Space then c.U = 1
        elseif input.KeyCode == Enum.KeyCode.LeftControl then c.D = -1
        end
    end)
    Vars.exploitFlyKeyEndConn = UserInputService.InputEnded:Connect(function(input)
        local c = Vars.exploitFlyControl
        if input.KeyCode == Enum.KeyCode.W then c.F = 0
        elseif input.KeyCode == Enum.KeyCode.S then c.B = 0
        elseif input.KeyCode == Enum.KeyCode.A then c.L = 0
        elseif input.KeyCode == Enum.KeyCode.D then c.R = 0
        elseif input.KeyCode == Enum.KeyCode.Space then c.U = 0
        elseif input.KeyCode == Enum.KeyCode.LeftControl then c.D = 0
        end
    end)

    Vars.StartExploitTeleport = function()
        if Vars.exploitTeleportConn then return end
        Vars.exploitTeleportConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if not Settings.Exploit.TeleportToCursor then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local char = LP.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local cam = Vars.GetCamera()
                if not cam then return end
                local mp = UserInputService:GetMouseLocation()
                local ray = cam:ViewportPointToRay(mp.X, mp.Y)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Blacklist
                params.FilterDescendantsInstances = {char}
                local result = Vars.Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                if result then
                    root.CFrame = CFrame_new(result.Position + V3(0, 3, 0))
                end
            end
        end)
    end
    Vars.StopExploitTeleport = function()
        if Vars.exploitTeleportConn then
            pcall(function() Vars.exploitTeleportConn:Disconnect() end)
            Vars.exploitTeleportConn = nil
        end
    end
end

-- ============================================================
-- BLOQUE 9: UI de Scryux (v9.8.0 con nuevas opciones)
-- ============================================================
do
    local Settings = Vars.Settings
    local table_insert = Vars.table_insert

    local Window = ScryuxUI:CreateWindow({
        Title = "Town Complete v9.8.0",
        Size = UDim2.new(0, 720, 0, 640),
        Keybind = Settings.Hotkeys.ToggleMenu,
        Theme = "Default",
        Acrylic = false,
        SaveFolder = "TownComplete_Settings/" .. tostring(game.PlaceId),
        FloatingIcon = true,
    })
    _env.TownUI_Window = Window
    Vars.Window = Window

    -- ============================================================
    -- TAB: ESP
    -- ============================================================
    local ESPTab = Window:CreateTab("ESP")
    ESPTab:CreateLabel("Keybind: RightShift = Menu | End = Panic | Y = Helper")
    ESPTab:CreateLabel("Version: v9.8.0")
    local ESPMain = ESPTab:CreateSection("ESP")
    ESPMain:CreateToggle({ Text = "ESP Master", Default = true, Index = "ESP_Enabled",
        Callback = function(v) Settings.ESP.Enabled = v end })
    ESPMain:CreateToggle({ Text = "Box", Default = true, Index = "ESP_Box",
        Callback = function(v)
            Settings.ESP.Box = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do esp.box.Visible = false end
            end
        end })
    ESPMain:CreateSlider({ Text = "Box Thickness", Min = 1, Max = 5, Default = 1, Index = "ESP_BoxThickness",
        Callback = function(v)
            Settings.ESP.BoxThickness = v
            for _, esp in pairs(Vars.ESPPool) do esp.box.Thickness = v end
        end })
    ESPMain:CreateSlider({ Text = "Box Padding", Min = 0, Max = 3, Default = 0.5, Index = "ESP_BoxPadding",
        Callback = function(v) Settings.ESP.BoxPadding = v end })

    local ESPInfo = ESPTab:CreateSection("Info")
    ESPInfo:CreateToggle({ Text = "Health Bar", Default = true, Index = "ESP_Health",
        Callback = function(v)
            Settings.ESP.ShowHealth = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do esp.health.Visible = false end
            end
        end })
    ESPInfo:CreateToggle({ Text = "Names", Default = true, Index = "ESP_Names",
        Callback = function(v)
            Settings.ESP.ShowName = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do esp.name.Visible = false end
            end
        end })
    ESPInfo:CreateToggle({ Text = "Show Distance", Default = false, Index = "ESP_Distance",
        Callback = function(v) Settings.ESP.ShowDistance = v end })
    ESPInfo:CreateToggle({ Text = "Head Dots", Default = false, Index = "ESP_HeadDots",
        Callback = function(v)
            Settings.ESP.HeadDots = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do
                    if esp.headDot then esp.headDot.Visible = false end
                end
            end
        end })
    ESPInfo:CreateColorpicker({ Text = "Head Dot Color", Default = Color3.fromRGB(255, 255, 0), Index = "ESP_HeadDotColor",
        Callback = function(c) Settings.ESP.HeadDotColor = c end })
    ESPInfo:CreateSlider({ Text = "Head Dot Radius", Min = 1, Max = 15, Default = 5, Index = "ESP_HeadDotRadius",
        Callback = function(v) Settings.ESP.HeadDotRadius = v end })
    ESPInfo:CreateToggle({ Text = "Items (armas tiradas)", Default = false, Index = "ESP_Items",
        Callback = function(v)
            Settings.ESP.Items = v
            if v then
                for _, part in ipairs(Vars.Workspace:GetDescendants()) do
                    if Vars.IsItemPart(part) then Vars.CreateItemESP(part) end
                end
            else
                Vars.ClearItemESP()
            end
        end })
    ESPInfo:CreateColorpicker({ Text = "Item Color", Default = Color3.fromRGB(255, 165, 0), Index = "ESP_ItemColor",
        Callback = function(c) Settings.ESP.ItemColor = c end })
    ESPInfo:CreateSlider({ Text = "Item Max Distance", Min = 50, Max = 2000, Default = 500, Index = "ESP_ItemMaxDist",
        Callback = function(v) Settings.ESP.ItemMaxDistance = v end })
    ESPInfo:CreateToggle({ Text = "Weapons (arma del enemigo)", Default = false, Index = "ESP_Weapons",
        Callback = function(v)
            Settings.ESP.Weapons = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do
                    if esp.weapon then esp.weapon.Visible = false end
                end
            end
        end })
    ESPInfo:CreateColorpicker({ Text = "Weapon Color", Default = Color3.fromRGB(255, 0, 255), Index = "ESP_WeaponColor",
        Callback = function(c) Settings.ESP.WeaponColor = c end })

    local ESPChams = ESPTab:CreateSection("Chams")
    ESPChams:CreateToggle({ Text = "Chams", Default = true, Index = "ESP_Chams",
        Callback = function(v)
            Settings.ESP.Chams = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do esp.chams.Enabled = false end
            end
        end })
    ESPChams:CreateSlider({ Text = "Chams Fill Transparency", Min = 0, Max = 1, Default = 0.25, Index = "ESP_ChamsFill",
        Callback = function(v) Settings.ESP.ChamsFillTransparency = v end })
    ESPChams:CreateSlider({ Text = "Chams Outline Transparency", Min = 0, Max = 1, Default = 0, Index = "ESP_ChamsOutlineTransp",
        Callback = function(v) Settings.ESP.ChamsOutlineTransparency = v end })
    ESPChams:CreateDropdown({ Text = "Chams Depth Mode", Options = {"AlwaysOnTop", "Occluded"}, Default = "AlwaysOnTop", Index = "ESP_ChamsDepth",
        Callback = function(v) Settings.ESP.ChamsDepthMode = v end })
    ESPChams:CreateColorpicker({ Text = "Chams Outline Color", Default = Color3.new(1, 1, 1), Index = "ESP_ChamsOutlineColor",
        Callback = function(c) Settings.ESP.ChamsOutlineColor = c end })
    ESPChams:CreateToggle({ Text = "Wallcheck Chams ESP", Default = false, Index = "ESP_WallcheckChams",
        Callback = function(v) Settings.ESP.WallcheckChams = v end })

    -- ============================================================
    -- TAB: Skeleton
    -- ============================================================
    local SkeletonTab = Window:CreateTab("Skeleton")
    local SkelMain = SkeletonTab:CreateSection("Skeleton ESP")
    SkelMain:CreateToggle({ Text = "Skeleton Master", Default = true, Index = "Skel_Enabled",
        Callback = function(v)
            Settings.Skeleton.Enabled = v
            if not v then Vars.ClearAllSkeletons() end
        end })
    SkelMain:CreateSlider({ Text = "Thickness", Min = 1, Max = 5, Default = 1, Index = "Skel_Thickness",
        Callback = function(v)
            Settings.Skeleton.Thickness = v
            for _, data in pairs(Vars.ActiveSkeletons) do
                for _, line in ipairs(data.lines) do line.Thickness = v end
            end
        end })
    SkelMain:CreateSlider({ Text = "Max Distance", Min = 50, Max = 2000, Default = 500, Index = "Skel_MaxDist",
        Callback = function(v) Settings.Skeleton.MaxDistance = v end })
    SkelMain:CreateDropdown({ Text = "Rig Mode", Options = {"Auto", "R6", "R15", "Both"}, Default = "Auto", Index = "Skel_RigMode",
        Callback = function(v)
            Settings.Skeleton.RigMode = v
            Vars.ClearAllSkeletons()
        end })
    SkelMain:CreateToggle({ Text = "Only Visible", Default = false, Index = "Skel_OnlyVisible",
        Callback = function(v) Settings.Skeleton.OnlyVisible = v end })

    -- ============================================================
    -- TAB: Aimbot
    -- ============================================================
    local AimbotTab = Window:CreateTab("Aimbot")
    local ASet = AimbotTab:CreateSection("Aimbot")
    ASet:CreateLabel("Keybind: RightShift (abrir) | Y (helper)")
    ASet:CreateToggle({ Text = "Aimbot Master", Default = false, Index = "Aim_Enabled",
        Callback = function(v) Settings.Aimbot.Enabled = v end })
    ASet:CreateDropdown({ Text = "Method", Options = {"Camera","Mouse"}, Default = "Camera", Index = "Aim_Method",
        Callback = function(v) Settings.Aimbot.Method = v end })
    ASet:CreateDropdown({ Text = "Priority", Options = {"Distance","FOV","Priority"}, Default = "Distance", Index = "Aim_Priority",
        Callback = function(v) Settings.Aimbot.Priority = v end })
    ASet:CreateToggle({ Text = "Wall Check", Default = false, Index = "Aim_WallCheck",
        Callback = function(v) Settings.Aimbot.WallCheck = v end })
    ASet:CreateToggle({ Text = "Strict Walls", Default = false, Index = "Aim_StrictWalls",
        Callback = function(v) Settings.Aimbot.StrictWallCheck = v end })
    ASet:CreateToggle({ Text = "Team Check", Default = false, Index = "Aim_TeamCheck",
        Callback = function(v) Settings.Aimbot.TeamCheck = v end })
    ASet:CreateToggle({ Text = "Ignore Passive", Default = true, Index = "Aim_IgnorePassive",
        Callback = function(v) Settings.Aimbot.IgnorePassive = v end })
    ASet:CreateToggle({ Text = "Require Gun Equipped", Default = true, Index = "Aim_RequireGun",
        Callback = function(v) Settings.Aimbot.RequireGun = v end })
    ASet:CreateSlider({ Text = "Max Distance", Min = 50, Max = 2000, Default = 500, Index = "Aim_MaxDist",
        Callback = function(v) Settings.Aimbot.MaxDistance = v end })
    ASet:CreateDropdown({ Text = "Aim Key Type", Options = {"Mouse","Key"}, Default = "Mouse", Index = "Aim_KeyType",
        Callback = function(v) Settings.Aimbot.AimKeyType = v end })
    ASet:CreateDropdown({ Text = "Aim Key", Options = {"T","Q","E","R","F","G","Z","X","C","V"}, Default = "T", Index = "Aim_Key",
        Callback = function(v) if Enum.KeyCode[v] then Settings.Aimbot.AimKey = Enum.KeyCode[v] end end })
    ASet:CreateDropdown({ Text = "Mouse Button", Options = {"Left","Right","Middle"}, Default = "Right", Index = "Aim_MouseBtn",
        Callback = function(v)
            if v == "Left" then Settings.Aimbot.AimMouseButton = Enum.UserInputType.MouseButton1
            elseif v == "Right" then Settings.Aimbot.AimMouseButton = Enum.UserInputType.MouseButton2
            else Settings.Aimbot.AimMouseButton = Enum.UserInputType.MouseButton3 end
        end })
    ASet:CreateSlider({ Text = "FOV", Min = 1, Max = 360, Default = 180, Index = "Aim_FOV",
        Callback = function(v) Settings.Aimbot.FOV = v end })
    ASet:CreateToggle({ Text = "Show FOV Circle", Default = false, Index = "Aim_ShowFOV",
        Callback = function(v) Settings.Aimbot.ShowFOV = v end })
    ASet:CreateSlider({ Text = "Smoothness Base", Min = 0, Max = 100, Default = 15, Index = "Aim_SmoothBase",
        Callback = function(v) Settings.Aimbot.BaseSmoothness = v / 100 end })
    ASet:CreateSlider({ Text = "Smoothness Helper", Min = 0, Max = 100, Default = 15, Index = "Aim_SmoothHelper",
        Callback = function(v) Settings.Aimbot.HelperSmoothness = v / 100 end })
    ASet:CreateToggle({ Text = "Prediction", Default = false, Index = "Aim_Prediction",
        Callback = function(v) Settings.Aimbot.UsePrediction = v end })
    ASet:CreateSlider({ Text = "Prediction Amount", Min = 0.01, Max = 0.3, Default = 0.13, Index = "Aim_PredAmount",
        Callback = function(v) Settings.Aimbot.PredictionAmount = v end })
    ASet:CreateToggle({ Text = "Use Ping Prediction", Default = false, Index = "Aim_PingPrediction",
        Callback = function(v) Settings.Aimbot.UsePingPrediction = v end })
    ASet:CreateToggle({ Text = "Anti-360", Default = false, Index = "Aim_Anti360",
        Callback = function(v) Settings.Aimbot.Anti360.Enabled = v end })
    ASet:CreateToggle({ Text = "Sticky Target Lock", Default = false, Index = "Aim_StickyLock",
        Callback = function(v) Settings.Aimbot.StickyLock = v end })
    ASet:CreateSlider({ Text = "Sticky Timeout (s)", Min = 0.5, Max = 10, Default = 2, Index = "Aim_StickyTimeout",
        Callback = function(v) Settings.Aimbot.StickyTimeout = v end })

    -- Aim Part Selection
    local APMSet = AimbotTab:CreateSection("Aim Part Selection")
    APMSet:CreateLabel("Selective FOV: apunta a la parte del cuerpo segun la posicion del mouse dentro del FOV")
    APMSet:CreateLabel("Hybrid: base fija (Head) que baja lentamente a Torso/Legs")
    APMSet:CreateDropdown({ Text = "Aim Part Mode", Options = Vars.BODY_PARTS_ALL, Default = "Selective FOV", Index = "Aim_AimPartMode",
        Callback = function(v)
            Settings.Aimbot.AimPartMode = v
            Vars.targetTransition.previousPlayer = nil
        end })

    -- Selective FOV zones
    local SelSet = AimbotTab:CreateSection("Selective FOV Zones")
    SelSet:CreateSlider({ Text = "Head Zone Bottom", Min = 0, Max = 1, Default = 0.35, Index = "Sel_HeadBottom",
        Callback = function(v) Settings.Aimbot.Selective.HeadZoneBottom = v end })
    SelSet:CreateSlider({ Text = "Torso Zone Bottom", Min = 0, Max = 1, Default = 0.70, Index = "Sel_TorsoBottom",
        Callback = function(v) Settings.Aimbot.Selective.TorsoZoneBottom = v end })
    SelSet:CreateSlider({ Text = "Left Arm Zone Right", Min = 0, Max = 1, Default = 0.35, Index = "Sel_LeftArmRight",
        Callback = function(v) Settings.Aimbot.Selective.LeftArmZoneRight = v end })
    SelSet:CreateSlider({ Text = "Right Arm Zone Left", Min = 0, Max = 1, Default = 0.65, Index = "Sel_RightArmLeft",
        Callback = function(v) Settings.Aimbot.Selective.RightArmZoneLeft = v end })
    SelSet:CreateSlider({ Text = "Transition Smoothing", Min = 0, Max = 1, Default = 0.85, Index = "Sel_TransitionSmooth",
        Callback = function(v) Settings.Aimbot.Selective.TransitionSmoothing = v end })
    SelSet:CreateSlider({ Text = "Deadzone Radius", Min = 0, Max = 0.5, Default = 0.05, Index = "Sel_Deadzone",
        Callback = function(v) Settings.Aimbot.Selective.DeadzoneRadius = v end })

    -- Hybrid
    local HybSet = AimbotTab:CreateSection("Hybrid Mode")
    HybSet:CreateDropdown({ Text = "Hybrid Base Part", Options = {"Head", "UpperTorso", "Torso", "LowerTorso"}, Default = "Head", Index = "Hyb_BasePart",
        Callback = function(v) Settings.Aimbot.Hybrid.BasePart = v end })
    HybSet:CreateSlider({ Text = "Vertical Bias Threshold", Min = 0, Max = 1, Default = 0.15, Index = "Hyb_VertBias",
        Callback = function(v) Settings.Aimbot.Hybrid.VerticalBiasThreshold = v end })
    HybSet:CreateSlider({ Text = "Downward Smoothness", Min = 0, Max = 1, Default = 0.7, Index = "Hyb_DownSmooth",
        Callback = function(v) Settings.Aimbot.Hybrid.DownwardSmoothness = v end })
    HybSet:CreateToggle({ Text = "Allow Return (up)", Default = true, Index = "Hyb_AllowReturn",
        Callback = function(v) Settings.Aimbot.Hybrid.AllowReturn = v end })

    -- Whitelist
    local WLSet = AimbotTab:CreateSection("Whitelist")
    WLSet:CreateButton("Toggle Whitelist (current target)", function()
        local t = Vars.TargetManager:GetCurrentTarget()
        if t then
            Vars.TargetManager:AddToWhitelist(t.player)
            local state = Vars.TargetManager:IsWhitelisted(t.player) and "añadido" or "removido"
            Window:Notify("Whitelist", t.player.Name .. " " .. state, 2, "Info")
        else
            Window:Notify("Whitelist", "Sin target actual", 2, "Warning")
        end
    end)

    -- ============================================================
    -- TAB: Aim Assist
    -- ============================================================
    local AimAssistTab = Window:CreateTab("Aim Assist")
    local AASet = AimAssistTab:CreateSection("Aim Assist")
    AASet:CreateToggle({ Text = "Aim Assist Master", Default = false, Index = "AA_Enabled",
        Callback = function(v)
            Settings.AimAssist.Enabled = v
            if v then Vars.StartAimAssist() else Vars.StopAimAssist() end
        end })
    AASet:CreateSlider({ Text = "FOV", Min = 1, Max = 360, Default = 30, Index = "AA_FOV",
        Callback = function(v) Settings.AimAssist.FOV = v end })
    AASet:CreateToggle({ Text = "Show FOV Circle", Default = false, Index = "AA_ShowFOV",
        Callback = function(v) Settings.AimAssist.ShowFOV = v end })
    AASet:CreateColorpicker({ Text = "FOV Color", Default = Color3.fromRGB(0, 255, 255), Index = "AA_FOVColor",
        Callback = function(c) Settings.AimAssist.FOVColor = c end })
    AASet:CreateSlider({ Text = "FOV Thickness", Min = 1, Max = 5, Default = 1, Index = "AA_FOVThickness",
        Callback = function(v) Settings.AimAssist.FOVThickness = v end })
    AASet:CreateSlider({ Text = "Max Distance", Min = 50, Max = 2000, Default = 500, Index = "AA_MaxDist",
        Callback = function(v) Settings.AimAssist.MaxDistance = v end })
    AASet:CreateSlider({ Text = "Smoothness", Min = 0, Max = 100, Default = 30, Index = "AA_Smoothness",
        Callback = function(v) Settings.AimAssist.Smoothness = v / 100 end })
    AASet:CreateDropdown({ Text = "Aim Part", Options = Vars.BODY_PARTS_ALL, Default = "Head", Index = "AA_AimPart",
        Callback = function(v) Settings.AimAssist.AimPart = v end })
    AASet:CreateToggle({ Text = "Use Selective FOV", Default = false, Index = "AA_Selective",
        Callback = function(v) Settings.AimAssist.Selective = v end })
    AASet:CreateDropdown({ Text = "Priority", Options = {"Distance", "FOV"}, Default = "Distance", Index = "AA_Priority",
        Callback = function(v) Settings.AimAssist.Priority = v end })
    AASet:CreateDropdown({ Text = "Method", Options = {"Camera", "Mouse"}, Default = "Camera", Index = "AA_Method",
        Callback = function(v) Settings.AimAssist.UseMouse = (v == "Mouse") end })
    AASet:CreateToggle({ Text = "Team Check", Default = false, Index = "AA_TeamCheck",
        Callback = function(v) Settings.AimAssist.TeamCheck = v end })
    AASet:CreateToggle({ Text = "Ignore Passive", Default = true, Index = "AA_IgnorePassive",
        Callback = function(v) Settings.AimAssist.IgnorePassive = v end })
    AASet:CreateToggle({ Text = "Wall Check", Default = false, Index = "AA_WallCheck",
        Callback = function(v) Settings.AimAssist.WallCheck = v end })
    AASet:CreateToggle({ Text = "Require Visible", Default = true, Index = "AA_Visible",
        Callback = function(v) Settings.AimAssist.Visible = v end })
    AASet:CreateToggle({ Text = "Use Prediction", Default = false, Index = "AA_Prediction",
        Callback = function(v) Settings.AimAssist.UsePrediction = v end })
    AASet:CreateSlider({ Text = "Prediction Amount", Min = 0.01, Max = 0.3, Default = 0.13, Index = "AA_PredAmount",
        Callback = function(v) Settings.AimAssist.PredictionAmount = v end })
    AASet:CreateToggle({ Text = "Use Ping Prediction", Default = false, Index = "AA_PingPrediction",
        Callback = function(v) Settings.AimAssist.UsePingPrediction = v end })

    -- ============================================================
    -- TAB: Weapon Mods
    -- ============================================================
    local WeaponTab = Window:CreateTab("Weapon Mods")
    local WS = WeaponTab:CreateSection("Weapon")
    WS:CreateToggle({ Text = "No Recoil", Default = false, Index = "W_NoRecoil",
        Callback = function(v)
            Settings.WeaponMods.NoRecoil = v
            if v then Vars.StartNoRecoil() else Vars.StopNoRecoil() end
        end })

    -- ============================================================
    -- TAB: Visuals
    -- ============================================================
    local VisualsTab = Window:CreateTab("Visuals")
    local VLight = VisualsTab:CreateSection("Lighting")
    VLight:CreateToggle({ Text = "Full Bright", Default = false, Index = "Vis_FullBright",
        Callback = function(v) Vars.setFullBright(v) end })
    VLight:CreateToggle({ Text = "X-Ray", Default = false, Index = "Vis_XRay",
        Callback = function(v)
            Settings.Visuals.XRay = v
            if v then Vars.StartXRay() else Vars.StopXRay() end
        end })
    VLight:CreateToggle({ Text = "No Fog", Default = false, Index = "Vis_NoFog",
        Callback = function(v) Vars.setNoFog(v) end })
    VLight:CreateToggle({ Text = "No Bloom", Default = false, Index = "Vis_NoBloom",
        Callback = function(v) Vars.setNoBloom(v) end })
    VLight:CreateToggle({ Text = "No SunRays", Default = false, Index = "Vis_NoSunRays",
        Callback = function(v) Vars.setNoSunRays(v) end })
    -- ✅ NUEVO v9.8.0: Reset All Visuals (Grok)
    VLight:CreateButton("Reset All Visuals", function()
        if Vars.ResetAllVisuals then Vars.ResetAllVisuals() end
        Window:Notify("Visuals", "Reset aplicado", 2, "Success")
    end)

    local VFOV = VisualsTab:CreateSection("Camera")
    VFOV:CreateToggle({ Text = "Custom FOV", Default = false, Index = "Vis_CustomFOV",
        Callback = function(v) Vars.setCustomFOV(v, Settings.Visuals.FOVValue) end })
    VFOV:CreateSlider({ Text = "FOV Value", Min = 1, Max = 120, Default = 70, Index = "Vis_FOVValue",
        Callback = function(v)
            Settings.Visuals.FOVValue = v
            if Settings.Visuals.CustomFOV then Vars.setCustomFOV(true, v) end
        end })

    local VHide = VisualsTab:CreateSection("First Person")
    VHide:CreateToggle({ Text = "Hide Body in First Person", Default = false, Index = "Vis_HideBody",
        Callback = function(v) Settings.Visuals.HideBody = v end })
    VHide:CreateToggle({ Text = "Also Hide Hands/Arms", Default = false, Index = "Vis_HideHands",
        Callback = function(v) Settings.Visuals.HideHands = v end })
    VHide:CreateToggle({ Text = "Also Hide Equipped Tool", Default = false, Index = "Vis_HideTool",
        Callback = function(v) Settings.Visuals.HideTool = v end })

    -- ============================================================
    -- ✅ Tracers (mejorado v9.8.0 con MaxActiveTracers de Grok)
    -- ============================================================
    local VTracer = VisualsTab:CreateSection("Bullet Tracers")
    VTracer:CreateToggle({ Text = "Bullet Tracers", Default = false, Index = "Vis_BulletTracers",
        Callback = function(v) Settings.Visuals.BulletTracers = v end })
    VTracer:CreateColorpicker({ Text = "Tracer Color", Default = Color3.fromRGB(255, 50, 50), Index = "Vis_TracerColor",
        Callback = function(c) Settings.Visuals.TracerColor = c end })
    VTracer:CreateSlider({ Text = "Lifetime (s)", Min = 0.1, Max = 10, Default = 2, Index = "Vis_TracerLifetime",
        Callback = function(v) Settings.Visuals.TracerLifetime = v end })
    VTracer:CreateSlider({ Text = "Thickness", Min = 1, Max = 10, Default = 2, Index = "Vis_TracerThickness",
        Callback = function(v) Settings.Visuals.TracerThickness = v end })
    VTracer:CreateSlider({ Text = "Max Distance", Min = 50, Max = 2000, Default = 500, Index = "Vis_TracerMaxDist",
        Callback = function(v) Settings.Visuals.TracerMaxDistance = v end })
    -- ✅ NUEVO v9.8.0
    VTracer:CreateSlider({ Text = "Max Active Tracers", Min = 5, Max = 200, Default = 40, Index = "Vis_MaxActiveTracers",
        Callback = function(v) Settings.Visuals.MaxActiveTracers = math.floor(v) end })

    local VCross = VisualsTab:CreateSection("Crosshair")
    VCross:CreateToggle({ Text = "Custom Crosshair", Default = false, Index = "Vis_Crosshair",
        Callback = function(v)
            Settings.Visuals.Crosshair = v
            if v then Vars.StartCrosshair() else Vars.StopCrosshair() end
        end })
    VCross:CreateColorpicker({ Text = "Crosshair Color", Default = Color3.fromRGB(255, 255, 255), Index = "Vis_CrosshairColor",
        Callback = function(c) Settings.Visuals.CrosshairColor = c end })
    VCross:CreateColorpicker({ Text = "Enemy Color", Default = Color3.fromRGB(255, 0, 0), Index = "Vis_CrosshairEnemyColor",
        Callback = function(c) Settings.Visuals.CrosshairEnemyColor = c end })
    VCross:CreateSlider({ Text = "Size", Min = 2, Max = 20, Default = 8, Index = "Vis_CrosshairSize",
        Callback = function(v) Settings.Visuals.CrosshairSize = v end })
    VCross:CreateSlider({ Text = "Thickness", Min = 1, Max = 5, Default = 2, Index = "Vis_CrosshairThickness",
        Callback = function(v) Settings.Visuals.CrosshairThickness = v end })
    VCross:CreateSlider({ Text = "Gap", Min = 0, Max = 20, Default = 4, Index = "Vis_CrosshairGap",
        Callback = function(v) Settings.Visuals.CrosshairGap = v end })

    -- ============================================================
    -- TAB: Backtrack
    -- ============================================================
    local BacktrackTab = Window:CreateTab("Backtrack")
    local BTSet = BacktrackTab:CreateSection("Backtrack (Rivals-style)")
    BTSet:CreateLabel("Guarda historial de posiciones y apunta a posiciones pasadas")
    BTSet:CreateToggle({ Text = "Enable Backtrack", Default = false, Index = "BT_Enabled",
        Callback = function(v) Settings.Backtrack.Enabled = v end })
    BTSet:CreateSlider({ Text = "Delay (s)", Min = 0.02, Max = 0.3, Default = 0.1, Index = "BT_Delay",
        Callback = function(v) Settings.Backtrack.Delay = v end })
    BTSet:CreateToggle({ Text = "Show Indicator", Default = false, Index = "BT_ShowIndicator",
        Callback = function(v) Settings.Backtrack.ShowIndicator = v end })

    -- ============================================================
    -- TAB: Anti-Fall
    -- ============================================================
    local AntiFallTab = Window:CreateTab("Anti-Fall")
    local AFSection = AntiFallTab:CreateSection("Anti-Fall Damage")
    AFSection:CreateToggle({ Text = "Disable Fall Damage", Default = false, Index = "AF_Enabled",
        Callback = function(v)
            Settings.AntiFall.Enabled = v
            if v then Vars.StartAntiFall() else Vars.StopAntiFall() end
        end })

    -- ============================================================
    -- TAB: Movement
    -- ============================================================
    local MovementTab = Window:CreateTab("Movement")
    local MSet = MovementTab:CreateSection("Strafe HvH")
    MSet:CreateToggle({ Text = "Strafe HvH (Window Peek)", Default = false, Index = "Mov_Strafe",
        Callback = function(v)
            Settings.Movement.StrafeEnabled = v
            if v then Vars.StartStrafeHvH() else Vars.StopStrafeHvH() end
        end })
    MSet:CreateSlider({ Text = "Strafe Distance", Min = 0.1, Max = 2, Default = 0.3, Index = "Mov_StrafeDist",
        Callback = function(v) Settings.Movement.StrafeDistance = v end })
    MSet:CreateSlider({ Text = "Peek Cooldown (s)", Min = 0.02, Max = 0.5, Default = 0.08, Index = "Mov_PeekCooldown",
        Callback = function(v) Settings.Movement.PeekCooldown = v end })
    MSet:CreateDropdown({ Text = "Strafe Key Left", Options = {"A", "Q", "Z", "X"}, Default = "A", Index = "Mov_KeyLeft",
        Callback = function(v) if Enum.KeyCode[v] then Settings.Movement.StrafeKeyLeft = Enum.KeyCode[v] end end })
    MSet:CreateDropdown({ Text = "Strafe Key Right", Options = {"D", "E", "C", "V"}, Default = "D", Index = "Mov_KeyRight",
        Callback = function(v) if Enum.KeyCode[v] then Settings.Movement.StrafeKeyRight = Enum.KeyCode[v] end end })

    -- ============================================================
    -- TAB: Exploit
    -- ============================================================
    local ExploitTab = Window:CreateTab("Exploit")
    local ExpSet = ExploitTab:CreateSection("Movement")
    ExpSet:CreateToggle({ Text = "Spinbot (360 continuo)", Default = false, Index = "Exp_Spinbot",
        Callback = function(v)
            Settings.Exploit.Spinbot = v
            if v then Vars.StartExploitSpinbot() else Vars.StopExploitSpinbot() end
        end })
    ExpSet:CreateSlider({ Text = "Spin Speed (deg/s)", Min = 60, Max = 2880, Default = 720, Index = "Exp_SpinSpeed",
        Callback = function(v) Settings.Exploit.SpinbotSpeed = v end })
    ExpSet:CreateLabel("Gira continuamente aunque camines")
    ExpSet:CreateToggle({ Text = "Walkspeed", Default = false, Index = "Exp_Walkspeed",
        Callback = function(v)
            Settings.Exploit.Walkspeed = v
            if v then Vars.StartExploitWalkspeed() else Vars.StopExploitWalkspeed() end
        end })
    ExpSet:CreateSlider({ Text = "Walkspeed Value", Min = 16, Max = 300, Default = 16, Index = "Exp_WalkspeedValue",
        Callback = function(v) Settings.Exploit.WalkspeedValue = v end })
    ExpSet:CreateToggle({ Text = "JumpPower", Default = false, Index = "Exp_JumpPower",
        Callback = function(v)
            Settings.Exploit.JumpPower = v
            if v then Vars.StartExploitJumpPower() else Vars.StopExploitJumpPower() end
        end })
    ExpSet:CreateSlider({ Text = "JumpPower Value", Min = 50, Max = 300, Default = 50, Index = "Exp_JumpPowerValue",
        Callback = function(v) Settings.Exploit.JumpPowerValue = v end })
    ExpSet:CreateToggle({ Text = "Noclip", Default = false, Index = "Exp_Noclip",
        Callback = function(v)
            Settings.Exploit.Noclip = v
            if v then Vars.StartExploitNoclip() else Vars.StopExploitNoclip() end
        end })
    ExpSet:CreateToggle({ Text = "Fly", Default = false, Index = "Exp_Fly",
        Callback = function(v)
            Settings.Exploit.Fly = v
            if v then Vars.StartExploitFly() else Vars.StopExploitFly() end
        end })
    ExpSet:CreateSlider({ Text = "Fly Speed", Min = 10, Max = 300, Default = 50, Index = "Exp_FlySpeed",
        Callback = function(v) Settings.Exploit.FlySpeed = v end })
    ExpSet:CreateLabel("Fly: WASD + Space/LCtrl")
    ExpSet:CreateToggle({ Text = "Teleport to Cursor", Default = false, Index = "Exp_TeleportToCursor",
        Callback = function(v)
            Settings.Exploit.TeleportToCursor = v
            if v then Vars.StartExploitTeleport() else Vars.StopExploitTeleport() end
        end })
    ExpSet:CreateLabel("Click izquierdo para teletransportarte")

    -- ============================================================
    -- TAB: Hotkeys
    -- ============================================================
    local HotkeyTab = Window:CreateTab("Hotkeys")
    local HKSet = HotkeyTab:CreateSection("Configurable Hotkeys")
    HKSet:CreateLabel("Cambiar las teclas de acceso rapido")
    HKSet:CreateDropdown({ Text = "Toggle Menu", Options = {"RightShift","LeftShift","Insert","Home","F1","F2"}, Default = "RightShift", Index = "HK_ToggleMenu",
        Callback = function(v) if Enum.KeyCode[v] then Settings.Hotkeys.ToggleMenu = Enum.KeyCode[v] end end })
    HKSet:CreateDropdown({ Text = "Helper Toggle", Options = {"Y","U","I","O","P","H","J","K","L"}, Default = "Y", Index = "HK_Helper",
        Callback = function(v) if Enum.KeyCode[v] then Settings.Hotkeys.Helper = Enum.KeyCode[v] end end })
    HKSet:CreateDropdown({ Text = "Panic", Options = {"End","Delete","Backspace","F12"}, Default = "End", Index = "HK_Panic",
        Callback = function(v) if Enum.KeyCode[v] then Settings.Hotkeys.Panic = Enum.KeyCode[v] end end })

    -- ============================================================
    -- TAB: Utility
    -- ============================================================
    local UtilityTab = Window:CreateTab("Utility")
    local USync = UtilityTab:CreateSection("Sync Booster + FPS Helper")
    USync:CreateToggle({ Text = "Sync Booster (Sync + FPS)", Default = false, Index = "Sync_Enabled",
        Callback = function(v)
            Settings.Sync.Enabled = v
            if v then Vars.StartSyncBooster() else Vars.StopSyncBooster() end
        end })
    USync:CreateToggle({ Text = "Auto-disable on low FPS (<30)", Default = false, Index = "Sync_AutoDisable",
        Callback = function(v) Settings.Sync.AutoDisableOnLowFPS = v end })
    USync:CreateToggle({ Text = "Try FFlag fallback (one-shot)", Default = false, Index = "Sync_FFlagFallback",
        Callback = function(v) Settings.Sync.TryFFlagFallback = v end })

    local UHUD = UtilityTab:CreateSection("HUD")
    UHUD:CreateToggle({ Text = "HUD (FPS / Ping)", Default = true, Index = "HUD_Enabled",
        Callback = function(v)
            Settings.HUD.Enabled = v
            if not v and Vars.HudLabel then Vars.HudLabel.Visible = false end
        end })
    UHUD:CreateToggle({ Text = "Show FPS", Default = true, Index = "HUD_ShowFPS",
        Callback = function(v) Settings.HUD.ShowFPS = v end })
    UHUD:CreateToggle({ Text = "Show Ping", Default = true, Index = "HUD_ShowPing",
        Callback = function(v) Settings.HUD.ShowPing = v end })
    UHUD:CreateDropdown({ Text = "HUD Position", Options = {"TopRight", "TopLeft", "BottomRight", "BottomLeft"}, Default = "TopRight", Index = "HUD_Position",
        Callback = function(v) Settings.HUD.Position = v end })

    local UPerf = UtilityTab:CreateSection("Performance")
    UPerf:CreateSlider({ Text = "ESP Update Rate (s)", Min = 0.01, Max = 0.2, Default = 0.03, Index = "Perf_ESPRate",
        Callback = function(v) Settings.Performance.ESPUpdateRate = v end })
    UPerf:CreateSlider({ Text = "Skeleton Update Rate (s)", Min = 0.01, Max = 0.2, Default = 0.04, Index = "Perf_SkelRate",
        Callback = function(v) Settings.Performance.SkeletonUpdateRate = v end })

    local UConfig = UtilityTab:CreateSection("Config")
    UConfig:CreateButton("Guardar", function()
        if Window.GetSaveManager then
            local sm = Window:GetSaveManager()
            sm:Save("default")
            Window:Notify("Config", "Guardado", 2, "Success")
        end
    end)
    UConfig:CreateButton("Cargar", function()
        if Window.GetSaveManager then
            local sm = Window:GetSaveManager()
            sm:Load("default")
            Window:Notify("Config", "Cargado", 2, "Success")
        end
    end)

    local UScript = UtilityTab:CreateSection("Script")
    UScript:CreateButton("Unload", function()
        _env.TownComplete_Cleanup()
        if Window.Destroy then Window:Destroy() end
    end)

    -- ============================================================
    -- PANIC (End)
    -- ============================================================
    Vars.panicConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Settings.Hotkeys.Panic then
            Settings.ESP.Enabled = false
            Settings.Skeleton.Enabled = false
            Settings.Aimbot.Enabled = false
            Settings.AimAssist.Enabled = false
            Settings.Sync.Enabled = false
            Settings.HUD.Enabled = false
            Settings.AntiFall.Enabled = false
            Settings.Visuals.XRay = false
            Settings.Visuals.CustomFOV = false
            Settings.Visuals.HideBody = false
            Settings.Visuals.HideHands = false
            Settings.Visuals.HideTool = false
            Settings.Visuals.BulletTracers = false
            Settings.Visuals.Crosshair = false
            Settings.ESP.HeadDots = false
            Settings.ESP.Items = false
            Settings.ESP.Weapons = false
            Settings.Movement.StrafeEnabled = false
            Settings.Exploit.Spinbot = false
            Settings.Exploit.Walkspeed = false
            Settings.Exploit.JumpPower = false
            Settings.Exploit.Noclip = false
            Settings.Exploit.Fly = false
            Settings.Exploit.TeleportToCursor = false
            Settings.Aimbot.StickyLock = false
            Settings.Backtrack.Enabled = false
            Vars.ClearAllESP()
            Vars.ClearAllSkeletons()
            Vars.ClearItemESP()
            Vars.StopSyncBooster()
            Vars.StopAntiFall()
            Vars.StopNoRecoil()
            Vars.StopStrafeHvH()
            Vars.StopExploitSpinbot()
            Vars.StopExploitWalkspeed()
            Vars.StopExploitJumpPower()
            Vars.StopExploitNoclip()
            Vars.StopExploitFly()
            Vars.StopExploitTeleport()
            Vars.StopHideBody()
            Vars.StopAimAssist()
            Vars.StopCrosshair()
            Vars.StopTracerLoop()
            Vars.ClearAllTracers()
            -- ✅ NUEVO v9.8.0: Reset visuales con función de Grok
            if Vars.ResetAllVisuals then
                Vars.ResetAllVisuals()
            else
                Vars.setFullBright(false)
                Vars.setNoFog(false)
                Vars.setNoBloom(false)
                Vars.setNoSunRays(false)
                Vars.setCustomFOV(false)
            end
            Vars.StopXRay()
            if Vars.HudLabel then Vars.HudLabel.Visible = false end
            if Vars.AimModeLabel then Vars.AimModeLabel.Visible = false end
            if _env.TownUI_Window then
                pcall(function()
                    _env.TownUI_Window:Notify("Panic", "Todo desactivado (End)", 3, "Warning")
                end)
            end
        end
    end)
end

-- ============================================================
-- BLOQUE 10: Cleanup + Init
-- ============================================================
do
    _env.TownComplete_Cleanup = function()
        Vars.isScriptUnloaded = true

        -- ✅ Desconectar todas las conexiones (incluyendo las nuevas)
        pcall(function() Vars.espSkeletonConn:Disconnect() end)
        pcall(function() Vars.fpsCounterConn:Disconnect() end)
        pcall(function() Vars.pingUpdateConn:Disconnect() end)
        pcall(function() Vars.hudConn:Disconnect() end)
        pcall(function() Vars.playerAddedConn:Disconnect() end)
        pcall(function() Vars.playerRemovingConn:Disconnect() end)
        pcall(function() Vars.localCharConn:Disconnect() end)
        pcall(function() Vars.localDiedConn:Disconnect() end)
        pcall(function() Vars.aimbotConn:Disconnect() end)
        pcall(function() Vars.fovConn:Disconnect() end)
        pcall(function() Vars.targetIndicatorConn:Disconnect() end)
        pcall(function() Vars.aimKeyBeganConn:Disconnect() end)
        pcall(function() Vars.aimKeyEndedConn:Disconnect() end)
        pcall(function() Vars.syncCharConn:Disconnect() end)
        pcall(function() Vars.panicConn:Disconnect() end)
        pcall(function() Vars.itemAddedConn:Disconnect() end)
        pcall(function() Vars.itemRemovingConn:Disconnect() end)
        pcall(function() Vars.exploitFlyKeyConn:Disconnect() end)
        pcall(function() Vars.exploitFlyKeyEndConn:Disconnect() end)
        pcall(function() Vars.posHistoryConn:Disconnect() end)
        -- ✅ NUEVO v9.8.0: Lighting ChildAdded (Grok)
        pcall(function() Vars.lightingChildAddedConn:Disconnect() end)

        -- Detener todos los módulos activos
        Vars.StopNoRecoil()
        Vars.StopSyncBooster()
        Vars.StopAntiFall()
        Vars.StopStrafeHvH()
        Vars.StopExploitSpinbot()
        Vars.StopExploitWalkspeed()
        Vars.StopExploitJumpPower()
        Vars.StopExploitNoclip()
        Vars.StopExploitFly()
        Vars.StopExploitTeleport()
        Vars.StopHideBody()
        Vars.StopAimAssist()
        Vars.StopCrosshair()
        Vars.StopTracerLoop()
        Vars.StopXRay()
        -- ✅ Reset visuales con función de Grok
        if Vars.ResetAllVisuals then
            Vars.ResetAllVisuals()
        else
            Vars.setFullBright(false)
            Vars.setNoFog(false)
            Vars.setNoBloom(false)
            Vars.setNoSunRays(false)
            Vars.setCustomFOV(false)
        end

        -- Limpiar todo el ESP / Skeleton / Tracers / Items
        Vars.ClearAllESP()
        Vars.ClearAllSkeletons()
        Vars.ClearAllTracers()
        Vars.ClearItemESP()

        for _, line in ipairs(Vars.SkeletonLinePool) do
            pcall(function() line:Remove() end)
        end
        Vars.SkeletonLinePool = {}

        local fov = Vars.GetFOVCircle and Vars.GetFOVCircle()
        if fov then pcall(function() fov:Remove() end) end
        local ti = Vars.GetTargetIndicator and Vars.GetTargetIndicator()
        if ti then pcall(function() ti:Remove() end) end
        if Vars.aimAssistFOVCircle then
            pcall(function() Vars.aimAssistFOVCircle:Remove() end)
        end
        if Vars.HudLabel then pcall(function() Vars.HudLabel:Remove() end) end
        if Vars.AimModeLabel then pcall(function() Vars.AimModeLabel:Remove() end) end

        Vars.stickyTarget = nil
        Vars.stickyLastSeen = 0
        Vars.positionHistory = {}

        for _, c in ipairs(Vars.tracerConnections) do
            pcall(function() c:Disconnect() end)
        end
        Vars.tracerConnections = {}

        if _env.TownUI_Window then
            pcall(function()
                if _env.TownUI_Window.GetSaveManager then
                    local sm = _env.TownUI_Window:GetSaveManager()
                    sm:Save("default")
                end
            end)
        end

        _env.TownUI_Window = nil
        _env.TownComplete_Loaded = false
    end

    _env.print = realPrint
    _env.warn  = realWarn

    Vars.StartHideBody()

    task.delay(0.6, function()
        if _env.TownUI_Window and _env.TownUI_Window.GetSaveManager then
            pcall(function()
                local sm = _env.TownUI_Window:GetSaveManager()
                sm:Load("default")
            end)
        end
    end)

    task.delay(1.0, function()
        if _env.TownUI_Window then
            pcall(function()
                _env.TownUI_Window:Notify(
                    "Town Complete v9.8.0",
                    "RightShift = Menu | Y = Helper | End = Panic",
                    6, "Success"
                )
            end)
        end
    end)
end
