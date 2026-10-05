-- Profiles contain only vehicle integration data, never player media state.
TMSProfiles = {}
TMSProfiles.valtraS = {
    id = "valtraS",
    filename = "data/vehicles/valtra/sseries/sseries.xml",
    -- Offset from the original indoor camera position in vehicle axes:
    -- right (-X), below eye level (-Y), forward (+Z). Fine calibration is pending.
    eyeOffset = {-0.42, -0.30, 0.52},
    calibrated = false
}

function TMSProfiles.find(filename)
    if type(filename) ~= "string" then return nil end
    local path = filename:gsub("\\", "/"):lower():gsub("^%$data/", "data/")
    for _, profile in ipairs({TMSProfiles.valtraS}) do
        if path == profile.filename or path:sub(-#profile.filename - 1) == "/" .. profile.filename then
            return profile
        end
    end
    return nil
end
