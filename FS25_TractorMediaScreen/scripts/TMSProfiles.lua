-- Profiles contain only vehicle integration data, never player media state.
TMSProfiles = {}
TMSProfiles.valtraS = {
    id = "valtraS",
    filename = "data/vehicles/valtra/sseries/sseries.xml",
    -- Provisional placement. Calibrate in FS25 before calling this release-ready.
    position = {0.65, 2.15, 0.35},
    rotation = {0, -20, 0},
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
