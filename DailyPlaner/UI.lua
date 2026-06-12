local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local FRAME_WIDTH = 320
local FRAME_HEIGHT = 420
local TAB_HEIGHT = 28
local ROW_HEIGHT = 26
local PADDING = 12

local COLORS = {
    bg = { 0.12, 0.10, 0.08, 0.95 },
    border = { 0.55, 0.45, 0.30, 1 },
    tabActive = { 0.28, 0.22, 0.16, 1 },
    tabInactive = { 0.18, 0.15, 0.11, 0.9 },
    tabHover = { 0.24, 0.19, 0.14, 1 },
    text = { 0.92, 0.86, 0.72, 1 },
    textMuted = { 0.65, 0.58, 0.48, 1 },
    accent = { 0.85, 0.72, 0.35, 1 },
    done = { 0.55, 0.52, 0.45, 1 },
}

local function SetBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

local function CreateFontString(parent, size, color, justifyH)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetFontObject(size == "small" and "GameFontNormalSmall" or "GameFontHighlight")
    fs:SetJustifyH(justifyH or "LEFT")
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    return fs
end

function DP:Toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:RefreshUI()
        self.frame:Show()
    end
end

function DP:RefreshUI()
    if not self.frame then
        return
    end
    self:RefreshTabs()
    self:RefreshItems()
end

function DP:RefreshTabs()
    local tabBar = self.tabBar
    local content = self.tabContent

    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local x = 0
    local activeId = self.db.activeNoteId

    for _, note in ipairs(self.db.notes) do
        local tab = CreateFrame("Button", nil, content, "BackdropTemplate")
        tab:SetSize(math.min(110, math.max(70, #note.title * 7 + 20)), TAB_HEIGHT - 4)
        tab:SetPoint("LEFT", content, "LEFT", x, 0)
        x = x + tab:GetWidth() + 4

        local isActive = note.id == activeId
        local bg = isActive and COLORS.tabActive or COLORS.tabInactive
        SetBackdrop(tab, bg, COLORS.border)

        local label = CreateFontString(tab, "small", isActive and COLORS.accent or COLORS.text)
        label:SetPoint("CENTER")
        label:SetText(note.title)
        label:SetWidth(tab:GetWidth() - 8)
        label:SetWordWrap(false)

        tab.noteId = note.id
        tab.label = label

        tab:SetScript("OnEnter", function(btn)
            if btn.noteId ~= self.db.activeNoteId then
                btn:SetBackdropColor(COLORS.tabHover[1], COLORS.tabHover[2], COLORS.tabHover[3], COLORS.tabHover[4])
            end
        end)
        tab:SetScript("OnLeave", function(btn)
            local active = btn.noteId == self.db.activeNoteId
            local c = active and COLORS.tabActive or COLORS.tabInactive
            btn:SetBackdropColor(c[1], c[2], c[3], c[4])
        end)
        tab:SetScript("OnClick", function(btn)
            self:SetActiveNote(btn.noteId)
            self:RefreshUI()
        end)
        tab:SetScript("OnMouseUp", function(btn, button)
            if button == "RightButton" then
                self:ShowTabMenu(btn, note)
            end
        end)
    end

    content:SetWidth(math.max(x, tabBar:GetWidth()))
end

function DP:ShowTabMenu(anchor, note)
    UIDropDownMenu_Initialize(self.tabMenu, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Переименовать"
        info.notCheckable = true
        info.func = function()
            self:ShowRenameDialog(note)
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Удалить вкладку"
        info.notCheckable = true
        info.disabled = #self.db.notes <= 1
        info.func = function()
            if self:DeleteNote(note.id) then
                self:RefreshUI()
            end
        end
        UIDropDownMenu_AddButton(info, level)
    end, "MENU")
    ToggleDropDownMenu(1, nil, self.tabMenu, anchor, 0, 0)
end

function DP:ShowRenameDialog(note)
    if not self.renameFrame then
        local f = CreateFrame("Frame", "DailyPlanerRenameFrame", UIParent, "BackdropTemplate")
        f:SetSize(260, 110)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        SetBackdrop(f, COLORS.bg, COLORS.border)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local title = CreateFontString(f, nil, COLORS.accent)
        title:SetPoint("TOP", 0, -14)
        title:SetText("Переименовать вкладку")

        local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        edit:SetSize(220, 24)
        edit:SetPoint("TOP", 0, -40)
        edit:SetAutoFocus(false)
        f.edit = edit

        local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ok:SetSize(80, 24)
        ok:SetPoint("BOTTOMRIGHT", -16, 14)
        ok:SetText("OK")
        f.ok = ok

        local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        cancel:SetSize(80, 24)
        cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
        cancel:SetText("Отмена")
        cancel:SetScript("OnClick", function() f:Hide() end)

        self.renameFrame = f
    end

    local f = self.renameFrame
    f.noteId = note.id
    f.edit:SetText(note.title)
    f.edit:HighlightText()
    f:Show()
    f.edit:SetFocus()

    f.ok:SetScript("OnClick", function()
        local text = strtrim(f.edit:GetText())
        if text ~= "" then
            self:RenameNote(f.noteId, text)
            self:RefreshUI()
        end
        f:Hide()
    end)

    f.edit:SetScript("OnEnterPressed", function()
        f.ok:Click()
    end)
    f.edit:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
end

function DP:RefreshItems()
    local scroll = self.itemScroll
    local content = self.itemContent

    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local note = self:GetActiveNote()
    if not note then
        return
    end

    local y = 0
    for _, item in ipairs(note.items) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(scroll:GetWidth() - 24, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -y)
        y = y + ROW_HEIGHT

        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(22, 22)
        check:SetPoint("LEFT", 4, 0)
        check:SetChecked(item.done)
        check.itemId = item.id

        check:SetScript("OnClick", function(btn)
            self:ToggleItem(note.id, btn.itemId)
            self:RefreshItems()
        end)

        local label = CreateFontString(row, nil, item.done and COLORS.done or COLORS.text)
        label:SetPoint("LEFT", check, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -28, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText(item.text)
        if item.done then
            label:SetTextColor(COLORS.done[1], COLORS.done[2], COLORS.done[3], 1)
        end

        local del = CreateFrame("Button", nil, row)
        del:SetSize(18, 18)
        del:SetPoint("RIGHT", -4, 0)
        del:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        del:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        del:SetAlpha(0.6)
        del.itemId = item.id
        del:SetScript("OnEnter", function(btn) btn:SetAlpha(1) end)
        del:SetScript("OnLeave", function(btn) btn:SetAlpha(0.6) end)
        del:SetScript("OnClick", function(btn)
            self:DeleteItem(note.id, btn.itemId)
            self:RefreshItems()
        end)
    end

    if #note.items == 0 then
        local empty = CreateFontString(content, "small", COLORS.textMuted)
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetText("Добавьте активность ниже...")
    end

    content:SetHeight(math.max(y, 40))
end

function DP:InitUI()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "DailyPlanerFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SaveFramePosition(frame)
    end)
    f:Hide()

    SetBackdrop(f, COLORS.bg, COLORS.border)
    self:RestoreFramePosition(f)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", -8, -8)
    titleBar:SetHeight(28)

    local title = CreateFontString(titleBar, nil, COLORS.accent)
    title:SetPoint("LEFT", 4, 0)
    title:SetText("Daily Planer")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Tab bar
    local tabBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tabBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -6)
    tabBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -36, -6)
    tabBar:SetHeight(TAB_HEIGHT)
    SetBackdrop(tabBar, COLORS.tabInactive, COLORS.border)

    local tabScroll = CreateFrame("ScrollFrame", nil, tabBar, "UIPanelScrollFrameTemplate")
    tabScroll:SetPoint("TOPLEFT", 4, -2)
    tabScroll:SetPoint("BOTTOMRIGHT", -22, 2)
    tabScroll:SetHorizontalScroll(0)

    local tabContent = CreateFrame("Frame", nil, tabScroll)
    tabContent:SetHeight(TAB_HEIGHT - 6)
    tabScroll:SetScrollChild(tabContent)

    local addTab = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
    addTab:SetSize(28, TAB_HEIGHT - 6)
    addTab:SetPoint("RIGHT", -2, 0)
    SetBackdrop(addTab, COLORS.tabInactive, COLORS.border)
    local addLabel = CreateFontString(addTab, nil, COLORS.accent)
    addLabel:SetPoint("CENTER")
    addLabel:SetText("+")
    addTab:SetScript("OnEnter", function(btn)
        btn:SetBackdropColor(COLORS.tabHover[1], COLORS.tabHover[2], COLORS.tabHover[3], COLORS.tabHover[4])
    end)
    addTab:SetScript("OnLeave", function(btn)
        btn:SetBackdropColor(COLORS.tabInactive[1], COLORS.tabInactive[2], COLORS.tabInactive[3], COLORS.tabInactive[4])
    end)
    addTab:SetScript("OnClick", function()
        self:AddNote()
        self:RefreshUI()
    end)

    self.tabMenu = CreateFrame("Frame", "DailyPlanerTabMenu", f, "UIDropDownMenuTemplate")

    -- Item list
    local listArea = CreateFrame("Frame", nil, f, "BackdropTemplate")
    listArea:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
    listArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, 52)
    SetBackdrop(listArea, { 0.08, 0.07, 0.05, 0.6 }, COLORS.border)

    local itemScroll = CreateFrame("ScrollFrame", nil, listArea, "UIPanelScrollFrameTemplate")
    itemScroll:SetPoint("TOPLEFT", 4, -4)
    itemScroll:SetPoint("BOTTOMRIGHT", -26, 4)

    local itemContent = CreateFrame("Frame", nil, itemScroll)
    itemContent:SetWidth(FRAME_WIDTH - 80)
    itemScroll:SetScrollChild(itemContent)

    -- Add item input
    local inputFrame = CreateFrame("Frame", nil, f)
    inputFrame:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    inputFrame:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    inputFrame:SetHeight(32)

    local input = CreateFrame("EditBox", nil, inputFrame, "InputBoxTemplate")
    input:SetSize(FRAME_WIDTH - 100, 24)
    input:SetPoint("LEFT", 0, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(120)

    local placeholder = CreateFontString(inputFrame, "small", COLORS.textMuted)
    placeholder:SetPoint("LEFT", input, "LEFT", 6, 0)
    placeholder:SetText("Новая активность...")
    placeholder:SetDrawLayer("ARTWORK")

    input:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    input:SetScript("OnEditFocusLost", function()
        if strtrim(input:GetText()) == "" then
            placeholder:Show()
        end
    end)
    input:SetScript("OnTextChanged", function(_, userInput)
        if userInput and strtrim(input:GetText()) ~= "" then
            placeholder:Hide()
        end
    end)

    local addBtn = CreateFrame("Button", nil, inputFrame, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 24)
    addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
    addBtn:SetText("Добавить")

    local function submitItem()
        local note = self:GetActiveNote()
        if not note then
            return
        end
        local text = strtrim(input:GetText())
        if text == "" then
            return
        end
        self:AddItem(note.id, text)
        input:SetText("")
        placeholder:Show()
        input:ClearFocus()
        self:RefreshItems()
    end

    addBtn:SetScript("OnClick", submitItem)
    input:SetScript("OnEnterPressed", submitItem)
    input:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
        edit:SetText("")
        placeholder:Show()
    end)

    self.frame = f
    self.tabBar = tabBar
    self.tabContent = tabContent
    self.itemScroll = itemScroll
    self.itemContent = itemContent
    self.input = input

    self:RefreshUI()
end
