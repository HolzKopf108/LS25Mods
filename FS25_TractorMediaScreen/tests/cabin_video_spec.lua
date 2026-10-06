-- Clock/material behavior only. This cannot prove FS25 rendering performance.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/media/TMSCabinClipData.lua")
dofile(mod .. "/scripts/media/TMSCabinVideo.lua")
local count, warnings = 0, 0
local function check(value, message) assert(value, message); count = count + 1 end
Logging = {info = function() end, warning = function() warnings = warnings + 1 end}
local function fixture()
    local applied, restored, fail = {}, {}, false
    local cabin = TMSCabinVideo.new(mod .. "/", TMSCabinClipData, {
        setTexture = function(vehicle, filename)
            table.insert(applied, {vehicle = vehicle, filename = filename})
            return not fail
        end,
        restore = function(vehicle) table.insert(restored, vehicle) end
    })
    return cabin, applied, restored, function() fail = true end
end
local v1, v2 = {}, {}
local cabin, applied, restored = fixture()
local video = {id = 1, state = "loading", currentTime = nil}
cabin:update(v1, video, "ogv")
check(#applied == 0, "Loading does not display an unrelated first frame")
video.state, video.currentTime = "playing", 0
cabin:update(v1, video, "ogv")
check(cabin.frame == 1 and applied[1].vehicle == v1, "First decoded frame belongs only to local vehicle")
video.currentTime = 1
cabin:update(v1, video, "ogv")
check(cabin.frame == 16, "Decoder clock is seconds, not milliseconds")
video.currentTime = 1.01
cabin:update(v1, video, "ogv")
check(#applied == 2, "No duplicate material reload within a frame interval")
video.currentTime = 5.999
cabin:update(v1, video, "ogv")
check(cabin.frame == 90 and #applied == 3, "Slow game update skips stale frames instead of accumulating drift")
video.currentTime = 0
cabin:update(v1, video, "ogv")
check(cabin.frame == 1, "Decoder clock wrapping to zero loops the cabin clip")
video.currentTime = 6
cabin:update(v1, video, "ogv")
check(cabin.frame == 1 and #applied == 4, "Boundary time wraps safely without out-of-range filename")
video.currentTime = 7
cabin:update(v1, video, "ogv")
check(cabin.frame == 16, "Continuously increasing loop clock is also supported")
local before = #applied
video.currentTime, video.timingError = nil, "clock failed"
cabin:update(v1, video, "ogv"); cabin:update(v1, video, "ogv")
check(#applied == before and cabin.state == "decoderClockUnavailable" and warnings == 1
    and cabin.frame == nil and #restored == 1,
    "Clock loss restores display without drift, frozen frame or repeated warning")
video.currentTime, video.timingError = 2, nil
cabin:update(v1, video, "ogv")
check(cabin.frame == 31, "Clock recovery resumes at actual media time")
cabin:update(v2, video, "ogv")
check(restored[#restored] == v1 and applied[#applied].vehicle == v2, "Vehicle replacement restores previous material first")
cabin:clear(); cabin:clear()
check(#restored == 3 and restored[3] == v2 and cabin.state == "idle", "Stop restores exactly once")
video.id, video.currentTime = 2, 0
cabin:update(v1, video, "mp4")
check(cabin.state == "unsupportedTestFormat" and cabin.frame == nil,
    "Prepared OGV frames cannot impersonate a different source")
cabin:update(v1, {state = "idle"}, "ogv")
check(cabin.vehicle == nil, "Released decoder cannot retain a monitor session")

for _, time in ipairs({-1, math.huge, 0/0, "1"}) do
    local invalid, edits = fixture()
    invalid:update(v1, {id = 3, state = "playing", currentTime = time}, "ogv")
    check(#edits == 0 and invalid.state == "decoderClockUnavailable", "Invalid clock cannot index a frame")
end
local failed, edits, _, fail = fixture()
fail()
failed:update(v1, {id = 4, state = "playing", currentTime = 0}, "ogv")
failed:update(v1, {id = 4, state = "playing", currentTime = 1}, "ogv")
check(#edits == 1 and failed.state == "materialUpdateFailed", "Material failure stops further work until retry")
failed:update(v1, {id = 5, state = "playing", currentTime = 0}, "ogv")
check(#edits == 2, "A new decoder session permits a fresh material attempt")
print(string.format("Cabin video: %d checks passed (%s)", count, _VERSION))
