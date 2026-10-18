-- Bounded HUD raster for the 32x18 probe using its uploaded CPU pixels.
-- RenderOverlay was black in FS25 1.24 despite ready=true. This bypasses that
-- unresolved path; it is NOT a high-resolution video sink.
-- FS25 Overlay documents image overlays, tint multiplication and HUD drawing:
-- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=474&version=engine
TMSPixelPip = {}
TMSPixelPip.__index = TMSPixelPip
TMSPixelPip.REQUIRED = {"createImageOverlay", "renderOverlay", "setOverlayUVs", "setOverlayColor", "delete"}
TMSPixelPip.MAX_WIDTH, TMSPixelPip.MAX_HEIGHT = 32, 18

local function integer(value, minimum)
    return type(value) == "number" and value == value and value < math.huge
        and value >= minimum and value % 1 == 0
end

local function detail(value)
    return tostring(value):gsub("[%c]", " "):sub(1, 240)
end

function TMSPixelPip.new(directory, api)
    return setmetatable({directory = directory, api = api or {}, preparedCount = 0,
        drawCount = 0, cellDrawCount = 0, skippedDrawCount = 0}, TMSPixelPip)
end

function TMSPixelPip:report(stage)
    if not TMSLog.DEBUG then return end
    local ready = "unavailable"
    if self.overlay ~= nil and type(self.api.getIsOverlayReady) == "function" then
        local ok, value = pcall(self.api.getIsOverlayReady, self.overlay)
        ready = ok and tostring(value) or "readback-error:" .. detail(value)
    end
    TMSLog.info("[TractorMediaScreen] Pixel PiP %s: mode=cpu-raster source=cabin-upload frame=%s size=%sx%s prepared=%d draws=%d cells=%d skipped=%d overlay=%s ready=%s",
        stage, tostring(self.frame), tostring(self.width), tostring(self.height), self.preparedCount,
        self.drawCount, self.cellDrawCount, self.skippedDrawCount, tostring(self.overlay), ready)
end

function TMSPixelPip:release()
    local overlay = self.overlay
    self.overlay, self.pixels, self.frame, self.width, self.height = nil, nil, nil, nil, nil
    -- Only this overlay is owned here. Never mutate cabin geometry/materials.
    if overlay ~= nil then
        local ok, reason = pcall(self.api.delete, overlay)
        if not ok then return reason end
    end
end

function TMSPixelPip:fail(reason)
    self:release()
    if self.error == nil then
        self.error = detail(reason)
        TMSLog.warning("[TractorMediaScreen] Pixel PiP unavailable: %s; cabin output continues", self.error)
    end
    return false
end

function TMSPixelPip:stop()
    if self.overlay ~= nil then self:report("stop") end
    local failure = self:release()
    self.error, self.preparedCount, self.drawCount, self.cellDrawCount, self.skippedDrawCount = nil, 0, 0, 0, 0
    self.lastReportFrame = nil
    if failure ~= nil then self:fail(failure) end
end

function TMSPixelPip:prepare(pixels, width, height, frame)
    if self.error ~= nil then return false end
    if not integer(frame, 0) or not integer(width, 1) or not integer(height, 1)
        or width > self.MAX_WIDTH or height > self.MAX_HEIGHT
        or type(pixels) ~= "table" or #pixels ~= width * height * 4 then
        return self:fail("invalid or oversized CPU raster (maximum 32x18 RGBA)")
    end
    if pixels == self.pixels and frame == self.frame and width == self.width and height == self.height then return true end
    -- Probe replaces, never mutates, its table after each successful upload.
    -- Keep that exact table; do not regenerate the animation or run another clock.
    for i = 1, #pixels do
        local v = pixels[i]
        if type(v) ~= "number" or not (v >= 0 and v <= 1) then return self:fail("invalid RGBA component") end
    end
    local ok, reason = pcall(function()
        if self.overlay == nil then
            for _, name in ipairs(self.REQUIRED) do
                if type(self.api[name]) ~= "function" then error("missing API: " .. name) end
            end
            local overlay = self.api.createImageOverlay(self.directory .. "assets/monitor/white.dds")
            if not integer(overlay, 1) then error("PiP image overlay creation failed") end
            self.overlay = overlay
        end
        self.pixels, self.width, self.height, self.frame = pixels, width, height, frame
        self.preparedCount = self.preparedCount + 1
        if self.lastReportFrame == nil or frame - self.lastReportFrame >= 50 then
            self:report("update")
            self.lastReportFrame = frame
        end
    end)
    if not ok then return self:fail(reason) end
    return true
end

function TMSPixelPip:draw(frame, x, y, width, height)
    if self.error ~= nil or self.overlay == nil or frame ~= self.frame then
        self.skippedDrawCount = self.skippedDrawCount + 1
        return false
    end
    local ok, reason = pcall(function()
        local api, overlay, pixels = self.api, self.overlay, self.pixels
        api.setOverlayUVs(overlay, 0, 0, 0, 1, 1, 0, 1, 1)
        -- Both the buffer shader and HUD use bottom-left row zero.
        -- Shared edge calculations avoid gaps or overlaps between cells.
        for row = 0, self.height - 1 do
            local bottom = y + row * height / self.height
            local top = y + (row + 1) * height / self.height
            for column = 0, self.width - 1 do
                local i = (row * self.width + column) * 4
                local left = x + column * width / self.width
                local right = x + (column + 1) * width / self.width
                api.setOverlayColor(overlay, pixels[i+1], pixels[i+2], pixels[i+3], pixels[i+4])
                api.renderOverlay(overlay, left, bottom, right - left, top - bottom)
                self.cellDrawCount = self.cellDrawCount + 1
            end
        end
        api.setOverlayColor(overlay, 1, 1, 1, 1)
    end)
    if not ok then return self:fail(reason) end
    self.drawCount = self.drawCount + 1
    if self.drawCount == 1 then
        self:report("first draw")
        TMSLog.info("[TractorMediaScreen] Pixel PiP rectangle: x=%.4f y=%.4f width=%.4f height=%.4f; maxCellsPerDraw=576; submitted calls are not a visual confirmation",
            x, y, width, height)
    end
    return true
end
