-- FS25: radioVolume is a 0..1 game setting, not a menu option index.
-- The SoundMixer owns live audio group volumes and stream volume listeners.
RadioVolume = {
    VERSION = "2.1.0.0"
}

local modName = g_currentModName
local modI18n = g_i18n

function RadioVolume.isEnabled()
    return g_dedicatedServer == nil
        and g_modIsLoaded ~= nil and g_modIsLoaded[modName] == true
end

function RadioVolume:loadMap()
    self.loggedContexts = {}
    self.radioAudioGroup = nil

    if not self.isEnabled() then
        return
    end

    self.radioAudioGroup = AudioGroup.getAudioGroupIndexByName("RADIO")
    Logging.info("[%s] v%s loaded; RADIO audio group=%s",
        modName, self.VERSION, tostring(self.radioAudioGroup))
end

function RadioVolume:deleteMap()
    -- FS25 removes the action events with their owning input component.
    self.radioAudioGroup = nil
    self.loggedContexts = nil
end

function RadioVolume.registerActionEvents(inputComponent, inputContext)
    if not RadioVolume.isEnabled() or not inputComponent.player.isOwner then
        return
    end

    -- FS25 calls this inside the player OR vehicle registration context.
    -- Enterable.onRegisterActionEvents uses the same global player hook,
    -- including when an attached implement is selected.
    local actions = {
        {InputAction.RV25_VOLUME_DOWN, RadioVolume.onVolumeDown},
        {InputAction.RV25_VOLUME_UP, RadioVolume.onVolumeUp}
    }
    local registered = 0

    for _, action in ipairs(actions) do
        local success, eventId = g_inputBinding:registerActionEvent(
            action[1], inputComponent, action[2], false, true, false, true)

        if success and eventId ~= nil then
            g_inputBinding:setActionEventTextVisibility(eventId, true)
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_LOW)
            registered = registered + 1
        else
            Logging.warning("[%s] Could not register %s; check the control binding",
                modName, tostring(action[1]))
        end
    end

    local context = inputContext or PlayerInputComponent.INPUT_CONTEXT_NAME
    RadioVolume.loggedContexts = RadioVolume.loggedContexts or {}
    if not RadioVolume.loggedContexts[context] then
        Logging.info("[%s] Hotkeys registered in %s: %d/2", modName, tostring(context), registered)
        RadioVolume.loggedContexts[context] = registered == 2
    end
end

function RadioVolume.onVolumeDown(inputComponent, actionName, inputValue)
    RadioVolume.onVolumeInput(inputComponent, inputValue, -1)
end

function RadioVolume.onVolumeUp(inputComponent, actionName, inputValue)
    RadioVolume.onVolumeInput(inputComponent, inputValue, 1)
end

function RadioVolume.onVolumeInput(inputComponent, inputValue, direction)
    local mission = g_currentMission
    if not RadioVolume.isEnabled() or inputValue <= 0
        or not inputComponent.player.isOwner or mission == nil
        or mission.isPlayerFrozen or (g_gui ~= nil and g_gui:getIsGuiVisible()) then
        return
    end

    if g_gameSettings == nil then
        Logging.warning("[%s] Game settings are unavailable", modName)
        return
    end

    -- Read on every press so a change in the game's audio menu is respected.
    local currentVolume = g_gameSettings:getValue("radioVolume")
    if type(currentVolume) ~= "number" then
        Logging.warning("[%s] radioVolume is not a number: %s", modName, tostring(currentVolume))
        return
    end

    local group = RadioVolume.radioAudioGroup or AudioGroup.getAudioGroupIndexByName("RADIO")
    local mixer = g_soundMixer
    if group == nil or mixer == nil or mixer.volumeFactors[group] == nil then
        Logging.warning("[%s] The RADIO SoundMixer group is unavailable", modName)
        return
    end
    RadioVolume.radioAudioGroup = group

    -- Integer steps avoid accumulated floating point errors at 0% and 100%.
    local currentStep = math.floor(currentVolume * 10 + 0.5)
    local nextStep = math.max(0, math.min(10, currentStep + direction))
    local nextVolume = nextStep / 10

    -- A bare setAudioGroupVolume would bypass the mixer's stream listeners
    -- and could be overwritten on the next state change. Let FS25 apply the
    -- factor in its next mixer update, including the normal fades/muting.
    mixer:setAudioGroupVolumeFactor(group, nextVolume)
    if currentVolume ~= nextVolume then
        g_gameSettings:setValue("radioVolume", nextVolume)
        g_gameSettings:save()
    end

    local percent = nextStep * 10
    mission:showBlinkingWarning(string.format(modI18n:getText("rv25_volume"), percent), 2000)
    Logging.info("[%s] Radio volume: %d%% -> %d%% (RADIO group=%s)",
        modName, math.floor(currentVolume * 100 + 0.5), percent, tostring(group))
end

-- Install once when the source is loaded, not again on each map load.
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents, RadioVolume.registerActionEvents)

addModEventListener(RadioVolume)
