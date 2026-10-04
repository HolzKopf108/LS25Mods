-- Parsing a link does not make a provider playable. No network requests here.
TMSMediaSource = {}

local function validVideoId(id)
    return type(id) == "string" and #id == 11 and id:match("^[%w_-]+$") ~= nil
end

function TMSMediaSource.parse(value)
    if type(value) ~= "string" or #value > 2048 then return nil, "invalidLink" end
    local url = value:match("^%s*(.-)%s*$")
    if url == "" or url:find("[%s%c\\]") then return nil, "invalidLink" end
    if not url:match("^[%a][%w+.-]*://") then url = "https://" .. url end
    local scheme, host, rest = url:match("^(https?)://([^/?#]+)(.*)$")
    if scheme == nil then return nil, "invalidLink" end
    host = host:lower()
    if host == "www.youtube.com" or host == "m.youtube.com" then host = "youtube.com" end
    local path = rest:match("^([^?#]*)") or ""
    local id
    if host == "youtu.be" then
        id = path:match("^/([%w_-]+)/?$")
    elseif host == "youtube.com" then
        if path == "/watch" then
            local query = rest:match("%?([^#]*)") or ""
            for pair in query:gmatch("[^&]+") do
                local key, val = pair:match("^([^=]+)=(.*)$")
                if key == "v" then
                    if id ~= nil then return nil, "invalidLink" end
                    id = val
                end
            end
        else
            id = path:match("^/shorts/([%w_-]+)/?$")
                or path:match("^/live/([%w_-]+)/?$")
                or path:match("^/embed/([%w_-]+)/?$")
        end
    elseif host == "twitch.tv" or host == "www.twitch.tv" then
        local channel = path:match("^/([%w_]+)/?$")
        if channel == nil or #channel > 25 then return nil, "invalidLink" end
        return {provider = "twitch", id = channel:lower(), playable = false}, "providerUnavailable"
    else
        return nil, "unsupportedProvider"
    end
    if not validVideoId(id) then return nil, "invalidLink" end
    return {provider = "youtube", id = id, playable = false}, "providerUnavailable"
end
