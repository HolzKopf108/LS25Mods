-- Resource/lifecycle tests. Mocked calls do not validate a native binding or shader.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/TMSLog.lua")
dofile(mod .. "/scripts/media/TMSPixelProbe.lua")
local count = 0
local function check(value, message) assert(value, message); count = count + 1 end
Logging = {info = function() end, warning = function() end}

local function fixture()
    local state = {live = {}, nextId = 100, uploads = {}, deletes = {}, materials = {}, calls = 0}
    local api = {format = 27}
    function api.loadI3DFile(filename, physics, onCreate)
        assert(filename == mod .. "/assets/pixelProbe/screen.i3d" and not physics and not onCreate)
        state.live[10] = true; return 10
    end
    function api.getNumOfChildren() return 1 end
    function api.getChildAt() return 11 end
    function api.setVisibility(_, visible)
        if visible then assert(state.bound ~= nil, "Never render without a bound buffer") end
    end
    function api.link(parent, root) state.parent = parent; assert(root == 10) end
    function api.createTextureBuffer(name, format, data)
        assert(format == 27 and name:find("TMSPixelProbe_", 1, true) == 1 and #data == 32 * 18 * 4)
        state.calls = state.calls + 1
        if state.failCreate then return 0 end
        state.nextId = state.nextId + 1
        state.live[state.nextId] = true
        table.insert(state.uploads, data)
        return state.nextId
    end
    function api.getMaterial() return 30 end
    function api.setMaterialCustomMap(material, name, texture, shared)
        assert(name == "tmsPixels" and state.live[texture])
        if state.failBind then error("rejected material") end
        table.insert(state.materials, {material, shared})
        state.bound = texture
        return shared and material or 31
    end
    function api.setMaterial(node, material) assert(node == 11 and material == 31) end
    function api.delete(id)
        assert(state.live[id], "Release each owned entity exactly once")
        state.live[id] = nil; table.insert(state.deletes, id)
        if id == 10 then state.bound = nil end
        if id == state.bound then error("Released current texture before replacing/removing material") end
    end
    return TMSPixelProbe.new(mod .. "/", api), state, api
end

local probe, state = fixture()
check(probe.state == "idle" and state.calls == 0, "Construction makes no native probe calls")
check(probe:start(500) and state.parent == 500 and state.calls == 1, "Explicit start attaches only to chosen monitor")
check(probe.pixelData == state.uploads[1], "Probe retains the exact table submitted to the texture buffer")
check(state.materials[1][2] == false, "First map edit clones the material")
probe:update(99)
check(state.calls == 1, "No upload every game frame")
probe:update(1)
check(state.calls == 2 and state.materials[2][2] == true and state.materials[2][1] == 31,
    "Next update edits only the own material")
check(probe.pixelData == state.uploads[2] and probe.pixelData ~= state.uploads[1],
    "Next upload replaces the CPU frame rather than mutating the previous table")
check(state.deletes[1] == 101 and state.live[102], "Replace before releasing the previous buffer")
probe:update(1200)
check(state.calls == 3 and probe.frame == 13, "Slow update skips stale frames without a catch-up burst")
local liveCount = 0
for _ in pairs(state.live) do liveCount = liveCount + 1 end
check(liveCount == 2, "Only scene and current texture retained after an update")
for _, dt in ipairs({-1, 0/0, math.huge, "100"}) do probe:update(dt) end
check(state.calls == 3, "Invalid time values cannot produce an unbounded frame or buffer")
probe:update(20000)
check(not probe.active and probe.state == "completed" and next(state.live) == nil, "Automatic time limit frees all entities")
check(probe.pixelData == nil, "Automatic stop releases the retained CPU pixels")
check(state.deletes[#state.deletes - 1] == 10, "Scene goes away before its last texture")
local released = #state.deletes
probe:stop(); probe:update(100)
check(#state.deletes == released and state.calls == 3, "Cleanup is idempotent; stopped probe cannot upload")

local data = TMSPixelProbe.pixels(0)
local changed = TMSPixelProbe.pixels(8)
local inRange, moved = true, false
for i, v in ipairs(data) do
    if v < 0 or v > 1 then inRange = false end
    if v ~= changed[i] then moved = true end
end
check(#data == 2304 and inRange and moved, "Complete finite RGBA image changes with time")
local function color(x, y) local i = (y * 32 + x) * 4; return data[i+1], data[i+2], data[i+3] end
local r,g,b = color(0,0)
check(r == 1 and g == 0 and b == 0, "Bottom left orientation marker red")
r,g,b = color(31,17)
check(r == 1 and g == 1 and b == 0, "Top right orientation marker yellow")

local missing, missingState, missingApi = fixture()
missingApi.createTextureBuffer = nil
check(not missing:start(500) and next(missingState.live) == nil, "Missing API fails before loading any scene")
local unsupported, unsupportedState, unsupportedApi = fixture()
unsupportedApi.format = nil
check(not unsupported:start(500) and next(unsupportedState.live) == nil, "No hard-coded format fallback")
local absent, absentState = fixture()
check(not absent:start(nil) and absentState.calls == 0, "No work without an attached monitor")
local failed, failedState = fixture()
failedState.failCreate = true
check(not failed:start(500) and next(failedState.live) == nil, "Constructor rejection cleans partially loaded scene")
local rejected, rejectedState = fixture()
rejectedState.failBind = true
check(not rejected:start(500) and next(rejectedState.live) == nil, "Bind rejection frees pending texture and scene")
check(rejected.pixelData == nil, "Rejected initial upload never becomes a HUD source")
local later, laterState = fixture()
later:start(500); laterState.failBind = true; later:update(100)
check(later.state == "failed" and next(laterState.live) == nil, "Update failure frees both old and pending texture")
check(later.pixelData == nil, "Failed replacement drops the last CPU frame rather than retaining stale pixels")
local calls = laterState.calls
later:update(1000)
check(laterState.calls == calls, "Failed probe does not retry on each game update")
laterState.failBind = false
check(later:start(600) and laterState.parent == 600, "An explicit new attempt can recover")
later:stop()
check(next(laterState.live) == nil, "Retried probe also releases all resources")

local synced, syncedState = fixture()
local pip = {prepared = 0, drawn = 0, stopped = 0}
function pip:stop()
    self.stopped = self.stopped + 1
    self.pixels, self.frame, self.error = nil, nil, nil
end
function pip:prepare(pixels, width, height, frame)
    if self.error ~= nil then return false end
    assert(width == 32 and height == 18 and pixels == syncedState.uploads[#syncedState.uploads],
        "HUD receives exactly the successful cabin upload with its dimensions")
    self.pixels = pixels
    self.prepared = self.prepared + 1
    self.frame = frame
    return true
end
function pip:draw(frame)
    if self.error ~= nil then return false end
    assert(self.frame == frame and self.pixels == synced.pixelData)
    self.drawn = self.drawn + 1
    return true
end
synced.pipRenderer = pip
synced:start(500); synced:update(0, false)
check(pip.prepared == 0, "Hidden PiP does not prepare HUD pixels")
synced:update(0, true); synced:draw(0, 0, .3, .2)
check(pip.frame == synced.frame and pip.pixels == synced.pixelData and syncedState.calls == 1,
    "Both displays share the submitted CPU pixels and frame, with a single producer")
synced:update(150, false)
check(pip.prepared == 1 and synced.frame == 1 and syncedState.calls == 2,
    "Hiding PiP leaves the producer running")
synced:update(0, true)
check(pip.frame == 1 and pip.pixels == syncedState.uploads[2] and syncedState.calls == 2,
    "Reshow refreshes existing cabin pixels without an extra buffer or animation generator")
pip.error = "HUD drawing unavailable"
synced:update(100, true)
check(synced.active and synced.frame == 2 and syncedState.calls == 3,
    "Failed optional HUD does not interrupt cabin pixel uploads")
check(not synced:draw(0, 0, .3, .2), "HUD failure propagates to caller without stopping the producer")
local stopCount = pip.stopped
local originalDelete = synced.api.delete
synced.api.delete = function(id)
    assert(pip.stopped == stopCount + 1 and pip.pixels == nil,
        "PiP releases its CPU pixels before cabin resources are deleted")
    originalDelete(id)
end
synced:stop()
check(not synced:draw(0, 0, .3, .2) and next(syncedState.live) == nil,
    "Stopping removes both outputs before releasing last buffer")
check(synced.pixelData == nil and pip.pixels == nil and pip.frame == nil,
    "Stopping removes every retained CPU-frame reference from both outputs")
print(string.format("TractorMediaScreen pixel probe: %d checks passed (%s)", count, _VERSION))
