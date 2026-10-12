local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/TMSLog.lua")
local count, calls = 0, {}
local function check(value, message) assert(value, message); count = count + 1 end
Logging = {}
for _, level in ipairs({"info", "warning", "error"}) do
    Logging[level] = function(...) calls[#calls + 1] = {level = level, args = {...}, n = select("#", ...)} end
end
local original = Logging.info
check(TMSLog.DEBUG == true, "Development build enables diagnostics centrally")
for _, level in ipairs({"info", "warning", "error"}) do
    TMSLog[level]("value=%s/%d", "test", 7, nil)
    local call = calls[#calls]
    check(call.level == level and call.n == 4 and call.args[1] == "value=%s/%d"
        and call.args[2] == "test" and call.args[3] == 7,
        "Logger preserves level, format, argument types and trailing nil")
end
TMSLog.DEBUG = false
local before = #calls
for _, level in ipairs({"info", "warning", "error"}) do TMSLog[level]("disabled") end
check(#calls == before, "Single switch suppresses all mod log levels")
Logging.info("engine-owned message")
check(Logging.info == original and #calls == before + 1, "Global engine logger remains unchanged")
TMSLog.DEBUG = true
TMSLog.info("enabled again")
check(#calls == before + 2, "Logging resumes when switch is re-enabled")
print(string.format("TractorMediaScreen logging: %d checks passed (%s)", count, _VERSION))
