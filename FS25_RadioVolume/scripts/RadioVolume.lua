-- FS25 1.20: use the player's global input registration, also used in vehicles.
-- Events belong to the input component so FS25 removes/rebuilds them together
-- with its own controls when leaving a game or rebinding keys.
RadioVolume = {}
local modI18n = g_i18n
local modName = g_currentModName

function RadioVolume.registerActionEvents(inputComponent)
    if not g_modIsLoaded[modName] or not inputComponent.player.isOwner or g_dedicatedServer ~= nil then
        return
    end

    local actions = {
        {InputAction.RV25_VOLUME_DOWN, -1},
        {InputAction.RV25_VOLUME_UP, 1}
    }

    for _, action in ipairs(actions) do
        local success, eventId = g_inputBinding:registerActionEvent(
            action[1], inputComponent, RadioVolume.onVolumeInput,
            false, true, false, true, action[2])

        if success then
            g_inputBinding:setActionEventTextVisibility(eventId, true)
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_LOW)
        else
            Logging.warning("RadioVolume: could not register %s; check for conflicting controls", tostring(action[1]))
        end
    end
end

function RadioVolume.onVolumeInput(inputComponent, actionName, inputValue, direction)
    local mission = g_currentMission
    if not g_modIsLoaded[modName] or inputValue <= 0 or not inputComponent.player.isOwner
        or g_dedicatedServer ~= nil or mission == nil
        or g_gui:getIsGuiVisible() then
        return
    end

    -- Read the live setting through FS25's reader, rather than keeping a second
    -- volume which would become stale after changes in the audio menu.
    local model = g_settingsModel
    local key = SettingsModel.SETTING.RADIO_VOLUME
    if model == nil or model.settings[key] == nil
        or model.settingReaders[key] == nil or model.settingWriters[key] == nil then
        Logging.warning("RadioVolume: FS25 radio setting is unavailable")
        return
    end

    -- The menu represents Off / 10% / ... / 100% as indices 1 / 2 / ... / 11.
    local currentIndex = model:getValue(key, true)
    local maxIndex = #model:getAudioVolumeTexts()
    local nextIndex = math.max(1, math.min(maxIndex, currentIndex + direction))

    if nextIndex ~= currentIndex then
        model:setValue(key, nextIndex)

        -- Apply exactly the writer used by the audio settings menu. Unlike
        -- applyChanges(), this commits only radio volume, leaving other pending
        -- menu changes alone. The writer updates the setting and the mixer.
        model.settingWriters[key](nextIndex, key)
        local state = model.settings[key]
        state.initial = nextIndex
        state.saved = nextIndex
        g_gameSettings:save()
    end

    mission:showBlinkingWarning(string.format(modI18n:getText("rv25_volume"), (nextIndex - 1) * 10), 2000)
end

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents, RadioVolume.registerActionEvents)
