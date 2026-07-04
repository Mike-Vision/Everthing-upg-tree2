local CheckUpdate = {}

function CheckUpdate.start(currentVersion, Library)
    task.spawn(function()
        print("[EverythingUpg Update] Update checker started. Current version:", currentVersion)
        while task.wait(60) do
            local success, err = pcall(function()
                local githubRepo = "https://raw.githubusercontent.com/Mike-vision/Everthing-upg-tree2/main/"
                -- Dùng safe index call để tránh bug namecall treo game:HttpGet trên Madium
                local settingsContent = game.HttpGet(game, githubRepo .. "src/settings.lua?t=" .. os.time())
                if settingsContent then
                    local githubVersion = settingsContent:match('SettingsModule%.Version%s*=%s*"([%d%.]+)"')
                    if githubVersion and githubVersion ~= currentVersion then
                        print("[EverythingUpg Update] New version detected:", githubVersion, "(Current:", currentVersion .. ")")
                        print("[EverythingUpg Update] Unloading GUI and performing auto-update...")
                        
                        -- Unload current Linoria GUI
                        if Library then
                            Library:Unload()
                        elseif getgenv().Linoria_Library then
                            getgenv().Linoria_Library:Unload()
                        end
                        
                        task.wait(1)
                        
                        -- Tải và chạy loader mới nhất từ GitHub
                        loadstring(game.HttpGet(game, githubRepo .. "loader.lua?t=" .. os.time()))()
                    end
                end
            end)
            if not success then
                warn("[EverythingUpg Update] Error checking for updates:", err)
            end
        end
    end)
end

return CheckUpdate
