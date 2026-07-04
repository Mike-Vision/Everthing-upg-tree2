local HttpService = game:GetService("HttpService")

local SettingsModule = {}

local defaultSettings = {
    Version = "2.4",
    AutoUpgrade = false,
    UpgradeDelay = 0.5,
    BatchSize = 10,
    AutoResearch = false,
    AutoConvert = false,
    MinConvertLambda = 10,
    AutoClickXP = false,
    XPClickDelay = 0.05,
    TokenStatus = "Scanning..."
}

SettingsModule.Values = {}
SettingsModule.Version = "2.4"

-- Initialize with defaults
for k, v in pairs(defaultSettings) do
    SettingsModule.Values[k] = v
end

local settingsFilePath = "everything_upg_settings.json"

-- Load settings from disk
function SettingsModule.load()
    local hasFile = false
    if isfile then
        pcall(function()
            hasFile = isfile(settingsFilePath)
        end)
    else
        -- Fallback if isfile not supported
        hasFile = true
    end
    
    if hasFile then
        local success, content = pcall(readfile, settingsFilePath)
        if success and content then
            local decodeSuccess, decoded = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if decodeSuccess and type(decoded) == "table" then
                -- Auto-delete outdated configuration version
                if decoded.Version ~= SettingsModule.Version then
                    print("[EverythingUpg Settings] Outdated configuration version detected! Deleting old settings...")
                    if delfile then
                        pcall(delfile, settingsFilePath)
                    end
                    SettingsModule.save() -- Save fresh defaults
                    return false
                end
                
                for k, v in pairs(decoded) do
                    -- Only restore valid settings and maintain correct types
                    if defaultSettings[k] ~= nil then
                        SettingsModule.Values[k] = v
                    end
                end
                print("[EverythingUpg Settings] Configuration loaded successfully.")
                return true
            end
        end
    end
    print("[EverythingUpg Settings] Using default configuration.")
    return false
end

-- Save settings to disk
function SettingsModule.save()
    local success, err = pcall(function()
        -- Avoid saving volatile statuses
        local toSave = {}
        for k, v in pairs(SettingsModule.Values) do
            if k ~= "TokenStatus" then
                toSave[k] = v
            end
        end
        toSave.Version = SettingsModule.Version
        local content = HttpService:JSONEncode(toSave)
        writefile(settingsFilePath, content)
    end)
    if success then
        print("[EverythingUpg Settings] Configuration saved successfully.")
    else
        warn("[EverythingUpg Settings] Failed to save configuration:", err)
    end
    return success
end

return SettingsModule
