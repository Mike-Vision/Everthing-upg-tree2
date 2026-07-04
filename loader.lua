-- Everything Upgrade Tree UI Launcher (LinoriaLib UI version)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Clean up existing Linoria UI / Window
if getgenv().Linoria_Window then
    pcall(function()
        getgenv().Linoria_Window:Unload()
    end)
end

-- Reset unload flag
getgenv().EverythingUpgUnloaded = false

-- Load Subsystems
local Farm = loadstring(readfile("Everything-upg-tree/src/main.lua"))()
getgenv().EverythingUpgFarm = Farm -- Cache Farm globally for transparency/debugging

-- Shortcut reference to settings values
local SettingsValues = Farm.Settings.Values

-- Load Linoria UI Library using safe .HttpGet syntax to prevent namecall hangs
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game.HttpGet(game, repo .. "Library.lua"))()
getgenv().Linoria_Library = Library
local ThemeManager = loadstring(game.HttpGet(game, repo .. "addons/ThemeManager.lua"))()

local Window = Library:CreateWindow({
    Title = "EVERYTHING UPG TREE",
    Center = true,
    AutoShow = true,
    TabPadding = 8
})

getgenv().Linoria_Window = Window

-- Create Tabs
local Tabs = {
    Farm = Window:AddTab("Farming"),
    Status = Window:AddTab("Status")
}

-- Create Groupboxes
local FarmGroup = Tabs.Farm:AddLeftGroupbox("⚡ Auto Farm Settings")
local ResearchGroup = Tabs.Farm:AddRightGroupbox("🔬 Research Center Settings")
local StatusGroup = Tabs.Status:AddLeftGroupbox("📊 Player Status")
local AdminGroup = Tabs.Status:AddRightGroupbox("⚙️ Admin Settings")

-- 1. Point Farm Settings
local PointToggle = FarmGroup:AddToggle("AutoPointToggle", {
    Text = "Enable Auto Point Upgrade",
    Default = SettingsValues.AutoUpgrade,
    Tooltip = "Automatically buy available Point upgrades safely (Cheapest first)"
})
PointToggle:OnChanged(function(val)
    SettingsValues.AutoUpgrade = val
    print("[EverythingUpg UI] Set AutoUpgrade =", val)
    Farm.Settings.save()
end)

local BatchSlider = FarmGroup:AddSlider("UpgradeBatchSlider", {
    Text = "Batch Size (Upgrades)",
    Default = SettingsValues.BatchSize,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Tooltip = "Configure amount of upgrades purchased per step (Default: 10)"
})
BatchSlider:OnChanged(function(val)
    SettingsValues.BatchSize = val
    Farm.Settings.save()
end)

local UpgradeDelaySlider = FarmGroup:AddSlider("UpgradeDelaySlider", {
    Text = "Upgrade Delay (s)",
    Default = math.floor(SettingsValues.UpgradeDelay * 10),
    Min = 1,
    Max = 20,
    Rounding = 0,
    Compact = false,
    Tooltip = "Configure delay between Point upgrade batches (e.g. 5 = 0.5s)"
})
UpgradeDelaySlider:OnChanged(function(val)
    local newVal = val / 10
    SettingsValues.UpgradeDelay = newVal
    Farm.Settings.save()
end)

-- Auto Leveling XP Settings
local XPToggle = FarmGroup:AddToggle("AutoClickXPToggle", {
    Text = "Enable Auto Click XP",
    Default = SettingsValues.AutoClickXP,
    Tooltip = "Automatically click the Leveling Center XP block extremely fast when detected"
})
XPToggle:OnChanged(function(val)
    SettingsValues.AutoClickXP = val
    print("[EverythingUpg UI] Set AutoClickXP =", val)
    Farm.Settings.save()
end)

local XPDelaySlider = FarmGroup:AddSlider("XPClickDelaySlider", {
    Text = "XP Click Delay (ms)",
    Default = math.floor(SettingsValues.XPClickDelay * 1000),
    Min = 10,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Tooltip = "Configure delay in milliseconds between XP clicks"
})
XPDelaySlider:OnChanged(function(val)
    local newVal = val / 1000
    SettingsValues.XPClickDelay = newVal
    Farm.Settings.save()
end)

-- 2. Research Settings
local ResearchToggle = ResearchGroup:AddToggle("AutoResearchToggle", {
    Text = "Enable Auto Research Upgrade",
    Default = SettingsValues.AutoResearch,
    Tooltip = "Automatically purchase Research Upgrades when you have enough RP/Lambda"
})
ResearchToggle:OnChanged(function(val)
    SettingsValues.AutoResearch = val
    print("[EverythingUpg UI] Set AutoResearch =", val)
    Farm.Settings.save()
end)

-- 3. Prestige / Convert Settings
local ConvertToggle = ResearchGroup:AddToggle("AutoConvertToggle", {
    Text = "Enable Auto Convert (Prestige)",
    Default = SettingsValues.AutoConvert,
    Tooltip = "Automatically convert Points into Lambda when minimum target is met"
})
ConvertToggle:OnChanged(function(val)
    SettingsValues.AutoConvert = val
    print("[EverythingUpg UI] Set AutoConvert =", val)
    Farm.Settings.save()
end)

local MinConvertSlider = ResearchGroup:AddSlider("MinConvertSlider", {
    Text = "Min Lambda to Convert (λ)",
    Default = SettingsValues.MinConvertLambda,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Tooltip = "Minimum pending Lambda required to automatically trigger Convert"
})
MinConvertSlider:OnChanged(function(val)
    SettingsValues.MinConvertLambda = val
    Farm.Settings.save()
end)

-- 4. Status Labels
local pointsLabel = StatusGroup:AddLabel("Points: --")
local lambdaLabel = StatusGroup:AddLabel("Lambda (λ): --")
local pendingLambdaLabel = StatusGroup:AddLabel("Pending Lambda: --")
local tokenStatusLabel = StatusGroup:AddLabel("Token Status: Scanning...")

-- 5. Admin Settings (Unload Button)
local UnloadButton = AdminGroup:AddButton({
    Text = "Unload Script",
    Func = function()
        Library:Unload()
    end,
    DoubleClick = false,
    Tooltip = "Stop all background loops, close the UI and destroy it."
})

-- Handle Cleanup on UI Unload
Library:OnUnload(function()
    getgenv().EverythingUpgSession = nil
    getgenv().EverythingUpgUnloaded = true
    getgenv().Linoria_Window = nil
    print("[EverythingUpg] Script fully unloaded and threads terminated.")
end)

-- Theme Manager tab integration
ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(Tabs.Status)

-- Background thread to update UI Status labels
task.spawn(function()
    while Library ~= nil and not getgenv().EverythingUpgUnloaded and getgenv().Linoria_Window == Window do
        task.wait(0.5)
        local success, err = pcall(function()
            local en = require(ReplicatedStorage.modules.en)
            
            -- Update Points
            local ptsVal = ReplicatedStorage.stats.currencies.pts.Value
            pointsLabel:SetText("Points: " .. en.short(en.convert(ptsVal)))
            
            -- Update Lambda
            local rpVal = ReplicatedStorage.stats.currencies.rp.Value
            lambdaLabel:SetText("Lambda (λ): " .. en.short(en.convert(rpVal)))
            
            -- Update Pending Lambda
            local rc = workspace.objects:FindFirstChild("research_center")
            local gainLabel = rc and rc:FindFirstChild("new", true) and rc.new:FindFirstChild("gain", true)
            if gainLabel then
                local text = gainLabel.Text
                local pendingStr = text:match("%->%s*([%d%.%a]+)")
                if pendingStr then
                    pendingLambdaLabel:SetText("Pending Lambda: " .. pendingStr .. " λ")
                else
                    pendingLambdaLabel:SetText("Pending Lambda: 0 λ")
                end
            else
                pendingLambdaLabel:SetText("Pending Lambda: N/A")
            end
            
            -- Update Token Status
            tokenStatusLabel:SetText("Token Status: " .. tostring(SettingsValues.TokenStatus))
        end)
        if not success or getgenv().EverythingUpgUnloaded then
            -- Stop thread if UI is unloaded
            break
        end
    end
end)

print("[EverythingUpg] Loader initialized successfully with Linoria UI.")
