-- A bounded in-mod video decoder driven by the existing native OGV clock.
-- QTRLE supplies cabin pixels; the OGV player supplies optional PiP and audio.
-- No external process, prepared DDS sequence or second playback clock.
TMSDecodedVideo = {}
TMSDecodedVideo.__index = TMSDecodedVideo
TMSDecodedVideo.DURATION = 20000
TMSDecodedVideo.MAX_PACKETS = 10

local function integer(value, low, high)
    return type(value) == "number" and value == value and value >= low
        and value <= high and value % 1 == 0
end

-- Byte samples are sRGB. The cabin buffer shader consumes linear RGB floats.
local linear = {}
for byte = 0, 255 do
    local c = byte / 255
    linear[byte] = c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end

function TMSDecodedVideo.toPixels(rgb, width, height)
    if type(rgb) ~= "string" or #rgb ~= width * height * 3 then return nil end
    local pixels = {}
    -- Codec rows start at the top; the cabin shader's row zero is at the bottom.
    for y = height - 1, 0, -1 do
        for x = 0, width - 1 do
            local pos = (y * width + x) * 3 + 1
            local r, g, b = rgb:byte(pos, pos + 2)
            local i = #pixels
            pixels[i+1], pixels[i+2], pixels[i+3], pixels[i+4] = linear[r], linear[g], linear[b], 1
        end
    end
    return pixels
end

function TMSDecodedVideo.new(data, surface)
    return setmetatable({data = data, surface = surface, state = "idle"}, TMSDecodedVideo)
end

function TMSDecodedVideo:stop()
    if self.surface ~= nil then self.surface:stop() end
    self.decoder, self.parent, self.frame, self.decodedFrame = nil, nil, nil, nil
    self.elapsed, self.decodedPackets, self.lastReport = 0, 0, nil
    self.state, self.error = "idle", nil
end

function TMSDecodedVideo:fail(reason)
    self:stop()
    self.state, self.error = "failed", tostring(reason):gsub("[%c]", " "):sub(1, 160)
    TMSLog.warning("[TractorMediaScreen] In-mod decoder failed: %s", self.error)
    return false
end

function TMSDecodedVideo:validate()
    local data = self.data
    if type(data) ~= "table" or data.codec ~= "qtrle-rgb24" or data.width ~= 32 or data.height ~= 18
        or not integer(data.fps, 1, 10) or not integer(data.duration, 1, 10)
        or type(data.frames) ~= "table" or #data.frames ~= data.fps * data.duration then
        return false, "invalidClipMetadata"
    end
    local sinceKey = self.MAX_PACKETS
    for _, packet in ipairs(data.frames) do
        if type(packet) ~= "table" or type(packet.hex) ~= "string"
            or #packet.hex > 8192 or #packet.hex < 14 or #packet.hex % 2 ~= 0
            or packet.hex:find("[^%da-fA-F]") or type(packet.keyframe) ~= "boolean" then
            return false, "invalidClipPacket"
        end
        sinceKey = packet.keyframe and 1 or sinceKey + 1
        if sinceKey > self.MAX_PACKETS then return false, "keyframeGapTooLarge" end
    end
    return true
end

function TMSDecodedVideo:start(parent)
    self:stop()
    if not integer(parent, 1, math.huge) then return self:fail("monitorNotAttached") end
    local valid, reason = self:validate()
    if not valid then return self:fail(reason) end
    local decoder, decoderReason = TMSQtrleDecoder.new(self.data.width, self.data.height)
    if decoder == nil then return self:fail(decoderReason) end
    self.decoder, self.parent, self.state = decoder, parent, "waiting"
    TMSLog.info("[TractorMediaScreen] In-mod decoder begin: qtrle-rgb24 %dx%d %dfps; native OGV clock/audio/PiP; no helper process or DDS frames; limit=20s",
        self.data.width, self.data.height, self.data.fps)
    return true
end

function TMSDecodedVideo:update(video, dt)
    if self.state == "idle" or self.state == "failed" or self.state == "completed" then return false end
    if video == nil or video.id == nil then return self:fail("nativePlaybackUnavailable") end
    if video.state ~= "playing" then
        if video.state ~= "loading" and video.state ~= "starting" then return self:fail("nativePlaybackStopped") end
        self.state = "waiting"
        return true
    end
    local seconds = video.currentTime
    if video.timingError ~= nil or type(seconds) ~= "number" or seconds ~= seconds
        or seconds < 0 or seconds == math.huge then return self:fail("decoderClockUnavailable") end
    if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt == math.huge then return self:fail("invalidUpdateTime") end
    -- dt limits this experiment only. It NEVER selects a video picture.
    self.elapsed = self.elapsed + dt
    if self.elapsed >= self.DURATION then
        TMSLog.info("[TractorMediaScreen] In-mod decoder completed: packets=%d uploads=%d",
            self.decodedPackets, self.surface.uploads or 0)
        self:stop()
        self.state = "completed"
        return true
    end
    local target = math.min(#self.data.frames - 1, math.floor((seconds % self.data.duration) * self.data.fps))
    if target ~= self.frame then
        local ok, reason = pcall(function()
            -- Seek from a nearby keyframe after a loop or a slow game update.
            -- This prevents an ever-growing decode catch-up queue.
            if self.decodedFrame == nil or target <= self.decodedFrame
                or target - self.decodedFrame > self.MAX_PACKETS then
                local first = target
                while first > 0 and not self.data.frames[first+1].keyframe do first = first - 1 end
                self.decoder:reset()
                self.decodedFrame = first - 1
            end
            local rgb
            for frame = self.decodedFrame + 1, target do
                local decodeReason
                rgb, decodeReason = self.decoder:decode(self.data.frames[frame+1].hex)
                if rgb == nil then error(decodeReason) end
                self.decodedPackets = self.decodedPackets + 1
            end
            local pixels = self.toPixels(rgb, self.data.width, self.data.height)
            if pixels == nil then error("invalidDecodedFrameSize") end
            if not self.surface.active then
                if not self.surface:start(self.parent, pixels, target) then error(self.surface.error or "surfaceStartFailed") end
            else
                self.surface:upload(target, pixels)
            end
            self.frame, self.decodedFrame = target, target
        end)
        if not ok then return self:fail(reason) end
    end
    self.state = "playing"
    if self.lastReport == nil or self.elapsed - self.lastReport >= 5000 then
        TMSLog.info("[TractorMediaScreen] In-mod decoder update: frame=%d time=%.3f packets=%d uploads=%d; cabin=decoded-rgb; PiP/audio=native-ogv",
            self.frame, seconds, self.decodedPackets, self.surface.uploads or 0)
        self.lastReport = self.elapsed
    end
    return true
end
