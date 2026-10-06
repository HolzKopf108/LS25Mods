-- Prepared frames of the bundled OGV only, synchronized to its decoder clock.
-- This is a 3D playback test, NOT a live VideoOverlay-to-material bridge.
-- Online media needs a separate, still unproven texture source.
TMSCabinVideo = {}
TMSCabinVideo.__index = TMSCabinVideo

function TMSCabinVideo.new(directory, data, api)
    return setmetatable({directory = directory, data = data, api = api, state = "idle"}, TMSCabinVideo)
end

function TMSCabinVideo:clear()
    if self.vehicle ~= nil and self.frame ~= nil then self.api.restore(self.vehicle) end
    self.vehicle, self.videoId, self.frame = nil, nil, nil
    self.state, self.failed, self.warned, self.started = "idle", false, false, false
end

function TMSCabinVideo:unavailable(reason)
    if self.frame ~= nil then
        self.api.restore(self.vehicle)
        self.frame = nil
    end
    self.state = reason
    if not self.warned then
        Logging.warning("[TractorMediaScreen] Cabin clip unavailable: %s (HUD playback may continue)", reason)
        self.warned = true
    end
end

function TMSCabinVideo:update(vehicle, video, format)
    if vehicle == nil or video == nil or video.id == nil then self:clear(); return end
    if vehicle ~= self.vehicle or video.id ~= self.videoId then
        self:clear()
        self.vehicle, self.videoId = vehicle, video.id
    end
    if self.failed then return end
    if video.state ~= "playing" then self.state = "waiting"; return end
    -- Frames come from exactly this source; other codecs can differ in timing.
    if format ~= "ogv" then self:unavailable("unsupportedTestFormat"); return end
    local seconds = video.currentTime
    if video.timingError ~= nil or type(seconds) ~= "number" or seconds ~= seconds
        or seconds < 0 or seconds == math.huge then
        self:unavailable("decoderClockUnavailable")
        return
    end
    local frame = math.min(self.data.frameCount,
        math.floor((seconds % self.data.duration) * self.data.fps) + 1)
    if frame ~= self.frame then
        if not self.api.setTexture(vehicle, self.directory .. self.data.frames[frame]) then
            self.failed = true
            self:unavailable("materialUpdateFailed")
            return
        end
        self.frame = frame
    end
    self.state = "frames"
    if not self.started then
        Logging.info("[TractorMediaScreen] Cabin clip active: prepared OGV frames, %dfps, %dx%d, decoderTime=%.3fs",
            self.data.fps, self.data.width, self.data.height, seconds)
        self.started = true
    end
end
