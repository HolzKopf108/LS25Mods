-- FS25 uses configuration item objects, including stable save identifiers.
TMSMonitorConfiguration = {}
local TMSMonitorConfiguration_mt = Class(TMSMonitorConfiguration, VehicleConfigurationItem)

function TMSMonitorConfiguration.new(configName, customMt)
    return VehicleConfigurationItem.new(configName, customMt or TMSMonitorConfiguration_mt)
end

function TMSMonitorConfiguration.postLoad(xmlFile, baseKey, baseDir, customEnvironment,
    isMod, items, storeItem, configName)
    if isMod or storeItem == nil or TMSProfiles.find(storeItem.xmlFilename) == nil then return end
    if #items > 0 then return end
    for index, saveId in ipairs({"NONE", "MONITOR"}) do
        local item = TMSMonitorConfiguration.new(configName)
        item:setIndex(index)
        item.name = TractorMediaScreen.i18n:getText(index == 1 and "tms_without" or "tms_with")
        item.price = index == 1 and 0 or 250
        item.saveId = saveId
        item.isDefault = index == 1
        item.isYesNoOption = false
        items[index] = item
    end
end

-- Our geometry is handled by the specialization, not XML object-change data.
function TMSMonitorConfiguration:onPreLoad() end
function TMSMonitorConfiguration:onLoad() end
function TMSMonitorConfiguration:onPrePostLoad() end
function TMSMonitorConfiguration:onPostLoad() end
function TMSMonitorConfiguration:onLoadFinished() end
function TMSMonitorConfiguration:onSizeLoad() end

function TMSMonitorConfiguration.register()
    local manager = g_vehicleConfigurationManager
    if manager == nil then return false end
    if manager:getConfigurationDescByName("tmsMonitor") == nil then
        manager:addConfigurationType("tmsMonitor", TractorMediaScreen.i18n:getText("tms_configuration"),
            nil, TMSMonitorConfiguration)
    end
    return true
end
