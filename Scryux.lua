--!strict
-- ============================================================
-- Town Complete v9.9.6 (Scryux UI) - Parte 1/3
-- FPS Booster + Smart Nearest + Fling + Follow/Emote
-- Todos los toggles ON → OFF por default
-- ============================================================

local _env = getgenv and getgenv() or _G
local realPrint = print
local realWarn  = warn

-- ============================================================
-- BLOQUE 0: Logger
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
        "https://raw.githubusercontent.com/scryuxdev/Scryux-Library/main/Scryux-Library.lua?t=" .. tostring(os.time()),
        "https://cdn.jsdelivr.net/gh/scryuxdev/Scryux-Library@main/Scryux-Library.lua?t=" .. tostring(os.time()),
        "https://github.com/scryuxdev/Scryux-Library/raw/main/Scryux-Library.lua?t=" .. tostring(os.time()),
    }
    local CACHE_FILE = "scryux_ui_cache.lua"
    local CACHE_VERSION = "v9.9.6"

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
-- BLOQUE 2: Servicios + Configuración + Vars
-- ============================================================
local Vars = {}
local Settings = {}
local BODY_PARTS_ALL = {}

do
    local Players, RunService, UserInputService, CoreGui, Stats, Lighting =
        game:GetService("Players"),
        game:GetService("RunService"),
        game:GetService("UserInputService"),
        game:GetService("CoreGui"),
        game:GetService("Stats"),
        game:GetService("Lighting")

    local VirtualInputManager = nil
    pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

    local HttpService = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local TweenService = game:GetService("TweenService")

    local LP = Players.LocalPlayer
    local Workspace = workspace
    local function GetCamera() return Workspace.CurrentCamera end

    Vars.Players = Players
    Vars.RunService = RunService
    Vars.UserInputService = UserInputService
    Vars.CoreGui = CoreGui
    Vars.Stats = Stats
    Vars.Lighting = Lighting
    Vars.VirtualInputManager = VirtualInputManager
    Vars.HttpService = HttpService
    Vars.MarketplaceService = MarketplaceService
    Vars.TweenService = TweenService
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
    Vars.table_concat = table.concat
    Vars.os_clock = os.clock
    Vars.string_find = string.find

    Vars.isScriptUnloaded = false
    Vars.activePlayers = {}

    Vars.aimKeyHeld = false
    Vars.isLocalDead = false
    Vars.aimbotHelperActive = false
    Vars.anti360Active = false
    Vars.anti360Cooldown = 0
    Vars.currentTargetForAnti360 = nil

    Vars.helperMousePosition = Vector2.new(0, 0)

    Vars.noRecoilRunning = false
    Vars.noRecoilConnections = {}

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

    Vars.strafeConnection = nil
    Vars.strafeKeyLeftHeld = false
    Vars.strafeKeyRightHeld = false

    Vars.spinbotConnection = nil
    Vars.spinbotActive = false

    Vars.hideBodyConnection = nil

    Vars.TracerPool = {}
    Vars.TracerPoolMAX = 64
    Vars.ActiveTracers = {}
    Vars.tracerLoopConn = nil

    Vars.stickyTarget = nil
    Vars.stickyLastSeen = 0

    Vars.aimAssistActive = false
    Vars.aimAssistConnection = nil
    Vars.aimAssistFOVCircle = nil
    Vars.aimAssistFOVConn = nil
    Vars.aimAssistLastFrame = 0
    Vars.aimAssistEngaged = false
    Vars.aimAssistLastMousePos = Vector2.new(0, 0)
    Vars.aimAssistLastMovementTime = 0

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

    -- ✅ Fling vars
    Vars.flingConn = nil
    Vars.flingLastTime = 0
    Vars.flingActive = false
    Vars.flingTarget = nil

    -- ✅ Follow vars
    Vars.followConn = nil
    Vars.followActive = false
    Vars.followT = 0
    Vars.jerkOffLoaded = false
    Vars.jerkOffRunning = false

    Vars.positionHistory = {}
    Vars.POS_HISTORY_MAX = 20
    Vars.POS_HISTORY_TTL = 0.2

    Vars.currentSelectivePartName = nil
    Vars.currentHybridPartName = nil
    Vars.currentSmartPartName = nil

    Vars.espSkeletonConn = nil
    Vars.OriginalLighting = nil
    Vars.lightingChildAddedConn = nil
    Vars.lastESPUpdate = 0
    Vars.lastSkeletonUpdate = 0

    Vars.HudBackground = nil
    Vars.HudLabel = nil
    Vars.HudRightLabel = nil
    Vars.HudAccentLine = nil

    Vars.fpsBoosterActive = false
    Vars.fpsBoosterOriginalMaterials = {}
    Vars.fpsBoosterOriginalLighting = nil
    Vars.fpsBoosterRemovedEffects = {}

    Vars.syncData = nil

    Vars.desyncActive = false
    Vars.desyncSeat = nil
    Vars.desyncWeld = nil
    Vars.desyncConnection = nil
    Vars.desyncSavedCFrame = nil
    Vars.desyncHiddenPos = nil
    Vars.desyncCharConn = nil

    Vars.antikickOriginal = nil

    Vars.indicatorGui = nil
    Vars.indicatorFrame = nil
    Vars.indicatorLabel = nil
    Vars.indicatorConn = nil
    Vars.indicatorDragging = false
    Vars.indicatorDragStart = nil
    Vars.indicatorStartPos = nil

    Vars.quickTogglesGui = nil
    Vars.qtConn = nil

    Vars.hitboxVisualizers = {}

    Vars.worldXrayParts = {}
    Vars.worldXrayActive = false
    Vars.loopFireLast = 0

    Vars.camYConn = nil
    Vars.cframeViewConn = nil
    Vars.camYOriginal = nil

    Vars.worldProximityConn = nil
    Vars.loopFireConn = nil

    Vars.trussPart = nil
    Vars.trussConn = nil

    Vars.airwalkPart = nil
    Vars.airwalkConn = nil

    Vars.flightBodyGyro = nil
    Vars.flightBodyVelocity = nil
    Vars.flightConn = nil

    Vars.autorespawnConns = {}
    Vars.autorespawnDeathPos = nil

    -- ============================================
    -- CONFIGURACIÓN (✅ TODO OFF por default)
    -- ============================================
    Settings = {
        ESP = {
            Enabled = false, Chams = false, TeamCheck = false,
            ShowHealth = false, ShowName = false, ShowDistance = false,
            Box = false, BoxColor = Color3.fromRGB(170, 0, 255),
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
            ItemMaxCount = 100,
            Weapons = false,
            WeaponColor = Color3.fromRGB(255, 0, 255),
            WeaponTextSize = 16,
            ColorByHealth = false,
            Colors = {
                Visible = Color3.fromRGB(255, 0, 0),
                Partial = Color3.fromRGB(255, 200, 0),
                Invisible = Color3.fromRGB(0, 255, 80),
                Passive = Color3.fromRGB(0, 120, 255),
                Dead = Color3.fromRGB(100, 100, 100),
            }
        },
        Skeleton = {
            Enabled = false, Color = Color3.fromRGB(255, 255, 255),
            Thickness = 1, MaxDistance = 500, RigMode = "Auto", OnlyVisible = false,
        },
        FullBright = { Enabled = false },
        Aimbot = {
            Enabled = false, Method = "Camera",
            WallCheck = false, StrictWallCheck = false,
            IgnoreTransparent = true, IgnoreNonCollidable = true,
            TeamCheck = false, IgnorePassive = false,
            MaxDistance = 500, AimKeyType = "Mouse",
            AimKey = Enum.KeyCode.T,
            AimMouseButton = Enum.UserInputType.MouseButton2,
            FOV = 180, ShowFOV = false,
            FOVColor = Color3.fromRGB(255,255,255), FOVThickness = 2,
            AimPartMode = "Smart Nearest",
            Selective = {
                Enabled = true,
                HeadZoneBottom = 0.35,
                TorsoZoneBottom = 0.70,
                LeftArmZoneRight = 0.35,
                RightArmZoneLeft = 0.65,
                TransitionSmoothing = 0.85,
                DeadzoneRadius = 0.05,
            },
            SmartNearest = {
                HeadBonus = 8,
                TorsoBonus = 5,
                LimbBonus = 0,
                RequireVisible = false,
                MaxScreenDist = 250,
            },
            Hybrid = {
                Enabled = false, BasePart = "Head",
                VerticalBiasThreshold = 0.15,
                DownwardSmoothness = 0.7, AllowReturn = false,
            },
            HelperSmoothness = 0.15, BaseSmoothness = 0.15,
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false,
            Priority = "Distance",
            StickyLock = false, StickyTimeout = 2,
            RequireGun = false,
            BonePriority = {
                Head = 1.0, UpperTorso = 0.7, LowerTorso = 0.6,
                HumanoidRootPart = 0.5,
                LeftUpperArm = 0.35, RightUpperArm = 0.35,
                LeftLowerArm = 0.25, RightLowerArm = 0.25,
                LeftUpperLeg = 0.3, RightUpperLeg = 0.3,
                LeftLowerLeg = 0.2, RightLowerLeg = 0.2,
            },
            Anti360 = { Enabled = false, DetectionDistance = 1.5, Hysteresis = 1.5, ReEnableDelay = 0.25 }
        },
        AimAssist = {
            Enabled = false, FOV = 30, ShowFOV = false,
            FOVColor = Color3.fromRGB(0, 255, 255), FOVThickness = 1,
            MaxDistance = 500,
            Smoothness = 0.7,
            MaxSpeed = 15,
            RequireMouseMovement = false,
            MouseMovementThreshold = 0.5,
            MouseStrength = 0.4,
            MovementMemory = 0.2,
            TeamCheck = false, IgnorePassive = false, WallCheck = false,
            Visible = true, UseMouse = false, Priority = "Distance",
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false, Selective = false,
            SmartNearest = {
                HeadBonus = 8,
                TorsoBonus = 5,
                LimbBonus = 0,
                RequireVisible = false,
                MaxScreenDist = 250,
            },
        },
        WeaponMods = { NoRecoil = false },
        Visuals = {
            XRay = false, NoFog = false, NoBloom = false, NoSunRays = false,
            CustomFOV = false, FOVValue = 70, OriginalFOV = nil,
            HideBody = false, HideHands = false, HideTool = false,
            BulletTracers = false, TracerColor = Color3.fromRGB(255, 50, 50),
            TracerLifetime = 2, TracerThickness = 2, TracerMaxDistance = 500,
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
        HUD = { Enabled = false, ShowFPS = false, ShowPing = false },
        Performance = { ESPUpdateRate = 0.03, SkeletonUpdateRate = 0.04 },
        AntiFall = { Enabled = false },
        Movement = {
            StrafeEnabled = false, StrafeDistance = 0.3, PeekCooldown = 0.08,
            StrafeKeyLeft = Enum.KeyCode.A, StrafeKeyRight = Enum.KeyCode.D,
        },
        Exploit = {
            Spinbot = false, SpinbotSpeed = 1000,
            Walkspeed = false, WalkspeedValue = 16,
            JumpPower = false, JumpPowerValue = 50,
            Noclip = false, Fly = false, FlySpeed = 50,
            TeleportToCursor = false,
            -- Fling
            FlingEnabled = false,
            FlingOnlyNearest = false,
            FlingVelocity = 1e24,
            FlingCooldown = 0.15,
            FlingLoop = false,
            FlingTransparency = false,
            -- Follow / Emote
            FollowEnabled = false,
            FollowTargetName = nil,
            FollowMode = "Follow",        -- "Follow" | "TPose" | "JerkOff"
            FollowOffsetX = 3,
            FollowOffsetY = 0,
            FollowOffsetZ = 0,
            FollowLockRotation = false,
        },
        Hotkeys = {
            ToggleMenu = Enum.KeyCode.RightShift,
            Helper = Enum.KeyCode.Y,
            Panic = Enum.KeyCode.End,
        },
        Backtrack = { Enabled = false, Delay = 0.1, ShowIndicator = false },
        Advanced = {
            AntiKick = false,
            HitChance = 100,
            HeadshotChance = 100,
            STS_Distance = 5,
            ScaleToScreen = false,
            MaxExpansion = 8,
            HitboxViz_Enabled = false,
            HitboxViz_Shape = "Block",
            HitboxViz_Material = "Neon",
            HitboxViz_Transparency = 0.6,
            HitboxViz_Color = Color3.fromRGB(255, 0, 0),
            HitboxViz_Gap = 0.4,
            Indicator_Enabled = false,
            Indicator_Draggable = false,
            QT_Enabled = false,
            QT_Draggable = false,
            CamY_Enabled = false,
            CamY_Offset = 0,
            CFrameView_Enabled = false,
            WP_Enabled = false,
            WP_HoldDuration = 0,
            WP_MaxActivation = 100,
            WX_Enabled = false,
            WX_Transparency = 0.5,
            WX_Blacklist = {"Humanoid"},
            LF_Enabled = false,
            LF_Interval = 1,
            LF_Type = "TouchInterest",
            Truss_Enabled = false,
            Airwalk_Enabled = false,
            Autorespawn_Enabled = false,
            Flight_Enabled = false,
            Flight_Speed = 50,
            Desync_Enabled = false,
            Desync_Transparency = 0.5,
            FPSBooster_Enabled = false,
            FPSBooster_QualityLevel = "Level01",
            FPSBooster_LOD = "Low",
            FPSBooster_Shadows = false,
            FPSBooster_Materials = false,
            FPSBooster_RemoveEffects = false,
            FPSBooster_MaterialTarget = "Plastic",
            FPSBooster_StreamingRadius = false,
            SaveFolder = "TownComplete_Saves",
            SaveExtension = ".json",
            CurrentSave = nil,
        },
    }

    Vars.Settings = Settings

    BODY_PARTS_ALL = {
        "Smart Nearest",
        "Auto (Nearest to Crosshair)",
        "Head", "Torso",
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

    local GetCamera = Vars.GetCamera

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

    local function PredictPosition(part, amount, usePing)
        if not part then return nil end
        local pos = part.Position

        local vel = V3(0, 0, 0)
        pcall(function()
            vel = part.AssemblyLinearVelocity or part.Velocity or V3(0, 0, 0)
        end)

        local acc = V3(0, 0, 0)
        pcall(function()
            if part.AssemblyLinearAcceleration then
                acc = part.AssemblyLinearAcceleration
            end
        end)

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

    local SMART_PARTS_R15 = {
        "Head", "UpperTorso", "LowerTorso",
        "LeftUpperArm", "RightUpperArm",
        "LeftLowerArm", "RightLowerArm",
        "LeftUpperLeg", "RightUpperLeg",
        "LeftLowerLeg", "RightLowerLeg",
    }
    local SMART_PARTS_R6 = {
        "Head", "Torso",
        "Left Arm", "Right Arm",
        "Left Leg", "Right Leg",
    }

    local function IsPartVisibleFrom(part, origin, char, cam)
        if not part or not part.Parent then return false end
        local dir = part.Position - origin
        if dir.Magnitude < 0.1 then return true end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist

        local ignore = {}
        if LP.Character then
            for _, p in ipairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") then table_insert(ignore, p) end
            end
        end
        if cam then table_insert(ignore, cam) end
        params.FilterDescendantsInstances = ignore

        local hit = Workspace:Raycast(origin, dir, params)
        if not hit then return false end

        if hit.Instance == part then return true end

        if hit.Instance:IsDescendantOf(char) then
            local hitDist = (hit.Position - origin).Magnitude
            local partDist = dir.Magnitude
            if math.abs(hitDist - partDist) < 0.3 then
                return true
            end
            return false
        end

        return false
    end

    local function GetSmartNearestVisiblePart(player, cam, screenPos, fovRadius, requireVisible, headBonus, torsoBonus)
        if not player or not player.Character then return nil end
        local char = player.Character
        local rigType = GetRigType(char)
        if not rigType then return nil end

        local parts = rigType == "R15" and SMART_PARTS_R15 or SMART_PARTS_R6
        local myHead = LP.Character and LP.Character:FindFirstChild("Head")
        local origin = myHead and myHead.Position or cam.CFrame.Position

        headBonus = headBonus or 0
        torsoBonus = torsoBonus or 0

        local best, bestScore = nil, math.huge
        local maxDist = (Settings.Aimbot.SmartNearest and Settings.Aimbot.SmartNearest.MaxScreenDist) or 250

        for _, partName in ipairs(parts) do
            local part = char:FindFirstChild(partName)
            if not part or not part:IsA("BasePart") then continue end

            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
            if not onScreen then continue end
            local screenDist = (V2(sp.X, sp.Y) - screenPos).Magnitude
            if screenDist > maxDist then continue end

            if requireVisible then
                local visible = IsPartVisibleFrom(part, origin, char, cam)
                if not visible then continue end
            end

            local bonus = 0
            if partName == "Head" then bonus = headBonus
            elseif partName == "UpperTorso" or partName == "Torso" then bonus = torsoBonus
            end

            local score = screenDist - bonus
            if score < bestScore then
                bestScore = score
                best = part
            end
        end
        return best
    end
    Vars.GetSmartNearestVisiblePart = GetSmartNearestVisiblePart
    Vars.IsPartVisibleFrom = IsPartVisibleFrom

    local function GetSelectiveBodyPart(player, screenPos, fovCenter, fovRadius)
        if not player or not player.Character then return nil end
        local char = player.Character
        local cam = GetCamera()
        if not cam then return nil end
        local cfg = Settings.Aimbot.Selective
        local rigType = GetRigType(char)
        if not rigType then return nil end

        local delta = V2(screenPos.X - fovCenter.X, screenPos.Y - fovCenter.Y)
        if delta.Magnitude < 0.01 then
            return char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        end

        local normX = math.clamp((delta.X + fovRadius) / (fovRadius * 2), 0, 1)
        local normY = math.clamp((delta.Y + fovRadius) / (fovRadius * 2), 0, 1)

        local verticalZone = "torso"
        if normY <= cfg.HeadZoneBottom then verticalZone = "head"
        elseif normY <= cfg.TorsoZoneBottom then verticalZone = "torso"
        else verticalZone = "legs" end

        local horizontalZone = "center"
        if normX <= cfg.LeftArmZoneRight then horizontalZone = "left"
        elseif normX >= cfg.RightArmZoneLeft then horizontalZone = "right" end

        local partName
        if rigType == "R15" then
            if verticalZone == "head" then partName = "Head"
            elseif verticalZone == "torso" then
                if horizontalZone == "left" then partName = "LeftUpperArm"
                elseif horizontalZone == "right" then partName = "RightUpperArm"
                else partName = "UpperTorso" end
            else
                if horizontalZone == "left" then partName = "LeftUpperLeg"
                elseif horizontalZone == "right" then partName = "RightUpperLeg"
                else partName = "LowerTorso" end
            end
        else
            if verticalZone == "head" then partName = "Head"
            elseif verticalZone == "torso" then
                if horizontalZone == "left" then partName = "Left Arm"
                elseif horizontalZone == "right" then partName = "Right Arm"
                else partName = "Torso" end
            else
                if horizontalZone == "left" then partName = "Left Leg"
                elseif horizontalZone == "right" then partName = "Right Leg"
                else partName = "Torso" end
            end
        end

        local part = char:FindFirstChild(partName)
        if not part then
            part = char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        end
        return part
    end
    Vars.GetSelectiveBodyPart = GetSelectiveBodyPart

    local hybridState = { currentPart = "Head", lastChange = 0 }
    local function GetHybridBodyPart(player, screenPos, fovCenter, fovRadius)
        if not player or not player.Character then return nil end
        local char = player.Character
        local cfg = Settings.Aimbot.Hybrid
        local now = os_clock()

        local delta = V2(screenPos.X - fovCenter.X, screenPos.Y - fovCenter.Y)
        local normY = math.clamp((delta.Y + fovRadius) / (fovRadius * 2), 0, 1)

        local targetPart = cfg.BasePart
        if normY > 0.5 + cfg.VerticalBiasThreshold then targetPart = "UpperTorso" end
        if normY > 0.75 + cfg.VerticalBiasThreshold then targetPart = "LowerTorso" end
        if not cfg.AllowReturn and normY < 0.5 then targetPart = hybridState.currentPart end

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

    local function GetBestBodyPartByPriority(player, cam)
        if not player or not player.Character then return nil end
        local char = player.Character
        if not cam then cam = GetCamera() end
        if not cam then return nil end
        local center = V2(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local best, bestScore = nil, math.huge
        for partName, priority in pairs(Settings.Aimbot.BonePriority) do
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

    Vars.posHistoryConn = Vars.RunService.Heartbeat:Connect(function()
        if Vars.isScriptUnloaded then return end
        if Settings.Backtrack.Enabled then
            Vars.UpdatePositionHistory()
        end
    end)
end

