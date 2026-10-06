-- Try the bundled test clips only. Online URLs never reach the native decoder.
TMSVideoProbe = {}
TMSVideoProbe.__index = TMSVideoProbe

function TMSVideoProbe.new(video, directory)
    return setmetatable({video = video, directory = directory, failures = {}}, TMSVideoProbe)
end

function TMSVideoProbe:stop()
    self.video:stop()
    self.active, self.failed = false, false
    self.format, self.formats, self.index = nil, nil, nil
    self.failures = {}
end

function TMSVideoProbe:recordFailure()
    local failure = self.video.lastError or {reason = "nativeError", operation = "unknown", detail = self.video.state}
    table.insert(self.failures, {format = self.format, reason = failure.reason,
        operation = failure.operation, detail = failure.detail})
    Logging.warning("[TractorMediaScreen] Video %s failed: %s (%s): %s",
        tostring(self.format), tostring(failure.reason), tostring(failure.operation), tostring(failure.detail))
end

function TMSVideoProbe:nextFormat()
    while self.index < #self.formats do
        self.index = self.index + 1
        self.format = self.formats[self.index]
        Logging.info("[TractorMediaScreen] Video attempt %d/%d: %s; file=%sassets/media/test.%s",
            self.index, #self.formats, self.format, self.directory, self.format)
        if self.video:start(self.directory .. "assets/media/test." .. self.format, 0.25, true) then
            return true
        end
        self:recordFailure()
        if self.video.state == "unavailable" then break end
    end
    self.active, self.failed = false, true
    return false
end

function TMSVideoProbe:start(format)
    if format ~= nil and format ~= "auto" and format ~= "mp4" and format ~= "ogv" and format ~= "webm" then
        return false
    end
    self:stop()
    -- OGV is confirmed playing in the user's FS25 1.24 test; MP4 failed there.
    self.formats = (format == nil or format == "auto") and {"ogv", "webm", "mp4"} or {format}
    self.index, self.active = 0, true
    return self:nextFormat()
end

function TMSVideoProbe:update(dt)
    if not self.active then return end
    local before = self.video.state
    self.video:update(dt)
    if before ~= self.video.state then
        Logging.info("[TractorMediaScreen] Video %s: %s", self.format, self.video.state)
    end
    if self.video.state == "error" or self.video.state == "timeout" or self.video.state == "unavailable" then
        self:recordFailure()
        self:nextFormat()
    elseif self.video.state == "ended" then
        self.active = false
    end
end

function TMSVideoProbe:getFailureSummary()
    local result = {}
    for _, failure in ipairs(self.failures) do
        table.insert(result, string.upper(failure.format) .. ": " .. failure.reason .. " (" .. failure.operation .. ")")
    end
    return table.concat(result, "; ")
end
