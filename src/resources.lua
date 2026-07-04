local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resources = {}

-- Safe session token retrieval with rate limiting to avoid lag
local cachedToken = nil
local lastScanTime = 0

function Resources.getSessionToken(Settings)
    if cachedToken then
        return cachedToken
    end
    
    if tick() - lastScanTime < 2.0 then
        return nil
    end
    lastScanTime = tick()
    
    if not getgc then 
        if Settings then
            Settings.TokenStatus = "getgc not supported"
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

-- Physics-matching Safe Teleportation
function Resources.safeTeleport(pos)
    local targetPos = typeof(pos) == "CFrame" and pos.Position or pos
    local success = false
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
            -- Wait for physics/position replication and check distance
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

-- Filter safe boards (no premium or donation tags)
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

-- Map config currency symbol/abbreviation to the correct ReplicatedStorage ValueObject
function Resources.getCurrencyObject(currencyName)
    local mappedName = currencyName
    
    -- Abbreviation/Symbol Mapping
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
    
    -- 1. Search in stats.currencies (case-insensitive)
    local currenciesFolder = ReplicatedStorage:FindFirstChild("stats") and ReplicatedStorage.stats:FindFirstChild("currencies")
    if currenciesFolder then
        for _, child in ipairs(currenciesFolder:GetChildren()) do
            if child.Name:lower() == lowerName then
                return child
            end
        end
    end
    
    -- 2. Search in stats.materials (case-insensitive)
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

return Resources
