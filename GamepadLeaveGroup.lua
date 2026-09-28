-- Adds leave-group confirmation to the unused bottom-face shortcuts slot.
local driver = CreateFrame("Frame")
local shortcuts, prompt
local buttonPending = true
local dialog = "FOREVER_TWEAKS_LEAVE_GROUP"

StaticPopupDialogs[dialog] = {
    text = "Leave your current group?",
    button1 = YES,
    button2 = CANCEL,
    OnAccept = function()
        if IsInGroup() then C_PartyInfo.LeaveParty() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OnLeaveClick(_, _, down)
    -- Both-shoulder mode already cancels native targeting. Do not write its
    -- wasModifierUsed field: native protected targeting code reads it later.
    if down and IsInGroup() then StaticPopup_Show(dialog) end
end

local function RefreshButton()
    buttonPending = true
    if not shortcuts or InCombatLockdown() then return end
    local button = shortcuts.faceBottomButton
    button:SetScript("OnClick", OnLeaveClick)
    button.SpecialActionIcon:SetTexture("Interface\\Icons\\Spell_Shadow_Teleport")
    button.SpecialActionIcon:Show()
    shortcuts:SetButtonEnabled(button, IsInGroup())
    buttonPending = false
end

local function RefreshPrompt(entry)
    entry:EnableOrDisablePrompt(IsInGroup())
end

local function Install()
    local page = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    if not shortcuts and page and page.actionBars and page.actionBars.shortcutsBar
        and page.actionBars.shortcutsBar.faceBottomButton and not InCombatLockdown() then
        shortcuts = page.actionBars.shortcutsBar
        hooksecurefunc(shortcuts, "SetUpActionButtons", RefreshButton)
        RefreshButton()
    end

    local legend = GamepadPersistentInputLegend
    if not prompt and legend and legend.groups and legend.groups.MODIFIER then
        -- Never call CreateEntry/AddToGroup here. Inserting into groups taints
        -- native legend iteration in the shared core-binding callback chain.
        -- An independent prompt follows an existing row without joining it.
        local bagsEntry
        for _, entry in ipairs(legend.groups.MODIFIER) do
            if entry.InputIcon1 and entry.InputIcon1.mappedButtonKey == GAMEPAD_FACE_RIGHT then
                bagsEntry = entry
                break
            end
        end
        if bagsEntry then
            prompt = CreateFrame("Frame", nil, legend, "InputPromptOneIconWithTextTemplate")
            prompt:SetPromptInputIconKey(1, GAMEPAD_FACE_BOTTOM)
            prompt:SetPromptText(LEAVE_PARTY)
            prompt:SetPromptFont("GameFontNormal")
            prompt:SetInputIconSize(1, 18, 18)
            prompt:SetPoint("TOPLEFT", bagsEntry, "TOPLEFT", 0, -24)
            prompt:SetShown(bagsEntry:IsShown())
            prompt:HookScript("OnShow", RefreshPrompt)
            bagsEntry:HookScript("OnShow", function() prompt:Show() end)
            bagsEntry:HookScript("OnHide", function() prompt:Hide() end)
            RefreshPrompt(prompt)
        end
    end
    if buttonPending then RefreshButton() end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("GROUP_ROSTER_UPDATE")
driver:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Do not let an old confirmation apply to a different roster.
        StaticPopup_Hide(dialog)
        buttonPending = true
        if prompt then RefreshPrompt(prompt) end
    end
    Install()
end)
