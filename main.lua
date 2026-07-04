-- EVERYTHING UPG TREE - Consolidated Script (Version 4.2)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

--------------------------------------------------------------------------------
-- 1. SETTINGS SUBSYSTEM
--------------------------------------------------------------------------------
local Settings = {
    Values = {},
    Version = "4.2"
}

local defaultSettings = {
    Version = "4.2",
    AutoUpgrade = false,
    UpgradeDelay = 0.5,
    BatchSize = 10,
    AutoResearch = false,
    AutoConvert = false,
    MinConvertLambda = 10,
    AutoClickXP = false,
    XPClickDelay = 0.05,
    TokenStatus = "Scanning...",
    DisableAntiCheat = false,
    AntiKick = false,
    AntiAFK = false,
    ModDetection = false
}

-- Initialize Settings Module with default values
for k, v in pairs(defaultSettings) do
    Settings.Values[k] = v
end

local settingsFilePath = "everything_upg_settings.json"

function Settings.load()
    local hasFile = false
    if isfile then
        pcall(function()
            hasFile = isfile(settingsFilePath)
        end)
    else
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
                if decoded.Version ~= Settings.Version then
                    print("[EverythingUpg Settings] Outdated version detected! Clearing old settings...")
                    if delfile then
                        pcall(delfile, settingsFilePath)
                    end
                    Settings.save()
                    return false
                end
                
                for k, v in pairs(decoded) do
                    if defaultSettings[k] ~= nil then
                        Settings.Values[k] = v
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

function Settings.save()
    local success, err = pcall(function()
        local toSave = {}
        for k, v in pairs(Settings.Values) do
            if k ~= "TokenStatus" then
                toSave[k] = v
            end
        end
        toSave.Version = Settings.Version
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

-- Load settings immediately
Settings.load()

--------------------------------------------------------------------------------
-- 2. RESOURCES SUBSYSTEM
--------------------------------------------------------------------------------
local Resources = {}
local cachedToken = nil
local lastScanTime = 0

function Resources.getSessionToken(SettingsValues)
    if cachedToken then
        return cachedToken
    end
    
    if tick() - lastScanTime < 2.0 then
        return nil
    end
    lastScanTime = tick()
    
    if not getgc then 
        if SettingsValues then
            SettingsValues.TokenStatus = "getgc not supported"
        end
        return nil 
    end
    
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "function" then
            local info = debug.getinfo(obj)
            if info.source and info.source:find("mouse_behaviour") then
                local nups = info.nups or 0
                for i = 1, nups do
                    local ok, val = pcall(debug.getupvalue, obj, i)
                    if ok and typeof(val) == "buffer" then
                        cachedToken = val
                        return val
                    end
                end
            end
        end
    end
    return nil
end

function Resources.safeTeleport(pos)
    local targetPos = typeof(pos) == "CFrame" and pos.Position or pos
    local success = false
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
            for i = 1, 5 do
                task.wait(0.05)
                if (hrp.Position - targetPos).Magnitude < 10 then
                    success = true
                    break
                end
            end
        end
    end)
    return success
end

function Resources.isSafeBoard(cfg)
    if not cfg or not cfg.tags then return false end
    for _, tag in ipairs(cfg.tags) do
        local tagLower = tostring(tag):lower()
        if tagLower:find("donation") or tagLower:find("robux") then
            return false
        end
    end
    return true
end

function Resources.getCurrencyObject(currencyName)
    local mappedName = currencyName
    
    if currencyName == "P" then
        mappedName = "pts"
    elseif currencyName == "RP" then
        mappedName = "rp"
    elseif currencyName == "$" then
        mappedName = "cash"
    elseif currencyName == "A" then
        mappedName = "alpha3"
    elseif currencyName == "B" then
        mappedName = "beta"
    elseif currencyName == "S" then
        mappedName = "solarmass"
    elseif currencyName == "PP" then
        mappedName = "ppts"
    elseif currencyName == "TP" then
        mappedName = "tpts"
    elseif currencyName == "PX" then
        mappedName = "ptsx"
    elseif currencyName == "CH" then
        mappedName = "chips"
    elseif currencyName == "MSPoints" then
        mappedName = "mspts"
    elseif currencyName == "G" then
        mappedName = "gold"
    end
    
    local lowerName = tostring(mappedName):lower()
    
    local currenciesFolder = ReplicatedStorage:FindFirstChild("stats") and ReplicatedStorage.stats:FindFirstChild("currencies")
    if currenciesFolder then
        for _, child in ipairs(currenciesFolder:GetChildren()) do
            if child.Name:lower() == lowerName then
                return child
            end
        end
    end
    
    local materialsFolder = ReplicatedStorage:FindFirstChild("stats") and ReplicatedStorage.stats:FindFirstChild("materials")
    if materialsFolder then
        for _, child in ipairs(materialsFolder:GetChildren()) do
            if child.Name:lower() == lowerName then
                return child
            end
        end
    end
    
    return nil
end

--------------------------------------------------------------------------------
-- 3. BYPASS & SECURITY SUBSYSTEM
--------------------------------------------------------------------------------
local successHook, hookErr = pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if Settings.Values.AntiKick then
                if typeof(self) == "Instance" and self == LocalPlayer and (method == "Kick" or method == "kick") then
                    warn("[EverythingUpg Anti-Kick] Blocked client namecall kick. Reason:", tostring(args[1]))
                    return nil
                end
            end
            
            if Settings.Values.DisableAntiCheat then
                if typeof(self) == "Instance" then
                    local selfName = tostring(self)
                    if (selfName == "diagnostics_event" or selfName == "hyperfail" or selfName == "offline_report" or selfName == "kick") and method == "FireServer" then
                        warn("[EverythingUpg Security] Blocked server report remote:", selfName)
                        return nil
                    end
                end
            end
            
            return oldNamecall(self, ...)
        end)

        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if Settings.Values.AntiKick then
                if typeof(self) == "Instance" and self == LocalPlayer and (tostring(key):lower() == "kick") then
                    return function(...)
                        local args = {...}
                        warn("[EverythingUpg Anti-Kick] Blocked client index kick. Reason:", tostring(args[2]))
                        return nil
                    end
                end
            end
            return oldIndex(self, key)
        end)
        print("[EverythingUpg] Anti-Kick & Security hooks successfully established.")
    else
        print("[EverythingUpg] Hookmetamethod not supported by executor.")
    end
end)

-- Anti-AFK Setup
local vu = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if Settings.Values.AntiAFK then
        pcall(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- Moderator / Player Detection Setup
local function shouldKick(player)
    if player == LocalPlayer then return false end
    
    if game.PrivateServerId ~= "" or game.PrivateServerOwnerId ~= 0 then
        return true
    end
    
    local success, rank = pcall(function()
        return player:GetRankInGroup(33959123)
    end)
    if success and rank then
        if rank >= 10 then return true end
        
        local success2, role = pcall(function()
            return player:GetRoleInGroup(33959123)
        end)
        if success2 and role then
            local r = role:lower()
            if r:find("mod") or r:find("admin") or r:find("staff") or r:find("helper") or r:find("dev") or r:find("owner") or r:find("creator") or r:find("manager") then
                return true
            end
        end
    end
    
    return false
end

local function checkPlayers()
    if Settings.Values.ModDetection then
        for _, p in ipairs(Players:GetPlayers()) do
            if shouldKick(p) then
                LocalPlayer:Kick("Security: Moderator / Player " .. p.Name .. " detected in session.")
                return
            end
        end
        
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") and child.Name ~= LocalPlayer.Name then
                local p = Players:GetPlayerFromCharacter(child)
                if not p then
                    LocalPlayer:Kick("Security: Ghost spectator detected in workspace.")
                    return
                end
            end
        end
        
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Camera") and obj ~= workspace.CurrentCamera then
                LocalPlayer:Kick("Security: Suspicious spectate camera detected.")
                return
            end
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    if Settings.Values.ModDetection and shouldKick(p) then
        LocalPlayer:Kick("Security: Moderator / Player " .. p.Name .. " joined session.")
    end
end)

task.spawn(function()
    while task.wait(3) do
        checkPlayers()
    end
end)

--------------------------------------------------------------------------------
-- 4. LINORIA UI CREATION
--------------------------------------------------------------------------------
-- Clean up existing Linoria UI / Window
if getgenv().Linoria_Window then
    pcall(function()
        getgenv().Linoria_Window:Unload()
    end)
    getgenv().Linoria_Window = nil
end

-- Clean up existing Linoria ScreenGui by Name (prevents duplication)
for _, child in ipairs(game:GetService("CoreGui"):GetChildren()) do
    if child:IsA("ScreenGui") and child.Name == "EverythingUpgGui" then
        pcall(function() child:Destroy() end)
    end
end
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
if PlayerGui then
    for _, child in ipairs(PlayerGui:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == "EverythingUpgGui" then
            pcall(function() child:Destroy() end)
        end
    end
end

getgenv().EverythingUpgUnloaded = false

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

if Library.ScreenGui then
    Library.ScreenGui.Name = "EverythingUpgGui"
end

-- Create Tabs
local Tabs = {
    Farm = Window:AddTab("Farming"),
    Anti = Window:AddTab("Anti"),
    Status = Window:AddTab("Status")
}

-- Create Groupboxes
local FarmGroup = Tabs.Farm:AddLeftGroupbox("⚡ Auto Farm Settings")
local ResearchGroup = Tabs.Farm:AddRightGroupbox("🔬 Research Center Settings")
local AntiGroup = Tabs.Anti:AddLeftGroupbox("🛡️ Security & Anti-Cheat Bypass")
local StatusGroup = Tabs.Status:AddLeftGroupbox("📊 Player Status")
local AdminGroup = Tabs.Status:AddRightGroupbox("⚙️ Admin Settings")

-- 1. Point Farm Settings
local PointToggle = FarmGroup:AddToggle("AutoPointToggle", {
    Text = "Enable Auto Point Upgrade",
    Default = Settings.Values.AutoUpgrade,
    Tooltip = "Automatically buy available Point upgrades safely (Cheapest first)"
})
PointToggle:OnChanged(function(val)
    Settings.Values.AutoUpgrade = val
    print("[EverythingUpg UI] Set AutoUpgrade =", val)
    Settings.save()
end)

local BatchSlider = FarmGroup:AddSlider("UpgradeBatchSlider", {
    Text = "Batch Size (Upgrades)",
    Default = Settings.Values.BatchSize,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Tooltip = "Configure amount of upgrades purchased per step (Default: 10)"
})
BatchSlider:OnChanged(function(val)
    Settings.Values.BatchSize = val
    Settings.save()
end)

local UpgradeDelaySlider = FarmGroup:AddSlider("UpgradeDelaySlider", {
    Text = "Upgrade Delay (s)",
    Default = math.floor(Settings.Values.UpgradeDelay * 10),
    Min = 1,
    Max = 20,
    Rounding = 0,
    Compact = false,
    Tooltip = "Configure delay between Point upgrade batches (e.g. 5 = 0.5s)"
})
UpgradeDelaySlider:OnChanged(function(val)
    local newVal = val / 10
    Settings.Values.UpgradeDelay = newVal
    Settings.save()
end)

local XPToggle = FarmGroup:AddToggle("AutoClickXPToggle", {
    Text = "Enable Auto Click XP",
    Default = Settings.Values.AutoClickXP,
    Tooltip = "Automatically click the Leveling Center XP block extremely fast when detected"
})
XPToggle:OnChanged(function(val)
    Settings.Values.AutoClickXP = val
    print("[EverythingUpg UI] Set AutoClickXP =", val)
    Settings.save()
end)

local XPDelaySlider = FarmGroup:AddSlider("XPClickDelaySlider", {
    Text = "XP Click Delay (ms)",
    Default = math.floor(Settings.Values.XPClickDelay * 1000),
    Min = 10,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Tooltip = "Configure delay in milliseconds between XP clicks"
})
XPDelaySlider:OnChanged(function(val)
    local newVal = val / 1000
    Settings.Values.XPClickDelay = newVal
    Settings.save()
end)

-- 2. Research Settings
local ResearchToggle = ResearchGroup:AddToggle("AutoResearchToggle", {
    Text = "Enable Auto Research Upgrade",
    Default = Settings.Values.AutoResearch,
    Tooltip = "Automatically purchase Research Upgrades when you have enough RP/Lambda"
})
ResearchToggle:OnChanged(function(val)
    Settings.Values.AutoResearch = val
    print("[EverythingUpg UI] Set AutoResearch =", val)
    Settings.save()
end)

-- 3. Prestige / Convert Settings
local ConvertToggle = ResearchGroup:AddToggle("AutoConvertToggle", {
    Text = "Enable Auto Convert (Prestige)",
    Default = Settings.Values.AutoConvert,
    Tooltip = "Automatically convert Points into Lambda when minimum target is met"
})
ConvertToggle:OnChanged(function(val)
    Settings.Values.AutoConvert = val
    print("[EverythingUpg UI] Set AutoConvert =", val)
    Settings.save()
end)

local MinConvertSlider = ResearchGroup:AddSlider("MinConvertSlider", {
    Text = "Min Lambda to Convert (λ)",
    Default = Settings.Values.MinConvertLambda,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Tooltip = "Minimum pending Lambda required to automatically trigger Convert"
})
MinConvertSlider:OnChanged(function(val)
    Settings.Values.MinConvertLambda = val
    Settings.save()
end)

-- 4. Status Labels
local pointsLabel = StatusGroup:AddLabel("Points: --")
local lambdaLabel = StatusGroup:AddLabel("Lambda (λ): --")
local pendingLambdaLabel = StatusGroup:AddLabel("Pending Lambda: --")
local tokenStatusLabel = StatusGroup:AddLabel("Token Status: Scanning...")
local otherCurrenciesLabel = StatusGroup:AddLabel("Other Currencies: None")

-- Anti-Cheat & Protection Settings
local AntiCheatToggle = AntiGroup:AddToggle("DisableAntiCheatToggle", {
    Text = "Disable Anti-Cheat",
    Default = Settings.Values.DisableAntiCheat,
    Tooltip = "Block client diagnostics and exploit reporting to the server"
})
AntiCheatToggle:OnChanged(function(val)
    Settings.Values.DisableAntiCheat = val
    print("[EverythingUpg UI] Set DisableAntiCheat =", val)
    Settings.save()
end)

local AntiKickToggle = AntiGroup:AddToggle("AntiKickToggle", {
    Text = "Anti-Kick",
    Default = Settings.Values.AntiKick,
    Tooltip = "Bypass client-side kick requests from local scripts"
})
AntiKickToggle:OnChanged(function(val)
    Settings.Values.AntiKick = val
    print("[EverythingUpg UI] Set AntiKick =", val)
    Settings.save()
end)

local AntiAFKToggle = AntiGroup:AddToggle("AntiAFKToggle", {
    Text = "Anti-AFK",
    Default = Settings.Values.AntiAFK,
    Tooltip = "Prevent getting kicked for idling after 20 minutes"
})
AntiAFKToggle:OnChanged(function(val)
    Settings.Values.AntiAFK = val
    print("[EverythingUpg UI] Set AntiAFK =", val)
    Settings.save()
end)

local ModDetectToggle = AntiGroup:AddToggle("ModDetectToggle", {
    Text = "Moderator Detection",
    Default = Settings.Values.ModDetection,
    Tooltip = "Instantly exit/kick when another player joins your private server"
})
ModDetectToggle:OnChanged(function(val)
    Settings.Values.ModDetection = val
    print("[EverythingUpg UI] Set ModDetection =", val)
    Settings.save()
end)

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

ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(Tabs.Status)

--------------------------------------------------------------------------------
-- 5. MAIN LOGIC AND THREADS
--------------------------------------------------------------------------------
local en = require(ReplicatedStorage.modules.en)

-- Helper functions for currency validation
local function canAffordCost(costRes, savings, isUnlockUpgrade)
    if type(costRes) ~= "table" then
        return true
    end
    
    for currencySymbol, costAmount in pairs(costRes) do
        local curObj = Resources.getCurrencyObject(currencySymbol)
        if not curObj then
            return false
        end
        
        local playerAmount = en.toNumber(en.convert(curObj.Value))
        local requiredAmount = en.toNumber(en.convert(costAmount))
        if playerAmount < requiredAmount then
            return false
        end

        if not isUnlockUpgrade and savings and savings[curObj.Name] then
            if playerAmount - requiredAmount < savings[curObj.Name] then
                return false
            end
        end
    end
    
    return true
end

local function getCostValue(costRes, currentLvl)
    if type(costRes) == "table" then
        local total = 0
        local hasKeys = false
        for _, costAmount in pairs(costRes) do
            hasKeys = true
            total = total + en.toNumber(en.convert(costAmount))
        end
        if not hasKeys then
            return (currentLvl or 0) * 1000000 + 1000000
        end
        return total
    elseif costRes == true then
        return (currentLvl or 0) * 1000000 + 1000000
    end
    return 999999999999
end

local function hasCurrencyRequirement(costRes, targetCurrency)
    if type(costRes) ~= "table" then
        return false
    end
    return costRes[targetCurrency] ~= nil
end

local session_id = tick()
getgenv().EverythingUpgSession = session_id

-- 1. Status Labels Update Thread
task.spawn(function()
    while Library ~= nil and not getgenv().EverythingUpgUnloaded and getgenv().Linoria_Window == Window do
        task.wait(0.5)
        local success, err = pcall(function()
            local ptsVal = ReplicatedStorage.stats.currencies.pts.Value
            pointsLabel:SetText("Points: " .. en.short(en.convert(ptsVal)))
            
            local rpVal = ReplicatedStorage.stats.currencies.rp.Value
            lambdaLabel:SetText("Lambda (λ): " .. en.short(en.convert(rpVal)))
            
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
            
            tokenStatusLabel:SetText("Token Status: " .. tostring(Settings.Values.TokenStatus))
            
            -- Update other currencies
            local activeCurrencies = {}
            local currenciesFolder = ReplicatedStorage:FindFirstChild("stats") and ReplicatedStorage.stats:FindFirstChild("currencies")
            if currenciesFolder then
                for _, cur in ipairs(currenciesFolder:GetChildren()) do
                    if cur.Name ~= "pts" and cur.Name ~= "rp" then
                        local val = en.convert(cur.Value)
                        if en.toNumber(val) > 0 then
                            table.insert(activeCurrencies, cur.Name:upper() .. ": " .. en.short(val))
                        end
                    end
                end
            end
            
            local materialsFolder = ReplicatedStorage:FindFirstChild("stats") and ReplicatedStorage.stats:FindFirstChild("materials")
            if materialsFolder then
                for _, mat in ipairs(materialsFolder:GetChildren()) do
                    local val = en.convert(mat.Value)
                    if en.toNumber(val) > 0 then
                        table.insert(activeCurrencies, mat.Name:upper() .. ": " .. en.short(val))
                    end
                end
            end
            
            if #activeCurrencies > 0 then
                otherCurrenciesLabel:SetText("Other Currencies:\n" .. table.concat(activeCurrencies, "\n"))
            else
                otherCurrenciesLabel:SetText("Other Currencies: None")
            end
        end)
        if not success or getgenv().EverythingUpgUnloaded then
            break
        end
    end
end)

-- 2. Main Logic Loop (Auto Upgrade, Auto Research, Auto Convert)
task.spawn(function()
    print("[EverythingUpg Main] Thread started session:", session_id)
    local lastUpgradeTime = 0
    local lastResearchTime = 0
    local Cooldowns = {}
    local game_data = require(ReplicatedStorage.modules.libraries.game_data)
    
    while getgenv().EverythingUpgSession == session_id do
        task.wait(0.1)
        
        local currentSettings = Settings.Values
        if currentSettings.AutoUpgrade or currentSettings.AutoResearch or currentSettings.AutoConvert then
            local token = Resources.getSessionToken(currentSettings)
            if not token then
                currentSettings.TokenStatus = "Not Found! (Click something)"
            else
                if currentSettings.TokenStatus ~= "didnt found exp block" then
                    currentSettings.TokenStatus = "Secure Active"
                end
            end
        else
            if currentSettings.AutoClickXP then
                local lc = workspace.objects:FindFirstChild("leveling_center")
                local new_model = lc and lc:FindFirstChild("new")
                local click_btn = new_model and new_model:FindFirstChild("click", true)
                if not click_btn then
                    currentSettings.TokenStatus = "didnt found exp block"
                elseif currentSettings.TokenStatus == "Disabled" or currentSettings.TokenStatus == "didnt found exp block" then
                    local token = Resources.getSessionToken(currentSettings)
                    currentSettings.TokenStatus = token and "Secure Active" or "Not Found! (Click something)"
                end
            else
                currentSettings.TokenStatus = "Disabled"
            end
        end
        
        if currentSettings.AutoUpgrade or currentSettings.AutoResearch or currentSettings.AutoConvert then
            local token = Resources.getSessionToken(currentSettings)
            if token then
                local actionTaken = false
                
                -- A. AUTO CONVERT (PRESTIGE)
                if currentSettings.AutoConvert and tick() - lastUpgradeTime >= currentSettings.UpgradeDelay then
                    pcall(function()
                        local gainResetValObj = ReplicatedStorage:FindFirstChild("temp") and ReplicatedStorage.temp:FindFirstChild("s_gain_reset")
                        if gainResetValObj then
                            local pendingNum = en.toNumber(en.convert(gainResetValObj.Value))
                            if pendingNum >= currentSettings.MinConvertLambda then
                                print("[EverythingUpg] Auto Converting at pending Lambda:", pendingNum)
                                ReplicatedStorage.remotes.research_convert:FireServer(true)
                                lastUpgradeTime = tick()
                                actionTaken = true
                                task.wait(0.5)
                            end
                        end
                    end)
                end
                
                -- B. AUTO POINT UPGRADES
                if not actionTaken and currentSettings.AutoUpgrade and tick() - lastUpgradeTime >= currentSettings.UpgradeDelay then
                    local upgradesFolder = workspace:FindFirstChild("upgrades")
                    if upgradesFolder then
                        local rawList = upgradesFolder:GetChildren()
                        local savings = {}
                        for _, upg in ipairs(rawList) do
                            local upgName = upg.Name
                            local configMod = upg:FindFirstChild("config")
                            local currentLvlVal = ReplicatedStorage.stats.upgrades:FindFirstChild(upgName)
                            if configMod and currentLvlVal then
                                local success, cfg = pcall(require, configMod)
                                if success and cfg and Resources.isSafeBoard(cfg) then
                                    local isVisible = true
                                    if cfg.visibility then
                                        local okVis, visVal = pcall(cfg.visibility)
                                        if okVis and visVal == false then isVisible = false end
                                    end
                                    if isVisible then
                                        local currentLvl = currentLvlVal.Value
                                        local maxLvl = cfg.max and (type(cfg.max) == "function" and cfg.max() or cfg.max) or 1
                                        if currentLvl < maxLvl and maxLvl == 1 then
                                            local ok, costRes = pcall(cfg.can_buy, currentLvl, maxLvl, false)
                                            if ok and costRes ~= false and costRes ~= nil then
                                                local okMax, costResMax = pcall(cfg.can_buy, currentLvl, maxLvl, true)
                                                local finalCostRes = (okMax and costResMax) or costRes
                                                if type(finalCostRes) == "table" then
                                                    for currencySymbol, costAmount in pairs(finalCostRes) do
                                                        local curObj = Resources.getCurrencyObject(currencySymbol)
                                                        if curObj then
                                                            local costNum = en.toNumber(en.convert(costAmount))
                                                            if not savings[curObj.Name] or costNum < savings[curObj.Name] then
                                                                savings[curObj.Name] = costNum
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        local buyableUpgrades = {}
                        local now = tick()
                        
                        for _, upg in ipairs(rawList) do
                            local upgName = upg.Name
                            if not Cooldowns[upgName] or now - Cooldowns[upgName] >= 10 then
                                local configMod = upg:FindFirstChild("config")
                                local currentLvlVal = ReplicatedStorage.stats.upgrades:FindFirstChild(upgName)
                                
                                if configMod and currentLvlVal then
                                    local success, cfg = pcall(require, configMod)
                                    if success and cfg and Resources.isSafeBoard(cfg) then
                                        local isVisible = true
                                        if cfg.visibility then
                                            local okVis, visVal = pcall(cfg.visibility)
                                            if okVis and visVal == false then isVisible = false end
                                        end
                                        
                                        if isVisible then
                                            local currentLvl = currentLvlVal.Value
                                            local maxLvl = cfg.max and (type(cfg.max) == "function" and cfg.max() or cfg.max) or 1
                                            
                                            if currentLvl < maxLvl then
                                                local ok, costRes = pcall(cfg.can_buy, currentLvl, maxLvl, false)
                                                if ok and costRes ~= false and costRes ~= nil then
                                                    local okMax, costResMax = pcall(cfg.can_buy, currentLvl, maxLvl, true)
                                                    local finalCostRes = (okMax and costResMax) or costRes
                                                    if canAffordCost(finalCostRes, savings, maxLvl == 1) then
                                                        local costVal = getCostValue(finalCostRes, currentLvl)
                                                        local isMain = hasCurrencyRequirement(finalCostRes, "P")
                                                        table.insert(buyableUpgrades, {
                                                            Instance = upg,
                                                            Config = cfg,
                                                            Name = upgName,
                                                            CurrentLevel = currentLvl,
                                                            MaxLevel = maxLvl,
                                                            Cost = costVal,
                                                            IsMain = isMain,
                                                            CurrentLvlVal = currentLvlVal
                                                        })
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local currentPos = hrp and hrp.Position
                        
                        table.sort(buyableUpgrades, function(a, b)
                            if a.IsMain ~= b.IsMain then return a.IsMain end
                            
                            local distA = 999999
                            local distB = 999999
                            if currentPos then
                                local boardA = upgradesFolder:FindFirstChild(a.Name)
                                local boardB = upgradesFolder:FindFirstChild(b.Name)
                                if boardA and boardA:FindFirstChild("main") then
                                    distA = (boardA.main.Position - currentPos).Magnitude
                                end
                                if boardB and boardB:FindFirstChild("main") then
                                    distB = (boardB.main.Position - currentPos).Magnitude
                                end
                            end
                            
                            local isNearA = distA < 15
                            local isNearB = distB < 15
                            if isNearA ~= isNearB then
                                return isNearA
                            end
                            
                            return a.Cost < b.Cost
                        end)
                        
                        if #buyableUpgrades > 0 then
                            local bestUpg = buyableUpgrades[1]
                            local upgName = bestUpg.Name
                            local prevLvl = bestUpg.CurrentLevel
                            
                            local board = upgradesFolder:FindFirstChild(upgName)
                            local teleportSuccess = false
                            if board and board:FindFirstChild("main") then
                                print("[EverythingUpg] Teleporting to Board", upgName, "...")
                                teleportSuccess = Resources.safeTeleport(board.main.CFrame + Vector3.new(0, 3, 0))
                            end
                            
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            local isClose = false
                            if hrp and board and board:FindFirstChild("main") then
                                if (hrp.Position - board.main.Position).Magnitude < 15 then
                                    isClose = true
                                end
                            end
                            
                            if isClose then
                                print("[EverythingUpg] Buying Point Upgrade:", upgName, "Level:", prevLvl + 1, "Cost:", bestUpg.Cost)
                                ReplicatedStorage.remotes.upgrade:FireServer(upgName, token)
                                lastUpgradeTime = tick()
                                actionTaken = true
                                task.wait(0.2)
                                
                                local newLvl = bestUpg.CurrentLvlVal.Value
                                if newLvl == prevLvl then
                                    Cooldowns[upgName] = tick()
                                    print("[EverythingUpg] Point Purchase failed for:", upgName, "- Setting 10s cooldown")
                                else
                                    print("[EverythingUpg] Point Purchase success for:", upgName, "- New Level:", newLvl)
                                end
                            else
                                print("[EverythingUpg] Teleport failed or character too far from board:", upgName, "- Purchase cancelled")
                                Cooldowns[upgName] = tick()
                            end
                        end
                    end
                end
                
                -- C. AUTO RESEARCH UPGRADES
                if not actionTaken and currentSettings.AutoResearch and tick() - lastResearchTime >= 1.5 then
                    pcall(function()
                        local rc = workspace.objects:FindFirstChild("research_center")
                        if not rc then return end
                        
                        local savings = {}
                        for upgName, cfg in pairs(game_data.research) do
                            local currentLvlVal = ReplicatedStorage.stats.research_upgrades:FindFirstChild(upgName)
                            if currentLvlVal then
                                local isVisible = true
                                if cfg.when_to_show then
                                    local okShow, showVal = pcall(cfg.when_to_show)
                                    if okShow and showVal == false then isVisible = false end
                                end
                                if isVisible then
                                    local currentLvl = currentLvlVal.Value
                                    local maxLvl = cfg.max
                                    if type(maxLvl) == "function" then
                                        maxLvl = maxLvl()
                                    elseif not maxLvl then
                                        maxLvl = 1
                                    end
                                    if currentLvl < maxLvl and maxLvl == 1 then
                                        local ok, costRes = pcall(cfg.can_buy, currentLvl, maxLvl, false)
                                        if ok and costRes ~= false and costRes ~= nil then
                                            local okMax, costResMax = pcall(cfg.can_buy, currentLvl, maxLvl, true)
                                            local finalCostRes = (okMax and costResMax) or costRes
                                            if type(finalCostRes) == "table" then
                                                for currencySymbol, costAmount in pairs(finalCostRes) do
                                                    local curObj = Resources.getCurrencyObject(currencySymbol)
                                                    if curObj then
                                                        local costNum = en.toNumber(en.convert(costAmount))
                                                        if not savings[curObj.Name] or costNum < savings[curObj.Name] then
                                                            savings[curObj.Name] = costNum
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        local buyableResearch = {}
                        for upgName, cfg in pairs(game_data.research) do
                            local currentLvlVal = ReplicatedStorage.stats.research_upgrades:FindFirstChild(upgName)
                            if currentLvlVal then
                                local isVisible = true
                                if cfg.when_to_show then
                                    local okShow, showVal = pcall(cfg.when_to_show)
                                    if okShow and showVal == false then isVisible = false end
                                end
                                if isVisible then
                                    local currentLvl = currentLvlVal.Value
                                    local maxLvl = cfg.max
                                    if type(maxLvl) == "function" then
                                        maxLvl = maxLvl()
                                    elseif not maxLvl then
                                        maxLvl = 1
                                    end
                                    if currentLvl < maxLvl then
                                        local ok, costRes = pcall(cfg.can_buy, currentLvl, maxLvl, false)
                                        if ok and costRes ~= false and costRes ~= nil then
                                            local okMax, costResMax = pcall(cfg.can_buy, currentLvl, maxLvl, true)
                                            local finalCostRes = (okMax and costResMax) or costRes
                                            if canAffordCost(finalCostRes, savings, maxLvl == 1) then
                                                local costVal = getCostValue(finalCostRes, currentLvl)
                                                local isMain = hasCurrencyRequirement(finalCostRes, "RP")
                                                table.insert(buyableResearch, {
                                                    Name = upgName,
                                                    CurrentLevel = currentLvl,
                                                    MaxLevel = maxLvl,
                                                    Cost = costVal,
                                                    IsMain = isMain,
                                                    CurrentLvlVal = currentLvlVal
                                                })
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        table.sort(buyableResearch, function(a, b)
                            if a.IsMain ~= b.IsMain then return a.IsMain end
                            return a.Cost < b.Cost
                        end)
                        
                        if #buyableResearch > 0 then
                            local bestResearch = buyableResearch[1]
                            local upgName = bestResearch.Name
                            local prevLvl = bestResearch.CurrentLevel
                            
                            print("[EverythingUpg] Buying Research Upgrade:", upgName, "Level:", prevLvl + 1, "Cost:", bestResearch.Cost)
                            ReplicatedStorage.remotes.research_upgrade:FireServer(upgName, "max", token)
                            lastResearchTime = tick()
                            actionTaken = true
                            task.wait(0.2)
                        end
                    end)
                end
            end
        end
    end
    print("[EverythingUpg Main] Thread stopped session:", session_id)
end)

-- 3. Auto Click XP Thread
task.spawn(function()
    print("[EverythingUpg XP] Thread started session:", session_id)
    local lastClickTime = 0
    local lastLogTime = 0
    while getgenv().EverythingUpgSession == session_id do
        task.wait(0.01)
        local currentSettings = Settings.Values
        if currentSettings.AutoClickXP then
            local lc = workspace.objects:FindFirstChild("leveling_center")
            local new_model = lc and lc:FindFirstChild("new")
            local click_btn = new_model and new_model:FindFirstChild("click", true)
            
            if not click_btn then
                currentSettings.TokenStatus = "didnt found exp block"
            else
                if currentSettings.TokenStatus == "didnt found exp block" or currentSettings.TokenStatus == "Disabled" then
                    local token = Resources.getSessionToken(currentSettings)
                    currentSettings.TokenStatus = token and "Secure Active" or "Not Found! (Click something)"
                end
                
                if tick() - lastClickTime >= currentSettings.XPClickDelay then
                    pcall(function()
                        local remote = ReplicatedStorage.remotes:FindFirstChild("click_xp")
                        if remote then
                            remote:FireServer()
                        end
                    end)
                    lastClickTime = tick()
                    if tick() - lastLogTime >= 2.0 then
                        print("[EverythingUpg XP] Auto clicking Leveling Center XP block...")
                        lastLogTime = tick()
                    end
                end
            end
        end
    end
    print("[EverythingUpg XP] Thread stopped session:", session_id)
end)

print("[EverythingUpg] Consolidate load complete (V4.2). UI is ready!")
