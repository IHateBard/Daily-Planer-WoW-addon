local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local function Print(msg)
    print("|cff00ccffDaily Planer:|r " .. msg)
end

local function RegisterSlashCommands()
    SLASH_DAILYPLANER1 = "/dailyplaner"
    SLASH_DAILYPLANER2 = "/dp"
    SLASH_DAILYPLANER3 = "/dplan"

    SlashCmdList.DAILYPLANER = function(msg)
        msg = strtrim(msg or ""):lower()

        if msg == "reset" then
            DailyPlanerDB = nil
            DP:InitDB()
            if DP.frame then
                DP:RefreshUI()
            end
            Print("данные сброшены.")
            return
        end

        if not DP.frame then
            Print("окно не создано. Попробуйте /reload и проверьте ошибки (/console scriptErrors 1).")
            return
        end

        DP:Toggle()
    end
end

function DP:Initialize()
    if self.initialized then
        return
    end

    local ok, err = pcall(function()
        self:InitDB()
        self:SyncQuestItems()
        self:RegisterQuestEvents()
        self:InitUI()
    end)

    if not ok then
        Print("ошибка инициализации: " .. tostring(err))
        return
    end

    RegisterSlashCommands()
    self.initialized = true
    Print("загружен. Команды: /dp, /dplan, /dailyplaner")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, addon)
    if addon ~= ADDON_NAME then
        return
    end
    DP:Initialize()
end)
