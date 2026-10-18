-- Native HUD drawing is mocked. Verify actual submitted colors and rectangles,
-- shared-source synchronization, bounded work and private resource lifetime.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/TMSLog.lua")
dofile(mod .. "/scripts/media/TMSPixelPip.lua")
local count = 0
local function check(value, message) assert(value, message); count = count + 1 end
local warnings, reports = 0, 0
Logging = {warning = function() warnings = warnings + 1 end,
    info = function() reports = reports + 1 end}
local function close(a, b) return math.abs(a - b) < 0.00000001 end

local function fixture()
    local state = {live = {}, deletes = {}, loads = 0, draws = {}, readbacks = 0}
    local api = {}
    function api.createImageOverlay(filename)
        assert(filename == mod .. "/assets/monitor/white.dds", "Tint requires an opaque white source")
        state.loads = state.loads + 1
        if state.failCreate then return 0 end
        state.live[30] = true; return 30
    end
    function api.setOverlayUVs(id, ...)
        assert(id == 30 and state.live[id])
        if state.failUVs then error("UV update rejected") end
        assert(table.concat({...}, ",") == "0,0,0,1,1,0,1,1")
        state.uvsSet = true
    end
    function api.setOverlayColor(id, r, g, b, a)
        assert(id == 30 and state.live[id])
        if state.failColor then error("tint rejected") end
        state.color = {r,g,b,a}
    end
    function api.renderOverlay(id, x, y, width, height)
        assert(id == 30 and state.live[id] and state.uvsSet and state.color)
        if state.failDraw then error("draw rejected") end
        state.draws[#state.draws+1] = {x=x,y=y,width=width,height=height,color=state.color}
    end
    function api.getIsOverlayReady(id)
        assert(id == 30 and state.live[id])
        state.readbacks = state.readbacks + 1
        if state.failReadback then error("readback rejected") end
        return true
    end
    function api.delete(id)
        assert(id == 30 and state.live[id], "Only the private overlay may be deleted, once")
        state.live[id] = nil
        state.deletes[#state.deletes+1] = id
    end
    return TMSPixelPip.new(mod .. "/", api), state, api
end

local corners = {1,0,0,1, 0,1,0,1, 0,0,1,1, 1,1,0,1}
local function draw(pip, frame, data, width, height)
    frame, data, width, height = frame or 0, data or corners, width or 2, height or 2
    return pip:prepare(data, width, height, frame) and pip:draw(frame, 0.68, 0.29, 0.30, 0.30)
end

local pip, state = fixture()
check(state.loads == 0 and pip.overlay == nil, "Construction does not allocate hidden PiP")
check(not pip:draw(0, .68, .29, .3, .3) and state.loads == 0,
    "Draw before update cannot allocate resources or show stale content")
check(draw(pip) and state.loads == 1 and #state.draws == 4 and pip.pixels == corners,
    "First draw uses the exact source table and a single reusable overlay")
local firstReports = reports
local allMatch = true
for i, rect in ipairs(state.draws) do
    local row, col = math.floor((i-1)/2), (i-1)%2
    allMatch = allMatch and close(rect.x, .68+col*.15) and close(rect.y, .29+row*.15)
        and close(rect.width, .15) and close(rect.height, .15)
    for channel = 1, 4 do
        allMatch = allMatch and rect.color[channel] == corners[(i-1)*4+channel]
    end
end
check(allMatch, "All corner colors occupy the expected bottom-left-origin HUD cells")
check(table.concat(state.color, ",") == "1,1,1,1", "Restore opaque white after the raster")
check(draw(pip) and state.loads == 1 and pip.preparedCount == 1 and reports == firstReports,
    "Repeated draws reuse the image and prepared data without log spam")
local draws = #state.draws
check(not pip:draw(1, .68, .29, .3, .3) and #state.draws == draws,
    "An unprepared cabin frame cannot display stale pixels")

local nextPixels = {.1,.2,.3,1, .4,.5,.6,1, .7,.8,.9,1, .2,.5,.8,1}
check(draw(pip, 29, nextPixels) and pip.frame == 29 and pip.pixels == nextPixels and state.loads == 1,
    "Reopening accepts the newest submitted frame without replay or second producer")
check(state.draws[#state.draws].color[3] == .8 and pip.preparedCount == 2,
    "HUD draws supplied arbitrary colors, not a separately generated test pattern")
check(draw(pip, 29, corners) and pip.preparedCount == 3,
    "Replacement data with the same frame number invalidates the cache")
pip:stop()
check(next(state.live) == nil and #state.deletes == 1 and pip.pixels == nil,
    "Stop releases only the owned overlay and all retained source data")
pip:stop()
check(#state.deletes == 1 and pip.error == nil, "Repeated stop is harmless")
check(draw(pip) and state.loads == 2 and pip.preparedCount == 1,
    "A new session can lazily start at frame zero")
pip:stop()

local full, fullState = fixture()
local raster = {}
for y = 0, 17 do
    for x = 0, 31 do
        local i = #raster
        raster[i+1],raster[i+2],raster[i+3],raster[i+4] = x/31,y/17,.37,1
    end
end
check(draw(full, 12, raster, 32, 18) and #fullState.draws == 576 and full.cellDrawCount == 576,
    "Full probe raster submits exactly 576 cells, with one image overlay")
local colorsMatch, edgesMatch = true, true
for i, rect in ipairs(fullState.draws) do
    for channel = 1, 4 do
        colorsMatch = colorsMatch and rect.color[channel] == raster[(i-1)*4+channel]
    end
    if (i-1)%32 < 31 then edgesMatch = edgesMatch and close(rect.x+rect.width, fullState.draws[i+1].x) end
    if i <= 32*17 then edgesMatch = edgesMatch and close(rect.y+rect.height, fullState.draws[i+32].y) end
end
local last = fullState.draws[576]
check(colorsMatch, "Every submitted RGBA value matches the source without interpolation or regeneration")
check(edgesMatch and close(last.x+last.width, .98) and close(last.y+last.height, .59),
    "Adjacent edges meet and the final cells end at the intended rectangle bounds")
full:stop()

local missing, missingState, missingApi = fixture()
missingApi.createImageOverlay = nil
check(not draw(missing) and missingState.loads == 0 and missing.error:find("createImageOverlay", 1, true),
    "Missing API fails before allocation")
local rejected, rejectedState = fixture()
rejectedState.failCreate = true
check(not draw(rejected) and next(rejectedState.live) == nil, "Rejected constructor retains no resources")

local invalidCases = {
    {corners, 33, 18, 0}, {corners, 2, 19, 0}, {corners, 0, 2, 0},
    {corners, 2.5, 2, 0}, {corners, 2, 2, math.huge}, {corners, 2, 2, -1},
    {corners, 2, 2, 0/0}, {{1,1,1}, 1, 1, 0},
    {{0/0,1,1,1}, 1, 1, 0}, {{1,math.huge,1,1}, 1, 1, 0},
    {{1,1,-.1,1}, 1, 1, 0}, {{1,1,1,1.1}, 1, 1, 0},
    {{"bad",1,1,1}, 1, 1, 0}
}
local invalidRejected = true
for _, args in ipairs(invalidCases) do
    local invalid, invalidState = fixture()
    invalidRejected = invalidRejected and not invalid:prepare(args[1],args[2],args[3],args[4])
        and invalidState.loads == 0 and next(invalidState.live) == nil
end
check(invalidRejected, "Dimensions, size bound, frame and every RGBA component are checked before allocation")

for _, failure in ipairs({"failUVs", "failColor", "failDraw"}) do
    local failed, failedState = fixture()
    failedState[failure] = true
    local beforeWarnings = warnings
    check(not draw(failed) and failed.error ~= nil and next(failedState.live) == nil and failed.pixels == nil,
        failure .. " releases only PiP resources")
    check(not draw(failed, 1) and failedState.loads == 1 and warnings == beforeWarnings+1,
        failure .. " warns once without retrying every frame")
    failed:stop()
    failedState[failure] = nil
    check(draw(failed) and failed.error == nil, failure .. " can recover after explicit session restart")
    failed:stop()
end

local diagnostic, diagnosticState = fixture()
draw(diagnostic)
local initialReports = reports
for frame = 1, 49 do draw(diagnostic, frame) end
check(reports == initialReports, "Diagnostics do not log every frame")
draw(diagnostic, 50)
check(reports == initialReports+1, "Progress is reported once per five source seconds")
diagnosticState.failReadback = true
check(draw(diagnostic, 100) and diagnostic.error == nil, "Optional readiness failures cannot stop HUD drawing")
diagnostic:stop()
local optional, optionalState, optionalApi = fixture()
optionalApi.getIsOverlayReady = nil
check(draw(optional) and optionalState.readbacks == 0, "Missing optional readiness getter permits drawing")
optional:stop()

local quiet, quietState = fixture()
TMSLog.DEBUG = false
local quietReports, quietWarnings = reports, warnings
check(draw(quiet) and quietState.readbacks == 0 and reports == quietReports,
    "Debug off skips all logging and readbacks while retaining playback")
quietState.failDraw = true
check(not draw(quiet) and quiet.error ~= nil and warnings == quietWarnings and next(quietState.live) == nil,
    "Debug off retains failure isolation and cleanup")
TMSLog.DEBUG = true
print(string.format("TractorMediaScreen pixel PiP: %d checks passed (%s)", count, _VERSION))
