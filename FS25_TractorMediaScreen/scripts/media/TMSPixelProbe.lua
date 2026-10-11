-- Experimental CPU pixels -> texture buffer -> material, never a video decoder.
-- Constructor argument types were inspected in GE 10.0.1, not run in FS25 yet.
TMSPixelProbe = {}
TMSPixelProbe.__index = TMSPixelProbe
TMSPixelProbe.WIDTH, TMSPixelProbe.HEIGHT = 32, 18
TMSPixelProbe.INTERVAL, TMSPixelProbe.DURATION = 100, 20000

function TMSPixelProbe.new(directory, api)
    return setmetatable({directory = directory, api = api, state = "idle", serial = 0}, TMSPixelProbe)
end

function TMSPixelProbe.pixels(frame)
    local data, width, height = {}, TMSPixelProbe.WIDTH, TMSPixelProbe.HEIGHT
    local bar = frame % width
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b = x / (width - 1), y / (height - 1), 0.08
            if x == bar or x == (bar + 1) % width then r, g, b = 1, 1, 1 end
            -- Four fixed corners make orientation observable from inside the cab.
            if x < 2 and y < 2 then r, g, b = 1, 0, 0 end
            if x >= width - 2 and y < 2 then r, g, b = 0, 1, 0 end
            if x < 2 and y >= height - 2 then r, g, b = 0, 0, 1 end
            if x >= width - 2 and y >= height - 2 then r, g, b = 1, 1, 0 end
            local i = #data
            data[i+1], data[i+2], data[i+3], data[i+4] = r, g, b, 1
        end
    end
    return data
end

function TMSPixelProbe:stop(reason)
    local wasActive = self.active
    self.active = false
    -- Remove the material's owner before releasing its last texture entity.
    for _, key in ipairs({"root", "pendingTexture", "texture"}) do
        local id = self[key]
        self[key] = nil
        if id ~= nil then
            local ok, detail = pcall(self.api.delete, id)
            if not ok then Logging.warning("[TractorMediaScreen] Pixel probe cleanup failed: %s", tostring(detail)) end
        end
    end
    self.node, self.material, self.parent = nil, nil, nil
    self.state = reason or "idle"
    if wasActive then
        Logging.info("[TractorMediaScreen] Pixel probe stopped: reason=%s uploads=%d; visual result requires player confirmation",
            self.state, self.uploads or 0)
    end
end

function TMSPixelProbe:fail(reason)
    self:stop("failed")
    self.error = tostring(reason)
    Logging.warning("[TractorMediaScreen] Pixel probe failed: %s", self.error)
    return false
end

function TMSPixelProbe:upload(frame)
    local api = self.api
    -- This allocates one immutable buffer per displayed frame. It does not
    -- retain a movie or assume an undocumented in-place texture upload API.
    local texture = api.createTextureBuffer("TMSPixelProbe_" .. self.serial .. "_" .. frame,
        api.format, TMSPixelProbe.pixels(frame))
    if type(texture) ~= "number" or not (texture > 0) or texture == math.huge or texture % 1 ~= 0 then
        error("texture buffer creation returned no entity")
    end
    self.pendingTexture = texture
    local material = api.setMaterialCustomMap(self.material or api.getMaterial(self.node, 0),
        "tmsPixels", texture, self.material ~= nil)
    if type(material) ~= "number" or not (material > 0) or material == math.huge or material % 1 ~= 0 then
        error("custom map assignment returned no material")
    end
    api.setMaterial(self.node, material, 0)
    self.material = material
    if self.texture ~= nil then api.delete(self.texture) end
    self.texture, self.pendingTexture = texture, nil
    self.frame, self.uploads = frame, self.uploads + 1
end

function TMSPixelProbe:start(parent)
    self:stop()
    self.error = nil
    local api = self.api
    for _, name in ipairs({"createTextureBuffer", "setMaterialCustomMap", "getMaterial", "setMaterial",
        "loadI3DFile", "getNumOfChildren", "getChildAt", "link", "setVisibility", "delete"}) do
        if type(api[name]) ~= "function" then return self:fail("missing API: " .. name) end
    end
    if type(api.format) ~= "number" or api.format < 0 or api.format % 1 ~= 0 then
        return self:fail("TextureFormat.R32G32B32A32_FLOAT unavailable")
    end
    if parent == nil or parent == 0 then return self:fail("monitor not attached") end
    self.serial, self.elapsed, self.frame, self.uploads = self.serial + 1, 0, nil, 0
    Logging.info("[TractorMediaScreen] Pixel probe begin: 32x18 RGBA float, 10 uploads/s, 20s; format=%s; no image files or decoder",
        tostring(api.format))
    local ok, reason = pcall(function()
        local root = api.loadI3DFile(self.directory .. "assets/pixelProbe/screen.i3d", false, false, false)
        if root == nil or root == 0 then error("probe I3D load failed") end
        self.root = root
        api.setVisibility(root, false)
        if api.getNumOfChildren(root) ~= 1 then error("unexpected probe model") end
        self.node = api.getChildAt(root, 0)
        self:upload(0)
        api.link(parent, root)
        self.parent = parent
        api.setVisibility(root, true)
    end)
    if not ok then return self:fail(reason) end
    self.active, self.state = true, "running"
    Logging.info("[TractorMediaScreen] Pixel probe first buffer submitted to material; not a visual success check")
    return true
end

function TMSPixelProbe:update(dt)
    if not self.active then return end
    if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt == math.huge then return end
    self.elapsed = self.elapsed + dt
    if self.elapsed >= TMSPixelProbe.DURATION then self:stop("completed"); return end
    local frame = math.floor(self.elapsed / TMSPixelProbe.INTERVAL)
    if frame == self.frame then return end
    -- Skip stale frames after a slow update; never enqueue a catch-up burst.
    local ok, reason = pcall(self.upload, self, frame)
    if not ok then self:fail(reason) end
end
