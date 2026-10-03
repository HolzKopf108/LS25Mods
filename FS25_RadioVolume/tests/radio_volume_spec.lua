-- Run using Lua 5.1+; paths are resolved relative to this test file.
-- Contract tests for the FS25 input and SettingsModel integration.
local warnings, notifications = {}, {}
local savedVolume, mixerVolume, saves = 0.5, 0.5, 0
local radioKey = "radioVolume"
g_currentModName = "FS25_RadioVolume"
g_modIsLoaded = {[g_currentModName] = true}
g_i18n = {getText = function() return "Radio-Lautstärke: %d%%" end}
GS_PRIO_LOW = 1
Logging = {warning = function(message) table.insert(warnings, message) end}
InputAction = {RV25_VOLUME_DOWN = "DOWN", RV25_VOLUME_UP = "UP"}
SettingsModel = {SETTING = {RADIO_VOLUME = radioKey}}
g_gui = {visible = false, getIsGuiVisible = function(self) return self.visible end}
g_gameSettings = {save = function() saves = saves + 1 end}
g_currentMission = {showBlinkingWarning = function(self, message, duration)
    assert(duration == 2000)
    table.insert(notifications, message)
end}

local model = {
    settings = {
        [radioKey] = {initial = 6, changed = 6, saved = 6},
        other = {initial = 1, changed = 2, saved = 1}
    },
    settingReaders = {}, settingWriters = {}
}
model.settingReaders[radioKey] = function() return math.floor(savedVolume * 10 + 0.5) + 1 end
model.settingWriters[radioKey] = function(index, key)
    assert(key == radioKey)
    savedVolume = (index - 1) / 10
    mixerVolume = savedVolume
end
function model:getValue(key, live)
    if live then return self.settingReaders[key](key) end
    return self.settings[key].changed
end
function model:setValue(key, index) self.settings[key].changed = index end
function model:getAudioVolumeTexts() return {"Off", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"} end
g_settingsModel = model

Utils = {appendedFunction = function(original, appended)
    return function(...) original(...); appended(...) end
end}
local baseCalls = 0
PlayerInputComponent = {registerGlobalPlayerActionEvents = function() baseCalls = baseCalls + 1 end}
g_inputBinding = {events = {}, fail = false}
function g_inputBinding:registerActionEvent(action, target, callback, up, down, always, active, direction)
    assert(not up and down and not always and active, "one step per press")
    if self.fail then return false, nil end
    local id = #self.events + 1
    self.events[id] = {action = action, target = target, callback = callback, direction = direction}
    return true, id
end
function g_inputBinding:setActionEventTextVisibility(id, value) assert(self.events[id] and value) end
function g_inputBinding:setActionEventTextPriority(id, value) assert(self.events[id] and value == GS_PRIO_LOW) end

local testDirectory = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "./"
dofile(testDirectory .. "../scripts/RadioVolume.lua")
local owner = {player = {isOwner = true}, locked = true}
local remote = {player = {isOwner = false}}
PlayerInputComponent.registerGlobalPlayerActionEvents(owner)
assert(baseCalls == 1 and #g_inputBinding.events == 2)
local down, up = g_inputBinding.events[1], g_inputBinding.events[2]
local function press(event, value)
    event.callback(event.target, event.action, value or 1, event.direction)
end
press(down)
assert(savedVolume == 0.4 and mixerVolume == 0.4 and saves == 1)
press(up)
assert(savedVolume == 0.5 and saves == 2)
assert(model.settings.other.changed == 2 and model.settings.other.saved == 1, "pending unrelated settings survive")
assert(model.settings[radioKey].initial == 6 and model.settings[radioKey].saved == 6)

-- Full range, clamping and no redundant disk writes at either limit.
for i = 1, 20 do press(down) end
assert(savedVolume == 0 and saves == 7)
for i = 1, 20 do press(up) end
assert(savedVolume == 1 and saves == 17)
assert(notifications[#notifications] == "Radio-Lautstärke: 100%")

-- Simulate changing volume in the game's audio menu; read that live value.
savedVolume = 0.2
press(up)
assert(savedVolume == 0.3 and model.settings[radioKey].changed == 4)

-- UI, release events, remote players, server and deselected mod do nothing.
local before = saves
g_gui.visible = true; press(down); g_gui.visible = false
press(down, 0)
RadioVolume.onVolumeInput(remote, "DOWN", 1, -1)
g_dedicatedServer = {}; press(down)
PlayerInputComponent.registerGlobalPlayerActionEvents(owner)
g_dedicatedServer = nil
g_modIsLoaded[g_currentModName] = false; press(down)
PlayerInputComponent.registerGlobalPlayerActionEvents(owner)
g_modIsLoaded[g_currentModName] = true
PlayerInputComponent.registerGlobalPlayerActionEvents(remote)
assert(saves == before and #g_inputBinding.events == 2)

-- Game owns event cleanup; re-registration attaches to a fresh component.
g_inputBinding.events = {}
local newOwner = {player = {isOwner = true}}
PlayerInputComponent.registerGlobalPlayerActionEvents(newOwner)
assert(#g_inputBinding.events == 2 and g_inputBinding.events[1].target == newOwner)
press(g_inputBinding.events[1])
assert(savedVolume == 0.2)

-- Registration conflicts must not access a missing event ID.
g_inputBinding.fail = true
PlayerInputComponent.registerGlobalPlayerActionEvents(newOwner)
assert(#warnings == 2)
g_inputBinding.fail = false
model.settingWriters[radioKey] = nil
press(g_inputBinding.events[1])
assert(#warnings == 3 and savedVolume == 0.2)
print("PASS: FS25 radio volume input, limits, live settings, persistence, UI and lifecycle contracts")
