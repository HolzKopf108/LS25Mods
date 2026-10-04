-- Client playback is never serialized. Only the monitor purchase is a normal
-- vehicle configuration, synchronized by FS25 itself.
TractorMediaScreen = {
    VERSION = "0.1.0.0",
    modName = g_currentModName,
    modDirectory = g_currentModDirectory,
    i18n = g_i18n,
    generation = 0
}

function TractorMediaScreen.isEnabled()
    return g_modIsLoaded ~= nil and g_modIsLoaded[TractorMediaScreen.modName] == true
end

function TractorMediaScreen.registerVehicleTypes(manager)
    if manager.typeName ~= "vehicle" or not TractorMediaScreen.isEnabled() then return end
    TMSMonitorConfiguration.register()
    local specName = TractorMediaScreen.modName .. ".tractorMediaScreen"
    for typeName, entry in pairs(manager.types) do
        if SpecializationUtil.hasSpecialization(Enterable, entry.specializations)
            and not SpecializationUtil.hasSpecialization(TMSVehicle, entry.specializations) then
            manager:addSpecialization(typeName, specName)
        end
    end
end

function TractorMediaScreen:loadMap()
    self:releaseSession()
    self.active = self.isEnabled() and g_dedicatedServer == nil
    self.registeredContexts = {}
    if not self.active then return end
    self.video = TMSNativeVideo.new({
        createVideoOverlay = createVideoOverlay,
        isVideoOverlayReadyToPlay = isVideoOverlayReadyToPlay,
        isVideoOverlayPlaying = isVideoOverlayPlaying,
        playVideoOverlay = playVideoOverlay,
        updateVideoOverlay = updateVideoOverlay,
        stopVideoOverlay = stopVideoOverlay,
        renderOverlay = renderOverlay,
        delete = delete
    })
    self.overlay = createImageOverlay(self.modDirectory .. "assets/monitor/testPattern.dds")
    Logging.info("[TractorMediaScreen] v%s loaded; GUI video missing APIs: %s; 3D video=unverified; YouTube=unavailable",
        self.VERSION, table.concat(self.video:missingFunctions(), ","))
    addConsoleCommand("tmsStatus", "Tractor Media Screen: local diagnostic status", "consoleStatus", self)
    addConsoleCommand("tmsMount", "Monitor position: x y z rx ry rz (meters/degrees)", "consoleMount", self)
    addConsoleCommand("tmsNodes", "List candidate cabin mappings", "consoleNodes", self)
    addConsoleCommand("tmsVideo", "Test native HUD video: ogv, mp4, webm or stop", "consoleVideo", self)
end

function TractorMediaScreen:deleteMap()
    self:releaseSession()
    if self.overlay ~= nil and self.overlay ~= 0 then delete(self.overlay) end
    self.overlay, self.video = nil, nil
    if self.active then
        for _, name in ipairs({"tmsStatus", "tmsMount", "tmsNodes", "tmsVideo"}) do
            removeConsoleCommand(name)
        end
    end
    self.active = false
end

function TractorMediaScreen:releaseSession()
    if self.video ~= nil then self.video:stop() end
    if self.vehicle ~= nil then TMSVehicle.setTestPattern(self.vehicle, false) end
    self.vehicle, self.source, self.lastInput = nil, nil, nil
    self.pip = false
    self.generation = self.generation + 1
end

function TractorMediaScreen.getLocalVehicle()
    if g_dedicatedServer ~= nil or g_localPlayer == nil or not g_localPlayer.isOwner then return nil end
    if type(g_localPlayer.getCurrentVehicle) ~= "function" then return nil end
    local vehicle = g_localPlayer:getCurrentVehicle()
    local spec = TMSVehicle.getState(vehicle)
    if spec == nil or not spec.equipped or spec.deleted then return nil end
    -- A passenger must not take over the driver's media session.
    if vehicle.getIsEntered ~= nil and not vehicle:getIsEntered() then return nil end
    return vehicle
end

function TractorMediaScreen:refreshVehicle()
    local vehicle = self.getLocalVehicle()
    if vehicle ~= self.vehicle then
        self:releaseSession()
        self.vehicle = vehicle
    end
    return vehicle
end

function TractorMediaScreen:update(dt)
    if not self.active then return end
    self:refreshVehicle()
    if self.video == nil then return end
    -- The prototype has no native pause/seek API. Stop when a menu opens.
    if g_gui ~= nil and g_gui:getIsGuiVisible() then
        if self.video.id ~= nil then self.video:stop() end
        return
    end
    local before = self.video.state
    self.video:update(dt)
    if before ~= self.video.state then
        Logging.info("[TractorMediaScreen] Native video state: %s", self.video.state)
    end
end

function TractorMediaScreen:draw()
    if not self.active or self.vehicle == nil or not self.pip
        or (g_gui ~= nil and g_gui:getIsGuiVisible()) then return end
    local aspect = (g_screenWidth or 1920) / (g_screenHeight or 1080)
    local width = math.min(0.30, 0.48 * 16 / 9 / aspect)
    local x, y, height = 0.98 - width, 0.20, width * aspect * 9 / 16
    if self.video ~= nil and self.video.id ~= nil then
        self.video:draw(x, y, width, height)
    elseif self.overlay ~= nil and self.overlay ~= 0 then
        renderOverlay(self.overlay, x, y, width, height)
    end
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    local caption = self.i18n:getText(self.video ~= nil and self.video.id ~= nil
        and "tms_videoTest" or "tms_patternTest")
    renderText(x, y + height + 0.006, getCorrectTextSize(0.014), caption)
end

function TractorMediaScreen.registerActionEvents(input, context)
    if not TractorMediaScreen.isEnabled() or g_dedicatedServer ~= nil
        or input.player == nil or not input.player.isOwner then return end
    local actions = {
        {InputAction.TMS25_MENU, TractorMediaScreen.onMenu},
        {InputAction.TMS25_PIP, TractorMediaScreen.onPip},
        {InputAction.TMS25_PATTERN, TractorMediaScreen.onPattern},
        {InputAction.TMS25_VIDEO_TEST, TractorMediaScreen.onVideoTest}
    }
    local count = 0
    for _, action in ipairs(actions) do
        local ok, id = g_inputBinding:registerActionEvent(action[1], input, action[2], false, true, false, true)
        if ok and id ~= nil then
            g_inputBinding:setActionEventTextVisibility(id, false)
            count = count + 1
        end
    end
    local key = context or "player"
    local seen = TractorMediaScreen.registeredContexts or {}
    TractorMediaScreen.registeredContexts = seen
    if not seen[key] then
        Logging.info("[TractorMediaScreen] Local input registered: %d/4 (%s)", count, tostring(key))
        seen[key] = true
    end
end

function TractorMediaScreen.canHandle(input, value)
    local self = TractorMediaScreen
    return self.active and value ~= nil and value > 0 and input.player.isOwner
        and g_currentMission ~= nil and not g_currentMission.isPlayerFrozen
        and not (g_gui ~= nil and g_gui:getIsGuiVisible()) and self:refreshVehicle() ~= nil
end

function TractorMediaScreen.onPip(input, name, value)
    if not TractorMediaScreen.canHandle(input, value) then return end
    local self = TractorMediaScreen
    self.pip = not self.pip
    if not self.pip and self.video ~= nil then self.video:stop() end
end

function TractorMediaScreen.onPattern(input, name, value)
    if not TractorMediaScreen.canHandle(input, value) then return end
    local self = TractorMediaScreen
    local spec = TMSVehicle.getState(self.vehicle)
    if not TMSVehicle.setTestPattern(self.vehicle, not spec.pattern) then
        InfoDialog.show(self.i18n:getText("tms_monitorUnavailable"))
    end
end

function TractorMediaScreen.onVideoTest(input, name, value)
    if not TractorMediaScreen.canHandle(input, value) then return end
    local self = TractorMediaScreen
    if self.video.id ~= nil then self.video:stop(); return end
    local ok = self:startVideoTest("ogv")
    if not ok then InfoDialog.show(self.i18n:getText("tms_nativeUnavailable")) end
end

function TractorMediaScreen.onMenu(input, name, value)
    if not TractorMediaScreen.canHandle(input, value) then return end
    local self = TractorMediaScreen
    self.video:stop()
    TextInputDialog.show(self.onLinkEntered, self, self.lastInput or "",
        self.i18n:getText("tms_menuTitle"), self.i18n:getText("tms_linkPrompt"),
        2048, self.i18n:getText("tms_checkLink"), self.generation)
end

function TractorMediaScreen:onLinkEntered(text, clickOk, generation)
    if not clickOk or not self.active or generation ~= self.generation then return end
    if self.getLocalVehicle() ~= self.vehicle or self.vehicle == nil then return end
    local source, reason = TMSMediaSource.parse(text)
    if source ~= nil then self.source, self.lastInput = source, text end
    InfoDialog.show(self.i18n:getText("tms_" .. reason))
end

function TractorMediaScreen:startVideoTest(format)
    if not self.active or self:refreshVehicle() == nil or self.video == nil then return false end
    if format ~= "ogv" and format ~= "mp4" and format ~= "webm" then return false end
    local filename = self.modDirectory .. "assets/media/test." .. format
    if not fileExists(filename) then return false end
    self.pip = true
    return self.video:start(filename, 0.25)
end

function TractorMediaScreen:consoleVideo(format)
    if self.video == nil then return "No client video session" end
    if format == "stop" then self.video:stop(); return "Stopped" end
    return self:startVideoTest(format or "ogv") and "Native HUD probe started (3D video not implemented)"
        or "No equipped local vehicle, unsupported format, missing file or native API"
end

function TractorMediaScreen:consoleStatus()
    self:refreshVehicle()
    local spec = TMSVehicle.getState(self.vehicle)
    return string.format("TractorMediaScreen %s | equipped=%s | model=%s | native=%s | missing=%s | YouTube=unavailable | 3D video=unverified",
        self.VERSION, tostring(spec ~= nil), tostring(spec ~= nil and spec.monitorNode ~= nil),
        self.video ~= nil and self.video.state or "disabled",
        self.video ~= nil and table.concat(self.video:missingFunctions(), ",") or "client unavailable")
end

function TractorMediaScreen:consoleMount(x, y, z, rx, ry, rz)
    local vehicle = self:refreshVehicle()
    local spec = TMSVehicle.getState(vehicle)
    if spec == nil or spec.monitorNode == nil then return "No equipped local monitor" end
    if x == nil then
        local px, py, pz = getTranslation(spec.monitorNode)
        local a, b, c = getRotation(spec.monitorNode)
        return string.format("tmsMount %.4f %.4f %.4f %.2f %.2f %.2f", px, py, pz,
            math.deg(a), math.deg(b), math.deg(c))
    end
    local values = {x, y, z, rx, ry, rz}
    for i = 1, 6 do
        values[i] = tonumber(values[i])
        if values[i] == nil or values[i] ~= values[i] or math.abs(values[i]) > (i <= 3 and 10 or 360) then
            return "Usage: tmsMount x y z rx ry rz (position -10..10 m, rotation -360..360 deg)"
        end
    end
    setTranslation(spec.monitorNode, values[1], values[2], values[3])
    setRotation(spec.monitorNode, math.rad(values[4]), math.rad(values[5]), math.rad(values[6]))
    return self:consoleMount()
end

function TractorMediaScreen:consoleNodes()
    local vehicle = self:refreshVehicle()
    if vehicle == nil then return "No equipped local vehicle" end
    local names = {}
    for name, node in pairs(vehicle.i3dMappings or {}) do
        local lower = name:lower()
        if lower:find("cabin", 1, true) or lower:find("interior", 1, true) or lower:find("camera", 1, true) then
            table.insert(names, name .. "=" .. tostring(node))
        end
    end
    table.sort(names)
    Logging.info("[TractorMediaScreen] Candidate mappings: %s", table.concat(names, ", "))
    return "Candidate mappings written to log.txt; current mount uses component 1"
end

-- Install hooks once, not on each map load. Both check the mod's active state.
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes,
    TractorMediaScreen.registerVehicleTypes)
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents, TractorMediaScreen.registerActionEvents)
addModEventListener(TractorMediaScreen)
