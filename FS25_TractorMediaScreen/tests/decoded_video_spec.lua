-- The real Lua codec and bundled packets run here. Only the GPU surface is mocked.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/TMSLog.lua")
dofile(mod .. "/scripts/media/TMSQtrleDecoder.lua")
dofile(mod .. "/scripts/media/TMSDecodedClipData.lua")
dofile(mod .. "/scripts/media/TMSDecodedVideo.lua")
local count, messages = 0, 0
local function check(value, message) assert(value, message); count = count + 1 end
Logging = {info = function() messages = messages + 1 end, warning = function() messages = messages + 1 end}

local function fixture(data)
    local surface = {uploads = 0, starts = 0, stops = 0}
    function surface:start(parent, pixels, frame)
        assert(parent == 900 and #pixels == 2304)
        self.active, self.starts = true, self.starts + 1
        self:upload(frame, pixels)
        return true
    end
    function surface:upload(frame, pixels)
        if self.reject then error("surface upload rejected") end
        self.uploads, self.frame, self.pixels = self.uploads + 1, frame, pixels
    end
    function surface:stop()
        self.active, self.pixels = false, nil
        self.stops = self.stops + 1
    end
    return TMSDecodedVideo.new(data or TMSDecodedClipData, surface), surface
end
local video = {id = 77, state = "loading"}
local clip, surface = fixture()
check(clip:start(900) and clip.state == "waiting" and surface.starts == 0,
    "Starting validates codec data but allocates no GPU surface before native playback")
check(clip:update(video, 100) and surface.starts == 0, "Loading waits for the native clock without an invented time")
video.state, video.currentTime = "playing", 0
check(clip:update(video, 16) and clip.frame == 0 and clip.decodedPackets == 1 and surface.starts == 1,
    "Native time zero decodes and uploads the first actual video packet")
check(clip:update(video, 16) and surface.uploads == 1, "Unchanged player time does not decode or upload again")
video.currentTime = .3
check(clip:update(video, 1000) and clip.frame == 3 and clip.decodedPackets == 4 and surface.uploads == 2,
    "Native time selects picture; game dt only limits the experiment")
local firstPixels = surface.pixels
video.currentTime = 5.9
local before = clip.decodedPackets
check(clip:update(video, 1) and clip.frame == 59 and clip.decodedPackets - before == 10,
    "Large jumps decode only the nearest keyframe group, at most ten packets")
check(surface.pixels ~= firstPixels and #surface.pixels == 2304, "Uploads own immutable RGBA data for each displayed frame")
video.currentTime = .1
before = clip.decodedPackets
check(clip:update(video, 200) and clip.frame == 1 and clip.decodedPackets - before == 2,
    "Loop or backwards seek resets codec state and rebuilds the correct keyframe group")
local independent = assert(TMSQtrleDecoder.new(32, 18))
independent:decode(TMSDecodedClipData.frames[1].hex)
local expected = TMSDecodedVideo.toPixels(assert(independent:decode(TMSDecodedClipData.frames[2].hex)), 32, 18)
local equal = true
for i = 1, #expected do equal = equal and expected[i] == surface.pixels[i] end
check(equal, "Rebuilt delta frame equals an independent decode from its keyframe")
clip:stop()
check(clip.state == "idle" and clip.decoder == nil and not surface.active and surface.pixels == nil,
    "Stop releases codec reference and GPU data")
check(not clip:update(video, 10), "Stopped decoder performs no work")

local corners = string.char(255,0,0, 0,255,0, 0,0,255, 128,128,128)
local converted = TMSDecodedVideo.toPixels(corners, 2, 2)
check(converted[1] == 0 and converted[2] == 0 and converted[3] == 1 and converted[4] == 1,
    "Codec bottom row becomes cabin row zero with opaque alpha")
check(converted[9] == 1 and converted[10] == 0 and converted[11] == 0,
    "Codec top-left red stays top-left on the cabin surface")
check(math.abs(converted[5] - .2158605001) < .000001 and converted[5] == converted[6],
    "sRGB bytes are converted to linear floats expected by the buffer shader")
check(TMSDecodedVideo.toPixels("short", 32, 18) == nil, "Incomplete decoded image is rejected")

local limited, limitedSurface = fixture()
limited:start(900)
video.currentTime = 1
limited:update(video, 1)
check(limited:update(video, 19999) and limited.state == "completed" and not limitedSurface.active,
    "Twenty seconds of playing ends and frees the cab surface")
check(not limited:update(video, 100), "Completed session cannot restart implicitly")

for _, clock in ipairs({-1, math.huge, 0/0, "1"}) do
    local bad, badSurface = fixture()
    bad:start(900); video.currentTime = clock
    check(not bad:update(video, 10) and bad.state == "failed" and not badSurface.active,
        "Invalid decoder clock fails without selecting or uploading a frame")
end
local absent = fixture()
absent:start(900); video.currentTime = nil
check(not absent:update(video, 10) and absent.error == "decoderClockUnavailable", "Missing native time has no dt fallback")
local getterFailure = fixture()
getterFailure:start(900); video.currentTime, video.timingError = 1, "getter failed"
check(not getterFailure:update(video, 10), "Failed native timing getter ends this decoder test")
video.timingError = nil
local stopped, stoppedSurface = fixture()
stopped:start(900); stopped:update(video, 10)
check(not stopped:update({state="ended"}, 10) and not stoppedSurface.active, "Native video removal removes the cab output")
local rejected, rejectedSurface = fixture()
rejected:start(900); rejected:update(video, 10)
rejectedSurface.reject = true; video.currentTime = 2
check(not rejected:update(video, 10) and rejected.state == "failed" and rejectedSurface.pixels == nil,
    "Upload failure releases its partial surface and drops decode state")

local corruptData = {}
for k,v in pairs(TMSDecodedClipData) do corruptData[k] = v end
corruptData.frames = {}
for i,v in ipairs(TMSDecodedClipData.frames) do corruptData.frames[i] = {hex=v.hex,keyframe=v.keyframe} end
corruptData.frames[2].hex = "0000000700ff00"
local corrupt, corruptSurface = fixture(corruptData)
corrupt:start(900); video.currentTime = 0; corrupt:update(video, 10)
video.currentTime = .1
check(not corrupt:update(video, 10) and corrupt.state == "failed" and not corruptSurface.active,
    "Corrupt packet terminates the decoder session instead of showing an unrelated pattern")
corruptData.frames[1].keyframe = false
local invalid, invalidSurface = fixture(corruptData)
check(not invalid:start(900) and invalidSurface.starts == 0, "Missing initial keyframe fails before GPU work")
local parent = fixture()
check(not parent:start(nil), "An equipped monitor is required")

TMSLog.DEBUG = false
local quiet, quietSurface = fixture()
local previousMessages = messages
quiet:start(900); video.currentTime = 0; quiet:update(video, 10); quiet:stop()
check(messages == previousMessages and quietSurface.uploads == 1, "Quiet logging preserves decode and cleanup")
TMSLog.DEBUG = true
print(string.format("TractorMediaScreen decoded video: %d checks passed (%s)", count, _VERSION))
