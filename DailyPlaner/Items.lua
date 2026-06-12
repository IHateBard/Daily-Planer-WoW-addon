local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local function NormalizeId(id)
    return tonumber(id)
end

function DP:EnsureNoteItems(note)
    if note and not note.items then
        note.items = {}
    end
end

function DP:IterateNoteItems(note)
    local items = {}
    self:EnsureNoteItems(note)

    local keyed = {}
    for key, item in pairs(note.items) do
        if type(item) == "table" then
            table.insert(keyed, {
                sortId = NormalizeId(item.id) or NormalizeId(key) or 0,
                item = item,
            })
        end
    end

    table.sort(keyed, function(a, b)
        return a.sortId < b.sortId
    end)

    for _, entry in ipairs(keyed) do
        table.insert(items, entry.item)
    end

    return items
end

function DP:NormalizeNoteItemsArray(note)
    self:EnsureNoteItems(note)
    note.items = self:IterateNoteItems(note)
end

function DP:GetItemCount(note)
    return #self:IterateNoteItems(note)
end

function DP:FindItemInNote(note, itemId)
    itemId = NormalizeId(itemId)
    for _, item in ipairs(self:IterateNoteItems(note)) do
        if NormalizeId(item.id) == itemId then
            return item
        end
    end
    return nil
end

function DP:RemoveItemFromNote(note, itemId)
    itemId = NormalizeId(itemId)
    local items = self:IterateNoteItems(note)
    for index, item in ipairs(items) do
        if NormalizeId(item.id) == itemId then
            table.remove(items, index)
            note.items = items
            return true
        end
    end
    return false
end

function DP:AppendItemToNote(note, item)
    self:NormalizeNoteItemsArray(note)
    table.insert(note.items, item)
end
