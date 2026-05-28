local defaults = {
    "Soulstone on cooldown?",
    "Ritual of Souls down?",
    "Food buff active?",
    "Wizard oil applied?",
    "Flask active?",
    "Pet Summoned",
    "Enough soul shards?",
    "Focus set?"
}

local checklistFrame
local configFrame
local checklistRows = {}
local configRows = {}

local function CopyDefaults()
    local copy = {}

    for i, item in ipairs(defaults) do
        copy[i] = item
    end

    return copy
end

local function GetCharacterProfileName()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Realm"

    return name .. " - " .. realm
end

local function EnsureRootDB()
    if type(PullCheckDB) ~= "table" then
        PullCheckDB = {}
    end

    if type(PullCheckDB.profiles) ~= "table" then
        PullCheckDB.profiles = {}
    end

    if type(PullCheckCharDB) ~= "table" then
        PullCheckCharDB = {}
    end
end

local function GetCurrentProfileName()
    EnsureRootDB()

    if not PullCheckCharDB.currentProfile or PullCheckCharDB.currentProfile == "" then
        PullCheckCharDB.currentProfile = PullCheckDB.currentProfile or "default"
    end

    return PullCheckCharDB.currentProfile
end

local function SetCurrentProfileName(profileName)
    EnsureRootDB()

    if not profileName or profileName == "" then
        return
    end

    PullCheckCharDB.currentProfile = profileName
    PullCheckDB.currentProfile = profileName

    if type(PullCheckDB.profiles[profileName]) ~= "table" then
        PullCheckDB.profiles[profileName] = {
            items = CopyDefaults()
        }
    end
end

local function DeleteProfile(profileName)
    EnsureRootDB()

    if not profileName or profileName == "" then
        print("PullCheck: no profile selected.")
        return
    end

    if not PullCheckDB.profiles[profileName] then
        print("PullCheck: profile does not exist: " .. profileName)
        return
    end

    PullCheckDB.profiles[profileName] = nil

    local nextProfile = next(PullCheckDB.profiles)

    if not nextProfile then
        PullCheckDB.profiles["default"] = {
            items = CopyDefaults()
        }

        nextProfile = "default"
    end

    SetCurrentProfileName(nextProfile)

    print("PullCheck deleted profile: " .. profileName)
end

local function EnsureDB()
    EnsureRootDB()

    local profileName = GetCurrentProfileName()

    if type(PullCheckDB.profiles[profileName]) ~= "table" then
        PullCheckDB.profiles[profileName] = {
            items = CopyDefaults()
        }
    end

    if type(PullCheckDB.profiles[profileName].items) ~= "table" then
        PullCheckDB.profiles[profileName].items = CopyDefaults()
    end

    return PullCheckDB.profiles[profileName]
end

local function GetItems()
    return EnsureDB().items
end

local function ApplyPanelBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })

    frame:SetBackdropColor(0, 0, 0, 0.95)
end

local function MakeDraggable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

local function AllChecklistRowsHidden()
    for _, row in ipairs(checklistRows) do
        if row:IsShown() then
            return false
        end
    end

    return true
end

local function CreateChecklistFrame()
    checklistFrame = CreateFrame("Frame", "PullCheckChecklistFrame", UIParent, "BackdropTemplate")
    checklistFrame:SetSize(430, 360)
    checklistFrame:SetPoint("CENTER")
    checklistFrame:SetFrameStrata("DIALOG")
    checklistFrame:SetClampedToScreen(true)
    checklistFrame:Hide()

    ApplyPanelBackdrop(checklistFrame)
    MakeDraggable(checklistFrame)

    local title = checklistFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", checklistFrame, "TOP", 0, -18)
    title:SetText("Pre-pull Checklist")

    local closeButton = CreateFrame("Button", nil, checklistFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", checklistFrame, "TOPRIGHT", -6, -6)
    closeButton:SetScript("OnClick", function()
        checklistFrame:Hide()
    end)
end

local function RefreshChecklist()
    if not checklistFrame then
        CreateChecklistFrame()
    end

    local items = GetItems()

    for _, row in ipairs(checklistRows) do
        row:Hide()
    end

    local height = math.max(120, 70 + (#items * 32))
    checklistFrame:SetHeight(height)

    for i, item in ipairs(items) do
        if not checklistRows[i] then
            local row = CreateFrame("Button", nil, checklistFrame)
            row:SetSize(360, 26)

            row.box = row:CreateTexture(nil, "ARTWORK")
            row.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            row.box:SetSize(24, 24)
            row.box:SetPoint("LEFT", row, "LEFT", 0, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.label:SetJustifyH("LEFT")

            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            row:SetScript("OnClick", function(self)
                self:Hide()

                if AllChecklistRowsHidden() then
                    checklistFrame:Hide()
                end
            end)

            checklistRows[i] = row
        end

        local row = checklistRows[i]
        row:SetPoint("TOPLEFT", checklistFrame, "TOPLEFT", 36, -48 - ((i - 1) * 32))
        row.label:SetText(item)
        row:Show()
    end

    checklistFrame:Show()
end

local function RefreshConfigList()
    if not configFrame then
        return
    end

    local items = GetItems()
    local currentProfile = GetCurrentProfileName()

    if configFrame.profileDropdown then
        UIDropDownMenu_SetText(configFrame.profileDropdown, currentProfile)
    end

    for _, row in ipairs(configRows) do
        row:Hide()
    end

    if configFrame.scrollChild then
        configFrame.scrollChild:SetHeight(math.max(1, #items * 30))
    end

    for i, item in ipairs(items) do
        if not configRows[i] then
            local row = CreateFrame("Frame", nil, configFrame.scrollChild)
            row:SetSize(560, 26)

            row.indexText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.indexText:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.indexText:SetWidth(34)
            row.indexText:SetJustifyH("RIGHT")

            row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.itemText:SetPoint("LEFT", row.indexText, "RIGHT", 10, 0)
            row.itemText:SetWidth(420)
            row.itemText:SetJustifyH("LEFT")

            row.deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.deleteButton:SetSize(54, 22)
            row.deleteButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.deleteButton:SetText("Del")

            configRows[i] = row
        end

        local row = configRows[i]
        local index = i

        row:SetPoint("TOPLEFT", configFrame.scrollChild, "TOPLEFT", 0, -((i - 1) * 30))
        row.indexText:SetText(index .. ".")
        row.itemText:SetText(item)

        row.deleteButton:SetScript("OnClick", function()
            table.remove(GetItems(), index)
            RefreshConfigList()
        end)

        row:Show()
    end
end

local function AddItemFromInput()
    if not configFrame then
        return
    end

    local text = configFrame.inputBox:GetText() or ""

    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    if text == "" then
        print("PullCheck: type something to add first.")
        return
    end

    table.insert(GetItems(), text)
    configFrame.inputBox:SetText("")
    RefreshConfigList()

    print("PullCheck added: " .. text)
end

local function ProfileDropDown_Initialize(self, level)
    EnsureDB()

    local names = {}

    for name in pairs(PullCheckDB.profiles) do
        table.insert(names, name)
    end

    table.sort(names)

    for _, name in ipairs(names) do
        local info = UIDropDownMenu_CreateInfo()

        info.text = name
        info.value = name
        info.checked = name == GetCurrentProfileName()

        info.func = function()
            SetCurrentProfileName(name)
            RefreshConfigList()
            CloseDropDownMenus()
        end

        UIDropDownMenu_AddButton(info, level)
    end
end

StaticPopupDialogs["PULLCHECK_DELETE_PROFILE"] = {
    text = "Delete PullCheck profile '%s'?\n\nThis will remove the profile and all checklist items in it.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, profileName)
        DeleteProfile(profileName)
        RefreshConfigList()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

local function ConfirmDeleteProfile(profileName)
    if not profileName or profileName == "" then
        print("PullCheck: no profile selected.")
        return
    end

    StaticPopup_Show("PULLCHECK_DELETE_PROFILE", profileName, nil, profileName)
end

local function CreateConfigFrame()
    configFrame = CreateFrame("Frame", "PullCheckConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(680, 560)
    configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetClampedToScreen(true)
    configFrame:Hide()

    ApplyPanelBackdrop(configFrame)
    MakeDraggable(configFrame)

    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -18)
    title:SetText("PullCheck Options")

    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -6, -6)
    closeButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)

    local profileLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 32, -58)
    profileLabel:SetText("Active profile:")

    configFrame.profileDropdown = CreateFrame("Frame", "PullCheckProfileDropdown", configFrame, "UIDropDownMenuTemplate")
    configFrame.profileDropdown:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 142, -50)

    UIDropDownMenu_SetWidth(configFrame.profileDropdown, 240)
    UIDropDownMenu_Initialize(configFrame.profileDropdown, ProfileDropDown_Initialize)
    UIDropDownMenu_SetText(configFrame.profileDropdown, GetCurrentProfileName())

    local deleteProfileButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    deleteProfileButton:SetSize(130, 24)
    deleteProfileButton:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 500, -58)
    deleteProfileButton:SetText("Delete Profile")

    deleteProfileButton:SetScript("OnClick", function()
        ConfirmDeleteProfile(GetCurrentProfileName())
    end)

    local newProfileLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    newProfileLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 32, -96)
    newProfileLabel:SetText("New profile:")

    configFrame.newProfileBox = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
    configFrame.newProfileBox:SetSize(300, 24)
    configFrame.newProfileBox:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 142, -90)
    configFrame.newProfileBox:SetAutoFocus(false)

    local setProfileButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    setProfileButton:SetSize(70, 24)
    setProfileButton:SetPoint("LEFT", configFrame.newProfileBox, "RIGHT", 14, 0)
    setProfileButton:SetText("Set")

    setProfileButton:SetScript("OnClick", function()
        local text = configFrame.newProfileBox:GetText() or ""
        text = text:gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
            print("PullCheck: enter a profile name first.")
            return
        end

        SetCurrentProfileName(text)
        configFrame.newProfileBox:SetText("")
        RefreshConfigList()
    end)

    configFrame.newProfileBox:SetScript("OnEnterPressed", function()
        setProfileButton:Click()
    end)

    local divider = configFrame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetVertexColor(0.45, 0.45, 0.45, 0.35)
    divider:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 30, -132)
    divider:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -30, -132)
    divider:SetHeight(1)

    local addHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    addHeader:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 32, -152)
    addHeader:SetText("Add checklist item")

    configFrame.inputBox = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
    configFrame.inputBox:SetSize(440, 24)
    configFrame.inputBox:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 36, -184)
    configFrame.inputBox:SetAutoFocus(false)

    configFrame.inputBox:SetScript("OnEnterPressed", function()
        AddItemFromInput()
    end)

    local addButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    addButton:SetSize(82, 24)
    addButton:SetPoint("LEFT", configFrame.inputBox, "RIGHT", 14, 0)
    addButton:SetText("Add +")
    addButton:SetScript("OnClick", function()
        AddItemFromInput()
    end)

    local listHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listHeader:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 32, -224)
    listHeader:SetText("Checklist items")

    configFrame.scrollFrame = CreateFrame("ScrollFrame", "PullCheckItemScrollFrame", configFrame, "UIPanelScrollFrameTemplate")
    configFrame.scrollFrame:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 32, -252)
    configFrame.scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -48, 28)

    configFrame.scrollChild = CreateFrame("Frame", nil, configFrame.scrollFrame)
    configFrame.scrollChild:SetSize(580, 1)

    configFrame.scrollFrame:SetScrollChild(configFrame.scrollChild)
    configFrame.scrollFrame:EnableMouseWheel(true)

    configFrame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = current - (delta * 30)

        if newScroll < 0 then
            newScroll = 0
        elseif newScroll > maxScroll then
            newScroll = maxScroll
        end

        self:SetVerticalScroll(newScroll)
    end)
end

local function ShowConfig()
    if not configFrame then
        CreateConfigFrame()
    end

    RefreshConfigList()
    configFrame:Show()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

local function HidePullCheckFrames()
    if checklistFrame then
        checklistFrame:Hide()
    end

    if configFrame then
        configFrame:Hide()
    end
end

local function ShowPullCheckWithSound()
    RefreshChecklist()

    if PlaySound then
        pcall(PlaySound, 8959)
    end
end

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "READY_CHECK" then
        ShowPullCheckWithSound()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        HidePullCheckFrames()
        return
    end
end)

SLASH_PULLCHECK1 = "/pullcheck"

local function PrintHelp()
    print("PullCheck commands:")
    print("/pullcheck config")
    print("/pullcheck show")
    print("/pullcheck help")
end

SlashCmdList["PULLCHECK"] = function(msg)
    msg = msg or ""

    local command = msg:match("^(%S*)")
    command = string.lower(command or "")

    if command == "" or command == "config" or command == "options" then
        ShowConfig()
        return
    end

    if command == "show" then
        RefreshChecklist()
        return
    end

    if command == "help" then
        PrintHelp()
        return
    end

    PrintHelp()
end