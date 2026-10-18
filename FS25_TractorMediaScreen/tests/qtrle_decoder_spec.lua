-- Pure codec tests: RGB bytes and packet errors do not depend on mocked FS25 APIs.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
dofile(mod .. "/scripts/media/TMSQtrleDecoder.lua")
local count = 0
local function check(value, message) assert(value, message); count = count + 1 end
local function byte(...) return string.char(...) end
local function be16(value) return byte(math.floor(value / 256) % 256, value % 256) end
local function be32(value) return be16(math.floor(value / 65536)) .. be16(value % 65536) end
local function hex(data) return (data:gsub(".", function(value) return string.format("%02x", value:byte()) end)) end
local function packet(body, firstLine, lineCount)
    local header = be16(0)
    if firstLine ~= nil then header = be16(8) .. be16(firstLine) .. be16(0) .. be16(lineCount) .. be16(0) end
    return hex(be32(#body + #header + 4) .. header .. body)
end
local red, green, blue, yellow, black = byte(255,0,0), byte(0,255,0), byte(0,0,255), byte(255,255,0), byte(0,0,0)
local unchanged = "00000007000000"
local decoder = assert(TMSQtrleDecoder.new(4, 2))
check(decoder:decode(unchanged) == black:rep(8), "Initial empty frame is black")
local key = packet(byte(1, 4) .. red .. green .. blue .. yellow .. byte(255)
    .. byte(1, 252) .. blue .. byte(255, 0))
local expected = red .. green .. blue .. yellow .. blue:rep(4)
check(decoder:decode(key) == expected, "Literal top row and repeated bottom row decode in RGB top-down order")
check(decoder:decode(unchanged) == expected, "Seven-byte empty frame preserves all pixels")
check(decoder:decode(key:upper()) == expected, "Uppercase hexadecimal is accepted")

local delta = packet(byte(2, 1) .. yellow .. byte(0, 2, 1) .. green .. byte(255, 0), 1, 1)
expected = red .. green .. blue .. yellow .. blue .. yellow .. blue .. green
check(decoder:decode(delta) == expected, "Delta starts at selected line and preserves initial and intermediate skipped pixels")
check(decoder:decode(packet(byte(5,255, 5,255,0))) == expected, "Entire unchanged lines can skip exactly the width")
check(decoder:decode(packet(byte(0), 2, 0)) == expected, "Empty changed-line range at frame end is valid")
check(decoder:decode(packet(byte(1,0,1,255, 1,255,0))) == expected, "A zero-length forward skip is bounded and preserves pixels")

local function reject(value, message)
    local result, reason = decoder:decode(value)
    check(result == nil and type(reason) == "string" and #reason > 0, message)
    check(decoder:decode(unchanged) == expected, message .. " leaves the reference intact")
end
reject(nil, "Nonstring input is rejected")
reject("0000000", "Odd hexadecimal length is rejected")
reject("0000000700000g", "Nonhexadecimal input is rejected")
reject("00000007000000\n", "Whitespace is rejected")
reject(string.rep("00", 4097), "Oversized payload is rejected before conversion")
reject("00000004000000", "Declared packet size must match bytes")
reject("80000007000000", "Unsupported high size bits are rejected")
reject("00000007000100", "Unknown header flags are rejected")
reject("00000007000800", "Truncated changed-line header is rejected")
reject(hex(be32(15) .. be16(8) .. be16(0) .. be16(1) .. be16(0) .. be16(0) .. byte(0)), "Reserved header fields must be zero")
reject(packet(byte(0), 3, 0), "Starting beyond the image is rejected")
reject(packet(byte(0), 1, 2), "Changed-line count must fit image")
reject(packet(byte(6,255,0), 0, 1), "Initial skip cannot cross a row")
reject(packet(byte(4,0,3,255,0), 0, 1), "Additional skip cannot cross a row")
reject(packet(byte(2,0,0,255,0), 0, 1), "Negative additional skip is rejected")
reject(packet(byte(1,0), 0, 1), "Missing additional skip byte is rejected")
reject(packet(byte(1,5) .. red:rep(5) .. byte(255,0), 0, 1), "Literal run cannot cross a row")
reject(packet(byte(2,252) .. red .. byte(255,0), 0, 1), "Repeated run cannot cross a row")
reject(packet(byte(1,128) .. red .. byte(255,0), 0, 1), "Largest signed repeat remains bounded by width")
reject(packet(byte(1,2) .. red, 0, 1), "Truncated literal pixel data is rejected")
reject(packet(byte(1,254,255), 0, 1), "Truncated repeated pixel data is rejected")
reject(packet(byte(1,1) .. red, 0, 1), "Missing end-of-line marker is rejected atomically after a write")
reject(packet(byte(1,1) .. red .. byte(255), 0, 1), "Missing end-of-frame marker is rejected atomically after a write")
reject(packet(byte(1,255,0)), "Premature end of declared lines is rejected")
reject(packet(byte(1,255,1,255,0), 0, 1), "Extra line is rejected")
reject(packet(byte(1,255,1,255,0,0)), "Bytes after frame terminator are rejected")

decoder:reset()
check(decoder:decode(unchanged) == black:rep(8), "Reset drops the previous picture")
check(decoder:decode(packet(byte(1,254) .. red .. byte(255,0), 1, 1)) == black:rep(4) .. red:rep(2) .. black:rep(2),
    "Delta after reset uses black for untouched pixels")
local limits = assert(TMSQtrleDecoder.new(32, 18))
local rows = {}
for y = 1, 18 do rows[y] = byte(1,224) .. byte(y, y + 1, y + 2) .. byte(255) end
local maximum = assert(limits:decode(packet(table.concat(rows) .. byte(0))))
check(#maximum == 32 * 18 * 3 and maximum:sub(1,3) == byte(1,2,3) and maximum:sub(-3) == byte(18,19,20),
    "Maximum supported frame decodes with exact row order and byte count")
local smallest = assert(TMSQtrleDecoder.new(1, 1))
check(smallest:decode(packet(byte(1,1) .. green .. byte(255,0))) == green, "A single pixel literal is valid")
for _, dimensions in ipairs({{0,1},{1,0},{33,1},{1,19},{1.5,1},{1,2.5},{-1,1},{math.huge,1},{0/0,1},{"4",2},{true,1}}) do
    local value, reason = TMSQtrleDecoder.new(dimensions[1], dimensions[2])
    check(value == nil and type(reason) == "string", "Invalid dimensions fail without allocating a frame")
end
check(TMSQtrleDecoder.new(nil, 1) == nil, "Missing dimensions fail without throwing")
print(string.format("QTRLE decoder: %d checks passed", count))
