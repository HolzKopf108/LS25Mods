-- Native rendering is mocked. These checks cover isolation and resource lifetime.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/TMSLog.lua")
dofile(mod .. "/scripts/media/TMSPixelPip.lua")
local count = 0
local function check(value, message) assert(value, message); count = count + 1 end
local warnings, reports = 0, 0
Logging = {warning = function() warnings = warnings + 1 end,
    info = function() reports = reports + 1 end}

local function fixture()
    local state = {live = {}, deletes = {}, loads = 0, updates = 0, draws = 0, assignments = 0, readbacks = 0}
    local api = {atmosphereQualityOff = 4} -- arbitrary named enum value, never guessed in production
    function api.loadI3DFile(filename, physics, onCreate, callUserAttributes)
        assert(filename == mod .. "/assets/pixelProbe/screen.i3d")
        assert(not physics and not onCreate and not callUserAttributes)
        state.loads = state.loads + 1
        state.live[10] = true; return 10
    end
    function api.setVisibility(id, visible)
        if id == 10 then assert(not visible); state.hidden = true
        else assert(id == 11 and visible); state.surfaceVisible = true end
    end
    function api.getNumOfChildren(id) assert(id == 10); return state.badModel and 2 or 1 end
    function api.getChildAt(id, index) assert(id == 10 and index == 0); return 11 end
    function api.getRootNode() return 999 end
    function api.link(parent, child)
        if child == 10 then assert(parent == 999 and state.hidden)
        else
            assert(parent == 10 and child == 20)
            if state.failLinkCamera then error("camera link rejected") end
            state.linkedCamera = true
        end
    end
    function api.setMaterial(node, material, slot)
        assert(node == 11 and material > 0 and slot == 0)
        if state.failMaterial then error("material rejected") end
        state.material = material; state.assignments = state.assignments + 1
    end
    function api.createCamera(name, fov, nearClip, farClip)
        assert(name == "TMSPixelPip" and math.abs(fov - math.pi / 3) < 0.0001)
        assert(nearClip == 0.01 and farClip == 2)
        state.live[20] = true; return 20
    end
    function api.setTranslation(camera, x, y, z) assert(camera == 20 and x == 0 and y == 0 and z == 1) end
    function api.setRotation(camera, x, y, z) assert(camera == 20 and x == 0 and y == 0 and z == 0) end
    function api.setIsOrthographic(camera, enabled) assert(camera == 20 and enabled) end
    function api.setOrthographicHeight(camera, height) assert(camera == 20 and height == 0.144) end
    function api.createRenderOverlay(scene, camera, aspect, resX, resY, alpha, shapeMask, lightMask,
        shadows, bloom, dof, ssao, async, atmosphere)
        assert(scene == 10 and camera == 20 and aspect == 16 / 9 and resX == 512 and resY == 288)
        assert(not alpha and shapeMask == 255 and lightMask == 67108864 and not shadows)
        assert(bloom == 0 and not dof and ssao == 0 and not async and atmosphere == api.atmosphereQualityOff)
        if state.failOverlay then return 0 end
        state.live[30] = true; return 30
    end
    function api.updateRenderOverlay(overlay)
        assert(overlay == 30 and state.live[30] and state.material)
        if state.failUpdate then error("overlay update rejected") end
        state.updates = state.updates + 1
    end
    function api.renderOverlay(overlay, x, y, width, height)
        assert(overlay == 30 and x == 0.7 and y == 0.3 and width == 0.25 and height == 0.25)
        assert(state.uvsSet and state.colorSet, "A render target must set full image UVs and opacity before every HUD draw")
        if state.failDraw then error("overlay draw rejected") end
        state.draws = state.draws + 1
        state.uvsSet, state.colorSet = false, false
    end
    function api.setOverlayUVs(overlay, ...)
        assert(overlay == 30)
        if state.failUVs then error("UV update rejected") end
        assert(table.concat({...}, ",") == "0,0,0,1,1,0,1,1", "Full RenderElement UV range")
        state.uvsSet = true
    end
    function api.setOverlayColor(overlay, r, g, b, a)
        assert(overlay == 30 and r == 1 and g == 1 and b == 1 and a == 1)
        state.colorSet = true
    end
    function api.getIsOverlayReady(overlay)
        assert(overlay == 30)
        state.readbacks = state.readbacks + 1
        if state.failReadback then error("readback rejected") end
        return true
    end
    function api.delete(id)
        assert(state.live[id], "Each owned entity is released only once")
        if id == 10 then
            assert(not state.live[30], "Delete overlay before its scene")
            if state.linkedCamera then state.live[20] = nil end
            state.linkedCamera = false
        end
        state.live[id] = nil
        table.insert(state.deletes, id)
    end
    return TMSPixelPip.new(mod .. "/", api), state, api
end

local function draw(pip, material, frame)
    material, frame = material or 40, frame or 0
    return pip:prepare(material, frame) and pip:draw(material, frame, 0.7, 0.3, 0.25, 0.25)
end

local pip, state = fixture()
check(state.loads == 0 and pip.overlay == nil, "Construction never loads hidden PiP")
check(not pip:draw(40, 0, 0.7, 0.3, 0.25, 0.25) and state.loads == 0,
    "Draw before update does not create a scene or show stale content")
check(pip:setMaterial(40) and state.assignments == 0, "Cabin uploads do not instantiate hidden PiP")
check(draw(pip) and state.hidden and state.surfaceVisible and state.material == 40,
    "First visible update hides the scene from the world but enables its surface")
local firstReports = reports
check(state.loads == 1 and state.updates == 1 and state.draws == 1 and reports > 0 and state.readbacks > 0,
    "First visible frame renders exactly once and reports actual readbacks")
check(draw(pip) and state.updates == 1 and state.draws == 2 and reports == firstReports,
    "Unchanged frames reuse the rendered overlay without repeated reports")
check(draw(pip, 40, 1) and state.loads == 1 and state.updates == 2, "Changed frame updates existing scene once")
check(not pip:draw(40, 2, 0.7, 0.3, 0.25, 0.25) and state.updates == 2 and state.draws == 3,
    "Draw for an unprepared frame waits for update rather than displaying stale pixels")
check(pip:draw(40, 1, 0.7, 0.3, 0.25, 0.25) and state.updates == 2,
    "Drawing current frame cannot update off-screen scene")
check(pip:setMaterial(41) and state.material == 41 and state.updates == 2,
    "Replace shared material before old texture release without rendering or creating texture data")
check(not pip:draw(41, 1, 0.7, 0.3, 0.25, 0.25) and not pip:draw(40, 1, 0.7, 0.3, 0.25, 0.25),
    "Changed material invalidates prepared content until update")
check(draw(pip, 41, 1) and state.updates == 3, "Material replacement refreshes even the same frame number")
pip:setMaterial(41)
pip:setMaterial(41)
check(state.updates == 3 and state.assignments == 2, "Hidden uploads neither render nor reassign unchanged material")
check(draw(pip, 41, 29) and state.updates == 4 and pip.lastFrame == 29,
    "Reopening PiP immediately displays latest frame without replaying missed frames")
check(pip.renderCount == 4, "Render count tracks actual refreshed frames")
pip:stop()
check(next(state.live) == nil and #state.deletes == 2 and state.deletes[1] == 30 and state.deletes[2] == 10,
    "Cleanup deletes overlay first and scene owns camera cleanup")
pip:stop()
check(#state.deletes == 2 and pip.error == nil, "Repeated stop is harmless and permits a new session")
check(draw(pip, 50, 0) and state.loads == 2 and pip.renderCount == 1, "New session can lazily reopen at frame zero")
pip:stop()

local missing, missingState, missingApi = fixture()
missingApi.createRenderOverlay = nil
check(not draw(missing) and missingState.loads == 0 and missing.error:find("createRenderOverlay", 1, true),
    "Missing API fails before allocating scene")
local enum, enumState, enumApi = fixture()
enumApi.atmosphereQualityOff = nil
check(not draw(enum) and enumState.loads == 0, "Missing named atmosphere enum has no hard-coded fallback")
local invalid, invalidState = fixture()
check(not draw(invalid, math.huge) and invalidState.loads == 0, "Invalid material fails before native work")

local model, modelState = fixture()
modelState.badModel = true
check(not draw(model) and next(modelState.live) == nil, "Unexpected model releases partially loaded scene")
local camera, cameraState = fixture()
cameraState.failLinkCamera = true
check(not draw(camera) and next(cameraState.live) == nil and cameraState.deletes[2] == 20,
    "Unlinked camera is released after scene when linking fails")
local overlay, overlayState = fixture()
overlayState.failOverlay = true
check(not draw(overlay) and next(overlayState.live) == nil and #overlayState.deletes == 1,
    "Overlay creation rejection releases scene and linked camera")

local failed, failedState = fixture()
draw(failed)
failedState.failUpdate = true
local beforeWarnings = warnings
check(not draw(failed, 40, 1) and next(failedState.live) == nil and failed.error ~= nil,
    "Render update failure releases PiP without requiring cabin shutdown")
check(not draw(failed, 40, 2) and not failed:setMaterial(41) and warnings == beforeWarnings + 1,
    "Failed PiP warns once and does not retry during that pixel session")
check(failedState.loads == 1, "Frame changes cannot silently restart failed PiP")
failed:stop()
failedState.failUpdate = false
check(draw(failed, 40, 0) and failed.error == nil, "Explicit pixel session restart clears failure latch")
failed:stop()

local rejected, rejectedState = fixture()
draw(rejected)
rejectedState.failMaterial = true
check(not rejected:setMaterial(41) and next(rejectedState.live) == nil,
    "Failed material replacement detaches PiP before caller releases previous texture")
local rejectedDraw, rejectedDrawState = fixture()
rejectedDrawState.failDraw = true
check(not draw(rejectedDraw) and next(rejectedDrawState.live) == nil,
    "HUD drawing failure releases resources and is contained")

local rejectedUV, rejectedUVState = fixture()
rejectedUVState.failUVs = true
check(not draw(rejectedUV) and next(rejectedUVState.live) == nil and rejectedUVState.draws == 0,
    "Failed UV initialization is contained without drawing a misleading empty overlay")
local missingUV, missingUVState, missingUVApi = fixture()
missingUVApi.setOverlayUVs = nil
check(not draw(missingUV) and missingUVState.loads == 0, "Missing required UV API fails before allocations")

local diagnostic, diagnosticState = fixture()
draw(diagnostic)
local initialReports = reports
for frame = 1, 49 do draw(diagnostic, 40, frame) end
check(reports == initialReports, "Diagnostics do not spam log for every frame")
draw(diagnostic, 40, 50)
check(reports == initialReports + 1, "Progress readback is limited to one per five seconds of source time")
diagnosticState.failReadback = true
check(draw(diagnostic, 40, 100) and diagnostic.error == nil,
    "Optional readiness getter failure cannot stop pixel rendering")
diagnostic:stop()

local quiet, quietState = fixture()
TMSLog.DEBUG = false
local quietReports, quietWarnings = reports, warnings
check(draw(quiet) and quietState.readbacks == 0 and reports == quietReports,
    "Disabled debug performs no diagnostic readbacks or logging while rendering still works")
quietState.failDraw = true
check(not draw(quiet) and quiet.error ~= nil and warnings == quietWarnings and next(quietState.live) == nil,
    "Disabling logs preserves error containment and cleanup")
TMSLog.DEBUG = true
print(string.format("TractorMediaScreen pixel PiP: %d checks passed (%s)", count, _VERSION))
