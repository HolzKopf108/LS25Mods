-- Small, bounded 24-bit QuickTime Animation decoder, implemented from the format.
-- Packet layout verified against FFmpeg's qtrleenc.c and qtrle.c:
-- https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/qtrleenc.c
-- No FFmpeg implementation code is included. This accepts the encoder's subset:
-- headers 0/8, zero reserved fields, exact sizes and an explicit frame terminator.
TMSQtrleDecoder = {}
local TMSQtrleDecoder_mt = {__index = TMSQtrleDecoder}

TMSQtrleDecoder.MAX_WIDTH = 32
TMSQtrleDecoder.MAX_HEIGHT = 18
TMSQtrleDecoder.MAX_PACKET_BYTES = 4096

local function dimension(value, limit)
    return type(value) == "number" and value >= 1 and value <= limit and value == math.floor(value)
end

function TMSQtrleDecoder.new(width, height)
    if not dimension(width, TMSQtrleDecoder.MAX_WIDTH) or not dimension(height, TMSQtrleDecoder.MAX_HEIGHT) then
        return nil, "QTRLE dimensions must be integers between 1x1 and 32x18"
    end
    local self = setmetatable({width = width, height = height}, TMSQtrleDecoder_mt)
    self:reset()
    return self
end

function TMSQtrleDecoder:reset()
    self.previous = string.rep(string.char(0), self.width * self.height * 3)
end

local function hexByte(pair)
    return string.char(tonumber(pair, 16))
end

local function unsigned16(data, position)
    local a, b = data:byte(position, position + 1)
    return a * 256 + b
end

function TMSQtrleDecoder:decode(packetHex)
    if type(packetHex) ~= "string" or #packetHex < 14 or #packetHex > self.MAX_PACKET_BYTES * 2
        or #packetHex % 2 ~= 0 or packetHex:find("[^%x]") ~= nil then
        return nil, "Invalid or oversized QTRLE hexadecimal packet"
    end
    local data = packetHex:gsub("..", hexByte)
    local a, b, c, d = data:byte(1, 4)
    if ((a * 256 + b) * 256 + c) * 256 + d ~= #data then
        return nil, "QTRLE packet size mismatch"
    end
    local header = unsigned16(data, 5)
    local firstLine, lineCount, position = 0, self.height, 7
    if header == 8 then
        if #data < 15 then return nil, "Truncated QTRLE line header" end
        firstLine = unsigned16(data, 7)
        lineCount = unsigned16(data, 11)
        if unsigned16(data, 9) ~= 0 or unsigned16(data, 13) ~= 0 then
            return nil, "Unsupported QTRLE reserved fields"
        end
        if firstLine > self.height or lineCount > self.height - firstLine then
            return nil, "QTRLE line range exceeds frame"
        end
        position = 15
    elseif header ~= 0 then
        return nil, "Unsupported QTRLE header"
    end

    -- FFmpeg emits this exact packet for an unchanged frame. The initial state
    -- and reset state are deliberately black; no external reference is needed.
    if #data == 7 and header == 0 and data:byte(7) == 0 then return self.previous end

    -- Work on a private image. A malformed delta must not damage its reference.
    local pixels = {}
    for index = 1, self.width * self.height do
        pixels[index] = self.previous:sub((index - 1) * 3 + 1, index * 3)
    end
    local line, endLine = firstLine, firstLine + lineCount
    while position <= #data do
        local skip = data:byte(position)
        position = position + 1
        if skip == 0 then
            if line ~= endLine or position ~= #data + 1 then
                return nil, "Premature QTRLE terminator or trailing data"
            end
            local result = table.concat(pixels)
            self.previous = result
            return result
        end
        if line >= endLine then return nil, "QTRLE contains too many lines" end
        local x = skip - 1
        if x > self.width then return nil, "QTRLE initial skip exceeds line" end
        local ended = false
        while position <= #data do
            local code = data:byte(position)
            position = position + 1
            if code == 255 then
                ended = true
                break
            elseif code == 0 then
                if position > #data then return nil, "Truncated QTRLE skip" end
                local additional = data:byte(position)
                position = position + 1
                if additional == 0 then return nil, "QTRLE backward skip is unsupported" end
                x = x + additional - 1
                if x > self.width then return nil, "QTRLE skip exceeds line" end
            else
                local repeated = code >= 128
                local length = repeated and 256 - code or code
                if length > self.width - x then return nil, "QTRLE pixel run exceeds line" end
                local bytesNeeded = repeated and 3 or length * 3
                if position + bytesNeeded - 1 > #data then return nil, "Truncated QTRLE pixel run" end
                for offset = 0, length - 1 do
                    local source = repeated and position or position + offset * 3
                    pixels[line * self.width + x + offset + 1] = data:sub(source, source + 2)
                end
                position = position + bytesNeeded
                x = x + length
            end
        end
        if not ended then return nil, "Missing QTRLE line terminator" end
        line = line + 1
    end
    return nil, "Missing QTRLE frame terminator"
end
