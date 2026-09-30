--!strict
-- ============================================================
-- Town Complete v9.9.3 (Scryux UI) - Parte 1/3
-- Smart Nearest Visible + Fixes completos
-- ============================================================

local _env = getgenv and getgenv() or _G
local realPrint = print
local realWarn  = warn

-- ============================================================
-- BLOQUE 0: Logger con niveles
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
-- BLOQUE 1: Helpers + Carga de Scryux UI (URLs CORREGIDAS)
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

    -- ✅ URLs CORREGIDAS (scryuxdev, no player2dwhite)
    local SCRYUX_URLS = {
        "https://raw.githubusercontent.com/scryuxdev/Scryux-Library/main/Scryux-Library.lua?t=" .. tostring(os.time()),
        "https://cdn.jsdelivr.net/gh/scryuxdev/Scryux-Library@main/Scryux-Library.lua?t=" .. tostring(os.time()),
        "https://github.com/scryuxdev/Scryux-Library/raw/main/Scryux-Library.lua?t=" .. tostring(os.time()),
    }
    local CACHE_FILE = "scryux_ui_cache.lua"
    local CACHE_VERSION = "v9.9.3"

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
    Logger.Error("No se pudo cargar Scryux UI — URL: https://github.com/scryuxdev/Scryux-Library")
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

    Vars.funConn = nil
    Vars.ragebotLastFire = 0
    Vars.ragebotTarget = nil
    Vars.orbitAngle = 0
    Vars.ragebotOrbitLastFire = 0
    Vars.ragebotOrbitTarget = nil
    Vars.blitzLastFire = 0
    Vars.blitzKilledPlayers = {}

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
    -- CONFIGURACIÓN
    -- ============================================
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
            -- ✅ v9.9.3: default "Smart Nearest" (flexible)
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
                -- Bonus de prioridad para partes (menor = más cerca del mouse se requiere)
                HeadBonus = 8,
                TorsoBonus = 5,
                LimbBonus = 0,
                -- Solo considera partes VISIBLES por raycast
                RequireVisible = true,
                -- Radio máximo desde el mouse hacia una parte para considerarla
                MaxScreenDist = 250,
            },
            Hybrid = {
                Enabled = false, BasePart = "Head",
                VerticalBiasThreshold = 0.15,
                DownwardSmoothness = 0.7, AllowReturn = true,
            },
            HelperSmoothness = 0.15, BaseSmoothness = 0.15,
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false,
            Priority = "Distance",
            StickyLock = false, StickyTimeout = 2,
            RequireGun = true,
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
            -- ✅ v9.9.3: aim assist legit (NoCries-style)
            Smoothness = 0.7,
            MaxSpeed = 15,
            RequireMouseMovement = true,
            MouseMovementThreshold = 0.5,
            MouseStrength = 0.4,
            MovementMemory = 0.2,
            TeamCheck = false, IgnorePassive = true, WallCheck = false,
            Visible = true, UseMouse = false, Priority = "Distance",
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false, Selective = false,
            -- Smart nearest settings (comparte con aimbot)
            SmartNearest = {
                HeadBonus = 8,
                TorsoBonus = 5,
                LimbBonus = 0,
                RequireVisible = true,
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
        HUD = { Enabled = true, ShowFPS = true, ShowPing = true },
        Performance = { ESPUpdateRate = 0.03, SkeletonUpdateRate = 0.04 },
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
        Fun = {
            RagebotEnabled = false,
            RagebotFOV = 360,
            RagebotMaxDistance = 500,
            RagebotFireRate = 0.05,
            RagebotAimPart = "Head",
            RagebotTeamCheck = true,
            RagebotUseCurrentTarget = false,
            RagebotSilentAim = true,
            OrbitEnabled = false,
            OrbitSpeed = 3, OrbitRadius = 8, OrbitHeight = 2,
            OrbitTargetPart = "HumanoidRootPart",
            OrbitLockCamera = false,
            RagebotOrbitEnabled = false,
            RagebotOrbitSpeed = 3, RagebotOrbitRadius = 8,
            BlitzEnabled = false,
            BlitzSpeed = 1000, BlitzFireRate = 0.01,
            BlitzTeleportRange = 5000,
        },
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
            Indicator_Draggable = true,
            QT_Enabled = false,
            QT_Draggable = true,
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
            SaveFolder = "TownComplete_Saves",
            SaveExtension = ".json",
            CurrentSave = nil,
        },
    }

    Vars.Settings = Settings

    -- ✅ v9.9.3: añadido "Smart Nearest" como modo nuevo
    BODY_PARTS_ALL = {
        "Smart Nearest",       -- nuevo modo flexible (default)
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

    -- ============================================================
    -- ✅ FIX: PredictPosition con pcall (AssemblyLinearAcceleration no existe en Solara)
    -- ============================================================
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

    -- ============================================================
    -- ✅ NUEVO v9.9.3: GetSmartNearestVisiblePart
    -- Apunta a la parte del cuerpo MÁS CERCANA al mouse que sea VISIBLE
    -- Esta es la lógica del "Nearest flexible" que querías
    -- ============================================================
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

    -- screenPos: posición del mouse en pantalla (o centro si no hay mouse)
    -- RequireVisible: si true, solo devuelve partes visibles por raycast
    -- HeadBonus/TorsoBonus/LimbBonus: reduce el score efectivo para partes prioritarias
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

            -- Proyección a pantalla
            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
            if not onScreen then continue end
            local screenDist = (V2(sp.X, sp.Y) - screenPos).Magnitude
            if screenDist > maxDist then continue end

            -- Check de visibilidad por parte (opcional, más costoso)
            if requireVisible then
                local visible = IsPartVisibleFrom(part, origin, char, cam)
                if not visible then continue end
            end

            -- Bonus por parte central
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

    -- ============================================================
    -- FOV Selectivo (legacy - mantenido por compatibilidad)
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

    -- ============================================================
    -- Modo Híbrido
    -- ============================================================
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

    Vars.posHistoryConn = Vars.RunService.Heartbeat:Connect(function()
        if Vars.isScriptUnloaded then return end
        if Settings.Backtrack.Enabled then
            Vars.UpdatePositionHistory()
        end
    end)
end

-- ============================================================
-- BLOQUE 4: ESP / Chams / Skeleton / HeadDots / Items / Weapons
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

    local GetCamera = Vars.GetCamera
    local IsPassive = Vars.IsPassive
    local CheckVisibility = Vars.CheckVisibility
    local GetBoundingVectors = Vars.GetBoundingVectors
    local GetRigType = Vars.GetRigType
    local GetBonesForRig = Vars.GetBonesForRig
    local SilentPcall = Vars.SilentPcall

    local function healthColor(hum)
        if not hum then return Settings.ESP.Colors.Visible end
        local maxH = hum.MaxHealth or 100
        local hp = math_clamp(hum.Health / maxH, 0, 1)
        return Color3.new(1 - hp, hp, 0)
    end
    Vars.healthColor = healthColor

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
    -- ESP Pool
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
        if Settings.ESP.ColorByHealth and hum then return healthColor(hum) end
        return Settings.ESP.Colors.Visible
    end

    local function UpdateESPForPlayer(player)
        if not player or player == LP then return end

        local esp = Vars.ESPPool[player.Name]
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

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

        if not isVisible or not boxPos or not boxSize then
            esp.box.Visible = false
            esp.health.Visible = false
            esp.name.Visible = false
            if esp.headDot then esp.headDot.Visible = false end
            if esp.weapon then esp.weapon.Visible = false end
            ClearSkeletonForPlayer(player.Name)
            return
        end

        esp.box.Visible = Settings.ESP.Box
        if Settings.ESP.Box then
            esp.box.Position = boxPos
            esp.box.Size = boxSize
            esp.box.Color = Settings.ESP.BoxColor
            esp.box.Thickness = Settings.ESP.BoxThickness
        end

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
    -- Items ESP
    -- ============================================================
    local ItemESPList = Vars.ItemESPList or {}
    Vars.ItemESPList = ItemESPList

    local function IsItemPart(part)
        if not part or not part:IsA("BasePart") then return false end
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

    Vars.espSkeletonConn = Vars.RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end

        local now = os_clock()
        local players = Vars.activePlayers
        if not players or #players == 0 then return end

        if Settings.ESP.Enabled then
            local espRate = Settings.Performance.ESPUpdateRate or 0.03
            if (now - Vars.lastESPUpdate) >= espRate then
                Vars.lastESPUpdate = now
                for i = 1, #players do
                    SilentPcall(UpdateESPForPlayer, players[i])
                end
                if Settings.ESP.Items then
                    SilentPcall(UpdateItemESP)
                end
            end
        end

        if Settings.Skeleton.Enabled then
            local skRate = Settings.Performance.SkeletonUpdateRate or 0.04
            if (now - Vars.lastSkeletonUpdate) >= skRate then
                Vars.lastSkeletonUpdate = now
                for i = 1, #players do
                    SilentPcall(UpdateSkeletonForPlayer, players[i])
                end
            end
        end
    end)
end

-- ============================================================
-- BLOQUE 5: HUD estilo Adonis + Eventos + Lighting + FOV + HideBody + Crosshair
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
    local table_concat = table.concat
    local os_clock = Vars.os_clock

    local GetCamera = Vars.GetCamera

    -- HUD Background
    local HudBackground = Drawing.new("Square")
    HudBackground.Filled = true
    HudBackground.Color = Color3.fromRGB(12, 12, 12)
    HudBackground.Transparency = 0.35
    HudBackground.Visible = false
    Vars.HudBackground = HudBackground

    local HudAccentLine = Drawing.new("Line")
    HudAccentLine.Thickness = 2
    HudAccentLine.Color = Color3.fromRGB(0, 200, 255)
    HudAccentLine.Visible = false
    Vars.HudAccentLine = HudAccentLine

    local HudLabel = Drawing.new("Text")
    HudLabel.Visible = false
    HudLabel.Size = 15
    HudLabel.Outline = true
    HudLabel.Color = Color3.fromRGB(240, 240, 240)
    HudLabel.Font = 2
    HudLabel.Center = false
    Vars.HudLabel = HudLabel

    local HudRightLabel = Drawing.new("Text")
    HudRightLabel.Visible = false
    HudRightLabel.Size = 15
    HudRightLabel.Outline = true
    HudRightLabel.Color = Color3.fromRGB(255, 220, 0)
    HudRightLabel.Font = 2
    HudRightLabel.Center = false
    Vars.HudRightLabel = HudRightLabel

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
            HudRightLabel.Visible = false
            HudBackground.Visible = false
            HudAccentLine.Visible = false
            return
        end

        local cam = GetCamera()
        if not cam then return end
        local viewport = cam.ViewportSize

        local leftParts = {}
        if Settings.HUD.ShowPing then
            table_insert(leftParts, "PING " .. cachedPing .. "ms")
        end
        if Settings.HUD.ShowFPS then
            table_insert(leftParts, "FPS " .. cachedFPS)
        end

        if Vars.TargetManager then
            local t = Vars.TargetManager:GetCurrentTarget()
            if t and t.player then
                table_insert(leftParts, "TARGET " .. t.player.Name)
            else
                table_insert(leftParts, "TARGET None")
            end
        end

        table_insert(leftParts, "MENU " .. Settings.Hotkeys.ToggleMenu.Name)
        if Settings.Sync.Enabled then table_insert(leftParts, "SYNC") end
        if Settings.Advanced.Desync_Enabled then table_insert(leftParts, "DESYNC") end
        if Settings.Advanced.AntiKick then table_insert(leftParts, "ANTIKICK") end

        local leftText = table_concat(leftParts, "  |  ")

        local rightText = ""
        if Settings.Aimbot.Enabled then
            local mode = Settings.Aimbot.AimPartMode
            if mode == "Smart Nearest" then
                rightText = "AIM Smart (" .. (Vars.currentSmartPartName or "Searching") .. ")"
            elseif mode == "Selective FOV" then
                rightText = "AIM Selective (" .. (Vars.currentSelectivePartName or "Auto") .. ")"
            elseif mode == "Hybrid" then
                rightText = "AIM Hybrid (" .. (Vars.currentHybridPartName or "Head") .. ")"
            else
                rightText = "AIM " .. mode
            end
        end

        if cachedFPS >= 60 then
            HudLabel.Color = Color3.fromRGB(0, 255, 120)
        elseif cachedFPS >= 30 then
            HudLabel.Color = Color3.fromRGB(255, 220, 0)
        else
            HudLabel.Color = Color3.fromRGB(255, 60, 60)
        end

        HudLabel.Text = leftText
        HudRightLabel.Text = rightText

        local barHeight = 24
        local barY = viewport.Y - barHeight - 6
        local barX = 8
        local barWidth = viewport.X - 16

        HudBackground.Size = V2(barWidth, barHeight)
        HudBackground.Position = V2(barX, barY)
        HudBackground.Visible = true

        HudAccentLine.From = V2(barX, barY)
        HudAccentLine.To = V2(barX + barWidth, barY)
        HudAccentLine.Color = HudLabel.Color
        HudAccentLine.Visible = true

        HudLabel.Position = V2(barX + 12, barY + 4)
        HudLabel.Visible = true

        if rightText ~= "" then
            HudRightLabel.Position = V2(barX + barWidth - 260, barY + 4)
            HudRightLabel.Visible = true
        else
            HudRightLabel.Visible = false
        end
    end)

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
    -- Lighting
    -- ============================================================
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

    local function ResetAllVisuals()
        setFullBright(false)
        setNoFog(false)
        setNoBloom(false)
        setNoSunRays(false)
        setCustomFOV(false)
    end
    Vars.ResetAllVisuals = ResetAllVisuals

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
    -- Crosshair
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
-- BLOQUE 6: Tracers + No Recoil + X-Ray
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

    local GetCamera = Vars.GetCamera

    local function AcquireTracer()
        local t = table_remove(Vars.TracerPool)
        if t then t.Visible = false; return t end
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
            tracer = tracer, fromPos = fromPos, toPos = toPos,
            startTime = os_clock(), lifetime = Settings.Visuals.TracerLifetime,
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
                local v1, o1 = cam:WorldToViewportPoint(data.fromPos)
                local v2, o2 = cam:WorldToViewportPoint(data.toPos)
                if o1 or o2 then
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
    -- No Recoil
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
    -- X-Ray
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
-- BLOQUE 7: Target Manager + Aimbot (Smart Nearest) + Aim Assist
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

    local GetCamera = Vars.GetCamera
    local IsMenuOpen = Vars.IsMenuOpen
    local CheckVisibility = Vars.CheckVisibility
    local IsPassive = Vars.IsPassive
    local GetRigType = Vars.GetRigType
    local hasGunScript = Vars.hasGunScript
    local PredictPosition = Vars.PredictPosition
    local GetSelectiveBodyPart = Vars.GetSelectiveBodyPart
    local GetHybridBodyPart = Vars.GetHybridBodyPart
    local GetBestBodyPartByPriority = Vars.GetBestBodyPartByPriority
    local GetBacktrackPosition = Vars.GetBacktrackPosition
    local GetSmartNearestVisiblePart = Vars.GetSmartNearestVisiblePart

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

    local TargetManager = {}
    local currentTarget = nil

    local function ComputeFOVRadius(cam, fovDegrees)
        if not cam then return 100 end
        local gf = cam.FieldOfView or 70
        local half = cam.ViewportSize.X / 2
        return half * math_tan(math_rad(fovDegrees / 2)) / math_tan(math_rad(gf / 2))
    end
    Vars.ComputeFOVRadius = ComputeFOVRadius

    -- ✅ v9.9.3: ResolveAimPart con Smart Nearest integrado
    local function ResolveAimPart(player, cam, fovCenter, fovRadius)
        local char = player.Character
        if not char then return nil end
        local mode = Settings.Aimbot.AimPartMode

        if mode == "Smart Nearest" then
            -- ✅ NUEVO: parte más cercana al mouse que sea visible
            local cfg = Settings.Aimbot.SmartNearest or {}
            local part = GetSmartNearestVisiblePart(
                player, cam, fovCenter, fovRadius,
                cfg.RequireVisible,
                cfg.HeadBonus or 8,
                cfg.TorsoBonus or 5
            )
            Vars.currentSmartPartName = part and part.Name or nil
            return part
        elseif mode == "Auto (Nearest to Crosshair)" then
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
            or state == Enum.HumanoidStateType.Physics then
            AddToDeadBlacklist(player.Name)
            return false
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            AddToDeadBlacklist(player.Name)
            return false
        end
        if state == Enum.HumanoidStateType.Ragdoll then
            AddToDeadBlacklist(player.Name)
            return false
        end
        if not char.Parent or char.Parent ~= Vars.Workspace then
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
        Vars.currentSmartPartName = nil
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

    -- Anti-360
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

    -- Main Aimbot Loop
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

    -- FOV Circle
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

    -- Target Indicator
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

    -- Hotkeys
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
    -- AIM ASSIST v9.9.3 (Smart Nearest Visible + Legit smooth)
    -- ============================================================
    local aimAssistEngaged = false

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

            local tr = player.Character:FindFirstChild("HumanoidRootPart")
            if not tr then continue end
            local dist = (lr.Position - tr.Position).Magnitude
            if Settings.AimAssist.MaxDistance > 0 and dist > Settings.AimAssist.MaxDistance then continue end

            -- ✅ Smart Nearest Visible
            local cfg = Settings.AimAssist.SmartNearest or {}
            local part = GetSmartNearestVisiblePart(
                player, cam, center, radius,
                cfg.RequireVisible ~= false,
                cfg.HeadBonus or 8,
                cfg.TorsoBonus or 5
            )
            if not part then continue end

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

            if dc < bestScore then
                bestScore = dc
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

        local now = os_clock()
        local currentMouse = UserInputService:GetMouseLocation()
        local mouseDelta = (currentMouse - Vars.aimAssistLastMousePos).Magnitude
        Vars.aimAssistLastMousePos = currentMouse
        Vars.helperMousePosition = currentMouse

        local threshold = Settings.AimAssist.MouseMovementThreshold or 0.5
        if mouseDelta >= threshold then
            Vars.aimAssistLastMovementTime = now
        end

        local movementMemory = Settings.AimAssist.MovementMemory or 0.2
        local recentlyMoved = (now - Vars.aimAssistLastMovementTime) < movementMemory

        if Settings.AimAssist.RequireMouseMovement and not recentlyMoved and not aimAssistEngaged then
            return
        end

        local target = GetAimAssistTarget()
        if not target then
            aimAssistEngaged = false
            return
        end

        local cam = GetCamera()
        if not cam then return end

        local dt = now - (Vars.aimAssistLastFrame or now)
        Vars.aimAssistLastFrame = now
        if dt > 0.5 then dt = 0.5 end
        if dt <= 0 then return end

        local aimPos = target.targetPos
        local currentCFrame = cam.CFrame
        local targetCFrame = CFrame_new(currentCFrame.Position, aimPos)

        local angleDelta = currentCFrame.LookVector:Angle(targetCFrame.LookVector)

        local maxSpeedDeg = Settings.AimAssist.MaxSpeed * (1 - Settings.AimAssist.Smoothness)
        local maxSpeedRad = math_rad(math.max(maxSpeedDeg, 0.5))
        local maxRotationThisFrame = maxSpeedRad * dt

        if angleDelta <= maxRotationThisFrame or angleDelta < math.rad(0.5) then
            aimAssistEngaged = true
            return
        end

        local fraction = maxRotationThisFrame / angleDelta
        fraction = math_clamp(fraction, 0, 1)

        if Settings.AimAssist.UseMouse then
            local sp = cam:WorldToViewportPoint(aimPos)
            local d = V2(sp.X - Vars.helperMousePosition.X, sp.Y - Vars.helperMousePosition.Y)
            if d.Magnitude > 0.5 then
                local mouseFraction = math_clamp(fraction * (Settings.AimAssist.MouseStrength or 0.4), 0, 1)
                pcall(function()
                    mousemoverel(d.X * mouseFraction, d.Y * mouseFraction)
                end)
            end
        else
            pcall(function()
                cam.CFrame = currentCFrame:Lerp(targetCFrame, fraction)
            end)
        end

        aimAssistEngaged = true
    end

    local function StartAimAssist()
        if Vars.aimAssistConnection then return end
        Vars.aimAssistActive = true
        Vars.aimAssistLastFrame = os_clock()
        aimAssistEngaged = false
        Vars.aimAssistLastMousePos = UserInputService:GetMouseLocation()
        Vars.aimAssistLastMovementTime = 0
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
        aimAssistEngaged = false
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

