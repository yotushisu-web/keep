local function createDmcConfigStore(d)
local A = { Accent = "DEC173", RainbowUI = false, Selected = "", Storage = "Session only", Notice = "" }
local document = { schema = 1, profiles = {}, accent = A.Accent, rainbowUI = false, selected = "" }
local blockedFile = false
local boolKeys = { "Enabled", "CloseRangeRush", "HighBallJumps", "JumpThenDive",
"BackwardRecovery", "PositionAssist", "PreShotCoverage", "RespectManualMovement",
"LegitPrediction", "AutoAttack", "Randomizer" }
local diveModes = { SMART = true, FORWARD = true, LEFT = true, RIGHT = true, SIDES = true }
local function copy(value)
if type(value) ~= "table" then return value end
local result = {}
for key, item in pairs(value) do result[key] = copy(item) end
return result
end
function A.Color(value)
if type(value) ~= "string" then return nil end
local hex = value:match("^%s*#?([%x]+)%s*$")
return hex and #hex == 6 and string.upper(hex) or nil
end
local function name(value)
if type(value) ~= "string" then return nil end
value = value:match("^%s*(.-)%s*$")
if #value < 1 or #value > 40 or value:find("[%c]") then return nil end
return value
end
function A.Validate(value)
if type(value) ~= "table" or type(value.goalkeeper) ~= "table"
or type(value.striker) ~= "table" or type(value.misc) ~= "table" then return nil end
local gk, striker, misc = {}, {}, {}
for _, key in ipairs(boolKeys) do
if type(value.goalkeeper[key]) ~= "boolean" then return nil end
gk[key] = value.goalkeeper[key]
end
if not diveModes[value.goalkeeper.DiveFilter] then return nil end
if value.goalkeeper.PositionMode ~= "THREATS"
and value.goalkeeper.PositionMode ~= "HOME_AND_THREATS" then return nil end
gk.DiveFilter, gk.PositionMode = value.goalkeeper.DiveFilter, value.goalkeeper.PositionMode
for _, key in ipairs({ "Enabled", "AutoCurve", "SmartRelease", "Randomizer" }) do
if type(value.striker[key]) ~= "boolean" then return nil end
striker[key] = value.striker[key]
end
local range = value.striker.Range
if type(range) ~= "number" or range ~= range or range < 40 or range > 100 then return nil end
striker.Range = math.floor(range + 0.5)
for _, key in ipairs({ "AutoDribble" }) do
if type(value.misc[key]) ~= "boolean" then return nil end
misc[key] = value.misc[key]
end
local accent = A.Color(value.accent)
if not accent then return nil end
if value.rainbowUI ~= nil and type(value.rainbowUI) ~= "boolean" then return nil end
return { goalkeeper = gk, striker = striker, misc = misc, accent = accent, rainbowUI = value.rainbowUI == true }
end
local function decode(raw)
if type(raw) ~= "string" or #raw > 262144 then return false end
local ok, value = pcall(d.decode, raw)
if not ok or type(value) ~= "table" or value.schema ~= 1 or type(value.profiles) ~= "table" then return false end
local profiles, count = {}, 0
for key, profile in pairs(value.profiles) do
local validName, validProfile = name(key), A.Validate(profile)
if validName == key and validProfile and count < 50 then
profiles[key], count = validProfile, count + 1
else A.Notice = "Some invalid configs were skipped." end
end
document = { schema = 1, profiles = profiles, accent = A.Color(value.accent) or A.Accent,
rainbowUI = value.rainbowUI == true,
selected = name(value.selected) or "",
acknowledgedVersion = type(value.acknowledgedVersion) == "string" and value.acknowledgedVersion or nil }
if not profiles[document.selected] then document.selected = "" end
return true
end
local canFile = type(d.read) == "function" and type(d.write) == "function"
if type(d.cache) == "string" then decode(d.cache) end
if canFile then
local exists = true
if type(d.exists) == "function" then
local ok, result = pcall(d.exists, d.path)
if ok then exists = result == true end
end
if exists then
local ok, raw = pcall(d.read, d.path)
if ok and not decode(raw) then
blockedFile = true
A.Notice = "Settings file is unreadable; saved configs in that file were kept untouched."
elseif not ok and type(d.exists) == "function" then
blockedFile = true
A.Notice = "Settings file could not be read; using this session."
end
end
A.Storage = blockedFile and "Session only · file unavailable" or "Local file · " .. d.path
end
A.Accent, A.RainbowUI, A.Selected = document.accent, document.rainbowUI, document.selected
local function persist()
document.accent, document.rainbowUI, document.selected = A.Accent, A.RainbowUI, A.Selected
local ok, encoded = pcall(d.encode, document)
if not ok then return false, "Could not encode settings." end
d.remember(encoded)
if canFile and not blockedFile then
local written, result = pcall(d.write, d.path, encoded)
if written and result ~= false then A.Storage = "Local file · " .. d.path; return true, "Saved to local file." end
A.Storage = "Session only · file write failed"
return true, "Saved for this session; the executor could not write the file."
end
return true, "Saved for this session; file storage is unavailable."
end
function A.List()
local names = {}
for key in pairs(document.profiles) do names[#names + 1] = key end
table.sort(names, function(a, b)
if string.lower(a) == string.lower(b) then return a < b end
return string.lower(a) < string.lower(b)
end)
return names
end
function A.Select(value)
if not document.profiles[value] then return false end
A.Selected = value
return true
end
function A.Save(value, profile, creating)
local validName, validProfile = name(value), A.Validate(profile)
if not validName then return false, "Enter a config name (1–40 characters)." end
if not validProfile then return false, "Current settings could not be saved." end
if creating and document.profiles[validName] then return false, "Name already exists. Select it and press Save." end
if not creating and not document.profiles[validName] then return false, "Select a config before saving." end
if creating and #A.List() >= 50 then return false, "Config limit reached (50)." end
local previous, selected = document.profiles[validName], A.Selected
document.profiles[validName], A.Selected = validProfile, validName
local ok, detail = persist()
if not ok then document.profiles[validName], A.Selected = previous, selected end
return ok, detail
end
function A.Get(value)
return copy(document.profiles[value])
end
function A.SetAppearance(value, rainbow)
local hex = A.Color(value)
if not hex then return false, "Use a six-digit hex color, for example #DEC173." end
if type(rainbow) ~= "boolean" then return false, "Rainbow UI must be on or off." end
local previousAccent, previousRainbow = A.Accent, A.RainbowUI
A.Accent, A.RainbowUI = hex, rainbow
local ok, detail = persist()
if not ok then A.Accent, A.RainbowUI = previousAccent, previousRainbow end
return ok, detail
end
function A.SetAccent(value)
return A.SetAppearance(value, A.RainbowUI)
end
function A.SetRainbowUI(value)
return A.SetAppearance(A.Accent, value)
end
function A.ShouldPrompt(previousBuild, currentBuild)
if document.acknowledgedVersion then return document.acknowledgedVersion ~= d.version end
return type(previousBuild) == "string" and previousBuild ~= currentBuild
end
function A.Acknowledge()
if document.acknowledgedVersion == d.version then return true end
document.acknowledgedVersion = d.version
return persist()
end
return A
end

-- Configs use the same feature setters as the controls. A refused native setter
-- rolls settings back instead of displaying a successful load.
local function createDmcSettingsController(d)
local A = {}
function A.Snapshot()
local gk = {}
for _, key in ipairs({ "CloseRangeRush", "HighBallJumps", "JumpThenDive", "BackwardRecovery",
"PositionAssist", "PreShotCoverage", "RespectManualMovement", "PositionMode",
"LegitPrediction", "AutoAttack" }) do gk[key] = d.config[key] end
gk.Enabled = d.gkEnabled()
gk.DiveFilter = d.config.DiveFilter == "ALL" and "SMART" or d.config.DiveFilter
return { goalkeeper = gk,
striker = {
Enabled = d.striker.Enabled,
AutoCurve = d.striker.AutoCurve,
SmartRelease = d.striker.SmartRelease,
Randomizer = d.striker.Randomizer,
Range = d.striker.GetAssistRange() },
misc = { AutoDribble = d.misc.AutoDribble },
accent = d.accent(), rainbowUI = d.rainbow and d.rainbow() == true or false }
end
local function apply(profile)
local function feature(object, key, value)
if object[key] == value then return end
assert(object["Set" .. key](value) ~= false, key .. " could not be changed")
assert(object[key] == value, key .. " did not accept the setting")
end
feature(d.striker, "AutoCurve", profile.striker.AutoCurve)
feature(d.striker, "SmartRelease", profile.striker.SmartRelease)
feature(d.striker, "Randomizer", profile.striker.Randomizer)
feature(d.striker, "Enabled", profile.striker.Enabled)
assert(d.striker.SetAssistRange(profile.striker.Range) ~= false, "Shot range could not be changed")
feature(d.misc, "AutoDribble", profile.misc.AutoDribble)
for key, value in pairs(profile.goalkeeper) do if key ~= "Enabled" then d.config[key] = value end end
d.resetGoalkeeper()
if d.gkEnabled() ~= profile.goalkeeper.Enabled then d.setGK(profile.goalkeeper.Enabled) end
d.theme(profile.accent)
if d.setRainbow then d.setRainbow(profile.rainbowUI == true) end
end
function A.Load(profile)
local valid = d.validate(profile)
if not valid then return false, "Config is invalid; settings were not changed." end
local previous = A.Snapshot()
local ok, err = pcall(apply, valid)
if ok then return true, "Config loaded." end
local restored = pcall(apply, previous)
return false, "Config load failed: " .. tostring(err)
.. (restored and ". Previous settings restored." or ". Some settings could not be restored; check the toggles.")
end
return A
end

local function showDmcUpdatePrompt(parent, hex)
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "DmcUpdate", false, 1001
gui.IgnoreGuiInset = true
local shade = Instance.new("Frame")
shade.Size, shade.BackgroundColor3, shade.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.fromRGB(0, 0, 0), 0.45
shade.Active, shade.BorderSizePixel, shade.Parent = true, 0, gui
local accent = Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
local panel = Instance.new("Frame")
panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.4)
panel.Size, panel.BackgroundColor3, panel.BorderSizePixel = UDim2.new(0.9, 0, 0, 200), Color3.fromRGB(16, 16, 15), 0
panel.Parent = shade
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(460, 200), panel
local heading = Instance.new("TextLabel")
heading.Position, heading.Size = UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 28)
heading.BackgroundTransparency, heading.TextSize, heading.Font = 1, 18, Enum.Font.FredokaOne
heading.TextXAlignment, heading.TextColor3, heading.Text, heading.Parent = Enum.TextXAlignment.Left, accent, "Dmc | Script updated", panel
local message = Instance.new("TextLabel")
message.Position, message.Size = UDim2.fromOffset(14, 52), UDim2.new(1, -28, 0, 56)
message.BackgroundTransparency, message.TextWrapped, message.TextSize = 1, true, 16
message.Font, message.TextColor3 = Enum.Font.Nunito, Color3.fromRGB(242, 243, 240)
message.Text, message.Parent = "Script updated press OK to continue", panel
local okButton = Instance.new("TextButton")
okButton.AnchorPoint, okButton.Position, okButton.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, -58), UDim2.fromOffset(100, 36)
okButton.Name, okButton.Text, okButton.TextSize, okButton.Font = "OK", "OK", 16, Enum.Font.FredokaOne
okButton.BackgroundColor3, okButton.TextColor3, okButton.BorderSizePixel = accent, Color3.fromRGB(16, 16, 15), 0
okButton.Modal, okButton.Parent = true, panel
local acknowledged = false
local connection = okButton.Activated:Connect(function() acknowledged = true end)
gui.Parent = parent
local waited, err = pcall(function()
while gui.Parent and not acknowledged do task.wait(0.05) end
end)
connection:Disconnect()
gui:Destroy()
assert(waited, err)
return acknowledged
end

-- Small, dependency-free startup controller. Game modules are loaded only after
-- its status panel is visible. No executor-specific GUI or identity API is needed.
local function createDmcStartup(d)
local B = {
stage = "Waiting for the game", finished = false,
cleanup = nil :: (() -> (boolean?, string?))?,
error = nil :: string?,
}
function B.Status(text)
B.stage = text
if not B.finished then pcall(d.show, "Dmc | Starting", text) end
end
function B.Load(path)
B.Status("Loading " .. path)
local object = d.resolve(path)
local result, closed
d.spawn(function()
local values = table.pack(pcall(d.require, object))
if not closed then result = values end
end)
local deadline = d.now() + 30
while not result and d.now() < deadline do d.wait() end
closed = true
assert(result, "Timed out loading " .. path .. ". The game module did not return within 30 seconds.")
assert(result[1], "Cannot load " .. path .. ": " .. tostring(result[2]))
assert(type(result[2]) == "table", "Unexpected module result: " .. path)
return result[2]
end
function B.Run(main)
B.Status(B.stage)
local ok, err = pcall(function() d.ready(); main(B) end)
B.finished = true
if ok then
pcall(d.hide)
else
local message = tostring(err)
local cleanup = B.cleanup
if cleanup then
local cleaned, released = pcall(cleanup)
if not cleaned or released == false then message = message .. "\nCleanup incomplete; rejoin before retrying." end
end
B.error = message
d.warn("[Dmc startup] " .. message)
pcall(d.show, "Dmc | Startup failed", message .. "\n\nSend this error and your executor name when reporting the problem.")
end
return ok, err
end
return B
end

local function createDmcStartupDisplay()
local gui, label, heading, closeConnection
local function hide()
if closeConnection then closeConnection:Disconnect(); closeConnection = nil end
if gui then gui:Destroy(); gui = nil end
end
local function show(title, message)
if not gui then
local player = game:GetService("Players").LocalPlayer
local parent = player and player:FindFirstChildOfClass("PlayerGui")
if not parent then return end
gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "DmcStartup", false, 1000
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position, panel.Size = UDim2.new(0.5, 0, 0.4, 0), UDim2.new(0.9, 0, 0, 200)
panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(16, 16, 15), 0
panel.Parent = gui
local size = Instance.new("UISizeConstraint")
size.MaxSize = Vector2.new(460, 200); size.Parent = panel
heading = Instance.new("TextLabel")
heading.Position, heading.Size = UDim2.new(0, 14, 0, 8), UDim2.new(1, -58, 0, 28)
heading.BackgroundTransparency, heading.TextSize = 1, 16
heading.TextXAlignment, heading.Font = Enum.TextXAlignment.Left, Enum.Font.GothamMedium
heading.TextColor3 = Color3.fromRGB(222, 193, 115); heading.Parent = panel
label = Instance.new("TextBox")
label.Position, label.Size = UDim2.new(0, 14, 0, 44), UDim2.new(1, -28, 1, -54)
label.BackgroundTransparency, label.TextSize, label.TextWrapped = 1, 13, true
label.ClearTextOnFocus, label.TextEditable, label.MultiLine = false, false, true
label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
label.Font, label.TextColor3 = Enum.Font.Code, Color3.fromRGB(233, 231, 220)
label.Parent = panel
local close = Instance.new("TextButton")
close.Text, close.TextSize = "X", 14
close.Position, close.Size = UDim2.new(1, -38, 0, 8), UDim2.new(0, 28, 0, 28)
close.BackgroundColor3, close.TextColor3 = Color3.fromRGB(39, 37, 30), heading.TextColor3
close.Parent = panel
closeConnection = close.Activated:Connect(hide)
gui.Parent = parent
end
heading.Text, label.Text = title, message
end
return show, hide
end

local startupShow, startupHide = createDmcStartupDisplay()
local BOOT = createDmcStartup({
now = os.clock, wait = function() task.wait(0.05) end, spawn = task.spawn,
require = require, warn = warn, show = startupShow, hide = startupHide,
ready = function()
local players = game:GetService("Players")
local deadline = os.clock() + 30
while (not game:IsLoaded() or not players.LocalPlayer) and os.clock() < deadline do
startupShow("Dmc | Starting", "Waiting for the game to finish loading...")
task.wait(0.1)
end
assert(game:IsLoaded() and players.LocalPlayer, "Game client was not ready after 30 seconds. Join the game before running Dmc.")
assert(players.LocalPlayer:WaitForChild("PlayerGui", 30), "PlayerGui is unavailable.")
startupShow("Dmc | Starting", "Loading game modules...")
end,
resolve = function(path)
local object = game:GetService("ReplicatedStorage")
local deadline = os.clock() + 30
for name in string.gmatch(path, "[^.]+") do
object = object:WaitForChild(name, math.max(0.01, deadline - os.clock()))
assert(object, "Missing dependency: " .. path .. ". Run Dmc in the supported game after it loads.")
end
return object
end,
})

BOOT.Run(function()
-- DMC MAIN BEGIN
--==============================================================
-- SERVICES
--==============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = assert(Players.LocalPlayer, "Run this on the client")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
-- Bump the release ID for every shipped update to trigger the one-time OK prompt.
local RELEASE_VERSION = "2026.10.02.1"
local BUILD = "Dmc Settings 1.5.2 | GK 3.2.7 | STR 0.16.3 | Misc 0.18.0 | Evaluation 0.2"
local ENV = _G
if type(getgenv) == "function" then
local ok, environment = pcall(getgenv)
if ok and type(environment) == "table" then ENV = environment end
end

local settingsHttp = game:GetService("HttpService")
local SettingsStore = createDmcConfigStore({
version = RELEASE_VERSION, path = "Dmc_settings.json", cache = ENV.__DMC_CONFIG_CACHE,
read = readfile, write = writefile, exists = isfile,
encode = function(value) return settingsHttp:JSONEncode(value) end,
decode = function(value) return settingsHttp:JSONDecode(value) end,
remember = function(value) ENV.__DMC_CONFIG_CACHE = value end,
})

-- Keep the current instance running until all dependencies have loaded.
--==============================================================
-- MODULES
--==============================================================
local function resolve(path)
local object = ReplicatedStorage
for name in string.gmatch(path, "[^.]+") do
object = object:WaitForChild(name, 5)
assert(object, "Missing dependency: " .. path)
end
return object
end

local function module(path)
return BOOT.Load(path)
end

local M = {
Dive = module("Modules.Actions.GoalkeeperDive"),
Assist = module("Modules.Actions.GoalkeeperDiveAssist"),
Actions = module("Modules.Actions.ActionCommands"),
Protocol = module("Modules.Actions.ActionRemoteProtocol"),
Locks = module("Modules.Actions.ActionLocks"),
Contacts = module("Modules.Actions.GoalkeeperActions"),
Physics = module("Modules.Ball.Physics"),
Hitboxes = module("Modules.Gameplay.HitboxSettings"),
Prediction = module("Modules.Gameplay.GoalkeeperPrediction"),
Match = module("Modules.Gameplay.MatchSettings"),
Controllers = module("Modules.Characters.CharacterControllers"),
Grounding = module("Modules.Characters.Grounding"),
Ragdoll = module("Modules.Characters.Ragdoll"),
Renderer = module("Client.Gameplay.Ball.Renderer"),
Teams = module("Client.Gameplay.ActorTeams"),
Practice = module("Client.Gameplay.PracticeSession"),
Movement = module("Client.Gameplay.Player.Movement"),
Presentation = module("Client.Gameplay.Actions.GoalkeeperDivePresentation"),
Slide = module("Client.Gameplay.Actions.SlideTackleInput"),
Dodge = module("Client.Gameplay.Actions.Dodge"),
Freeze = module("Client.Gameplay.KickoffFreeze"),
Replay = module("Client.Gameplay.Replay.GoalReplay"),
Clock = module("Client.Player.CharacterMotionSmoothing"),
Keybinds = module("Modules.Gameplay.Keybinds"),
Role = module("Client.Gameplay.Player.GoalkeeperRole"),
Actors = module("Modules.Characters.Actors"),
Motion = module("Modules.Characters.CharacterMotion"),
}

local BallRemotes = resolve("Remotes.Ball")
local TackleRemote = BallRemotes:WaitForChild("Tackle", 5)
local StateRemote = BallRemotes:WaitForChild("State", 5)

assert(TackleRemote and StateRemote and PlayerGui, "Client is not ready")

if SettingsStore.ShouldPrompt(ENV.AutoGKBuild, BUILD) then
BOOT.Status("Waiting for update confirmation")
assert(showDmcUpdatePrompt(PlayerGui, SettingsStore.Accent), "Update confirmation was closed before OK.")
SettingsStore.Acknowledge()
end

if type(ENV.__AUTO_GK_CLEANUP) == "function" then
local called, released, detail = pcall(ENV.__AUTO_GK_CLEANUP)
assert(called, "Previous Auto GK cleanup threw: " .. tostring(released))
assert(released == true,
"Previous Auto GK cleanup was not confirmed: "
.. tostring(detail or "Older cleanup has no success result; rejoin once before loading this version"))
end

--==============================================================
-- CONFIGURATION
--==============================================================
local Config = {
Enabled = true,
PositionAssist = true,
PreShotCoverage = true,
CoverageRange = 65,
CoverageMinimumDepth = 3,
CoverageLeadSeconds = 0.10,
CoverageMaximumLead = 2,
CoverageStartRadius = 0.90,
CoverageStopRadius = 0.45,
CoverageUpdateHz = 20,
UrgentShotSeconds = 0.55,
PositionMode = "THREATS",
RespectManualMovement = true,
HighBallJumps = true,
JumpThenDive = true,
DiveFilter = "SMART",
BackwardRecovery = true,
PlannerHz = 12,
CloseShotPlannerHz = 30,
UISampleHz = 4,
SampleStep = 0.01,
PredictionHorizon = 1.10,
GoalMarginSeconds = 0.045,
JumpQueueEstimate = 0.05,
JumpQueueTimeout = 0.45,
JumpDiveMinimumAge = 0.07,
JumpRetrySeconds = 0.65,
HomeDepth = 8,
HomeRadius = 2.5,
PositionDeadzone = 0.65,
SafeLateralReach = 14,
PositionResponseSeconds = 0.14,
PositionStartDeadzone = 1.15,
HomeStopRadius = 1.25,
TargetChangeDeadzone = 0.20,
TargetResponseSeconds = 0.16,
ManualReleaseGrace = 0.18,
CachedFrameMaxAge = 0.12,
MissingStateDisplayDelay = 0.40,
UIStatusDebounce = 0.18,
UIEventHoldSeconds = 0.50,
MaxFinalCandidates = 14,
RuntimeErrorRetrySeconds = 0.25,
RuntimeErrorLimit = 3,
Debug = false,
LegitPrediction = false,
AutoAttack = false,
}

local Stats = {
Requests = 0,
JumpRequests = 0,
DiveRequests = 0,
FlightsActedOn = 0,
CatchesObserved = 0,
ActionMatches = 0,
Rejected = 0,
}

ENV.AutoGKConfig = Config
ENV.AutoGKStats = Stats
ENV.AUTO_GK_ENABLED = true
ENV.AutoGKBuild = BUILD

--==============================================================
-- LIFECYCLE
--==============================================================
local S = {
alive = true,
cleanupComplete = false,
cleaningUp = false,
cleanupError = nil,
closeDropdown = nil,
cancelUITweens = nil,
releaseOwnedState = nil,
releaseStriker = nil,
releaseMisc = nil,
releaseEvaluation = nil,
connections = {},
status = "STARTING",
detail = "",
nextActionAt = 0,
nextJumpAt = 0,
nextPlanAt = 0,
queueEstimate = Config.JumpQueueEstimate,
jump = nil,
controller = nil,
ownedMove = nil,
moveCharacter = nil,
lastChar = nil,
lastFrame = nil,
nextUIAt = 0,
pending = nil,
lastWarning = {},
catches = {},
coverageFrame = nil,
coverageNextAt = 0,
coverageWrites = 0,
plannerMilliseconds = 0,
immediatePlansChecked = 0,
delayedPlansChecked = 0,
lastPlanReason = "NONE",
loopBusy = false,
runtimeFailures = 0,
runtimeRetryAt = 0,
runtimeError = nil,
countedFlights = {},
wasKeeper = false,
manualActionUntil = 0,
motionLease = nil,
nextLeaseId = 0,
orphanedLease = nil,
uiBusy = false,
retiredLocks = {},
retiredMotions = {},
jumpBlockOwned = false,
uiClosers = {},
ownLockAcquires = 0,
ownLockReleases = 0,
goalBasis = setmetatable({}, { __mode = "k" }),
stick = Vector2.zero,
touches = {},
focused = true,
ui = nil,
allowPositioning = false,
positionActive = false,
positionTarget = nil,
positionKey = nil,
positionChangedAt = 0,
manualUntil = 0,
positionWrites = 0,
releaseWrites = 0,
releaseReasons = {},
lastReleaseReason = "NONE",
holdStops = 0,
holdRechecks = 0,
holdRecheckMisses = 0,
followupBlocks = 0,
lastFollowupBlock = nil,
ballPhase = "STARTING",
ballInfo = "",
ballSignature = nil,
missingSince = nil,
currentContext = nil,
observedBallId = nil,
displayName = "STARTING",
displayDetail = "",
displayUntil = 0,
displayCandidate = nil,
displayCandidateSince = 0,
moveLock = "AutoGK.ContactTest."
.. tostring(math.floor(os.clock() * 1000000)),
}

-- Installed before listeners so partial initialization has the same cleanup contract.
local function cleanup()
if S.cleanupComplete then return true end
if S.cleaningUp then return false, "Cleanup is already running" end

S.cleaningUp = true
S.alive = false
ENV.AUTO_GK_ENABLED = false
local failures = {}

local function attempt(label, fn, ...)
local ok, result, detail = pcall(fn, ...)
if not ok or result == false then
failures[#failures + 1] = label .. ": "
.. tostring(ok and (detail or "release refused") or result)
return false
end
return true
end

if S.closeDropdown then attempt("UI close", S.closeDropdown) end
if S.cancelUITweens then attempt("UI tweens", S.cancelUITweens) end

if S.releaseMisc then attempt("Miscellaneous", S.releaseMisc) end
if S.releaseStriker then attempt("Striker hooks", S.releaseStriker) end
if S.releaseEvaluation then attempt("Evaluation observers", S.releaseEvaluation) end

if S.releaseOwnedState then
attempt("Owned state", S.releaseOwnedState, true)
end

-- Retain failed handles so a later call can retry them.
local remaining = {}
for _, connection in ipairs(S.connections) do
if not attempt("Disconnect", function() connection:Disconnect() end) then
remaining[#remaining + 1] = connection
end
end
S.connections = remaining

if S.ui and attempt("UI destroy", function() S.ui:Destroy() end) then
S.ui = nil
S.closeDropdown = nil
S.cancelUITweens = nil
S.isUIInput = nil
end

if S.loopBusy then
failures[#failures + 1] = "Main update is still finishing; retry cleanup"
end

if S.ownedMove or S.jump or S.jumpBlockOwned or S.motionLease
or S.controller or next(S.retiredLocks) or next(S.retiredMotions) then
failures[#failures + 1] = "Owned movement resources remain"
end

S.cleanupComplete = #failures == 0
S.cleanupError = #failures > 0 and table.concat(failures, "; ") or nil
S.cleaningUp = false

if S.cleanupComplete then
ENV.__AUTO_GK_CONTROLLER = nil
else
warn("[Auto GK] Cleanup incomplete: " .. S.cleanupError)
end

return S.cleanupComplete, S.cleanupError
end

ENV.__AUTO_GK_CLEANUP = cleanup
ENV.StopAutoGK = cleanup
BOOT.cleanup = cleanup

local function connect(signal, fn)
local c = signal:Connect(fn)
table.insert(S.connections, c)
return c
end

local function log(message)
if Config.Debug then
print("[Auto GK] " .. message)
end
end

local function report(key, message)
if os.clock() >= (S.lastWarning[key] or 0) then
S.lastWarning[key] = os.clock() + 4
warn("[Auto GK] " .. key .. ": " .. tostring(message))
end
end

local function flushStatusDisplay()
if not S.displayCandidate then return end

local clock = os.clock()

if clock >= S.displayUntil
and clock - S.displayCandidateSince
>= Config.UIStatusDebounce then

S.displayName = S.status
S.displayDetail = S.detail
S.displayCandidate = nil
end
end

local function status(name: string, detail)
S.status = name
S.detail = detail or ""

if S.displayName == name then
S.displayDetail = S.detail
S.displayCandidate = nil
return
end

local event =
name == "CATCH OBSERVED"
or name == "SERVER REJECTED"
or name == "JUMP QUEUED"
or name == "CLOSE-RANGE RUSH"
or string.sub(name, 1, 9) == "DIVE SENT"

local immediate =
event
or name == "OFF"
or name == "NO CHARACTER"
or name == "WAITING FOR GK"
or name == "RUNTIME ERROR"
or name == "MANUAL SLIDE"
or name == "MANUAL DODGE"
or name == "RAGDOLL"
or name == "ROUND TRANSITION"
or name == "WINDOW UNFOCUSED"

if immediate then
S.displayName = name
S.displayDetail = S.detail
S.displayCandidate = nil
S.displayUntil = os.clock()
+ (event and Config.UIEventHoldSeconds or 0)
return
end

if S.displayCandidate ~= name then
S.displayCandidate = name
S.displayCandidateSince = os.clock()
end

flushStatusDisplay()
end

local function flat(v)
return Vector3.new(v.X, 0, v.Z)
end

local function finite(n)
return type(n) == "number"
and n == n
and math.abs(n) < math.huge
end

local function finiteVector(v)
return typeof(v) == "Vector3"
and finite(v.X)
and finite(v.Y)
and finite(v.Z)
end

local function unit(v, fallback)
v = flat(v)

return v.Magnitude > 0.0001
and v.Unit
or (fallback or Vector3.new(0, 0, -1))
end

local function now()
return M.Clock.GetSmoothedServerTime()
end

local function inputActive()
if not S.focused
or UserInputService:GetFocusedTextBox() then
return true
end

for _, key in ipairs({
Enum.KeyCode.W,
Enum.KeyCode.A,
Enum.KeyCode.S,
Enum.KeyCode.D,
Enum.KeyCode.Up,
Enum.KeyCode.Down,
Enum.KeyCode.Left,
Enum.KeyCode.Right,
}) do
if UserInputService:IsKeyDown(key) then
return true
end
end

return S.stick.Magnitude > 0.12
or next(S.touches) ~= nil
end

connect(UserInputService.InputChanged, function(input)
if input.KeyCode == Enum.KeyCode.Thumbstick1 then
S.stick = Vector2.new(input.Position.X, input.Position.Y)
end
end)

connect(UserInputService.InputBegan, function(input)
if input.UserInputType == Enum.UserInputType.Touch then
S.touches[input] = true
end
end)

connect(UserInputService.InputEnded, function(input)
S.touches[input] = nil

if input.KeyCode == Enum.KeyCode.Thumbstick1 then
S.stick = Vector2.zero
end
end)

connect(UserInputService.WindowFocusReleased, function()
S.focused = false
S.stick = Vector2.zero
table.clear(S.touches)
end)

connect(UserInputService.WindowFocused, function()
S.focused = true
S.manualUntil = os.clock() + Config.ManualReleaseGrace
S.nextPlanAt = 0
end)

--==============================================================
-- ACTION ACCOUNTING
--==============================================================
local function recordRequest(kind, frame)
Stats.Requests = Stats.Requests + 1

if kind == "JUMP" then
Stats.JumpRequests = Stats.JumpRequests + 1
elseif kind == "DIVE" then
Stats.DiveRequests = Stats.DiveRequests + 1
end

local key = frame and frame.flightKey

if key and not S.countedFlights[key] then
S.countedFlights[key] = true
Stats.FlightsActedOn = Stats.FlightsActedOn + 1
end
end

--==============================================================
-- MOVEMENT OWNERSHIP
--==============================================================
local function resetPositionTarget()
S.positionActive = false
S.positionTarget = nil
S.positionKey = nil
end

local function noteMoveRelease(reason)
S.lastReleaseReason = reason
S.releaseReasons[reason] =
(S.releaseReasons[reason] or 0) + 1

return reason
end

local function releaseMove(allowWrite)
local character, owned = S.moveCharacter, S.ownedMove
resetPositionTarget()

local function released(reason)
if S.moveCharacter == character and S.ownedMove == owned then
S.ownedMove = nil
S.moveCharacter = nil
end
return reason == "NONE" and reason or noteMoveRelease(reason)
end

if not owned or owned.Magnitude == 0 then return released("NONE") end
if not character or not character.Parent then return released("CHARACTER_GONE") end
if not allowWrite then return released("YIELD_WITHOUT_WRITE") end

if inputActive() and S.focused
and not UserInputService:GetFocusedTextBox() then
return released("MANUAL_INPUT")
end

local current = M.Controllers.GetMoveCommand(character)
if current.Magnitude == 0 then return released("ALREADY_ZERO") end
if current.Unit:Dot(owned.Unit) <= 0.999 then return released("COMMAND_CHANGED") end

-- Do not discard ownership until the write succeeds.
assert(M.Controllers.SetMoveCommand(character, Vector3.zero) ~= false,
"Automatic movement stop was refused")
S.releaseWrites = S.releaseWrites + 1
return released("STOPPED")
end

local function invalidateFrame(allowWrite)
S.lastFrame = nil
S.keeperWait = nil
S.keeperContact = nil
S.allowPositioning = false
S.coverageFrame = nil
S.coverageNextAt = 0
S.nextPlanAt = 0
releaseMove(allowWrite)
end

local function releaseMotionLock(lease)
if not lease or not lease.lockHeld then
return true
end
local ok, err = pcall(
M.Movement.UnlockMovement,
lease.lockName
)
ok = ok and err ~= false
if ok then
lease.lockHeld = false
S.ownLockReleases = S.ownLockReleases + 1
S.retiredLocks[lease.lockName] = nil
else
S.retiredLocks[lease.lockName] = lease
report("OWN LOCK RELEASE", err)
end
return ok
end

local function releaseMotionController(lease)
if not lease or not lease.cancelPending then return true end
local ok, result = pcall(lease.controller.Cancel)
if ok and result ~= false then
lease.cancelPending = false
S.retiredMotions[lease] = nil
return true
end
S.retiredMotions[lease] = true
report("OWN MOTION CANCEL", result)
return false
end

local function finishMotion(cancel, expected)
local lease = S.motionLease
if not lease or (expected and lease ~= expected) then
return false
end
S.motionLease = nil
local active = lease.controller
if S.controller == active then
S.controller = nil
end
lease.closed = true
local canceled = true
if active and cancel then
lease.cancelPending = true
canceled = releaseMotionController(lease)
end
local unlocked = releaseMotionLock(lease)
return canceled and unlocked
end

local function serviceOwnedMotion()
for lease in pairs(S.retiredMotions) do
if os.clock() >= (lease.cancelRetryAt or 0) then
lease.cancelRetryAt = os.clock() + 1
releaseMotionController(lease)
end
end
for lockName in pairs(S.retiredLocks) do
if os.clock() >= (S.retiredLocks[lockName].retryAt or 0) then
S.retiredLocks[lockName].retryAt = os.clock() + 1
releaseMotionLock(S.retiredLocks[lockName])
end
end
end

--==============================================================
-- GOALKEEPER PREDICTIONS
--==============================================================
-- Predictions are modeled as { flight = ..., landing = ..., dive = ... }
-- where each item is { eta, position, velocity, direction, ... }.
local function modelFlight(predicted, ballCf, ballV)
local flight = predicted.flight
if not flight then return false end
if flight.phase == "DIVE" then
return false
end
local ballY = ballCf.Position.Y
local gk = S.currentContext
if not gk or not gk.character or not gk.rootCf then return false end
local rootY = gk.rootCf.Position.Y
if math.abs(ballY - rootY) > 5 then
return false
end
return true
end

local function updateFlightPlan()
if not S.lastFrame then return end
local now = os.clock()
local frame = S.lastFrame
if now < S.nextPlanAt then
S.immediatePlansChecked = S.immediatePlansChecked + 1
return
end
S.nextPlanAt = now + (1 / Config.PlannerHz)
S.plannerMilliseconds = 0
end

local function position(f, dt)
if Rush.candidate ~= nil then releaseMove(true); return end
if not f or not S.moveCharacter then return end
if not f.position then return end

if f.landing and f.landing.position then
S.positionTarget = f.landing.position
else
S.positionTarget = nil
end
end

local function requestJump(f, plan)
if not authorizedFrame(f) or manualJumpHeld() then
return false
end

if Config.LegitPrediction and f.eta and f.eta > 0.6 then
    S.nextActionAt = os.clock() + (math.random(100, 250) / 1000)
end
return true
end

local function requestDive(f, plan)
if not authorizedFrame(f) then
return false
end

if Config.LegitPrediction and f.eta and f.eta > 0.6 then
    S.nextActionAt = os.clock() + (math.random(100, 250) / 1000)
end
S.nextLeaseId = S.nextLeaseId + 1
return true
end

--==============================================================
-- UI BUILDING (Simplified)
--==============================================================

local function section(name)
-- UI section placeholder
end

local function toggle(label, getter, setter)
-- Toggle placeholder
end

section("AUTOMATION")
toggle("Legit prediction", function() return Config.LegitPrediction end, function(value) Config.LegitPrediction = value end)
toggle("Auto Attack (Beta)", function() return Config.AutoAttack end, function(value) Config.AutoAttack = value end)

section("SHOOTING")
toggle("Randomizer (Flick Shot)", function() return STR.Randomizer end, function(value) STR.SetRandomizer(value) end)

--==============================================================
-- END DMC MAIN
--==============================================================
end)
