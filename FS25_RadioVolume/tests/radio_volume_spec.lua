-- Lua 5.1+; run from any directory. This cannot replace a test in FS25.
-- No SettingsModel is provided: radio controls must work without a menu model.
-- The mixer simulation follows the documented FS25 factor -> engine -> listener
-- path. A validation runner may supply the actual documented SoundMixer methods.
local warnings, messages, infos, listeners = {}, {}, {}, {}
local saves, baseCalls, engineVolume, streamVolume = 0, 0, 0.5, 0.5
local radioGroup, vehicleGroup = 7, 3
local settings = {radioVolume = 0.5, vehicleVolume = 0.7, radioIsActive = true, radioVehicleOnly = false}

g_currentModName = "FS25_RadioVolume"
g_modIsLoaded = {[g_currentModName] = true}
g_i18n = {getText = function(_, key)
    assert(key == "rv25_volume")
    return "Radio volume: %d%%"
end}
GS_PRIO_LOW = 1
Logging = {
    warning = function(format, ...) table.insert(warnings, string.format(format, ...)) end,
    info = function(format, ...) table.insert(infos, string.format(format, ...)) end
}
InputAction = {RV25_VOLUME_DOWN = "RV25_VOLUME_DOWN", RV25_VOLUME_UP = "RV25_VOLUME_UP"}
AudioGroup = {getAudioGroupIndexByName = function(name)
    assert(name == "RADIO")
    return radioGroup
end}
g_gui = {visible = false, getIsGuiVisible = function(self) return self.visible end}
g_gameSettings = {
    getValue = function(_, name) return settings[name] end,
    setValue = function(_, name, value)
        assert(name == "radioVolume", "only radio volume may change")
        settings[name] = value
    end,
    save = function() saves = saves + 1 end
}
g_currentMission = {showBlinkingWarning = function(_, message, duration)
    assert(duration == 2000)
    table.insert(messages, message)
end}

-- FS25's update uses game-state volume * user factor; streams receive listeners.
GameState = {LOADING = 0}
g_gameStateManager = {getGameState = function() return 1 end}
function setAudioGroupVolume(group, value)
    if group == radioGroup then engineVolume = value end
end
local function setFactor(self, group, factor)
    if self.volumeFactors[group] ~= nil then
        self.volumeFactors[group] = factor
        self.isDirty = true
    end
end
local function mixerUpdate(self, dt)
    if not self.isDirty then return end
    for group, data in pairs(self.gameStates[g_gameStateManager:getGameState()]) do
        local value = data.volume * self.volumeFactors[group]
        if self.volumes[group] ~= value then
            setAudioGroupVolume(group, value)
            self.volumes[group] = value
            for _, listener in ipairs(self.volumeChangedListeners[group]) do
                listener.func(listener.target, group, value)
            end
        end
    end
    self.isDirty = false
end
local listenerTarget = {}
g_soundMixer = {
    gameStates = {[1] = {
        [radioGroup] = {volume = 1, fadeInDuration = 0, fadeOutDuration = 0},
        [vehicleGroup] = {volume = 1, fadeInDuration = 0, fadeOutDuration = 0}
    }},
    volumeFactors = {[radioGroup] = 0.5, [vehicleGroup] = 0.7},
    volumes = {[radioGroup] = 0.5, [vehicleGroup] = 0.7},
    volumeChangedListeners = {
        [radioGroup] = {{target = listenerTarget, func = function(target, group, value)
            assert(target == listenerTarget and group == radioGroup)
            streamVolume = value
            table.insert(listeners, value)
        end}},
        [vehicleGroup] = {}
    },
    setAudioGroupVolumeFactor = SoundMixer and SoundMixer.setAudioGroupVolumeFactor or setFactor,
    update = SoundMixer and SoundMixer.update or mixerUpdate
}

Utils = {appendedFunction = function(original, appended)
    return function(...) original(...); appended(...) end
end}
PlayerInputComponent = {
    INPUT_CONTEXT_NAME = "PLAYER",
    registerGlobalPlayerActionEvents = function() baseCalls = baseCalls + 1 end
}
Vehicle = {INPUT_CONTEXT_NAME = "VEHICLE"}
g_inputBinding = {events = {}, nextId = 0, context = "PLAYER", fail = false}
function g_inputBinding:registerActionEvent(action, target, callback, up, down, always, active)
    assert(not up and down and not always and active, "one step per press, no repeat")
    if self.fail then return false, nil end
    -- Re-registering an action for the same owner/context replaces that event.
    for id, event in pairs(self.events) do
        if event.action == action and event.target == target and event.context == self.context then
            self.events[id] = nil
        end
    end
    self.nextId = self.nextId + 1
    local id = self.nextId
    self.events[id] = {action = action, target = target, callback = callback, context = self.context}
    return true, id
end
function g_inputBinding:setActionEventTextVisibility(id, value) assert(self.events[id] and value) end
function g_inputBinding:setActionEventTextPriority(id, value) assert(self.events[id] and value == GS_PRIO_LOW) end
function g_inputBinding:removeActionEventsByTarget(target)
    for id, event in pairs(self.events) do
        if event.target == target then self.events[id] = nil end
    end
end
function addModEventListener(listener) assert(#listeners == 0); listeners.mod = listener end

local testDirectory = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "./"
dofile(testDirectory .. "../scripts/RadioVolume.lua")
assert(listeners.mod == RadioVolume)
assert(g_settingsModel == nil and SettingsModel == nil)
RadioVolume:loadMap()
assert(infos[1]:find("v2.1.0.0 loaded", 1, true))

local owner = {player = {isOwner = true}, locked = true}
local remote = {player = {isOwner = false}}
local function eventFor(action, context)
    local result
    for _, event in pairs(g_inputBinding.events) do
        if event.action == action and event.context == context then
            assert(result == nil, "no duplicate action in a context")
            result = event
        end
    end
    assert(result, "action must exist in " .. context)
    return result
end
local function press(event, value)
    event.callback(event.target, event.action, value or 1)
end
local function flushMixer() g_soundMixer:update(1000) end
local function assertVolume(expected)
    assert(math.abs(settings.radioVolume - expected) < 0.000001)
    assert(math.abs(engineVolume - expected) < 0.000001, "engine audio must change")
    assert(math.abs(streamVolume - expected) < 0.000001, "stream listener must receive the volume")
end

-- On foot, then driving: Enterable in FS25 calls this global method using VEHICLE.
PlayerInputComponent.registerGlobalPlayerActionEvents(owner)
assert(baseCalls == 1)
local down = eventFor(InputAction.RV25_VOLUME_DOWN, "PLAYER")
press(down)
assert(engineVolume == 0.5 and streamVolume == 0.5, "FS25 applies mixer changes on update")
assert(g_soundMixer.isDirty and g_soundMixer.volumeFactors[radioGroup] == 0.4)
flushMixer()
assertVolume(0.4)
assert(saves == 1)

g_inputBinding.context = Vehicle.INPUT_CONTEXT_NAME
PlayerInputComponent.registerGlobalPlayerActionEvents(owner, Vehicle.INPUT_CONTEXT_NAME)
local up = eventFor(InputAction.RV25_VOLUME_UP, "VEHICLE")
down = eventFor(InputAction.RV25_VOLUME_DOWN, "VEHICLE")
press(up); flushMixer(); assertVolume(0.5)
assert(saves == 2 and owner.locked, "player movement may be locked while driving")
assert(infos[#infos]:find("50%%"))
assert(g_soundMixer.volumeFactors[vehicleGroup] == 0.7 and settings.vehicleVolume == 0.7)
assert(settings.radioIsActive and not settings.radioVehicleOnly)

-- Range, float rounding, and redundant writes at the limits.
for i = 1, 20 do press(down); flushMixer() end
assertVolume(0)
assert(saves == 7)
for i = 1, 20 do press(up); flushMixer() end
assertVolume(1)
assert(saves == 17 and messages[#messages] == "Radio volume: 100%")

-- A live menu change must override any previously remembered hotkey volume.
settings.radioVolume = 0.2
press(up); flushMixer(); assertVolume(0.3)
settings.radioVolume = 0.30000000000000004
press(down); flushMixer(); assertVolume(0.2)
settings.radioIsActive = false
press(up); flushMixer(); assertVolume(0.3)
assert(not settings.radioIsActive, "changing the volume must not turn on the radio")

-- A menu/focus state may mute radio even when the requested setting is nonzero.
g_soundMixer.gameStates[1][radioGroup].volume = 0
press(up); flushMixer()
assert(settings.radioVolume == 0.4 and engineVolume == 0 and streamVolume == 0)
g_soundMixer.gameStates[1][radioGroup].volume = 1
g_soundMixer.isDirty = true
flushMixer(); assertVolume(0.4)

-- UI, pause/freeze, release, remote players, dedicated server, inactive mod.
local beforeSaves, beforeMessages = saves, #messages
g_gui.visible = true; press(down); g_gui.visible = false
g_currentMission.isPlayerFrozen = true; press(down); g_currentMission.isPlayerFrozen = false
press(down, 0)
RadioVolume.onVolumeDown(remote, "RV25_VOLUME_DOWN", 1)
g_dedicatedServer = {}; press(down)
PlayerInputComponent.registerGlobalPlayerActionEvents(owner)
g_dedicatedServer = nil
g_modIsLoaded[g_currentModName] = false; press(down)
PlayerInputComponent.registerGlobalPlayerActionEvents(owner)
g_modIsLoaded[g_currentModName] = true
PlayerInputComponent.registerGlobalPlayerActionEvents(remote)
assert(saves == beforeSaves and #messages == beforeMessages)
local mission = g_currentMission
g_currentMission = nil; press(down); g_currentMission = mission
assert(saves == beforeSaves)

-- Rebinding / re-entering / another map must not double one press.
PlayerInputComponent.registerGlobalPlayerActionEvents(owner, "VEHICLE")
down = eventFor(InputAction.RV25_VOLUME_DOWN, "VEHICLE")
press(down); flushMixer(); assertVolume(0.3)
assert(saves == beforeSaves + 1)
g_inputBinding:removeActionEventsByTarget(owner)
assert(next(g_inputBinding.events) == nil)
local hook = PlayerInputComponent.registerGlobalPlayerActionEvents
RadioVolume:deleteMap(); RadioVolume:loadMap()
assert(PlayerInputComponent.registerGlobalPlayerActionEvents == hook)
local newOwner = {player = {isOwner = true}}
PlayerInputComponent.registerGlobalPlayerActionEvents(newOwner, "VEHICLE")
down = eventFor(InputAction.RV25_VOLUME_DOWN, "VEHICLE")
assert(down.target == newOwner)
press(down); flushMixer(); assertVolume(0.2)

-- Failures are visible in the log and must not show a false success popup.
g_inputBinding.fail = true
PlayerInputComponent.registerGlobalPlayerActionEvents(newOwner, "VEHICLE")
assert(#warnings == 2)
g_inputBinding.fail = false
beforeSaves, beforeMessages = saves, #messages
local mixer = g_soundMixer
g_soundMixer = nil; press(down); g_soundMixer = mixer
local factor = mixer.volumeFactors[radioGroup]
mixer.volumeFactors[radioGroup] = nil; press(down); mixer.volumeFactors[radioGroup] = factor
local gameSettings = g_gameSettings
g_gameSettings = nil; press(down); g_gameSettings = gameSettings
settings.radioVolume = nil; press(down); settings.radioVolume = 0.2
assert(#warnings == 6 and saves == beforeSaves and #messages == beforeMessages)
print("PASS: radio setting, audible engine/stream path, vehicle/foot inputs, limits, persistence and lifecycle")
