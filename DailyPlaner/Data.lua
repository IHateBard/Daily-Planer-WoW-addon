local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local DEFAULT_NOTE_TITLE = "Заметка"

local function NormalizeId(id)
    return tonumber(id)
end

function DP:InitDB()
    if not DailyPlanerDB then
        DailyPlanerDB = {}
    end

    local db = DailyPlanerDB

    if not db.notes or #db.notes == 0 then
        db.notes = {
            {
                id = 1,
                title = DEFAULT_NOTE_TITLE .. " 1",
                items = {},
            },
        }
        db.activeNoteId = 1
        db.nextNoteId = 2
        db.nextItemId = 1
    end

    db.nextNoteId = db.nextNoteId or (#db.notes + 1)
    db.nextItemId = db.nextItemId or 1
    db.activeNoteId = NormalizeId(db.activeNoteId) or NormalizeId(db.notes[1].id)

    if not db.activeNoteId then
        db.activeNoteId = NormalizeId(db.notes[1].id)
    end

    if not db.questTitleCache then
        db.questTitleCache = {}
    end

    for _, note in ipairs(db.notes) do
        note.id = NormalizeId(note.id) or note.id
        self:NormalizeNoteItemsArray(note)
        for _, item in ipairs(note.items) do
            item.id = NormalizeId(item.id) or item.id
            if item.kind == "quest" and NormalizeId(item.questId) then
                item.kind = "quest"
                item.questId = NormalizeId(item.questId)
            elseif not item.kind then
                item.kind = "text"
            end
        end
    end

    self.db = db
    self:InitQuestCache()
end

function DP:GetActiveNote()
    local activeId = NormalizeId(self.db.activeNoteId)
    for _, note in ipairs(self.db.notes) do
        if NormalizeId(note.id) == activeId then
            return note
        end
    end
    return self.db.notes[1]
end

function DP:SetActiveNote(noteId)
    self.db.activeNoteId = NormalizeId(noteId)
end

function DP:AddNote(title)
    local id = self.db.nextNoteId
    self.db.nextNoteId = id + 1

    local note = {
        id = id,
        title = title or (DEFAULT_NOTE_TITLE .. " " .. id),
        items = {},
    }

    table.insert(self.db.notes, note)
    self.db.activeNoteId = id
    return note
end

function DP:DeleteNote(noteId)
    if #self.db.notes <= 1 then
        return false
    end

    for i, note in ipairs(self.db.notes) do
        if NormalizeId(note.id) == NormalizeId(noteId) then
            table.remove(self.db.notes, i)
            if self.db.activeNoteId == noteId then
                self.db.activeNoteId = self.db.notes[math.max(1, i - 1)].id
            end
            return true
        end
    end

    return false
end

function DP:RenameNote(noteId, title)
    title = strtrim(title or "")
    if title == "" then
        return false
    end

    for _, note in ipairs(self.db.notes) do
        if NormalizeId(note.id) == NormalizeId(noteId) then
            note.title = title
            return true
        end
    end
    return false
end

function DP:AddItem(noteId, text)
    text = strtrim(text or "")
    if text == "" then
        return nil
    end

    for _, note in ipairs(self.db.notes) do
        if NormalizeId(note.id) == NormalizeId(noteId) then
            local id = self.db.nextItemId
            self.db.nextItemId = id + 1

            local item = {
                id = id,
                kind = "text",
                text = text,
                done = false,
            }

            self:AppendItemToNote(note, item)
            return item
        end
    end

    return nil
end

function DP:AddQuestItem(noteId, questId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return nil
    end

    for _, note in ipairs(self.db.notes) do
        if NormalizeId(note.id) == NormalizeId(noteId) then
            self:NormalizeNoteItemsArray(note)
            for _, item in ipairs(note.items) do
                if self:IsQuestItem(item) and self:GetQuestId(item) == NormalizeId(questId) then
                    return nil
                end
            end

            local id = self.db.nextItemId
            self.db.nextItemId = id + 1
            questId = NormalizeId(questId)

            local title = self:GetQuestTitle(questId)
            local item = {
                id = id,
                kind = "quest",
                questId = questId,
                title = title,
                text = title,
                done = self:IsQuestCompleted(questId),
            }

            self:AppendItemToNote(note, item)
            self:CacheQuestTitle(questId, title)
            self:RequestQuestTitle(questId)
            return item
        end
    end

    return nil
end

function DP:ToggleItem(noteId, itemId)
    for _, note in ipairs(self.db.notes) do
        if NormalizeId(note.id) == NormalizeId(noteId) then
            local item = self:FindItemInNote(note, itemId)
            if not item then
                return nil
            end
            if self:IsQuestItem(item) then
                return self:IsQuestItemDone(item)
            end
            item.done = not item.done
            return item.done
        end
    end
    return nil
end

function DP:DeleteItem(noteId, itemId)
    for _, note in ipairs(self.db.notes) do
        if NormalizeId(note.id) == NormalizeId(noteId) then
            return self:RemoveItemFromNote(note, itemId)
        end
    end
    return false
end

function DP:SaveFramePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    self.db.frame = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

function DP:RestoreFramePosition(frame)
    local pos = self.db.frame
    if not pos then
        frame:SetPoint("CENTER")
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end
