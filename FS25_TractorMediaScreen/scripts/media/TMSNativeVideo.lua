-- Native FS25 GUI-video probe. It deliberately does not claim a 3D video output.
TMSNativeVideo = {}
local TMSNativeVideo_mt = {__index = TMSNativeVideo}
TMSNativeVideo.REQUIRED = {"createVideoOverlay", "isVideoOverlayReadyToPlay",
    "isVideoOverlayPlaying", "playVideoOverlay", "updateVideoOverlay",
    "stopVideoOverlay", "renderOverlay", "delete"}

function TMSNativeVideo.new(api)
    return setmetatable({api = api, state = "idle", elapsed = 0, id = nil}, TMSNativeVideo_mt)
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
    if id ~= nil then
        -- Release once even when the native playback call itself fails.
        pcall(self.api.stopVideoOverlay, id)
        pcall(self.api.delete, id)
    end
    self.state = state or "idle"
    self.elapsed = 0
end

function TMSNativeVideo:start(filename, volume)
    self:stop()
    if #self:missingFunctions() > 0 then self.state = "unavailable"; return false end
    local ok, id = pcall(self.api.createVideoOverlay, filename, false, volume or 0.25)
    if not ok or id == nil or id == 0 then self.state = "error"; return false end
    self.id, self.state = id, "loading"
    return true
end

function TMSNativeVideo:update(dt)
    if self.id == nil then return end
    self.elapsed = self.elapsed + math.max(0, dt)
    local ok, reason = pcall(function()
        if not self.api.isVideoOverlayReadyToPlay(self.id) then
            if self.elapsed > 15000 then self:stop("timeout") end
            return
        end
        if self.state == "loading" then
            self.api.playVideoOverlay(self.id)
            self.state, self.elapsed = "starting", 0
        end
        if self.api.isVideoOverlayPlaying(self.id) then
            self.state = "playing"
            self.api.updateVideoOverlay(self.id)
        elseif self.state == "playing" then
            self:stop("ended")
        elseif self.elapsed > 5000 then
            self:stop("timeout")
        end
    end)
    if not ok then
        self:stop("error")
        -- No media URL or opaque native error is written to the game log.
        return false
    end
    return true
end

function TMSNativeVideo:draw(x, y, width, height)
    if self.id ~= nil and self.state == "playing" then
        local ok = pcall(self.api.renderOverlay, self.id, x, y, width, height)
        if not ok then self:stop("error") end
    end
end
