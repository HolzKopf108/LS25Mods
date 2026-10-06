-- Read-only inventory. Names do not establish signatures or video texture support.
-- FS25 DataDump confirms a table-valued __index on the mod environment.
-- Only standard Lua table access is used; no discovered function is called.
TMSRuntimeApiReport = {}
TMSRuntimeApiReport.MAX_ENTRIES = 20000
TMSRuntimeApiReport.MAX_TABLES = 32
TMSRuntimeApiReport.MAX_DEPTH = 8
TMSRuntimeApiReport.MAX_NAMES = 256
TMSRuntimeApiReport.MAX_LINE = 550

local controls = {
    "createVideoOverlay", "isVideoOverlayReadyToPlay", "playVideoOverlay",
    "isVideoOverlayPlaying", "updateVideoOverlay", "getVideoOverlayCurrentTime",
    "stopVideoOverlay", "renderOverlay", "createRenderOverlay",
    "createMaterialTextureFromFile", "setMaterialCustomMap",
    "createImageOverlayWithTexture", "setMaterialDiffuseMapFromFile"
}
local filters = {"video", "overlay", "texture", "material", "render", "blit"}

local function relevant(name)
    if type(name) ~= "string" or #name > 96 or not name:match("^[%a_][%w_]*$") then
        return false
    end
    local lower = name:lower()
    for _, word in ipairs(filters) do
        if lower:find(word, 1, true) ~= nil then return true end
    end
    return false
end

-- Inputs are explicit so tests need no simulated GIANTS native handles.
function TMSRuntimeApiReport.collect(environments, knownValues)
    local report = {
        entries = 0, tables = 0, functions = 0, names = {}, controls = {},
        blockedInheritance = 0, cycles = 0, limited = false, missingControlNames = 0
    }
    local visited, selected = {}, {}
    local function scan(environment, depth)
        if type(environment) ~= "table" then return end
        if visited[environment] then
            report.cycles = report.cycles + 1
            return
        end
        if depth > TMSRuntimeApiReport.MAX_DEPTH or report.tables >= TMSRuntimeApiReport.MAX_TABLES then
            report.limited = true
            return
        end
        visited[environment] = true
        report.tables = report.tables + 1
        -- next ignores __pairs and accesses no entry through __index.
        for name, value in next, environment do
            if report.entries >= TMSRuntimeApiReport.MAX_ENTRIES then
                report.limited = true
                break
            end
            report.entries = report.entries + 1
            if type(value) == "function" then
                report.functions = report.functions + 1
                if relevant(name) then selected[name] = true end
            end
        end
        local meta = getmetatable(environment)
        if meta ~= nil and type(meta) ~= "table" then
            report.blockedInheritance = report.blockedInheritance + 1
        elseif type(meta) == "table" then
            local parent = rawget(meta, "__index")
            if type(parent) == "table" then
                scan(parent, depth + 1)
            elseif parent ~= nil then
                -- Do not invoke a functional __index or bypass a protected table.
                report.blockedInheritance = report.blockedInheritance + 1
            end
        end
    end
    for _, environment in ipairs(environments) do scan(environment, 1) end
    for name in next, selected do report.names[#report.names + 1] = name end
    table.sort(report.names)
    report.selected = #report.names
    -- Sort before truncation so bounded output is reproducible for a full scan.
    while #report.names > TMSRuntimeApiReport.MAX_NAMES do
        report.names[#report.names] = nil
        report.limited = true
    end
    for _, name in ipairs(controls) do
        local present = type(rawget(knownValues, name)) == "function"
        local enumerated = selected[name] == true
        report.controls[#report.controls + 1] = {
            name = name, present = present, enumerated = enumerated
        }
        if present and not enumerated then
            report.missingControlNames = report.missingControlNames + 1
        end
    end
    return report
end

function TMSRuntimeApiReport.capture()
    local environments = {}
    local function add(value)
        if type(value) == "table" then environments[#environments + 1] = value end
    end
    add(_G)
    -- Some FS25 environments restrict getfenv. An unavailable route is optional.
    local failures = 0
    if type(getfenv) == "function" then
        -- A numeric stack level inside pcall refers to its C/global frame.
        -- Request this function's environment explicitly to include the mod.
        for _, target in ipairs({0, TMSRuntimeApiReport.capture}) do
            local ok, environment = pcall(getfenv, target)
            if ok and type(environment) == "table" then add(environment)
            else failures = failures + 1 end
        end
    end
    local report = TMSRuntimeApiReport.collect(environments, {
        createVideoOverlay = createVideoOverlay,
        isVideoOverlayReadyToPlay = isVideoOverlayReadyToPlay,
        playVideoOverlay = playVideoOverlay,
        isVideoOverlayPlaying = isVideoOverlayPlaying,
        updateVideoOverlay = updateVideoOverlay,
        getVideoOverlayCurrentTime = getVideoOverlayCurrentTime,
        stopVideoOverlay = stopVideoOverlay,
        renderOverlay = renderOverlay,
        createRenderOverlay = createRenderOverlay,
        createMaterialTextureFromFile = createMaterialTextureFromFile,
        setMaterialCustomMap = setMaterialCustomMap,
        createImageOverlayWithTexture = createImageOverlayWithTexture,
        setMaterialDiffuseMapFromFile = setMaterialDiffuseMapFromFile
    })
    report.environmentFailures = failures
    return report
end

function TMSRuntimeApiReport.write(report, logger)
    local prefix = "[TractorMediaScreen] API inventory "
    local lineCount = 0
    local function emit(text)
        logger(prefix .. text)
        lineCount = lineCount + 1
    end
    emit(string.format("begin: tables=%d entries=%d functions=%d selected=%d shown=%d limited=%s blockedInheritance=%d missingControlNames=%d environmentFailures=%d",
        report.tables, report.entries, report.functions, report.selected, #report.names,
        tostring(report.limited), report.blockedInheritance, report.missingControlNames,
        report.environmentFailures or 0))
    local function list(label, values)
        local text = label
        for _, value in ipairs(values) do
            if #prefix + #text + #value + 2 > TMSRuntimeApiReport.MAX_LINE then
                emit(text)
                text = label
            end
            text = text .. (text == label and "" or ", ") .. value
        end
        if text ~= label then emit(text) end
    end
    list("names: ", report.names)
    local status = {}
    for _, control in ipairs(report.controls) do
        status[#status + 1] = control.name .. "=" .. (control.present and "function" or "unavailable")
            .. (control.enumerated and "/listed" or "/notListed")
    end
    list("controls: ", status)
    emit("end: names only; no native media/render functions called; no signatures or video-to-material support established")
    return lineCount
end
