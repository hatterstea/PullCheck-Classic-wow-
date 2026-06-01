--pullcheck.lua--
local defaults = {
    "Soulstone on cooldown?",
    "Ritual of Souls down?",
    "Food buff active?",
    "Wizard oil applied?",
    "Flask active?",
    "Pet Summoned",
    "Focus set?"
}

local checklistFrame
local configFrame
local itemEditorFrame

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

local function GetItemText(item)
    if type(item) == "table" then
        return item.text or ""
    end

    return item or ""
end

local function GetItemTrackingType(item)
    if type(item) == "table" then
        return item.trackType or "manual"
    end

    return "manual"
end

local function GetItemTrackingLabel(item)
    local trackType = GetItemTrackingType(item)

    if trackType == "spellID" then
        return "[Spell ID]"
    end

    if trackType == "preset" then
        return "[Preset]"
    end

    return "[Manual]"
end

local function GetItemSpellID(item)
    if type(item) == "table" then
        return item.spellID
    end

    return nil
end

local function GetActivePresets()
    return PullCheckPresets_TBC or {}
end

local function GetPresetByKey(presetKey)
    if not presetKey then
        return nil
    end

    return GetActivePresets()[presetKey]
end

local function GetFirstPresetKey()
    local keys = {}

    for key in pairs(GetActivePresets()) do
        table.insert(keys, key)
    end

    table.sort(keys)

    return keys[1]
end

local function GetItemPresetKey(item)
    if type(item) == "table" then
        return item.presetKey
    end

    return nil
end

local function GetSpellIconByID(spellID)
    spellID = tonumber(spellID)

    if not spellID then
        return nil
    end

    local name, rank, icon = GetSpellInfo(spellID)

    if icon then
        return icon
    end

    return nil
end

local function FormatTimeRemaining(seconds)
    if not seconds then
        return ""
    end

    seconds = math.max(0, math.floor(seconds + 0.5))

    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)

        return string.format("%dh %02dm", hours, minutes)
    end

    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        local remainingSeconds = seconds % 60

        return string.format("%dm %02ds", minutes, remainingSeconds)
    end

    return seconds .. "s"
end

local function GetPlayerAuraInfoBySpellID(spellID)
    spellID = tonumber(spellID)

    if not spellID then
        return {
            found = false,
            icon = nil,
            remaining = nil
        }
    end

    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, auraSpellID = UnitAura("player", i, "HELPFUL")

        if not name then
            break
        end

        if auraSpellID == spellID then
            local remaining = nil

            if expirationTime and expirationTime > 0 then
                remaining = expirationTime - GetTime()
            end

            return {
                found = true,
                icon = icon or GetSpellIconByID(spellID),
                duration = duration,
                expirationTime = expirationTime,
                remaining = remaining
            }
        end
    end

    return {
        found = false,
        icon = GetSpellIconByID(spellID),
        remaining = nil
    }
end

local function PlayerHasAuraBySpellID(spellID)
    return GetPlayerAuraInfoBySpellID(spellID).found
end

local function IsTrackedItemComplete(item)
    local trackType = GetItemTrackingType(item)

    if trackType == "spellID" then
        return PlayerHasAuraBySpellID(GetItemSpellID(item))
    end

    if trackType == "preset" then
        local preset = GetPresetByKey(GetItemPresetKey(item))

        if not preset or type(preset.spellIDs) ~= "table" then
            return false
        end

        for _, spellID in ipairs(preset.spellIDs) do
            if PlayerHasAuraBySpellID(spellID) then
                return true
            end
        end
    end

    return false
end

local function AllChecklistItemsResolved()
    local items = GetItems()

    for i, item in ipairs(items) do
        if IsTrackedItemComplete(item) then
            -- tracked item is complete
        elseif checklistRows[i] and not checklistRows[i]:IsShown() then
            -- manual item was clicked off
        else
            return false
        end
    end

    return true
end

local function UpdateChecklistVisuals()
    local items = GetItems()

    for i, item in ipairs(items) do
        local row = checklistRows[i]

        if row then
            local trackType = GetItemTrackingType(item)

            row.label:SetText(GetItemText(item))
            row.timeText:SetText("")
            row.icon:Hide()

            row.label:ClearAllPoints()

            if trackType == "spellID" or trackType == "preset" then
                local auraInfo

                if trackType == "preset" then
                    local preset = GetPresetByKey(GetItemPresetKey(item))

                    auraInfo = {
                        found = false,
                        icon = nil,
                        remaining = nil
                    }

                    if preset and type(preset.spellIDs) == "table" then
                        for _, spellID in ipairs(preset.spellIDs) do
                            local testAura = GetPlayerAuraInfoBySpellID(spellID)

                            if testAura.icon and not auraInfo.icon then
                                auraInfo.icon = testAura.icon
                            end

                            if testAura.found then
                                auraInfo = testAura
                                break
                            end
                        end
                    end
                else
                    auraInfo = GetPlayerAuraInfoBySpellID(GetItemSpellID(item))
                end

                if auraInfo.icon then
                    row.icon:SetTexture(auraInfo.icon)
                    row.icon:Show()
                    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                else
                    row.label:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
                end

                row.label:SetPoint("RIGHT", row.timeText, "LEFT", -8, 0)

                if auraInfo.found then
                    row.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                    row.label:SetTextColor(0.2, 1, 0.2)

                    if auraInfo.remaining then
                        row.timeText:SetText(FormatTimeRemaining(auraInfo.remaining))
                        row.timeText:SetTextColor(0.2, 1, 0.2)
                    else
                        row.timeText:SetText("active")
                        row.timeText:SetTextColor(0.2, 1, 0.2)
                    end
                else
                    row.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
                    row.label:SetTextColor(1, 0.25, 0.25)
                    row.timeText:SetText("missing")
                    row.timeText:SetTextColor(1, 0.25, 0.25)
                end
            else
                row.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
                row.label:SetTextColor(1, 1, 1)
                row.label:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
                row.label:SetPoint("RIGHT", row.timeText, "LEFT", -8, 0)
            end
        end
    end
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

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
            row.icon:Hide()

            row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.timeText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.timeText:SetWidth(72)
            row.timeText:SetJustifyH("RIGHT")
            row.timeText:SetText("")

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
            row.label:SetPoint("RIGHT", row.timeText, "LEFT", -8, 0)
            row.label:SetJustifyH("LEFT")

            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            row:SetScript("OnClick", function(self)
                self:Hide()

                if AllChecklistItemsResolved() then
                    checklistFrame:Hide()
                end
            end)

            checklistRows[i] = row
        end

        local row = checklistRows[i]
        row:SetPoint("TOPLEFT", checklistFrame, "TOPLEFT", 36, -48 - ((i - 1) * 32))

        row:Show()
    end

    UpdateChecklistVisuals()
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

            row.typeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.typeText:SetPoint("LEFT", row.indexText, "RIGHT", 10, 0)
            row.typeText:SetWidth(72)
            row.typeText:SetJustifyH("LEFT")

            row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.itemText:SetPoint("LEFT", row.typeText, "RIGHT", 8, 0)
            row.itemText:SetWidth(270)
            row.itemText:SetJustifyH("LEFT")

            row.spellIDText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.spellIDText:SetPoint("LEFT", row.itemText, "RIGHT", 10, 0)
            row.spellIDText:SetWidth(90)
            row.spellIDText:SetJustifyH("LEFT")

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
        row.typeText:SetText(GetItemTrackingLabel(item))
        row.itemText:SetText(GetItemText(item))

        local trackType = GetItemTrackingType(item)
        local spellID = GetItemSpellID(item)

        if spellID then
            row.spellIDText:SetText("ID: " .. spellID)
        elseif trackType == "preset" then
            local preset = GetPresetByKey(GetItemPresetKey(item))

            if preset then
                row.spellIDText:SetText(preset.name)
            else
                row.spellIDText:SetText("No preset")
            end
        else
            row.spellIDText:SetText("")
        end

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

local function PresetDropDown_Initialize(self, level)
    local presets = GetActivePresets()
    local keys = {}

    for key in pairs(presets) do
        table.insert(keys, key)
    end

    table.sort(keys)

    for _, key in ipairs(keys) do
        local preset = presets[key]
        local info = UIDropDownMenu_CreateInfo()

        info.text = preset.name or key
        info.value = key
        info.checked = itemEditorFrame and itemEditorFrame.selectedPresetKey == key

        info.func = function()
            itemEditorFrame.selectedPresetKey = key
            UIDropDownMenu_SetText(itemEditorFrame.presetDropdown, preset.name or key)
            CloseDropDownMenus()
        end

        UIDropDownMenu_AddButton(info, level)
    end
end

local function CreateItemEditorFrame()
    itemEditorFrame = CreateFrame("Frame", "PullCheckItemEditorFrame", UIParent, "BackdropTemplate")
    itemEditorFrame:SetSize(430, 320)
    itemEditorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 90)
    itemEditorFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    itemEditorFrame:SetFrameLevel(100)
    itemEditorFrame:SetToplevel(true)
    itemEditorFrame:SetClampedToScreen(true)
    itemEditorFrame:Hide()

    ApplyPanelBackdrop(itemEditorFrame)

    itemEditorFrame:SetBackdropColor(0, 0, 0, 1)
    itemEditorFrame:SetBackdropBorderColor(1, 1, 1, 0.85)

    itemEditorFrame.opaqueBackground = itemEditorFrame:CreateTexture(nil, "BACKGROUND")
    itemEditorFrame.opaqueBackground:SetTexture("Interface\\Buttons\\WHITE8x8")
    itemEditorFrame.opaqueBackground:SetVertexColor(0, 0, 0, 0.96)
    itemEditorFrame.opaqueBackground:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 12, -12)
    itemEditorFrame.opaqueBackground:SetPoint("BOTTOMRIGHT", itemEditorFrame, "BOTTOMRIGHT", -12, 12)

    MakeDraggable(itemEditorFrame)

    local title = itemEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", itemEditorFrame, "TOP", 0, -18)
    title:SetText("New Checklist Item")

    local closeButton = CreateFrame("Button", nil, itemEditorFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", itemEditorFrame, "TOPRIGHT", -6, -6)
    closeButton:SetScript("OnClick", function()
        itemEditorFrame:Hide()
    end)

    local nameLabel = itemEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 32, -60)
    nameLabel:SetText("Name:")

    itemEditorFrame.nameBox = CreateFrame("EditBox", nil, itemEditorFrame, "InputBoxTemplate")
    itemEditorFrame.nameBox:SetSize(300, 24)
    itemEditorFrame.nameBox:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 92, -54)
    itemEditorFrame.nameBox:SetAutoFocus(false)

    local trackingLabel = itemEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    trackingLabel:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 32, -100)
    trackingLabel:SetText("Tracking:")

    local SetTrackingMode

    local function CreateTrackingOption(label, yOffset)
        local button = CreateFrame("CheckButton", nil, itemEditorFrame, "UICheckButtonTemplate")
        button:SetSize(24, 24)
        button:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 112, yOffset)

        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.label:SetPoint("LEFT", button, "RIGHT", 4, 0)
        button.label:SetText(label)

        return button
    end

    itemEditorFrame.manualOption = CreateTrackingOption("Manual", -94)
    itemEditorFrame.spellIDOption = CreateTrackingOption("Spell ID", -124)
    itemEditorFrame.presetOption = CreateTrackingOption("Preset", -154)

    local spellIDLabel = itemEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellIDLabel:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 132, -190)
    spellIDLabel:SetText("Spell ID:")

    itemEditorFrame.spellIDBox = CreateFrame("EditBox", nil, itemEditorFrame, "InputBoxTemplate")
    itemEditorFrame.spellIDBox:SetSize(160, 24)
    itemEditorFrame.spellIDBox:SetPoint("LEFT", spellIDLabel, "RIGHT", 10, 0)
    itemEditorFrame.spellIDBox:SetAutoFocus(false)

    itemEditorFrame.presetDropdown = CreateFrame("Frame", "PullCheckPresetDropdown", itemEditorFrame, "UIDropDownMenuTemplate")
    itemEditorFrame.presetDropdown:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 112, -182)
    UIDropDownMenu_SetWidth(itemEditorFrame.presetDropdown, 220)
    UIDropDownMenu_Initialize(itemEditorFrame.presetDropdown, PresetDropDown_Initialize)
    itemEditorFrame.presetDropdown:Hide()

    local presetNote = itemEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    presetNote:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 132, -214)
    presetNote:SetWidth(250)
    presetNote:SetJustifyH("LEFT")
    presetNote:SetText("")

    local modeNote = itemEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    modeNote:SetPoint("TOPLEFT", itemEditorFrame, "TOPLEFT", 32, -226)
    modeNote:SetWidth(360)
    modeNote:SetJustifyH("LEFT")

    SetTrackingMode = function(mode)
        itemEditorFrame.trackingMode = mode

        itemEditorFrame.manualOption:SetChecked(mode == "manual")
        itemEditorFrame.spellIDOption:SetChecked(mode == "spellID")
        itemEditorFrame.presetOption:SetChecked(mode == "preset")

        if mode == "spellID" then
            spellIDLabel:Show()
            itemEditorFrame.spellIDBox:Show()
            itemEditorFrame.presetDropdown:Hide()
            presetNote:Hide()
        elseif mode == "preset" then
            spellIDLabel:Hide()
            itemEditorFrame.spellIDBox:Hide()

            itemEditorFrame.presetDropdown:Show()

            local presetKey = itemEditorFrame.selectedPresetKey or GetFirstPresetKey()
            itemEditorFrame.selectedPresetKey = presetKey

            local preset = GetPresetByKey(presetKey)

            if preset then
                UIDropDownMenu_SetText(itemEditorFrame.presetDropdown, preset.name or presetKey)
                presetNote:SetText("")
            else
                UIDropDownMenu_SetText(itemEditorFrame.presetDropdown, "No presets found")
                presetNote:SetText("No presets are currently loaded.")
            end

            presetNote:Show()
            modeNote:SetText("Preset items use built-in spell IDs from the loaded preset file.")
        else
            spellIDLabel:Hide()
            itemEditorFrame.spellIDBox:Hide()
            itemEditorFrame.presetDropdown:Hide()
            presetNote:Hide()
            modeNote:SetText("Manual items are checked off by clicking them in the checklist.")
        end
    end

    itemEditorFrame.manualOption:SetScript("OnClick", function()
        SetTrackingMode("manual")
    end)

    itemEditorFrame.spellIDOption:SetScript("OnClick", function()
        SetTrackingMode("spellID")
    end)

    itemEditorFrame.presetOption:SetScript("OnClick", function()
        SetTrackingMode("preset")
    end)

    itemEditorFrame.SetTrackingMode = SetTrackingMode
    SetTrackingMode("manual")

    local saveButton = CreateFrame("Button", nil, itemEditorFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(90, 24)
    saveButton:SetPoint("BOTTOMRIGHT", itemEditorFrame, "BOTTOMRIGHT", -116, 28)
    saveButton:SetText("Save")

    local cancelButton = CreateFrame("Button", nil, itemEditorFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(90, 24)
    cancelButton:SetPoint("LEFT", saveButton, "RIGHT", 12, 0)
    cancelButton:SetText("Cancel")

    cancelButton:SetScript("OnClick", function()
        itemEditorFrame:Hide()
    end)

    saveButton:SetScript("OnClick", function()
        local text = itemEditorFrame.nameBox:GetText() or ""
        text = text:gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
            print("PullCheck: item name cannot be blank.")
            return
        end

        local trackType = itemEditorFrame.trackingMode or "manual"

        local newItem = {
            text = text,
            trackType = trackType
        }

        if trackType == "spellID" then
            local spellIDText = ""

            if itemEditorFrame.spellIDBox then
                spellIDText = itemEditorFrame.spellIDBox:GetText() or ""
            end

            spellIDText = spellIDText:gsub("^%s+", ""):gsub("%s+$", "")

            local spellID = tonumber(spellIDText)

            if not spellID then
                print("PullCheck: enter a valid Spell ID.")
                return
            end

            newItem.spellID = spellID
        end

        if trackType == "preset" then
            local presetKey = itemEditorFrame.selectedPresetKey or GetFirstPresetKey()

            if not presetKey or not GetPresetByKey(presetKey) then
                print("PullCheck: choose a valid preset.")
                return
            end

            newItem.presetKey = presetKey
        end

        table.insert(GetItems(), newItem)

        itemEditorFrame:Hide()
        RefreshConfigList()

        print("PullCheck added: " .. text)
    end)

    itemEditorFrame.nameBox:SetScript("OnEnterPressed", function()
        saveButton:Click()
    end)
end

local function ShowItemEditor(text)
    if not itemEditorFrame then
        CreateItemEditorFrame()
    end

    itemEditorFrame.nameBox:SetText(text or "")
    itemEditorFrame.nameBox:HighlightText()

    if itemEditorFrame.spellIDBox then
        itemEditorFrame.spellIDBox:SetText("")
    end

    itemEditorFrame.selectedPresetKey = GetFirstPresetKey()

    if itemEditorFrame.presetDropdown then
        local preset = GetPresetByKey(itemEditorFrame.selectedPresetKey)

        if preset then
            UIDropDownMenu_SetText(itemEditorFrame.presetDropdown, preset.name)
        else
            UIDropDownMenu_SetText(itemEditorFrame.presetDropdown, "No presets found")
        end
    end
    
    if itemEditorFrame.SetTrackingMode then
        itemEditorFrame.SetTrackingMode("manual")
    end

    if configFrame then
        itemEditorFrame:SetFrameLevel(configFrame:GetFrameLevel() + 20)
    end

    itemEditorFrame:Show()
    itemEditorFrame.nameBox:SetFocus()
end

local function OpenItemEditorFromInput()
    if not configFrame then
        return
    end

    local text = configFrame.inputBox:GetText() or ""
    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    if text == "" then
        print("PullCheck: type something to add first.")
        return
    end

    ShowItemEditor(text)
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

    local checklistHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    checklistHeader:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 32, -152)
    checklistHeader:SetText("Checklist items")

    local addButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    addButton:SetSize(180, 28)
    addButton:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 36, -184)
    addButton:SetText("Add Checklist Item")

    addButton:SetScript("OnClick", function()
        ShowItemEditor("")
    end)

    local typeHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    typeHeader:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 76, -224)
    typeHeader:SetText("Type")

    local itemHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    itemHeader:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 156, -224)
    itemHeader:SetText("Item")

    local spellIDHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    spellIDHeader:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 500, -224)
    spellIDHeader:SetText("Details")

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
eventFrame:RegisterEvent("UNIT_AURA")

local function HidePullCheckFrames()
    if checklistFrame then
        checklistFrame:Hide()
    end

    if configFrame then
        configFrame:Hide()
    end
end

local function ShowPullCheckWithSound()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    RefreshChecklist()

    if PlaySound then
        pcall(PlaySound, 8959)
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "READY_CHECK" then
        ShowPullCheckWithSound()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        HidePullCheckFrames()
        return
    end

    if event == "UNIT_AURA" then
        local unit = ...

        if InCombatLockdown and InCombatLockdown() then
            return
        end

        if unit == "player" and checklistFrame and checklistFrame:IsShown() then
            UpdateChecklistVisuals()
        end

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
        if InCombatLockdown and InCombatLockdown() then
            print("PullCheck: checklist is disabled during combat.")
            return
        end

        RefreshChecklist()
        return
    end

    if command == "help" then
        PrintHelp()
        return
    end

    PrintHelp()
end
