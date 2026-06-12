local ADDON_NAME = ...

DailyPlaner = DailyPlaner or {}
local DP = DailyPlaner

local FRAME_WIDTH = 340
local FRAME_HEIGHT = 440
local HEADER_HEIGHT = 32
local TAB_HEIGHT = 30
local FOOTER_HEIGHT = 46
local ROW_HEIGHT = 30
local PADDING = 14

local COLORS = {
    bg = { 0.10, 0.08, 0.06, 0.97 },
    panel = { 0.06, 0.05, 0.04, 0.85 },
    border = { 0.50, 0.40, 0.28, 1 },
    borderLight = { 0.65, 0.55, 0.38, 0.6 },
    tabActive = { 0.22, 0.18, 0.13, 1 },
    tabInactive = { 0.14, 0.12, 0.09, 0.85 },
    tabHover = { 0.20, 0.16, 0.12, 1 },
    text = { 0.93, 0.88, 0.76, 1 },
    textMuted = { 0.58, 0.52, 0.44, 1 },
    accent = { 0.90, 0.78, 0.38, 1 },
    done = { 0.50, 0.47, 0.42, 1 },
    rowHover = { 1, 1, 1, 0.07 },
    delete = { 0.82, 0.38, 0.38, 1 },
    deleteHover = { 1.0, 0.55, 0.55, 1 },
    inputBg = { 0.04, 0.03, 0.02, 0.9 },
}

local function SetBackdrop(frame, bgColor, borderColor)
    if BackdropTemplateMixin and not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

local function ClearChildren(parent)
    if parent.EnumerateChildren then
        for child in parent:EnumerateChildren() do
            child:Hide()
            child:SetParent(nil)
        end
        return
    end

    local children = { parent:GetChildren() }
    for i = 1, #children do
        children[i]:Hide()
        children[i]:SetParent(nil)
    end
end

local function CreateFontString(parent, size, color, justifyH)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetFontObject(size == "small" and "GameFontNormalSmall" or "GameFontHighlight")
    fs:SetJustifyH(justifyH or "LEFT")
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    return fs
end

local function GetScrollInnerWidth(scroll, fallback)
    local width = scroll:GetWidth()
    if width and width > 40 then
        return width - 8
    end
    return fallback
end

local TAB_SCROLL_STEP = 72
local TAB_ICON_SIZE = 20
local TAB_ICON_PIXEL = 14
local TAB_ICONS_WIDTH = TAB_ICON_SIZE * 2 + 4

local function CreateArrowButton(parent, direction)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, TAB_HEIGHT - 6)

    local tex = direction == "left"
        and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
        or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"

    btn:SetNormalTexture(tex)
    btn:SetPushedTexture(tex)
    btn:SetDisabledTexture(tex)
    local disabled = btn:GetDisabledTexture()
    if disabled then
        disabled:SetDesaturated(true)
    end
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    btn:SetAlpha(0.85)

    return btn
end

local function CreateTabIconButton(parent, display, color, useTexture)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(TAB_ICON_SIZE, TAB_HEIGHT - 6)

    local icon = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    icon:SetPoint("CENTER", 0, 0)

    if useTexture then
        icon:SetText(string.format("|T%s:%d:%d:0:0|t", display, TAB_ICON_PIXEL, TAB_ICON_PIXEL))
    else
        icon:SetFontObject("GameFontNormalLarge")
        icon:SetText(display)
        icon:SetTextColor(color[1], color[2], color[3], 0.85)
        btn:SetScript("OnEnter", function()
            icon:SetTextColor(color[1], color[2], color[3], 1)
        end)
        btn:SetScript("OnLeave", function()
            icon:SetTextColor(color[1], color[2], color[3], 0.85)
        end)
    end

    btn.icon = icon
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local highlight = btn:GetHighlightTexture()
    if highlight then
        highlight:SetAlpha(0.35)
    end

    return btn
end

function DP:UpdateTabScroll(activeLeft, activeWidth)
    if not self.tabStrip or not self.tabContent then
        return
    end

    local stripWidth = self.tabStrip:GetWidth()
    local contentWidth = self.tabContent:GetWidth()
    local maxScroll = math.max(0, contentWidth - stripWidth)
    self.tabScrollOffset = self.tabScrollOffset or 0

    if activeLeft and activeWidth then
        local activeRight = activeLeft + activeWidth
        if activeLeft < self.tabScrollOffset then
            self.tabScrollOffset = activeLeft
        elseif activeRight > self.tabScrollOffset + stripWidth then
            self.tabScrollOffset = activeRight - stripWidth
        end
    end

    self.tabScrollOffset = math.max(0, math.min(self.tabScrollOffset, maxScroll))

    self.tabContent:ClearAllPoints()
    self.tabContent:SetPoint("TOPLEFT", self.tabStrip, "TOPLEFT", -self.tabScrollOffset, 0)

    local canScroll = maxScroll > 0
    self.tabScrollLeft:SetShown(canScroll)
    self.tabScrollRight:SetShown(canScroll)
    self.tabScrollLeft:SetEnabled(self.tabScrollOffset > 0.5)
    self.tabScrollRight:SetEnabled(self.tabScrollOffset < maxScroll - 0.5)
end

function DP:ScrollTabs(delta)
    if not self.tabStrip or not self.tabContent then
        return
    end

    local maxScroll = math.max(0, self.tabContent:GetWidth() - self.tabStrip:GetWidth())
    self.tabScrollOffset = math.max(0, math.min((self.tabScrollOffset or 0) + delta, maxScroll))
    self:UpdateTabScroll()
end

local function UpdateScrollBar(scroll, content)
    local scrollBar = scroll.ScrollBar
    if not scrollBar then
        return
    end

    local needsScroll = content:GetHeight() > scroll:GetHeight() + 2
    if needsScroll then
        scrollBar:Show()
        scroll:SetPoint("BOTTOMRIGHT", -22, 6)
    else
        scrollBar:Hide()
        scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        scroll:SetVerticalScroll(0)
    end
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
    self:UpdateSubtitle()
end

function DP:UpdateSubtitle()
    if not self.subtitle then
        return
    end

    local note = self:GetActiveNote()
    if not note then
        self.subtitle:SetText("")
        return
    end

    local total = #note.items
    local done = 0
    for _, item in ipairs(note.items) do
        if item.done then
            done = done + 1
        end
    end

    if total == 0 then
        self.subtitle:SetText("нет активностей")
    else
        self.subtitle:SetText(string.format("%d / %d выполнено", done, total))
    end
end

function DP:RefreshTabs()
    local content = self.tabContent
    ClearChildren(content)

    local x = 0
    local activeId = self.db.activeNoteId
    local activeLeft, activeWidth

    for _, note in ipairs(self.db.notes) do
        local titleWidth = math.min(110, math.max(40, (#note.title * 6.5)))
        local tabWidth = titleWidth + TAB_ICONS_WIDTH + 10

        local tab = CreateFrame("Frame", nil, content)
        tab:SetSize(tabWidth, TAB_HEIGHT - 6)
        tab:SetPoint("TOPLEFT", x, 0)

        local isActive = note.id == activeId
        if isActive then
            activeLeft = x
            activeWidth = tabWidth
        end

        x = x + tabWidth + 2

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        local c = isActive and COLORS.tabActive or COLORS.tabInactive
        bg:SetColorTexture(c[1], c[2], c[3], c[4])

        local border = tab:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT")
        border:SetPoint("TOPRIGHT")
        border:SetHeight(1)
        border:SetColorTexture(COLORS.borderLight[1], COLORS.borderLight[2], COLORS.borderLight[3], 0.5)

        local underline = tab:CreateTexture(nil, "OVERLAY")
        underline:SetHeight(2)
        underline:SetPoint("BOTTOMLEFT", 6, 1)
        underline:SetPoint("BOTTOMRIGHT", -6, 1)
        underline:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], isActive and 1 or 0)

        local delBtn = CreateTabIconButton(tab, "×", COLORS.delete, false)
        delBtn:SetPoint("RIGHT", -2, 0)
        delBtn:SetEnabled(#self.db.notes > 1)
        if not delBtn:IsEnabled() then
            delBtn.icon:SetTextColor(COLORS.textMuted[1], COLORS.textMuted[2], COLORS.textMuted[3], 0.5)
        end
        delBtn:SetScript("OnClick", function()
            if self:DeleteNote(note.id) then
                self:RefreshUI()
            end
        end)

        local renameBtn = CreateTabIconButton(
            tab,
            "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
            COLORS.accent,
            true
        )
        renameBtn:SetPoint("RIGHT", delBtn, "LEFT", 0, 0)
        renameBtn:SetScript("OnClick", function()
            self:ShowRenameDialog(note)
        end)

        local selectBtn = CreateFrame("Button", nil, tab)
        selectBtn:SetPoint("TOPLEFT", 0, 0)
        selectBtn:SetPoint("BOTTOMLEFT", 0, 0)
        selectBtn:SetPoint("RIGHT", renameBtn, "LEFT", -2, 0)
        selectBtn:RegisterForClicks("LeftButtonUp")

        local label = CreateFontString(selectBtn, "small", isActive and COLORS.accent or COLORS.text, "LEFT")
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", -4, 0)
        label:SetMaxLines(1)
        label:SetText(note.title)

        tab.noteId = note.id
        tab.bg = bg

        selectBtn:SetScript("OnClick", function()
            self:SetActiveNote(note.id)
            self:RefreshUI()
        end)
        selectBtn:SetScript("OnEnter", function()
            if note.id ~= self.db.activeNoteId then
                bg:SetColorTexture(COLORS.tabHover[1], COLORS.tabHover[2], COLORS.tabHover[3], COLORS.tabHover[4])
            end
        end)
        selectBtn:SetScript("OnLeave", function()
            local active = note.id == self.db.activeNoteId
            local color = active and COLORS.tabActive or COLORS.tabInactive
            bg:SetColorTexture(color[1], color[2], color[3], color[4])
        end)
    end

    content:SetWidth(math.max(x, 1))
    content:SetHeight(TAB_HEIGHT - 6)
    self:UpdateTabScroll(activeLeft, activeWidth)
end

function DP:ShowRenameDialog(note)
    if not self.renameFrame then
        local f = CreateFrame("Frame", "DailyPlanerRenameFrame", UIParent, "BackdropTemplate")
        f:SetSize(280, 118)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        SetBackdrop(f, COLORS.bg, COLORS.border)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local title = CreateFontString(f, nil, COLORS.accent)
        title:SetPoint("TOP", 0, -16)
        title:SetText("Переименовать вкладку")

        local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        edit:SetSize(236, 24)
        edit:SetPoint("TOP", 0, -44)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(24)
        f.edit = edit

        local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ok:SetSize(84, 26)
        ok:SetPoint("BOTTOMRIGHT", -16, 14)
        ok:SetText("OK")
        f.ok = ok

        local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        cancel:SetSize(84, 26)
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
    ClearChildren(content)

    local note = self:GetActiveNote()
    if not note then
        return
    end

    local innerWidth = GetScrollInnerWidth(scroll, FRAME_WIDTH - PADDING * 2 - 36)
    content:SetWidth(innerWidth)

    local y = 4
    for _, item in ipairs(note.items) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(innerWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -y)
        row:EnableMouse(true)
        y = y + ROW_HEIGHT + 2

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        rowBg:SetColorTexture(0, 0, 0, 0)

        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT", 6, 0)
        check:SetChecked(item.done)
        check.itemId = item.id
        check:SetScript("OnClick", function(btn)
            self:ToggleItem(note.id, btn.itemId)
            self:RefreshUI()
        end)

        local label = CreateFontString(row, nil, item.done and COLORS.done or COLORS.text)
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -36, 0)
        label:SetJustifyH("LEFT")
        label:SetMaxLines(1)
        label:SetText(item.text)
        if item.done then
            label:SetTextColor(COLORS.done[1], COLORS.done[2], COLORS.done[3], 1)
        end

        local del = CreateFrame("Button", nil, row)
        del:SetSize(32, ROW_HEIGHT)
        del:SetPoint("RIGHT", -2, 0)
        del.itemId = item.id

        local delBg = del:CreateTexture(nil, "BACKGROUND")
        delBg:SetPoint("TOPLEFT", 4, -3)
        delBg:SetPoint("BOTTOMRIGHT", -4, 3)
        delBg:SetColorTexture(0, 0, 0, 0)

        local delIcon = del:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        delIcon:SetPoint("CENTER", 0, 1)
        delIcon:SetText("×")
        delIcon:SetTextColor(COLORS.delete[1], COLORS.delete[2], COLORS.delete[3], 0.55)

        del:SetScript("OnClick", function(btn)
            self:DeleteItem(note.id, btn.itemId)
            self:RefreshUI()
        end)

        local function setRowHover(hovered)
            if hovered then
                rowBg:SetColorTexture(COLORS.rowHover[1], COLORS.rowHover[2], COLORS.rowHover[3], COLORS.rowHover[4])
                delBg:SetColorTexture(1, 1, 1, 0.08)
                delIcon:SetTextColor(COLORS.deleteHover[1], COLORS.deleteHover[2], COLORS.deleteHover[3], 1)
            else
                rowBg:SetColorTexture(0, 0, 0, 0)
                delBg:SetColorTexture(0, 0, 0, 0)
                delIcon:SetTextColor(COLORS.delete[1], COLORS.delete[2], COLORS.delete[3], 0.55)
            end
        end

        row:SetScript("OnEnter", function()
            setRowHover(true)
        end)
        row:SetScript("OnLeave", function()
            setRowHover(false)
        end)
        del:SetScript("OnEnter", function()
            setRowHover(true)
        end)
        del:SetScript("OnLeave", function()
            setRowHover(false)
        end)
    end

    if #note.items == 0 then
        local empty = CreateFontString(content, "small", COLORS.textMuted, "CENTER")
        empty:SetPoint("TOP", 0, -48)
        empty:SetWidth(innerWidth - 16)
        empty:SetText("Список пуст.\nДобавьте активность в поле ниже.")
    end

    content:SetHeight(math.max(y + 8, scroll:GetHeight()))
    UpdateScrollBar(scroll, content)
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
    f:Hide()

    SetBackdrop(f, COLORS.bg, COLORS.border)
    self:RestoreFramePosition(f)

    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetPoint("TOPRIGHT", -PADDING, -PADDING)
    header:SetHeight(HEADER_HEIGHT)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        f:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        self:SaveFramePosition(f)
    end)

    local title = CreateFontString(header, nil, COLORS.accent)
    title:SetPoint("TOPLEFT", 2, -2)
    title:SetText("Daily Planer")

    local subtitle = CreateFontString(header, "small", COLORS.textMuted)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("")
    self.subtitle = subtitle

    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 4, 4)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Tab bar
    local tabBar = CreateFrame("Frame", nil, f)
    tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -10)
    tabBar:SetHeight(TAB_HEIGHT)

    local addTab = CreateFrame("Button", nil, tabBar)
    addTab:SetSize(28, TAB_HEIGHT - 6)
    addTab:SetPoint("TOPRIGHT", 0, 0)

    local tabScrollRight = CreateArrowButton(tabBar, "right")
    tabScrollRight:SetPoint("RIGHT", addTab, "LEFT", -4, 0)
    tabScrollRight:Hide()

    local tabScrollLeft = CreateArrowButton(tabBar, "left")
    tabScrollLeft:SetPoint("TOPLEFT", 0, 0)
    tabScrollLeft:Hide()

    local tabStrip = CreateFrame("Frame", nil, tabBar)
    tabStrip:SetPoint("TOPLEFT", tabScrollLeft, "TOPRIGHT", 4, 0)
    tabStrip:SetPoint("BOTTOMLEFT", tabScrollLeft, "BOTTOMRIGHT", 4, 0)
    tabStrip:SetPoint("RIGHT", tabScrollRight, "LEFT", -4, 0)
    tabStrip:SetClipsChildren(true)
    tabStrip:EnableMouseWheel(true)
    tabStrip:SetScript("OnMouseWheel", function(_, delta)
        self:ScrollTabs(-delta * 24)
    end)

    local tabContent = CreateFrame("Frame", nil, tabStrip)
    tabContent:SetPoint("TOPLEFT", 0, 0)
    tabContent:SetHeight(TAB_HEIGHT - 6)

    tabScrollLeft:SetScript("OnClick", function()
        self:ScrollTabs(-TAB_SCROLL_STEP)
    end)
    tabScrollRight:SetScript("OnClick", function()
        self:ScrollTabs(TAB_SCROLL_STEP)
    end)

    self.tabScrollOffset = 0
    self.tabScrollLeft = tabScrollLeft
    self.tabScrollRight = tabScrollRight
    self.tabStrip = tabStrip

    local tabSeparator = tabBar:CreateTexture(nil, "ARTWORK")
    tabSeparator:SetHeight(1)
    tabSeparator:SetPoint("BOTTOMLEFT", 0, 0)
    tabSeparator:SetPoint("BOTTOMRIGHT", 0, 0)
    tabSeparator:SetColorTexture(COLORS.borderLight[1], COLORS.borderLight[2], COLORS.borderLight[3], 0.45)

    local addBg = addTab:CreateTexture(nil, "BACKGROUND")
    addBg:SetAllPoints()
    addBg:SetColorTexture(COLORS.tabInactive[1], COLORS.tabInactive[2], COLORS.tabInactive[3], COLORS.tabInactive[4])

    local addLabel = CreateFontString(addTab, nil, COLORS.accent, "CENTER")
    addLabel:SetPoint("CENTER")
    addLabel:SetText("+")

    addTab:SetScript("OnEnter", function()
        addBg:SetColorTexture(COLORS.tabHover[1], COLORS.tabHover[2], COLORS.tabHover[3], COLORS.tabHover[4])
    end)
    addTab:SetScript("OnLeave", function()
        addBg:SetColorTexture(COLORS.tabInactive[1], COLORS.tabInactive[2], COLORS.tabInactive[3], COLORS.tabInactive[4])
    end)
    addTab:SetScript("OnClick", function()
        local note = self:AddNote()
        self:RefreshUI()
        self:ShowRenameDialog(note)
    end)

    -- List
    local listArea = CreateFrame("Frame", nil, f, "BackdropTemplate")
    listArea:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    listArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, FOOTER_HEIGHT + PADDING)
    SetBackdrop(listArea, COLORS.panel, COLORS.border)

    local itemScroll = CreateFrame("ScrollFrame", nil, listArea, "UIPanelScrollFrameTemplate")
    itemScroll:SetPoint("TOPLEFT", 6, -6)
    itemScroll:SetPoint("BOTTOMRIGHT", -6, 6)

    local itemContent = CreateFrame("Frame", nil, itemScroll)
    itemScroll:SetScrollChild(itemContent)

    if itemScroll.ScrollBar then
        itemScroll.ScrollBar:SetWidth(10)
    end

    -- Footer
    local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    footer:SetHeight(FOOTER_HEIGHT - 8)
    SetBackdrop(footer, COLORS.inputBg, COLORS.border)

    local input = CreateFrame("EditBox", nil, footer, "InputBoxTemplate")
    input:SetPoint("LEFT", 12, 0)
    input:SetPoint("RIGHT", footer, "RIGHT", -92, 0)
    input:SetHeight(24)
    input:SetAutoFocus(false)
    input:SetMaxLetters(120)

    local placeholder = CreateFontString(footer, "small", COLORS.textMuted)
    placeholder:SetPoint("LEFT", input, "LEFT", 4, 0)
    placeholder:SetText("Новая активность...")
    placeholder:SetDrawLayer("ARTWORK")

    input:SetScript("OnEditFocusGained", function()
        placeholder:Hide()
    end)
    input:SetScript("OnEditFocusLost", function()
        if strtrim(input:GetText()) == "" then
            placeholder:Show()
        end
    end)
    input:SetScript("OnTextChanged", function(_, userInput)
        if userInput and strtrim(input:GetText()) ~= "" then
            placeholder:Hide()
        elseif strtrim(input:GetText()) == "" and not input:HasFocus() then
            placeholder:Show()
        end
    end)

    local addBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    addBtn:SetSize(76, 26)
    addBtn:SetPoint("RIGHT", -10, 0)
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
        self:RefreshUI()
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
    self.tabStrip = tabStrip
    self.tabContent = tabContent
    self.itemScroll = itemScroll
    self.itemContent = itemContent
    self.input = input

    self:RefreshUI()
end
