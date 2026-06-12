local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local pendingQuestLoads = {}
local questTitleCache = {}

local WORLD_MAP_ROOTS = { 946, 947, 905, 875, 424, 572, 619, 113 }

local function Print(msg)
    print("|cff00ccffDaily Planer:|r " .. msg)
end

local function NormalizeId(id)
    return tonumber(id)
end

local function NormalizeSearchText(text)
    text = strlower(strtrim(text or ""))
    text = text:gsub("|c%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|h", "")
    text = text:gsub("|H", "")
    text = text:gsub("%[", "")
    text = text:gsub("%]", "")
    return text
end

function DP:ParseQuestInput(input)
    input = strtrim(input or "")
    if input == "" then
        return nil
    end

    local questId = input:match("quest:(%d+)")
        or input:match("Hquest:(%d+)")
        or input:match("hquest:(%d+)")
    if questId then
        return tonumber(questId)
    end

    if input:match("^%d+$") then
        return tonumber(input)
    end

    return nil, input
end

function DP:CacheQuestTitle(questId, title)
    questId = NormalizeId(questId)
    if questId and title and title ~= "" then
        questTitleCache[questId] = title
        if self.db and self.db.questTitleCache then
            self.db.questTitleCache[tostring(questId)] = title
        end
    end
end

function DP:InitQuestCache()
    if not self.db or not self.db.questTitleCache then
        return
    end

    for questId, title in pairs(self.db.questTitleCache) do
        questId = NormalizeId(questId)
        if questId and type(title) == "string" and title ~= "" then
            questTitleCache[questId] = title
        end
    end
end

function DP:ResolveQuestTitle(questId)
    questId = NormalizeId(questId)
    if not questId then
        return nil
    end

    if questTitleCache[questId] then
        return questTitleCache[questId]
    end

    local title = C_QuestLog.GetTitleForQuestID(questId)
    if title and title ~= "" then
        self:CacheQuestTitle(questId, title)
        return title
    end

    if GetQuestLink then
        local link = GetQuestLink(questId)
        if link then
            local fromLink = link:match("%[(.-)%]")
            if fromLink and fromLink ~= "" then
                self:CacheQuestTitle(questId, fromLink)
                return fromLink
            end
        end
    end

    return nil
end

function DP:RequestQuestTitle(questId, callback)
    questId = NormalizeId(questId)
    if not questId then
        return nil
    end

    local title = self:ResolveQuestTitle(questId)
    if title then
        if callback then
            callback(questId, title)
        end
        return title
    end

    pendingQuestLoads[questId] = callback or pendingQuestLoads[questId] or true
    C_QuestLog.RequestLoadQuestByID(questId)
    return nil
end

function DP:OnQuestDataLoadResult(questId, success)
    questId = NormalizeId(questId)
    if not questId then
        return
    end

    if success then
        local title = C_QuestLog.GetTitleForQuestID(questId)
        if title and title ~= "" then
            self:CacheQuestTitle(questId, title)
        end
    end

    local callback = pendingQuestLoads[questId]
    if callback and type(callback) == "function" then
        pendingQuestLoads[questId] = nil
        if success then
            callback(questId, self:ResolveQuestTitle(questId) or ("Квест #" .. questId))
        end
    else
        pendingQuestLoads[questId] = nil
    end

    if self.questAddFrame and self.questAddFrame:IsShown() then
        self:RefreshQuestSearchResults()
    end

    if self.frame and self.frame:IsShown() then
        self:RefreshUI()
    end
end

function DP:GetQuestTitle(questId, fallback)
    questId = NormalizeId(questId)
    if not questId then
        return fallback or ""
    end

    return self:ResolveQuestTitle(questId) or fallback or ("Квест #" .. questId)
end

function DP:IsQuestItem(item)
    return item and item.kind == "quest" and NormalizeId(item.questId) ~= nil
end

function DP:GetQuestId(item)
    if not self:IsQuestItem(item) then
        return nil
    end
    return NormalizeId(item.questId)
end

function DP:IsQuestCompleted(questId)
    questId = NormalizeId(questId)
    if not questId then
        return false
    end

    if C_QuestLog.IsQuestFlaggedCompleted(questId) then
        return true
    end

    if C_QuestLog.IsQuestFlaggedCompletedOnAccount and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questId) then
        return true
    end

    if C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questId) then
        return true
    end

    if C_QuestLog.IsComplete and C_QuestLog.IsComplete(questId) then
        return true
    end

    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questId)
    if objectives and #objectives > 0 then
        local allDone = true
        for _, objective in ipairs(objectives) do
            if not objective.finished then
                allDone = false
                break
            end
        end
        if allDone then
            return true
        end
    end

    return false
end

function DP:IsQuestActive(questId)
    questId = NormalizeId(questId)
    if not questId then
        return false
    end
    return self:IsQuestInLog(questId) or C_QuestLog.IsOnQuest(questId)
end

function DP:GetQuestLogIndex(questId)
    questId = NormalizeId(questId)
    if not questId then
        return nil
    end

    if C_QuestLog.GetLogIndexForQuestID then
        return C_QuestLog.GetLogIndexForQuestID(questId)
    end

    if GetQuestLogIndexByID then
        return GetQuestLogIndexByID(questId)
    end

    return nil
end

function DP:IsQuestInLog(questId)
    local logIndex = self:GetQuestLogIndex(questId)
    return logIndex ~= nil and logIndex > 0
end

function DP:EnsureQuestUILoaded()
    if not C_AddOns then
        return
    end

    if not C_AddOns.IsAddOnLoaded("Blizzard_QuestLog") then
        C_AddOns.LoadAddOn("Blizzard_QuestLog")
    end
end

function DP:GetQuestMapId(questId)
    questId = NormalizeId(questId)
    if not questId then
        return nil
    end

    if GetQuestUiMapID then
        local mapId = GetQuestUiMapID(questId)
        if mapId and mapId > 0 then
            return mapId
        end
    end

    if C_QuestLog.GetNextWaypoint then
        local mapId = C_QuestLog.GetNextWaypoint(questId)
        if mapId and mapId > 0 then
            return mapId
        end
    end

    if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
        local mapId = C_TaskQuest.GetQuestZoneID(questId)
        if mapId and mapId > 0 then
            return mapId
        end
    end

    return nil
end

function DP:GetWorldMapFrame()
    if QuestMapFrame and QuestMapFrame.GetParent then
        return QuestMapFrame:GetParent()
    end
    return WorldMapFrame
end

function DP:SuperTrackQuest(questId)
    questId = NormalizeId(questId)
    if not questId then
        return
    end

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(questId)
    elseif C_QuestLog.SetSuperTrackedQuestID then
        C_QuestLog.SetSuperTrackedQuestID(questId)
    end

    if C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(questId)
    end

    local logIndex = self:GetQuestLogIndex(questId)
    if logIndex and logIndex > 0 then
        if C_QuestLog.AddQuestWatch then
            if not (C_QuestLog.IsQuestWatched and C_QuestLog.IsQuestWatched(questId)) then
                C_QuestLog.AddQuestWatch(questId)
            end
        elseif AddQuestWatch then
            AddQuestWatch(logIndex, true)
        end

        if QuestSuperTracking_OnQuestTracked then
            QuestSuperTracking_OnQuestTracked(questId)
        end
    end
end

function DP:OpenQuestJournal(questId)
    questId = NormalizeId(questId)
    if not questId then
        return
    end

    self:EnsureQuestUILoaded()

    if OpenQuestLog then
        OpenQuestLog()
    end

    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(questId)
    elseif QuestMapFrame_ShowQuestDetails then
        QuestMapFrame_ShowQuestDetails(questId)
    else
        C_QuestLog.SetSelectedQuest(questId)
    end

    self:SuperTrackQuest(questId)
end

function DP:ShowQuestOnMap(questId)
    questId = NormalizeId(questId)
    if not questId then
        return
    end

    self:EnsureQuestUILoaded()

    local function applyMapFocus()
        local mapId = self:GetQuestMapId(questId)
        local mapFrame = self:GetWorldMapFrame()

        if OpenQuestLog then
            OpenQuestLog()
        elseif ToggleWorldMap and (not WorldMapFrame or not WorldMapFrame:IsShown()) then
            ToggleWorldMap()
        end

        if mapId and mapFrame and mapFrame.SetMapID then
            mapFrame:SetMapID(mapId)
        end

        if mapFrame and mapFrame.SetFocusedQuestID then
            mapFrame:SetFocusedQuestID(questId)
        end

        if mapId and C_QuestLog.SetMapForQuestPOIs then
            C_QuestLog.SetMapForQuestPOIs(mapId)
        end

        self:SuperTrackQuest(questId)
    end

    if self:GetQuestMapId(questId) then
        applyMapFocus()
        return
    end

    C_QuestLog.RequestLoadQuestByID(questId)
    self:RequestQuestTitle(questId, function()
        applyMapFocus()
        if self.frame and self.frame:IsShown() then
            self:RefreshUI()
        end
    end)
    applyMapFocus()
end

function DP:FocusQuest(questId)
    questId = NormalizeId(questId)
    if not questId then
        return
    end

    self:RequestQuestTitle(questId)

    if self:IsQuestInLog(questId) then
        self:OpenQuestJournal(questId)
        Print("открыт журнал: " .. self:GetQuestTitle(questId))
        return
    end

    self:ShowQuestOnMap(questId)
    Print("метка на карте: " .. self:GetQuestTitle(questId))
end

function DP:IsQuestItemDone(item)
    if self:IsQuestItem(item) then
        local questId = self:GetQuestId(item)
        if self:IsQuestCompleted(questId) then
            item.done = true
            return true
        end
        return item.done and true or false
    end
    return item.done and true or false
end

function DP:GetItemDisplayText(item)
    if self:IsQuestItem(item) then
        return self:GetQuestTitle(self:GetQuestId(item), item.title or item.text)
    end
    return item.text or ""
end

function DP:SyncQuestItems()
    for _, note in ipairs(self.db.notes) do
        for _, item in ipairs(self:IterateNoteItems(note)) do
            if self:IsQuestItem(item) then
                local questId = self:GetQuestId(item)
                item.questId = questId
                item.done = self:IsQuestCompleted(questId)
                local title = self:ResolveQuestTitle(questId)
                if title then
                    item.title = title
                    item.text = title
                    self:CacheQuestTitle(questId, title)
                else
                    self:RequestQuestTitle(questId)
                end
            end
        end
    end
end

function DP:VisitAllMaps(callback)
    local seen = {}

    local function visit(mapId)
        mapId = NormalizeId(mapId)
        if not mapId or seen[mapId] then
            return
        end
        seen[mapId] = true
        callback(mapId)

        if C_Map.GetMapChildrenInfo then
            local children = C_Map.GetMapChildrenInfo(mapId)
            if children then
                for _, child in ipairs(children) do
                    visit(child.mapID or child.mapId)
                end
            end
        end
    end

    for _, rootId in ipairs(WORLD_MAP_ROOTS) do
        if C_Map.GetMapInfo(rootId) then
            visit(rootId)
        end
    end
end

function DP:VisitRelevantMaps(callback)
    local startMapId = C_Map.GetBestMapForUnit("player")
    if not startMapId then
        return
    end

    local seen = {}

    local function visit(mapId)
        mapId = NormalizeId(mapId)
        if not mapId or seen[mapId] then
            return
        end
        seen[mapId] = true
        callback(mapId)

        if C_Map.GetMapChildrenInfo then
            local children = C_Map.GetMapChildrenInfo(mapId)
            if children then
                for _, child in ipairs(children) do
                    visit(child.mapID or child.mapId)
                end
            end
        end

        local mapInfo = C_Map.GetMapInfo(mapId)
        if mapInfo and mapInfo.parentMapID then
            visit(mapInfo.parentMapID)
        end
    end

    visit(startMapId)
end

function DP:CollectQuestIdsFromMap(mapId, seen)
    mapId = NormalizeId(mapId)
    if not mapId then
        return
    end

    C_QuestLog.SetMapForQuestPOIs(mapId)

    local quests = C_QuestLog.GetQuestsOnMap(mapId)
    if not quests then
        return
    end

    for _, quest in ipairs(quests) do
        local questId = NormalizeId(quest.questID or quest.questId)
        if questId then
            seen[questId] = true
            if quest.title and quest.title ~= "" then
                self:CacheQuestTitle(questId, quest.title)
            else
                self:RequestQuestTitle(questId)
            end
        end
    end
end

function DP:TitleMatchesSearch(title, search)
    if not title or title == "" then
        return false
    end

    local normalizedTitle = NormalizeSearchText(title)
    local normalizedSearch = NormalizeSearchText(search)

    if normalizedTitle == normalizedSearch then
        return true
    end

    if strfind(normalizedTitle, normalizedSearch, 1, true) then
        return true
    end

    return false
end

function DP:CollectQuestLogIds(addCandidate)
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then
            local questId = NormalizeId(info.questID)
            if questId then
                addCandidate(questId)
                if info.title and info.title ~= "" then
                    self:CacheQuestTitle(questId, info.title)
                end
            end
        end
    end
end

function DP:SearchCachedQuestsByName(search, limit, resultSeen, results)
    local function tryAdd(questId, title)
        questId = NormalizeId(questId)
        if not questId or resultSeen[questId] then
            return
        end
        if self:TitleMatchesSearch(title, search) then
            resultSeen[questId] = true
            table.insert(results, { questId = questId, title = title })
        end
    end

    if self.db and self.db.questTitleCache then
        for questId, title in pairs(self.db.questTitleCache) do
            if #results >= limit then
                return
            end
            if type(title) == "string" then
                tryAdd(questId, title)
            end
        end
    end

    for questId, title in pairs(questTitleCache) do
        if #results >= limit then
            return
        end
        tryAdd(questId, title)
    end
end

function DP:StartGlobalQuestScan(searchText)
    if self.globalScanInProgress then
        self.pendingGlobalScanSearch = searchText
        return
    end

    self.globalScanInProgress = true
    self.globalScanMaps = {}
    self.globalScanIndex = 1
    self.globalScanSearch = searchText

    self:VisitAllMaps(function(mapId)
        table.insert(self.globalScanMaps, mapId)
    end)

    self:ScanNextGlobalMapBatch()
end

function DP:ScanNextGlobalMapBatch()
    if not self.globalScanInProgress then
        return
    end

    local batchSize = 8
    local mapSeen = {}

    for _ = 1, batchSize do
        if self.globalScanIndex > #self.globalScanMaps then
            self.globalScanInProgress = false
            self.globalScanDone = true
            self.pendingQuestSearch = nil

            if self.questAddFrame and self.questAddFrame:IsShown() then
                self:RefreshQuestSearchResults()
            end

            local nextSearch = self.pendingGlobalScanSearch
            self.pendingGlobalScanSearch = nil
            if nextSearch then
                self:StartGlobalQuestScan(nextSearch)
            end
            return
        end

        self:CollectQuestIdsFromMap(self.globalScanMaps[self.globalScanIndex], mapSeen)
        self.globalScanIndex = self.globalScanIndex + 1
    end

    C_Timer.After(0.03, function()
        self:ScanNextGlobalMapBatch()
    end)
end

function DP:SearchQuestsByName(search, limit)
    search = strtrim(search or "")
    if search == "" then
        return {}
    end

    limit = limit or 25
    local results = {}
    local resultSeen = {}
    local candidateIds = {}
    local candidateSeen = {}

    local function addCandidate(questId)
        questId = NormalizeId(questId)
        if questId and not candidateSeen[questId] then
            candidateSeen[questId] = true
            table.insert(candidateIds, questId)
        end
    end

    local function addResult(questId, title)
        questId = NormalizeId(questId)
        if not questId or resultSeen[questId] then
            return false
        end
        if self:TitleMatchesSearch(title, search) then
            resultSeen[questId] = true
            table.insert(results, { questId = questId, title = title })
            return #results >= limit
        end
        return false
    end

    self:SearchCachedQuestsByName(search, limit, resultSeen, results)
    if #results >= limit then
        return results
    end

    self:CollectQuestLogIds(addCandidate)

    local mapSeen = {}
    self:VisitRelevantMaps(function(mapId)
        self:CollectQuestIdsFromMap(mapId, mapSeen)
    end)

    for questId in pairs(mapSeen) do
        addCandidate(questId)
    end

    local pendingTitles = false

    for _, questId in ipairs(candidateIds) do
        local title = self:ResolveQuestTitle(questId)
        if not title then
            pendingTitles = true
            self:RequestQuestTitle(questId)
        elseif addResult(questId, title) then
            break
        end
    end

    if #results < limit and not self.globalScanInProgress and not self.globalScanDone then
        self.pendingQuestSearch = search
        self:StartGlobalQuestScan(search)
    elseif pendingTitles then
        self.pendingQuestSearch = search
    else
        self.pendingQuestSearch = nil
    end

    return results
end

function DP:AddQuestFromSearchResult(questId)
    questId = NormalizeId(questId)
    if not questId then
        return false
    end

    local note = self:GetActiveNote()
    if not note then
        Print("нет активной заметки")
        return false
    end

    if self:AddQuestItem(note.id, questId) then
        if self.questAddFrame then
            self.questAddFrame:Hide()
        end
        self:RefreshUI()
        Print("добавлен: " .. self:GetQuestTitle(questId))
        return true
    end

    Print("квест уже есть в списке")
    return false
end

function DP:TryAddQuestFromSearchInput()
    local query = strtrim(self.questSearchInput and self.questSearchInput:GetText() or "")
    local questId, searchText = self:ParseQuestInput(query)

    if questId then
        return self:AddQuestFromSearchResult(questId)
    end

    if searchText and searchText ~= "" then
        self:RefreshQuestSearchResults()

        if self.lastQuestSearchResults and #self.lastQuestSearchResults == 1 then
            return self:AddQuestFromSearchResult(self.lastQuestSearchResults[1].questId)
        end

        if self.lastQuestSearchResults and #self.lastQuestSearchResults == 0 then
            Print("квест не найден. Попробуйте ID, например: 94385")
        end
        return false
    end

    return false
end

function DP:RegisterQuestEvents()
    if self.questEventsRegistered then
        return
    end

    local frame = self.questEventFrame
    if not frame then
        frame = CreateFrame("Frame")
        self.questEventFrame = frame
    end

    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("QUEST_WATCH_UPDATE")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("QUEST_LOG_CRITERIA_UPDATE")
    frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "QUEST_DATA_LOAD_RESULT" then
            local questId, success = ...
            self:OnQuestDataLoadResult(questId, success)
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            self:InitQuestCache()
        end

        self:SyncQuestItems()
        if self.frame and self.frame:IsShown() then
            self:RefreshUI()
        end
    end)

    self.questEventsRegistered = true
end
