-- ============================================================
-- Town Complete v9.12 (Scryux UI)
-- Base: v9.10 (funcional) + Local Extras + Weld Abuse + Fling
-- ============================================================

local _env = getgenv and getgenv() or _G
local realPrint = print
local realWarn  = warn

rawset(_env, "__TownRealPrint", realPrint)
rawset(_env, "__TownRealWarn",  realWarn)

-- ============================================================
-- BLOQUE 0: Logger SILENCIOSO + Error Capturer
-- ============================================================
local Logger = {
    level = "ERROR",
    prefix = "[TownComplete] ",
    levels = {DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4},
    _silent = true,
    _consoleOpen = false,
}

local function _noop() end

local function _SafeRConsolePrint(msg)
    if type(rconsoleprint) ~= "function" then return end
    pcall(rconsoleprint, msg)
end

local function _LoggerEmit(level, ...)
    if Logger._silent then
        local dbg = rawget(_env, "TownDebug")
        if not dbg and not Logger._consoleOpen then return end
    end
    if Logger.levels[level] < Logger.levels[Logger.level] then return end
    local args = {...}
    local parts = {}
    for i = 1, #args do parts[i] = tostring(args[i]) end
    local line = Logger.prefix .. "[" .. level .. "] " .. table.concat(parts, " ")
    if Logger._consoleOpen then
        local tag = "@@WHITE@@"
        if level == "WARN"  then tag = "@@YELLOW@@" end
        if level == "ERROR" then tag = "@@LIGHT_RED@@" end
        if level == "INFO"  then tag = "@@LIGHT_GREEN@@" end
        if level == "DEBUG" then tag = "@@LIGHT_GRAY@@" end
        _SafeRConsolePrint(tag)
        _SafeRConsolePrint(line .. "\n")
        _SafeRConsolePrint("@@WHITE@@")
    else
        realPrint(line)
    end
end

function Logger.Debug(...) _LoggerEmit("DEBUG", ...) end
function Logger.Info(...)  _LoggerEmit("INFO",  ...) end
function Logger.Warn(...)  _LoggerEmit("WARN",  ...) end
function Logger.Error(...) _LoggerEmit("ERROR", ...) end

function Logger.OpenConsole()
    if type(rconsolecreate) ~= "function" then
        rawset(_env, "TownDebug", true)
        Logger._silent = false
        return false
    end
    local ok = pcall(rconsolecreate)
    if not ok then
        rawset(_env, "TownDebug", true)
        Logger._silent = false
        return false
    end
    if type(rconsolesettitle) == "function" then
        pcall(rconsolesettitle, "TownComplete Debug")
    end
    _SafeRConsolePrint("@@LIGHT_CYAN@@[TownComplete] Console debug abierta\n")
    _SafeRConsolePrint("@@LIGHT_GRAY@@Nivel actual: " .. Logger.level .. "\n")
    _SafeRConsolePrint("@@WHITE@@")
    Logger._consoleOpen = true
    Logger._silent = false
    return true
end

function Logger.CloseConsole()
    Logger._consoleOpen = false
    Logger._silent = true
    if type(rconsoledestroy) == "function" then
        pcall(rconsoledestroy)
    end
end

local _ExecName, _ExecVer = "Unknown", "?"
if type(identifyexecutor) == "function" then
    local ok, name, ver = pcall(identifyexecutor)
    if ok then
        _ExecName = name or _ExecName
        _ExecVer  = ver  or _ExecVer
    end
end
rawset(_env, "__TownExecutor", _ExecName .. " " .. _ExecVer)
Logger.ExecName = _ExecName
Logger.ExecVer  = _ExecVer

rawset(_env, "print", _noop)
rawset(_env, "warn",  _noop)

function Logger.RestoreGlobalPrint()
    rawset(_env, "print", realPrint)
    rawset(_env, "warn",  realWarn)
end

function Logger.SilenceGlobalPrint()
    rawset(_env, "print", _noop)
    rawset(_env, "warn",  _noop)
end

local function _GetStack(level)
    local lines = {}
    level = level or 2
    for i = level, level + 6 do
        local ok, info = pcall(debug.getinfo, i, "Sl")
        if not ok or not info then break end
        local src = info.short_src or info.source or "?"
        src = src:gsub("^@", "")
        local short = src:match("([^/\\]+)$") or src
        table.insert(lines, string.format("      - %s : linea %d", short, info.currentline or -1))
    end
    return lines
end

local function _ClassifyError(errStr)
    if not errStr then return "unknown" end
    local s = tostring(errStr):lower()
    if s:find("attempt to index", 1, true) then return "index" end
    if s:find("attempt to call", 1, true) then return "call" end
    if s:find("attempt to compare", 1, true) then return "compare" end
    if s:find("attempt to perform arithmetic", 1, true) then return "arith" end
    if s:find("attempt to concatenate", 1, true) then return "concat" end
    if s:find("is not a valid member", 1, true) then return "member" end
    if s:find("permission", 1, true) then return "perm" end
    if s:find("timeout", 1, true) then return "timeout" end
    if s:find("stack overflow", 1, true) then return "stack" end
    if s:find("http", 1, true) then return "http" end
    if s:find("json", 1, true) then return "json" end
    if s:find("nil", 1, true) then return "nil" end
    return "generic"
end

local _CAT_COLORS = {
    index    = "@@LIGHT_RED@@",
    call     = "@@LIGHT_RED@@",
    compare  = "@@LIGHT_RED@@",
    arith    = "@@LIGHT_RED@@",
    concat   = "@@LIGHT_RED@@",
    member   = "@@LIGHT_RED@@",
    perm     = "@@YELLOW@@",
    timeout  = "@@YELLOW@@",
    stack    = "@@LIGHT_MAGENTA@@",
    http     = "@@LIGHT_CYAN@@",
    json     = "@@LIGHT_CYAN@@",
    nil      = "@@YELLOW@@",
    generic  = "@@LIGHT_RED@@",
    unknown  = "@@WHITE@@",
}

local function _EmitError(context, errStr, errLevel, extraStackLevel)
    local s = tostring(errStr or "unknown error")
    local category = _ClassifyError(s)
    local color = _CAT_COLORS[category] or "@@LIGHT_RED@@"
    local ctxStr = tostring(context or "?")
    local sep = "-------------------------------"

    if Logger._consoleOpen then
        _SafeRConsolePrint("@@LIGHT_GRAY@@" .. sep .. "\n")
        _SafeRConsolePrint(color .. "[" .. ctxStr .. "] " .. category:upper() .. "\n")
        _SafeRConsolePrint("@@WHITE@@  " .. s .. "\n")
        local stack = _GetStack((errLevel or 2) + (extraStackLevel or 0))
        if #stack > 0 then
            _SafeRConsolePrint("@@LIGHT_GRAY@@  Stack:\n")
            for _, line in ipairs(stack) do
                _SafeRConsolePrint("@@LIGHT_GRAY@@" .. line .. "\n")
            end
        end
        _SafeRConsolePrint("@@LIGHT_GRAY@@" .. sep .. "\n")
        _SafeRConsolePrint("@@WHITE@@")
    elseif rawget(_env, "TownDebug") then
        realPrint(Logger.prefix .. "[" .. ctxStr .. "] " .. s)
        for _, line in ipairs(_GetStack((errLevel or 2) + (extraStackLevel or 0))) do
            realPrint(line)
        end
    end
end

function Logger.Err(context, err)
    _EmitError(context, err, 3)
end
Logger.ErrorWithHint = Logger.Err

function Logger.SafeCall(context, fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = xpcall(fn, function(err)
        return {
            msg = tostring(err),
            trace = debug.traceback("", 2),
        }
    end, ...)
    if not ok then
        local ctxStr = tostring(context or "SafeCall")
        if Logger._consoleOpen then
            local sep = "-------------------------------"
            _SafeRConsolePrint("@@LIGHT_GRAY@@" .. sep .. "\n")
            _SafeRConsolePrint("@@LIGHT_RED@@[" .. ctxStr .. "]\n")
            _SafeRConsolePrint("@@WHITE@@" .. (result.msg or "unknown") .. "\n")
            if result.trace then
                _SafeRConsolePrint("@@LIGHT_GRAY@@  Trace:\n")
                for line in tostring(result.trace):gmatch("[^\n]+") do
                    _SafeRConsolePrint("@@LIGHT_GRAY@@      " .. line .. "\n")
                end
            end
            _SafeRConsolePrint("@@LIGHT_GRAY@@" .. sep .. "\n@@WHITE@@")
        elseif rawget(_env, "TownDebug") then
            realPrint(Logger.prefix .. "[" .. ctxStr .. "] " .. (result.msg or "unknown"))
            if result.trace then realPrint(result.trace) end
        end
        return nil
    end
    return result
end

do
    local LogService = game:GetService("LogService")

    local function IsTownMessage(msg)
        if type(msg) ~= "string" then return false end
        return string.find(msg, "Town", 1, true) ~= nil
            or string.find(msg, "TownComplete", 1, true) ~= nil
            or string.find(msg, "TownUI", 1, true) ~= nil
    end

    rawset(_env, "__TownLogServiceConn", nil)

    local conn = LogService.MessageOut:Connect(function(message, msgType)
        if rawget(_env, "__TownUnloaded") then return end
        if msgType ~= Enum.MessageType.MessageError
            and msgType ~= Enum.MessageType.MessageWarning then
            return
        end
        if not IsTownMessage(message) then return end

        local isError = (msgType == Enum.MessageType.MessageError)
        local category = _ClassifyError(message)
        local color = isError and (_CAT_COLORS[category] or "@@LIGHT_RED@@") or "@@YELLOW@@"

        if Logger._consoleOpen then
            local sep = "-------------------------------"
            _SafeRConsolePrint("@@LIGHT_GRAY@@" .. sep .. "\n")
            _SafeRConsolePrint(color .. "[Uncaught] " .. (isError and "ERROR" or "WARN") .. "\n")
            _SafeRConsolePrint("@@WHITE@@" .. tostring(message) .. "\n")
            local stack = _GetStack(2)
            if #stack > 0 then
                _SafeRConsolePrint("@@LIGHT_GRAY@@  Stack:\n")
                for _, line in ipairs(stack) do
                    _SafeRConsolePrint("@@LIGHT_GRAY@@" .. line .. "\n")
                end
            end
            _SafeRConsolePrint("@@LIGHT_GRAY@@" .. sep .. "\n@@WHITE@@")
        elseif rawget(_env, "TownDebug") then
            realPrint(Logger.prefix .. "[Uncaught] " .. tostring(message))
        end
    end)

    rawset(_env, "__TownLogServiceConn", conn)
end

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
    local CACHE_VERSION = "v9.12"

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
        duration = 0.15,
        previousPlayer = nil,
    }
    Vars.TARGET_TRANSITION_DURATION = 0.15

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
    Vars.exploitWalkspeedCharConn = nil
    Vars.exploitJumpCharConn = nil

    Vars.infJumpConn = nil
    Vars.noGravityOriginal = nil
    Vars.watchOriginalCameraType = nil

    Vars.weldAbuseConn = nil
    Vars.weldAbuseActive = false
    Vars.weldAbuseTarget = nil
    Vars.weldAbuseSavedCFrame = nil

    Vars.flingConn = nil
    Vars.flingActive = false
    Vars.flingLastTime = 0

    Vars.touchFlingConn = nil
    Vars.touchFlingActive = false
    Vars.clickFlingTool = nil
    Vars.clickFlingConn = nil
    Vars.clickFlingActive = false

    Vars.WELD_OFFSETS = {
        Elevator    = { pos = Vector3.new(0, -3, 0),      rot = CFrame.Angles(math.rad(-90), 0, math.rad(3.34)) },
        HeadSit     = { pos = Vector3.new(0, 3, 0.9),     rot = CFrame.Angles(0, 0, 0) },
        Annoy       = { pos = Vector3.new(0, 2, 0),       rot = CFrame.Angles(0, 0, 0), random = true },
        Speed3      = { pos = Vector3.new(0, 0.7, 1),     rot = CFrame.Angles(0, 0, 0) },
        Speed5      = { pos = Vector3.new(0, 0.7, 0.5),   rot = CFrame.Angles(0, 0, 0) },
        Speed10     = { pos = Vector3.new(0, 0.7, 0.35),  rot = CFrame.Angles(0, 0, 0) },
        Bang        = { pos = Vector3.new(0, 0, 1.1),     rot = CFrame.Angles(0, 0, 0) },
        Jumpscare   = { pos = Vector3.new(0, 1.5, -0.8),  rot = CFrame.Angles(0, math.rad(180), 0) },
        MagicCarpet = { pos = Vector3.new(0, -3.6, 0),    rot = CFrame.Angles(math.rad(-90), 0, 0) },
        Platform    = { pos = Vector3.new(0, -4, 0),      rot = CFrame.Angles(math.rad(-90), 0, 0) },
        NoJump      = { pos = Vector3.new(0, 3.5, 0),     rot = CFrame.Angles(math.rad(-90), 0, 0) },
        Rocket      = { pos = Vector3.new(0, -3, 0),      rot = CFrame.Angles(math.rad(90), 0, math.rad(-69)) },
    }

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
                HeadZone = 0.22,
                TorsoZone = 0.55,
                LeftArmZoneX = 0.35,
                RightArmZoneX = 0.65,
                RequireVisible = false,
                MaxScreenDist = 250,
                HeadBonus = 0,
                TorsoBonus = 0,
            },
            Hybrid = {
                Enabled = false, BasePart = "Head",
                VerticalBiasThreshold = 0.15,
                DownwardSmoothness = 0.7, AllowReturn = false,
            },
            HelperSmoothness = 0.15, BaseSmoothness = 0.15,
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false,
            Priority = "FOV",
            StickyLock = false, StickyTimeout = 2,
            RequireGun = false,
            HumanMode = false,
            SwitchCooldown = 0.45,
            SwitchRange = 40,
            Humanize = true,
            JitterAmount = 0.35,
            JitterSpeed = 12,
            EaseStyle = "EaseOut",
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
            Smoothness = 0.5,
            Strength = 0.6,
            MaxSpeed = 30,
            Stickiness = 0.3,
            SnapRadius = 3,
            RequireMouseMovement = false,
            MouseMovementThreshold = 0.5,
            MouseStrength = 0.4,
            MovementMemory = 0.2,
            TeamCheck = false, IgnorePassive = false, WallCheck = false,
            Visible = true, UseMouse = false, Priority = "FOV",
            UsePrediction = false, PredictionAmount = 0.13,
            UsePingPrediction = false, Selective = false,
            HumanMode = true,
            SwitchCooldown = 0.5,
            SwitchRange = 30,
            JitterAmount = 0.25,
            EaseStyle = "EaseInOut",
            SmartNearest = {
                HeadZone = 0.22,
                TorsoZone = 0.55,
                LeftArmZoneX = 0.35,
                RightArmZoneX = 0.65,
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
            InfJump = false,
            NoGravity = false,
            Watch = false,
            WeldAbuseEnabled = false,
            WeldAbuseType = "HeadSit",
            WeldAbuseTargetName = nil,
            FlingEnabled = false,
            FlingVelocity = 1e25,
            FlingCooldown = 0.5,
            FlingLoop = false,
            FlingOnlyNearest = true,
            TouchFlingEnabled = false,
            ClickFlingEnabled = false,
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

