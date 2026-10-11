-- A private, flat view of the same material used by the cabin surface.
-- FS25 RenderElement documents the scene, overlay and cleanup sequence:
-- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=480&version=engine
-- FS25 orthographic camera APIs:
-- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=2&function=46&version=engine
-- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=2&function=48&version=engine
TMSPixelPip = {}
TMSPixelPip.__index = TMSPixelPip
TMSPixelPip.REQUIRED = {"loadI3DFile", "getNumOfChildren", "getChildAt", "getRootNode",
    "link", "setVisibility", "createCamera", "setTranslation", "setRotation",
    "setIsOrthographic", "setOrthographicHeight", "createRenderOverlay",
    "updateRenderOverlay", "renderOverlay", "setMaterial", "delete"}

local function integer(value, minimum)
    return type(value) == "number" and value == value and value < math.huge
        and value >= minimum and value % 1 == 0
end

local function detail(value)
    return tostring(value):gsub("[%c]", " "):sub(1, 240)
end

function TMSPixelPip.new(directory, api)
    return setmetatable({directory = directory, api = api or {}, renderCount = 0}, TMSPixelPip)
end

function TMSPixelPip:release()
    local failure
    -- The overlay refers to the scene. The scene owns its linked camera.
    -- Keep an unlinked camera separately so a partial setup can also be freed.
    for _, key in ipairs({"overlay", "scene", "orphanCamera"}) do
        local id = self[key]
        self[key] = nil
        if id ~= nil then
            local ok, reason = pcall(self.api.delete, id)
            if not ok and failure == nil then failure = reason end
        end
    end
    self.camera, self.node, self.material, self.lastFrame = nil, nil, nil, nil
    return failure
end

function TMSPixelPip:fail(reason)
    self:release()
    if self.error == nil then
        self.error = detail(reason)
        Logging.warning("[TractorMediaScreen] Pixel PiP unavailable: %s; cabin output continues", self.error)
    end
    return false
end

function TMSPixelPip:stop()
    local failure = self:release()
    self.error, self.renderCount = nil, 0
    if failure ~= nil then self:fail(failure) end
end

function TMSPixelPip:setMaterial(material)
    if self.error ~= nil then return false end
    if not integer(material, 1) then return self:fail("invalid material entity") end
    -- Hidden PiP has no scene yet. The next prepare receives the latest material.
    if self.node == nil or material == self.material then return true end
    local ok, reason = pcall(self.api.setMaterial, self.node, material, 0)
    if not ok then return self:fail(reason) end
    self.material, self.lastFrame = material, nil
    return true
end

function TMSPixelPip:create(material)
    local api = self.api
    for _, name in ipairs(self.REQUIRED) do
        if type(api[name]) ~= "function" then error("missing API: " .. name) end
    end
    if not integer(api.atmosphereQualityOff, 0) then error("AtmosphereQuality.OFF unavailable") end
    local scene = api.loadI3DFile(self.directory .. "assets/pixelProbe/screen.i3d", false, false, false)
    if not integer(scene, 1) then error("PiP scene load failed") end
    self.scene = scene
    api.setVisibility(scene, false)
    if api.getNumOfChildren(scene) ~= 1 then error("unexpected PiP model") end
    self.node = api.getChildAt(scene, 0)
    if not integer(self.node, 1) then error("PiP surface unavailable") end
    api.link(api.getRootNode(), scene)
    api.setMaterial(self.node, material, 0)
    self.material = material

    local camera = api.createCamera("TMSPixelPip", math.rad(60), 0.01, 2)
    if not integer(camera, 1) then error("PiP camera creation failed") end
    self.camera, self.orphanCamera = camera, camera
    api.link(scene, camera)
    self.orphanCamera = nil
    -- The existing quad faces +Z and measures 0.256 x 0.144 metres.
    -- A camera at +Z with no rotation looks along -Z; no world camera changes.
    api.setTranslation(camera, 0, 0, 1)
    api.setRotation(camera, 0, 0, 0)
    api.setIsOrthographic(camera, true)
    api.setOrthographicHeight(camera, 0.144)
    local overlay = api.createRenderOverlay(scene, camera, 16 / 9, 512, 288,
        true, 255, 67108864, false, 0, false, 0, false, api.atmosphereQualityOff)
    if not integer(overlay, 1) then error("PiP overlay creation failed") end
    self.overlay = overlay
end

function TMSPixelPip:prepare(material, frame)
    if self.error ~= nil then return false end
    if not integer(material, 1) or not integer(frame, 0) then return self:fail("invalid material or frame") end
    local ok, reason = pcall(function()
        if self.scene == nil then self:create(material) end
        if not self:setMaterial(material) then return end
        -- Both surfaces share the material and its current texture buffer.
        -- Call from the update phase only while PiP is visible, matching
        -- RenderElement. Drawing itself never changes the off-screen scene.
        if self.lastFrame ~= frame then
            self.api.updateRenderOverlay(self.overlay)
            self.lastFrame, self.renderCount = frame, self.renderCount + 1
            if self.renderCount == 1 then
                Logging.info("[TractorMediaScreen] Pixel PiP first render submitted: 512x288; shared cabin material; frame=%d; verify visible output", frame)
            end
        end
    end)
    if not ok then return self:fail(reason) end
    return self.error == nil
end

function TMSPixelPip:draw(material, frame, x, y, width, height)
    if self.error ~= nil or self.overlay == nil or material ~= self.material or frame ~= self.lastFrame then
        return false
    end
    local ok, reason = pcall(self.api.renderOverlay, self.overlay, x, y, width, height)
    if not ok then return self:fail(reason) end
    return true
end
