-- Table traversal and reporting checks, not a native FS25 API/renderer test.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/media/TMSRuntimeApiReport.lua")
local count = 0
local function check(condition, message)
    assert(condition, message)
    count = count + 1
end
local calls = 0
local function forbidden()
    calls = calls + 1
    error("Inventory must not call functions")
end
local shared = {createVideoOverlay = forbidden, setMaterialCustomMap = forbidden,
    unrelatedFunction = forbidden, videoLink = "https://private.example/watch", playerName = "private"}
local first = setmetatable({renderOverlay = forbidden}, {__index = shared, __pairs = forbidden})
local second = setmetatable({getVideoOverlayCurrentTime = forbidden}, {__index = shared})
local report = TMSRuntimeApiReport.collect({first, second}, {createVideoOverlay = forbidden})
check(report.tables == 3 and report.functions == 5, "Shared inherited table is scanned once")
check(table.concat(report.names, ",") == "createVideoOverlay,getVideoOverlayCurrentTime,renderOverlay,setMaterialCustomMap",
    "Only relevant function identifiers are sorted and deduplicated")
check(report.missingControlNames == 0, "Visible control is covered by enumeration")
check(calls == 0, "No discovered native or __pairs callback was called")
local lines = {}
local function log(line) lines[#lines + 1] = line end
local written = TMSRuntimeApiReport.write(report, log)
check(written == #lines and written > 2, "Report emits bounded header, names, controls and footer")
local text = table.concat(lines, "\n")
check(not text:find("private", 1, true) and not text:find("https", 1, true), "No personal values are logged")
check(not text:find("unrelatedFunction", 1, true), "Unrelated global functions stay out of log")

local functional = setmetatable({renderOverlay = forbidden}, {__index = forbidden})
local protected = setmetatable({}, {__metatable = "locked", __index = forbidden})
report = TMSRuntimeApiReport.collect({functional, protected}, {createVideoOverlay = forbidden})
check(calls == 0 and report.blockedInheritance == 2, "Functional/protected parents never executed or bypassed")
check(report.missingControlNames == 1, "Control functions missing from traversal expose incomplete coverage")
check(#report.names == 1, "Blocked parents do not create invented function names")
local cycle = {renderOverlay = forbidden}
setmetatable(cycle, {__index = cycle})
report = TMSRuntimeApiReport.collect({cycle}, {})
check(report.tables == 1 and report.cycles == 1, "Inheritance cycles terminate")

local deep = {}
for index = 1, 12 do deep = setmetatable({}, {__index = deep}) end
report = TMSRuntimeApiReport.collect({deep}, {})
check(report.tables == TMSRuntimeApiReport.MAX_DEPTH and report.limited, "Inheritance depth is bounded and reported")
local many = {}
for index = 1, TMSRuntimeApiReport.MAX_ENTRIES + 20 do many[index] = "no output" end
report = TMSRuntimeApiReport.collect({many}, {})
check(report.entries == TMSRuntimeApiReport.MAX_ENTRIES and report.limited, "Entry traversal is bounded and reported")
local tables = {}
for index = 1, 40 do tables[index] = {} end
report = TMSRuntimeApiReport.collect(tables, {})
check(report.tables == TMSRuntimeApiReport.MAX_TABLES and report.limited, "Number of scanned tables is bounded")

local names = {}
for index = 1, 300 do names[string.format("testVideo%03d", index)] = forbidden end
names["video\nforged log"] = forbidden
names["https://private.example/video"] = forbidden
names["video" .. string.rep("x", 97)] = forbidden
report = TMSRuntimeApiReport.collect({names}, {})
check(report.selected == 300 and #report.names == TMSRuntimeApiReport.MAX_NAMES and report.limited,
    "Output cap preserves total and excludes malformed or oversized names")
check(report.names[1] == "testVideo001" and report.names[#report.names] == "testVideo256",
    "Truncation after sorting is deterministic")
lines = {}
TMSRuntimeApiReport.write(report, log)
local bounded = true
for _, line in ipairs(lines) do
    if #line > TMSRuntimeApiReport.MAX_LINE then bounded = false end
end
check(bounded and #lines < 40, "Log line length and total output remain bounded")
check(calls == 0, "No native functions were called throughout all inventory checks")

-- Native globals are passed as values, never invoked; both Lua versions supported.
createVideoOverlay = forbidden
setMaterialCustomMap = forbidden
local captured = TMSRuntimeApiReport.capture()
check(captured.selected >= 2 and captured.missingControlNames == 0,
    "Capture discovers actual environment names including known controls")
check(calls == 0, "Capture invokes no engine functions")
local originalGetfenv = getfenv
local modEnvironment = {fixtureVideoOnlyInMod = forbidden}
getfenv = function(target)
    if target == 0 then return {} end
    assert(target == TMSRuntimeApiReport.capture, "Use function environment, not pcall stack level")
    return modEnvironment
end
local modCaptured = TMSRuntimeApiReport.capture()
getfenv = originalGetfenv
check(table.concat(modCaptured.names, ","):find("fixtureVideoOnlyInMod", 1, true) ~= nil
    and modCaptured.environmentFailures == 0, "Capture includes a distinct mod function environment")
if type(setfenv) == "function" then
    local originalEnvironment = getfenv(TMSRuntimeApiReport.capture)
    local isolated = setmetatable({_G = {}, fixtureVideoIsolatedMod = forbidden}, {__index = originalEnvironment})
    setfenv(TMSRuntimeApiReport.capture, isolated)
    modCaptured = TMSRuntimeApiReport.capture()
    setfenv(TMSRuntimeApiReport.capture, originalEnvironment)
    assert(table.concat(modCaptured.names, ","):find("fixtureVideoIsolatedMod", 1, true) ~= nil,
        "Lua 5.1 capture must include actual isolated setfenv environment")
end
print(string.format("TractorMediaScreen: %d runtime API report checks passed (%s)", count, _VERSION))
