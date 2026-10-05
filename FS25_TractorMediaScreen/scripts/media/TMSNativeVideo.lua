-- Native FS25 GUI-video probe. This has no 3D texture output.
-- Playback order follows FS25 VideoElement (Script v1.20.0.0): wait for
-- readiness, request playback once, then update only while playing.
-- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=506&version=script
TMSNativeVideo = {}
local TMSNativeVideo_mt = {__index = TMSNativeVideo}
TMSNativeVideo.REQUIRED = {"createVideoOverlay", "isVideoOverlayReadyToPlay",
    "isVideoOverlayPlaying", "playVideoOverlay", "updateVideoOverlay",
    "stopVideoOverlay", "renderOverlay", "delete"}
TMSNativeVideo.LOAD_TIMEOUT = 15000
TMSNativeVideo.START_TIMEOUT = 5000

local function diagnosticText(value)
    -- Keep native diagnostics bounded and on one log line. No source URL is
    -- accepted by this backend; online links belong to the provider layer.
    return tostring(value):gsub("[%c]", " "):sub(1, 240)
end

function TMSNativeVideo.new(api)
    return setmetatable({api = api or {}, state = "idle", elapsed = 0,
        readyWait = 0, id = nil}, TMSNativeVideo_mt)
end

function TMSNativeVideo:missingFunctions()
    local missing = {}
    for _, name in ipairs(self.REQUIRED) do
        if type(self.api[name]) ~= "function" then table.insert(missing, name) end
    end
    return missing
end

function TMSNativeVideo:stop(state)
    local id = self.id
    self.id = nil
    self.cleanupError = nil
    if id ~= nil then
        -- Release exactly once, including when stopVideoOverlay itself fails.
        for _, operation in ipairs({"stopVideoOverlay", "delete"}) do
            local ok, detail = pcall(self.api[operation], id)
            if not ok then
                self.cleanupError = {operation = operation, detail = diagnosticText(detail)}
            end
        end
    end
    self.state = state or "idle"
    self.elapsed, self.readyWait = 0, 0
    self.currentTime, self.timingError, self.lastError = nil, nil, nil
end

function TMSNativeVideo:fail(reason, operation, detail, state)
    self:stop(state or "error")
    self.lastError = {reason = reason, operation = operation, detail = diagnosticText(detail)}
    return false
end

function TMSNativeVideo:call(operation, ...)
    local ok, value = pcall(self.api[operation], ...)
    if not ok then self:fail("nativeError", operation, value) end
    return ok, value
end

function TMSNativeVideo:start(filename, volume, looping)
    self:stop()
    local missing = self:missingFunctions()
    if #missing > 0 then
        return self:fail("missingApi", "capabilities", table.concat(missing, ","), "unavailable")
    end
    if type(filename) ~= "string" or filename == "" or filename:find("[%c]")
        or filename:match("^%a[%w+.-]*://") then
        return self:fail("invalidSource", "source", "A local video filename is required")
    end
    if type(self.api.fileExists) == "function" then
        local ok, exists = self:call("fileExists", filename)
        if not ok then return false end
        if not exists then return self:fail("missingFile", "fileExists", "Test video file is missing") end
    end
    volume = tonumber(volume) or 0.25
    if volume ~= volume then volume = 0.25 end
    volume = math.max(0, math.min(1, volume))
    local ok, id = pcall(self.api.createVideoOverlay, filename, looping == true, volume)
    if not ok then return self:fail("createFailed", "createVideoOverlay", id) end
    if type(id) ~= "number" or id <= 0 or id ~= id then
        return self:fail("createFailed", "createVideoOverlay", "Invalid overlay handle: " .. tostring(id))
    end
    self.id, self.state = id, "loading"
    return true
end

function TMSNativeVideo:update(dt)
    if self.id == nil then return end
    dt = math.max(0, dt)
    self.elapsed = self.elapsed + dt
    local ok, ready = self:call("isVideoOverlayReadyToPlay", self.id)
    if not ok then return false end
    if not ready then
        self.readyWait = self.readyWait + dt
        if self.readyWait > self.LOAD_TIMEOUT then
            return self:fail(self.state == "loading" and "loadingTimeout" or "readyTimeout",
                "isVideoOverlayReadyToPlay", "Decoder did not become ready within 15 seconds", "timeout")
        end
        return true
    end
    self.readyWait = 0
    if self.state == "loading" then
        if not self:call("playVideoOverlay", self.id) then return false end
        self.state, self.elapsed = "starting", 0
    end
    local playing
    ok, playing = self:call("isVideoOverlayPlaying", self.id)
    if not ok then return false end
    if playing then
        if self.state ~= "playing" then self.elapsed = 0 end
        self.state = "playing"
        if not self:call("updateVideoOverlay", self.id) then return false end
        -- Optional FS25 VideoElement API for diagnostics only. A clock failure
        -- must not stop an otherwise working native picture/audio stream.
        if type(self.api.getVideoOverlayCurrentTime) == "function" and self.timingError == nil then
            local clockOk, currentTime = pcall(self.api.getVideoOverlayCurrentTime, self.id)
            if clockOk then
                if type(currentTime) == "number" then self.currentTime = currentTime end
            else
                self.timingError = diagnosticText(currentTime)
            end
        end
    elseif self.state == "playing" then
        self:stop("ended")
    elseif self.elapsed > self.START_TIMEOUT then
        return self:fail("startTimeout", "isVideoOverlayPlaying",
            "Decoder did not start playback within 5 seconds", "timeout")
    end
    return true
end

function TMSNativeVideo:draw(x, y, width, height)
    if self.id ~= nil and self.state == "playing" then
        return self:call("renderOverlay", self.id, x, y, width, height)
    end
    return false
end
