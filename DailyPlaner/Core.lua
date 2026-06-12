local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local function OnAddonLoaded(_, addon)
    if addon ~= ADDON_NAME then
        return
    end

    DP:InitDB()
    DP:InitUI()

    SLASH_DAILYPLANER1 = "/dailyplaner"
    SLASH_DAILYPLANER2 = "/dp"
    SlashCmdList.DAILYPLANER = function(msg)
        msg = strtrim(msg or ""):lower()

        if msg == "reset" then
            DailyPlanerDB = nil
            DP:InitDB()
            if DP.frame then
                DP:RefreshUI()
            end
            print("|cff00ccffDaily Planer:|r данные сброшены.")
            return
        end

        DP:Toggle()
    end

    print("|cff00ccffDaily Planer|r загружен. Команды: |cffffff00/dp|r, |cffffff00/dailyplaner|r")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnAddonLoaded)
