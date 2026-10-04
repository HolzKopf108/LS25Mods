TMSVehicle = {}

function TMSVehicle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function TMSVehicle.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", TMSVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", TMSVehicle)
end

function TMSVehicle.getState(vehicle)
    if vehicle == nil or TractorMediaScreen == nil then return nil end
    return vehicle["spec_" .. TractorMediaScreen.modName .. ".tractorMediaScreen"]
end

function TMSVehicle:onLoad(savegame)
    local spec = TMSVehicle.getState(self)
    if spec == nil then return end
    spec.profile = TMSProfiles.find(self.configFileName)
    spec.equipped = spec.profile ~= nil and self.configurations.tmsMonitor == 2
    spec.deleted = false
    if not spec.equipped or not self.isClient or g_dedicatedServer ~= nil then return end
    spec.requestId = self:loadSubSharedI3DFile(
        TractorMediaScreen.modDirectory .. "assets/monitor/monitor.i3d", false, false,
        TMSVehicle.onMonitorLoaded, self, spec)
end

function TMSVehicle.onMonitorLoaded(vehicle, i3dNode, failedReason, spec)
    if i3dNode == nil or i3dNode == 0 then
        Logging.warning("[TractorMediaScreen] Monitor I3D could not be loaded")
        return
    end
    if spec.deleted or getNumOfChildren(i3dNode) == 0 then delete(i3dNode); return end
    local monitor = getChildAt(i3dNode, 0)
    local parent = vehicle.components[1].node
    -- A fixed vehicle component is used until the actual cabin mapping is verified.
    -- Never attach to the movable camera node.
    link(parent, monitor)
    spec.monitorNode, spec.parentNode = monitor, parent
    spec.displayNode = getChildAt(monitor, 0)
    delete(i3dNode)
    local p, r = spec.profile.position, spec.profile.rotation
    setTranslation(monitor, p[1], p[2], p[3])
    setRotation(monitor, math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
    spec.pattern = false
    Logging.info("[TractorMediaScreen] Monitor loaded: profile=%s, mount=provisional, node=%s",
        spec.profile.id, tostring(monitor))
end

function TMSVehicle.setTestPattern(vehicle, enabled)
    local spec = TMSVehicle.getState(vehicle)
    if spec == nil or spec.displayNode == nil or spec.deleted then return false end
    if spec.pattern == enabled then return true end
    if type(setMaterialDiffuseMapFromFile) ~= "function" then return false end
    local filename = TractorMediaScreen.modDirectory .. "assets/monitor/"
        .. (enabled and "testPattern.dds" or "black.dds")
    -- The first edit clones the shared material. Subsequent edits affect only
    -- this vehicle's material, so another tractor on this client stays black.
    local ok, material = pcall(setMaterialDiffuseMapFromFile,
        spec.displayMaterial or getMaterial(spec.displayNode, 0), filename,
        false, true, spec.displayMaterial ~= nil)
    if not ok or material == nil or material == 0 then
        Logging.warning("[TractorMediaScreen] Display material update failed")
        return false
    end
    setMaterial(spec.displayNode, material, 0)
    spec.displayMaterial, spec.pattern = material, enabled
    return true
end

function TMSVehicle:onDelete()
    local spec = TMSVehicle.getState(self)
    if spec == nil then return end
    spec.deleted = true
    if TractorMediaScreen.vehicle == self then TractorMediaScreen:releaseSession() end
    if spec.monitorNode ~= nil then delete(spec.monitorNode); spec.monitorNode = nil end
    spec.displayNode, spec.displayMaterial = nil, nil
    if spec.requestId ~= nil then
        g_i3DManager:releaseSharedI3DFile(spec.requestId)
        spec.requestId = nil
    end
end
