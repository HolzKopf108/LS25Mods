TMSVehicle = {}

function TMSVehicle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function TMSVehicle.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", TMSVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", TMSVehicle)
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
    spec.mountFinished = false
    if not spec.equipped or not self.isClient or g_dedicatedServer ~= nil then return end
    spec.requestId = self:loadSubSharedI3DFile(
        TractorMediaScreen.modDirectory .. "assets/monitor/monitor.i3d", false, false,
        TMSVehicle.onMonitorLoaded, self, spec)
end

local function isFixedVehicleParent(vehicle, parent, camera)
    local node = parent
    for _ = 1, 64 do
        if node == nil or node == 0 then return false end
        if node == camera.cameraNode or node == camera.cameraPositionNode
            or node == camera.rotateNode or node == camera.headTrackingNode
            or node == camera.cameraWorldParent then return false end
        for _, component in ipairs(vehicle.components or {}) do
            if node == component.node then return true end
        end
        node = getParent(node)
    end
    return false
end

function TMSVehicle.resolveCabinMount(vehicle, profile)
    local enterable = vehicle.spec_enterable
    local root = vehicle.components and vehicle.components[1] and vehicle.components[1].node
    if enterable == nil or root == nil or profile.eyeOffset == nil then return nil end
    for index, camera in ipairs(enterable.cameras or {}) do
        if camera.isInside and camera.cameraPositionNode ~= nil and camera.cameraPositionNode ~= 0
            and type(camera.origTransX) == "number" and type(camera.origTransY) == "number"
            and type(camera.origTransZ) == "number" then
            -- VehicleCamera may detach the rendered camera into world space.
            -- The original position and its base parent remain the cabin reference.
            -- Never use the current pose: saved look/zoom/head tracking is personal.
            local base = camera.cameraBaseParentNode or getParent(camera.cameraPositionNode)
            local parent = base
            local extraRotation = base ~= nil and base ~= 0
                and base == camera.rotateNode and base ~= camera.cameraPositionNode
            if extraRotation then
                parent = getParent(base)
                if type(camera.origRotX) ~= "number" or type(camera.origRotY) ~= "number"
                    or type(camera.origRotZ) ~= "number" then parent = nil end
            end
            if isFixedVehicleParent(vehicle, parent, camera) then
                local eye = {camera.origTransX, camera.origTransY, camera.origTransZ}
                if extraRotation then
                    -- Some indoor cameras have a separate look pivot. Reconstruct
                    -- its neutral pose on our own short-lived node, without moving it.
                    local reference = createTransformGroup("tmsNeutralCameraReference")
                    link(parent, reference)
                    setTranslation(reference, getTranslation(base))
                    setRotation(reference, camera.origRotX, camera.origRotY, camera.origRotZ)
                    eye = {localToLocal(reference, parent, eye[1], eye[2], eye[3])}
                    delete(reference)
                end
                local offset = profile.eyeOffset
                local dx, dy, dz = localDirectionToLocal(root, parent, offset[1], offset[2], offset[3])
                local ux, uy, uz = localDirectionToLocal(root, parent, 0, 1, 0)
                return {parent = parent, cameraIndex = index, eye = eye,
                    position = {eye[1] + dx, eye[2] + dy, eye[3] + dz},
                    direction = {-dx, -dy, -dz}, up = {ux, uy, uz}}
            end
        end
    end
    return nil
end

function TMSVehicle:onLoadFinished()
    local spec = TMSVehicle.getState(self)
    if spec == nil or spec.deleted or not spec.equipped or not self.isClient
        or g_dedicatedServer ~= nil or spec.mountFinished then return end
    -- Enterable:onPostLoad has now finalized camera parents and suspension offsets.
    spec.mount = TMSVehicle.resolveCabinMount(self, spec.profile)
    spec.mountFinished = true
    if spec.mount == nil then
        Logging.warning("[TractorMediaScreen] No fixed indoor camera reference for profile=%s; monitor not attached",
            spec.profile.id)
    end
    TMSVehicle.attachMonitor(self, spec)
end

function TMSVehicle.onMonitorLoaded(vehicle, i3dNode, failedReason, spec)
    if i3dNode == nil or i3dNode == 0 then
        Logging.warning("[TractorMediaScreen] Monitor I3D could not be loaded")
        return
    end
    if spec.deleted or getNumOfChildren(i3dNode) == 0 then delete(i3dNode); return end
    spec.pendingI3d = i3dNode
    TMSVehicle.attachMonitor(vehicle, spec)
end

function TMSVehicle.attachMonitor(vehicle, spec)
    local i3dNode = spec.pendingI3d
    if i3dNode == nil or not spec.mountFinished then return end
    spec.pendingI3d = nil
    if spec.deleted or spec.mount == nil then delete(i3dNode); return end
    local monitor = getChildAt(i3dNode, 0)
    local mount = spec.mount
    local parent = mount.parent
    link(parent, monitor)
    spec.monitorNode, spec.parentNode = monitor, parent
    spec.displayNode = getChildAt(monitor, 0)
    delete(i3dNode)
    local p, d, u = mount.position, mount.direction, mount.up
    setTranslation(monitor, p[1], p[2], p[3])
    -- The model's display faces local +Z. Aim that normal at the original eye point.
    setDirection(monitor, d[1], d[2], d[3], u[1], u[2], u[3])
    spec.pattern = false
    Logging.info("[TractorMediaScreen] Monitor loaded: profile=%s, mount=indoor-reference, parent=%s, camera=%d, position=%.3f %.3f %.3f",
        spec.profile.id, tostring(parent), mount.cameraIndex, p[1], p[2], p[3])
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
    if spec.pendingI3d ~= nil then delete(spec.pendingI3d); spec.pendingI3d = nil end
    if spec.monitorNode ~= nil then delete(spec.monitorNode); spec.monitorNode = nil end
    spec.displayNode, spec.displayMaterial = nil, nil
    if spec.requestId ~= nil then
        g_i3DManager:releaseSharedI3DFile(spec.requestId)
        spec.requestId = nil
    end
end
