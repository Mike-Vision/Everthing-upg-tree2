local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Load Submodules from GitHub
local githubRepo = "https://raw.githubusercontent.com/Mike-vision/Everthing-upg-tree2/main/"
local Resources = loadstring(game.HttpGet(game, githubRepo .. "src/resources.lua"))()
local Settings = loadstring(game.HttpGet(game, githubRepo .. "src/settings.lua"))()

-- Attempt to load saved settings
Settings.load()

-- Hook metatable functions to bypass client kick and report remotes safely
local successHook, hookErr = pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Block client-side Kick requests safely
            if Settings and Settings.Values and Settings.Values.AntiKick then
                if typeof(self) == "Instance" and self == LocalPlayer and (method == "Kick" or method == "kick") then
                    warn("[EverythingUpg Anti-Kick] Blocked client namecall kick. Reason:", tostring(args[1]))
                    return nil
                end
            end
            
            -- Block diagnostics reporting remotes safely
            if Settings and Settings.Values and Settings.Values.DisableAntiCheat then
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
            if Settings and Settings.Values and Settings.Values.AntiKick then
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
    if Settings and Settings.Values and Settings.Values.AntiAFK then
        pcall(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- Moderator / Player Detection Setup
local function checkPlayers()
    if Settings and Settings.Values and Settings.Values.ModDetection then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                LocalPlayer:Kick("Security: Another player detected in your private session.")
                break
            end
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    if Settings and Settings.Values and Settings.Values.ModDetection and p ~= LocalPlayer then
        LocalPlayer:Kick("Security: Player " .. p.Name .. " joined your private session.")
    end
end)

task.spawn(function()
    while task.wait(3) do
        checkPlayers()
    end
end)

local en = require(ReplicatedStorage.modules.en)

-- Helper functions for currency validation
local function canAffordCost(costRes, Resources, savings, isUnlockUpgrade)
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

        -- Apply savings limit if this is a normal upgrade (maxLvl > 1) to prioritize unlocks
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
            -- Empty table means special upgrade, assign virtual cost based on level
            return (currentLvl or 0) * 1000000 + 1000000
        end
        return total
    elseif costRes == true then
        -- Boolean true means special upgrade affordable, assign virtual cost based on level
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

-- Main Logic Thread
local session_id = tick()
getgenv().EverythingUpgSession = session_id

task.spawn(function()
    print("[EverythingUpg Main] Thread started session:", session_id)
    local lastUpgradeTime = 0
    local lastResearchTime = 0
    local Cooldowns = {} -- Avoid spamming failed purchases
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
                
                -- 1. AUTO CONVERT (PRESTIGE)
                if currentSettings.AutoConvert and tick() - lastUpgradeTime >= currentSettings.UpgradeDelay then
                    pcall(function()
                        local rc = workspace:FindFirstChild("objects") and workspace.objects:FindFirstChild("research_center")
                        local gainLabel = rc and rc:FindFirstChild("new", true) and rc.new:FindFirstChild("gain", true)
                        if gainLabel then
                            local text = gainLabel.Text
                            -- Text format: "720.17k ₱ -> 14.69 λ"
                            local pendingStr = text:match("%->%s*([%d%.%a]+)")
                            if pendingStr then
                                local pendingNum = en.toNumber(en.convert(pendingStr))
                                if pendingNum >= currentSettings.MinConvertLambda then
                                    print("[EverythingUpg] Teleporting to Research Center for Conversion...")
                                    Resources.safeTeleport(rc:GetPivot() + Vector3.new(0, 3, 0))
                                    
                                    print("[EverythingUpg] Auto Converting at pending Lambda:", pendingNum)
                                    ReplicatedStorage.remotes.research_convert:FireServer()
                                    lastUpgradeTime = tick()
                                    actionTaken = true
                                    task.wait(0.5)
                                end
                            end
                        end
                    end)
                end
                
                -- 2. AUTO POINT UPGRADES (Sequential and physics-matching)
                if not actionTaken and currentSettings.AutoUpgrade and tick() - lastUpgradeTime >= currentSettings.UpgradeDelay then
                    local upgradesFolder = workspace:FindFirstChild("upgrades")
                    if upgradesFolder then
                        local rawList = upgradesFolder:GetChildren()
                        -- Phase 1: Pre-calculate savings targets for unlock upgrades (maxLvl == 1)
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
                            
                            -- Check cooldown
                            if not Cooldowns[upgName] or now - Cooldowns[upgName] >= 10 then
                                local configMod = upg:FindFirstChild("config")
                                local currentLvlVal = ReplicatedStorage.stats.upgrades:FindFirstChild(upgName)
                                
                                if configMod and currentLvlVal then
                                    local success, cfg = pcall(require, configMod)
                                    if success and cfg and Resources.isSafeBoard(cfg) then
                                        -- STRICT SECURITY: Check visibility
                                        local isVisible = true
                                        if cfg.visibility then
                                            local okVis, visVal = pcall(cfg.visibility)
                                            if okVis and visVal == false then
                                                isVisible = false
                                            end
                                        end
                                        
                                        if isVisible then
                                            local currentLvl = currentLvlVal.Value
                                            local maxLvl = cfg.max and (type(cfg.max) == "function" and cfg.max() or cfg.max) or 1
                                            
                                            if currentLvl < maxLvl then
                                                local ok, costRes = pcall(cfg.can_buy, currentLvl, maxLvl, false)
                                                if ok and costRes ~= false and costRes ~= nil then
                                                    local okMax, costResMax = pcall(cfg.can_buy, currentLvl, maxLvl, true)
                                                    local finalCostRes = (okMax and costResMax) or costRes
                                                    if canAffordCost(finalCostRes, Resources, savings, maxLvl == 1) then
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
                        
                        -- Sort upgrades: P first, then cheaper cost
                        table.sort(buyableUpgrades, function(a, b)
                            if a.IsMain ~= b.IsMain then
                                return a.IsMain
                            end
                            return a.Cost < b.Cost
                        end)
                        
                        -- Buy exactly ONE upgrade at a time to prevent spam ban
                        if #buyableUpgrades > 0 then
                            local bestUpg = buyableUpgrades[1]
                            local upgName = bestUpg.Name
                            local prevLvl = bestUpg.CurrentLevel
                            
                            -- Move close to the board
                            local board = upgradesFolder:FindFirstChild(upgName)
                            local teleportSuccess = false
                            if board and board:FindFirstChild("main") then
                                print("[EverythingUpg] Teleporting to Board", upgName, "...")
                                teleportSuccess = Resources.safeTeleport(board.main.CFrame + Vector3.new(0, 3, 0))
                            end
                            
                            -- Verify distance again to prevent server side distance kick/ban
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
                                -- Wait for server replication
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
                
                -- 3. AUTO RESEARCH UPGRADES
                if not actionTaken and currentSettings.AutoResearch and tick() - lastResearchTime >= 1.5 then
                    pcall(function()
                                                local currentRP = en.toNumber(en.convert(ReplicatedStorage.stats.currencies.rp.Value))
                        
                        -- Phase 1: Pre-calculate savings targets for research unlock upgrades (maxLvl == 1)
                        local savings = {}
                        for upgName, cfg in pairs(game_data.research) do
                            local currentLvlVal = ReplicatedStorage.stats.research_upgrades:FindFirstChild(upgName)
                            if currentLvlVal then
                                local isVisible = true
                                if cfg.when_to_show then
                                    local okShow, showVal = pcall(cfg.when_to_show)
                                    if okShow and showVal == false then
                                        isVisible = false
                                    end
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
                                    if okShow and showVal == false then
                                        isVisible = false
                                    end
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
                                            
                                            if canAffordCost(finalCostRes, Resources, savings, maxLvl == 1) then
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
                        
                        -- Sort research: RP first, then cheaper cost
                        table.sort(buyableResearch, function(a, b)
                            if a.IsMain ~= b.IsMain then
                                return a.IsMain
                            end
                            return a.Cost < b.Cost
                        end)
                        
                        -- Buy exactly ONE research upgrade (No teleportation needed for research)
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
    end
    print("[EverythingUpg Main] Thread stopped session:", session_id)
end)

-- 4. AUTO CLICK XP THREAD
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

return {
    Settings = Settings,
    Resources = Resources
}
