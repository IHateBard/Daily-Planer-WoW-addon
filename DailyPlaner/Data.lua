local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local DEFAULT_NOTE_TITLE = "Заметка"

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

    if not db.activeNoteId then
        db.activeNoteId = db.notes[1].id
    end

    self.db = db
end

function DP:GetActiveNote()
    for _, note in ipairs(self.db.notes) do
        if note.id == self.db.activeNoteId then
            return note
        end
    end
    return self.db.notes[1]
end

function DP:SetActiveNote(noteId)
    self.db.activeNoteId = noteId
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
        if note.id == noteId then
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
    for _, note in ipairs(self.db.notes) do
        if note.id == noteId then
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
        if note.id == noteId then
            local id = self.db.nextItemId
            self.db.nextItemId = id + 1

            local item = {
                id = id,
                text = text,
                done = false,
            }
            table.insert(note.items, item)
            return item
        end
    end

    return nil
end

function DP:ToggleItem(noteId, itemId)
    for _, note in ipairs(self.db.notes) do
        if note.id == noteId then
            for _, item in ipairs(note.items) do
                if item.id == itemId then
                    item.done = not item.done
                    return item.done
                end
            end
        end
    end
    return nil
end

function DP:DeleteItem(noteId, itemId)
    for _, note in ipairs(self.db.notes) do
        if note.id == noteId then
            for i, item in ipairs(note.items) do
                if item.id == itemId then
                    table.remove(note.items, i)
                    return true
                end
            end
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
