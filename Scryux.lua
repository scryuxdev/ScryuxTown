-- ============================================================
-- Town Complete v10.2 (PVP Build — Optimized Client-Side)
-- ============================================================

rawset(getgenv and getgenv() or _G, "__TownUnloaded", false)

local _env = getgenv and getgenv() or _G
local realPrint = print
local realWarn  = warn
rawset(_env, "__TownRealPrint", realPrint)
rawset(_env, "__TownRealWarn",  realWarn)

-- ============================================================
-- BLOQUE 0: Logger
-- ============================================================
local Logger = {
    level = "ERROR", prefix = "[TownComplete] ",
    levels = {DEBUG=1, INFO=2, WARN=3, ERROR=4},
    _silent = true, _consoleOpen = false,
}

local _noop = function() end

local function _safeStr(v)
    if v == nil then return "nil" end
    local ok, s = pcall(tostring, v)
    return (ok and type(s) == "string") and s or "<unprintable>"
end

local function _SafeRConsolePrint(msg)
    if type(rconsoleprint) ~= "function" then return end
    pcall(rconsoleprint, _safeStr(msg))
end

local function _LoggerEmit(level, ...)
    level = _safeStr(level)
    if Logger._silent then
        local dbg = rawget(_env, "TownDebug")
        if not dbg and not Logger._consoleOpen then return end
    end
    local lvlVal = Logger.levels[level]
    local minVal = Logger.levels[Logger.level] or 4
    if not lvlVal or lvlVal < minVal then return end
    local args = {...}
    local parts = table.create(#args)
    for i = 1, #args do parts[i] = _safeStr(args[i]) end
    local line = _safeStr(Logger.prefix) .. "[" .. level .. "] " .. table.concat(parts, " ")
    if Logger._consoleOpen then _SafeRConsolePrint(line .. "\n")
    else realPrint(line) end
end

function Logger.Debug(...) _LoggerEmit("DEBUG", ...) end
function Logger.Info(...)  _LoggerEmit("INFO",  ...) end
function Logger.Warn(...)  _LoggerEmit("WARN",  ...) end
function Logger.Error(...) _LoggerEmit("ERROR", ...) end

function Logger.OpenConsole()
    if type(rconsolecreate) ~= "function" then rawset(_env,"TownDebug",true); Logger._silent=false; return false end
    local ok = pcall(rconsolecreate)
    if not ok then rawset(_env,"TownDebug",true); Logger._silent=false; return false end
    if type(rconsolesettitle) == "function" then pcall(rconsolesettitle, "TownComplete Debug") end
    Logger._consoleOpen = true; Logger._silent = false
    return true
end

function Logger.CloseConsole()
    Logger._consoleOpen = false; Logger._silent = true
    if type(rconsoledestroy) == "function" then pcall(rconsoledestroy) end
end

local _ExecName, _ExecVer = "Unknown", "?"
if type(identifyexecutor) == "function" then
    local ok, name, ver = pcall(identifyexecutor)
    if ok then _ExecName = _safeStr(name); _ExecVer = _safeStr(ver) end
end
Logger.ExecName = _ExecName; Logger.ExecVer = _ExecVer

function Logger.RestoreGlobalPrint() rawset(_env,"print",realPrint); rawset(_env,"warn",realWarn) end
function Logger.SilenceGlobalPrint() rawset(_env,"print",_noop); rawset(_env,"warn",_noop) end

function Logger.Err(context, err)
    if rawget(_env, "TownDebug") then
        realPrint(Logger.prefix .. "[" .. _safeStr(context) .. "] " .. _safeStr(err))
    end
end
Logger.ErrorWithHint = Logger.Err

function Logger.SafeCall(context, fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = xpcall(fn, function(err)
        return { msg = _safeStr(err), trace = debug.traceback("", 2) }
    end, ...)
    if not ok then
        if rawget(_env, "TownDebug") then
            realPrint(Logger.prefix .. "[" .. _safeStr(context or "SafeCall") .. "] " .. _safeStr(result and result.msg))
        end
        return nil
    end
    return result
end

-- ============================================================
-- BLOQUE 1: Scryux UI loader
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
    local CACHE_FILE    = "scryux_ui_cache.lua"
    local CACHE_VERSION = "v10.0"

    local function SafeRequest(url)
        if Has("request") then
            local ok, r = pcall(request, { Url=url, Method="GET", Headers={["User-Agent"]="Mozilla/5.0"} })
            if ok and r and r.Success then return r.Body end
        end
        local ok, result = pcall(function() return game:HttpGet(url) end)
        return ok and result or nil
    end

    local function IsValidUI(code)
        return code and #code >= 2000
            and code:find("CreateWindow", 1, true)
            and code:find("CreateTab", 1, true)
    end

    local function LoadFromCache()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
        local ok, exists = pcall(isfile, CACHE_FILE)
        if not ok or not exists then return nil end
        local ok2, cached = pcall(readfile, CACHE_FILE)
        if not ok2 or not IsValidUI(cached) then
            if type(delfile) == "function" then pcall(delfile, CACHE_FILE) end
            return nil
        end
        if not cached:find(CACHE_VERSION, 1, true) then
            if type(delfile) == "function" then pcall(delfile, CACHE_FILE) end
            return nil
        end
        local fn = loadstring(cached)
        if not fn then return nil end
        local ok3, lib = pcall(fn)
        return (ok3 and lib) and lib or nil
    end

    local function LoadFromURL(url)
        local code = SafeRequest(url)
        if not IsValidUI(code) then return nil end
        local fn = loadstring(code)
        if not fn then return nil end
        local ok, lib = pcall(fn)
        if ok and lib then
            if type(writefile) == "function" then
                pcall(writefile, CACHE_FILE, "-- " .. CACHE_VERSION .. "\n" .. code)
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
    realPrint("[TownComplete] ERROR: No se pudo cargar Scryux UI")
    return
end

-- ============================================================
-- BLOQUE 2: Services + Config
-- ============================================================
local Vars = {}
local Settings = {}

local _V2   = Vector2.new
local _V3   = Vector3.new
local _CF   = CFrame.new
local _mfloor = math.floor
local _mclamp = math.clamp
local _mmax   = math.max
local _mmin   = math.min
local _mrad   = math.rad
local _mtan   = math.tan
local _msin   = math.sin
local _mcos   = math.cos
local _mabs   = math.abs
local _clock  = os.clock
local _tins   = table.insert
local _trem   = table.remove
local _tclr   = table.clear
local _tcat   = table.concat
local _sfind  = string.find

do
    local Players            = game:GetService("Players")
    local RunService         = game:GetService("RunService")
    local UserInputService   = game:GetService("UserInputService")
    local CoreGui            = game:GetService("CoreGui")
    local Stats              = game:GetService("Stats")
    local Lighting           = game:GetService("Lighting")
    local HttpService        = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local TweenService       = game:GetService("TweenService")
    local VirtualInputManager
    pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

    local LP        = Players.LocalPlayer
    local Workspace = workspace
    local function GetCamera() return Workspace.CurrentCamera end

    Vars.Players            = Players
    Vars.RunService         = RunService
    Vars.UserInputService   = UserInputService
    Vars.CoreGui            = CoreGui
    Vars.Stats              = Stats
    Vars.Lighting           = Lighting
    Vars.VirtualInputManager= VirtualInputManager
    Vars.HttpService        = HttpService
    Vars.MarketplaceService = MarketplaceService
    Vars.TweenService       = TweenService
    Vars.LP                 = LP
    Vars.Workspace          = Workspace
    Vars.GetCamera          = GetCamera

    Vars.isScriptUnloaded   = false
    Vars.activePlayers      = {}
    Vars.aimKeyHeld         = false
    Vars.isLocalDead        = false
    Vars.aimbotHelperActive = false
    Vars.helperMousePosition= _V2(0, 0)

    Vars.noRecoilRunning    = false
    Vars.noRecoilConnections= {}

    Vars.visibilityCache    = {}
    Vars.VIS_CACHE_TTL      = 0.20

    Vars.SharedRayParams    = RaycastParams.new()
    Vars.SharedRayParams.FilterType = Enum.RaycastFilterType.Blacklist
    Vars.SharedIgnoreList   = {}
    Vars.SharedIgnoreListOwner = nil

    Vars.SkeletonLinePool   = {}
    Vars.SkeletonLinePoolMAX= 500
    Vars.ActiveSkeletons    = {}
    Vars.ESPPool            = {}
    Vars.ESPObjectPool      = {box={},health={},name={},chams={},headDot={},weapon={},teamSquare={}}
    Vars.ESPObjectPoolMAX   = 32
    Vars.ItemESPList        = {}
    Vars.hideBodyConnection = nil

    -- Off-screen pool
    Vars.OffscreenPool      = {}
    Vars.OffscreenPoolMAX   = 32
    Vars.ActiveOffscreen    = {}

    Vars.TracerPool         = {}
    Vars.TracerPoolMAX      = 64
    Vars.ActiveTracers      = {}
    Vars.tracerLoopConn     = nil

    Vars.aimAssistActive    = false
    Vars.aimAssistConnection= nil
    Vars.aimAssistFOVCircle = nil
    Vars.aimAssistFOVConn   = nil
    Vars.aimAssistLastMousePos     = _V2(0, 0)
    Vars.aimAssistLastMovementTime = 0

    Vars.targetTransition   = {
        active=false, startCFrame=nil, targetCFrame=nil,
        progress=0, duration=0.15, previousPlayer=nil,
    }
    Vars.TARGET_TRANSITION_DURATION = 0.15

    Vars.deadBlacklist        = {}
    Vars.DEAD_BLACKLIST_DURATION = 3
    Vars.whitelist            = {}

    Vars.positionHistory      = {}
    Vars.POS_HISTORY_MAX      = 20

    Vars.currentNearestPartName = nil

    Vars.OriginalLighting     = nil
    Vars.lightingChildAddedConn = nil

    Vars.lastESPUpdate        = 0
    Vars.lastSkeletonUpdate   = 0

    Vars.HudBackground  = nil
    Vars.HudLabel       = nil
    Vars.HudRightLabel  = nil
    Vars.HudAccentLine  = nil

    Vars.fpsBoosterActive           = false
    Vars.fpsBoosterOriginalMaterials= {}
    Vars.fpsBoosterOriginalLighting = nil

    Vars.quickTogglesGui = nil
    Vars.qtConn          = nil

    Vars._camFixConn    = nil
    Vars._sprintFOVConn = nil

    -- Triggerbot state
    Vars.lastTriggerClick    = 0
    Vars.sharedTriggerParams = RaycastParams.new()
    Vars.sharedTriggerParams.FilterType = Enum.RaycastFilterType.Blacklist
    Vars.sharedTriggerParams.IgnoreWater = true

    local NEAREST_CFG = {
        HeadZone        = 0.18,
        TorsoZone       = 0.52,
        LeftArmZoneX    = 0.35,
        RightArmZoneX   = 0.65,
        RequireVisible  = false,
        Hysteresis      = 0.04,
    }

    Settings = {
        ESP = {
            Enabled=false, Chams=false,
            Box=false, BoxColor=Color3.fromRGB(170,0,255),
            BoxThickness=1, BoxPadding=0.5, HealthThickness=2,
            ChamsColor=Color3.fromRGB(170,0,255),
            ChamsFillTransparency=0.25, ChamsOutlineTransparency=0,
            ChamsOutlineColor=Color3.new(1,1,1),
            ChamsDepthMode="AlwaysOnTop",
            ChamsWallcheckMode="Off",
            HeadDots=false, HeadDotColor=Color3.fromRGB(255,255,0),
            HeadDotRadius=5, HeadDotThickness=2, HeadDotTransparency=1,
            Items=false, ItemColor=Color3.fromRGB(255,165,0),
            ItemTextSize=16, ItemMaxDistance=500, ItemMaxCount=100,
            Weapons=false, WeaponColor=Color3.fromRGB(255,0,255),
            WeaponTextSize=16, ColorByHealth=false,
            ShowTeamIndicator=true,
            TeamIndicatorColor=Color3.fromRGB(60,130,255),
            EnemyIndicatorColor=Color3.fromRGB(255,50,50),
            Colors = {
                Visible=Color3.fromRGB(255,0,0),
                Partial=Color3.fromRGB(255,200,0),
                Invisible=Color3.fromRGB(0,255,80),
                Passive=Color3.fromRGB(0,120,255),
                Dead=Color3.fromRGB(100,100,100),
            },
        },
        Skeleton = {
            Enabled=false, Color=Color3.fromRGB(255,255,255),
            Thickness=1, MaxDistance=500, RigMode="Auto",
            OnlyVisible=false, ShowJoints=false, DynamicThickness=true,
        },
        FullBright = { Enabled=false },
        Aimbot = {
            Enabled=false, Method="Camera",
            Wallbang=false,
            WallCheck=false, StrictWallCheck=false,
            IgnoreTransparent=true, IgnoreNonCollidable=true,
            TeamCheck=false, IgnorePassive=false,
            TeamMethod="Normal",
            MaxDistance=500,
            AimKeyType="Mouse",
            AimKey=Enum.KeyCode.T,
            AimMouseButton=Enum.UserInputType.MouseButton2,
            FOV=180,
            FOVShowCircle=false,
            FOVFilled=false,
            FOVFillColor=Color3.fromRGB(255,255,255),
            FOVFillTransparency=0.85,
            FOVOutlineColor=Color3.fromRGB(255,255,255),
            FOVOutlineThickness=2,
            FOVOutlineTransparency=0,
            FOVNumSides=60,
            FOVCenterDot=false,
            FOVCenterDotSize=3,
            FOVCenterDotColor=Color3.fromRGB(255,50,50),
            FOVCenterDotTransparency=0,
            AimPartMode="Nearest",
            Nearest=NEAREST_CFG,
            PriorityMode="Normal",
            HelperSmoothness=0.15, BaseSmoothness=0.15,
            UsePrediction=false, PredictionAmount=0.13, UsePingPrediction=false,
            Priority="FOV", StickyLock=false, StickyTimeout=2, RequireGun=false,
            HumanMode=false, SwitchCooldown=0.45, SwitchRange=40,
            Humanize=true, JitterAmount=0.35, JitterSpeed=12, EaseStyle="EaseOut",
            BonePriority = {
                Head=1.0, UpperTorso=0.7, LowerTorso=0.6, HumanoidRootPart=0.5,
                LeftUpperArm=0.35, RightUpperArm=0.35,
                LeftLowerArm=0.25, RightLowerArm=0.25,
                LeftUpperLeg=0.3,  RightUpperLeg=0.3,
                LeftLowerLeg=0.2,  RightLowerLeg=0.2,
            },
        },
        AimAssist = {
            Enabled=false, FOV=30, ShowFOV=false,
            FOVColor=Color3.fromRGB(0,255,255), FOVThickness=1,
            MaxDistance=500, Smoothness=0.5, Strength=0.6, MaxSpeed=30,
            RequireMouseMovement=false, MouseMovementThreshold=0.5,
            TeamCheck=false, IgnorePassive=false, WallCheck=false,
            UsePrediction=false, PredictionAmount=0.13,
            HumanMode=true,
            Deadzone=3,
            SmartNearest={ HeadZone=0.18, TorsoZone=0.52, RequireVisible=false },
        },
        WeaponMods = { NoRecoil=false, NoCameraBob=false, NoSprintFOV=false },
        Visuals = {
            NoFog=false, NoBloom=false,
            CustomFOV=false, FOVValue=70, OriginalFOV=nil,
            HideBody=false, HideHands=false, HideTool=false,
            BulletTracers=false, TracerColor=Color3.fromRGB(255,50,50),
            TracerLifetime=2, TracerThickness=2, TracerMaxDistance=500,
            MaxActiveTracers=40,
        },
        HUD = { Enabled=false, ShowFPS=false, ShowPing=false },
        Performance = { ESPUpdateRate=0.03, SkeletonUpdateRate=0.04 },
        Hotkeys = {
            ToggleMenu=Enum.KeyCode.RightShift,
            Helper=Enum.KeyCode.Y,
            Panic=Enum.KeyCode.End,
        },
        Backtrack = { Enabled=false, Delay=0.1 },
        Crosshair = {
            Enabled       = false,
            Style         = "Cross",
            Color         = Color3.fromRGB(255, 255, 255),
            OutlineColor  = Color3.fromRGB(0, 0, 0),
            Outline       = true,
            Size          = 10,
            Thickness     = 2,
            Gap           = 4,
            Dot           = false,
            DotSize       = 3,
            DotColor      = Color3.fromRGB(255, 50, 50),
            Transparency  = 0,
            Spinning      = false,
            SpinSpeed     = 90,
            _angle        = 0,
        },
        WallbangSettings = {
            Enabled         = false,
            MaxPenetrations = 3,
            MaxDistance     = 600,
            ShowDebugLine   = false,
            DebugLineLifetime = 0.12,
        },
        -- v10.2 NEW
        Triggerbot = {
            Enabled         = false,
            Key             = Enum.UserInputType.MouseButton2,
            UseKey          = false,
            Delay           = 0.05,
            BotTargeting    = false,
            PassiveCheck    = true,
            RayDistance     = 1000,
        },
        OffscreenESP = {
            Enabled         = false,
            Color           = Color3.fromRGB(255, 100, 100),
            Radius          = 200,
            Size            = 15,
        },
        Advanced = {
            QT_Enabled=false,
            FPSBooster_Enabled=false,
            FPSBooster_QualityLevel="Level01",
            FPSBooster_Shadows=false,
            FPSBooster_Materials=false,
            FPSBooster_MaterialTarget="Plastic",
            SaveFolder="TownComplete_Saves",
            SaveExtension=".json",
            CurrentSave=nil,
        },
    }

    Vars.Settings   = Settings
    Vars.NEAREST_CFG = NEAREST_CFG
end

-- ============================================================
-- BLOQUE 2.5: TeamManager
-- ============================================================
do
    local LP      = Vars.LP
    local Players = Vars.Players

    Vars.TeamManager = {
        method="Normal", myTeam=nil, myTeamColor=nil,
        teammates={}, enemies={}, list={},
        lastUpdate=0, _conn=nil, _changeCallbacks={},
    }
    local TM = Vars.TeamManager

    function TM:Refresh()
        local myTeam      = LP.Team
        local myTeamColor = LP.TeamColor
        local changed     = (myTeam ~= self.myTeam) or (myTeamColor ~= self.myTeamColor)
        self.myTeam       = myTeam
        self.myTeamColor  = myTeamColor
        _tclr(self.teammates); _tclr(self.enemies); _tclr(self.list)
        local teamsByName = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local tName = p.Team and p.Team.Name or "Sin Team"
            if not teamsByName[tName] then
                teamsByName[tName] = { name=tName, color=p.TeamColor, players={}, isMine=(p.Team == myTeam and myTeam ~= nil) }
            end
            _tins(teamsByName[tName].players, p.Name)
        end
        for _, data in pairs(teamsByName) do _tins(self.list, data) end
        if myTeam then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    if p.Team == myTeam then self.teammates[p.UserId] = true
                    else                     self.enemies[p.UserId]   = true end
                end
            end
        else
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then self.enemies[p.UserId] = true end
            end
        end
        if changed then
            for _, cb in ipairs(self._changeCallbacks) do pcall(cb, myTeam, myTeamColor) end
            local w = _env.TownUI_Window
            if w and w.Notify then
                pcall(w.Notify, w, "Team Cambiado", "Ahora estás en: " .. (myTeam and myTeam.Name or "Sin Team"), 3, "Info")
            end
        end
    end

    function TM:IsEnemy(player)
        if not player or player == LP then return false end
        if self.method == "Normal" then return true end
        local mt = LP.Team;  if not mt then return true end
        local pt = player.Team; if not pt then return true end
        return pt ~= mt
    end

    function TM:IsTeammate(player)
        if not player or player == LP then return false end
        if self.method == "Normal" then return false end
        local mt = LP.Team;  if not mt then return false end
        local pt = player.Team; if not pt then return false end
        return pt == mt
    end

    function TM:GetMyTeamName() return LP.Team and LP.Team.Name or "Sin Team" end

    function TM:GetTeamListString()
        local parts = {}
        for _, d in ipairs(self.list) do _tins(parts, d.name .. " (" .. #d.players .. ")") end
        return _tcat(parts, " | ")
    end

    function TM:OnTeamChange(cb) _tins(self._changeCallbacks, cb) end

    function TM:Start()
        if self._conn then return end
        self:Refresh()
        self._conn = Vars.RunService.Heartbeat:Connect(function()
            if Vars.isScriptUnloaded then return end
            local now = _clock()
            if (now - self.lastUpdate) < 0.5 then return end
            self.lastUpdate = now
            self:Refresh()
        end)
    end

    function TM:Stop()
        if self._conn then pcall(function() self._conn:Disconnect() end); self._conn = nil end
    end

    TM.method = Settings.Aimbot.TeamMethod or "Normal"
    TM:Start()
end

-- ============================================================
-- BLOQUE 3: Core Functions
-- ============================================================
do
    local LP      = Vars.LP
    local Settings= Vars.Settings
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
        local ok, r = pcall(fn, ...)
        return ok and r or nil
    end
    Vars.SilentPcall = SilentPcall

    local function hasGunScript(character)
        if not character then return false end
        for _, child in pairs(character:GetChildren()) do
            if child:IsA("Tool") and child:FindFirstChild("GunScript") then
                local gs = child:FindFirstChild("GunScript")
                if gs:IsA("LocalScript") then return true end
            end
        end
        return false
    end
    Vars.hasGunScript = hasGunScript

    local function IsPassive(playerName)
        local char = Vars.Workspace:FindFirstChild(playerName)
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
        if not part.CanCollide then return true end
        local m = part.Material
        if m == Enum.Material.Glass or m == Enum.Material.ForceField then return true end
        local n = part.Name:lower()
        if _sfind(n,"glass") or _sfind(n,"window") then return true end
        if part:IsA("SpawnLocation") or part:IsA("Seat") then return true end
        if part.Parent and part.Parent:IsA("Tool") then return true end
        if part:IsA("MeshPart") and part.Transparency >= 0.3 then return true end
        return false
    end

    local function RebuildIgnoreList(targetPlayer)
        local ignore = {}
        if LP.Character then
            for _, p in ipairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") then _tins(ignore, p) end
            end
        end
        if targetPlayer and targetPlayer.Character then
            for _, p in ipairs(targetPlayer.Character:GetDescendants()) do
                if p:IsA("BasePart") then _tins(ignore, p) end
            end
        end
        local cam = GetCamera()
        if cam then _tins(ignore, cam) end
        Vars.SharedIgnoreList = ignore
        Vars.SharedRayParams.FilterDescendantsInstances = ignore
        Vars.SharedIgnoreListOwner = targetPlayer and targetPlayer.Name or nil
    end
    Vars.RebuildIgnoreList = RebuildIgnoreList

    local function CheckPositionVisibility(position, player, ignoreTransparent, ignoreNonCollidable)
        local cam = GetCamera(); if not cam then return "hidden" end
        local camPos = cam.CFrame.Position
        local dir  = (position - camPos).Unit
        local dist = (position - camPos).Magnitude
        local targetName = player and player.Name or nil
        if Vars.SharedIgnoreListOwner ~= targetName then RebuildIgnoreList(player) end
        local params    = Vars.SharedRayParams
        local hits      = {}
        local origin    = camPos
        local remaining = dist
        for _ = 1, 50 do
            if remaining <= 0.01 then break end
            local hit = Vars.Workspace:Raycast(origin, dir * remaining, params)
            if not hit then break end
            local hp = hit.Instance
            if player and player.Character and hp:IsDescendantOf(player.Character) then break end
            if hp.Parent and hp.Parent:IsA("Tool") then
                local nd = (hit.Position - origin).Magnitude
                origin = hit.Position + dir * 0.01; remaining = remaining - nd - 0.01
            elseif (ignoreTransparent and IsPartTransparent(hp))
                or (ignoreNonCollidable and not hp.CanCollide) then
                local nd = (hit.Position - origin).Magnitude
                origin = hit.Position + dir * 0.01; remaining = remaining - nd - 0.01
            else
                _tins(hits, hp)
                local nd = (hit.Position - origin).Magnitude
                origin = hit.Position + dir * 0.01; remaining = remaining - nd - 0.01
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
        local now    = _clock()
        if cached and (now - cached.time) < Vars.VIS_CACHE_TTL then return cached.vis end
        local vis = CheckPositionVisibility(
            head.Position, player,
            Settings.Aimbot.IgnoreTransparent,
            Settings.Aimbot.IgnoreNonCollidable
        )
        Vars.visibilityCache[player.Name] = { vis=vis, time=now }
        return vis
    end
    Vars.CheckVisibility = CheckVisibility

    local function GetBoundingVectors(char)
        if not char then return nil, nil, false end
        local ok, cf, size = pcall(function()
            local c, s = char:GetBoundingBox(); return c, s
        end)
        if not ok or not cf or not size then return nil, nil, false end
        local padding = Settings.ESP.BoxPadding
        size = size + _V3(padding, padding, padding)
        local hx, hy, hz = size.X/2, size.Y/2, size.Z/2
        local corners = {
            cf*_CF(-hx, hy, hz), cf*_CF(hx, hy, hz),
            cf*_CF(-hx,-hy, hz), cf*_CF(hx,-hy, hz),
            cf*_CF(-hx, hy,-hz), cf*_CF(hx, hy,-hz),
            cf*_CF(-hx,-hy,-hz), cf*_CF(hx,-hy,-hz),
        }
        local minX, minY =  math.huge,  math.huge
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
        local boxPos  = _V2(minX, minY)
        local boxSize = _V2(maxX-minX, maxY-minY)
        if boxSize.X > 5000 or boxSize.Y > 5000 or boxSize.X < 1 or boxSize.Y < 1 then
            return nil, nil, false
        end
        return boxPos, boxSize, true
    end
    Vars.GetBoundingVectors = GetBoundingVectors

    local function GetRigType(char)
        if not char then return nil end
        if char:FindFirstChild("UpperTorso") and char:FindFirstChild("LowerTorso") then return "R15" end
        if char:FindFirstChild("Torso") then return "R6" end
        if char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") then return "R6" end
        return nil
    end
    Vars.GetRigType = GetRigType

    local R15_BONES = {
        {"UpperTorso","Head"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
        {"UpperTorso","LowerTorso"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    }
    local R6_BONES = {
        {"Torso","Head"},
        {"Torso","Left Arm"},{"Torso","Right Arm"},
        {"Torso","Left Leg"},{"Torso","Right Leg"},
    }
    local function GetBonesForRig(rigType)
        if rigType == "R15" then return R15_BONES
        elseif rigType == "R6" then return R6_BONES end
        return nil
    end
    Vars.GetBonesForRig = GetBonesForRig

    local function GetLivePing()
        local ok, ping = pcall(function()
            return Vars.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        return (ok and ping) and (ping / 1000) or 0
    end
    Vars.GetLivePing = GetLivePing

    local function PredictPosition(part, amount, usePing)
        if not part then return nil end
        local pos = part.Position
        local vel = _V3(0,0,0)
        pcall(function() vel = part.AssemblyLinearVelocity or part.Velocity or _V3(0,0,0) end)
        local acc = _V3(0,0,0)
        pcall(function()
            local ok, a = pcall(function() return part.AssemblyLinearAcceleration end)
            if ok and a then acc = a end
        end)
        local t = amount + (usePing and GetLivePing() * 0.5 or 0)
        return pos + vel * t + 0.5 * acc * t * t
    end
    Vars.PredictPosition = PredictPosition

    local NEAREST_PARTS_R15 = {
        "Head","UpperTorso","LowerTorso",
        "LeftUpperArm","RightUpperArm",
        "LeftLowerArm","RightLowerArm",
        "LeftUpperLeg","RightUpperLeg",
        "LeftLowerLeg","RightLowerLeg",
    }
    local NEAREST_PARTS_R6 = {
        "Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg",
    }

    local function _ResolveNearestPart(rigType, relX, relY, cfg)
        local hZ = cfg.HeadZone  or 0.18
        local tZ = cfg.TorsoZone or 0.52
        local lX = cfg.LeftArmZoneX  or 0.35
        local rX = cfg.RightArmZoneX or 0.65
        if rigType == "R15" then
            local sZ  = hZ + (tZ - hZ) * 0.35
            local cZ  = hZ + (tZ - hZ) * 0.65
            local hpZ = tZ + (1 - tZ) * 0.30
            local thZ = tZ + (1 - tZ) * 0.65
            if relY < hZ then return "Head"
            elseif relY < sZ then
                return relX < lX and "LeftUpperArm" or relX > rX and "RightUpperArm" or "UpperTorso"
            elseif relY < cZ then
                return relX < lX and "LeftUpperArm" or relX > rX and "RightUpperArm" or "UpperTorso"
            elseif relY < tZ then
                return relX < lX and "LeftLowerArm" or relX > rX and "RightLowerArm" or "UpperTorso"
            elseif relY < hpZ then
                return relX < lX and "LeftUpperLeg" or relX > rX and "RightUpperLeg" or "LowerTorso"
            elseif relY < thZ then
                return relX < lX and "LeftUpperLeg" or relX > rX and "RightUpperLeg" or "LowerTorso"
            else
                return relX < 0.35 and "LeftLowerLeg" or relX > 0.65 and "RightLowerLeg" or "LowerTorso"
            end
        else
            local hip = tZ + (1 - tZ) * 0.5
            if relY < hZ then return "Head"
            elseif relY < tZ then
                return relX < lX and "Left Arm" or relX > rX and "Right Arm" or "Torso"
            elseif relY < hip then
                return relX < lX and "Left Leg" or relX > rX and "Right Leg" or "Torso"
            else
                return relX < lX and "Left Leg" or relX > rX and "Right Leg" or "Torso"
            end
        end
    end

    local _nearestState = {}

    local function GetNearestVisiblePart(player, cam, screenPos)
        if not player or not player.Character then return nil end
        local char    = player.Character
        local rigType = GetRigType(char)
        if not rigType then return nil end
        local cfg = Vars.Settings.Aimbot.Nearest
        local boxPos, boxSize, ok = GetBoundingVectors(char)
        if not ok or not boxPos or not boxSize then
            local parts = rigType == "R15" and NEAREST_PARTS_R15 or NEAREST_PARTS_R6
            local best, bestDist = nil, math.huge
            for _, pn in ipairs(parts) do
                local part = char:FindFirstChild(pn)
                if part and part:IsA("BasePart") then
                    local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (screenPos - _V2(sp.X, sp.Y)).Magnitude
                        if d < 250 and d < bestDist then bestDist = d; best = part end
                    end
                end
            end
            return best
        end
        local relX = (screenPos.X - boxPos.X) / _mmax(boxSize.X, 1)
        local relY = (screenPos.Y - boxPos.Y) / _mmax(boxSize.Y, 1)
        if relX < -0.3 or relX > 1.3 or relY < -0.3 or relY > 1.3 then return nil end
        local targetName = _ResolveNearestPart(rigType, relX, relY, cfg)
        local state = _nearestState[player.Name]
        local now   = _clock()
        if state and state.lastPart and targetName ~= state.lastPart then
            if (now - (state.lastSwitchTime or 0)) < (cfg.Hysteresis or 0.04) then
                targetName = state.lastPart
            end
        end
        if not state then
            _nearestState[player.Name] = { lastPart=targetName, lastSwitchTime=now }
        elseif state.lastPart ~= targetName then
            state.lastSwitchTime = now; state.lastPart = targetName
        end
        local part = char:FindFirstChild(targetName)
        if not part or not part:IsA("BasePart") then
            part = char:FindFirstChild("Head")
                or char:FindFirstChild("Torso")
                or char:FindFirstChild("UpperTorso")
        end
        return part
    end
    Vars.GetNearestVisiblePart = GetNearestVisiblePart
    Vars.ClearNearestState = function()
        for k in pairs(_nearestState) do _nearestState[k] = nil end
    end

    -- v10.2: Head mode validator — rompe el lock si Head sale de pantalla o del FOV
    local function ValidateHeadTarget(player, cam, fovCenter, fovRadius)
        if not player or not player.Character then return false end
        local head = player.Character:FindFirstChild("Head")
        if not head then return false end
        local sp, onScreen = cam:WorldToViewportPoint(head.Position)
        if not onScreen then return false end
        local d = (_V2(sp.X, sp.Y) - fovCenter).Magnitude
        return d <= fovRadius
    end
    Vars.ValidateHeadTarget = ValidateHeadTarget

    local function GetBacktrackPosition(pn, delay)
        local hist = Vars.positionHistory[pn]
        if not hist or #hist == 0 then return nil end
        local tt = _clock() - delay
        for _, entry in ipairs(hist) do
            if entry.time <= tt then return entry.pos, entry.cframe end
        end
        return hist[#hist].pos, hist[#hist].cframe
    end
    Vars.GetBacktrackPosition = GetBacktrackPosition

    local function UpdatePositionHistory()
        local now = _clock()
        for _, p in ipairs(Vars.activePlayers) do
            if not p.Character then continue end
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local hist = Vars.positionHistory[p.Name]
            if not hist then hist = {}; Vars.positionHistory[p.Name] = hist end
            _tins(hist, 1, { pos=root.Position, time=now, cframe=root.CFrame })
            while #hist > Vars.POS_HISTORY_MAX do _trem(hist) end
        end
    end
    Vars.UpdatePositionHistory = UpdatePositionHistory

    Vars.posHistoryConn = Vars.RunService.Heartbeat:Connect(function()
        Logger.SafeCall("posHistory/Heartbeat", function()
            if Vars.isScriptUnloaded then return end
            if Settings.Backtrack.Enabled then Vars.UpdatePositionHistory() end
        end)
    end)
end

-- ============================================================
-- BLOQUE 4: ESP / Skeleton / Items
-- ============================================================
do
    local LP       = Vars.LP
    local CoreGui  = Vars.CoreGui
    local Settings = Vars.Settings
    local GetCamera      = Vars.GetCamera
    local IsPassive      = Vars.IsPassive
    local CheckVisibility= Vars.CheckVisibility
    local GetBoundingVectors = Vars.GetBoundingVectors
    local GetRigType     = Vars.GetRigType
    local GetBonesForRig = Vars.GetBonesForRig
    local SilentPcall    = Vars.SilentPcall

    local function healthColor(hum)
        if not hum then return Settings.ESP.Colors.Visible end
        local hp = _mclamp(hum.Health / (hum.MaxHealth or 100), 0, 1)
        return Color3.new(1-hp, hp, 0)
    end
    Vars.healthColor = healthColor

    local function _ReleaseDrawing(obj, pool, poolName)
        if not obj then return end
        obj.Visible = false
        local p = Vars.ESPObjectPool[poolName]
        if p and #p < Vars.ESPObjectPoolMAX then _tins(p, obj)
        else pcall(function() obj:Remove() end) end
    end
    local function _ReleaseHighlight(obj, pool, poolName)
        if not obj then return end
        obj.Enabled = false; obj.Adornee = nil; obj.Parent = nil
        local p = Vars.ESPObjectPool[poolName]
        if p and #p < Vars.ESPObjectPoolMAX then _tins(p, obj)
        else pcall(function() obj:Destroy() end) end
    end

    local function AcquireSkeletonLine()
        local l = _trem(Vars.SkeletonLinePool)
        if l then l.Visible = false; return l end
        l = Drawing.new("Line"); l.Thickness = 1; l.Visible = false
        return l
    end
    local function ReleaseSkeletonLine(l)
        if not l then return end
        l.Visible = false
        if #Vars.SkeletonLinePool < Vars.SkeletonLinePoolMAX then
            _tins(Vars.SkeletonLinePool, l)
        else pcall(function() l:Remove() end) end
    end

    local function ClearSkeletonForPlayer(pn)
        if not pn then return end
        local d = Vars.ActiveSkeletons[pn]
        if not d then return end
        for _, l in ipairs(d.lines) do ReleaseSkeletonLine(l) end
        Vars.ActiveSkeletons[pn] = nil
    end
    Vars.ClearSkeletonForPlayer = ClearSkeletonForPlayer

    local function ClearAllSkeletons()
        for n in pairs(Vars.ActiveSkeletons) do ClearSkeletonForPlayer(n) end
    end
    Vars.ClearAllSkeletons = ClearAllSkeletons

    local function GetOrCreateESP(name)
        local esp = Vars.ESPPool[name]
        if esp then return esp end
        local function take(poolName, create)
            local obj = _trem(Vars.ESPObjectPool[poolName])
            return obj and obj or create()
        end
        local box = take("box", function()
            local b = Drawing.new("Square"); b.Thickness=1; b.Filled=false; b.Visible=false; return b end)
        local health = take("health", function()
            local h = Drawing.new("Line"); h.Thickness=2; h.Visible=false; return h end)
        local nameLabel = take("name", function()
            local n = Drawing.new("Text"); n.Size=16; n.Center=true; n.Outline=true; n.Font=2; n.Visible=false; return n end)
        local headDot = take("headDot", function()
            local c = Drawing.new("Circle"); c.Filled=true; c.Visible=false; return c end)
        local weapon = take("weapon", function()
            local w = Drawing.new("Text"); w.Size=16; w.Center=true; w.Outline=true; w.Font=2; w.Visible=false; return w end)
        local teamSquare = take("teamSquare", function()
            local s = Drawing.new("Square"); s.Filled=true; s.Thickness=0; s.Visible=false; return s end)
        local chams = take("chams", function()
            local h = Instance.new("Highlight")
            h.FillColor           = Settings.ESP.ChamsColor
            h.OutlineColor        = Settings.ESP.ChamsOutlineColor
            h.FillTransparency    = Settings.ESP.ChamsFillTransparency
            h.OutlineTransparency = Settings.ESP.ChamsOutlineTransparency
            h.DepthMode           = Enum.HighlightDepthMode[Settings.ESP.ChamsDepthMode]
                                    or Enum.HighlightDepthMode.AlwaysOnTop
            h.Enabled = false; h.Parent = CoreGui
            return h end)
        chams.Parent = CoreGui
        esp = { box=box, health=health, name=nameLabel, chams=chams,
                headDot=headDot, weapon=weapon, teamSquare=teamSquare }
        Vars.ESPPool[name] = esp
        return esp
    end
    Vars.GetOrCreateESP = GetOrCreateESP

    local function RemoveESPForPlayer(name)
        local esp = Vars.ESPPool[name]
        if not esp then return end
        _ReleaseDrawing(esp.box,        nil, "box")
        _ReleaseDrawing(esp.health,     nil, "health")
        _ReleaseDrawing(esp.name,       nil, "name")
        _ReleaseDrawing(esp.headDot,    nil, "headDot")
        _ReleaseDrawing(esp.weapon,     nil, "weapon")
        _ReleaseDrawing(esp.teamSquare, nil, "teamSquare")
        _ReleaseHighlight(esp.chams,    nil, "chams")
        Vars.ESPPool[name] = nil
    end
    Vars.RemoveESPForPlayer = RemoveESPForPlayer

    local function ClearAllESP()
        for n in pairs(Vars.ESPPool) do RemoveESPForPlayer(n) end
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
        local esp  = Vars.ESPPool[player.Name]
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 or not Settings.ESP.Enabled then
            if esp then
                esp.box.Visible  = false; esp.health.Visible = false
                esp.name.Visible = false; esp.chams.Enabled  = false
                if esp.headDot    then esp.headDot.Visible    = false end
                if esp.weapon     then esp.weapon.Visible      = false end
                if esp.teamSquare then esp.teamSquare.Visible  = false end
            end
            ClearSkeletonForPlayer(player.Name)
            return
        end
        esp = GetOrCreateESP(player.Name)
        local boxPos, boxSize, isVisible = GetBoundingVectors(char)
        local color    = GetESPColor(player)
        local visState = CheckVisibility(player)
        if Settings.ESP.Chams then
            esp.chams.Adornee           = char
            esp.chams.OutlineColor      = Settings.ESP.ChamsOutlineColor
            esp.chams.OutlineTransparency = Settings.ESP.ChamsOutlineTransparency
            esp.chams.DepthMode         = Enum.HighlightDepthMode[Settings.ESP.ChamsDepthMode]
                                          or Enum.HighlightDepthMode.AlwaysOnTop
            esp.chams.FillColor         = color
            local mode       = Settings.ESP.ChamsWallcheckMode or "Off"
            local shouldHide = (mode == "OnlyVisible"      and visState ~= "visible")
                            or (mode == "OnlyHidden"       and visState == "visible")
                            or (mode == "PartiallyVisible" and visState == "hidden")
            esp.chams.FillTransparency  = shouldHide and 1 or Settings.ESP.ChamsFillTransparency
            esp.chams.Enabled           = true
        else
            esp.chams.Enabled = false
        end
        if not isVisible or not boxPos or not boxSize then
            esp.box.Visible  = false; esp.health.Visible = false; esp.name.Visible = false
            if esp.headDot    then esp.headDot.Visible    = false end
            if esp.weapon     then esp.weapon.Visible      = false end
            if esp.teamSquare then esp.teamSquare.Visible  = false end
            ClearSkeletonForPlayer(player.Name)
            return
        end
        esp.box.Visible = Settings.ESP.Box
        if Settings.ESP.Box then
            esp.box.Position  = boxPos
            esp.box.Size      = boxSize
            esp.box.Color     = color
            esp.box.Thickness = Settings.ESP.BoxThickness
        end
        if Settings.ESP.ShowHealth then
            local hp = _mclamp(hum.Health / _mmax(hum.MaxHealth, 1), 0, 1)
            esp.health.From      = _V2(boxPos.X - 5, boxPos.Y + boxSize.Y)
            esp.health.To        = _V2(boxPos.X - 5, boxPos.Y + boxSize.Y * (1 - hp))
            esp.health.Color     = Color3.fromHSV(hp * 0.3, 1, 1)
            esp.health.Thickness = Settings.ESP.HealthThickness
            esp.health.Visible   = true
        else esp.health.Visible = false end
        if Settings.ESP.ShowName then
            local text = player.Name
            if Settings.ESP.ShowDistance and LP.Character then
                local myRoot    = LP.Character:FindFirstChild("HumanoidRootPart")
                local theirRoot = char:FindFirstChild("HumanoidRootPart")
                if myRoot and theirRoot then
                    text = text .. " [" .. _mfloor((myRoot.Position - theirRoot.Position).Magnitude) .. "m]"
                end
            end
            esp.name.Text     = text
            esp.name.Position = _V2(boxPos.X + boxSize.X/2, boxPos.Y - 18)
            esp.name.Color    = color
            esp.name.Visible  = true
        else esp.name.Visible = false end
        if Settings.ESP.HeadDots and esp.headDot then
            local head = char:FindFirstChild("Head")
            if head then
                local sp, onScreen = GetCamera():WorldToViewportPoint(head.Position)
                if onScreen then
                    esp.headDot.Position    = _V2(sp.X, sp.Y)
                    esp.headDot.Radius      = Settings.ESP.HeadDotRadius
                    esp.headDot.Thickness   = Settings.ESP.HeadDotThickness
                    esp.headDot.Color       = Settings.ESP.HeadDotColor
                    esp.headDot.Transparency= Settings.ESP.HeadDotTransparency
                    esp.headDot.Visible     = true
                else esp.headDot.Visible = false end
            else esp.headDot.Visible = false end
        elseif esp.headDot then esp.headDot.Visible = false end
        if Settings.ESP.Weapons and esp.weapon then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                esp.weapon.Text     = tool.Name
                esp.weapon.Position = _V2(boxPos.X + boxSize.X/2, boxPos.Y + boxSize.Y + 14)
                esp.weapon.Color    = Settings.ESP.WeaponColor
                esp.weapon.Size     = Settings.ESP.WeaponTextSize
                esp.weapon.Visible  = true
            else esp.weapon.Visible = false end
        elseif esp.weapon then esp.weapon.Visible = false end
        if Settings.ESP.ShowTeamIndicator and esp.teamSquare then
            local isTeammate = Vars.TeamManager and Vars.TeamManager:IsTeammate(player) or false
            esp.teamSquare.Size     = _V2(10, 10)
            esp.teamSquare.Position = _V2(boxPos.X + boxSize.X/2 - 5, boxPos.Y - 32)
            esp.teamSquare.Color    = isTeammate
                and Settings.ESP.TeamIndicatorColor
                or  Settings.ESP.EnemyIndicatorColor
            esp.teamSquare.Visible  = true
        elseif esp.teamSquare then
            esp.teamSquare.Visible = false
        end
    end
    Vars.UpdateESPForPlayer = UpdateESPForPlayer

    local _skeletonJointDots = {}
    local function _GetJointDot(pn, jn)
        _skeletonJointDots[pn] = _skeletonJointDots[pn] or {}
        local dot = _skeletonJointDots[pn][jn]
        if not dot then
            dot = Drawing.new("Circle")
            dot.Filled = true; dot.NumSides = 8; dot.Visible = false
            _skeletonJointDots[pn][jn] = dot
        end
        return dot
    end
    local function _ClearJointDots(pn)
        local dots = _skeletonJointDots[pn]
        if not dots then return end
        for _, d in pairs(dots) do pcall(function() d:Remove() end) end
        _skeletonJointDots[pn] = nil
    end
    Vars._ClearJointDots = _ClearJointDots

    local function UpdateSkeletonForPlayer(player)
        if not player or player == LP or not Settings.Skeleton.Enabled then
            ClearSkeletonForPlayer(player and player.Name)
            if player then _ClearJointDots(player.Name) end
            return
        end
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then
            ClearSkeletonForPlayer(player.Name); _ClearJointDots(player.Name); return
        end
        if Settings.Skeleton.OnlyVisible and CheckVisibility(player) == "hidden" then
            ClearSkeletonForPlayer(player.Name); _ClearJointDots(player.Name); return
        end
        local cam    = GetCamera(); if not cam then return end
        local camPos = cam.CFrame.Position
        local theirRoot = char:FindFirstChild("HumanoidRootPart")
        if not theirRoot then return end
        local dist = (camPos - theirRoot.Position).Magnitude
        if Settings.Skeleton.MaxDistance > 0 and dist > Settings.Skeleton.MaxDistance then
            ClearSkeletonForPlayer(player.Name); _ClearJointDots(player.Name); return
        end
        local dynT   = Settings.Skeleton.DynamicThickness and _mclamp(400/dist, 0.5, 2.5) or 1
        local finalT = Settings.Skeleton.Thickness * dynT
        local rigType = GetRigType(char)
        if not rigType then ClearSkeletonForPlayer(player.Name); _ClearJointDots(player.Name); return end
        local mode = Settings.Skeleton.RigMode
        if (mode == "R6" and rigType ~= "R6") or (mode == "R15" and rigType ~= "R15") then
            ClearSkeletonForPlayer(player.Name); _ClearJointDots(player.Name); return
        end
        local bones = GetBonesForRig(rigType)
        if not bones then ClearSkeletonForPlayer(player.Name); _ClearJointDots(player.Name); return end
        local data = Vars.ActiveSkeletons[player.Name]
        if not data or data.rigType ~= rigType then
            ClearSkeletonForPlayer(player.Name)
            data = { lines={}, rigType=rigType }
            Vars.ActiveSkeletons[player.Name] = data
        end
        for i, bone in ipairs(bones) do
            local line = data.lines[i] or AcquireSkeletonLine()
            data.lines[i] = line
            local a = char:FindFirstChild(bone[1])
            local b = char:FindFirstChild(bone[2])
            if a and b then
                local va, oa = cam:WorldToViewportPoint(a.Position)
                local vb, ob = cam:WorldToViewportPoint(b.Position)
                if oa and ob then
                    line.From      = _V2(va.X, va.Y)
                    line.To        = _V2(vb.X, vb.Y)
                    line.Color     = Settings.Skeleton.Color
                    line.Thickness = finalT
                    line.Visible   = true
                else line.Visible = false end
            else line.Visible = false end
        end
        for i = #bones + 1, #data.lines do data.lines[i].Visible = false end
        if Settings.Skeleton.ShowJoints then
            local jointNames = rigType == "R15"
                and {"Head","LeftHand","RightHand","LeftFoot","RightFoot"}
                or  {"Head","Left Arm","Right Arm","Left Leg","Right Leg"}
            local r = _mclamp(300/dist, 1.5, 4)
            for _, jn in ipairs(jointNames) do
                local dot  = _GetJointDot(player.Name, jn)
                local part = char:FindFirstChild(jn)
                if part then
                    local vp, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        dot.Position = _V2(vp.X, vp.Y)
                        dot.Radius   = r
                        dot.Color    = Settings.Skeleton.Color
                        dot.Visible  = true
                    else dot.Visible = false end
                else dot.Visible = false end
            end
        else
            local dots = _skeletonJointDots[player.Name]
            if dots then for _, d in pairs(dots) do d.Visible = false end end
        end
    end
    Vars.UpdateSkeletonForPlayer = UpdateSkeletonForPlayer

    local ItemESPList = Vars.ItemESPList

    local function IsItemPart(part)
        if not part or not part:IsA("BasePart") then return false end
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then return false end
        local n = part.Name:lower()
        if n:find("weapon") or n:find("gun") or n:find("collectible")
            or n:find("pickup") or n:find("item") or n:find("loot") then return true end
        if part.Parent and part.Parent:IsA("Tool") then return true end
        return false
    end
    Vars.IsItemPart = IsItemPart

    local function CreateItemESP(part)
        if not part or not part.Parent then return end
        if ItemESPList[part] then return end
        if not Settings.ESP.Enabled or not Settings.ESP.Items then return end
        if not IsItemPart(part) then return end
        local label = Drawing.new("Text")
        label.Size         = Settings.ESP.ItemTextSize or 14
        label.Center       = true; label.Outline = true
        label.OutlineColor = Color3.new(0,0,0)
        label.Font         = 2
        label.Color        = Settings.ESP.ItemColor or Color3.fromRGB(255,255,100)
        label.Visible      = false
        label.Text         = part.Name
        ItemESPList[part]  = label
    end
    Vars.CreateItemESP = CreateItemESP

    local function ClearItemESP()
        for _, label in pairs(ItemESPList) do pcall(function() label:Remove() end) end
        _tclr(ItemESPList)
    end
    Vars.ClearItemESP = ClearItemESP

    local function UpdateItemESP()
        if not Settings.ESP.Enabled or not Settings.ESP.Items then
            for _, l in pairs(ItemESPList) do l.Visible = false end
            return
        end
        local cam     = GetCamera(); if not cam then return end
        local lpRoot  = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local maxDist = Settings.ESP.ItemMaxDistance or 0
        for part, label in pairs(ItemESPList) do
            if not part or not part.Parent then
                pcall(function() label:Remove() end); ItemESPList[part] = nil
            else
                local show = not (lpRoot and maxDist > 0 and
                    (part.Position - lpRoot.Position).Magnitude > maxDist)
                if show then
                    local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        label.Position = _V2(sp.X, sp.Y)
                        label.Color    = Settings.ESP.ItemColor
                        label.Size     = Settings.ESP.ItemTextSize
                        label.Text     = part.Name
                        label.Visible  = true
                    else label.Visible = false end
                else label.Visible = false end
            end
        end
    end
    Vars.UpdateItemESP = UpdateItemESP

    Vars.itemAddedConn = Vars.Workspace.DescendantAdded:Connect(function(desc)
        if Vars.isScriptUnloaded then return end
        if desc:IsA("BasePart") and IsItemPart(desc) then
            task.defer(function() pcall(CreateItemESP, desc) end)
        end
    end)
    Vars.itemRemovingConn = Vars.Workspace.DescendantRemoving:Connect(function(desc)
        if Vars.isScriptUnloaded then return end
        local label = ItemESPList[desc]
        if label then pcall(function() label:Remove() end); ItemESPList[desc] = nil end
    end)

    local function RebuildActivePlayers()
        Vars.activePlayers = {}
        for _, p in ipairs(Vars.Players:GetPlayers()) do
            if p ~= LP then _tins(Vars.activePlayers, p) end
        end
    end
    Vars.RebuildActivePlayers = RebuildActivePlayers
    RebuildActivePlayers()

    Vars.espSkeletonConn = Vars.RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        local now     = _clock()
        local players = Vars.activePlayers
        if not players or #players == 0 then return end
        if Settings.ESP.Enabled then
            local espRate = Settings.Performance.ESPUpdateRate or 0.03
            if (now - Vars.lastESPUpdate) >= espRate then
                Vars.lastESPUpdate = now
                for i = 1, #players do SilentPcall(UpdateESPForPlayer, players[i]) end
                if Settings.ESP.Items then SilentPcall(UpdateItemESP) end
            end
        end
        if Settings.Skeleton.Enabled then
            local skRate = Settings.Performance.SkeletonUpdateRate or 0.04
            if (now - Vars.lastSkeletonUpdate) >= skRate then
                Vars.lastSkeletonUpdate = now
                for i = 1, #players do SilentPcall(UpdateSkeletonForPlayer, players[i]) end
            end
        end
    end)
end

-- ============================================================
-- BLOQUE 5: HUD / Lighting
-- ============================================================
do
    local Players   = Vars.Players
    local RunService= Vars.RunService
    local Stats     = Vars.Stats
    local Lighting  = Vars.Lighting
    local LP        = Vars.LP
    local Settings  = Vars.Settings
    local GetCamera = Vars.GetCamera

    local HudBackground = Drawing.new("Square")
    HudBackground.Filled = true; HudBackground.Color = Color3.fromRGB(12,12,12)
    HudBackground.Transparency = 0.35; HudBackground.Visible = false
    Vars.HudBackground = HudBackground

    local HudAccentLine = Drawing.new("Line")
    HudAccentLine.Thickness = 2; HudAccentLine.Color = Color3.fromRGB(0,200,255)
    HudAccentLine.Visible = false; Vars.HudAccentLine = HudAccentLine

    local HudLabel = Drawing.new("Text")
    HudLabel.Visible = false; HudLabel.Size = 15; HudLabel.Outline = true
    HudLabel.Color = Color3.fromRGB(240,240,240); HudLabel.Font = 2
    Vars.HudLabel = HudLabel

    local HudRightLabel = Drawing.new("Text")
    HudRightLabel.Visible = false; HudRightLabel.Size = 15; HudRightLabel.Outline = true
    HudRightLabel.Color = Color3.fromRGB(255,220,0); HudRightLabel.Font = 2
    Vars.HudRightLabel = HudRightLabel

    local cachedFPS = 60; local cachedPing = 0
    local frameCount = 0; local lastFPSReset = _clock()

    local function GetPing()
        local ok, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        return (ok and ping) and _mfloor(ping) or 0
    end
    Vars.GetPing = GetPing

    Vars.fpsCounterConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        frameCount = frameCount + 1
        local now = _clock()
        if (now - lastFPSReset) >= 1 then
            cachedFPS = frameCount; frameCount = 0; lastFPSReset = now
        end
    end)
    Vars.pingUpdateConn = RunService.Heartbeat:Connect(function()
        if Vars.isScriptUnloaded then return end
        pcall(function() cachedPing = GetPing() end)
    end)

    Vars.hudConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        if not Settings.HUD.Enabled then
            HudLabel.Visible = false; HudRightLabel.Visible = false
            HudBackground.Visible = false; HudAccentLine.Visible = false
            return
        end
        local cam = GetCamera(); if not cam then return end
        local viewport = cam.ViewportSize
        local leftParts = {}
        if Settings.HUD.ShowPing  then _tins(leftParts, "PING " .. cachedPing .. "ms") end
        if Settings.HUD.ShowFPS   then _tins(leftParts, "FPS "  .. cachedFPS) end
        if Vars.TargetManager then
            local t = Vars.TargetManager:GetCurrentTarget()
            _tins(leftParts, "TARGET " .. (t and t.player.Name or "None"))
        end
        local hkName = Settings.Hotkeys.ToggleMenu and Settings.Hotkeys.ToggleMenu.Name or "?"
        _tins(leftParts, "MENU " .. hkName)
        if Vars.TeamManager then
            _tins(leftParts, "TEAM[" .. Settings.Aimbot.TeamMethod .. "]: " .. Vars.TeamManager:GetMyTeamName())
        end
        if Settings.Advanced.FPSBooster_Enabled        then _tins(leftParts, "FPSBOOST") end
        if Settings.WeaponMods.NoRecoil                then _tins(leftParts, "NORECOIL") end
        if Settings.WallbangSettings.Enabled           then _tins(leftParts, "WALLBANG") end
        if Settings.Crosshair.Enabled                  then _tins(leftParts, "XHAIR") end
        if Settings.Triggerbot.Enabled                 then _tins(leftParts, "TRIGGER") end
        local rightText = ""
        if Settings.Aimbot.Enabled then
            local mode = Settings.Aimbot.AimPartMode
            if mode == "Nearest" then
                rightText = "AIM Nearest (" .. (Vars.currentNearestPartName or "Searching") .. ")"
            elseif mode == "Head" then
                rightText = "AIM Head"
            end
        end
        if cachedFPS >= 60    then HudLabel.Color = Color3.fromRGB(0,255,120)
        elseif cachedFPS >= 30 then HudLabel.Color = Color3.fromRGB(255,220,0)
        else                        HudLabel.Color = Color3.fromRGB(255,60,60) end
        HudLabel.Text      = _tcat(leftParts, "  |  ")
        HudRightLabel.Text = rightText
        local barH = 24; local barY = viewport.Y - barH - 6
        local barX = 8;  local barW = viewport.X - 16
        HudBackground.Size     = _V2(barW, barH)
        HudBackground.Position = _V2(barX, barY); HudBackground.Visible = true
        HudAccentLine.From     = _V2(barX,       barY)
        HudAccentLine.To       = _V2(barX + barW, barY)
        HudAccentLine.Color    = HudLabel.Color; HudAccentLine.Visible = true
        HudLabel.Position      = _V2(barX + 12,       barY + 4); HudLabel.Visible = true
        if rightText ~= "" then
            HudRightLabel.Position = _V2(barX + barW - 260, barY + 4); HudRightLabel.Visible = true
        else HudRightLabel.Visible = false end
    end)

    Vars.playerAddedConn = Players.PlayerAdded:Connect(function(p)
        if p ~= LP then Vars.RebuildActivePlayers() end
    end)
    Vars.playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
        Vars.RemoveESPForPlayer(p.Name)
        Vars.ClearSkeletonForPlayer(p.Name)
        if Vars._ClearJointDots then Vars._ClearJointDots(p.Name) end
        Vars.visibilityCache[p.Name]  = nil
        Vars.positionHistory[p.Name]  = nil
        Vars.RebuildActivePlayers()
    end)
    Vars.localCharConn = LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        Vars.ClearAllSkeletons(); Vars.ClearAllESP()
        Vars.isLocalDead = false
        if Vars.RebuildIgnoreList then Vars.RebuildIgnoreList(nil) end
    end)
    Vars.localDiedConn = nil
    if LP.Character then
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            Vars.localDiedConn = hum.Died:Connect(function() Vars.isLocalDead = true end)
        end
    end

    local function SaveOriginalLighting()
        if Vars.OriginalLighting then return end
        Vars.OriginalLighting = {
            Brightness=Lighting.Brightness, FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
            FogColor=Lighting.FogColor, OutdoorAmbient=Lighting.OutdoorAmbient,
            Ambient=Lighting.Ambient, GlobalShadows=Lighting.GlobalShadows,
        }
    end
    Vars.SaveOriginalLighting = SaveOriginalLighting

    local function setFullBright(enabled)
        SaveOriginalLighting()
        if enabled then
            Lighting.Brightness = 2.5; Lighting.FogEnd = 9e9; Lighting.FogStart = 0
            Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
            Lighting.Ambient        = Color3.fromRGB(180,180,180)
            Lighting.GlobalShadows  = false
        else
            local orig = Vars.OriginalLighting
            Lighting.Brightness     = orig.Brightness
            Lighting.FogEnd         = Settings.Visuals.NoFog and 9e9   or orig.FogEnd
            Lighting.FogStart       = Settings.Visuals.NoFog and 0     or orig.FogStart
            Lighting.OutdoorAmbient = orig.OutdoorAmbient
            Lighting.Ambient        = orig.Ambient
            Lighting.GlobalShadows  = orig.GlobalShadows
        end
        Settings.FullBright.Enabled = enabled
    end
    Vars.setFullBright = setFullBright

    local function setNoFog(enabled)
        SaveOriginalLighting()
        if enabled then
            Lighting.FogEnd = 9e9; Lighting.FogStart = 0
        elseif not Settings.FullBright.Enabled then
            Lighting.FogEnd   = Vars.OriginalLighting.FogEnd
            Lighting.FogStart = Vars.OriginalLighting.FogStart
        end
        Settings.Visuals.NoFog = enabled
    end
    Vars.setNoFog = setNoFog

    local function setNoBloom(enabled)
        pcall(function()
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("BloomEffect") then e.Enabled = not enabled end
            end
        end)
        Settings.Visuals.NoBloom = enabled
    end
    Vars.setNoBloom = setNoBloom

    local function setCustomFOV(enabled, value)
        local cam = Vars.GetCamera(); if not cam then return end
        if enabled then
            if not Settings.Visuals.OriginalFOV then Settings.Visuals.OriginalFOV = cam.FieldOfView end
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
        setFullBright(false); setNoFog(false); setNoBloom(false); setCustomFOV(false)
    end
    Vars.ResetAllVisuals = ResetAllVisuals

    local HIDE_BODY_PARTS  = {
        "UpperTorso","LowerTorso","Torso",
        "LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm",
        "LeftUpperLeg","LeftLowerLeg","LeftFoot",
        "RightUpperLeg","RightLowerLeg","RightFoot",
    }
    local HIDE_HANDS_PARTS = { "LeftHand","RightHand" }

    local function ApplyHideBody()
        if not LP.Character then return end
        local char = LP.Character
        for _, pn in ipairs(HIDE_BODY_PARTS) do
            local part = char:FindFirstChild(pn)
            if part and part:IsA("BasePart") then
                part.LocalTransparencyModifier = Settings.Visuals.HideBody and 1 or 0
            end
        end
        for _, pn in ipairs(HIDE_HANDS_PARTS) do
            local part = char:FindFirstChild(pn)
            if part and part:IsA("BasePart") then
                part.LocalTransparencyModifier = Settings.Visuals.HideHands and 1 or 0
            end
        end
        if Settings.Visuals.HideTool then
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local tool = (hum and hum:FindFirstChildOfClass("Tool")) or char:FindFirstChildOfClass("Tool")
            if tool then
                for _, p in ipairs(tool:GetDescendants()) do
                    if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end
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
end

-- ============================================================
-- BLOQUE 6: Tracers / NoRecoil
-- ============================================================
do
    local RunService = Vars.RunService
    local LP         = Vars.LP
    local Settings   = Vars.Settings
    local GetCamera  = Vars.GetCamera

    local function AcquireTracer()
        local t = _trem(Vars.TracerPool)
        if t then t.Visible = false; return t end
        t = Drawing.new("Line"); t.Thickness = 2; t.Visible = false; return t
    end
    local function ReleaseTracer(t)
        if not t then return end
        t.Visible = false
        if #Vars.TracerPool < Vars.TracerPoolMAX then _tins(Vars.TracerPool, t)
        else pcall(function() t:Remove() end) end
    end

    local function CreateTracer(fp, tp)
        if not Settings.Visuals.BulletTracers then return end
        if not fp or not tp then return end
        if (fp - tp).Magnitude > Settings.Visuals.TracerMaxDistance then return end
        local maxA = Settings.Visuals.MaxActiveTracers or 40
        if #Vars.ActiveTracers >= maxA then
            local oldest = _trem(Vars.ActiveTracers, 1)
            if oldest then ReleaseTracer(oldest.tracer) end
        end
        local tr = AcquireTracer()
        tr.Color       = Settings.Visuals.TracerColor
        tr.Thickness   = Settings.Visuals.TracerThickness
        tr.Transparency= 0; tr.Visible = true
        _tins(Vars.ActiveTracers, {
            tracer=tr, fromPos=fp, toPos=tp,
            startTime=_clock(), lifetime=Settings.Visuals.TracerLifetime,
        })
    end
    Vars.CreateTracer = CreateTracer

    local function UpdateTracers()
        if Vars.isScriptUnloaded then return end
        local cam = GetCamera(); if not cam then return end
        local now = _clock()
        local i   = 1
        while i <= #Vars.ActiveTracers do
            local d   = Vars.ActiveTracers[i]
            local age = now - d.startTime
            if age >= d.lifetime then
                ReleaseTracer(d.tracer); _trem(Vars.ActiveTracers, i)
            else
                local v1, o1 = cam:WorldToViewportPoint(d.fromPos)
                local v2, o2 = cam:WorldToViewportPoint(d.toPos)
                if o1 or o2 then
                    d.tracer.From         = _V2(v1.X, v1.Y)
                    d.tracer.To           = _V2(v2.X, v2.Y)
                    d.tracer.Transparency = age / d.lifetime
                    d.tracer.Visible      = true
                else d.tracer.Visible = false end
                i = i + 1
            end
        end
    end

    Vars.tracerLoopConn = RunService.RenderStepped:Connect(function() pcall(UpdateTracers) end)

    function Vars.ClearAllTracers()
        for _, d in ipairs(Vars.ActiveTracers) do ReleaseTracer(d.tracer) end
        _tclr(Vars.ActiveTracers)
        for _, t in ipairs(Vars.TracerPool) do pcall(function() t:Remove() end) end
        _tclr(Vars.TracerPool)
    end

    local function _applyNoRecoil()
        local plr = LP; if not plr then return end
        local rf  = plr:FindFirstChild("Recoil"); if not rf then return end
        local function zeroVal(v)
            if not v then return end
            if v:IsA("CFrameValue") and v.Value ~= CFrame.new() then v.Value = CFrame.new()
            elseif v:IsA("NumberValue") and v.Value ~= 0 then v.Value = 0 end
        end
        zeroVal(rf:FindFirstChild("CurrentRecoil"))
        zeroVal(rf:FindFirstChild("CurrentRecoil2"))
        zeroVal(rf:FindFirstChild("CurrentRecoil3"))
        zeroVal(rf:FindFirstChild("Recoil"))
        local char = plr.Character
        if char then
            local cr = char:FindFirstChild("Recoil")
            if cr then
                for _, c in ipairs(cr:GetDescendants()) do zeroVal(c) end
            end
        end
    end
    Vars._applyNoRecoil = _applyNoRecoil

    local noRecoilConnections = Vars.noRecoilConnections

    Vars.StartNoRecoil = function()
        if Vars.noRecoilRunning then return end
        Vars.noRecoilRunning = true
        _tins(noRecoilConnections, RunService.Stepped:Connect(function()
            if not Vars.noRecoilRunning then return end
            pcall(_applyNoRecoil)
        end))
        _tins(noRecoilConnections, RunService.Heartbeat:Connect(function()
            if not Vars.noRecoilRunning then return end
            pcall(_applyNoRecoil)
        end))
        _tins(noRecoilConnections, LP.CharacterAdded:Connect(function()
            task.wait(0.5); pcall(_applyNoRecoil)
        end))
    end

    Vars.StopNoRecoil = function()
        Vars.noRecoilRunning = false
        for _, c in ipairs(noRecoilConnections) do pcall(function() c:Disconnect() end) end
        _tclr(noRecoilConnections)
    end
end

-- ============================================================
-- BLOQUE 7: TargetManager + Aimbot + AimAssist v2 + FOV
-- ============================================================
do
    local RunService       = Vars.RunService
    local UserInputService = Vars.UserInputService
    local Players          = Vars.Players
    local LP               = Vars.LP
    local Settings         = Vars.Settings
    local GetCamera        = Vars.GetCamera
    local IsMenuOpen       = Vars.IsMenuOpen
    local CheckVisibility  = Vars.CheckVisibility
    local IsPassive        = Vars.IsPassive
    local hasGunScript     = Vars.hasGunScript
    local PredictPosition  = Vars.PredictPosition
    local GetBacktrackPosition = Vars.GetBacktrackPosition
    local GetNearestVisiblePart = Vars.GetNearestVisiblePart

    local function IsDeadBlacklisted(pn)
        local e = Vars.deadBlacklist[pn]
        if not e then return false end
        if _clock() > e then Vars.deadBlacklist[pn] = nil; return false end
        return true
    end
    local function AddToDeadBlacklist(pn)
        Vars.deadBlacklist[pn] = _clock() + Vars.DEAD_BLACKLIST_DURATION
    end
    local function IsWhitelisted(player)
        return player and Vars.whitelist[player.UserId] == true
    end

    local function ComputeFOVRadius(cam, fov)
        if not cam then return 100 end
        local half = cam.ViewportSize.X / 2
        return half * _mtan(_mrad(fov / 2)) / _mtan(_mrad((cam.FieldOfView or 70) / 2))
    end
    Vars.ComputeFOVRadius = ComputeFOVRadius

    local function ResolveAimPart(player, cam, fovCenter)
        local char = player.Character; if not char then return nil end
        local mode = Settings.Aimbot.AimPartMode
        if mode == "Nearest" then
            local p = GetNearestVisiblePart(player, cam, fovCenter)
            Vars.currentNearestPartName = p and p.Name or nil
            return p
        elseif mode == "Head" then
            local head = char:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                Vars.currentNearestPartName = "Head"
                return head
            end
            return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        end
        return char:FindFirstChild("Head")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
    end
    Vars.ResolveAimPart = ResolveAimPart

    local TargetManager  = {}
    local currentTarget  = nil

    function TargetManager:ValidateTarget(player)
        if not player or player == LP then return false end
        if IsDeadBlacklisted(player.Name) then return false end
        if not player.Character then return false end
        local char = player.Character
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        if hum.Health <= 0 then AddToDeadBlacklist(player.Name); return false end
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Dead
        or state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.Ragdoll then
            AddToDeadBlacklist(player.Name); return false
        end
        if not char:FindFirstChild("HumanoidRootPart") then AddToDeadBlacklist(player.Name); return false end
        if not char:FindFirstChild("Head") then AddToDeadBlacklist(player.Name); return false end
        if char.Parent ~= Vars.Workspace then AddToDeadBlacklist(player.Name); return false end
        return true
    end

    function TargetManager:GetCandidates()
        local candidates = {}
        if not LP.Character then return candidates end
        local lr = LP.Character:FindFirstChild("HumanoidRootPart")
        if not lr then return candidates end
        local cam       = GetCamera(); if not cam then return candidates end
        local fovCenter = Vars.helperMousePosition
        local fovRadius = ComputeFOVRadius(cam, Settings.Aimbot.FOV)
        for _, player in ipairs(Vars.activePlayers) do
            if IsWhitelisted(player)             then continue end
            if IsDeadBlacklisted(player.Name)    then continue end
            if not self:ValidateTarget(player)   then continue end
            if Settings.Aimbot.TeamCheck and Vars.TeamManager then
                if not Vars.TeamManager:IsEnemy(player) then continue end
            end
            if Settings.Aimbot.IgnorePassive and IsPassive(player.Name) then continue end
            local tr   = player.Character.HumanoidRootPart
            local dist = (lr.Position - tr.Position).Magnitude
            if Settings.Aimbot.MaxDistance > 0 and dist > Settings.Aimbot.MaxDistance then continue end
            if not Settings.WallbangSettings.Enabled and not Settings.Aimbot.Wallbang then
                if Settings.Aimbot.WallCheck then
                    local vis = CheckVisibility(player)
                    if Settings.Aimbot.StrictWallCheck and vis ~= "visible" then continue end
                    if vis == "hidden" then continue end
                end
            end
            local aimPart = ResolveAimPart(player, cam, fovCenter)
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
            local dc = (_V2(sp.X, sp.Y) - fovCenter).Magnitude
            if dc > fovRadius then continue end
            _tins(candidates, {
                player=player, part=aimPart, targetPos=tp,
                distance=dist, screenDist=dc, screenPos=sp,
                aimPartName=aimPart.Name,
            })
        end
        return candidates
    end

    function TargetManager:GetBestTarget()
        local c = self:GetCandidates()
        if #c == 0 then
            self:ClearTarget()
            Vars.targetTransition.active = false
            Vars.targetTransition.previousPlayer = nil
            return nil
        end
        local pr   = Settings.Aimbot.Priority or "FOV"
        local best, bs = nil, math.huge
        for _, x in ipairs(c) do
            local s
            if pr == "Distance" then s = x.distance
            elseif pr == "FOV"  then s = x.screenDist
            elseif pr == "Priority" then
                local prio = Settings.Aimbot.BonePriority[x.aimPartName] or 0.5
                s = x.screenDist / _mmax(prio, 0.01)
            else s = x.screenDist end
            if s < bs then bs = s; best = x end
        end
        return best
    end

    function TargetManager:LockTarget(t)
        if not t then self:ClearTarget(); return end
        if currentTarget and currentTarget.player == t.player then return end
        if currentTarget and currentTarget.part and t.part and t.part.Parent then
            local cam = GetCamera()
            Vars.targetTransition.active       = true
            Vars.targetTransition.startCFrame  = cam.CFrame
            Vars.targetTransition.targetCFrame = _CF(cam.CFrame.Position, t.part.Position)
            Vars.targetTransition.progress     = 0
            Vars.targetTransition.previousPlayer = currentTarget.player
        end
        currentTarget = t
    end

    -- v10.2: UpdateTarget con Head mode fix
    function TargetManager:UpdateTarget()
        if not currentTarget or not currentTarget.player then self:ClearTarget(); return end
        if not self:ValidateTarget(currentTarget.player) then self:ClearTarget(); return end
        if IsWhitelisted(currentTarget.player) then self:ClearTarget(); return end
        if Settings.Aimbot.TeamCheck and Vars.TeamManager then
            if not Vars.TeamManager:IsEnemy(currentTarget.player) then self:ClearTarget(); return end
        end
        local lr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not lr then self:ClearTarget(); return end
        local d = (currentTarget.player.Character.HumanoidRootPart.Position - lr.Position).Magnitude
        if Settings.Aimbot.MaxDistance > 0 and d > Settings.Aimbot.MaxDistance then self:ClearTarget(); return end

        local cam       = GetCamera()
        local fovCenter = Vars.helperMousePosition
        local fovRadius = ComputeFOVRadius(cam, Settings.Aimbot.FOV)

        -- HEAD MODE FIX: si Head salió de pantalla o del FOV → clear inmediato, sin atasco
        if Settings.Aimbot.AimPartMode == "Head" then
            if not Vars.ValidateHeadTarget(currentTarget.player, cam, fovCenter, fovRadius) then
                self:ClearTarget(); return
            end
        end

        local aimPart = ResolveAimPart(currentTarget.player, cam, fovCenter)
        if not aimPart then self:ClearTarget(); return end
        currentTarget.part        = aimPart
        currentTarget.targetPos   = aimPart.Position
        currentTarget.aimPartName = aimPart.Name
    end

    function TargetManager:ClearTarget()
        currentTarget = nil
        Vars.currentNearestPartName = nil
    end
    function TargetManager:GetCurrentTarget() return currentTarget end
    function TargetManager:AddToWhitelist(player)
        if Vars.whitelist[player.UserId] then Vars.whitelist[player.UserId] = nil
        else                                  Vars.whitelist[player.UserId] = true end
        if currentTarget and currentTarget.player == player then self:ClearTarget() end
    end
    function TargetManager:IsWhitelisted(player) return IsWhitelisted(player) end
    Vars.TargetManager = TargetManager

    local function GetEasedFraction(t, style)
        t = _mclamp(t, 0, 1)
        if style == "Linear"    then return t
        elseif style == "EaseOut" then return 1 - (1-t)^3
        else return t < 0.5 and (2*t*t) or (1 - (-2*t+2)^2/2) end
    end

    local lastFrameTime = 0; local lastSwitchTime = 0; local jitterSeed = 0

    local function MainAimbotLoop()
        if Vars.isScriptUnloaded or not Settings.Aimbot.Enabled then return end
        if Vars.isLocalDead or IsMenuOpen() then return end
        if type(isrbxactive) == "function" and not isrbxactive() then return end
        if Settings.Aimbot.RequireGun and not hasGunScript(LP.Character) then
            TargetManager:ClearTarget()
            Vars.targetTransition.active = false
            return
        end

        Vars.helperMousePosition = UserInputService:GetMouseLocation()
        local now = _clock()
        local dt  = _mclamp(now - lastFrameTime, 0.001, 0.5)
        lastFrameTime = now

        local held = Settings.Aimbot.AimKeyType == "Key"
            and Vars.aimKeyHeld
            or UserInputService:IsMouseButtonPressed(Settings.Aimbot.AimMouseButton)
        if not held then
            Vars.targetTransition.active = false
            return
        end

        if TargetManager:GetCurrentTarget() then TargetManager:UpdateTarget() end

        if Settings.WallbangSettings.Enabled and Vars.WallbangGetTarget then
            local wbHit = Vars.WallbangGetTarget()
            if wbHit and wbHit.player and wbHit.part then
                local wbCandidate = {
                    player      = wbHit.player,
                    part        = wbHit.part,
                    targetPos   = wbHit.hitPos,
                    aimPartName = wbHit.part.Name,
                }
                if not (TargetManager:GetCurrentTarget()
                    and TargetManager:GetCurrentTarget().player == wbHit.player) then
                    TargetManager:LockTarget(wbCandidate)
                    lastSwitchTime = now
                end
            end
        end

        local current    = TargetManager:GetCurrentTarget()
        local canSwitch  = not current
            or (now - lastSwitchTime) >= (Settings.Aimbot.SwitchCooldown or 0.45)

        if not current or (Settings.Aimbot.HumanMode and canSwitch) then
            local best = TargetManager:GetBestTarget()
            if best then
                local keep = false
                if current and Settings.Aimbot.HumanMode then
                    local cam = GetCamera()
                    if current.part and current.part.Parent and best.part and best.part.Parent then
                        local ap, oA = cam:WorldToViewportPoint(current.part.Position)
                        local bp, oB = cam:WorldToViewportPoint(best.part.Position)
                        if oA and oB then
                            local dx = ap.X - bp.X; local dy = ap.Y - bp.Y
                            if (dx*dx + dy*dy) < (Settings.Aimbot.SwitchRange or 40)^2 then keep = true end
                        end
                    end
                end
                if not keep then
                    TargetManager:LockTarget(best)
                    lastSwitchTime = now
                    local cam = GetCamera()
                    Vars.targetTransition.active       = true
                    Vars.targetTransition.startCFrame  = cam.CFrame
                    Vars.targetTransition.targetCFrame = _CF(cam.CFrame.Position, best.part.Position)
                    Vars.targetTransition.progress     = 0
                    Vars.targetTransition.duration     = Vars.TARGET_TRANSITION_DURATION
                    Vars.targetTransition.previousPlayer = current and current.player or nil
                end
            end
        end

        local t = TargetManager:GetCurrentTarget()
        if not t then return end
        local ap = t.part
        if not ap or not ap.Parent then TargetManager:ClearTarget(); return end

        if Vars.targetTransition.active then
            Vars.targetTransition.progress = Vars.targetTransition.progress
                + dt / Vars.targetTransition.duration
            if Vars.targetTransition.progress >= 1 then
                Vars.targetTransition.progress = 1
                Vars.targetTransition.active   = false
            end
            local cam    = GetCamera()
            local eased  = GetEasedFraction(Vars.targetTransition.progress, Settings.Aimbot.EaseStyle)
            Vars.targetTransition.targetCFrame = _CF(cam.CFrame.Position, ap.Position)
            pcall(function()
                cam.CFrame = Vars.targetTransition.startCFrame:Lerp(
                    Vars.targetTransition.targetCFrame, eased)
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

        if Settings.Aimbot.Humanize then
            jitterSeed = jitterSeed + dt * (Settings.Aimbot.JitterSpeed or 12)
            local jit  = Settings.Aimbot.JitterAmount or 0.35
            aimPos = aimPos + _V3(
                _msin(jitterSeed * 6.28) * jit * 0.01,
                _mcos(jitterSeed * 5.13) * jit * 0.01,
                _msin(jitterSeed * 7.71) * jit * 0.01
            )
        end

        local sm  = (Vars.aimbotHelperActive and Settings.Aimbot.HelperSmoothness or Settings.Aimbot.BaseSmoothness)
        local cam = GetCamera()

        if Settings.Aimbot.Method == "Camera" then
            if sm >= 1 then return end
            local tcf = _CF(cam.CFrame.Position, aimPos)
            if sm <= 0 then
                pcall(function() cam.CFrame = tcf end)
            else
                pcall(function()
                    cam.CFrame = cam.CFrame:Lerp(tcf, _mclamp(1 - sm, 0.01, 1))
                end)
            end
        else
            local sp = cam:WorldToViewportPoint(aimPos)
            local d  = _V2(sp.X - Vars.helperMousePosition.X, sp.Y - Vars.helperMousePosition.Y)
            if d.Magnitude > 0.5 then
                local f = sm <= 0 and 1 or _mclamp(1 - sm, 0.01, 1)
                mousemoverel(d.X * f, d.Y * f)
            end
        end
    end

    Vars.aimbotConn = RunService.RenderStepped:Connect(function() pcall(MainAimbotLoop) end)

    local fovCircle    = nil
    local fovFillCircle= nil
    local fovCenterDot = nil

    local function _updateFOVVisuals()
        if Vars.isScriptUnloaded then return end
        local show = Settings.Aimbot.FOVShowCircle and Settings.Aimbot.Enabled and not IsMenuOpen()
        fovCircle     = fovCircle     or Drawing.new("Circle")
        fovFillCircle = fovFillCircle or (function()
            local c = Drawing.new("Circle"); c.Filled = true; return c end)()
        fovCenterDot  = fovCenterDot  or (function()
            local c = Drawing.new("Circle"); c.Filled = true; return c end)()
        if not show then
            fovCircle.Visible    = false
            fovFillCircle.Visible= false
            fovCenterDot.Visible = false
            return
        end
        local cam    = GetCamera(); if not cam then return end
        local mp     = UserInputService:GetMouseLocation()
        local center = _V2(mp.X, mp.Y)
        local radius = ComputeFOVRadius(cam, Settings.Aimbot.FOV)
        fovFillCircle.Position    = center; fovFillCircle.Radius = radius
        fovFillCircle.Color       = Settings.Aimbot.FOVFillColor
        fovFillCircle.Transparency= Settings.Aimbot.FOVFillTransparency
        fovFillCircle.NumSides    = Settings.Aimbot.FOVNumSides or 60
        fovFillCircle.Visible     = Settings.Aimbot.FOVFilled
        fovCircle.Position    = center; fovCircle.Radius = radius
        fovCircle.Color       = Settings.Aimbot.FOVOutlineColor
        fovCircle.Thickness   = Settings.Aimbot.FOVOutlineThickness
        fovCircle.Transparency= Settings.Aimbot.FOVOutlineTransparency
        fovCircle.NumSides    = Settings.Aimbot.FOVNumSides or 60
        fovCircle.Visible     = true
        fovCenterDot.Position    = center
        fovCenterDot.Radius      = Settings.Aimbot.FOVCenterDotSize
        fovCenterDot.Color       = Settings.Aimbot.FOVCenterDotColor
        fovCenterDot.Transparency= Settings.Aimbot.FOVCenterDotTransparency
        fovCenterDot.Visible     = Settings.Aimbot.FOVCenterDot
    end

    Vars.fovConn = RunService.RenderStepped:Connect(function() pcall(_updateFOVVisuals) end)
    Vars.GetFOVCircle = function() return fovCircle end

    -- ============================================================
    -- AIM ASSIST v2 — fuerza adaptativa, deadzone, edge falloff
    -- ============================================================
    local aaJitterSeed = 0

    local function AimAssistLoop(dt)
        if Vars.isScriptUnloaded or not Settings.AimAssist.Enabled then return end
        if Vars.isLocalDead or IsMenuOpen() then return end
        if type(isrbxactive) == "function" and not isrbxactive() then return end
        if not dt or dt <= 0 then dt = 0.016 end
        if dt > 0.5 then dt = 0.5 end

        local now          = _clock()
        local currentMouse = UserInputService:GetMouseLocation()
        local mouseDelta   = (currentMouse - Vars.aimAssistLastMousePos).Magnitude
        Vars.aimAssistLastMousePos = currentMouse
        Vars.helperMousePosition   = currentMouse

        if mouseDelta >= (Settings.AimAssist.MouseMovementThreshold or 0.5) then
            Vars.aimAssistLastMovementTime = now
        end
        if Settings.AimAssist.RequireMouseMovement
            and (now - Vars.aimAssistLastMovementTime) >= 0.2 then return end

        if not LP.Character then return end
        local lr = LP.Character:FindFirstChild("HumanoidRootPart"); if not lr then return end
        local cam = GetCamera(); if not cam then return end
        local center    = currentMouse
        local fovRadius = ComputeFOVRadius(cam, Settings.AimAssist.FOV)

        local best, bestDist = nil, math.huge
        for _, player in ipairs(Vars.activePlayers) do
            if not player or player == LP then continue end
            if IsWhitelisted(player) or IsDeadBlacklisted(player.Name) then continue end
            if not player.Character then continue end
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            if Settings.AimAssist.TeamCheck and Vars.TeamManager then
                if not Vars.TeamManager:IsEnemy(player) then continue end
            end
            if Settings.AimAssist.IgnorePassive and IsPassive(player.Name) then continue end
            local tr = player.Character:FindFirstChild("HumanoidRootPart"); if not tr then continue end
            local dist = (lr.Position - tr.Position).Magnitude
            if Settings.AimAssist.MaxDistance > 0 and dist > Settings.AimAssist.MaxDistance then continue end
            if Settings.AimAssist.WallCheck then
                local vis = CheckVisibility(player)
                if vis == "hidden" then continue end
            end

            -- Parte más cercana al cursor usando GetNearestVisiblePart
            local part = GetNearestVisiblePart(player, cam, center)
            if not part then continue end

            local tp = part.Position
            if Settings.AimAssist.UsePrediction then
                tp = PredictPosition(tr, Settings.AimAssist.PredictionAmount, false) or tp
            end
            local sp, onScreen = cam:WorldToViewportPoint(tp)
            if not onScreen then continue end
            local dc = (_V2(sp.X, sp.Y) - center).Magnitude
            if dc <= fovRadius and dc < bestDist then
                bestDist = dc
                best = { player=player, part=part, targetPos=tp, screenDist=dc }
            end
        end

        if not best then return end

        local sp, onScreen = cam:WorldToViewportPoint(best.targetPos)
        if not onScreen then return end

        -- Deadzone: muy cerca del target → no hacer nada (evita vibración)
        local deadzone = Settings.AimAssist.Deadzone or 3
        if best.screenDist <= deadzone then return end

        local curCF    = cam.CFrame
        local targetCF = _CF(curCF.Position, best.targetPos)
        local angleDeg = math.deg(curCF.LookVector:Angle(targetCF.LookVector))
        if angleDeg < 0.05 then return end

        -- Edge falloff: cuadrático, fuerza máxima en el centro del FOV, mínima en el borde
        local fovNorm     = _mclamp(best.screenDist / _mmax(fovRadius, 1), 0, 1)
        local edgeFalloff = 1 - fovNorm * fovNorm
        local strength    = (Settings.AimAssist.Strength or 0.6) * edgeFalloff

        local smooth      = _mclamp(Settings.AimAssist.Smoothness or 0.5, 0.01, 0.99)
        local maxSpeedDeg = (Settings.AimAssist.MaxSpeed or 30) * (1 - smooth) * strength
        local maxRotRad   = _mrad(_mmax(maxSpeedDeg, 0.1))
        local maxRot      = maxRotRad * dt

        local fraction = _mclamp(maxRot / _mrad(_mmax(angleDeg, 0.01)), 0, 1) * strength

        -- HumanMode: reducir fuerza progresivamente al acercarse
        if Settings.AimAssist.HumanMode then
            if angleDeg < 15 then fraction = fraction * 0.7 end
            if angleDeg < 5  then fraction = fraction * 0.4 end
            if angleDeg < 2  then fraction = fraction * 0.15 end
            -- Micro jitter humanizador
            aaJitterSeed = aaJitterSeed + dt * 8
            local j = 0.003
            best.targetPos = best.targetPos + _V3(
                _msin(aaJitterSeed * 5.1) * j,
                _mcos(aaJitterSeed * 6.3) * j,
                0
            )
        end

        local finalCF = _CF(curCF.Position, best.targetPos)
        pcall(function() cam.CFrame = curCF:Lerp(finalCF, _mclamp(fraction, 0, 0.35)) end)
    end

    Vars.StartAimAssist = function()
        if Vars.aimAssistConnection then return end
        Vars.aimAssistActive          = true
        Vars.aimAssistLastMousePos    = UserInputService:GetMouseLocation()
        Vars.aimAssistLastMovementTime= 0
        Vars.aimAssistConnection = RunService.RenderStepped:Connect(function(dt)
            pcall(AimAssistLoop, dt)
        end)
        if not Vars.aimAssistFOVCircle then
            Vars.aimAssistFOVCircle = Drawing.new("Circle")
            Vars.aimAssistFOVCircle.Filled  = false
            Vars.aimAssistFOVCircle.Visible = false
        end
        if not Vars.aimAssistFOVConn then
            Vars.aimAssistFOVConn = RunService.RenderStepped:Connect(function()
                if Vars.isScriptUnloaded or not Vars.aimAssistFOVCircle then return end
                local show = Settings.AimAssist.ShowFOV
                    and Settings.AimAssist.Enabled and not IsMenuOpen()
                Vars.aimAssistFOVCircle.Visible = show
                if show then
                    local cam = GetCamera()
                    local r   = ComputeFOVRadius(cam, Settings.AimAssist.FOV)
                    local mp  = UserInputService:GetMouseLocation()
                    Vars.aimAssistFOVCircle.Position  = _V2(mp.X, mp.Y)
                    Vars.aimAssistFOVCircle.Radius    = r
                    Vars.aimAssistFOVCircle.Color     = Settings.AimAssist.FOVColor
                    Vars.aimAssistFOVCircle.Thickness = Settings.AimAssist.FOVThickness
                end
            end)
        end
    end

    Vars.StopAimAssist = function()
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

    Vars.aimKeyBeganConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Settings.Hotkeys.Helper then
            Vars.aimbotHelperActive = not Vars.aimbotHelperActive
            local w = _env.TownUI_Window
            if w and w.Notify then
                pcall(w.Notify, w, "Helper",
                    Vars.aimbotHelperActive and "Aim: Helper mode" or "Aim: Base mode", 1.5, "Info")
            end
        end
        if input.KeyCode == Settings.Aimbot.AimKey then Vars.aimKeyHeld = true end
    end)
    Vars.aimKeyEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Settings.Aimbot.AimKey then Vars.aimKeyHeld = false end
    end)
end

-- ============================================================
-- BLOQUE 8: FPS Booster + Camera Fixes
-- ============================================================
do
    local RunService = Vars.RunService
    local LP         = Vars.LP
    local Settings   = Vars.Settings
    local Workspace  = Vars.Workspace
    local Lighting   = Vars.Lighting
    local GetCamera  = Vars.GetCamera

    local function ApplyFPSBooster(state)
        Settings.Advanced.FPSBooster_Enabled = state
        if state then
            if Vars.fpsBoosterActive then return end
            Vars.fpsBoosterActive = true
            Vars.fpsBoosterOriginalMaterials = {}
            Vars.fpsBoosterOriginalLighting  = {
                GlobalShadows=Lighting.GlobalShadows, Brightness=Lighting.Brightness,
                Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
            }
            pcall(function()
                local q = Enum.QualityLevel[Settings.Advanced.FPSBooster_QualityLevel]
                    or Enum.QualityLevel.Level01
                settings().Rendering.QualityLevel = q
            end)
            if Settings.Advanced.FPSBooster_Shadows == false then
                pcall(function() Lighting.GlobalShadows = false end)
            end
            task.spawn(function()
                task.wait(0.1)
                local targetMat = Enum.Material[Settings.Advanced.FPSBooster_MaterialTarget or "Plastic"]
                    or Enum.Material.Plastic
                local count = 0
                local ok, desc = pcall(function() return Workspace:GetDescendants() end)
                if not ok or not desc then return end
                for _, obj in ipairs(desc) do
                    if count >= 100000 then break end
                    if Vars.isScriptUnloaded or not Vars.fpsBoosterActive then break end
                    if obj:IsA("BasePart") then
                        if LP.Character and obj:IsDescendantOf(LP.Character) then continue end
                        if Vars.fpsBoosterOriginalMaterials[obj] == nil then
                            Vars.fpsBoosterOriginalMaterials[obj] = obj.Material
                        end
                        if Settings.Advanced.FPSBooster_Materials then
                            pcall(function() obj.Material = targetMat; obj.Reflectance = 0 end)
                        end
                        if Settings.Advanced.FPSBooster_Shadows == false then
                            pcall(function() obj.CastShadow = false end)
                        end
                        count = count + 1
                    end
                end
            end)
        else
            if not Vars.fpsBoosterActive then return end
            Vars.fpsBoosterActive = false
            for part, mat in pairs(Vars.fpsBoosterOriginalMaterials) do
                if part and part.Parent then pcall(function() part.Material = mat end) end
            end
            Vars.fpsBoosterOriginalMaterials = {}
            if Vars.fpsBoosterOriginalLighting then
                local orig = Vars.fpsBoosterOriginalLighting
                pcall(function()
                    Lighting.GlobalShadows  = orig.GlobalShadows
                    Lighting.Brightness     = orig.Brightness
                    Lighting.Ambient        = orig.Ambient
                    Lighting.OutdoorAmbient = orig.OutdoorAmbient
                end)
                Vars.fpsBoosterOriginalLighting = nil
            end
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Default end)
        end
    end
    Vars.ApplyFPSBooster = ApplyFPSBooster

    local function _applyNoCameraBob()
        local char = LP.Character; if not char then return end
        local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        hum.CameraOffset = _V3(hum.CameraOffset.X, 0, hum.CameraOffset.Z)
    end
    Vars._applyNoCameraBob = _applyNoCameraBob

    local function _applyNoSprintFOV()
        local char = LP.Character; if not char then return end
        local cam  = GetCamera();  if not cam  then return end
        local targetFOV = Settings.Visuals.CustomFOV
            and (Settings.Visuals.FOVValue or 70)
            or (LP:GetAttribute("FOV") or 70)
        if _mabs(cam.FieldOfView - targetFOV) > 1 then cam.FieldOfView = targetFOV end
    end
    Vars._applyNoSprintFOV = _applyNoSprintFOV

    Vars.CleanupAdvanced = function()
        pcall(function() Vars.ApplyFPSBooster(false) end)
        if Vars._camFixConn    then pcall(function() Vars._camFixConn:Disconnect() end);    Vars._camFixConn    = nil end
        if Vars._sprintFOVConn then pcall(function() Vars._sprintFOVConn:Disconnect() end); Vars._sprintFOVConn = nil end
    end
end

-- ============================================================
-- BLOQUE 8.8: Save/Load
-- ============================================================
do
    local HttpService = Vars.HttpService
    local Settings    = Vars.Settings
    local SAVE_FOLDER = Settings.Advanced.SaveFolder
    local SAVE_EXT    = Settings.Advanced.SaveExtension

    local function SavePath(n) return SAVE_FOLDER .. "/" .. n .. SAVE_EXT end
    local function EnsureFolder()
        if type(makefolder) ~= "function" then return false end
        if type(isfolder) == "function" and not isfolder(SAVE_FOLDER) then pcall(makefolder, SAVE_FOLDER) end
        return true
    end

    local function ListSaves()
        local saves = {}
        if type(listfiles) ~= "function" or type(isfolder) ~= "function" then return saves end
        if not isfolder(SAVE_FOLDER) then return saves end
        for _, file in ipairs(listfiles(SAVE_FOLDER)) do
            local name = file:match("([^/]+)" .. SAVE_EXT .. "$")
            if name then _tins(saves, name) end
        end
        return saves
    end
    Vars.ListSaves = ListSaves

    local function SerializeConfig()
        local out = {}
        for section, data in pairs(Settings) do
            if type(data) == "table" then
                out[section] = {}
                for k, v in pairs(data) do
                    if type(v) == "table" and v.R and v.G and v.B then
                        out[section][k] = { __type="Color3", R=v.R, G=v.G, B=v.B }
                    elseif type(v) == "table" and v.X and v.Y then
                        out[section][k] = { __type="Vector2", X=v.X, Y=v.Y }
                    else out[section][k] = v end
                end
            end
        end
        return out
    end

    local function DeserializeConfig(data)
        if not data then return end
        for section, tbl in pairs(data) do
            if type(Settings[section]) == "table" then
                for k, v in pairs(tbl) do
                    if type(v) == "table" and v.__type == "Color3" then
                        Settings[section][k] = Color3.new(v.R, v.G, v.B)
                    elseif type(v) == "table" and v.__type == "Vector2" then
                        Settings[section][k] = Vector2.new(v.X, v.Y)
                    else Settings[section][k] = v end
                end
            end
        end
    end

    Vars.SaveConfig = function(name)
        if not EnsureFolder() then return false end
        if not name or name == "" then name = "TOWN" end
        local data = { version="1.0", timestamp=os.time(), config=SerializeConfig() }
        local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
        if not ok then return false end
        if pcall(writefile, SavePath(name), encoded) then
            Settings.Advanced.CurrentSave = name; return true
        end
        return false
    end

    Vars.LoadConfig = function(name)
        if not name or name == "" then return false end
        if type(readfile) ~= "function" then return false end
        local ok, raw = pcall(readfile, SavePath(name))
        if not ok or not raw then return false end
        local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok2 or not decoded or not decoded.config then return false end
        DeserializeConfig(decoded.config)
        Settings.Advanced.CurrentSave = name
        return true
    end
end

-- ============================================================
-- BLOQUE 8.9: Quick Toggles
-- ============================================================
do
    local Settings = Vars.Settings

    local QuickTogglesList = {
        { name="ESP",     get=function() return Settings.ESP.Enabled end,
                           set=function(v) Settings.ESP.Enabled = v end },
        { name="Aimbot",  get=function() return Settings.Aimbot.Enabled end,
                           set=function(v) Settings.Aimbot.Enabled = v end },
        { name="AimAsst", get=function() return Settings.AimAssist.Enabled end,
                           set=function(v)
                               Settings.AimAssist.Enabled = v
                               if v then Vars.StartAimAssist() else Vars.StopAimAssist() end end },
        { name="NoRecoil",get=function() return Settings.WeaponMods.NoRecoil end,
                           set=function(v)
                               Settings.WeaponMods.NoRecoil = v
                               if v then Vars.StartNoRecoil() else Vars.StopNoRecoil() end end },
        { name="Trigger", get=function() return Settings.Triggerbot.Enabled end,
                           set=function(v) Settings.Triggerbot.Enabled = v end },
        { name="Wallbang", get=function() return Settings.WallbangSettings.Enabled end,
                           set=function(v) Settings.WallbangSettings.Enabled = v end },
        { name="XHair",   get=function() return Settings.Crosshair.Enabled end,
                           set=function(v) Settings.Crosshair.Enabled = v end },
        { name="FPSBoost",get=function() return Settings.Advanced.FPSBooster_Enabled end,
                           set=function(v) Vars.ApplyFPSBooster(v) end },
    }

    local function CreateQuickToggles()
        if Vars.quickTogglesGui and Vars.quickTogglesGui.Parent then
            Vars.quickTogglesGui:Destroy()
        end
        pcall(function()
            local parent
            if type(gethui) == "function" then
                local ok, hui = pcall(gethui)
                if ok and hui then parent = hui end
            end
            parent = parent or Vars.CoreGui
            if not parent then return end
            local sg = Instance.new("ScreenGui")
            sg.Name = "TC_QuickToggles"; sg.ResetOnSpawn = false
            sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = parent
            local main = Instance.new("Frame")
            main.Size = UDim2.new(0, 105, 0, #QuickTogglesList * 26 + 10)
            main.Position = UDim2.new(0, 10, 0.5, -150)
            main.BackgroundColor3 = Color3.fromRGB(20,20,20)
            main.BackgroundTransparency = 0.4; main.BorderSizePixel = 0; main.Parent = sg
            local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = main
            local layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 4); layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.VerticalAlignment   = Enum.VerticalAlignment.Center; layout.Parent = main
            for i, item in ipairs(QuickTogglesList) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0, 95, 0, 22)
                btn.BackgroundColor3 = item.get() and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
                btn.Text = item.name; btn.TextColor3 = Color3.new(1,1,1)
                btn.TextSize = 12; btn.Font = Enum.Font.Code; btn.BorderSizePixel = 0
                btn.LayoutOrder = i; btn.Parent = main
                local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 4); c2.Parent = btn
                btn.MouseButton1Click:Connect(function()
                    local ns = not item.get()
                    item.set(ns)
                    btn.BackgroundColor3 = ns and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
                end)
                task.spawn(function()
                    while btn.Parent and not Vars.isScriptUnloaded do
                        local cur = item.get()
                        local exp = cur and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
                        if btn.BackgroundColor3 ~= exp then btn.BackgroundColor3 = exp end
                        task.wait(0.3)
                    end
                end)
            end
            Vars.quickTogglesGui = sg
        end)
    end

    Vars.qtConn = Vars.RunService.Heartbeat:Connect(function()
        if Vars.isScriptUnloaded then return end
        if not Settings.Advanced.QT_Enabled then
            if Vars.quickTogglesGui and Vars.quickTogglesGui.Enabled then
                Vars.quickTogglesGui.Enabled = false
            end
            return
        end
        if not Vars.quickTogglesGui or not Vars.quickTogglesGui.Parent then
            CreateQuickToggles()
        elseif not Vars.quickTogglesGui.Enabled then
            Vars.quickTogglesGui.Enabled = true
        end
    end)
end

-- ============================================================
-- BLOQUE 9: UI (Scryux)
-- ============================================================
do
    local Settings         = Vars.Settings
    local UserInputService = Vars.UserInputService

    local Window
    do
        local ok, result = pcall(function()
            return ScryuxUI:CreateWindow({
                Title = "Town Complete v10.2 (PVP)",
                Size = UDim2.new(0, 800, 0, 680),
                Keybind = Settings.Hotkeys.ToggleMenu,
                Theme = "Dark", Acrylic = true,
                SaveFolder = "TownComplete_Settings/" .. tostring(game.PlaceId),
                FloatingIcon = true, SearchBar = false, ShowSearch = false,
                Draggable = true, Resizable = true, CornerRadius = 8,
                Shadow = true, Transparency = 0.95,
            })
        end)
        if not ok then
            realPrint("[TownComplete] CreateWindow ERROR: " .. tostring(result))
            _env.print = realPrint; _env.warn = realWarn; return
        end
        Window = result
    end
    _env.TownUI_Window = Window; Vars.Window = Window

    -- ===== ESP Tab =====
    local ESPTab  = Window:CreateTab("ESP")
    local ESPMain = ESPTab:CreateSection("ESP Master")
    ESPMain:CreateToggle({ Text="ESP Master", Default=false, Index="ESP_Enabled",
        Callback=function(v) Settings.ESP.Enabled = v end })
    ESPMain:CreateToggle({ Text="Team Indicator", Default=true, Index="ESP_TeamIndicator",
        Callback=function(v)
            Settings.ESP.ShowTeamIndicator = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do
                    if esp.teamSquare then esp.teamSquare.Visible = false end
                end
            end
        end })
    ESPMain:CreateColorpicker({ Text="Team Color", Default=Color3.fromRGB(60,130,255), Index="ESP_TeamColor",
        Callback=function(c) Settings.ESP.TeamIndicatorColor = c end })
    ESPMain:CreateColorpicker({ Text="Enemy Color", Default=Color3.fromRGB(255,50,50), Index="ESP_EnemyColor",
        Callback=function(c) Settings.ESP.EnemyIndicatorColor = c end })

    -- Off-Screen ESP (v10.2)
    local OSSection = ESPTab:CreateSection("Off-Screen Indicators")
    OSSection:CreateToggle({ Text="Off-Screen ESP", Default=false, Index="OS_Enabled",
        Callback=function(v) Settings.OffscreenESP.Enabled = v end })
    OSSection:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(255,100,100), Index="OS_Color",
        Callback=function(c) Settings.OffscreenESP.Color = c end })
    OSSection:CreateSlider({ Text="Radio (px desde centro)", Min=50, Max=500, Default=200, Index="OS_Radius",
        Callback=function(v) Settings.OffscreenESP.Radius = v end })
    OSSection:CreateSlider({ Text="Tamaño del triángulo", Min=5, Max=40, Default=15, Index="OS_Size",
        Callback=function(v) Settings.OffscreenESP.Size = v end })

    local ESPsSection = ESPTab:CreateSection("Active Elements")
    ESPsSection:CreateToggle({ Text="Box", Default=false, Index="ESP_Box",
        Callback=function(v)
            Settings.ESP.Box = v
            if not v then for _, esp in pairs(Vars.ESPPool) do esp.box.Visible = false end end
        end })
    ESPsSection:CreateSlider({ Text="Box Thickness", Min=1, Max=5, Default=1, Index="ESP_BoxThickness",
        Callback=function(v) Settings.ESP.BoxThickness = v end })
    ESPsSection:CreateSlider({ Text="Box Padding", Min=0, Max=3, Default=0.5, Index="ESP_BoxPadding",
        Callback=function(v) Settings.ESP.BoxPadding = v end })
    ESPsSection:CreateToggle({ Text="Name", Default=false, Index="ESP_Names",
        Callback=function(v) Settings.ESP.ShowName = v end })
    ESPsSection:CreateToggle({ Text="Health Bar", Default=false, Index="ESP_Health",
        Callback=function(v) Settings.ESP.ShowHealth = v end })
    ESPsSection:CreateToggle({ Text="Show Distance", Default=false, Index="ESP_Distance",
        Callback=function(v) Settings.ESP.ShowDistance = v end })
    ESPsSection:CreateToggle({ Text="Head Dots", Default=false, Index="ESP_HeadDots",
        Callback=function(v)
            Settings.ESP.HeadDots = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do
                    if esp.headDot then esp.headDot.Visible = false end
                end
            end
        end })
    ESPsSection:CreateColorpicker({ Text="Head Dot Color", Default=Color3.fromRGB(255,255,0), Index="ESP_HeadDotColor",
        Callback=function(c) Settings.ESP.HeadDotColor = c end })
    ESPsSection:CreateSlider({ Text="Head Dot Radius", Min=1, Max=15, Default=5, Index="ESP_HeadDotRadius",
        Callback=function(v) Settings.ESP.HeadDotRadius = v end })
    ESPsSection:CreateToggle({ Text="Items", Default=false, Index="ESP_Items",
        Callback=function(v)
            Settings.ESP.Items = v
            if v then
                task.spawn(function()
                    task.wait(0.1)
                    local count, maxItems = 0, Settings.ESP.ItemMaxCount or 100
                    local ok, desc = pcall(function() return Vars.Workspace:GetDescendants() end)
                    if not ok or not desc then return end
                    for _, part in ipairs(desc) do
                        if count >= maxItems then break end
                        if part:IsA("BasePart") and Vars.IsItemPart(part) then
                            pcall(Vars.CreateItemESP, part); count = count + 1
                        end
                    end
                end)
            else Vars.ClearItemESP() end
        end })
    ESPsSection:CreateColorpicker({ Text="Item Color", Default=Color3.fromRGB(255,165,0), Index="ESP_ItemColor",
        Callback=function(c) Settings.ESP.ItemColor = c end })
    ESPsSection:CreateSlider({ Text="Item Max Distance", Min=50, Max=2000, Default=500, Index="ESP_ItemMaxDist",
        Callback=function(v) Settings.ESP.ItemMaxDistance = v end })
    ESPsSection:CreateToggle({ Text="Weapons", Default=false, Index="ESP_Weapons",
        Callback=function(v)
            Settings.ESP.Weapons = v
            if not v then
                for _, esp in pairs(Vars.ESPPool) do
                    if esp.weapon then esp.weapon.Visible = false end
                end
            end
        end })
    ESPsSection:CreateColorpicker({ Text="Weapon Color", Default=Color3.fromRGB(255,0,255), Index="ESP_WeaponColor",
        Callback=function(c) Settings.ESP.WeaponColor = c end })
    ESPsSection:CreateToggle({ Text="Color By Health", Default=false, Index="ESP_ColorByHealth",
        Callback=function(v) Settings.ESP.ColorByHealth = v end })

    local ESPChams = ESPTab:CreateSection("Chams")
    ESPChams:CreateToggle({ Text="Chams Master", Default=false, Index="ESP_Chams",
        Callback=function(v)
            Settings.ESP.Chams = v
            if not v then for _, esp in pairs(Vars.ESPPool) do esp.chams.Enabled = false end end
        end })
    ESPChams:CreateSlider({ Text="Fill Transparency", Min=0, Max=1, Default=0.25, Index="ESP_ChamsFill",
        Callback=function(v) Settings.ESP.ChamsFillTransparency = v end })
    ESPChams:CreateSlider({ Text="Outline Transparency", Min=0, Max=1, Default=0, Index="ESP_ChamsOutlineTransp",
        Callback=function(v) Settings.ESP.ChamsOutlineTransparency = v end })
    ESPChams:CreateDropdown({ Text="Depth Mode", Options={"AlwaysOnTop","Occluded"}, Default="AlwaysOnTop", Index="ESP_ChamsDepth",
        Callback=function(v) Settings.ESP.ChamsDepthMode = v end })
    ESPChams:CreateColorpicker({ Text="Outline Color", Default=Color3.new(1,1,1), Index="ESP_ChamsOutlineColor",
        Callback=function(c) Settings.ESP.ChamsOutlineColor = c end })
    ESPChams:CreateDropdown({ Text="Wallcheck Filter",
        Options={"Off","OnlyVisible","OnlyHidden","PartiallyVisible"},
        Default="Off", Index="ESP_ChamsWallcheck",
        Callback=function(v) Settings.ESP.ChamsWallcheckMode = v end })

    -- ===== Skeleton Tab =====
    local SkeletonTab = Window:CreateTab("Skeleton")
    local SkelMain    = SkeletonTab:CreateSection("Skeleton ESP")
    SkelMain:CreateToggle({ Text="Skeleton Master", Default=false, Index="Skel_Enabled",
        Callback=function(v)
            Settings.Skeleton.Enabled = v
            if not v then Vars.ClearAllSkeletons() end
        end })
    SkelMain:CreateSlider({ Text="Thickness", Min=1, Max=5, Default=1, Index="Skel_Thickness",
        Callback=function(v) Settings.Skeleton.Thickness = v end })
    SkelMain:CreateSlider({ Text="Max Distance", Min=50, Max=2000, Default=500, Index="Skel_MaxDist",
        Callback=function(v) Settings.Skeleton.MaxDistance = v end })
    SkelMain:CreateDropdown({ Text="Rig Mode", Options={"Auto","R6","R15"}, Default="Auto", Index="Skel_RigMode",
        Callback=function(v) Settings.Skeleton.RigMode = v; Vars.ClearAllSkeletons() end })
    SkelMain:CreateToggle({ Text="Only Visible", Default=false, Index="Skel_OnlyVisible",
        Callback=function(v) Settings.Skeleton.OnlyVisible = v end })
    SkelMain:CreateToggle({ Text="Dynamic Thickness", Default=true, Index="Skel_DynThickness",
        Callback=function(v) Settings.Skeleton.DynamicThickness = v end })
    SkelMain:CreateToggle({ Text="Show Joints", Default=false, Index="Skel_ShowJoints",
        Callback=function(v)
            Settings.Skeleton.ShowJoints = v
            if not v then
                for name in pairs(Vars.ActiveSkeletons) do Vars._ClearJointDots(name) end
            end
        end })

    -- ===== Aimbot Tab =====
    local AimbotTab = Window:CreateTab("Aimbot")
    local ASet      = AimbotTab:CreateSection("Aimbot")

    ASet:CreateToggle({ Text="Aimbot Master", Default=false, Index="Aim_Enabled",
        Callback=function(v) Settings.Aimbot.Enabled = v end })
    ASet:CreateDropdown({ Text="Aim Mode", Options={"Nearest","Head"}, Default="Nearest", Index="Aim_AimPartMode",
        Callback=function(v)
            Settings.Aimbot.AimPartMode = v
            Vars.targetTransition.previousPlayer = nil
            if Vars.TargetManager then Vars.TargetManager:ClearTarget() end
        end })
    ASet:CreateLabel("Nearest = zona inteligente + hysteresis")
    ASet:CreateLabel("Head    = solo cabeza, se libera solo si sale del FOV (v10.2 fix)")

    local WBSection = AimbotTab:CreateSection("Wallbang")
    WBSection:CreateToggle({ Text="Wallbang (ignora paredes)", Default=false, Index="Aim_Wallbang",
        Callback=function(v) Settings.Aimbot.Wallbang = v end })
    WBSection:CreateLabel("ON = el aim funciona a través de cualquier pared")

    -- Triggerbot UI (v10.2)
    local TBSection = AimbotTab:CreateSection("Triggerbot")
    TBSection:CreateToggle({ Text="Triggerbot Master", Default=false, Index="TB_Enabled",
        Callback=function(v) Settings.Triggerbot.Enabled = v end })
    TBSection:CreateToggle({ Text="Usar tecla (Off = siempre activo cuando enabled)", Default=false, Index="TB_UseKey",
        Callback=function(v) Settings.Triggerbot.UseKey = v end })
    TBSection:CreateSlider({ Text="Delay (s)", Min=0, Max=0.5, Default=0.05, Index="TB_Delay",
        Callback=function(v) Settings.Triggerbot.Delay = v end })
    TBSection:CreateToggle({ Text="Target Bots (BotStorage)", Default=false, Index="TB_Bots",
        Callback=function(v) Settings.Triggerbot.BotTargeting = v end })
    TBSection:CreateToggle({ Text="Ignorar Passive/ForceField", Default=true, Index="TB_Passive",
        Callback=function(v) Settings.Triggerbot.PassiveCheck = v end })
    TBSection:CreateLabel("Sin tecla = dispara automático sobre enemigo")
    TBSection:CreateLabel("Con tecla = solo cuando MB2 held")

    ASet:CreateDropdown({ Text="Method", Options={"Camera","Mouse"}, Default="Camera", Index="Aim_Method",
        Callback=function(v) Settings.Aimbot.Method = v end })
    ASet:CreateDropdown({ Text="Priority", Options={"FOV","Distance","Priority"}, Default="FOV", Index="Aim_Priority",
        Callback=function(v) Settings.Aimbot.Priority = v end })

    local TeamSet = AimbotTab:CreateSection("Team")
    TeamSet:CreateToggle({ Text="Team Check", Default=false, Index="Aim_TeamCheck",
        Callback=function(v) Settings.Aimbot.TeamCheck = v end })
    TeamSet:CreateDropdown({ Text="Team Method", Options={"Normal","Scrim"}, Default="Normal", Index="Aim_TeamMethod",
        Callback=function(v)
            Settings.Aimbot.TeamMethod = v
            if Vars.TeamManager then Vars.TeamManager.method = v end
            if Window.Notify then Window:Notify("Team", "Método: " .. v, 2, "Info") end
        end })
    TeamSet:CreateLabel("Normal = todos enemigos | Scrim = teams reales")
    TeamSet:CreateButton("Ver Teams actuales", function()
        if Vars.TeamManager and Window.Notify then
            local parts = {}
            for _, data in ipairs(Vars.TeamManager.list) do
                _tins(parts, data.name .. " (" .. #data.players .. ")" .. (data.isMine and " [MÍO]" or ""))
            end
            Window:Notify("Teams", #parts > 0 and table.concat(parts, " | ") or "Sin teams", 6, "Info")
        end
    end)

    ASet:CreateToggle({ Text="Wall Check", Default=false, Index="Aim_WallCheck",
        Callback=function(v) Settings.Aimbot.WallCheck = v end })
    ASet:CreateToggle({ Text="Ignore Passive", Default=false, Index="Aim_IgnorePassive",
        Callback=function(v) Settings.Aimbot.IgnorePassive = v end })
    ASet:CreateToggle({ Text="Require Gun", Default=false, Index="Aim_RequireGun",
        Callback=function(v) Settings.Aimbot.RequireGun = v end })
    ASet:CreateSlider({ Text="Max Distance", Min=50, Max=2000, Default=500, Index="Aim_MaxDist",
        Callback=function(v) Settings.Aimbot.MaxDistance = v end })
    ASet:CreateDropdown({ Text="Aim Key Type", Options={"Mouse","Key"}, Default="Mouse", Index="Aim_KeyType",
        Callback=function(v) Settings.Aimbot.AimKeyType = v end })
    ASet:CreateDropdown({ Text="Aim Key", Options={"T","Q","E","R","F","G","Z","X","C","V"}, Default="T", Index="Aim_Key",
        Callback=function(v) if Enum.KeyCode[v] then Settings.Aimbot.AimKey = Enum.KeyCode[v] end end })
    ASet:CreateDropdown({ Text="Mouse Button", Options={"Left","Right","Middle"}, Default="Right", Index="Aim_MouseBtn",
        Callback=function(v)
            Settings.Aimbot.AimMouseButton =
                v == "Left"  and Enum.UserInputType.MouseButton1 or
                v == "Right" and Enum.UserInputType.MouseButton2 or
                Enum.UserInputType.MouseButton3
        end })
    ASet:CreateSlider({ Text="FOV", Min=1, Max=360, Default=180, Index="Aim_FOV",
        Callback=function(v) Settings.Aimbot.FOV = v end })
    ASet:CreateSlider({ Text="Smoothness Base", Min=0, Max=100, Default=15, Index="Aim_SmoothBase",
        Callback=function(v) Settings.Aimbot.BaseSmoothness = v/100 end })
    ASet:CreateSlider({ Text="Smoothness Helper", Min=0, Max=100, Default=15, Index="Aim_SmoothHelper",
        Callback=function(v) Settings.Aimbot.HelperSmoothness = v/100 end })
    ASet:CreateToggle({ Text="Prediction", Default=false, Index="Aim_Prediction",
        Callback=function(v) Settings.Aimbot.UsePrediction = v end })
    ASet:CreateSlider({ Text="Prediction Amount", Min=0.01, Max=0.3, Default=0.13, Index="Aim_PredAmount",
        Callback=function(v) Settings.Aimbot.PredictionAmount = v end })
    ASet:CreateToggle({ Text="Ping Prediction", Default=false, Index="Aim_PingPred",
        Callback=function(v) Settings.Aimbot.UsePingPrediction = v end })
    ASet:CreateToggle({ Text="Sticky Lock", Default=false, Index="Aim_StickyLock",
        Callback=function(v) Settings.Aimbot.StickyLock = v end })
    ASet:CreateSlider({ Text="Sticky Timeout (s)", Min=0.5, Max=10, Default=2, Index="Aim_StickyTimeout",
        Callback=function(v) Settings.Aimbot.StickyTimeout = v end })
    ASet:CreateToggle({ Text="Human Mode", Default=false, Index="Aim_HumanMode",
        Callback=function(v) Settings.Aimbot.HumanMode = v end })
    ASet:CreateSlider({ Text="Switch Cooldown (s)", Min=0.1, Max=2, Default=0.45, Index="Aim_SwitchCooldown",
        Callback=function(v) Settings.Aimbot.SwitchCooldown = v end })
    ASet:CreateSlider({ Text="Switch Range (px)", Min=5, Max=200, Default=40, Index="Aim_SwitchRange",
        Callback=function(v) Settings.Aimbot.SwitchRange = v end })
    ASet:CreateToggle({ Text="Humanize", Default=true, Index="Aim_Humanize",
        Callback=function(v) Settings.Aimbot.Humanize = v end })
    ASet:CreateSlider({ Text="Jitter Amount", Min=0, Max=2, Default=0.35, Index="Aim_Jitter",
        Callback=function(v) Settings.Aimbot.JitterAmount = v end })
    ASet:CreateSlider({ Text="Jitter Speed (Hz)", Min=1, Max=30, Default=12, Index="Aim_JitterSpeed",
        Callback=function(v) Settings.Aimbot.JitterSpeed = v end })
    ASet:CreateDropdown({ Text="Ease Style", Options={"Linear","EaseOut","EaseInOut"}, Default="EaseOut", Index="Aim_EaseStyle",
        Callback=function(v) Settings.Aimbot.EaseStyle = v end })

    local FOVSkin = AimbotTab:CreateSection("FOV Circle")
    FOVSkin:CreateToggle({ Text="Show FOV Circle", Default=false, Index="Aim_ShowFOV",
        Callback=function(v) Settings.Aimbot.FOVShowCircle = v end })
    FOVSkin:CreateToggle({ Text="Filled", Default=false, Index="Aim_FOVFilled",
        Callback=function(v) Settings.Aimbot.FOVFilled = v end })
    FOVSkin:CreateColorpicker({ Text="Fill Color", Default=Color3.fromRGB(255,255,255), Index="Aim_FOVFillColor",
        Callback=function(c) Settings.Aimbot.FOVFillColor = c end })
    FOVSkin:CreateSlider({ Text="Fill Transparency", Min=0, Max=1, Default=0.85, Index="Aim_FOVFillTransp",
        Callback=function(v) Settings.Aimbot.FOVFillTransparency = v end })
    FOVSkin:CreateColorpicker({ Text="Outline Color", Default=Color3.fromRGB(255,255,255), Index="Aim_FOVOutlineColor",
        Callback=function(c) Settings.Aimbot.FOVOutlineColor = c end })
    FOVSkin:CreateSlider({ Text="Outline Thickness", Min=1, Max=10, Default=2, Index="Aim_FOVOutlineThick",
        Callback=function(v) Settings.Aimbot.FOVOutlineThickness = v end })
    FOVSkin:CreateSlider({ Text="Outline Transparency", Min=0, Max=1, Default=0, Index="Aim_FOVOutlineTransp",
        Callback=function(v) Settings.Aimbot.FOVOutlineTransparency = v end })
    FOVSkin:CreateSlider({ Text="Circle Smoothness", Min=10, Max=120, Default=60, Index="Aim_FOVNumSides",
        Callback=function(v) Settings.Aimbot.FOVNumSides = _mfloor(v) end })
    FOVSkin:CreateToggle({ Text="Center Dot", Default=false, Index="Aim_FOVCenterDot",
        Callback=function(v) Settings.Aimbot.FOVCenterDot = v end })
    FOVSkin:CreateColorpicker({ Text="Center Dot Color", Default=Color3.fromRGB(255,50,50), Index="Aim_FOVCenterDotColor",
        Callback=function(c) Settings.Aimbot.FOVCenterDotColor = c end })
    FOVSkin:CreateSlider({ Text="Center Dot Size", Min=1, Max=10, Default=3, Index="Aim_FOVCenterDotSize",
        Callback=function(v) Settings.Aimbot.FOVCenterDotSize = v end })

    local WLSet = AimbotTab:CreateSection("Whitelist")
    WLSet:CreateButton("Toggle Whitelist (target actual)", function()
        local t = Vars.TargetManager:GetCurrentTarget()
        if t then
            Vars.TargetManager:AddToWhitelist(t.player)
            local st = Vars.TargetManager:IsWhitelisted(t.player) and "añadido" or "removido"
            if Window.Notify then Window:Notify("Whitelist", t.player.Name .. " " .. st, 2, "Info") end
        else
            if Window.Notify then Window:Notify("Whitelist", "Sin target activo", 2, "Warning") end
        end
    end)

    -- ===== Aim Assist Tab =====
    local AimAssistTab = Window:CreateTab("Aim Assist")
    local AASet        = AimAssistTab:CreateSection("Aim Assist v2")
    AASet:CreateToggle({ Text="Aim Assist Master", Default=false, Index="AA_Enabled",
        Callback=function(v)
            Settings.AimAssist.Enabled = v
            if v then Vars.StartAimAssist() else Vars.StopAimAssist() end
        end })
    AASet:CreateLabel("v10.2: Edge falloff cuadrático + deadzone + parte más cercana al cursor")
    AASet:CreateSlider({ Text="FOV", Min=1, Max=360, Default=30, Index="AA_FOV",
        Callback=function(v) Settings.AimAssist.FOV = v end })
    AASet:CreateToggle({ Text="Show FOV", Default=false, Index="AA_ShowFOV",
        Callback=function(v) Settings.AimAssist.ShowFOV = v end })
    AASet:CreateSlider({ Text="Max Distance", Min=50, Max=2000, Default=500, Index="AA_MaxDist",
        Callback=function(v) Settings.AimAssist.MaxDistance = v end })
    AASet:CreateSlider({ Text="Smoothness", Min=0, Max=100, Default=50, Index="AA_Smoothness",
        Callback=function(v) Settings.AimAssist.Smoothness = v/100 end })
    AASet:CreateSlider({ Text="Strength", Min=0, Max=100, Default=60, Index="AA_Strength",
        Callback=function(v) Settings.AimAssist.Strength = v/100 end })
    AASet:CreateSlider({ Text="Max Speed (°/s)", Min=1, Max=180, Default=30, Index="AA_MaxSpeed",
        Callback=function(v) Settings.AimAssist.MaxSpeed = v end })
    AASet:CreateSlider({ Text="Deadzone (px)", Min=0, Max=20, Default=3, Index="AA_Deadzone",
        Callback=function(v) Settings.AimAssist.Deadzone = v end })
    AASet:CreateToggle({ Text="Team Check", Default=false, Index="AA_TeamCheck",
        Callback=function(v) Settings.AimAssist.TeamCheck = v end })
    AASet:CreateToggle({ Text="Wall Check", Default=false, Index="AA_WallCheck",
        Callback=function(v) Settings.AimAssist.WallCheck = v end })
    AASet:CreateToggle({ Text="Human Mode", Default=true, Index="AA_HumanMode",
        Callback=function(v) Settings.AimAssist.HumanMode = v end })
    AASet:CreateToggle({ Text="Prediction", Default=false, Index="AA_Prediction",
        Callback=function(v) Settings.AimAssist.UsePrediction = v end })
    AASet:CreateSlider({ Text="Prediction Amount", Min=0.01, Max=0.3, Default=0.13, Index="AA_PredAmount",
        Callback=function(v) Settings.AimAssist.PredictionAmount = v end })

    -- ===== Crosshair Tab =====
    local XHairTab = Window:CreateTab("Crosshair")
    local XHMain   = XHairTab:CreateSection("Crosshair")
    XHMain:CreateToggle({ Text="Crosshair Master", Default=false, Index="XH_Enabled",
        Callback=function(v) Settings.Crosshair.Enabled = v end })
    XHMain:CreateDropdown({ Text="Style", Options={"Cross","X","T","Circle","Dot"}, Default="Cross", Index="XH_Style",
        Callback=function(v) Settings.Crosshair.Style = v end })
    XHMain:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(255,255,255), Index="XH_Color",
        Callback=function(c) Settings.Crosshair.Color = c end })
    XHMain:CreateToggle({ Text="Outline", Default=true, Index="XH_Outline",
        Callback=function(v) Settings.Crosshair.Outline = v end })
    XHMain:CreateColorpicker({ Text="Outline Color", Default=Color3.fromRGB(0,0,0), Index="XH_OutlineColor",
        Callback=function(c) Settings.Crosshair.OutlineColor = c end })
    XHMain:CreateSlider({ Text="Size (arm length px)", Min=2, Max=40, Default=10, Index="XH_Size",
        Callback=function(v) Settings.Crosshair.Size = v end })
    XHMain:CreateSlider({ Text="Thickness", Min=1, Max=8, Default=2, Index="XH_Thickness",
        Callback=function(v) Settings.Crosshair.Thickness = v end })
    XHMain:CreateSlider({ Text="Gap (center space px)", Min=0, Max=20, Default=4, Index="XH_Gap",
        Callback=function(v) Settings.Crosshair.Gap = v end })
    XHMain:CreateSlider({ Text="Transparency", Min=0, Max=1, Default=0, Index="XH_Transparency",
        Callback=function(v) Settings.Crosshair.Transparency = v end })
    local XHDot = XHairTab:CreateSection("Center Dot")
    XHDot:CreateToggle({ Text="Center Dot", Default=false, Index="XH_Dot",
        Callback=function(v) Settings.Crosshair.Dot = v end })
    XHDot:CreateColorpicker({ Text="Dot Color", Default=Color3.fromRGB(255,50,50), Index="XH_DotColor",
        Callback=function(c) Settings.Crosshair.DotColor = c end })
    XHDot:CreateSlider({ Text="Dot Size", Min=1, Max=10, Default=3, Index="XH_DotSize",
        Callback=function(v) Settings.Crosshair.DotSize = v end })
    local XHSpin = XHairTab:CreateSection("Spinning")
    XHSpin:CreateToggle({ Text="Spinning (giratoria)", Default=false, Index="XH_Spinning",
        Callback=function(v) Settings.Crosshair.Spinning = v end })
    XHSpin:CreateSlider({ Text="Spin Speed (°/s)", Min=10, Max=720, Default=90, Index="XH_SpinSpeed",
        Callback=function(v) Settings.Crosshair.SpinSpeed = v end })

    -- ===== Wallbang Tab =====
    local WBTab  = Window:CreateTab("Wallbang")
    local WBMain = WBTab:CreateSection("Penetración Real")
    WBMain:CreateToggle({ Text="Wallbang Master", Default=false, Index="WB_Enabled",
        Callback=function(v) Settings.WallbangSettings.Enabled = v end })
    WBMain:CreateLabel("Rayo multi-pass — atraviesa paredes, detecta jugadores detrás.")
    WBMain:CreateSlider({ Text="Max Penetraciones", Min=1, Max=6, Default=3, Index="WB_MaxPen",
        Callback=function(v) Settings.WallbangSettings.MaxPenetrations = _mfloor(v) end })
    WBMain:CreateSlider({ Text="Distancia máxima", Min=100, Max=1500, Default=600, Index="WB_MaxDist",
        Callback=function(v) Settings.WallbangSettings.MaxDistance = v end })
    local WBDbg = WBTab:CreateSection("Debug")
    WBDbg:CreateToggle({ Text="Debug Lines (naranja por pared)", Default=false, Index="WB_DebugLines",
        Callback=function(v) Settings.WallbangSettings.ShowDebugLine = v end })
    WBDbg:CreateSlider({ Text="Debug Line Lifetime (s)", Min=0.05, Max=1, Default=0.12, Index="WB_DebugLifetime",
        Callback=function(v) Settings.WallbangSettings.DebugLineLifetime = v end })

    -- ===== Weapon Mods Tab =====
    local WeaponTab = Window:CreateTab("Weapon Mods")
    local WSSet     = WeaponTab:CreateSection("Weapon")
    WSSet:CreateToggle({ Text="No Recoil (Town)", Default=false, Index="W_NoRecoil",
        Callback=function(v)
            Settings.WeaponMods.NoRecoil = v
            if v then Vars.StartNoRecoil() else Vars.StopNoRecoil() end
        end })
    local CamFix = WeaponTab:CreateSection("Camera Fixes")
    CamFix:CreateToggle({ Text="No Camera Bob", Default=false, Index="W_NoCamBob",
        Callback=function(v)
            Settings.WeaponMods.NoCameraBob = v
            if v then
                if not Vars._camFixConn then
                    Vars._camFixConn = Vars.RunService.Heartbeat:Connect(function()
                        pcall(Vars._applyNoCameraBob)
                    end)
                end
            else
                if Vars._camFixConn then Vars._camFixConn:Disconnect(); Vars._camFixConn = nil end
            end
        end })
    CamFix:CreateToggle({ Text="No Sprint FOV", Default=false, Index="W_NoSprintFOV",
        Callback=function(v)
            Settings.WeaponMods.NoSprintFOV = v
            if v then
                if not Vars._sprintFOVConn then
                    Vars._sprintFOVConn = Vars.RunService.Heartbeat:Connect(function()
                        pcall(Vars._applyNoSprintFOV)
                    end)
                end
            else
                if Vars._sprintFOVConn then Vars._sprintFOVConn:Disconnect(); Vars._sprintFOVConn = nil end
            end
        end })

    -- ===== Visuals Tab =====
    local VisualsTab = Window:CreateTab("Visuals")
    local VLight     = VisualsTab:CreateSection("Lighting")
    VLight:CreateToggle({ Text="Full Bright", Default=false, Index="Vis_FullBright",
        Callback=function(v) Vars.setFullBright(v) end })
    VLight:CreateToggle({ Text="No Fog",  Default=false, Index="Vis_NoFog",
        Callback=function(v) Vars.setNoFog(v) end })
    VLight:CreateToggle({ Text="No Bloom",Default=false, Index="Vis_NoBloom",
        Callback=function(v) Vars.setNoBloom(v) end })
    VLight:CreateButton("Reset Visuals", function()
        if Vars.ResetAllVisuals then Vars.ResetAllVisuals() end
    end)
    local VFOV = VisualsTab:CreateSection("Camera")
    VFOV:CreateToggle({ Text="Custom FOV", Default=false, Index="Vis_CustomFOV",
        Callback=function(v) Vars.setCustomFOV(v, Settings.Visuals.FOVValue) end })
    VFOV:CreateSlider({ Text="FOV Value", Min=1, Max=120, Default=70, Index="Vis_FOVValue",
        Callback=function(v)
            Settings.Visuals.FOVValue = v
            if Settings.Visuals.CustomFOV then Vars.setCustomFOV(true, v) end
        end })
    local VHide = VisualsTab:CreateSection("First Person")
    VHide:CreateToggle({ Text="Hide Body",  Default=false, Index="Vis_HideBody",
        Callback=function(v) Settings.Visuals.HideBody  = v end })
    VHide:CreateToggle({ Text="Hide Hands", Default=false, Index="Vis_HideHands",
        Callback=function(v) Settings.Visuals.HideHands = v end })
    VHide:CreateToggle({ Text="Hide Tool",  Default=false, Index="Vis_HideTool",
        Callback=function(v) Settings.Visuals.HideTool  = v end })
    local VTracer = VisualsTab:CreateSection("Bullet Tracers")
    VTracer:CreateToggle({ Text="Bullet Tracers", Default=false, Index="Vis_BulletTracers",
        Callback=function(v) Settings.Visuals.BulletTracers = v end })
    VTracer:CreateColorpicker({ Text="Tracer Color", Default=Color3.fromRGB(255,50,50), Index="Vis_TracerColor",
        Callback=function(c) Settings.Visuals.TracerColor = c end })

    -- ===== Advanced Tab =====
    local AdvancedTab = Window:CreateTab("Advanced")
    AdvancedTab:CreateSection("Quick Toggles"):CreateToggle({ Text="Enable Quick Toggles", Default=false, Index="Adv_QT",
        Callback=function(v) Settings.Advanced.QT_Enabled = v end })
    AdvancedTab:CreateSection("Performance"):CreateToggle({ Text="FPS Booster", Default=false, Index="Adv_FPSBooster",
        Callback=function(v) Vars.ApplyFPSBooster(v) end })

    -- ===== Hotkeys Tab =====
    local HotkeyTab = Window:CreateTab("Hotkeys")
    local HKSet     = HotkeyTab:CreateSection("Hotkeys")
    HKSet:CreateDropdown({ Text="Toggle Menu", Options={"RightShift","LeftShift","Insert","Home","F1","F2"},
        Default="RightShift", Index="HK_ToggleMenu",
        Callback=function(v) if Enum.KeyCode[v] then Settings.Hotkeys.ToggleMenu = Enum.KeyCode[v] end end })
    HKSet:CreateDropdown({ Text="Panic", Options={"End","Delete","Backspace","F12"},
        Default="End", Index="HK_Panic",
        Callback=function(v) if Enum.KeyCode[v] then Settings.Hotkeys.Panic = Enum.KeyCode[v] end end })

    -- ===== Utility Tab =====
    local UtilityTab = Window:CreateTab("Utility")
    local UHUD = UtilityTab:CreateSection("HUD")
    UHUD:CreateToggle({ Text="HUD Enabled", Default=false, Index="HUD_Enabled",
        Callback=function(v)
            Settings.HUD.Enabled = v
            if not v then
                Vars.HudLabel.Visible      = false
                Vars.HudRightLabel.Visible = false
                Vars.HudBackground.Visible = false
                Vars.HudAccentLine.Visible = false
            end
        end })
    UHUD:CreateToggle({ Text="Show FPS",  Default=false, Index="HUD_ShowFPS",
        Callback=function(v) Settings.HUD.ShowFPS  = v end })
    UHUD:CreateToggle({ Text="Show Ping", Default=false, Index="HUD_ShowPing",
        Callback=function(v) Settings.HUD.ShowPing = v end })
    local UScript = UtilityTab:CreateSection("Script")
    UScript:CreateButton("Unload", function()
        _env.TownComplete_Cleanup()
        if Window.Destroy then Window:Destroy() end
    end)
    UtilityTab:CreateSection("Debug"):CreateLabel(
        "Executor: " .. tostring(Logger.ExecName) .. " " .. tostring(Logger.ExecVer))
    UtilityTab:CreateSection("Debug"):CreateButton("Abrir consola debug", function()
        local ok = Logger.OpenConsole()
        if Window.Notify then
            Window:Notify("Debug", ok and "Consola abierta" or "No soportado", 2, ok and "Success" or "Warning")
        end
    end)

    -- Panic
    Vars.panicConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode ~= Settings.Hotkeys.Panic then return end
        Settings.ESP.Enabled            = false
        Settings.Skeleton.Enabled       = false
        Settings.Aimbot.Enabled         = false
        Settings.Aimbot.Wallbang        = false
        Settings.AimAssist.Enabled      = false
        Settings.HUD.Enabled            = false
        Settings.Visuals.CustomFOV      = false
        Settings.Visuals.HideBody       = false
        Settings.Visuals.HideHands      = false
        Settings.Visuals.HideTool       = false
        Settings.ESP.HeadDots           = false
        Settings.ESP.Items              = false
        Settings.ESP.Weapons            = false
        Settings.Aimbot.StickyLock      = false
        Settings.Backtrack.Enabled      = false
        Settings.Advanced.FPSBooster_Enabled = false
        Settings.Advanced.QT_Enabled    = false
        Settings.WeaponMods.NoRecoil              = false
        Settings.WallbangSettings.Enabled         = false
        Settings.WallbangSettings.ShowDebugLine   = false
        Settings.Crosshair.Enabled                = false
        Settings.Crosshair.Spinning               = false
        Settings.Triggerbot.Enabled               = false
        Settings.OffscreenESP.Enabled             = false

        Vars.ClearAllESP(); Vars.ClearAllSkeletons(); Vars.ClearItemESP()
        Vars.StopNoRecoil(); Vars.StopHideBody(); Vars.StopAimAssist()
        Vars.ClearAllTracers()
        if Vars.CleanupCrosshair  then pcall(Vars.CleanupCrosshair) end
        if Vars.CleanupWallbang   then pcall(Vars.CleanupWallbang) end
        if Vars.CleanupOffscreen  then pcall(Vars.CleanupOffscreen) end
        if Vars.ResetAllVisuals   then Vars.ResetAllVisuals() end
        if Vars.ApplyFPSBooster   then Vars.ApplyFPSBooster(false) end

        Vars.HudLabel.Visible      = false
        Vars.HudRightLabel.Visible = false
        Vars.HudBackground.Visible = false
        Vars.HudAccentLine.Visible = false

        if _env.TownUI_Window and _env.TownUI_Window.Notify then
            pcall(_env.TownUI_Window.Notify, _env.TownUI_Window,
                "Panic", "Todo desactivado", 3, "Warning")
        end
    end)
end

-- ============================================================
-- BLOQUE 9.5: Crosshair (Drawing, giratoria, personalizable)
-- ============================================================
do
    local RunService       = Vars.RunService
    local UserInputService = Vars.UserInputService
    local Settings         = Vars.Settings

    local _chLines   = {}
    local _chCircle  = nil
    local _chDot     = nil
    local _chOCircle = nil

    local function _EnsureCHObjects()
        for i = 1, 8 do
            if not _chLines[i] then
                local l = Drawing.new("Line"); l.Visible = false; _chLines[i] = l
            end
        end
        if not _chCircle then
            _chCircle = Drawing.new("Circle"); _chCircle.Filled = false; _chCircle.Visible = false
        end
        if not _chOCircle then
            _chOCircle = Drawing.new("Circle"); _chOCircle.Filled = false; _chOCircle.Visible = false
        end
        if not _chDot then
            _chDot = Drawing.new("Circle"); _chDot.Filled = true; _chDot.Visible = false
        end
    end

    local function _HideAllCH()
        for _, l in ipairs(_chLines) do l.Visible = false end
        if _chCircle  then _chCircle.Visible  = false end
        if _chOCircle then _chOCircle.Visible = false end
        if _chDot     then _chDot.Visible     = false end
    end

    local function _DrawArm(idx, cx, cy, angle, len, gap, thickness, color, outline, outColor, transp)
        local rad   = math.rad(angle)
        local cos_r = math.cos(rad)
        local sin_r = math.sin(rad)
        local fx = cx + cos_r * gap
        local fy = cy + sin_r * gap
        local tx = cx + cos_r * (gap + len)
        local ty = cy + sin_r * (gap + len)
        local from = _V2(fx, fy)
        local to   = _V2(tx, ty)
        local fillIdx    = idx * 2 - 1
        local outlineIdx = idx * 2
        if outline then
            local ol = _chLines[outlineIdx]
            ol.From        = from; ol.To = to
            ol.Color       = outColor; ol.Thickness = thickness + 2
            ol.Transparency= transp; ol.Visible = true
        else _chLines[outlineIdx].Visible = false end
        local fl = _chLines[fillIdx]
        fl.From        = from; fl.To = to
        fl.Color       = color; fl.Thickness = thickness
        fl.Transparency= transp; fl.Visible = true
    end

    local function _UpdateCrosshair(dt)
        if Vars.isScriptUnloaded then return end
        local cfg = Settings.Crosshair
        if not cfg.Enabled then _HideAllCH(); return end
        _EnsureCHObjects()
        if cfg.Spinning then
            cfg._angle = (cfg._angle + cfg.SpinSpeed * dt) % 360
        else
            cfg._angle = 0
        end
        local mp = UserInputService:GetMouseLocation()
        local cx = mp.X; local cy = mp.Y
        local a  = cfg._angle; local sz = cfg.Size; local gp = cfg.Gap
        local th = cfg.Thickness; local c = cfg.Color
        local oc = cfg.OutlineColor; local ol = cfg.Outline; local tr = cfg.Transparency
        local style = cfg.Style
        _HideAllCH()
        if style == "Cross" then
            _DrawArm(1, cx, cy, a,       sz, gp, th, c, ol, oc, tr)
            _DrawArm(2, cx, cy, a + 90,  sz, gp, th, c, ol, oc, tr)
            _DrawArm(3, cx, cy, a + 180, sz, gp, th, c, ol, oc, tr)
            _DrawArm(4, cx, cy, a + 270, sz, gp, th, c, ol, oc, tr)
        elseif style == "X" then
            _DrawArm(1, cx, cy, a + 45,  sz, gp, th, c, ol, oc, tr)
            _DrawArm(2, cx, cy, a + 135, sz, gp, th, c, ol, oc, tr)
            _DrawArm(3, cx, cy, a + 225, sz, gp, th, c, ol, oc, tr)
            _DrawArm(4, cx, cy, a + 315, sz, gp, th, c, ol, oc, tr)
        elseif style == "T" then
            _DrawArm(1, cx, cy, a,       sz, gp, th, c, ol, oc, tr)
            _DrawArm(2, cx, cy, a + 90,  sz, gp, th, c, ol, oc, tr)
            _DrawArm(3, cx, cy, a + 270, sz, gp, th, c, ol, oc, tr)
        elseif style == "Circle" then
            if ol then
                _chOCircle.Position = _V2(cx, cy); _chOCircle.Radius = sz + 1
                _chOCircle.Color = oc; _chOCircle.Thickness = th + 2
                _chOCircle.Transparency = tr; _chOCircle.NumSides = 48; _chOCircle.Visible = true
            end
            _chCircle.Position = _V2(cx, cy); _chCircle.Radius = sz
            _chCircle.Color = c; _chCircle.Thickness = th
            _chCircle.Transparency = tr; _chCircle.NumSides = 48; _chCircle.Visible = true
        end
        if cfg.Dot then
            _chDot.Position = _V2(cx, cy); _chDot.Radius = cfg.DotSize
            _chDot.Color = cfg.DotColor; _chDot.Transparency = tr; _chDot.Visible = true
        end
    end

    Vars.crosshairConn = RunService.RenderStepped:Connect(function(dt)
        pcall(_UpdateCrosshair, dt)
    end)

    Vars.CleanupCrosshair = function()
        if Vars.crosshairConn then
            pcall(function() Vars.crosshairConn:Disconnect() end); Vars.crosshairConn = nil
        end
        _HideAllCH()
        for _, l in ipairs(_chLines) do pcall(function() l:Remove() end) end
        _chLines = {}
        if _chCircle  then pcall(function() _chCircle:Remove() end);  _chCircle  = nil end
        if _chOCircle then pcall(function() _chOCircle:Remove() end); _chOCircle = nil end
        if _chDot     then pcall(function() _chDot:Remove() end);     _chDot     = nil end
    end
end

-- ============================================================
-- BLOQUE 9.6: Wallbang — penetración multi-pass real
-- ============================================================
do
    local RunService   = Vars.RunService
    local LP           = Vars.LP
    local Settings     = Vars.Settings
    local GetCamera    = Vars.GetCamera

    local _wbParams = RaycastParams.new()
    _wbParams.FilterType = Enum.RaycastFilterType.Blacklist
    _wbParams.IgnoreWater = true

    local function _RebuildWBIgnore()
        local ignore = {}
        if LP.Character then
            for _, p in ipairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") then _tins(ignore, p) end
            end
        end
        local cam = GetCamera()
        if cam then _tins(ignore, cam) end
        _wbParams.FilterDescendantsInstances = ignore
    end

    local _dbgLines = {}
    local _dbgActive = {}

    local function _AcquireDebugLine()
        local l = _trem(_dbgLines)
        if l then l.Visible = false; return l end
        l = Drawing.new("Line"); l.Thickness = 2; l.Visible = false; return l
    end
    local function _ReleaseDebugLine(l)
        if not l then return end
        l.Visible = false
        if #_dbgLines < 64 then _tins(_dbgLines, l)
        else pcall(function() l:Remove() end) end
    end
    local function _ClearDebugLines()
        for _, d in ipairs(_dbgActive) do _ReleaseDebugLine(d.line) end
        _tclr(_dbgActive)
    end

    local function _UpdateDebugLines()
        local now = _clock()
        local cam = GetCamera(); if not cam then return end
        local i = 1
        while i <= #_dbgActive do
            local d = _dbgActive[i]
            local age = now - d.startTime
            if age >= d.lifetime then
                _ReleaseDebugLine(d.line); _trem(_dbgActive, i)
            else
                local v1, o1 = cam:WorldToViewportPoint(d.from)
                local v2, o2 = cam:WorldToViewportPoint(d.to)
                if o1 or o2 then
                    d.line.From = _V2(v1.X, v1.Y); d.line.To = _V2(v2.X, v2.Y)
                    d.line.Transparency = age / d.lifetime; d.line.Visible = true
                else d.line.Visible = false end
                i = i + 1
            end
        end
    end

    local function WallbangCast(originPos, direction)
        local cfg = Settings.WallbangSettings
        if not cfg.Enabled then return {} end
        _RebuildWBIgnore()
        local params     = _wbParams
        local hits       = {}
        local excluded   = {}
        local currentPos = originPos
        local remaining  = cfg.MaxDistance
        local passCount  = 0
        local maxPass    = cfg.MaxPenetrations or 3
        local filterList = {}
        for _, v in ipairs(params.FilterDescendantsInstances) do _tins(filterList, v) end
        while passCount < maxPass and remaining > 0.01 do
            params.FilterDescendantsInstances = filterList
            local result = workspace:Raycast(currentPos, direction * remaining, params)
            if not result then break end
            local inst    = result.Instance
            local hitPos  = result.Position
            local hitDist = (hitPos - currentPos).Magnitude
            if cfg.ShowDebugLine then
                local dbgL = _AcquireDebugLine()
                dbgL.Color = Color3.fromRGB(255, 80, 0); dbgL.Thickness = 1
                _tins(_dbgActive, { line=dbgL, from=currentPos, to=hitPos,
                    startTime=_clock(), lifetime=cfg.DebugLineLifetime })
            end
            remaining  = remaining - hitDist
            currentPos = hitPos + direction * 0.05
            local char = inst.Parent
            if char and char:FindFirstChildOfClass("Humanoid") then
                for _, p in ipairs(Vars.activePlayers) do
                    if p.Character == char and not excluded[p] then
                        _tins(hits, { player=p, part=inst, hitPos=hitPos })
                        excluded[p] = true; break
                    end
                end
            end
            _tins(filterList, inst)
            passCount = passCount + 1
        end
        return hits
    end
    Vars.WallbangCast = WallbangCast

    local function WallbangGetTarget()
        local cfg = Settings.WallbangSettings
        if not cfg.Enabled then return nil end
        local cam = GetCamera(); if not cam then return nil end
        local origin = cam.CFrame.Position
        local dir    = cam.CFrame.LookVector
        local hits   = WallbangCast(origin, dir)
        if #hits == 0 then return nil end
        local best, bestDist = nil, math.huge
        for _, h in ipairs(hits) do
            local d = (h.hitPos - origin).Magnitude
            if d < bestDist then bestDist = d; best = h end
        end
        return best
    end
    Vars.WallbangGetTarget = WallbangGetTarget

    Vars.wbDebugConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        if Settings.WallbangSettings.ShowDebugLine then
            pcall(_UpdateDebugLines)
        else
            if #_dbgActive > 0 then _ClearDebugLines() end
        end
    end)

    Vars.CleanupWallbang = function()
        if Vars.wbDebugConn then
            pcall(function() Vars.wbDebugConn:Disconnect() end); Vars.wbDebugConn = nil
        end
        _ClearDebugLines()
        for _, l in ipairs(_dbgLines) do pcall(function() l:Remove() end) end
        _tclr(_dbgLines)
    end
end

-- ============================================================
-- BLOQUE 9.7: Triggerbot (v10.2)
-- ============================================================
do
    local RunService       = Vars.RunService
    local UserInputService = Vars.UserInputService
    local LP               = Vars.LP
    local Settings         = Vars.Settings
    local GetCamera        = Vars.GetCamera
    local IsMenuOpen       = Vars.IsMenuOpen
    local IsPassive        = Vars.IsPassive

    local function _BuildTriggerParams()
        local ignore = {}
        if LP.Character then
            for _, p in ipairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") then _tins(ignore, p) end
            end
        end
        local cam = GetCamera()
        if cam then _tins(ignore, cam) end
        Vars.sharedTriggerParams.FilterDescendantsInstances = ignore
    end

    local function _IsValidTriggerTarget(hitInstance)
        if not hitInstance or not hitInstance.Parent then return false end
        local char = hitInstance:FindFirstAncestorOfClass("Model")
        if not char then return false end
        local player = Vars.Players:GetPlayerFromCharacter(char)
        if player then
            if player == LP then return false end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return false end
            if Settings.Triggerbot.PassiveCheck and IsPassive(player.Name) then return false end
            if Settings.Aimbot.TeamCheck and Vars.TeamManager then
                if not Vars.TeamManager:IsEnemy(player) then return false end
            end
            return true
        end
        if Settings.Triggerbot.BotTargeting then
            local botStorage = Vars.Workspace:FindFirstChild("BotStorage")
            if botStorage and char:IsDescendantOf(botStorage) then
                local hum = char:FindFirstChildOfClass("Humanoid")
                return hum and hum.Health > 0
            end
        end
        return false
    end

    local _triggerKeyHeld = false

    Vars.triggerbotKeyBeganConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if Settings.Triggerbot.UseKey then
            if input.UserInputType == Settings.Triggerbot.Key then _triggerKeyHeld = true end
        end
    end)
    Vars.triggerbotKeyEndedConn = UserInputService.InputEnded:Connect(function(input)
        if Settings.Triggerbot.UseKey then
            if input.UserInputType == Settings.Triggerbot.Key then _triggerKeyHeld = false end
        end
    end)

    Vars.triggerbotConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        if not Settings.Triggerbot.Enabled then return end
        if Vars.isLocalDead or IsMenuOpen() then return end
        if type(isrbxactive) == "function" and not isrbxactive() then return end
        if Settings.Triggerbot.UseKey and not _triggerKeyHeld then return end
        local now   = _clock()
        local delay = Settings.Triggerbot.Delay or 0.05
        if (now - Vars.lastTriggerClick) < delay then return end
        local cam = GetCamera(); if not cam then return end
        local viewport = cam.ViewportSize
        local cx, cy   = viewport.X / 2, viewport.Y / 2
        _BuildTriggerParams()
        local unitRay = cam:ViewportPointToRay(cx, cy)
        local result  = Vars.Workspace:Raycast(
            unitRay.Origin,
            unitRay.Direction * (Settings.Triggerbot.RayDistance or 1000),
            Vars.sharedTriggerParams
        )
        if result and result.Instance then
            if _IsValidTriggerTarget(result.Instance) then
                Vars.lastTriggerClick = now
                pcall(function()
                    if type(mouse1click) == "function" then mouse1click() end
                end)
            end
        end
    end)
end

-- ============================================================
-- BLOQUE 9.8: Off-Screen ESP (v10.2)
-- ============================================================
do
    local RunService = Vars.RunService
    local LP         = Vars.LP
    local Settings   = Vars.Settings
    local GetCamera  = Vars.GetCamera

    local _osPool   = {}
    local _osActive = {}

    local function _AcquireArrow()
        local t = _trem(_osPool)
        if t then t.Visible = false; return t end
        t = Drawing.new("Triangle"); t.Filled = true; t.Thickness = 1; t.Visible = false
        return t
    end
    local function _ReleaseArrow(t)
        if not t then return end
        t.Visible = false
        if #_osPool < Vars.OffscreenPoolMAX then _tins(_osPool, t)
        else pcall(function() t:Remove() end) end
    end
    local function _ClearAllArrows()
        for _, d in ipairs(_osActive) do _ReleaseArrow(d.arrow) end
        _tclr(_osActive)
    end
    local function _GetOrCreateArrow(player)
        for _, d in ipairs(_osActive) do
            if d.player == player then return d.arrow end
        end
        local arr = _AcquireArrow()
        _tins(_osActive, { player=player, arrow=arr })
        return arr
    end
    local function _HideArrow(player)
        for _, d in ipairs(_osActive) do
            if d.player == player then d.arrow.Visible = false; return end
        end
    end

    Vars.offscreenConn = RunService.RenderStepped:Connect(function()
        if Vars.isScriptUnloaded then return end
        local cfg = Settings.OffscreenESP
        if not cfg.Enabled then
            for _, d in ipairs(_osActive) do d.arrow.Visible = false end
            return
        end
        local cam = GetCamera(); if not cam then return end
        local viewport  = cam.ViewportSize
        local camCF     = cam.CFrame
        local cx, cy    = viewport.X / 2, viewport.Y / 2
        local radius    = cfg.Radius or 200
        local arrowSize = cfg.Size or 15
        local color     = cfg.Color or Color3.fromRGB(255, 100, 100)
        local rendered  = {}

        for _, player in ipairs(Vars.activePlayers) do
            if not player or player == LP then continue end
            if not player.Character then _HideArrow(player); continue end
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then _HideArrow(player); continue end
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then _HideArrow(player); continue end

            local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
            local inBounds = onScreen
                and sp.X >= 0 and sp.X <= viewport.X
                and sp.Y >= 0 and sp.Y <= viewport.Y

            if inBounds then _HideArrow(player); continue end

            local relPos = camCF:PointToObjectSpace(hrp.Position)
            local dx, dy = relPos.X, -relPos.Y
            local mag    = math.sqrt(dx*dx + dy*dy)
            local dirX, dirY = 0, -1
            if mag > 1e-4 then dirX, dirY = dx/mag, dy/mag end

            local ax = cx + dirX * radius
            local ay = cy + dirY * radius
            local tipX = ax + dirX * arrowSize
            local tipY = ay + dirY * arrowSize
            local perpX, perpY = -dirY, dirX
            local half = arrowSize * 0.5

            local arr = _GetOrCreateArrow(player)
            arr.PointA = _V2(tipX, tipY)
            arr.PointB = _V2(ax + perpX * half, ay + perpY * half)
            arr.PointC = _V2(ax - perpX * half, ay - perpY * half)
            arr.Color  = color
            arr.Visible = true
            rendered[player] = true
        end

        for _, d in ipairs(_osActive) do
            if not rendered[d.player] then d.arrow.Visible = false end
        end
    end)

    Vars.CleanupOffscreen = function()
        if Vars.offscreenConn then
            pcall(function() Vars.offscreenConn:Disconnect() end); Vars.offscreenConn = nil
        end
        _ClearAllArrows()
        for _, t in ipairs(_osPool) do pcall(function() t:Remove() end) end
        _tclr(_osPool)
    end
end

-- ============================================================
-- BLOQUE 10: Cleanup + Init
-- ============================================================
do
    _env.TownComplete_Cleanup = function()
        Vars.isScriptUnloaded = true

        local connections = {
            "espSkeletonConn","fpsCounterConn","pingUpdateConn","hudConn",
            "playerAddedConn","playerRemovingConn","localCharConn","localDiedConn",
            "aimbotConn","fovConn","aimKeyBeganConn","aimKeyEndedConn",
            "panicConn","itemAddedConn","itemRemovingConn","posHistoryConn",
            "tracerLoopConn","qtConn","_camFixConn","_sprintFOVConn",
            "crosshairConn","wbDebugConn",
            -- v10.2
            "triggerbotConn","triggerbotKeyBeganConn","triggerbotKeyEndedConn",
            "offscreenConn",
        }
        for _, name in ipairs(connections) do
            local c = Vars[name]
            if c then pcall(function() c:Disconnect() end); Vars[name] = nil end
        end

        if Vars.TeamManager then pcall(function() Vars.TeamManager:Stop() end) end
        rawset(_env, "__TownUnloaded", true)
        local logConn = rawget(_env, "__TownLogServiceConn")
        if logConn then pcall(function() logConn:Disconnect() end) end

        pcall(Vars.StopNoRecoil)
        pcall(Vars.StopHideBody)
        pcall(Vars.StopAimAssist)
        if Vars.ApplyFPSBooster  then pcall(Vars.ApplyFPSBooster, false) end
        if Vars.CleanupAdvanced  then pcall(Vars.CleanupAdvanced) end
        if Vars.CleanupCrosshair then pcall(Vars.CleanupCrosshair) end
        if Vars.CleanupWallbang  then pcall(Vars.CleanupWallbang) end
        if Vars.CleanupOffscreen then pcall(Vars.CleanupOffscreen) end
        if Vars.ResetAllVisuals  then pcall(Vars.ResetAllVisuals) end

        Vars.ClearAllESP(); Vars.ClearAllSkeletons()
        Vars.ClearAllTracers(); Vars.ClearItemESP()

        if Vars._ClearJointDots then
            for name in pairs(Vars.ActiveSkeletons) do pcall(Vars._ClearJointDots, name) end
        end
        if Vars.ClearNearestState then pcall(Vars.ClearNearestState) end

        for _, line in ipairs(Vars.SkeletonLinePool) do pcall(function() line:Remove() end) end
        Vars.SkeletonLinePool = {}

        -- Off-screen pool cleanup
        for _, d in ipairs(Vars.ActiveOffscreen) do
            if d.arrow then pcall(function() d.arrow:Remove() end) end
        end
        _tclr(Vars.ActiveOffscreen)
        for _, t in ipairs(Vars.OffscreenPool) do pcall(function() t:Remove() end) end
        _tclr(Vars.OffscreenPool)

        local fov = Vars.GetFOVCircle and Vars.GetFOVCircle()
        if fov then pcall(function() fov:Remove() end) end
        if Vars.aimAssistFOVCircle then pcall(function() Vars.aimAssistFOVCircle:Remove() end) end
        if Vars.HudLabel      then pcall(function() Vars.HudLabel:Remove() end) end
        if Vars.HudRightLabel then pcall(function() Vars.HudRightLabel:Remove() end) end
        if Vars.HudBackground then pcall(function() Vars.HudBackground:Remove() end) end
        if Vars.HudAccentLine then pcall(function() Vars.HudAccentLine:Remove() end) end

        if _env.TownUI_Window then
            pcall(function()
                if _env.TownUI_Window.GetSaveManager then
                    _env.TownUI_Window:GetSaveManager():Save("default")
                end
            end)
        end
        _env.TownUI_Window      = nil
        _env.TownComplete_Loaded= false
    end

    if Logger.CloseConsole   then pcall(Logger.CloseConsole) end
    if Logger.RestoreGlobalPrint then pcall(Logger.RestoreGlobalPrint)
    else rawset(_env, "print", realPrint); rawset(_env, "warn", realWarn) end

    rawset(_env, "__TownUnloaded", false)
    Vars.StartHideBody()

    task.delay(0.6, function()
        if _env.TownUI_Window and _env.TownUI_Window.GetSaveManager then
            _env.TownUI_Window:GetSaveManager():Load("default")
        end
    end)
    task.delay(1.5, function()
        if _env.TownUI_Window then
            _env.TownUI_Window:Notify(
                "Town Complete v10.2 (PVP)",
                "RS = Menu | Y = Helper | End = Panic | Triggerbot + OffscreenESP + AA v2 + Head fix",
                6, "Success"
            )
        end
    end)
    task.delay(3, function() Logger.SilenceGlobalPrint() end)
end

-- ============================================================
-- BLOQUE 9.9: PathFinder Debug Visualizer (v10.2)
-- Visualiza waypoints, NavMesh chunks, vectores de velocidad,
-- línea de predicción de movimiento y datos en tiempo real.
-- Sección "Debug" en UI.
-- ============================================================
do
    local RunService       = Vars.RunService
    local UserInputService = Vars.UserInputService
    local LP               = Vars.LP
    local Settings         = Vars.Settings
    local GetCamera        = Vars.GetCamera

    -- --------------------------------------------------------
    -- Config block (dentro de Settings)
    -- --------------------------------------------------------
    Settings.PathDebug = {
        Enabled             = false,

        -- Waypoints (predicción de movimiento)
        ShowWaypoints       = true,
        WaypointColor       = Color3.fromRGB(0, 220, 255),
        WaypointRadius      = 6,
        WaypointCount       = 8,        -- cuántos waypoints adelantados dibujar
        WaypointDt          = 0.08,     -- intervalo de tiempo entre waypoints (s)

        -- Prediction line (línea al punto futuro)
        ShowPredLine        = true,
        PredLineColor       = Color3.fromRGB(255, 80, 0),
        PredLineThickness   = 2,
        PredTime            = 0.35,     -- segundos en el futuro

        -- Velocity vector
        ShowVelocity        = true,
        VelocityColor       = Color3.fromRGB(0, 255, 80),
        VelocityScale       = 0.4,      -- escala visual del vector

        -- Chunks (cuadrícula de terreno)
        ShowChunks          = false,
        ChunkSize           = 16,       -- studs por chunk
        ChunkRadius         = 3,        -- chunks alrededor del LocalPlayer
        ChunkColor          = Color3.fromRGB(80, 80, 255),
        ChunkThickness      = 1,
        ChunkLabelColor     = Color3.fromRGB(200, 200, 255),
        ChunkLabelSize      = 12,

        -- NavMesh overlay (approx via workspace terrain color overlay)
        ShowNavMesh         = false,
        NavMeshColor        = Color3.fromRGB(120, 0, 200),
        NavMeshAlpha        = 0.45,

        -- Data labels (velocidad, distancia, state)
        ShowDataLabels      = true,
        DataLabelColor      = Color3.fromRGB(255, 255, 100),
        DataLabelSize       = 13,

        -- Target filter: All players or only aimbot target
        TargetMode          = "All",    -- "All" | "AimbotTarget"
        MaxDistance         = 400,
    }

    -- --------------------------------------------------------
    -- Drawing pools
    -- --------------------------------------------------------
    local _pdPool = {
        waypointDots  = {},
        predLines     = {},
        velLines      = {},
        chunkLines    = {},
        chunkLabels   = {},
        dataLabels    = {},
    }
    local _pdActive = {
        waypointDots  = {},  -- { dot=Drawing, player=p }
        predLines     = {},
        velLines      = {},
        dataLabels    = {},
    }
    local _chunkLinesActive  = {}
    local _chunkLabelsActive = {}

    local function _Take(pool, createFn)
        local obj = table.remove(pool)
        return obj or createFn()
    end
    local function _Return(pool, obj, hideFn, maxSize)
        hideFn(obj)
        if #pool < (maxSize or 256) then table.insert(pool, obj) end
    end

    local function _NewCircle()
        local c = Drawing.new("Circle")
        c.Filled = true; c.NumSides = 16; c.Visible = false; return c
    end
    local function _NewLine()
        local l = Drawing.new("Line"); l.Visible = false; return l
    end
    local function _NewText()
        local t = Drawing.new("Text")
        t.Outline = true; t.Center = true; t.Font = 2; t.Visible = false; return t
    end
    local function _HideCircle(c) c.Visible = false end
    local function _HideLine(l)   l.Visible = false end
    local function _HideText(t)   t.Visible = false end

    -- --------------------------------------------------------
    -- Prediction: position at T seconds in the future
    -- uses velocity + half-acceleration (same as Vars.PredictPosition)
    -- --------------------------------------------------------
    local function _PredPos(root, t)
        if not root then return nil end
        local pos = root.Position
        local vel = _V3(0,0,0)
        pcall(function() vel = root.AssemblyLinearVelocity or root.Velocity or _V3(0,0,0) end)
        local acc = _V3(0,0,0)
        pcall(function()
            local ok, a = pcall(function() return root.AssemblyLinearAcceleration end)
            if ok and a then acc = a end
        end)
        return pos + vel * t + 0.5 * acc * t * t
    end

    -- --------------------------------------------------------
    -- Chunk helpers
    -- --------------------------------------------------------
    local function _ChunkCoord(pos, size)
        return math.floor(pos.X / size), math.floor(pos.Z / size)
    end
    local function _ChunkWorldPos(cx, cz, size, y)
        return _V3(cx * size, y, cz * size)
    end

    -- --------------------------------------------------------
    -- Clear all active debug objects
    -- --------------------------------------------------------
    local function _ClearAllPD()
        for _, d in ipairs(_pdActive.waypointDots) do
            _Return(_pdPool.waypointDots, d.dot, _HideCircle)
        end
        _tclr(_pdActive.waypointDots)
        for _, d in ipairs(_pdActive.predLines) do
            _Return(_pdPool.predLines, d.line, _HideLine)
        end
        _tclr(_pdActive.predLines)
        for _, d in ipairs(_pdActive.velLines) do
            _Return(_pdPool.velLines, d.line, _HideLine)
        end
        _tclr(_pdActive.velLines)
        for _, d in ipairs(_pdActive.dataLabels) do
            _Return(_pdPool.dataLabels, d.lbl, _HideText)
        end
        _tclr(_pdActive.dataLabels)
        for _, l in ipairs(_chunkLinesActive) do
            _Return(_pdPool.chunkLines, l, _HideLine)
        end
        _tclr(_chunkLinesActive)
        for _, t in ipairs(_chunkLabelsActive) do
            _Return(_pdPool.chunkLabels, t, _HideText)
        end
        _tclr(_chunkLabelsActive)
    end
    Vars.ClearPathDebug = _ClearAllPD

    -- --------------------------------------------------------
    -- Per-player entry helpers
    -- --------------------------------------------------------
    local function _GetOrAddEntry(list, player, createFn)
        for _, d in ipairs(list) do
            if d.player == player then return d end
        end
        local entry = createFn()
        entry.player = player
        table.insert(list, entry)
        return entry
    end
    local function _RemoveEntry(list, player, releaseFn)
        for i, d in ipairs(list) do
            if d.player == player then
                releaseFn(d)
                table.remove(list, i)
                return
            end
        end
    end

    -- --------------------------------------------------------
    -- Main render loop
    -- --------------------------------------------------------
    local function _UpdatePathDebug()
        if Vars.isScriptUnloaded then return end
        local cfg = Settings.PathDebug
        if not cfg.Enabled then
            _ClearAllPD()
            return
        end

        local cam = GetCamera(); if not cam then return end
        local viewport = cam.ViewportSize
        local lpChar  = LP.Character
        local lpRoot  = lpChar and lpChar:FindFirstChild("HumanoidRootPart")

        -- Decide which players to visualize
        local targets = {}
        if cfg.TargetMode == "AimbotTarget" then
            if Vars.TargetManager then
                local t = Vars.TargetManager:GetCurrentTarget()
                if t and t.player and t.player.Character then
                    table.insert(targets, t.player)
                end
            end
        else
            for _, p in ipairs(Vars.activePlayers) do
                if p and p ~= LP and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and lpRoot then
                        local d = (hrp.Position - lpRoot.Position).Magnitude
                        if cfg.MaxDistance <= 0 or d <= cfg.MaxDistance then
                            table.insert(targets, p)
                        end
                    end
                end
            end
        end

        local renderedPlayers = {}

        for _, player in ipairs(targets) do
            local char = player.Character; if not char then continue end
            local root = char:FindFirstChild("HumanoidRootPart"); if not root then continue end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            renderedPlayers[player] = true

            -- ---- Waypoints (future positions) ----
            if cfg.ShowWaypoints then
                local entry = _GetOrAddEntry(_pdActive.waypointDots, player, function()
                    local dots = {}
                    for i = 1, cfg.WaypointCount do
                        local dot = _Take(_pdPool.waypointDots, _NewCircle)
                        table.insert(dots, dot)
                    end
                    return { dots = dots }
                end)

                -- Ensure dot count matches config
                while #entry.dots < cfg.WaypointCount do
                    table.insert(entry.dots, _Take(_pdPool.waypointDots, _NewCircle))
                end

                for i = 1, cfg.WaypointCount do
                    local dot = entry.dots[i]
                    if not dot then continue end
                    local t   = i * cfg.WaypointDt
                    local wp  = _PredPos(root, t)
                    if not wp then dot.Visible = false; continue end
                    local sp, onScreen = cam:WorldToViewportPoint(wp)
                    if onScreen then
                        -- Fade alpha from bright → dim as i increases
                        local alpha = 1 - (i - 1) / cfg.WaypointCount * 0.75
                        dot.Position    = _V2(sp.X, sp.Y)
                        dot.Radius      = cfg.WaypointRadius * (1 - (i-1)/cfg.WaypointCount * 0.5)
                        dot.Color       = cfg.WaypointColor
                        dot.Transparency= 1 - alpha
                        dot.Visible     = true
                    else
                        dot.Visible = false
                    end
                end
            else
                -- Hide existing waypoint dots for this player
                for _, d in ipairs(_pdActive.waypointDots) do
                    if d.player == player then
                        for _, dot in ipairs(d.dots or {}) do dot.Visible = false end
                    end
                end
            end

            -- ---- Prediction Line (torso → future position) ----
            if cfg.ShowPredLine then
                local futurePos = _PredPos(root, cfg.PredTime)
                local torso = char:FindFirstChild("UpperTorso")
                           or char:FindFirstChild("Torso")
                           or root
                if futurePos and torso then
                    local sp1, on1 = cam:WorldToViewportPoint(torso.Position)
                    local sp2, on2 = cam:WorldToViewportPoint(futurePos)
                    if on1 or on2 then
                        local entry = _GetOrAddEntry(_pdActive.predLines, player, function()
                            return { line = _Take(_pdPool.predLines, _NewLine) }
                        end)
                        local l = entry.line
                        l.From      = _V2(sp1.X, sp1.Y)
                        l.To        = _V2(sp2.X, sp2.Y)
                        l.Color     = cfg.PredLineColor
                        l.Thickness = cfg.PredLineThickness
                        l.Visible   = true
                    else
                        _RemoveEntry(_pdActive.predLines, player, function(d)
                            _Return(_pdPool.predLines, d.line, _HideLine)
                        end)
                    end
                end
            else
                _RemoveEntry(_pdActive.predLines, player, function(d)
                    _Return(_pdPool.predLines, d.line, _HideLine)
                end)
            end

            -- ---- Velocity Vector (root → root + vel * scale) ----
            if cfg.ShowVelocity then
                local vel = _V3(0,0,0)
                pcall(function() vel = root.AssemblyLinearVelocity or root.Velocity or _V3(0,0,0) end)
                local velEnd = root.Position + vel * cfg.VelocityScale
                local sp1, on1 = cam:WorldToViewportPoint(root.Position)
                local sp2, on2 = cam:WorldToViewportPoint(velEnd)
                if on1 or on2 then
                    local entry = _GetOrAddEntry(_pdActive.velLines, player, function()
                        return { line = _Take(_pdPool.velLines, _NewLine) }
                    end)
                    local l = entry.line
                    l.From      = _V2(sp1.X, sp1.Y)
                    l.To        = _V2(sp2.X, sp2.Y)
                    l.Color     = cfg.VelocityColor
                    l.Thickness = 2
                    l.Visible   = true
                else
                    _RemoveEntry(_pdActive.velLines, player, function(d)
                        _Return(_pdPool.velLines, d.line, _HideLine)
                    end)
                end
            else
                _RemoveEntry(_pdActive.velLines, player, function(d)
                    _Return(_pdPool.velLines, d.line, _HideLine)
                end)
            end

            -- ---- Data Labels (velocidad, distancia, estado humanoid) ----
            if cfg.ShowDataLabels then
                local sp, onScreen = cam:WorldToViewportPoint(root.Position + _V3(0, 3.5, 0))
                if onScreen then
                    local vel = _V3(0,0,0)
                    pcall(function() vel = root.AssemblyLinearVelocity or root.Velocity or _V3(0,0,0) end)
                    local speed = math.floor(vel.Magnitude * 10) / 10
                    local dist  = lpRoot and math.floor((root.Position - lpRoot.Position).Magnitude) or 0
                    local state = "?"
                    if hum then
                        pcall(function()
                            state = tostring(hum:GetState()):match("HumanoidStateType%.(.+)") or "?"
                        end)
                    end
                    local predFuturePos = _PredPos(root, cfg.PredTime)
                    local predDist = predFuturePos and math.floor((predFuturePos - root.Position).Magnitude * 10) / 10 or 0

                    local labelText = string.format(
                        "[%s] spd:%.1f d:%dm\nstate:%s pred:%.1fstu",
                        player.Name, speed, dist, state, predDist
                    )

                    local entry = _GetOrAddEntry(_pdActive.dataLabels, player, function()
                        return { lbl = _Take(_pdPool.dataLabels, _NewText) }
                    end)
                    local lbl = entry.lbl
                    lbl.Text     = labelText
                    lbl.Position = _V2(sp.X, sp.Y)
                    lbl.Color    = cfg.DataLabelColor
                    lbl.Size     = cfg.DataLabelSize
                    lbl.Visible  = true
                else
                    _RemoveEntry(_pdActive.dataLabels, player, function(d)
                        _Return(_pdPool.dataLabels, d.lbl, _HideText)
                    end)
                end
            else
                _RemoveEntry(_pdActive.dataLabels, player, function(d)
                    _Return(_pdPool.dataLabels, d.lbl, _HideText)
                end)
            end
        end

        -- Hide entries for players not rendered this frame
        local function _HideNonRendered(list, releaseFn)
            local i = 1
            while i <= #list do
                local d = list[i]
                if not renderedPlayers[d.player] then
                    releaseFn(d)
                    table.remove(list, i)
                else
                    i = i + 1
                end
            end
        end

        if not cfg.ShowWaypoints then
            _HideNonRendered(_pdActive.waypointDots, function(d)
                for _, dot in ipairs(d.dots or {}) do
                    _Return(_pdPool.waypointDots, dot, _HideCircle)
                end
            end)
        end
        _HideNonRendered(_pdActive.predLines, function(d)
            _Return(_pdPool.predLines, d.line, _HideLine)
        end)
        _HideNonRendered(_pdActive.velLines, function(d)
            _Return(_pdPool.velLines, d.line, _HideLine)
        end)
        _HideNonRendered(_pdActive.dataLabels, function(d)
            _Return(_pdPool.dataLabels, d.lbl, _HideText)
        end)

        -- ---- Chunks grid ----
        if cfg.ShowChunks and lpRoot then
            -- Release old chunk lines/labels back to pool
            for _, l in ipairs(_chunkLinesActive) do
                _Return(_pdPool.chunkLines, l, _HideLine)
            end
            _tclr(_chunkLinesActive)
            for _, t in ipairs(_chunkLabelsActive) do
                _Return(_pdPool.chunkLabels, t, _HideText)
            end
            _tclr(_chunkLabelsActive)

            local sz   = cfg.ChunkSize
            local rad  = cfg.ChunkRadius
            local lp_y = lpRoot.Position.Y
            local cx0, cz0 = _ChunkCoord(lpRoot.Position, sz)

            for cx = cx0 - rad, cx0 + rad do
                for cz = cz0 - rad, cz0 + rad do
                    -- Four corners of this chunk
                    local p00 = _ChunkWorldPos(cx,   cz,   sz, lp_y)
                    local p10 = _ChunkWorldPos(cx+1, cz,   sz, lp_y)
                    local p01 = _ChunkWorldPos(cx,   cz+1, sz, lp_y)
                    local p11 = _ChunkWorldPos(cx+1, cz+1, sz, lp_y)

                    -- Draw 4 edges
                    local edges = {
                        {p00, p10}, {p10, p11}, {p11, p01}, {p01, p00},
                    }
                    for _, edge in ipairs(edges) do
                        local s1, o1 = cam:WorldToViewportPoint(edge[1])
                        local s2, o2 = cam:WorldToViewportPoint(edge[2])
                        if o1 or o2 then
                            local line = _Take(_pdPool.chunkLines, _NewLine)
                            line.From      = _V2(s1.X, s1.Y)
                            line.To        = _V2(s2.X, s2.Y)
                            line.Color     = cfg.ChunkColor
                            line.Thickness = cfg.ChunkThickness
                            line.Visible   = true
                            table.insert(_chunkLinesActive, line)
                        end
                    end

                    -- Chunk label at center
                    local centerWorld = _ChunkWorldPos(cx, cz, sz, lp_y)
                        + _V3(sz/2, 0, sz/2)
                    local sc, oc = cam:WorldToViewportPoint(centerWorld)
                    if oc then
                        local lbl = _Take(_pdPool.chunkLabels, _NewText)
                        lbl.Text     = string.format("(%d,%d)", cx, cz)
                        lbl.Position = _V2(sc.X, sc.Y)
                        lbl.Color    = cfg.ChunkLabelColor
                        lbl.Size     = cfg.ChunkLabelSize
                        lbl.Visible  = true
                        table.insert(_chunkLabelsActive, lbl)
                    end
                end
            end
        else
            for _, l in ipairs(_chunkLinesActive) do
                _Return(_pdPool.chunkLines, l, _HideLine)
            end
            _tclr(_chunkLinesActive)
            for _, t in ipairs(_chunkLabelsActive) do
                _Return(_pdPool.chunkLabels, t, _HideText)
            end
            _tclr(_chunkLabelsActive)
        end
    end

    Vars.pathDebugConn = RunService.RenderStepped:Connect(function()
        pcall(_UpdatePathDebug)
    end)

    Vars.CleanupPathDebug = function()
        if Vars.pathDebugConn then
            pcall(function() Vars.pathDebugConn:Disconnect() end)
            Vars.pathDebugConn = nil
        end
        _ClearAllPD()
        -- Release all pooled objects
        for _, dot in ipairs(_pdPool.waypointDots) do pcall(function() dot:Remove() end) end
        for _, l   in ipairs(_pdPool.predLines)    do pcall(function() l:Remove()   end) end
        for _, l   in ipairs(_pdPool.velLines)     do pcall(function() l:Remove()   end) end
        for _, l   in ipairs(_pdPool.chunkLines)   do pcall(function() l:Remove()   end) end
        for _, t   in ipairs(_pdPool.chunkLabels)  do pcall(function() t:Remove()   end) end
        for _, t   in ipairs(_pdPool.dataLabels)   do pcall(function() t:Remove()   end) end
    end

    -- --------------------------------------------------------
    -- UI — Debug Tab
    -- --------------------------------------------------------
    local Window = _env.TownUI_Window
    if Window then
        local DebugTab = Window:CreateTab("Debug")

        local DBMaster = DebugTab:CreateSection("PathFinder Visualizer")
        DBMaster:CreateToggle({ Text="PathFinder Debug Master", Default=false, Index="PD_Enabled",
            Callback=function(v)
                Settings.PathDebug.Enabled = v
                if not v then _ClearAllPD() end
            end })
        DBMaster:CreateLabel("Visualiza predicción de movimiento, waypoints y chunks en tiempo real.")
        DBMaster:CreateDropdown({ Text="Modo de target",
            Options={"All","AimbotTarget"}, Default="All", Index="PD_TargetMode",
            Callback=function(v) Settings.PathDebug.TargetMode = v end })
        DBMaster:CreateSlider({ Text="Distancia máxima", Min=50, Max=1000, Default=400, Index="PD_MaxDist",
            Callback=function(v) Settings.PathDebug.MaxDistance = v end })

        local DBWaypoints = DebugTab:CreateSection("Waypoints (Predicción)")
        DBWaypoints:CreateToggle({ Text="Mostrar Waypoints", Default=true, Index="PD_Waypoints",
            Callback=function(v) Settings.PathDebug.ShowWaypoints = v end })
        DBWaypoints:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(0,220,255), Index="PD_WPColor",
            Callback=function(c) Settings.PathDebug.WaypointColor = c end })
        DBWaypoints:CreateSlider({ Text="Cantidad de waypoints", Min=2, Max=20, Default=8, Index="PD_WPCount",
            Callback=function(v) Settings.PathDebug.WaypointCount = math.floor(v) end })
        DBWaypoints:CreateSlider({ Text="Intervalo (s)", Min=0.01, Max=0.3, Default=0.08, Index="PD_WPDt",
            Callback=function(v) Settings.PathDebug.WaypointDt = v end })
        DBWaypoints:CreateSlider({ Text="Radio del punto (px)", Min=2, Max=15, Default=6, Index="PD_WPRadius",
            Callback=function(v) Settings.PathDebug.WaypointRadius = v end })
        DBWaypoints:CreateLabel("Los puntos se desvanecen conforme se alejan en el tiempo.")

        local DBPredLine = DebugTab:CreateSection("Prediction Line")
        DBPredLine:CreateToggle({ Text="Mostrar línea de predicción", Default=true, Index="PD_PredLine",
            Callback=function(v) Settings.PathDebug.ShowPredLine = v end })
        DBPredLine:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(255,80,0), Index="PD_PLColor",
            Callback=function(c) Settings.PathDebug.PredLineColor = c end })
        DBPredLine:CreateSlider({ Text="Grosor", Min=1, Max=6, Default=2, Index="PD_PLThick",
            Callback=function(v) Settings.PathDebug.PredLineThickness = v end })
        DBPredLine:CreateSlider({ Text="Tiempo de predicción (s)", Min=0.05, Max=1.5, Default=0.35, Index="PD_PLTime",
            Callback=function(v) Settings.PathDebug.PredTime = v end })
        DBPredLine:CreateLabel("Línea naranja: torso → posición futura estimada.")

        local DBVel = DebugTab:CreateSection("Vector de Velocidad")
        DBVel:CreateToggle({ Text="Mostrar velocidad", Default=true, Index="PD_Velocity",
            Callback=function(v) Settings.PathDebug.ShowVelocity = v end })
        DBVel:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(0,255,80), Index="PD_VelColor",
            Callback=function(c) Settings.PathDebug.VelocityColor = c end })
        DBVel:CreateSlider({ Text="Escala visual", Min=0.05, Max=2, Default=0.4, Index="PD_VelScale",
            Callback=function(v) Settings.PathDebug.VelocityScale = v end })
        DBVel:CreateLabel("Línea verde: dirección y magnitud de velocidad actual.")

        local DBChunks = DebugTab:CreateSection("Chunks (Cuadrícula)")
        DBChunks:CreateToggle({ Text="Mostrar Chunks", Default=false, Index="PD_Chunks",
            Callback=function(v) Settings.PathDebug.ShowChunks = v end })
        DBChunks:CreateColorpicker({ Text="Color línea", Default=Color3.fromRGB(80,80,255), Index="PD_ChunkColor",
            Callback=function(c) Settings.PathDebug.ChunkColor = c end })
        DBChunks:CreateColorpicker({ Text="Color label", Default=Color3.fromRGB(200,200,255), Index="PD_ChunkLblColor",
            Callback=function(c) Settings.PathDebug.ChunkLabelColor = c end })
        DBChunks:CreateSlider({ Text="Tamaño de chunk (studs)", Min=4, Max=64, Default=16, Index="PD_ChunkSize",
            Callback=function(v) Settings.PathDebug.ChunkSize = math.floor(v) end })
        DBChunks:CreateSlider({ Text="Radio de chunks visibles", Min=1, Max=8, Default=3, Index="PD_ChunkRadius",
            Callback=function(v) Settings.PathDebug.ChunkRadius = math.floor(v) end })
        DBChunks:CreateSlider({ Text="Grosor de línea", Min=1, Max=4, Default=1, Index="PD_ChunkThick",
            Callback=function(v) Settings.PathDebug.ChunkThickness = v end })
        DBChunks:CreateLabel("Muestra la cuadrícula de chunks alrededor del LocalPlayer.")
        DBChunks:CreateLabel("Coordenadas (X,Z) de cada chunk visibles en pantalla.")

        local DBData = DebugTab:CreateSection("Data Labels")
        DBData:CreateToggle({ Text="Mostrar datos en tiempo real", Default=true, Index="PD_DataLabels",
            Callback=function(v) Settings.PathDebug.ShowDataLabels = v end })
        DBData:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(255,255,100), Index="PD_DataColor",
            Callback=function(c) Settings.PathDebug.DataLabelColor = c end })
        DBData:CreateSlider({ Text="Tamaño de texto", Min=8, Max=20, Default=13, Index="PD_DataSize",
            Callback=function(v) Settings.PathDebug.DataLabelSize = math.floor(v) end })
        DBData:CreateLabel("Muestra: nombre, velocidad, distancia, estado humanoid, desplazamiento predicho.")

        -- Script info section
        DebugTab:CreateSection("Script Info"):CreateLabel(
            "Executor: " .. tostring(Logger.ExecName) .. " " .. tostring(Logger.ExecVer))
        DebugTab:CreateSection("Script Info"):CreateButton("Abrir consola debug", function()
            local ok = Logger.OpenConsole()
            if Window.Notify then
                Window:Notify("Debug", ok and "Consola abierta" or "No soportado", 2, ok and "Success" or "Warning")
            end
        end)
    end

end

do
    local _originalCleanup = _env.TownComplete_Cleanup
    _env.TownComplete_Cleanup = function()
        if Vars.CleanupPathDebug then pcall(Vars.CleanupPathDebug) end
        if Vars.pathDebugConn then
            pcall(function() Vars.pathDebugConn:Disconnect() end)
            Vars.pathDebugConn = nil
        end
        Settings.PathDebug.Enabled = false
        _originalCleanup()
    end
end

do
    local RunService       = Vars.RunService
    local UserInputService = Vars.UserInputService
    local LP               = Vars.LP
    local Settings         = Vars.Settings
    local GetCamera        = Vars.GetCamera

    -- --------------------------------------------------------
    -- Settings block
    -- --------------------------------------------------------
    Settings.EnemyVis = {
        -- FOV Cone
        FOVCone         = false,
        FOVConeAngle    = 70,           -- grados totales del cono (FOV real del personaje)
        FOVConeLength   = 20,           -- studs de largo del cono
        FOVConeSegments = 12,           -- segmentos del arco
        FOVConeColor    = Color3.fromRGB(255, 60, 60),
        FOVConeAlpha    = 0.55,         -- transparencia (0=opaco 1=invisible)
        FOVConeThick    = 1.5,
        -- si el local player está dentro del cono → color de alerta
        FOVConeAlertColor = Color3.fromRGB(255, 0, 0),
        FOVConeIdleColor  = Color3.fromRGB(255, 180, 0),

        -- Look Vector
        LookVector       = false,
        LookVectorLength = 12,
        LookVectorColor  = Color3.fromRGB(255, 255, 0),
        LookVectorThick  = 2,
        -- dot indicator (punto de impacto visual)
        LookDot          = true,
        LookDotRadius    = 5,
        LookDotColor     = Color3.fromRGB(255, 80, 0),

        -- Velocity Arrows (3D → screen projected)
        VelArrows        = false,
        VelArrowColor    = Color3.fromRGB(0, 200, 255),
        VelArrowThick    = 2,
        VelArrowScale    = 0.35,        -- escala visual de la flecha
        VelArrowHead     = 6,           -- tamaño de la cabeza de flecha (px)
        VelMinSpeed      = 1,           -- velocidad mínima para mostrar flecha

        MaxDistance      = 400,
    }

    -- --------------------------------------------------------
    -- Box ESP fix — tamaño estable via Head + HRP solo
    -- Reemplaza GetBoundingVectors para el box ESP:
    -- usa puntos fijos del cuerpo en lugar de GetBoundingBox()
    -- que salta con animaciones.
    -- --------------------------------------------------------
    local function GetStableBoxVectors(char)
        if not char then return nil, nil, false end
        local cam = GetCamera(); if not cam then return nil, nil, false end

        local head = char:FindFirstChild("Head")
        local hrp  = char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("UpperTorso")
        if not head or not hrp then return nil, nil, false end

        -- Usa sólo Head (top) y HRP (base) para calcular el box.
        -- Añade offsets fijos en lugar de depender del bounding box animado.
        local topPos    = head.Position + _V3(0, 0.6, 0)   -- justo encima de la cabeza
        local bottomPos = hrp.Position  - _V3(0, 2.8, 0)   -- pies aproximados

        local function project(pos)
            local sp, on = cam:WorldToViewportPoint(pos)
            return _V2(sp.X, sp.Y), on
        end

        -- Proyectar 4 esquinas usando la mitad del ancho del HRP como referencia fija
        local halfW = 1.05  -- studs, aproximado para R15/R6
        local camRight = cam.CFrame.RightVector * halfW

        local tL, tLon = project(topPos    - camRight)
        local tR, tRon = project(topPos    + camRight)
        local bL, bLon = project(bottomPos - camRight)
        local bR, bRon = project(bottomPos + camRight)

        if not (tLon or tRon or bLon or bRon) then return nil, nil, false end

        local minX = math.min(tL.X, tR.X, bL.X, bR.X)
        local minY = math.min(tL.Y, tR.Y, bL.Y, bR.Y)
        local maxX = math.max(tL.X, tR.X, bL.X, bR.X)
        local maxY = math.max(tL.Y, tR.Y, bL.Y, bR.Y)

        local boxPos  = _V2(minX, minY)
        local boxSize = _V2(maxX - minX, maxY - minY)

        -- Clamp para evitar boxes gigantes fuera de pantalla
        if boxSize.X < 2 or boxSize.Y < 4
        or boxSize.X > 600 or boxSize.Y > 800 then
            return nil, nil, false
        end

        return boxPos, boxSize, true
    end
    -- Sobreescribir la función usada por UpdateESPForPlayer
    Vars.GetBoundingVectors = GetStableBoxVectors

    -- --------------------------------------------------------
    -- Inventory ESP fix — solo herramienta equipada, limpio
    -- El bug original mezclaba backpack + character sin separar.
    -- --------------------------------------------------------
    local function GetEquippedWeaponName(char)
        if not char then return nil end
        -- Solo busca el Tool actualmente en el Character (equipado)
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return nil end
        -- Nombre limpio: quita sufijos comunes de juegos como " [x2]", "(Upgraded)" etc.
        local name = tool.Name
        return name
    end

    -- Parcheamos UpdateESPForPlayer para usar GetEquippedWeaponName
    -- en lugar del campo weapon que ya existe — limpiamos el label.
    local _originalESPUpdate = Vars.UpdateESPForPlayer
    Vars.UpdateESPForPlayer = function(player)
        _originalESPUpdate(player)
        -- Fix weapon label: solo nombre de arma equipada, sin basura
        local esp  = Vars.ESPPool[player and player.Name]
        if not esp or not esp.weapon then return end
        local char = player and player.Character
        if not char then return end
        local weaponName = GetEquippedWeaponName(char)
        if Settings.ESP.Weapons and weaponName then
            -- Ya fue seteado por _originalESPUpdate, pero lo sobreescribimos limpio
            esp.weapon.Text = "🔫 " .. weaponName
        elseif Settings.ESP.Weapons and not weaponName then
            esp.weapon.Text = ""
            esp.weapon.Visible = false
        end
    end

    -- --------------------------------------------------------
    -- Drawing pools para EnemyVis
    -- --------------------------------------------------------
    local _evPool = {
        coneLines  = {},   -- arco del cono (segments+2 líneas por player)
        lookLines  = {},
        lookDots   = {},
        velLines   = {},   -- shaft de la flecha
        velHeads   = {},   -- 2 líneas de la cabeza de flecha
    }

    local _evActive = {} -- keyed by player.Name
    -- entry: { coneLines={}, lookLine=L, lookDot=C, velLine=L, velHead1=L, velHead2=L }

    local function _TakeLine()
        local l = table.remove(_evPool.coneLines)
        if l then l.Visible = false; return l end
        l = Drawing.new("Line"); l.Visible = false; return l
    end
    local function _TakeDot()
        local c = table.remove(_evPool.lookDots)
        if c then c.Visible = false; return c end
        c = Drawing.new("Circle"); c.Filled = true; c.NumSides = 12; c.Visible = false
        return c
    end
    local function _RetLine(l)
        l.Visible = false; table.insert(_evPool.coneLines, l)
    end
    local function _RetDot(c)
        c.Visible = false; table.insert(_evPool.lookDots, c)
    end

    local function _GetEntry(player)
        local e = _evActive[player.Name]
        if e then return e end
        -- allocate
        local cfg = Settings.EnemyVis
        local segs = cfg.FOVConeSegments + 2
        local clines = {}
        for i = 1, segs do table.insert(clines, _TakeLine()) end
        e = {
            coneLines = clines,
            lookLine  = _TakeLine(),
            lookLine2 = _TakeLine(),   -- second line for dot connector
            lookDot   = _TakeDot(),
            velLine   = _TakeLine(),
            velHead1  = _TakeLine(),
            velHead2  = _TakeLine(),
        }
        _evActive[player.Name] = e
        return e
    end

    local function _HideEntry(e)
        for _, l in ipairs(e.coneLines or {}) do l.Visible = false end
        if e.lookLine  then e.lookLine.Visible  = false end
        if e.lookLine2 then e.lookLine2.Visible = false end
        if e.lookDot   then e.lookDot.Visible   = false end
        if e.velLine   then e.velLine.Visible   = false end
        if e.velHead1  then e.velHead1.Visible  = false end
        if e.velHead2  then e.velHead2.Visible  = false end
    end

    local function _ReleaseEntry(name)
        local e = _evActive[name]
        if not e then return end
        for _, l in ipairs(e.coneLines or {}) do _RetLine(l) end
        if e.lookLine  then _RetLine(e.lookLine) end
        if e.lookLine2 then _RetLine(e.lookLine2) end
        if e.lookDot   then _RetDot(e.lookDot) end
        if e.velLine   then _RetLine(e.velLine) end
        if e.velHead1  then _RetLine(e.velHead1) end
        if e.velHead2  then _RetLine(e.velHead2) end
        _evActive[name] = nil
    end

    -- --------------------------------------------------------
    -- Helper: Is local player inside enemy FOV cone?
    -- --------------------------------------------------------
    local function _IsInCone(enemyHRP, lookVec, lpPos, halfAngleRad, length)
        if not enemyHRP or not lpPos then return false end
        local toLP = (lpPos - enemyHRP.Position)
        if toLP.Magnitude > length then return false end
        local flat = _V3(toLP.X, 0, toLP.Z).Unit
        local lf   = _V3(lookVec.X, 0, lookVec.Z)
        if lf.Magnitude < 0.01 then return false end
        lf = lf.Unit
        local dot = lf:Dot(flat)
        return dot >= math.cos(halfAngleRad)
    end

    -- --------------------------------------------------------
    -- Main EnemyVis loop
    -- --------------------------------------------------------
    local function _UpdateEnemyVis()
        if Vars.isScriptUnloaded then return end
        local cfg = Settings.EnemyVis
        local anyEnabled = cfg.FOVCone or cfg.LookVector or cfg.VelArrows
        if not anyEnabled then
            for name in pairs(_evActive) do _ReleaseEntry(name) end
            return
        end

        local cam = GetCamera(); if not cam then return end
        local lpChar = LP.Character
        local lpRoot = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
        local halfAng = math.rad(cfg.FOVConeAngle / 2)

        local rendered = {}

        for _, player in ipairs(Vars.activePlayers) do
            if not player or player == LP then continue end
            local char = player.Character; if not char then continue end
            local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then continue end
            local head = char:FindFirstChild("Head")

            -- Distance gate
            if lpRoot and cfg.MaxDistance > 0 then
                if (hrp.Position - lpRoot.Position).Magnitude > cfg.MaxDistance then continue end
            end

            rendered[player.Name] = true
            local e = _GetEntry(player)

            -- ---- FOV Cone ----
            if cfg.FOVCone then
                local lookXZ = _V3(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
                if lookXZ.Magnitude > 0.01 then lookXZ = lookXZ.Unit end
                local coneLen = cfg.FOVConeLength
                local segs    = cfg.FOVConeSegments
                local origin  = hrp.Position + _V3(0, 0.5, 0)

                local inCone = lpRoot and _IsInCone(hrp, hrp.CFrame.LookVector, lpRoot.Position, halfAng, coneLen)
                local color  = inCone and cfg.FOVConeAlertColor or cfg.FOVConeIdleColor

                -- Build arc points
                local arcPts = {}
                for i = 0, segs do
                    local t   = i / segs
                    local ang = -halfAng + t * (2 * halfAng)
                    local dir = CFrame.new(origin, origin + lookXZ)
                        * CFrame.Angles(0, ang, 0)
                    local worldPt = origin + dir.LookVector * coneLen
                    local sp, on  = cam:WorldToViewportPoint(worldPt)
                    table.insert(arcPts, { pos=_V2(sp.X, sp.Y), on=on })
                end
                local originSP, originOn = cam:WorldToViewportPoint(origin)
                local originV2 = _V2(originSP.X, originSP.Y)

                -- Left edge (origin → arc[0])
                local li = 1
                if e.coneLines[li] then
                    local l = e.coneLines[li]
                    if originOn or arcPts[1].on then
                        l.From = originV2; l.To = arcPts[1].pos
                        l.Color = color; l.Thickness = cfg.FOVConeThick
                        l.Transparency = cfg.FOVConeAlpha; l.Visible = true
                    else l.Visible = false end
                    li = li + 1
                end
                -- Arc segments
                for i = 1, #arcPts - 1 do
                    if e.coneLines[li] then
                        local l = e.coneLines[li]
                        if arcPts[i].on or arcPts[i+1].on then
                            l.From = arcPts[i].pos; l.To = arcPts[i+1].pos
                            l.Color = color; l.Thickness = cfg.FOVConeThick
                            l.Transparency = cfg.FOVConeAlpha; l.Visible = true
                        else l.Visible = false end
                        li = li + 1
                    end
                end
                -- Right edge (arc[last] → origin)
                if e.coneLines[li] then
                    local l = e.coneLines[li]
                    if originOn or arcPts[#arcPts].on then
                        l.From = arcPts[#arcPts].pos; l.To = originV2
                        l.Color = color; l.Thickness = cfg.FOVConeThick
                        l.Transparency = cfg.FOVConeAlpha; l.Visible = true
                    else l.Visible = false end
                    li = li + 1
                end
                -- Hide unused slots
                for i = li, #e.coneLines do e.coneLines[i].Visible = false end
            else
                for _, l in ipairs(e.coneLines) do l.Visible = false end
            end

            -- ---- Look Vector ----
            if cfg.LookVector and head then
                local lookDir  = head.CFrame.LookVector
                local startPos = head.Position
                local endPos   = startPos + lookDir * cfg.LookVectorLength

                local s1, o1 = cam:WorldToViewportPoint(startPos)
                local s2, o2 = cam:WorldToViewportPoint(endPos)

                if o1 or o2 then
                    local l = e.lookLine
                    l.From      = _V2(s1.X, s1.Y)
                    l.To        = _V2(s2.X, s2.Y)
                    l.Color     = cfg.LookVectorColor
                    l.Thickness = cfg.LookVectorThick
                    l.Visible   = true

                    -- Dot at tip
                    if cfg.LookDot then
                        local d = e.lookDot
                        d.Position    = _V2(s2.X, s2.Y)
                        d.Radius      = cfg.LookDotRadius
                        d.Color       = cfg.LookDotColor
                        d.Transparent = 0
                        d.Visible     = true
                    else
                        e.lookDot.Visible = false
                    end
                else
                    e.lookLine.Visible = false
                    e.lookDot.Visible  = false
                end
                e.lookLine2.Visible = false
            else
                e.lookLine.Visible  = false
                e.lookLine2.Visible = false
                e.lookDot.Visible   = false
            end

            -- ---- Velocity Arrows ----
            if cfg.VelArrows then
                local vel = _V3(0,0,0)
                pcall(function()
                    vel = hrp.AssemblyLinearVelocity or hrp.Velocity or _V3(0,0,0)
                end)
                local speed = vel.Magnitude
                if speed >= cfg.VelMinSpeed then
                    local scaledVel = vel * cfg.VelArrowScale
                    local tipWorld  = hrp.Position + scaledVel

                    local s1, o1 = cam:WorldToViewportPoint(hrp.Position)
                    local s2, o2 = cam:WorldToViewportPoint(tipWorld)

                    if o1 or o2 then
                        -- Arrow shaft
                        local shaft = e.velLine
                        local from2 = _V2(s1.X, s1.Y)
                        local to2   = _V2(s2.X, s2.Y)
                        shaft.From      = from2
                        shaft.To        = to2
                        shaft.Color     = cfg.VelArrowColor
                        shaft.Thickness = cfg.VelArrowThick
                        shaft.Visible   = true

                        -- Arrow head: two lines back from tip
                        local dx = to2.X - from2.X
                        local dy = to2.Y - from2.Y
                        local len = math.sqrt(dx*dx + dy*dy)
                        if len > 2 then
                            local ux = dx / len; local uy = dy / len
                            local hSize = cfg.VelArrowHead
                            -- perpendicular
                            local px = -uy; local py = ux
                            local hBase = _V2(to2.X - ux * hSize, to2.Y - uy * hSize)
                            e.velHead1.From = to2
                            e.velHead1.To   = _V2(hBase.X + px * hSize * 0.5,
                                                   hBase.Y + py * hSize * 0.5)
                            e.velHead1.Color     = cfg.VelArrowColor
                            e.velHead1.Thickness = cfg.VelArrowThick
                            e.velHead1.Visible   = true

                            e.velHead2.From = to2
                            e.velHead2.To   = _V2(hBase.X - px * hSize * 0.5,
                                                   hBase.Y - py * hSize * 0.5)
                            e.velHead2.Color     = cfg.VelArrowColor
                            e.velHead2.Thickness = cfg.VelArrowThick
                            e.velHead2.Visible   = true
                        else
                            e.velHead1.Visible = false
                            e.velHead2.Visible = false
                        end
                    else
                        e.velLine.Visible  = false
                        e.velHead1.Visible = false
                        e.velHead2.Visible = false
                    end
                else
                    e.velLine.Visible  = false
                    e.velHead1.Visible = false
                    e.velHead2.Visible = false
                end
            else
                e.velLine.Visible  = false
                e.velHead1.Visible = false
                e.velHead2.Visible = false
            end
        end

        -- Release entries for players no longer rendered
        for name in pairs(_evActive) do
            if not rendered[name] then _ReleaseEntry(name) end
        end
    end

    Vars.enemyVisConn = RunService.RenderStepped:Connect(function()
        pcall(_UpdateEnemyVis)
    end)

    Vars.CleanupEnemyVis = function()
        if Vars.enemyVisConn then
            pcall(function() Vars.enemyVisConn:Disconnect() end)
            Vars.enemyVisConn = nil
        end
        for name in pairs(_evActive) do _ReleaseEntry(name) end
        for _, l in ipairs(_evPool.coneLines) do pcall(function() l:Remove() end) end
        for _, c in ipairs(_evPool.lookDots)  do pcall(function() c:Remove() end) end
    end

    -- --------------------------------------------------------
    -- UI — añadir sección en la tab ESP 
    -- --------------------------------------------------------
    local Window = _env.TownUI_Window
    if Window then
        -- FOV Cone + Look Vector + Velocity Arrows → tab ESP nueva sección
        local ESPTab = Window:CreateTab("Enemy Vis")

        local EVMaster = ESPTab:CreateSection("Enemy Vis Master")
        EVMaster:CreateLabel("FOV Cone, Look Vector y Velocity Arrows sobre enemigos en pantalla.")
        EVMaster:CreateSlider({ Text="Distancia máxima", Min=50, Max=1000, Default=400, Index="EV_MaxDist",
            Callback=function(v) Settings.EnemyVis.MaxDistance = v end })

        local EVCone = ESPTab:CreateSection("FOV Cone (campo de visión)")
        EVCone:CreateToggle({ Text="Enemy FOV Cone", Default=false, Index="EV_Cone",
            Callback=function(v) Settings.EnemyVis.FOVCone = v end })
        EVCone:CreateSlider({ Text="Ángulo del cono (°)", Min=10, Max=180, Default=70, Index="EV_ConeAngle",
            Callback=function(v) Settings.EnemyVis.FOVConeAngle = v end })
        EVCone:CreateSlider({ Text="Largo del cono (studs)", Min=4, Max=60, Default=20, Index="EV_ConeLen",
            Callback=function(v) Settings.EnemyVis.FOVConeLength = v end })
        EVCone:CreateSlider({ Text="Segmentos del arco", Min=4, Max=24, Default=12, Index="EV_ConeSegs",
            Callback=function(v) Settings.EnemyVis.FOVConeSegments = math.floor(v) end })
        EVCone:CreateSlider({ Text="Grosor de línea", Min=1, Max=5, Default=1, Index="EV_ConeThick",
            Callback=function(v) Settings.EnemyVis.FOVConeThick = v end })
        EVCone:CreateSlider({ Text="Transparencia", Min=0, Max=1, Default=0.55, Index="EV_ConeAlpha",
            Callback=function(v) Settings.EnemyVis.FOVConeAlpha = v end })
        EVCone:CreateColorpicker({ Text="Color — alerta (estás en su FOV)",
            Default=Color3.fromRGB(255,0,0), Index="EV_ConeAlert",
            Callback=function(c) Settings.EnemyVis.FOVConeAlertColor = c end })
        EVCone:CreateColorpicker({ Text="Color — idle (no te ve)",
            Default=Color3.fromRGB(255,180,0), Index="EV_ConeIdle",
            Callback=function(c) Settings.EnemyVis.FOVConeIdleColor = c end })
        EVCone:CreateLabel("Rojo = estás dentro de su campo visual. Naranja = no te ve.")

        local EVLook = ESPTab:CreateSection("Look Vector (línea de mirada)")
        EVLook:CreateToggle({ Text="Look Vector", Default=false, Index="EV_LookVec",
            Callback=function(v) Settings.EnemyVis.LookVector = v end })
        EVLook:CreateSlider({ Text="Largo (studs)", Min=2, Max=40, Default=12, Index="EV_LookLen",
            Callback=function(v) Settings.EnemyVis.LookVectorLength = v end })
        EVLook:CreateSlider({ Text="Grosor", Min=1, Max=5, Default=2, Index="EV_LookThick",
            Callback=function(v) Settings.EnemyVis.LookVectorThick = v end })
        EVLook:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(255,255,0), Index="EV_LookColor",
            Callback=function(c) Settings.EnemyVis.LookVectorColor = c end })
        EVLook:CreateToggle({ Text="Punto de impacto (dot en el tip)", Default=true, Index="EV_LookDot",
            Callback=function(v) Settings.EnemyVis.LookDot = v end })
        EVLook:CreateColorpicker({ Text="Color del dot", Default=Color3.fromRGB(255,80,0), Index="EV_LookDotColor",
            Callback=function(c) Settings.EnemyVis.LookDotColor = c end })
        EVLook:CreateSlider({ Text="Radio del dot (px)", Min=2, Max=12, Default=5, Index="EV_LookDotRadius",
            Callback=function(v) Settings.EnemyVis.LookDotRadius = v end })
        EVLook:CreateLabel("Línea amarilla desde la cabeza → donde está mirando el enemigo.")

        local EVVel = ESPTab:CreateSection("Velocity Arrows (flechas de velocidad)")
        EVVel:CreateToggle({ Text="Velocity Arrows", Default=false, Index="EV_VelArrows",
            Callback=function(v) Settings.EnemyVis.VelArrows = v end })
        EVVel:CreateColorpicker({ Text="Color", Default=Color3.fromRGB(0,200,255), Index="EV_VelColor",
            Callback=function(c) Settings.EnemyVis.VelArrowColor = c end })
        EVVel:CreateSlider({ Text="Escala visual", Min=0.05, Max=2, Default=0.35, Index="EV_VelScale",
            Callback=function(v) Settings.EnemyVis.VelArrowScale = v end })
        EVVel:CreateSlider({ Text="Tamaño cabeza de flecha (px)", Min=2, Max=20, Default=6, Index="EV_VelHead",
            Callback=function(v) Settings.EnemyVis.VelArrowHead = v end })
        EVVel:CreateSlider({ Text="Velocidad mínima para mostrar", Min=0, Max=20, Default=1, Index="EV_VelMin",
            Callback=function(v) Settings.EnemyVis.VelMinSpeed = v end })
        EVVel:CreateSlider({ Text="Grosor", Min=1, Max=5, Default=2, Index="EV_VelThick",
            Callback=function(v) Settings.EnemyVis.VelArrowThick = v end })
        EVVel:CreateLabel("Flecha 2D desde el HRP en dirección del movimiento. Más larga = más rápido.")
    end
end

do
    local _prev = _env.TownComplete_Cleanup
    _env.TownComplete_Cleanup = function()
        if Vars.CleanupEnemyVis then pcall(Vars.CleanupEnemyVis) end
        if Vars.enemyVisConn then
            pcall(function() Vars.enemyVisConn:Disconnect() end)
            Vars.enemyVisConn = nil
        end
        _prev()
    end
end
