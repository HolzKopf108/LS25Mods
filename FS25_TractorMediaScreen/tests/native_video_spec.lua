-- Simulated decoder failures, not a codec or FS25 runtime test.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/media/TMSNativeVideo.lua")
local count = 0
local function check(condition, message)
    assert(condition, message)
    count = count + 1
end

local function fixture()
    local env = {ready = false, playing = false, autoStart = true,
        created = 0, played = 0, stopped = 0, deleted = 0, updated = 0, clockReads = 0}
    local api = {
        fileExists = function() return true end,
        createVideoOverlay = function(filename, looping, volume)
            env.created = env.created + 1
            env.looping, env.volume = looping, volume
            return 123
        end,
        isVideoOverlayReadyToPlay = function() return env.ready end,
        playVideoOverlay = function()
            env.played = env.played + 1
            env.playing = env.autoStart
        end,
        isVideoOverlayPlaying = function() return env.playing end,
        updateVideoOverlay = function() env.updated = env.updated + 1 end,
        getVideoOverlayCurrentTime = function()
            env.clockReads = env.clockReads + 1
            return 1.5
        end,
        renderOverlay = function() end,
        stopVideoOverlay = function() env.stopped = env.stopped + 1; env.playing = false end,
        delete = function() env.deleted = env.deleted + 1 end
    }
    return TMSNativeVideo.new(api), env, api
end

local video, env, api = fixture()
check(video:start("test.mp4", 0.4, true) and env.looping == true and env.volume == 0.4,
    "Explicit looping uses documented createVideoOverlay argument")
video:update(16)
check(env.played == 0 and env.updated == 0 and video.state == "loading",
    "No premature play/update while the decoder is loading")
env.ready = true
video:update(16)
video:update(16)
check(env.played == 1 and env.updated == 2 and video.state == "playing" and video.currentTime == 1.5,
    "Start exactly once, update every playing frame and expose optional seconds")
env.ready = false
video:update(100)
env.ready = true
video:update(20000)
env.ready = false
video:update(100)
check(video.id ~= nil and video.lastError == nil,
    "Temporary lost readiness after a long-running clip does not use total elapsed time as timeout")
video:update(15000)
check(video.state == "timeout" and video.lastError.reason == "readyTimeout"
    and env.deleted == 1, "Sustained lost readiness is bounded and diagnosed")
video:stop()
check(video.lastError == nil and env.deleted == 1, "Explicit stop clears diagnostics without double deletion")

video, env, api = fixture()
check(video:start("test.ogv"), "Loading test starts")
video:update(15001)
check(video.lastError.reason == "loadingTimeout" and video.lastError.operation == "isVideoOverlayReadyToPlay"
    and video.id == nil, "Loading timeout explains which stage failed")
check(video:start("test.webm") and video.lastError == nil, "A retry clears the previous error")
env.ready, env.autoStart = true, false
video:update(16)
video:update(5001)
check(video.lastError.reason == "startTimeout" and env.played == 1 and env.deleted == 2,
    "Ready decoder that never plays has a distinct start timeout and only one play request")

for _, invalid in ipairs({false, 0, -1, "123"}) do
    video, env, api = fixture()
    api.createVideoOverlay = function() return invalid end
    check(not video:start("test.mp4") and video.lastError.reason == "createFailed" and video.id == nil,
        "Invalid native handles are never used")
end
video, env, api = fixture()
api.createVideoOverlay = function() return nil end
check(not video:start("test.mp4") and video.lastError.reason == "createFailed", "Nil native handle is a creation failure")
api.createVideoOverlay = nil
check(not video:start("test.mp4") and video.state == "unavailable"
    and video.lastError.detail:find("createVideoOverlay", 1, true), "Missing API is explicit")

video, env, api = fixture()
api.fileExists = function() return false end
check(not video:start("test.mp4") and video.lastError.reason == "missingFile" and env.created == 0,
    "Missing bundled source fails before native allocation")
api.fileExists = nil
check(video:start("test.mp4"), "fileExists remains optional for embedders")
video:stop()
for _, source in ipairs({"", "https://youtube.com/watch?v=abcdefghijk", "test\000.mp4"}) do
    local before = env.created
    check(not video:start(source) and video.lastError.reason == "invalidSource" and env.created == before,
        "Invalid filenames and provider URLs never reach the local native decoder")
end

for _, operation in ipairs({"fileExists", "createVideoOverlay", "isVideoOverlayReadyToPlay",
    "playVideoOverlay", "isVideoOverlayPlaying", "updateVideoOverlay", "renderOverlay"}) do
    video, env, api = fixture()
    api[operation] = function() error("native failure\nsecond line") end
    env.ready = true
    video:start("test.mp4")
    video:update(16)
    video:draw(0, 0, 0.3, 0.3)
    local expectedDeletes = operation == "createVideoOverlay" or operation == "fileExists"
    expectedDeletes = expectedDeletes and 0 or 1
    check(video.state == "error" and video.id == nil and video.lastError.operation == operation
        and not video.lastError.detail:find("\n", 1, true) and env.deleted == expectedDeletes,
        "Native failures report the exact operation and release allocated handles: " .. operation)
end

video, env, api = fixture()
env.ready = true
api.getVideoOverlayCurrentTime = function()
    env.clockReads = env.clockReads + 1
    error("optional clock unavailable")
end
video:start("test.mp4")
video:update(16)
video:update(16)
check(video.state == "playing" and video.lastError == nil and video.timingError ~= nil and env.clockReads == 1,
    "Optional diagnostic clock failure neither interrupts playback nor repeats each frame")
api.stopVideoOverlay = function() error("stop failed") end
video:stop()
check(video.id == nil and env.deleted == 1 and video.cleanupError.operation == "stopVideoOverlay",
    "Delete still runs when native stop fails")

print(string.format("Native video: %d checks passed (%s)", count, _VERSION))
