-- Run with Lua 5.1 or 5.4. Game objects are simulated; this is not a game test.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
local count = 0
local function check(condition, message)
    assert(condition, message)
    count = count + 1
end
local function load(relative) dofile(mod .. "/" .. relative) end
load("scripts/TMSProfiles.lua")
load("scripts/media/TMSMediaSource.lua")
load("scripts/media/TMSNativeVideo.lua")
load("scripts/media/TMSVideoProbe.lua")
load("scripts/media/TMSRuntimeApiReport.lua")
load("scripts/media/TMSCabinClipData.lua")
load("scripts/media/TMSCabinVideo.lua")

for _, url in ipairs({"https://youtube.com/watch?v=dQw4w9WgXcQ", "youtu.be/dQw4w9WgXcQ",
    "https://www.youtube.com/shorts/dQw4w9WgXcQ?feature=share", "https://m.youtube.com/watch?a=1&v=dQw4w9WgXcQ"}) do
    local source, reason = TMSMediaSource.parse(url)
    check(source ~= nil and source.id == "dQw4w9WgXcQ" and not source.playable
        and reason == "providerUnavailable", "Valid links must not imply playback support")
end
for _, url in ipairs({"https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ", "javascript:alert(1)",
    "https://youtube.com@evil.test/watch?v=dQw4w9WgXcQ", "file:///video.mp4",
    "https://youtube.com/watch?v=short", "https://youtube.com/watch?v=dQw4w9WgXcQ&v=abcdefghijk",
    "https://youtu.be/dQw4w9WgXcQ/extra", string.rep("a", 2049), ""}) do
    check(TMSMediaSource.parse(url) == nil, "Reject malformed or unrelated media links")
end
local twitch = TMSMediaSource.parse("https://twitch.tv/example_channel")
check(twitch.provider == "twitch" and not twitch.playable, "Twitch is recognized but not implemented")
check(TMSProfiles.find("C:\\Games\\FS25\\data\\vehicles\\valtra\\sSeries\\sSeries.xml") ~= nil, "Windows basegame path")
check(TMSProfiles.find("$data/vehicles/valtra/sSeries/sSeries.xml") ~= nil, "$data basegame path")
check(TMSProfiles.find("data/vehicles/valtra/tSeries/tSeries.xml") == nil, "No other Valtra models")
check(TMSProfiles.find("mydata/vehicles/valtra/sSeries/sSeries.xml") == nil, "Require full path segment")

local created, stopped, deleted, started = 0, 0, 0, 0
local ready, playing, throwUpdate = false, false, false
local lastLoop, lastVolume
local decoderTime = 0
local api = {
    createVideoOverlay = function(filename, looping, volume)
        check(type(looping) == "boolean" and type(volume) == "number" and volume >= 0 and volume <= 1,
            "Explicit loop/volume settings")
        lastLoop, lastVolume = looping, volume
        created = created + 1; return 100 + created
    end,
    isVideoOverlayReadyToPlay = function() return ready end,
    isVideoOverlayPlaying = function() return playing end,
    getVideoOverlayCurrentTime = function() return decoderTime end,
    playVideoOverlay = function() started = started + 1; playing = true end,
    updateVideoOverlay = function() if throwUpdate then error("native failure") end end,
    stopVideoOverlay = function() stopped = stopped + 1; playing = false end,
    delete = function() deleted = deleted + 1 end,
    renderOverlay = function() end
}
local video = TMSNativeVideo.new(api)
check(video:start("test.ogv", 0.25), "Native creation")
check(lastLoop == false and lastVolume == 0.25, "Backend respects caller's loop/volume settings")
video:update(16)
check(started == 0 and video.state == "loading", "Wait for decoder readiness")
ready = true
video:update(16); video:update(16)
check(started == 1 and video.state == "playing", "Start only once")
video:draw(0, 0, .3, .3)
check(created == 1, "Drawing does not create a second decoder")
video:stop(); video:stop()
check(stopped == 1 and deleted == 1, "Idempotent stop and release")
ready = false
video:start("test.ogv", .25); video:update(15001)
check(video.state == "timeout" and video.id == nil, "Loading timeout frees resources")
ready, throwUpdate = true, true
video:start("test.ogv", .25); video:update(16)
check(video.state == "error" and video.id == nil, "Native errors free resources")
throwUpdate = false
video:start("test.ogv", .25); video:update(16); playing = false; video:update(16)
check(video.state == "ended" and video.id == nil, "End of clip frees resources")
check(not TMSNativeVideo.new({}):start("test.ogv"), "Missing engine functions handled")

-- Minimal FS25 interfaces, separately checked against primary documentation.
function Class(class, parent)
    class.__index = class
    setmetatable(class, {__index = parent})
    return {__index = class}
end
VehicleConfigurationItem = {}
function VehicleConfigurationItem.new(name, mt)
    return setmetatable({configName = name, name = "", index = -1, configKey = "",
        price = 0, dailyUpkeep = 0, isDefault = false, isSelectable = true}, mt)
end
function VehicleConfigurationItem:setIndex(i) self.index = i; self.saveId = tostring(i) end
function VehicleConfigurationItem:saveToXMLFile(xml, key, active)
    xml:setValue(key .. "#name", self.configName)
    xml:setValue(key .. "#id", self.saveId)
    xml:setValue(key .. "#isActive", active)
end
g_currentModName = "FS25_TractorMediaScreen"
g_currentModDirectory = mod .. "/"
g_modIsLoaded = {[g_currentModName] = true}
g_i18n = {getText = function(_, key) return key end}
g_dedicatedServer = nil
g_gui = {getIsGuiVisible = function() return false end}
g_currentMission = {isPlayerFrozen = false}
Logging = {info = function() end, warning = function() end}
InfoDialog = {count = 0, show = function(text) InfoDialog.last = text; InfoDialog.count = InfoDialog.count + 1 end}
TMSLinkDialog = {register = function() end, reset = function() end,
    show = function(callback, target, default, title, prompt, confirm, args)
        TMSLinkDialog.pending = function(text, ok, action) callback(target, text, ok, args, action) end
        return true
    end}
Enterable = {}
SpecializationUtil = {hasSpecialization = function(spec, specs)
    for _, candidate in ipairs(specs) do if candidate == spec then return true end end
    return false
end, registerEventListener = function() end}
TypeManager = {finalizeTypes = function() end}
PlayerInputComponent = {registerGlobalPlayerActionEvents = function() end}
Utils = {
    prependedFunction = function(original, fn) return function(...) fn(...); return original(...) end end,
    appendedFunction = function(original, fn) return function(...) original(...); return fn(...) end end
}
function addModEventListener() end
local commands = {}
function addConsoleCommand(name) commands[name] = true end
function removeConsoleCommand(name) commands[name] = nil end
local overlays = 0
function createImageOverlay() overlays = overlays + 1; return 10 + overlays end
function fileExists() return true end
for key, fn in pairs(api) do _G[key] = fn end
InputAction = {TMS25_MENU = 1, TMS25_PIP = 2, TMS25_PATTERN = 3, TMS25_VIDEO_TEST = 4}
local bindings = 0
g_inputBinding = {
    registerActionEvent = function(_, action, owner, callback, up, down, always, active)
        check(not up and down and not always and active, "Single key press semantics")
        bindings = bindings + 1; return true, bindings
    end,
    setActionEventTextVisibility = function(_, id, visible) check(not visible, "Hidden F1 entries") end
}
local configs = {}
g_vehicleConfigurationManager = {
    getConfigurationDescByName = function(_, name) return configs[name] end,
    addConfigurationType = function(_, name, title, callback, class) configs[name] = class end
}
load("scripts/vehicle/TMSConfiguration.lua")
load("scripts/vehicle/TMSVehicle.lua")
load("scripts/TractorMediaScreen.lua")

local manager = {typeName = "vehicle", types = {tractor = {specializations = {Enterable}},
    trailer = {specializations = {}}}}
local added = 0
function manager:addSpecialization(name, fullName)
    check(fullName == "FS25_TractorMediaScreen.tractorMediaScreen", "Namespaced specialization")
    added = added + 1; table.insert(self.types[name].specializations, TMSVehicle)
end
TypeManager.finalizeTypes(manager); TypeManager.finalizeTypes(manager)
check(added == 1 and configs.tmsMonitor == TMSMonitorConfiguration, "Registration once per type")
local items = {}
TMSMonitorConfiguration.postLoad(nil, nil, nil, nil, false, items,
    {xmlFilename = "data/vehicles/valtra/sSeries/sSeries.xml"}, "tmsMonitor")
check(#items == 2 and items[1].isDefault and items[2].price == 250, "Shop choices and price")
check(items[1].saveId == "NONE" and items[2].saveId == "MONITOR", "Stable save IDs")
local saved = {}
items[2]:saveToXMLFile({setValue = function(_, key, value) saved[key] = value end}, "config", true)
check(saved["config#id"] == "MONITOR", "Configuration save identity preserved")
local excluded = {}
TMSMonitorConfiguration.postLoad(nil, nil, nil, nil, true, excluded,
    {xmlFilename = "data/vehicles/valtra/sSeries/sSeries.xml"}, "tmsMonitor")
check(#excluded == 0, "No injection into another mod's vehicle")

local specKey = "spec_FS25_TractorMediaScreen.tractorMediaScreen"
local function makeVehicle()
    local vehicle = {configFileName = "data/vehicles/valtra/sSeries/sSeries.xml",
        configurations = {tmsMonitor = 2}, isClient = true, components = {{node = 20}},
        spec_enterable = {cameras = {{isInside = true, cameraNode = 30, cameraPositionNode = 30,
            rotateNode = 30, origTransX = 0, origTransY = 1, origTransZ = 0}}},
        [specKey] = {}, getIsEntered = function() return true end}
    function vehicle:loadSubSharedI3DFile(path, create, physics, callback, target, args)
        self.pending = function(node) callback(target, node, nil, args) end
        return 99
    end
    TMSVehicle.onLoad(vehicle)
    return vehicle
end
local v1, v2 = makeVehicle(), makeVehicle()
local released, linked = 0, {}
function getNumOfChildren() return 1 end
function getChildAt(id) return id + 1 end
function link(parent, child) linked[child] = parent end
function setTranslation() end
function setRotation() end
function setDirection() end
function getParent(node) return node == 30 and 25 or node == 25 and 20 or 0 end
function localDirectionToLocal(from, to, x, y, z) return x, y, z end
g_i3DManager = {releaseSharedI3DFile = function() released = released + 1 end}
v1.pending(1000); v2.pending(2000)
TMSVehicle.onLoadFinished(v1); TMSVehicle.onLoadFinished(v2)
check(linked[1001] == 25 and linked[2001] == 25, "Monitor is fixed to cabin parent, never moving camera")
local materialByNode, edits = {}, {}
function getMaterial(node) return materialByNode[node] or 5 end
function setMaterial(node, material) materialByNode[node] = material end
function setMaterialDiffuseMapFromFile(material, filename, wrap, srgb, shared)
    check(type(wrap) == "boolean" and srgb == true, "Real material API argument types")
    table.insert(edits, {material = material, shared = shared, filename = filename})
    return shared and material or material + 100
end
check(TMSVehicle.setTestPattern(v1, true), "Local test pattern applied")
check(materialByNode[1002] == 105 and materialByNode[2002] == nil, "Other tractor material stays unchanged")
TMSVehicle.setTestPattern(v1, false)
check(edits[1].shared == false and edits[2].shared == true, "Clone once, then edit isolated material")

g_localPlayer = {isOwner = true, getCurrentVehicle = function() return v1 end}
local apiCaptures, originalCapture = 0, TMSRuntimeApiReport.capture
TMSRuntimeApiReport.capture = function(...)
    apiCaptures = apiCaptures + 1
    return originalCapture(...)
end
TractorMediaScreen:loadMap()
TractorMediaScreen:update(16)
check(apiCaptures == 1 and commands.tmsApi, "Client collects runtime function names once at map load")
local input = {player = g_localPlayer}
TractorMediaScreen.registerActionEvents(input, "VEHICLE")
check(bindings == 4, "Four local bindings")
TractorMediaScreen.registerActionEvents({player = {isOwner = false}}, "VEHICLE")
check(bindings == 4, "No remote player bindings")
TractorMediaScreen.onMenu(input, nil, 1)
TMSLinkDialog.pending("https://youtu.be/dQw4w9WgXcQ", true)
check(TractorMediaScreen.source.provider == "youtube" and TractorMediaScreen.video.id == nil,
    "YouTube URL never passed to native decoder")
TractorMediaScreen.onMenu(input, nil, 1)
local stale = TMSLinkDialog.pending
g_localPlayer.getCurrentVehicle = function() return v2 end
TractorMediaScreen:update(16)
stale("https://youtu.be/dQw4w9WgXcQ", true)
check(TractorMediaScreen.source == nil, "Stale dialog cannot change new vehicle session")
check(not TractorMediaScreen.pip, "A new vehicle session starts without PiP")
check(TractorMediaScreen:startVideoTest("ogv") and not TractorMediaScreen.pip,
    "Starting the cabin clip does not enable PiP")
ready, decoderTime = true, 0.5
TractorMediaScreen:update(16)
check(TractorMediaScreen.video.state == "playing" and TractorMediaScreen.cabinVideo.frame == 8
    and not TractorMediaScreen.pip, "Cabin playback advances before PiP was ever enabled")
TractorMediaScreen:stopVideoTest()
TractorMediaScreen.onPip(input, nil, 1)
check(TractorMediaScreen.pip, "PiP toggles locally")
check(TractorMediaScreen:startVideoTest("ogv"), "Local HUD probe can start")
check(lastLoop == true and lastVolume == 1.0, "Driver test loops at native default volume")
check(TractorMediaScreen.pip, "Starting preserves manually enabled PiP")
local decoder = TractorMediaScreen.video.id
ready, decoderTime = true, 1
TractorMediaScreen:update(16)
check(TractorMediaScreen.cabinVideo.frame == 16 and v2[specKey].displayFilename:find("frame_0016.dds", 1, true),
    "Cabin receives frame matching the single native player's time")
TractorMediaScreen.onPip(input, nil, 1)
decoderTime = 2
TractorMediaScreen:update(16)
check(not TractorMediaScreen.pip and TractorMediaScreen.video.id == decoder
    and TractorMediaScreen.cabinVideo.frame == 31, "Hiding PiP keeps one player and advances cabin video")
TractorMediaScreen.onPip(input, nil, 1)
check(TractorMediaScreen.video.id == decoder, "Showing PiP again does not restart or duplicate playback")
TractorMediaScreen:stopVideoTest()
check(v2[specKey].displayFilename:find("black.dds", 1, true) and TractorMediaScreen.video.id == nil,
    "Stopping restores the previous black screen even when pattern flag was already false")
ready = false
TractorMediaScreen.onPip(input, nil, 1)
TractorMediaScreen.onVideoTest(input, nil, 1)
check(TractorMediaScreen.videoProbe.format == "ogv" and not TractorMediaScreen.pip,
    "Video key starts OGV without enabling PiP")
TractorMediaScreen:update(15001)
check(TractorMediaScreen.videoProbe.format == "webm" and not TractorMediaScreen.pip,
    "Fallback to WebM preserves hidden PiP")
TractorMediaScreen:update(15001)
check(TractorMediaScreen.videoProbe.format == "mp4", "Second loading failure automatically tries MP4")
local messagesBefore = InfoDialog.count
TractorMediaScreen:update(15001)
TractorMediaScreen:update(16)
check(TractorMediaScreen.videoProbe.failed and TractorMediaScreen.video.id == nil,
    "All unsupported formats release resources and end retries")
check(InfoDialog.count == messagesBefore + 1 and InfoDialog.last:find("loadingTimeout", 1, true),
    "Asynchronous native failure is shown to driver exactly once with diagnostic reason")
TractorMediaScreen.onVideoTest(input, nil, 1)
check(TractorMediaScreen.videoProbe.active and TractorMediaScreen.videoProbe.format == "ogv",
    "A fresh video key press can retry after failure")
g_gui.getIsGuiVisible = function() return true end
TractorMediaScreen:update(16)
check(not TractorMediaScreen.videoProbe.active and TractorMediaScreen.video.id == nil,
    "Menu opening cancels format fallback and stops audio")
g_gui.getIsGuiVisible = function() return false end
TractorMediaScreen.onMenu(input, nil, 1)
TMSLinkDialog.pending("", true, "videoTest")
check(TractorMediaScreen.videoProbe.active and TractorMediaScreen.videoProbe.format == "ogv"
    and not TractorMediaScreen.pip, "Menu button starts video without enabling PiP")
TractorMediaScreen:startVideoTest("mp4")
g_localPlayer.getCurrentVehicle = function() return nil end
TractorMediaScreen:update(16)
check(TractorMediaScreen.video.id == nil and TractorMediaScreen.vehicle == nil, "Exit releases playback")
local beforeBind = bindings
g_gui.getIsGuiVisible = function() return true end
check(not TractorMediaScreen.canHandle(input, 1), "Menus block driving hotkeys")
g_gui.getIsGuiVisible = function() return false end
TractorMediaScreen:deleteMap()
check(next(commands) == nil, "Map cleanup unregisters console commands")
check(apiCaptures == 1, "Video starts, menus and vehicle changes do not repeat the API inventory")

g_dedicatedServer = {}
local beforeOverlay = overlays
TractorMediaScreen:loadMap()
TractorMediaScreen.registerActionEvents(input, "VEHICLE")
local serverVehicle = makeVehicle()
check(serverVehicle.pending == nil, "Dedicated server does not load visual I3D")
check(overlays == beforeOverlay and bindings == beforeBind and not TractorMediaScreen.active,
    "Dedicated server creates neither player inputs nor video/HUD")
check(apiCaptures == 1 and commands.tmsApi == nil, "Dedicated server skips client API inventory")
TractorMediaScreen:deleteMap()
g_dedicatedServer = nil
TMSVehicle.onDelete(v1); TMSVehicle.onDelete(v1)
check(released == 1 and v1[specKey].monitorNode == nil, "Vehicle cleanup idempotent")
local late = makeVehicle()
TMSVehicle.onDelete(late)
late.pending(3000)
check(linked[3001] == nil, "Late async callback cannot attach deleted vehicle")
print(string.format("TractorMediaScreen: %d checks passed (%s)", count, _VERSION))
